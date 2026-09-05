#include "audio/audio_engine.h"
#include "audio/synth.h"
#include "core/camera.h"
#include "core/emitter.h"
#include "core/midi_input.h"
#include "core/take_recorder.h"
#include "core/offline_clock.h"
#include "render/show_capture.h"   // S8: ProRes writer, armed by SS_CAPTURE
#include "core/take_replay.h"
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
#include "core/physics_constants.h"
#include "core/units.h" // space::units::kTimeLapse for the UNIVERSE TIME readout
#include <algorithm>
#include <cmath>
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
  // S1 (2026-08-21): the render pipeline, the postfx chain and the SYPHON FEED
  // are all sized from the drawable (renderer.mm:1151, :4515), so the window's
  // aspect ratio IS the output's aspect ratio. The Cologne wall is 10x4 m =
  // 2.5:1, and anything RECORDED at the wrong shape is wrong permanently.
  // Same env-var idiom as SS_FULLSCREEN / SS_SOR_SWEEPS. Example:
  //   open -n SpaceSynth.app --env SS_WIDTH=2560 --env SS_HEIGHT=1024
  int winW = 1280, winH = 800;
  // S5 (2026-09-03): the upper bound is MEASURED on the GPU, not typed. The
  // old 16384 refused his 19,644-wide wall (5340 + 2×7152) while the M5 Max
  // rasterizes it (probe: clear + readback exact at 19644×1680 and 32768 wide).
  // A size the device cannot allocate is refused LOUDLY, never silently
  // rendered at 1280x800 — that was the failure the constant produced.
  if (const char *ew = getenv("SS_WIDTH")) {
    int v = atoi(ew);
    if (v >= 320) winW = v;
    else fprintf(stderr, "[S1] SS_WIDTH=%s below 320, ignored\n", ew);
  }
  if (const char *eh = getenv("SS_HEIGHT")) {
    int v = atoi(eh);
    if (v >= 240) winH = v;
    else fprintf(stderr, "[S1] SS_HEIGHT=%s below 240, ignored\n", eh);
  }
  // S8 (2026-09-03): the RENDER size and the PRESENTED size are two numbers.
  // MEASURED 18:22: the layer refuses a drawable above 16,384 wide while every
  // offscreen texture allocates at 19,644. So the pinned size is the RENDER
  // size (renderer.pinRenderSize below); the drawable is the largest exact
  // half (1/2, 1/4, 1/8) the layer will present — same aspect by construction,
  // which matters because the camera aspect reads the drawable. Presentable
  // as-is ⇒ preview == render, exactly as S5 had it.
  int renderW = 0, renderH = 0;
  if (getenv("SS_WIDTH") || getenv("SS_HEIGHT")) {
    renderW = winW; renderH = winH;
    int div = 1;
    while (div <= 8 && !Window::canAllocateDrawable(renderW / div, renderH / div)) div *= 2;
    if (div > 8) {
      fprintf(stderr, "[S1] 🚨 SS_WIDTH/SS_HEIGHT %dx%d REFUSED: this GPU cannot allocate or present a drawable of "
                      "that size or any half of it down to 1/8 (see the lines above). Not pinning; the window "
                      "follows the screen.\n", renderW, renderH);
      winW = 1280; winH = 800; renderW = 0; renderH = 0;
      unsetenv("SS_WIDTH"); unsetenv("SS_HEIGHT");
    } else {
      winW = renderW / div; winH = renderH / div;
      if (div > 1)
        printf("[S8] render %dx%d exceeds what the layer presents: drawable pinned to the 1/%d preview %dx%d\n",
               renderW, renderH, div, winW, winH);
    }
  }
  // PIN the render buffer to exactly this many pixels. Without the pin macOS
  // clamps the WINDOW to the screen and the drawable follows it — measured
  // 2026-08-21: 2560x1024 requested, 3600x2048 rendered, the wrong aspect.
  // window.mm prints the buffer size and the preview scale together.
  if (getenv("SS_WIDTH") || getenv("SS_HEIGHT")) window.pinDrawableSize(winW, winH);
  if (!window.create(winW, winH, "SPACE Synth v1.0 [STABLE]")) {
    fprintf(stderr, "Failed to create window\n");
    return 1;
  }
  Logger::log("Application Started: SPACE Synth v1.0 [STABLE]");

  // Style metrics follow the UI scale (physical DPI), NOT the backing scale.
  // At 3024x1964 in a 1x mode backingScaleFactor is 1.0, which told the theme
  // nothing about the panel being 255 ppi — hence a microscopic UI.
  space::UITheme::ApplyPremiumTheme(window.getUIScale());

  // ── Renderer ────────────────────────────────────────────────────────
  Renderer renderer;
  if (!renderer.init(window.metalDevice(), window.metalLayer(), window.width(),
                     window.height())) {
    fprintf(stderr, "Failed to init Metal renderer\n");
    return 1;
  }
  // S5 (2026-09-03, his ruling): when the drawable is PINNED for a render,
  // the sprite-size reference is the DELIVERY height — 1680, his wall — so
  // full res is 1.0 and half res 0.5: the same picture, smaller; the 840
  // preview he composes against IS the render. SS_REF_HEIGHT overrides.
  // Not pinned ⇒ the renderer keeps its live reference (2260) untouched.
  if (getenv("SS_WIDTH") || getenv("SS_HEIGHT")) {
    float ref = 1680.0f;
    if (const char *r = getenv("SS_REF_HEIGHT")) {
      float v = (float)atof(r);
      if (v >= 1.0f) ref = v;
      else fprintf(stderr, "[SIZE] SS_REF_HEIGHT=%s invalid, keeping %.0f\n", r, ref);
    }
    renderer.setSizeReferenceHeight(ref);
    printf("[SIZE] pinned render: sprite-size reference height = %.0f (delivery height; SS_REF_HEIGHT overrides). "
           "Full res %dx%d -> scale %.4f\n", ref, renderW, renderH, (double)renderH / ref);
    // S8: every target at the RENDER size, final pass offscreen, drawable = preview.
    renderer.pinRenderSize(renderW, renderH);
  }
  // S8: the writer. Armed only by SS_CAPTURE + a pinned render + the offline
  // clock; reads the renderer's offscreen SDR frame, one frame per output tick.
  space::ShowCapture showCap;
  if (getenv("SS_CAPTURE")) {
    if (renderW <= 0)
      fprintf(stderr, "[CAPTURE] SS_CAPTURE refused: no pinned render (set SS_WIDTH/SS_HEIGHT).\n");
    else if (showCap.open(renderW, renderH,
                          space::OfflineClock::get().enabled ? space::OfflineClock::get().fps : 0,
                          renderer.getMetalDevice()))
      renderer.setCapture(&showCap);
  }

  // ── TWO-WINDOW MODE (2026-08-23, his order) ───────────────────────────────
  // "i cant have the settings in the same window im sending out. just gimme two
  //  windows mode and if its two windows all the settings are in the same
  //  sizable window and the synth is just synth."
  // SS_TWO_WINDOWS=1 puts the whole ImGui UI in its own freely resizable
  // window; the main window then renders nothing but the show. Same env-var
  // idiom as SS_FULLSCREEN. Off = the old single-window behaviour, untouched.
  // Press I at any time to toggle. SS_TWO_WINDOWS=1 just starts in that mode.
  if (getenv("SS_TWO_WINDOWS")) {
    if (!window.toggleSettingsWindow())
      fprintf(stderr, "[UI] SS_TWO_WINDOWS set but the settings window could "
                      "not be created — staying single-window.\n");
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
  // S9 OFFLINE: the envelope (attack/decay/sustain/release, totalAmplitude —
  // 12 render branches gate on them) advances INSIDE Synth::processBlock,
  // which CoreAudio pulls in REAL time. A render slower than real time would
  // let a note release while the frame clock is still in its attack. So
  // offline the engine is NOT started and the frame callback steps the synth
  // itself, sampleRate/fps samples per output frame (48000/30 = 1600 exactly),
  // into a scratch buffer — the video carries no audio, Ableton has it.
  const bool kOfflineAudio = space::OfflineClock::get().enabled;
  if (kOfflineAudio) {
    printf("[OFFLINE] audio engine NOT started; synth stepped %d samples per output frame on the frame clock "
           "(envelope advances exactly 1/%d s per frame)\n",
           48000 / space::OfflineClock::get().fps, space::OfflineClock::get().fps);
  } else if (!audio.start(0, 48000)) {
    fprintf(stderr, "[FATAL ERROR] Audio Engine failed to start! Check your "
                    "hardware permissions.\n");
  } else {
    printf("[AUDIO] Engine started successfully.\n");
  }

  // Moved up from its old spot near the HUD state (was line 366) so the CC
  // ride mapping below (2026-09-04) can capture it by reference — the S6-lite
  // apply attaches to the MIDI callback, which is built before the HUD block.
  // Plain data struct, default-initialized; nothing between here and its old
  // position depended on the old order.
  static space::AppState app;

  // ── MIDI Input ──────────────────────────────────────────────────────
  MidiInput midiInput;
  // S2: the take recorder. push() is the only thing added to the MIDI thread —
  // one ring slot, no lock, no malloc, no file. Drained and written on the
  // main thread (frame callback + after window.run()). Disarmed unless
  // SS_RECORD=<path>; prints its marker CC at launch either way.
  space::TakeRecorder takeRec;
  // The ONE consumer of MidiEvent (S1, 2026-09-03). Notes reach the synth
  // exactly as before; CC is delivered and printed but has no consumer yet —
  // the mapping apply (S6) attaches HERE, not to a second callback. `t` is
  // absolute seconds (CACurrentMediaTime timebase), `stamped` says whether it
  // came from the packet or from callback entry.
  // Named so S4's replay calls the SAME callable from the frame callback —
  // one code path for a live event and a replayed one, by construction.
  std::function<void(const space::MidiEvent &)> onMidi = [&](const space::MidiEvent &ev) {
    takeRec.push(ev);
    switch (ev.kind) {
    case space::MidiKind::NoteOn: {
      float velocity = ev.b / 127.0f;
      synth.noteOn(ev.a, velocity);
      printf("[MIDI] noteOn  note=%d vel=%.2f ch=%d voices=%d\n", ev.a, velocity,
             ev.channel, synth.activeVoiceCount());
      break;
    }
    case space::MidiKind::NoteOff:
      synth.noteOff(ev.a);
      printf("[MIDI] noteOff note=%d ch=%d\n", ev.a, ev.channel);
      break;
    case space::MidiKind::CC: {
      printf("[MIDI] cc num=%d val=%d ch=%d t=%.6f%s\n", ev.a, ev.b, ev.channel,
             ev.t, ev.stamped ? "" : " (unstamped)");
      // ── CC RIDE TEST (his order 2026-09-04 ~02:5x, relayed by BRAIN) ──────
      // Six FADER parameters from his list only: zoom, camera up/down,
      // exposure, fluid, glitch, chromatic. `pause` excluded on purpose — his
      // own words, "must be a on off switch in midi not a 1-127 value", and
      // the registry has no switch type yet (board §AA18, his call to make).
      // Hardcoded CC numbers for THIS TEST, not the S6 registry — the
      // smallest thing that answers whether a ride works at all. Runs on the
      // MIDI thread same as noteOn/noteOff above, so it applies whether the
      // HUD is shown or hidden — no showHUD dependency to satisfy.
      static double lastLogT[12] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
      static const char *const kName[12] = {
          "zoom",      "camTilt",   "exposure",    "fluid",  "glitch",
          "chromatic", "iscoOrbit", "thetaSpin",   "camPhi", "phaseAmount",
          "thetaRange", "spinRate"};
      // 14-bit zoom (2026-09-04 ~12:30, his verdict "back and forth zoomies,
      // not one consistent ride"): the real take's own log showed the 7-bit
      // step gap running 3.4-98.4s (measured, not the ~1.4s first assumed)
      // against a 0.5s-settle critically-damped spring -- the camera fully
      // stopped between every CC step. Standard MIDI 14-bit pairing, CC20
      // MSB + CC52 LSB.
      // ⚠️ LATCH FIX (2026-09-04 ~13:5x): applying on EITHER half (the
      // original take-3-prep version) let a fresh MSB apply immediately
      // against a STALE cached LSB for a moment before the real LSB caught
      // up -- OPUS measured 23 such lurches (~15 rho, <1ms each) in take 2.
      // Now MSB only CACHES; the apply happens on LSB, which is always the
      // fresher, complete pair. `everApplied` is the coarse-sender fallback:
      // the very FIRST MSB this run applies immediately (coarse, lsb=0) so a
      // 7-bit-only sender that never sends the LSB half still moves the
      // camera once, instead of sitting dead forever waiting for a byte that
      // isn't coming. Same pattern reused for thetaSpin below.
      static uint8_t zoomMSB = 0, zoomLSB = 0;
      static bool zoomEverApplied = false;
      static uint8_t thetaMSB = 0, thetaLSB = 0;
      static bool thetaEverApplied = false;
      static uint8_t spinMSB = 0, spinLSB = 0;
      // THETA RANGE SELECTOR (2026-09-04 ~15:12, OPUS's catch): the 14-bit
      // pair always maps v14/16383 onto [0, thetaRangeMax) -- a 90deg tilt
      // that only ever SENDS v14 up to a quarter of 16383 wastes 3/4 of the
      // quantization density, reproducing take-1's stepping (measured:
      // 32 crossings over 4800 frames, one per 150 -- the spring's tail
      // cannot bridge that). The fix is on the RECEIVER: let the driver
      // always send the FULL 0-16383 range for maximum density, and have
      // THIS side scale it to whatever span the shot needs. Default is the
      // orbit's full turn (2pi) so the orbit driver needs no new CC at all;
      // CC33 nonzero switches it to pi/2 for the tilt shot.
      static float thetaRangeMax = 2.0f * M_PI_F;
      const float t01 = ev.b / 127.0f;
      int idx = -1;
      float mapped = 0.0f;
      switch (ev.a) {
      case 20: { // zoom MSB -> cache only (apply on CC52 LSB), coarse-fallback on first-ever
        idx = 0;
        zoomMSB = ev.b;
        if (!zoomEverApplied) {
          uint16_t v14 = ((uint16_t)zoomMSB << 7) | zoomLSB;
          float t14 = v14 / 16383.0f;
          mapped = space::Camera::kMinRho +
                  t14 * (space::Camera::kMaxRho - space::Camera::kMinRho);
          camera.setZoomAbs(mapped);
          zoomEverApplied = true;
        } else {
          mapped = camera.getRho(); // log the unchanged value, not applied
        }
        break;
      }
      case 52: { // zoom LSB -> applies the full 14-bit pair
        idx = 0;
        zoomLSB = ev.b;
        uint16_t v14 = ((uint16_t)zoomMSB << 7) | zoomLSB;
        float t14 = v14 / 16383.0f;
        mapped = space::Camera::kMinRho +
                t14 * (space::Camera::kMaxRho - space::Camera::kMinRho);
        camera.setZoomAbs(mapped);
        zoomEverApplied = true;
        break;
      }
      case 21: // camera up/down -> theta, linear over [0, pi] (7-bit static
               // hold, take-2 shape; NOT used by the take-3 spin ride, which
               // drives theta via the 14-bit CC28/29 pair below instead)
        idx = 1;
        mapped = t01 * M_PI_F;
        camera.setTiltAbs(mapped);
        break;
      case 28: { // thetaSpin MSB -> cache only, same latch pattern as zoom
        idx = 7;
        thetaMSB = ev.b;
        if (!thetaEverApplied) {
          uint16_t v14 = ((uint16_t)thetaMSB << 7) | thetaLSB;
          mapped = (v14 / 16383.0f) * thetaRangeMax;
          camera.setTiltAbs(mapped);
          thetaEverApplied = true;
        } else {
          mapped = camera.getTheta();
        }
        break;
      }
      case 29: { // thetaSpin LSB -> applies the full 14-bit pair, linear
                 // [0, thetaRangeMax) -- see the CC33 selector above
        idx = 7;
        thetaLSB = ev.b;
        uint16_t v14 = ((uint16_t)thetaMSB << 7) | thetaLSB;
        mapped = (v14 / 16383.0f) * thetaRangeMax;
        camera.setTiltAbs(mapped);
        thetaEverApplied = true;
        break;
      }
      case 34: { // spinRate MSB -> cache only (apply on CC66 LSB), same
                 // latch pattern as zoom/theta: applying on EITHER half lets
                 // a fresh MSB pair with a stale LSB for one message.
        idx = 11;
        spinMSB = ev.b;
        mapped = app.uiSpinCcUnit;
        break;
      }
      case 66: { // spinRate LSB -> applies the full 14-bit pair.
                 // 0 = stopped (the app's own default, so a dropped CC fails
                 // SAFE), 16383 = kSpinMax, the M87* photon-sphere ceiling.
                 // Direction is applied where it is used (main loop): RIGHT
                 // arrow, i.e. dirY = -1, his "spin it to the right".
        idx = 11;
        spinLSB = ev.b;
        uint16_t v14 = ((uint16_t)spinMSB << 7) | spinLSB;
        app.uiSpinCcUnit = v14 / 16383.0f;
        app.uiSpinCcActive = true;
        mapped = app.uiSpinCcUnit;
        break;
      }
      case 33: // thetaRange selector -- raw 0 = full 2pi (ORBIT, the
               // default so the orbit driver needs no change at all),
               // nonzero = pi/2 (TILT, take 4's edge-on-to-face-on shot).
               // EXACT selector like camPhi, not a scaled value -- there is
               // no reason to round when there are only two spans.
        idx = 10;
        thetaRangeMax = (ev.b == 0) ? (2.0f * M_PI_F) : (M_PI_F * 0.5f);
        mapped = thetaRangeMax;
        break;
      case 30: // camPhi -> azimuth pose, EXACT selector not a scaled value
               // (2026-09-04 ~13:59 fix: a 7-bit-scaled t01*2pi cannot land
               // exactly on pi/2 -- nearest raw was 90.72deg, cos(phi)=
               // -0.0124, which put posZ = rho*sinTheta*cosPhi at +-24.8
               // units off the disk plane at rho=2000, once per revolution
               // -- a slow vertical bob on a shot whose premise is staying
               // in-plane. phi is never modulated once armed, so there is no
               // reason to carry any rounding at all: raw 0 = TUMBLE
               // (phi=0 exactly), any other raw = ORBIT (phi=pi/2 exactly).
        idx = 8;
        mapped = (ev.b == 0) ? 0.0f : (M_PI_F * 0.5f);
        camera.setPhiAbs(mapped);
        // Take-3 verdict fix (2026-09-04 ~14:58): "the rotation seems
        // wrong ... not what i wanted" -- the theta-derived up vector rolls
        // WITH the orbit when theta is the orbit angle (see camera.h
        // `orbitUpFix`). Same selector as the pose itself: nonzero raw
        // (ORBIT) arms the fix, raw 0 (TUMBLE) leaves the original
        // theta-derived up alone -- tumble's whole point is going over the
        // pole, which needs the basis-flip-avoidance path untouched.
        camera.setOrbitUpFix(ev.b != 0);
        break;
      case 31: // phaseAmount -> uiPhaseVizAmount, 7-bit static hold (his
               // order 2026-09-04 ~14:44, "phase fx off" for all future
               // takes). Held at 0, NOT a default change in app_state.h --
               // this is a per-render override, reversible, and it lands in
               // the log so the take is provably phase=0 rather than
               // assumed. Zeroing the amount alone is sufficient regardless
               // of the separate `uiPhaseViz` bool (renderer.mm:2081 --
               // `phaseViz ? phaseVizAmount : 0.0f` is 0 either way when
               // phaseVizAmount is 0).
        idx = 9;
        mapped = t01;
        app.uiPhaseVizAmount = mapped;
        break;
      case 22: { // exposure -> logarithmic [0.01,100], matches its own slider's curve
        idx = 2;
        const float lo = std::log(0.01f), hi = std::log(100.0f);
        mapped = std::exp(lo + t01 * (hi - lo));
        app.uiExposure = mapped;
        break;
      }
      case 23: // fluid -> uiTrailDecay, linear [0, 0.99]
        idx = 3;
        mapped = t01 * 0.99f;
        app.uiTrailDecay = mapped;
        break;
      case 24: // glitch -> uiGlitch, linear [0, 1]
        idx = 4;
        mapped = t01;
        app.uiGlitch = mapped;
        break;
      case 25: // chromatic -> uiChromatic, linear [0, 0.02]
        idx = 5;
        mapped = t01 * 0.02f;
        app.uiChromatic = mapped;
        break;
      case 26: { // ISCO orbit -> uiIscoSeconds, logarithmic [0.02,30] — same
                 // curve as its own slider (main.cpp:1729-1730). LOWER=faster
                 // (his order 2026-09-04 morning: park this at the fast end).
        idx = 6;
        const float lo = std::log(0.02f), hi = std::log(30.0f);
        mapped = std::exp(lo + t01 * (hi - lo));
        app.uiIscoSeconds = mapped;
        break;
      }
      default:
        break;
      }
      // Rate-limited: at most 5/s per parameter, plus always the sweep's
      // endpoints (raw 0 and 127) so "changed and reset again" is never the
      // one line that got throttled away.
      if (idx >= 0 &&
          (ev.t - lastLogT[idx] >= 0.2 || ev.b == 0 || ev.b == 127)) {
        printf("[MIDI-MAP] %-9s cc=%d raw=%3d -> %.5f\n", kName[idx], ev.a,
               ev.b, mapped);
        lastLogT[idx] = ev.t;
      }
      break;
    }
    }
  };
  midiInput.start(onMidi);
  // S4: replay of an S2 take by output frame index (SS_REPLAY, needs
  // SS_RENDER_FPS). Refuses loudly without the offline clock, without a
  // marker, or with drops. Ticked at the top of every frame, before physics.
  space::TakeReplay takeReplay(space::OfflineClock::get().enabled ? space::OfflineClock::get().fps : 0);

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
  // `app` itself moved up to :291 (before the MIDI callback, which needs it).

  // TEMP-SLICE3 (remove after slice-3 verdict): the headless shock-tube run
  // (SS_SPH_TEST, see renderer.mm uploadParticles) needs the SPH force +
  // viscosity toggles ON without a hand on the mod menu.
  if (getenv("SS_SPH_TEST")) {
    app.uiTogSphPressure = true;                     // bit11
    app.uiTogSphVisc = !getenv("SS_SPH_NOVISC");     // bit12 (A/B control: off)
    app.uiTogSphCool = getenv("SS_SPH_COOL") != nullptr;  // bit13 (slice-4 A/B)
  }
  // TEMP substrate-noise hunt: kill the legacy grid pressure for baseline A/B.
  if (getenv("SS_NO_LEGACY_PRESSURE")) app.uiTogNoLegacyPressure = true;
  // SS_SPH_VISC=1 → bit12 shock viscosity+heating ON without the SS_SPH_TEST
  // reseed (that flag rebuilds the field into two test spheres — unusable for
  // in-situ runs). Needed for the AMR bounce: shocks are the honest dissipation
  // that binds a COLD radial collapse (dynfric can't — σ→0, drag ∝ 1/v³).
  if (getenv("SS_SPH_VISC")) app.uiTogSphVisc = true;

  // SS_NO_CAPTURE=1 → bit2 seed-capture OFF for honest-physics beds. Measured
  // 2026-07-13 ~23:30 (gated_v2 log): the gated-visc bed collapsed to
  // Mtot(<5)=2.26e5 — best state ever — and the DEFAULT-ON capture cheat then
  // converted the honest core into 6 seed bodies (biggest 2.2e5 M☉, "hole 74%",
  // ~780k particles eaten). The fake-BH machinery destroys the honest
  // experiment exactly when it starts working. Full retirement = slice 4
  // (after the honest horizon fires); this only keeps it out of test beds.
  if (getenv("SS_NO_CAPTURE")) app.uiTogSeedCapture = false;

  // SS_ORTHO=0 → launch in PERSPECTIVE ("pov") instead of the default
  // orthographic camera (2026-09-04, his order for the take 6/7 re-runs:
  // "repeat run 6 and 7 but from non ortho mode .. the pov ish mode").
  // An offline render has no keyboard, so the "Ortho Camera" checkbox
  // (main.cpp:1984) is unreachable; this writes the same app.uiOrthoMode the
  // checkbox writes, so the code path is identical to clicking it.
  // ⚠️ The two projections do NOT frame the same at the same rho: ortho's
  // world half-height is rho*1.2 (main.cpp:1299) while perspective's is
  // d*tan(45°/2) = rho*0.414214 (renderer.mm kTanHalfFov), so perspective is
  // ~2.9x TIGHTER at the same zoom value. The lens survives it — the
  // `config.orthoMode &&` term that zeroed bhShadowNdcRadius in perspective
  // was removed 2026-08-10 and the divisor fixed 2026-08-20 (renderer.mm:2201).
  if (const char *om = getenv("SS_ORTHO")) {
    app.uiOrthoMode = (atoi(om) != 0);
    printf("[CAM] SS_ORTHO=%s -> %s projection\n", om,
           app.uiOrthoMode ? "ORTHOGRAPHIC" : "PERSPECTIVE");
  }
  }

  // SS_SUBSTEPS=N — pin the physics-substep slider at launch (2026-08-29).
  // Measurement hook ONLY: it writes the same app.uiPhysicsSubsteps the slider
  // writes (main.cpp:1474), so the code path is identical to dragging it. It
  // exists because the sweep 1/2/4/8/16/32 stalls the UI before it reaches the
  // top by hand (his report 2026-08-29), which makes the high-N rows of the
  // cost table unobtainable from the slider. Clamped to the slider's own 1..32.
  if (const char *nsub = getenv("SS_SUBSTEPS")) {
    int v = atoi(nsub);
    app.uiPhysicsSubsteps = (v < 1) ? 1 : (v > 32 ? 32 : v);
    fprintf(stderr, "[SUBSTEPS] pinned to %d by SS_SUBSTEPS\n", app.uiPhysicsSubsteps);
  }

  // SS_NO_ANALYTIC_SPIN=1 → bit20 time-lapse orbit playback OFF at launch
  // (ring-snap A/B, 2026-09-02: does the post-play field still snap into
  // concentric rings when the first seed-class body forms, with the Keplerian
  // pose sweep disabled?). Same variable the mod-menu checkbox writes.
  if (getenv("SS_NO_ANALYTIC_SPIN")) app.uiTogAnalyticSpin = false;

  // 🔬 TEMP-DIAG isolation ladder (docs/BUG_lines_2026-07-12.md): SS_INERT=1
  // turns EVERY optional force OFF (all bhToggles force bits cleared, legacy
  // grid pressure retired; renderer.mm skips the ungated merge_stars pass under
  // the same flag). SS_INERT_KEEP="tok,tok" re-enables forces one at a time:
  //   fieldgrav(bit0) central(bit1) capture(bit2) seedseed(bit3) originpin(bit4)
  //   relax(bit5) resurrect(bit6) substep(bit9) pm(bit10) sphp(bit11) sphv(bit12)
  //   sphcool(bit13) legacy(bit14 force back ON) merge(merge_stars pass)
  // ⚠️ tokens are matched with strstr — keep them substring-unique.
  if (getenv("SS_INERT")) {
    const char *keep = getenv("SS_INERT_KEEP");
    auto kept = [keep](const char *tok) {
      return keep != nullptr && strstr(keep, tok) != nullptr;
    };
    app.uiTogFieldGravity     = kept("fieldgrav");
    app.uiTogCentralSMBH      = kept("central");
    app.uiTogSeedCapture      = kept("capture");
    app.uiTogSeedMerge        = kept("seedseed");
    app.uiTogOriginPin        = kept("originpin");
    app.uiTogRelaxation       = kept("relax");
    app.uiTogResurrection     = kept("resurrect");
    app.uiTogAdaptiveSubstep  = kept("substep");
    app.uiTogPMGravity        = kept("pm");
    app.uiTogSphPressure      = kept("sphp");
    app.uiTogSphVisc          = kept("sphv");
    app.uiTogSphCool          = kept("sphcool");
    app.uiTogNoLegacyPressure = !kept("legacy"); // inverted: kept = legacy force runs
  }

  // Arrow-key PHYSICAL spin: hold to ramp torque on the particle body, with
  // momentum/drag. The max is PHYSICAL, not arbitrary: M87*'s real Kerr horizon
  // angular velocity Ω_H = a/(r₊²+a²)·c = 9.79e-6 rad/s (one rotation ≈ 7.43
  // days), time-lapsed ×6.42e5 so the hole turns once per second on screen —
  // smooth at 120fps (~3°/frame, no aliasing; the old 188 rad/s = 90°/frame =
  // the strobing/shaking). You cannot out-spin the black hole.
  // Top speed anchored to the UNIVERSAL MAX — matter orbiting at the speed of
  // light c near the photon sphere (1.5 r_g of M87*): Ω_c = c/(1.5 r_g) =
  // 3e8 / (1.5 · 9.6e12) ≈ 2.08e-5 rad/s. Nothing can spin faster than this.
  // Time-lapsed for a visible, fast on-screen rotation; the tangential pixel-
  // stretch fuse bridges the per-frame gap so it doesn't strobe.
  static constexpr float kOmegaLightReal = 2.08e-5f; // c at the photon sphere (rad/s)
  static constexpr float kBHTimeLapse    = 2.1e7f;   // time compression
  static constexpr float kSpinMax = kOmegaLightReal * kBHTimeLapse; // ≈437 rad/s (~70 rev/s)
  static bool arrowL = false, arrowR = false, arrowU = false, arrowD = false;
  static bool rollL = false, rollR = false;      // Option+←/→ = third-axis roll (Z)
  static float spinHold = 0.0f;
  // TAP vs HOLD threshold. Used in BOTH places that need it: the release
  // check that fires the camera quadrant-rotate, and the render-loop gate
  // that engages the physical spin. One constant so they cannot drift.
  static constexpr float kTapHoldSec = 0.18f;
  static float spinVelX = 0.0f, spinVelY = 0.0f; // current spin rate (rad/s)
  static float spinVelZ = 0.0f;                  // roll rate (rad/s)
  static float spinAngleX = 0.0f, spinAngleY = 0.0f; // accumulated spin angle (rad)
  static float spinAngleZ = 0.0f;                // accumulated roll angle (rad)

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

  // SS_SEQ=<pattern> — drive the instrument at launch (2026-08-29).
  // Measurement hook ONLY: calls the same firePreset the SEQUENCER buttons call.
  // WHY: his verdict 2026-08-29 — "play short notes, chords.. pauses, what
  // happens in between. not just a held note". Every measurement before this ran
  // at REST (phase=0.0 amp=0.000), which is the regime he says is FINE. A held
  // note never shows the TRANSITIONS, and the transitions are suspect: hashFresh
  // (particles.metal:1687) is FALSE during attack, so PM gravity (:1696), field
  // self-gravity (:1785) and dynamic friction (:1971) all switch OFF on every
  // note onset. Short notes = permanent attack = gravity permanently off.
  // All patterns start at t=6s so the field settles first.
  if (const char *sq = getenv("SS_SEQ")) {
    if (!strcmp(sq, "transitions")) {
      // staccato run -> pause -> chord -> pause -> stabs -> sustained chord
      firePreset("SS_SEQ transitions", {
        {60, 6.0f, 0.20f}, {62, 6.8f, 0.20f}, {64, 7.6f, 0.20f},
        {65, 8.4f, 0.20f}, {67, 9.2f, 0.20f}, {69, 10.0f, 0.20f},
        {60, 13.0f, 1.5f}, {64, 13.0f, 1.5f}, {67, 13.0f, 1.5f}, {71, 13.0f, 1.5f},
        {72, 17.0f, 0.15f}, {74, 17.6f, 0.15f},
        {48, 20.0f, 3.0f}, {55, 20.0f, 3.0f}, {60, 20.0f, 3.0f},
      });
    } else if (!strcmp(sq, "staccato")) {
      firePreset("SS_SEQ staccato", {
        {60, 6.0f, 0.15f}, {60, 7.0f, 0.15f}, {60, 8.0f, 0.15f},
        {60, 9.0f, 0.15f}, {60, 10.0f, 0.15f}, {60, 11.0f, 0.15f},
        {60, 12.0f, 0.15f}, {60, 13.0f, 0.15f}, {60, 14.0f, 0.15f},
        {60, 15.0f, 0.15f}, {60, 16.0f, 0.15f}, {60, 17.0f, 0.15f},
      });
    } else if (!strcmp(sq, "held")) {   // CONTROL: the easy case, one long chord
      firePreset("SS_SEQ held", {
        {60, 6.0f, 12.0f}, {64, 6.0f, 12.0f}, {67, 6.0f, 12.0f}, {71, 6.0f, 12.0f},
      });
    } else {
      fprintf(stderr, "[SS_SEQ] unknown pattern '%s' (transitions|staccato|held)\n", sq);
    }
  }


  // ── Simulation pause (SPACE) — physics freezes, render/camera live on ──
  bool simPaused = false;
  // ── F8 whiteout bisect — raw scene + Reinhard, whole postfx chain off ──
  bool debugBypassPostFX = false;
  // SPACE held down while paused → the emergent time-lapse keeps running.
  bool spaceHeld = false;
  // N key: disable the sensor bleach (yellow-zone isolation instrument).
  bool debugNoBleach = false;
  // A long hold LATCHES the time-lapse: stays on after release, cleared by tap.
  bool pauseTimelapseLatched = false;
  // ── TIME WARP (SHIFT+←/→) — multiplicative ramp, rides key-repeat like
  // the camera arrows: hold to sweep. ×1.3 per tick, range 1/64× … 64×.
  float timeWarp = 1.0f;
  // SS_TIME_WARP=X — pin the time-warp dial at launch (2026-08-29).
  // Measurement hook ONLY, same idiom as SS_SUBSTEPS: it writes the same
  // `timeWarp` the UI writes, so the code path is identical. Needed to A/B the
  // "x120 convention" (particles.metal:1425/:3704/:4059), whose error scales as
  // warp^2 and therefore cannot be seen at warp 1.
  if (const char *tw = getenv("SS_TIME_WARP")) {
    float v = (float)atof(tw);
    if (v >= 0.01f && v <= 64.0f) {
      timeWarp = v;
      fprintf(stderr, "[TIMEWARP] pinned to %.2f by SS_TIME_WARP\n", timeWarp);
    } else {
      fprintf(stderr, "[TIMEWARP] SS_TIME_WARP=%s out of range 0.01..64, ignored\n", tw);
    }
  }

  // Running UNIVERSE CLOCK — accumulated PHYSICS time (real seconds), ticked in
  // the sim loop by kTimeLapse x renderer.simSecondsLastStep() — i.e. per STEP
  // ACTUALLY TAKEN, not per frame (E2, 2026-08-30). Adaptive human units.
  double universeClockSec = 0.0;

  // ── Key events ──────────────────────────────────────────────────────
  window.setKeyCallback([&](const KeyEvent &e) {
    // SHIFT+←/→ = TIME WARP. Checked before the camera arrows (same keys,
    // shift modifier) and before the isRepeat gate so holding the key
    // sweeps the scale — the same ramp feel as the camera rotation.
    if (e.shift && e.isDown && (e.keyCode == 123 || e.keyCode == 124)) {
      timeWarp *= (e.keyCode == 124) ? 1.3f : (1.0f / 1.3f);
      timeWarp = std::min(std::max(timeWarp, 1.0f / 64.0f), 64.0f);
      if (std::fabs(timeWarp - 1.0f) < 0.12f) timeWarp = 1.0f; // snap to real-time
      printf("[TIME] warp ×%.2f\n", timeWarp);
      return;
    }

    // OPTION+←/→ = ROLL — spin around the missing THIRD axis (Z, the screen
    // plane; Jamal 2026-07-19, binding chosen over Shift which is time warp).
    // Same held-ramp/momentum as the other two axes (render loop below).
    if (e.option && (e.keyCode == 123 || e.keyCode == 124)) {
      if (e.keyCode == 123) rollL = e.isDown;
      else                  rollR = e.isDown;
      return;
    }

    // Arrow keys = orbit camera. Handled BEFORE the isRepeat gate so a
    // held key fires every macOS key-repeat tick.
    // A TAP steps the camera TARGET one exact EIGHTH-turn (45°) in the direction
    // pressed; the spring in Camera::update eases it there and stops. It no
    // longer writes a velocity impulse, so there is nothing to soft-lock: the
    // landing is exact by construction rather than caught on the way down.
    //   123=Left  124=Right  125=Down  126=Up
    // Hold to RAMP the spin up to extreme (light-trail territory). Track held
    // state for down AND up; the per-frame ramp lives in the render loop.
    if (e.keyCode == 123 || e.keyCode == 124 || e.keyCode == 125 ||
        e.keyCode == 126) {
      bool d = e.isDown;
      // TAP (quick press+release, under the threshold → spin never engaged) =
      // the camera step. HOLD = the physical spin.
      if (!d && spinHold < kTapHoldSec) {
        // ±1 = one 45° step, exactly — 8 taps per revolution, his order
        // 2026-08-28. WAS a 0.06 rad velocity impulse that a magnetic detent
        // then caught near a multiple of 90°.
        if (e.keyCode == 123)      camera.rotateKey(+1, 0);
        else if (e.keyCode == 124) camera.rotateKey(-1, 0);
        else if (e.keyCode == 126) camera.rotateKey(0, +1);
        else if (e.keyCode == 125) camera.rotateKey(0, -1);
      }
      if (e.keyCode == 123)      arrowL = d;
      else if (e.keyCode == 124) arrowR = d;
      else if (e.keyCode == 126) arrowU = d;
      else if (e.keyCode == 125) arrowD = d;
      // Releasing ←/→ after letting go of Option lands here (no modifier):
      // clear the roll-held state too so the roll can't stick on.
      if (!d && (e.keyCode == 123 || e.keyCode == 124)) rollL = rollR = false;
      return;
    }

    // SPACE genuinely HELD (auto-repeat fires only on a real hold) while
    // paused → LATCH the time-lapse: it keeps running after the finger
    // lifts (Jamal 16:31 "if I hold it it should keep on going even if I
    // lift the finger"). Cleared by the next tap (resume).
    if (e.isRepeat && e.keyCode == 49 && e.isDown && simPaused) {
      if (!pauseTimelapseLatched) printf("[SIM] PAUSED + TIME-LAPSE LATCHED\n");
      pauseTimelapseLatched = true;
      return;
    }

    if (e.isRepeat)
      return;

    // C = CINEMATIC MODE. His spec 2026-08-28, verbatim: "i press a key.
    // ideally c and the cmaera movement becomes smooth as a cienma camera .
    // thats it."
    // Toggles the settle time and damping of the ONE camera law — orbit, tilt
    // and zoom all slow together and stop overshooting. It does NOT touch the
    // body spin or the time warp: those move the OBJECT, not the camera
    // ("at warp we spin the object not the camera").
    // keyCode 8 = 'C'. Free: it is not in the note keyMap above (0,13,1,14,2,
    // 3,17,5,16,4,32,38,40,31,37,35,41) and had no other handler.
    if (e.keyCode == 8 && e.isDown && !e.isRepeat) {
      camera.setCinematic(!camera.isCinematic());
      printf("[CINE] cinematic camera %s\n",
             camera.isCinematic() ? "ON" : "OFF");
      fflush(stdout);
      return;
    }

    // Z/X = octave shift
    if (e.keyCode == 6 && e.isDown) {
      synth.setOctaveShift(synth.octaveShift() - 1);
      return;
    }
    if (e.keyCode == 7 && e.isDown) {
      synth.setOctaveShift(synth.octaveShift() + 1);
      return;
    }

    // R = reset camera AND the rigid spin (angle + velocity), so reset returns
    // to the true default orientation instead of staying stuck at the
    // accumulated spin rotation.
    if (e.keyCode == 15 && e.isDown) {
      camera.reset();
      spinVelX = spinVelY = spinVelZ = 0.0f;
      spinAngleX = spinAngleY = spinAngleZ = 0.0f;
      rollL = rollR = false;
      spinHold = 0.0f;
      return;
    }

    // TAB = toggle HUD
    if (e.keyCode == 48 && e.isDown) {
      showHUD = !showHUD;
      return;
    }

    // SPACE = pause/resume the ENTIRE simulation (physics freezes in place,
    // render + camera keep working — inspect the frozen field freely).
    // TAP = TOTAL pause (time-lapse clock frozen too). HOLD = the emergent
    // time-lapse keeps running while the key is down ("it did lowkey feel
    // nice" — Jamal 2026-07-23 16:20), release → total pause.
    if (e.keyCode == 49) {
      if (e.isDown) {
        simPaused = !simPaused;
        spaceHeld = simPaused; // pausing press held down = time-lapse alive
        pauseTimelapseLatched = false; // any tap clears the hold-latch
        printf("[SIM] %s\n", simPaused ? "PAUSED" : "RESUMED");
      } else {
        spaceHeld = false;     // released → total pause unless LATCHED (held long)
      }
      return;
    }

    // N = bleach isolation: disable the sensor bleach only. If the traveling
    // cream "yellow zone" turns into structured white/colour, the bleach's
    // partial-wash band is confirmed as the yellow-maker.
    // ── I = TWO-WINDOW MODE (2026-08-23, his order: "i press a key and it
    // goes two windows"). 34 is free: not in keyMap[] (the piano keys) and
    // not bound elsewhere. WantCaptureKeyboard is checked upstream in
    // window.mm, so typing an "i" into a text field does not trigger it.
    if (e.keyCode == 34 && e.isDown && !e.isRepeat) {
      const bool split = window.toggleSettingsWindow();
      printf("[UI] two-window mode %s\n",
             split ? "ON — main window is now clean output"
                   : "OFF — controls back in the main window");
    }

    if (e.keyCode == 45 && e.isDown) {
      debugNoBleach = !debugNoBleach;
      printf("[POSTFX] bleach %s\n", debugNoBleach ? "OFF (isolation)" : "ON");
      return;
    }

    // B = whiteout bisect: bypass the ENTIRE postfx composite (raw HDR
    // scene + plain Reinhard). Whiteout still there → scene/particles;
    // gone → postfx chain. (B, not F8: mac F-keys are media keys sans Fn.)
    if (e.keyCode == 11 && e.isDown) {
      debugBypassPostFX = !debugBypassPostFX;
      printf("[POSTFX] bypass %s\n", debugBypassPostFX ? "ON (raw scene + Reinhard)" : "OFF");
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
    // S4: the OUTPUT frame index — one per frame callback, counted here so
    // replay, and later capture, share one number. Replayed events apply at
    // the top of their frame, before the sequencer and before the physics
    // step, through the same `onMidi` a live packet uses.
    static uint32_t outFrame = 0;
    // S8: SS_CAPTURE_FRAMES reached ⇒ close the files and END the run, before
    // anything of this frame begins.
    if (showCap.done()) {
      static bool ended = false;
      if (!ended) {
        ended = true;
        printf("[CAPTURE] %u frames written — ending the run.\n", showCap.framesWritten());
        showCap.finish();
        window.close();
      }
      return;
    }
    takeReplay.tick(outFrame, onMidi);
    outFrame++;
    // S9 OFFLINE: advance the synth (and every envelope) by exactly one output
    // frame of samples, AFTER this frame's replayed notes are queued and BEFORE
    // the envelope is read below. Sample offsets are 0, so a note lands at the
    // start of its frame. Unset ⇒ CoreAudio pulls processBlock as always.
    if (kOfflineAudio) {
      static float scratchL[48000 / 30], scratchR[48000 / 30];   // largest case (30 fps)
      const int n = 48000 / space::OfflineClock::get().fps;
      synth.processBlock(48000.0f, scratchL, scratchR, n);
    }
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

      // ── SEQ PROBE (2026-08-29) — the physics state THROUGH the transitions.
      // Was every 0.5s and it fetched `stats` only to `(void)` them away, so a
      // 0.15s stab fell entirely between two samples. Now 0.05s, and it prints
      // what actually matters across a note edge: the envelope PHASE (0 silence,
      // 1 attack, 2 decay, 3 sustain, 4 release — gravity is OFF in phase 1, see
      // particles.metal:1687 hashFresh), the speeds against the play cap, and
      // the integrator clamp population. ⚠ avgSpeed/maxSpeed/accOverCount come
      // from the cached readback (getPhysicsStats), which refreshes on a coarser
      // cadence than this line — so read them as a step function, not per-frame.
      seqLogTimer += dt;
      if (seqLogTimer >= 0.05f) {
        auto st = renderer.getPhysicsStats();
        auto ev = synth.getDominantEnvelope();
        printf("[SEQPROBE] t=%6.2f phase=%.1f voices=%d amp=%.3f "
               "vAvg=%.3f vMax=%.3f clamped=%d worst=%.3g warp=%.2f\n",
               seqTime, ev.phase, synth.activeVoiceCount(),
               synth.totalAmplitude(), st.avgSpeed, st.maxSpeed,
               st.accOverCount, st.maxAccRatio, timeWarp);
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
      float dirZ = (rollR ? 1.0f : 0.0f) - (rollL ? 1.0f : 0.0f); // Option+←/→
      if (dirX != 0.0f || dirY != 0.0f || dirZ != 0.0f) {
        spinHold += dt;
        // TAP CONTRIBUTES ZERO SPIN (his order 2026-08-27: "i only want that
        // when i hold the keys"). Spin engages only once the press passes
        // kTapHoldSec — the SAME threshold the release check uses to fire the
        // camera rotate — so tap and hold are exactly complementary.
        // WAS: engaged immediately. One ~60 ms tap put ~1.6 rad/s on the body,
        // which the 2.5/s drag integrates to ~37° of REAL rotation after the
        // finger lifts. The camera still snapped to its 90° quadrant, but the
        // body had turned under it — which is why the snap stopped reading as a
        // snap, and why a tap made the shape "dent and bend".
        // Holding still ramps HARD (accel grows with hold time) and momentum
        // still carries after release: the ramp below is UNCHANGED.
        if (spinHold >= kTapHoldSec) {
          float accel = 8.0f + spinHold * spinHold * 25.0f;
          spinVelY += dirY * accel * dt;
          spinVelX += dirX * accel * dt;
          spinVelZ += dirZ * accel * dt;
        }
      } else {
        spinHold = 0.0f;
      }
      // Momentum drag: coasts to a stop in ~2s after release (heavy flywheel,
      // not frictionless). Stronger drag while NOT actively driving.
      float dragRate = (dirX != 0.0f || dirY != 0.0f || dirZ != 0.0f) ? 0.3f : 2.5f;
      float spinDrag = std::max(0.0f, 1.0f - dt * dragRate);
      spinVelX *= spinDrag;
      spinVelY *= spinDrag;
      spinVelZ *= spinDrag;
      // Physical ceiling = M87*'s real horizon spin (time-lapsed). Smooth at
      // 120fps; you cannot out-spin the black hole.
      spinVelX = std::clamp(spinVelX, -kSpinMax, kSpinMax);
      spinVelY = std::clamp(spinVelY, -kSpinMax, kSpinMax);
      spinVelZ = std::clamp(spinVelZ, -kSpinMax, kSpinMax);
      // ── CC-OWNED SPIN (2026-09-04) ─────────────────────────────────────
      // When the ride is driving, it OWNS the Y rate: replace, do not add.
      // Placed AFTER the drag and the clamp on purpose -- the integrator
      // above would otherwise bleed the ramp off at 0.3/s while "held" and
      // 2.5/s when not, and no arrow IS held in an offline render.
      // Negative = the RIGHT arrow's direction (dirY = arrowL - arrowR),
      // his "spin it to the right". Flip this one sign to reverse it.
      if (app.uiSpinCcActive)
        spinVelY = -app.uiSpinCcUnit * kSpinMax;
      // RIGID-FRAME SPIN: the spin is a rigid rotation applied in the RENDER,
      // not in the physics — so the disk/Chladni shape rotates as one solid
      // body (no force-fighting → no rest-scatter, no note-pinning, no jump to
      // FTL). Physics stays spin-free (setSpin 0). We accumulate the ANGLE for
      // the render rotation; spinVel is still passed (config.spinX/Y) for the
      // analytic trail/Doppler velocity.
      spinAngleX += spinVelX * dt;
      spinAngleY += spinVelY * dt;
      spinAngleZ += spinVelZ * dt;
      renderer.setSpin(0.0f, 0.0f);
    }
    camera.update(dt);
    float view[16], proj[16], viewProj[16];
    camera.buildViewMatrix(view);

    if (app.uiOrthoMode) {
      // S1: aspect comes from the DRAWABLE (pixels), not the window (points).
      // When the buffer is pinned these differ, and the buffer is the truth.
      float aspect =
          (float)window.drawableWidth() / (float)window.drawableHeight();
      float frustum = camera.getRho() * 1.2f; // Dynamic orthographic zoom
      Renderer::orthoMatrix(proj, -frustum * aspect, frustum * aspect, -frustum,
                            frustum, -5000.0f, 5000.0f);
    } else {
      // SS_FOV=<deg> — the PERSPECTIVE vertical field of view, default 45.
      // ⚠️ 45 deg is a LAPTOP-aspect number. perspectiveMatrix fixes the
      // VERTICAL fov and derives the horizontal from aspect (renderer.mm:6186),
      // so the world half-height it shows at distance d is d*tan(fov/2) =
      // 0.414*d at 45 deg, against ortho's rho*1.2 (:1299) -- perspective is
      // 2.9x TIGHTER at the same zoom, which spreads the same particles over
      // 8.4x the area and is why a straight ortho->perspective swap reads dark.
      // The fov at which the two projections frame IDENTICALLY at EVERY zoom
      // is derived from ortho's own law, not picked: tan(fov/2) = 1.2 =>
      // fov = 2*atan(1.2) = 100.389 deg.
      static float sFovDeg = []{
        float v = 45.0f;
        if (const char *f = getenv("SS_FOV")) {
          float t = (float)atof(f);
          if (t > 1.0f && t < 179.0f) v = t;
        }
        printf("[CAM] perspective vertical FOV %.3f deg (SS_FOV)\n", v);
        return v;
      }();
      // NEAR PLANE 0.001 -> 1.0 (2026-09-05, his POV "insane flicker" live +
      // "crazy shake" in the render). Depth in NDC is ~1 - n/z, so with n =
      // 0.001 every particle beyond a few units lands within float spacing of
      // 1.0: at z = 1000 the buffer cannot separate two stars closer than ~60
      // units, and the Less test against the depth prepass becomes a
      // per-frame coin flip (thread-order) -- flicker live, "shake" at 30 fps.
      // Ortho maps depth linearly over +-5000 and never had this. kMinRho is
      // 50, so nothing the camera can frame is lost at n = 1 (resolution at
      // z = 1000 becomes ~0.06 units).
      Renderer::perspectiveMatrix(proj, sFovDeg * (M_PI_F / 180.0f),
                                  (float)window.drawableWidth() /
                                      (float)window.drawableHeight(),
                                  1.0f, 20000.0f); // far: kMaxRho 5800 + cloud ~7600, margin
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
            synth.setDrive(currentPreset.speedCap);
          }
          break;
        }
      }
      presetsLoaded = true;
    }

    // ═══ TOP STATUS BAR — Stellaris-style glowing telemetry strip (2026-06-27)
    // First piece of the cockpit redesign: status lives in a glowing edge-anchored
    // bar drawn with ImDrawList, NOT stacked rows in the control window. The
    // control window below becomes the left rail in the next step. (Layout chosen
    // 2026-06-27.)
    if (showHUD) {
      auto hs = renderer.getPhysicsStats();
      float fieldM = std::max(hs.fieldMassMsun, 1.0f);
      const float barH = 34.0f;
      const float barW = (float)window.width();
      ImGui::SetNextWindowPos(ImVec2(0, 0));
      ImGui::SetNextWindowSize(ImVec2(barW, barH));
      ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(0, 0));
      ImGui::Begin("##topbar", nullptr,
                   ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoBackground |
                       ImGuiWindowFlags_NoNav | ImGuiWindowFlags_NoInputs |
                       ImGuiWindowFlags_NoBringToFrontOnFocus |
                       ImGuiWindowFlags_NoSavedSettings);
      ImDrawList *dl = ImGui::GetWindowDrawList();

      // frosted backing + glowing accent underline (layered for bloom)
      dl->AddRectFilled(ImVec2(0, 0), ImVec2(barW, barH), IM_COL32(8, 9, 14, 190));
      for (int g = 3; g >= 0; --g)
        dl->AddLine(ImVec2(0, barH - 1.0f + g), ImVec2(barW, barH - 1.0f + g),
                    IM_COL32(110, 150, 255, 70 - g * 18), 1.0f);
      dl->AddLine(ImVec2(0, barH - 1.0f), ImVec2(barW, barH - 1.0f),
                  IM_COL32(150, 185, 255, 255), 1.5f);

      const float cy = barH * 0.5f;
      float x = 16.0f;
      const ImU32 dim = IM_COL32(255, 255, 255, 110);
      auto seg = [&](const char *label, ImU32 valCol, const char *val) {
        if (label[0]) {
          ImVec2 ls = ImGui::CalcTextSize(label);
          dl->AddText(ImVec2(x, cy - ls.y * 0.5f), dim, label);
          x += ls.x + 7.0f;
        }
        ImVec2 vs = ImGui::CalcTextSize(val);
        dl->AddText(ImVec2(x, cy - vs.y * 0.5f), valCol, val);
        x += vs.x + 16.0f;
      };
      auto divider = [&]() {
        dl->AddLine(ImVec2(x - 4.0f, 8.0f), ImVec2(x - 4.0f, barH - 9.0f),
                    IM_COL32(255, 255, 255, 45), 1.0f);
        x += 14.0f;
      };

      char buf[48];
      // UNIVERSE clock (adaptive units) + warp / pause
      double cv = universeClockSec; const char *cu = "sec";
      if (cv >= 31557600.0)   { cv /= 31557600.0; cu = "yr"; }
      else if (cv >= 86400.0) { cv /= 86400.0;    cu = "days"; }
      else if (cv >= 3600.0)  { cv /= 3600.0;     cu = "hr"; }
      else if (cv >= 60.0)    { cv /= 60.0;       cu = "min"; }
      std::snprintf(buf, sizeof(buf), "%.1f %s", cv, cu);
      seg("UNIVERSE", IM_COL32(150, 185, 255, 255), buf);
      if (simPaused) std::snprintf(buf, sizeof(buf), "PAUSED");
      else std::snprintf(buf, sizeof(buf), "%gx", (double)timeWarp);
      seg("", simPaused ? IM_COL32(255, 200, 60, 255)
                        : IM_COL32(255, 255, 255, 150), buf);
      divider();
      std::snprintf(buf, sizeof(buf), "%.0f%%", 100.0f * hs.coreMassMsun / fieldM);
      seg("COLLAPSE", IM_COL32(100, 220, 255, 255), buf);
      divider();
      if (hs.bhStrength >= 1.0f) std::snprintf(buf, sizeof(buf), "FORMED");
      else std::snprintf(buf, sizeof(buf), "%.0f%%", 100.0f * hs.bhStrength);
      seg("BH", IM_COL32(255, 160, 60, 255), buf);
      divider();
      std::snprintf(buf, sizeof(buf), "%.2f c", hs.avgSpeed);
      seg("v", IM_COL32(130, 180, 255, 255), buf);
      divider();
      std::snprintf(buf, sizeof(buf), "%.1e K", (double)hs.avgTemp);
      seg("T", IM_COL32(255, 180, 80, 255), buf);

      // right-aligned FPS
      std::snprintf(buf, sizeof(buf), "%.0f fps", ImGui::GetIO().Framerate);
      ImVec2 fs = ImGui::CalcTextSize(buf);
      dl->AddText(ImVec2(barW - fs.x - 16.0f, cy - fs.y * 0.5f),
                  IM_COL32(255, 255, 255, 150), buf);

      ImGui::End();
      ImGui::PopStyleVar();
    }

    // ── Top Right Overlay Control Panel ──────────────────────────────
    if (showHUD) {
      ImGui::SetNextWindowPos(ImVec2(window.width() - 250, 44));
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
    }
    // Hidden UI = fully clean output (vantablack, no lingering "SHOW ARCHITECT"
    // restore button). Press TAB (keyCode 48, handled above) to bring it back.


    if (showHUD) {
      ImGui::SetNextWindowPos(ImVec2(30, 30), ImGuiCond_FirstUseEver);
      ImGui::SetNextWindowSize(ImVec2(340, 0), ImGuiCond_FirstUseEver);

      // Custom header drawing inside the window
      ImGui::Begin("PHYSICS ARCHITECT", nullptr,
                   ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar);

      // ═══════════ HUD — STATUS (info-forward, always at top) ══════════════
      // The values that matter, prominent — Stellaris/Elite style. Controls
      // follow below. (Phase 3 redesign 2026-06-26.)
      {
        auto hs = renderer.getPhysicsStats();
        float fieldM = std::max(hs.fieldMassMsun, 1.0f);
        const ImVec4 accent(0.45f, 0.65f, 1.0f, 1.0f);
        const ImVec4 amber(1.0f, 0.6f, 0.2f, 1.0f);
        auto fmtT = [](double sec, double &v, const char *&u) {
          v = sec; u = "sec";
          if (sec >= 31557600.0) { v = sec / 31557600.0; u = "years"; }
          else if (sec >= 86400.0) { v = sec / 86400.0; u = "days"; }
          else if (sec >= 3600.0)  { v = sec / 3600.0;  u = "hours"; }
          else if (sec >= 60.0)    { v = sec / 60.0;    u = "min"; }
        };
        auto Meter = [](const char *lbl, float frac, ImVec4 c, const char *val) {
          frac = frac < 0.0f ? 0.0f : (frac > 1.0f ? 1.0f : frac);
          ImGui::TextColored(ImVec4(1, 1, 1, 0.7f), "%-11s", lbl);
          ImGui::SameLine();
          ImGui::PushStyleColor(ImGuiCol_PlotHistogram, c);
          ImGui::ProgressBar(frac, ImVec2(-1.0f, 14.0f), val);
          ImGui::PopStyleColor();
        };

        double cv; const char *cu; fmtT(universeClockSec, cv, cu);
        ImGui::PushStyleColor(ImGuiCol_Text, accent);
        ImGui::Text("UNIVERSE   %.1f %s", cv, cu);
        ImGui::PopStyleColor();
        ImGui::SameLine();
        if (simPaused)
          ImGui::TextColored(amber, "  [ PAUSED ]");
        else
          ImGui::TextDisabled("   %g x  ·  %.0f fps", timeWarp,
                              ImGui::GetIO().Framerate);

        ImGui::Spacing();
        char vb[40];
        std::snprintf(vb, sizeof(vb), "%.1f%%", 100.0f * hs.coreMassMsun / fieldM);
        Meter("COLLAPSE", hs.coreMassMsun / fieldM, ImVec4(0.4f, 0.9f, 1.0f, 1), vb);
        if (hs.bhStrength >= 1.0f) std::snprintf(vb, sizeof(vb), "FORMED");
        else std::snprintf(vb, sizeof(vb), "%.0f%%", 100.0f * hs.bhStrength);
        Meter("BLACK HOLE", std::min(hs.bhStrength, 1.0f), amber, vb);
        std::snprintf(vb, sizeof(vb), "%.3f c", hs.avgSpeed);
        Meter("ORBITAL v", hs.avgSpeed, ImVec4(0.5f, 0.7f, 1.0f, 1), vb);
        std::snprintf(vb, sizeof(vb), "%.1e K", (double)hs.avgTemp);
        Meter("PLASMA T",
              (float)(std::log10(std::max((double)hs.avgTemp, 1.0)) / 13.0),
              ImVec4(1.0f, 0.7f, 0.3f, 1), vb);
        ImGui::Spacing();
        // Same %.0f -> %.2f precision fix as "Biggest body" below (2026-08-08).
        ImGui::TextDisabled("Field %.2e M_sun   ·   biggest %.2f M_sun",
                            (double)hs.fieldMassMsun, hs.maxBodyMsun);
      }
      ImGui::Separator();
      ImGui::Spacing();

      // ── UNIVERSE TIME — Universe-Sandbox-style speed control (Phase 2) ─────
      // Pause + discrete speed presets wired to the existing simPaused/timeWarp
      // (also space / shift+arrows). Live readout = how much PHYSICS time elapses
      // per real second = kTimeLapse·timeWarp, in adaptive units.
      ImGui::SeparatorText("UNIVERSE TIME");
      ImGui::Indent();
      {
        if (ImGui::Button(simPaused ? " PLAY " : " PAUSE")) simPaused = !simPaused;
        ImGui::SameLine();
        const float kSpeeds[] = {0.25f, 0.5f, 1.0f, 2.0f, 4.0f, 8.0f, 16.0f, 64.0f};
        for (int i = 0; i < 8; ++i) {
          bool active = !simPaused &&
                        std::fabs(timeWarp - kSpeeds[i]) < 0.01f * kSpeeds[i] + 1e-4f;
          if (active)
            ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.20f, 0.55f, 1.0f, 1.0f));
          char lbl[12];
          std::snprintf(lbl, sizeof(lbl), "%gx", kSpeeds[i]);
          if (ImGui::SmallButton(lbl)) { timeWarp = kSpeeds[i]; simPaused = false; }
          if (active) ImGui::PopStyleColor();
          if (i < 7) ImGui::SameLine();
        }
        // Adaptive human-unit formatter for a duration in seconds.
        auto fmtTime = [](double s, double &v, const char *&u) {
          v = s; u = "sec";
          if (s >= 31557600.0)   { v = s / 31557600.0; u = "years"; }
          else if (s >= 86400.0) { v = s / 86400.0;    u = "days";  }
          else if (s >= 3600.0)  { v = s / 3600.0;     u = "hours"; }
          else if (s >= 60.0)    { v = s / 60.0;       u = "min";   }
        };
        // Running UNIVERSE CLOCK (cosmic time elapsed) + the rate per real second.
        double cv; const char *cu; fmtTime(universeClockSec, cv, cu);
        double rv; const char *ru;
        fmtTime(simPaused ? 0.0 : space::units::kTimeLapse * (double)timeWarp, rv, ru);
        if (simPaused)
          ImGui::TextColored(ImVec4(1.0f, 0.8f, 0.2f, 1.0f), "PAUSED");
        else
          ImGui::Text("%g x real-time   ·   %.2f %s / real-sec", timeWarp, rv, ru);
        ImGui::Text("Universe clock: %.2f %s elapsed", cv, cu);
      }
      ImGui::Unindent();
      ImGui::Spacing();

      // ── REAL SCALE: the Milky Way unit system, derived from the Sgr A*
      // anchor in physics_constants.h. Every number is sourced/computed, not
      // arbitrary sim units — this is the maßstabsgetreu floor (see governing
      // model). Pure readout; changes no behavior.
      if (ImGui::CollapsingHeader("GALAXY / REAL SCALE", ImGuiTreeNodeFlags_DefaultOpen)) {
        using namespace space::phys;
        ImGui::Indent();
        const auto &bh = BH_ANCHOR;
        const double PI = 3.14159265358979;
        double rg_AU      = bh.r_g_m / AU;
        // ❌ WAS `bh.m_per_sim / AU` — Sgr A*'s 2·r_g = 1.27e10 m = 0.0849 AU.
        // The PHYSICS length unit is 2·r_g of the FIELD (spacetime.h:43) =
        // 1.75504e9 m = 0.011732 AU. So this line reported every distance on
        // screen 7.236× too large — which is exactly the mass ratio
        // 4.297e6/5.94276e5 = 7.231, because r_g ∝ M. Two anchors were live at
        // once and the panel published the wrong one, under a [FIXED CAL] label
        // that made it read as the trustworthy number.
        // Audited 2026-08-11 16:46:49 → docs/STATE_2026-08-11_units_scale_real_numbers.md
        double scale_AU   = space::units::kUnitMeters / AU;  // 1 sim = 2·r_g(FIELD)
        double a          = bh.spin_a;
        // (the anchor's own horizon/ISCO period are gone — both are LIVE now)
        // ❌ WAS `N × PARTICLE_MASS_UNIT`, i.e. "every particle is exactly 1 M☉".
        // The IMF mean is 0.297 M☉ (this file's own :95 says 0.30), so the field
        // read 2.0e6 M☉ against the 5.94e5 M☉ the integrator actually uses —
        // overstated 3.365×, and the NSC fraction with it (6.67% vs 1.98%).
        double fieldMass  = (double)renderer.getPhysicsStats().fieldMassMsun; // LIVE
        double fieldPct   = 100.0 * fieldMass / NSC_MASS_MSUN;
        double isco_rg    = 6.0;                       // ~Schwarzschild ISCO (low spin)
        double v_c        = std::sqrt(1.0 / isco_rg);  // v/c at the inner stable orbit
        double GM         = G * bh.mass_Msun * M_SUN;
        double r_isco     = isco_rg * bh.r_g_m;

        // ── LIVE HOLE — derived from THIS sim, not from the anchor ──────────
        // 2026-08-08 00:36, Jamal: "Static info in a ui is stupid. Why would it
        // be static... this is groundwork everything else builds on." He is
        // right: every line below used to read BH_ANCHOR (Sgr A*'s textbook
        // numbers), so the largest block on screen could never move no matter
        // what the simulation did. It now reads the running sim.
        //   r_g = G·M/c², M = the heaviest body the sim actually has.
        //   G·M_sun/c² = 1476.6 m, so r_g[m] = 1476.6 · (M/M_sun).
        // The one number that stays fixed is the SCALE, and it is labelled as
        // the calibration it is rather than dressed as telemetry.
        const auto hstat  = renderer.getPhysicsStats();
        double holeM      = (double)hstat.maxBodyMsun;          // M_sun, LIVE
        double rgLive_m   = (G * M_SUN / C2) * holeM;           // G·M/c²  [m]
        double rgLive_AU  = rgLive_m / AU;
        bool   haveHole   = (holeM > 0.0);

        ImGui::Text("Anchor:   %s  (scale calibration only)", bh.name);
        if (haveHole) {
          ImGui::Text("Hole mass:%.4g M_sun   [LIVE]", holeM);
          ImGui::Text("r_g:      %.3e AU  (%.3e km)   [LIVE]",
                      rgLive_AU, rgLive_m / 1000.0);
        } else {
          ImGui::TextDisabled("Hole mass: --   (no body yet)");
          ImGui::TextDisabled("r_g:       --");
        }
        ImGui::Text("Spin a*:  %.2f  (not simulated — Schwarzschild)", a);
        // Cosmic distance in LIGHT-units (light travels 1 AU in ~499 s). Adaptive
        // so it reads in human light-distance (light-sec → light-min → ... →
        // light-years) — the "light-years stuff" in honest units for this scale.
        auto lightStr = [](double au, char *out, size_t n) {
          double ls = au * 499.004784; // light-seconds per AU
          double v = ls; const char *u = "light-sec";
          if (ls >= 31557600.0)   { v = ls / 31557600.0; u = "light-yr";   }
          else if (ls >= 86400.0) { v = ls / 86400.0;    u = "light-days"; }
          else if (ls >= 3600.0)  { v = ls / 3600.0;     u = "light-hr";   }
          else if (ls >= 60.0)    { v = ls / 60.0;       u = "light-min";  }
          std::snprintf(out, n, "%.2f %s", v, u);
        };
        char lbuf[32];
        lightStr(scale_AU, lbuf, sizeof(lbuf));
        ImGui::TextDisabled("Scale:    1 sim unit = %.4f AU  (%s)  [FIXED CAL]",
                            scale_AU, lbuf);
        // MEASURED horizon: the largest r where r_s(M(<r)) >= r, computed every
        // frame from the radial mass profile. Was never plumbed to the UI, so
        // this line used to print the anchor's horizon and never moved.
        if (hstat.horizonR > 0.0f) {
          double horizLive_AU = (double)hstat.horizonR * scale_AU;
          lightStr(horizLive_AU, lbuf, sizeof(lbuf));
          ImGui::Text("Horizon:  %.4f sim = %.3e AU  (%s)   [MEASURED]",
                      (double)hstat.horizonR, horizLive_AU, lbuf);
          ImGui::Text("  M(<r_h): %.4g M_sun   [LIVE]",
                      (double)hstat.horizonMassMsun);
        } else {
          // Not "no data" — a real, continuously measured approach signal.
          ImGui::Text("Horizon:  none yet   sup r_s/r = %.3f   [LIVE]",
                      (double)hstat.horizonRatio);
        }
        ImGui::Separator();
        // ❌ WAS the hardcoded string "Particle: 1.00 M_sun (1 star)". The mass
        // is drawn per-id from a single α=2.3 power law over 0.08–50 M☉
        // (particles.metal:131) — SALPETER, not Kroupa (Kroupa is a broken power
        // law; the label was simply wrong). Live mean = M_field / N_live ≈ 0.297.
        ImGui::Text("Particle: %.3f M_sun mean  (IMF-sampled, 0.08-50)",
                    app.uiParticleCount > 0
                        ? fieldMass / (double)app.uiParticleCount : 0.0);
        ImGui::Text("Field:    %.2e stars = %.2e M_sun (Salpeter a=2.3)",
                    (double)app.uiParticleCount, fieldMass);
        ImGui::Text("          %.1f%% of the nuclear star cluster", fieldPct);
        ImGui::Separator();
        // ISCO of the LIVE hole. v/c at 6 r_g is sqrt(1/6) for ANY Schwarzschild
        // mass — that one is genuinely a constant and is marked as such. The
        // RADIUS and the PERIOD both scale with M, so they move with the sim.
        ImGui::Text("Inner orbit (ISCO ~6 r_g):");
        ImGui::TextDisabled("  v = %.2f c  (%.2e km/s)  [mass-independent]",
                            v_c, v_c * C / 1000.0);
        if (haveHole) {
          double GMlive     = G * holeM * M_SUN;
          double r_iscoLive = isco_rg * rgLive_m;
          double T_live_min = 2.0 * PI *
                              std::sqrt(r_iscoLive * r_iscoLive * r_iscoLive / GMlive) / 60.0;
          ImGui::Text("  period = %.4g min  (real time)   [LIVE]", T_live_min);
        } else {
          ImGui::TextDisabled("  period = --   (no body yet)");
        }

        // ── LIVE telemetry — the actual running sim, mapped to real units.
        // Provisional calibration (see physics_constants.h); reacts on play.
        auto s = renderer.getPhysicsStats();
        // Velocity is now REAL: the stats "speed" field holds the orbital v/c =
        // sqrt(0.5/r_sim) derived from the Sgr A* anchor (geometry, not a calib).
        double vmax_c = (double)s.maxSpeed;   // innermost particle's orbital speed
        double vavg_c = (double)s.avgSpeed;   // field-mean orbital speed (reactive)
        double tmax_K = (double)s.maxTemp;   // real virial temperature [K]
        double tavg_K = (double)s.avgTemp;
        auto stateOf = [](double T) -> const char * {
          if (T < T_PLASMA_LO) return "gas";
          if (T < T_FUSION_H)  return "plasma";
          if (T < T_IRON_CORE) return "fusion-hot";
          if (T < T_QGP)       return "plasma (extreme)";
          return "quark-gluon";
        };
        ImGui::Separator();
        // ── THE COLLAPSE — plain-language live readout (Jamal's numbers) ──
        {
          float fieldM = std::max(s.fieldMassMsun, 1.0f);
          float pctIn = 100.0f * s.coreMassMsun / fieldM;
          float holePct = 100.0f * std::min(s.bhStrength, 1.0f);
          ImGui::TextColored(ImVec4(0.4f, 0.9f, 1.0f, 1.0f), "THE COLLAPSE");
          ImGui::Text("  Center mass:  %.0f M_sun", s.coreMassMsun);
          ImGui::Text("  Collapsed:    %.1f%%   (still outside: %.1f%%)",
                      pctIn, 100.0f - pctIn);
          // PRECISION FIX (2026-08-08 00:33, Jamal: "its 50 from the start its
          // always 50 ive observed it before u even were aware of it" — he was
          // right and it is a readout bug, not a physics one). The heaviest star
          // the IMF spawns is 49.957 M_sun and M_BH_SEED is exactly 50.0, so
          // %.0f printed "50" from frame one: a value sitting exactly ON the seed
          // threshold when it is really BELOW it, and nothing had formed. It then
          // looked frozen because a merger has to add a full solar mass before
          // the rounding ticks. Show hundredths so the gap to the threshold is
          // visible and small growth reads. Mark whether it has actually crossed.
          ImGui::Text("  Biggest body: %.2f M_sun%s", s.maxBodyMsun,
                      (s.maxBodyMsun >= 50.0f) ? "  [SEED]" : "  (< 50 seed)");
          if (holePct >= 100.0f)
            ImGui::TextColored(ImVec4(1.0f, 0.5f, 0.2f, 1.0f),
                               "  BLACK HOLE: FORMED");
          else
            ImGui::Text("  Black hole:   %.0f%% formed", holePct);
          ImGui::Separator();
        }
        ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.5f, 1.0f), "LIVE  [all real]");
        ImGui::Text("  Orbital v (inner): %.3f c", vmax_c);
        ImGui::Text("  Orbital v (mean):  %.3f c", vavg_c);
        ImGui::Text("  Plasma T (inner):  %.2e K  [%s]", tmax_K, stateOf(tmax_K));
        ImGui::Text("  Plasma T (mean):   %.2e K  [%s]", tavg_K, stateOf(tavg_K));
        ImGui::TextDisabled("  [sim] orbV max=%.4f avg=%.4f  KE=%.2f", s.maxSpeed, s.avgSpeed, s.kineticEnergy);
        // Step 2 measurement: how far the worst gravity kick exceeds the per-step
        // accuracy budget. ratio>1 = integrator clamp firing (running inaccurate);
        // sub-steps needed ≈ ceil(4·ratio). Diagnostic only — nothing capped yet.
        {
          // Honest form: ONE rogue particle out of 2M is not "accuracy lost" —
          // report HOW MANY kicks exceeded the c·dt budget (clamp fired) plus
          // the worst offender; red only when the over-budget POPULATION is
          // significant (>0.01% of live).
          float r = s.maxAccRatio;
          int over = s.accOverCount;
          int liveN = std::max(app.uiParticleCount, 1);
          float overPct = 100.0f * (float)over / (float)liveN;
          bool bad = overPct > 0.01f;
          ImGui::TextColored(bad ? ImVec4(1.0f, 0.4f, 0.3f, 1.0f)
                                 : ImVec4(0.6f, 0.9f, 0.6f, 1.0f),
                             "  [accuracy] clamped kicks: %d (%.3f%%)  worst %.1e c*dt%s",
                             over, overPct, r, bad ? "  DEGRADED" : "");
        }

        // ── LIVE METERS (Ableton-style bars) — the moving values at a glance ──
        ImGui::Spacing();
        ImGui::TextColored(ImVec4(0.6f, 0.8f, 1.0f, 1.0f), "METERS");
        auto Meter = [](const char *label, float frac, ImVec4 col,
                        const char *val) {
          frac = frac < 0.0f ? 0.0f : (frac > 1.0f ? 1.0f : frac);
          ImGui::Text("%-12s", label);
          ImGui::SameLine();
          ImGui::PushStyleColor(ImGuiCol_PlotHistogram, col);
          ImGui::ProgressBar(frac, ImVec2(-1.0f, 12.0f), val);
          ImGui::PopStyleColor();
        };
        float fieldM2 = std::max(s.fieldMassMsun, 1.0f);
        char vb[32];
        std::snprintf(vb, sizeof(vb), "%.1f%%", 100.0f * s.coreMassMsun / fieldM2);
        Meter("Collapse", s.coreMassMsun / fieldM2, ImVec4(0.4f, 0.9f, 1.0f, 1), vb);
        std::snprintf(vb, sizeof(vb), "%.0f%%", 100.0f * std::min(s.bhStrength, 1.0f));
        Meter("Black hole", std::min(s.bhStrength, 1.0f), ImVec4(1.0f, 0.5f, 0.2f, 1), vb);
        std::snprintf(vb, sizeof(vb), "%.3f c", vavg_c);
        Meter("Orbital v", (float)vavg_c, ImVec4(0.5f, 0.7f, 1.0f, 1), vb);
        std::snprintf(vb, sizeof(vb), "%.1e K", tavg_K);
        Meter("Plasma T", (float)(std::log10(std::max(tavg_K, 1.0)) / 13.0),
              ImVec4(1.0f, 0.7f, 0.3f, 1), vb);
        std::snprintf(vb, sizeof(vb), "%g x", timeWarp);
        Meter("Time warp",
              (float)((std::log2(std::max((double)timeWarp, 1e-3)) + 6.0) / 12.0),
              ImVec4(0.7f, 0.5f, 1.0f, 1), vb);

        ImGui::Unindent();
      }
      ImGui::Spacing();

      if (false && ImGui::CollapsingHeader("PRESETS", ImGuiTreeNodeFlags_DefaultOpen)) { // removed 2026-06-26 (non-functional)
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

        // Collisions + Bond Network: engine-permanent (toggles removed 2026-07-07).

        ImGui::Checkbox("Phase Viz", &app.uiPhaseViz);
        ImGui::SetItemTooltip(
            "Tint particles by Feynman phase (action integral).\n"
            "BLENDS over the physical blackbody/spectral colour — it does not\n"
            "replace it (changed 2026-08-24). Hue only; brightness untouched.");
        UiSliderFloat("Phase Amount", &app.uiPhaseVizAmount, 0.0f, 1.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right)) app.uiPhaseVizAmount = 0.35f;
        ImGui::SetItemTooltip(
            "0.00 = pure physical colour · 1.00 = full phase rainbow.\n"
            "Right-click to reset to 0.35.");

        // ── BLACK-HOLE MECHANISM TOGGLES (audit / follow-the-science) ─────────
        // Each one on/off so we can isolate every piece of the BH and rebuild
        // the lifecycle (star → supernova → BH) in honest order.
        if (ImGui::CollapsingHeader("Black Hole — mechanisms")) {
          ImGui::Checkbox("Field self-gravity", &app.uiTogFieldGravity);
          ImGui::SetItemTooltip("Near+far grid gravity (star↔star clumping)");
          ImGui::Checkbox("Central SMBH pull", &app.uiTogCentralSMBH);
          ImGui::SetItemTooltip("Hard-coded Sgr A* the cluster orbits");
          ImGui::Checkbox("Seed capture (eating)", &app.uiTogSeedCapture);
          ImGui::SetItemTooltip("Stars eaten by a seed → parked (the 'vanish')");
          ImGui::Checkbox("Seed-seed merge", &app.uiTogSeedMerge);
          ImGui::SetItemTooltip("Seeds coalesce into one (runaway → BH)");
          ImGui::Checkbox("Seed origin-pin", &app.uiTogOriginPin);
          ImGui::SetItemTooltip("Spring pulling seeds to centre (scripted)");
          ImGui::Checkbox("Relaxation damping", &app.uiTogRelaxation);
          ImGui::SetItemTooltip("Accretion drag near the core (dissipative)");
          ImGui::Checkbox("Resurrection on play", &app.uiTogResurrection);
          ImGui::SetItemTooltip("Eaten particles revive at home when you play");
          ImGui::Checkbox("Bright seed render", &app.uiTogSeedRender);
          ImGui::SetItemTooltip("Discrete bright accretion blob at rest");
          ImGui::Checkbox("Lens / shadow", &app.uiTogLensShadow);
          if (ImGui::IsItemHovered())
            ImGui::SetTooltip("bit8: particle-forward lens (sprite bend)");
          ImGui::Checkbox("Metric shadow (geodesic march)", &app.uiTogMetricShadow);
          // FLOOR 0.25 -> 0.02 (2026-07-25 22:14:00): the old floor was set when
          // every value on this dial meant something 43.4334x faster than its
          // label (the c3 error, units.h). With the honest law the tempo Jamal
          // called perfect in the held pause is 1/43.4334 = 0.023 s, which the
          // old floor made unreachable.
          // LOGARITHMIC (2026-07-25 22:29:00, Jamal: "add the slider for the
          // speed back"): after the floor went to 0.02 the useful tempo region
          // sat in the first 0.01% of a LINEAR 0.02..30 track — one pixel of
          // travel was a 100x tempo jump, so the control was effectively gone.
          // Log scale spans the 3.2 decades evenly: fine control at 0.023 (the
          // restored held-pause tempo) AND at 3.27 (true physical real-time).
          UiSliderFloat("ISCO orbit (screen seconds)", &app.uiIscoSeconds, 0.02f, 30.0f,
                        "%.3f s", ImGuiSliderFlags_Logarithmic);
          if (ImGui::IsItemHovered())
            ImGui::SetTooltip("How long ONE ISCO ORBIT takes on screen. LOWER = faster.\n"
                              "The compression is DERIVED from the hole's mass\n"
                              "(T_isco = 92.3436*GM), not a chosen multiplier.\n"
                              "Default 0.52 s is DERIVED: play is capped at 72.7x c\n"
                              "(CHLADNI_VCAP 1.2 vs c*dt 0.0165), so compressing by\n"
                              "72.7 puts the hole on the same clock as the Chladni\n"
                              "regime. Gravity is otherwise 176x slower at ISCO.\n"
                              "Physical orbits are 38s (ISCO) to 12.5min (r=18) —\n"
                              "visually static, and too slow for the streak path,\n"
                              "which is why near-hole matter reads as dots.\n"
                              "1x = true physical rate. Physics never sees this.");
          ImGui::Checkbox("Spectral colour (Planck bands)", &app.uiTogSpectralColour);
          ImGui::Checkbox("Accretion gas softening", &app.uiTogAccretionGas);
          ImGui::Checkbox("Fluid streak (flux-conserving arc)", &app.uiTogFluidStreak);
          if (ImGui::IsItemHovered())
            ImGui::SetTooltip("bit18: the sprite quad GROWS with the motion arc and\n"
                              "brightness falls as 1/length (flux conserved), so fast\n"
                              "matter draws a long dim ribbon. OFF = the old clamped\n"
                              "streak that could never exceed one sprite.");
          ImGui::SliderInt("Physics substeps (fast, stable)", &app.uiPhysicsSubsteps, 1, 32);
          if (ImGui::IsItemHovered())
            ImGui::SetTooltip("N orbit steps/frame. Leave time at x1, dial THIS up:\n"
                              "advances Nx time per frame (fast trails, volume fill)\n"
                              "WITHOUT the dt-blowup that x64 causes. Full physics runs\n"
                              "ONCE; the extra N-1 are the LIGHT orbit kernel (central\n"
                              "gravity only) so it stays cheap. Rest/BH only, not play.");
          ImGui::Checkbox("Time-lapse orbit playback", &app.uiTogAnalyticSpin);
          if (ImGui::IsItemHovered())
            ImGui::SetTooltip("bit20 DEFAULT ON: the clean time-lapse. Sprites sweep at\n"
                              "the real Omega(r), fixed-rate clock (smooth, no jitter),\n"
                              "and the ray-march samples the SAME advanced field so\n"
                              "emission + sprites agree. A timelapse of the real orbits.\n"
                              "OFF = raw physics motion (slow ~38s/orbit). ISCO dial = speed.");
          // BH ray-march UI deleted 2026-08-27 20:49:10 (his order) — the
          // pass, its bit19 toggle and its emission/extent/shadow dials are gone.

            ImGui::SetTooltip("Inner no-emit radius: matter inside this doesn't light,\n"
                              "so the centre goes DARK (the shadow). 0 = fill the core;\n"
                              "~2.6 = photon-capture shadow; 3 = ISCO gap.");

          ImGui::SeparatorText("LENS + LIGHT TRAILS");
          UiSliderFloat("Smear length", &app.uiSmearShutter, 0.0f, 60.0f, "%.1f");
          UiSliderFloat("Smear hold", &app.uiSmearHold, 0.0f, 1.0f, "%.2f");
          if (ImGui::IsItemHovered())
            ImGui::SetTooltip("How much colour the band KEEPS along its length.\n"
                              "0 = fades out fast, which reads as blur. 1 = holds\n"
                              "full strength the whole way, which is what makes a\n"
                              "pixel stretch read as solid bands instead of a\n"
                              "smudge.");
          if (ImGui::IsItemHovered())
            ImGui::SetTooltip("How long the shutter is open on the motion smear.\n"
                              "The star pass measures 0.05 s of REAL travel; this\n"
                              "multiplies it. 0 = no smear. Works on the picture,\n"
                              "not per star, so it cannot make hair.");
          if (ImGui::IsItemHovered())
            ImGui::SetTooltip("bit17: near-hole splat softening (size x3, lum /9,\n"
                              "falloff 5.0 -> 1.2) inside 4 r_h. OFF = sharp,\n"
                              "like the rest of the field. The blur A/B.");
          if (ImGui::IsItemHovered())
            ImGui::SetTooltip("bit16: colour from the real Planck band integral\n"
                              "instead of the blackbody FIT, and the supernovaRamp\n"
                              "hue mix off. OFF = the old fit + ramp (A/B).");
          if (ImGui::IsItemHovered())
            ImGui::SetTooltip("bit15: shadow COMPUTED by marching null geodesics of the\n"
                              "honest metric (b_c = 2.598 r_s) instead of the r_h-sized\n"
                              "particle silhouette. OFF = the old silhouette (A/B).");
          ImGui::SetItemTooltip("Screen-space gravitational lens + shadow");
          ImGui::Checkbox("Adaptive sub-step (central)", &app.uiTogAdaptiveSubstep);
          ImGui::SetItemTooltip("GMAT-style: sub-step the central pull near the core so "
                                "a close pass ORBITS instead of plunging on a saturated "
                                "c·dt kick. Needs 'Central SMBH pull' on. OFF = old single kick.");
          ImGui::Checkbox("PM gravity (Poisson −∇Φ)", &app.uiTogPMGravity);
          ImGui::Checkbox("SPH pressure force (bit11)", &app.uiTogSphPressure);
          ImGui::SetItemTooltip("Real energy-conserving self-gravity: solve ∇²Φ=4πGρ on the "
                                "128³ grid each frame (red-black SOR), force = −∇Φ. Replaces the "
                                "per-frame centroid/COM attractors that pumped the cold cluster to the "
                                "speed cap. ON overrides the bit0/bit9 legacy force.");
          ImGui::Checkbox("SPH viscosity + shock heat (bit12)", &app.uiTogSphVisc);
          ImGui::SetItemTooltip("Slice 3: Monaghan artificial viscosity + energy equation. "
                                "Approaching gas shocks: KE converts to internal energy u "
                                "(heat), pressure resists interpenetration. Needs bit11 on.");
          ImGui::Checkbox("SPH radiative cooling (bit13)", &app.uiTogSphCool);
          ImGui::SetItemTooltip("Slice 4: optically-thin sink, du/dt ∝ −ρT⁴. Hot plasma "
                                "radiates u away toward the cold floor; cold gas untouched "
                                "(T⁴ steepness). The honest energy sink — lets shocked gas "
                                "cool, lose pressure and recollapse. Needs bit12 on.");
          UiSliderFloat("Cooling tau (s)", &app.uiSphCoolTau, 0.1f, 30.0f, "%.1f");
          ImGui::SetItemTooltip("Cooling e-fold time at cap temperature (1.35e12 K) and "
                                "density 1: small = radiates fast.");
        }

        ImGui::Checkbox("Ortho Camera", &app.uiOrthoMode);
        ImGui::SetItemTooltip(
            "Toggle between Orthographic (HTML vibe) and Perspective");

        // SIZE = real stellar radius. Anchor: 1 M☉ star = 1 R☉ (the Sun). The
        // population spans the real IMF (0.08–150 M☉) → radius R=M^0.8 = 0.13–55
        // R☉. The slider is the on-screen scale (×), and via the size↔mass↔gravity
        // coupling it also scales how hard the cluster pulls.
        UiSliderFloat("Star scale", &app.uiParticleSize, 0.5f, 10.0f, "×%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiParticleSize = 2.0f;
        ImGui::SetItemTooltip("On-screen scale of each star (1 M☉ = 1 R☉). "
                              "Also scales the cluster's mass/gravity.");
        {
          float k = app.uiParticleSize; // ×scale
          ImGui::TextDisabled("  1 star = 1 R☉ (Sun) | range 0.13–55 R☉ "
                              "(0.08–150 M☉) | drawn ×%.1f", k);
        }

        UiSliderInt("Amount", &app.uiParticleCount, 0, 10000000);
        if (ImGui::Button("Reset to Default")) {
          app.uiParticleCount = 2000000;
        }
        ImGui::SetItemTooltip("Active number of particles");

        // FULL SIMULATION RESET: re-run the deterministic spawn (same seed,
        // same IMF masses) and re-upload — the field returns to t=0 exactly:
        // all eaten stars restored, all heat gone, fresh star map.
        if (ImGui::Button("RESET SIMULATION")) {
          particles.init(PARTICLE_COUNT, MAX_WAVE_DEPTH);
          auto freshData = packForGPU(particles);
          renderer.uploadParticles(freshData.data(), PARTICLE_COUNT);
          renderer.setBlackHolePose(false, 0.0f); // release any posed BH latch
          printf("[SIM] FULL RESET — field respawned at t=0\n");
        }
        ImGui::SetItemTooltip("Respawn the entire field at its initial state");

        // ── ANALYTIC BLACK HOLE — pose the end-state, don't evolve into it ──────
        // "Make blue, don't generate it." We arrange the particles directly into
        // the closed-form black-hole configuration — a thin Keplerian accretion
        // disk with an empty shadow inside r_in — and grade the MASS hot-inner →
        // cool-outer. The existing REST renderer (star-map path) colours by mass
        // (Teff=5772·M^0.55 → red dwarf … blue giant), and the analytic Kerr Ω /
        // Doppler / lensing already run off position. So this snaps a real,
        // scale-anchored black hole onto the screen using only the maths the BH
        // needs — no real-time collapse. Sim is paused so it stays posed.
        // r_s(field) = 1.0 sim unit (units.h conservation anchor).
        if (ImGui::Button("RENDER BLACK HOLE (analytic)")) {
          const int N = PARTICLE_COUNT;
          std::vector<space::GPUParticle> bh((size_t)N);
          // Disk must sit OUTSIDE the geometric shadow (b = 2.6·r_s = 2.6 sim for
          // the full field mass). Inner edge = ISCO ≈ 3·r_s = 3.0 sim.
          const float r_in = 3.0f, r_out = 12.0f;  // disk span, sim units
          const float M_hi = 18.0f, M_lo = 0.3f;   // inner blue-white → outer red
          for (int i = 0; i < N; ++i) {
            uint32_t hsh = (uint32_t)i * 2654435761u;          // Knuth hash → 3 deterministic uniforms
            auto rnd = [&](uint32_t salt) {
              uint32_t x = hsh ^ (salt * 0x9E3779B9u);
              x ^= x >> 15; x *= 0x85EBCA6Bu; x ^= x >> 13;
              return (float)(x & 0xFFFFFFu) / 16777216.0f;
            };
            float u1 = rnd(1), u2 = rnd(2), u3 = rnd(3);
            float r   = r_in * std::pow(r_out / r_in, u1);     // log-uniform: inner-dense
            float phi = u2 * 6.2831853f;
            float hgt = 0.04f * r;                             // thin disk
            float z   = (u3 - 0.5f) * 2.0f * hgt;
            float x   = r * std::cos(phi);
            float y   = r * std::sin(phi);
            float frac = (r_out - r) / (r_out - r_in);         // 1 inner → 0 outer
            float mass = M_lo * std::pow(M_hi / M_lo, frac);   // heavy inner → light outer
            space::GPUParticle &p = bh[(size_t)i];
            p.x = x; p.y = y; p.z = z; p.mass = mass;
            p.vx = 0; p.vy = 0; p.vz = 0; p.phase = 0;
            p.prevX = x; p.prevY = y; p.prevZ = z; p.temperature = 0.0f;
            p.spinX = 0; p.spinY = 0; p.spinZ = 0; p.charge = 0;
            p.entanglementID = (uint32_t)i; p.pad1 = 0; p.pad2 = 0; p.pad3 = 0;
          }
          renderer.uploadParticles(bh.data(), N);
          // Drive the REAL lens from our geometry: declare a formed hole of the
          // whole field mass (conservation anchor → r_s = 1.0 sim, shadow 2.6).
          renderer.setBlackHolePose(true, (float)space::units::kMbhMsun);
          app.uiTogLensShadow = true;   // bit8: lens + secondary image + raytracer
          app.uiOrthoMode = true;       // lens shadow only computes in ortho
          // NOT paused: the sim keeps running so the spatial hash rebuilds each
          // frame for the geodesic raytracer — but renderer freezes the physics
          // integrator while posed, so the disk stays analytically posed.
          simPaused = false;
          printf("[BH] analytic black-hole pose uploaded (%d particles, disk %.2f–%.2f sim); "
                 "geodesic raytracer ON (M=%.3e M_sun)\n", N, r_in, r_out, space::units::kMbhMsun);
        }
        ImGui::SetItemTooltip("Pose particles into the closed-form BH disk + shadow (no sim). "
                              "Turn ON 'Lens / shadow' for the lensed dark shadow.");

        if (simPaused) {
          ImGui::SameLine();
          ImGui::TextColored(ImVec4(1.0f, 0.8f, 0.2f, 1.0f), "PAUSED [space]");
        }
        if (timeWarp != 1.0f) {
          ImGui::TextColored(ImVec4(0.4f, 0.9f, 1.0f, 1.0f),
                             "TIME x%.2f [shift+arrows]", timeWarp);
        }

        // BH-fakeness dials REMOVED (2026-06-26, Jamal "all the params from the
        // black-hole fakeness gone, dead ends gone"): BH Size / Lens Bend / Arc
        // Wrap / Horizon Exposure / Trail Gain drove the now-disabled fake
        // lens/shadow/analytic-arc-trail layers (the de-stacking). Kept: the
        // dials that drive REAL physics-colour/motion.
        ImGui::SeparatorText("COLOUR");
        // ── LOGARITHMIC FADERS (2026-08-02 19:3x) — Jamal: "first millimeter
        // feels like more variety then the last 99% of the fader."
        // Both dials add KELVIN, and colour-vs-Kelvin is a logarithmic
        // relationship — the continuum LUT is itself log-spaced
        // (spectral_lut.h continuumTempAt: TMin·(TMax/TMin)^(i/N), 300 K→80 kK
        // over 256 bins). So equal SCREEN travel must mean equal RATIO in K,
        // not equal absolute K. On the old linear taper the entire visible
        // red→orange→white→blue walk happened in the bottom few percent and
        // the top 90% of throw was all clamped blue-white — exactly what he
        // felt. ImGuiSliderFlags_Logarithmic makes travel proportional to the
        // ratio, so the perceptual range spreads across the whole fader.
        // Not a range change: both end values are unchanged, only the taper.
        UiSliderFloat("Colour Spectrum", &app.uiColorTempK, 0.0f, 100000.0f, "%.0f",
                      ImGuiSliderFlags_Logarithmic);
        ImGui::SetItemTooltip("Speed->temperature colour gain: low = warm/red field, high = full red->blue spectrum (hot matter blue)");
        UiSliderFloat("Plasma Heat", &app.uiHeatGain, 0.0f, 6000.0f, "%.0f",
                      ImGuiSliderFlags_Logarithmic);
        ImGui::SetItemTooltip("Thermal heat->colour gain: low = warm/red field (white rare), high = play-heat drives white/blue plasma");

        // ── STAR LAWS (2026-07-28) — these were hardcoded constants in
        // render.metal; every star experiment cost a rebuild. Defaults below
        // reproduce those constants exactly. Ranges are LOGARITHMIC where the
        // quantity spans decades: a linear slider on a 27,000:1 range spends
        // ~99% of its travel in the top decade and is unusable.
        // Right-click any of these to snap back to the shipped default.
        ImGui::SeparatorText("STAR LAWS");
        UiSliderFloat("Lum Exponent", &app.uiStarLumExp, 0.5f, 4.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right)) app.uiStarLumExp = 3.5f;
        ImGui::SetItemTooltip(
            "L = M^this. THE colour lever, per the [KPROBE] measurement: at 3.5 "
            "about 1%% of stars (all >10,000K) emit 75%% of the light, so the "
            "visible field is blue while 73%% of your stars are actually below "
            "2515K. LOWER this to lift the orange bulk into view. Physical = 3.5.");
        UiSliderFloat("Lum Gain", &app.uiStarLumGain, 0.01f, 100.0f, "%.3f",
                      ImGuiSliderFlags_Logarithmic);
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right)) app.uiStarLumGain = 2.5f;
        ImGui::SetItemTooltip("Overall star brightness multiplier. Exposure "
                              "calibration point: sun-type reads as a visible point at 2.5.");
        UiSliderFloat("Lum Ceiling", &app.uiStarLumCeil, 10.0f, 65000.0f, "%.0f",
                      ImGuiSliderFlags_Logarithmic);
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right)) app.uiStarLumCeil = 1000.0f;
        ImGui::SetItemTooltip(
            "Hard clip on star luminance. Everything above it is EXACTLY one "
            "brightness. WARNING: raising this was the 07-26 asinh failure - it "
            "pushes more pixels into the sensor bleach and whitens MORE of the "
            "field. Lower the exponent instead.");
        UiSliderFloat("Kelvin Scale", &app.uiStarKelvinA, 1000.0f, 15000.0f, "%.0f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right)) app.uiStarKelvinA = 5772.0f;
        ImGui::SetItemTooltip("K = this * M^p. 5772 = the Sun's T_eff, so a 1 "
                              "solar-mass particle renders as the Sun.");
        UiSliderFloat("Kelvin Exponent", &app.uiStarKelvinP, 0.0f, 1.2f, "%.3f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right)) app.uiStarKelvinP = 0.55f;
        ImGui::SetItemTooltip(
            "K = A * M^this. Sets the WIDTH of the colour spread: 0 = every star "
            "the same temperature, 0.55 spans 2944K (0.3 Msun, orange) to "
            "14,140K (5 Msun, blue-white).");
        // ── STAR SIZE (2026-07-28) — measured meanPx 1.02, 99.2% of stars
        // pinned at the 1 px floor. A 1 px sprite has no area to carry hue.
        ImGui::SeparatorText("STAR SIZE  (measured: mean 1.02 px)");
        UiSliderFloat("Size Gain", &app.uiStarSizeGain, 0.1f, 100.0f, "%.2f",
                      ImGuiSliderFlags_Logarithmic);
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right)) app.uiStarSizeGain = 1.0f;
        ImGui::SetItemTooltip(
            "Blunt multiplier on every star's sprite diameter. START HERE: at "
            "1.0 the whole dwarf bulk is pinned to the 1 px floor and cannot "
            "show colour or a core. Watch [KPROBE-SCALE] meanPx in the log.");
        UiSliderFloat("Size Exponent", &app.uiStarSizeExp, 0.0f, 2.0f, "%.3f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right)) app.uiStarSizeExp = 0.8f;
        ImGui::SetItemTooltip(
            "R = M^this. 0.8 = the true stellar radius relation. LOWER = dwarfs "
            "and giants converge in size; 0 = every star identical size.");
        UiSliderFloat("Size Floor (px)", &app.uiStarSizeFloor, 0.25f, 16.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right)) app.uiStarSizeFloor = 1.0f;
        ImGui::SetItemTooltip(
            "Minimum sprite diameter in PIXELS. This is what currently pins "
            "99.2%% of the field to one size - the same condition that got the "
            "old saturation-PSF law removed for looking 'weirdly the same size'.");
        UiSliderFloat("Size Ceiling (px)", &app.uiStarSizeCeil, 4.0f, 400.0f, "%.0f",
                      ImGuiSliderFlags_Logarithmic);
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right)) app.uiStarSizeCeil = 48.0f;
        ImGui::SetItemTooltip("Soft (tanh) ceiling in PIXELS. Measured max is "
                              "16.3 px, so at 48 this is not currently binding.");
        // Streak Length + Collapse % REMOVED (2026-06-26, Jamal: dead).

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

      if (false && ImGui::CollapsingHeader("NEW SCIENCE (Phase 9)", // removed 2026-06-26
                                  ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Indent();
        ImGui::Checkbox("ODS-06 Black Holes", &app.uiBlackHoles);
        ImGui::SetItemTooltip("Enable gravitational collapse "
                              "(Schwarzschild "
                              "radius) at high density");
        ImGui::Unindent();
      }

      if (false && ImGui::CollapsingHeader("INDUSTRY DEBUGGING (Phase 7)")) { // removed 2026-06-26
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

      if (false && ImGui::CollapsingHeader("VJ MODE & AUDIO INPUT", // removed 2026-06-26
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

        // "Drive" slider REMOVED (2026-06-26, Jamal: "the drive button, gooo,
        // destroyed everything anyways"). It was a mislabeled scale/speedCap dial
        // that nuked the sim. Gone.
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

      // Keyboard Mode toggle REMOVED (2026-06-26, Jamal).
      ImGui::Unindent();

      if (false && ImGui::CollapsingHeader("DYNAMICS", ImGuiTreeNodeFlags_DefaultOpen)) { // removed 2026-06-26 (jitter unlinked, wave depth dead)
        ImGui::Indent();
        ImGui::Separator();
        ImGui::Text("GLOBAL LFO");
        UiSliderFloat("LFO Rate", &app.uiLFORate, 0.01f, 10.0f, "%.2f Hz");
        UiSliderFloat("LFO Depth", &app.uiLFODepth, 0.0f, 1.0f, "%.2f");
        ImGui::SetItemTooltip("Modulates Size and Scale over time");

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
        // Reset STATE — re-forms the black hole after hyperdrive (unwinds the
        // accumulated render-spin so it stops rendering warped, + re-seeds the
        // particles) WITHOUT touching the camera, so your framing is kept.
        if (ImGui::Button("Reset State (keep camera)")) {
          spinVelX = spinVelY = 0.0f;
          spinAngleX = spinAngleY = 0.0f;
          spinHold = 0.0f;
          renderer.triggerReset();
        }
        ImGui::SetItemTooltip(
            "Re-form the black hole (unwind spin + re-seed) without moving the "
            "camera. Use after hyperdrive when the BH comes back warped.");
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
        UiSliderFloat("Exposure", &app.uiExposure, 0.01f, 100.0f, "%.3f",
                      ImGuiSliderFlags_Logarithmic);
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiExposure = 1.0f;
        ImGui::SetItemTooltip("Global camera iris: scales ALL light before the "
                              "tonemap. Stop down (<1) until the cluster core "
                              "resolves instead of burning to a blob");

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

        UiSliderFloat("Neon Grade", &app.uiNeonGrade, 0.0f, 1.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiNeonGrade = 0.0f;
        ImGui::SetItemTooltip("Cyberpunk color grade (indigo/magenta/cyan)");

        UiSliderFloat("Grade LUT", &app.uiGradeAmount, 0.0f, 1.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiGradeAmount = 0.0f;
        ImGui::SetItemTooltip(
            "Display grade LUT (33^3, applied after the tonemap).\n"
            "Shadow lift toward hue 280 deg — the ONE arc neither the Planck\n"
            "locus nor the supernova emission lines occupy, so it cannot\n"
            "compete with a real colour. Gated on chroma, so faint stars keep\n"
            "their hue; only the neutral void takes the tint.\n"
            "Lift is capped at 0.03, under sRGB's 0.04045 linear-segment\n"
            "threshold, so it stays inside the display's defined toe.");

        UiSliderFloat("Vignette", &app.uiVignette, 0.0f, 1.0f, "%.2f");
        if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
          app.uiVignette = 0.0f;
        ImGui::SetItemTooltip("Cinematic edge darkening");
        ImGui::Unindent();
      }

      if (false && ImGui::CollapsingHeader("VJ FX (Resolume-style)", // removed 2026-06-26
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

      if (false && ImGui::CollapsingHeader("PHYSICS STATS")) { // removed 2026-06-26
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

      if (false && ImGui::CollapsingHeader("DEBUG GPU", // removed 2026-06-26
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

    // ── MASTER PATCH — REMOVED from the UI per Jamal (2026-06-21). It was a
    // redundant dev aggregator (16 faders that also live in PHYSICS ARCHITECT,
    // plus a "Print Values to Log" defaults dumper). Gated off (if(false)) not
    // deleted, so the dial-defaults tool is one line away if it's ever wanted.
    if (false) {
      ImGui::SetNextWindowPos(ImVec2(390, 30), ImGuiCond_FirstUseEver);
      ImGui::SetNextWindowSize(ImVec2(300, 0), ImGuiCond_FirstUseEver);
      ImGui::Begin("MASTER PATCH");

      // ── Tempometer: live spin speed ──────────────────────────────────
      {
        float spinMag = std::sqrt(spinVelX * spinVelX + spinVelY * spinVelY);
        float revs = spinMag / 6.28319f;     // rad/s → rev/s (on screen)
        float frac = spinMag / kSpinMax;     // fraction of light-speed orbit
        ImGui::TextColored(ImVec4(0.5f, 0.85f, 1.0f, 1.0f),
                           "%s  %.0f%% of light-speed  ·  %.1f rev/s",
                           frac > 0.98f ? "⟳ MAX = c (light speed)" : "⟳ SPIN",
                           frac * 100.0f, revs);
        char ov[32];
        snprintf(ov, sizeof(ov), "%.0f%%", frac * 100.0f);
        ImGui::ProgressBar(frac, ImVec2(-1.0f, 0.0f), ov);
      }

      ImGui::SeparatorText("Particles");
      UiSliderFloat("Size##mp", &app.uiParticleSize, 0.5f, 10.0f, "%.2f");
      UiSliderInt("Amount##mp", &app.uiParticleCount, 0, 10000000);
      UiSliderFloat("Sharpness##mp", &app.uiSharpness, 1.0f, 40.0f, "%.1f");
      UiSliderFloat("Grain##mp", &app.uiGrainAlpha, 0.01f, 1.0f, "%.3f");

      // BH Size / Disk Thickness dials REMOVED (2026-06-26) — fake lens/disk.

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
        printf("[PATCH] size=%.2f count=%d sharp=%.1f grain=%.3f "
               "bhSize=%.2f disk=%.3f scale=%.0f wave=%.1f lfoRate=%.2f "
               "lfoDepth=%.2f bloom=%.2f fluidity=%.2f chroma=%.3f vign=%.2f\n",
               app.uiParticleSize, app.uiParticleCount, app.uiSharpness,
               app.uiGrainAlpha, app.uiShadowRadius,
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
    // Push volatile settings back into synth
    // Jitter KILLED 2026-09-01 (his order: "its from v1 it never brought
    // anything good") — dial deleted, synth pitch-drift pinned 0 (synth.h),
    // GPU shimmer consumer deleted (particles.metal).
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
    // F5 2026-08-10: hand the shader the real view axis. Today the camera still
    // looks at the origin, so this equals normalize(-cameraPos) — the exact
    // expression render.metal used to compute inline — making this change a
    // visual NO-OP by construction. That is the verification: if the picture
    // moves, the plumbing is wrong.
    camera.getForward(config.cameraForward);
    config.orthoMode = app.uiOrthoMode;
    config.phaseViz = app.uiPhaseViz;
    config.phaseVizAmount = app.uiPhaseVizAmount;
    config.shadowRadius = app.uiShadowRadius;
    config.smearShutter = app.uiSmearShutter;
    config.smearHold = app.uiSmearHold;
    config.streakLen = app.uiStreakLen;
    config.colorTempK = app.uiColorTempK;
    // STAR LAW DIALS (2026-07-28) — identity defaults.
    config.starLumExp = app.uiStarLumExp;
    config.starLumGain = app.uiStarLumGain;
    config.starLumCeil = app.uiStarLumCeil;
    config.starKelvinA = app.uiStarKelvinA;
    config.starKelvinP = app.uiStarKelvinP;
    config.starSizeGain = app.uiStarSizeGain;
    config.starSizeExp = app.uiStarSizeExp;
    config.starSizeFloor = app.uiStarSizeFloor;
    config.starSizeCeil = app.uiStarSizeCeil;
    config.heatGain = app.uiHeatGain;
    // Pack the BH mechanism toggles into the bitmask uniform.
    config.bhToggles =
        ((app.uiTogFieldGravity ? 1u : 0u) << 0) |
        ((app.uiTogCentralSMBH  ? 1u : 0u) << 1) |
        ((app.uiTogSeedCapture  ? 1u : 0u) << 2) |
        ((app.uiTogSeedMerge    ? 1u : 0u) << 3) |
        ((app.uiTogOriginPin    ? 1u : 0u) << 4) |
        ((app.uiTogRelaxation   ? 1u : 0u) << 5) |
        ((app.uiTogResurrection ? 1u : 0u) << 6) |
        ((app.uiTogSeedRender   ? 1u : 0u) << 7) |
        ((app.uiTogLensShadow   ? 1u : 0u) << 8) |
        ((app.uiTogAdaptiveSubstep ? 1u : 0u) << 9) |
        ((app.uiTogPMGravity    ? 1u : 0u) << 10) |
        ((app.uiTogSphPressure  ? 1u : 0u) << 11) |
        ((app.uiTogSphVisc      ? 1u : 0u) << 12) |
        ((app.uiTogSphCool      ? 1u : 0u) << 13) |
        ((app.uiTogNoLegacyPressure ? 1u : 0u) << 14) |
        ((app.uiTogMetricShadow ? 1u : 0u) << 15) |
        ((app.uiTogSpectralColour ? 1u : 0u) << 16) |
        ((app.uiTogAccretionGas ? 1u : 0u) << 17) |
        ((app.uiTogFluidStreak ? 1u : 0u) << 18) |
        ((app.uiTogAnalyticSpin ? 1u : 0u) << 20);
    config.sphCoolTau = app.uiSphCoolTau;
    config.iscoScreenSeconds = app.uiIscoSeconds;
    config.physicsSubsteps = app.uiPhysicsSubsteps;
    config.collapseFrac = app.uiCollapseFrac;

    // ── Update ADSR (Phase 12.6) ──────────────────────────────────
    synth.envelopeParams().attack = app.uiAttack / 1000.0f;
    synth.envelopeParams().release = app.uiRelease / 1000.0f;
    // Supernova adds on top of user slider values
    config.bloomIntensity = app.uiBloom;
    config.exposure = app.uiExposure;
    // A/B RESULT, KEPT AS A LEDGER ENTRY (2026-07-26 19:20:00): a temporary
    // sweep of this value (1 / 3 / 10, 6 s per step, untouched silent run, 167
    // samples) showed framerate is FLAT in final-image brightness — within
    // matched avgLum bins: lum<1 -> 34.2/33.9/34.2 fps, lum 1-4 -> 34.6/35.5/
    // 35.0, lum 4-8 -> 33.5/34.0. So display saturation costs NOTHING in fps.
    // The apparent fps-vs-brightness correlation inside a single run is the
    // COLLAPSE driving both: density raises overlap (fill cost = real frames)
    // and raises brightness (free). Do not re-chase exposure for performance;
    // the fps suspect remains sprite fill (handoff 2026-07-26 §3.4).
    // Spin blurs into a solid disk at high RPM: boost the motion-blur feedback
    // with spin speed so fast rotation smears instead of strobing.
    // Trails are the user's Fluidity slider ONLY. The spin must stay a CRISP
    // rigid rotation of the real particles — no persistence smear. (The 0.96
    // spin-driven feedback fused the rotating shape into a blurry squashy comet
    // with a leading/lagging half. Killed.)
    // WHITEOUT DIAGNOSTIC (2026-07-23): trail persistence is max(color,
    // prev*decay) in postfx — it HOLDS blown-out splat pixels for seconds
    // (at 0.99 decay and 5 FPS a white pixel outlives its cause by ~20 s of
    // wall time). Force persistence OFF while PAUSED: if pausing mid-shape
    // now stays crisp instead of whiting out, the trail feedback is the
    // whitener confirmed.
    config.trailDecay = simPaused ? 0.0f : app.uiTrailDecay;
    config.debugBypassPostFX = debugBypassPostFX;
    config.debugNoBleach = debugNoBleach;
    config.simPaused = simPaused; // renderer freezes the emergent time-lapse clock while paused
    config.pauseHoldTimelapse =
        simPaused && (spaceHeld || pauseTimelapseLatched); // HOLD/LATCH: time-lapse lives on
    // Scope-line gate: spin magnitude (0→cap) drives the oscilloscope beams.
    // 0 when at rest → pure points; ramps to 1 at the clean-120fps spin cap.
    {
      float spinMag = std::sqrt(spinVelX * spinVelX + spinVelY * spinVelY +
                                spinVelZ * spinVelZ);
      config.oscAmount = std::clamp(spinMag / kSpinMax, 0.0f, 1.0f);
      // Spin velocity (for analytic trail/Doppler) + accumulated angle (for the
      // render-side rigid rotation of the whole shape).
      config.spinX = spinVelX;
      config.spinY = spinVelY;
      config.spinZ = spinVelZ;
      config.spinAngleX = spinAngleX;
      config.spinAngleY = spinAngleY;
      config.spinAngleZ = spinAngleZ;
      // TANGENTIAL pixel-stretch (driven by spin): smear bright pixels along
      // concentric CIRCLES (not radially out), so they stay on their radius —
      // bounded to the BH/SN, never globby — and the spinning bright side fuses
      // into fine concentric "5D" trails. 0 at rest, ramps to 1 at top spin.
      config.pixelStretch = std::clamp(spinMag / kSpinMax, 0.0f, 1.0f);
    }
    config.sharpness = app.uiSharpness;
    config.grainAlpha = app.uiGrainAlpha;
    config.chromaticAmount = app.uiChromatic;
    // Creative FX + beat reactivity
    app.uiFxTime += dt;
    config.glitchAmount = app.uiGlitch;
    config.neonGrade = app.uiNeonGrade;
    config.gradeAmount = app.uiGradeAmount;
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
    if (app.uiSoloCollisions)
      debugFlags |= DEBUG_COLLISIONS;
    if (app.uiFixedTimestep)
      debugFlags |= DEBUG_FIXED_DT;
    if (app.uiQuantumEntangle)
      debugFlags |= DEBUG_ODS01;
    if (app.uiBlackHoles)
      debugFlags |= DEBUG_ODS06;
    // TEMP-DIAG: SS_PLAY_SKIP="sculpt,impulse,web,jitter,symbreak"
    // (any subset) disables individual play-force families (bits 16-22) so the
    // [VEL]/[SHAPE] drift names its own culprit. This is the play-stack
    // rationalization instrument — one gate per LIVE additive play force.
    // Measurement only — mirrors SS_SPH_SKIP.
    {
      static uint32_t playSkipBits = 0;
      static bool playSkipParsed = false;
      if (!playSkipParsed) {
        playSkipParsed = true;
        if (const char *sk = getenv("SS_PLAY_SKIP")) {
          if (strstr(sk, "sculpt"))    playSkipBits |= (1u << 16); // Atom-Model gradient (core Chladni)
          // bit17 (breathing) + bit19 (swirl) retired 2026-07-09 — both forces
          // deleted after the rationalization sweep proved zero shape effect.
          if (strstr(sk, "impulse"))   playSkipBits |= (1u << 18); // point-source impulse/shockwave
          if (strstr(sk, "web"))       playSkipBits |= (1u << 20); // chord webbing (inter-harmonic)
          if (strstr(sk, "symbreak"))  playSkipBits |= (1u << 22); // Noether symmetry-break impulse
          // 🔬 BUG_lines_2026-07-12: "dynfric" gates the UNGATED Chandrasekhar
          // dynamical-friction block (particles.metal ~1277) — a REST force,
          // parked in this parser because it shares the debugFlags transport.
          if (strstr(sk, "dynfric"))   playSkipBits |= (1u << 24); // per-cell dyn friction (rest)
          printf("[PLAY-SKIP] %s -> bits 0x%x\n", sk, playSkipBits);
        }
      }
      debugFlags |= playSkipBits;
    }

    // EIGENMODE-ONLY IS THE DEFAULT (2026-07-19 19:4x, Jamal's verdict on the
    // clean A/B: "looks a loooot better... the motion is amazing, fps better").
    // The cylindrical cavity eigenmode + Gor'kov (bit23) is ON by default and
    // the Atom-Model sphere-surface sculpt (the hollow-shell maker) is OFF by
    // default (bit16 skip). Escape hatches for A/B: SS_NO_EIGENMODE=1 disables
    // the eigenmode; SS_SCULPT=1 re-enables the sphere sculpt.
    {
      static uint32_t eigenBit = 0;
      static bool eigenParsed = false;
      if (!eigenParsed) {
        eigenParsed = true;
        if (!getenv("SS_NO_EIGENMODE")) {
          eigenBit = (1u << 23);
          printf("[EIGENMODE] ON (bit23, default) — cylindrical cavity + "
                 "Gor'kov (SS_NO_EIGENMODE to disable)\n");
        }
        if (!getenv("SS_SCULPT")) {
          eigenBit |= (1u << 16);   // skip the sphere sculpt (SS_SCULPT=1 re-enables)
          printf("[SCULPT] OFF (default) — sphere-surface sculpt skipped "
                 "(SS_SCULPT=1 to re-enable)\n");
        }
        // Warm-trap kicks DEFAULT OFF (2026-07-20 00:18): the naive velocity
        // kick was MEASURED harmful twice (evaporation + a systematic z-drift
        // to +13.5 — the bisect with kicks off restored symmetric 3D spread,
        // σ=(6.3,6.3,9.8)). SS_WARM=1 re-enables for future correct-Langevin
        // work only.
        if (!getenv("SS_WARM")) {
          eigenBit |= (1u << 27);
          printf("[WARM] OFF (default) — thermal kicks disabled (SS_WARM=1 to experiment)\n");
        }
      }
      debugFlags |= eigenBit;
    }

    // SS_LTRANS=1 → enable α-disc angular-momentum transport (bit25, slice 3).
    // The one missing physics term of the honest-BH chain (state-of-the-union
    // 2026-07-13 §1 link 5): viscous diffusion of the resolved mean flow so the
    // rotation-supported ring ([SHELLV] vt:vr = 10:1) hands its L outward and
    // sinks. Default OFF — show-safe. Verify by numbers: [SHELLV] vt:vr falls,
    // [CORE] M(<0.5) climbs past 1.06e5.
    {
      static uint32_t ltransBit = 0;
      static bool ltransParsed = false;
      if (!ltransParsed) {
        ltransParsed = true;
        if (!getenv("SS_NO_LTRANS")) {   // DEFAULT ON (2026-07-18 01:12:40, honest toggle stack); SS_NO_LTRANS disables
          ltransBit = (1u << 25);
          printf("[LTRANS] ON (bit25) — α-disc angular-momentum transport (default; SS_NO_LTRANS to disable)\n");
        }
      }
      debugFlags |= ltransBit;
    }

    // SS_TEST_NOPULL=1 → bit26: once the honest hole exists (r_h>0), the
    // kernel strips the inward radial gravity component — pure rotation,
    // no pull. 2026-07-19 observe-only probe, default OFF.
    {
      static uint32_t noPullBit = 0;
      static bool noPullParsed = false;
      if (!noPullParsed) {
        noPullParsed = true;
        if (getenv("SS_TEST_NOPULL")) {
          noPullBit = (1u << 26);
          printf("[NOPULL] TEST ON (bit26) — inward gravity OFF once r_h>0 (SS_TEST_NOPULL)\n");
        }
      }
      debugFlags |= noPullBit;
    }

    // SS_NO_DEADSKIP=1 → bit28: restores the pre-2026-08-13 path where a dead
    // particle walks the whole back half of compute_physics. A/B CONTROL ONLY.
    // The skip it disables is output-equivalent (particles.metal:1156 — the
    // write-back is mass-gated, every atomic below it sits inside a mass-gated
    // block), so this bit can only move the FRAME COST, never the picture.
    // That is the point: run the same binary twice, with and without, and the
    // fps delta is attributable to nothing else. Default OFF = skip is ON.
    {
      static uint32_t noDeadSkipBit = 0;
      static bool noDeadSkipParsed = false;
      if (!noDeadSkipParsed) {
        noDeadSkipParsed = true;
        if (getenv("SS_NO_DEADSKIP")) {
          noDeadSkipBit = (1u << 28);
          printf("[DEADSKIP] A/B CONTROL — OFF (bit28): corpses walk the full kernel again (SS_NO_DEADSKIP)\n");
        } else {
          printf("[DEADSKIP] ON (default) — dead particles return at particles.metal:1156\n");
        }
      }
      debugFlags |= noDeadSkipBit;
    }

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

    // A4 SETTLE-HOLD TRIED AND REVERTED, 2026-08-10 16:12:00, on his order.
    // A 2 s hold of the release regime after the audio envelope went Off was
    // built (16:07:41) and rejected on sight: "noo because now the stuck moment
    // is before the pause u just introduced. thats where the snap is at."
    // The hold did not hide the snap, it ISOLATED it -- by inserting a visible
    // pause after the transition, it proved the discontinuity happens EARLIER,
    // at or just after note-off, not at the release->silence edge. So the
    // release->silence boundary is NOT the remaining A4 defect. Do not re-try a
    // settle hold here; it has been measured and it is the wrong end.
    renderer.setEnvelopeState(envState.phase, envState.progress,
                              envState.intensity);
    // S2: main-thread side of the take recorder — move the ring into the log
    // and append this frame's envelope ground truth (what S9's frame-clocked
    // envelope is verified against). No-ops unless SS_RECORD is set.
    takeRec.drain();
    // Offline the frame IS the clock: the row's t is this frame's time so it
    // lines up with replayed events (which carry frame/fps) and with a live
    // take's wall-time rows for the S9 comparison.
    takeRec.frame(space::OfflineClock::get().enabled
                      ? (double)(outFrame - 1) / (double)space::OfflineClock::get().fps
                      : space::TakeRecorder::nowSeconds(),
                  envState.phase, envState.progress, synth.totalAmplitude());
    renderer.setDiskThickness(app.uiDiskThickness);

    // ── STAR-MAP LIFECYCLE: hold the BLACK HOLE after release ────────────────
    // The audio envelope returns to Off (phase 0 = star map) once release ends,
    // but VISUALLY the matter must STAY collapsed as a black hole — the loop is
    // star map → play (supernova) → let go → SLOW collapse into a black hole
    // that PERSISTS. Track a collapse state: it starts when a played note
    // finishes, ramps collapseT 0→1 slowly (the slow collapse), holds at the BH,
    // and resets to the supernova/star map only when a new note plays.
    {
        // HELD-BH LATCH REMOVED (2026-07-10). `collapsed` was set true the first
        // time a note finished and was cleared ONLY by starting another note, so
        // envelopePhase was pinned at 4.0 for the rest of the session. Downstream
        // that meant, permanently, after ONE note:
        //   particles.metal:505  isSilence = (phase < 0.5) -> false: the rest /
        //                        lifecycle branch never ran again
        //   render.metal:644     starMix = 0: star-map colour AND the seed render
        //                        (:790, gated starMix>0.5) were both dead
        //   particles.metal:2056 release damping never released
        //   particles.metal:2010 the "collapse into the BH" gravity, gated to
        //                        phase>3.5, ran forever at envelopeProgress=1
        // i.e. the sim jammed in its endgame state and the star map never came
        // back. envelopePhase now follows the real envelope: 0 at silence.
        //
        // The collapse gesture this latch was faking belongs on a THRESHOLD
        // (density / geometric horizon), not on a phase — see :2015, which
        // already states the intent: "ALWAYS-ON central gravity -> the galaxy
        // self-collapses over time (the BH is the EMERGENT physical sum of the
        // mass falling in, no note required)." That is the next change.
        // PAUSE FREEZES THE REGIME TOO (2026-07-23 04:21, whiteout root cause
        // measured by [LUMPROBE]): SPACE froze positions but the envelope
        // lived on — when the sound died mid-pause, phase→0 flipped the
        // render into the REST star-luminance regime on a still-PACKED play
        // shape: avg scene radiance 0.044 → ~1100 (×25k), white blob, and
        // the overdraw dropped 100 → 7 fps. While paused, hold the envelope
        // uniforms at their pause-moment values so the frame stays in the
        // regime it was paused in.
        static float pausedPhase = 0.0f, pausedProgress = 0.0f;
        static bool  wasPausedEnv = false;
        if (simPaused && !wasPausedEnv) {        // capture at the pause edge
            pausedPhase    = envState.phase;
            pausedProgress = envState.progress;
        }
        wasPausedEnv = simPaused;
        config.envelopePhase    = simPaused ? pausedPhase : envState.phase;   // 0 = star map, else playing
        config.envelopeProgress = simPaused ? pausedProgress : envState.progress;
    }

    float effectiveTotalAmp = synth.totalAmplitude();
    if (app.uiVJMode) {
        for (const auto& vd : voiceData) effectiveTotalAmp += vd.amplitude;
    }

    // Phase 1A: Smoothed amplitude envelope (attack-release)
    // Prevents jarring jumps and ensures particles have time to respond
    static float smoothedAmp = 0.0f;
    // ⏱️ 2026-08-29 — WAS a bare per-FRAME smoother (rise 0.25, decay 0.12), so
    // its time constant depended on frame rate: the decay e-folded in 0.065 s at
    // 120 fps but 0.196 s at 40 fps. This value IS `u.totalAmplitude` in the
    // shader, and it gates playGate (particles.metal:1319) — which selects the
    // 20.69c play velocity cap and the play friction. So the length of the
    // "still playing" tail after a note ends moved with the frame rate.
    // MEASURED 2026-08-29: with SS_SEQ=staccato the probe reports amp=0.000
    // (raw envelope, silent) while vMax still reads ~21c — the shader was still
    // in the play regime because THIS lagged. Now a real time constant.
    // IDENTITY AT 60 fps BY CONSTRUCTION: 1-exp(-(1/60)/0.130380) = 0.120000 and
    // 1-exp(-(1/60)/0.057936) = 0.250000, the exact old coefficients.
    const float kTauRise  = 0.057936f;  // s
    const float kTauDecay = 0.130380f;  // s
    float dtAmp = std::clamp(dt, 1.0f / 480.0f, 0.1f);   // guard stalls
    float rise  = 1.0f - std::exp(-dtAmp / kTauRise);
    float decay = 1.0f - std::exp(-dtAmp / kTauDecay);
    if (effectiveTotalAmp > smoothedAmp)
        smoothedAmp = rise * effectiveTotalAmp + (1.0f - rise) * smoothedAmp;
    else
        smoothedAmp = decay * effectiveTotalAmp + (1.0f - decay) * smoothedAmp;

    // SPACE pause: skip the physics step entirely — no compute dispatch,
    // the field freezes in place; render and camera keep running.
    // TIME WARP scales only the PHYSICS clock (audio/camera stay realtime).
    // Above ~8× the Verlet integrator coarsens (forces are per-frame
    // impulses) — honest tradeoff for review speed.
    // Physics uses a PINNED base dt (0.0165) scaled by timeWarp inside the
    // renderer (fixed step = stable; scaled = time controls work). The clock
    // advances by that same physics dt so the readout matches what the sim does.
    // S3 OFFLINE: warp pinned to 1 and the SECOND dt copy (the one :2753
    // confesses) taken from the same source as the renderer's. Unset ⇒ the
    // two lines below are exactly the live path.
    if (space::OfflineClock::get().enabled) {
      // The dial lives HERE, so the loud line lives here: a leftover ×2 (or a
      // 0.5 — setTimeWarp clamps only to 1e-3) would render a video of the
      // wrong length with nothing on screen to show it. Printed once, before
      // the renderer ever sees the value; the renderer pins again after us.
      static bool sWarned = false;
      if (!sWarned && std::fabs(timeWarp - 1.0f) > 1e-6f) {
        sWarned = true;
        fprintf(stderr, "[OFFLINE] 🚨 warp dial was %.4f at render start (SS_TIME_WARP, slider or preset) — "
                        "FORCED to 1.0. Unpinned, the video would be %.2fx the wrong length.\n",
                timeWarp, timeWarp);
      }
      timeWarp = 1.0f;
    }
    renderer.setTimeWarp(timeWarp);
    float simDt = space::OfflineClock::get().enabled ? (float)space::OfflineClock::get().dt
                                                     : 0.0165f * timeWarp;
    if (!simPaused) {
      renderer.computeStep(simDt, voiceData.data(), (int)voiceData.size(),
                           smoothedAmp, app.uiWaveDepth,
                           effectiveDrive,
                           app.uiEField, app.uiBField, app.uiGravity, app.uiStringStiffness,
                           app.uiRestLength, debugFlags);
      // ⏱️ TRUE TIME — E2, 2026-08-30. Tick the universe clock by the sim time
      // the step ACTUALLY integrated, and tick it AFTER the step, not before.
      // WAS: `kTimeLapse * simDt`, once per FRAME, from a 0.0165 literal this
      // file recomputed for itself. Two faults in one line.
      //   1. It assumed exactly one step per frame. Under substeps it
      //      under-reported elapsed time by exactly N, and under E1's wall-clock
      //      accumulator a frame can integrate 0 or 2 steps, so the readout and
      //      the sim drift apart with no bound.
      //   2. `0.0165f * timeWarp` here is a SECOND copy of the step length,
      //      agreeing with renderer.mm:1466 only by coincidence of the literal.
      //      The renderer owns the step; ask it what it did.
      // kTimeLapse maps integrator time -> real physics seconds, unchanged.
      universeClockSec +=
          (double)space::units::kTimeLapse * renderer.simSecondsLastStep();
      // [UCLOCK] — verification probe for E2. The clock is UI-only, so without
      // this the change is unobservable from a log. Same 240-frame cadence as
      // [PERF]/[GRAV] so the three lines can be read against each other.
      {
        static uint64_t uc = 0;
        if ((uc++ % 240u) == 0u)
          fprintf(stderr, "[UCLOCK] clock=%.6f simSecLastStep=%.6f\n",
                  universeClockSec, renderer.simSecondsLastStep());
      }
    }

    // Two-window mode is a per-frame fact, not a one-time setup: he can also
    // close the controls window with its red button, which window.mm handles
    // by hiding it. Reading visibility here keeps the UI target correct in
    // every one of those paths.
    renderer.setUILayer(window.settingsWindowVisible()
                            ? window.settingsMetalLayer()
                            : nullptr);
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
        auto bhs = renderer.getPhysicsStats();
        float pctIn = (bhs.fieldMassMsun > 1.0f)
                          ? 100.0f * bhs.coreMassMsun / bhs.fieldMassMsun
                          : 0.0f;
        snprintf(buf, sizeof(buf),
                 "FPS: %d | Particles: %dk | Voices: %d | Amp: %.2f | "
                 "CORE %.0f M / %.1f%% in / %.1f%% out | hole %.0f%%",
                 fps, app.uiParticleCount / 1000, vc, synth.totalAmplitude(),
                 bhs.coreMassMsun, pctIn, 100.0f - pctIn,
                 100.0f * std::min(bhs.bhStrength, 1.0f));
        Logger::log(buf);
        printf("\n%s    ", buf);
      } else {
        char buf[256];
        auto bhs2 = renderer.getPhysicsStats();
        float pctIn2 = (bhs2.fieldMassMsun > 1.0f)
                           ? 100.0f * bhs2.coreMassMsun / bhs2.fieldMassMsun
                           : 0.0f;
        snprintf(buf, sizeof(buf),
                 "FPS: %d | Particles: %dk | CORE %.0f M (%.1f%% in / %.1f%% out) "
                 "| biggest body %.0f M | hole %.0f%%",
                 fps, app.uiParticleCount / 1000, bhs2.coreMassMsun, pctIn2,
                 100.0f - pctIn2, bhs2.maxBodyMsun,
                 100.0f * std::min(bhs2.bhStrength, 1.0f));
        Logger::log(buf);
        printf("\n%s    ", buf);
      }

      // ── TEMP/SPEED cluster log (colour calibration data) ──────────────
      // Tagged by state so a test run (SILENCE / NOTE / CHORD, ±SPIN) can be
      // read straight from the log: does temp actually rise on play? does
      // speed rise on spin? what Kelvin/colour do those map to?
      {
        PhysicsStats st = renderer.getPhysicsStats();
        float spinMag = std::sqrt(spinVelX * spinVelX + spinVelY * spinVelY);
        const char *state = (vc == 0) ? "SILENCE" : (vc == 1 ? "NOTE" : "CHORD");
        const char *spinTag = (spinMag > 0.05f) ? " +SPIN" : "";
        // sim temp → shader display Kelvin: kelvin ≈ (3675 + temp*3000); °C = K-273
        float maxK = 3675.0f + st.maxTemp * 3000.0f;
        char tbuf[320];
        snprintf(tbuf, sizeof(tbuf),
                 "[CLUSTER] %s%s | temp avg %.2f max %.2f (max~%.0fK %.0fC) | "
                 "speed avg %.3f max %.3f | spin %.0f%% | amp %.2f",
                 state, spinTag, st.avgTemp, st.maxTemp, maxK, maxK - 273.0f,
                 st.avgSpeed, st.maxSpeed, (spinMag / kSpinMax) * 100.0f,
                 synth.totalAmplitude());
        Logger::log(tbuf);
        printf("\n%s", tbuf);
      }

      // ── Auto GPU Readback Probe — sample 1000, classify ──
      const int PROBE_N = 1000;
      static std::vector<GPUParticle> probe(PROBE_N);
      renderer.readbackParticles(probe.data(), PROBE_N);
      int liveCount = 0, wallCount = 0, insideRS = 0, movingCount = 0;
      int liveBand[10] = {0};
      // COLOR-TEMP probe (2026-06-25): the per-particle temperature (prevW.w)
      // that drives supernovaRamp(temp/SN_TEMP_PEAK=6) at play and heatK. Need
      // its real range at silence vs play to scale SN_TEMP_PEAK correctly (the
      // color temp is a 0–8 sim scale, NOT the 1e12 K kinetic HUD readout).
      float ctMin = 1e9f, ctMax = -1e9f, ctSum = 0.0f;
      // MASS-SPREAD probe (2026-06-25): is there a real stellar mass spread
      // (red dwarfs → giants), or are stars all ~one mass (Jamal: "only small
      // and a bit larger, all same colour")? Buckets in M_sun. Tells us if the
      // colour/size sameness is a RENDER gap (spread exists, dim dwarfs unseen)
      // or a PHYSICS gap (collisions aren't growing a spread).
      int massBucket[6] = {0}; // <0.5, 0.5-2, 2-10, 10-100, 100-1e3, 1e3+
      float mMin = 1e30f, mMax = -1e30f;
      // SHAPE probe (TEMP 2026-07-08, Jamal: "entire star map spawns as a
      // giant tube... center is not a proper center"): per-axis mean + σ of
      // the live population. A ball reads σx≈σy≈σz, mean≈0; a capsule/tube
      // shows one axis σ far larger. Answers spawn-vs-dynamics deformation.
      double sxm = 0, sym = 0, szm = 0, sx2 = 0, sy2 = 0, sz2 = 0;
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
          float ct = p.temperature;
          ctSum += ct;
          if (ct < ctMin) ctMin = ct;
          if (ct > ctMax) ctMax = ct;
          float mm = p.mass;
          if (mm < mMin) mMin = mm;
          if (mm > mMax) mMax = mm;
          int mb = (mm < 0.5f) ? 0 : (mm < 2.0f) ? 1 : (mm < 10.0f) ? 2
                 : (mm < 100.0f) ? 3 : (mm < 1000.0f) ? 4 : 5;
          massBucket[mb]++;
          sxm += p.x; sym += p.y; szm += p.z;
          sx2 += (double)p.x * p.x; sy2 += (double)p.y * p.y;
          sz2 += (double)p.z * p.z;
        }
      }
      float ctAvg = (liveCount > 0) ? ctSum / (float)liveCount : 0.0f;
      printf("\n  [PROBE-%d] live=%d walls=%d insideRS=%d moving=%d  "
             "envPhase=%.1f voices=%d\n",
             PROBE_N, liveCount, wallCount, insideRS, movingCount,
             config.envelopePhase, vc);
      printf("  [COLOR-TEMP] prevW.w  avg=%.3f  min=%.3f  max=%.3f  "
             "(SN_TEMP_PEAK=6 → ramp t=avg/6=%.3f)\n",
             ctAvg, (liveCount ? ctMin : 0.0f), (liveCount ? ctMax : 0.0f),
             ctAvg / 6.0f);
      printf("  [BAND] r<0.4:%d  0.4-0.8:%d  0.8-1.2:%d  1.2-1.6:%d  1.6-2.0:%d  2.0+:%d\n",
             liveBand[0], liveBand[1], liveBand[2], liveBand[3], liveBand[4],
             liveBand[5]+liveBand[6]+liveBand[7]+liveBand[8]+liveBand[9]);
      printf("  [MASS Msun] min=%.2f max=%.1f | <0.5:%d  0.5-2:%d  2-10:%d  "
             "10-100:%d  100-1k:%d  1k+:%d\n",
             (liveCount ? mMin : 0.0f), (liveCount ? mMax : 0.0f),
             massBucket[0], massBucket[1], massBucket[2], massBucket[3],
             massBucket[4], massBucket[5]);
      if (liveCount > 0) {
        double n = (double)liveCount;
        double mx = sxm / n, my = sym / n, mz = szm / n;
        printf("  [SHAPE] mean=(%.1f %.1f %.1f)  sigma=(%.1f %.1f %.1f)\n",
               mx, my, mz,
               std::sqrt(std::max(0.0, sx2 / n - mx * mx)),
               std::sqrt(std::max(0.0, sy2 / n - my * my)),
               std::sqrt(std::max(0.0, sz2 / n - mz * mz)));
        // Net drift = the smoking gun for any one-sided force (2026-07-08).
        double svx = 0, svy = 0, svz = 0;
        for (int i = 0; i < PROBE_N; i++) {
          if (probe[i].mass < 0.001f) continue;
          svx += probe[i].vx; svy += probe[i].vy; svz += probe[i].vz;
        }
        printf("  [VEL] mean v=(%.4f %.4f %.4f) sim/frame  voices=%d\n",
               svx / n, svy / n, svz / n, vc);
      }
      // [SHELLV] — what supports the r≈2.8 shell (AMR slice-3 diagnostic)?
      // Radial profile of mean radial velocity v_r (infall<0), mean tangential
      // speed v_t, from the same 1000-particle probe. Signatures: rotation →
      // v_t ≫ |v_r|; pressure/static → both ≈0; breathing → v_r sign flips
      // between probes. Units: sim/frame.
      {
        const float rEdges[6] = {1.0f, 2.0f, 3.0f, 4.0f, 6.0f, 1e9f};
        double vr[6] = {0}, vt[6] = {0}; int nB[6] = {0};
        for (int i = 0; i < PROBE_N; i++) {
          const auto &q = probe[i];
          if (q.mass < 0.001f) continue;
          float rq = std::sqrt(q.x*q.x + q.y*q.y + q.z*q.z);
          if (rq < 1e-4f) continue;
          int b = 0; while (rq > rEdges[b] && b < 5) b++;
          float vrad = (q.x*q.vx + q.y*q.vy + q.z*q.vz) / rq;
          float v2 = q.vx*q.vx + q.vy*q.vy + q.vz*q.vz;
          vr[b] += vrad;
          vt[b] += std::sqrt(std::max(0.0f, v2 - vrad*vrad));
          nB[b]++;
        }
        printf("  [SHELLV] r<1:%d vr=%+.4f vt=%.4f | 1-2:%d vr=%+.4f vt=%.4f | "
               "2-3:%d vr=%+.4f vt=%.4f | 3-4:%d vr=%+.4f vt=%.4f | 4-6:%d vr=%+.4f vt=%.4f\n",
               nB[0], nB[0] ? vr[0]/nB[0] : 0.0, nB[0] ? vt[0]/nB[0] : 0.0,
               nB[1], nB[1] ? vr[1]/nB[1] : 0.0, nB[1] ? vt[1]/nB[1] : 0.0,
               nB[2], nB[2] ? vr[2]/nB[2] : 0.0, nB[2] ? vt[2]/nB[2] : 0.0,
               nB[3], nB[3] ? vr[3]/nB[3] : 0.0, nB[3] ? vt[3]/nB[3] : 0.0,
               nB[4], nB[4] ? vr[4]/nB[4] : 0.0, nB[4] ? vt[4]/nB[4] : 0.0);
      }
      // [BALANCE] — the linked triad gravity↔spin↔pull, made measurable
      // (entropy diagnostic 2026-07-19). Per shell:
      //   L    = r·v_t         specific angular momentum (SPIN). Track across
      //                        probes: CONSTANT L = no transport → cannot accrete
      //                        (orbits or plunges, never a ring); FALLING L =
      //                        accretion/dissipation is doing work (entropy up).
      //   vcirc= √(GM_enc/r)·kDt  the circular speed the shell needs (GRAVITY),
      //                        from the field mass enclosed inside r (probe est.).
      //   sup  = v_t/vcirc     the balance. sup≈1 holds a stable orbit; sup<1 =
      //                        spin lost to gravity → that shell PLUNGES (PULL wins);
      //                        sup>1 = over-supported → drifts out. This pinpoints
      //                        the exact radius the disk breaks.
      // (Horizon-area/entropy monotonicity = watch [HORIZON] r_h across samples;
      //  any decrease violates the area theorem = physically illegal frame.)
      {
        const float bEdges[6] = {1.0f, 3.0f, 6.0f, 10.0f, 20.0f, 1e9f};
        double sr[6] = {0}, svt[6] = {0}; int nB[6] = {0};
        // RING-RES DEBUG (2026-07-23 18:32, Jamal: "the ring still low res —
        // debug our situation"): the merger-flash SIZE swell (+4px/flashT,
        // temp>2.5, up to +20px) was built for transient novae; if ring
        // matter is CHRONICALLY above threshold, every ring star is a
        // permanently swollen fat blob = the low-res look. Measure it.
        double sFl[6] = {0}; int nHot[6] = {0};
        // DISK THICKNESS (2026-07-26, Jamal: the hole "is still a circle with a
        // camera bend, not a 3D sphere that actually bends anything"). The
        // metric-native design (DESIGN_2026-07-24 §4) states the hard
        // requirement: the disk must be a REAL 3D emitter, because a ray-march
        // of a FLAT annulus has no over/under light paths — the photon ring and
        // the top/bottom arcs only exist if there is vertical structure to bend
        // around. Measure what we actually have: H = sqrt(<z^2>) per shell and
        // the aspect ratio H/R. H/R -> 0 = a sheet of paper (his "0 depth, like
        // an inward spiral of paper"); a real thin accretion disk is H/R ~ 0.01
        // -0.1, a thick/ADAF torus ~0.3-1. Also track whether the disk is BORN
        // flat or COLLAPSES to flat, which decides spawn-vs-physics.
        double szz[6] = {0}, srcyl[6] = {0};
        for (int i = 0; i < PROBE_N; i++) {
          const auto &q = probe[i];
          if (q.mass < 0.001f) continue;
          float rq = std::sqrt(q.x*q.x + q.y*q.y + q.z*q.z);
          if (rq < 1e-4f) continue;
          int b = 0; while (rq > bEdges[b] && b < 5) b++;
          float vrad = (q.x*q.vx + q.y*q.vy + q.z*q.vz) / rq;
          float v2 = q.vx*q.vx + q.vy*q.vy + q.vz*q.vz;
          sr[b] += rq;
          svt[b] += std::sqrt(std::max(0.0f, v2 - vrad*vrad));
          sFl[b] += std::min(std::max(q.temperature - 2.5f, 0.0f), 5.0f);
          if (q.temperature > 2.5f) nHot[b]++;
          szz[b] += (double)q.z * (double)q.z;
          srcyl[b] += std::sqrt((double)q.x*q.x + (double)q.y*q.y);
          nB[b]++;
        }
        const float kDt = 0.0165f;
        const double Mfield = (double)space::units::kMbhMsun; // field mass budget (M_sun)
        printf("  [BALANCE] L=r*vt spin | vcirc=sqrt(GMenc/r) grav | sup=vt/vcirc (<1 PLUNGES)\n");
        for (int b = 0; b < 6; b++) {
          if (nB[b] == 0) continue;
          double meanR = sr[b] / nB[b];
          double meanVt = svt[b] / nB[b];
          // M_enc inside meanR: fraction of the probe closer than meanR × field mass.
          int encN = 0;
          for (int i = 0; i < PROBE_N; i++) {
            const auto &q = probe[i];
            if (q.mass < 0.001f) continue;
            float rq = std::sqrt(q.x*q.x + q.y*q.y + q.z*q.z);
            if (rq < meanR) encN++;
          }
          double Menc = (double)encN / PROBE_N * Mfield;
          double vcirc = meanR > 1e-4
              ? std::sqrt(space::units::gmSim(Menc) / meanR) * kDt : 0.0;
          double L = meanR * meanVt;
          double sup = vcirc > 1e-9 ? meanVt / vcirc : 0.0;
          // clamp predictor: the c·dt integrator cap fires when gacc·dt/speedCap > 1.
          // >1 = this shell's gravity kick is TRUNCATED (integration fails here) →
          // localizes the 90% [ACC] clamp: is it the core only, or the disk too?
          double gacc = space::units::gmSim(Menc) / (meanR * meanR); // per wall-s^2
          double clampR = gacc * (double)kDt / (double)space::units::kCSimPerSec;
          // EXACT SPEEDS (2026-07-23 18:25, Jamal: "rotation way too slow vs
          // our global unit system — we need exact speeds"). Two periods per
          // shell, both in WALL seconds:
          //   Tmeas = 2π·r / v_measured   what the screen actually does
          //   Texact= 2π/√(GM_enc/r³)     what the unit law demands (gmSim is
          //                               per-wall-s², warp already baked in)
          // Tmeas/Texact = 1 → on-screen rotation is unit-exact; ≫1 names the
          // speed thief (drag? dilation? playback clock?).
          double vWall  = meanVt / (double)kDt;                       // sim/wall-s
          double Tmeas  = vWall > 1e-9 ? 2.0 * M_PI * meanR / vWall : 0.0;
          double omegaX = std::sqrt(space::units::gmSim(Menc) /
                                    std::max(meanR * meanR * meanR, 1e-12));
          double Texact = omegaX > 1e-9 ? 2.0 * M_PI / omegaX : 0.0;
          printf("    r=%.2f n=%4d Menc=%.2e L=%.4f vt=%.4f vcirc=%.4f sup=%.2f clamp=%.2f Tmeas=%.1fs Texact=%.1fs flash=%.2f hot=%d%%\n",
                 meanR, nB[b], Menc, L, meanVt, vcirc, sup, clampR, Tmeas, Texact,
                 sFl[b] / nB[b], (int)(100.0 * nHot[b] / nB[b]));
        }
        printf("  [DISKZ] H=sqrt(<z^2>) vertical scale height | H/R aspect (->0 = flat sheet)\n");
        for (int b = 0; b < 6; b++) {
          if (nB[b] == 0) continue;
          double H = std::sqrt(szz[b] / nB[b]);
          double Rc = srcyl[b] / nB[b];
          printf("    r=%.2f n=%4d H=%.4f Rcyl=%.3f H/R=%.4f\n",
                 sr[b] / nB[b], nB[b], H, Rc, (Rc > 1e-6 ? H / Rc : 0.0));
        }
      }
      // Integration-accuracy budget (same numbers as the HUD [accuracy] row):
      // how many gravity kicks hit the c·dt clamp this frame + the worst
      // offender. The AMR fine well shrinks orbital periods ~(1/0.03)^1.5 —
      // if this population explodes as the core assembles, the BOUNCE is
      // integration heating, and the fix is sub-stepping, not more force work.
      {
        PhysicsStats sAcc = renderer.getPhysicsStats();
        printf("  [ACC] clamped=%d (%.4f%%)  worst=%.2e c*dt\n",
               sAcc.accOverCount,
               100.0f * (float)sAcc.accOverCount / (float)std::max(app.uiParticleCount, 1),
               sAcc.maxAccRatio);
      }

      // 🔬 TEMP-DIAG (docs/BUG_lines_2026-07-12.md): SS_DUMP=/path.bin → one-
      // shot FULL-field position dump (float32 x,y,z per particle) on the 3rd
      // stats probe (~30 s in). Splits the fork: lines IN THE DATA = physics/
      // spawn; data clean = RENDER. Analyzed offline (histogram/FFT vs the
      // cellSize-1.0 grid).
      if (const char *dumpPath = getenv("SS_DUMP")) {
        static int dumpTick = 0;
        static int dumpAt = getenv("SS_DUMP_TICK") ? atoi(getenv("SS_DUMP_TICK")) : 3;
        if (++dumpTick == dumpAt) {
          int n = renderer.particleCount();
          std::vector<GPUParticle> all((size_t)n);
          renderer.readbackParticles(all.data(), n);
          if (FILE *f = fopen(dumpPath, "wb")) {
            // SS_DUMP_H=1 (2026-09-01, diagnostic only): append per-particle
            // crystallization hardness H (entanglement.y float bits, CPU name
            // pad1) as a 4th float — measures whether the US2 freeze ever
            // integrates during a sustain. Off = the original 3-float format.
            const bool dumpH = getenv("SS_DUMP_H") != nullptr;
            for (int i = 0; i < n; i++) {
              float xyz[3] = {all[i].x, all[i].y, all[i].z};
              fwrite(xyz, sizeof(float), 3, f);
              if (dumpH) {
                float h;
                memcpy(&h, &all[i].pad1, sizeof(float));
                // + Verlet per-frame displacement (pos − prev): names the
                // live transport term directly. 7 floats/particle total.
                float dxyz[4] = {h, all[i].x - all[i].prevX,
                                 all[i].y - all[i].prevY,
                                 all[i].z - all[i].prevZ};
                fwrite(dxyz, sizeof(float), 4, f);
              }
            }
            fclose(f);
            printf("  [DUMP] wrote %d particles (%s float32) -> %s\n", n,
                   dumpH ? "x,y,z,H" : "x,y,z", dumpPath);
          } else {
            printf("  [DUMP] FAILED to open %s\n", dumpPath);
          }
        }
      }

      fflush(stdout);
    }

  });

  window.run();

  takeRec.finish();   // S2: write the take (main thread, after the run loop)
  showCap.finish();   // S8: close the ProRes files (no-op if already finished / not armed)
  Logger::log("Application Session End");
  Logger::exportToDownloads();

  printf("\n");
  return 0;
}
