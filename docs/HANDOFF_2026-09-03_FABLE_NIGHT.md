# SPACE SYNTH — handoff 2026-09-03 15:45:00 (FABLE — the night build window: parser, floor, hold, and the field that leaves)

> **His verdict on this state:** on the floor build (before bed, via BRAIN): *"Field is fine. Chladni too dsrk. And pixely."* · *"No chladni weird different Color profile clearly."* · *"Also not fine filament at sustain but lowkey buggy. Maybe it's the hardening thing. It used to be so goated in tube."* · on the pull: *"Soon ss the bh is there retun pull must go cause bh has its own gravity taking over"* · this morning, correcting §5b: *"No that's not it. The reason is there are way fewer particles per pixel now. Before we had every single particle in the dense field. Today chladni shape is not dense is coarse."*
> **Cold start:** read `docs/BOARD_BLACKHOLE.md` (BRAIN folds the night as its next section) and `docs/BRIEFING_2026-09-03_NIGHT.md` — NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `74bee76` (my two source commits: `ae0449e` floor, `74bee76` hold; SONNET's parser `9fbe0ba` was built and verified by me). 24+ commits UNPUSHED, no push order. ⚠️ **Every `file:line` below is at `74bee76`**; `main.cpp` moved back by 11 when the TEMP-DIAG was stripped — re-grep, never renumber.
**Build + launch:** `bash package_macos.sh` then `SS_FULLSCREEN=1 SS_LENS_RENDER=1 ./SpaceSynth.app/Contents/MacOS/SpaceSynth`. ⚠️ **The bundle on disk (06:08:22) was built WITH `SS_PHASE_AMOUNT` in `main.cpp`, which is now stripped from source — binary ≠ source until the next build.** Not rebuilt: no build order, app down. Measurement launch used all night: add `SS_TWO_WINDOWS=1` (UI in its own window) and `SS_CAM_RHO=2000` (his max zoom-out; 800 = ±9.6 sim, 2000 = ±24 sim, `camera.h:114/127`), capture the show window by CG window id (`screencapture -x -l <id>`), never the whole screen.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | MIDI System Real-Time bytes (0xF8 clock, 0xFE active-sensing, 0xFA start) parsed as 3-byte messages; a clock sharing a CoreMIDI packet with a Note On ate the note, and a Note Off too (stuck notes) | intermittent missing/stuck notes on any DAW-clocked path | 1-byte skip before the status mask (SONNET's hunk, `9fbe0ba`, built + verified by me) | `midi_input.mm:28` | `[MEASURED n=8 cases]` real parser compiled into a harness, HEAD vs fix: `[F8][90 3C 64]` nothing → noteOn(60); `[F8][80 3C 00]` nothing → noteOff(60); `[F8 F8 F8][90 3C 64]` noteOn both (why it was intermittent). Live: built app, IAC Driver Bus 1, one packet `F8 90 3C 64` → `[MIDI] noteOn note=60`. IAC path only; USB controller not measured. |
| 2 | Chladni bars read as dashed lines at an angle ("unterbrochene Linien wegen dem Angle") | every play sprite floored at 1.0 REFERENCE px (`render.metal:1388`, collapse `:1409`) then × `sizeResScale = height/2260` (`renderer.mm:2156`, 08-21 More-Space panel) → **0.84 device px** on today's 3024×1898 drawable | floor at ONE DEVICE PIXEL after the scale, culls stay 0 (`ae0449e`) | `render.metal:2539` | `[MEASURED]` standalone Metal, M5 Max, 200 points on a 20° line, random sub-pixel offsets: **0.84 px → 137/200 lit, 63 empty columns; 1.00 px → 200/200**. `[MEASURED n=3+]` own captures after: 95–100% of lit pixels have a lit 4-neighbour. **His eyes: not yet.** Does NOT touch "pixely" (row 5). |
| 3 | Return pull came back after play: v3 fade was PROPORTIONAL, `ramp *= 1 − bhStrength`, so at 0.3 the pull ran at 70% | AD.7 | v4 hold latch: engages at first `bhStrength >= 1.0` (the 100% law, `renderer.mm:2203`), clears ONLY at `lastHorizonR <= 0` (seed class dead, `:3783/:3810`); `[RETURN]` prints `r_h=` and `hold=` (`74bee76`) | `renderer.mm:1854-1857` | `[MEASURED n=3]` formation → 8 s chord: hold=1 at +8–9 s, pull 0.00, play pumps Mmax to exactly 50, r_h→0, hold clears, pull ramps for the next formation. `[MEASURED n=3]` formation → 60 s soak → **2 s chord**: seed survives at 1,600–2,200 M☉, bhStrength **0.01**, hold stays 1, `[MASSCENSUS] pull=0.00` on 15/15 unconditional samples. `[HIS WORDS]` the ruling above. Verified as mechanism + surviving-seed regime only; his eyes on the look: not yet. |
| 4 | "Chladni weird different colour profile" | unknown | the PHASE TINT (`render.metal:2322`, amount 0.35 default, hue rotated by the particle's own path length, OPUS's read) | `render.metal:2322` · fader `main.cpp:1489` | `[MEASURED n=3 vs 3]` per-bar-pixel hue change over 0.5 s: tint 0.35 → **11–21°**, tint 0 → **3°**; bar saturation 0.50–0.57 → 0.61–0.62. Isolated-pixel and partial-intensity fractions IDENTICAL between arms ⇒ tint is the colour noise, not the geometry. His fader test: Phase Amount → 0 during a chord. |
| 5 | BRAIN's first return-pull gate `if (lastHorizonR > 0) ramp = 0` | proposed | NOT BUILT — disproved by arithmetic before the file was touched | `renderer.mm:3783` + `particles.metal:1470` | `[READ]` `lastHorizonR > 0` ⇔ some body ≥ 50 M☉ exists ⇔ exactly the set `RETURN_MIN_MASS = 50` lets the pull act on ⇒ dead code by construction. BRAIN accepted, re-authorised (B). |

## 2. 🚨 OPEN — his list, verbatim

1. **"Chladni too dsrk"** → this morning: **"there are way fewer particles per pixel now… today chladni shape is not dense is coarse."**
   `MEASURE:` `[GRAV] live=` (mass>0.001 count, `renderer.mm:3863`) before a chord, during, after — in HIS regime (long rest, fed hole, `mrg` in the thousands), which nobody ran.
   State: `[MEASURED n=20 logs]` `live=` **never below 1,982,817 of 2,000,000** in any run last night (rest 1,999,997; every chord 1,999,9xx); `Mlive` 594,276 on every sample. In those runs the count was intact and the per-pixel loss was AREA: `[MEASURED n=5]` meanR 11.2 → 27.2 plateau, maxR 60 → 90 during a 26-s chord, identical to 2 decimals; HDR frame-average (`[LUMPROBE]`, `renderer.mm:5133`) 0.05–0.10 at rest → 0.000 in play; **legibility: below 10% of rest brightness in 1–2 s, at the floor in 3–4 s; at rho 2000 below 10% within the first second.** Ruled out by relaunch A/B: `SS_NO_COVERAGE`, `SS_NO_DEPTH_PREPASS`, rho 800 vs 2000, far plane. Dated: `912e4bf` (2026-08-27 17:21:29) deleted the play CAN (r≤6) and says *"The wall was doing the shaping"*; the 09-02 buffer (`particles.metal:385/3404`) is a cap, not a boundary. **His reading wins where the logs are silent:** the "invisible abyss" pile (~46%, `particles.metal:785`) is a long-rest many-merge regime; rebirth is sustain-only. `[HYPOTHESIS]` for his sessions; `[MEASURED]` only for last night's.
2. **"And pixely."** `MEASURE:` his eyes with Phase Amount at 0 vs 0.35 (row 4 removes the colour noise, geometry unchanged). State: the 1-px hard point is neither exonerated nor convicted. Arm B (floor OUT) and the pin (`SS_WIDTH=3600 SS_HEIGHT=2260`, today's panel only) DROPPED on BRAIN's order.
3. **"not fine filament at sustain but lowkey buggy. Maybe it's the hardening thing. It used to be so goated in tube."** State: hardening producer (`particles.metal:3172-3187`) and all consumers (`:3374-3376`, sustain lock, release ramp) are **code-identical** to `SPACE-SYNTH-TUBE` @ 13ac249; ridge-pull region diffs to zero lines. Hardening cannot act on matter leaving at the play cap — same root as #1. "In tube" is literal (the can).
4. **"the black hole should never exceed a certain size… the size must be in sync of the whole, the lens and the force"** — untouched this session. σ is pinned (§AD.1); the cap is derivable, not started.
5. **Merger stand-off** — his ruling *"Both — they're the same stall."* State: `[READ]` no path consumes a ≥50 M☉ body: `merge_stars` refuses ≥50 at input (`particles.metal:3837`), seed capture requires a victim < 50 (`:1519`). `[MEASURED n=7]` `mrg=reached/landed/refused` 0/0/0 on 27+ samples with seeds ≤ 4; **refused = 0 always; denominators too small for a rate**. 2-s chords FRAGMENT a seed into 5–10 registry bodies which then fall back to 2–4 (3/3) — observed, mechanism UNEXPLAINED (no channel named; `seeds=` read 0 once with Mmax 2,154 alive, counter suspect).
6. **`bhStrength = 0.01` while a 1.6–2.2k M☉ hole is alive and GROWING, 3/3** (`[BH-POP] … LATCH` on every line). The lens gates on `bhStrength >= 1.0` (`renderer.mm:2203`), so after a short chord he has a hole the engine believes in and the renderer draws almost nothing for. Needs his ruling on what "formed" means after play — a definition, not a defect. BRAIN's §4 headline.
7. **"the transition from black hole to play looks weird"** — undescribed, unmeasured.
8. **"webbspikes i dont see"** — `SS_SPIKES=jwst` draws inside the sprite footprint; not built wider.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **`lastHorizonR > 0` as the return-pull gate — REJECTED 2026-09-03 06:01:xx.** Zeroes the pull exactly when it has a body to act on (row 5 above). Any "hole exists" test must not be the same predicate as the pull's target set.
- **Per-pixel hue drift as a test of OPUS's 20.69× play/rest phase RATE — NOT MEASURABLE 06:44.** Rest reads 3.7–12.5° per 0.5 s, which is sampling (different matter under the pixel), not phase rate. The A/A0 arm settles CAUSATION only; the rate stays predicted.
- **`SS_PHASE_AMOUNT` TEMP-DIAG in `main.cpp` — STRIPPED 15:43 on BRAIN's order** after 3/3; the real fader (`main.cpp:1489`) is his test. Do not re-add a launch hook for a fader that exists.
- **Whole-screen `screencapture` with the UI up — INVALID.** My first "bar" measurement was the Architect panel (mean lum 75). Use `SS_TWO_WINDOWS=1` + window-id capture, and check the frame with your own eyes before trusting a classifier.
- **8-s chord as the AD.7 test — WRONG REGIME.** Kills every seed we grew (3/3 + a 2,452 M☉ one); 2 s is the regime where a seed survives. Whether he plays 2-s chords is his side.
- **"Chladni too dark" as a luminance/exposure/bloom/alpha/coverage fault — RULED OUT by A/B 06:2x.** And "the field leaves" as the WHOLE story — CORRECTED BY HIM this morning: coarse = fewer particles per pixel; the spread is one cause of that, the eaten pile is the other, and last night's logs only cover the first.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-03 15:42:35  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS   (run BEFORE my commits; re-run below)

1. git
  ok    branch true-physics, HEAD 03474e0
  FAIL  6 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M docs/BOARD_BLACKHOLE.md          ← BRAIN's (re-stamp in progress, waits on my shas)
           M src/main.cpp                     ← STRIPPED 15:43 (git restore), BRAIN's order
           M src/render/render.metal          ← COMMITTED ae0449e
           M src/render/renderer.mm           ← COMMITTED 74bee76
          ?? docs/BRIEFING_2026-09-03_NIGHT.md      ← BRAIN's
          ?? docs/HANDOFF_2026-09-03_BRAIN_NIGHT.md ← BRAIN's
  WARN  24 commit(s) not pushed             ← no push order
2. board vs HEAD
  FAIL  docs/BOARD_BLACKHOLE.md is 1 code commit(s) behind HEAD (verified at dbda8e8)   ← BRAIN re-stamps after my shas
  WARN  docs/BOARD_BLACKHOLE.md is 255205B — split closed rows into BOARD_CLOSED.md
  WARN  docs/BOARD.md has no 'Commit at last verification' line · 166995B
3. deployed artifact
  ok    SpaceSynth newer than newest source      ← TRUE BY TIMESTAMP ONLY: bundle 06:08:22 contains the stripped diag
  ok    default.metallib newer than newest source
4. referenced paths (live docs only)
  ok    46 referenced path(s) in live docs all resolve
5. orbital-plane convention — 8 site(s) carry a plane assumption (render.metal:577/765/1146/1466/1469/2585/3329, postfx.metal:66) — none touched this session
PREFLIGHT: FAILURES ABOVE — fix before handing off.
```
Re-run after my commits and BRAIN's board re-stamp (HEAD `47af4ae`, board current at `74bee76`):
```
PREFLIGHT 2026-09-03 15:46:44
1. git   ok branch true-physics, HEAD 47af4ae
         FAIL 2 uncommitted: ?? docs/HANDOFF_2026-09-03_BRAIN_NIGHT.md (BRAIN's)  ?? docs/HANDOFF_2026-09-03_FABLE_NIGHT.md (this file, committed alone right after)
         WARN 28 commit(s) not pushed — no push order
2. board ok docs/BOARD_BLACKHOLE.md current at 74bee76 — 2 docs-only commit(s) since, no source change
3. deployed artifact
         FAIL STALE: SpaceSynth predates src/main.cpp — run the packaging script, do not test this
         FAIL STALE: default.metallib predates src/main.cpp
         ← WAS true at 15:46 (the 06:08:22 bundle carried the stripped hook). CLEARED 2026-09-03 17:15:33: rebuilt after
           the Metal toolchain was reinstalled (Xcode 26.6 + the separate MetalToolchain component; the 15:50 build failed
           on missing libc++ headers because the Downloads Xcode had been deleted — toolchain, not code). Verified:
           main.cpp.o recompiled, linked, `strings` shows 0 hits for SS_PHASE_AMOUNT in the bundle binary, both artifacts
           17:15:33 > every source. NOT launched — his eyes own the floor and hold verdicts.
4. paths ok 46 referenced path(s) resolve
```

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| "The 2-s chord fragments the seed and the pieces RE-MERGE via seed_mark/seed_apply" | The victim gate (`particles.metal:1519`) requires mass < 50; no channel consumes a ≥50 body. Re-merge observed in `seeds=`, mechanism unexplained (BRAIN's correction, accepted). |
| "Chladni too dark = the field LEAVES the frame" as the cause | His correction: coarse = fewer particles PER PIXEL. The spread is real (5/5) but it is one contributor; the eaten pile in his regime is the other and last night's logs cannot see it. |
| First A-run "bars mean lum 75, 0.3% isolated" | The classifier measured the ImGui Architect panel, not the field. Withdrawn; all later numbers are window-id captures with the UI in its own window. |
| "The play sprites are rendered dark" (before the A/Bs) | HDR average 0.000 with coverage and depth prepass off and at two zooms ⇒ not drawn dark; not in frame / spread. |
| Estimated stamps | none this session — every stamp from `date`. |

---

**Last Updated:** 2026-09-03 15:45:00
**Folded into board:** BRAIN folds the night into `docs/BOARD_BLACKHOLE.md` (his order: the board is BRAIN's); FABLE wrote no board rows.
