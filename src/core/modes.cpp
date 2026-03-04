#include "core/modes.h"
#include <algorithm>
#include <cmath>

namespace space {

ModeTable::ModeTable() {
  for (int midi = 0; midi < 128; midi++) {
    // Musical Pitch Class (0 = C, 1 = C#, ..., 11 = B)
    int pitchClass = midi % 12;

    // Octave. MIDI note 24 (C1) is octave 1.
    int octave = (midi / 12) - 1;

    // The Atom Model:
    // Azimuthal lobes (m) = Pitch Class. (C = 0 lobes = symmetrical tube)
    int m = pitchClass;

    // Polar rings (n) = Octave. (Higher octaves add radial complexity)
    int n = std::max(1, octave);

    // Alpha (frequency coefficient) is mostly vestigial in Phase 9, but map it
    // to Hz for safety.
    double alpha = 440.0 * std::pow(2.0, (midi - 69) / 12.0);

    ordered_[midi] = Mode{m, n, alpha};
  }
}

int ModeTable::midiToModeIndex(int midi) const {
  return std::clamp(midi, 0, 127);
}

int ModeTable::keyboardToModeIndex(int midi, int kbStart) const {
  // Determine the relative note within the current keyboard block
  int relativeNote = std::clamp(midi - kbStart, 0, 15);

  // Map the 16 drum pads / white keys directly to a diatonic scale or
  // continuous run For simplicity, we just map it back to an absolute MIDI note
  // in the C3 range
  int absoluteMidi = 48 + relativeNote; // C3 (48) upwards
  return std::clamp(absoluteMidi, 0, 127);
}

const Mode &ModeTable::modeForMidi(int midi, bool keyboardMode,
                                   int kbStart) const {
  int idx =
      keyboardMode ? keyboardToModeIndex(midi, kbStart) : midiToModeIndex(midi);
  return ordered_[idx];
}

} // namespace space
