# F1 — THE LENS, BUILDABLE: time-space bending around the hole
**Written:** 2026-08-31 18:18:28 · FABLE window · his order via BRAIN: *"i want fable on
the lense / time space bending around the black hole."*
**Companions:** `DESIGN_BH_2026-08-31_F1_RENDERER.md` (the architecture and the law
mapping — this doc implements its §3) · `DESIGN_BH_2026-08-31_F1_FALSIFIABLE_TESTS.md`
(T1–T5 — every build step below names which test gates it).
**Every `file:line` re-grepped 2026-08-31 18:18:28.** OPUS builds; FABLE designed; nothing
here is done until his eyes pass it.

---

## 0. THE LIVE STATE, EXACTLY — better than "the lens is fake", narrower than "it lives"

**What is alive and correct (do not rebuild):**
- **The exact α(b) table.** Built once on CPU (`renderer.mm:938` — Newton for the turning
  point, 1024-pt midpoint rule under the `u = u0(1−t²)` substitution that removes the
  turning-point singularity), uploaded (`renderer.mm:962`), **bound every frame**
  (`renderer.mm:4191`, `:4250`), declared in the shader (`render.metal:653`), sampler ready
  (`lensAlphaSample`, `render.metal:340`) with the log-in-(b−b_c) schedule that resolves
  the divergence.
- **`tools/bc_validate.cpp`** — a real null-geodesic integrator, `b_c` to 8.2e-15. The
  "how do we integrate" question is answered in-tree.

**What is dead scaffolding (present, but drives nothing):**
- ⚠️ **NOTHING CONSUMES α TODAY.** `lensAlphaSample` has zero callers (re-verified:
  one occurrence in shader code — its definition). The buffer is bound and unread.
  "Consumed at 653" would overstate it: DECLARED at 653, read by nothing.
