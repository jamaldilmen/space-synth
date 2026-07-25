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
  bool  uiTogSeedCapture  = false; // bit2 — DEFAULT OFF (2026-07-18 01:12:40, honest toggle stack made default; = SS_NO_CAPTURE; capture cheat kept out of the honest bed). Was ON (2026-07-07): victim-initiated star→seed capture. Was OFF since the dry-launch rebuild — THE reason feed=0 in every window (seedAccum is written ONLY by the bit2/bit3 paths); seeds grew solely via merge_stars' tidal branch, so the formed-hole plunge/disruption regime split never applied.
  bool  uiTogSeedMerge    = false; // bit3  seed↔seed merge
  bool  uiTogOriginPin    = false; // bit4  seed origin-pin spring
  bool  uiTogRelaxation   = false; // bit5  core-collapse cooling — OFF (pure gravity collapses the horizon-scale cluster; cooling froze the infall)
  bool  uiTogResurrection = false; // bit6  revive eaten particles on play
  bool  uiTogSeedRender   = false; // bit7  bright discrete seed render (rest)
  bool  uiTogLensShadow   = true;  // bit8 — DEFAULT ON (2026-07-19 17:58, Jamal: "always launch with lensing on"). The 07-18 OFF reasons (scratch smears, lens surviving the hole, wrong scale) were fixed 07-19: honest r_h key, lens-coherent streaks, photon transport un-double-booked. Resolve iteration continues WITH it on.
  bool  uiTogMetricShadow = true;  // bit15 — DEFAULT ON (2026-07-24, metric-native BH pivot, ratified by Jamal). The shadow is COMPUTED by integrating null geodesics of the honest metric (r_s = emergent r_h) instead of painted by the r_h-sized particle silhouette: dark pixels are rays measured to cross the horizon, so the shadow lands at the real photon-capture radius b_c = 2.598 r_s, ~2.6x the old blob. Uncheck for a live A/B against the silhouette. Integrator validated offline before shipping (b_c to 1.4e-6) — see the shader banner in render.metal.
  bool  uiTogSpectralColour = true; // bit16 — DEFAULT ON (2026-07-24, spectral starmap increment 2). Colour comes from the REAL Planck integral over the band set (spectral_lut.h, verified by [SPEC-LUT] against docs/spectral_bands_reference.txt) instead of the Tanner-Helland fit, and the supernovaRamp hue mix stands down. Lines return at increment 3 as lineStrength ADDED over the continuum. Uncheck for a live A/B against the old fit+ramp path.
  bool  uiTogAccretionGas = false;  // bit17 — DEFAULT OFF (2026-07-25 20:15, Jamal: the softening = the blur; OFF keeps near-hole matter SHARP so trails read, not fuzzy blobs). Was DEFAULT ON — restored 2026-07-24 after the A/B DISPROVED it: Jamal's verdict was "no its the tempo", so the softening is NOT the blur. The "accretion matter is gas" softening from 11:40 today: inside 4 r_h (ramp to 32) pointSize x3, luminance /9, Gaussian falloff exponent 5.0 -> 1.2. Prime suspect for "in the black hole it's still just fuzzy and blurr" vs the sharp lines play produces. ON = that softening; OFF = near-hole matter as sharp as the field.
  bool  uiTogAnalyticSpin = true; // bit20 — DEFAULT ON as the CLEAN TIME-LAPSE (2026-07-25 19:15, Jamal "build the clean time-lapse"). This is the orbit playback: sprites swept at the real Keplerian Ω(r)=√(GM/r³), now driven by a FIXED-rate clock (renderer.mm, no wall-clock jitter) and made COHERENT with the ray-march (which back-rotates its field sample by the same Ω·t), so emission and sprites move together. It's a time-lapse of the REAL orbits — fast + smooth + cheap, the honest answer after real substep physics proved too costly/unstable to hit Chladni-speed. OFF = raw physics motion (slow ~38s/orbit). Earlier this was labelled the "fake" spin; the fake part was only the jitter + the sprite/emission mismatch, both fixed now.
  bool  uiTogRayMarch = true;  // bit19 — DEFAULT ON (2026-07-25, "calculate the hole, don't put a lens there"). The metric-native ray-march: integrate null geodesics of the honest metric (r_s = emergent r_h) BACKWARD and ADD the emission of the REAL particle field (CIC hash grid) gathered along each ray. Rays winding over the hole pick up the disk's far side (the arch = inner/outer ring); captured rays stop gathering (shadow = absence). Additive — no black paint, so the withdrawn overlay disc cannot recur. This is what a flat lensed sprite could never do (one sprite ≠ 3 images). OFF = no metric emission (the sprite-lens/absence path only). emitScale hardcoded 1e-3 for now — the single brightness dial.
  bool  uiTogFluidStreak = true;  // bit18 — DEFAULT ON (2026-07-24, "no fluid streak. fix it"). The arc used to be drawn INSIDE a fixed sprite quad and windowed to zero before its edge, so a trail could never exceed ONE sprite however fast the matter moved (speed past elong=1 changed nothing) — and stretching MULTIPLIED flux, which was the blown-out white core. Now the quad grows with the arc and brightness falls as 1/length, so fast matter draws a long DIM ribbon at conserved total flux. OFF = the old clamped round-dot path.
  bool  uiTogAdaptiveSubstep = true; // TEST // bit9  GMAT-style adaptive sub-step of the central field (orbit instead of c·dt plunge) — OFF by default
  bool  uiTogPMGravity   = true;  // bit10 PM gravity: real Poisson solve ∇²Φ=4πGρ on the 128³ grid, force=−∇Φ (energy-conserving). Replaces the centroid/COM attractors that pumped the cold cluster to the speed cap (2026-06-30). When ON it overrides the bit0/bit9 legacy force.
  bool  uiTogSphPressure = true;  // bit11 — DEFAULT ON (Jamal verdict 2026-07-07: the reaction-engine config is the baseline) SPH pressure force (reaction engine slice 2b): a=−Σ m_j(P_i/ρ_i²+P_j/ρ_j²)∇W added to gravity. ≈0 at rest (cold u); matters when heated. Toggle in the mod menu.
  bool  uiTogSphVisc = true;      // bit12 — DEFAULT ON (2026-07-18 01:12:40, honest toggle stack; now Balsara/cold-gated so it no longer slabs the rest field = SS_SPH_VISC). Was DEFAULT OFF (2026-07-11): the Monaghan β·μ² term is velocity-driven (no heat needed), so it fired on the COLD ROTATING star-map at rest and, amplified by the 32-per-cell ρ under-count in the packed Plummer core, produced the vertical SLABS + colour-slicing + over-exposure (isolated to bit12 via SS_ONLY_SPH vs SS_ONLY_SPH_P, Jamal's eyes 2026-07-11). Pressure (bit11) alone = clean "gold". ⚠️ FOLLOW-UP: re-enable with a Balsara / cold-subsonic gate so shock heating returns for the reaction engine WITHOUT slabbing the rest field — see [[space-synth-handoff-2026-07-10]]. Was DEFAULT ON (2026-07-07). SPH viscosity + shock heating (slice 3): Monaghan Π_ij in the momentum eqn + energy eqn du/dt = PdV + ½Π·(v_ij·∇W) → KE becomes heat in uBuffer. Needs bit11 (same fused kernel).
  bool  uiTogNoLegacyPressure = true; // bit14 — DEFAULT ON (2026-07-07): legacy count-difference grid "pressure" retired; it was THE substrate noise pump (rest speed 0.136→0.008 measured). Real pressure = bit11/12 SPH. Delete the force outright in the slice-5 cleanup.
  bool  uiTogSphCool = true;      // bit13 — DEFAULT ON (2026-07-07) SPH radiative cooling (slice 4): Λ∝ρT⁴ optically-thin sink, u decays toward the cold floor with τ=τ₀/(ρ·(T/T_cap)³). The honest energy sink (replaces the u-cap discard). Needs bit12.
  float uiRayBcull = 16.0f;       // metric ray-march (bit19) EXTENT: impact-parameter cull in r_s. 2.6 (the shadow-only value) discarded every ray that would show the disk (disk lives at 3..22 r_s) → the filled orange core. Widen to render the disk + its lensed rings. Higher = more disk but more pixels marched (FPS).
  float uiRayInnerR = 2.6f;       // metric ray-march (bit19) SHADOW: inner no-emit radius in r_s. Matter inside this doesn't emit → the dark centre. ~2.6 = photon-capture shadow; raise toward ISCO (3) for a bigger dark hole.
  float uiRayEmitLog = -7.5f;     // log10 of the metric ray-march emission gain (bit19). Default −7.5 (2026-07-25 16:33: Jamal "always have to lower to −7.5ish for the orange cube to disappear"). −6 filled the bCull march box with a bright warm haze (the "orange cube/box" = the emission bounding region); −7.5 is where the fill fades and only the disk/lens structure remains. emitScale = 10^this. 1e-3 saturated the whole capture disc to a solid orange "yolk" 2026-07-25 14:20 (every ray hit the clamp) — sweep DOWN until the saturation breaks and the disk/lensing structure emerges. LOWER = dimmer.
  int   uiPhysicsSubsteps = 1;    // N fixed-dt physics steps per frame (2026-07-25). Advances N× time per frame for the FAST sweep that makes real trails + volumetric Chladni fill — but each step is the stable dt=0.0165, so it does NOT detonate like dt×64 (which just scales the step past the stability limit → the field explodes into dots). Leave time-warp at ×1 and dial THIS for speed. Cost: ~N× physics compute (watch FPS). ⚠ rate-based effects (drain/recycle) currently run per-substep = N× per frame — watch for fast depletion; gate them if it bites.
  float uiIscoSeconds = 1.0f;     // DEFAULT 1.0s (2026-07-25 20:15, Jamal — faster so the sweep streaks into trails, not dots; was 3.8). DECLARED time-lapse as PHYSICS: screen-seconds per ISCO orbit; compression DERIVED from the hole (T_isco = 92.3436*GM), never a bare multiplier. 3.8 s = Jamal's chosen 10x at the current hole. ⚠ 0.52 s was tried and REJECTED on sight 2026-07-24 18:10 ("looks even worse"): it was derived by matching CHLADNI_VCAP (1.2 sim/frame = ~72x c, which particles.metal itself flags as superluminal), so anchoring to it inherited its unphysicality — and it also saturated the streak law (elong = clamp(speed*1.4,0,1) pins at 1.0, lengthX maxes at 5x) so every particle drew the same maximal smear and the disk structure dissolved into haze. LOWER = faster. Render clock only.
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
