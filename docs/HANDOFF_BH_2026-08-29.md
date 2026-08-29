# SPACE SYNTH — BH window handoff 2026-08-29 03:12:44

> **His verdict on this state:** *"WE NEED TO GET THE PHSSICS CORRECT our black hoel is still a toilet drain. stuff behvaes differntly near a balckhole i want this executed just as well as kill the tube."* (2026-08-28 14:04) · on time warp, 2026-08-29 02:30: *"its ampfliefied when i advanc time or uppen thex4 x8 x16. then the bh dies and evaporates een if i dont play… the reverisbitliy through lay is mandatory a feuature nto abug. the way that the mergers behave is broken."*
> **Cold start:** read `docs/BOARD_BLACKHOLE.md` — NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-POST-TUBE` branch `post-tube` @ `68ee28c`
**Build + launch:** `bash package_macos.sh` then `pkill -x SpaceSynth; SS_FULLSCREEN=1 ./SpaceSynth.app/Contents/MacOS/SpaceSynth`

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | Hole vanishes instantly | horizon keyed to a radial profile windowed at 5.0 sim | keyed to the seed mass | `renderer.mm` (uncommitted) | `[MEASURED n=233]` drawn zero 2/233 vs profile 13/233; and live: profile 0.0000 with a 102,046 M☉ seed, drawn held 0.1717 |
| 2 | Why the profile blinds | `RADIAL_MAX_R = 5.0` calibrated at meanR 3.92; `ratio>=1` is binary | identified | `particles.metal:405`, `:4271` | `[MEASURED]` 34,280 M☉ seed → horizonR **0.0000**, while a smaller seed with 33× the mass *inside the window* → 0.2344 |
| 3 | "The cubes/grids for months" | assumed render artifact | **it is the physics** | `particles.metal:1429`, `:3812`, `:1373` | `[READ]` capture + merge run entirely on the cell grid; both scans are 3×3×3 cells |
| 4 | "Toilet drain", as a number | unquantified | quantified | `:1803`, `:1429` | `[READ]` ε = 5.82 r_h, clamp = 8.15 r_h — **horizon, photon sphere and ISCO all inside ONE softening length** |
| 5 | Root cause of both | — | **a body has a mass but no RADIUS** | `docs/SEED_CONTINUUM_DESIGN_2026-08-29.md` | `[READ]` χ = r_s/R goes 4.2e-6 → 4.2e-5 over 1→100,000 M☉: mass alone can never make a body compact |
| 6 | Time warp breaks physics | believed unsolved | **already solved, wired to the wrong control** | `main.cpp:2697` vs `app_state.h:73` | `[READ]` `uiPhysicsSubsteps` is the full-physics fixed-dt loop (`renderer.mm:3064-3069`), slider 1..32, and its own note says *"leave time-warp at ×1 and dial THIS"* |
| 7 | Arrow taps "3 = 90°" | stated as a constant | frame-rate dependent | — | `[MEASURED]` 7.28° @18.7fps → 65.43° @120fps, a **9× spread**; derived three ways independently |

## 2. 🚨 OPEN — his list, verbatim

1. **"the way that the mergers behave is broken"** (2026-08-29 02:30)
   `MEASURE:` retest **after** warp is invariant — warp corrupts merge rates, so every merge number taken at ×64 is void.
   State: `[READ]` candidates are the one-seed-per-cell race (`:3812`, plain write, last writer wins) and the clamp+scan pairing — `[HYPOTHESIS]` which one dominates.

2. **"the bh dies and evaporates een if i dont play"** (2026-08-29 02:30)
   `MEASURE:` **Physics-substeps sweep — 1/2/4/8/16, read `[PERF] fps` at each. ~30 s of his hands, no code.** 🚨 This is the ONLY blocked input; every cost number without it is a guess.
   State: `[READ]` `main.cpp:2697` `simDt = 0.0165f * timeWarp` — at ×64 one step of dt=1.056. ⚠️ Do **not** naively wire warp→substeps: `app_state.h:73` warns rate-based drain runs **N× per substep**, which would trade one evaporation for another.

3. **"stuff behvaes differntly near a balckhole"** (2026-08-28 14:04)
   `MEASURE:` `[AMR] finePhi` ratio r0.25/r1 → 4.0 for a real 1/r well; `[CELLPROBE] clump` must fall from 14,827×.
   State: `[READ]` nothing behaves differently because there is no near field — §1 row 4.

**Order (his ruling 2026-08-29 02:30):** (1) time-warp invariance · (2) mergers, retested after · (3) delete the `max()` latch · (4) χ continuum last.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **Deleting the `:1429` capture clamp on its own — WILL PLATEAU.** The 3×3×3 neighbour scan (`particles.metal:1378-1381`) caps separation at 2.0–3.46 sim regardless of the clamp. Clamp and scan width must move together or reach rises by ~1.4–2.5× and stops. Do not predict "reach scales with mass" from the clamp alone.
- **`bhSeedMassMono`'s `max()` latch — MY OWN CHANGE, recommend deleting it.** It makes the drawn radius unable to shrink, which fights his 2026-08-04 reversibility feature. In `run_212302` the raw seed drops **10×** where the latched value drops **2×** — those 8 suppressed drops were him playing, and we were hiding them.
- **The cheap central-gravity substep — ALREADY TRIED, EXPLODED** (`renderer.mm:3064-3069`): it strips self-gravity/pressure/boundary balance, v→0.33c. The full-physics loop replaced it. Do not re-propose the cheap one.
- **1D FFT peak-picking on a sparse dot field** — produced three different "lattice periods" today (33.5, 46/52, 50/133 px), all artifacts. Use a **high-passed 2D autocorrelation**; a real lattice gives an ACF bump ~0.1, the noise floor is ±0.001.

## 4. 🔬 PREFLIGHT

```
1. git
  ok    branch post-tube, HEAD 68ee28c
  FAIL  11 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M SpaceSynth.app/Contents/MacOS/SpaceSynth
           M docs/CAMERA_STEP2_DESIGN.md
           M docs/blackhole-library/README.md
           M imgui.ini
           M src/core/camera.h
           M src/main.cpp
           M src/render/renderer.mm
          ?? docs/BH_NEAR_FIELD_AUDIT_2026-08-28.md
          ?? docs/SEED_CONTINUUM_DESIGN_2026-08-29.md
          ?? docs/STATUS.md
          ?? docs/blackhole-library/04_HOW_THE_REFERENCES_DO_IT.md
  WARN  build artifact is TRACKED — commit sources separately FIRST, then it alone:
          SpaceSynth.app/Contents/MacOS/SpaceSynth
  WARN  no upstream set for post-tube
