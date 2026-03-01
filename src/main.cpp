#include "audio/audio_engine.h"
#include "audio/synth.h"
#include "core/camera.h"
#include "core/modes.h"
#include "core/particles.h"
#include "core/preset_manager.h"
#include "imgui.h"
#include "render/renderer.h"
#include "ui/ui_theme.h"
#include "ui/window.h"
#include <cstdio>
#include <fcntl.h>
#include <signal.h>
#include <string>
#include <unistd.h>

using namespace space;

static void ensureSingleInstance() {
  const char *pidFilePath = "/tmp/SpaceSynth.pid";
  int fd = open(pidFilePath, O_RDWR | O_CREAT, 0666);
  if (fd == -1)
    return;

  char buf[32];
  ssize_t bytes = read(fd, buf, sizeof(buf) - 1);
  if (bytes > 0) {
    buf[bytes] = '\0';
    pid_t oldPid = (pid_t)std::atoi(buf);
    if (oldPid > 0 && oldPid != getpid()) {
      // Check if process exists and is not us
      if (kill(oldPid, 0) == 0) {
        // Kill the old process
        kill(oldPid, SIGTERM);
        // Give it a moment to exit
        for (int i = 0; i < 5; i++) {
          usleep(50000);
          if (kill(oldPid, 0) != 0)
            break;
          if (i == 4)
            kill(oldPid, SIGKILL);
        }
      }
    }
  }

  // Write current PID
  if (ftruncate(fd, 0) == 0) {
    lseek(fd, 0, SEEK_SET);
    std::string pidStr = std::to_string(getpid());
    write(fd, pidStr.c_str(), pidStr.length());
  }
  close(fd);
}

