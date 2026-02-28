#include "core/modes.h"
#include <algorithm>
#include <cmath>

namespace space {

ModeTable::ModeTable() {
    int idx = 0;
    for (int m = 0; m < MAX_ORDER; m++) {
        for (int n = 0; n < MAX_ZEROS; n++) {
            ordered_[idx++] = Mode{m, n + 1, ZEROS[m][n]};
        }
    }

    // Sort by alpha (ascending) — simple patterns first, complex last
    std::sort(ordered_.begin(), ordered_.end(),
        [](const Mode& a, const Mode& b) { return a.alpha < b.alpha; });
}

int ModeTable::midiToModeIndex(int midi) const {
    int note = std::clamp(midi, 21, 108);
    float normalized = static_cast<float>(note - 21) / 87.0f;
    return std::clamp(static_cast<int>(normalized * 27.99f), 0, NUM_MODES - 1);
}

int ModeTable::keyboardToModeIndex(int midi, int kbStart) const {
    float normalized = std::clamp(
        static_cast<float>(midi - kbStart) / 16.0f, 0.0f, 1.0f);
    return std::clamp(static_cast<int>(normalized * 27.99f), 0, NUM_MODES - 1);
}

const Mode& ModeTable::modeForMidi(int midi, bool keyboardMode, int kbStart) const {
    int idx = keyboardMode ? keyboardToModeIndex(midi, kbStart) : midiToModeIndex(midi);
    return ordered_[idx];
}

} // namespace space
