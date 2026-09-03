# SPACE SYNTH — handoff 2026-09-03 22:25:14 (FABLE — the show renderer: S8 CAPTURE SHIPPED AND MEASURED, the first frames exist)

> **His verdict on this state `[HIS WORDS via BRAIN]`:** *"Test looks amazing. Bravo."* (2026-09-03 ~21:2x, his eyes on the frame-200 wall composite — the LOOK is accepted) · *"It doesnt matter. Every fader gets the same movement. I'll list all parameters that need mod support when I'm home in front of screen."* (~21:06 ⇒ S7 = ONE universal slew law; the parameter list is HIS) · *"what I wanna do is have my set in one session. The entire 30 mins. Press play. Send it to space synth. And watch it render. I need a real time preview."* (⇒ the target workflow; S6 mapping is its blocker) · *"Run it"* (~20:2x, the one authorized launch — used) · *"Fix cosmetics"* (20:57). Standing order: *"This is the most improtant build of the project. Highest prio."*
> **Cold start:** read `docs/BOARD.md` §AA (BRAIN's; it folds S1–S5 at `52f6d68` — S8 below is NOT folded yet, BRAIN owns the fold), then `docs/DESIGN_2026-09-03_OFFLINE_RENDERING.md` (SONNET) and `docs/DESIGN_2026-09-03_MIDI_MAP_AND_LINK.md` §10 (OPUS, the S6 spec) — NOT this file.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `3e085d7` (sources end here: `c6cad75` S8 capture · `3e085d7` two log strings; before that `52f6d68` S5 and the seven renderer commits of the afternoon). 51 commits UNPUSHED, no push order. ⚠️ Every `file:line` below is at `3e085d7`. Since `52f6d68`: `main.cpp` +52/−6 (hunks at old 7 · 141 · 184 · 715 · 3232), `renderer.mm` +118/−3 (old 3 · 335 · 446 · 1392 · 2203 · 5359 · 5487 · 5488 · 5490 · 5492 · 5729 · 5887 · 6003 · 6005), `window.mm` +18/−1, `renderer.h` +11, `take_replay.cpp` 1/1, `CMakeLists.txt` +3, two new files. PIECEWISE — re-read, never renumber.
**Build + launch:** `bash package_macos.sh` (bundle 20:58:03 = source). Live: `SS_FULLSCREEN=1 SS_LENS_RENDER=1 ./SpaceSynth.app/Contents/MacOS/SpaceSynth`. **Record a take:** `SS_RECORD=<take.txt>` (marker CC 119 at bar 1 beat 1). **Render the wall:** `SS_RENDER_FPS=30 SS_REPLAY=<take.txt> SS_WIDTH=19644 SS_HEIGHT=1680 SS_CAPTURE=<base> SS_CAPTURE_SLICES=7152,5340,7152 [SS_CAPTURE_FRAMES=n] SS_LENS_RENDER=1 ./SpaceSynth.app/Contents/MacOS/SpaceSynth` → `<base>_L.mov` / `_C.mov` / `_R.mov` (ProRes 422 HQ, 709); unset `SS_CAPTURE_FRAMES` = until quit (close button / Cmd+Q closes the files). Half-res preview render: `SS_WIDTH=9822 SS_HEIGHT=840`, one file with `SS_CAPTURE_SLICES` unset.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1–6 | S1 parser · S2 recorder · S3 offline clock · S4 replay (ceil) · S9 envelope · S5 resolution pin | see the 18:33 version of this file, folded as `docs/BOARD.md` §AA1–AA6 | unchanged | — | `[MEASURED]` in §AA |
| 7 | **0 frames existed. The wall could not be rendered: the presenting `CAMetalLayer` refuses any drawable above 16,384 wide** (nextDrawable nil → SIGSEGV on the final blit, his *"it crashed lol"* 18:22) | the final post pass wrote to `drawable.texture`; every target followed the layer's size | **The RENDER size is pinned apart from the layer.** `Renderer::pinRenderSize` (`renderer.mm:6109`, called `main.cpp:206`): every target at the render size, `resize()` ignores its arguments while pinned (`:5975`). Final pass → offscreen `finalTexture` (EDR, feeds `prevFrameTexture` exactly as the drawable did, `:5373`/`:5537`); second pass with `edrHeadroom=1.0` → `captureTexture` (`:5506`, what the projector sees — the Syphon reasoning; the Syphon block itself untouched); third pass at the DRAWABLE's size → the on-screen preview (`:5540`; UV is vertex-derived, `postfx.metal:112`, so only `resolution` changes). `main.cpp:142`: the drawable is the largest exact half (1/2..1/8) `canAllocateDrawable()` accepts — 19,644 → 9,822×840, same aspect by construction (the camera aspect reads the drawable, `main.cpp:1068`). Unpinned: nil targets, live path byte for byte | `renderer.mm`, `main.cpp` | `[MEASURED n=1 run, 300 frames]` log: `[S8] render 19644x1680 exceeds what the layer presents: drawable pinned to the 1/2 preview 9822x840` · `[SIZE] … reference height 1680 -> sizeResScale 1.0000` · no crash (`c6cad75`) |
| 8 | **No writer** | — | `src/render/show_capture.{h,mm}`: `SS_CAPTURE=<base>` arms one `AVAssetWriter` per slice (`SS_CAPTURE_SLICES`, widths must sum to the render width or refused; unset = one file), ProRes 422 HQ tagged 709, fed by **64RGBAHalf IOSurface pixel buffers wrapped as RGBA16Float Metal textures via `CVMetalTextureCache`** — the render targets' own format, no conversion (`show_capture.mm:110`); one blit per slice (`:160`); after commit `waitUntilCompleted` + append at pts `frame/fps` (`renderer.mm:5810`, `show_capture.mm:183`); back-pressure = wait on `isReadyForMoreMediaData`, never drop; `SS_CAPTURE_FRAMES=n` closes the files and ends the run (`main.cpp:749`; `Window::close()` now actually stops NSApp, `window.mm:813` — it had no callers and only raised a flag). Refused without the offline clock | `show_capture.mm`, `main.cpp:210` | `[MEASURED]` standalone probe BEFORE the code: adaptor accepts 64RGBAHalf at 7152×1680 and 5340×1680, decoded clears = `fe0000`/`00ff01`/`0000ff` (exact) · **the run 20:22:04→20:22:11:** `ffprobe` L `7152,1680,300` · C `5340,1680,300` · R `7152,1680,300`, `prores` HQ `yuv422p10le` bt709 (verified independently by BRAIN); app quit itself, exit 0, no crash report (`c6cad75`) |
| 9 | Full-res speed and memory were `[HYPOTHESIS]` | 9,822 measured 21.6 fps windowed (S5) | **300 frames at 19,644×1680 rendered AND written in ≤ 7 s wall ⇒ ≥ 43 frames/s, faster than real time**; the app's own counter 16 (warm-up) → 49 → 71 → 76 → 80; `[PROFILE/120f] Compute avg 11.11 (min 5.33 max 48.17) \| Render+PostFX avg 9.26 (min 6.89 max 30.33) \| Total avg 20.36 max 78.50 ms`; **peak RSS 2.56 GB** (1-s `ps` samples: 0.42 → 2.28 → 2.38 → 2.55 → 2.56 → 2.51 → 2.55 GB). ⚠️ 2M particles, **no hole formed** (`hole 0%`) — the lens pass cost at this width is still unmeasured | run log `scratchpad/s8_run.log` (session dir) | `[MEASURED n=1 run]` |
| 10 | Two stale log strings | `[REPLAY] ARMED … floor(t*fps)` (schedule has been ceil since `d6cbb7c`); `[SIZE] drawable WxH` (since S8 that number is the render size) | `ceil` · `[SIZE] render WxH (= the drawable live; the pinned render size under S8)` — strings only, no maths | `take_replay.cpp:75`, `renderer.mm:2217` | `[READ]` literals read back out of the built binary with `strings`, no launch (`3e085d7`) |

## 2. 🚨 OPEN — his list, verbatim

1. **"what I wanna do is have my set in one session. The entire 30 mins. Press play. Send it to space synth. And watch it render. I need a real time preview."** — S6 mapping (OPUS §1.5/§3.4: apply OUTSIDE `if (showHUD)`, refuse the marker CC) is the blocker; CC events already reach `onMidi` (`main.cpp:300`) and are printed with no consumer. `MEASURE:` a logged 0→127 sweep moves a mapped fader in replay with a per-frame value trace; two renders identical. State: not started.
2. **"It doesnt matter. Every fader gets the same movement."** — S7 = ONE slew law on the frame clock, universal; no per-parameter table. **He names the parameters that get mod support, from the screen — do not pre-empt the list.** State: not started, waiting on his list.
3. **Disk budget, `[MEASURED-derived]`:** L 982,726,939 B + C 1,050,482,859 B + R 967,337,195 B for 10 s = **300 MB/s for all three walls ⇒ a 30-minute set ≈ 540 GB** of ProRes 422 HQ. HIS number to plan around (344 GB free on / at 19:53). Not a fault; a fact he has to rule on (drive, or a lighter codec for the sides).
4. **Alignment to the Ableton timeline** — `[MEASURED]` on the SYNTHETIC take only: each replayed event lands 0–33 ms after its recorded time, never before. `[UNVERIFIED]` Ableton's own MIDI stamping (`stamps packet|callback|mixed` in the take header) and end-to-end frame-vs-bar — now testable, the files exist.
5. **What is in the frames** `[MEASURED n=3 frames × 3 walls, 10-bit luma]`: C YAVG 93.7/68.1/73.5, YMAX to 928; **L and R YAVG 64.6 (video black is 64), YMAX 400–650** — the matter sits in the centre 5,340 of the 19,644 in this take. His eyes accepted the look (*"Bravo"*); composition of the side walls is his call, not a writer fault.
6. **Lens cost at 19,644 wide** — unmeasured (no hole in the synthetic take). `MEASURE:` a take that forms a hole, same env, read `[PROFILE/120f]`.
7. **Floor `ae0449e` + hold `74bee76`** (this morning) — still await his eyes.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **The on-screen drawable as the wall-size render target — DEAD `[MEASURED 18:22]`.** The layer cannot present > 16,384; the final pass now renders offscreen (row 7). The drawable is a preview only.
- **Three cameras / off-axis frusta per wall — REJECTED BY HIM ~16:2x** (*"Not by rotating the camera"*). One image, crop three slices — which is what `SS_CAPTURE_SLICES` does.
- **A typed pin ceiling (16384 / 32768) — DEAD.** Measured on the device (`canAllocateDrawable`); Metal aborts above 32,768 rather than returning nil.
- **Changing the live `dt` to 1/60 — REJECTED (his "smarter compromise")**: offline only.
- **`floor(t·fps)` for replay — RETRACTED 18:1x**, `ceil` since `d6cbb7c`.
- **A per-parameter slew/curve table for S7 — DEAD BEFORE DESIGN, his ruling ~21:06** (*"Every fader gets the same movement"*).
- **Feeding `prevFrameTexture` from the SDR capture pass — NOT taken (design):** the trails would feed back compressed highlights and differ from live. It is fed from the EDR final target instead; the cost is one extra post pass at full width, measured affordable (row 9).

## 4. 🔬 PREFLIGHT

```
PREFLIGHT run 2026-09-03 22:25:14 (after the two source commits, BEFORE this handoff commit)
PREFLIGHT 2026-09-03 22:25:14  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS
1. git
  ok    branch true-physics, HEAD d95296b
  FAIL  1 uncommitted path(s) — COMMIT THEM. Step 6 is mandatory; /handoff IS the order.
           M docs/BOARD.md
  WARN  53 commit(s) not pushed
2. board vs HEAD
  FAIL  docs/BOARD_BLACKHOLE.md is 2 code commit(s) behind HEAD (verified at 52f6d68)
  WARN  docs/BOARD_BLACKHOLE.md is 251812B — split closed rows into BOARD_CLOSED.md
  ok    docs/BOARD_CLOSED.md archive, 104965B — exempt (not read at cold start)
  ok    docs/BOARD.md current at 3e085d7 — 2 docs-only commit(s) since, no source change
  WARN  docs/BOARD.md is 184105B — split closed rows into BOARD_CLOSED.md
3. deployed artifact
  FAIL  STALE: SpaceSynth predates src/render/renderer.mm — run the packaging script, do not test this
  FAIL  STALE: default.metallib predates src/render/renderer.mm — run the packaging script, do not test this
4. referenced paths (live docs only)
  FAIL  docs/BOARD.md references missing path: src/render/show_capture.cpp
5. orbital-plane convention — READ THESE, do not skip
```
Notes: the uncommitted `docs/BOARD.md` is BRAIN's live edit (his order: BRAIN owns both boards and the fold). The two "missing path" FAILs are brace-expansion citations in §AA (`take_recorder.{h,cpp}`) that the checker cannot resolve — BRAIN's to spell out. This file is the last path I own; committed right after this run.

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| none this pass | — |

---

**Last Updated:** 2026-09-03 22:25:14
**Folded into board:** NOT by me — `docs/BOARD.md` §AA is BRAIN's (his order); BRAIN [5d8bf1] has both shas (`c6cad75`, `3e085d7`) and this file. S8 is not on the board at this stamp.
