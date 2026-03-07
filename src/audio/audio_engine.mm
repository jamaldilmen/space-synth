#include "audio/audio_engine.h"
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
};

static OSStatus audioOutputCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber, UInt32 inNumberFrames,
                                    AudioBufferList *ioData) {
  static int callbackCount = 0;
  if (++callbackCount % 100 == 1) {
    fprintf(stderr, "[AUDIO] Callback pulse (%d) | frames=%u\n", callbackCount,
            (unsigned int)inNumberFrames);
  }

  auto *impl = static_cast<AudioEngine::Impl *>(inRefCon);
  if (!impl->synth)
    return noErr;

  float *outL = static_cast<float *>(ioData->mBuffers[0].mData);
  float *outR = (ioData->mNumberBuffers > 1)
                    ? static_cast<float *>(ioData->mBuffers[1].mData)
                    : nullptr;

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

  return noErr;
}

AudioEngine::AudioEngine() : impl_(new Impl()) {}

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

  AudioComponentDescription desc = {kAudioUnitType_Output,
                                    kAudioUnitSubType_DefaultOutput,
                                    kAudioUnitManufacturer_Apple, 0, 0};

  AudioComponent comp = AudioComponentFindNext(nullptr, &desc);
  if (!comp) {
    fprintf(stderr, "[AUDIO ERROR] Could not find default output component\n");
    return false;
  }

  OSStatus err = AudioComponentInstanceNew(comp, &impl_->audioUnit);
  if (err != noErr) {
    fprintf(stderr,
            "[AUDIO ERROR] Could not create audio unit instance (err=%d)\n",
            (int)err);
    return false;
  }

  AURenderCallbackStruct callback;
  callback.inputProc = audioOutputCallback;
  callback.inputProcRefCon = impl_;

  err = AudioUnitSetProperty(
      impl_->audioUnit, kAudioUnitProperty_SetRenderCallback,
      kAudioUnitScope_Input, 0, &callback, sizeof(callback));
  if (err != noErr) {
    fprintf(stderr, "[AUDIO ERROR] Could not set render callback (err=%d)\n",
            (int)err);
    return false;
  }

  AudioStreamBasicDescription stream;
  stream.mSampleRate = sampleRate;
  stream.mFormatID = kAudioFormatLinearPCM;
  stream.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked |
                        kAudioFormatFlagIsNonInterleaved;
  stream.mBytesPerPacket = 4;
  stream.mFramesPerPacket = 1;
  stream.mBytesPerFrame = 4;
  stream.mChannelsPerFrame = 2;
  stream.mBitsPerChannel = 32;

  err = AudioUnitSetProperty(impl_->audioUnit, kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input, 0, &stream, sizeof(stream));
  if (err != noErr) {
    fprintf(stderr, "[AUDIO ERROR] Could not set stream format (err=%d)\n",
            (int)err);
    return false;
  }

  err = AudioUnitInitialize(impl_->audioUnit);
  if (err != noErr) {
    fprintf(stderr, "[AUDIO ERROR] Could not initialize audio unit (err=%d)\n",
            (int)err);
    return false;
  }

  OSStatus startErr = AudioOutputUnitStart(impl_->audioUnit);
  if (startErr != noErr) {
    fprintf(stderr, "[AUDIO ERROR] Could not start audio output (err=%d)\n",
            (int)startErr);
    return false;
  }

  printf("[AUDIO] Engine started successfully at %d Hz\n", sampleRate);
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

int AudioEngine::readSamples(float *buffer, int maxFrames) { return 0; }

} // namespace space
