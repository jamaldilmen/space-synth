#pragma once

namespace space {

// AppState — single source of truth for all tweakable UI control state.
// Extracted from the loose `static` locals that used to live in main()
// (refactor step 2). Field names keep the `ui` prefix so the migration was a
// pure rename; they can be cleaned up later. Defaults here ARE the app
// defaults. Sequencer/HUD state is intentionally NOT here yet (see step 7).
struct AppState {
  // ── Simulation ──
  float uiParticleSize = 2.0f;
  int   uiParticleCount = 2000000;
  float uiSharpness = 5.0f;    // particle Gaussian falloff (live render dial)
  float uiGrainAlpha = 0.08f;  // per-particle base alpha (live render dial)
  float uiShadowRadius = 1.0f; // x multiplier on the PHYSICAL lens radius // BH shadow radius (sim coords)
  float uiDiskThickness = 0.15f; // accretion-disk vertical thickness
  float uiJitter = 0.1f;       // not properly linked yet (kept, flagged in UI)
  float uiScale = 100.0f;      // shared: Space Scale + audio Drive
  float uiWaveDepth = 20.0f;
  float uiEField = 0.5f;
  float uiBField = 1.0f;
  float uiGravity = 0.8f;
  float uiStringStiffness = 50.0f;
  float uiRestLength = 0.05f;
  float uiRotationX = 0.0f;
  float uiRotationY = 0.0f;
  float uiRotationZ = 0.0f;
  bool  uiAutoRotateScene = false;

  // ── Global modulation LFO ──
  float uiLFORate = 0.5f;
  float uiLFODepth = 0.0f;
  float uiLFOPhase = 0.0f;

  // ── Camera / render mode ──
  bool  uiChorus = true;
  bool  uiOrthoMode = true;
  bool  uiCollisions = false;
  bool  uiBondNetwork = false; // nervous-system-of-light bond lines (hardened state)
  // ── BLACK-HOLE mechanism toggles (UI on/off, default all-on = current) ──
  bool  uiTogFieldGravity = true;  // bit0  field self-gravity (near+far grid)
  bool  uiTogCentralSMBH  = true;  // bit1  hard-coded central SMBH pull
  bool  uiTogSeedCapture  = true;  // bit2  star→seed capture (eating)
  bool  uiTogSeedMerge    = true;  // bit3  seed↔seed merge
  bool  uiTogOriginPin    = true;  // bit4  seed origin-pin spring
  bool  uiTogRelaxation   = true;  // bit5  accretion relaxation damping
  bool  uiTogResurrection = true;  // bit6  revive eaten particles on play
  bool  uiTogSeedRender   = true;  // bit7  bright discrete seed render (rest)
  bool  uiTogLensShadow   = true;  // bit8  screen-space lens/shadow
  bool  uiPhaseViz = false;

  // ── Envelope (ADSR) ──
  float uiAttack = 20.0f;   // ms
  float uiDecay = 100.0f;   // ms
  float uiSustain = 0.7f;
  float uiRelease = 400.0f; // ms

  // ── Post-FX ──
  float uiBloom = 0.45f; // dynamic HDR glow on (audio-reactive); tune in MASTER PATCH
  float uiTrailDecay = 0.05f; // "Fluidity" (screen persistence — NOT the trails)
  float uiChromatic = 0.0f;
  float uiGlitch = 0.0f;
  float uiScanlines = 0.0f;
  float uiNeonGrade = 0.0f;
  float uiVignette = 0.0f;
  float uiFxTime = 0.0f; // running seconds for animated FX

  // ── Resolume-style VJ FX ──
  int   uiMirrorMode = 0;
  int   uiKaleido = 0;
  int   uiTile = 1;
  float uiTwirl = 0.0f;
  float uiHueShift = 0.0f;
  float uiStrobe = 0.0f;
  float uiInvert = 0.0f;
  int   uiPosterize = 0;
  float uiBlur = 0.0f;

  // ── Black hole aesthetics ──
  float uiBlackHoleRotationX = 0.0f;
  bool  uiAutoRotateBlackHole = true;

  // ── VJ mode / audio input ──
  bool  uiVJMode = false;
  float uiInputGain = 2.0f;

  // ── Debugging (Phase 7) — backing state; most controls were culled ──
  bool  uiFixedTimestep = false;
  // E-field OFF: all charges are +1 (particles.cpp) so this was pure pair
  // REPULSION — an anti-collision. Real stellar collisions are inelastic
  // (merge, KE→heat→radiated: mass piles up → the hole). The dissipative
  // channel is the collisional relaxation in particles.metal; this force
  // injected outward KE at max compression = the core "trampoline" bounce.
  bool  uiSoloEField = false;
  bool  uiSoloBField = true;
  // Legacy pairwise gravity OFF: it double-counts the real self-gravity
  // (Barnes-Hut block, real units) inside the 0.02 contact radius, at an
  // arbitrary 0.8 constant in the ~120× a·dt convention. With real IMF
  // masses in posW.w (massProd up to 50×50) it would detonate close pairs.
  // Mergers (US2 eating) replace what contact "gravity" was faking.
  bool  uiSoloGravity = false;
  bool  uiSoloStrings = true;
  bool  uiSoloJitter = true;
  bool  uiSoloCollisions = true;
  bool  uiAutoMode = true;
  bool  uiQuantumEntangle = false;
  bool  uiBlackHoles = false;

  // ── BLACK HOLE TUNING dials (defaults = the tuned 2026-06-12 look) ──
  float uiLensBend = 0.85f;    // spacetime bend strength (0..1)
  float uiArcWrap = 2.2f;      // max trail arc sweep (rad)
  float uiArcGain = 5.0f;      // horizon exposure gain
  float uiTrailGain = 1.0f;    // trail brightness x
  float uiStreakLen = 1.0f;    // motion streak length x
  float uiColorTempK = 27000.0f; // colour spectrum: |v|²→Kelvin gain (live tune)
  float uiHeatGain = 3000.0f;    // thermal heat→Kelvin gain (live tune; lower = less white)
  float uiCollapseFrac = 0.25f;// %% of field in core = hole formed
};

} // namespace space
