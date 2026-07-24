# DESIGN — THE METRIC-NATIVE BLACK HOLE (major architectural pivot)
**Written:** 2026-07-24 12:20:00. Status: ARCHITECTURE PROPOSAL — nothing built.
**Jamal's order (12:1x):** "calculate the entire black hole and not put a lens
there... it's not a calculated spacetime-changing monster. like our timelapse:
it goes on even if the simulation is on pause, because it's the maths. with the
black hole it should be the same... how are you even gonna calculate what the
inner and outer ring is if it's just a 2D circle spinning with zero depth with
a lens popped onto that." → This doc + two research reports, then a FRESH window.

## 0. The decision
Retire the particle-forward lens (each particle draws one sprite at its own bent
position). Replace the hole's RENDER with a **metric-native backward geodesic
ray-march** that samples the REAL particle emission field. The metric g(M) becomes
the one computed object the whole hole is derived from — exactly the way the
timelapse warp is one computed transform. Everything up to the disk (collapse,
emergent horizon, drain fix, gas/star states, the physics) is KEPT.

## 1. Why the current architecture cannot produce correct inner/outer rings
GROUNDED in the code (render.metal particle_vertex lens block; spacetime.h):
1. **One sprite can't be three images.** The NASA/Gargantua structure — photon
   ring + primary image (far side arched over the top) + secondary image
   (underside below) — is the SAME light arriving by different geodesic paths.
   A point sprite draws once, at one bent position. So the arch is FAKED by
   displacement and can never be in correct proportion — the proportion is set
   by the multiple paths we never compute.
2. **The disk is physically flat (z≈0), zero depth.** No real far side to lens
   over, no underside. The "2D feel" is literal. And it is the SAME ROOT as the
   wrong tempo: the disk is a flat ring spun as a RIGID render decal on the
   wall-clock, not real matter on real 3D orbits at the lawful speed. One root,
   three symptoms (2D look, wrong/uneven tempo, fake ring proportions).

## 2. The principle Jamal named: the metric is the one computed object
We ALREADY have the metric, exactly (spacetime.h, first-principles, no tuning):
- 1 sim length = 2·r_g(field); c ≡ 1; r_s(M) = 2·gmSim(M)/c² = 2·gmSim(M).
- gmSim(M) = r_g per M_sun, exact. r_s(field) = 1.0 by construction.
- The honest EMERGENT horizon gives live M(<r) and r_h (the [HORIZON] probe).
So g(M) is as pure-math as the timelapse T(t). The hole should be VIEWED THROUGH
g(M), not have a lens bolted onto a flat ring. It exists whether the sim is
paused or not, because it is math, not a sim step (Jamal's exact point).

## 3. Target architecture — backward geodesic ray-march (DNGR / Interstellar method)
For each camera ray (per pixel, or per screen tile): integrate the null geodesic
BACKWARD through g(M). Wherever the ray crosses the disk volume, accumulate the
REAL particle emission sampled there (density/temperature/velocity from the
deposited field). Outcomes fall out of the geodesics — nothing placed by hand:
- rays captured by the horizon → the SHADOW (correct ~2.6 r_s size, geometric);
- rays winding the photon sphere → the PHOTON RING (n=1,2 subrings);
- rays passing over → PRIMARY image of the far side (the top arch);
- rays passing under → SECONDARY image (the underside);
- gravitational redshift + Doppler beaming from the SAME integration, for free.
Inner/outer ring proportions are CORRECT because they are the actual light paths.

## 4. The one hard requirement that also fixes 2D + tempo
The disk must be a REAL 3D EMITTER: particles occupying a true annulus with
thickness and inclination, each on its real Keplerian orbit at the lawful speed
√(GM/r) (the value the [BALANCE] Texact column already prints). This single fix:
(a) gives the ray-march something 3D to bend → real over/under images;
(b) gives depth → kills the 2D feel;
(c) gives the lawful, differential tempo → kills the sluggish rigid-spin.
[Front B of the overhaul (B2 drag-exemption 2026-07-23) already began parking a
real orbiting disk instead of draining — build on that, not the render decal.]

## 5. What we KEEP vs REPLACE
KEEP (untouched): the whole physics pipeline — Chladni play, supernova, emergent
collapse, honest horizon, B2 drain-exemption, gas/star per-particle states, the
CIC density deposit to the spatial hash, the unit system, the timelapse warp.
REPLACE: only the RENDER of the hole region — the particle-forward lens block +
the flat-ring rigid spin → the metric ray-march + real 3D orbiting emitter.

## 6. The BH CORE DIRECTIVE tension — stated and resolved
Directive: "the BH IS the particles, never a shader." A raytracer was DELETED
2026-06-28 for this. BUT that one sampled a FAKE analytic disk (useless). This
one samples the ACTUAL deposited particle field — it IS the particles, viewed
through the real metric instead of each flattened to a sprite. Opposite of the
deleted one; honors the directive's intent (no invented second layer, the light
is the particles' own emission). Needs Jamal's explicit ratification.

## 7. Open questions the two research reports resolve (docs written 2026-07-24)
→ `docs/RESEARCH_2026-07-24_interstellar_dngr.md` (Interstellar/DNGR method)
→ `docs/RESEARCH_2026-07-24_blackhole_sota.md` (state-of-the-art BH↔spacetime + real-time impl)
Questions:
- Schwarzschild (we have spin a — Kerr?) — which metric, and the geodesic form to
  integrate (Hamiltonian? 2nd-order? conserved E,L reduction to a 1D radial ODE?).
- Real-time budget: analytic deflection LUT (we built one) vs full numerical
  geodesic march, at 2M particles / Metal GPU / target fps. Adaptive stepping.
- How to sample the live particle field as a volumetric emitter (reuse the CIC
  hash grid? a dedicated disk density/emission texture updated each frame?).
- Disk emission model: Shakura–Sunyaev T(r) (we have it) + Doppler + redshift g-factor.
- Screen strategy: full-screen ray-march pass only in the hole's screen bbox;
  compositing with the untouched starfield/particle passes.

## 8. Risk (honest)
Biggest single change in the project. FPS is the main risk (marching a volume
sampled from 2M particles). Mitigations to spec: bbox-limited pass, coarse march
+ few steps, analytic-deflection hybrid, LOD by zoom. It does NOT touch the
physics, so a bad render path can be reverted to the sprite lens without losing
the collapse/disk work. Build behind a toggle first; A/B against the sprite lens.

## 9. Cold-start for the fresh window
Read, in order: this doc → the two RESEARCH docs → `DESIGN_2026-07-23_blackhole_overhaul.md`
(the fronts A/B/C, the yellow-zone + fineness ledger) → memory
`space_synth_session_2026-07-23` + this session's. The physics is sound and the
disk now PARKS (B2). The job is the render architecture: g(M) ray-march + 3D emitter.
