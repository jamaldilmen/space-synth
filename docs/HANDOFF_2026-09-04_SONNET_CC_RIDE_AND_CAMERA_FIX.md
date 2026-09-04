# SPACE SYNTH — handoff 2026-09-04 15:20:00 (SONNET)

> **His verdict on this state:** not seen yet — take 4 (chord+tilt) is built and ready but did not run this session; he called `/handoff` across all four windows before it launched.
> **Cold start:** read `docs/BOARD_BLACKHOLE.md` §AD → §AC.12 → `docs/BOARD.md` — NOT this file. This session's rows are NOT yet folded into the board (FABLE holds it; BRAIN is queued for §AA26 after release) — until they land there, this file is the only record of what changed.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `ff1fdc0`
**Build + launch:** `bash package_macos.sh` then launch directly with stdout captured (`./SpaceSynth.app/Contents/MacOS/SpaceSynth > logs/<name>.log 2>&1 &`) — MIDI rides need the log for frame-lock. Last bundle built 15:13:59, newer than source — verified.

---

## 1. ✅ CLOSED THIS SESSION (confirmed live, in a real take)

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | CC never reached a parameter | Wired, printed, no consumer (S1 shipped it, nothing used it) | 6 faders + `pause` excluded, CC20-26 | `main.cpp` onMidi CC arm | `[MEASURED n=6]` take 2 log: all six first/max/last raw correct, sweep-and-reset |
| 2 | 7-bit zoom stepped, "back and forth zoomies" | Camera fully settled (0.5s spring) then sat still 3.4-98.4s between CC steps | 14-bit pair CC20 MSB/CC52 LSB, MSB-caches/LSB-applies latch | `main.cpp` case 20/52 | `[MEASURED]` take 1's own log, gap stats; take 3 ran the fix live, his words "zoom ramping monotonically, all six live" (BRAIN, relayed) |
| 3 | camPhi 7-bit scaled value can't land on exactly 90° | raw 32 → 90.72°, `cosφ=-0.0124` → ±24.8-unit vertical bob once per revolution at rho=2000 | Exact 2-value selector: raw 0=φ=0, nonzero=φ=π/2 | `main.cpp` case 30 | `[READ]` formula + arithmetic, verified before shipping — not yet re-measured live post-fix |
| 4 | Frame-locked ride desyncs from wall-clock capture | First 3-min driver ran on wall time; capture ran 3.47fps not the assumed ~30 → take aborted at 55s, zoom stalled in the first third | Driver tails `[CAPTURE] frame N written`, extrapolates between markers, snaps on each new one | `logs/midi_ride_framelock*.mm` (not committed — standalone tool) | `[MEASURED]` take 3 completed full 5400 frames on this mechanism |

## 2. 🚨 OPEN — his list, verbatim

1. **"i want the same zoom out and tilt but bot hitting at the same time... tile to 90 front on view and zoom at end of its path hitting at the same time. phase thing off."** (take 4)
   `MEASURE:` run `logs/midi_ride_cmaj_tilt` against a live capture, grep for `theta14=16383` and `zoom14=16383` on the SAME `marker=`.
   State: built, bundle 15:13:59 has it. **NEVER RUN AGAINST THE APP** — verified only against a synthetic log (chord hold, release, both parameters landing together at frac=1.0). CC33 range selector (raw 0=2π orbit / nonzero=π/2 tilt), phaseAmount CC31 held-0, chord NoteOn/NoteOff sequencing at frame 0/600 — all four pieces are synthetic-log-only.

2. **"another hting w eneed to do the next runs with phaxe vx offfff important."**
   `MEASURE:` grep a real take's log for `[MIDI-MAP] phaseAmount cc=31 raw=0`.
   State: CC31 built, `app_state.h` default (0.35) deliberately untouched — his UI default, not overridden. Never sent in a real take yet.

