#pragma once
// ── THE OFFLINE CLOCK (S3 of the show renderer, 2026-09-03) ────────────────
// His order: render an Ableton take at exactly 30 (or 60) fps, one wide image.
// His ruling on drift (via BRAIN): LIVE dt stays 0.0165 (six hand-synced
// literals; particles.metal:362 "IDENTITY AT WARP 1 BY CONSTRUCTION" exists
// because of it). OFFLINE ONLY: dt = 1/60 exactly, 2 steps per output frame at
// 30 fps, 1 at 60 ⇒ sim time per output frame = 1/fps EXACTLY, zero drift
// against the Ableton timeline. His ruling on warp: "Warp won't be during
// rendering" — so it is PINNED to 1.0 and logged, not assumed.
//
// ONE source of truth. renderer.mm (physics step size + count, posed-disk
// clock, lens EMA, substeps), main.cpp (the second dt copy, warp) and
// window.mm (the frame-callback dt that drives sequencer / camera rides / VJ
// crossfade) all read THIS. Unset ⇒ `enabled == false` and every consumer
// takes its untouched live path — the live app is byte-for-byte what it was.
#include <cstdio>
#include <cstdlib>

namespace space {

struct OfflineClock {
  bool   enabled       = false;
  int    fps           = 0;
  double dt            = 0.0;   // physics step SIZE in sim seconds (1/60)
  int    stepsPerFrame = 0;     // physics steps per OUTPUT frame
  double frameDt       = 0.0;   // sim seconds per output frame == 1/fps == dt*steps

  // Read SS_RENDER_FPS once. Only 30 and 60 are exact with dt = 1/60; anything
  // else is refused LOUDLY and the clock stays live — never a silent "close".
  static const OfflineClock &get() {
    static OfflineClock oc = [] {
      OfflineClock c;
      const char *e = getenv("SS_RENDER_FPS");
      if (!e) return c;
      int f = atoi(e);
      if (f != 30 && f != 60) {
        fprintf(stderr, "[OFFLINE] SS_RENDER_FPS=%s refused: only 30 or 60 are exact with dt=1/60. "
                        "Clock stays LIVE.\n", e);
        return c;
      }
      c.enabled = true;
      c.fps = f;
      c.dt = 1.0 / 60.0;
      c.stepsPerFrame = 60 / f;          // 2 at 30 fps, 1 at 60 fps
      c.frameDt = c.dt * c.stepsPerFrame; // == 1/fps exactly
      printf("[OFFLINE] CLOCK ON: fps=%d dt=%.10f steps/frame=%d sim-seconds/frame=%.10f "
             "(live dt 0.0165 untouched; warp pinned to 1.0; window clock = 1/fps)\n",
             c.fps, c.dt, c.stepsPerFrame, c.frameDt);
      return c;
    }();
    return oc;
  }
};

} // namespace space
