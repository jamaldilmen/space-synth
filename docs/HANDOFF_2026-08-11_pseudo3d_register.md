# HANDOFF — THE PSEUDO-3D REGISTER, THE COST MODEL, AND FIVE DEAD ENDS CUT

**Written:** 2026-08-11 11:48:24
**Commit:** `ea2cfba` — **nothing committed.** Everything below is uncommitted working tree.
**Bundle:** `SpaceSynth.app/Contents/MacOS/SpaceSynth` @ **2026-08-11 04:15:06** (binary AND metallib newer than every source)
**His verdict on the build:** *"stable 60 FPS"* (2026-08-11, after the dead-code removal)
**Board:** `docs/BOARD.md` §H is the live version of this. Read the board first.

---

## 0. READ THIS FIRST — the one-line summary a cold reader needs

**The physics is 3D. The render is not.** Every fake found tonight lives in the
render path, and they cluster almost entirely in the black hole. The Chladni
eigenmode — the thing everyone assumes is a 2D plate pattern — is the most
honestly three-dimensional part of the engine. See §3.

**And the thing he named as "the real problem" is not where the time goes.**
§G6's 2M vertex invocations cost 2.4–3.3 ms. The Poisson solver costs ~6 ms.
Compute is 76% of the frame. See §2.

---

## 1. WHAT SHIPPED — five dead ends removed, one refused

All five were verified unreachable **before** deletion, not after. App runs clean,
hole forms, no errors, and his verdict is stable 60 fps.

| # | Item | Evidence it was dead |
|---|---|---|
| 1 | `render.metal` — the **Y-axis time-lapse twin** (~45 lines) | `bhDiskAxisY` is `0.0f` at all seven sites (`renderer.h:205` + `renderer.mm:1561, :1599, :1602, :1833, :1871, :1874`), never written elsewhere. `> 0.5f` could not be true. |
| 2 | `render.metal` — the **`bhVisible = false` cull** | Constant-false gate; its `length(in.posW.xy)` ran for every vertex of every frame anyway. |
| 3 | `renderer.mm` — **`Renderer::render(config)`, 240 lines** + header decl | `main.cpp:2548` is the only call site in the tree and passes a viewProj. |
| 4 | `renderer.mm:3327` — **posePhase host gate** | Kernel self-gated but still launched 2M threads every rendered frame. |
| 5 | `src/core/lut.cpp` + `lut.h`, out of `CMakeLists.txt` | Zero callers; nothing included `core/lut.h` but `lut.cpp` itself. |

**⚠️ Read #4 before touching `pose_phase_advance`.** The host gate mirrors the
kernel's opening test term for term, against the same values the camera was built
from that frame: `bit20`, `bhDiskGMSmooth` (→ `cam.bhDiskGM`, `renderer.mm:1655`),
`renderPhaseSmooth` (→ `cam.envelopePhase`, `:1727`). Ordering verified: `:1655`
precedes `renderWithCamera` at `:1685`. `bhDiskAxisY` is deliberately **omitted**
because it is a constant-true term. **If the kernel's gate changes, change this one
in the same commit** — a host gate stricter than the kernel silently freezes the
playback phase and nothing errors.

**Why #3 mattered beyond line count:** it was compiled and grep-able but never
executed, so it kept answering questions about the live renderer with stale code.
**Two claims that reached the board were read out of that dead body** — a hardcoded
`cameraPos`, and a shadow radius still gated to ortho after the live path at
`:1783` had dropped that term. Deleting it removes the trap, not just the bytes.

**⚠️ My own error, logged:** deleting #3 I went off by one and removed the *live*
overload's signature line. Caught on the next grep, restored, build links. The
lesson is the boring one — after a line-range delete, grep for the symbols that
were supposed to survive, not just the ones that were supposed to go.

**REFUSED — `spatial_hash.metal:333`, the 32-per-cell scatter cap.** It is a
**live design limit, not dead code**, and it is load-bearing: `cellStarts` is a
prefix sum of live counts, so writing past 32 overflows into the next cell's
region, the same star lands in two lists, and mass is *created* (`Mlive` tripled
at 50k dead — the note above it records the measurement). Raising or dropping it
changes SPH neighbour sampling and the merge path. That is a physics decision, not
a cleanup. **The waste is real and worse than first reported:** for the
767k-particle cell, ~767,000 threads hit `atomic_load` on **one address** and
discard — contention on a single cache line, not just wasted arithmetic.

