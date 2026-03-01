#include "../core/envelope.h"
#include "../core/modes.h"
#include "svf.h"
#include <cstdint>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

namespace space {

enum class Waveform { Sine, Triangle, Sawtooth, Square };

// A single synth voice: oscillator + envelope + mode mapping
struct Voice {
  int midiNote = 0;
  float frequency = 0.0f;
  Waveform waveform = Waveform::Sine;
  Envelope envelope;
  SVF filter;
  const Mode *mode = nullptr; // Points into ModeTable

  float phase = 0.0f; // Oscillator phase [0, 2π)

  // Initialize filter state
  void init(float sampleRate);

  // Generate one sample and advance phase
  float tick(float sampleRate);
};

// Polyphonic synthesizer
// Manages voices, MIDI input, keyboard input, waveform selection
class Synth {
public:
  Synth();

  void noteOn(int midi, float velocity = 1.0f);
  void noteOff(int midi);

  // Generate one sample across all voices
  float tick(float sampleRate);

  // Update all envelopes (call once per render frame)
  void updateEnvelopes(float dt);

  // Get total amplitude across all voices (for driving particles)
  float totalAmplitude() const;

  // Get active voice count
  int activeVoiceCount() const;

  // Access active voices (for particle physics — need mode + amplitude per
  // voice)
  struct ActiveVoice {
    float amplitude;
    float frequency;
    const Mode *mode;
  };
  std::vector<ActiveVoice> getActiveVoices() const;

  // Settings
  void setDrive(float d) { drive_ = std::max(1.0f, d); }
  float drive() const { return drive_; }

  void setWaveform(Waveform w) { waveform_ = w; }
  Waveform waveform() const { return waveform_; }
  void cycleWaveform();

  void setKeyboardMode(bool kb) { keyboardMode_ = kb; }
  bool keyboardMode() const { return keyboardMode_; }

  void setOctaveShift(int shift) {
    octaveShift_ = std::max(-2, std::min(4, shift));
  }
  int octaveShift() const { return octaveShift_; }

  EnvelopeParams &envelopeParams() { return envParams_; }
  const EnvelopeParams &envelopeParams() const { return envParams_; }

  ModeTable &modeTable() { return modeTable_; }

private:
  mutable std::mutex mutex_;
  std::unordered_map<int, Voice> voices_;
  ModeTable modeTable_;
  EnvelopeParams envParams_;
  Waveform waveform_ = Waveform::Sine;
  bool keyboardMode_ = false;
  int octaveShift_ = 0;
  float drive_ = 1.6f; // Default analog drive (Moog overdriven)

  static constexpr int BASE_OCTAVE = 3;
  int keyboardStart() const { return (BASE_OCTAVE + octaveShift_) * 12 + 12; }

  static float midiToFreq(int midi) {
    return 440.0f * std::pow(2.0f, (midi - 69) / 12.0f);
  }
};

} // namespace space
