# HANDOFF — 2026-08-13 02:52:00
**Branch:** `kill-the-tube-2026-08-11` · **Worktree:** `SPACE-SYNTH-TUBE-killtube` (THE LIVE ONE)
**Bundle:** `SpaceSynth.app` @ **2026-08-13 02:42:32**
**Last commit:** `38b72f1` (2026-08-12 22:27:28) — **everything below is UNCOMMITTED**
**Read `docs/BOARD.md` first.** This file is the session, the board is the truth.

---

## 0. THE HEADLINE

Two items closed, one deferred by him after my diagnosis failed twice.

| Item | State | The number |
|---|---|---|
| **A1″** — seed↔seed merge bound | ✅ **DONE, verified on HIS play run** | worst `Mmax` = **100.1% of ceiling** (was 137%) |
| **12 PERF-TELEMETRY** | ✅ **DONE, baseline captured** | **~31–36 fps** idle @2M, worst frame **50–99 ms** |
| **13 GRID-IMPRINT** | ⏸️ **deferred — *"fuck it low prio"*** | 2 fixes shipped, symptom unchanged twice |

---

## 1. A1″ — BOUNDED (done)

**The bug:** the seed↔seed merge at `particles.metal:1481` deposited with a plain
`atomic_fetch_add` — no budget, no CAS, no taper. Both the rate limit and the
outcome bound were invisible to it.

**The path to the fix ran through a wrong turn, and the wrong turn is the lesson.**

- **v2 (his explicit order, "route it through the CAS"):** the capture path's CAS
  copied verbatim — budget `MDOT·dt·fFb`, **ENTRY** test `mcur < budgetMx`.
  **MEASURED on his play run: `mrg=1902/10/1892` — 99.5% refused, and the 10 that
  landed still put `Mmax` at 185,710.7 against a 135,113 ceiling = 137%.**
  An entry test asks "is the plate under budget?" then adds whatever it likes. The
  capture path survives that because its overshoot is one star (≤50 M☉); here the
  victim is a SEED, so the overshoot IS the bug. **A 99.5% refusal rate is not a
  bound, it is a lottery with a 0.5% ticket.**
- **v3 (the fit test, shipped):** two changes.
  1. **Budget is HEADROOM (`mBound − mS`), not `MDOT`.** A BH↔BH merger is
     *dynamical* — there is no disc to drain, so the viscous rate has no physical
     claim on it. Keeping `MDOT` would have banned merges outright (21–73 M☉/frame
     against a ≥50 M☉ victim) and killed the runaway to one giant with them.
  2. **The claim must FIT WHOLE:** `mcur + myMx <= budgetMx`. Overshoot is then
     exactly zero by construction, and several victims converging on one seed in a
     frame are bounded TOGETHER on the shared plate instead of each against a stale
     `posW.w`.
  No taper here on purpose: a merge is a discrete event, and a smoothstep on a
  discrete event is just a slower lottery.

**VERIFIED — his play run, 2026-08-13 02:25:56, `/tmp/killtube_fit.log`, 115 samples, 181 noteOns:**
- worst excursion **`Mmax` = 102,168.8 vs 102,100.5 ceiling = 100.1%** — 68 M☉ over,
  inside the capture path's own documented ≤50 M☉ single-victim slack, plus the
  basis difference between the log's `Mlive` and the shader's `u.fieldMassMsun`.
  **Not a merge breach.** The 31 "over" samples all sit at 100.0–100.1% — the taper
  asymptote, same place A1′-endgame parks.
- **merges still fire: `mrg=17575/22/17553`, 22 landed** — including `Mmax`
  141,948.9 → 380,561.8 (**×2.68 in one sample**), which was **correctly allowed**
  because the ceiling then was 469,402. Free below the ceiling, hard stop at it.
- he grew the field to `Mlive` = 2.97M and the bound tracked it: peak `Mmax`
  489,919.6 vs 509,993 = 96%.

---

## 2. THE CONDITION HE CALLED AND I HADN'T

*"mergers never really happen through random launch mode, rather after play."*

He was right and the code agrees: the merge is gated `playGate < 0.5` and blocked
through attack, so it can **only fire at rest, on seeds that play piled into one
place**. A cold idle launch never gets two seeds within 1.4 cells — which is why
every unattended run I did logged `mrg=0/0/0` and why A1″ sat "shipped, unproven"
for hours. **Any future merge work needs a PLAY run. There is no substitute.**

---

## 3. PERF TELEMETRY (done) — and the trap it prevents

There was **no timing telemetry of any kind** in this build: no fps, no frame time,
no wall-clock stamps, so frame rate could not even be reconstructed after the fact.
His report *"disabling ortho gave me huge fps back"* could be neither corroborated
nor refuted.

Now, on the existing 240-frame cadence:

    [PERF] fps=33.9 worst=53.4ms ortho=1 warp=1.00 particles=2000000 n=240

Mean fps over the window, **the worst single frame in it** (the spike is the
stutter he feels; a mean hides it), and the state it was measured in.

🚨 **`physicsUniforms.dt` IS NOT FRAME TIME.** It is a fixed `0.0165 × timeWarp`
step (`renderer.mm:1402`), pinned deliberately to kill the variable-FPS energy
pump. Deriving fps from it gives you the TIME WARP. This reads `CACurrentMediaTime()`.

**Baseline, idle, 2M particles, ortho, 1×: ~31–36 fps, worst frame 50–99 ms.**
First hard perf numbers this project has had. **His ortho claim is now measurable
but still unmeasured** — toggle ortho mid-run and both populations land in one log.

