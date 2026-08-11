# HANDOFF — GRID + SCALE AUDIT, THE CULL FIX, AND ONE DISPROVEN HYPOTHESIS

**Written:** 2026-08-11 03:45:28
**Commit:** `ea2cfba` — **nothing committed today.** Everything below is uncommitted working tree.
**Bundle:** `SpaceSynth.app/Contents/MacOS/SpaceSynth` @ **2026-08-11 03:36:33** (binary AND metallib both newer than every source — the shader change is genuinely deployed)
**Running at handoff:** pid 16319, fullscreen, launched 03:36:58
**Board:** `docs/BOARD.md` §G is the live version of this. Read the board first.

---

## 0. READ THIS FIRST — the two things a cold reader will get wrong

**1. The thing he actually cares about is NOT the one I fixed.** I shipped a correctness fix to the horizon capture cull. Ninety seconds later he told me the real problem:

> *"its not thta i see them its that theyre still computed even if only liek 5 thousand are out 2 mio get rendered thats the fucking problem"*

The cull lives **inside `particle_vertex`** (`render.metal:541`, cull at `:665`). It is a **late discard, not a skip** — all 2M vertex invocations run and pay full cost; zeroing `pointSize` only saves rasterisation. **§G6 on the board. Not started, no design agreed.** Do not mistake the shipped fix for an answer to this.

**2. I had a hypothesis, it was good, and my own probe killed it.** See §3. It is recorded so nobody spends a night re-deriving it.

---

## 1. WHAT SHIPPED — capture cull on the raw horizon (board §G8)

**Measured cause.** On the frame a hole forms: `raw = 0.0781`, `smooth = 0.0130`. The cull was gated on the eased value (`renderer.mm:1610`), which converges at ×0.03/frame (`renderer.mm:1494`) — so for ~2 s after every formation the cull radius was up to **6× smaller than the true horizon**, and every shell between the two was inside the real hole and still drawn.

**The change.** New appended field `horizonRRaw` on `CameraUniforms`, fed from `lastHorizonR` at **both** camera-build sites in `renderer.mm`. The cull reads it for both its gate and its radius.

**What was deliberately NOT changed.** `cam.horizonR` still carries the eased value and still drives the hole pass, membrane, pose and lens **radius**. The easing is not a bug — it exists because the probe steps every few seconds and the drawn hole *"visibly JUMPED size"* (`renderer.h:211`, 2026-07-19). Only the yes/no cull moved to truth, which makes the render agree with the physics, which already used raw (`renderer.mm:1980`).

**⚠️ The layout guard fired, and it caught a real hazard.** Appending one float gave `sizeof(CameraUniforms)` = 276 in C++ but **288 in Metal** — MSL rounds struct size up to its largest member alignment (16), the C++ half declares the matrix as `float[16]` (alignment 4) and does not round. Field offsets still agreed, but one `sizeof` number could no longer be true on both sides. **Fixed by padding the tail to 288**, the same pattern `PostFXUniforms` already uses (`gradePad0/1/2`). The rule is now written into the struct for the next person who appends.

**Verification:** 79 samples, max `ratio` 5.371, **0 frames with a real hole and the cull off.**

**⚠️ Honest limit on my own number.** The formation-frame gap in the verification run was **1.6×**, not 6×. The probe samples every ~2 s and lands at different points on the easing curve. The 6× catch was real but it was a lucky sample; I should not have implied it was typical. What is solid: raw always leads smooth during the easing window, and the hole-with-no-cull count is zero.

---

## 2. WHAT THE AUDIT FOUND — six questions, his brief 2026-08-11 03:05

Full tables on the board (§G1–G7). The load-bearing findings:

**Two live unit systems.** `spacetime.h` anchors on `kMfieldMsun = 5.94276e5` M☉ ⇒ **1.75504e9 m/sim**. `physics_constants.h` anchors on `BH_SGRA = 4.297e6` M☉ ⇒ **1.27e10 m/sim**. **7.23× apart**, both live — the second is `#include`d by `main.cpp:16` and read at `:1054`, and `renderer.mm:~1976` hardcodes `gmSim(4297000.0)` into the physics. Its own header still says *"DECISION PENDING."*

**Three contradictory hardcoded BH spins** — `a=0.99` (`particles.metal:245`), `KERR_A=0.5` (`render.metal:274`), `a*=0.10` (`physics_constants.h:113`). The field's own angular momentum is never measured to derive any of them.

**Time warp multiplies dt with no compensation.** `main.cpp:2537`, `simDt = 0.0165f * timeWarp`. `main.cpp:2530` admits *"Above ~8× the Verlet integrator coarsens."* He runs 64×. `units.h:20` describes the accuracy-governed cap that would fix it; it was never built.

**The accuracy meter is probably measuring a path that isn't running.** Its computation sits inside the `bit9` sub-step branch (`particles.metal:1642`) — the legacy path that `bit10` PM gravity **overrides** (`app_state.h:60`). It is diagnostic-only (`main.cpp:1199`, *"nothing capped yet"*), sub-steps cap at 32, and it turns red above **0.01% of live particles** = 200 of 2M. **The threshold, not the physics, is why it glows.**

**Structural root of the origin-lock:** `SpatialHashUniforms` (`renderer.h:341`) has **no centre field**. Every grid built on it is `[−halfExtent,+halfExtent]` about the origin by construction.

**Two holes is impossible because the hole is not an object — it is a query result.** One `bhX/bhY/bhZ` (`renderer.h:329-332`), one scalar `horizonR` (`:371`), one radial profile. No identity, no lifetime, no slot for a second. The *seed* layer already went plural (`spatial_hash.metal:73`, up to 256 seed ids) — that is the seam where two holes would have to be built.

---

