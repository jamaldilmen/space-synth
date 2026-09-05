# SPACE SYNTH — handoff 2026-09-05 15:25:00 (FABLE, afternoon)

> **His verdict on this state:** "Wider one song plan good" (2026-09-05 ~13:5x, on the orbit end distance and the song plan) · "Actually don't do the music run at all skip it" (~14:30) · the orbit take itself: not seen yet.
> **Cold start:** read `docs/BOARD.md` §AA29 (this session) and §AA28 (the morning), then `docs/SPACE_SYNTH_LIVE.md` §5.2 — NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ the docs commit on top of `23222fc` (sources end at `acda80f`; `23222fc` is tools only)
**Build + launch:** `bash package_macos.sh`, then the orbit recipe verbatim from bible §5.2:
`SS_LUM_CEIL=520 SS_CAM_THETA=1.5707963 SS_CAM_PHI=1.5707963 bash scratchpad/run_replay.sh <name> scratchpad/takes/orbit_wide_5400.take 50 5400 1 19644`
⚠️ Bundle 14:08:19 carries three source changes the 11:57:55 bundle did not: takes 4/6/7/8/9 and take 10 are from DIFFERENT binaries.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | The orbit take (take 3's shot) had never been rendered with the up-vector fix | roll (fixed 14757d5) + an unknown second fault | **take10_orbit_wide delivered**: ortho, rho 50→5800, 360° from π/2, no notes, 5400 f ×3, 65 GB ProRes, DXV3 ×3 DXD3 on LOSTINSPACE | `scratchpad/takes/orbit_wide_5400.take` | `[MEASURED ffprobe ×3 + check_replay 20866/20866]` |
| 2 | Absolute theta target > π spun the camera a full turn every 7 frames | `setTiltAbs` re-asserted the raw value against a co-wrapped actual | nearest representative: `tgtTheta = theta + wrapPi(abs − theta)` (`8182846`) | `src/core/camera.h` | `[MEASURED]` −π..π cycle at f=4,11,18,25 before; 0.003 rad tracking after |
| 3 | No frame-exact transport for a generated ride | MIDI driver tailing `[CAPTURE]` markers (target jumps at markers, §AA28) | `SS_REPLAY` take files: `gen_take.py` → `run_replay.sh` → `check_replay.py` (`23222fc`) | `scratchpad/` | `[MEASURED n=6 runs, 0 mismatches, 0 late]` |
| 4 | Frame 0 sprang 90° into the orbit pose | no launch env for the angle | `SS_CAM_THETA` / `SS_CAM_PHI` (`7ea4fe8`) | `src/core/camera.h` `reset()` | `[MEASURED]` f=0..15 stable to 1e-4 |
| 5 | Exposure only 7-bit (7.5 % steps) | CC22 alone | CC22 MSB + CC54 LSB, 7-bit senders unchanged (`acda80f`) | `src/main.cpp` | `[READ]` + 7-bit smoke still pumps 0.72/0.78/0.96 |
| 6 | Takes 6/7 (5-min POV, BRAIN) undelivered | ProRes only | DXV3 ×6 on LOSTINSPACE, 9000 f each, DXD3 | drive | `[MEASURED ffprobe ×6]` |
| 7 | Masters of 4/8/9 only on the Mac | 271 GB local | copied to `LOSTINSPACE/JAMAL/MASTERS_PRORES/`, size-verified; **local copies NOT deleted** | drive | `[MEASURED stat ×9]` |

## 2. 🚨 OPEN — his list, verbatim

1. **"The most important one is one long black hole shot with the slow spin / orbit."** (~14:1x) — take 10 is 3 minutes. If "long" means 10 minutes: ~2 h at this render cost and ~250 GB; needs the local masters gone first.
   `MEASURE:` his eyes on `take10_orbit_wide_{L,C,R}_dxv3.mov` in Resolume; then his length ruling.
   State: 3-min version delivered `[MEASURED]`; verdict not seen.
2. **"U will get the t9 stuff in a few hours."** (14:4x) — take2 / take5 / take7-ortho ProRes to convert (+10 min footage), the partial `take7_in_out_4notes_L_dxv3.mov` on T9 to delete first.
   `MEASURE:` `ls /Volumes` — T9 not mounted as of 15:25.
3. **Delete the local ProRes of takes 4/8/9?** 271 GB. Copied and verified on the drive. Not deleted; his word.
4. **Orbit render cost 2.2× take 3** — smear taps suspected (§AA29.6). Controlled pair not run; smear is a look, his call.
5. **Song shot** — cancelled by him; plan and generator kept (bible §5.2). Nothing pending unless he re-orders it.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **A MIDI driver tailing the capture log for a beat-locked ride — REJECTED 2026-09-05 13:3x.** The marker extrapolation put 10–22-step target jumps right after every marker (§AA28); the replay applies at ceil(t·30) with no estimation at all. Use `SS_REPLAY`.
- **"In key" reasoning for the notes of a render — REJECTED 2026-09-05 13:4x.** `[OFFLINE] audio engine NOT started`: the synth is inaudible in the deliverable. Notes are a field input and a render-budget term (one held chord per section = 15 note-ons vs 613 onsets), nothing else.
- **A trailing hold of the same absolute angle every frame — REJECTED (the mechanism of §AA29.2).** Reduce against the actual or the wrap fights you.
- **Reading the render's fps while a 271 GB copy reads the same volume — not a measurement (2026-09-05 14:2x).** The orbit's 2.6→5.3 fps is contaminated for its first 7 minutes.
- **Starting a job the other window already flagged, without "taking it" — happened twice (14:39/14:47 conversion, 15:1x /handoff).** Rule in §AA29.9.
- **Trusting preflight's STALE verdict after a by-hunk commit — inverse trap (11:55 and 15:22).** Staging rewrites source mtimes; the bundle content is unchanged. Decide by content (`git diff <built-sha>`), then rebuild once so the next window is not asked the same question.
- **The delivered set spans TWO binaries:** takes 4/6/7/8/9 from the 11:57:55 bundle, take 10 from 14:08:19 (carries `8182846` `7ea4fe8` `acda80f`). Re-rendering 6/7 byte-for-byte needs the tree WITHOUT those; re-rendering 10 needs them.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-05 15:20:43  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS

1. git
  ok    branch true-physics, HEAD 74a21d8
  FAIL  3 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M imgui.ini
           M src/core/camera.h
           M src/main.cpp
  ok    pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at 41609e1 — 6 docs-only commit(s) since, no source change
  WARN  docs/BOARD_BLACKHOLE.md is 269975B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 104965B — exempt (not read at cold start)
  ok    docs/BOARD.md current at 41609e1 — 6 docs-only commit(s) since, no source change
  WARN  docs/BOARD.md is 211559B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    69 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere
        (camera.h setTiltAbs/reset touched — the wrap is about the camera angle, not the disk plane; the 8 shader sites are untouched)

PREFLIGHT: FAILURES ABOVE — fix before handing off.
```
Resolution: the three paths were committed as `8182846`, `7ea4fe8`, `acda80f` (+ `23222fc` tools); imgui.ini reverted; the bundle binary is NOT tracked (`git ls-files --error-unmatch SpaceSynth.app/Contents/MacOS/SpaceSynth` → no match), so no tracked-binary trap. ⚠️ After these commits preflight reports the bundle STALE against `camera.h` — the by-content staging rewrote the source mtime (15:21:23) while the bundle is 14:08:19 and its CONTENT is exactly what built it; same benign case as 11:55. **The rebuild, the restamp of both boards and the FINAL preflight are BRAIN's closing pass, which follows this handoff** (`docs/HANDOFF_2026-09-05_BRAIN_POV_TAKES_AND_DEPTH_BOUND.md`); this handoff does not touch the `Commit at last verification:` line.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "Take 3 ran at 22 fps" as the comparison for the orbit's cost (14:2x, to BRAIN) | Total double-counts (§AA24); the defensible comparison is Render+PostFX to Render+PostFX: 155 → 250–340 ms. |
| "~190 GB free" before the orbit (14:09) | 185 GB measured by BRAIN at 14:09:34; I quoted a number from four minutes earlier. Both estimates for the two takes were extrapolations from other takes' bytes-per-frame; the orbit landed at 65 GB against a 70 GB guess. |
| My first exposure-pair patch (13:3x) | It would have made a 7-bit-only sender apply exposure once and then cache forever; fixed before any take used it (`expLSBEverSeen`). |

---

**Last Updated:** 2026-09-05 15:25:00
**Folded into board:** `docs/BOARD.md` §AA29 @ 2026-09-05 15:25:00 (restamp + final preflight: BRAIN's closing pass, which follows)
