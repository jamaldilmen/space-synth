# SPACE SYNTH — handoff 2026-08-28 13:05:00

> **His verdict on this state:** *"a black hole is not a lense… FUCK THE LENSE. this enitre approach is ass."* (2026-08-27) · *"the march as it is rn is dead too delete it all of it to never retun its the oranghe blob itsnot what we want."* · *"this is the only blocker in the project weve sucesfully killed the tube after a couzople of months this is inanse."*
> **Cold start:** read `docs/BOARD.md` §V and `docs/BOARD_BLACKHOLE.md` §U — NOT this file, NOT older handoffs. The knowledge is `docs/blackhole-library/`.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-POST-TUBE` branch `post-tube` @ `9751d9a`+
⛔ **`SPACE-SYNTH-BH` / `SPACE-SYNTH-RESONATOR` / `SPACE-SYNTH-TUBE-camera` NO LONGER EXIST.**
**Build + launch:** `bash package_macos.sh` then `open -n SpaceSynth.app --env SS_FULLSCREEN=1`

---

## 0. 🎯 TASKS — TOP OF THE LIST, HIS ORDER

**1. 🕳️ FIX `M` — make the drawn hole key off the MONOTONIC SEED MASS.** ⏳ *Awaiting his go.*
   The hole "vanishes instantly" because `cam.horizonR` comes from a radial profile that is **blind beyond r = 5.0 sim**, on a **binary** test with no hysteresis. `renderer.mm:3314` already prescribes the fix in its own words. **Everything else about the hole is blocked behind this** — a new renderer keyed to the current quantity inherits the one-frame cut. §U3 / §U4.

**2. 🎥 CAMERA — SMOOTHNESS + AUTOMATED A→B RIDES.** ⛔ **NO BPM SYNC.**
   His words 2026-08-28: *"we dont want a bpm sync its not needed for now u got that wrong. its just about smoothness in camer amotion. automated camera rdies from point a to b ."*
   ⭐ **A→B comes FREE with the smoothness fix** — once input writes a TARGET and a second-order spring chases it, a ride is one assignment and the camera departs from rest, accelerates, decelerates and arrives at rest. No spline, no path code.
   ⏳ **HIS CALL, quoted verbatim, do not reword:** *"A-to-B between two points comes free with the smoothness fix. Do you also want rides that pass through several waypoints, or is point-to-point enough?"*
   ⏳ **HIS OTHER CALL:** does cinematic mode own **time warp**? It would change a control he uses constantly.

**3. 👁️ THE PER-PIXEL TRACER — his chosen architecture, BLOCKED BY TASK 1.**
   Backward geodesics per pixel that **TERMINATE ON THE REAL PARTICLES** and take their emission and `g`. ⛔ Never a grid fog integral — that was the march. §U8.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| U1 | The lens | forward per-sprite screen displacement; 2 image roots max | **DELETED**, ~320 lines. Shadow-by-absence SURVIVED and now applies to every ray (it was gated `!lensWillImage`) | `render.metal` `particle_vertex`, `renderer.mm` instanceCount 2→1 | `[HIS WORDS 2026-08-27]` |
| U2 | The ray-march | emission summed from a 128³ grid, NEAREST-sampled, no temperature — a fog integral over a box | **DELETED**, ~410 lines + pipeline + bit19 + 3 dials. `bhbody_fragment` deliberately kept | `render.metal`, `renderer.mm`, `app_state.h`, `main.cpp`, `renderer.h` | `[HIS WORDS 2026-08-27]` |
| V1 | Two trees, each missing the other's work | BH lacked the tube kill; camera lacked the keys fix | **ONE TREE**, merged `96ce430`, worktrees removed, renamed `post-tube` | `git merge-base --is-ancestor` on all 7 commits | `[READ]` |
| U3 | "The hole vanishes instantly" | **UNDIAGNOSED for weeks** | **MECHANISM FOUND:** detector blind beyond `RADIAL_MAX_R = 5.0`, binary test, no hysteresis | `particles.metal:405`, `:4271`, `renderer.mm:3213-3228` | `[MEASURED n=4 runs]` |
| U6 | Board row **L9** | *"`bc_validate.cpp` DOES NOT EXIST IN THE TREE and never did"* | **REFUTED** — it exists in `tools/`, runs, reproduces `b_c` to 8.2e-15. The row searched `src/` | `tools/bc_validate.cpp` | `[MEASURED]` |
| V6 | `MEMORY.md` silently truncating | 28,464 B against a ~24,986 B loader cap — the bottom never reached a cold start | **24,954 B.** 82 bullets, 83 links, 7 ⭐⭐⭐, every link resolves | `memory/MEMORY.md` | `[MEASURED]` |

## 2. 🚨 OPEN — his list, verbatim

1. **"this is the only blocker in the project"** — the black hole. `[HIS WORDS 2026-08-27]`
   `MEASURE:` the R1–R6 tests in `docs/reference/BH_REFERENCE.md`, measured off self-captured screenshots.
   State: `[MEASURED]` **nothing now produces R2 (photon ring), R5 (far-side arch) or R6 (underside arc)** — that is the honest cost of the two kills. R1 shadow, R3, T2 dilation survive. **Blocked behind Task 1.**

2. **"the shapes are way bigter than theh used to"** → §T2, the field inflates and never settles.
   `MEASURE:` hold one note, log `meanR` every 240 frames; settled = two consecutive samples within 5%.
   State: `[MEASURED n=16]` meanR 12→71 over 64 s, `maxR` pinned at the 100 cap by 44 s. ⭐ **NOW CONFIRMED AS THE ROOT OF THREE SEPARATE BUGS** (§U5) — it reaches a third board. Owner of record: CAMERA window, parked.

3. **"we need smooth rides form different angles and like in my dji drone a cinematoic mode for allmovement"** `[HIS WORDS 2026-08-28]`
   `MEASURE:` log `phi` per frame across one tap — pre-fix frame one carries PEAK angular speed, post-fix it is ~0 and peaks mid-move. Then drive identical input at 120 fps and ~20 fps; total angle must match within a couple percent.
   State: `[READ camera.h:38]` `friction = max(0, 1 − dt·6)` — impulse-driven, ease-IN unobtainable at any setting. **Three separate impulse systems**, not one: camera orbit, body spin (`main.cpp:~798-827`), and time warp (`×1.3`, no smoothing at all).

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **THE LENS — KILLED 2026-08-27 21:02:15.** A lens is a SURFACE that refracts; a black hole has no surface. A forward per-particle map produces exactly as many images as you code roots for — **two** — while the photon ring is the n→∞ stack. **It could never have arrived by tuning.** ⛔ The deflection LUT in `renderer.mm` is real physics and STAYS; it is a table, not the lens.
- **THE RAY-MARCH — KILLED 2026-08-27 20:49:10.** ⚠️ **The geodesics were NOT the defect** — backward geodesic integration is exactly what NASA does. The defect was averaging a 128³ grid along a line. ⛔ Do not rebuild it; anything replacing it must terminate on the matter that is actually there.
- **BPM / BEAT-SYNCED CAMERA — REJECTED 2026-08-28.** *"we dont want a bpm sync its not needed for now u got that wrong."* 🚨 **This was the BRAIN's error, not the camera window's:** it raised beat-derived damping as an open QUESTION and the brain relayed it as a PROPOSAL. **Quote a peer's question; never re-word it.** ⛔ Do not reintroduce it via the "Link so params are BPM-syncable" line — that is about params generally, not the camera.
- **Fine box ±4 → ±8 — REJECTED 2026-08-27.** *"well the dont widen the box."*
- **`kGridSize` 128→256 — costed, not chosen.** +1.26 GB, 335M→2.7 B Poisson invocations/frame, and CFL `uMax ∝ h²` drops 4× — a physics regression.
- **B-4 beaming, all three forms — do not schedule as an independent win.** ⚠️ And face-on `vLos` is **exactly zero** (max 4.0e-18); his default camera is face-on, so **beaming has never been visible to him.** Any verdict needs an edge-on A/B first.

## 4. 🔬 PREFLIGHT

```
PASTE_PREFLIGHT_HERE
```

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "The march has never executed" | Read from a REST-state log where `horizonR = 0` gates it off. **He watched it run.** His eyes beat my log read. |
| "P1 (the step-rule ceiling) will show a photon ring" | The pass was gated off. The change was **invisible, not wrong** — and I told him to look before confirming the pass runs at all. |
| "ω tied to the beat is an open call for him" | It was the camera window's question and I re-worded it into a proposal. He rejected it flatly. |
| "The tree is clean apart from the design doc" | True when said, false 30 s later — I launched the app and it rewrites tracked `imgui.ini`. |
| "All index lines are under ~450 chars" | Rounded from memory instead of re-measuring. Actual: 661 / 498 / 473. |
| "There are 10 entries in the ⭐⭐⭐ tier" | `grep -c "⭐⭐⭐"` counts the header PROSE that explains the tier. Entries only: exactly 7. **A count is a measurement; that one had a definition error in it.** |
| Board L9: "`bc_validate.cpp` never existed" (not mine, but carried) | It is in `tools/`. The row searched `src/`. |

---

**Last Updated:** 2026-08-28 13:05:00
**Folded into board:** `docs/BOARD.md` §V and `docs/BOARD_BLACKHOLE.md` §U @ 2026-08-28 12:55:00
