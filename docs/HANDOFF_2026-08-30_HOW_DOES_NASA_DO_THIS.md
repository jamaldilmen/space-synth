# SPACE SYNTH — handoff 2026-08-30 23:45:00 — **HOW DOES NASA DO THIS?**

> ⭐ **FIRST QUESTION IN THE NEW WINDOW, his order 2026-08-30:** *"so... then our spptosch here is shit. how does... u guessed it.. NASA do that?"*
> **Answer this before writing any code:** how do real N-body / SPH codes (GADGET, ChaNGa, AREPO, Bonsai, PKDGRAV, and whatever NASA/JPL actually fly) do neighbour finding **without a fixed per-cell sample**? Trees vs uniform grids, k-nearest vs fixed-radius, how they keep it deterministic, and what it costs at 2×10⁶ bodies on one GPU.
> **His standing order this session:** *"fix the clock dont report unless its fixed dont priooritze other issue sbefore the center of our universe is fixed"*
> **Cold start:** read **`docs/BOARD.md` §Y** and **`docs/BOARD_BLACKHOLE.md` §X** — NOT this file, NOT older handoffs.
> 📅 **6 DAYS TO REVEAL.** Show: Cologne **2026-09-05**. Tomorrow is Monday.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `b070cbc` — sources end at `d0697d8`, `5b65a97` is the bundle.
**Build + launch:** `bash package_macos.sh` (**never bare `make`**) then `SS_FULLSCREEN=1 ./SpaceSynth.app/Contents/MacOS/SpaceSynth 2>&1 | tee run.log`
**Gates:** `SS_TRUE_TIME=0` (legacy 1 step/frame) · `SS_MAX_STEPS=N` · `SS_TIME_WARP=X` · `SS_SUBSTEPS=N` · `SS_TRUE_SUBSTEPS=1` · `SS_SEQ=transitions|staccato|held`
**Probes added:** `[UCLOCK]` universe clock · `[POSECLK]` pose clock · `[PERF] steps= realtime= clamp=`

---

## 1. ✅ CLOSED THIS SESSION

**Nine clock leaks, one concern per commit.** Full table with `file:line` in `docs/BOARD.md` §Y0.

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | 🚨 **The physics kernel ran on a hardcoded 1/60** | `dt = (debugFlags & (1<<6)) ? 1/60 : u.dt`, labelled "deterministic debug". **Bit 6 became the sustain-rebirth gate on 2026-08-03 (default ON)** and this consumer was never updated — taken on EVERY shipped run | `dt = u.dt` | `e2838f6` | `[READ particles.metal]` **95 uses of `dt` vs 2 of `u.dt`** in one kernel — 1.01× apart at ×1, **4× at ×4, 16× at ×16** |
| 2 | Step count assumed one per frame | sim-s per wall-s = `0.0165 × fps` | wall-clock accumulator; step SIZE untouched | `574765f` | `[MEASURED n=6 interleaved]` 239–240 of 240 both arms |
| 3 | `stepTick` non-monotonic | `frameCounter*nTrue + tsub`; it gates the SPH + Poisson cadences | monotonic executed-step count | `574765f` | `[READ renderer.mm]` |
| 4 | `universeClockSec` under-reported by N | per FRAME, from a second 0.0165 literal in `main.cpp` | ticks by `simSecondsLastStep()` | `84df144` | `[MEASURED]` `0.016500` at N=1, `0.066000` at N=4, ratio **4.000** |
| 5 | Pose clock was WALL time | warp-immune; sprites desynced from matter by warp×N | EMA fed SIM seconds | `7c90ca3` | `[MEASURED]` `0.016500` at ×1, `0.066000` at ×4 |
| 6 | Wall delta clamped to 0.033 s | **the clock lied below 30 fps** — sequencer, VJ rates, camera spin, `smoothedAmp` up to 24% slow | bound 0.25 s | `d0697d8` | `[MEASURED]` `SS_SEQ=staccato`, **+0.077 s over 11.09 s = 0.69%** at 48 fps |
| 7 | `SUSTAIN_REBIRTH` per-frame fraction | its own comment states the intent in seconds; 1.5 s at 120 fps became 4.5 s at 40 | per-SECOND rate × `u.dt` | `d9c485d` | `[READ particles.metal]` |
| 8 | `physicsUniforms.time` per frame | `+= dt` | `+= dt × steps` | `574765f` | `[READ renderer.mm]` |
| 9 | `radialMassBuffer` cleared in-loop, accumulated out-of-loop | zero-step frame double-counted the horizon profile | clear moved to its consumer | `851cf70` | `[READ renderer.mm]` |