3. **Orbit re-run with the up-vector fix** (take 3 replacement, "the rotation seems wrong ... not what i wanted")
   `MEASURE:` re-run `logs/midi_ride_orbit`, confirm `screenUp` no longer sweeps — visual verdict only he can give.
   State: `orbitUpFix` built into `camera.h`, armed automatically by `camPhi` nonzero. **Verified only by reproducing `buildViewMatrix`'s exact math in Python** (`[READ]` + independent numerical check, not `[MEASURED]` from a running process) — never rendered.

4. **S6, the full CC→parameter registry** (~55 `UiSliderFloat`/`UiSliderInt` sites, board §AA15/§AA18/§AA19) — still not started. Tonight's build is hardcoded test CCs on 10 parameters, explicitly scoped down from "all faders" under time pressure (his own later order: "so tile w bot hitting" etc. kept arriving faster than a full registry could be built safely). Two raw bypasses (Master Volume, Space Scale) still need special-case handling whenever the real registry is built.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **Wall-clock-timed ride driver — REJECTED 2026-09-04 ~11:40:00.** Assumed ~30fps; capture ran 3.47-10.34fps depending on scene load. Take 3's first attempt aborted at 55s, zoom finished in the first third. Frame-locking off `[CAPTURE] frame N written` is the only correct approach for anything durationally tied to the render, not the wall clock — this is permanent, not a today-only fix (board's own S6 "replay at exactly 30fps" note already said so).
- **Apply-on-either-half for 14-bit MSB/LSB — REJECTED 2026-09-04 ~13:56:00.** A fresh MSB applying immediately against a stale cached LSB produced measured ~15rho lurches (OPUS, 23 occurrences in take 2, each <1ms). Fixed to cache-on-MSB/apply-on-LSB, with a first-message-only coarse fallback so a 7-bit-only sender still moves once.
- **θ range capped to a literal quarter of the 14-bit value (v14≤4096) for a 90° sweep — REJECTED 2026-09-04 ~15:12:00.** Landed exactly on 90° but wasted 3/4 of the quantization density — OPUS measured this would give 32 crossings over 4800 frames (one per 150) vs take 3's proven-continuous 127-over-5400 (one per 43), reproducing take-1-style stepping in the tilt shot meant to replace a broken take. Fixed by scaling on the RECEIVER (CC33) so the driver always sends the full 0-16383 range regardless of the target angular span.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-04 15:18:33  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS

1. git
  ok    branch true-physics, HEAD ff1fdc0
  FAIL  2 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
          ?? docs/SPACE_SYNTH_LIVE.md
          ?? docs/patches/
  WARN  70 commit(s) not pushed

2. board vs HEAD
  FAIL  docs/BOARD_BLACKHOLE.md is 2 code commit(s) behind HEAD (verified at e750a73)
  WARN  docs/BOARD_BLACKHOLE.md is 258746B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 104965B — exempt (not read at cold start)
  FAIL  docs/BOARD.md is 2 code commit(s) behind HEAD (verified at e750a73)
  WARN  docs/BOARD.md is 196584B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    62 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:577,765,1146,1466,1469,2585,3329; src/render/postfx.metal:66
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: FAILURES ABOVE — fix before handing off.
```

**Both FAILs above are NOT mine to fix, confirmed with BRAIN before leaving them:**
- The 2 uncommitted paths are `docs/SPACE_SYNTH_LIVE.md` (BRAIN's, created on his order, BRAIN commits it) and `docs/patches/fable_merge_diag_2026-09-04.patch` (FABLE's own file, appeared during this session, not mine to touch).
- The board-behind FAIL is this session's two commits (`14757d5`, `ff1fdc0`) — BRAIN is holding the fold for its own `§AA26` slot, queued behind FABLE's release of the board files. Not folded here per "one window owns the board at a time."

§5 orbital-plane WARN: read all 8 sites — none reference `Camera::theta`/`phi`/the view matrix; they're the simulation's own world-space spin axis (particle-level, `particles.metal`/`render.metal`), a different concern from this session's camera view-matrix change. Confirmed no interaction, not just assumed.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| none | — |

---

**Last Updated:** 2026-09-04 15:20:00
**Folded into board:** NOT YET — BRAIN queued for `§AA26`, after FABLE releases `docs/BOARD.md`/`docs/BOARD_BLACKHOLE.md`.
