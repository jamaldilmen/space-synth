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
  bool  uiTogSeedCapture  = true;  // bit2 — DEFAULT ON (2026-08-03, Jamal A/B'd bit2+bit3 live: "the other two levers gave it a better look though so thats nice"). Previously: DEFAULT OFF (2026-07-18 01:12:40, honest toggle stack made default; = SS_NO_CAPTURE; capture cheat kept out of the honest bed). Was ON (2026-07-07): victim-initiated star→seed capture. Was OFF since the dry-launch rebuild — THE reason feed=0 in every window (seedAccum is written ONLY by the bit2/bit3 paths); seeds grew solely via merge_stars' tidal branch, so the formed-hole plunge/disruption regime split never applied.
  bool  uiTogSeedMerge    = true;  // bit3 — DEFAULT ON (2026-08-03, same live A/B as bit2). seed↔seed merge: without it separately-grown seeds can never combine, so the field holds N unresolved lumps (measured 40 bodies over the 50 M_sun seed threshold at once) and can never organically settle into one hole — or into a few real ones.
  bool  uiTogOriginPin    = false; // bit4  seed origin-pin spring
  bool  uiTogRelaxation   = false; // bit5  core-collapse cooling — OFF (pure gravity collapses the horizon-scale cluster; cooling froze the infall)
  bool  uiTogResurrection = true;  // bit6 — DEFAULT ON (2026-08-03, Jamal: "when i sustain a note the particles from within the black hole respawn into the shape ... this way we also finally solve the fucking invisible abyss of light where all particles perpetually land in once eaten by a black hole"). This bit is now the SUSTAIN REBIRTH gate: while a note is held, SUSTAIN_REBIRTH of the dead pile per frame is reborn beside a living particle, i.e. inside the current Chladni figure, carrying REBIRTH_MASS (0.01 M_sun — light, not stars; the eaten mass stays conserved in the seed that ate it). Without this ON the eaten pile is permanent and the field thins with every hole. ⚠️ It also enables the pre-existing REST_RECYCLE trickle (dead matter drifting back to its star-map home at rest) — that path is unchanged but was never on by default before.
  bool  uiTogSeedRender   = false; // bit7  bright discrete seed render (rest)
  bool  uiTogLensShadow   = true;  // bit8 — DEFAULT ON (2026-07-19 17:58, Jamal: "always launch with lensing on"). The 07-18 OFF reasons (scratch smears, lens surviving the hole, wrong scale) were fixed 07-19: honest r_h key, lens-coherent streaks, photon transport un-double-booked. Resolve iteration continues WITH it on.
  // 🚨 DEFAULT FLIPPED TO OFF 2026-08-22 — HIS VERDICT: "turn the shadow off
  // btw its fake and annoying". This is the same complaint as BH10 ("still a
  // fake visual not physical overlay"). The optics behind it are real — the §2
  // parity proof stands — so what reads fake is the BLEND, not the physics.
  // Unchecking falls back to the r_h-sized particle silhouette, which is what
  // he will now see. The metric path is NOT deleted: tick the box to get it
  // back, and the A/B is still available in both directions.
  // ⭐ Safe to flip only since 2026-08-22: bit15 used to be shared with AMR
  // fine force, so this box moved physics too. AMR now owns bit21.
  bool  uiTogMetricShadow = false;  // bit15 — DEFAULT OFF 2026-08-22. WAS ON from 2026-07-24 (metric-native BH pivot, ratified by Jamal). The shadow is COMPUTED by integrating null geodesics of the honest metric (r_s = emergent r_h) instead of painted by the r_h-sized particle silhouette: dark pixels are rays measured to cross the horizon, so the shadow lands at the real photon-capture radius b_c = 2.598 r_s, ~2.6x the old blob. Uncheck for a live A/B against the silhouette. Integrator validated offline before shipping (b_c to 1.4e-6) — see the shader banner in render.metal.
  bool  uiTogSpectralColour = true; // bit16 — DEFAULT ON (2026-07-24, spectral starmap increment 2). Colour comes from the REAL Planck integral over the band set (spectral_lut.h, verified by [SPEC-LUT] against docs/spectral_bands_reference.txt) instead of the Tanner-Helland fit, and the supernovaRamp hue mix stands down. Lines return at increment 3 as lineStrength ADDED over the continuum. Uncheck for a live A/B against the old fit+ramp path.
  bool  uiTogAccretionGas = false;  // bit17 — DEFAULT OFF (2026-07-25 20:15, Jamal: the softening = the blur; OFF keeps near-hole matter SHARP so trails read, not fuzzy blobs). Was DEFAULT ON — restored 2026-07-24 after the A/B DISPROVED it: Jamal's verdict was "no its the tempo", so the softening is NOT the blur. The "accretion matter is gas" softening from 11:40 today: inside 4 r_h (ramp to 32) pointSize x3, luminance /9, Gaussian falloff exponent 5.0 -> 1.2. Prime suspect for "in the black hole it's still just fuzzy and blurr" vs the sharp lines play produces. ON = that softening; OFF = near-hole matter as sharp as the field.
  bool  uiTogAnalyticSpin = true; // bit20 — DEFAULT ON as the CLEAN TIME-LAPSE (2026-07-25 19:15, Jamal "build the clean time-lapse"). This is the orbit playback: sprites swept at the real Keplerian Ω(r)=√(GM/r³), now driven by a FIXED-rate clock (renderer.mm, no wall-clock jitter) and made COHERENT with the ray-march (which back-rotates its field sample by the same Ω·t), so emission and sprites move together. It's a time-lapse of the REAL orbits — fast + smooth + cheap, the honest answer after real substep physics proved too costly/unstable to hit Chladni-speed. OFF = raw physics motion (slow ~38s/orbit). Earlier this was labelled the "fake" spin; the fake part was only the jitter + the sprite/emission mismatch, both fixed now.
  bool  uiTogFluidStreak = true;  // bit18 — DEFAULT ON (2026-07-24, "no fluid streak. fix it"). The arc used to be drawn INSIDE a fixed sprite quad and windowed to zero before its edge, so a trail could never exceed ONE sprite however fast the matter moved (speed past elong=1 changed nothing) — and stretching MULTIPLIED flux, which was the blown-out white core. Now the quad grows with the arc and brightness falls as 1/length, so fast matter draws a long DIM ribbon at conserved total flux. OFF = the old clamped round-dot path.
  bool  uiTogAdaptiveSubstep = true; // TEST // bit9  GMAT-style adaptive sub-step of the central field (orbit instead of c·dt plunge) — OFF by default
  bool  uiTogPMGravity   = true;  // bit10 PM gravity: real Poisson solve ∇²Φ=4πGρ on the 128³ grid, force=−∇Φ (energy-conserving). Replaces the centroid/COM attractors that pumped the cold cluster to the speed cap (2026-06-30). When ON it overrides the bit0/bit9 legacy force.
  bool  uiTogSphPressure = true;  // bit11 — DEFAULT ON (Jamal verdict 2026-07-07: the reaction-engine config is the baseline) SPH pressure force (reaction engine slice 2b): a=−Σ m_j(P_i/ρ_i²+P_j/ρ_j²)∇W added to gravity. ≈0 at rest (cold u); matters when heated. Toggle in the mod menu.
  bool  uiTogSphVisc = true;      // bit12 — DEFAULT ON (2026-07-18 01:12:40, honest toggle stack; now Balsara/cold-gated so it no longer slabs the rest field = SS_SPH_VISC). Was DEFAULT OFF (2026-07-11): the Monaghan β·μ² term is velocity-driven (no heat needed), so it fired on the COLD ROTATING star-map at rest and, amplified by the 32-per-cell ρ under-count in the packed Plummer core, produced the vertical SLABS + colour-slicing + over-exposure (isolated to bit12 via SS_ONLY_SPH vs SS_ONLY_SPH_P, Jamal's eyes 2026-07-11). Pressure (bit11) alone = clean "gold". ⚠️ FOLLOW-UP: re-enable with a Balsara / cold-subsonic gate so shock heating returns for the reaction engine WITHOUT slabbing the rest field — see [[space-synth-handoff-2026-07-10]]. Was DEFAULT ON (2026-07-07). SPH viscosity + shock heating (slice 3): Monaghan Π_ij in the momentum eqn + energy eqn du/dt = PdV + ½Π·(v_ij·∇W) → KE becomes heat in uBuffer. Needs bit11 (same fused kernel).
  bool  uiTogNoLegacyPressure = true; // bit14 — DEFAULT ON (2026-07-07): legacy count-difference grid "pressure" retired; it was THE substrate noise pump (rest speed 0.136→0.008 measured). Real pressure = bit11/12 SPH. Delete the force outright in the slice-5 cleanup.
  bool  uiTogSphCool = true;      // bit13 — DEFAULT ON (2026-07-07) SPH radiative cooling (slice 4): Λ∝ρT⁴ optically-thin sink, u decays toward the cold floor with τ=τ₀/(ρ·(T/T_cap)³). The honest energy sink (replaces the u-cap discard). Needs bit12.
  int   uiPhysicsSubsteps = 1;    // N fixed-dt physics steps per frame (2026-07-25). Advances N× time per frame for the FAST sweep that makes real trails + volumetric Chladni fill — but each step is the stable dt=0.0165, so it does NOT detonate like dt×64 (which just scales the step past the stability limit → the field explodes into dots). Leave time-warp at ×1 and dial THIS for speed. Cost: ~N× physics compute (watch FPS). ⚠ rate-based effects (drain/recycle) currently run per-substep = N× per frame — watch for fast depletion; gate them if it bites.
  float uiIscoSeconds = 1.0f;     // DEFAULT 1.0s — HONEST: with the c3 fix (units.h::iscoPeriodWallSec) this now really is ONE ISCO orbit per screen-second. 0.023 was tried 22:14 to reproduce the pre-fix feel and REVERTED 22:33 (Jamal: "there's like a multiplikator there somewhere" — correct, 0.023 was a hidden 43.4334x buried in a default; a hidden factor is the exact thing the c3 fix removed). The dial is logarithmic 0.02..30 now, so pick the tempo on the slider, not in the default. 3.27s = true physical real-time at a 1.5e5 Msun hole. Was 1.0 (2026-07-25 20:15, Jamal — faster so the sweep streaks into trails, not dots; was 3.8). DECLARED time-lapse as PHYSICS: screen-seconds per ISCO orbit; compression DERIVED from the hole (T_isco = 92.3436*GM), never a bare multiplier. 3.8 s = Jamal's chosen 10x at the current hole. ⚠ 0.52 s was tried and REJECTED on sight 2026-07-24 18:10 ("looks even worse"): it was derived by matching CHLADNI_VCAP (1.2 sim/frame = ~72x c, which particles.metal itself flags as superluminal), so anchoring to it inherited its unphysicality — and it also saturated the streak law (elong = clamp(speed*1.4,0,1) pins at 1.0, lengthX maxes at 5x) so every particle drew the same maximal smear and the disk structure dissolved into haze. LOWER = faster. Render clock only.
  float uiSphCoolTau = 2.0f;      // τ₀ [simt] cooling e-fold at T_cap, ρ=1 (~1 simt ≈ 1 s wall at 60fps)
  // PHASE TINT — DEFAULT ON as of 2026-08-24 22:2x, his order ("the phase
  // thingy needs to be standard on"). It no longer REPLACES the physical
  // colour — it blends over it by uiPhaseVizAmount, hue only. See the note
  // at render.metal's phase-tint block.
  bool  uiPhaseViz = true;
  float uiPhaseVizAmount = 0.35f; // 0 = pure physical colour, 1 = full rainbow

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
  float uiNeonGrade = 0.0f;
  // Display grade LUT blend. DEFAULT 0 = exact bypass: the stage ships proving
  // it changes nothing until HE dials it. The look is his verdict, not mine.
  float uiGradeAmount = 0.0f;
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
  float uiSmearShutter = 24.0f; // motion-smear length (2026-08-20)
  float uiSmearHold = 1.0f;     // 1 = solid bands, 0 = fading blur
  float uiStreakLen = 1.0f;    // motion streak length x
  // KINETIC KELVIN PEDESTAL → 0 (2026-08-02 19:0x). Jamal: "only at release
  // does color actually come, its just white grey ish at play. so the scale is
  // off." Measured: kelvinU = 5772·M^0.55 + |v|²·K, so at K=27000 a 1507 K red
  // dwarf reads 3937 K at |v|=0.3, 8257 K at |v|=0.5, and EVERYTHING clamps to
  // 40000 K by |v|=1.19. Play velocities sit in that range, so the mass Teff
  // spread (which IS the OBAFGKM colour) is buried while a note sounds and only
  // returns as velocity decays at release. Exactly his symptom.
  // |v|² IS kinetic energy — a heat term wearing a velocity coat. render.metal
  // :1451 records the IDENTICAL bug being fixed once already ("HEAT TERM
  // REMOVED (2026-07-10) … +4500 K on a 3000 K dwarf → white. The mass Teff
  // spread … was buried under it after the first note"), and the Lupton 2004
  // rule stated three lines above this term in the same expression says
  // "Heat belongs in luminance, not in Kelvin." This term violated it.
  // Real Doppler is NOT this: it is linear in RADIAL velocity and signed, and
  // it already has its own path (DOPPLER_K_COLOR). Plumbing kept — the slider
  // is live, so dial it up to A/B the old look.
  float uiColorTempK = 0.0f;     // colour spectrum: |v|²→Kelvin gain (live tune)
  // PLAY HEAT PEDESTAL → 0 (2026-08-02 19:2x). Jamal: "white f".
  // render.metal:1317 (the PLAY colour path, separate from the star path):
  //     kelvin = clamp(diskK + clamp(temp,0,5)*tuneHeatK + ke*tuneColorK, …)
  // At play temperatures the clamp SATURATES at 5, so this added a FLAT
  // +15,000 K to every particle in the field. Measured effect on the Planck
  // band colour:
  //     0.087 M☉  1507 K → 16507 K   (1.000,0.132,0.011) → (0.650,0.892,1.000)
  //     1.00  M☉  5772 K → 20772 K   (1.000,0.922,0.668) → (0.602,0.857,1.000)
  //     5.00  M☉ 13988 K → 28988 K   (0.697,0.926,1.000) → (0.557,0.823,1.000)
  // Every mass lands on the same blue-white; summed additively that is WHITE,
  // and the OBAFGKM spread is gone. Colour only returned once the note decayed
  // and temp fell — his "only at release does color actually come".
  // THIS IS THE SAME BUG, AND THE SAME FIX, AS THE STAR PATH ON 2026-07-10:
  // render.metal:1451 "HEAT TERM REMOVED … clamp(temp,0,5)*tuneHeatK added a
  // flat pedestal … +4500 K on a 3000 K dwarf → white. The mass Teff spread,
  // which IS the OBAFGKM colour, was buried under it after the first note."
  // It was removed from the star path and left live in the play path. Lupton
  // 2004: heat belongs in LUMINANCE, not in Kelvin — and it still is, via
  // thT/luminance, which this does not touch.
  // Plumbing kept: the slider is live ("Plasma Heat"), so dial it up to A/B.
  float uiHeatGain = 0.0f;       // thermal heat→Kelvin gain (live tune; lower = less white)
  float uiCollapseFrac = 0.25f;// %% of field in core = hole formed
  // ── STAR LAW DIALS (2026-07-28) ─────────────────────────────────────────
  // Built because every star attribute was a hardcoded constant, so no star
  // experiment could be A/B'd live (Jamal 09:07: "thats a real loophole").
  // EVERY default here equals the constant it replaced, so at defaults the
  // picture is bit-identical to b047744.
  // The [KPROBE] histogram (2026-07-28 12:23) says uiStarLumExp is the one
  // that matters: at 3.5, ~1% of stars (all >10,000 K) emit 75% of the light,
  // so the visible field is selection-biased blue. LOWER it to lift the
  // orange 73% into view. Do NOT raise uiStarLumCeil to chase colour — that
  // was the 07-26 asinh failure.
  float uiStarLumExp = 3.5f;     // L = M^this
  float uiStarLumGain = 2.5f;    // starLum = L * this
  float uiStarLumCeil = 1000.0f; // starLum ceiling (hard clip)
  float uiStarKelvinA = 5772.0f; // K = this * M^p  (solar T_eff)
  float uiStarKelvinP = 0.55f;   // K = A * M^this
  // ── STAR SIZE (2026-07-28 15:21) ────────────────────────────────────────
  // [KPROBE-SCALE] measured meanPx 1.02 / maxPx 16.3 with 99.2% of stars
  // PINNED to the 1 px floor (Kroupa mode 0.087 M☉ → Rstar 0.142 → rawStar
  // ~0.14 px, so the floor swallows the whole bulk). A 1 px sprite cannot
  // carry hue, and it is why raising brightness only grows the spike cross
  // ("if jacked up all looks like only diamonds").
  // uiStarSizeGain is the blunt lever: it multiplies every star's size.
  float uiStarSizeGain = 1.0f;   // rawStar *= this (1.0 = shipped behaviour)
  float uiStarSizeExp = 0.8f;    // Rstar = M^this
  float uiStarSizeFloor = 1.0f;  // minimum sprite diameter in PIXELS
  float uiStarSizeCeil = 48.0f;  // tanh soft ceiling in PIXELS
};

} // namespace space
