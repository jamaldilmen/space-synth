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
  bool  uiCollisions = true;   // engine-permanent, Jamal 2026-07-07 (god-forms verdict)
  bool  uiBondNetwork = true;  // engine-permanent, Jamal 2026-07-07
  // ── BLACK-HOLE mechanism toggles — DEFAULT ALL OFF (launch DRY: bare field,
  //    no BH machinery; we rebuild the lifecycle on this honest base) ──
  bool  uiTogFieldGravity = true;  // bit0  field self-gravity (near+far grid) — the real base, ON

  bool  uiTogCentralSMBH  = false; // bit1  hard-coded central SMBH pull
  bool  uiTogSeedCapture  = true;  // bit2 — DEFAULT ON (2026-07-07): victim-initiated star→seed capture. Was OFF since the dry-launch rebuild — THE reason feed=0 in every window (seedAccum is written ONLY by the bit2/bit3 paths); seeds grew solely via merge_stars' tidal branch, so the formed-hole plunge/disruption regime split never applied.
  bool  uiTogSeedMerge    = false; // bit3  seed↔seed merge
  bool  uiTogOriginPin    = false; // bit4  seed origin-pin spring
  bool  uiTogRelaxation   = false; // bit5  core-collapse cooling — OFF (pure gravity collapses the horizon-scale cluster; cooling froze the infall)
  bool  uiTogResurrection = false; // bit6  revive eaten particles on play
  bool  uiTogSeedRender   = false; // bit7  bright discrete seed render (rest)
  bool  uiTogLensShadow   = false; // bit8  screen-space lens/shadow
  bool  uiTogAdaptiveSubstep = true; // TEST // bit9  GMAT-style adaptive sub-step of the central field (orbit instead of c·dt plunge) — OFF by default
  bool  uiTogPMGravity   = true;  // bit10 PM gravity: real Poisson solve ∇²Φ=4πGρ on the 128³ grid, force=−∇Φ (energy-conserving). Replaces the centroid/COM attractors that pumped the cold cluster to the speed cap (2026-06-30). When ON it overrides the bit0/bit9 legacy force.
  bool  uiTogSphPressure = true;  // bit11 — DEFAULT ON (Jamal verdict 2026-07-07: the reaction-engine config is the baseline) SPH pressure force (reaction engine slice 2b): a=−Σ m_j(P_i/ρ_i²+P_j/ρ_j²)∇W added to gravity. ≈0 at rest (cold u); matters when heated. Toggle in the mod menu.
  bool  uiTogSphVisc = false;     // bit12 — DEFAULT OFF (2026-07-11): the Monaghan β·μ² term is velocity-driven (no heat needed), so it fired on the COLD ROTATING star-map at rest and, amplified by the 32-per-cell ρ under-count in the packed Plummer core, produced the vertical SLABS + colour-slicing + over-exposure (isolated to bit12 via SS_ONLY_SPH vs SS_ONLY_SPH_P, Jamal's eyes 2026-07-11). Pressure (bit11) alone = clean "gold". ⚠️ FOLLOW-UP: re-enable with a Balsara / cold-subsonic gate so shock heating returns for the reaction engine WITHOUT slabbing the rest field — see [[space-synth-handoff-2026-07-10]]. Was DEFAULT ON (2026-07-07). SPH viscosity + shock heating (slice 3): Monaghan Π_ij in the momentum eqn + energy eqn du/dt = PdV + ½Π·(v_ij·∇W) → KE becomes heat in uBuffer. Needs bit11 (same fused kernel).
  bool  uiTogNoLegacyPressure = true; // bit14 — DEFAULT ON (2026-07-07): legacy count-difference grid "pressure" retired; it was THE substrate noise pump (rest speed 0.136→0.008 measured). Real pressure = bit11/12 SPH. Delete the force outright in the slice-5 cleanup.
  bool  uiTogSphCool = true;      // bit13 — DEFAULT ON (2026-07-07) SPH radiative cooling (slice 4): Λ∝ρT⁴ optically-thin sink, u decays toward the cold floor with τ=τ₀/(ρ·(T/T_cap)³). The honest energy sink (replaces the u-cap discard). Needs bit12.
  float uiSphCoolTau = 2.0f;      // τ₀ [simt] cooling e-fold at T_cap, ρ=1 (~1 simt ≈ 1 s wall at 60fps)
  bool  uiPhaseViz = false;

  // ── Envelope (ADSR) ──
  float uiAttack = 20.0f;   // ms
  float uiDecay = 100.0f;   // ms
  float uiSustain = 0.7f;
  float uiRelease = 400.0f; // ms

  // ── Post-FX ──
  float uiBloom = 0.45f; // dynamic HDR glow on (audio-reactive); tune in MASTER PATCH
  float uiExposure = 1.0f; // global camera iris: scales HDR scene pre-tonemap
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