🚨 **THREE CHANGE THE IMAGE AND HE HAS NOT LOOKED YET:** posed spin **slows 20–45%** at his fps (to the rate the matter actually moves); sustain rebirth **~3× faster** (authored intent); warp now genuinely scales the step, **so warp may look WORSE — honestly so.**

## 2. 🚨 OPEN — his list, verbatim

1. ⭐ **THE SAMPLING CAP — biggest thing on the board.** *"so... then our spptosch here is shit. how does... u guessed it.. NASA do that?"* (2026-08-30)
   `MEASURE:` cap in `spatial_hash.metal scatter_particles` + `merge_stars` / capture scans; stack **n≥4 per arm**, `Mmax` at matched window index.
   State: `[READ]` `scatter_particles` stores the first **32** per cell on a first-come `atomic_fetch_add`; merge and capture scan the same 32; `bhPeakCount` (uncapped) logs **334,576**. So the hole forms from a **0.01% sample chosen by GPU scheduling order.**
   `[MEASURED n=4 per arm]` cap 32 → `Mmax` 3388 / 3345 / 37257 / 35224 (**11.1× fork**, seeds@win2 = 1,1,2,2). Cap 64 → 20979 / 21418 / 7229 / 6223 (**3.4× fork**, seeds = 8,7,8,8).
   — **not** known: the true cost of a bigger cap (merge inner loop is O(count²); the cap-64 runs read 45.2/40.4/28.9/25.9 fps but were sequential and drifting), and whether sampling is the *only* cause (still bimodal at 64). **Cap is back at 32 in the tree.**

