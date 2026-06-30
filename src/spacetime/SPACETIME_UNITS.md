# SPACETIME — the unified space-AND-time unit engine (SPEC)
_Created 2026-06-29 03:15:00 · branch STARS · the "system that is an engine by itself."_

## Why this exists
SPACE SYNTH is a **real-time synthesizer of SPACE AND TIME**, grounded in the real measured
universe — lengths, masses, **speeds, orbital periods, collision energies, and especially
TIME**. Today space is anchored (units.h: 1 sim = 2 r_g of the field, r_s(field)=1.0 sim) but
**time is a fudge**: `kTimeLapse = 20.58` ("1 screen-second = 20.58 sim-seconds") is an
arbitrary constant with no physical derivation. That single un-grounded number is why:
- collapse "takes forever," supernova timing is arbitrary, BH spin is a decorative constant;
- gravity feels fake, collision/explosion don't read as real — **they're all unscaled time.**

This folder is the clean home for the honest, derived space-time unit system that replaces
units.h's time hack. It is a SYSTEM: every dynamical quantity (G, v, Ω, periods, supernova
phases, collapse time) derives from the same measured constants and the same time mapping.

## Core principles (NO SHORTCUTS — ground the science in science)
1. **One self-consistent unit set.** Length, mass, time all from measured SI constants
   (G, c, M☉, the field mass). Every derived quantity (gmSim, v_circ, Ω_horizon, t_ff,
   supernova rise/fade, ISCO period) computed from them — never a tuned-by-feel value.
2. **Honest real→screen time mapping.** Real processes span ~15 orders of magnitude (ms
   core-collapse → Myr cluster evolution → kyr remnant). One **global time-lapse factor**
   `T_lapse` (real seconds per screen second) maps real→screen so that ALL relative timing
   stays physically correct (the supernova : collapse : spin ratios are real). Pick `T_lapse`
   so the PRIMARY process is watchable; everything else follows at the same factor.
   → value(s) TBD from the time-research agent (a3d5fad8).
3. **Energy injection bends time (the play mechanism).** Playing a note injects energy/force
   into a region; in GR mass-energy density curves spacetime and changes the local dynamical
   rate. So the played region's process (supernova) evolves FASTER as a real consequence of
   the injected energy density — this is WHY play-supernova forms faster than the spontaneous
   one. Model the local time-rate as a function of injected energy density (physics basis TBD
   from research). This is the synth's defining feature: you play spacetime.
4. **Stable at ≤6× warp; remove higher.** A fixed-step integrator + c-cap breaks at high
   time-warp (dt×accel overshoot → ejection). The math must be CORRECT up to ~6× real-time;
   warp options above the principled max are removed (or require adaptive sub-stepping). The
   adaptive sub-step is what lets the real timescales be compressed without breaking.

