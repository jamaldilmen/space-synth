#include "audio/audio_engine.h"
#include "audio/fft.h"
#include "audio/synth.h"
#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudio.h>
#include <cmath>

namespace space {

// ── Ring Buffer ─────────────────────────────────────────────────────────────

AudioRingBuffer::AudioRingBuffer(int capacity)
    : buffer_(capacity, 0.0f), capacity_(capacity) {}

bool AudioRingBuffer::write(const float *data, int frames) {
  int wp = writePos_.load(std::memory_order_relaxed);
  int rp = readPos_.load(std::memory_order_acquire);

  for (int i = 0; i < frames; i++) {
    int next = (wp + 1) % capacity_;
    if (next == rp)
      return false; // full
    buffer_[wp] = data[i];
    wp = next;
  }
  writePos_.store(wp, std::memory_order_release);
  return true;
}

int AudioRingBuffer::read(float *data, int maxFrames) {
  int rp = readPos_.load(std::memory_order_relaxed);
  int wp = writePos_.load(std::memory_order_acquire);
  int count = 0;

  while (rp != wp && count < maxFrames) {
    data[count++] = buffer_[rp];
    rp = (rp + 1) % capacity_;
  }
  readPos_.store(rp, std::memory_order_release);
  return count;
}

int AudioRingBuffer::available() const {
  int wp = writePos_.load(std::memory_order_acquire);
  int rp = readPos_.load(std::memory_order_acquire);
  return (wp - rp + capacity_) % capacity_;
}

// ── CoreAudio Implementation ────────────────────────────────────────────────

struct AudioEngine::Impl {
  AudioComponentInstance audioUnit = nullptr;
  Synth *synth = nullptr;
  float sampleRate = 48000.0f;

  std::unique_ptr<FFTAnalyzer> fft;
  std::vector<float> inputScratchBuffer;
};

static OSStatus audioOutputCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber, UInt32 inNumberFrames,
                                    AudioBufferList *ioData) {
  // ⛔ NO stdio HERE — 2026-08-22. A pulse `fprintf(stderr, ...)` every 100th
  // callback lived on this line. stderr is unbuffered: it is a write(2) plus a
  // FILE lock, on the thread that must never block. Nothing else read
  // `callbackCount`, so it went with it. Do not add printf/NSLog/os_log to any
  // function reachable from this callback — use a lock-free counter the render
  // thread reads instead.

  auto *impl = static_cast<AudioEngine::Impl *>(inRefCon);
  float *outL = static_cast<float *>(ioData->mBuffers[0].mData);
  float *outR = (ioData->mNumberBuffers > 1)
                    ? static_cast<float *>(ioData->mBuffers[1].mData)
                    : nullptr;

  if (impl->synth) {
    const float sampleRate = impl->sampleRate;
    if (outR) {
      impl->synth->processBlock(sampleRate, outL, outR, inNumberFrames);
    } else {
      for (UInt32 i = 0; i < inNumberFrames; i++) {
        float sL = 0.0f, sR = 0.0f;
        impl->synth->tick(sampleRate, sL, sR);
        outL[i] = sL;
      }
    }
  } else {
    // Silence if no synth attached
    memset(outL, 0, inNumberFrames * sizeof(float));
    if (outR)
      memset(outR, 0, inNumberFrames * sizeof(float));
  }

  return noErr;
}

