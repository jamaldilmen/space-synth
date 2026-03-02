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

float Voice::tick(float sampleRate, float synthJitter) {
  float amp = envelope.amplitude;
  if (amp < 0.0001f)
    return 0.0f;

  // Filter Modulation: Keytracking and Envelope Sweep
  // Base cutoff tracks the fundamental pitch (Moog/Diva style)
  float baseCutoff = std::max(50.0f, frequency * 0.8f);

  // Envelope sweep amount scales with pitch as well
  float sweepAmount = 3000.0f + (frequency * 2.5f);
  float cutoff = baseCutoff + (amp * sweepAmount);

  // Set filter with slightly higher resonance for that "brassiness"
  filter.set(cutoff, 0.45f);

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

  // 1. Heisenberg Phase Drift (Juno Instability)
  // Analog oscillators drift slightly in pitch. By tying this to the
  // physics engine's jitter (scaling with momentary wave amplitude),
  // we map Heisenberg momentum noise directly to oscillator instability.
  float driftCents = ((rand() % 1000) / 1000.0f - 0.5f) * 10.0f *
                     (synthJitter * amp); // ±5 cents base drift
  float driftRatio = std::pow(2.0f, driftCents / 1200.0f);
  float driftedFrequency = frequency * driftRatio;

  // Advance phase with the drifty frequency
  phase += TWO_PI * driftedFrequency / sampleRate;
  if (phase >= TWO_PI)
    phase -= TWO_PI;

  // Breathy Noise Layer: Scales with frequency (higher notes = more 'air')
  float noiseAmount = 0.05f * amp * (1.0f + frequency / 500.0f);
  float noise = ((rand() % 1000) / 1000.0f - 0.5f) * noiseAmount;

  // Diva Vibes: Pre-filter analog saturation (drive)
  // Hit the filter "hot" to get that thick brassy tone
  float saturatedSample = std::tanh(sample * 1.5f);

  // Pass through Resonant Lowpass Filter
  float filtered = filter.process(saturatedSample + noise);

  return filtered * amp;
}

Synth::Synth() { chorus_.init(48000.0f); }

void Synth::tick(float sampleRate, float &outL, float &outR) {
  std::lock_guard<std::mutex> lock(mutex_);
  float mixed = 0.0f;
  for (auto &[midi, voice] : voices_) {
    // Inject the global physics jitter into the voice tick for Phase Drift
    mixed += voice.tick(sampleRate, jitter_);
  }
  // Apply soft clipper (tanh limiter) before output
  float limited = std::tanh(mixed * 0.4f) * 0.8f; // Headroom buffer

  // Stereo spatialization via Chorus
  chorus_.process(limited, limited, outL, outR);
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