**What the five deletions bought in frame time: nothing measurable.** Like-for-like
window vs baseline: compute 25.94 vs 22.43 ms, render 7.30 vs 6.49 — the *new*
build reads slower, and at n=7 against a ~1 ms noise floor that is not a
regression either. Expected: four of the five were never executed, and the
posePhase gate only skips frames before the first hole, which forms early.
**Control that proves the deletions changed nothing:** run D (shader untouched,
long run) and run E (shader modified, long run) land at render 17.51 vs 19.28 ms
at the same sim age. The value here is that the code stopped lying.

---

## 2. THE COST MODEL — measured, five runs

Fullscreen, 2M particles, `caffeinate -dis`, hole latched (`bhStrength=1.00 LATCH`)
in every run, so the star pass ran at `instanceCount=2` = **4M invocations**.

| Run | Config | Compute | Render+PostFX |
|---|---|---|---|
| A | baseline (n=7) | 22.92 | 7.31 (med 6.49, min 6.00) |
| B | star pass not encoded (n=19) | 21.87 | **4.02** (max 4.77) |
| C | `SS_SOR_SWEEPS=8` (n=25) | **16.74** | 8.32 |
| D | `SS_SPH_SKIP=density,pressure,force` (n=46) | 15.20 | 15.76 ⚠️ |
| E | after dead-code removal (n=32) | 23.21 | 15.78 |

**Star pass = 2.4–3.3 ms.** A and B differ only in whether one draw is encoded;
their ranges do not overlap (A min 6.00 > B max 4.77). This is the cleanest number
of the night, and it **bounds §G6**: no cull or compaction scheme can win more than
this, because deleting the pass entirely *is* this.

**Coarse Poisson SOR ≈ 6 ms — roughly double the whole star pass.**
`renderer.mm:2495` runs **80 sweeps × 2 colours = 160 compute encoders per frame**,
each dispatching all **2,097,152 cells**. `poisson_sor` (`spatial_hash.metal:1173`)
has **no empty-cell skip**: the grid is ~99% vacuum and every cell is swept 160×
per frame regardless. The code already suspected it — *"80 sweeps = 160 compute
encoders/frame — encoder overhead is a prime suspect."* The saving is if anything
**understated**: run C sat at a *denser* state than A (Mtot(<5) 2.8e5 vs 1.7e5),
which costs more, not less.

**⚠️ Run D yields no number and I am not claiming one.** Killing SPH pressure let
the field collapse to a different shape entirely (r50 3.83 vs 0.059 sim) and
Render+PostFX *quadrupled*. What it does establish: **fill cost is state-dependent
and can dominate everything else** when the field collapses into a small screen
area. That is a separate lead from §G6 and probably a more valuable one.

**Noise floor:** ~1 ms on compute (A vs B, where compute should have been
identical). Treat anything under that as nothing.

**⚠️ Method note.** These runs are **not duration-matched** — A got 10 profile
prints, D got 49. The sim ages differently, so cross-run compute numbers carry a
state confound. Only A-vs-B is a clean isolation. Duration-match the next set.

---

## 3. THE PSEUDO-3D REGISTER

**The physics is genuinely 3D.** The cavity eigenmode is
Ψ(ρ,θ,z) = J_m(k_ρρ)·cos(mθ)·cos(k_z z) (`particles.metal:460`), the rest-state cap
is a true 3D sphere, and the horizon test is a real 3D
`dot(relBH0, relBH0)` (`particles.metal:629`). **Every fake below is in the render.**

Ranked by how much of the "it doesn't read as 3D" complaint each one can plausibly
own.

