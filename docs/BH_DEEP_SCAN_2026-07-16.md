# BH LOGIC DEEP SCAN — 2026-07-16 00:04 (Jamal's order, zoomed-in crescent verdict)

## THE FINDING (one sentence)
The honest black hole is **100% observer and render, 0% dynamics** — `u.horizonR`
is uploaded to the physics kernel and NEVER READ (1 occurrence in
particles.metal = the declaration; 0 in spatial_hash.metal): matter inside the
horizon keeps living as ordinary hot SPH gas.

## The measured consequence chain (why "all particles in the center, not
## surrounding the hole")
1. Infalling matter shock-heats to the uMax cap (measured u=0.2621 ≈ cap;
   HUD PLASMA T pegged 1.0e+11 K).
2. Cap-hot gas has enormous pressure → forms a PRESSURE-SUPPORTED BALL in
   hydrostatic equilibrium AT THE CENTER — its radius set by pressure, not
   by r_h. The ball's bright surface pokes past the black splats = the
   crescent / "black dot with fuzz" at zoom.
3. The ball's pressure fountain recycles matter OUTWARD (the persistent
   vr>0 core readings all day = the ball breathing) — fighting the very
   collapse the horizon needs, from INSIDE the horizon, which is physically
   impossible (nothing pushes out across a horizon).
4. Meanwhile dynfric + LTRANS (no ISCO floor, mean-flow → 0 at center) drain
   orbiters' L all the way → they join the ball instead of parking in a
   ring. Result: center pile, no gap, no ring — exactly his verdict.

## The missing law (the "time axis" statement)
Inside the horizon, time effectively ends for the outside universe: no
signal, no pressure, no light crosses outward. The one-way membrane IS the
physics. In sim terms, for r < r_h matter must be CAUSALLY DEAD:
- NO SPH pair forces (pressure/viscosity cannot act outward),
- NO heat bookkeeping / emission → render-dark by physics (u → floor),
- pure gravity + strong inward damping → advects to the compact center,
- one-way: never revived/resurrected/re-heated,
- mass KEEPS COUNTING in the radial profile (core directive: the particles
  ARE the hole; r_h stays honest and grows).
Visible result: clean black ≤ r_h that only grows; the surviving matter's
inner edge sits just OUTSIDE r_h = the RING with the gap; the queue has
something to queue against (no fountain pushing back).

## Secondary findings
- Eaten-by-merge stars park at (4000,4000,4000) mass 0 — horizon-dead matter
  must NOT use that path (mass must stay in the profile, in place).
- Lifecycle revive/park is not r_h-gated — must respect the one-way rule.
- HUD "COLLAPSE 300%" family: bookkeeping (core vs stale total), separate
  ledger item; sane 41% early-run.
- Zoom-out lag + hole-body depth remain queued behind this fix.

## Fix design (ONE change): the ONE-WAY MEMBRANE block in compute_physics
Early in the kernel: if (u.horizonR > 0 && r < u.horizonR) → skip pattern/
SPH/dynfric/LTRANS force paths, zero u (dark, no pressure source), apply
gravity + strong velocity damping, clamp outward radial velocity to 0
(nothing exits), mark temp=0 for the render. SPH kernels additionally skip
pairs whose BOTH members are inside r_h (cheap: gate on the particle's own
r in sph_force via densityIn? — simplest honest cut: gate in compute_physics
where sphForce is APPLIED, and zero uInOut inside).
