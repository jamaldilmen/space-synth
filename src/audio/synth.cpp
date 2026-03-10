#include "audio/synth.h"
#include <algorithm>
#include <atomic>
#include <cmath>
#include <mutex>
#include <vector>

namespace space {

static constexpr float TWO_PI = 2.0f * M_PI;

void Voice::init(float sampleRate) {
  filter.setSampleRate(sampleRate);
  filter.reset();
  static std::atomic<uint32_t> globalSeed(42);
  rngState = (globalSeed.fetch_add(1, std::memory_order_relaxed) * 1103515245u +
              12345u);
}

static uint32_t xorshift32(uint32_t &state) {
  state ^= state << 13;
  state ^= state >> 17;
  state ^= state << 5;
  return state;
}

float Voice::tick(float sampleRate, float synthJitter) {
  float amp = envelope.amplitude;
  if (amp < 0.0001f)
    return 0.0f;

  float baseCutoff = std::max(50.0f, frequency * 0.8f);
  float sweepAmount = 3000.0f + (frequency * 2.5f);
  float cutoff = baseCutoff + (amp * sweepAmount);

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

  // Phase Drift: Jitter scales with amplitude (instability)
  float driftCents = ((float)(xorshift32(rngState) % 1000) / 1000.0f - 0.5f) *
                     10.0f * (synthJitter * amp);
  float driftRatio = std::pow(2.0f, driftCents / 1200.0f);

  phase += TWO_PI * (frequency * driftRatio) / sampleRate;
  if (phase >= TWO_PI)
    phase -= TWO_PI;

  float noiseVal = (float)(xorshift32(rngState) % 1000) / 1000.0f - 0.5f;
  float noiseAmount = 0.05f * amp * (1.0f + frequency / 500.0f);
  float noise = noiseVal * noiseAmount;

  float saturatedSample = std::tanh(sample * 1.5f);
  float filtered = filter.process(saturatedSample + noise);

  return filtered * amp;
}

Synth::Synth() { chorus_.init(48000.0f); }

void Synth::tick(float sampleRate, float &outL, float &outR) {
  processBlock(sampleRate, &outL, &outR, 1);
}

void Synth::processBlock(float sampleRate, float *outL, float *outR,
                         int numFrames) {
#if defined(__arm64__) || defined(__aarch64__)
  // Flush denormals to zero on ARM (prevents denormal performance penalty)
  uint64_t fpcr;
  __asm__ __volatile__("mrs %0, fpcr" : "=r"(fpcr));
  __asm__ __volatile__("msr fpcr, %0" ::"r"(fpcr | (1 << 24))); // FZ bit
#endif

  {
    std::lock_guard<std::mutex> lock(queueMutex_);
    swapBuffer_.swap(commandQueue_);
  }

  // Interleave commands and synthesis for sample-accurate timing
  int cmdIdx = 0;

  for (int i = 0; i < numFrames; i++) {
    // Fire all commands scheduled for this specific sample
    while (cmdIdx < (int)swapBuffer_.size() &&
           swapBuffer_[cmdIdx].sampleOffset <= i) {
      const auto &cmd = swapBuffer_[cmdIdx];
      if (cmd.type == MidiCommand::NoteOn) {
        handleNoteOnInternal(cmd.midi, cmd.velocity);
      } else {
        handleNoteOffInternal(cmd.midi);
      }
      cmdIdx++;
    }

    float mixed = 0.0f;
    for (auto it = voices_.begin(); it != voices_.end();) {
      mixed += it->second.tick(sampleRate, jitter_);
      // Update envelope and clean up finished voices
      it->second.envelope.update(1.0f / sampleRate, envParams_);
      if (!it->second.envelope.isActive()) {
        it = voices_.erase(it);
      } else {
        ++it;
      }
    }

    float limited = std::tanh(mixed * 0.45f) * 0.9f;
    chorus_.process(limited, limited, outL[i], outR[i]);

    // Apply Master Volume
    outL[i] *= masterVolume_;
    outR[i] *= masterVolume_;
  }
}

void Synth::processCommands() {
  std::vector<MidiCommand> commands;
  {
    std::lock_guard<std::mutex> lock(queueMutex_);
    commands.swap(commandQueue_);
  }

  for (const auto &cmd : commands) {
    if (cmd.type == MidiCommand::NoteOn) {
      handleNoteOn(cmd.midi, cmd.velocity);
    } else {
      handleNoteOff(cmd.midi);
    }
  }
}

void Synth::noteOn(int midi, float velocity, int sampleOffset) {
  std::lock_guard<std::mutex> lock(queueMutex_);
  if (commandQueue_.size() < 256) {
    commandQueue_.push_back(
        {MidiCommand::NoteOn, midi, velocity, sampleOffset});
    // Keep queue sorted by sample offset
    std::sort(commandQueue_.begin(), commandQueue_.end(),
              [](const MidiCommand &a, const MidiCommand &b) {
                return a.sampleOffset < b.sampleOffset;
              });
  }
}

void Synth::noteOff(int midi, int sampleOffset) {
  std::lock_guard<std::mutex> lock(queueMutex_);
  if (commandQueue_.size() < 256) {
    commandQueue_.push_back({MidiCommand::NoteOff, midi, 0.0f, sampleOffset});
    std::sort(commandQueue_.begin(), commandQueue_.end(),
              [](const MidiCommand &a, const MidiCommand &b) {
                return a.sampleOffset < b.sampleOffset;
              });
  }
}

void Synth::handleNoteOn(int midi, float velocity) {
  std::lock_guard<std::mutex> lock(mutex_);
  handleNoteOnInternal(midi, velocity);
}

void Synth::handleNoteOnInternal(int midi, float velocity) {
  auto it = voices_.find(midi);
  if (it != voices_.end()) {
    voices_.erase(it);
  }

  if (voices_.size() >= MAX_VOICES) {
    // Prefer stealing voices in Release > Sustain > Decay. Never steal Attack.
    int stealMidi = -1;
    float bestScore = -1.0f;
    for (const auto &[m, voice] : voices_) {
      float score = -1.0f;
      switch (voice.envelope.phase) {
      case EnvPhase::Release:
        score = 3.0f + (1.0f - voice.envelope.amplitude);
        break;
      case EnvPhase::Sustain:
        score = 2.0f + (1.0f - voice.envelope.amplitude);
        break;
      case EnvPhase::Decay:
        score = 1.0f + (1.0f - voice.envelope.amplitude);
        break;
      case EnvPhase::Attack:
        score = -1.0f;
        break; // Never steal Attack
      default:
        score = 4.0f;
        break; // Off/silent = best candidate
      }
      if (score > bestScore) {
        bestScore = score;
        stealMidi = m;
      }
    }
    if (stealMidi != -1) {
      voices_.erase(stealMidi);
    }
  }

  Voice v;
  v.midiNote = midi;
  v.frequency = midiToFreq(midi);
  v.waveform = waveform_;
  v.envelope.noteOn(velocity);
  v.mode = &modeTable_.modeForMidi(midi, keyboardMode_, keyboardStart());
  v.init(48000.0f);

  voices_[midi] = v;
}

void Synth::handleNoteOff(int midi) {
  std::lock_guard<std::mutex> lock(mutex_);
  handleNoteOffInternal(midi);
}

void Synth::handleNoteOffInternal(int midi) {
  auto it = voices_.find(midi);
  if (it != voices_.end()) {
    it->second.envelope.noteOff();
  }
}

void Synth::updateEnvelopes(float /*dt*/) {
  // Logic moved to audio thread processBlock for sample-accuracy
}

float Synth::totalAmplitude() const {
  std::lock_guard<std::mutex> lock(mutex_);
  float total = 0.0f;
  for (const auto &[midi, voice] : voices_) {
    total += voice.envelope.amplitude;
  }
  return total;
}

int Synth::activeVoiceCount() const {
  // Process any pending commands so the count is immediate
  const_cast<Synth *>(this)->processCommands();
  std::lock_guard<std::mutex> lock(mutex_);
  return (int)voices_.size();
}

std::vector<Synth::ActiveVoice> Synth::getActiveVoices() const {
  std::lock_guard<std::mutex> lock(mutex_);
  std::vector<ActiveVoice> active;
  for (const auto &[midi, voice] : voices_) {
    active.push_back(
        {voice.envelope.amplitude, voice.frequency, voice.phase, voice.mode});
  }
  return active;
}

void Synth::cycleWaveform() {
  waveform_ = (Waveform)(((int)waveform_ + 1) % 4);
}

Synth::EnvelopeState Synth::getDominantEnvelope() const {
  std::lock_guard<std::mutex> lock(mutex_);

  if (voices_.empty()) {
    return {0.0f, 0.0f, 0.0f}; // Silence → Black hole
  }

  // Find the loudest voice to determine lifecycle phase
  float maxAmp = 0.0f;
  const Voice *dominant = nullptr;

  for (const auto &[note, voice] : voices_) {
    if (voice.envelope.amplitude > maxAmp) {
      maxAmp = voice.envelope.amplitude;
      dominant = &voice;
    }
  }

  if (!dominant || maxAmp < 0.001f) {
    return {0.0f, 0.0f, 0.0f};
  }

  EnvelopeState state;
  // Compute total amplitude without re-locking (we already hold mutex_)
  float total = 0.0f;
  for (const auto &[midi, voice] : voices_) {
    total += voice.envelope.amplitude;
  }
  state.intensity = total;

  // Map EnvPhase enum to float codes
  switch (dominant->envelope.phase) {
  case EnvPhase::Attack: {
    state.phase = 1.0f;
    float attackTime = envParams_.attack;
    state.progress =
        (attackTime > 0.0f)
            ? std::min(1.0f, dominant->envelope.envTime / attackTime)
            : 1.0f;
    break;
  }
  case EnvPhase::Decay: {
    state.phase = 2.0f;
    float decayTime = envParams_.decay;
    state.progress =
        (decayTime > 0.0f)
            ? std::min(1.0f, dominant->envelope.envTime / decayTime)
            : 1.0f;
    break;
  }
  case EnvPhase::Sustain: {
    state.phase = 3.0f;
    state.progress = 0.5f; // Sustain has no time progression
    break;
  }
  case EnvPhase::Release: {
    state.phase = 4.0f;
    float releaseTime = envParams_.release;
    state.progress =
        (releaseTime > 0.0f)
            ? std::min(1.0f, dominant->envelope.envTime / releaseTime)
            : 1.0f;
    break;
  }
  case EnvPhase::Off:
  default: {
    state.phase = 0.0f;
    state.progress = 0.0f;
    break;
  }
  }

  return state;
}

} // namespace space