| # | Site | What is fake | Weight |
|---|---|---|---|
| **P1** | `renderer.mm:1033` `depthWriteEnabled = NO` | **The structural one.** 2M points in a 3D field and **nothing occludes anything**. Depth test is `Less` against a buffer no pass ever writes. Every "in front / behind" on screen is additive blending, not geometry. This is why the 2026-07-24 geodesic paint had to be withdrawn — no later pass has depth to order against. **Fixing this is the precondition for most of the rest.** | ★★★ |
| **P2** | `render.metal:1257` `dist = mix(out.position.w, cam.cameraPos.w, isOrtho)` | In ortho — **the default** (`renderer.h:54`) — every one of the 2M particles is handed the *same* camera distance. **There is no per-particle depth at all.** It drives point size and the fragment `fadeAmount`. A depth cue that is constant across the whole field cannot produce depth. | ★★★ |
| **P3** | `renderer.mm:1783` `cam.bhShadowNdcRadius` | The hole's size is a **screen-space NDC disc radius** computed on the CPU through the ortho world→NDC map. Its own comment states the perspective error: **~2.897× too small**, and `d` is camera→origin, not camera→hole, so the error grows as the seed wanders. | ★★★ |
| **P4** | `render.metal:583`, `:586`, `:532` | The BH disk playback rotates **`.xy` only, about Z**, and drives Keplerian Ω from `rxy = length(posW.xy - c2)` — a **2D radius**. A particle high above the plane gets the same Ω as one in it. **The disk is an annulus pretending to be a disk.** | ★★ |
| **P5** | `render.metal:576` | That block's comment says the playback is **"DEFAULT OFF"**. `app_state.h:56` sets `uiTogAnalyticSpin = true` — **DEFAULT ON**. So **P4 is the live path**, not an A/B path. **5th sighting of comment decay**, and this one mislabels which renderer you are reading. | ★★ |
| **P6** | `render.metal:796` `rDil = length(in.posW.xyz)` | Time dilation measured **from the origin** while the hole sits at r=3.8–5.9 sim. The shear pivots around a point the hole is not at. (Board §G5; re-confirmed live.) | ★★ |
| **P7** | `spatial_hash.metal:262` `density_heatmap` | **Collapses the 128³ grid to a 128×128 `texture2d` by averaging along Z** — a projection, axis-locked to world Z regardless of camera. Its normalisation comment cites *"800k in 256x256"*; the app runs 2M on 128³. **And nothing samples the texture** — it is never bound as a fragment texture anywhere. Currently gated off (`collisionsEnabled = false`), so it costs nothing today. **Latent dead end + a 2D answer to a 3D question.** | ★ |
| **P8** | `render.metal:941` | The lens is real 3D thin-lens geometry, but rests on *"Ortho camera: transverse world lengths ≡ angles, lens plane through the origin."* True in ortho, false in perspective. | ★ |
| **P9** | `render.metal:157` `velDir2D` / `strDir2D` | Streaks and webbing are **screen-space 2D** vectors; webbing gates on `screenDist < 0.15` NDC, so two particles far apart in depth but adjacent on screen get strung together. | ★ |
| **P10** | `render.metal:1261` | Sprites are point impostors — *"the sphere impostor needs ~20+ pixels to read as a 3D sphere."* A painted sphere, not geometry. | ★ |