2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at 9751d9a — 4 docs-only commit(s) since, no source change
  ok    docs/BOARD.md current at 9751d9a — 4 docs-only commit(s) since, no source change
  WARN  docs/BOARD.md is 121403B — split closed rows into BOARD_CLOSED.md
3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source
4. referenced paths (live docs only)
  ok    35 referenced path(s) in live docs all resolve
5. orbital-plane convention
  WARN  7 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere
PREFLIGHT: FAILURES ABOVE — fix before handing off.
```

🚨 **The FAIL is REAL and is NOT mine to clear unilaterally.** The BRAIN window claimed the commit and was still busy at 03:08; two windows committing one dirty tree — with a tracked binary built from all three windows' changes — is the exact collision this project spent 2026-08-28 avoiding. **Whoever reads this next: confirm no other window is mid-commit, then commit sources one concern at a time, binary last and alone, `imgui.ini` reverted at commit time and not before.**

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "`[AMR] M<Rfine`=8.16 vs `[GRAV] Menc`=158,483 — a four-orders contradiction" | **Cross-frame pairing.** Those lines print at different cadences (417× / 418×); I compared different frames. Same frame, they agree exactly. |
| "The fine-grid potential well is flat (Φ ratio 1.09)" | Same cause — a late frame after the patch had drained. Same-frame ratio is 2.38, a real well. |
| "`gMaxMass` is not monotonic — a bug, 10th comment-is-not-a-mechanism sighting" | **It is his 2026-08-04 reversibility feature**, documented at `particles.metal:788-807`. The two comments calling it "conserved, monotonic" are STALE, not lying. **New rule: check the DATE on a comment, not just the code under it.** |
| "The `max()` latch was never exercised — 0 decreases in 233 samples" | True of that one clean run only. In `run_212302` it resets twice and the raw seed drops 10×. |
| "bCull sits at a raw 7.0 and will clip the disk" | It was a **multiplier** (`bDerived = (meanR/rsSim)·(bhRayBcull/7)`), ≈213 r_s at default. I quoted a stale `app_state.h:74` comment without reading the live code — one turn after citing that very rule. |
| "There is no lattice in his screenshots" | Correct about the frames, wrong as stated. **Five clean tests are evidence about my frames, not about his claim.** He has seen the grids for months. |
| "median drawn/profile = 0.627" | Measured on a mature accreting run; does not generalise. Early-run median is 0.0115 (n=7). Neither is *the* ratio. |

---

**Last Updated:** 2026-08-29 03:12:44
**Folded into board:** `docs/BOARD_BLACKHOLE.md` §V (BH detail) + `docs/BOARD.md` §W (non-BH) @ 2026-08-29 10:45:00 — folded by the brain window; both re-stamped at `ea14dbc`.
