# 🕳️ THE BLACK HOLE BOARD — dedicated, 2026-08-14

> **His order, 2026-08-14 01:41:51:** *"create dedicated board for BH. with all knowledge every hard limit and inspo we know of and track this shit down properly. I want my proper bh with the time / space mindfuck look. Nothing below that."*

🎯 **COLD START = `docs/TODO.md`** (12 KB, ~3k tokens) — the whole open list in four buckets, every `file:line` re-read against the code 2026-08-20 14:08:59. **Open this file only for the detail of a row you are actually working.**

**This file is the reference of truth for the hole.** `docs/BOARD.md` stays the whole-project board; everything BH moves here. Every row carries a **verified `file:line`** checked on **2026-08-14 01:41:51** against `SPACE-SYNTH-TUBE-killtube`, branch `kill-the-tube-2026-08-11`, bundle `01:28:44`. A row with no citation is a claim, not a fact, and is labelled as such.

**Commit at last verification:** `5b65a97` ⭐ **RE-STAMPED 2026-08-30 23:45:00 — SESSION 2026-08-30 FOLDED IN AS §X (read it FIRST). 🚨 THE HOLE'S FORMATION IS DECIDED BY A 32-PER-CELL BUFFER SIZE — every single-run BH comparison on this board is unreliable. Engine-wide clock law + closures in `docs/BOARD.md` §Y.** Sources end at `d0697d8`; `5b65a97` is the bundle, which carries NO source change. 🌳 **TREE IS `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` @ `true-physics`.** Previously `4847e92` ⭐ **RE-STAMPED 2026-08-29 17:39:00 — SESSION 2026-08-29 FOLDED IN AS §W (read it FIRST). Engine-wide law + all measurements live in `docs/BOARD.md` §X.** Sources at `d0db70b`; `4847e92` is the bundle, which carries NO source change. Previously `01f1048` ⭐ **RE-STAMPED 2026-08-29 10:46:00 — SESSION 2026-08-28/29 FOLDED IN AS §V (read it first; §U is the session before).** Tree is now `/Users/airy/SPACE SYNTH/SPACE-SYNTH-POST-TUBE` @ **`post-tube`** (he named it 2026-08-28; was `SPACE-SYNTH-BH` @ `bh-gargantua-2026-08-26`). 🚨 **BOTH BH RENDERERS WERE DELETED THIS SESSION — every row below that describes the lens or the march is now HISTORY, not state.** §1a, §1b, §2, §5 and §6 in particular describe code that no longer exists. §U is the current state. ⚠️ Only the §U rows were read at this sha; every other row still carries its own older stamp, and many now describe deleted code. Previously `44d1798`.

---


## X. 🕳️ SESSION 2026-08-30 — **THE HOLE'S FORMATION IS DECIDED BY A BUFFER SIZE**

> Engine-wide clock law + all nine clock closures live in `docs/BOARD.md` §Y. This is the BH half.

🚨 **`merge_stars` and the seed capture both scan `min(cellCounts[cid], 32u)`, and `scatter_particles` stores only the first 32 per cell on a first-come `atomic_fetch_add`.** The densest cell logs **334,576** particles (`bhPeakCount`, uncapped). The hole therefore forms out of a **0.01% sample chosen by GPU scheduling order.**

`[MEASURED n=4 stacked per arm]` warp 1, fullscreen, 2M, `Mmax` at matched window 5 — cap 32: 3388 / 3345 / 37257 / 35224 (**11.1× fork**, seeds at window 2 = 1,1,2,2). Cap 64: 20979 / 21418 / 7229 / 6223 (**3.4× fork**, seeds = 8,7,8,8).
⭐ **Doubling the sample quadrupled the seeds and cut the fork 3×.** The discriminator between the slow and fast branch is whether a SECOND seed forms in the opening 240 frames.

⚠️ **This invalidates single-run BH comparisons across this whole board.** `Mmax` at matched sim time forks 11× on identical inputs, so any accretion constant tuned against one run was tuned against a coin flip. `count_cells` already warned: *"a seed in a 15k-star core cell was sampled 0.2% of frames and STARVED (measured: Mmax froze)."*

🚨 **Warp still does not form the hole properly, and the 2026-08-29 ×120 fix did NOT close it** — the handoff row claiming "mergers died under warp → fixed" overstated what was measured. `[MEASURED 2026-08-30]` at warp 4 one run was **stone dead** (`Mmax=50.0` = `M_BH_SEED`, `seeds=0`, `mrg=0/0/0`, 2M particles untouched, `peak=1897514` — the field imploded into one cell) while others formed partially. Root cause now known: `compute_physics` was integrating on a hardcoded 1/60 for 95 of its 97 `dt` uses (§Y0 row 1), so warp barely reached the integrator; the two sites the ×120 fix touched were among the 2 that did. Fixed at `e2838f6` — **warp is now honestly a bigger step, and therefore honestly unstable.** The cure is warp as MORE steps, gated on step cost.

---

## W. ⏱️ SESSION 2026-08-29 — WARP WAS KILLING THE HOLE, AND THE ×120 CONVENTION WAS WHY

> **Full engine-wide law + all measurements: `docs/BOARD.md` §X. This section is the BH half only.**
> **His words 2026-08-29:** *"mergers dont make sense on the high speeds yet."* · ***"I want the money shot to be two black holes merging."***

### W1. ✅ WARP WAS DETERMINISTICALLY KILLING SEED FORMATION — root cause found and fixed
`[READ particles.metal:1425/:3704/:4059]` the **"×120 seed-capture convention"** converted per-step displacement to velocity by assuming dt = 1/120 s. Real dt = 0.0165 (60.6/s), and under warp dt = 0.0165·warp ⇒ **`vrel²` wrong by 3.92 × warp²**.
- `:3704` (merge bound test, **UNCLAMPED**) refuses fusion at `vrel2 >= vesc2` ⇒ an inflated `vrel²` declares BOUND pairs unbound. **This is the mergers-under-warp bug.**
- `:1427` / `:4061` gravitational focusing is `rt·(2GM)/vrel²` — *"the accelerator… what powers the runaway to forming"* — so it was **~4× too weak at ×1 and ~63× too weak at ×4**.
`[MEASURED n=2, seed 777, matched sim time 63.4 units]` **BEFORE at warp 16: `Mmax=50.0` (exactly `M_BH_SEED`), 0 seeds, 0 merges, 2.00M untouched — nothing formed at all.** AFTER: 11426 / 8734 with seeds forming, 2/2. Warp 1 unchanged; merges 11–15 → 20–33.
Now `v = displacement / u.dt` (warp-invariant) at all three sites; the comment that taught the convention is corrected.

### W2. 🚨 THE FOCUSING FIX IS MOSTLY BEING THROWN AWAY — clamp is next
`[READ particles.metal:1429 and :4063]` `reach = 1.4f * su.cellSize; rt2 = min(rt2, reach*reach)`. The 3.92× stronger focusing W1 restored is capped straight back off. ⭐ **This is why the board already recorded that deleting the clamp alone plateaus (2.00–3.46 sim): focusing was broken TOO. Clamp + the 3×3×3 scan + ×120 all had to move — one is now done.**

### W3. 🔴 THE HOLE'S GROWTH RATE IS SET BY THE FRAME RATE
`[READ]` capture, `merge_stars` and `seed_apply` run ONCE per frame while the sim advances N× per frame under substeps, and `0.0165 × fps` sim-seconds per wall-second under warp. `[MEASURED n=3 seeds]` at matched sim time the frozen build reached **0.25×** the reference `Mmax`; unfreezing the force pipeline gave **0.99×**. See `BOARD.md` §X1.

### W4. 🚨 STILL NOT TIME-INVARIANT — the real BH task
Warp 16 reaches ~10k where warp 1 reaches ~95k at equal sim time — **~9× short.** Root is `BOARD.md` §X0 (`dt = 0.0165 × timeWarp`, one step per frame, no accumulator). ⭐ **His question for next session: how does true physics enable a 1:1-scale Kerr hole, and fix mergers + BH–BH mergers?** The honest answer starts here: until a wall-clock accumulator makes warp mean *more steps*, no merger dynamics measured under warp means anything — and `[READ]` the near-field is still sub-cell (horizon 0.1717, photon sphere 0.2576, ISCO 0.5151 all inside ONE softening length of 1.0), so a 1:1 Kerr hole has no resolution to live in yet. See `space_synth_a_body_has_no_radius_2026-08-29`.

---

## V. 🕳️ SESSION 2026-08-28/29 — M RE-KEYED, THE DRAIN LOCATED, WARP NAMED AS THE BUG

**Read at `68ee28c` + this session's uncommitted work. Every row tagged.**

### V1. The drawn hole no longer keys off the blind radial profile — SHIPPED, UNJUDGED
`renderer.mm` +38. `bhSeedMassMono` (running max of the biggest body while a seed-class body
survives, 0 when none does) replaces the windowed profile as the source of `lastHorizonR`.
The profile is still computed and still logged; `[HORIZON]` now prints both.
- `[MEASURED n=233]` profile blinked to 0 on **13**; drawn on **2**, both pre-seed. The vanish
  reproduced live and the fix absorbed it.
- `[MEASURED n=137]` **BUT: hole present 57% (was 7%) while size fell to 0.018 of the profile
  (n=10 both-nonzero).** ⚠️ **The fix TRADES SIZE FOR PERSISTENCE.** The earlier "0.627" was one
  mature run and does NOT generalise; the brain relayed it as if it did.
- `[MEASURED n=58]` the profile can only return multiples of **0.0195** (`RADIAL_MAX_R 5.0/256`),
  11 distinct values in 58 samples. **That staircase is why the ×0.03 easing was added 2026-07-19.
  A seed-derived radius is continuous — gone at the source.**

### V2. 🚨 RETRACTED — `gMaxMass` NON-MONOTONICITY IS HIS FEATURE, NOT A BUG
`[READ particles.metal:786-807]` A revived corpse returns at `imfMassOfId(id)` — its **exact**
spawn mass — **withdrawn from the hole** via the `seedAccum[6]` ledger. The comment:
*"gMaxMass becomes NON-MONOTONE for the first time — the only way the hole can shrink under
play… Explicit call by Jamal, 2026-08-04: reversibility wins."*
- `[MEASURED n=19]` **15 of 19 significant `Mmax` drops are at `phase=3.0`** (sustain).
- `[HIS WORDS 2026-08-29]` *"the reverisbitliy through lay is mandatory a feuature nto abug"*.
- ⛔ **CONSEQUENCE: the `max()` latch in V1 SUPPRESSES the shrink he asked for** — raw seed
  dropped **10×**, latched **2×**; 8 of his own note-driven shrinks were hidden.
  ⭐ **STANDING RECOMMENDATION (BH window, against its own change): delete the `max()`, keep the
  seed keying.** The vanish came from the profile window, not the seed. **Not yet ruled on.**
- 🪶 **NEW TRAP: a comment can be honest and still wrong because the DESIGN moved under it.**
  `renderer.mm:209` and the 2026-06-13 note at `:3313` both say *"conserved, monotonic"* and both
  PRE-DATE his 08-04 call. **Check a comment's DATE against later design decisions.**
  ⛔ And [[space_synth_bh_reversibility_2026-08-07]] already recorded this — **the brain
  dispatched "key it off the MONOTONIC seed" without reading its own index.**

### V3. 🚨 TIME WARP IS A SOLVED PROBLEM BEHIND THE WRONG CONTROL — his top physics bug
`[HIS WORDS 2026-08-29]` *"its ampfliefied when i advanc time or uppen the x4 x8 x16. then the
bh dies and evaporates even if i dont play… the only thing its uspposed to do is play it faster."*
- `[READ main.cpp:2697]` `float simDt = 0.0165f * timeWarp;` then **ONE** `computeStep`. At ×64
  the step is **1.056 in a single step** — a different integration, not faster physics.
- `[READ main.cpp:2691]` the code admits it: *"Above ~8× the Verlet integrator coarsens… honest
  tradeoff for review speed."* **Written as a review tool; he uses it as a performance control.**
- ⭐ `[READ app_state.h:73]` **`uiPhysicsSubsteps` IS the fixed-dt accumulator, already built,
  already stable, already a slider (`main.cpp:1474`, 1..32):** *"each step is the stable
  dt=0.0165, so it does NOT detonate like dt×64 (which just scales the step past the stability
  limit → the field explodes into dots). **Leave time-warp at ×1 and dial THIS for speed.**"*
- ⛔ `[READ renderer.mm:3064]` `nSub` is the **FULL** physics loop. The cheap central-gravity
  substep was tried, **EXPLODED**, and was replaced. (Brain had this backwards.)
- ⚠️ **DO NOT NAIVELY WIRE warp → substeps.** Same comment: *"rate-based effects (drain/recycle)
  currently run per-substep = N× per frame."* **The rebirth withdrawal is rate-based** — wired
  naively the hole still evaporates, for a new reason.
- ⭐ **TWO DISTINCT MASS-LOSS BUGS — stop conflating:** *with play* = the withdrawal (his
  feature); *with warp, no play* = integrator blow-up. **No withdrawal fires when he is not
  playing**, so the phase-3.0 evidence says nothing about the second.
- 📋 **BLOCKED ON HIM: the substep sweep** — set the slider to 1/2/4/8/16, read `[PERF] fps`.
  No code. `[MEASURED n=209]` whole-frame at ×1/2M: **median 61.7 fps, range 23.7–120.0** — that
  is frame, not step, so it does NOT give ms/step. ⭐ It also IS the proof: **substeps ×16 at warp
  ×1 is the correct physics at 16× speed.** Survives there + dies at warp ×16 ⇒ diagnosed.
- ⚠️ **"ZERO mergers, ever" and "never test above 1×" were SYMPTOMS of this.** Retest after.

### V4. THE NEAR FIELD IS DECIDED BY MESH CONSTANTS, NOT PHYSICS — the "toilet drain"
`[HIS WORDS 2026-08-28]` *"our black hoel is still a toilet drain. stuff behvaes differntly near
a balckhole i want this executed just as well as kill the tube."*
`[READ]` every characteristic radius is smaller than the smoothing length:

| | sim | in r_h |
|---|---|---|
| r_h (measured) | 0.1717 | 1.00 |
| photon sphere | 0.2576 | 1.5 |
| ISCO | 0.5151 | 3.0 |
| **softening ε = cellSize** (`:1803`) | **1.0000** | **5.82** |
| **capture clamp 1.4×cellSize** (`:1429`) | **1.4000** | **8.15** |

- `[READ particles.metal:1429]` `rt2 = min(rt2, reach*reach)` — the tidal radius is computed
  honestly one line above from mass and relative velocity, **then thrown away.** At cellSize 1.0
  the hole's reach is **1.4 sim regardless of mass.** ⭐ Fake in exactly the way the lens was.
- ⚠️ **Deleting it alone plateaus at 2.00–3.46 sim** — the capture scan is 3×3×3
  (`:1378-1381`), which bounds separation independently. **Clamp + scan width must move together.
  Do NOT predict "reach scales with mass".**
