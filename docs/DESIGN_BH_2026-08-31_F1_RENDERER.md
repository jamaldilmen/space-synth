# F1 — THE TRANSITION-NATIVE GEODESIC RENDERER
**Written:** 2026-08-31 16:42:01 · FABLE window · design only, zero `src/` edits
**Feeds:** F1 (the hole has no renderer). **Gated by:** OPUS cost measurements (§8).
**Inputs:** `docs/blackhole-library/02_LIGHT`, `04_HOW_THE_REFERENCES_DO_IT`,
`docs/SCIENCE_2026-08-31_blackhole_appearance.md` (P1, claims checked where used),
`docs/BOARD_BLACKHOLE.md` §Z (the mutual-exclusion law), §U8 (his chosen architecture).

Every `file:line` below was re-grepped in this tree on 2026-08-31 16:42:01 unless tagged
`[HANDOFF]` (taken from `HANDOFF_2026-08-31_FOUR_WINDOWS.md`, verified there 12:43:01).

---

## 0. THE CONSTRAINTS THIS DESIGN IS BUILT AGAINST — none are negotiable

1. **His architecture (§U8):** per-pixel backward geodesics that **TERMINATE ON THE REAL
   PARTICLES**. Never a grid fog integral. Both prior renderers are deleted (`00741f2`).
2. **The mutual-exclusion law (§Z, his ruling 2026-08-31 16:33:00):** BH and Chladni are two
   states of ONE entity; play ends the hole; force pumps out of the hole into the shapes;
   coexistence is legal only in transition. **The hole must be drawable while it is LEAVING.**
3. **NO SECOND LAYER** = one entity, not one representation. A per-pixel integrator for the
   collapsed state is legal; a bolted-on second object is not.
4. **The resolution wall:** horizon 0.1717 / photon sphere 0.2576 / ISCO 0.5151 sim all sit
   inside ONE coarse softening length (1.0), and span 2.75/4.12/8.24 fine ε (0.0625) inside
   the AMR box (§Y2). Design against it, not around it.
5. **A8 (library 04 §4):** the caustic/sampling structure MUST be filtered or oversampled.
   Nobody in the reference set shipped one unfiltered ray per pixel. Our "pebbles" came from
   ignoring exactly this.
6. **Live mass, both directions:** the drawn hole keys off the LIVE seed mass
   (`renderer.mm:3501`, `bhSeedMassMono = gMaxMass`), which can now FALL at runtime, and the
   outcome cap is dead (§Z4) so M is unbounded upward. The renderer may assume neither a
   persistent nor a bounded hole.

---

## 1. THE CENTRAL UNLOCK — dynamics resolution is not transport resolution

The resolution wall (constraint 4) limits the **matter distribution** near the hole. It does
not limit the **optics**, because null geodesics are integrated in the analytic
Schwarzschild metric of a point mass, on the screen's own angular grid — the particle grid
never enters. Our own proof: `tools/bc_validate.cpp` reproduces `b_c = 3√3·M` to 8.2e-15 on
this machine while the field runs on a 128³ hash. This is also how every production imaging
code is built — the GRMHD dynamics stage and the ray-transport stage are decoupled
(P1 §4.2 cites the ipole/grtrans/RAPTOR/GRay/Odyssey convention; claim checked against its
own citations, not reproduced here).

**So the honest split is:**
- **Geometry from the metric, at screen resolution** — legitimate at ANY hole mass,
  including all the way down the dissolution to M = 0.
- **Brightness from the particles, outside r_s + one fine ε** — which is where the
  particles actually are ([[space_synth_hole_has_no_intake_2026-08-22]]: capture
  teleport-deletes matter, so nothing lingers just outside the horizon anyway).

This split is what makes F1 buildable at all under constraint 4.

## 2. THE SECOND UNLOCK — spherical symmetry makes the transition free

We are a = 0 (the geometry already is: `render.metal:337` `kLensBc = 2.5980762` is the
Schwarzschild capture parameter). In a spherically symmetric metric **every backward ray
lies in one plane** — the plane spanned by the pixel's view direction and the hole. The
whole 3D transport problem reduces to a one-parameter family of planar trajectories
`r(φ; b)` indexed by impact parameter `b`.

