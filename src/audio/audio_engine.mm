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
};

static OSStatus audioOutputCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber, UInt32 inNumberFrames,
                                    AudioBufferList *ioData) {
  auto *impl = static_cast<AudioEngine::Impl *>(inRefCon);
  if (!impl->synth)
    return noErr;

  float *outL = static_cast<float *>(ioData->mBuffers[0].mData);
  float *outR = (ioData->mNumberBuffers > 1)
                    ? static_cast<float *>(ioData->mBuffers[1].mData)
                    : nullptr;

  const float sampleRate = 48000.0f;

  for (UInt32 i = 0; i < inNumberFrames; i++) {
    float sample = impl->synth->tick(sampleRate);
    outL[i] = sample;
    if (outR)
      outR[i] = sample;
  }

  return noErr;
}

AudioEngine::AudioEngine() : impl_(new Impl()) {}

AudioEngine::~AudioEngine() {
  stop();
  delete impl_;
}

void AudioEngine::setSynth(Synth *s) { impl_->synth = s; }

std::vector<AudioDevice> AudioEngine::enumerateDevices() {
  return {}; // Simplified for output focus
}

bool AudioEngine::start(uint32_t deviceId, int sampleRate) {
  if (running_)
    stop();
  sampleRate_ = sampleRate;

  AudioComponentDescription desc = {kAudioUnitType_Output,
                                    kAudioUnitSubType_DefaultOutput,
                                    kAudioUnitManufacturer_Apple, 0, 0};

  AudioComponent comp = AudioComponentFindNext(nullptr, &desc);
  if (!comp)
    return false;

  if (AudioComponentInstanceNew(comp, &impl_->audioUnit) != noErr)
    return false;

  AURenderCallbackStruct callback;
  callback.inputProc = audioOutputCallback;
  callback.inputProcRefCon = impl_;

  if (AudioUnitSetProperty(
          impl_->audioUnit, kAudioUnitProperty_SetRenderCallback,
          kAudioUnitScope_Input, 0, &callback, sizeof(callback)) != noErr)
    return false;

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

  if (AudioUnitSetProperty(impl_->audioUnit, kAudioUnitProperty_StreamFormat,
                           kAudioUnitScope_Input, 0, &stream,
                           sizeof(stream)) != noErr)
    return false;

  if (AudioUnitInitialize(impl_->audioUnit) != noErr)
    return false;
  if (AudioOutputUnitStart(impl_->audioUnit) != noErr)
    return false;

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