- **The coded second root is doubly dead:** `isSecondary = (iid == 1u)`
  (`render.metal:784`) — but `instanceCount:1u` (`renderer.mm:4211`) means instance 1
  never draws, AND `render.metal:1070` culls any secondary unconditionally ("no second
  image without a lens"). Six `isSecondary` branches survive as scaffolding.
- 🪶 **Decayed credit, for the O0 sweep:** `render.metal:326` attributes the LUT to
  "renderer.mm schwarzschildAlpha" — that function name no longer exists (build is inline
  at `renderer.mm:938`). The LUT is alive; only the credit is stale. 15th sighting.

**So the precise starting point:** the correct bend angle is computed, uploaded, and bound
— and applied to NOTHING. The historical defect (screen-space remap of rendered sprites =
the plate) was deleted 2026-08-27. The job is not to fix a wrong application; it is to
give the right physics its FIRST correct application: trace the ray, find what is there.

## 1. THE CORE DECISION — integrate per pixel, validate against the table

Two candidate transports for `r(φ; b)` inside the region:

**(a) A 2D trajectory LUT** `(b, arc) → r` — precomputed like the α table.
**(b) Direct in-shader integration** of the planar geodesic, per pixel.

**This design chooses (b), with (a)'s 1D table kept as the VALIDATION ORACLE.** Reasons,
each grounded in this tree's own history:
1. **The encoding risk is real and has already bitten.** The α table's own banner
   (`render.metal:331`) records that a wrong log schedule silently cost 23.6% error, and
   warns the schedule is mirrored in two files with no error on mismatch. A 2D table
   doubles that encoding surface; an integrator has none.
2. **The plunge and scatter branches unify.** `b < b_c` (no turning point, ray falls in)
   and `b > b_c` (turning point, ray escapes) are the same ODE with different fates; a
   table needs two parameterizations, the integrator needs an exit test.
3. **In-shader integration has precedent HERE**: the shipped shader integrator reproduced
   `b_c` to 1.45e-5 at step 0.03 (library 02 §1's measured row). This is not novel risk.

**The equation** (r_s = 1 units, u = r_s/r; the one card, library 02):
```
d²u/dφ² = (3/2)u² − u          energy check: (du/dφ)² = 1/b² − u² + u³
```
Two state variables, RK2, **step Δφ = π/512 baseline** (⛔ corrected from the original
π/64 by the B1 RULING in §5 — π/64 was 32× too coarse for its own gate; adaptive schemes
legal if re-gated), **winding cap φ_total ≤ 3π** — n = 1 territory, consistent with the
P1 verdict that n ≥ 3 must not be drawn. The energy identity is the in-loop drift check
(a free assert per step, log-only).

**Initial conditions at a FINITE camera** — b is the CONSERVED L/E, not an asymptotic
approximation, so this is exact: `u₀ = r_s/r_cam`, `v₀ = ±sqrt(1/b² − u₀² + u₀³)` inbound;
the ray's plane basis is built from the pixel ray and the hole exactly as
`bhbody_fragment` builds its geometry (`render.metal:3028` block — same unproject, same
world-space hole).

## 2. THE MARCH — termination, in order of test, per step

Per φ-step, map `(u, φ)` to a world point, then:
1. **Horizon:** `u ≥ 1` → the pixel is DARK. Stop. Shadow by absence — never stamp `b_c`.
2. **Particle hit:** hash-cell lookup (`scatter_particles`/`cellStarts` at
   `spatial_hash.metal:326`), ray-segment vs the ≤32 finite footprints. Hit → take that
   particle's `unifiedKelvin` emission (`render.metal:481`) × one net `g³` (design doc
   §3.2 — g from position + MEASURED particle velocity; the broken Ω law is never read).
   Stop.
3. **Approved opaque-cell termination** (his "1. yes", scoped): the cell's UNCAPPED count
   marks it optically thick and the 32-sample missed → terminate on the cell aggregate
   (`compute_cell_centroids`, `spatial_hash.metal:380`). ONE cell, ONE termination —
   accumulation along the ray stays banned. 🚨 Cube-watch is a standing report condition.
4. **Escape** (`r` beyond the march bound, heading out): the ray leaves the strong field
   travelling STRAIGHT in its exit direction. Terminate by sampling the scene radiance in
   that exit direction — the role the references give the celestial sphere. For us that is
   the sprite-pass framebuffer read at the exit direction's reprojection.
   ⚠️ **Stated approximation, not hidden:** this treats matter OUTSIDE the march bound as
   distant — parallax between camera and exit point is neglected, error ~ (march bound /
   distance to that matter). Matter INSIDE the bound is really terminated on; the error
   touches only the mid-field just outside. **This is an environment-map termination of a
   genuinely traced ray — not the plate: the plate MOVED rendered pixels by α; this reads
   what the exit ray actually looks at.** If his eyes catch the mid-field seam, the march
   bound is the dial that pushes it out, at linear cost.
5. **Winding cap reached** without any hit: treat as capture-adjacent; dark. (Only rays
   hugging `b_c` get here; their true fate alternates images thinner than a pixel — P1's
   own do-not-draw regime.)

**Step-vs-cell note:** Δs ≈ r·Δφ grows with r; beyond r ≈ cellSize/Δφ the march can skip
cells. The march bound should sit at or inside that radius so every cell along the curved
segment is actually visited; outside it, rule 4 already owns the ray.

## 3. THE REGION AND THE HANDOVER — unchanged from the architecture doc, restated as the contract

- Fragment pass over the screen disc `b < B_geo(M)`, `B_geo ∝ r_s(M)`, live per frame —
  M falls, the disc shrinks, at M = 0 the pass draws zero pixels. **The four cannot-go-down
  rules are dead (mass ratchet, horizon ease, strength floor, disk-rotation ease), so the
  input really does fall now — design against the live value, not the old lag.**
- Sprites whose straight-line image lands inside `B_geo` are suppressed (the widened form
  of the existing `b_c` cull at `render.metal:990`); the integrator redraws that light.
- The tDilate shear (`render.metal:926`) stays untouched and its `r_s` and the
  integrator's `r_s` must be THE SAME live value — one entity, one mass.
- T1 (seam) is the acceptance test of this section; its failure modes are diagnostic.

## 4. WHAT DIES, AND WHEN

The `isSecondary` scaffolding (`render.metal:784` and its six branches) is the coded
second root — the thing T2 proved fakeable and T3 kills. **It is deleted, not commented
out** (a zero-consumer mechanism gets deleted — the faders precedent) — **but only AFTER
the integrator's secondary image passes his eyes.** Sequence: new thing judged, then old
scaffolding removed, one commit, so the diff that deletes it cites the verdict. Same
commit retires the `:326` decayed credit and rewrites the `:340` sampler banner to name
its new caller (or deletes the sampler too if the integrator ends up not reading the α
table at runtime — it is the oracle, not the path).

## 5. BUILD ORDER FOR OPUS — one verifiable change each, a test per step

| # | Change | Verified by | Visual? |
|---|---|---|---|
| B1 | CPU reference marcher (mirror of the shader loop) + validation: recover α(b) from the marcher, compare to the live 256-entry table AND `bc_validate` | ⛔ **GATE CORRECTED 2026-08-31 18:50:14 — see the B1 RULING below the table.** Original "rel < 1e-3 over b ∈ (1.001·b_c, 200)" was WRONG and OPUS's run rightly failed it | no |
| B2 | Region mask + fragment pass in DEBUG colouring (termination class per pixel: horizon / particle / aggregate / escape / cap) | ⛔ **SPLIT BY OPUS 2026-08-31, ACCEPTED 20:04:29 — see the B2 SPLIT note below.** The original gate ("T4 in debug form") referenced B2b machinery and was wrong FOR B2a — same class of error as the original B1 gate | yes — debug view, his first look |
| B3 | Real termination + emission + sprite suppression handover | T1 seam numbers; T4 for real; T2 triad sign | yes |
| B4 | One net g³ + Kelvin shift | edge-on A/B (face-on is null by measurement) | yes |
| B5 | A8: per-frame jitter + temporal accumulation inside the region | pebble check at the ring; T3 arc at closest alignment | yes |
| B6 | Delete `isSecondary` scaffolding + stale banners (§4) | citation sweep stays 0 DEAD; T2/T3 still pass | no |

Each step STOPS for its verdict per working protocol. B1 needs no build token conflict —
it is offline CPU code beside `bc_validate`. **The two pending cost numbers (coverage at
b < 10/20 r_s, step cost) fall out of B2 for free** — the debug pass IS the cost probe.

### THE B2 SPLIT — OPUS's deviation, accepted 2026-08-31 20:04:29, with per-half gates

OPUS split B2 rather than applying it whole, and flagged the split instead of doing it
silently — correct on both counts. **B2a** = region mask + per-pixel geodesic march +
termination classes WITHOUT particle machinery (built, cost probe running).
**B2b** = particle + opaque-cell termination classes (not started). The original B2 gate
("T4 in debug form") needs B2b's machinery, so gating B2a on it would repeat the B1
mistake. The per-half gates:

- **B2a gate:** in the debug frame, (1) the termination class must be a function of `b`
  ALONE — azimuthally uniform circles centred on the hole; with no particles involved,
  ANY azimuthal structure in B2a's classes is a bug, and this can fail on one captured
  frame; (2) the horizon-class disc's radius scales with live M (visible shrinking under
  a drain, or two masses → two radii); (3) the winding-cap class appears only in a thin
  annulus hugging `b_c`; (4) the two cost numbers (coverage at b < 10/20 r_s, ms at
  π/512) are logged — B2a IS the cost probe.
  ⚠️ **MEASUREMENT DISCIPLINE, added 2026-08-31 20:08:11 from OPUS's finding:** the cost
  gate (4) CANNOT be measured against a free-running hole. `[MEASURED by OPUS]` two runs
  at the SAME `SS_SPAWN_SEED` diverged 4× in Mmax after 50 s — the 32-of-334k neighbour
  fork (F2) is set by GPU scheduling order, not the RNG, so region area ∝ (B_geo·r_s)²
  is not reproducible between arms. OPUS's first A/B was invalid for exactly this reason
  and was rightly not reported. **Gate (4) runs with `SS_LENS_PIN_RS` (debug-pass-only
  r_s override; its banner marks it measurement-only — set otherwise it decouples the
  drawn region from the mass, which is precisely a §Z violation). Gate (2) runs with the
  pin OFF, as a separate observation — pinned, disc size is constant by construction and
  the test is void.** ⭐ Same hazard, pre-empted for T1: the seam test compares
  integrator vs sprites on IDENTICAL state — same-frame or frozen-state only, never two
  free runs, or the fork measures "different hole", not "different transport".