## 3. ❌ DISPROVEN — do not retry this

**The hypothesis:** the collapsed clump (49.6% of field mass) drifts in and out of the ±4.0 sim AMR box, so gravity falls back to the 1.0 sim coarse grid — coarser than the object's own `r_s` = 0.4956 sim — killing the horizon, which explains both the broken rotating BH and particles drawn inside the hole.

**It was measured and it is wrong.** Controlling for collapse state:

```
                         IN box              OUT of box
dispersed  ratio<0.3  : raw==0 33/33 (100%) | raw==0 34/34 (100%)
AT HORIZON ratio>0.8  : raw==0  0/53   (0%) | raw==0  0/2    (0%)
max ratio seen while OUT of the box = 4.955   ← fully formed hole, outside the grid
```

`horizonR` is explained **entirely** by `ratio`, exactly as designed. The first correlation I reported (94% zero while OUT vs 38% while IN) was an artifact — the OUT samples happened to be the dispersed ones.

**The origin-lock is still real as a structural fact** (the struct genuinely has no centre field; the clump genuinely leaves the box). **Its consequence is UNPROVEN.** I also overstated a through-line — I told him five of six issues traced to the origin-lock. That is not established.

---

## 4. A9 EXTINCTION — FAILED, his verdict 2026-08-11 02:35:00

> *"look its still a rick and morty eye just buzzy stuff we dot have any science in place here"*

Mark it **failed**, not partial. It was built to answer *"why does matter at high concentrations look like ass"* and it does not.

**Why, measured rather than guessed:** the gate is already saturated (`smoothstep(150,1500,count=34835) = 1.000`), so absorption is at maximum. The object is **~1 cell across** and the march steps `1.5×cellSize` — the **first sample is already outside it**, so every particle in the clump gets the same τ. **Flat by construction.** Extinction was a render answer to a physics/resolution hole.

**Retraction:** my *"~32 fps, roughly half the baseline"* perf claim is withdrawn. 41 samples: **mean 53.3**, min 16.9, max 90.0, against a 42–57 baseline. I read a transient as a level.

---

## 5. THE DEGENERACY-PRESSURE DEAD END — killed before it was built

He said "go" on adding electron degeneracy pressure. **I did not build it, because it would have been a no-op**, and burning his verdict on a no-op is the failure mode this project keeps hitting.

- `scatter_particles` caps at **32 particles per cell** (`spatial_hash.metal:333`). The top cell holds **767,032**. An SPH-path term reaches 0.004% of the mass that matters.
- The physics kills it properly: `a_deg / a_grav = 1.58e-05`. Degeneracy is **63,000× weaker than gravity** there, because the clump is **2.1×10⁵ × the Chandrasekhar limit**. Electron degeneracy stops supporting anything above 1.4 M☉; this is 294,518 M☉.
- The honest answer to *"what happens when the density is that high"*: **it collapses to a black hole and nothing stops it** — that behaviour is correct. Measured ρ is **0.51×** the black-hole density for that mass.

**⚠️ Therefore `[DENSPROBE]`'s `regime` label is misleading and should be fixed before anyone trusts it.** It classifies by **density alone** and called that clump a "WHITE DWARF". Density alone does not set the regime — mass does too.

---

## 6. LEFTOVER BS (board §G7)

- 💀 **Chladni gradient LUT is dead code that still compiles.** `GradientLUT`/`makeLUT`/`sampleLUT`/`LUTCache` — zero callers outside `src/core/lut.cpp`; still in `CMakeLists.txt:16`. **`CLAUDE.md` lists it as "Key Files to Understand First #2."**
- ⚠️ **`EIGEN_R` comment wrong by 2×** — `particles.metal:504` says `// 3.0 sim units`, value is **6.0**. `EIGEN_L` is **12.0**, not 6.0. *(4th sighting of comment decay.)*
- 🚩 **That stale comment already corrupted a probe.** `renderer.mm:2628` sizes `[GRIDPROBE]`'s scan from the wrong cavity radius, so it scans **exactly the cavity and none of its surroundings** — the thing its own comment says it exists to capture. **First case here where a stale comment broke a measurement, not just a claim.**

---

## 7. METHOD RULES EARNED TODAY

1. **Check whether a proposed change can physically matter BEFORE building it.** Degeneracy pressure passed code review and failed arithmetic. Two minutes of Python saved a wasted verdict.
2. **A raw correlation is not a result — control for the obvious confound.** My box-vs-horizon finding looked decisive at 94% and evaporated the moment I conditioned on collapse state.
3. **Keep the instrument in step with the change it measures.** When the cull moved to raw, the probe's `cullOn` still read the eased value — a probe reporting the old gate would have quietly certified a fix it was no longer measuring.
4. **A regime label computed from one variable will lie when the regime depends on two.** Density alone said white dwarf; mass said black hole.
5. **Trust the layout guard over your own append.** It caught a C++/MSL size divergence that offsets alone would not have shown.

---

## 8. OPEN, IN THE ORDER HE NAMED THEM

1. **§G6 — the 2M vertex cost.** His stated real problem. Not started.
2. **Unified scale** — one unit system, one anchor, derived spin, accuracy-governed warp. Untouched.
3. **Density/pressure/extinction resolution** — still 1.0 sim with no fine path. Governs the buzzy-clump look; independent of the BH work.
4. **Rotating BH** — `render.metal:782` computes dilation from the **origin** while the hole sits at r=3.8–5.9 sim. Code reading, no A/B run.
5. **Fix `[DENSPROBE]`'s regime label** before steering by it.
6. **`[GRIDPROBE]` scan radius** — mis-sized by the stale `EIGEN_R` comment.

**Nothing is committed past `ea2cfba`. No commit without his explicit order.**
