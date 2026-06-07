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
#include "ui/window.h"
#include "ui/ui_theme.h"
#include "core/logger.h"
#include "core/resource_helper.h"
#include "core/app_state.h"
#include <algorithm>
#include <array>
#include <chrono>
#include <cstdio>
#include <fcntl.h>
#include <signal.h>
#include <string>
#include <unistd.h>

using namespace space;

// ── Typable sliders ────────────────────────────────────────────────────────
// Drop-in replacements for ImGui::SliderFloat/Int that turn into a text input
// box on DOUBLE-CLICK (ImGui natively only allows Ctrl+Click). Same signature
// + defaults as the ImGui versions, so call sites are unchanged.
static ImGuiID g_uiEditId = 0;
static bool g_uiEditFocus = false;

static bool UiSliderFloat(const char *label, float *v, float v_min, float v_max,
                          const char *fmt = "%.3f", ImGuiSliderFlags flags = 0) {
  ImGuiID id = ImGui::GetID(label);
  if (g_uiEditId == id) {
    if (g_uiEditFocus) { ImGui::SetKeyboardFocusHere(); g_uiEditFocus = false; }
    bool done = ImGui::InputFloat(label, v, 0.0f, 0.0f, fmt,
                                  ImGuiInputTextFlags_EnterReturnsTrue |
                                      ImGuiInputTextFlags_AutoSelectAll);
    if (done || ImGui::IsItemDeactivated()) g_uiEditId = 0;
    return done;
  }
  bool changed = ImGui::SliderFloat(label, v, v_min, v_max, fmt, flags);
  if (ImGui::IsItemHovered() && ImGui::IsMouseDoubleClicked(ImGuiMouseButton_Left)) {
    g_uiEditId = id;
    g_uiEditFocus = true;
  }
  return changed;
}

