#include "audio/synth.h"
#include <algorithm>
#include <cmath>
#include <mutex>
#include <vector>

namespace space {

static constexpr float TWO_PI = 2.0f * M_PI;

float Voice::tick(float sampleRate) {
  float amp = envelope.amplitude;
  if (amp < 0.0001f)
    return 0.0f;

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

  return sample * amp;
}

Synth::Synth() {}

float Synth::tick(float sampleRate) {
  std::lock_guard<std::mutex> lock(mutex_);
  float mixed = 0.0f;
  for (auto &[midi, voice] : voices_) {
    mixed += voice.tick(sampleRate);
  }
  return mixed * 0.3f; // MATCH HTML MASTER GAIN
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
  return std::min(1.5f, total);
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
