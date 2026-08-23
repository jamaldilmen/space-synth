#pragma once
#include <array>
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
    float fastEnv = 0.0f;
    float slowEnv = 0.0f;
    float cooldown = 0.0f;
    bool isTransient = false;
  };

  static constexpr int kVJBands = 16;

  // Get the current VJ frequency analysis bands. GENUINELY lock-free now
  // (2026-08-22) — the old comment said "lock-free read" while the body took a
  // mutex AND heap-allocated the returned vector INSIDE it, on the main thread,
  // twice a frame, against a realtime thread that blocked on the same mutex.
  // Returns by value: std::array is a stack aggregate, so no allocation, and
  // .size() / range-for / indexing all behave as the old vector did.
  std::array<VJBand, kVJBands> getVJBands() const;

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
  // RT-THREAD-PRIVATE working state. The envelope followers (fastEnv/slowEnv/
  // cooldown) live here across callbacks; ONLY audioInputCallback mutates it
  // after construction, so it needs no synchronisation of its own.
  std::vector<VJBand> vjBands_;

  // ── PUBLICATION: seqlock, not a mutex (2026-08-22) ────────────────────────
  // The realtime thread must never block. It publishes a snapshot by bumping
  // vjSeq_ odd, copying, then bumping it even — both stores are wait-free.
  // A reader retries if it observes an odd count or a changed count.
  VJBand vjPublished_[kVJBands] = {};
  mutable std::atomic<uint32_t> vjSeq_{0};
  std::atomic<float> vjInputGain_{2.0f}; // Default boost to 2.0x
  std::atomic<uint32_t> transientMask_{0};

public:
  uint32_t getTransientMask() const { return transientMask_.load(std::memory_order_acquire); }
};

} // namespace space