- `[READ :3812]` `cellSeedMap[cell] = tid + 1u` — **one seed per cell, no atomic, last writer
  wins.** With 11 seeds live, two in a cell means one is invisible to capture AND merge.
- `[READ :3807]` rejection is **per-axis**, so the seed-map domain is a **CUBE of half-side 64**
  while `[GRAV] maxR=100.0`. Matter sits outside the faces.
- `[MEASURED]` `[CELLPROBE]` at rest: `matterInCapped=86.1% scanCanSee=14.9%`,
  `matterOver32=88.5% ghostReads=74.2%`, `maxCell=234890` vs `meanOccCell=15.7`.

### V5. THE SEED MECHANISM HAS NO REPRESENTATION ACROSS SCALE
`[HIS WORDS 2026-08-29]` *"the entire seed mechanism is kinda broken size and mass and color has
no rperesantation there scaled up form single merger to a black hole itself. our rules for
gravity and all dont chnage accordingly as required to get both right."*
- `[READ render.metal:2110]` past `M ≥ 50` the branch sets `out.color = blackbodyRGB(20000 + …)`
  and `out.luminance = 10 + …` — **neither depends on mass.** A 50 M☉ seed and a 101,800 M☉ body
  are the same colour and brightness.
- **Crossing 50 M☉: luminance 1000 → 10 (100× DROP).** Kelvin cliff is 40,000 → 20,000
  (`unifiedKelvin` clamps at 40,000, `:492`) — **not** the uncapped 49,626 the brain first gave.
- ⭐ `[READ render.metal:488]` `float M = clamp(massMsun, 0.08f, 500.0f)` — **mass is clamped to
  500 M☉ BEFORE the kelvin law**, so colour is already saturated above 500 on the STAR path too.
  His complaint is true on **both** sides of the threshold.
- The branch is gated `cam.horizonR <= 0.0f` — it **stops entirely** once a horizon exists: a
  third regime with no continuity. `M_BH_SEED` appears **24×** in `particles.metal` as a hard
  `>=`, gating physics and rendering alike, with no ramp anywhere.
- ⭐ **ROOT CAUSE (BH window): a body has a MASS but no RADIUS.** Every law needing one substitutes
  a mass formula or a mesh constant — which is *why* the gravity rules cannot follow the body.
- **Design: `docs/SEED_CONTINUUM_DESIGN_2026-08-29.md`.** Compactness `χ = r_s(M)/R`;
  `R_vis = mix(R, r_s, χ)`, `K = K_star·sqrt(1−χ)`, `L = L_star·(1−χ)²`. At χ≈1e-5 the star laws
  are recovered to float precision. **On R∝M^0.8, χ goes 4.2e-6 → 4.2e-5 from 1 to 100,000 M☉ —
  a body never becomes compact by getting heavier, only by collapsing.**
- ⛔ **BLOCKER, his call: there is NO spare component in `Particle`.** `[READ particles.metal:16-22]`
  the `entanglement` comment says *"y: pad1, z: pad2, w: pad3"* and **all three carry live data** —
  `.y` = original id (`spatial_hash.metal:366`), `.z`/`.w` = theta/aphi as bitcast floats
  (`:1163-1164`) AND bond origin ids (`:2922`, `:2956`). Carrying `R` needs a **wider struct**.
  ⚠️ `.z`/`.w` double-duty float/uint is a possible aliasing bug — noted, NOT this job.

### V6. VISUAL SPEC — the references agree; `docs/blackhole-library/04_HOW_THE_REFERENCES_DO_IT.md`
`[HIS WORDS 2026-08-29]` *"how does nasa do it ? how did ineterstellar do it ? dont guess research
our references there sltitle room for interpretation."* **He was right — they agree.**
Backward per-pixel null geodesics; the ray **terminates on the emitter**, never a fog integral;
disk over AND under; higher-order images stack on the shadow edge; ONE net `g`; `I_ν ∝ ν³`;
shadow at `b_c = 3√3/2 = 2.598 r_s`.
- ⭐ **R5/R6/R2 are ONE mechanism indexed by winding number**, not three features.
- ⭐ **On DISK STRUCTURE, NASA is the reference and Interstellar is not** — NASA renders knots
  shearing into lanes from real velocity shear; the film's disk is a **static artist's texture at
  uniform 4500 K, not even accreting.** We are particles with real shear: natively closer to NASA.
- 🚨 **The EHT ring is NOT the photon ring** — it is lensed near-horizon emission near it
  (M87\*: 42±3 μas). Our own `BH_REFERENCE.md` R2 conflates them. **n=1 reachable at 4K; n=2
  needs ~535× finer — say "n=1 only" aloud.**
- 🚨 **WE RUN A SPINNING DISK ON A NON-SPINNING SPACETIME.** `[READ render.metal:308]`
  `KERR_A = 0.5f`, used **only** at `:1409` in `Ω(r)=1/(r^1.5+a)`; the shadow uses
  `kLensBc = 2.5980762` (`:337`, `:990`) = the **Schwarzschild** capture parameter.
  **Kinematics a=0.5, geometry a=0, Gargantua a=0.999 — three spins in one renderer.**
  ⛔ Gargantua's D-shaped shadow is frame dragging: **unreachable without Kerr in the METRIC.**
  (CAMERA reported "no Kerr `a` anywhere" — a grep miss, corrected by brain.)
- ⭐ **THE REAL OPEN PROBLEM:** every reference terminates rays on an **analytic** surface. His
  direction terminates them on **real particles.** **Nobody has solved ray-vs-particle-cloud
  because nobody else had the particles.** Everything around it is settled.
- ⚠️ **A8, never respected: caustics MUST be filtered or oversampled.** DNGR spent ray bundles,
  NASA 500 billion photons — **neither shipped one unfiltered ray per pixel, which is exactly what
  GARGANTY did.** ⛔ FPS rejection of the raytracer **stands**; rebuild nothing. But *"impossible
  because of polar caustics"* is not a correct sentence — that needed Kerr caustics AND an
  infinitely thin disk AND unfiltered single rays. Our emitters have finite extent.

### V7. Seeds / mergers / BH — the state he asked for `[MEASURED n=191]`
seeds form up to **11**; capture fires in bursts (0 most samples, peak **638 meals, 204/frame**);
seed–seed merges **20 landed, 0 refused**; `Mmax` 0 → **101,800**. ⛔ **"ZERO mergers, ever" is
REFUTED.** But the trajectory is `100,552 → 101,800 → 13,457 → 50 (seeds=0)` and it **cycles** —
peak varies **6×** across three runs of the same build (47,259 / 101,800 / 303,137).
`[HIS WORDS]` *"the way that the mergers behave is broken."* **Queued behind V3** — warp corrupts
merge rates, so measuring mergers first measures the wrong thing.

## U. 🔪 SESSION 2026-08-27 — BOTH RENDERERS DELETED, AND THE HOLE'S REAL BUG FOUND

> **HIS ORDERS, verbatim:** *"a black hole is not a lense. i want u to kill the lense like u killed the tube. FUCK THE LENSE. this enitre approach is ass."* · *"the march as it is rn is dead too delete it all of it to never retun its the oranghe blob itsnot what we want."* · *"collapse to one tree . commit."* `[HIS WORDS 2026-08-27]`

**U1. THE LENS IS DELETED.** ~320 lines from `particle_vertex`: the bit8 gate, the angle-space solve `β = θ − α(θ)·D` with its Newton iteration on the LUT, the second instance and `imageWeight`, the hole-centred screen fallback, `lensRamp`, `preLensNDC`. `instanceCount` 2 → 1. Commit `00741f2`. `[HIS WORDS]`
  ⭐ **The shadow SURVIVED and got stronger.** The straight-line photon-capture cull was gated `!lensWillImage`; with the lens gone it applies to every ray again, at the exact `b_c = 2.5980762 r_s`. **The shadow never depended on the lens.** `[READ render.metal:~1029]`

**U2. THE RAY-MARCH IS DELETED.** ~410 lines: `bhmarch_fragment` in full, its pipeline, its encode block, bit19, and all three dials (`uiRayEmitLog` / `uiRayBcull` / `uiRayInnerR` gone from `app_state.h`, `main.cpp`, `renderer.h`). `[HIS WORDS]`
  ⭐ **The defect was NOT the geodesics** — backward geodesic integration is exactly what NASA does. It was **what it gathered**: emission summed from a 128³ density grid, NEAREST-sampled, no temperature of its own. A fog integral over a box can only ever be a soft blob.
  ⭐ **KEPT ON PURPOSE:** `bhmarch_vertex`, `BHMarchOut`, `BHMarchUniforms`, `bhMarchUniformBuffer` all still serve **`bhbody_fragment`** — the depth-only capture sphere he PASSED 2026-08-14. Do not clean them up as march residue. `[READ]`

**U3. 🚨 THE HORIZON DETECTOR IS BLIND BEYOND r = 5.0 SIM — THIS IS "THE HOLE VANISHES INSTANTLY".**
  `particles.metal:405` `RADIAL_MAX_R = 5.0f`; `:4271` hard-clips `if (encDist < RADIAL_MAX_R)`. Matter outside is **not counted at all**. `renderer.mm:3213-3228` then walks 256 shells for the largest r with `r_s(M(<r))/r ≥ 1.0` — **binary, no hysteresis**. The frame the enclosed profile fails, `lastHorizonR` is **exactly 0**. `[READ particles.metal:405]`
```
run2:  Mmax = 34,280 M☉  seeds=16  Menc=4,827    ->  horizonR raw = 0.0000
run5:  Mmax = 16,325 M☉  seeds=4   Menc=157,550  ->  horizonR raw = 0.2344
```
  `[MEASURED n=4 runs]` A seed of **34,280 M☉ with the drawn horizon at exactly zero**; the run with LESS seed mass but 33× more mass inside the window HAD a horizon. It is not mass and not rest-vs-play — **it is whether the mass is inside the 5.0 window.**
  ⇒ ***"it goes straight to the shapes"* and *"it vanishes instantly"* are ONE event, not two.** Closes §T8's question.

**U4. THREE "MASS OF THE HOLE" NUMBERS, AND THE ONE THAT DRAWS IT IS THE FLIMSIEST.** `[READ]`
  - `bhSeedMass` — monotonic, *"the seed IS the black hole"* → drives `bhStrength` + shadow radius
  - `totalSeedM` — accumulated `renderer.mm:3198`, consumed ONLY by the printf at `:3441` → **drives nothing**
  - `lastHorizonR` — from the radial profile → **`cam.horizonR`, the gate every BH consumer keys off**
  ⭐ **`renderer.mm:3314` already prescribes the fix, in its own words:** *"basing the hole on it made the hole 'form then vanish'. The seed IS the black hole; r_s(M_seed) is its real horizon, monotonic → the hole forms and STAYS."* **The seed path was built. The gate still uses the profile.** No-hair says a hole has ONE M; ours has one number and two decorations.
  ⏳ **THE FIX IS WRITTEN UP AND AWAITING HIS GO:** key the drawn hole off the monotonic seed mass.

**U5. ⭐ THE PATTERN — THREE CONSTANTS FROZEN AT THE COLLAPSED-BALL ERA.** All were true when the field measured `meanR 3.92, maxR 4.4`; it now measures **meanR 12→71**. `[MEASURED]`
  | constant | consequence |
  |---|---|
  | `RADIAL_MAX_R = 5.0` | the hole "vanishes" (U3) |
  | march `dl = step·r^1.5` at `rMarchStart` 430–750 | rays flew **past** the photon sphere — 12 steps, `rmin` 16.05 r_s, turn 0.997π |
  | `halfExtent = 64` | `maxR` pins against it at the 100 cap |
  🚨 **Killing the tube did not break these — it removed the cylinder that kept the field small enough for them to be true.** ⇒ §T2 inflation is the ROOT, reaching a third board.

**U6. ↩️ CORRECTIONS TO THIS BOARD, all verified in source or by running the tool.**
  - ⛔ **L9 IS REFUTED.** `tools/bc_validate.cpp` **EXISTS AND RUNS** — the row searched `src/` and concluded it "never existed". Method A reproduces `b_c` to **8.2e-15**.
  - ⛔ **"step 0.10 BREAKS, b_c collapses to 0.5" IS A CONFLATION.** Measured: 0.10 → `b_c = 2.60103` (rel err 1.2e-3). The 0.5 collapse is the **half-COEFFICIENT** config, a different row.
  - ⛔ **§1b is 10 days stale** — it says the march is default OFF and "can only ever be orange". It was default **ON** since 2026-08-17 with a blackbody law. Moot now (deleted), but the row misled a whole session.
  - ⛔ **bCull was NOT a raw 7.0** — `bDerived = (meanR/rsSim)·(dial/7.0)`, a multiplier on a derived extent ≈ 213 r_s. The `app_state.h:74` comment describes pre-derivation semantics.

**U7. 📚 `docs/blackhole-library/` OPENED — his order.** *"research everything there is to know… anything we know as a species about bhs… create a dedicated folder within docs that is our personal library."* README (board) + `01_FORMATION` + `02_LIGHT` + `03_THE_REFERENCE_FRAMES`. The two NASA frames stay primary; **Gargantua added via the DNGR paper, with the trap stated — the film turned Doppler asymmetry OFF, so Fig. 15c is the reference, not the movie frame.**

**U8. ⭐ HIS CHOSEN ARCHITECTURE — per-pixel backward geodesics that TERMINATE ON THE REAL PARTICLES.**
  Each pixel's ray integrates backward; when it enters occupied space it **resolves against the particles there** and takes their emission and their `g`, then stops. Captured (`r < r_s`) → black by absence.
  🚨 **The distinction that makes this legal and not a re-run of the march:** the march **averaged a grid along a line**; this **terminates on the same matter the sprites draw.** Same entity, per-pixel state — which is what NO SECOND LAYER actually means (his clarification 2026-08-26).
  ⛔ **BLOCKED BY U4.** A tracer keyed to `lastHorizonR` inherits the one-frame cut. **Fix M first.**

---

## M. THE MARCH SESSION — 2026-08-17/18 (bit19)

**His standing call on the look, 2026-08-17:** *"a mix between the nasa and interstellar vibe"* and *"like we ssaid nasa x interstellar stop spininign i cricles"*. Physically the two references differ in exactly ONE term: Interstellar/DNGR is isothermal at 4500 K with all colour from `g` (DNGR doc §3), NASA/Goddard is genuinely accreting so `T` falls with radius. The mix = NASA's radial structure at Interstellar's colour temperature.