## Anchor constants (everything derives from these)
- c = 299,792.458 km/s · r_g = GM/c² = **1.477 km/M☉** · r_s = 2GM/c² = **2.953 km/M☉**
- **Natural BH tick: t_g = GM/c³ = 4.925 μs/M☉** (light-crossing of one r_g; the system's true clock).
  c³/GM = 2.030e5 s⁻¹/M☉ converts geometric Ω → rad/s.
- **THE HONEST TIME ANCHOR (replaces kTimeLapse=20.58):** sim length unit = kUnitMeters =
  2·r_g(field) = 1.7552e9 m. Define **1 sim time unit = (1 sim length)/c = kUnitMeters/c ≈ 5.85 s**.
  Then c = 1 in sim units BY CONSTRUCTION and G is derived — no arbitrary constant. The
  field's gravitational tick t_g(594k M☉) ≈ 2.93 s; horizon light-crossing ≈ 5.85 s.

## Real timescales (grounded — agent a3d5fad8, sourced)
| process | real duration | source/formula |
|---|---|---|
| iron-core implosion → bounce | infall 0.1–0.45 s, bounce ~few **ms**; infall v 0.1–0.25c | t_ff=√(3π/32Gρ), ρ→10¹⁴ |
| neutrino burst | **~10 s** (SN1987A ~13 s) | 99% of ~3e46 J |
| shock breakout | **~30 s → ~1 day** (compact→RSG) | UV/X flash |
| SN rise to optical peak | **~7–20 days** | ⁵⁶Ni→Co, τ½=6.08 d |
| SN plateau/decline (born→vanish) | plateau **~80–120 d**, tail months (⁵⁶Co τ½=77.2 d); transient ~months–2 yr | |
| SN remnant visible expansion | **~10²–10⁶ yr** (Crab: 972 yr, r~1.7 pc, ~1500 km/s, grows yearly) | Sedov-Taylor |
| direct stellar-core → BH | horizon ~**ms**; envelope free-fall **~1–3 s** | |
| cluster → BH (gravothermal) | **~Myr** (t_cc≈0.2 t_rh w/ mass spectrum; single-mass 15–18 t_rh) | t_rh∝N^½r_h^{3/2} |
| BH horizon spin Ω_H (a*=0.9) | **10 M☉ → ~1 ms/rotation (~kHz, AUDIO RATE!)**; Sgr A* ~6.6 min; M87* ~7.4 d | Ω_H=[a*/(2(1+√(1−a*²)))]·c³/GM, **∝1/M** |
| ISCO orbital period | 10 M☉ **~4.5 ms**; Sgr A* **~30 min**; M87* ~33 d | T=92.3 t_g (Schw.); v=0.5c at 6 r_g |
| stellar collision | v ~ v_esc(Sun)=**618 km/s**; KE ~**1.8e41 J** ≈ stellar binding energy → merges | ½μv² |

**Measured BH spins a\*:** Cyg X-1 >0.9985, GRS 1915 ~0.98, M87* ~0.9, Sgr A* ~0.65–0.95
(treat as ranges in any HUD label). Max stable a*=0.998.

## What this engine answers (the user's framing)
- **Why gravity is fake** → mean-field softened (collisionless); + un-scaled time makes it creep.
- **Why collapse/collision isn't right** → no real relaxation/dynamical-friction + wrong time scale + collision scale ≪ gravity scale (see docs/bh_root_cause_analysis_2026-06-29.md).
- **Why explosion doesn't really exist** → supernova phases not grounded in real durations; play "bends time" but the spontaneous one has no real clock.
- The fix per root-cause MD: Rank-1 Chandrasekhar dynamical friction, radius-driven merging,
  geometric pop, remove the external SMBH — ALL on this honest space-time base.

## Explicitly NOT this
- ❌ No LUT / posed / rendered fixed BH shape (Jamal: the starmap must FORM a BH, not collapse
  into a baked shape). The BH emerges from the particles' real physics on this unit base.
- ❌ No tuned-by-feel constants. If a number isn't derived from measurement, it's wrong.

## Status / next
1. ✅ DONE — Time-research agent (a3d5fad8) returned the real timescales (table above).
2. ✅ DONE (2026-06-29 16:51) — `spacetime.h` implemented: derived SI-anchored unit core,
   c ≡ 1 + G derived, self-verifying static_asserts (gmSim(field)=0.5, r_s(field)=1.0,
   1 sim-time=5.854 s, t_g=2.927 s). `kUnitMeters` now DERIVED (2·G·M_field/c²), not the
   rounded 1.7552e9 literal. NOT YET HERE: `T_lapse` policy + energy→time-rate fn (see #3/#4).
3. ✅ DONE (2026-06-29 18:13, behavior-neutral, verified by Jamal "yeah it does") —
   `units.h` re-based onto spacetime.h. Magic `kTimeLapse=20.58` REMOVED → now derived
   (`kTLapse × kSimSeconds`). Warp is now ONE explicit labeled knob `kTLapse=3.515`
   (sim-time/wall-sec, = old behavior). All constants match old build ≤0.01% (the rounding
   fix). dt convention (wall-seconds) unchanged this step.
4. ✅ DONE (2026-06-30 16:30) — Accuracy MEASUREMENT slice. Added a per-frame accuracy meter
   (worst gravity kick / light-step = k0/gkmax, atomic-max → HUD `[accuracy]`). Live toggles
   are 0x201 (field self-gravity + bit9 adaptive substep; external SMBH OFF). FINDING: at rest
   the ratio is ~1e-5, ~6 orders BELOW the 32-substep budget (ratio 8) even at 64× warp →
   the accuracy ceiling is NOT the blocker; weak/diffuse gravity is. Governor deferred.
5. ✅ DONE (2026-06-30 16:51, verified by Jamal) — RANK-1 Chandrasekhar dynamical friction
   (the collapse keystone). A.1: velocity dispersion σ computed in compute_cell_centroids,
   stored in cellVelocities.w (teleport spikes excluded, σ≤c, behavior-neutral). A.2: drag
   a_df=−4πG1²ρ·lnΛ·m·G(X)·v̂/v² added to shiftV, with f_relax=4e11 time-compression (derived:
   t_cc≈78 Myr → ~1000 sim-time units). RESULT: real gravothermal collapse — ratio climbed
   1000× (1e-5→2e-2), mass conserved (1.890e5 constant), no explosion. Jamal: "sense of gravity."
6. DEEP DIAGNOSIS (2026-06-30 17:30, many measured runs — TWO of my hypotheses were
   REFUTED by data, kept here so they aren't re-tried):
   - A.2 "collapse" was WRONG: meanR actually EXPANDS 47→78 (friction OFF) / 47→68 (ON).
     Friction is correct (it slows expansion) but can't bind the cluster.
   - "slingshot/saturated-kick heating" REFUTED: KE spikes 6→1589 while accRatio stays
     <0.02 (never near the budget of 8) → gravity never stresses the integrator. The KE
     swings are mostly teleport/respawn velocity contamination, not real heating.
   - ROOT CAUSE (consistent across every run): the spawn is a SHELL at r_inner=25..r_outer=60
     sim (particles.cpp:12-13), meanR~47, but r_s(field)=1.0 sim → cluster is 25-60× too
     DIFFUSE. Gravity there is ~1e-6 of a light-step → far too weak to bind/collapse → it
     disperses regardless of friction. encFrac=0 always (nothing reaches center). bhMassEnc=0,
     r_h=0, BH 0% — the pop has no concentrated mass to fire on.
   - THE DILEMMA (particles.cpp:12 documents it): spawn dense (r~2, near horizon) → strong
     gravity BUT fixed-step kick explodes ("cap-ejection big bang"); spawn diffuse (r=47) →
     no explosion BUT gravity too weak. The ONLY escape = robust adaptive sub-stepping of the
     strong close-range force (Step 2) → enables a dense, strongly self-bound cluster that
     collapses WITHOUT exploding. So Step 2 is the keystone, not just a warp governor.
   NEXT: Step 2 — make adaptive sub-stepping robustly handle strong forces (2a), so the spawn
   can be dense/strongly-gravitating; THEN friction drives a real collapse; THEN the pop fires.
