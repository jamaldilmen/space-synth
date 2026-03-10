#pragma once
#include <atomic>
#include <cstdint>
#include <functional>
#include <string>
#include <vector>

namespace space {

struct AudioDevice {
  uint32_t id;
  std::string name;
  int inputChannels;
  int sampleRate;
};

// Lock-free SPSC ring buffer for audio→render thread communication
class AudioRingBuffer {
public:
  explicit AudioRingBuffer(int capacity = 8192);

  bool write(const float *data, int frames);
  int read(float *data, int maxFrames);
  int available() const;

private:
  std::vector<float> buffer_;
  std::atomic<int> readPos_{0};
  std::atomic<int> writePos_{0};
  int capacity_;
};

// CoreAudio input engine
// Captures audio from a selected device and delivers samples via ring buffer
class AudioEngine {
public:
  AudioEngine();
  ~AudioEngine();

  // Enumerate available input devices (including BlackHole/Loopback)
  std::vector<AudioDevice> enumerateDevices();

  // Start capture from a specific device
  bool start(uint32_t deviceId = 0, int sampleRate = 48000);
  void stop();

  // Hook up a synth to the audio output
  void setSynth(class Synth *s);

  bool isRunning() const { return running_; }
  int sampleRate() const { return sampleRate_; }

  // Read captured audio (call from render thread)
  int readSamples(float *buffer, int maxFrames);

  // Get current RMS amplitude (lock-free)
  float currentAmplitude() const {
    return amplitude_.load(std::memory_order_relaxed);
  }

  // Expose internals for CoreAudio callbacks
  AudioRingBuffer &ringBuffer() { return ringBuffer_; }
  std::atomic<float> &amplitude() { return amplitude_; }

  // ── VJ Audio Analysis (Phase 18) ─────────────────────────
  struct VJBand {
    float frequency; // Center frequency of the band
    float amplitude; // Current envelope-followed amplitude
  };

  // Get the current VJ frequency analysis bands (lock-free read)
  std::vector<VJBand> getVJBands() const;

  // Called by render thread to process available ring buffer audio into VJ
  // bands
  void processAudioAnalysis(float dt);

  // VJ Input Gain Control
  void setVJInputGain(float gain) {
    vjInputGain_.store(gain, std::memory_order_relaxed);
  }
  float vjInputGain() const {
    return vjInputGain_.load(std::memory_order_relaxed);
  }

public:
  struct Impl;
  Impl *impl_ = nullptr;

  AudioRingBuffer ringBuffer_;
  std::atomic<float> amplitude_{0.0f};
  std::atomic<bool> running_{false};
  int sampleRate_ = 48000;

  // VJ State
  std::vector<VJBand> vjBands_;
  mutable std::mutex vjMutex_;
  std::atomic<float> vjInputGain_{2.0f}; // Default boost to 2.0x
};

} // namespace space
