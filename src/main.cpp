#include "audio/audio_engine.h"
#include "audio/synth.h"
#include "core/camera.h"
#include "core/modes.h"
#include "core/particles.h"
#include "render/renderer.h"
#include "ui/window.h"
#include <cstdio>

using namespace space;

int main() {
  // ── Window ──────────────────────────────────────────────────────────
  Window window;
  if (!window.create(1280, 800, "SPACE Synth")) {
    fprintf(stderr, "Failed to create window\n");
    return 1;
  }

  // ── Renderer ────────────────────────────────────────────────────────
  Renderer renderer;
  if (!renderer.init(window.metalDevice(), window.metalLayer(), window.width(),
                     window.height())) {
    fprintf(stderr, "Failed to init Metal renderer\n");
    return 1;
  }

  // ── Particles ───────────────────────────────────────────────────────
  const int PARTICLE_COUNT = 100000;
  const float MAX_WAVE_DEPTH = 100.0f;
  const float PLATE_RADIUS = 400.0f;

  ParticleSystem particles;
  particles.init(PARTICLE_COUNT, MAX_WAVE_DEPTH);

  auto gpuData = packForGPU(particles);
  renderer.uploadParticles(gpuData.data(), PARTICLE_COUNT);

  // ── Camera ──────────────────────────────────────────────────────────
  Camera camera;
  window.setMouseCallback([&](const MouseEvent &e) {
    if (e.isDown && e.button == 0) {
      // Rotate: scaling deltas for sensitivity
      camera.rotate(-e.dx * 0.005f, -e.dy * 0.005f);
    }
  });
  window.setScrollCallback([&](float dx, float dy) { camera.zoom(dy * 0.5f); });

  // ── Synth & Audio ──────────────────────────────────────────────────
  Synth synth;
  AudioEngine audio;
  audio.setSynth(&synth);
  audio.start(0, 48000);

  // ── Keyboard mapping ────────────────────────────────────────────────
  // macOS keyCodes → semitone offsets (matches SOUND ARCHITECT.html)
  struct KM {
    int keyCode;
    int semitone;
  };
  const KM keyMap[] = {
      {0, 0},   // A → C
      {13, 1},  // W → C#
      {1, 2},   // S → D
      {14, 3},  // E → D#
      {2, 4},   // D → E
      {3, 5},   // F → F
      {17, 6},  // T → F#
      {5, 7},   // G → G
      {16, 8},  // Y → G#
      {4, 9},   // H → A
      {32, 10}, // U → A#
      {38, 11}, // J → B
      {40, 12}, // K → C+
      {31, 13}, // O → C#+
      {37, 14}, // L → D+
      {35, 15}, // P → D#+
      {41, 16}, // ; → E+
  };
  const int numKeys = sizeof(keyMap) / sizeof(keyMap[0]);

  auto getMidi = [&](int keyCode) -> int {
    for (int i = 0; i < numKeys; i++) {
      if (keyMap[i].keyCode == keyCode)
        return (3 + synth.octaveShift()) * 12 + 12 + keyMap[i].semitone;
    }
    return -1;
  };

  // ── Key events ──────────────────────────────────────────────────────
  window.setKeyCallback([&](const KeyEvent &e) {
    if (e.isRepeat)
      return;

    // Z/X = octave shift
    if (e.keyCode == 6 && e.isDown) {
      synth.setOctaveShift(synth.octaveShift() - 1);
      return;
    }
    if (e.keyCode == 7 && e.isDown) {
      synth.setOctaveShift(synth.octaveShift() + 1);
      return;
    }

    // R = reset camera
    if (e.keyCode == 15 && e.isDown) {
      camera.reset();
      return;
    }

    int midi = getMidi(e.keyCode);
    if (midi < 0 || midi > 127)
      return;

    if (e.isDown) {
      synth.noteOn(midi);
      printf("[SYNTH] noteOn midi=%d voices=%d\n", midi,
             synth.activeVoiceCount());
    } else {
      synth.noteOff(midi);
    }
  });

  // ── Resize ──────────────────────────────────────────────────────────
  window.setResizeCallback([&](int w, int h) { renderer.resize(w, h); });

  // ── FPS counter ─────────────────────────────────────────────────────
  int frameCount = 0;
  float fpsTimer = 0.0f;
  int fps = 0;

  // ── Frame callback ──────────────────────────────────────────────────
  window.setFrameCallback([&](float dt) {
    // Update envelopes
    synth.updateEnvelopes(dt);

    // Build voice data for GPU
    auto activeVoices = synth.getActiveVoices();
    std::vector<VoiceGPUData> voiceData;
    for (const auto &v : activeVoices) {
      voiceData.push_back(
          {v.mode->m, v.mode->n, (float)v.mode->alpha, v.amplitude});
    }

    // GPU physics step
    renderer.computeStep(dt, voiceData.data(), (int)voiceData.size(),
                         synth.totalAmplitude(), MAX_WAVE_DEPTH);

    // Update camera
    camera.update(dt);
    float view[16], proj[16], viewProj[16];
    camera.buildViewMatrix(view);
    Renderer::perspectiveMatrix(proj, 45.0f * (M_PI_F / 180.0f),
                                (float)window.width() / window.height(), 1.0f,
                                5000.0f);

    // viewProj = proj * view
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        viewProj[j * 4 + i] = 0;
        for (int k = 0; k < 4; k++) {
          viewProj[j * 4 + i] += proj[k * 4 + i] * view[j * 4 + k];
        }
      }
    }

    // Render
    RenderConfig config;
    config.width = window.width();
    config.height = window.height();
    config.particleSize = 4.0f; // Boosted for visibility
    config.plateRadius = PLATE_RADIUS;
    renderer.render(config, viewProj);

    // FPS
    frameCount++;
    fpsTimer += dt;
    if (fpsTimer >= 1.0f) {
      fps = frameCount;
      frameCount = 0;
      fpsTimer -= 1.0f;

      int vc = synth.activeVoiceCount();
      if (vc > 0) {
        printf("\r%d fps | %dk particles | %d voice%s | amp %.2f    ", fps,
               PARTICLE_COUNT / 1000, vc, vc > 1 ? "s" : "",
               synth.totalAmplitude());
      } else {
        printf("\r%d fps | %dk particles | ready    ", fps,
               PARTICLE_COUNT / 1000);
      }
      fflush(stdout);
    }
  });

  printf("SPACE Synth — %dk particles\n", PARTICLE_COUNT / 1000);
  printf("Keys: A-; for notes, Z/X octave shift\n");

  window.run();

  printf("\n");
  return 0;
}