static bool UiSliderInt(const char *label, int *v, int v_min, int v_max,
                        const char *fmt = "%d", ImGuiSliderFlags flags = 0) {
  ImGuiID id = ImGui::GetID(label);
  if (g_uiEditId == id) {
    if (g_uiEditFocus) { ImGui::SetKeyboardFocusHere(); g_uiEditFocus = false; }
    bool done = ImGui::InputInt(label, v, 0, 0,
                                ImGuiInputTextFlags_EnterReturnsTrue |
                                    ImGuiInputTextFlags_AutoSelectAll);
    if (done || ImGui::IsItemDeactivated()) g_uiEditId = 0;
    return done;
  }
  bool changed = ImGui::SliderInt(label, v, v_min, v_max, fmt, flags);
  if (ImGui::IsItemHovered() && ImGui::IsMouseDoubleClicked(ImGuiMouseButton_Left)) {
    g_uiEditId = id;
    g_uiEditFocus = true;
  }
  return changed;
}

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
  if (!window.create(1280, 800, "SPACE Synth v1.0 [STABLE]")) {
    fprintf(stderr, "Failed to create window\n");
    return 1;
  }
  Logger::log("Application Started: SPACE Synth v1.0 [STABLE]");

  float scale = window.getContentScale();
  space::UITheme::ApplyPremiumTheme(scale);

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
    if (e.isDown && (e.button == 0 || e.button == 1)) {
      // Rotate sensitivity — chilled for screen-recording framing (was 0.005)
      camera.rotate(-e.dx * 0.0015f, -e.dy * 0.0015f);
    }
  });
  window.setScrollCallback([&](float dx, float dy) {
    // Logarithmic zoom, sensitivity dialed down for fine framing (was 0.015)
    camera.zoom(dy * std::max(0.0005f, camera.getRho() * 0.004f));
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
  static space::AppState app;

  // Arrow-key PHYSICAL spin: hold to ramp torque on the particle body up to
  // extreme (solid swept shape), with momentum/drag.
  static bool arrowL = false, arrowR = false, arrowU = false, arrowD = false;
  static float spinHold = 0.0f;
  static float spinVelX = 0.0f, spinVelY = 0.0f; // current spin rate (rad/s)

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


  // ── Key events ──────────────────────────────────────────────────────
  window.setKeyCallback([&](const KeyEvent &e) {
    // Arrow keys = orbit camera. Handled BEFORE the isRepeat gate so a
    // held key fires every macOS key-repeat tick → smooth continuous
    // rotation. Step is a velocity impulse; Camera::update applies
    // friction and soft-locks to the nearest 90° quadrant when the
    // user lets go.
    //   123=Left  124=Right  125=Down  126=Up
    // Hold to RAMP the spin up to extreme (light-trail territory). Track held
    // state for down AND up; the per-frame ramp lives in the render loop.
    if (e.keyCode == 123 || e.keyCode == 124 || e.keyCode == 125 ||
        e.keyCode == 126) {
      bool d = e.isDown;
      // TAP (quick press+release, under the threshold → spin never engaged) =
      // the old snapped-camera quadrant rotate. HOLD = the physical spin.
      if (!d && spinHold < 0.18f) {
        constexpr float TAP_STEP = 0.06f; // enough to soft-lock to next 90°
        if (e.keyCode == 123)      camera.rotateKey(+TAP_STEP, 0.0f);
        else if (e.keyCode == 124) camera.rotateKey(-TAP_STEP, 0.0f);
        else if (e.keyCode == 126) camera.rotateKey(0.0f, +TAP_STEP);
        else if (e.keyCode == 125) camera.rotateKey(0.0f, -TAP_STEP);
      }
      if (e.keyCode == 123)      arrowL = d;
      else if (e.keyCode == 124) arrowR = d;
      else if (e.keyCode == 126) arrowU = d;
      else if (e.keyCode == 125) arrowD = d;
      return;
    }

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
  auto fpsLastTime = std::chrono::steady_clock::now(); // real wall-clock FPS window
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
    std::vector<VoiceGPUData> vjVoices;
    std::vector<VoiceGPUData> synthVoices;
    static std::unordered_map<int, float> lastAmps;

    // ── VJ Audio Band Injection ──
    // Per-band release state: tracks amplitude for smooth fade-out
    // 3C: Crossfade support — track previous mode for smooth transitions
    struct VJBandState {
      float amp; int group;
      int lastM; int lastN; float lastAlpha;
      // Crossfade: previous mode fading out when mode changes
      int prevM; int prevN; float prevAlpha;
      float crossfade; // 1.0 = fully old mode, 0.0 = fully new mode
    };
    static std::array<VJBandState, 16> vjBandState{};
    static constexpr float VJ_RELEASE_RATE = 5.0f; // decay per second (~200ms full fade)
    static constexpr float VJ_CROSSFADE_RATE = 8.0f; // crossfade speed (~125ms)

    if (app.uiVJMode) {
      auto bands = audio.getVJBands();
      uint32_t tMask = audio.getTransientMask();

      // Curated mode palettes: transient vs sustain per frequency group
      struct ModeDef { int m; int n; float alpha; };
      static const ModeDef transientModes[6] = {
        {0, 1, 2.40f},  // Sub: radial pulse
        {0, 2, 5.52f},  // Kick: radial explosion
        {6, 1, 6.38f},  // Low-mid: scattered
        {5, 2, 8.41f},  // Mid: complex shrapnel
        {10,1, 10.5f},  // Hi-mid: fine detail
        {8, 1, 8.65f},  // Air: chaotic sparkle
      };
      static const ModeDef sustainModes[6] = {
        {1, 1, 3.83f},  // Sub: simple breathing
        {2, 1, 5.13f},  // Kick/bass: warm wave
        {3, 1, 6.38f},  // Low-mid: flowing
        {2, 2, 7.01f},  // Mid: medium complexity
        {4, 1, 7.58f},  // Hi-mid: detailed
        {3, 2, 8.41f},  // Air: texture
      };

      // Update per-band release state
      size_t bandCount = std::min(bands.size(), (size_t)16);
      for (size_t i = 0; i < bandCount; i++) {
        int group = (i < 2) ? 0 : (i < 4) ? 1 : (i < 7) ? 2 : (i < 10) ? 3 : (i < 13) ? 4 : 5;
        if (bands[i].amplitude > 0.005f) {
          // Active: track live amplitude and mode
          vjBandState[i].amp = bands[i].amplitude;
          vjBandState[i].group = group;
          bool isOnset = (tMask >> i) & 1;
          const ModeDef& mode = isOnset ? transientModes[group] : sustainModes[group];
          // 3C: Detect mode change → trigger crossfade
          if (mode.m != vjBandState[i].lastM || mode.n != vjBandState[i].lastN) {
            vjBandState[i].prevM = vjBandState[i].lastM;
            vjBandState[i].prevN = vjBandState[i].lastN;
            vjBandState[i].prevAlpha = vjBandState[i].lastAlpha;
            vjBandState[i].crossfade = 1.0f; // start full crossfade
          }
          vjBandState[i].lastM = mode.m;
          vjBandState[i].lastN = mode.n;
          vjBandState[i].lastAlpha = mode.alpha;
        } else if (vjBandState[i].amp > 0.01f) {
          // Releasing: decay amplitude smoothly
          vjBandState[i].amp -= VJ_RELEASE_RATE * dt;
          if (vjBandState[i].amp < 0.01f) vjBandState[i].amp = 0.0f;
        } else {
          vjBandState[i].amp = 0.0f;
        }
        // 3C: Decay crossfade timer
        if (vjBandState[i].crossfade > 0.0f) {
          vjBandState[i].crossfade -= VJ_CROSSFADE_RATE * dt;
          if (vjBandState[i].crossfade < 0.0f) vjBandState[i].crossfade = 0.0f;
        }
      }

      // Sort by current amplitude (live + releasing), take top 6
      constexpr int VJ_MAX_VOICES = 6;
      std::array<size_t, 16> bandIdx;
      for (size_t i = 0; i < bandCount; i++) bandIdx[i] = i;
      std::sort(bandIdx.begin(), bandIdx.begin() + bandCount,
                [&](size_t a, size_t b) { return vjBandState[a].amp > vjBandState[b].amp; });

      int vjAdded = 0;
      for (size_t bi = 0; bi < bandCount && vjAdded < VJ_MAX_VOICES; bi++) {
        size_t i = bandIdx[bi];
        float amp = vjBandState[i].amp;
        if (amp > 0.005f) {
          int emIdx = vjVoices.size() % MAX_EMITTERS;

          float dAmp =
              std::max(0.0f, amp - lastAmps[-(int)i - 1]);
          lastAmps[-(int)i - 1] = amp;

          // 3C: Crossfade weighting — new mode fades in, old mode fades out
          float xfade = vjBandState[i].crossfade; // 1.0=old, 0.0=new
          float newWeight = 1.0f - xfade;
          float freq = (i < bands.size()) ? bands[i].frequency : 440.0f;
          float phase = std::fmod((float)ImGui::GetTime() * freq * 0.05f,
                                  M_PI_F * 2.0f);

          // Primary voice (new/current mode)
          VoiceGPUData vd;
          vd.m = vjBandState[i].lastM;
          vd.n = vjBandState[i].lastN;
          vd.alpha = vjBandState[i].lastAlpha;
          vd.amplitude = amp * newWeight;
          vd.emitterX = emitters[emIdx].x;
          vd.emitterY = emitters[emIdx].y;
          vd.emitterZ = emitters[emIdx].z;
          vd.frequency = freq;
          vd.deltaAmp = dAmp * newWeight;
          vd.phase = phase;
          vd.bandGroup = vjBandState[i].group;

          vjVoices.push_back(vd);
          vjAdded++;

          // Crossfade voice (old mode fading out)
          if (xfade > 0.01f && vjAdded < VJ_MAX_VOICES + 3) {
            VoiceGPUData vdOld;
            vdOld.m = vjBandState[i].prevM;
            vdOld.n = vjBandState[i].prevN;
            vdOld.alpha = vjBandState[i].prevAlpha;
            vdOld.amplitude = amp * xfade;
            vdOld.emitterX = emitters[emIdx].x;
            vdOld.emitterY = emitters[emIdx].y;
            vdOld.emitterZ = emitters[emIdx].z;
            vdOld.frequency = freq;
            vdOld.deltaAmp = 0.0f;
            vdOld.phase = phase;
            vdOld.bandGroup = vjBandState[i].group;
            vjVoices.push_back(vdOld);
          }
        } else {
          lastAmps[-(int)i - 1] = 0.0f;
        }
      }
    }

    // Synth voices (cap at 8)
    for (int i = 0;
         i < (int)activeVoices.size() && synthVoices.size() < 8; i++) {
      const auto &v = activeVoices[i];
      int emIdx = (vjVoices.size() + synthVoices.size()) % MAX_EMITTERS;

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
      vd.bandGroup = 0;

      synthVoices.push_back(vd);
    }
    // Cleanup old voices from lastAmps if they aren't active
    if (activeVoices.empty())
      lastAmps.clear();

    // Phase 4A: Merge voice sets with dynamic amplitude weighting
    float vjAmp = 0.0f, synthAmp = 0.0f;
    for (auto& v : vjVoices) vjAmp += v.amplitude;
    for (auto& v : synthVoices) synthAmp += v.amplitude;
    float sumAmp = vjAmp + synthAmp + 1e-6f;
    float vjW = 0.3f + 0.7f * (vjAmp / sumAmp);
    float synthW = 0.3f + 0.7f * (synthAmp / sumAmp);

    std::vector<VoiceGPUData> voiceData;
    for (auto v : synthVoices) { v.amplitude *= synthW; voiceData.push_back(v); }
    for (auto v : vjVoices) { v.amplitude *= vjW; voiceData.push_back(v); }
    if (voiceData.size() > MAX_EMITTERS) voiceData.resize(MAX_EMITTERS);

    // Arrow-hold → physically SPIN the particle body (torque on the sim, not
    // the camera). Ramps HARD and carries momentum, so holding rips it up to
    // where the trails merge into a solid swept shape. Left/right → spin around
    // Y; up/down → spin around X.
    {
      float dirY = (arrowL ? 1.0f : 0.0f) - (arrowR ? 1.0f : 0.0f);
      float dirX = (arrowU ? 1.0f : 0.0f) - (arrowD ? 1.0f : 0.0f);
      if (dirX != 0.0f || dirY != 0.0f) {
        spinHold += dt;
        if (spinHold > 0.18f) { // past tap threshold → engage the spin
          float accel = 6.0f + spinHold * spinHold * 30.0f; // ramp hard
          spinVelY += dirY * accel * dt;
          spinVelX += dirX * accel * dt;
        }
      } else {
        spinHold = 0.0f;
      }
      // Momentum drag: coasts to a stop in ~2s after release (heavy flywheel,
      // not frictionless). Stronger drag while NOT actively driving.
      float dragRate = (dirX != 0.0f || dirY != 0.0f) ? 0.3f : 2.5f;
      float spinDrag = std::max(0.0f, 1.0f - dt * dragRate);
      spinVelX *= spinDrag;
      spinVelY *= spinDrag;
      // Clean ceiling at 120fps refresh (~188 rad/s before rotation aliases).
      spinVelX = std::clamp(spinVelX, -188.0f, 188.0f);
      spinVelY = std::clamp(spinVelY, -188.0f, 188.0f);
      renderer.setSpin(spinVelX, spinVelY);
    }
    camera.update(dt);
    float view[16], proj[16], viewProj[16];
    camera.buildViewMatrix(view);

    if (app.uiOrthoMode) {
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
        app.uiRotationX + app.uiBlackHoleRotationX +
        (app.uiAutoRotateBlackHole ? (float)ImGui::GetTime() * 0.2f : 0.0f) +
        (app.uiAutoRotateScene ? (float)ImGui::GetTime() * 0.15f : 0.0f);
    config.rotationY = app.uiRotationY;
    config.rotationZ = app.uiRotationZ;

    // ── ImGui HUD ──────────────────────────────────────────────────
    static Preset currentPreset;
    static bool presetsLoaded = false;
    static std::vector<std::string> presetFiles;
    static int selectedPresetIdx = -1;

    if (!presetsLoaded) {
      std::string presetsDir = ResourceHelper::getResourcePath("presets");
      presetFiles = PresetManager::scanPresets(presetsDir);
      // Try to load default.json
      for (int i = 0; i < (int)presetFiles.size(); i++) {
        if (presetFiles[i] == "default.json") {
          selectedPresetIdx = i;
          std::string path = ResourceHelper::getResourcePath("presets/" + presetFiles[i]);
          if (PresetManager::loadPreset(path,
                                        currentPreset)) {
            app.uiParticleSize = currentPreset.particleSize;
            app.uiJitter = currentPreset.jitterScale;
            synth.setDrive(currentPreset.speedCap);
          }
          break;
        }
      }
      presetsLoaded = true;
    }

    // ── Top Right Overlay Control Panel ──────────────────────────────
    if (showHUD) {
      ImGui::SetNextWindowPos(ImVec2(window.width() - 250, 20));
      ImGui::SetNextWindowSize(ImVec2(230, 0));
      ImGui::Begin("##topright", nullptr,
                   ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoBackground);

      ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1, 1, 1, 0.6f));
      ImGui::Text("MASTER VOLUME");
      ImGui::PopStyleColor();

      float currentVol = synth.masterVolume();
      if (UiSliderFloat("##MasterVol", &currentVol, 0.0f, 1.0f, "%.2f")) {
        synth.setMasterVolume(currentVol);
      }

      ImGui::Spacing();

      if (ImGui::Button("HIDE ARCHITECT", ImVec2(215, 30))) {
        showHUD = false;
      }
      if (ImGui::IsItemHovered())
        ImGui::SetTooltip("Hide UI (TAB)");
      ImGui::End();
    } else {
      // Minimal restore button when HUD is hidden
      ImGui::SetNextWindowPos(ImVec2(window.width() - 160, 20));
      ImGui::SetNextWindowSize(ImVec2(140, 0));
      ImGui::Begin("##restore_ui", nullptr,
                   ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoBackground);
      if (ImGui::Button("SHOW ARCHITECT", ImVec2(130, 30))) {
        showHUD = true;
      }
      if (ImGui::IsItemHovered())
        ImGui::SetTooltip("Restore UI (TAB)");
      ImGui::End();
    }


    if (showHUD) {
      ImGui::SetNextWindowPos(ImVec2(30, 30), ImGuiCond_FirstUseEver);
      ImGui::SetNextWindowSize(ImVec2(340, 0), ImGuiCond_FirstUseEver);

      // Custom header drawing inside the window
      ImGui::Begin("PHYSICS ARCHITECT", nullptr,
                   ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar);

      if (ImGui::CollapsingHeader("GLOBALS", ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Indent();
        ImGui::Text("Performance View");
        ImGui::TextDisabled("FPS: %.1f | Mode: %s", ImGui::GetIO().Framerate, 
                            app.uiOrthoMode ? "Orthogonal" : "Perspective");
        ImGui::Unindent();
      }
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
              std::string path = ResourceHelper::getResourcePath("presets/" + presetFiles[n]);
              if (PresetManager::loadPreset(path,
                                            currentPreset)) {
                app.uiParticleSize = currentPreset.particleSize;
                app.uiJitter = currentPreset.jitterScale;
                synth.setDrive(currentPreset.speedCap);
                app.uiEField = currentPreset.eField;
                app.uiBField = currentPreset.bField;
                app.uiGravity = currentPreset.gravity;
                app.uiStringStiffness = currentPreset.stringStiffness;
                app.uiRestLength = currentPreset.restLength;
                app.uiParticleCount = currentPreset.particleCount;
              }
            }
            if (is_selected)
              ImGui::SetItemDefaultFocus();
          }
          ImGui::EndCombo();
        }
        ImGui::SameLine();
        if (ImGui::Button("Save") && selectedPresetIdx >= 0) {
          currentPreset.particleSize = app.uiParticleSize;
          currentPreset.jitterScale = app.uiJitter;
          currentPreset.speedCap = synth.drive();
          currentPreset.eField = app.uiEField;
          currentPreset.bField = app.uiBField;
          currentPreset.gravity = app.uiGravity;
          currentPreset.stringStiffness = app.uiStringStiffness;
          currentPreset.restLength = app.uiRestLength;
          currentPreset.particleCount = app.uiParticleCount;
          std::string path = ResourceHelper::getResourcePath("presets/" + presetFiles[selectedPresetIdx]);
          PresetManager::savePreset(path, currentPreset);
        }
        ImGui::Unindent();
      }

      if (ImGui::CollapsingHeader("SIMULATION",
                                  ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Indent();

        // Removed SimMode and SphereMode

        if (ImGui::Checkbox("Collisions", &app.uiCollisions)) {
          renderer.setCollisionsEnabled(app.uiCollisions);
        }
        ImGui::SetItemTooltip("Enable particle-particle elastic collisions");

        ImGui::Checkbox("Phase Viz", &app.uiPhaseViz);
        ImGui::SetItemTooltip(
            "Color particles by Feynman phase (action integral)");

        ImGui::Checkbox("Ortho Camera", &app.uiOrthoMode);
        ImGui::SetItemTooltip(
            "Toggle between Orthographic (HTML vibe) and Perspective");

        UiSliderFloat("Size", &app.uiParticleSize, 0.5f, 10.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiParticleSize = 2.0f;
        ImGui::SetItemTooltip("Physical radius of each particle");

        UiSliderInt("Amount", &app.uiParticleCount, 0, 10000000);
        if (ImGui::Button("Reset to Default")) {
          app.uiParticleCount = 2000000;
        }
        ImGui::SetItemTooltip("Active number of particles");

        UiSliderFloat("BH Size", &app.uiShadowRadius, 0.3f, 5.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiShadowRadius = 2.4f;
        ImGui::SetItemTooltip(
            "Black-hole shadow radius (sim coords). Physical value ~2.6; "
            "lower reads proportional to the disk.");

        UiSliderFloat("Sharpness", &app.uiSharpness, 1.0f, 40.0f, "%.1f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiSharpness = 5.0f;
        ImGui::SetItemTooltip(
            "Particle grain sharpness (Gaussian falloff). Low = soft/blurry, "
            "high = crisp/tight. Live.");

        UiSliderFloat("Grain", &app.uiGrainAlpha, 0.01f, 1.0f, "%.3f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiGrainAlpha = 0.08f;
        ImGui::SetItemTooltip(
            "Per-particle opacity. Higher = each grain reads solid; lower = "
            "fainter, blends more. Live.");

        ImGui::Unindent();
      }

      if (ImGui::CollapsingHeader("NEW SCIENCE (Phase 9)",
                                  ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Indent();
        ImGui::Checkbox("ODS-06 Black Holes", &app.uiBlackHoles);
        ImGui::SetItemTooltip("Enable gravitational collapse "
                              "(Schwarzschild "
                              "radius) at high density");
        ImGui::Unindent();
      }

      if (ImGui::CollapsingHeader("INDUSTRY DEBUGGING (Phase 7)")) {
        ImGui::Indent();

        auto stats = renderer.getPhysicsStats();
        if (stats.errorState > 0) {
          ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1.0f, 0.2f, 0.2f, 1.0f));
          ImGui::Text("!!! PHYSICAL ASSERT FAILED !!!");
          ImGui::Text(stats.errorState == 1 ? "Error: NaN Detected"
                                            : "Error: Energy Explosion");
          ImGui::PopStyleColor();

          if (app.uiAutoMode) {
            ImGui::TextColored(ImVec4(1, 0.5, 0, 1),
                               "Auto-Mitigation Active...");
          }
        } else {
          ImGui::TextColored(ImVec4(0.2f, 1.0f, 0.2f, 1.0f),
                             "Physics Core: OK");
        }

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
        ImGui::Checkbox("Enable VJ Mode (Mic/System In)", &app.uiVJMode);
        ImGui::SetItemTooltip("Visualize incoming audio using "
                              "16-band FFT harmonic sculpting");

        if (app.uiVJMode) {
          if (UiSliderFloat("Input Gain", &app.uiInputGain, 0.1f, 10.0f,
                                 "%.2f x")) {
            audio.setVJInputGain(app.uiInputGain);
          }
          if (ImGui::IsItemClicked(ImGuiMouseButton_Right)) {
            app.uiInputGain = 2.0f;
            audio.setVJInputGain(app.uiInputGain);
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

        if (UiSliderFloat("Drive", &app.uiScale, 1.0f, 10.0f, "%.1f")) {
          // This was previously mislabeled as
          // 'Scale' in one place and 'Drive' in
          // another. Let's use it for Scale (as
          // requested) and move Drive to a separate
          // slider if needed.
          renderer.setScale(app.uiScale);
        }
        ImGui::SetItemTooltip("Filter saturation and analog clipping "
                              "(Moog-style)");

        if (ImGui::Checkbox("BBD Chorus", &app.uiChorus)) {
          synth.chorus().setEnabled(app.uiChorus);
        }
        ImGui::SetItemTooltip("Lush stereo bucket-brigade dual delay");

        if (app.uiChorus) {
          ImGui::Indent();
          float cRate = synth.chorus().rate();
          if (UiSliderFloat("LFO Rate##Chorus", &cRate, 0.1f, 10.0f, "%.2f Hz")) {
            synth.chorus().setRate(cRate);
          }
          float cDepth = synth.chorus().depth();
          if (UiSliderFloat("LFO Depth##Chorus", &cDepth, 0.0f, 10.0f, "%.2f ms")) {
            synth.chorus().setDepth(cDepth);
          }
          float cMix = synth.chorus().mix();
          if (UiSliderFloat("Chorus Mix", &cMix, 0.0f, 1.0f, "%.2f")) {
            synth.chorus().setMix(cMix);
          }
          ImGui::Unindent();
        }

        UiSliderFloat("Attack", &app.uiAttack, 5.0f, 500.0f, "%.0f ms");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiAttack = 20.0f;
        ImGui::SetItemTooltip("Envelope attack duration");
        synth.envelopeParams().attack = app.uiAttack / 1000.0f;

        UiSliderFloat("Decay", &app.uiDecay, 5.0f, 1000.0f, "%.0f ms");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiDecay = 100.0f;
        ImGui::SetItemTooltip("Envelope decay duration");
        synth.envelopeParams().decay = app.uiDecay / 1000.0f;

        UiSliderFloat("Sustain", &app.uiSustain, 0.0f, 1.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiSustain = 0.7f;
        ImGui::SetItemTooltip("Sustain level — controls visual expansion size");
        synth.envelopeParams().sustain = app.uiSustain;

        UiSliderFloat("Release", &app.uiRelease, 1.0f, 2000.0f, "%.0f ms");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiRelease = 400.0f;
        ImGui::SetItemTooltip("Envelope release duration");
        synth.envelopeParams().release = app.uiRelease / 1000.0f;

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
        UiSliderFloat("Jitter (not linked)", &app.uiJitter, 0.0f, 5.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiJitter = 1.0f;
        ImGui::SetItemTooltip("WARNING: not properly linked yet — no reliable "
                              "visible effect. Kept for re-wiring later.");

        ImGui::Separator();
        ImGui::Text("GLOBAL LFO");
        UiSliderFloat("LFO Rate", &app.uiLFORate, 0.01f, 10.0f, "%.2f Hz");
        UiSliderFloat("LFO Depth", &app.uiLFODepth, 0.0f, 1.0f, "%.2f");
        ImGui::SetItemTooltip("Modulates Jitter, Size, and Scale over time");

        ImGui::Unindent();
      }

      if (ImGui::CollapsingHeader("GEOMETRY", ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Indent();
        if (UiSliderFloat("Space Scale", &app.uiScale, 10.0f, 2000.0f,
                               "%.0f")) {
          renderer.setScale(app.uiScale);
        }
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right)) {
          app.uiScale = 100.0f;
          renderer.setScale(app.uiScale);
        }
        ImGui::SetItemTooltip("Global cosmic scale "
                              "(Expansion/Contraction)");

        UiSliderFloat("Wave Depth", &app.uiWaveDepth, 5.0f, 100.0f, "%.1f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiWaveDepth = 20.0f;
        ImGui::SetItemTooltip("Vibrational displacement intensity");

        if (ImGui::Button("Reset Camera")) {
          camera.reset();
        }
        ImGui::SameLine();
        if (ImGui::Button("Snap Back (Reset)")) {
          renderer.triggerReset();
        }
        // Live camera angles. Arrow keys ←/→ rotate azimuth (φ),
        // ↑/↓ rotate elevation (θ). Soft-locks at 0°/90°/180°/270°.
        {
          const float RAD2DEG = 180.0f / M_PI_F;
          float phiDeg   = camera.getPhi()   * RAD2DEG;
          float thetaDeg = camera.getTheta() * RAD2DEG;
          ImGui::Text("Azimuth φ : %+7.2f°   (←/→)", phiDeg);
          ImGui::Text("Elevation θ: %+7.2f°   (↑/↓)", thetaDeg);
          ImGui::Text("Distance ρ : %.1f",            camera.getRho());
        }
        ImGui::SetItemTooltip("Instantly re-seed all particles into "
                              "center");

        ImGui::Unindent();
      }

      if (ImGui::CollapsingHeader("POST-FX", ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Indent();
        UiSliderFloat("Bloom", &app.uiBloom, 0.0f, 1.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiBloom = 0.0f;
        ImGui::SetItemTooltip("Cross-shaped bright-pass glow");

        UiSliderFloat("Fluidity", &app.uiTrailDecay, 0.0f, 0.99f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiTrailDecay = 0.0f;
        ImGui::SetItemTooltip("Motion trails (Feedback factor)");

        UiSliderFloat("Chromatic", &app.uiChromatic, 0.0f, 0.02f, "%.3f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiChromatic = 0.0f;
        ImGui::SetItemTooltip("RGB split lens effect");

        ImGui::SeparatorText("CYBERPUNK / TECHNO");

        UiSliderFloat("Glitch", &app.uiGlitch, 0.0f, 1.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiGlitch = 0.0f;
        ImGui::SetItemTooltip("Datamosh RGB block tear (beat-reactive)");

        UiSliderFloat("Scanlines", &app.uiScanlines, 0.0f, 1.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiScanlines = 0.0f;
        ImGui::SetItemTooltip("CRT scanlines");

        UiSliderFloat("Neon Grade", &app.uiNeonGrade, 0.0f, 1.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiNeonGrade = 0.0f;
        ImGui::SetItemTooltip("Cyberpunk color grade (indigo/magenta/cyan)");

        UiSliderFloat("Vignette", &app.uiVignette, 0.0f, 1.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiVignette = 0.0f;
        ImGui::SetItemTooltip("Cinematic edge darkening");
        ImGui::Unindent();
      }

      if (ImGui::CollapsingHeader("VJ FX (Resolume-style)",
                                  ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Indent();
        const char *mirrorNames[] = {"Off", "Horizontal", "Vertical", "Quad"};
        ImGui::Combo("Mirror", &app.uiMirrorMode, mirrorNames, 4);
        ImGui::SetItemTooltip("Fold the image onto itself");

        UiSliderInt("Kaleidoscope", &app.uiKaleido, 0, 16);
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiKaleido = 0;
        ImGui::SetItemTooltip("Radial segments (0 = off)");

        UiSliderInt("Tile", &app.uiTile, 1, 8);
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiTile = 1;
        ImGui::SetItemTooltip("NxN repeat (1 = off)");

        UiSliderFloat("Twirl", &app.uiTwirl, -1.0f, 1.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiTwirl = 0.0f;
        ImGui::SetItemTooltip("Swirl distortion");

        UiSliderFloat("Hue Shift", &app.uiHueShift, 0.0f, 1.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiHueShift = 0.0f;
        ImGui::SetItemTooltip("Rotate all colours");

        UiSliderFloat("Strobe", &app.uiStrobe, 0.0f, 1.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiStrobe = 0.0f;
        ImGui::SetItemTooltip("Beat-reactive flash");

        UiSliderFloat("Invert", &app.uiInvert, 0.0f, 1.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiInvert = 0.0f;
        ImGui::SetItemTooltip("Colour invert mix");

        UiSliderInt("Posterize", &app.uiPosterize, 0, 16);
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiPosterize = 0;
        ImGui::SetItemTooltip("Quantize colours (0 = off)");

        UiSliderFloat("Blur", &app.uiBlur, 0.0f, 1.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiBlur = 0.0f;
        ImGui::SetItemTooltip("Multi-pass Gaussian blur (ping-pong HDR)");
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
        ImGui::Text("dt: %f | Particles: %d", dt, app.uiParticleCount);
        ImGui::Text("Total Amplitude: %.3f", synth.totalAmplitude());

        ImGui::Unindent();
      }

      ImGui::Spacing();
      ImGui::Separator();
      ImGui::TextDisabled("FPS: %.1f | Particles: %dk",
                          ImGui::GetIO().Framerate, app.uiParticleCount / 1000);
      ImGui::End();
    } // if (showHUD)

    // ── MASTER PATCH — every valuable fader in one window, for dialing the
    // default patch. Double-click any value to type it exactly. ──────────
    if (showHUD) {
      ImGui::SetNextWindowPos(ImVec2(390, 30), ImGuiCond_FirstUseEver);
      ImGui::SetNextWindowSize(ImVec2(300, 0), ImGuiCond_FirstUseEver);
      ImGui::Begin("MASTER PATCH");

      // ── Tempometer: live spin speed ──────────────────────────────────
      {
        float spinMag = std::sqrt(spinVelX * spinVelX + spinVelY * spinVelY);
        float hz = spinMag / 6.28319f; // rad/s → Hz (revolutions/sec)
        float frac = spinMag / 188.0f;
        ImGui::TextColored(ImVec4(0.5f, 0.85f, 1.0f, 1.0f),
                           "%s  %.1f Hz   %.0f rad/s",
                           frac > 0.98f ? "⟳ LOCKED" : "⟳ SPIN", hz, spinMag);
        char ov[32];
        snprintf(ov, sizeof(ov), "%.0f%%", frac * 100.0f);
        ImGui::ProgressBar(frac, ImVec2(-1.0f, 0.0f), ov);
      }

      ImGui::SeparatorText("Particles");
      UiSliderFloat("Size##mp", &app.uiParticleSize, 0.5f, 10.0f, "%.2f");
      UiSliderInt("Amount##mp", &app.uiParticleCount, 0, 10000000);
      UiSliderFloat("Sharpness##mp", &app.uiSharpness, 1.0f, 40.0f, "%.1f");
      UiSliderFloat("Grain##mp", &app.uiGrainAlpha, 0.01f, 1.0f, "%.3f");
      UiSliderFloat("Jitter##mp", &app.uiJitter, 0.0f, 5.0f, "%.2f");

      ImGui::SeparatorText("Black Hole");
      UiSliderFloat("BH Size##mp", &app.uiShadowRadius, 0.3f, 5.0f, "%.2f");
      UiSliderFloat("Disk Thickness##mp", &app.uiDiskThickness, 0.02f, 1.0f, "%.3f");

      ImGui::SeparatorText("Motion");
      if (UiSliderFloat("Space Scale##mp", &app.uiScale, 10.0f, 2000.0f, "%.0f"))
        renderer.setScale(app.uiScale);
      UiSliderFloat("Wave Depth##mp", &app.uiWaveDepth, 5.0f, 100.0f, "%.1f");
      UiSliderFloat("LFO Rate##mp", &app.uiLFORate, 0.01f, 10.0f, "%.2f");
      UiSliderFloat("LFO Depth##mp", &app.uiLFODepth, 0.0f, 1.0f, "%.2f");

      ImGui::SeparatorText("Look");
      UiSliderFloat("Bloom##mp", &app.uiBloom, 0.0f, 1.0f, "%.2f");
      UiSliderFloat("Fluidity##mp", &app.uiTrailDecay, 0.0f, 0.99f, "%.2f");
      UiSliderFloat("Chromatic##mp", &app.uiChromatic, 0.0f, 0.02f, "%.3f");
      UiSliderFloat("Vignette##mp", &app.uiVignette, 0.0f, 1.0f, "%.2f");

      ImGui::Separator();
      if (ImGui::Button("Print Values to Log")) {
        printf("[PATCH] size=%.2f count=%d sharp=%.1f grain=%.3f jitter=%.2f "
               "bhSize=%.2f disk=%.3f scale=%.0f wave=%.1f lfoRate=%.2f "
               "lfoDepth=%.2f bloom=%.2f fluidity=%.2f chroma=%.3f vign=%.2f\n",
               app.uiParticleSize, app.uiParticleCount, app.uiSharpness,
               app.uiGrainAlpha, app.uiJitter, app.uiShadowRadius,
               app.uiDiskThickness, app.uiScale, app.uiWaveDepth, app.uiLFORate,
               app.uiLFODepth, app.uiBloom, app.uiTrailDecay, app.uiChromatic,
               app.uiVignette);
      }
      ImGui::SetItemTooltip("Dump all current fader values to the console/log "
                            "so they can be baked in as defaults.");

      ImGui::End();
    }

    // ── Apply Audio-Visual Macros ─────────────────────────────────────
    // Calculate effective values
    float effectiveSize = app.uiParticleSize;
    float effectiveDrive = synth.drive();
    float effectiveJitterMultiplier = 1.0f;

    // Push volatile settings back into synth
    synth.setJitter(app.uiJitter * effectiveJitterMultiplier);
    synth.setDrive(effectiveDrive);

    // Update Global LFO
    app.uiLFOPhase =
        std::fmod(app.uiLFOPhase + dt * app.uiLFORate * M_PI_F * 2.0f, M_PI_F * 2.0f);
    float lfoVal = sin(app.uiLFOPhase) * app.uiLFODepth;

    config.particleSize = effectiveSize * (1.0f + lfoVal * 0.2f);
    config.plateRadius = app.uiScale * (1.0f + lfoVal * 0.1f);
    config.cameraRho = camera.getRho();
    config.cameraPos[0] = camera.getX();
    config.cameraPos[1] = camera.getY();
    config.cameraPos[2] = camera.getZ();
    config.jitterFactor =
        app.uiJitter * effectiveJitterMultiplier * (1.0f + lfoVal * 0.5f);
    config.orthoMode = app.uiOrthoMode;
    config.phaseViz = app.uiPhaseViz;
    config.shadowRadius = app.uiShadowRadius;

    // ── Update ADSR (Phase 12.6) ──────────────────────────────────
    synth.envelopeParams().attack = app.uiAttack / 1000.0f;
    synth.envelopeParams().release = app.uiRelease / 1000.0f;
    // Supernova adds on top of user slider values
    config.bloomIntensity = app.uiBloom;
    // Spin blurs into a solid disk at high RPM: boost the motion-blur feedback
    // with spin speed so fast rotation smears instead of strobing.
    config.trailDecay = app.uiTrailDecay; // no spin smear — oscilloscope is a crisp path, not blur
    config.sharpness = app.uiSharpness;
    config.grainAlpha = app.uiGrainAlpha;
    config.chromaticAmount = app.uiChromatic;
    // Creative FX + beat reactivity
    app.uiFxTime += dt;
    config.glitchAmount = app.uiGlitch;
    config.scanlineAmount = app.uiScanlines;
    config.neonGrade = app.uiNeonGrade;
    config.vignette = app.uiVignette;
    config.fxTime = app.uiFxTime;
    config.audioLevel = std::min(1.0f, synth.totalAmplitude());
    // VJ FX
    config.mirrorMode = (float)app.uiMirrorMode;
    config.kaleidoSegments = (float)app.uiKaleido;
    config.tileCount = (float)app.uiTile;
    config.twirl = app.uiTwirl;
    config.hueShift = app.uiHueShift;
    config.strobe = app.uiStrobe;
    config.invert = app.uiInvert;
    config.posterize = (float)app.uiPosterize;
    config.blurAmount = app.uiBlur;

    // ── Update ADSR ────────────────────────────────────────────────
    synth.envelopeParams().attack = app.uiAttack / 1000.0f;
    synth.envelopeParams().release = app.uiRelease / 1000.0f;

    // ── Update Physics ──────────────────────────────────────────────
    renderer.setActiveParticleCount(app.uiParticleCount);

    // Build Debug Flags bitmask
    uint32_t debugFlags = 0;
    if (app.uiSoloEField)
      debugFlags |= DEBUG_E_FIELD;
    if (app.uiSoloBField)
      debugFlags |= DEBUG_B_FIELD;
    if (app.uiSoloGravity)
      debugFlags |= DEBUG_GRAVITY;
    if (app.uiSoloStrings)
      debugFlags |= DEBUG_STRINGS;
    if (app.uiSoloJitter)
      debugFlags |= DEBUG_JITTER;
    if (app.uiSoloCollisions)
      debugFlags |= DEBUG_COLLISIONS;
    if (app.uiFixedTimestep)
      debugFlags |= DEBUG_FIXED_DT;
    if (app.uiQuantumEntangle)
      debugFlags |= DEBUG_ODS01;
    if (app.uiBlackHoles)
      debugFlags |= DEBUG_ODS06;

    // ── Auto-Stabilizer Supervisor (Phase 8) ────────────────────────
    auto stats = renderer.getPhysicsStats();
    if (app.uiAutoMode && stats.errorState > 0) {
      // Step 1: Immediate parameter mitigation (dial down stress)
      app.uiEField *= 0.5f;
      app.uiBField *= 0.5f;
      app.uiGravity *= 0.8f;

      // Step 2: If we have NaNs, we MUST reset the hardware state
      if (stats.errorState == 1) {
        renderer.resetParticles();
      }

      // Step 3: Log to console (silent unless debugging)
      // printf("[AUTO-MODE] Instability detected. Mitigating...\n");
    }

    // Phase 17: Wire ADSR lifecycle to black hole dynamics
    auto envState = synth.getDominantEnvelope();

    // VJ mode: if VJ bands are driving voices but synth is silent,
    // override envelope to sustain so GPU doesn't gate forces
    if (app.uiVJMode && envState.phase < 0.5f && !voiceData.empty()) {
        float vjMaxAmp = 0.0f;
        for (const auto& vd : voiceData) vjMaxAmp = std::max(vjMaxAmp, vd.amplitude);
        envState.phase = 3.0f;     // Sustain
        envState.progress = 1.0f;  // Fully in sustain
        envState.intensity = vjMaxAmp;
    }

    renderer.setEnvelopeState(envState.phase, envState.progress,
                              envState.intensity);
    renderer.setDiskThickness(app.uiDiskThickness);

    // Pass envelope state to config for shaders
    config.envelopePhase = envState.phase;
    config.envelopeProgress = envState.progress;

    float effectiveTotalAmp = synth.totalAmplitude();
    if (app.uiVJMode) {
        for (const auto& vd : voiceData) effectiveTotalAmp += vd.amplitude;
    }

    // Phase 1A: Smoothed amplitude envelope (attack-release)
    // Prevents jarring jumps and ensures particles have time to respond
    static float smoothedAmp = 0.0f;
    float rise = 0.25f, decay = 0.12f;
    if (effectiveTotalAmp > smoothedAmp)
        smoothedAmp = rise * effectiveTotalAmp + (1.0f - rise) * smoothedAmp;
    else
        smoothedAmp = decay * effectiveTotalAmp + (1.0f - decay) * smoothedAmp;

    renderer.computeStep(dt, voiceData.data(), (int)voiceData.size(),
                         smoothedAmp, app.uiWaveDepth,
                         app.uiJitter * effectiveJitterMultiplier, effectiveDrive,
                         app.uiEField, app.uiBField, app.uiGravity, app.uiStringStiffness,
                         app.uiRestLength, debugFlags);

    renderer.render(config, viewProj);

    // FPS
    frameCount++;
    // Real wall-clock FPS — NOT the physics dt (which is clamped to 0.033s in
    // window.mm and would falsely cap the reported rate at ~30).
    auto fpsNow = std::chrono::steady_clock::now();
    float fpsElapsed = std::chrono::duration<float>(fpsNow - fpsLastTime).count();
    if (fpsElapsed >= 1.0f) {
      fps = (int)(frameCount / fpsElapsed + 0.5f);
      frameCount = 0;
      fpsLastTime = fpsNow;

      int vc = synth.activeVoiceCount();
      if (vc > 0) {
        char buf[256];
        snprintf(buf, sizeof(buf), "FPS: %d | Particles: %dk | Voices: %d | Amp: %.2f", 
                 fps, app.uiParticleCount / 1000, vc, synth.totalAmplitude());
        Logger::log(buf);
        printf("\n%s    ", buf);
      } else {
        char buf[256];
        snprintf(buf, sizeof(buf), "FPS: %d | Particles: %dk | Ready", 
                 fps, app.uiParticleCount / 1000);
        Logger::log(buf);
        printf("\n%s    ", buf);
      }

      // ── Auto GPU Readback Probe — sample 1000, classify ──
      const int PROBE_N = 1000;
      static std::vector<GPUParticle> probe(PROBE_N);
      renderer.readbackParticles(probe.data(), PROBE_N);
      int liveCount = 0, wallCount = 0, insideRS = 0, movingCount = 0;
      int liveBand[10] = {0};
      for (int i = 0; i < PROBE_N; i++) {
        const auto &p = probe[i];
        bool isWall = p.mass < 0.001f;
        float r = std::sqrt(p.x*p.x + p.y*p.y + p.z*p.z);
        float v = std::sqrt(p.vx*p.vx + p.vy*p.vy + p.vz*p.vz);
        if (isWall) wallCount++;
        else {
          liveCount++;
          if (r < 0.40f) insideRS++;
          if (v > 1e-5f) movingCount++;
          int bucket = std::min(9, (int)(r / 0.4f));
          liveBand[bucket]++;
        }
      }
      printf("\n  [PROBE-%d] live=%d walls=%d insideRS=%d moving=%d  "
             "envPhase=%.1f voices=%d\n",
             PROBE_N, liveCount, wallCount, insideRS, movingCount,
             config.envelopePhase, vc);
      printf("  [BAND] r<0.4:%d  0.4-0.8:%d  0.8-1.2:%d  1.2-1.6:%d  1.6-2.0:%d  2.0+:%d\n",
             liveBand[0], liveBand[1], liveBand[2], liveBand[3], liveBand[4],
             liveBand[5]+liveBand[6]+liveBand[7]+liveBand[8]+liveBand[9]);

      fflush(stdout);
    }

  });

  window.run();

  Logger::log("Application Session End");
  Logger::exportToDownloads();

  printf("\n");
  return 0;
}