- **B2b gate:** the original criterion — a hidden emitter's particle class appears at
  `b > b_c` (T4 in debug form), and the aggregate class appears ONLY in cells whose
  UNCAPPED count marks them optically thick.

### THE B1 RULING — 2026-08-31 18:50:14, FABLE, after OPUS's validator failed the original gate

**The original gate was wrong, for two stated reasons — it is REPLACED, not relaxed:**
1. **Wrong error metric in the far field.** The observable is angular displacement on
   screen, which is ABSOLUTE. α falls as 2/b while the marcher's absolute error is
   near-constant in b, so a relative gate is hardest exactly where the bend is least
   visible. At b = 200, α = 0.0100 rad and the miss was 1.9e-5 rad — 0.03–0.09 px at any
   real drawable. The gate demanded the error be small relative to α; physics demands it
   be small relative to a PIXEL.
2. **It gated a regime the design's own §2 rule 4 excludes.** The march is bounded;
   b = 200 rays are escape-handled, not marched. The envelope stays in the gate only as a
   conservative ceiling.

**The corrected gate — two legs plus the capture leg, each tied to the test it feeds:**
- **Strong field, b ∈ (1.001·b_c, 20]: relative error < 1e-3.** Why 1e-3: T5's runtime
  tolerance is 1%; the marcher must sit 10× under it so T5 tests physics, not numerics.