---

## 4. GRID-IMPRINT — deferred, and honestly

**His sighting stands:** 64× + held low C → *"you see the grid, the boxes."*

**I shipped two fixes and neither changed what he sees:**
1. Coarse PM `∇Φ` at `:1610` was nearest-cell → made CIC-trilinear. → *"unchanged"*
2. AMR fine `∇Φ` at `:2101` was the same mistake, **and it overrides the coarse one
   in the core** (`mix(gacc, gaccFine, w)`, w = 1 inside 75% of the fine box, AMR on
   by default) → made trilinear too. → *"still there"*

**KEEP BOTH.** They are real defects regardless of this symptom: mass is deposited
**CIC**, force was read back **NGP**, and mismatched kernels in a PM code give grid
imprinting, self-forces and momentum error. The codebase already knew the pattern —
density and flare read trilinear at `:1175`/`:1184`, called *"the alias-free
pattern"* right there. **Measured cost: none detectable** (33.9–35.2 fps after vs
~31–36 before).

**Ruled out by inspection:** the coverage-resolve postfx (`postfx.metal:213`) is a
pure per-pixel Beer-Lambert factor — no tiling, no neighbourhood — so it cannot make
blocks. `SS_NO_COVERAGE=1` settles it in one relaunch if anyone doubts it.

### THE NEXT STEP IS AN OBSERVATION, NOT CODE

**Orbit the camera while the boxes are visible.**
- **Rotate with the field** ⇒ world-space, physics. Next suspect: the near-field
  3×3×3 centroid sum — each cell a point mass at a centroid whose sample count
  **caps at 32**, i.e. a per-cell biased force in exactly the dense regime a held
  note at 64× creates.
- **Locked to the screen** ⇒ renderer, and every physics change is orthogonal.

**Why the screenshots cannot settle it:** the default camera sits at `(0,0,ρ)` on
the +Z axis (`camera.h:31-32`), so a world-space XY lattice and a screen-space
tiling **project identically**. Orbiting breaks the degeneracy.

**Alternative, needs his hands once:** reach the boxy state, then `SS_DUMP` +
`SS_DUMP_TICK` writes the particle buffer — if the positions carry no block
structure, it is the renderer, settled with zero guessing.

---

## 5. METHOD NOTES — five, all earned tonight

1. 🚨 **"Run it" means LAUNCH it. He plays.** I started posting synthetic key
   events (`System Events` → `key code 0/2/5`) to drive a play run and he killed the
   call: *"achill i just pressd it just wanted u to open the app."* The keystroke
   channel demonstrably works, which is exactly why it must not be used — the
   playing is his verdict, and a run I drove is a run he never saw.
2. 🚨 **Grep EVERY read of a field before declaring a class of bug fixed.** I fixed
   `phi[` and shipped. `finePhi[` was the same bug and overrode the fix. Then I
   assumed the pair explained the symptom and shipped again. **Two builds against an
   unverified diagnosis.** The five-second orbit test should have come first.
3. **A comment claiming "NO cap" sat on the line defining the cap** —
   `STAR_MAP_CAP = 100.0f`, `particles.metal:310`. Third sighting of that family.
4. **Bootstrap timing is stochastic:** the first star to cross `M_BH_SEED` took
   ~40 s, ~90 s and ~8 min across three runs of *identical code*. I read the 8-min
   run as a regression caused by my own change and was wrong. **One run is never
   evidence about an endpoint.**
5. **Count at the gate; do not infer a mechanism from a curve.** Everything real
   tonight came from `mrg=`/`cap=` counters. Every wrong call came from reading a
   shape and reasoning backwards.

---

## 6. STATE OF THE TREE

**Uncommitted** in `SPACE-SYNTH-TUBE-killtube`:
- `src/render/particles.metal` — A1″ fit test; both `∇Φ` reads trilinear; **temp
  `mrg=` gate counters (`accDiag[2..4]`, three sites)**
- `src/render/renderer.mm` — `[PERF]` line + `lastOrtho` member; **temp `mrg=`
  readout**; `accDiagBuffer` enlarged 2 → 8 words (clear still zeroes only `[0..1]`
  on purpose, so the counters accumulate)
- `docs/BOARD.md` — A1″ closed, PERF closed, GRID-IMPRINT deferred, plus the six
  rows added tonight
- `imgui.ini`, app binary

🚨 **STRIP THE `mrg=` COUNTERS BEFORE SHIPPING.** They are the instrument that
proved A1″ — keep them until the next merge verification, then remove all four
sites (three in `particles.metal`, one readout in `renderer.mm`) and drop
`accDiagBuffer` back to 2 words.

**Open, all grounded with file:lines, none acted on:**
**10 DEAD-COMPUTE** (his order — corpses run the full kernel, ~46% of the field;
NOT a plain early-out, sustain rebirth at `:720` fires only on dead particles) ·
**11 MERGER-FACE** (a merger has no visual identity; the science question first) ·
**13 GRID-IMPRINT** (deferred, orbit test) · **14 TUBE-AND-SPHERE** (`ORBIT_R_CHLADNI = 6.0`
+ `STAR_MAP_CAP = 100.0` and the `mix()` at `:3141` — **B7 that ignores `:3141`
will not kill the tube**) · **15 ETERNAL-ECHO** (deferred behind D6).

**Berlin New Media Week: 2026-09-02 — 20 days.**

---
**Last Updated:** 2026-08-13 02:52:00