static OSStatus audioInputCallback(void *inRefCon,
                                   AudioUnitRenderActionFlags *ioActionFlags,
                                   const AudioTimeStamp *inTimeStamp,
                                   UInt32 inBusNumber, UInt32 inNumberFrames,
                                   AudioBufferList *ioData) {
  auto *engine = static_cast<AudioEngine *>(inRefCon);
  auto *impl = engine->impl_;

  AudioBufferList bufferList;
  bufferList.mNumberBuffers = 1;
  bufferList.mBuffers[0].mDataByteSize = inNumberFrames * sizeof(float);
  bufferList.mBuffers[0].mNumberChannels = 1;
  bufferList.mBuffers[0].mData =
      nullptr; // Let CoreAudio allocate it or we must provide our own.

  // Ensure scratch buffer is large enough (resize is safe-ish here because it
  // shouldn't hit after first frame)
  if (impl->inputScratchBuffer.size() < inNumberFrames) {
    impl->inputScratchBuffer.resize(inNumberFrames);
  }

  bufferList.mBuffers[0].mData = impl->inputScratchBuffer.data();

  OSStatus err = AudioUnitRender(impl->audioUnit, ioActionFlags, inTimeStamp,
                                 inBusNumber, inNumberFrames, &bufferList);
  if (err == noErr) {
    float *inSamples = static_cast<float *>(bufferList.mBuffers[0].mData);
    float gain = engine->vjInputGain();

    // Apply input gain
    for (UInt32 i = 0; i < inNumberFrames; i++) {
      inSamples[i] *= gain;
    }

    // Write mono audio to ring buffer
    engine->ringBuffer_.write(inSamples, inNumberFrames);

    // Calculate RMS amplitude
    float sumSq = 0.0f;
    for (UInt32 i = 0; i < inNumberFrames; i++) {
      sumSq += inSamples[i] * inSamples[i];
    }
    float rms = std::sqrt(sumSq / inNumberFrames);
    engine->amplitude_.store(rms, std::memory_order_relaxed);

    // Phase 18: Feed incoming live audio to the FFT Analyzer
    if (impl->fft) {
      if (impl->fft->process(inSamples, inNumberFrames)) {
        // FFT frame is ready. Extract logarithmic bins.
        const auto &magnitudes = impl->fft->magnitudes();

        // ⛔ NO LOCK HERE — 2026-08-22. This took lock_guard(vjMutex_) while
        // the main thread held the same mutex in getVJBands() *and allocated
        // under it*, 2x/frame. vjBands_ is RT-private; the snapshot is
        // published wait-free below.
        for (int i = 0; i < 16; i++) {
          float centerFreq = engine->vjBands_[i].frequency;
          int binStart = (int)(centerFreq * 0.8f * 2048 / engine->sampleRate_);
          int binEnd = (int)(centerFreq * 1.25f * 2048 / engine->sampleRate_);
          binStart = std::max(1, std::min(1023, binStart));
          binEnd = std::max(binStart + 1, std::min(1024, binEnd));

          float bandEnergy = 0.0f;
          for (int b = binStart; b < binEnd; b++) {
            bandEnergy += magnitudes[b] * magnitudes[b];
          }
          bandEnergy = std::sqrt(bandEnergy / (binEnd - binStart));

          // Envelope following (fast attack, tuned release per frequency group)
          float currentAmp = engine->vjBands_[i].amplitude;
          if (bandEnergy > currentAmp) {
            engine->vjBands_[i].amplitude =
                std::min(1.0f, currentAmp + (bandEnergy - currentAmp) * 0.8f);
          } else {
            float release =
                (i < 4) ? 0.98f
                        : 0.95f; // Bass decays slightly slower for visual punch
            engine->vjBands_[i].amplitude =
                std::max(0.0f, currentAmp * release);
          }
        }

        // Per-band onset detection (fast/slow envelope ratio)
        uint32_t mask = 0;
        for (int i = 0; i < 16; i++) {
          auto& b = engine->vjBands_[i];
          float E = b.amplitude * b.amplitude;
          b.fastEnv = 0.3f * E + 0.7f * b.fastEnv;
          b.slowEnv = 0.01f * E + 0.99f * b.slowEnv;
          b.isTransient = false;
          if (b.cooldown > 0.f) b.cooldown -= (float)inNumberFrames / engine->sampleRate_;
          if (E > 1e-5f && b.slowEnv > 0.f && b.cooldown <= 0.f) {
            float ratio = b.fastEnv / (b.slowEnv + 1e-6f);
            if (ratio > 2.0f) {
              b.isTransient = true;
              b.cooldown = 0.03f;
              mask |= (1u << i);
            }
          }
        }
        engine->transientMask_.store(mask, std::memory_order_release);

        // ── PUBLISH (seqlock write half). Wait-free: two relaxed/release
        // stores around a 16-element copy. Odd count = write in progress.
        const uint32_t seq = engine->vjSeq_.load(std::memory_order_relaxed);
        engine->vjSeq_.store(seq + 1, std::memory_order_release);
        std::atomic_thread_fence(std::memory_order_release);
        for (int i = 0; i < AudioEngine::kVJBands; i++) {
          engine->vjPublished_[i] = engine->vjBands_[i];
        }
        engine->vjSeq_.store(seq + 2, std::memory_order_release);
      }
    }
  }
  return err;
}

AudioEngine::AudioEngine() : impl_(new Impl()) {
  // Initialize VJ bands: 16 logarithmic bands
  vjBands_.resize(kVJBands);
  for (int i = 0; i < kVJBands; i++) {
    vjBands_[i].frequency = 40.0f * std::pow(2.0f, i * 0.5f); // 40Hz to ~7.5kHz
    vjBands_[i].amplitude = 0.0f;
    // Seed the PUBLISHED copy too. Without this, getVJBands() returns
    // frequency = 0 until the first FFT frame lands and the live-spectrum UI
    // (main.cpp:1831, "%4.0fHz") labels all 16 bands "0Hz" before any audio.
    vjPublished_[i] = vjBands_[i];
  }
}

AudioEngine::~AudioEngine() {
  stop();
  delete impl_;
}

void AudioEngine::setSynth(Synth *s) { impl_->synth = s; }

std::vector<AudioDevice> AudioEngine::enumerateDevices() { return {}; }

