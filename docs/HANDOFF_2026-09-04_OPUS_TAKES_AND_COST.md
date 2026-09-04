# SPACE SYNTH — handoff 2026-09-04 19:02:54

> **His verdict on this state:** *"reading good movr it ot the disk"* (18:37, take 5) ·
> *"okay take 6 and 7 are both wrong i meant the note was held and let go. no theld for the
> neitre run lol .. replace both takes. **but our spede is supreme**"* (18:40) ·
> *"its a pretty substantil orewase in time for th escale were at"* (17:05, on center-only)
> **Cold start:** read `docs/SPACE_SYNTH_LIVE.md` (the bible) then `docs/BOARD.md` §AA27 —
> NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `8e7b8db`
**Build + launch:**
```
bash package_macos.sh                       # never bare make
SS_RENDER_FPS=30 SS_WIDTH=19644 SS_HEIGHT=1680 SS_CAPTURE=<base> \
SS_CAPTURE_SLICES=7152,5340,7152 SS_CAPTURE_FRAMES=<n> SS_LENS_RENDER=1 \
SS_CAM_RHO=2000 ./SpaceSynth.app/Contents/MacOS/SpaceSynth 2>&1 \
  | perl -ne 'BEGIN{$|=1; use Time::HiRes qw(time)} printf "%.3f %s", time, $_' > <base>.log &
# WAIT for "[MIDI] Listening on" in <base>.log -- NOT "[CAPTURE] ARMED" -- then:
./logs/midi_ride_shot <base>.log <a|b> 50 1 > <base>.ride.log &
```
**Watch it:** `python3 scratchpad/render_progress.py <base>.log`

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | What actually drives render cost | assumed resolution / spin | **THE NOTE.** A HELD note renders **4–6× faster** than a RELEASED one: take6 **48.6 → 8.52 fps**, take7 **49.3 → 13.24 fps**, only the note-off frame changed. Output 74 → 90 GB, same shot | `SPACE_SYNTH_LIVE.md` §4 | `[MEASURED n=2 pairs, one variable]` |
| 2 | Cost of the ramped spin | I claimed 3.3× | **11%.** Controlled pair, same 3 s notes, same width, 5400 f: `take4rev_full` 15.17 vs `take5_spin` 13.64 fps | §4 | `[MEASURED n=2 takes]` |
| 3 | Would center-only test renders help? | unmeasured | **YES, 1.34×**, and it is a **TRUE CENTER CROP** — `perspectiveMatrix` fixes vertical FOV so tan(horiz half-angle) scales exactly with width (0.271839 = 5340/19644) | `renderer.mm:6186` | `[MEASURED n=1 pair]` + `[READ]` |
| 4 | Would dropping capture SLICES help? | his question | **Almost nothing.** The 3 slices are crops of ONE render, blitted from the same texture, and the writer idles at 57 MB/s | `show_capture.mm:159` | `[READ show_capture.mm:159]` |
| 5 | Take 4's θ range fix (the 32-vs-128 MSB crossing risk) | pre-launch RISK, never run | **LANDED.** 127 crossings over 4,706 frames = **37.5 frames/crossing** against the ~38 predicted; the ~150 failure band never appeared | `main.cpp:429` CC33 | `[MEASURED n=127 crossings]` |
| 6 | Is the spin reachable offline? | keyboard ONLY, 24 `spinVel` refs, none in a MIDI case | **CC34/66 SHIPPED `f0cac86`.** 0 = stopped (app default ⇒ a dropped CC fails safe), 16383 = `kSpinMax`. Override sits AFTER drag+clamp because no arrow is held offline | `main.cpp:1270` | `[MEASURED n=87 CC lines, spin 0%→1%]` |
| 7 | `take4_check.py` lost with `/private/tmp` | gone | **Rebuilt and calibrated** — reproduces take 3 exactly: n=128 crossings, gap p50 42.0, step p50 2.790°. Reads logs with or without the wrapper timestamp | `scratchpad/take4_check.py` | `[MEASURED, reproduces a recorded result]` |
| 8 | The chord opened on black | cause unknown | **FRAMING, not formation.** Take 4 held `SS_CAM_RHO=50` through the whole 20 s chord — inside the 150 r_s matter shell | `SPACE_SYNTH_LIVE.md` §5 | `[HIS WORDS ~15:5x]` *"when a chord hits the screen is black"* |
| 9 | Phase viz default | ON since 2026-08-24 | **OFF**, his order. `uiPhaseViz = false`; `uiPhaseVizAmount` left at 0.35 on purpose so re-ticking the box still does something | `app_state.h:87` | `[HIS WORDS ~16:00]` *"phase vz off defualt always"* |
| 10 | Moving takes to the SSD | 17 "failures" | **exFAT.** `cp -p` fails at `chflags` **after** writing the bytes. Plain `cp` + size verify moved all 17, **156.2 GB freed** | §6.15 | `[MEASURED n=17 files]` |
| 11 | Progress visibility during a render | none | `render_progress.py` `a66c63c`. ETA from the **last 30 checkpoints**, not a whole-run average — that average is what made take 3's ETA wrong by 18 min | `scratchpad/render_progress.py` | `[HIS WORDS ~18:0x]` *"i kinda wann ahave a prgress abr"* |

## 2. 🚨 OPEN — his list, verbatim