**The through-line, stated as a hypothesis and NOT as a finding:** P1 and P2 are
the same fact wearing two hats — the renderer has no notion of per-particle depth,
so it can neither order particles nor shade them by distance. P3–P6 are the black
hole inheriting that: a screen-space disc, a 2D radius, an origin-centred dilation.
**This is a hypothesis about a common cause. It is not measured.** The last time a
through-line like this was asserted here ("five of six issues trace to the
origin-lock") it did not survive contact with a controlled measurement.

---

## 4. CHLADNI — NOT faking 3D. This one is honest.

Asked directly, answered from the code rather than the comment.

`particles.metal:2272`:
```
int   pAx  = 2 + ((mm + nn) % 3);     // NEVER 0, never 1
float kZ   = float(pAx) * M_PI_F / EIGEN_L;
float zeta = pz + 0.5f * EIGEN_L;      // phase referenced to the WALL, not the origin
float cZ   = cos(kZ * zeta);
float psi  = JJ.x * cA * cZ;           // Ψ = J_m(k_ρρ)·cos(mθ)·cos(k_z ζ)
float dPdz = JJ.x * cA * (-kZ * sZ);   // ∇Ψ has a REAL z component
```

- `pAx` is **never 0**, so `kZ > 0` always and `cos(k_z ζ)` genuinely varies along z.
  A z-invariant field — a 2D pattern extruded — would need `pAx == 0`. It cannot be.
- `pAx` is **never 1** by construction. That was deliberate: `pAx=1` is a single
  axial node = a flat disk = the "eye" seen edge-on, and the old `1 + ((m+n)%3)`
  produced exactly that for low C (m=0, n=3). `2 + (…)` fixed it.
- The axial phase is referenced to the cavity **wall**, not the origin, so the p
  nodal planes sit strictly *inside* the can rather than collecting on the end faces.
- The force `-contrast·Ψ∇Ψ` uses the full 3D `grad`, including `dPdz`, and the
  per-id acoustic `contrast` sign spreads the population across nodes *and*
  antinodes rather than collapsing every particle onto one Ψ=0 skin.

**Conclusion: the Chladni field is a real 3D cylindrical cavity mode.** If the
play state reads flat on screen, the cause is in the register above (no depth
write, no per-particle depth), **not** in the eigenmode.

**Separate, still open, and NOT a 3D problem:** the 2026-07-28 audit's finding
stands — `ridgePull` uses the **sculpt** gradient rather than the eigenmode ∇Ψ,
and there is no node dissipation. And C = m=0 = circles by construction.

---

## 5. CORRECTIONS TO THINGS PREVIOUSLY WRITTEN DOWN

1. **"The hole is hard-gated to ortho" — NO LONGER TRUE.** The `config.orthoMode &&`
   term was removed from the live path in the A0 test (`renderer.mm:1783`). The
   version that still carries it lived in `render(config)`, which had **zero
   callers** and is now deleted. The scale in perspective is still wrong (P3).
2. **"SOR is the monster, disproven" — I said that too early.** I called it
   disproven off 9 samples; with 25 the saving is ~6 ms and real. **Read the whole
   run before writing a verdict.**
3. **§G6 reframed.** Still true that 4M vertex invocations run every frame. No
   longer open how much that is worth: 2.4–3.3 ms, ~10% of the GPU frame.

---

## 6. METHOD RULES EARNED TONIGHT

1. **After a line-range delete, grep for what was supposed to SURVIVE.** An
   off-by-one removed the live function's signature; only the survivor grep caught it.
2. **Read the whole run before calling a result.** See §5.2.
3. **Duration-match A/B runs.** Cross-run compute numbers here carry a sim-age
   confound that could have been designed out for free.
4. **"Dead code" and "a design limit" are different things** and only one of them
   is safe to delete on a cleanup instruction. The scatter cap looked like waste
   and is load-bearing.
5. **A self-gating kernel still launches every thread.** A gate in the shader is
   documentation; a gate on the host is a saving.

---

## 7. OPEN — first to-dos

1. **P1 + P2 — give the renderer real per-particle depth.** Depth write for the
   particles, and a true per-particle distance in ortho instead of the constant.
   This is the precondition for P3–P6 and is the honest reading of *"bring it fully
   into the 3rd dimension."* **No design agreed — do not start building without one.**
2. **P3 — the shadow radius divisor.** Smallest self-contained fix in the register;
   the comment already states the correct derivation and the deferral was deliberate.
3. **P5 — correct the `render.metal:576` comment** so the next reader knows which
   playback is live. Free, and it stops the 6th sighting.
4. **The SOR sweep count** — ~6 ms, one knob (`SS_SOR_SWEEPS`), already instrumented.
   Needs an accuracy verdict, not just a perf one: fewer sweeps = a less converged Φ.
5. **The fill-cost lead from run D** — overdraw when the field collapses, currently
   unquantified and possibly larger than everything in §2.
6. Carried from §G: unified scale · `[DENSPROBE]` regime label · `[GRIDPROBE]` scan
   radius mis-sized by the stale `EIGEN_R` comment.

**Nothing is committed past `ea2cfba`. No commit without his explicit order.**
