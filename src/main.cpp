#include "ui/window.h"
#include "render/renderer.h"
#include "core/particles.h"
#include "core/modes.h"
#include "audio/synth.h"
#include "audio/audio_engine.h"
#include "audio/fft.h"
#include "ui/mod_menu.h"

#include <chrono>
#include <cstdio>

using namespace space;

int main() {
    // ── Window ──────────────────────────────────────────────────────────
    Window window;
    if (!window.create(1920, 1080, "SPACE Synth")) {
        fprintf(stderr, "Failed to create window\n");
        return 1;
    }

    // ── Renderer ────────────────────────────────────────────────────────
    Renderer renderer;
    if (!renderer.init(window.metalLayer(), window.width(), window.height())) {
        fprintf(stderr, "Failed to init Metal renderer\n");
        return 1;
    }

    // ── Particles ───────────────────────────────────────────────────────
    ParticleSystem particles;
    particles.init(100000, 100.0f);

    auto gpuData = packForGPU(particles);
    renderer.uploadParticles(gpuData.data(), particles.count());

    // ── Synth ───────────────────────────────────────────────────────────
    Synth synth;

    // ── Audio engine (for mic input) ────────────────────────────────────
    AudioEngine audio;
    FFTAnalyzer fft(2048, 48000);

    // ── Keyboard mapping ────────────────────────────────────────────────
    // Matches SOUND ARCHITECT.html: A=C, W=C#, S=D, ... K=C5, etc.
    // macOS keyCodes → MIDI offsets
    struct KeyMapping { int keyCode; int semitone; };
    const KeyMapping keyMap[] = {
        {0, 0},    // A → C
        {13, 1},   // W → C#
        {1, 2},    // S → D
        {14, 3},   // E → D#
        {2, 4},    // D → E
        {3, 5},    // F → F
        {17, 6},   // T → F#
        {5, 7},    // G → G
        {16, 8},   // Y → G#
        {4, 9},    // H → A
        {32, 10},  // U → A#
        {38, 11},  // J → B
        {40, 12},  // K → C (octave up)
        {31, 13},  // O → C#
        {37, 14},  // L → D
        {35, 15},  // P → D#
        {41, 16},  // ; → E
    };
    const int numKeys = sizeof(keyMap) / sizeof(keyMap[0]);

    auto getMidi = [&](int keyCode) -> int {
        for (int i = 0; i < numKeys; i++) {
            if (keyMap[i].keyCode == keyCode) {
                return (3 + synth.octaveShift()) * 12 + 12 + keyMap[i].semitone;
            }
        }
        return -1;
    };

    // ── Key events ──────────────────────────────────────────────────────
    window.setKeyCallback([&](const KeyEvent& e) {
        if (e.isRepeat) return;

        // Z/X = octave shift
        if (e.keyCode == 6 && e.isDown) {  // Z
            synth.setOctaveShift(synth.octaveShift() - 1);
            return;
        }
        if (e.keyCode == 7 && e.isDown) {  // X
            synth.setOctaveShift(synth.octaveShift() + 1);
            return;
        }

        int midi = getMidi(e.keyCode);
        if (midi < 0 || midi > 127) return;

        if (e.isDown) synth.noteOn(midi);
        else synth.noteOff(midi);
    });

    // ── Resize ──────────────────────────────────────────────────────────
    window.setResizeCallback([&](int w, int h) {
        renderer.resize(w, h);
    });

    // ── Main loop ───────────────────────────────────────────────────────
    auto lastTime = std::chrono::high_resolution_clock::now();
    int frameCount = 0;
    float fpsTimer = 0.0f;
    int fps = 0;

    printf("SPACE Synth running. Keys: A-; for notes, Z/X octave shift.\n");

    // Run loop is inside window.run() — we need to restructure for
    // frame-by-frame control. For now, basic event pump:
    window.run();

    return 0;
}