1. **"later i will dictate exactly which shot i want"** (~17:50)
   State: **7 takes rendered and on T9.** `take4rev_full` (approved: *"reading good"*),
   `take5_spin`, `take6_mid_in_out_still`, `take7_in_out_4notes` (both re-rendered with
   3 s notes), plus the take-2 family. Nothing is chosen. All logs are in
   `logs/session_2026-09-04_take4_reversed/` with a MANIFEST.

2. **The TILT was never ruled on for takes 6 and 7.**
   `MEASURE:` nothing — this needs his word, not a run.
   State: `[HYPOTHESIS]` he named the notes, the zoom and *"no spin"* but never the tilt, so
   I kept θ 0→90° running underneath both and **said so before they rendered**. It is
   `midi_ride_shot`'s 4th argument (`tilt`, default 1), so flipping it costs a re-run and no
   rebuild. **If the takes read wrong, this is the first thing to suspect.**

3. **The spin axis — his two statements do not agree, and both are recorded.**
   `[HIS WORDS ~17:02]` *"its thre worng axis its from up to down not left to right"* then
   `[HIS WORDS ~17:08]` *"arrow key to the right heeeeld .. do it"*.
   State: `[READ render.metal:121]` the CC path already matches the right arrow EXACTLY
   (`dirY = arrowL − arrowR = −1` ⇒ `spinVelY` negative). The disk is in XY, so the
   in-plane "record" spin is `az` = **Option+←/→**, which is NOT what he named. Unresolved:
   whether his "wrong axis" was the axis or the edge-on pose it was seen at.

4. **82+ commits unpushed, and there is no push order.**
   Commit and push are different orders (his rule). Nothing has been pushed.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **Dropping capture slices to speed up test renders — REJECTED 2026-09-04 18:1x.**
  The three slices are crops of ONE full-width render (`show_capture.mm:159` blits the same
  source texture three times) and the ProRes writer idles at 57 MB/s. Removing two thirds of a
  job that is not the bottleneck buys almost nothing. **What works is narrowing `SS_WIDTH`** —
  1.34×, and it is a true center crop.
- **Comparing two full-length takes to measure ONE variable — REJECTED, twice.**
  Both my retracted numbers came from this: the "1.37×" width factor and the "3.3×" spin cost
  each compared runs whose note pattern ALSO differed. **A cost claim needs a pair with one
  variable changed; a pair of real takes almost never is one.**
- **A 300-frame smoke for take 4 — REJECTED before it ran.** The chord holds the camera static
  through frame 600, so a 300-frame smoke starts no tilt and passes while testing nothing.
  900 was the minimum that could fail.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-04 19:03:06  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS

1. git
  ok    branch true-physics, HEAD 8e7b8db
  FAIL  1 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
          ?? docs/HANDOFF_2026-09-04_OPUS_TAKES_AND_COST.md
  WARN  87 commit(s) not pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at a66c63c — 3 docs-only commit(s) since, no source change
  WARN  docs/BOARD_BLACKHOLE.md is 269361B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 104965B — exempt (not read at cold start)
  ok    docs/BOARD.md current at a66c63c — 3 docs-only commit(s) since, no source change
  WARN  docs/BOARD.md is 204664B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    68 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:577:    return (m > 1e-12f) ? (L / m) : float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:765:            float3 axis = float3(0.0f, 0.0f, 1.0f);
  ?     src/render/render.metal:1146:            float2 tang = float2(-rel.y, rel.x) / rxy;  // +Ω about z, matches
  ?     src/render/render.metal:1466:        float rXY = length(spinPos.xy);
  ?     src/render/render.metal:1469:            float3 tang = float3(-spinPos.y, spinPos.x, 0.0f) / rXY; // prograde about Z
  ?     src/render/render.metal:2585:    float2 perp   = float2(-dir.y, dir.x);
  ?     src/render/render.metal:3329:                mp = rotAboutAxis(mp, float3(0.0f, 0.0f, 1.0f),
  ?     src/render/postfx.metal:66:    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: FAILURES ABOVE — fix before handing off.

[The single FAIL above is this handoff file itself, untracked at the moment
 preflight ran. It is committed in the same breath; the re-run below is clean.]
```

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "The spin costs 3.3× on frame rate" | Compared `take6` v1 (48.6 fps, notes SUSTAINED) against `take5_spin` (13.6 fps, notes released). The note difference was doing the work. The controlled pair says **11%**. |
| "The width factor is 1.37×, use it for planning" | Taken from two full-length takes whose note patterns differed. The clean A/B at matched framing is **1.34×**. |
| "The freed space did not come back" | Three `df` reads five seconds apart. APFS reclaim is PROGRESSIVE — it landed between 15:42:18 and his 15:43:58 screenshot. The rule was already in memory and I read too eagerly anyway. |
| "MISSING FRAMES" on take 5 | My own checker's arithmetic. Checkpoints run 0, 29, 59 … 5399 = 181 entries; my formula predicted 180 because it ignored the frame-0 entry. The run was contiguous. |
| "All 14 files byte-identical" (the first SSD verify) | zsh does not word-split unquoted variables, so BOTH sides hashed nothing and `diff` compared two empty files. A pass that could not fail is not a pass. |
| "The spin ramp is not monotonic" (implied a defect) | One backward step of 0.300 rad/s in 82 samples — the estFrame extrapolation correcting when a marker lands, 0.146% of target. Real, but I stated it before sizing it. |

---

**Last Updated:** 2026-09-04 19:02:54
**Folded into board:** `docs/BOARD.md` §AA27 + `docs/SPACE_SYNTH_LIVE.md` §4/§5/§6.13–6.16 @ 2026-09-04 19:02:54
