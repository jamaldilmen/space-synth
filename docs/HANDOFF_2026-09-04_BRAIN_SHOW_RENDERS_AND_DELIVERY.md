# SPACE SYNTH — BRAIN handoff 2026-09-04 15:17:38

> **His verdict on this state:** *"amazing"* (take 2's zoom, ~14:35) · *"yoo thevideo runs in resoulume smootoooth"* (~14:5x, the DXV3 pipeline) · *"the rotation seems wrong like the axis its not what i wanted"* (~14:57, take 3 — **CORRECT, it was**) · *"isnane but the zoom is jumpy ... its liek back and forth zoomies not one consistent ride"* (~12:28, take 1 — **CORRECT**)
> **Cold start:** read **`docs/SPACE_SYNTH_LIVE.md`** — the show bible, created this session on his order. Then `docs/BOARD.md` §AA26. NOT this file, NOT older handoffs.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `85b4aa3`
**Build + launch:** `bash package_macos.sh` && the capture invocation in §2.1 below
**My role:** routing, verification, measurement. Source in this session was written by SONNET; runs were driven by OPUS and (once) by me.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | **"Does frame time hold over a 10-minute render?" — his ordered question** | unknown; longest capture ever was 300 frames | **It holds.** Last ~30 min of wall clock drift **−0.39%**; all instability is the first ~20% (formation) | `/Users/airy/Desktop/sweep/r3_600s.log` | `[MEASURED n=600 blocks]` 18,000 frames, 3 slices, all exact, 0 writer failures, RSS flat |
| 2 | **A 60-second test gave the OPPOSITE answer** | R1 read "+121%, degrades severely" and was believed | That was the **formation transient** filling the window. Ten minutes shows it settles | same | `[MEASURED]` decile trajectory 129.8 → 233.6 → … → 216.0 ms |
| 3 | **The camera ride was timed in WALL seconds** | a "180 s" ride against a render at 2–10 fps ⇒ zoom finished in the first third | **Frame-locked** to `[CAPTURE] frame N` markers, driven by `N/maxFrames` | `logs/midi_ride_framelock.mm` | `[MEASURED]` zoom landed on 127 at marker 5399 |
| 4 | **7-bit CC cannot ride a 3-minute camera move — HIS catch** | 128 steps ⇒ one update per ~30 output frames vs a 15-frame settle ⇒ **134 lunges with dead stops** | **14-bit pairs.** Median gap **0.00 frames**, 1.08 updates/frame, **43×** the rate | `main.cpp` CC 20/52 | `[MEASURED n=5,693]` 2 of 5,693 over settle vs 129 of 133 |
| 5 | **14-bit MSB tick applied a stale LSB** | 23 lurches of ~15 rho per take | **Receiver-side LSB latch** + first-MSB fallback ⇒ **0 lurches** over a full take | `main.cpp` cases 20/52, 28/29 | `[MEASURED]` take 3: 0 stale-LSB over 4,952 zoom applications |
| 6 | **The orbit rolled the picture — HIS catch** | `refUp` is θ-derived (`camera.h:263`); we made θ the ORBIT angle ⇒ disk **vertical** and a **360° roll** | `orbitUpFix` pins `refUp` to the disk normal (0,0,−1) for orbit only | `camera.h:275` | `[READ]` + numeric basis check at θ=0/90/180/270 |
| 7 | **DXV3 delivery — could we, and at what size?** | unknown; Alley is GUI-only | ffmpeg's `dxv` encoder emits **DXT1 "Normal Quality, No Alpha"**, tagged `DXD3`. **~3× SMALLER than ProRes**, encodes at ~55 fps | `docs/SPACE_SYNTH_LIVE.md` §3 | `[MEASURED]` L 1.35 / C 1.44 MB/frame · `[HIS WORDS ~14:5x]` *"runs in resoulume smootoooth"* |
| 8 | **What the sim pause does during a capture** | never tested | Writer **cannot** stall or disarm; movie keeps recording at full byte cost; camera keeps riding. Gain here is ~+15%, **not** the 3× measured live | `main.cpp:2967` / `:3005` | `[READ]` brace-depth verified |
| 9 | **The show bible did not exist** | learnings lived in chat and three boards | **`docs/SPACE_SYNTH_LIVE.md`** — event, scale, pipeline, economics, 13 learnings each with what it cost | that file | `[HIS WORDS 2026-09-04 ~15:0x]` *"this must be the bible of the day"* |

**Deliverables on disk:** `~/Desktop/sweep/take2_3min_{L,C,R}.mov` (3 min, zoom-only, **KEEP**) · `dxv3_test_C_10sec.mov` (the DXV3 proof he played in Resolume). Take 1 and take 3 deleted on his order.

---

## 2. 🚨 OPEN — his list, verbatim

1. **`[HIS WORDS 2026-09-04 ~15:0x]`** *"now i want the run with a chord. now i want the same zoom out and tilt but bot hitting at the same time. so tile to 90 front on view and zoom at end of its path hitting at the same time. phase thing off."*
   `MEASURE:` 900-frame smoke, then `SS_RENDER_FPS=30 SS_WIDTH=19644 SS_HEIGHT=1680 SS_CAPTURE=/Users/airy/Desktop/sweep/take4_3min SS_CAPTURE_SLICES=7152,5340,7152 SS_CAPTURE_FRAMES=5400 SS_LENS_RENDER=1 SS_CAM_RHO=50`, ride `midi_ride_cmaj_tilt <log> 5400 600 50`.
   State: **BUILT, bundle 2026-09-04 15:13:59, NEVER RUN.** 🚨 **Everything in it is verified against SYNTHETIC LOGS ONLY** — the CC33 range selector, the full-range θ, the chord sequencing and the phase override have not met the app. **Smoke before spending 27 minutes.** The smoke must be **900** frames, not 300: the chord holds the camera static through frame 600, so a 300-frame smoke never starts the tilt and would pass while testing nothing.

2. **`[HIS WORDS ~14:57]`** *"then we wil do the bh run with proepr angles when thats done"* — the orbit re-run with the corrected up vector.
   `MEASURE:` same invocation, ride `midi_ride_orbit <log> 5400 50` (sends `camPhi` nonzero ⇒ φ=π/2 **and** `orbitUpFix`).
   State: built on the same bundle, **not run.** ⚠️ `iscoOrbit` is still held at **0.02 = 50× the default pose rate**, which spins AND smears the field independently of the camera. He asked *"is the time warp kicking in"* — **isolating it means one run at 1.0 with the camera orbit unchanged.** Not done, his call.

3. **`[HIS WORDS ~15:0x]`** *"we will just test a binch of setuips so i know how to prompt you the actual dinal renders later"* — these are LEARNING runs, not deliverables.
   State: the shot vocabulary is in `SPACE_SYNTH_LIVE.md` §5 — every CC, every framing, what each env does.

4. **`[HIS WORDS ~14:3x]`** *"the hard drive should be here soon"* — three 10-min parts is **~223 GB in DXV3** (was ~690 GB in ProRes). Conversion is one ffmpeg command per slice, ~16 min per part.

5. **`[HIS WORDS 2026-09-04 ~15:0x]`** *"we need to do the next runs with phaxe vx offfff important."*
   State: **DONE as a mechanism** — `phaseAmount` CC31 held at 0, and it lands in the log so a take is provably phase-off. `app_state.h` default deliberately unchanged. **Not yet exercised in a real run.**

---

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **`r_infl` as the render-cost driver — REJECTED 2026-09-04 03:23.** Fits well over one monotonic run (`^0.72`, r=0.890) and dies on the segment test: over the stretch where `r_infl` is FLAT the render still rose **+58%**, and over the stretch where it climbs 2.3× the render moved **+1.1%**. Two quantities riding the same clock. `Render ~ r_infl^0.16` over R3's wider range — the exponent is not stable across scales.
- **Seed mass as the driver — REJECTED same test, opposite segment.** Each explains exactly the stretch the other cannot.
- **Uninitialised / out-of-bounds memory as the formation mechanism — REJECTED 2026-09-04 ~12:00** by a full static bounds audit: no OOB index, no never-written slot reaching a physics decision, and Metal zero-fills at allocation. What survives is **thread-arrival order in atomic CAS** (`particles.metal:3931`/`:3935` merge claim, `:1650`/`:1791` seed budget) — verified at all three sites.
- **Reordering the 14-bit send to fix the stale byte — REJECTED by arithmetic.** MSB-first overshoots by 127 counts, LSB-first undershoots by 127. Symmetric. Only a receiver-side LSB latch removes it.
- **`[PROBE-1000] live` as a field measurement — REJECTED.** It is a 1,000-slot tracer of the heaviest stars, which the seed eats first: in one run the field read **−72%** and the tracer **−97%**. `live=` is ambiguous in these logs; always name the tag.
- **Cinematic settle (`C`) as the jumpy-zoom fix — NOT TAKEN.** It works (45-frame settle > the 30-frame gap) but it is a workaround for a resolution problem and it re-damps the orbit. 14-bit is the real fix.
- **Deleting the smoke movies before he had seen them — AVOIDED.** He opened `take3_smoke_*.mov`, saw 10 seconds and reported *"the take ended it wa sjust couple second slong"*. The real take had never launched. ⇒ **A smoke artefact left on his Desktop reads as a failed deliverable.** Name them unmistakably or delete them immediately.

---

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-04 15:15:43  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS

1. git
  ok    branch true-physics, HEAD 85b4aa3
  FAIL  5 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M imgui.ini
           M src/core/camera.h
           M src/main.cpp
          ?? docs/SPACE_SYNTH_LIVE.md
          ?? scratchpad/s6_cc_wip_2026-09-04.patch
  WARN  68 commit(s) not pushed

2. board vs HEAD
  ok    docs/BOARD_BLACKHOLE.md current at e750a73 — 6 docs-only commit(s) since, no source change
  WARN  docs/BOARD_BLACKHOLE.md is 258746B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 104965B — exempt (not read at cold start)
  ok    docs/BOARD.md current at e750a73 — 6 docs-only commit(s) since, no source change
  WARN  docs/BOARD.md is 196584B — split closed rows into BOARD_CLOSED.md

3. deployed artifact
  ok    SpaceSynth newer than newest source
  ok    default.metallib newer than newest source

4. referenced paths (live docs only)
  ok    62 referenced path(s) in live docs all resolve

5. orbital-plane convention — READ THESE, do not skip
  ?     src/render/render.metal:577 · :765 · :1146 · :1466 · :1469 · :2585 · :3329 · postfx.metal:66
  WARN  8 site(s) carry a plane assumption — confirm each is right HERE, not elsewhere

────────────────────────────────────────────────────────
PREFLIGHT: FAILURES ABOVE — fix before handing off.
```
**Resolution of the FAIL:** `src/core/camera.h` + `src/main.cpp` are SONNET's and are committed in ITS handoff (routed 15:17; FABLE correctly refused to touch another window's files). `imgui.ini` is the app's own auto-save, reverted at commit time. `scratchpad/s6_cc_wip…patch` is redundant with the applied source and is deleted, not committed. `docs/SPACE_SYNTH_LIVE.md` is mine and is committed here.

---

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| **"Compute owns the frame — 55–72% of GPU time"** (~03:0x) | `[PROFILE/120f]` times GPU **occupancy**, and the render buffer `encodeWaitForEvent`s on the compute event (`renderer.mm:2059`), so `Total` double-counts. The board already carried "unreliable for apportioning cost" and I did not look it up. Replaced by compute vs the **frame interval** — 101/114/118% on a stalled scene — and then by #7 below. |
| **"On a forming scene compute is the bottleneck"** | Inverted on the first real forming capture: Compute 32.80 → 38.54 ms (flat) while **Render 12.64 → 201.29 (×15.9)**. The three older logs were all **stalled** scenes (biggest body pinned at exactly 50 M). Different scenes, different bottlenecks. |
| **"`r_infl` may be the mechanism"** — handed to OPUS as a lead | Overreach on a 60 s monotonic correlation. OPUS's segment test killed it. See §3. |
| **The seed-registry count as an independent second observable** | It tracks formation time exactly within the same arm (nReg 1 ⇔ formed at sample 5; nReg 9–10 ⇔ formed at sample 2). Derived, not independent. **The same pooling error I had warned OPUS about four hours earlier.** |
| **"220 spin updates in the smoke, sub-frame, gliding"** | Those were the spring's **position samples** from the `else` branch, not applied targets. Applied θ was 7-bit. Conclusion (smooth) survived; the mechanism was wrong. |
| **"DXV3 will be ~89 GB per 3-min take, bigger than ProRes"** | Assumed fixed-rate DXT1 at 4 bpp. The encoder uses LZ-style back-references (`libavcodec/dxvenc.c`) and crushes this footage's black. **Measured ~22 GB — 3× SMALLER.** |
| **"`r_infl` reaches 160× design scale"** | I read the tail of the file instead of sorting it. Sorted max is **9,152 = 458×**. |
| **Message headers 03:00 – 03:11, and again ~13:00** | Typed from a sense of elapsed time, not read from `date`; ran up to **5 minutes fast**. Cross-window event ordering was wrong until OPUS noticed the skew. Log timestamps and file mtimes were always real. |
| **"`SS_CAPTURE=1`"** in the previous handoff | It is a base **PATH** — `=1` writes `1_L.mov` into the repo. Full path always. |
| **"Take 4 is an orbit"** — briefed to SONNET, which built it that way | His order was a **tilt to 90° face-on**, φ=0. Caught before the smoke; cost one rebuild. |

---

**Last Updated:** 2026-09-04 15:17:38
**Folded into board:** `docs/BOARD.md` §AA26 — **PENDING**, FABLE holds both board files until it releases (announced 15:16). This handoff is written first; the board row follows and is committed separately.