### M1. ✅ CLOSED

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| **M1a** | **The march extent was a CONSTANT in r_s while r_s AND the field move independently.** So the marched region tracked the shrinking hole and lost the disc. | `bCull = 7.0` (dial), `rMarchStart = 60.0` hardcoded | `bCull = meanR/r_s`, `rMarchStart = maxR/r_s`, both from the reduce the `[GRAV]` line already prints. Dial kept as a multiplier (old default 7.0 ≡ 1.0×). | `renderer.mm` (grep `bDerived`), `renderer.mm` `measuredMaxR` | `[MEASURED n=210]` probe lines, one run: adapted **4.87 → 198.19** as r_s went 0.059→0.840. Identity `bCull × r_s = meanR` holds by construction. |
| **M1b** | **The scale of the miss, measured.** | meanR 43.91 sim, maxR 100.0, r_s 0.2344 ⟹ field mean = **187 r_s**, bCull sat at **7** | march covered **3.7%** of the disc radius; slider max (40) could only reach **21%** — *no dial setting could ever show the disc* | `app_state.h:65` predicted this verbatim | `[MEASURED n=3]` `[MARCH]`+`[GRAV]` 2026-08-17 17:43 |
| **M1c** | **Hardcoded orange — the reason he banned bit19 on 2026-07-28.** | `float3(1.0f, 0.55f, 0.25f)`, no temperature input | `blackbodyRGB(g·T(r))`, `T(r) = 6500 K·(r/r_in)^(−3/4)·[1−√(r_in/r)]^(1/4)/f_peak`, `r_in` = ISCO = 3 r_s, anchor = DNGR's own white-balance point (doc §3). Sweep: 6500 K @4.08 r_s → 1322 K @60 r_s. | `render.metal` bhmarch_fragment (grep `T_ANCHOR_K`) | `[READ]` + `[HIS WORDS]` 2026-08-17 *"this orange shadow … must leave asap"* (07-28 09:32:18) |
| **M1d** | **No `g` at all in the march.** | emission had no Doppler and no gravitational shift | `g = 1/[u^t(1−Ω·b)]`, `u^t = 1/√(1−3M/r)`, `Ω = √(M/r³)` — **ONE factor**, exact, using the photon's conserved `b` the march already holds. Bounded by `√((1±β)/(1∓β))`, the emitter's own head-on/tail-on limits. | `render.metal` (grep `gShift`) | `[READ]` unit check: Ω·r at ISCO = **0.4082** vs `particles.metal:246` measured orbV max **0.4092c**, 0.25% |
| **M1e** | **Emission with no absorption — the brown fill.** | `emit +=`, unbounded ∫ρ ds over a 60 r_s path; the outer volume outweighs the inner disc at any gain | `dTau = dens·dl·emitScale; emit += trans·(1−e^−dTau)·col; trans *= …`. **No new constant** — in LTE the source function IS the Planck function, so the same κρ ds is both (Kirchhoff). Saturates at B(T); an unbounded fill is now structurally impossible. | `render.metal` (grep `dTau`) | `[HIS WORDS]` 2026-08-17 16:26 *"the emission is this bs"* → cause identified as missing extinction, not gain |
| **M1f** | **Phase Viz dead in the star map** (board item 4, and the handoff's guess had the polarity backwards). | — | `render.metal:2282` `out.color = mix(out.color, starColor, starMix)` with `starMix = 1−smoothstep(0,0.5,envelopePhase)` = **1 at silence**, and it never checks `cam.phaseViz`. Phase Viz writes at `:1743` and is overwritten 540 lines later. Chladni: starMix=0 → survives. Near hole: `:1898` drives starMix→0 → survives. | `render.metal:1743`, `:1866`, `:1898`, `:2282` | `[READ]` all four sites, live callers |

### M2. 🚨 OPEN

0. 🚨 **BH2 — TWO Ω LAWS FOR ONE DISC, STILL LIVE.** Sprite Doppler uses `Ω = 1/(r^1.5 + KERR_A)` on the
   CYLINDRICAL radius about a hardcoded global **+Z** (`render.metal:1610`, `:1611` — both still flagged by
   preflight §5 on 2026-08-20 18:27:12); the march uses `√(M/r³)` about `poseAxis` (`:3716`, `:3721`).
   ⚠️ **A fix was written and REVERTED on 2026-08-20 14:22:25 — and it was never rejected on its merits.** I
   read *"it looks so fucking bad"* as a verdict on the change; his next message was *"no apart from what u just
   did it just looks really bad as per picture"*, i.e. the picture was already bad and the change was not the
   subject. **Re-applying is cheap; nothing about it was disproven.**
   `MEASURE:` the one prediction it carries — β at the disc goes from ≈ r/(r^1.5+0.5) to √(r_s/2r), about a
   **3× drop** at meanR ≈ 44 sim with r_s ≈ 0.23, so the approaching-limb glow gets weaker before it gets right.

1. **[HIS WORDS] 2026-08-18** *"dtill the same in every way lol"* — **the emission law (M1c/M1d/M1e) is still UNTESTED.** It has never run in the regime where it can be seen. Every state in the 210-line probe run was a **collapsed ball** (meanR 4.6–11.6 sim, r_s up to 0.84), where the derived extent reproduces ~7 — the old constant — so the picture was necessarily identical.
   `MEASURE:` get the field to the **expanded disc** state (meanR ≈ 44 sim, r_s ≈ 0.23 — his 2026-08-17 17:39 screenshot), then read `[MARCH] bCull` ≥ ~150 and look at the marched region.
2. **[MEASURED n=776] fps median 39.9** (min 14.1, max 108.5) with the derived extent live — **unchanged** from the 40 fps he reported before it. The predicted cost blowup did not occur; see §M3.
3. **[HIS WORDS] 2026-08-17** *"theres a weird smear when i move cam … like uhrzeiger straight lines that create blurr"*, and *"it didnt matter it was in oth mods"*. **Candidate (b) is DEAD** — the pose clock is pause-gated in the emergent branch (`renderer.mm` `emergentPoseDt`, returns 0.0 when `paused && !holdTimelapse`) but NOT in the posed branch, so a mechanism gated off in one mode cannot smear in both. Leaves **(a) postfx frame-feedback** and **(c) the `spinAngle*tDilate` shear**. `MEASURE:` A/B one against the other behind an env bit.
4. **[HIS WORDS] 2026-08-17** *"i think its how now thousand s fo stars creat ehair thins sprites that like overlay adn create a flicker … i thinkth epixels are too small for the sim."* **Confirmed mechanism, unfixed:** `renderer.mm:3971` draws `MTLPrimitiveTypeLine`, 1.5M × 22 verts. A Metal line is exactly **one device pixel**, binary coverage, and `sampleCount` has **zero hits** in `src/render/` — no MSAA anywhere. Sub-pixel marks at sub-pixel positions under additive blend scintillate on camera motion. DNGR's answer (doc §6): the sample has an **elliptical footprint** and the source is **mip-filtered at that footprint** — *"no flicker/aliasing and no supersampling"*. Ours has neither.
   ⭐ Also a conservation gap: a line has no width, so a ribbon that should be a tenth of a pixel thick deposits the same energy as a full-pixel one. Same class as the S7 missing-luminosity term.
5. **[HIS WORDS] 2026-08-18** *"when i hold space the neitre thing runs at 120 fpps"* — **the arc pass is NOT the fps bottleneck.** Same 33M line-verts draw while paused. Board item 1 blames the line-vertex count; this measurement contradicts it. The compute is the cost.
6. **The 128³ box-average objection is UNADDRESSED** (`app_state.h:57`): the march samples NEAREST (`render.metal` grep `int3(round(`) from a 128³ grid while the sprites draw at sub-pixel precision, and the two are additively overlaid. Trilinear was tried and pulled 2026-07-26.
7. **The RIAF fork, still his.** `particles.metal:245` measures **h/r = 0.746** at two independent radii agreeing to 3% — a thick RIAF at ~4e10 K, which emits in X-ray and has **no true RGB**. M1c is therefore a **DECLARED TRANSFER** (physical shape, cited anchor), not a claim about our gas. The real question — *cool the gas so h/r drops and the thin disc becomes true rather than represented* — is untouched.

### M3. ⛔ DEAD ROADS

- **Raising the emission gain to make the pass visible — 2026-08-17 16:02:41 → reverted 16:29:05.** −7.5→−6.0 produced a screen-filling brown blob; his verdict *"the emission is this bs why are u even turning it on that was not what we're on"*. The gain was never the problem: `emit +=` had no extinction (M1e). Lowering it hides the fill, it does not fix it. **Brightness is his** (2026-08-14 12:26). The gain sits at −6.0 again only because the transfer now bounds it and at −7.5 the transfer is a numerical no-op (`dTau ≈ 3e-8`).
- **Reading the marched region's size off a screenshot — twice, both directions.** Its apparent size is `bCull × r_s` against the camera zoom. At 16:26 (zoomed in) the same 1.6-sim region filled the frame; at 17:39 (wide) it was a dot. **Read it off `[MARCH]`, never off the image.**

**Source of record for the physics:** `docs/RESEARCH_2026-07-24_interstellar_dngr.md` — the DNGR extraction (James, von Tunzelmann, Franklin & Thorne, CQG 32 (2015) 065001 = arXiv:1502.03808v2). Section numbers below in the form *(DNGR §7.1)* refer to that doc.

---

## 0. THE TARGET, DECOMPOSED — what "the time / space mindfuck look" is actually made of

The Gargantua look is not one effect. It is **five** separable features, and they fail independently. Naming them is what makes this trackable.

| # | Feature | What it looks like | What produces it |
|---|---|---|---|
| **S1** | **The shadow** | A hard black disc at **b_c = 2.598 r_s**, edge crisp, ~2.6× the horizon | Ray fate: photons with b < b_c spiral in *(DNGR §5)* |
| **S2** | **The wrap** | The far side of the disk bent **over the top and under the bottom** of the shadow — the signature horseshoe | Secondary images: rays making ~½–1 loop *(DNGR §4, §5)* |
| **S3** | **The photon ring** | An infinite stack of exponentially thinner, fainter rings **hugging the shadow edge** | n ≥ 2 windings near the photon sphere r = 1.5 r_s *(DNGR §4)* |
| **T1** | **Doppler beaming** | One side **blazing**, the other nearly gone | g³ specific-intensity transform on the disk's orbital velocity *(DNGR §3, §5)*. Intensity only — the **colour** half is vetoed, see §1c |
| **T2** | **Time dilation shear** | The inner disk **winds and nearly freezes** relative to the outer | dτ/dt = √(1 − 1.5 r_s/r); inner clocks run slow |

⭐ **THE KEY STRATEGIC FACT: WE ALREADY HAVE THE "TIME" HALF. THE GAP IS THE "SPACE" HALF.**
**T2 is built, live, and he loves it** — it is his *"time warp traces… beautiful time warpeyssss"* (2026-07-26 21:00). `render.metal:782-784`: `tDilate = sqrt(max(0.4, 1 − BH_R_IN_SIM/r))` applied per-particle to the spin angle, making the view rotation a **radius-dependent shear**. 🚨 **It was removed once as a "correctness fix" and killed the effect on sight (9-minute regression, 2026-07-26 20:58 → 21:06:52). NEVER remove it.**
**T1, S1, S2, S3 are all partial or absent.** That is the whole job.

> ⚠️ **Nolan's cheat, and our deliberate departure** *(DNGR §3, "Movie cheat")*: the film **turned OFF** the g³ Doppler asymmetry because the true lopsidedness was *"too confusing for a mass audience"*, and slowed spin to a/M = 0.6. **Their Fig. 15c is what the disk truly looks like. We want the true version.** So our reference is *not* the movie frame — it is Fig. 15c. This matters: if we ever match the movie exactly, we did it wrong.

---

## 1. WHAT WE ACTUALLY HAVE — verified inventory

### 1a. ✅ REAL, LIVE, AND PHYSICAL

| Thing | Where | Status |
|---|---|---|
| **Exact Schwarzschild deflection LUT** — α(b) = 2∫₀^{u₀} du/√(1/b² − u²(1−u)) − π, 256 entries, log-spaced b/r_s ∈ [2.60, 200], turning point by Newton, endpoint singularity killed by u = u₀(1−t²), 1024-point midpoint quadrature | `renderer.mm:799-836` | **Real.** Genuinely log-divergent at the photon sphere. |
| **Angle-space thin-lens solve** β = θ − α(θ)·D, weak-field seed + 3 Newton steps on the LUT, each particle's **true depth D** behind the hole, re-projected through `viewProjection` | `render.metal:970-1046` | **Real.** Moves particles, not pixels. |
| **A genuine second image** — instance 1 solves the opposite root, dimmed by real relative magnification | `render.metal:1043-1062`, instanced at `renderer.mm:3643` | **Real, and parity-flipped** — see §2. |
| **T2 dilation shear** | `render.metal:782-784` | **Real, live, his favourite thing.** |
| **Horizon-interior cull** — matter inside r_h emits nothing | `render.metal:821-838` | Real. Reach = **1.0 r_s only.** |
| **Photon-capture cull** at the exact b_c = 2.5980762 r_s | `render.metal:840-874` | Real but **gated off whenever the lens is on** (`!lensWillImage`, `:857`) = off by default. |
| **Capture test on the IMAGE** (2026-08-14, this session) | `render.metal:1019` | **SHIPPED, UNVERIFIED — his verdict pending.** See §4. |
| **Emergent horizon r_h** from the honest mass profile, eased for render (~0.7 s e-fold), raw value kept for physics | `renderer.mm:1608-1616`; raw at `cam.horizonRRaw` | Real. Two values on purpose — **use raw for physics facts, smooth for drawn size.** |

### 1b. 🌑 BUILT, CORRECT, AND SWITCHED OFF — the geodesic ray-march

**`bhmarch_fragment`, `render.metal:2951-3140+`, pipeline built at `renderer.mm:3924`, gated on bit19.**
This is a real implementation of DNGR §7: unprojects each pixel to a world ray (ortho *and* perspective, `:2971-2974`), culls by impact parameter (`:2980`), back-extends to r = 60 r_s, **marches in units of r_s so the step rule is scale-free** (`:2989-2992`), integrates with `dl = stepScale·r^1.5` (`:3005`), **breaks on `r < 1.0` = captured = shadow by absence** (`:3002`), and gathers emission from the **real particle field** via the CIC hash grid.

**It is DEFAULT OFF** (`app_state.h:57`, `uiTogRayMarch = false`) since **2026-07-28 09:32:18**, on his order: *"this orange shadow of the blackhole is super old and must leave asap."*

**Why it was killed — both reasons are structural, not tuning:**
1. 🎨 **It can only ever be orange.** Its single colour is a hardcoded `float3(1.0f, 0.55f, 0.25f)` scaled by density (`render.metal:3129`). **There is no temperature input and no temperature grid exists anywhere in the renderer.** It physically cannot be anything but orange at some brightness.
2. 🧱 **It can never carry Chladni structure.** Its output is a box-average of a **128³ density grid**; the sprites draw **2M+ bodies at sub-pixel precision**. Two pictures of one disk ~100× apart in resolution, **additively overlaid** — that is his *"it doesn't connect to the rings"*.
   ⭐ **The 2026-07-26 21:20 A/B settled it: lens bit8 ON, march OFF → *"ITS FINALLY THE CORRECT FEEL"*.**

🚨 **DO NOT re-pitch the march as the hole's renderer.** See [[space_synth_lens_is_the_hero_2026-07-26]]. **It is still the only thing in the codebase that can produce S3 (the photon ring) and true multi-loop S2.** That tension is the central design problem of this board — §5.

### 1c. ❌ ABSENT

- ⚠️ **T1 was listed here as ABSENT on the first draft of this board. THAT WAS WRONG — corrected 2026-08-14 12:01:52.** Beaming exists and always did, at `render.metal:1469+`. See §4b for what was actually wrong with it and what shipped. The **colour** half is a different matter: `dopplerColor` was deleted 2026-08-11 (declared, assigned, never read), and `:1467` records that **Doppler-as-hue was removed 2026-06-26 on his verdict — do NOT re-propose it.**
- **S3 photon ring.** The lens produces **exactly two images** (instances 0 and 1). n ≥ 2 windings are not representable by a two-instance sprite scheme, full stop.
- **Kerr / spin.** Everything is Schwarzschild (a = 0). No frame-dragging, no shadow flattening, no off-centre shadow. *(DNGR §1.3, §7.4 — the upgrade path is written if we ever want it.)*

---

## 2. ✅ ANSWERED — DOES OUR SECOND IMAGE SWAP HANDEDNESS?

**The test** *(DNGR §4, and his own NASA top-view panel)*: light from beneath the far side travels **>180°, so paths cross and that image arrives left-right SWAPPED.** No image-space warp can flip parity. So parity is the yes/no that decides whether the lens is real optics or decoration.

**✅ YES — IT IS REAL OPTICS.** Answered from the code 2026-08-14 01:12:00, no screen needed.

Secondary placement (`render.metal:1055`): `target = bhWorld + along·dHat − pHat·th`. Signed transverse coordinate θ_r = −th(β):
- **tangential** eigenvalue = θ_r/β = −th/β **< 0**
- **radial** eigenvalue = −dth/dβ **> 0** — from β = α(θ)·D − θ, dβ/dth = α′D − 1 < 0 since α is decreasing

**det J < 0 ⟹ negative parity ⟹ mirror-reversed.** Nobody painted it; it falls out of solving the opposite root. The Newton damping `min(da·D − 1.0f, −0.25f)` (`:1049`) clamps that denominator negative, so even the damped solve cannot lose the sign.

**⟹ The lens needed a FIX, not a replacement — and it got one. Both blend sites are CLOSED.** Bend, parity and second image were all physical; the two blend sites that were wrong were fixed on 2026-08-14 and are kept here for provenance:

- ✅ **FIXED 2026-08-14 17:30:54 — re-verified in source 2026-08-20 14:08:59, and again 2026-08-22 01:34:32.** *(Was: "the flip is incomplete below full strength" — the secondary was lerped from its UNLENSED position, giving a zero-parity ring that swept outward as the hole strengthened.)* The `mix` is gone: the second image is now placed where the lens equation puts it (`render.metal:1164`) and fades in by being FAINT, carried by `imageWeight`. The old text is preserved in the comment block at `:1141-1163`.
- ✅ **FIXED 2026-08-14 17:53:52 — re-verified in source 2026-08-20 14:08:59, and again 2026-08-22 01:34:32.** *(Was: the secondary ignored `tuneLens`, so only the bit8 toggle could kill it — the Lens Bend dial could not turn the second image off, and the fold-over arc survived at full strength wherever the dial sat.)* `imageWeight = cam.tuneLens * lensRamp * clamp((A−1)/(A+1))` at `render.metal:1184`; at `tuneLens = 0` the weight goes to 0 and `:1722` drops `pointSize` to 0 — the same outcome bit8 produces. **Multiply, not `mix`:** the second image has no unlensed brightness to fall back to, so with no lens it simply does not exist. `depthMix` is deliberately excluded — it is identically 1 there. The old text is preserved in the comment block at `:1169-1183`.
  ⚠️ `:1621` in the pre-2026-08-22 wording of this row was line drift; the live site is `:1722` (`render.metal`). This is **A0i** landing on this board's own §2 — see §N1.

> 🚨⭐ **THE CONSEQUENCE THAT OUTLIVES THE FIX — EVERY PRE-2026-08-14 SLIDER A/B IS VOID.**
> **Any lens A/B run with the Lens Bend SLIDER before 2026-08-14 17:53:52 proves nothing and must not be cited.** The dial had no effect on the second image, so "lens down" and "lens up" were photographs of the *same* fold-over arc at full strength. A null result from such a run is not evidence that the lens does nothing — it is evidence that the slider did nothing.
> **An A/B done with the bit8 TOGGLE is trustworthy; one done with the SLIDER is not.** Every lens comparison, verdict or screenshot pair on this board or in any handoff dated before that timestamp needs re-reading in that light, and re-running before it is believed.

---

## 3. 🚨 HARD LIMITS — structural, measured, or paid for in blood

| # | Limit | Evidence |
|---|---|---|
| ~~**L1**~~ | ✅ **FIXED 2026-08-20 15:36:28, UNVERIFIED — he has not looked.** The divisor is now the screen half-height **at the hole**: `frustum` in ortho (unchanged, byte for byte), `dHole * 0.414214` in perspective, where 0.414214 = tan(45°/2) and 45° is the fov `main.cpp:776` actually passes. The perspective shadow was **2.897× too small**, exactly the factor the code's own comment predicted before measurement. `dHole` is computed from the real camera and hole vectors, NOT from `cameraRho` — under the origin lock (L5) they are the same number today, and writing `cameraRho` would have baked that lock into the lens. | `renderer.mm:1661-1690` |
| **L2** | **The lens is OFF during play.** `bhLensActive = (totalAmplitude < 0.02f)`. The hole only lenses at silence. Deliberate (star-map regime) but it means **the mindfuck look is a REST-STATE look** and cannot appear while he plays. | `renderer.mm:1618` |
| **L3** | **A two-instance sprite scheme cannot produce S3.** n ≥ 2 windings need a per-pixel integrator. This is a representation ceiling, not a bug. | `renderer.mm:3643` |
| **L4** | **The march can only be orange, and can only be 128³.** Both structural — no temperature input exists, and a box-averaged grid cannot resolve sub-pixel sprites. | `render.metal:3129`; `app_state.h:57` |
| **L5** | **Origin lock: the renderer's hole centre IS the origin.** `bhPosX/Y/Z` are hard-zeroed by design (the COM is pinned at 0/0/0 and the seed sinks there); the enclosure-COM refinement sits inside `if (false)`. So every "re-centre on the hole" fix is a **NO-OP** — 4 have been logged. Making it honest is real work (A3②), not a vector swap. ⚠️ `render.metal:774-775` cites this as `renderer.mm:3293-3295`; **that citation has drifted** — the live sites are below. | `renderer.mm:3555-3557` (the zeroing), `:3193` (`if (false)` refinement) |
| **L6** | **⚠️ NEW — bit15 IS DOUBLE-BOOKED and the AMR kill-switch is broken.** bit15 = "metric shadow" in the render *and* = "AMR fine force" in the physics. `physicsUniforms.bhToggles = bhToggles \| (amrOn ? 0x8000u : 0u)` — an **OR**, which can only ADD the bit, never clear it. `uiTogMetricShadow` defaults **true**, so bit15 is always set ⟹ **`SS_NO_AMR=1` does not disable AMR while metric shadow is on.** Any AMR A/B run to date is suspect. | `renderer.mm:1897`, `particles.metal:2161`, `render.metal:821` |
| **L7** | **Perf ceiling.** Baseline idle @2M, ortho, 1×: **~31–36 fps, worst frame 50–99 ms.** ~46% of the field is corpses running the full kernel. A per-pixel march on top of this is not free. 🚨 `physicsUniforms.dt` is a fixed `0.0165×warp` step — **never derive fps from it.** | `docs/BOARD.md` rows 10⁺, 12 |
| **L8** | **Never test the hole above 1× time warp.** At 64× a star moves 127 contact-radii per frame and tunnels past every merge test. Accretion/merger results at high warp are artifacts. | [[space_synth_bh_reversibility_2026-08-07]] |
| **L9** | **`bc_validate.cpp` DOES NOT EXIST IN THE TREE and never did** — `git log --all --diff-filter=A` finds no commit that ever added it. `render.metal:2990` and `app_state.h:53` both cite it as the integrator's validation (b_c to 1.4e-6). **That validation is currently an unverifiable claim.** Re-deriving it is cheap and should be done before the march is ever trusted again. | verified 2026-08-14 |
| **L10** | **Limits are PERCEPTUAL, not technical.** His standing rule: report ceilings as the cost of the *current formulation*, never architect down to a measured number. | [[feedback_limits_are_perceptual_not_technical]] |

---

## 4. ✅ THE NASA GAP — SHIPPED AND **PASSED**

### ✅ HIS VERDICT 2026-08-14 12:13:00 — ***"i think the core is blacker tho"***. S1 accepted. Keep it.

### THE NASA GAP: our shadow was hoped-for, not guaranteed

**The skill diff in one sentence:** NASA/DNGR trace a **geodesic per PIXEL**, so the shadow is a property of **RAY FATE** — a pixel is black iff its ray ends on the horizon, and light can never appear inside b_c. **We forward-map SPRITES and hope none land there.**

**The number:** our shadow was guaranteed black only out to **r_h = 1.0 r_s**, against a true shadow of **2.598 r_s** ⟹ **1 − (1/2.598)² = 85% of the shadow AREA had no reliable mechanism.**

Three culls, each partly off: horizon-interior (`:821`, only r < r_h); straight-line capture (`:857`, **off whenever the lens is on** = default); lens floor th ≥ 2.62 rsW (`:988`), **diluted** at `:991`.

**Two leaks filled the hole:**
1. **`tuneLens` dilution** — floor bottomed out at 0.85 × 2.62 = **2.227 r_s** ⟹ drawn shadow **14% too small** with a pile-up ring at the wrong radius.
2. ⭐ **The `depthMix` slab — the big one, and the actual "blurry mess".** `depthMix = smoothstep(0, rsW, D)` (`:974`) → 0 for matter within one r_s **behind** the hole, so that slab drew **UNLENSED straight through the middle of the shadow**, down to r_h. Un-lensed, centred on the hole, against what should be pure black.
   🚨 Nothing removed it: the slab cull was deleted (`:853-856`) while the comment at `:803-805` **still claims** it *"handles the thin slab at the hole's own depth"*. There is no slab term at `:857`.

**THE FILL — one change, `render.metal:1019`.** Judge the photon by where its **IMAGE** lands, not its source:

    if (along > 0.0f && thEff < 2.5980762f * rsW) cullThis = true;

- The **SECONDARY already did exactly this** (`:1052`, culls at th ≤ 2.605 rsW). The **PRIMARY** was the one missing it. That asymmetry was the bug.
- `along > 0` so foreground matter keeps crossing the disc — the front/behind asymmetry is what reads as a 3D body (`:793`).
- The arch is untouched: floored primaries sit at ≥ 2.62 r_s, outside b_c.

**LOOK FOR:** disc black not smeared; edge crisp and **~17% wider** (2.227 → 2.598 r_s); foreground matter still crossing it.
**FAILURE MODE:** if the arch dims, floor vs capture radius are fighting (2.62 vs 2.598 = 0.8% margin) → widen the floor, not the test.
**Bundle `01:28:44` > source `01:28:37` — deploy verified. NOT COMMITTED.**

### 4b. T1 — THE HONEST BEAMING LAW. SHIPPED 2026-08-14 12:01:52, UNVERIFIED.

**Correction to this board's own first draft: beaming was never missing.** It has been in `render.metal:1469-1503` all along, driven by the **analytic** Kerr orbital velocity Ω(r) = 1/(r^1.5 + a) (`:1487`) — computed analytically on purpose so it survives at rest where `velW ≈ 0`. That part is sound and is **untouched**.

**What was wrong were the two lines that turned β_los into brightness:**

| | was | should be | why |
|---|---|---|---|
| exponent | `DOPPLER_EXP = 1.4f` (`:297`) | **3** | Liouville: I_ν ∝ ν³ *(DNGR §3, Fig. 15c caption)* |
| gain | `DOPPLER_K_BEAM = 0.8f` (`:296`) in `1 + K·β` | **no free gain** | The real Doppler factor has none. `vOrbit = Ω(r)·r` runs **0.23–0.67**, which already *is* β at c = 1 — so K was fudge on top of a correct velocity |
| dark side | `max(0.35f, …)` (`:1500`) | **no floor** | It held the receding side at 23%. DNGR: it should nearly vanish. The floor guarded a hard-clamp SEAM that a smooth g cannot produce |

**Measured contrast at β ≈ 0.55 (Gargantua's inner disk):** old law **1.69 vs 0.23 = 7.3×**. Honest law **6.4 vs 0.157 = 41×** — the true ratio is ((1+β)/(1−β))³.
⚠️ **ARITHMETIC CORRECTED 2026-08-14 12:19:20.** This row first read *"11.4 vs 0.088 = 129×"*; γ = 1.197 was dropped from both ends. The real peak is **6.4×**, i.e. **3.8× hotter than the old law's peak** — which is exactly what saturated the additive blend. See 4c.

**Shipped:** `b2 = min(|β|², 0.9801)`, `γ = rsqrt(1−b2)`, `g = 1/(γ(1−β_los))`, `luminance *= g³`. No free parameters. `DOPPLER_K_BEAM` and `DOPPLER_EXP` now compile as **unused** — the compiler confirming the old law is fully gone. (Both constants left in place; deleting them is a separate change.)

🚨 **Gravitational redshift is NOT folded in** — that is the √(1−2M/r) factor of A.16 and is a separate change.
🚨 **The colour half stays dead.** `:1467`: *Doppler-as-hue was removed 2026-06-26 on Jamal's verdict — do NOT re-propose it.* This change is intensity only.

**LOOK FOR:** one limb of the disk clearly **blazing**, the opposite limb nearly gone, sweeping smoothly as the camera orbits. **FAILURE MODE:** the bright limb whites out — g³ peaks ~11×, and the additive blend has blown past white before (2026-06-25). If it does, the fix is the tonemap/luminance scale, **not** re-introducing the fudge exponent.

### ✅ 4e. THE HOLE IS A BODY — SHIPPED AND **PASSED**. 2026-08-14 12:27:34.

> **His verdict 12:30:57 — *"the hole looks holey finally."*** First time. Keep it.

**WHAT WAS FAKE, and it was never the lens.** Nothing in this renderer drew a black hole. The hole was the region where we chose not to stamp sprites — three culls and a gap. Mechanically:
- the particle pass is ADDITIVE with depth **write off** (`renderer.mm:1077`),
- the main pass **discards** its depth (`storeAction DontCare`, `renderer.mm:3618`),
- `depthPrepassTexture` is written every frame and **sampled by nothing** — there is not one `texture2d<>` declaration in `render.metal`.

⟹ **Nothing in the scene occluded anything.** No "in front", no "behind", only sums of light. A black hole is, before it is any optics, **a thing that blocks** — ours had no existence in the scene's visibility. That is also exactly why the 2026-07-24 fullscreen paint had to be withdrawn the day it shipped: no depth, so it blacked out matter in front of it.

**THE FIX (`render.metal` `bhbody_fragment`, pipeline `renderer.mm` + encode before the particle draw):** per-pixel ray-sphere against the photon-capture surface at b_c = 2.5980762 r_s, writing **depth only** with `writeMask = MTLColorWriteMaskNone`. It paints nothing; it removes light by being in the way — the literal reading of "SHADOW = ABSENCE, NEVER PAINT". The particle pass **already** depth-tested (`MTLCompareFunctionLess`, `:1074`) and had simply never had anything to test against, so this turns existing machinery on rather than adding a layer. The wrap survives: lensed images land at ≥2.62 r_s, outside the silhouette.

⚠️ **`bgDepthState` is created and never used** — no `CompareFunctionAlways` pass exists to punch through this.

### ⭐✅ 4f. SPAGHETTIFIED LIGHT — SHIPPED 2026-08-14 12:37:53. **HIS REACTION: *"WAIT what is that. that looks crazy."***

> His order 12:36: *"its just stars, u see it like streuselkuchen, viele kleine dotties. no time stretched lines of light bro LETS SPAGHETTIFI THE LIGHT"*

**THE CODE TO DO THIS HAS BEEN IN THE REPO SINCE JUNE. It was never the wrong idea — it had a plane bug.**

`trajectory_vertex` (`render.metal:2701`) draws each particle's **real orbital arc over an exposure window**: `totalPhi = min(Ω(r)·exposure + spin·0.05, tuneArcWrap)`, `Ω = 1/(r^0.9 + KERR_A)` (inner-fast), with `horizonExp = bhStrength·exp(−r·0.8)` so the exposure grows exponentially near the hole. **The arc LENGTH is the speed** — that is time-stretched light earned by the physics, not a screen-space smear.

**⛔ It was stripped 2026-06-25** as *"fake trails centered to a tube shape… NOT the particles' real paths."* **That verdict was earned by a BUG, not by the concept:** `:2767` swept the arc about **+Y** (`posW.xz`) while the disk orbits **+Z**. Every ribbon ran **90° ACROSS the real motion** — which is exactly what "a tube painted over the field" looks like. **Same class of fault as PLANE FIX №2 in the Doppler block** (`:1477`: *"the 90°-off tangent made vLos noise → azimuthally UNIFORM ring… fake overlay"*).

**PLANE FIX №3 (2026-08-14):** `rXY = length(posW.xy)`, sweep about +Z, `ang` negative so the ribbon trails BEHIND along the prograde sense (+z×r, matching the Doppler block's `tang = (−y, x, 0)`). Re-enabled at `renderer.mm` (was `if (false && trajectoryPipeline …)`), original gate kept: emergent hole **or** manual spin.

🚨 **THE LESSON, THIRD SIGHTING: a 90°-off orbital plane makes correct physics look like a fake overlay.** Doppler (№2), trajectory arcs (№3). **Before condemning any azimuthal effect as "fake", check its plane against `posW.xy`/+Z first.**

**Live dials on this look (all already wired):** `tuneArcGain` (exposure→ribbon length), `tuneArcWrap` (sweep cap, ≈2.2 rad — longer closes arcs into per-particle CIRCLES = concentric rings), `tuneTrailGain` (brightness).
**⚠️ Honest caveats, none yet judged:**
- `Ω = 1/(r^0.9 + a)` is a **COMPRESSED** differential, tuned down from 1.5 in June so the inner/outer ratio "no longer tears the disk into two populations". **It is therefore NOT the true Kepler law** — the funnel's winding is artistically compressed. A lever if he wants it more extreme.
- **`rXY > 8.0` cull at rest** (`:2756`) emits nothing outside the hole's neighbourhood — that is why the OUTER rings are still Streuselkuchen dots. Deliberate old tuning, not a bug. One line to lift.
- **fps NOT MEASURED.** 22 line-verts × up to 1.5M particles = **33M vertices**; baseline was ~31–36 fps (§L7). If it bites, cap the arc budget — do **not** shorten the ribbons.

### ⛔ 4c. BOTH BEAMING CHANGES REVERTED — 2026-08-14 12:35:26. Baseline restored bit-for-bit.

**His verdict 12:30:57: *"its just black mush over half the screen."*** ⚠️ **I first suspected the new depth body. MEASURED INSTEAD, and it was not:** live `horizonR` = **0.098 → 0.176 sim**, so b_c ≈ **0.44 sim against a disk radius of 18 — under 3% of the disk.** The body is the size of a dot and cannot darken anything. **The beaming was the culprit.**

| attempt | what | why it failed |
|---|---|---|
| 12:01:52 | raw g³ | peak 1.69 → 6.4; additive blend saturated → *"just blue grey ish"* |
| 12:19:20 | ÷ ⟨g³⟩ = (1+β²/2)/(1−β²) | **worse.** Normalising by the MEAN of a skewed distribution crushes the TYPICAL value |

**The arithmetic I owed before shipping it.** At the disk's peak β ≈ 0.6: ⟨g³⟩ = 1.84, but g³ for **transverse** matter = (1−β²)^{3/2} = 0.512 ⟹ typical particle drew **0.512/1.84 = 0.28, i.e. 3.6× dimmer.** Most of a ring moves transversely, so most of it went dark and one approaching arc survived. The ring mean was exactly 1.0 as designed — carried entirely by the crescent.

🚨 **THE LESSON — why this is a revert, not attempt 3.** g³ is correct physics, but a **41× intra-frame range cannot be carried by an additive point cloud with no opacity floor.** DNGR Fig 15c is a *thick disk rendered to film*; its dim side reads because it is a lit surface, not a sum of sparse sprites. **Beaming is downstream of the surface problem (§4d.1), not independent of it.**
🚨 **AND IT IS NOT MINE TO TUNE.** His order 12:26: *"i will create a new preset in the ui at a later point, it cant be constructed from the parameters in the engine rn."* **Brightness/colour is his via presets. Do not touch that block again unasked.** Dead code kept verbatim for whoever revisits it WITH the dials and an opacity floor.

### ~~4c-old. T1 flux normalisation~~ — superseded by the revert above

**His verdict 12:13:** *"why is it also just blue… its still just blue grey ish diamondy."* **This was the predicted failure mode landing.** Raw g³ peaks at 6.4 vs the old law's 1.69, and the absolute luminance scale was tuned for the old peak — so with ~2M sprites under ADDITIVE blending the bright limb saturates locally and washes to white/blue. **Changing the law without changing the exposure it was built for is a photographic error, not a physics one.**

**Cure = exposure, never the exponent.** The azimuthal mean of g³ around a ring is closed-form:
`g³ = (1−β²)^{3/2}/(1−β cosφ)³`, `⟨(1−β cosφ)^−3⟩_φ = (1+β²/2)/(1−β²)^{5/2}` ⟹ **`⟨g³⟩ = (1+β²/2)/(1−β²)`**.
Dividing by it holds the ring's **average** brightness exactly where it was; the full contrast ratio 41× is **redistributed, not rescaled**. Zero free parameters. Peak drops 6.4 → 3.87, trough 0.157 → 0.095.
⚠️ **Assumes edge-on** — the LOS modulation amplitude is |β|·sin(i), so a face-on view is slightly over-dimmed. Revisit only if face-on reads flat.
🚨 **Never restore `DOPPLER_EXP = 1.4`.** If the peak still saturates, the next lever is the tonemap.

### 4d. 🔴 HIS OPEN COMPLAINTS FROM THE 12:13 RUN — not yet actioned

1. ⭐ **"star size is still stars, not smear of stretched light"** + the light-streak reels he attached as reference. **This is the biggest remaining gap and it is BLOCKED, not unsolved:** the streak mechanism is hard-off at `render.metal:1249` and he rejected re-landing it **twice** (2026-07-25 22:26, 2026-07-26 12:35 — *"the entire mechanix is broken and is a relict from very early days… screen-space velocity-stretching of a point sprite is the wrong mechanism for trails, full stop"*). It needs **replacing**, not repairing. Candidate: draw the particle's REAL path segment (`prevW → posW`) as line geometry — that is a true long exposure, not a smeared dot, and it is what the reference photographs physically are. ⚠️ Distinct from the stripped 22-vertex ANALYTIC arc ribbons, which were fake by construction.
2. **"diamondy"** — every particle draws a full-strength 4-point diffraction cross. `starness = (1−elong)/sL`; `sL == 1` (bit18 dead) and `elong ≈ 0` at rest, so the gate that was *meant* to keep the orbiting disk clean (`:2521`) is inert. A brightness gate was added 2026-07-26 and **reverted 2026-07-28 09:31:05** — *"u need to undo more than u did. its still broken."* 🚨 **`:2583`: DO NOT re-add a gate here until the STAR ATTRIBUTE DIALS exist.** So the unblock is **build the dials**, not another gate.
3. **"the accuracy meter is still shaky when blackhole is there"** — HUD stability, uninvestigated.
4. **"still a fake visual not physical overlay"** (lens off `#3` vs on `#4`). ⚠️ Note the parity proof in §2 says the optics ARE real — so this complaint is most likely **1 and 2 wearing a lens costume**: discrete spiking dots on a ring can never read as the continuous surface of pics 10/11, however correct the bending is.
5. **Colour:** *"usually a black hole is reddish blueish, not just blue grey"*. His own `#3`/`#4` are already warm orange, so this is state-dependent, not global. Likely resolves with 4c; re-judge after.

**⭐ PICS 10 + 11 ARE THE TRUTH** (his words): `~/Downloads/BH_optics_explained.jpg` (the NASA warped-optics panel — the parity diagram of §2) and `~/Downloads/Black_hole's_accretion_disk.jpg` (the labelled NASA disk: shadow, photon ring, far-side image, underside image, Doppler beaming). **Those two images name S1/S2/S3/T1 exactly as §0 decomposes them.**

---

## 5. ⚔️ THE CENTRAL DESIGN TENSION — read this before proposing anything

**Sprites give us Chladni structure and 2M-body detail. Only a per-pixel integrator gives S3 and true multi-loop S2. We cannot have both from one renderer, and overlaying them was tried and failed** (two pictures ~100× apart in resolution — *"it doesn't connect to the rings"*).

Three ways out, honestly stated:

- **(A) Stay sprite-native, accept no photon ring.** ~~Fix the lens's two blend sites (§2)~~ ✅ **DONE 2026-08-14, re-verified in source 2026-08-22 01:34:32** — `render.metal:1164` + `:1184`; fix L1's divisor, add T1 beaming. **Gets: S1 ✅, S2 ✅, T1 ✅, T2 ✅, S3 ❌.** Cheapest by far, and four of five features is already a different-looking hole.
- **(B) A third instance for n = 2.** Extends the sprite scheme by one winding. Cheap to try, gives a *hint* of S3, still not the infinite stack. Cost: +50% on the heaviest pass (L7).
- **(C) Hybrid — march ONLY the thin annulus at the shadow edge** where S3 lives (b ∈ [2.598, ~2.7] r_s), composited under the sprites. Sidesteps L4's resolution mismatch because that annulus has **no Chladni structure to lose** — it is pure lensed light. Needs L9 resolved first and a temperature input to escape the orange.

⭐ **Recommendation: (A) fully, then evaluate (C) with real eyes on it.** (A) is four of the five features and every step is one verifiable change. **Do not open by rewriting the lens** — two of the last three hypotheses on this project were refuted by their own fixes.

---

## 6. 🛤️ THE TRACK — ordered, one verifiable change each

| # | Item | Unlocks | Cost |
|---|---|---|---|
| **0** | ⏳ **His verdict on the §4 capture test.** Everything below stacks on it. | S1 | **0** |
| ~~**1**~~ | ✅ **DONE 2026-08-14, VERIFIED IN SOURCE 2026-08-20 14:08:59, RE-VERIFIED 2026-08-22 01:34:32** — `render.metal:1164` (secondary placed by the lens equation, no `mix`) + `:1184` (`imageWeight = cam.tuneLens * lensRamp * …`). This row sat open on the board for six days after the code closed it. 🚨 **Its consequence is permanent: every pre-2026-08-14 SLIDER lens A/B is void — see the callout in §2.** | — | **0** |
| ~~**2**~~ | ✅ **SHIPPED 2026-08-20 15:36:28 — see L1. UNVERIFIED.** ⏳ **What to look at: in PERSPECTIVE the shadow should be ~2.9× bigger; in ORTHO it must be identical.** If perspective looks unchanged, this is not the path drawing it — that is a finding, not a tweak. | S1 / gates A0 | **0** |
| **3** | ✅ **T1 — HONEST BEAMING LAW. SHIPPED 2026-08-14 12:01:52, verdict pending.** See §4b. Was 1/18 of the true asymmetry. 🚨 If the g³ ceiling is ever revisited, the fix is the tonemap — never the fudge exponent. | **The effect Nolan turned off. Nobody has seen it in a movie.** | **done** |
| **3b** | **Gravitational redshift** — the √(1−2M/r) factor of A.16, the other half of g. Deliberately not batched with 3. ⚠️ Reference form is a SINGLE g combining both; do not apply two independent multipliers without checking against A.16. | T1 complete | **S** |
| **4** | **Re-derive L9** — a 40-line offline integrator measuring b_c against 3√3·M = 2.598076. | Makes the march trustworthy again; gates (C) | **S** |
| **5** | **Fix the bit15 double-booking** (L6) — give AMR its own bit. | Every AMR A/B becomes valid | **S** |
| **6** | Evaluate **(C)** — annulus-only march for S3 | S3 | **L** |

**Deferred, deliberately:** Kerr/spin *(DNGR §7.4 — the path is written, the look barely changes at our viewing geometry)*; L5 origin lock (real work, no visual payoff until the hole moves); L2 play-time lensing (regime decision, his call).

---

## 7. ☠️ DEAD ROADS — do not retry

- **The fullscreen geodesic paint / black-disc overlay.** Withdrawn the same day it shipped. A fullscreen multiply after the particles **blacked out matter clearly in FRONT of the hole** — and it cannot do otherwise, because depth WRITE is off for the particles (`renderer.mm:1077`) so no later pass has depth to order against. *"A black circle that overlays in front of everything."* `renderer.mm:3853-3863`
- **The screen-space raytracer shadow.** Deleted 2026-06-28 — a 2D circle sampling no useful disk. `renderer.mm:3911`
- **The march as the hole's renderer.** L4. Settled by A/B 2026-07-26 21:20.
- **The slab-cull exception.** Removed 2026-07-19 17:58 — it carved a straight-edged band across the shadow (*"it looks like a pokeball"*). `render.metal:853-856`
- **The seed billboard.** One ImGui-scale sprite pinned to the 220px cap = *"a yellow thing, unnatural, attached to the black hole, super low-res, tilting with the camera"*. Now stands down once an honest horizon exists. `render.metal:2103`
- **The analytic Ω(r) arc ribbons.** *"Fake trails centered to a tube shape."* Gated `if (false)`. `renderer.mm:3894`
- **`postfx` as the cause of anything.** Ruled out on fps and on star appearance. Never suggest again.
- **Re-centring dilation/lens on `cam.bhX/Y/Z`.** L5 — 4 no-ops logged.

---

## 8. 📐 THE ONE CARD — keep these numbers to hand

    Field units:  r_s = 1.0,  M = 0.5,  c = 1
    Photon sphere:        r = 3M = 1.5 r_s
    Capture / shadow:     b_c = 3√3·M = 2.5980762 r_s      ← the number everything keys on
    Geodesic (a=0, Cart): d²x/dλ² = −3·M(<r)·|x×v|²·x/|x|⁵  = −(3/2)·r_s·h²·x/r⁵
                          ⚠ the (3/2) is NOT (1/2) — the half-value has no photon sphere at all
    Doppler g-factor:     g = (p·u_obs)/(p·u_emit)
    Shifted blackbody:    B_ν(ν, g·T) ≡ g³·B_ν(ν/g, T)      — ONE operation, never both
    Shadow angular size:  sinθ_sh = b_c·√(1−2M/r_c)/r_c  ≈  b_c/r_c
    Time dilation:        dτ/dt = √(1 − 1.5·r_s/r)          — ours floors at 0.4, render.metal:783

---

## N. ROWS MOVED IN FROM `docs/BOARD.md` — 2026-08-19 00:14:12

**His order, 2026-08-19: *"move bh stuff to bh board"*** — executing the standing 2026-08-14 rule
that everything black-hole lives here. Every block below is **verbatim** out of `BOARD.md`, with the
line it occupied in the pre-move file. `BOARD.md` keeps a one-line pointer where each block was.

⚠️ **Not yet reconciled with §0–§8 of this board.** These rows were written before this board existed,
so some restate what §1/§3/§4 already say and some may contradict them. **Where they disagree, §0–§8
wins** — they were verified later. Folding them in is the next pass, not done here.


### N1. A0. THE STANDING STRUCTURAL FAULT — the GoPro verdict, and the A0 test that came back inconclusive

*Moved from `BOARD.md` lines 122–164 — the hole itself: whether it reads as a body or a screen-space circle.*

#### 🕳️🚨 A0. THE STANDING STRUCTURAL FAULT — "IT IS NOT A BLACK HOLE, IT IS A BLACK CIRCLE WITH A GOPRO ON TOP"

**His verdict, 2026-08-10 09:13:00, with a screenshot, lens OFF:**
> *"when i turn off lens it's still just a weird spinning circle... like not a thick ring like Sonic the Hedgehog coins but **flat 2D rings with fake depth**. It's not a true black hole. This issue has been standing for **months**. I believe that a lot of our issues fall back to the fact that **it's not a black hole but a black circle with a GoPro on top**. Our black hole eventually needs to **survive non-ortho mode**. It's **crumbling under its own hotfixes**."*

🚨 **THIS ROW OUTRANKS EVERYTHING BELOW IT.** A1′, A2, A3①②③ are all bookkeeping inside a renderer whose camera cannot express depth. **A2 "passing" means a number went down — it does not mean a black hole exists.** Treat every ✅ below as scoped to arithmetic until this row moves.

**MEASURED THE SAME MINUTE — his verdict holds. My first two findings did NOT.**

🚨 **RETRACTION, 2026-08-10 09:24:00.** The rows I wrote as A0a and A0b described **`renderer.mm:1401`, the one-argument `render(const RenderConfig&)` overload, which has ZERO callers.** It is dead code. Verified: `grep` for `.render(`/`->render(` across `src` returns exactly one call site, `main.cpp:2533`, and it is the **two-argument** form. Both claims are withdrawn. The row itself survives on his eyes and on A0d below.

| # | Finding | Evidence |
|---|---|---|
| ~~**A0a**~~ | ~~two camera systems, BH uses the wrong one~~ **WITHDRAWN.** The live path is `render(config, viewProj)` and it `memcpy`s the matrix built in `main.cpp:770-779` — which **does** branch `orthoMatrix` / `perspectiveMatrix(45°)`. The toggle reaches the particle/BH path. | `renderer.mm:1628`, `:1696`; `main.cpp:2533`, `:770-779` |
| ~~**A0b**~~ | ~~`cameraPos` hardcoded `{0,R,0}`~~ **WITHDRAWN.** That literal is in the dead overload. The live path sets `cam.cameraPos` from `config.cameraPos`, which `main.cpp` fills from the real orbit camera (`camera.getX/Y/Z()`). A comment at `:1697-1699` records that this was already fixed once. | `renderer.mm:1700-1702`; `main.cpp:2162-2164` |
| **A0c** | **AN ORTHOGRAPHIC PROJECTION CANNOT PRODUCE THE LOOK HE IS ASKING FOR.** Under ortho a tilted ring projects to an *exact ellipse* — near and far sides render at identical scale, so there is no foreshortening and no volume. **"Flat 2D rings with fake depth" is the literal, correct description of an orthographic projection of a ring.** The "thick Sonic-coin ring" he wants requires perspective plus real vertical structure; no post-FX can add it. **Still stands — this is geometry, not a code claim.** | `main.cpp:773` (the live ortho matrix); his screenshot 2026-08-10 09:13:00 |
| **A0d** ⭐ | **THE HOLE IS HARD-GATED TO ORTHO — this is the real mechanism, and it is one line.** `cam.bhShadowNdcRadius = (config.orthoMode && frustum > 1e-4 && bhLensActive) ? bSim*plateRadius/frustum : 0.0f`. **Turn ortho off → the radius is literally `0.0f`** → every shader gate on it (`> 1e-4`) goes false → no shadow, no lens. The hole does not degrade in perspective, it **ceases to be drawn**. That is "cannot survive non-ortho mode", stated in code. | `renderer.mm:1749-1752`; gates at `render.metal:771`, `:879`, cull at `:671` |
| **A0e** | **AND IT IS A SCREEN-SPACE CIRCLE, NOT A MARCHED OBJECT.** The quantity passed to the shader is an **NDC radius** — `render.metal:1035` consumes it as `thetaE`, a screen-space deflection angle. Nothing is marched through a world-space metric on this path. **"A black circle with a GoPro on top" is a fair description of what the code draws.** | `renderer.h:177`; `renderer.mm:1749`; `render.metal:1035` |
| **A0f** | **SECOND GATE: the lens is OFF whenever he is playing.** `bhLensActive = (totalAmplitude < 0.02f)`. Any judgement of the hole made while notes are sounding is a judgement of a hole with no lens. | `renderer.mm:1748` |
| **A0g** 🪤 | **THE DEAD OVERLOAD IS A NEAR-DUPLICATE, NOT JUST UNUSED — IT IS A STANDING TRAP.** `Renderer::render(const RenderConfig&)` has **zero callers** (verified 2026-08-10 09:55:00: one `.render(`/`->render(` hit in all of `src`). It is not inert: it *near-duplicates the live path*. The `cam.bhShadowNdcRadius` gate exists **twice, identically, four lines each** — the two copies differ only in the trailing comment on the preceding line. An `Edit` on the live gate failed with *"Found 2 matches"*; had it not, the change would have landed in dead code and read as a no-op. **This duplication is the direct cause of the A0a/A0b retraction above**, and it silently shadows the live path in every grep. **Rule: assume any camera/BH uniform assignment exists in BOTH bodies; confirm which one you are editing before you edit it.** The same both-bodies check is owed to the CPU-side feeders for `render.metal:904` and `:1031`. ⚖️ *Camera window's recommendation, and I agree: the dead overload should eventually be **deleted**, not maintained — but that is a deletion during show prep, so it is **Jamal's call and post-BNMW**. Flag it, do not action it.* | `renderer.mm:1401` (dead body), `:1501` (dead gate) vs `:1763` (live gate) — **all three verified 2026-08-10 10:01:00** |
| **A0h** ⚠️ | **`CameraUniforms` IS HAND-MIRRORED ACROSS CPU/GPU WITH NO LAYOUT GUARD — AND THE GUARD PATTERN ALREADY EXISTS IN THE SAME FILE.** `renderer.h:166-222` and `render.metal:24-74` are mirrored **positionally**, ~40 float fields, kept in sync by nothing but a comment (`renderer.h:166`: *"matches the struct in render.metal"*). **But `renderer.mm:36` already does this correctly for a different struct:** `static_assert(sizeof(BHMarchUniforms) == 88, "BHMarchUniforms layout")`. So the project knows the technique and `CameraUniforms` was simply left out. A mid-struct insert on one side shifts **every field after it** — `bhShadowNdcRadius`, `horizonR`, `bhX/Y/Z`, the whole `tune*` block — and would present as a *physics* bug, chased in the wrong file for a day. **Agreed working rule (both sessions): new fields are APPENDED AT THE END of both structs, never inserted.** Appending degrades a mismatch from "everything after the insert is garbage" to "the one new field is garbage" — local and obvious instead of global and misleading. ⚠️ Note when the assert is added: `sizeof` catches drift but **not transposition** — two structs can agree on size and disagree on layout. `offsetof` anchors bind only the fields anchored; a swap strictly between two anchors still slips through. A green build is an improvement, not a proof. | `renderer.h:166-222` vs `render.metal:24-74`; precedent at `renderer.mm:36` — **verified 2026-08-10 10:01:00** |
| **A0h′** ✅ | **THE GUARD FOR A0h IS FULLY SPECIFIED AND TESTED — not designed, tested.** Both sessions compiled standalone `.metal` files (scratchpad only, nothing in the repo). Compiler: *Apple metal version 32023.850, target air64-apple-darwin27.0.0*. Results: **(1)** MSL supports `static_assert` + `sizeof` and **it fires** — wrong value → `error: static_assert failed … 1 error generated`; the *failing* case was checked deliberately, since a clean compile alone only proves the assert was ignored. **(2)** `offsetof` **does NOT exist in MSL** (no `<cstddef>`) — writing the anchors the obvious way would have broken the shader build and looked like a struct bug. **(3)** `__builtin_offsetof` **works** in MSL and fires. **(4)** ⭐ **It catches TRANSPOSITION**: two adjacent floats swapped, `sizeof` unchanged, anchor caught it — the exact gap `sizeof` alone leaves, reproduced rather than argued. **Final shape:** same shared numbers in both files — `sizeof` + `__builtin_offsetof` anchors on `bhShadowNdcRadius`, `bhX`, and the tail field (the three that exist under the same name in BOTH files; `cameraPos`/`cameraPad` does **not** qualify — Metal declares `float4 cameraPos` and has no `cameraPad`). Use `__builtin_offsetof` on the C++ side too, so both blocks read identically and nobody "fixes" the Metal one back. Since the Metal compile runs as the `MetalShaders` target inside `package_macos.sh`, **the guard breaks the normal build loop** — it has teeth. ⚠️ **Honest limit, to be stated in the code comment:** three anchors across ~40 fields catch size drift, tail-append mismatch, and transposition *across* an anchor. A transposition strictly *between* two anchors still slips through. **Better than the comment that guards it today; not a proof.** | verified **2026-08-10 10:06:00** (sizeof, this window) and **2026-08-10 ~10:10** (offsetof/transposition, camera window); precedent `renderer.mm:36` |
| **A0j** 🚧 | **HOW TO READ A CLEAN A0 RESULT — DO NOT OVER-READ IT.** If a disc appears in perspective, that proves the hole draws **for a camera that still points at the origin**. It does **not** prove perspective is solved. Two sites hardcode that assumption: `render.metal:1031` `viewDir = normalize(-cam.cameraPos.xyz)` (feeds `behindBH`, which decides what is lensed vs what occludes the hole — the thing that puts the hole *in the room* rather than on a flat layer, per the 2026-06-13 comment) and `render.metal:904` `dHat = normalize(-cam.cameraPos.xyz)`, whose own comment reads *"(ortho: parallel rays)"* — self-documenting that it is ortho-only, and it guards the **seam fix of 2026-07-26 13:56:00**. Both are safe *today* only because `camera.h:123` hardcodes the same thing (`forward = {-posX,-posY,-posZ}`) — the whole camera is look-at-origin. **The moment dolly rides or POV-follow land, both misclassify silently: the lens bends the wrong half of the field, the occlusion inverts, and the old seam artefact returns.** No error, just wrong. Both sites need the real forward vector, not just the view matrix. ⚖️ Owned by the camera window (`airy-7b`), not this row — recorded here so a green A0 is never mistaken for "perspective works". | `render.metal:904`, `:1031`; `camera.h:123` — verified **2026-08-10 10:04:00** |
| **A0i** 📅 | **`file:line` IN THIS DOCUMENT DECAYS, AND NOTHING MARKS IT STALE.** The live gate moved `:1749 → :1763` at **2026-08-10 09:55:29** — mid-session, from a comment block added directly above it. Every A0 reference written before that timestamp was correct when written and wrong an hour later, with nothing in the file to say so. **Rule: cite a grep pattern or quote the surrounding line; where a bare number is unavoidable, stamp it with the time it was verified.** A `file:line` without a verification timestamp is a claim with no expiry date. | this row, and the `:1750`→`:1763` drift throughout §A0 |

**What this reframes:** ⭐ **C3 (99.3% of stars pinned to one pixel), C7 (the Cartwheel colour law), the "two rings" history, and the months of "it reads as two circles" reports are all plausibly downstream of A0.** Before spending another session on any of them, settle whether the BH path can render in perspective at all.

##### ⏸️ A0 VERDICT — **INCONCLUSIVE, NOT PASSED AND NOT FAILED.** 2026-08-10 10:20:00

**Done:** the `config.orthoMode &&` term was removed (live gate, now `renderer.mm:1763`; the ortho path is unchanged, this only adds the perspective case). Built and deployed **09:55:37**, verified newer than source, launched twice (09:57:31, 10:18:07).

**His verdict:** *"the cam is still kinda locked in place so I don't know if I see the BH — but that's not even our priority right now."*

**Read that precisely — it is NOT a null result.** The measurement could not be TAKEN. The camera cannot be moved to a viewpoint where the answer would be visible, so no observation was made, and **no conclusion about the gate is licensed in either direction.** Anyone later reading "A0 test ran" must not read it as "perspective works" or as "the gate wasn't it."

**⭐ WHAT THIS CHANGES — THE DEPENDENCY IS THE REVERSE OF WHAT WE ASSUMED.** A0 was written as though the camera work sat downstream of it. It does not. **Reading A0's result REQUIRES a camera that can move**, because a locked, origin-pointing camera produces no parallax and therefore cannot distinguish a perspective-correct disc from a flat one. So: **the camera overhaul now gates the A0 measurement.** That is also the show work, so the two are no longer in tension — they are the same road, in the order camera → then re-read A0.

**STILL UNMEASURED, carried forward for when the camera moves:** the predicted **~2.9×** scale error (`/frustum` is the ortho world→NDC map; perspective needs `d·tan(fovY/2)`, and `d` must be camera→**hole**, not camera→origin, since the seed wanders). The divisor fix is deliberately **not** batched into the gate drop — it is the next change, and it needs the measurement first.

**⚠️ Do not re-run this test with a locked camera.** It will produce the same non-answer. Re-open it only after the camera window lands a movable, non-origin-pointing camera — and then read **A0j** before interpreting the result.

🚨 **AND THE TESTS:** his words — *"whatever tests you've been running here are total ass. Stuck from start at 49.97 as I've said all the fucking time."* **He is right on the facts.** `Biggest body` sat at the IMF ceiling (~49.9) for the whole of two runs while we waited (see **A5**), and the runs that did cross validated a *number*, not a hole. **A2's result is real and also nearly beside the point until A0 moves.**



### N2. THE ACCRETION / HORIZON ROWS out of §A. BLOCKERS

*Moved from `BOARD.md` lines 396–421 — every one of these is the hole forming, feeding, merging, or refunding.*

| ~~A1~~ | ~~**Accretion is dead.**~~ ❌ **REFUTED 2026-08-08 00:05:09 — MEASURED, 3 RUNS.** Accretion is not dead. **It runs away.** See **A1′** below. The old claim came from a **64× run**, where §7's tunnelling arithmetic is correct and merging genuinely cannot happen. Nobody had run **1× silent** long enough. | ✅ closed | 3 stacked runs, `logs/A1_*` | — |
| **MERGER-FACE** 🎨⭐ | 🎨 **"A MERGER DOESNT HAVE A VISUAL FACE YET. ITS JUST MILLIONS OF DOTS." — his call, 2026-08-13 01:02:00**, with the follow-up: *"these mergers are not mergers but a STILL squarish giordy bs thats 2d."* His screenshots show the merged body as a **blown-out squarish white slab with a hard straight edge** — flat, no volume, no aura, and it does not read as an event. His other words for the failure: *"like a wet towel tryna add more water"*, *"it has 0 aura"*, *"not a force event that turns into a pre black hole of thousands of dying stars."* ⭐ **AND HE ASKED THE RIGHT QUESTION FIRST: what does a stellar merger ACTUALLY look like, science-wise? We have never asked.** That question is the row — the render follows the answer, not the other way round. **The three cases are physically different and we currently draw all three identically (as more dots):** ① **star ↔ star** → contact binary → common-envelope ejection → a **LUMINOUS RED NOVA**: brightens ~10⁴×, then goes RED and COOL as the ejected envelope expands and recombines, months-long plateau. V1309 Sco (2008) is the textbook case — the only merger caught with a pre-merger light curve — plus V838 Mon (2002). **So a real star merger is not a white flash; it is a red, slow, expanding shell.** ② **star ↔ black hole** → **TIDAL DISRUPTION**: the star is stretched into a stream at the tidal radius, ~half the debris unbound and ~half returns to circularise, flare rises in weeks and decays as the classic **t^(−5/3)** fallback law. We already book the inelastic KE loss for this (`seedAccum` word 5, "drives the TDE flare") — **the physics is in the books and NOTHING draws it.** ③ **BH ↔ BH** → **no light at all**, gravitational waves only; the visual is the RINGDOWN of the field around it, not the object. 🚨 **UNDIAGNOSED, separate from the art question: WHERE DOES THE SQUARE COME FROM?** A hard straight edge in a particle cloud is a BOX, and this project has been bitten by exactly that before — the AMR row records `r≈2.66 DAM was the AMR box face`. Suspect the AMR fine-grid box before suspecting the sprite. | ⬜ **NEW — question posed, science sketched, NOTHING verified against a source** | his screenshots 2026-08-13 00:59:04 + 00:59:27 + 01:0x; KE ledger `seedAccum` word 5; AMR box precedent in the AMR row | **M** (research first, then render) |
| **A1‴** | 🔨 **ORPHANED MEAL DEPOSITS NO LONGER DESTROYED — SHIPPED, STILL UNPROVEN.** `seed_apply` used to `return` when the slot's seed was dead, **discarding the plate**. A seed eaten in the same frame parks with `posW.w = 0`, so every meal other threads deposited into it (stars it captured, smaller seeds that merged in) vanished from the books. The merge comment's *"one victim per pair, no mutual death"* is true for a PAIR and says nothing about a **CHAIN**: A→B and B→C in one frame makes B exactly this case. **Signature that opened it:** `Mlive` fell 594,046 → 589,683 (**−4,363**) across the `seeds` 26→8 cascade, **81% of a 13.8-min run's entire −5,385 drift**, then flat for 9 minutes. Now a dead slot's deposit is swept by the **lowest-index live slot**, mass + momentum + KE together. 🚨 **The first version swept to the BIGGEST live seed and that was a MASS-CREATION RACE** — every thread scans while every thread writes `posW.w`, so two can both believe they are the sink and credit the orphan twice. The withdrawal block four lines up runs on thread 0 alone for exactly this reason and says so. Aliveness is stable under those writes (crediting only grows a mass); a mass ORDERING is not. ⚠️ **UNPROVEN:** no run since has reproduced the 26-seed cascade — the two clean runs held `seeds` at 1–3, so the chain path was never exercised. `Mlive` held to −71 over 457,421 eaten in the 22:00 run, which is consistent, not proof. | 🔨 built, **untested** | `particles.metal` `seed_apply` sweep block; drift from `/tmp/killtube_bound.log` | **S** (a run that reaches the cascade) |
| **A2** | ⭐ **UNBLOCKED 2026-08-08 — RUNNABLE FOR THE FIRST TIME IN FOUR HANDOFFS.** The A1′ fix makes a hole **persist over a living field** (`r_h = 0.3516` with 1.27M stars alive), so both preconditions finally hold at once: a real seed exists, and there are corpses to refund. **The test:** let it run silent at 1× until `Biggest body` clears 50, then **hold a sustained note** and watch that number **FALL** — the first non-monotone `gMaxMass` in the project's history. Watch for `[REBIRTH] withdraw=…`; `SHORTFALL(minted)` means the drain clamped at 0 and mass was created. 🚨 **NEEDS HIS EARS AND HANDS — he must play.** ⚠️ Momentum is knowingly not conserved on rebirth (a reborn particle takes its host's velocity); flagged as a choice, not an oversight. ✅ **NOT MASKED — warning withdrawn 2026-08-08 17:04:19.** The old note said A3① would hide the effect. Measured: `seedTarget` never reaches 1 in any healthy run (max 0.726), so it pins nothing — **and the test watches `Biggest body` = `gMaxMass`, a HUD number that does not depend on `bhStrength` at all.** ⭐ **A2 is observable right now, with no code change first.** ⚠️ Momentum is knowingly not conserved on rebirth (a reborn particle takes its host's velocity); flagged as a choice, not an oversight. — 🔥 **IT FIRED, 2026-08-08 18:12→18:31. `[REBIRTH]` had 0 occurrences in the whole project; run 1 logged 40.** `gMaxMass` fell `177,218 → 90,294 → 45,653 → 22,751 → 10,798 → 4,809 → 1,820 → 737 → 319 → 147 → 50.0` — **23 falling steps, halving every 120 frames, `SHORTFALL(minted)` = 0.** The field came back: `live` 2,000,000 → **1,227,500** → **1,999,950**. FPS median 48, 3.3% under 30 — healthy. 🚨 **BUT A2 AT 2M IS STILL n=1 AND THIS PROJECT BANS SINGLE-RUN CLAIMS.** Run 2 reproduced it (7 lines, hole `548.6 → 248.8 → 76.5 → 50.0`, 0 SHORTFALL) but at **10M particles** — a different configuration that cannot stack. **A clean 2M repeat is owed.** Full detail: `docs/MEASURED_2026-08-08_A2_refund_fired.md`. | 🔨 **log-verified ×1 at 2M · visual verdict NEVER GIVEN** | `particles.metal:689`, `:694`, `:3445`; `renderer.mm:3094` | **S** (the test) |
| **A3①** | **The `/0.5` denominator is REAL but NOT CURRENTLY BINDING — and it is NOT what stops the reversal. MEASURED, 5 LOGS STACKED, 2026-08-08 17:04:19.** The arithmetic checks out: `seedTarget = kRsSimPerMsun · bhSeedMass / kREnc` reaches 1 at `0.5 / 1.6825e-6 = ` **297,177 M☉** exactly as the row claimed. ❌ **But `seedTarget` is not what pins `bhStrength`.** Counting `[BH-POP]` samples: `seedTarget ≥ 1` occurs **0 times in all four healthy runs** (max `seedTarget` reached: **0.003 · 0.726 · 0.723 · 0.041**), while `r_s/r ≥ 1` occurs in **1,529 · 223 · 179 · 120** samples — **and `seedTarget < 1` in every single one of those.** Only the pre-fix 30-s runaway crossed it (`Mmax` 557,451 → `seedTarget` 1.879). 🚨 **So the thing holding `target ≥ 1` is `honestTarget` (`r_s/r`, median 3.4), not this denominator.** Since `target = max(seedTarget, densTarget, honestTarget)`, **fixing `kREnc` alone cannot make the hole un-form** — third no-op fix found on this board for the same structural reason. ⚠️ **It becomes binding soon, though:** post-fix growth is **2,451 M☉/wall-s** and run2 peaked at `Mmax` 215,829, i.e. **~33 s of further running crosses 297,177**. On a Berlin-length run it *will* engage. ⭐ **The row that actually controls reversal is A3② (the ORIGIN LOCK)** — `r_s/r` is computed from a profile binned around the origin while the seed wanders off it. **Fix A3② first; A3① is a follow-up, not a prerequisite.** | ⬜ real, not binding yet | Measured: `logs/A1fix_CAS*`, `A1fix_ratelimit`, `A1_retest_seed{7,42}`. Code: `renderer.mm:2994` `seedTarget`, `:3030` the `max()`; `units.h:86` `kREnc = 0.5` | **M** |
| **A3②-white** ⭐🚨 | **THE "WHITE MERGERS" REGRESSION IS A3② WEARING A COSTUME — SAME BUG, AND IT IS THE VISIBLE ONE. Traced 2026-08-10 19:50:00.** His report: *"these two mergers u see rn we had them black once, then some changes turned them white again… they look cheap and sluggish compared to the rest."* ⚠️ **SELF-CORRECTION, 2026-08-10 19:54:00 — I first wrote this as "the seed wanders off the origin". That is NOT the mechanism, and the origin lock is NOT a bug to undo.** `renderer.mm:3340-3347` records it as **his own call**: *"Jamal: lensing and the hole drifted apart after seconds of correctness… the centre of gravity is PINNED at 0/0/0 by design and the seed sinks there — the hole IS at the origin, always. The wandering enclosure-COM refinement made the rendered shadow chase disk slosh."* **Do not re-enable the refinement; it was tried and rejected.** | ⚠️ **THIS ROW LOST ITS LAST TWO CELLS** — it was written without them and has been rendering as a 2-column row ever since; noticed 2026-08-23 20:12:26. The claim above is unchanged; only the missing cells are new. | ⬜ Verified/Note to be filled the next time this row is actually worked |

**THE ACTUAL MECHANISM — THE MEASUREMENT ASSUMES ONE HOLE, AND HE HAS TWO.** The design holds only while a *single* mass sinks to the pinned centre. His screenshot shows **two** massive bodies, both clearly off-centre. The COM pin recentres the FIELD's centre of mass, so with two lumps the origin sits **between** them and neither is there. The radial profile bins around `u.bhX/Y/Z` = `(0,0,0)` (grep `// RADIAL PROFILE:` in `particles.metal`; initialisers at `renderer.mm:196`, refinement disabled at `renderer.mm:2987` — ⚠️ **board cited `:2959`, drifted, corrected**), so **it measures the empty gap between the two bodies** and reports `sup r_s/r = 0.000` while 60% of the field mass sits in them. 🚨 **And `horizonR == 0` is exactly the condition that keeps the seed BLOB alive:** `render.metal:1941` renders it only `if (… && cam.horizonR <= 0.0f)` — *"pre-horizon only… once the honest horizon exists the blob stands down and the hole is ONLY the particles + lens"*. **The stand-down logic is correct. The measurement feeding it is broken, so the blob never stands down.** What gets drawn instead: `Req = pow(M, 0.8)` → at his observed **356,475 M☉** that is ~27,600 R☉ → size clamps at the **220 px ceiling**, `blackbodyRGB(20000 K)` = blue-white, luminance 10. **One flat 220-pixel billboard sprite.** ⭐ **HIS OWN SCREENSHOT IS THE PROOF:** *"Horizon: none yet, sup r_s/r = 0.000"* printed beside a 356,475 M☉ body. ⚠️ **This is the SAME artifact class he killed on 2026-07-23** (*"a yellow thing, unnatural, attached to the black hole, super low-res, tilting with the camera"*) — the stand-down was wired then, and A3② quietly un-wires it. ⭐ **CONSEQUENCE: this is a SHOW-VISIBLE defect, not physics bookkeeping.** Promote it accordingly.

⭐ **RECOMMENDED FIX — ONE LINE, AND IT TOUCHES NEITHER THE ORIGIN LOCK NOR THE PHYSICS: gate the blob on MASS, not on `horizonR`.** The blob exists to make a *small pre-horizon seed* visible (its own comment: *"a body that eats VISIBLY fattens"*). At **356,475 M☉** drawing a blackbody STAR is wrong on its own terms, whatever the horizon measurement says — the stellar mass-luminosity law has no business being evaluated there. Add an upper mass bound to `render.metal:1941` so the billboard covers the range it was designed for and stands down above it, horizon or no horizon. **This leaves his origin lock intact, leaves the single-hole design intact, and removes the white sprite today.** The deeper question — that the honest-horizon measurement cannot see a two-body configuration at all — is real, is **NOT** solved by this, and stays open below. | ⬜ **NEW — traced, fix proposed, NOT built** | `renderer.mm:196`, `:2987`; `render.metal:1941-1954`; `particles.metal` grep `// RADIAL PROFILE:` — all read **2026-08-10 19:50:00** | **S** to unlock |
| **A3②** | **Fake hole — the profile is centred on the origin.** Root cause found this pass and it is blunter than the older docs said: the COM refinement is wrapped in **`if (false)`** with the comment `ORIGIN LOCK: refinement disabled`. So `bhPosX/Y/Z` never leave their `0.0f` initialisers, and the radial profile — which bins around `u.bhX/Y/Z` — measures around the origin while the seed wanders off it. | ⬜ | `renderer.mm:2959` `if (false) { // ORIGIN LOCK`; `:196` the initialisers; the binning is in **`kernel void reduce_stats`**, grep `// RADIAL PROFILE:` (**`particles.metal:3907`** as of 2026-08-10 15:17:00) — ⚠️ **this row previously cited `:3808`, which was stale by ~76 lines BEFORE today's edits. Re-verified by content, not by arithmetic.** | **S** to unlock, **?** to make honest |
| **A3③** | ❌ **PREMISE REFUTED 2026-08-08 16:31:44 — MEASURED. THE LATCH IS NOT THE BUG, AND FIXING IT IS A NO-OP.** The row said the latch "catches an instant" where the innermost shell transiently satisfies `r_s/r ≥ 1`. **It is not an instant.** ⚠️ **STACKED ACROSS ALL 6 LOGS (2026-08-08 16:44:07) — this project bans single-run claims and my first pass broke that rule.** Share of `[BH-POP]` samples with `r_s/r ≥ 1`: `A1fix_CAS` **1,529/1,534 = 99.7%** (median 3.431) · `A1fix_CAS_run2` **223/233 = 95.7%** (3.610) · `A1fix_ratelimit` **179/195 = 91.8%** (3.966) · `retest_seed7` **120/125 = 96.0%** (4.674) · `retest_seed42` **26/68 = 38.2%** (0.530) · `soak_1x_silent` **474/6,975 = 6.8%** (0.000). **So: sustained in 4 of 6 runs, mostly absent in 2** — and 🚨 **BOTH OUTLIERS ARE EXPLAINED, NEITHER CONTRADICTS THE AVERAGE (2026-08-08 16:52:31, his call: "trust the avg, not single transients"; "for weird runs it's more likely my screen was locked").** `soak_1x_silent` is a **STARVED RUN: median 24 FPS, 93.0% of 75,370 samples below 30 FPS, min 0** — and `dt` is per-frame, not wall-clock (`renderer.mm:1339`), so the field barely progressed. Its `r_h > 0` share (6.8%) is very nearly the complement of its healthy-frame share. Cross-check: `retest_seed42` **median 79 FPS, 0% under 30**, `A1fix_CAS` **median 40 FPS, 0% under 30** — the outlier is the only starved one. `retest_seed42`'s 38.2% has a different and known cause: it is the **30-second pre-fix runaway** (max `r_s/r` = **23.716**), so it destroyed its own field before accumulating samples. ⭐ **RULE FOR THIS PROJECT: check the FPS distribution before believing a null result — display sleep starves the sim, and a starved run is not evidence.** In `A1fix_CAS` the only 5 sub-1 samples are exactly the opening ramp `0.000 · 0.147 · 0.569 · 0.797 · 0.984`. 🚨 **Deleting the latch would change nothing, and this does NOT depend on the run variance above — it is an argument from the code.** `honestTarget = min(r_s/r, 1)` saturates at **1.0**, so `bhStrengthEma` converges to 1.0 on its own; the latch only replaces an asymptote with an exact 1.0. **Every downstream consumer gates at 0.5** — doubled particle instancing `renderer.mm:3460` `(bhStrength > 0.5f)`, raytracer `:3540` `(bhStrength > 0.5f \|\| oscAmount > 0.01f)` — and the log shows **`bhStrength = 0.95` at `r_s/r = 0.984`, i.e. BEFORE the latch ever set.** All gates were already open. The latch rounds the last 5% up and switches nothing on. ⭐ **What actually declares the hole:** `r_h = 0.1172` sim encloses **73,770 M☉ (12.4% of the field)**, and `r_s(73,770) = 1.6825e-6 × 73,770 = 0.1241 > 0.1172` → ratio **1.059**. The criterion is being **genuinely satisfied by DIFFUSE mass** — **726 `[GRAV]` samples read `hole=1.00L` with `seeds=0` and `Mmax=50.0`**; the first `seeds=1` arrives only at `Mmax=91.7`. 🚨 **ROOT CAUSE IS SCALE, NOT LOGIC:** `r_s(594,276 M☉) = 0.9999 ≈ **1.0 sim**`, so the field spawns at `R_DISK = 18 sim` = **18 Schwarzschild radii of its own total mass**, with collapse unopposed (**B10**). A centrally-concentrated cluster that small *must* reach `r_s/r ≥ 1` within seconds — **the initial condition is already nearly a black hole.** ✅ **CLOSED BY HIS CALL 2026-08-08 16:52:31: "we still have the starting gravity pull so it makes sense that it's looking weird cause it's scripted, it's not that deep."** He is right and it is in the source: the inward drag is **authored**. `particles.metal:775` `fricRest = pow(0.99f, dt)` — *"the gentle drag IS the accretion mechanism (slow inspiral toward the mass centre)"* — and `:780` `pow(0.95f, dt)` on release, *"e-fold ~20 s, **replaces the deleted scripted collapse**"*. So an early central concentration is the drag doing exactly what it was written to do. **`hole=1.00L seeds=0` is authored behaviour reported honestly, not a fake hole. No fix. Row closed, "fake hole" framing retired.** ⚠️ **My three proposed "fixes" (compactness test / change `R_DISK` ratio / accept) were scope I invented for a non-problem.** | ✅ closed — not a bug | Measured: `logs/A1fix_CAS_20260808_022500.log`. Code: `renderer.mm:3064` the latch, `:3037` the EMA, `:3029` `honestTarget`, `:2905-2911` the shell loop; `units.h:85` `kRsSimPerMsun`; `particles.cpp:107` `R_DISK = 18` | **?** (was **S**) |

> ~~A3①②③ are three independent bugs that all present as "BH FORMED when it isn't".~~ **Corrected 2026-08-08 16:52:31 — A3③ is CLOSED and was never a bug** (authored drag, his call). **Two remain: A3① and A3②.** They are still independent of each other; fixing one does not touch the other.

| **A5** | ⏱️ **THE FUSE IS A 3–16 MINUTE STOCHASTIC WAIT — A SHOW RISK, NOT A BUG.** Nothing visible happens until one body crosses `M_BH_SEED = 50.0` (`particles.metal:185`), and **that threshold sits exactly on the IMF ceiling**: `imfMassOfId` (`:131`) draws Salpeter −1.3 over **0.08…50.0**, so the heaviest star that can SPAWN is ~49.91 and `Biggest body` reads flat at ~49.9 until a **rare heavy–heavy merger**. Verified by porting the IMF exactly (reproduces the field total to 0.03%: 594,084 vs the log's 594,276): of 2,000,000 stars, **3,334 exceed 10 M☉ (0.167%) and only 687 exceed 25 M☉ (0.034%)**. Ordinary merging runs fine the whole time — one run logged **68 merges with `Mmax` never moving**, because all 68 were light pairs. Measured crossings: **3.5 min · ~8 min · 10+ min (quit) · 16 min (never)**. ⭐ **PROPOSED FIX — MASS SEGREGATION, and it is missing physics, not a cheat:** mass is `imf::massOfId(i)` (`particles.cpp:307`), a pure function of slot index, while placement is an INDEPENDENT component draw (disk 75% / nucleus 10% / halo 15%) — so the 687 heavyweights are scattered at random and only ~10% land in the nucleus. Real clusters are mass-segregated (massive stars sink by dynamical friction). Making *placement* mass-dependent concentrates them in the dense nucleus and the fuse shortens by itself. 🚨 **Leaves `imfMassOfId` byte-identical on the GPU — which is REQUIRED, because the A2 refund depends on recovering spawn mass from the slot id.** 🚨 **Do NOT instead widen the merge cross-section — an uncapped capture radius is exactly what caused the A1′ runaway.** | ⬜ **NEW — his ask, "can we make the fuse faster"** | `particles.metal:185` `M_BH_SEED`, `:131` `imfMassOfId`; `particles.cpp:307` mass, `:132-134` the component draw | **M** |
| **A6** | 💧 **REFUND FLOOR LEAK — THE GUARD CANNOT DETECT ITS OWN FAILURE MODE.** In run 1, **17 `[REBIRTH]` samples charge a withdrawal while the hole is ALREADY at the 50.0 floor** (`withdraw=0.1 … hole=50.0`). The guard is `(wdraw > gMaxMass)` at `renderer.mm:3096` — `0.1 > 50.0` is false, so it never flags. Refunds keep being paid after the hole has nothing left, i.e. **mass is created**. ⚠️ Direction matches run 1's **+1,543 M☉ (+0.260%)** drift; **magnitude NOT reconciled — candidate cause, not a conclusion.** Distinct from **B5** (−280 M☉): this one is positive and 5× larger. | ⬜ **NEW** | `renderer.mm:3096` the guard; `particles.metal:731` `mass = imfMassOfId(id)` | **S** |
| **A8** | ❓ **`feed` RETURNED NONZERO FOR THE FIRST TIME EVER.** Every run ever logged showed `feed=0/0.0 scan=0` — the seed-feed path had never scanned once, and that was established as a standing fact. Run 2 (10M) logged **`seeds=6 feed=2/0.3`**. Either the path finally engages at higher particle counts, or something else changed. **Unexplained; re-measure before anyone relies on the old "feed never fires" claim.** | ⬜ **NEW** | `logs/A2_refund_20260809_202105.log`, final `[GRAV]` | **S** to settle |


### N3. B1 and B9 out of §B. PHYSICS

*Moved from `BOARD.md` lines 427–436 — B1 is the horizon test centred on mass (same fix as A3②); B9 is the merger flash.*

| B1 | Centre the horizon test on the mass, not the origin | ⬜ | Same as A3② — **these are the same fix.** Folded. | — |
| B9 | Merger flash is invisible — temp baseline 5.29e11 makes a `+2.0` flash a 1e-11 relative change | ⬜ | not re-verified — from 08-03 | **S** |


### N4. C12. DOPPLER — reopened by his order 2026-08-11

*Moved from `BOARD.md` lines 490–524 — relativistic beaming of the disc; §4b of this board already carries the honest beaming law.*

#### 🌈🚨 C12. DOPPLER — REOPENED BY HIS ORDER, 2026-08-11. *"the doppler thing needs to be restudied. we need it its science we did it wrong"*

🔄 **THIS OVERRIDES THE STANDING "NEVER RE-PROPOSE DOPPLER-AS-HUE" RULE (2026-06-26).** Newest signal wins; nobody is to quote the old verdict back at him. ⭐ **And the old rule was mis-written, which is WHY it needs overriding — see the rule amendment at the end of this file.** What he rejected in June was a **flat colour tint that read as a "2D filter"**. He never rejected relativistic Doppler. The mechanism was wrong; the physics was always right.

##### C12a. WHAT WE DID WRONG — four errors, all now identified

| # | Error | The correct physics | Evidence |
|---|---|---|---|
| **1** | 🚨 **THE COLOUR WAS A TINT. This is the real scientific error.** `dopplerColor = max(0.25, 1 + K·v_los)` multiplied an already-computed RGB by a scalar — which only brightens/desaturates. That is why it read as a flat filter. | **A Doppler-shifted blackbody IS STILL A BLACKBODY, at `T_obs = δ · T_emit`.** The Planck shape is preserved under a frequency rescale — it is why the CMB dipole is a *temperature* dipole, not a colour cast. **So the shift must rescale the TEMPERATURE and re-evaluate `blackbodyRGB`, never multiply the colour.** We already have `blackbodyRGB` (`:201`) and `unifiedKelvin` (`:448`) and already call them (`:1423`, `:1596`). | deleted at 12:31:44, §H7 |
| **2** | **`1 + K·v_los` is not the Doppler factor**, and `K = 5.0` was a taste knob. First-order only — and our disk runs at **0.409c** (measured, A1′), where first order is visibly wrong. | **δ = 1 / (γ(1 − β·n̂))**, `γ = 1/√(1−β²)`. Zero free parameters. | `K_COLOR` deleted; §G5's "fixed ratios" class |
| **3** | **The beaming exponent is invented.** `pow(beam, DOPPLER_EXP)` with `DOPPLER_EXP = 1.4f` (`:297`) and `K_BEAM = 0.8f` (`:296`) — neither derived from anything. | **`I_ν/ν³` is a Lorentz invariant ⇒ bolometric intensity ∝ δ⁴.** Band-limited it is `δ^(3+α)`. Not 1.4. | `render.metal:296-297`, `:1354` |
| **4** | ⭐ **GRAVITATIONAL REDSHIFT IS MISSING — AND WE ALREADY COMPUTE IT.** Near the hole both shifts apply. | **`g_total = δ_doppler × √(1 − r_s/r)`.** That square root is *literally* `tDilate` at `render.metal:782`, sitting unused for this purpose. **The honest version costs almost nothing new — it combines two things the file already has.** | `render.metal:782` |

##### C12b. ⭐ AND THE VELOCITY IS FAKE TOO — the real one is 190 lines above it

The block reconstructs an **analytic** `vOrbit` from a Kerr `Ω(r) = 1/(r^1.5 + KERR_A)` law at the *spun* position. But `render.metal:1126` already computes **`float3 velReal = (in.posW.xyz - in.prevW.xyz) * 120.0f`** — the particle's true per-frame velocity, used by the streaks. **The Doppler is being driven by a law instead of by the field's own motion, while the field's own motion is already in scope.** Using `velReal` also makes the effect correct for matter that is *not* on a circular orbit — infalling, ejected, or unbound — which the analytic law gets wrong by construction.
⚠️ **One honest caveat, stated before building:** `velReal` is a one-frame finite difference, so it inherits the analytic playback's rotation when bit20 is on (`:586`). That has to be handled or the playback's fake speed feeds the Doppler — **which is exactly the ~176× seam bug the 2026-07-16 comment records.** The fix is to take the difference *before* the playback rotation, not after.

##### C12c. THE HONEST SHAPE — every number derived, nothing to tune

    β    = velReal / c_sim                       (c from spacetime.h, not a constant here)
    n̂    = normalize(cameraPos − worldPos)
    δ    = 1 / (γ · (1 − dot(β, n̂)))              γ = 1/√(1−|β|²)
    g    = δ · sqrt(1 − r_s/r)                    ← the gravitational half, = tDilate
    T_obs = g · T_emit                            → blackbodyRGB(T_obs)   ← COLOUR
    I    ∝ g⁴                                     → out.luminance         ← BRIGHTNESS

**Colour comes from temperature. Brightness comes from δ⁴. Nothing multiplies a colour.**

⚠️ **THE LIMIT THAT WILL DECIDE WHETHER THIS IS VISIBLE, stated now rather than discovered later:** `blackbodyRGB` clamps to **1000–40000 K** and its blue branch is nearly flat above ~6600 K. Plasma temperature in our field reaches **~5×10¹¹ K**. **At those temperatures every particle is already pinned to the top of the ramp and NO shift of any size will change its colour.** So the effect can only ever be visible where `T_emit` sits inside the ramp's dynamic range. **This is a representation limit, not a physics limit** — and it is the same wall as C3 and A9. It may mean the honest answer is a *mapped* temperature scale, which is a design question for him, not something to guess.

| # | Item | State | Evidence | Cost |
|---|---|---|---|---|
| **C12** | **Relativistic Doppler, done properly** — δ from the real per-particle β, T_obs = g·T_emit through `blackbodyRGB`, I ∝ g⁴, gravitational term from the existing `tDilate`. **Zero free parameters; `K_COLOR`/`K_BEAM`/`DOPPLER_EXP` all die.** | ⬜ **NEW — studied, NOT built. Needs his call on the temperature-range limit first.** | `render.metal:201`, `:296-297`, `:782`, `:1126`, `:1353-1354`; `spacetime.h` for c | **M** |



---

**Last Updated:** 2026-08-22 01:34:32 (BH4 — §2's two lens blend sites re-verified in source and their closure carried through to §5(A); the void-slider-A/B consequence promoted to a standing callout. §N added 2026-08-19 00:14:12; §0 still carries the verification stamp)
**Live tree:** `SPACE-SYNTH-TUBE-killtube`, branch `kill-the-tube-2026-08-11`
**Build:** `bash package_macos.sh` — never bare `make`. Launch `--env SS_FULLSCREEN=1`, always.
