#pragma once
#include "core/bessel.h"
#include "core/lut.h"
#include <array>
#include <vector>

namespace space {

// A single Chladni mode: Bessel order m, zero index n, and the alpha value
struct Mode {
    int m;          // angular order (0..6)
    int n;          // radial zero index (1..4)
    double alpha;   // Bessel zero value J_m(alpha) = 0
};

// 28 modes (7 orders × 4 zeros), sorted by alpha (= frequency complexity)
// Low alpha = simple patterns (few nodal lines)
// High alpha = complex patterns (many nodal lines)
constexpr int NUM_MODES = 28;

class ModeTable {
public:
    ModeTable();

    // Get mode by index (0..27), sorted by ascending alpha
    const Mode& operator[](int index) const { return ordered_[index]; }

    // Map a MIDI note (21-108) to a mode index using full 88-key range
    int midiToModeIndex(int midi) const;

    // Map a keyboard-relative note to a mode index
    // kbStart = starting MIDI note of current keyboard range
    int keyboardToModeIndex(int midi, int kbStart) const;

    // Get the mode for a MIDI note
    const Mode& modeForMidi(int midi, bool keyboardMode, int kbStart) const;

private:
    std::array<Mode, NUM_MODES> ordered_;
};

} // namespace space