int main() {
  ensureSingleInstance();
  // ── Window ──────────────────────────────────────────────────────────
  Window window;
  if (!window.create(1280, 720, "SPACE Synth")) {
    fprintf(stderr, "Failed to create window\n");
    return 1;
  }

  space::UITheme::ApplyPremiumTheme();

  // ── Renderer ────────────────────────────────────────────────────────
  Renderer renderer;
  if (!renderer.init(window.metalDevice(), window.metalLayer(), window.width(),
                     window.height())) {
    fprintf(stderr, "Failed to init Metal renderer\n");
    return 1;
  }

  // ── Particles ───────────────────────────────────────────────────────
  const int PARTICLE_COUNT = 800000;
  const float MAX_WAVE_DEPTH = 100.0f;
  const float PLATE_RADIUS = 400.0f;

  ParticleSystem particles;
  particles.init(PARTICLE_COUNT, MAX_WAVE_DEPTH);

  auto gpuData = packForGPU(particles);
  renderer.uploadParticles(gpuData.data(), PARTICLE_COUNT);

  // ── Camera ──────────────────────────────────────────────────────────
  Camera camera;
  window.setMouseCallback([&](const MouseEvent &e) {
    if (ImGui::GetCurrentContext() && ImGui::GetIO().WantCaptureMouse)
      return;
    if (e.isDown && e.button == 0) {
      // Rotate: scaling deltas for sensitivity
      camera.rotate(-e.dx * 0.005f, -e.dy * 0.005f);
    }
  });
  window.setScrollCallback([&](float dx, float dy) {
    // Ultra-smooth logarithmic zoom
    camera.zoom(dy * std::max(0.001f, camera.getRho() * 0.015f));
  });

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

  // ── HUD State ──────────────────────────────────────────────────────
  static bool showHUD = true;
  static float uiParticleSize = 4.0f;
  static int uiParticleCount = 800000;
  static float uiJitter = 1.0f;
  static float uiDamping = 0.95f;
  static float uiRetraction = 1.0f;
  static float uiWaveDepth = 140.0f; // matches plate scale correctly

  static float uiSpeedCap = 1.2f;
  static float uiModeP = 1.0f;
  static int uiSimMode = 0;         // 0=Classic, 1=Vortex
  static int uiSphereMode = 1;      // 1=Sphere, 0=Flat
  static bool uiOrthoMode = true;   // Use Orthographic projection
  static float uiAttack = 20.0f;    // ms
  static float uiRelease = 400.0f;  // ms
  static bool uiCollisions = false; // Particle-particle collisions
  static bool uiPhaseViz = false;   // Feynman phase arrow coloring

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

    // TAB = toggle HUD
    if (e.keyCode == 48 && e.isDown) {
      showHUD = !showHUD;
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
    static int debugFrameCount = 0;
    debugFrameCount++;
    if (debugFrameCount == 1 || debugFrameCount % 60 == 0) {
      printf("[FRAME] #%d dt=%.4f\n", debugFrameCount, dt);
      fflush(stdout);
    }
    // Update envelopes
    synth.updateEnvelopes(dt);

    // Build voice data for GPU
    auto activeVoices = synth.getActiveVoices();
    std::vector<VoiceGPUData> voiceData;
    for (const auto &v : activeVoices) {
      voiceData.push_back(
          {v.mode->m, v.mode->n, (float)v.mode->alpha, v.amplitude});
    }

    camera.update(dt);
    float view[16], proj[16], viewProj[16];
    camera.buildViewMatrix(view);

    if (uiOrthoMode) {
      float aspect = (float)window.width() / (float)window.height();
      float frustum = camera.getRho() * 1.2f; // Dynamic orthographic zoom
      Renderer::orthoMatrix(proj, -frustum * aspect, frustum * aspect, -frustum,
                            frustum, -5000.0f, 5000.0f);
    } else {
      Renderer::perspectiveMatrix(proj, 45.0f * (M_PI_F / 180.0f),
                                  (float)window.width() / window.height(),
                                  0.001f, 5000.0f);
    }

    // viewProj = proj * view
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        viewProj[j * 4 + i] = 0;
        for (int k = 0; k < 4; k++) {
          viewProj[j * 4 + i] += proj[k * 4 + i] * view[j * 4 + k];
        }
      }
    }

    // Render configuration
    static RenderConfig config;
    config.width = window.width();
    config.height = window.height();

    // ── ImGui HUD ──────────────────────────────────────────────────
    static Preset currentPreset;
    static bool presetsLoaded = false;
    static std::vector<std::string> presetFiles;
    static int selectedPresetIdx = -1;

    if (!presetsLoaded) {
      presetFiles = PresetManager::scanPresets("../presets");
      // Try to load default.json
      for (int i = 0; i < (int)presetFiles.size(); i++) {
        if (presetFiles[i] == "default.json") {
          selectedPresetIdx = i;
          if (PresetManager::loadPreset("../presets/" + presetFiles[i],
                                        currentPreset)) {
            uiParticleSize = currentPreset.particleSize;
            uiJitter = currentPreset.jitterScale;
            uiDamping = currentPreset.damping;
            uiSpeedCap = currentPreset.speedCap;
          }
          break;
        }
      }
      presetsLoaded = true;
    }

    // ── Floating Toggle Button ──────────────────────────────────────
    ImGui::SetNextWindowPos(ImVec2(window.width() - 50, 20));
    ImGui::Begin("##toggle", nullptr,
                 ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoBackground |
                     ImGuiWindowFlags_AlwaysAutoResize);
    if (ImGui::Button(showHUD ? "X" : "::", ImVec2(30, 30))) {
      showHUD = !showHUD;
    }
    if (ImGui::IsItemHovered())
      ImGui::SetTooltip("Toggle HUD (TAB)");
    ImGui::End();

    if (showHUD) {
      ImGui::SetNextWindowPos(ImVec2(30, 30), ImGuiCond_FirstUseEver);
      ImGui::SetNextWindowSize(ImVec2(340, 0), ImGuiCond_FirstUseEver);

      // Custom header drawing inside the window
      ImGui::Begin("PHYSICS ARCHITECT", nullptr,
                   ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar);

      ImGui::TextColored(ImVec4(0.5f, 0.6f, 1.0f, 1.0f),
                         "S P A C E   S Y N T H");
      ImGui::Separator();
      ImGui::Spacing();

      if (ImGui::CollapsingHeader("PRESETS", ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Indent();
        const char *comboLabel = (selectedPresetIdx < 0)
                                     ? "Select..."
                                     : presetFiles[selectedPresetIdx].c_str();
        if (ImGui::BeginCombo("##preset", comboLabel)) {
          for (int n = 0; n < (int)presetFiles.size(); n++) {
            const bool is_selected = (selectedPresetIdx == n);
            if (ImGui::Selectable(presetFiles[n].c_str(), is_selected)) {
              selectedPresetIdx = n;
              if (PresetManager::loadPreset("../presets/" + presetFiles[n],
                                            currentPreset)) {
                uiParticleSize = currentPreset.particleSize;
                uiJitter = currentPreset.jitterScale;
                uiDamping = currentPreset.damping;
                uiSpeedCap = currentPreset.speedCap;
              }
            }
            if (is_selected)
              ImGui::SetItemDefaultFocus();
          }
          ImGui::EndCombo();
        }
        ImGui::SameLine();
        if (ImGui::Button("Save") && selectedPresetIdx >= 0) {
          currentPreset.particleSize = uiParticleSize;
          currentPreset.jitterScale = uiJitter;
          currentPreset.damping = uiDamping;
          currentPreset.speedCap = uiSpeedCap;
          PresetManager::savePreset(
              "../presets/" + presetFiles[selectedPresetIdx], currentPreset);
        }
        ImGui::Unindent();
      }

      if (ImGui::CollapsingHeader("SIMULATION",
                                  ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Indent();

        ImGui::Text("Sim Mode:");
        ImGui::SameLine();
        ImGui::RadioButton("Classic", &uiSimMode, 0);
        ImGui::SameLine();
        ImGui::RadioButton("Vortex", &uiSimMode, 1);
        if (ImGui::IsItemHovered())
          ImGui::SetTooltip(
              "Vortex Mode: Biblically Accurate Maxwellian Medium");

        bool sphereOn = (uiSphereMode == 1);
        if (ImGui::Checkbox("Sphere Mode", &sphereOn)) {
          uiSphereMode = sphereOn ? 1 : 0;
        }
        ImGui::SetItemTooltip("Project particles onto a 3D spherical shell");

        if (ImGui::Checkbox("Collisions", &uiCollisions)) {
          renderer.setCollisionsEnabled(uiCollisions);
        }
        ImGui::SetItemTooltip("Enable particle-particle elastic collisions");

        ImGui::Checkbox("Phase Viz", &uiPhaseViz);
        ImGui::SetItemTooltip(
            "Color particles by Feynman phase (action integral)");

        ImGui::Checkbox("Ortho Camera", &uiOrthoMode);
        ImGui::SetItemTooltip(
            "Toggle between Orthographic (HTML vibe) and Perspective");

        ImGui::SliderFloat("Size", &uiParticleSize, 0.5f, 10.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiParticleSize = 4.0f;
        ImGui::SetItemTooltip("Physical radius of each particle");

        ImGui::SliderInt("Amount", &uiParticleCount, 10000, 800000);
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiParticleCount = 800000;
        ImGui::SetItemTooltip("Active number of particles");

        ImGui::SliderFloat("Limit", &uiSpeedCap, 0.1f, 5.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiSpeedCap = 1.2f;
        ImGui::SetItemTooltip("Maximum particle velocity cap");

        ImGui::SliderFloat("ModeP", &uiModeP, 1.0f, 4.0f, "%.0f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiModeP = 1.0f;
        ImGui::SetItemTooltip("Depth Mode multiplier (Wave complexity)");

        ImGui::Unindent();
      }

      if (ImGui::CollapsingHeader("AUDIO SYNTH",
                                  ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Indent();
        const char *waveforms[] = {"Sine", "Triangle", "Sawtooth", "Square"};
        int currentWave = (int)synth.waveform();
        if (ImGui::Combo("Wave", &currentWave, waveforms,
                         IM_ARRAYSIZE(waveforms))) {
          synth.setWaveform((Waveform)currentWave);
        }
        ImGui::SetItemTooltip("Oscillator waveform type");

        ImGui::Unindent();
      }

      ImGui::SliderFloat("Attack", &uiAttack, 5.0f, 500.0f, "%.0f ms");
      if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
        uiAttack = 20.0f;
      ImGui::SetItemTooltip("Envelope attack duration");

      if (ImGui::SliderFloat("Release", &uiRelease, 50.0f, 2000.0f,
                             "%.0f ms")) {
        // Handled in main loop
      }
      if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
        uiRelease = 400.0f;
      ImGui::SetItemTooltip("Envelope release duration");

      bool kbMode = synth.keyboardMode();
      if (ImGui::Checkbox("Keyboard Mode", &kbMode)) {
        synth.setKeyboardMode(kbMode);
      }
      ImGui::SetItemTooltip("Toggle between Piano layout (Keyboard) and "
                            "linear mapping (Full Range)");

      ImGui::Unindent();
    }

    if (ImGui::CollapsingHeader("DYNAMICS", ImGuiTreeNodeFlags_DefaultOpen)) {
      ImGui::Indent();
      ImGui::SliderFloat("Jitter", &uiJitter, 0.0f, 5.0f, "%.2f");
      if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
        uiJitter = 1.0f;
      ImGui::SetItemTooltip("Random displacement factor");

      ImGui::SliderFloat("Fluid", &uiDamping, 0.8f, 1.0f, "%.3f");
      if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
        uiDamping = 0.95f;
      ImGui::SetItemTooltip("Simulation damping (Air resistance)");
      ImGui::Unindent();
    }

    if (ImGui::CollapsingHeader("GEOMETRY", ImGuiTreeNodeFlags_DefaultOpen)) {
      ImGui::Indent();
      ImGui::SliderFloat("Scale", &config.plateRadius, 100.0f, 1000.0f, "%.0f");
      if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
        config.plateRadius = 400.0f;
      ImGui::SetItemTooltip("Radius of the vibrating plate");

      ImGui::SliderFloat("Retract", &uiRetraction, 0.0f, 5.0f, "%.2f");
      if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
        uiRetraction = 1.0f;
      ImGui::SetItemTooltip("Magnetic pull towards center");

      ImGui::SliderFloat("Plate Depth", &uiWaveDepth, 5.0f, 100.0f, "%.1f");
      if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
        uiWaveDepth = 20.0f;
      ImGui::SetItemTooltip(
          "Maximum displacement depth of the vibrating plate");

      if (ImGui::Button("Reset Camera")) {
        camera.reset();
      }
      ImGui::SetItemTooltip("Restore camera to default position");

      ImGui::Unindent();
    }

    if (ImGui::CollapsingHeader("POST-FX", ImGuiTreeNodeFlags_DefaultOpen)) {
      ImGui::Indent();
      ImGui::SliderFloat("Bloom", &config.bloomIntensity, 0.0f, 1.0f, "%.2f");
      if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
        config.bloomIntensity = 0.0f;
      ImGui::SetItemTooltip("Cross-shaped bright-pass glow");

      ImGui::SliderFloat("Fluidity", &config.trailDecay, 0.0f, 0.99f, "%.2f");
      if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
        config.trailDecay = 0.0f;
      ImGui::SetItemTooltip("Motion trails (Feedback factor)");

      ImGui::SliderFloat("Chromatic", &config.chromaticAmount, 0.0f, 0.02f,
                         "%.3f");
      if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
        config.chromaticAmount = 0.0f;
      ImGui::SetItemTooltip("RGB split lens effect");
      ImGui::Unindent();
    }

    if (ImGui::CollapsingHeader("PHYSICS STATS")) {
      ImGui::Indent();
      auto stats = renderer.getPhysicsStats();
      ImGui::Text("Kinetic Energy: %.4f", stats.kineticEnergy);
      ImGui::Text("Momentum: (%.4f, %.4f)", stats.momentumX, stats.momentumY);
      float momentumMag = sqrtf(stats.momentumX * stats.momentumX +
                                stats.momentumY * stats.momentumY);
      ImGui::Text("  |p| = %.6f", momentumMag);
      ImGui::Unindent();
    }

    ImGui::Spacing();
    ImGui::Separator();
    ImGui::TextDisabled(
        "FPS: %.1f | Particles: %dk%s", ImGui::GetIO().Framerate,
        renderer.particleCount() / 1000, uiCollisions ? " | COLL" : "");
    // ── Generate GPU Debug Window ────────────────────
    if (ImGui::CollapsingHeader("DEBUG GPU STATE",
                                ImGuiTreeNodeFlags_DefaultOpen)) {
      ImGui::Indent();
      ImGui::Text("dt: %f | Particles: %d", dt, uiParticleCount);
      ImGui::Text("Total Amplitude: %.3f", synth.totalAmplitude());

      if (ImGui::Button("Fetch GPU Particle Memory (first 4)")) {
        std::vector<GPUParticle> debugParts(4);
        renderer.readbackParticles(debugParts.data(), 4);

        for (int i = 0; i < 4; i++) {
          ImGui::Text("P[%d]: pos[%5.2f, %5.2f, %5.2f]", i, debugParts[i].x,
                      debugParts[i].y, debugParts[i].z);
          ImGui::Text("       vel[%5.2f, %5.2f, %5.2f] phase: %.2f",
                      debugParts[i].vx, debugParts[i].vy, debugParts[i].vz,
                      debugParts[i].phase);
        }
      }
      ImGui::Unindent();
    }
    ImGui::End();

    config.particleSize = uiParticleSize;
    config.cameraRho = camera.getRho();
    config.orthoMode = uiOrthoMode;
    config.phaseViz = uiPhaseViz;

    // ── Update ADSR ────────────────────────────────────────────────
    synth.envelopeParams().attack = uiAttack / 1000.0f;
    synth.envelopeParams().release = uiRelease / 1000.0f;

    // ── Update Physics ──────────────────────────────────────────────
    renderer.setActiveParticleCount(uiParticleCount);

    renderer.computeStep(dt, voiceData.data(), (int)voiceData.size(),
                         synth.totalAmplitude(), uiWaveDepth, uiJitter,
                         uiRetraction, uiDamping, uiSpeedCap, uiModeP,
                         uiSimMode, uiSphereMode);

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

      // ── Auto GPU Readback Probe ──
      GPUParticle probe[2];
      renderer.readbackParticles(probe, 2);
      printf("\n  [GPU] dt=%.4f voices=%d amp=%.3f", dt, vc,
             synth.totalAmplitude());
      printf("\n  [P0] pos(%.4f, %.4f, %.4f) vel(%.6f, %.6f, %.6f)", probe[0].x,
             probe[0].y, probe[0].z, probe[0].vx, probe[0].vy, probe[0].vz);
      printf("\n  [P1] pos(%.4f, %.4f, %.4f) vel(%.6f, %.6f, %.6f)\n",
             probe[1].x, probe[1].y, probe[1].z, probe[1].vx, probe[1].vy,
             probe[1].vz);

      fflush(stdout);
    }
  });

  printf("SPACE Synth — %dk particles\n", PARTICLE_COUNT / 1000);
  printf("Keys: A-; for notes, Z/X octave shift\n");

  window.run();

  printf("\n");
  return 0;
}
