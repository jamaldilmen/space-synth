# SPACE SYNTH — handoff 2026-09-03 18:33:00 (FABLE — the show renderer, S1–S5 shipped, S8 is the blocker for full res)

> **His verdict on this state:** *"it crashed lol"* (2026-09-03 ~18:24, the 19,644-wide pin — explained below; the guard is built, not launched). On the design, via BRAIN: *"Not by rotating the camera … it's one image as it already is."* · *"I def wanna deliver straight 30 or 60 fps. I guess it's gonna be 30 fps."* · *"Warp won't be during rendering no worries."* · marker CC at bar 1 beat 1 · sprite reference = the delivery height 1680 · F2 folded into S1. His order, verbatim: *"This is the most improtant build of the project. Highest prio."*
> **Cold start:** read `docs/BOARD_BLACKHOLE.md` (BRAIN folds S1–S5; at this stamp it is 6 code commits behind HEAD — BRAIN [5d8bf1]'s), then `docs/DESIGN_2026-09-03_OFFLINE_RENDERING.md` (SONNET) and `docs/DESIGN_2026-09-03_MIDI_MAP_AND_LINK.md` §10 (OPUS) — NOT this file.

**Tree:** `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS` branch `true-physics` @ `52f6d68` (mine tonight, one concern each: `d4cf127` S1 · `7ff7158` S2 · `5fd6cbb` S3 · `7d2e0d8` S4 · `3e4ac40` S9 · `d6cbb7c` S4 fix · `52f6d68` S5; plus the morning's `ae0449e` floor · `74bee76` hold · `f381c4d`/`2b9385e` handoff). 42+ commits UNPUSHED, no push order. ⚠️ Every `file:line` here is at `52f6d68`; `main.cpp` moved ~+80 lines tonight — re-grep.
**Build + launch:** `bash package_macos.sh` (bundle 18:30:36 = source). Live: `SS_FULLSCREEN=1 SS_LENS_RENDER=1 ./SpaceSynth.app/Contents/MacOS/SpaceSynth`. **Record a take:** `SS_RECORD=<take.txt>` (marker CC 119 at bar 1 beat 1; `SS_TAKE_MARKER_CC` overrides; quit with the close button or Cmd+Q — a kill writes nothing). **Replay offline:** `SS_RENDER_FPS=30 SS_REPLAY=<take.txt> [SS_REPLAY_START_FRAME=n] [SS_WIDTH=9822 SS_HEIGHT=840]`. Two-window/no-UI measurement launch: `SS_TWO_WINDOWS=1 SS_CAM_RHO=2000`.

---

## 1. ✅ CLOSED THIS SESSION

| # | Fault | Was | Now | Where | Proof |
|---|---|---|---|---|---|
| 1 | The app could not capture a CC event; System Common bytes ate the note sharing their packet | `MidiCallback(int,float,bool)`, no CC, no channel, 0xF1/F3/F6/F0 mis-sized | ONE `MidiEvent{kind,channel,a,b,stamped,t}` callback; CC parsed; channel nibble; MIDI-table sizes; `t` = packet stamp in seconds (mach×125/3), 0-stamp guarded + flagged | `midi_input.mm:48/64/85`, `midi_input.h` | `[MEASURED n=17 cases]` harness on the real file, HEAD vs S1; live over IAC on the built bundle (`d4cf127`) |
| 2 | No way to log a take | — | `SS_RECORD`: ring on the MIDI thread (`push` :54, no lock/malloc/file), file on the main thread at exit (`finish` :85, close button + atexit), marker CC 119 = t0, pre-roll kept at negative t, drops counted, NO MARKER fails loudly (:123), per-frame envelope rows | `take_recorder.cpp` | `[MEASURED]` two live takes: 42 events / 1,537 frames / marker 0.000000 / 33/33 sweep CCs / unstamped 2 flagged / dropped 0; no-marker take → `t0 NONE` (`7ff7158`) |
| 3 | Live clock: 60.606 steps/s ⇒ −1% drift vs an Ableton timeline; warp scales dt; window clock is wall time | — | `SS_RENDER_FPS=30\|60` (one header, `offline_clock.h:30`): dt=1/60, steps/frame `:44`, warp pinned + logged, accumulator bypassed (`renderer.mm:1810`), substeps 1 (`:2383`), posed-disk `:2231` + lens EMA `:5104` on frame time, window dt `window.mm:763`. 11 branches, ONE gate; unset = live path | `renderer.mm:1734` | `[MEASURED]` `frame=300 simTime=10.000020 expected=10.000000` (float32 accumulation; integer steps exact); SS_TIME_WARP=2 → loud FORCED line; 25 fps refused. Live pre/post runs identical in [RETURN]/[PERF] shape+values (`5fd6cbb`) |
| 4 | No replay | — | `SS_REPLAY`: events at `startFrame + ceil(t·fps)` (`take_replay.cpp:48`), applied at the top of the frame through the SAME `onMidi` live packets use (`main.cpp:267/716`); refuses clock-off / `t0 NONE` / drops | `take_replay.cpp:80` | `[MEASURED]` two launches → byte-identical 40-event schedules; 40/40 at `ceil(t·30)`; `TAKE COMPLETE at frame 325` (`7d2e0d8`, `d6cbb7c`) |
| 5 | The envelope (12 render branches) advances on the CoreAudio thread in real time — wrong picture for any render slower than real time | — | Offline: engine NOT started; `synth.processBlock(48000, scratch, 1600)` once per frame after the replayed notes, before the envelope read | `main.cpp:241/725` | `[MEASURED n=2 replays vs live]` every phase transition lags the live take ≤ 1 frame (0.682→0.700, 9.732→9.733 …); 362/363 rows agree; two replays' 466 rows byte-identical (`3e4ac40`) |
| 6 | Pin refused his 19,644-wide wall (typed cap 16384) and silently rendered 1280×800; half-res would have been a 2× different picture | `main.cpp` cap, `sizeResScale=height/2260` | `Window::canAllocateDrawable` (`window.mm:520`, measured on the device + a CAMetalLayer probe :555, 32768 abort pre-check :527); pinned reference height 1680 via `setSizeReferenceHeight` (`renderer.mm:2391`, `main.cpp:182`), live 2260 untouched (`:2198`) | `main.cpp:141` | `[MEASURED]` 9822×840 → `[SIZE] … 1680 → 0.5000`, chain runs, 21.6 fps; live → `2260 → 0.7080` (`52f6d68`). ⚠️ the layer probe itself: BUILT 18:30:36, NOT LAUNCHED |

## 2. 🚨 OPEN — his list, verbatim

1. **"This is the most improtant build of the project."** — S8, S6, S7 not started. `MEASURE:` a 10-s replay → three ProRes files with 300 frames each (`ffprobe nb_frames`), widths 7152/5340/7152, and a CC trace lining up with the replay log.
   State: **S8 CAPTURE is the blocker for full res.** `[MEASURED 18:22–18:25]` every offscreen texture type (RGBA16F mipmapped/plain, Depth32F, RG16F, RGBA8) allocates and rasterizes at 19,644×1680, and ProRes 422HQ/4444/HEVC sessions open at 19,644, 9,822, 7,152, 5,340; **but the `CAMetalLayer` that PRESENTS refuses any drawable above 16,384** (`nextDrawable` nil, `drawableSize` 0×0) and the final blit `copyFromTexture:drawable.texture` (`renderer.mm` renderWithCamera) SIGSEGV'd — his *"it crashed lol"*. ⇒ S8 = the existing Syphon post pass (`renderer.mm:~5460`, gated on `hasClients`) forced on into an OFFSCREEN target of the pinned size, blit → `CVPixelBuffer` (`CVMetalTextureCache`) → three `AVAssetWriter`s cropping x 0–7151 / 7152–12491 / 12492–19643, ProRes 422 HQ, one frame per output tick, writer back-pressure; the on-screen layer shows a ≤16,384 preview. `[HYPOTHESIS]` until built: memory at 19,644 wide (≈264 MB per RGBA16F target × ~12 targets) fits the M5 Max; render speed at that width unmeasured (9,822 measured 21.6 fps windowed).
2. **"The midi cc mist work so well that i can compose rides and fades accurately"** — S6 (OPUS's registry, `DESIGN_…_MIDI_MAP_AND_LINK.md` §1.5/§3.4: apply OUTSIDE `if (showHUD)`, refuse mapping the marker CC) and S7 (slew on the frame clock; 7-bit CC steps every ~7 frames at 30 fps). `MEASURE:` a logged 0→127 sweep moves a mapped fader in replay with a per-frame value trace; two renders identical. State: not started; CC events already arrive at `onMidi` (`main.cpp:267`) and are printed.
3. **Alignment to the Ableton timeline** — `[MEASURED]` each replayed event lands 0–33 ms AFTER its recorded time, never before, deterministic (S4 fix). `[UNVERIFIED]` Ableton's own MIDI output stamping: the take header will read `stamps packet|callback|mixed` on his first real take — read it. `[UNVERIFIED]` end-to-end frame-vs-bar: no video exists.
4. **Floor `ae0449e` + hold `74bee76`** (this morning) — still await his eyes; his night verdicts on Chladni are in `docs/HANDOFF_2026-09-03_FABLE_NIGHT.md`.

## 3. ⛔ DEAD ROADS — recorded so they are not retried

- **Three cameras / off-axis frusta per wall — REJECTED BY HIM 2026-09-03 ~16:2x** (*"Not by rotating the camera"*). One image, crop three slices.
- **Changing the live `dt` to 1/60 — REJECTED (BRAIN's ruling under his "smarter compromise")**: six hand-synced literals + `particles.metal:362`'s identity. Offline-only; warp 0.99 reproduces today's timing if ever wanted.
- **A typed pin ceiling (16384 → "32768") — DEAD.** 16384 refused a size the GPU renders; the ceiling is measured on the device (`canAllocateDrawable`). Metal's validation ABORTS above 32768 rather than returning nil, so that one number is checked before any descriptor exists.
- **The on-screen drawable as the wall-size render target — DEAD (MEASURED).** The layer cannot present > 16,384. The render target must be offscreen (S8).
- **`floor(t·fps)` for replay — RETRACTED, see §5.**
- **Launching the app to verify from my window while he is at the machine — his interrupt 18:2x.** Build without launching; his eyes own launches.

## 4. 🔬 PREFLIGHT

```
PREFLIGHT 2026-09-03 18:30:39  —  /Users/airy/SPACE SYNTH/SPACE-SYNTH-TRUE-PHYSICS   (before the S5 commit; re-run below)
1. git   ok branch true-physics, HEAD d6cbb7c
         FAIL 6 uncommitted path(s): M imgui.ini (app-rewritten, reverted) M src/main.cpp M src/render/renderer.h
              M src/render/renderer.mm M src/ui/window.h M src/ui/window.mm   ← COMMITTED 52f6d68 (S5)
         WARN 42 commit(s) not pushed   ← no push order
2. board FAIL docs/BOARD_BLACKHOLE.md is 6 code commit(s) behind HEAD (verified at 74bee76)   ← BRAIN's to fold + re-stamp (S1–S5)
         FAIL docs/BOARD.md is 6 code commit(s) behind HEAD                                    ← same
3. artifact ok SpaceSynth newer than newest source · ok default.metallib newer   (built 18:30:36, NOT launched)
```
Re-run after the handoff commit (`075f3df`, 2026-09-03 18:35:53):
```
1. git   ok HEAD 075f3df · FAIL 1 uncommitted: M docs/HANDOFF_2026-09-03_OPUS_MAPPING_AND_COLOUR.md ← OPUS's, being written in its window; not mine to sweep
         WARN 44 commit(s) not pushed — no push order
2. board ok docs/BOARD_BLACKHOLE.md (BRAIN re-stamped meanwhile) · FAIL docs/BOARD.md 7 code commits behind (verified at 74bee76) ← BRAIN's
3. artifact ok binary + metallib (18:30:36) newer than every source — NOT launched
4. paths ok 49 referenced path(s) resolve
```

## 5. ↩️ RETRACTED THIS SESSION

| Claim I made | Why it was wrong |
|---|---|
| S4: "`floor(t·fps)` applied at the top of that frame — never early, at most one frame late" | Backwards. The top of the frame that CONTAINS t is up to 1/fps BEFORE t; measured 11–31 ms early on every envelope transition (S9). Fixed to `ceil` in `d6cbb7c`; now 0–33 ms late, never early. |
| "19,644 wide rasterizes, so the full-res pin will work" | True of textures, false of the presenting layer; the pin at 19,644 crashed in the first frame. Measured both halves; S8 must render offscreen. |
| S3 spec relayed as "`frameCounter` == 2N offline" | `frameCounter` counts frames (one computeStep per frame); the step count is `[OFFLINE] steps/frame=2` / `[PERF] steps=`. |
| Estimated stamps | none — all from `date`. |

---

**Last Updated:** 2026-09-03 18:33:00
**Folded into board:** NOT by me — the board is BRAIN's; BRAIN [5d8bf1] has the seven shas and this file.