2. **Warp still does not form the hole above ~2×.** *"weve been having this error i clearl even stated it that at 4x upwards the bh doesnt form proeprly anymore. allegately u fiexed it last session"* (2026-08-30)
   `MEASURE:` `SS_TIME_WARP=4`, read `[GRAV] Mmax seeds mrg peak meanR`.
   State: `[MEASURED]` one warp-4 run was **stone dead** — `Mmax=50.0` (= `M_BH_SEED`), `seeds=0`, `mrg=0/0/0`, 2M untouched, `peak=1897514`, `meanR` 11.36 → 2.52: the field imploded into one cell. Root cause is now known and fixed (#1 above), so warp finally reaches the integrator — **as a bigger step, which is the wrong shape.** The cure is warp as MORE steps, gated on step cost.

3. **The step costs 23.65 ms against the 16.5 ms it represents**, so real time is unreachable at his config.
   State: `[MEASURED n=6]` fullscreen 2M runs at **0.49–0.86× real time**, best step rate ~49/s against the 60.61/s the clock asks for. This is throughput, not clock — no clock change touches it. It is the same wall behind warp, behind the frame rate, and behind his offline-render item.

4. **`u.frameCounter` still seeds the RNG per FRAME** — all substeps in a frame draw identically. Off the shipped path. ⚠️ needs per-step uniforms and **`PhysicsUniforms` has no static_asserts.**

5. **Φ is never re-solved while he plays** (gated `totalAmplitude < 0.02`). Large, but a physics decision he made — deliberately untouched this session.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **Zeroing the accumulator's debt at the clamp — MEASURED WORSE THAN THE BUG.** 208–238 steps per 240 frames vs legacy's 240; realtime 0.81 → 0.58–0.79. It deleted real time. Carry at most one step of debt instead — that is identity with legacy below 60.61 fps and skips above it.
- **Buying frame rate by shrinking the window — REJECTED, his order.** *"yo u launched it in a tin y window lol"*. Frame rate IS the independent variable; shrinking the drawable changes the quantity under test and describes no config he will ever run.
- **`SS_ORTHO` launch gate — REJECTED, his order.** *"i dont want ortho off by dfault. this is not a fix lol"*. Reaching for a faster config to make a change look like it works is dodging the test. Reverted; not in the tree.
- **Sequential A/B arms — INVALID, cost four runs.** All-of-one-arm-then-the-other confounds the change with thermal drift, battery drain and **display idle**. Interleave AND alternate the within-pair order; hold the display awake with `caffeinate -dimsu`.
- **Brute-force substepping** (unchanged from 08-29): 23.65 ms vs 1.77 ms for the integrate. The fix must reduce the required step, not buy more.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-08-30 23:39:59  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS

1. git
  ok    branch true-physics, HEAD b070cbc
  ok    working tree clean — committed
  WARN  build artifact is TRACKED — commit sources separately FIRST, then it alone:
          SpaceSynth.app/Contents/MacOS/SpaceSynth
  WARN  11 commit(s) not pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at 5b65a97 — 1 docs-only commit(s) since, no source change
  ok    docs/BOARD_BLACKHOLE.md size 111890B
  ok    docs/BOARD_CLOSED.md archive, 90810B — exempt (not read at cold start)
  ok    docs/BOARD.md current at 5b65a97 — 1 docs-only commit(s) since, no source change
  WARN  docs/BOARD.md is 146390B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    41 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:566:    return (m > 1e-12f) ? (L / m) : float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:753:            float3 axis = float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:1109:            float2 tang = float2(-rel.y, rel.x) / rxy;  // +Ω about z, matches
  ?     src/render/render.metal:1407:        float rXY = length(spinPos.xy);
  ?     src/render/render.metal:1410:            float3 tang = float3(-spinPos.y, spinPos.x, 0.0f) / rXY; // prograde about Z
  ?     src/render/render.metal:2501:    float2 perp   = float2(-dir.y, dir.x);
  ?     src/render/postfx.metal:66:    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  WARN  7 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: no failures.
```

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "The one-clock fix slowed hole growth ~6×" | **Single-run comparison, and the board bans it.** Stacked n=4: the outcome is BIMODAL (3388 / 3345 / 37257 / 35224) and the pre-fix run sits inside the upper cluster. I was one step from reporting the fork as the fix. |
| "At max=1 the accumulator can never be worse than legacy" | A structural claim I did not check against the code I had written. Zeroing the carry at the clamp **deleted real time**; measured 208–238 steps per 240 frames vs 240. |
| "The clamp fix carries the debt" | It did not. I subtracted the **unclamped** n before the clamp ran, so `min(acc, kStepWall)` was a no-op. Caught before reporting it as working; corrected to spend only the clamped n. |
| "Feeding the pose clock sim time is identity, so the look is unchanged" | Identity **only at 60.61 fps**. At his 32–52 fps the posed spin slows 20–45%. Corrected in the source comment before it became provenance. |
| "The machine collapsed thermally mid-batch" | **His correction: the screen went standby.** The display-sleep trap is already a logged finding and I walked into it — and it explains the asymmetry I could not account for, because OFF ran first in every pair and ON always second. |
| "Low Power Mode was on" (quoting `pmset -g` `powermode 2` back at him) | He said it was off. Per the standing rule his statement is ground truth and my reading of that field is what is wrong. Do not cite `powermode` as evidence. |
| The 2026-08-29 handoff row "mergers died under warp → **fixed**" | Overstated. `[MEASURED 2026-08-30]` warp 4 still fails and one run was deterministically dead. The board's own footnote already said "~9× short of time-invariance". |

---

**Last Updated:** 2026-08-30 23:45:00
**Folded into board:** `docs/BOARD.md` §Y + `docs/BOARD_BLACKHOLE.md` §X @ 2026-08-30 23:45:00, both re-stamped at `5b65a97` (the bundle; sources end at `d0697d8`).
