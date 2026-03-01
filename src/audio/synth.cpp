#include "audio/synth.h"
#include <algorithm>
#include <cmath>
#include <mutex>
#include <vector>

namespace space {

static constexpr float TWO_PI = 2.0f * M_PI;

void Voice::init(float sampleRate) {
  filter.setSampleRate(sampleRate);
  filter.reset();
}

float Voice::tick(float sampleRate) {
  float amp = envelope.amplitude;
  if (amp < 0.0001f)
    return 0.0f;

  // Filter Modulation: Cutoff sweeps based on envelope
  // Base cutoff 200Hz, sweeps up to 6000Hz based on envelope amplitude
  float cutoff = 200.0f + (amp * 5800.0f);
  // Optional: add velocity tracking here later
  filter.set(cutoff, 0.3f); // 0.3 resonance (mild peak)

  float sample = 0.0f;
  switch (waveform) {
  case Waveform::Sine:
    sample = std::sin(phase);
    break;
  case Waveform::Triangle:
    sample = 2.0f * std::abs(2.0f * (phase / TWO_PI -
                                     std::floor(phase / TWO_PI + 0.5f))) -
             1.0f;
    break;
  case Waveform::Sawtooth:
    sample = 2.0f * (phase / TWO_PI - std::floor(phase / TWO_PI + 0.5f));
    break;
  case Waveform::Square:
    sample = phase < M_PI ? 1.0f : -1.0f;
    break;
  }

  phase += TWO_PI * frequency / sampleRate;
  if (phase >= TWO_PI)
    phase -= TWO_PI;

  // Breathy Noise Layer: only during attack/decay (when envelope is high)
  // Adds analog instability
  float noise = ((rand() % 1000) / 1000.0f - 0.5f) * 0.1f * amp;

  // Pass through Resonant Lowpass Filter
  float filtered = filter.process(sample + noise);

  return filtered * amp;
}

Synth::Synth() {}

float Synth::tick(float sampleRate) {
  std::lock_guard<std::mutex> lock(mutex_);
  float mixed = 0.0f;
  for (auto &[midi, voice] : voices_) {
    mixed += voice.tick(sampleRate);
  }
  // Apply soft clipper (tanh limiter) before output
  float limited = std::tanh(mixed * 0.4f); // 0.4f gain staging
  return limited * 0.8f;                   // Headroom buffer
}

void Synth::noteOn(int midi, float velocity) {
  std::lock_guard<std::mutex> lock(mutex_);

  // Kill existing voice on same note
  auto it = voices_.find(midi);
  if (it != voices_.end()) {
    voices_.erase(it);
  }

  Voice v;
  v.midiNote = midi;
  v.frequency = midiToFreq(midi);
  v.waveform = waveform_;
  v.envelope.noteOn(velocity);
  v.mode = &modeTable_.modeForMidi(midi, keyboardMode_, keyboardStart());
  v.init(48000.0f); // hardcoded for now, should match audio engine

  voices_[midi] = v;
}

void Synth::noteOff(int midi) {
  std::lock_guard<std::mutex> lock(mutex_);

  auto it = voices_.find(midi);
  if (it == voices_.end())
    return;
  it->second.envelope.noteOff();
}

void Synth::updateEnvelopes(float dt) {
  std::lock_guard<std::mutex> lock(mutex_);

  std::vector<int> dead;
  for (auto &[midi, voice] : voices_) {
    voice.envelope.update(dt, envParams_);
    if (!voice.envelope.isActive()) {
      dead.push_back(midi);
    }
  }
  for (int midi : dead) {
    voices_.erase(midi);
  }
}

float Synth::totalAmplitude() const {
  std::lock_guard<std::mutex> lock(const_cast<std::mutex &>(mutex_));

  float total = 0.0f;
  for (const auto &[_, voice] : voices_) {
    total += voice.envelope.amplitude;
  }
  return std::min(4.0f, total); // Allow full polyphonic amplitude through
}

int Synth::activeVoiceCount() const {
  std::lock_guard<std::mutex> lock(const_cast<std::mutex &>(mutex_));

  int count = 0;
  for (const auto &[_, voice] : voices_) {
    if (voice.envelope.amplitude > 0.001f)
      count++;
  }
  return count;
}

std::vector<Synth::ActiveVoice> Synth::getActiveVoices() const {
  std::lock_guard<std::mutex> lock(const_cast<std::mutex &>(mutex_));

  std::vector<ActiveVoice> active;
  for (const auto &[_, voice] : voices_) {
    if (voice.envelope.amplitude > 0.001f && voice.mode) {
      active.push_back({voice.envelope.amplitude, voice.frequency, voice.mode});
    }
  }
  return active;
}

void Synth::cycleWaveform() {
  int idx = (static_cast<int>(waveform_) + 1) % 4;
  waveform_ = static_cast<Waveform>(idx);
}

} // namespace space
