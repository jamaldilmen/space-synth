#include "../core/envelope.h"
#include "../core/modes.h"
#include "chorus.h"
#include "svf.h"
#include <cstdint>
#include <mutex>
#include <string>
#include <array>
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

  float phase = 0.0f;    // Oscillator phase [0, 2π)
  uint32_t rngState = 0; // Per-voice Xorshift state (Phase 12 stability)

  // Initialize filter state
  void init(float sampleRate);

  // Generate one sample and advance phase
  float tick(float sampleRate, float synthJitter);
};

// Polyphonic synthesizer
// Manages voices, MIDI input, keyboard input, waveform selection
class Synth {
public:
  Synth();

  void noteOn(int midi, float velocity = 1.0f, int sampleOffset = 0);
  void noteOff(int midi, int sampleOffset = 0);

  // Generate one sample across all voices (stereo)
  void tick(float sampleRate, float &outL, float &outR);

  // High-performance block processing (Phase 12 stability)
  void processBlock(float sampleRate, float *outL, float *outR, int numFrames);

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
    float phase;
    const Mode *mode;
  };
  std::vector<ActiveVoice> getActiveVoices() const;

  // Get dominant envelope state for black hole lifecycle (Phase 17)
  struct EnvelopeState {
    float phase;     // 0=silence, 1=attack, 2=decay, 3=sustain, 4=release
    float progress;  // 0.0 to 1.0 within current phase
    float intensity; // Combined amplitude measure
  };
  EnvelopeState getDominantEnvelope() const;

  // Settings
  void setDrive(float d) { drive_ = std::max(1.0f, d); }
  float drive() const { return drive_; }

  // setJitter/jitter() DELETED 2026-09-01 with the Jitter dial (his order)

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

  Chorus &chorus() { return chorus_; }
  const Chorus &chorus() const { return chorus_; }

  struct MidiCommand {
    enum Type { NoteOn, NoteOff } type;
    int midi;
    float velocity;
    int sampleOffset;
  };
  std::vector<MidiCommand> commandQueue_;
  std::vector<MidiCommand>
      swapBuffer_; // Pre-allocated swap buffer (avoids RT heap alloc)
  mutable std::mutex queueMutex_;

  void processCommands();
  void handleNoteOn(int midi, float velocity);
  void handleNoteOff(int midi);

  // Lock-free internal versions for sample-accurate block processing
  void handleNoteOnInternal(int midi, float velocity);
  void handleNoteOffInternal(int midi);

  static constexpr int MAX_VOICES = 64; // Polyphonic safety limit

  mutable std::mutex mutex_;

  // ── FIXED VOICE POOL (2026-08-23) ─────────────────────────────────────────
  // Was std::unordered_map<int, Voice>. Every mutation of that map ran on the
  // CoreAudio realtime thread: erase() -> free(), operator[] -> malloc + a
  // possible rehash, and the erase at the top of the per-sample loop meant a
  // free() could happen PER SAMPLE. A realtime thread must never touch the
  // allocator. Voice is plain data (no heap members), so a fixed pool costs
  // one 64-slot array and removes the allocator from the audio path entirely.
  // Lookup is a linear scan of 64 contiguous slots — cheaper in practice than
  // the map's hashing and pointer chasing, and branch-predictable.
  std::array<Voice, MAX_VOICES> voices_{};
  std::array<bool, MAX_VOICES> voiceOn_{}; // slot occupied
  int voiceCount_ = 0;                     // == count of true in voiceOn_

  // -1 if no live voice holds that note / no slot is free.
  int findVoiceSlot(int midi) const;
  int allocVoiceSlot() const;
  void releaseVoiceSlot(int slot);
  ModeTable modeTable_;
  EnvelopeParams envParams_;
  Chorus chorus_;
  Waveform waveform_ = Waveform::Sine;
  bool keyboardMode_ = false;
  int octaveShift_ = 0;
  float drive_ = 1.6f;  // Default analog drive (Moog overdriven)
  float jitter_ = 0.1f; // AUDIO pitch-drift RESTORED 2026-09-01, his reversal:
                        // "leave jitter in then for audio." Fixed default, no
                        // dial: 0.1 is what the deleted feed delivered at boot
                        // (app_state uiJitter default 0.1 × multiplier 1.0) —
                        // the sound every launch had. VISUAL jitter stays dead.

  static constexpr int BASE_OCTAVE = 3;
  int keyboardStart() const { return (BASE_OCTAVE + octaveShift_) * 12 + 12; }

  static float midiToFreq(int midi) {
    return 440.0f * std::pow(2.0f, (midi - 69) / 12.0f);
  }

  void setMasterVolume(float v) {
    masterVolume_ = std::max(0.0f, std::min(1.0f, v));
  }
  float masterVolume() const { return masterVolume_; }

private:
  float masterVolume_ = 1.0f;
};

} // namespace space