**And in units of r_s that family is MASS-INDEPENDENT.** A static 2D LUT —
`(b/r_s, arc-parameter) → (r/r_s, φ)` — computed once, offline, by the same quadrature that
built the existing deflection LUT, serves every hole mass and every frame of the
transition. The live mass enters only as a per-frame SCALE FACTOR `r_s(M) = kRsSimPerMsun ×
bhSeedMassMono` (`renderer.mm:3530`).

**This is how the design satisfies the law rather than fighting it:**

| §Z clause | How it falls out |
|---|---|
| 1 — mutual exclusion | The geodesic region's screen area is a pure function of live M (§4). M = 0 ⇒ zero area ⇒ the frame IS the Chladni state. No flag, no state machine, no latch. |
| 2 — play ends the hole | The renderer is a pure function of (M, camera, particles) each frame. The physics drains M (§Z1); the picture follows in the same frame. |
| 3 — force pumps out | As M falls, `r_s` falls, deflection `α = 2 r_s/b` falls, and every lensed image relaxes CONTINUOUSLY back to its straight-line position. The light literally returns to the shapes. Not a crossfade — one budget, one scale factor. |
| 4 — coexistence only in transition | Mid-transition the frame is a shrinking geodesic disc over a live Chladni field. That is the only regime where both appear, and it is geometrically enforced. |

⭐ **The transition is not an edge case anywhere in this design. It is the ordinary
operation of a mass-scaled static LUT.** A renderer that special-cases formation or
dissolution has already violated the law.

## 3. THE ARCHITECTURE — one entity, two transports of the same light

### 3.1 The region split
Deflection at impact parameter `b` is `α ≈ 2 r_s/b` (weak field, library 02 §2). Define the
**geodesic region**: the screen disc where deflection exceeds one pixel of angular
resolution, `b < B_geo(M) ∝ r_s(M)` (worked numbers §8). Then:

- **Outside `B_geo`** — the existing sprite pass, unchanged. A straight ray and a geodesic
  are the same ray there to sub-pixel accuracy; the sprite pass is already the correct
  transport. This is also, identically, the whole frame in the Chladni state.
- **Inside `B_geo`** — a fragment pass over that disc only. Each pixel unprojects to a world
  ray exactly as `bhbody_fragment` already does (`render.metal:3034`, via
  `mu.inverseViewProj`, ortho AND perspective), reduces to its plane through the hole,
  walks the trajectory LUT scaled by live `r_s(M)`, and **terminates on the first real
  particle it enters** (§3.2). Rays with `b < b_c` that terminate on nothing reach the
  horizon: the pixel stays dark. **Shadow by absence, never paint** — same law as the
  existing cull at `render.metal:990` and the banner at `:1042`.
- **The seam is invisible by physics, not by blending:** at `b = B_geo` the integrator and
  the sprite pass agree to sub-pixel by construction. That agreement is TESTABLE (an A/B
  strip across the boundary) and is the acceptance test for the handover.
- Sprites whose straight-line image lands inside `B_geo` are suppressed there — the same
  test the capture cull already applies at `b_c`, widened to `B_geo`. The integrator
  redraws that light from the ray side, including the far-side wrap landing OVER the
  shadow. **One entity: same particles, same emission law, two transports.**

### 3.2 Termination on the real particles
The ray marches its plane in LUT steps; each 3D sample point looks up its spatial-hash cell
(`scatter_particles`/`cellStarts` at `spatial_hash.metal:326`, counts read capped via `min(cellCounts, 32u)` at `:391`) and ray-tests the ≤32
scattered particles' **finite footprints** — the same radius law the sprite pass draws.
First hit terminates the ray:

- **Emission = the sprite pass's own law**: `unifiedKelvin` (`render.metal:481`, consumed
  at `:1577`/`:1731`) → `blackbodyRGB` (`:220`). Not a new colour law. One entity.
- **One net g, applied once (A5):** `g = g_grav(r_emit)/g_grav(r_cam) × 𝒟(v_particle, k̂)`,
  transferred as `B_ν(ν, g·T) ≡ g³·B_ν(ν/g, T)` — in RGB terms: shift the Kelvin by `g`,
  scale intensity by `g³`, and say aloud that RGB is an approximation of that rule.