- **Far field, b ∈ (20, 200]: ABSOLUTE error < 1e-4 rad.** Why 1e-4: sub-half-pixel
  **at FOV ≥ ~61°** — 0.31 px at 100°, 0.38 px at 80°, 0.51 px at 60° on the 5340 px
  front wall — which covers the wall frustums (front 68.33°, sides 111.67°).
  ⛔ **CORRECTED 2026-08-31 18:52:39 — this bullet first said "sub-half-pixel
  everywhere", which is FOV-blind and false: pixel count alone does not convert an
  angular error.** (BRAIN's catch, arithmetic re-verified here.) At narrow FOV the gate
  CEILING reaches one pixel: 1.02 px at 30° — and a camera ride toward the hole is
  exactly a narrow-FOV, audience-looking-hardest regime. **Accepted as a stated limit,
  not tightened**, for two reasons: (1) at b > 20 r_s the whole bend is ≤ 0.1 rad and
  falling — a one-pixel error there does not read; (2) the π/512 BASELINE sits 5× under
  the ceiling: its actual 1.93e-5 rad is **0.20 px even at 30° FOV**. The 1 px exposure
  exists only if a future scheme ships at exactly the gate ceiling — if a ride ever shows
  a far-field seam, the gate's far leg tightens to 5e-5 rad and the scheme re-gates;
  that is the named dial, decided by his eyes, not silently.
  T1's seam budget (< 1 px total) keeps ≥ 2× headroom at the wall FOVs.
- **Capture: b_c recovered to rel < 1e-3** (the leg α never tests; passing at 3.365e-4).

**The step: baseline Δφ = π/512** — the first scheme that passes both legs with real
margin (rel 2.166e-4 = 4.6×; abs 1.93e-5 rad = 5.2×). π/256 is REJECTED as baseline: it
scrapes leg 1 at 0.91 of the bound, and a gate passed at 1.1× margin is a gate waiting
to flake. π/1024 is not required. ⭐ **The gate gates the SCHEME, not the constant:**
adaptive stepping (fine near the turning point, coarse far out) is legal and encouraged
for B2's cost — any scheme re-run through the same validator that passes both legs is in.
**Cost honesty:** π/512 is 8× the π/64 this doc first assumed; that multiplier flows into
B2's measurement as-is. If B2 says it is unaffordable, we return with data — correctness
is not pre-shrunk to fit a budget. His bar stands: "no shortcuts no fake lense."

**What B1 already proved, kept on the record:** RK2 confirmed second order (error ÷4 per
halving, seven step sizes); marcher vs the live LUT's quadrature at b = 3.0 agrees to
7.6e-6 across two code-independent methods; the capture radius passes. The physics of the
marcher is right; the criterion I wrote for it was not. Retracted and corrected here.

## 6. TIME-SPACE BENDING WHILE THE HOLE DISSOLVES — the fast-light statement

Per frame the metric is STATIC at the current `r_s(M)`; rays are traced whole in that
snapshot. This is the **fast-light approximation** — the default in every production
imaging code (P1 §4.2's ipole/RAPTOR family), and the only regime where the mutual-
exclusion law's transition is cheap: bending strength follows M within one frame, the
region shrinks continuously, the light "returns to the shapes" as clause 3 demands.
**What it neglects:** light-crossing time across the region vs. per-frame mass change —
during a fast drain a real photon would sample a shrinking hole along its path
(slow-light). **If and only if his eyes say the transition looks wrong, that is the
targeted science question BRAIN offered to write** — it is downstream of a lens that
works at all, and it is the one P4 fragment worth keeping warm.

---
**Last Updated:** 2026-08-31 20:08:11 — measurement discipline added to the B2a gate
(OPUS's finding): cost pinned via SS_LENS_PIN_RS, mass-scaling checked pin-off, T1
same-state rule pre-empted — the free-running hole diverges 4× at identical seed.
Previous stamp 20:04:29 — B2 SPLIT accepted (OPUS's deviation, flagged not
silent) with per-half gates; the original B2 gate referenced B2b machinery and gating B2a
on it would have repeated the B1 mistake.
Previous stamp 18:52:39 — far-field justification corrected (BRAIN's
catch): "sub-half-pixel everywhere" was FOV-blind; now stated per-FOV with the narrow-FOV
camera-ride case an accepted, named limit and the baseline's 5× cushion on record.
Previous stamp 18:50:14 — B1 RULING added (§5): the original α gate was
wrong in metric and domain, replaced with the two-leg gate; step baseline π/512; π/64
retracted. First cut 2026-08-31 18:18:28. FABLE owns this file.
