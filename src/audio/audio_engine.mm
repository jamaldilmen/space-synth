#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudio.h>
#include "audio/audio_engine.h"
#include <cmath>

namespace space {

// ── Ring Buffer ─────────────────────────────────────────────────────────────

AudioRingBuffer::AudioRingBuffer(int capacity)
    : buffer_(capacity, 0.0f), capacity_(capacity) {}

bool AudioRingBuffer::write(const float* data, int frames) {
    int wp = writePos_.load(std::memory_order_relaxed);
    int rp = readPos_.load(std::memory_order_acquire);

    for (int i = 0; i < frames; i++) {
        int next = (wp + 1) % capacity_;
        if (next == rp) return false;  // full
        buffer_[wp] = data[i];
        wp = next;
    }
    writePos_.store(wp, std::memory_order_release);
    return true;
}

int AudioRingBuffer::read(float* data, int maxFrames) {
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
    AudioDeviceID deviceId = 0;
};

static OSStatus audioInputCallback(
    void* inRefCon,
    AudioUnitRenderActionFlags* ioActionFlags,
    const AudioTimeStamp* inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList* ioData)
{
    auto* engine = static_cast<AudioEngine*>(inRefCon);
    (void)engine;
    // TODO: Render audio from unit, compute RMS, write to ring buffer
    // This is the real-time audio thread — no allocations, no locks, no ObjC
    return noErr;
}

AudioEngine::AudioEngine() : impl_(new Impl()) {}

AudioEngine::~AudioEngine() {
    stop();
    delete impl_;
}

std::vector<AudioDevice> AudioEngine::enumerateDevices() {
    std::vector<AudioDevice> devices;

    AudioObjectPropertyAddress addr = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };

    UInt32 size = 0;
    AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &addr, 0, nullptr, &size);
    int count = size / sizeof(AudioDeviceID);
    std::vector<AudioDeviceID> ids(count);
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, nullptr, &size, ids.data());

    for (auto id : ids) {
        // Check if device has input channels
        AudioObjectPropertyAddress inputAddr = {
            kAudioDevicePropertyStreamConfiguration,
            kAudioDevicePropertyScopeInput,
            kAudioObjectPropertyElementMain
        };

        UInt32 streamSize = 0;
        AudioObjectGetPropertyDataSize(id, &inputAddr, 0, nullptr, &streamSize);
        if (streamSize == 0) continue;

        std::vector<uint8_t> buf(streamSize);
        auto* abl = reinterpret_cast<AudioBufferList*>(buf.data());
        AudioObjectGetPropertyData(id, &inputAddr, 0, nullptr, &streamSize, abl);

        int channels = 0;
        for (UInt32 i = 0; i < abl->mNumberBuffers; i++) {
            channels += abl->mBuffers[i].mNumberChannels;
        }
        if (channels == 0) continue;

        // Get device name
        AudioObjectPropertyAddress nameAddr = {
            kAudioObjectPropertyName,
            kAudioObjectPropertyScopeGlobal,
            kAudioObjectPropertyElementMain
        };
        CFStringRef cfName = nullptr;
        UInt32 nameSize = sizeof(cfName);
        AudioObjectGetPropertyData(id, &nameAddr, 0, nullptr, &nameSize, &cfName);

        char name[256] = {};
        if (cfName) {
            CFStringGetCString(cfName, name, sizeof(name), kCFStringEncodingUTF8);
            CFRelease(cfName);
        }

        devices.push_back({static_cast<uint32_t>(id), name, channels, 48000});
    }

    return devices;
}

bool AudioEngine::start(uint32_t deviceId, int sampleRate) {
    if (running_) stop();
    sampleRate_ = sampleRate;

    // TODO: Set up AUHAL audio unit with input callback
    // - Configure device ID
    // - Set stream format (float32, mono/stereo, sampleRate)
    // - Set input callback to audioInputCallback
    // - Initialize and start
    running_ = true;
    return true;
}

void AudioEngine::stop() {
    if (!running_) return;
    if (impl_->audioUnit) {
        AudioOutputUnitStop(impl_->audioUnit);
        AudioComponentInstanceDispose(impl_->audioUnit);
        impl_->audioUnit = nullptr;
    }
    running_ = false;
}

int AudioEngine::readSamples(float* buffer, int maxFrames) {
    return ringBuffer_.read(buffer, maxFrames);
}

} // namespace space