- ⭐ **Doppler comes from the MEASURED per-particle velocity, not from the Ω(r) law.** P1
  §3.1 shows the coded `Ω` at `render.metal:1428` (`KERR_A` at `:308`) is dimensionally
  3.41× too fast and applied about a field axis rather than a hole. This renderer never
  reads it — the particles carry their own velocities, which is the one place we are more
  honest than both references (library 04 §2.3). The Ω fix remains a separate, OPUS-owned
  correction for the sprite streaks.
- **No extra magnification factor.** One backward ray per (jittered) sample + `g³` already
  contains the lensing magnification (P1 §2.5). Multiplying by a Jacobian double-counts.

### 3.3 What A8 costs us, and how it is paid
The finite particle footprint IS the physical ray bundle — the thing DNGR synthesised
artificially, we have natively (library 04 §5.2). On top of that: jitter the ray's screen
position per frame inside the region and accumulate temporally (the region is small; the
cost is bounded). **Never one hard unfiltered ray.** This is the exact respect A8 has never
been paid here, and it is a launch criterion, not a polish item.

## 4. WHAT THIS DRAWS AND REFUSES TO DRAW — the P1 verdicts, adopted

| Feature | Verdict | Why |
|---|---|---|
| Shadow / dark region | **DRAW, by absence** | rays that reach `r_s` terminate on nothing. Never stamp a disc at `b_c` — the dark edge is set by where emission stops (P1 §1.2), and during dissolution it shrinks with M for free. |
| Far-side wrap over the top (R5) | **DRAW** | falls out of any correct backward integration — rays from matter behind the hole, bent over. No extra code beyond §3. |
| Second image, parity-flipped (R6-as-is) | **DRAW** | the >180° family arrives mirrored. ⚠️ **Refinement to R6, honestly:** the Luminet UNDERSIDE ARC requires an optically thick two-faced disc. Our field is optically thin particles — there is no underside; what appears below the shadow is the n = 2 image of the same emitting volume (P1 §1.6). Drawing a Luminet arc would be a fabrication. |
| Photon ring n ≥ 3 | **DO NOT DRAW** | ~one pixel wide at any plausible field of view, and carries a fraction of a percent of the flux — a visible bright ring at `b_c` is ANTI-physical (P1 §4.3). Whatever sub-pixel pileup the LUT produces integrates into the pixel; no ring primitive, ever. |
| Doppler asymmetry | **DRAW, from particle velocities** (§3.2) | invisible face-on regardless — measured `vLos = 0` at his default camera ([[space_synth_facing_and_taps_2026-08-27]]). Any verdict on it needs an edge-on A/B first. |
| A disc | **DO NOT FABRICATE** | a collisionless field has no disc and emits nothing as gas (P1 §2.4). The particles themselves are the emitters, drawn where they are. If he ever wants a gas disc, that is a posited, labelled addition — a different task. |
| Seed-mass holes (r_s ≪ fine ε) | lensing point + shadow only, **no emission structure** | anything drawn inside a few ε of a seed is softening artefact (P1 §4.3). The region is a few pixels at seed mass anyway — the design degrades to this on its own. |

## 5. WHAT THE RENDERER CONSUMES — and one input it must refuse

