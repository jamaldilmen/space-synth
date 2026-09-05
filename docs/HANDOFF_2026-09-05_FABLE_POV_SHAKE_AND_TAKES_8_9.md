# SPACE SYNTH — handoff 2026-09-05 11:58:00 (FABLE)

> **His verdict on this state:** "amazing i think its gone" (2026-09-05 01:02:12, live app, POV, the near-plane fix and nothing else changed) · "cant believe it was that easy.. okay now we know pov is inverted" (01:37)
> **Cold start:** read `docs/BOARD.md` §AA28 (this session) then `docs/SPACE_SYNTH_LIVE.md` — NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `41609e1` (sources end at `38170d5`; `41609e1` reverts a collision commit, `91604cb` is imgui.ini)
**Build + launch:** `bash package_macos.sh` then, for the POV show config:
`SS_FULLSCREEN=1 SS_WIDTH=19644 SS_HEIGHT=1680 SS_ORTHO=0 SS_FOV=45 SS_REF_HEIGHT=420 SS_LUM_CEIL=520 SS_CAM_RHO=50 SS_LENS_RENDER=1 ./SpaceSynth.app/Contents/MacOS/SpaceSynth`
**Render a take:** `SS_REF_HEIGHT=420 SS_LUM_CEIL=520 bash logs/run_shot.sh <name> d 50 9000 0 19644` (take 8) · `… e 2925 9000 0 19644` (take 9). ⚠️ `logs/` is gitignored — the driver and runner exist only on this Mac.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | POV "mad shaking" in takes 6/7 and "insane flicker" live | perspective near plane 0.001 with far 5000 ⇒ depth collapses to one float value beyond a few units ⇒ star-pass `Less` test vs the depth prepass flips per frame | near 1.0, far 20000 (`38170d5`) | `src/main.cpp` `perspectiveMatrix(` call; `renderer.mm:851` (Depth32Float), `:1326`, `:4699` | `[HIS WORDS 2026-09-05 01:02:12]` "amazing i think its gone", identical config, one variable |
| 2 | The camera was suspected (BRAIN's spring-parallax hypothesis) | no per-frame camera readout existed | `[CAMF]` offline per frame + `[CAM-LIVE]` on movement (`f09609f`); zoom spring is critically damped `kZetaZoom = 1.00f` | `src/main.cpp` after `camera.update(dt)`; `src/core/camera.h` | `[MEASURED n=3: camf_b_smoke, camf_c_hold, camf_b_4x]` rho ripple ±5% vs picture ±30%; static hold rho 927.45825 to 1e-5 from f450 while the field stepped |
| 3 | POV could not frame what ortho frames at its far end | `kMaxRho` 2000 | 5800 = 2400 / tan 22.5°, derived from ortho's 1.2·rho law (`0cac109`) | `src/core/camera.h` | `[READ camera.h]` |
| 4 | No way to set Lum Ceiling on an offline render | fader only | `SS_LUM_CEIL=<v>` env, `[LUM]` log line (`a94e76f`) | `src/main.cpp` after the `SS_ORTHO` block | `[READ]` + `[LUM] SS_LUM_CEIL=520` in both take logs |
| 5 | Takes 8 and 9 (his two POV shots) not rendered | — | rendered 01:40–01:58, 9000 f each, all notes/chords on+off in the logs; DXV3 on `/Volumes/LOSTINSPACE/JAMAL/`, six slices DXD3 verified | `~/Desktop/sweep/take8_*`, `take9_*`; drive | `[MEASURED ffprobe ×6]` |
| 7 | Proof that takes 8/9 carry the fix | by report | by ordering: bundle 01:40:07 < take8 log end 01:48:35 < take9 01:58:37; 150 profile windows, none paused (BRAIN re-measured) | bundle mtime, `~/Desktop/sweep/take[89]_*.log` | `[MEASURED n=150 windows]` |
| 6 | take4rev_full, take6 (ortho), take4_chord to delivery format | ProRes only | DXV3: take4rev + take6 on T9/JAMAL (21:38–21:51), take4_chord on LOSTINSPACE/JAMAL (00:45–00:48); take7 (ortho) conversion CUT when T9 dropped off the bus ~21:53 — partial `_L_dxv3.mov` may exist on T9, delete it | drives | `[MEASURED ffprobe]` |

## 2. 🚨 OPEN — his list, verbatim

1. **"chords held twice as long as the notes"** (2026-09-05 01:51) — DONE in take 9 (180 f). Not yet judged on the big screen.
   `MEASURE:` his eyes on `take9_pov_chords_2925to50_{L,C,R}_dxv3.mov` in Resolume.
   State: rendered and delivered `[MEASURED]` — verdict not seen yet.
2. **"STAND DOWN on the point-spread floor until after Cologne"** (his ruling 11:0x via BRAIN).
   `MEASURE:` none today. After the show: the 1-px floor at `render.metal:1388` / `:2539` is the Chladni dashed-lines item, unrelated to the shake.
   State: `[READ]` both sites real; cost unmeasured; not for today.
3. **take 7 (ortho) DXV3 conversion** — cut by the T9 disconnect.
   `MEASURE:` when T9 is back: delete any partial `take7_in_out_4notes_L_dxv3.mov`, rerun `ffmpeg -i in.mov -c:v dxv -pix_fmt rgba out_dxv3.mov` for L/C/R.
   State: originals intact on T9 `[READ ls before the drop]`.
4. **`logs/midi_ride_shot.mm` modes c/d/e and `run_shot.sh` are the only record of how takes 8/9 were driven and `logs/` is gitignored.** He said "thats ok" (00:1x). Risk stands: this Mac only.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **Sprite size as the shake fix — REJECTED 2026-09-05 00:54:27.** 4x sprites (`SS_REF_HEIGHT=420`) at 5340 centre read "that was looking good" (21:18) but at full width "crazy shake is back". The mechanism was depth, not raster. 4x survives only as his chosen LOOK.
- **Global phase correlation on a star field as a motion metric — REJECTED 2026-09-04 21:0x.** It locks onto static content; take 7's "frozen" frames had every star moving 1.5–2.1 px. Per-star tracking with background subtraction is the honest instrument, and even that biased toward integer steps in dense fields (my retraction below).
- **"Zoom out" = larger rho in POV — REJECTED 2026-09-05 01:37, his call.** His out is rho 50. The rest cloud reaches ~7600 world (maxR 61–76 sim × plate 100), so no POV distance is outside it; "wide" to him is the view from the core.
- **A centre-slice smoke to judge framing — REJECTED 2026-09-05 01:2x.** The 5340 C slice is a crop of the middle 27% and reads "zoomed in" whatever the camera does. Smoke full width when framing is the question.
- **Two windows committing one tree — happened 11:53–11:54.** `25bbfc7` regressed three hunks; reverted `41609e1`. The 🔑 token rule covers it; the gap is `/handoff` in one window being invisible to the other.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-05 11:53:06  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS

1. git
  ok    branch true-physics, HEAD cc29ab7
  FAIL  3 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M imgui.ini
           M src/core/camera.h
           M src/main.cpp
  ok    pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at a66c63c — 4 docs-only commit(s) since, no source change
  WARN  docs/BOARD_BLACKHOLE.md is 269361B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 104965B — exempt (not read at cold start)
  ok    docs/BOARD.md current at a66c63c — 4 docs-only commit(s) since, no source change
  WARN  docs/BOARD.md is 204664B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    68 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:577 / :765 / :1146 / :1466 / :1469 / :2585 / :3329, postfx.metal:66
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere
        (none touched this session — no orbital code changed)

PREFLIGHT: FAILURES ABOVE — fix before handing off.
```
Resolution: the FAIL was the uncommitted tree; sources were committed by BRAIN (`0cac109`…`38170d5`) at 11:53–11:54 during this handoff, the collision commit reverted at `41609e1`. Final re-run after the docs commit is appended at the bottom of this file.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "Stars are drawn on an integer pixel grid; each star's per-frame step is quantised to whole pixels" (2026-09-04 21:0x–21:2x, sent to BRAIN and to him) | Tracker artefact: a centroid over a ~130-grey dense background is pulled to the peak pixel. Background-subtracted tracking still showed two-level steps of 0.5–0.6 px, not 1.0, and doubling/quadrupling the sprite did not remove the shake. The mechanism was the depth test, not the raster. |
| "POV moves the picture 3–4× faster on screen, so the same snapping becomes visible" (21:19 report) | The speed difference is real (ortho 0.54 vs POV 1.7–2.2 px/frame) but it explained nothing: the shake was per-frame depth-test flicker, present at any speed and visible live with a static camera. |
| "Take 7's frozen frames are frames where the physics did not advance" (20:5x, briefly) | Withdrawn within minutes: pixel diffs were nonzero and per-star tracking showed motion on those frames; the phase-correlation metric was locking onto static content. |
| "For tonight, re-render 6 and 7 with `SS_REF_HEIGHT=420` — env only, no code" (21:19 recommendation) | The re-render at 4x full width shook ("crazy shake is back", 00:54). The recommendation would have shipped the defect. |

---

**Last Updated:** 2026-09-05 11:58:00
**Folded into board:** `docs/BOARD.md` §AA28 @ 2026-09-05 11:58:00