bool AudioEngine::start(uint32_t deviceId, int sampleRate) {
  if (running_)
    stop();
  sampleRate_ = sampleRate;
  impl_->sampleRate = static_cast<float>(sampleRate);

  impl_->fft = std::make_unique<FFTAnalyzer>(2048, sampleRate);
  impl_->inputScratchBuffer.resize(8192, 0.0f);

  // Plain HAL output unit (NOT VoiceProcessingIO). VoiceProcessingIO puts
  // CoreAudio into voice-call mode, which ducks/silences every other app on the
  // system — even with DuckNonVoiceAudio=0. HALOutput drives synth output
  // (bus 0) and still allows optional mic input (bus 1) without any ducking.
  OSType subType = kAudioUnitSubType_HALOutput;

  AudioComponentDescription desc = {kAudioUnitType_Output, subType,
                                    kAudioUnitManufacturer_Apple, 0, 0};

  AudioComponent comp = AudioComponentFindNext(nullptr, &desc);
  if (!comp) {
    fprintf(stderr, "[AUDIO ERROR] Could not find IO component\n");
    return false;
  }

  OSStatus err = AudioComponentInstanceNew(comp, &impl_->audioUnit);
  if (err != noErr) {
    fprintf(stderr, "[AUDIO ERROR] Could not create IO unit (err=%d)\n",
            (int)err);
    return false;
  }

  // Enable Input on Bus 1 (Input bus)
  UInt32 enableIO = 1;
  err = AudioUnitSetProperty(
      impl_->audioUnit, kAudioOutputUnitProperty_EnableIO,
      kAudioUnitScope_Input, 1, &enableIO, sizeof(enableIO));

  // Enable Output on Bus 0 (Output bus)
  err = AudioUnitSetProperty(
      impl_->audioUnit, kAudioOutputUnitProperty_EnableIO,
      kAudioUnitScope_Output, 0, &enableIO, sizeof(enableIO));

  // Set Output Callback
  AURenderCallbackStruct outCallback;
  outCallback.inputProc = audioOutputCallback;
  outCallback.inputProcRefCon = impl_;
  err = AudioUnitSetProperty(
      impl_->audioUnit, kAudioUnitProperty_SetRenderCallback,
      kAudioUnitScope_Input, 0, &outCallback, sizeof(outCallback));

  // Set Input Callback
  AURenderCallbackStruct inCallback;
  inCallback.inputProc = audioInputCallback;
  inCallback.inputProcRefCon = this; // Pass AudioEngine instance
  err = AudioUnitSetProperty(
      impl_->audioUnit, kAudioOutputUnitProperty_SetInputCallback,
      kAudioUnitScope_Global, 1, &inCallback, sizeof(inCallback));

  AudioStreamBasicDescription stream;
  stream.mSampleRate = sampleRate;
  stream.mFormatID = kAudioFormatLinearPCM;
  stream.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked |
                        kAudioFormatFlagIsNonInterleaved;
  stream.mBytesPerPacket = 4;
  stream.mFramesPerPacket = 1;
  stream.mBytesPerFrame = 4;
  stream.mChannelsPerFrame = 2; // Stereo out
  stream.mBitsPerChannel = 32;

  // Set format for Output (Bus 0)
  err = AudioUnitSetProperty(impl_->audioUnit, kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input, 0, &stream, sizeof(stream));

  // Set format for Input (Bus 1) - Mono In
  stream.mChannelsPerFrame = 1;
  err =
      AudioUnitSetProperty(impl_->audioUnit, kAudioUnitProperty_StreamFormat,
                           kAudioUnitScope_Output, 1, &stream, sizeof(stream));

  err = AudioUnitInitialize(impl_->audioUnit);
  if (err != noErr) {
    fprintf(stderr, "[AUDIO ERROR] Could not initialize IO unit (err=%d)\n",
            (int)err);
    return false;
  }

  OSStatus startErr = AudioOutputUnitStart(impl_->audioUnit);
  if (startErr != noErr) {
    fprintf(stderr, "[AUDIO ERROR] Could not start IO output (err=%d)\n",
            (int)startErr);
    return false;
  }

  printf("[AUDIO] IO Engine started successfully at %d Hz\n", sampleRate);
  running_ = true;
  return true;
}

void AudioEngine::stop() {
  if (!running_)
    return;
  if (impl_->audioUnit) {
    AudioOutputUnitStop(impl_->audioUnit);
    AudioUnitUninitialize(impl_->audioUnit);
    AudioComponentInstanceDispose(impl_->audioUnit);
    impl_->audioUnit = nullptr;
  }
  running_ = false;
}

int AudioEngine::readSamples(float *buffer, int maxFrames) {
  return ringBuffer_.read(buffer, maxFrames);
}

std::array<AudioEngine::VJBand, AudioEngine::kVJBands>
AudioEngine::getVJBands() const {
  // Seqlock read half. No mutex, no allocation — so the realtime thread is
  // never blocked by this call. Retries only if it catches a write in flight.
  std::array<VJBand, kVJBands> out{};
  for (;;) {
    const uint32_t s1 = vjSeq_.load(std::memory_order_acquire);
    if (s1 & 1u) continue;  // writer mid-publish
    for (int i = 0; i < kVJBands; i++) out[i] = vjPublished_[i];
    std::atomic_thread_fence(std::memory_order_acquire);
    if (vjSeq_.load(std::memory_order_relaxed) == s1) break;
  }
  return out;
}

} // namespace space