- **Raw live mass:** `bhSeedMassMono` via `lastHorizonR` (`renderer.mm:3530`), per frame.
- ⛔ **NOT the old eased `lastHorizonRSmooth`** — the `×0.03/frame` render ease (§Z2a,
  now dead at `renderer.mm:1852` where the kill's own comment stands) drew the hole ~3 s
  after the mass had left, violating clause 4. That ease was the 2026-07-19 cure for the
  radial-profile STAIRCASE (11 discrete values, §V1) — and the staircase died when keying
  went seed-derived and continuous.
  ✅ **ORDERED KILLED by him 2026-08-31 (relayed via BRAIN 17:05:45): "kill the ease. fix
  probe rate instead obviously !!!"** — OPUS's edit, with the probe rate fixed alongside.
  ⭐ **CORRECTED 2026-08-31 17:08:54 — the ease kill alone was NOT enough, and this line
  originally over-claimed it was.** The dies-on-the-beat assumption had THREE obstacles.
  ✅ **ALL THREE ARE NOW SHIPPED-DEAD, re-verified in the live tree 2026-08-31 17:14:30**
  (OPUS's edits landed while this doc was being written; old line numbers shifted):
  1. the `×0.03` radius ease — now `lastHorizonRSmooth = lastHorizonR` verbatim
     (`renderer.mm:1852`; formerly near line 1829). The kill comment above it states the
     law violation plainly: a ~3 s render lag WAS "after play bh formed stays for a bit".
  2. the `×0.04` `bhStrengthEma` ease — now `bhStrengthEma = target` (`renderer.mm:3678`;
     formerly near 3640). Flagged here as uncovered; his order via BRAIN: "kill that too".
  3. 🚨 the strength FLOOR — was `std::max(bhStrengthEma, 1.0f)` while `bhFormedLatch`
     held: not a lag, a cannot-go-down rule, same class as the §Z1 mass ratchet, and the
     latch never cleared in his play run (drained to 938 M☉ with a small NONZERO horizon).
     Now `bhStrength = bhStrengthEma` (`renderer.mm:3718`; formerly near 3669). OPUS's
     own kill comment confirms this doc's §Z1 correction: *"killing the mass ratchet
     alone would NOT have let the drawn hole die."*
  ⚠️ The surviving `std::max` at `renderer.mm:1851` is the POSED-BH override only
  (`bhPosed` path) — not a floor on the emergent path. Checked so nobody re-flags it.
  **This design may now assume the drawn hole follows the honest r_h and strength with no
  lag and no floor — the hole can die on the beat.** UNJUDGED by his eyes, like everything
  else §Z shipped — F1 still gates that verdict (§Z3).
- ℹ️ **Clause-3 pump-out is moving to PLAY AMPLITUDE** (OPUS, in progress per BRAIN
  2026-08-31 17:05:45): the drain rate becomes a function of how hard he plays, not of
  corpse availability. **No structural change here** — this design consumes the live MASS
  per frame, never the drain RATE — recorded so nobody wires a rate assumption in later.
- **Untouched, by order and by design:** the tDilate shear (`render.metal:926`, `:2810` —
  his "beautiful time warpeyssss", never remove); the depth-only capture sphere
  `bhbody_fragment` (`render.metal:3028`) — inside the region the integrator supersedes its
  job, outside it keeps occluding for the sprite pass; the capture cull at `:990`, which
  becomes the `B_geo` handover test rather than a separate mechanism.
- **Ready and waiting:** the 1024-point Schwarzschild deflection LUT
  (`lensAlphaSample`, `render.metal:340`) has ZERO shader callers today (re-verified: one
  occurrence, its definition) — it is the quadrature seed for the 2D trajectory LUT, and
  `renderer.mm:908`/`:924`/`:930` already document its schedule. ⚠️ Library 04 §5.7 cites
  those comments at `:854`–`:876` — decayed, lines moved; 14th sighting of the pattern.

## 6. WHY THIS IS NOT A DEAD ROAD RETRIED

- **Not the march (U2):** the march summed emission from a 128³ density grid along the ray
  — a fog integral with no temperature. This TERMINATES on the same matter the sprites
  draw, taking its emission and its g. That distinction is the licence §U8 grants.
- **Not the lens (U1):** the lens was a forward per-sprite displacement — it could only make
  as many images as it had coded roots (two), and could never flip parity. Backward
  per-pixel transport produces the whole winding family and mirrors the >180° images by
  construction. **Parity is the free honesty test** (library 02 §3).
- **Not the rejected Kerr raytracer:** that was full-screen, per-pixel ODE integration in
  Kerr with unfiltered single rays. This is a bounded screen region, planar Schwarzschild,
  static-LUT stepping, filtered per A8. The caustic defect was Kerr-specific and
  sampling-specific (04 §5.2); FPS is answered by measurement, not assertion — §8.

## 7. OPEN PROBLEMS — stated, not smoothed over

1. **Ray-vs-particle-cloud is unsolved in the literature** (04 §5.5) — nobody else had the
   particles. §3.2 is a proposed solution, not a cited one. It stands or falls on the seam
   test and the cost measurement.
2. **The 32-per-cell sample (F2) reaches the picture.** In a 334k-particle core cell the
   ray tests 0.01% of the matter that is really there — rays can MISS through genuinely
   opaque cells (§V4: `ghostReads=74.2%`). Mitigation: a cell whose UNCAPPED count says it
   is optically thick terminates the ray on the cell's aggregate emission
   (`compute_cell_centroids` exists, `spatial_hash.metal:380`).
   ✅ **RULED YES by him 2026-08-31 ("1. yes.", relayed via BRAIN 17:05:45), WITH SCOPE:**
   ONE termination on ONE cell is inside the no-fog ban because it is not an integral
   along the ray. **Accumulating across several cells along a ray is NOT covered by this
   yes — it is a different question and must be re-asked, not inherited.**
   ⚠️ **Standing watch condition, report-don't-tune:** a per-cell aggregate is a CUBIC
   quantity, and the grid showing up in the picture is his oldest complaint ("grids for
   months", [[space_synth_the_grid_is_in_the_physics_2026-08-28]]). If opaque cores start
   reading as CUBES on screen, that is a finding to surface immediately, never a defect to
   quietly smooth.
3. **Unbounded M (§Z4).** `B_geo ∝ r_s(M)` and M is now uncapped — the region can grow to
   cover the frame, and cost grows with its area. The honest failure mode is a frame-rate
   cliff at extreme mass, reported as such; quiet degradation (fewer steps, lower res) is
   banned by standing rules. Needs his call once the cost numbers exist.
4. **Multiple holes.** Up to 11 seeds live (§V7). Superposed analytic metrics don't exist;
   v1 scopes the geodesic region to the DOMINANT formed hole, others stay sprite+shadow.
   Two formed holes orbiting (the §Y1 endgame, and the F3 money shot) will need two
   disjoint regions — legal while the regions don't overlap, undefined when they do. Stated
   now so it is a decision later, not a surprise.
5. **The ~220 px blackbody blob above ~356k M☉** (§Z4 consequence, traced not fixed) is
   OPUS's; if the region suppression of in-region sprites happens to mask it, that is a
   side effect to REPORT, not a fix to claim.

## 8. THE NUMBERS, AND WHAT I NEED FROM OPUS — I do not build, launch, or measure

Worked example at the formed-hole scale (`M = 102,144 M☉ ⇒ r_s = 0.1717 sim`,
`b_c = 0.446 sim`): one-pixel deflection at ~2 Mpix means the region boundary sits near
`α ≈ 1e-3 rad ⇒ B_geo ≈ 2 r_s/1e-3 ≈ 340 r_s ≈ 58 sim` — clearly too generous; a
PERCEPTUAL threshold (α under ~1/20 of the shadow's angular radius) lands nearer
`B_geo ≈ 10–20 r_s ≈ 2–3.5 sim`. The threshold is a dial to sweep on screen, not a
constant to bake. At `Mmax = 161,690` (measured idle, §Z4) scale everything by 1.58×.

**Asks, in order:**
1. **Screen coverage:** at his default camera and a formed hole, what fraction of the
   drawable falls inside `b < 10 r_s` and `b < 20 r_s`? (One log line from existing
   uniforms — no new physics.)
2. **A step-cost anchor:** the cost of a bounded fragment pass at that coverage with
   ~64–128 LUT samples/ray — even a synthetic loop, interleaved arms, n≥4, per the
   measurement discipline. This is the go/no-go for the whole design.
3. **The seam A/B** once a prototype exists: a strip across `B_geo` — integrator vs sprite
   pass must agree to sub-pixel. Disagreement means the LUT scale or the handover test is
   wrong, and the design says so before he ever judges the look.

---
**Last Updated:** 2026-08-31 17:08:54 — §5 corrected: dies-on-the-beat had THREE obstacles
(both eases + the `:3669` strength floor), all now ordered killed; the earlier claim that
the first kill sufficed is retracted inline. Companion doc:
`DESIGN_BH_2026-08-31_F1_FALSIFIABLE_TESTS.md` (T1–T5 for BRAIN's P4). ⚠️ P0 (what object
are we simulating) is with the science track — if it moves the spawn's reference object,
it lands UPSTREAM of this design; nothing here assumes a particular astrophysical identity
beyond the unit convention.
Previous stamp 2026-08-31 17:05:45 — folded his three rulings (relayed via BRAIN):
§7.2 aggregate-termination YES with scope + cube-watch; §5 ease KILL ordered (lag
assumption now guaranteed); clause-3 pump-out moving to play amplitude (no structural
change, recorded). §7 items 3/4/5 remain OPEN — his silence is not approval.
First cut 2026-08-31 16:42:01. FABLE owns this file; corrections from
the O0 sweep land as inline tags, not silent rewrites.
