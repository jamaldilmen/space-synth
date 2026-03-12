#include "audio/audio_engine.h"
#include "audio/synth.h"
#include "core/camera.h"
#include "core/emitter.h"
#include "core/midi_input.h"
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

  // ImGui global configuration
  ImGuiIO &io = ImGui::GetIO();
  io.ConfigDragClickToInputText =
      true; // Enable double-click to type on all sliders

  // ── Particles ───────────────────────────────────────────────────────
  const int PARTICLE_COUNT = 10000000;
  const float MAX_WAVE_DEPTH = 100.0f;
  // (PLATE_RADIUS removed)

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
  if (!audio.start(0, 48000)) {
    fprintf(stderr, "[FATAL ERROR] Audio Engine failed to start! Check your "
                    "hardware permissions.\n");
  } else {
    printf("[AUDIO] Engine started successfully.\n");
  }

  // ── MIDI Input ──────────────────────────────────────────────────────
  MidiInput midiInput;
  midiInput.start([&](int note, float velocity, bool isNoteOn) {
    if (isNoteOn) {
      synth.noteOn(note, velocity);
      printf("[MIDI] noteOn  note=%d vel=%.2f voices=%d\n", note, velocity,
             synth.activeVoiceCount());
    } else {
      synth.noteOff(note);
      printf("[MIDI] noteOff note=%d\n", note);
    }
  });

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

  // ── Emitters ────────────────────────────────────────────────────────
  EmitterArray emitters;

  // ── HUD State ──────────────────────────────────────────────────────
  static bool showHUD = true;
  static float uiParticleSize = 4.0f;
  static int uiParticleCount = 5000000;
  static float uiJitter = 0.1f;
  static float uiScale = 100.0f; // NEW DEFAULT: 100.0f as requested
  static float uiSupernova = 0.0f;
  static float uiWaveDepth = 20.0f;
  static float uiEField = 0.5f;
  static float uiBField = 1.0f;
  static float uiGravity = 0.8f;
  static float uiStringStiffness = 50.0f;
  static float uiRestLength = 0.05f;
  static float uiRotationX = 0.0f;
  static float uiRotationY = 0.0f;
  static float uiRotationZ = 0.0f;
  static bool uiAutoRotateScene = false;

  // Global Modulation LFO
  static float uiLFORate = 0.5f;
  static float uiLFODepth = 0.0f;
  static float uiLFOPhase = 0.0f;

  // uiSpeedCap removed: driven by synth.drive() instead
  static bool uiChorus = true;
  static bool uiOrthoMode = true;  // Use Orthographic projection
  static float uiAttack = 20.0f;   // ms
  static float uiRelease = 400.0f; // ms
  static bool uiCollisions =
      true; // Particle-particle collisions (MUST be on for Phase 5)
  static bool uiPhaseViz = false; // Feynman phase arrow coloring
  static float uiBloom = 0.0f;
  static float uiTrailDecay = 0.0f;
  static float uiChromatic = 0.0f;

  // ── Phase 18: Black Hole Aesthetics ──────────────────────────────
  static float uiBlackHoleRotationX = 0.0f;
  static bool uiAutoRotateBlackHole = true;

  // ── Phase 18: VJ Mode ────────────────────────────────────────────
  static bool uiVJMode = false;

  // ── Sequencer State (Phase 12) ───────────────────────────────────
  struct SeqNote {
    int midi;
    float startTime;
    float duration;
  };
  static bool seqRunning = false;
  static float seqTime = 0.0f;
  static std::vector<SeqNote> seqNotes;
  static std::vector<bool> seqNoteOn;
  static std::vector<bool> seqNoteDone;
  static float seqLogTimer = 0.0f;

  auto firePreset = [&](const char *name, std::vector<SeqNote> notes) {
    seqNotes = notes;
    seqNoteOn.assign(notes.size(), false);
    seqNoteDone.assign(notes.size(), false);
    seqTime = 0.0f;
    seqLogTimer = 0.0f;
    seqRunning = true;
    printf("[SEQ] Start: %s (%d notes)\n", name, (int)notes.size());
  };

  // Industry-Level Debugging (Phase 7)
  static bool uiFixedTimestep = false;
  static bool uiSoloEField = true;
  static bool uiSoloBField = true;
  static bool uiSoloGravity = true;
  static bool uiSoloStrings = true;
  static bool uiSoloJitter = true;
  static bool uiSoloCollisions = true;
  static bool uiAutoMode = true;         // Auto-Self-Healing (Phase 8)
  static bool uiQuantumEntangle = false; // Masterplan ODS-01 (Telepathy)
  static bool uiBlackHoles = false;      // Masterplan ODS-06 (Singularities)

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

  // ImGui global configuration
  ImGui::GetIO().ConfigDragClickToInputText =
      true; // Enable double-click to type on all sliders

  // ── Frame callback ──────────────────────────────────────────────────
  window.setFrameCallback([&](float dt) {
    // ── Run sequencer logic (Phase 12 stability) ───────────────────
    if (seqRunning) {
      seqTime += dt;
      float maxEndTime = 0.0f;
      for (size_t i = 0; i < seqNotes.size(); i++) {
        auto &n = seqNotes[i];
        float endTime = n.startTime + n.duration;
        maxEndTime = std::max(maxEndTime, endTime);

        if (!seqNoteOn[i] && !seqNoteDone[i] && seqTime >= n.startTime) {
          synth.noteOn(n.midi);
          seqNoteOn[i] = true;
          printf("[SEQ] noteOn midi=%d t=%.2f\n", n.midi, seqTime);
        }
        if (seqNoteOn[i] && seqTime >= endTime) {
          synth.noteOff(n.midi);
          seqNoteOn[i] = false;
          seqNoteDone[i] = true;
          printf("[SEQ] noteOff midi=%d t=%.2f\n", n.midi, seqTime);
        }
      }

      // Log stats every 0.5s
      seqLogTimer += dt;
      if (seqLogTimer >= 0.5f) {
        auto stats = renderer.getPhysicsStats();
        (void)stats; // Suppress unused warning
        printf("[SEQ-DATA] t=%.1f voices=%d amp=%.2f\n", seqTime,
               synth.activeVoiceCount(), synth.totalAmplitude());
        seqLogTimer = 0;
      }

      if (seqTime > maxEndTime + 2.0f) {
        seqRunning = false;
        printf("[SEQ] Finished\n");
      }
    }

    // Build voice data for GPU (with emitter positions)
    auto activeVoices = synth.getActiveVoices();
    std::vector<VoiceGPUData> voiceData;
    static std::unordered_map<int, float> lastAmps;

    // ── VJ Audio Band Injection ──
    if (uiVJMode) {
      auto bands = audio.getVJBands();
      for (size_t i = 0; i < bands.size() && voiceData.size() < MAX_EMITTERS;
           i++) {
        if (bands[i].amplitude > 0.005f) {
          int emIdx = voiceData.size() % MAX_EMITTERS;

          float dAmp =
              std::max(0.0f, bands[i].amplitude - lastAmps[-(int)i - 1]);
          lastAmps[-(int)i - 1] = bands[i].amplitude;

          VoiceGPUData vd;
          // Assign unique harmonic modes (M,N) based on frequency band index
          vd.m = (int)(i % 5) + 1;
          vd.n = (int)(i / 5) + 1;
          vd.alpha = 1.0f + (float)i * 0.15f;
          vd.amplitude = bands[i].amplitude;
          vd.emitterX = emitters[emIdx].x;
          vd.emitterY = emitters[emIdx].y;
          vd.emitterZ = emitters[emIdx].z;
          vd.frequency = bands[i].frequency;
          vd.deltaAmp = dAmp;
          vd.phase =
              std::fmod((float)ImGui::GetTime() * bands[i].frequency * 0.05f,
                        M_PI_F * 2.0f);

          voiceData.push_back(vd);
        } else {
          lastAmps[-(int)i - 1] = 0.0f;
        }
      }
    }

    for (int i = 0;
         i < (int)activeVoices.size() && voiceData.size() < MAX_EMITTERS; i++) {
      const auto &v = activeVoices[i];
      int emIdx = voiceData.size() % MAX_EMITTERS;

      // Compute transient delta (Phase 12 shockwaves)
      float lastA = lastAmps.count(v.mode->m + v.mode->n * 100)
                        ? lastAmps[v.mode->m + v.mode->n * 100]
                        : 0.0f;
      float dAmp = std::max(0.0f, v.amplitude - lastA);
      lastAmps[v.mode->m + v.mode->n * 100] = v.amplitude;

      VoiceGPUData vd;
      vd.m = v.mode->m;
      vd.n = v.mode->n;
      vd.alpha = (float)v.mode->alpha;
      vd.amplitude = v.amplitude;
      vd.emitterX = emitters[emIdx].x;
      vd.emitterY = emitters[emIdx].y;
      vd.emitterZ = emitters[emIdx].z;
      vd.frequency = v.frequency;
      vd.deltaAmp = dAmp;
      vd.phase = v.phase;

      voiceData.push_back(vd);
    }
    // Cleanup old voices from lastAmps if they aren't active
    if (activeVoices.empty())
      lastAmps.clear();

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
    config.rotationX =
        uiRotationX + uiBlackHoleRotationX +
        (uiAutoRotateBlackHole ? (float)ImGui::GetTime() * 0.2f : 0.0f) +
        (uiAutoRotateScene ? (float)ImGui::GetTime() * 0.15f : 0.0f);
    config.rotationY = uiRotationY;
    config.rotationZ = uiRotationZ;

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
            synth.setDrive(currentPreset.speedCap);
          }
          break;
        }
      }
      presetsLoaded = true;
    }

    // ── Top Right Control Window ──────────────────────────────────────
    ImGui::SetNextWindowPos(ImVec2(window.width() - 250, 20));
    ImGui::SetNextWindowSize(ImVec2(230, 0));
    ImGui::Begin("##topright", nullptr,
                 ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoBackground);

    ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1, 1, 1, 0.6f));
    ImGui::Text("MASTER VOLUME");
    ImGui::PopStyleColor();

    float currentVol = synth.masterVolume();
    if (ImGui::SliderFloat("##MasterVol", &currentVol, 0.0f, 1.0f, "%.2f")) {
      synth.setMasterVolume(currentVol);
    }

    ImGui::Spacing();

    if (ImGui::Button(showHUD ? "HIDE ARCHITECT" : "SHOW ARCHITECT",
                      ImVec2(215, 30))) {
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

      if (ImGui::CollapsingHeader("MACROS", ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Indent();
        ImGui::PushStyleColor(ImGuiCol_SliderGrab,
                              ImVec4(1.0f, 0.3f, 0.0f, 1.0f));
        ImGui::SliderFloat("Supernova", &uiSupernova, 0.0f, 1.0f, "%.2f");
        ImGui::PopStyleColor();
        ImGui::SetItemTooltip("Global A/V Macro: Overdrives Chorus, Jitter, "
                              "Drive, Bloom, and Particle Size simultaneously");
        ImGui::Unindent();
      }

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
                synth.setDrive(currentPreset.speedCap);
                uiEField = currentPreset.eField;
                uiBField = currentPreset.bField;
                uiGravity = currentPreset.gravity;
                uiStringStiffness = currentPreset.stringStiffness;
                uiRestLength = currentPreset.restLength;
                uiParticleCount = currentPreset.particleCount;
                uiSupernova = currentPreset.supernova;
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
          currentPreset.speedCap = synth.drive();
          currentPreset.eField = uiEField;
          currentPreset.bField = uiBField;
          currentPreset.gravity = uiGravity;
          currentPreset.stringStiffness = uiStringStiffness;
          currentPreset.restLength = uiRestLength;
          currentPreset.particleCount = uiParticleCount;
          currentPreset.supernova = uiSupernova;
          PresetManager::savePreset(
              "../presets/" + presetFiles[selectedPresetIdx], currentPreset);
        }
        ImGui::Unindent();
      }

      if (ImGui::CollapsingHeader("SIMULATION",
                                  ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Indent();

        // Removed SimMode and SphereMode

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

        ImGui::SliderInt("Amount", &uiParticleCount, 0, 10000000);
        if (ImGui::Button("Reset to Default")) {
          uiParticleCount = 5000000;
        }
        ImGui::SetItemTooltip("Active number of particles");

        // Limit / SpeedCap moved to Audio Synth (Analog Drive)

        ImGui::SliderFloat("E-Field Core", &uiEField, 0.0f, 0.5f, "%.4f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiEField = 0.05f;
        ImGui::SetItemTooltip(
            "Inverse-Square 1/r^2 Stiffness (Coulomb repulsion)");

        ImGui::SliderFloat("B-Field Spin", &uiBField, 0.0f, 0.5f, "%.4f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiBField = 0.05f;
        ImGui::SetItemTooltip(
            "Vortex induction strength (Biot-Savart velocity transfer)");

        ImGui::Separator();

        ImGui::SliderFloat("Gravity (G)", &uiGravity, 0.0f, 0.1f, "%.4f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiGravity = 0.005f;
        ImGui::SetItemTooltip(
            "Newtonian Self-Gravity (Inward collapse to Potato Radius)");

        ImGui::SliderFloat("String Tension", &uiStringStiffness, 0.0f, 0.2f,
                           "%.4f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiStringStiffness = 0.01f;
        ImGui::SetItemTooltip(
            "Hooke's Law spring tension between neighbor particles");

        ImGui::SliderFloat("String Rest", &uiRestLength, 0.0f, 0.1f, "%.4f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiRestLength = 0.01f;
        ImGui::SetItemTooltip("Ideal distance where string tension relaxes");

        ImGui::SliderFloat("Rotate X", &uiRotationX, -M_PI_F, M_PI_F,
                           "%.3f rad");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiRotationX = 0.0f;

        ImGui::SliderFloat("Rotate Y", &uiRotationY, -M_PI_F, M_PI_F,
                           "%.3f rad");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiRotationY = 0.0f;

        ImGui::SliderFloat("Rotate Z", &uiRotationZ, -M_PI_F, M_PI_F,
                           "%.3f rad");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiRotationZ = 0.0f;

        ImGui::Checkbox("Auto Rotate View", &uiAutoRotateScene);
        ImGui::Unindent();
      }

      if (ImGui::CollapsingHeader("NEW SCIENCE (Phase 9)",
                                  ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Indent();
        ImGui::Checkbox("ODS-01 Quantum Entanglement", &uiQuantumEntangle);
        ImGui::SetItemTooltip("Enable telepathic state transfer "
                              "between paired particles");
        ImGui::Checkbox("ODS-06 Black Holes", &uiBlackHoles);
        ImGui::SetItemTooltip("Enable gravitational collapse "
                              "(Schwarzschild "
                              "radius) at high density");
        ImGui::Unindent();
      }

      if (ImGui::CollapsingHeader("INDUSTRY DEBUGGING (Phase 7)")) {
        ImGui::Indent();

        ImGui::Checkbox("Deterministic (Fixed dt)", &uiFixedTimestep);
        ImGui::SetItemTooltip("Force dt = 1/60s for perfectly "
                              "repeatable experiments");

        ImGui::Separator();
        ImGui::Text("Force Isolation (Solo/Mute):");
        static const char *forceLabels[] = {"E-Field", "B-Field", "Gravity",
                                            "Strings", "Jitter",  "Collisions"};
        bool *solos[] = {&uiSoloEField,  &uiSoloBField, &uiSoloGravity,
                         &uiSoloStrings, &uiSoloJitter, &uiSoloCollisions};

        for (int i = 0; i < 6; i++) {
          ImGui::Checkbox(forceLabels[i], solos[i]);
          if (i % 2 == 0)
            ImGui::SameLine(150);
        }
        ImGui::NewLine();

        auto stats = renderer.getPhysicsStats();
        if (stats.errorState > 0) {
          ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1.0f, 0.2f, 0.2f, 1.0f));
          ImGui::Text("!!! PHYSICAL ASSERT FAILED !!!");
          ImGui::Text(stats.errorState == 1 ? "Error: NaN Detected"
                                            : "Error: Energy Explosion");
          ImGui::PopStyleColor();

          if (uiAutoMode) {
            ImGui::TextColored(ImVec4(1, 0.5, 0, 1),
                               "Auto-Mitigation Active...");
          }
        } else {
          ImGui::TextColored(ImVec4(0.2f, 1.0f, 0.2f, 1.0f),
                             "Physics Core: OK");
        }

        ImGui::Checkbox("Auto-Mode (Self-Healing)", &uiAutoMode);
        ImGui::SetItemTooltip("Automatically dial down parameters "
                              "and reset on "
                              "stability failure");

        ImGui::Unindent();
      }

      if (ImGui::CollapsingHeader("EMITTERS")) {
        ImGui::Indent();
        int numVoices = std::max(1, (int)activeVoices.size());
        for (int i = 0; i < numVoices && i < MAX_EMITTERS; i++) {
          ImGui::PushID(i);
          char label[32];
          snprintf(label, sizeof(label), "E%d XY", i);
          float pos[2] = {emitters[i].x, emitters[i].y};
          if (ImGui::SliderFloat2(label, pos, -0.9f, 0.9f, "%.2f")) {
            emitters[i].x = pos[0];
            emitters[i].y = pos[1];
          }
          if (ImGui::IsItemClicked(ImGuiMouseButton_Right)) {
            emitters[i].x = 0.0f;
            emitters[i].y = 0.0f;
          }
          ImGui::PopID();
        }
        if (ImGui::Button("Reset Emitters")) {
          emitters.reset();
        }
        ImGui::SameLine();
        if (ImGui::Button("Auto-Arrange")) {
          emitters.arrangeSphere(numVoices, 0.4f);
        }
        ImGui::SetItemTooltip("Arrange emitters in a 3D sphere "
                              "(r=0.4)");
        ImGui::Unindent();
      }

      if (ImGui::CollapsingHeader("VJ MODE & AUDIO INPUT",
                                  ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Indent();
        ImGui::Checkbox("Enable VJ Mode (Mic/System In)", &uiVJMode);
        ImGui::SetItemTooltip("Visualize incoming audio using "
                              "16-band FFT harmonic sculpting");

        if (uiVJMode) {
          static float uiInputGain = 2.0f;
          if (ImGui::SliderFloat("Input Gain", &uiInputGain, 0.1f, 10.0f,
                                 "%.2f x")) {
            audio.setVJInputGain(uiInputGain);
          }
          if (ImGui::IsItemClicked(ImGuiMouseButton_Right)) {
            uiInputGain = 2.0f;
            audio.setVJInputGain(uiInputGain);
          }
          ImGui::SetItemTooltip("Boost quiet audio signals before "
                                "FFT analysis");

          // Visualize the bands as a small EQ
          // graphic
          auto bands = audio.getVJBands();
          float maxAmp = 0.001f;
          for (const auto &b : bands)
            maxAmp = std::max(maxAmp, b.amplitude);

          ImGui::Text("Live Spectrum:");
          for (size_t i = 0; i < bands.size(); i++) {
            char buf[32];
            snprintf(buf, sizeof(buf), "%4.0fHz", bands[i].frequency);
            ImGui::ProgressBar(bands[i].amplitude, ImVec2(-1.0f, 10.0f), buf);
          }
        }
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

        if (ImGui::SliderFloat("Drive", &uiScale, 1.0f, 10.0f, "%.1f")) {
          // This was previously mislabeled as
          // 'Scale' in one place and 'Drive' in
          // another. Let's use it for Scale (as
          // requested) and move Drive to a separate
          // slider if needed.
          renderer.setScale(uiScale);
        }
        ImGui::SetItemTooltip("Filter saturation and analog clipping "
                              "(Moog-style)");

        if (ImGui::Checkbox("BBD Chorus", &uiChorus)) {
          synth.chorus().setEnabled(uiChorus);
        }
        ImGui::SetItemTooltip("Lush stereo bucket-brigade dual delay");

        if (uiChorus) {
          ImGui::Indent();
          float cRate = synth.chorus().rate();
          if (ImGui::SliderFloat("LFO Rate", &cRate, 0.1f, 10.0f, "%.2f Hz")) {
            synth.chorus().setRate(cRate);
          }
          float cDepth = synth.chorus().depth();
          if (ImGui::SliderFloat("LFO Depth##Chorus", &cDepth, 0.0f, 10.0f, "%.2f ms")) {
            synth.chorus().setDepth(cDepth);
          }
          float cMix = synth.chorus().mix();
          if (ImGui::SliderFloat("Chorus Mix", &cMix, 0.0f, 1.0f, "%.2f")) {
            synth.chorus().setMix(cMix);
          }
          ImGui::Unindent();
        }

        ImGui::SliderFloat("Attack", &uiAttack, 5.0f, 500.0f, "%.0f ms");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiAttack = 20.0f;
        ImGui::SetItemTooltip("Envelope attack duration");
        synth.envelopeParams().attack = uiAttack / 1000.0f;

        static float uiDecay = 100.0f;
        ImGui::SliderFloat("Decay", &uiDecay, 5.0f, 1000.0f, "%.0f ms");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiDecay = 100.0f;
        ImGui::SetItemTooltip("Envelope decay duration");
        synth.envelopeParams().decay = uiDecay / 1000.0f;

        static float uiSustain = 0.7f;
        ImGui::SliderFloat("Sustain", &uiSustain, 0.0f, 1.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiSustain = 0.7f;
        ImGui::SetItemTooltip("Sustain level — controls visual expansion size");
        synth.envelopeParams().sustain = uiSustain;

        ImGui::SliderFloat("Release", &uiRelease, 1.0f, 2000.0f, "%.0f ms");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiRelease = 400.0f;
        ImGui::SetItemTooltip("Envelope release duration");
        synth.envelopeParams().release = uiRelease / 1000.0f;

        ImGui::Unindent();
      }

      bool kbMode = synth.keyboardMode();
      if (ImGui::Checkbox("Keyboard Mode", &kbMode)) {
        synth.setKeyboardMode(kbMode);
      }
      ImGui::SetItemTooltip("Toggle between Piano layout (Keyboard) "
                            "and "
                            "linear mapping (Full Range)");
      ImGui::Unindent();

      if (ImGui::CollapsingHeader("DYNAMICS", ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Indent();
        ImGui::SliderFloat("Jitter", &uiJitter, 0.0f, 5.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiJitter = 1.0f;
        ImGui::SetItemTooltip("Random displacement factor");

        ImGui::Separator();
        ImGui::Text("GLOBAL LFO");
        ImGui::SliderFloat("LFO Rate", &uiLFORate, 0.01f, 10.0f, "%.2f Hz");
        ImGui::SliderFloat("LFO Depth", &uiLFODepth, 0.0f, 1.0f, "%.2f");
        ImGui::SetItemTooltip("Modulates Jitter, Size, and Scale over time");

        ImGui::Unindent();
      }

      if (ImGui::CollapsingHeader("GEOMETRY", ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Indent();
        if (ImGui::SliderFloat("Space Scale", &uiScale, 10.0f, 2000.0f,
                               "%.0f")) {
          renderer.setScale(uiScale);
        }
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right)) {
          uiScale = 100.0f;
          renderer.setScale(uiScale);
        }
        ImGui::SetItemTooltip("Global cosmic scale "
                              "(Expansion/Contraction)");

        ImGui::SliderFloat("Wave Depth", &uiWaveDepth, 5.0f, 100.0f, "%.1f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiWaveDepth = 20.0f;
        ImGui::SetItemTooltip("Vibrational displacement intensity");

        ImGui::Spacing();
        ImGui::SeparatorText("BLACK HOLE");
        ImGui::SliderAngle("Rotation X", &uiBlackHoleRotationX, -180.0f,
                           180.0f);
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiBlackHoleRotationX = 0.0f;
        ImGui::Checkbox("Auto-Rotate", &uiAutoRotateBlackHole);
        ImGui::SetItemTooltip("Continuous rotation over time");

        if (ImGui::Button("Reset Camera")) {
          camera.reset();
        }
        ImGui::SameLine();
        if (ImGui::Button("Snap Back (Reset)")) {
          renderer.triggerReset();
        }
        ImGui::SetItemTooltip("Instantly re-seed all particles into "
                              "center");

        ImGui::Unindent();
      }

      if (ImGui::CollapsingHeader("POST-FX", ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Indent();
        ImGui::SliderFloat("Bloom", &uiBloom, 0.0f, 1.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiBloom = 0.0f;
        ImGui::SetItemTooltip("Cross-shaped bright-pass glow");

        ImGui::SliderFloat("Fluidity", &uiTrailDecay, 0.0f, 0.99f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiTrailDecay = 0.0f;
        ImGui::SetItemTooltip("Motion trails (Feedback factor)");

        ImGui::SliderFloat("Chromatic", &uiChromatic, 0.0f, 0.02f, "%.3f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          uiChromatic = 0.0f;
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

      if (ImGui::CollapsingHeader("SEQUENCER",
                                  ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Indent();

        if (ImGui::Button("Maj7", ImVec2(45, 0))) {
          firePreset("Major 7th", {
                                      {60, 0.0f, 2.0f}, // C4
                                      {64, 0.0f, 2.0f}, // E4
                                      {67, 0.0f, 2.0f}, // G4
                                      {71, 0.0f, 2.0f}, // B4
                                  });
        }
        ImGui::SameLine();
        if (ImGui::Button("Min7", ImVec2(45, 0))) {
          firePreset("Minor 7th", {
                                      {60, 0.0f, 2.0f}, // C4
                                      {63, 0.0f, 2.0f}, // Eb4
                                      {67, 0.0f, 2.0f}, // G4
                                      {70, 0.0f, 2.0f}, // Bb4
                                  });
        }
        ImGui::SameLine();
        if (ImGui::Button("5th", ImVec2(45, 0))) {
          firePreset("Power 5th", {
                                      {48, 0.0f, 2.0f}, // C3
                                      {55, 0.0f, 2.0f}, // G3
                                  });
        }
        ImGui::SameLine();
        if (ImGui::Button("Run", ImVec2(45, 0))) {
          firePreset("Chromatic Run", {
                                          {60, 0.0f, 0.4f},
                                          {61, 0.3f, 0.4f},
                                          {62, 0.6f, 0.4f},
                                          {63, 0.9f, 0.4f},
                                          {64, 1.2f, 0.4f},
                                          {65, 1.5f, 0.4f},
                                          {66, 1.8f, 0.4f},
                                          {67, 2.1f, 0.4f},
                                      });
        }
        ImGui::SameLine();
        if (ImGui::Button("Stop", ImVec2(45, 0)) && seqRunning) {
          for (size_t i = 0; i < seqNotes.size(); i++) {
            if (seqNoteOn[i])
              synth.noteOff(seqNotes[i].midi);
          }
          seqRunning = false;
        }

        // Status display
        if (seqRunning) {
          int activeNotes = 0;
          for (auto on : seqNoteOn)
            if (on)
              activeNotes++;
          ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f),
                             "RUNNING t=%.1fs notes=%d", seqTime, activeNotes);
        } else {
          ImGui::TextDisabled("Idle — pick a chord");
        }

        ImGui::Unindent();
      }

      if (ImGui::CollapsingHeader("DEBUG GPU",
                                  ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Indent();
        ImGui::Text("dt: %f | Particles: %d", dt, uiParticleCount);
        ImGui::Text("Total Amplitude: %.3f", synth.totalAmplitude());

        if (ImGui::Button("Fetch GPU Memory (first 4)")) {
          std::vector<GPUParticle> debugParts(4);
          renderer.readbackParticles(debugParts.data(), 4);
          for (int i = 0; i < 4; i++) {
            ImGui::Text("P[%d]: pos[%5.2f, %5.2f, %5.2f]", i, debugParts[i].x,
                        debugParts[i].y, debugParts[i].z);
          }
        }
        ImGui::Unindent();
      }

      ImGui::Spacing();
      ImGui::Separator();
      ImGui::TextDisabled("FPS: %.1f | Particles: %dk",
                          ImGui::GetIO().Framerate, uiParticleCount / 1000);
      ImGui::End();
    } // if (showHUD)

    // ── Apply Audio-Visual Macros ─────────────────────────────────────
    // Calculate effective values interpolated by Supernova Macro
    float effectiveSize =
        uiParticleSize + (uiSupernova * 8.0f); // Grow up to +8px
    float effectiveDrive =
        synth.drive() + (uiSupernova * 3.4f); // Push into Moog clipping
    float effectiveJitterMultiplier =
        1.0f + (uiSupernova * 9.0f); // 10x Phase Drift

    // Push volatile settings back into synth
    synth.setJitter(uiJitter * effectiveJitterMultiplier);
    synth.setDrive(effectiveDrive);

    // Update Global LFO
    uiLFOPhase =
        std::fmod(uiLFOPhase + dt * uiLFORate * M_PI_F * 2.0f, M_PI_F * 2.0f);
    float lfoVal = sin(uiLFOPhase) * uiLFODepth;

    config.particleSize = effectiveSize * (1.0f + lfoVal * 0.2f);
    config.plateRadius = uiScale * (1.0f + lfoVal * 0.1f);
    config.cameraRho = camera.getRho();
    config.jitterFactor =
        uiJitter * effectiveJitterMultiplier * (1.0f + lfoVal * 0.5f);
    config.orthoMode = uiOrthoMode;
    config.phaseViz = uiPhaseViz;

    // ── Update ADSR (Phase 12.6) ──────────────────────────────────
    synth.envelopeParams().attack = uiAttack / 1000.0f;
    synth.envelopeParams().release = uiRelease / 1000.0f;
    // Supernova adds on top of user slider values
    config.bloomIntensity = uiBloom + uiSupernova * 1.5f;
    config.trailDecay = uiTrailDecay + uiSupernova * 0.1f;
    config.chromaticAmount = uiChromatic + uiSupernova * 0.015f;

    // ── Update ADSR ────────────────────────────────────────────────
    synth.envelopeParams().attack = uiAttack / 1000.0f;
    synth.envelopeParams().release = uiRelease / 1000.0f;

    // ── Update Physics ──────────────────────────────────────────────
    renderer.setActiveParticleCount(uiParticleCount);

    // Build Debug Flags bitmask
    uint32_t debugFlags = 0;
    if (uiSoloEField)
      debugFlags |= DEBUG_E_FIELD;
    if (uiSoloBField)
      debugFlags |= DEBUG_B_FIELD;
    if (uiSoloGravity)
      debugFlags |= DEBUG_GRAVITY;
    if (uiSoloStrings)
      debugFlags |= DEBUG_STRINGS;
    if (uiSoloJitter)
      debugFlags |= DEBUG_JITTER;
    if (uiSoloCollisions)
      debugFlags |= DEBUG_COLLISIONS;
    if (uiFixedTimestep)
      debugFlags |= DEBUG_FIXED_DT;
    if (uiQuantumEntangle)
      debugFlags |= DEBUG_ODS01;
    if (uiBlackHoles)
      debugFlags |= DEBUG_ODS06;

    // ── Auto-Stabilizer Supervisor (Phase 8) ────────────────────────
    auto stats = renderer.getPhysicsStats();
    if (uiAutoMode && stats.errorState > 0) {
      // Step 1: Immediate parameter mitigation (dial down stress)
      uiEField *= 0.5f;
      uiBField *= 0.5f;
      uiGravity *= 0.8f;

      // Step 2: If we have NaNs, we MUST reset the hardware state
      if (stats.errorState == 1) {
        renderer.resetParticles();
      }

      // Step 3: Log to console (silent unless debugging)
      // printf("[AUTO-MODE] Instability detected. Mitigating...\n");
    }

    // Phase 17: Wire ADSR lifecycle to black hole dynamics
    auto envState = synth.getDominantEnvelope();
    renderer.setEnvelopeState(envState.phase, envState.progress,
                              envState.intensity);

    // Pass envelope state to config for shaders
    config.envelopePhase = envState.phase;
    config.envelopeProgress = envState.progress;

    renderer.computeStep(dt, voiceData.data(), (int)voiceData.size(),
                         synth.totalAmplitude(), uiWaveDepth,
                         uiJitter * effectiveJitterMultiplier, effectiveDrive,
                         uiEField, uiBField, uiGravity, uiStringStiffness,
                         uiRestLength, debugFlags);

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
        printf("\n%d fps | %dk particles | %d voice%s | amp %.2f    ", fps,
               PARTICLE_COUNT / 1000, vc, vc > 1 ? "s" : "",
               synth.totalAmplitude());
      } else {
        printf("\n%d fps | %dk particles | ready    ", fps,
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
