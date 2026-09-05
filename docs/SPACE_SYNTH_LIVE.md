# SPACE SYNTH — LIVE

**The bible of the show.** Event facts, the scale, the delivery pipeline, and every lesson
that cost us a take. Created on his order 2026-09-04 15:12:04.

> **How to use this file:** everything below is either MEASURED (a number from a log or a
> file on disk) or HIS RULING (his words, quoted). Nothing here is inferred. If a line has
> no measurement and no quote behind it, it does not belong in this file.

**Last Updated:** 2026-09-05 15:23:00  *(OPUS: §5 corrections — zoom reaches `kMaxRho` 5800, and FOV is launch-env only so a dolly zoom is not shootable today.)*  *(Previous stamp 2026-09-05 12:47:07: the `near = 1.0` safety bound is `kMinRho`, added to §6.17 on his order. Previous stamp 2026-09-05 12:14:00.)*  *(POV session: the shake was the near plane (§6.17); POV zoom inverted for him; takes 8 and 9 recipe in §5.1 on his order; §6.18. Previous stamp 2026-09-04 19:01:04.)*  *(evening session: seven takes rendered; the note-sustain cost driver found and the "spin costs 3.3x" claim RETRACTED; center-only test renders ruled in at 1.34x; CC-driven spin shipped `f0cac86`; sections 4, 5 and 6.13-6.16 are new. Previous stamp 2026-09-04 15:15:19.)*

---

## 1. THE EVENT

| | |
|---|---|
| **Show** | COLOGNE opening event |
| **Date** | **2026-09-05** |
| **Room** | Three walls, ~270° wrap |
| **Wall sizes** | sides 14.75 × 3.50 m ×2 · front 10.01 × 3.50 m |
| **Unwrapped** | 39.5 × 3.50 m · 138.25 m² · **11.286 : 1** |
| **Playback** | Resolume Arena **7.15.0** (Alley + Wire also installed) |

⛔ **NOT** Berlin New Media Week / 2026-09-02 — the board carried that date until 2026-08-23.
⛔ The old `15×4 + 15×4 + 10×4 = 160 m²` figure was a PRE-WALK ESTIMATE: area overstated
15.7%, height 14.3%. He measured 3.50 m walls on 2026-08-24; a Polycam scan (256,532 verts)
confirmed it.

---

## 2. THE SCALE — the numbers everything else derives from

| | |
|---|---|
| **Canvas** | **19,644 × 1680** — ONE image, cropped into three |
| **Slices** | **L 7152** · **C 5340** · **R 7152**, all × 1680 |
| **Frame rate** | **30 fps**, offline clock (`SS_RENDER_FPS=30`) |
| **Master codec** | ProRes 422 HQ |
| **Delivery codec** | **DXV3** (DXT1, Normal Quality, No Alpha) |
| **Deliverable shape** | **THREE 10-MINUTE PARTS** — his ruling 2026-09-04 ~00:1x |

**His words on the shape:** *"three parts each 10 mins. waaaaaaaaaaay more digestible. drift
wont get toooooo crazy. more easy to change stuff on the go. edit it if its shit. re render
if somethings not adding up then waiting for a full 30 min file every time."*

🚩 **19,644 ≡ 12 (mod 16).** Any sum of multiples of 16 is itself a multiple of 16, so **no
split of 19,644 into three 16-aligned widths can exist.** Exactly one slice must always carry
a mod-16 remainder. Design around *which slice absorbs it*, never around avoiding it.
**In practice this has not bitten** — see §3.

---

## 3. THE DELIVERY PIPELINE — measured, and proven in Resolume

```
ffmpeg -i take_L.mov -c:v dxv -pix_fmt rgba take_L_dxv3.mov     # per slice
```

- `/opt/homebrew/bin/ffmpeg` has a **DXV encoder**. `ffmpeg -h encoder=dxv` offers exactly one
  format: **`dxt1` — "DXT1 (Normal Quality, No Alpha)"**. That is literally "DXV3 normal
  quality". Pixel format must be `rgba`.
- The MOV muxer tags it **`DXD3`** (DXV3), not a fallback. The ffmpeg patch author tested the
  output against Resolume's own software before merge.
- ⭐ **HIS VERDICT 2026-09-04 ~14:5x — the pipeline is PROVEN:** *"yoo thevideo runs in
  resoulume smootoooth"*. GPU playback, no Alley needed.
- ⭐ **The 16-px padding worry did NOT materialise.** The encoded 5340-wide centre slice reports
  `width=5340 coded_width=5340` — ffmpeg did not pad it — and Resolume played it. **No crop,
  no re-slice, no 4 px seam.** The walls stay exactly 7152 / 5340 / 7152.
- ffmpeg **cannot** emit DXT5/YCoCg ("high quality") or alpha. Only DXT1. Not a gap for this
  show; relevant if alpha is ever needed.

### Sizes — MEASURED, not estimated

| | ProRes 422 HQ | DXV3 |
|---|---|---|
| L wall / frame | 4.89 MB | **1.35 MB** |
| C wall / frame | 3.87 MB | **1.44 MB** |
| **3-min take, all three** | **69–74 GB** | **~22 GB** |
| **10-min part** | ~230–246 GB | **~74 GB** |
| **Three 10-min parts** | ~690–738 GB | **~223 GB** |

⛔ **An earlier estimate of ~89 GB per 3-min take in DXV3 was WRONG.** It assumed fixed-rate
DXT1 at 4 bits/pixel. The encoder's own source (`libavcodec/dxvenc.c`) uses LZ-style
back-references, which crush this footage's large black areas. **Always measure; never quote
the codec's theoretical bitrate for this content.**

### Conversion speed — MEASURED
300 frames in 5–6 s ≈ **55 fps**. ⇒ a 3-minute take (three slices) ≈ **5 minutes**; a
10-minute part ≈ **16 minutes**.

🚩 **That 55 fps is the INTERNAL-SSD figure. Reading ProRes off an external drive and writing
DXV3 back to the SAME drive costs ~25%.** Measured 2026-09-05 16:53:05 → 17:12:36: nine slices,
48,600 frames, 19 m 31 s wall = **41.5 fps sustained**, source and destination both on
LOSTINSPACE. Budget from 41.5 whenever the encode does not read from the internal disk —
a 3-minute take (three slices) ≈ **6.5 minutes** on that path, not 5.

### Playback ceiling
No Resolume-imposed max; the limit is GPU texture size, practically **16,384 px**. Each slice
(≤7152) is far under it. ⚠️ It would only bite if the three were ever loaded as ONE
19,644-wide layer instead of three outputs.

---

## 4. RENDER ECONOMICS — MEASURED 2026-09-04

| Take | Content | Wall clock | Ratio |
|---|---|---|---|
| 3-min, four post-FX faders sweeping | opens zoomed IN | 36 min | **12.0× realtime** |
| 3-min, zoom only | opens zoomed IN | 27 min | **9.0× realtime** |
| 10-min, static camera | — | 63 min | **6.3× realtime** |

⇒ **A 10-minute part at the zoomed-in opening framing costs ~90 minutes. Three parts ≈ 4.5 h.**
The opening close-up is the expensive part; the run speeds up as the camera pulls back.

**Other measured facts:**
- **Frame time HOLDS.** Over a 10-minute render the last ~30 minutes of wall clock drift
  **−0.39%**. All instability is in the first ~20% (formation).
  ⚠️ **A 60-second test reports the OPPOSITE** — it measures only the formation transient and
  says "degrades severely, +121%". Ten minutes was needed to see the truth.
- **Memory is flat** — RSS 2337 → 2098 MB over 18,000 frames, peak 2354. No growth.
- **The ProRes writer is never the bottleneck** — 57.1 MB/s sustained, zero back-pressure
  stalls. ⚠️ It has NOT been tested at 300 MB/s; a realtime-30fps version of this content
  would demand ~360 MB/s, which is unmeasured.
### 2026-09-04 evening — SEVEN TAKES, and the cost driver is NOT what I first said

| Take | Content | Frames | Wall | fps |
|---|---|---|---|---|
| `take4rev_full` | chromatic, 3 s notes, no spin | 5400 | 355.9 s | **15.17** |
| `take5_spin` | same + ramped spin | 5400 | 395.7 s | **13.64** |
| `take6` v1 | 2 notes **SUSTAINED** across their halves | 7200 | 148 s | **48.6** |
| `take6` v2 | same shot, notes **released after 3 s** | 7200 | 844.9 s | **8.52** |
| `take7` v1 | 4 notes **SUSTAINED** | 7200 | 146 s | **49.3** |
| `take7` v2 | same shot, notes **released after 3 s** | 7200 | 543.9 s | **13.24** |

🚨 **A HELD NOTE IS 4–6× CHEAPER TO RENDER THAN A RELEASED ONE.** `[MEASURED n=2 pairs,
one variable changed]` take6 48.6 → 8.52 fps and take7 49.3 → 13.24 fps; the ONLY difference
is the note-off frame. A sustained voice parks the field in a settled state; letting go lets
it evolve, and an evolving field costs both GPU time and ProRes bitrate (74 GB → 90 GB on the
same shot). **Note behaviour belongs in the render budget next to framing.**

⛔ **"THE SPIN COSTS 3.3×" IS RETRACTED (2026-09-04 18:40:00).** The controlled pair —
same 3 s notes, same width, same 5400 frames — is `take4rev_full` 15.17 fps vs `take5_spin`
13.64 fps ⇒ **the spin costs 11%, not 3.3×.** The 3.3× compared a spin take against a
SUSTAINED-note take and read the note difference as the spin.

📐 **CENTER-ONLY TEST RENDERS: 1.34×** `[MEASURED n=1 pair, 900 frames, matched framing,
same driver]` 19644 with 3 slices 30.8 s vs 5340 single slice 22.9 s; 3.14 GB vs 9.50 GB out.
**Narrowing the render width is a TRUE CENTER CROP, not a reframe** — `perspectiveMatrix`
(`renderer.mm:6186`) fixes vertical FOV and derives horizontal from aspect, so tan of the
horizontal half-angle scales EXACTLY with width (0.271839 both). ⛔ The "1.37×" I quoted from
the two full-length takes is RETRACTED — those two runs had different note patterns, so the
number carried the content change inside it. His ruling `[HIS WORDS ~17:05]`: *"its a pretty
substantial increase in time for the scale we're at ... i just need to guess that the sides
are part of the shot. front is more important anyways"* ⇒ **test renders center-only, sides
only for the final.**

⚠️ **Only writing the centre SLICE saves almost nothing** — the three slices are crops of ONE
full-width render (`show_capture.mm:159` blits the same source texture three times), and the
writer idles at 57 MB/s. The saving comes from narrowing `SS_WIDTH`, not from dropping slices.

- **The field loses ~72% of its matter over ten minutes** (two agreeing instruments). That is
  a COMPOSITION fact about a 10-minute part, not only a physics one.

---

## 5. THE SHOT — what is built and how to ask for it

Every camera and look parameter is driven by MIDI CC from a **frame-locked** ride script that
tails the render's own `[CAPTURE] frame N written` markers.

| Parameter | CC | Shape |
|---|---|---|
| **zoom** (rho 50 → 2000) | 20 MSB / 52 LSB, 14-bit | **p² eased** — creeps early, most travel in the last fifth |
| **camTilt** (θ) | 21 | set-and-hold |
| **thetaSpin** (θ swept) | 28 MSB / 29 LSB, 14-bit | linear |
| **camPhi** | 30 | selector: raw 0 = tumble (φ=0) · nonzero = orbit (φ=π/2 exactly) |
| **iscoOrbit** | 26 | set-and-hold |
| **phaseAmount** | 31 | set-and-hold, **0 = phase FX OFF** |
| **spinRate** (rigid body spin) | **34 MSB / 66 LSB, 14-bit** | 0 = stopped, 16383 = `kSpinMax` 436.8 rad/s. Direction applied receiver-side: NEGATIVE = right arrow |
| exposure / fluid / glitch / chromatic | 22–25 | available, **not used since take 2** |

🚩 **Two corrections to the table above, verified 2026-09-05 15:23:00 by OPUS against `74a21d8`
(the two `[READ]`s below sit in hunks NOT touched by the uncommitted working-tree edits):**
- **zoom reaches 5800, not 2000.** `kMaxRho` was raised 2000 → 5800 on 2026-09-05
  `[READ src/core/camera.h:121]`, and the CC20/52 handler maps the 14-bit pair linearly across
  `kMinRho .. kMaxRho`, so the pair reaches whatever that constant currently holds. The POV
  takes' rho 2925 is exactly the midpoint of 50..5800 — that is `zUnit = 0.5` landing on the
  same map, not a second one.
- **FOV is NOT rideable.** `sFovDeg` is a function-local `static` initialised ONCE from `SS_FOV`
  on the first perspective frame, and no `case` in the `MidiKind::CC` switch writes it
  `[READ src/main.cpp, the sFovDeg lambda and the CC switch — symbols, not line numbers, the
  file has uncommitted edits]`. ⇒ **a dolly zoom (travel in while the lens widens) cannot be
  shot today**: it needs a new CC plus a per-frame FOV into `perspectiveMatrix`. Every take so
  far changes framing by rho alone.

**The drivers, all in `logs/` (gitignored, same as every sender):**

| Driver | Shot |
|---|---|
| `midi_ride_cmaj_tilt` | take 4 — held C-E-G chord, then tilt 0→90° + zoom OUT, landing together |
| `midi_ride_cmaj_tilt_rev` | same, zoom **IN** (opens wide at rho 2000, arrives rho 50) |
| `midi_ride_chromatic_tilt_rev` | 9 notes 60→68, one per 20 s held 3 s, reversed zoom |
| `midi_ride_chromatic_tilt_spin` | as above + the ramped spin |
| `midi_ride_shot` | **five modes.** `a` = middle→all-in→all-out + 1 min stillness, 2 notes · `b` = one in→out sweep, 4 notes C→E♭ · `c` = static-hold test (zoom to rho ~927 over 300 f, then frozen, tilt off) · **`d` = TAKE 8** · **`e` = TAKE 9** — see the POV recipe below. `<log> <a\|b\|c\|d\|e> [tickMs] [tilt]` |

### 5.1 THE POV SHOTS — takes 8 and 9, the full recipe (his order 2026-09-05 12:1x: "the recipes belong in the bible, not in the gitignored logs folder")

Both rendered 2026-09-05 01:40–01:58 on bundle 01:40:07 (sources = `38170d5`), delivered as DXV3 on `/Volumes/LOSTINSPACE/JAMAL/`, ProRes in `~/Desktop/sweep/`. `docs/BOARD.md` §AA28 has the measurements.

**Common to both — the POV config `[HIS WORDS 2026-09-05 01:02:12 "amazing i think its gone"]`:**
```
SS_REF_HEIGHT=420 SS_LUM_CEIL=520 bash logs/run_shot.sh <name> <d|e> <SS_CAM_RHO> 9000 0 19644
# run_shot.sh sets: SS_FOV=45 SS_RENDER_FPS=30 SS_WIDTH=19644 SS_HEIGHT=1680 SS_CAPTURE=~/Desktop/sweep/<name>
#                   SS_CAPTURE_FRAMES=9000 SS_LENS_RENDER=1 SS_CAM_RHO=<rho> SS_ORTHO=0 SS_CAPTURE_SLICES=7152,5340,7152
# then:  ./SpaceSynth.app/Contents/MacOS/SpaceSynth | perl(timestamp) > <name>.log
#        gate on "[MIDI] Listening on", then ./logs/midi_ride_shot <name>.log <mode> 50 1 > <name>.ride.log
```
- `SS_ORTHO=0` perspective, `SS_FOV=45` vertical, near plane **1.0** / far **20000** (the 0.001 near plane WAS the shake — §6.17), `kMaxRho = 5800`.
- `SS_REF_HEIGHT=420` ⇒ `sizeResScale` 4.0 — 4× sprites, the LOOK he chose (*"that was looking good"* 21:18). It is not a fix for anything.
- `SS_LUM_CEIL=520` — *"for all runs lumen ceiling 520"* (01:39).
- **Camera pose: the default.** θ = π/2, φ = 0 (`camera.reset()`), and the driver sends **no** theta/phi/thetaRange CC at all (`noPose`). Holds sent every 5 s: CC26 iscoOrbit = 0, CC31 phaseAmount = 0.
- Zoom: 14-bit CC20 (MSB) + CC52 (LSB), receiver maps v14/16383 → rho 50..5800 (`main.cpp case 52`). Target updated every 50 ms wall tick from the frame estimate (marker + rate extrapolation, capped at marker + 30). `zUnit` 0 = rho 50, 1 = rho 5800; `smooth(u) = u²(3−2u)`.
- Notes: velocity 90, sent as note-on at the frame in the table, note-off at on + hold.

🚨 **POV ZOOM READS INVERTED TO HIM `[HIS WORDS 2026-09-05 01:37 "cant believe it was that easy.. okay now we know pov is inverted"]`.** His "all the way out" is **rho 50** (camera at the core, the cloud all around it), his "in" is **rho 5800** (in the outskirts, huge near stars). The rest cloud reaches maxR 61–76 sim × plate 100 ≈ 7600 world, so no POV distance is outside it. Set every POV ride by HIS words, never by the geometry.

| Take | Mode | `SS_CAM_RHO` | Camera over 9000 f (300 s) | Notes (MIDI, on frame → off frame) |
|---|---|---|---|---|
| **take8_pov_octaves_50to2925** | `d` | 50 | `zUnit = 0.5·smooth(f/9000)` ⇒ rho 50 → 2925, his "out → half way in" | C every minute rising an octave, each held 90 f (3 s): 60 @0→90 · 72 @1800→1890 · 84 @3600→3690 · 96 @5400→5490 · 108 @7200→7290 |
| **take9_pov_chords_2925to50** | `e` | 2925 | `zUnit = 0.5 − 0.5·smooth(f/9000)` ⇒ rho 2925 → 50, "start in the middle and zoom out" | chords held 180 f (6 s, *"twice as long as the notes"* 01:51): C maj 60-64-67 @0→180 · D min 62-65-69 @1800→1980 · E min 64-67-71 @3600→3780 · F maj 65-69-72 @5400→5580 · **minute 4–5: nothing** |

🚩 **`maxFrames` is HARDCODED per mode inside `midi_ride_shot.mm`** (a/b = 7200, c = 900-range test, **d/e = 9000**). The runner's `<frames>` argument only sets `SS_CAPTURE_FRAMES`; if it disagrees with the mode the ride silently desynchronises from the capture (BRAIN). 🚩 **The runner gates the driver on `[MIDI] Listening on`, NOT on `[CAPTURE] ARMED`** — the wrong gate ran a smoke at noteOn 0 / noteOff 3 (§6.13).

`run_shot.sh` positional args, no flags: `<name> <mode> <SS_CAM_RHO> <frames> <SS_ORTHO 0|1> <SS_WIDTH> [<SS_CAPTURE_SLICES>]` — omit the last for the three walls, pass `""` for one full-width slice; `SS_FOV` and `SS_REF_HEIGHT`/`SS_LUM_CEIL` come from the environment. The approved ortho control, take 4 chord: `SS_RENDER_FPS=30 SS_WIDTH=19644 SS_HEIGHT=1680 SS_CAPTURE_SLICES=7152,5340,7152 SS_CAPTURE_FRAMES=5400 SS_LENS_RENDER=1 SS_CAM_RHO=2000` + `./logs/midi_ride_cmaj_tilt_rev <log> 5400 600 50` (maxFrames, chordFrames, tickMs) — 20.45 fps, chord off f600.6 vs 600, zoom14 0 + theta14 16383 landed together (BRAIN, `logs/run_take4_chord.sh`).

Driver park before frame 0: mode `d` sends zoom14 = 0 (rho 50), mode `e` sends 8192 (rho 2925), so frame 0 starts at rest at the launch rho (no spring-in). The driver's own status line prints rho with the OLD 50..2000 formula for modes a/b — cosmetic; the `[CAMF]` line in the app log is the truth.

**Verified per take (app log):** `[LUM] SS_LUM_CEIL=520`, `[CAM] SS_ORTHO=0 -> PERSPECTIVE`, `[SIZE] … sizeResScale 4.0000`, `[CAMF] f=0 rho=<launch> theta=1.5707963 phi=0`, every `[MIDI] noteOn/noteOff` of the table, `[CAPTURE] frame 8999 written`.

⚠️ The driver source `logs/midi_ride_shot.mm` and `logs/run_shot.sh` are still gitignored; the table above is sufficient to rebuild them. Build: `clang++ -std=c++17 -O2 -fobjc-arc -framework CoreMIDI -framework CoreFoundation -framework Foundation logs/midi_ride_shot.mm -o logs/midi_ride_shot`.

### 5.1a TAKES 6 AND 7 — the same POV config, five minutes, and the ZOOM BOUND that makes them safe

His order 2026-09-05 ~12:5x: *"make the songs five minutes each not song slol the runs lol"*, after
*"can we now safely re do th ebroken ones .. nonbhr0okenly ?"*

```
SS_REF_HEIGHT=420 SS_LUM_CEIL=520 bash logs/run_shot.sh <name> <a|b> <SS_CAM_RHO> 9000 0 19644 "7152,5340,7152"
#   take 6 → mode a, SS_CAM_RHO=1488   (zUnit 0.25 — the "middle" of the CAPPED range)
#   take 7 → mode b, SS_CAM_RHO=50     (all the way in)
```
| take | shape | notes | measured |
|---|---|---|---|
| 6 `take6_pov5m_mid_in_out_still` | middle → all-in → all-out over `rideFrames` 7200, then **1800 f (60 s) of stillness** | C4 at f0, C#4 at f3600, each held 90 f then RELEASED | 9000 f, **545.5 s**, landed zoom14 8192 / theta 90.00° |
| 7 `take7_pov5m_in_out_4notes` | ONE sweep all-in → all-out across all 9000 f | C4/C#4/D4/D#4 on the quarters — f0 / 2250 / 4500 / 6750, held 90 f | 9000 f, **505.3 s**, landed zoom14 8191 / theta 89.99° |

🚨 **THE ZOOM BOUND — WHY THESE STOP AT rho 2925 AND NOT AT `kMaxRho` 5800.**
`const double kOutCap = 0.5` in `midi_ride_shot.mm` caps modes a/b at zUnit 0.5. It is there because
**§6.17's near-plane fix bought a factor, not immunity.** Depth step is `ulp·z²/near`; with near = 1.0
that is **0.51 world units at z = 2925** but **2.00 at z = 5800**, and past ~2 units apart in depth
neighbouring stars share a depth value and the star pass `Less` test flips by thread order again.
His eyes settled it: a 5-minute take 6 at the full 5800 shook on the FIXED bundle (*"i see that the
take i shsaking right now"*), while 8 and 9 at 2925 are *"amazing no shakies all good"*.
⭐ **RULE: in PERSPECTIVE, do not zoom past rho ~2925.** ⛔ **ORTHO IS EXEMPT** — it maps depth linearly
over ±5000, which is why §5.2's orbit reaches 5800 safely. ⚠️ The cap is a WORKAROUND; the real fix is
reversed-Z depth and is not built.

🚩 **TWO DRIVER FAULTS FIXED HERE, both invisible until the take length changed:** modes a/b hardcoded
`maxFrames = 7200` *and* their leg boundaries as literal frames (2700/5400) — the legs now derive from
`rideFrames`; and the `take complete` line printed `rho=2000` from a stale kMaxRho span while the camera
landed at 5800. **Verify a shot table against a synthetic log before spending a render** — generate a
file of `[CAPTURE] frame N written` lines 0..N-1 and run the driver against it with no app.

### 5.2 REPLAY-DRIVEN TAKES — the orbit recipe (take 10) and how to make any ride frame-exact

**Transport:** `SS_REPLAY=<file>` (S4, `src/core/take_replay.cpp`). A "SPACE SYNTH take v1" text file: header lines `# SPACE SYNTH take v1`, `# … t0 MARKER …`, `# … dropped 0 …`, then `E <t seconds> <kind 0=on 1=off 2=cc> <ch> <a> <b> 1`. Each event applies at output frame `ceil(t·30)` through `onMidi` — the same path, latch and mapping as live MIDI. No driver, no `[CAPTURE]` marker tailing, no wall clock. Generator: `scratchpad/gen_take.py`; runner: `scratchpad/run_replay.sh <name> <take> <SS_CAM_RHO> <frames> <SS_ORTHO> <SS_WIDTH> [slices]`; verifier: `scratchpad/check_replay.py <take> <log>` — run it on EVERY take: it compares each applied `[REPLAY]` line to the file (0 mismatches on all six runs so far). ⚠️ The app prints one `[REPLAY]` line per event (a 20k-event take = 20k log lines).

**take10_orbit_wide (DELIVERED 2026-09-05 14:39, DXV3 on LOSTINSPACE/JAMAL):**
```
SS_LUM_CEIL=520 SS_CAM_THETA=1.5707963 SS_CAM_PHI=1.5707963 \
bash scratchpad/run_replay.sh take10_orbit_wide scratchpad/takes/orbit_wide_5400.take 50 5400 1 19644
```
ORTHO, 5400 f. The file: CC30 = 32 (φ = π/2 ORBIT, and `orbitUpFix` on — main.cpp case 30), CC33 = 0 (θ range 2π), CC26 = 0, CC31 = 0, re-sent every 150 f; zoom14 = 16383·frac² (rho 50 → 5800, his *"Wider one"*), θ14 = 16383·((0.25 + frac) mod 1) (a full 360° starting at the default π/2 so frame 0 is at rest), one MSB+LSB pair per frame where the value changes; no notes. 65 GB ProRes, ~24 min wall (render-bound, see board §AA29.6). `SS_CAM_THETA/PHI` exist since `7ea4fe8` — without them frame 0 springs 90°.

🚨 **θ TARGETS ABOVE π SPUN THE CAMERA UNTIL `8182846`** — any 2π-range ride (take 3) beyond 180° made the camera do a full turn every 7 frames. Fixed at the camera; documented in §6.19.

**The song shot (cancelled 2026-09-05 ~14:30, plan kept):** `gen_take.py beat <out> <onset.npy>` — 120 BPM = 15 f/beat; kick onsets from a 40–150 Hz spectral-flux peak list snapped to the eighth grid; exposure pump via CC22 (7-bit) or CC22+CC54 (14-bit, `acda80f`); one held chord per section (the §4 cost law: a released note re-evolves the field); audio muxed into the CENTRE slice only: `ffmpeg -i C.mov -i song.mp3 -map 0:v -map 1:a -c:v copy -c:a aac -b:a 320k -shortest`. The synth is NOT started offline, so the notes are inaudible in the deliverable — they are a physics input; "in key" is a non-question for a render.

🚨 **WHY THE CHORD OPENED ON BLACK** `[HIS WORDS ~15:5x]` *"when a chord hits the screen is
black"*. Take 4 held the camera at `SS_CAM_RHO=50` through the whole 20 s chord — INSIDE the
matter shell, which sits at 150 r_s — so there was nothing between the camera and the hole.
Cause is the FRAMING, not the formation. Fixed by opening wide and flying in.

**Framing vocabulary — verified from `camera.h:192-194`, disk is in XY, normal is Z:**
- **θ = 0, φ = 0** → camera on +Y, **edge-on**, disk HORIZONTAL on screen. *(the approved look)*
- **θ = 90°, φ = 0** → camera on +Z, **face-on / "front on view"**, looking down the normal.
- **φ = π/2, θ swept** → camera circles IN the disk plane — a true orbit — **but see §6.4.**

**Launch envs that matter:**
- `SS_CAM_RHO=50` — sets the camera POSITION at construction, so frame 1 is fully zoomed in
  **at rest**. Without it the camera springs inward for the first ~15 frames.
- ⚠️ **There is no launch env for the camera ANGLE.** The tilt must arrive by CC and springs
  into place over ~0.5 s (~15 output frames) at the head of every take.

---

## 6. LEARNINGS FROM MISTAKES — each one cost real time

### 6.1 Wall clock is not output time — **cost: one aborted take**
The ride was told "180 seconds"; that is 180 seconds of WALL clock, while the render runs at
2–10 fps. The zoom would have finished in the first third and left two thirds static.
✅ **Rule: every automation is FRAME-LOCKED** to the `[CAPTURE] frame N` markers, driven by
`N / maxFrames`, never by a stopwatch.

### 6.2 A 7-bit MIDI fader cannot ride a 3-minute camera move — **cost: one full take**
128 steps across 5,400 frames = a camera update every ~30 output frames, against a spring that
settles in **15**. The camera lunged, arrived, sat still, lunged again — **134 little rides,
not one**. His words: *"its liek back and forth zoomies not one consistent ride."*
✅ **Rule: 14-bit (MSB + LSB, CC n / CC n+32) for anything that must move continuously.**
Measured result: median gap **0.00 frames**, 1.08 updates per output frame, **43×** the update
rate.
⛔ Not fixes: resending the same 7-bit value more often; going linear instead of eased
(linear spreads steps to 42 frames — *worse*).

### 6.3 14-bit needs a receiver-side LSB latch
Applying on EITHER byte means that at each MSB tick the app briefly applies `(new MSB, stale
LSB)` — measured as **23 lurches of ~15 rho** in one take.
⛔ **Reordering the send does NOT help** — MSB-first overshoots by 127 counts, LSB-first
undershoots by 127. Symmetric.
✅ **Rule: cache the MSB, apply only when the LSB arrives**, with a first-time-MSB fallback so
a 7-bit-only source (Ableton) still works. Verified: **0 lurches** afterwards.
⚠️ Harmless in the takes that had it — the stale value lived **<1 ms inside a 250–500 ms
frame** and could not be sampled. *Verifying a defect is real is not verifying it matters.*

### 6.3a THE CONTROL RANGE MUST MATCH THE TRAVEL — 14-bit is necessary, not sufficient
**Caught before the take, 2026-09-04 15:12, by measuring take 3's real log rather than its smoke.**

The θ pair is mapped `(v14 / 16383) × 2π`. So a sweep that only travels **90°** uses **a quarter
of the range — 4,096 counts, not 16,383** — and the applied steps get 4× coarser.

| | travel | counts used | MSB crossings | one applied step every |
|---|---|---|---|---|
| take 3 (orbit) | 0→**360°** over 5,400 fr | 16,383 (full) | 127 | **43 frames** ✅ reads continuous |
| take 4 as first built | 0→**90°** over 4,800 fr | 4,096 (¼) | 32 | **150 frames** ✗ 4.5 s still, ×32 |
| take 4 fixed, mapped [0, π/2] | 0→**90°** over 4,800 fr | 16,383 (full) | 127 | **38 frames** ✅ |

✅ **Rule: map the 14-bit pair over the range the shot ACTUALLY travels, not the widest range
the parameter can express.** Parameterise the range (a selector CC) so an orbit build and a
tilt build can share one bundle.

🚩 **AND A SUBTLETY THAT MAKES THIS HARD TO EYEBALL:** in take 3, **124 of 132 applied θ targets
exceeded the 15-frame settle** — and it still read as continuous, because ζ=0.70's underdamped
tail carries the camera across a 43-frame gap. **"Gap > settle" is therefore NOT automatically
visible; it depends on the damping.** The tail does not reach across 150 frames, which is why
the quarter-range version would have failed where take 3 did not.
`[MEASURED from take 3's full log]` 244 applied targets, gap p50 **42.0 frames**, max 84.5,
angular step p50 **2.790°** — exactly MSB-crossing spacing.

🚩 **THE SMOKE WAS STRUCTURALLY BLIND TO IT.** Take 4 holds the camera static for the first
**600** frames (the chord); a **300**-frame smoke never starts the tilt and would have passed
while testing nothing about the shot's main move. Same shape as take 2's smoke never moving the
MSB off zero.
✅ **Rule: the smoke must be longer than any static prefix in the take**, and it must produce a
falsifiable NUMBER (here: applied-θ gap ≈ 38 frames, not ≈ 150), not a pass/fail.

### 6.4 The camera's UP vector is derived from θ — **cost: one full take (the orbit)**
`camera.h:263` — `refUp = (−cosθ·sinφ, sinθ, −cosθ·cosφ)`. That is correct when θ is an
ELEVATION. We made θ the ORBIT angle at φ=π/2, so the basis rotated with the orbit:
```
take 2  θ=0,   φ=0     screenUp=(0,0,-1)  = disk normal ⇒ disk HORIZONTAL ✓
take 3  θ=0,   φ=π/2   screenUp=(-1,0,0)  ⇒ disk VERTICAL, and it rolls a full 360° ✗
```
His words: *"the rotation seems wrong like the axis its not what i wanted"* — **he was right.**
✅ **Fix: for orbit only, pin `refUp` to the disk normal (0,0,−1).** Then `screenUp` is constant
and only the viewpoint travels. Default path untouched — it exists to avoid a basis flip at
the poles and normal camera work still needs it.
✅ **A θ sweep at φ=0 (edge-on → face-on) needs NO fix** — that is the elevation pivot the
original derivation is designed for, and it does not roll.

### 6.5 Every camera motion goes through a spring
`camera.h:169` — *"EVERY MOTION GOES THROUGH THE SPRING. There is no path that writes a
position or a velocity directly any more."* Setters write the TARGET only.
⇒ Against a continuously moving target the spring trails by a **constant** offset (simulated:
0.2068°, ~3.1 output frames at ζ=0.70) and does **not** oscillate. Steady-state ramp error is
constant even underdamped; oscillation is a step-response artefact.

### 6.6 `live=` is ambiguous in the logs — **cost: a wrong conclusion, caught before shipping**
`[GRAV] live` is the FIELD (~2.0 M). `[PROBE-1000] live` is a 1,000-slot TRACER of the heaviest
stars, which the seed eats first. In one run: field **−72%**, tracer **−97%**.
✅ **Rule: never write `live` unqualified. Always name the tag.** A tracer null is not a field null.

### 6.7 Check `Compute avg 0.00` before comparing any two logs
A "41 fps venue run" turned out to be a **paused sim** — `Compute avg 0.00` in 350 of 352
windows, and `[SIM] PAUSED` printed at line 466. A filename and a resolution do not tell you
whether the physics was running.

### 6.8 Freshness is not cleanliness
"Bundle newer than newest source" passed a binary that was 1 second newer **and carried two
other windows' uncommitted work**. ✅ **The mtime check proves a binary is not stale; only
`git status` proves it is not contaminated.**

### 6.9 One tree, four windows — "don't build" ≠ "don't affect the build"
A source edit lands in whoever runs `package_macos.sh` next. ✅ **Park work to a patch** (`git
diff > x.patch`, verify with `git apply --check`, then `git checkout --`) rather than leaving
it in the tree.

### 6.10 APFS reclaims disk PROGRESSIVELY
After deleting 216 GB, `df` read **+77.7 GB at 6 s** and the full **+216.2 GB only at ~70 s**.
✅ **Wait for the free figure to STOP CHANGING (4 identical reads), not to start moving.**
✅ **His rule: delete with `rm`, never the Trash** — *"Not just papierkorb. Otherwise disk will
blow up."*

### 6.11 `SS_CAPTURE` is a PATH, not a flag
`SS_CAPTURE=1` writes `1_L.mov` etc. into the current directory. Always a full path.

### 6.12 Test the instrument before the take
Two takes were saved by a **300-frame smoke run** (~3 min, ~4 GB) that reproduces the true HEAD
of the real take (ride's `maxFrames` left at the full count). It caught a parser that had never
seen real capture output, and confirmed a fix with a falsifiable prediction (23 lurches → 0).

---

### 6.13 Gate the ride on `[MIDI] Listening`, not `[CAPTURE] ARMED` — **cost: one 900-frame smoke**

`[CAPTURE] ARMED` is log line 21; `[MIDI] Listening on N source(s)` is line **46**. A driver
launched on the ARMED line fires its first notes into a port the app is not yet listening on.
`[MEASURED]` take 4's smoke logged `noteOn 0 / noteOff 3` — the chord never sounded, and the
release at frame 600 landed on a note that was never struck.

⚠️ The ride numbers from that run were still valid (the ride is frame-locked and CC33 is
re-sent every tick), so a run can be half-wrong. Check `noteOn` and `noteOff` COUNTS on every
take, not just that the log has MIDI in it.

### 6.14 A note-off scheduled at `maxFrames` never sends — **cost: two full takes**

The driver exits at `lastMarkerFrame >= maxFrames - 1`. A release scheduled at frame 7200 when
the last frame is 7199 is never reached: take 6 logged **2 on / 1 off**, take 7 **4 on / 3
off**, and the final note of each was still sounding at the end. Every note-off must be clamped
to `maxFrames - 1`.

`[HIS WORDS 2026-09-04 ~18:38]` *"i meant the note was held and let go. no held for the entire
run"* — and then, to my "struck": *"not struck. held for a couple secs then let go."* The
window is ~3 s (90 frames at 30 fps), the same as the chromatic take he approved.

### 6.15 The SSD is exFAT — `cp -p` fails AFTER writing the data

`cp: chflags: Invalid argument`. exFAT has no macOS file flags, so `-p` fails at the flag step,
returns non-zero, and a script that treats non-zero as "copy failed" will keep the source and
report a failure that did not happen — the bytes are already there. `[MEASURED]` a 17-file move
reported 17 failures while T9 usage went 69 → 230 GB. **Use plain `cp` and verify by SIZE.**
⛔ And do not swallow `cp`'s stderr; the real reason was hidden for a whole round trip.

### 6.16 Which arrow spins WHICH axis — the disk is in XY

`applySpin` (`render.metal:121`): `ay` mixes x and z, `ax` mixes y and z, **`az` mixes x and y**.
The disk lives in XY (`particles.metal` computes `rXY`), so **`az` — Option+←/→ — is the only
one that spins it in its own plane** like a record. Plain ←/→ drive `ay` and tumble it
end-over-end.

⚠️ **But his verdict was that the plain RIGHT arrow is the shot** `[HIS WORDS ~17:08]` *"arrow
key to the right heeeeld"*, and the CC path already matched it exactly (`dirY = arrowL − arrowR
= −1` ⇒ `spinVelY` negative). His *"it's the wrong axis, it's up-down not left-right"* was
against a take whose camera is EDGE-ON for its first half — the read changes with the pose,
so judge a spin axis at the framing it will actually be seen at.

### 6.17 The POV "shake" and "flicker" were the perspective NEAR PLANE — **cost: takes 6 and 7 POV (~180 GB), one evening**
`perspectiveMatrix(…, 0.001f, 5000.0f)`. NDC depth ≈ 1 − n/z: with n = 0.001 every particle beyond a few units lands within float32 spacing of 1.0 (`Depth32Float`), so at z = 1000 two stars < ~60 units apart share one depth value, and the star pass `Less` test against the depth prepass flipped per frame by thread order — *"insane flicker"* live, *"crazy shake"* at 30 fps. Ortho maps depth linearly and never had it. Fix `38170d5`: near 1.0, far 20000. **What it was NOT:** the camera spring (critically damped, `[CAMF]` ripple ±5%), the ride driver, the sim clock, or sprite size (4× sprites at full width still shook — *"crazy shake is back"* 00:54). Rule: when a defect is POV-only, read the projection before measuring pixels.

⚠️ **AND THE BOUND THAT MAKES `near = 1.0` SAFE IS `kMinRho`, NOT LUCK.** A near plane clips
everything closer to the eye than itself, so `near = 1.0` is only free while the camera cannot
get within 1 world unit of anything it must draw. `kMinRho = 50` (`camera.h:113`) is what
guarantees that today. **If anyone ever lowers `kMinRho` below ~1 for a POV shot, particles
inside 1 world unit of the eye will silently VANISH** — no error, no log line, just missing
matter at the closest approach, which is exactly the frame a fly-through is built around.
Raising `near` is what bought the depth precision, so the two numbers are one decision:
change `kMinRho` and you must re-derive `near`. `[READ main.cpp:1391, camera.h:113]`
`[NOT MEASURED — no run has gone below kMinRho 50; this is the derivation, not an observation.]`

### 6.18 A centre-slice smoke cannot judge framing — **cost: three smokes and an argument**
The 5340 C slice is the middle 27 % of 19,644 and reads "zoomed in" whatever the camera does. Smoke full width when framing is the question; and when he says "not zoomed out", launch the live app in the same config and let HIM zoom — the live `[CAM-LIVE]` line then names the number.

### 6.19 An absolute angle target past 180° spun the camera — **cost: take 3's second half, found only on 2026-09-05**
`Camera::update()` wraps the actual into (−π, π] and shifts the target by the same 2π; `setTiltAbs` re-asserted the raw absolute every frame, so after every wrap the spring saw ~2π of error and raced round again — a full turn every 7 frames (measured on the song-shot smoke). Only a 2π-range ride (the orbit) beyond 180° could hit it; every other take was under π. Fix `8182846`: the target is the representative nearest the actual. Rule: a frame-by-frame absolute set into a wrapped state must always be reduced against the current actual; and **check the stream, not the picture** — the replay differ caught it, no eye had.

### 6.20 Two windows, one job — twice more
The takes 6/7 conversion was started by both windows eight minutes apart; `/handoff` was run in both windows in the same minute. Rule now: **say "taking it" and get the confirm before touching a job** — app, tree, conversion, docs. The 11:54 regression (25bbfc7) was the first sighting; §6.9 already said the tree is shared.

## 7. OPEN — carried into the show, not solved

- 🚨 **Black-hole formation is decided by a GPU thread RACE.** `merge_stars` claims stars with
  an atomic CAS; 98–99% of found pairs contend, and whichever thread arrives first wins.
  Measured: pinned **0/17**, unpinned **16/16** on the clean build — and adding **704 bytes** to
  an unrelated diagnostic buffer **inverted it** (pinned 3/3, unpinned 0/3). The resolution pin
  is not the cause; it is one of two accidental layouts.
  ⇒ ⭐ **But the capture path forms reliably** — pinned capture **2/2**, and every take since has
  formed. The show renders fine; the LIVE preview at venue resolution does not.
- 🔎 **Where the render time goes is still unnamed.** Ruled out by measurement: the lens
  influence radius (swings 5.5× while cost moves 1.1%), seed mass, and the four post-FX faders
  (they shift the curve ~20% but do not change its shape). The only surviving candidate is
  **how much of the SCREEN the lensed region covers** — cost halved as the camera pulled back
  in both takes that did so. Decisive test needs three arms: lens off, smear off, both off.
  ⚠️ A null on the lens arm alone must NOT be read as "not the render".
- ⚠️ **The lens influence radius reaches 458× its design scale** (max 9,152 against ≈20). His
  *"it lokey needs a cap"* row is worse than the board had it — and the render cost is
  INDIFFERENT to it, which is its own surprise.
- ⚠️ **MIDI running status may drop the second byte of a 14-bit pair** (`midi_input.mm:96`
  skips a data byte with no status). Covered today by the camera spring; it would bite any
  parameter without a spring in front of it.
- ⚠️ **`pause` has no representation.** He wants it as an on/off switch, not a 0–127 fader, and
  the registry has no switch type. HIS design decision, not started.
- ⚠️ **The sim pause is his "TIME GLITCH"** — measured **≈3× fps** at matched hole strength
  (n=3 before / n=6 after, one run). During a capture it does NOT pause the movie: the writer
  keeps appending at full byte cost (a 30 s hold = 900 frames ≈ 10.8 GB) and the camera keeps
  riding, which is the look. ⚠️ Trails are forced OFF while paused (`main.cpp:2619`).

---

## 8. HIS STANDING RULES FOR RENDERS

1. **Phase FX OFF** on every run from 2026-09-04 onward — *"we need to do the next runs with
   phaxe vx offfff important."* Held at 0 by CC so the log proves it.
2. **Delete with `rm`, never the Trash.**
3. **The venue resolution stays on his screen** — a control run at another resolution is HIS
   call to approve, never a silent relaunch.
4. **Correct beats fast.** It goes on stage.
5. **Don't press `C` during a take** — it toggles cinematic camera (settle 0.5 s → 1.5 s, orbit
   re-damped) and changes the feel of every move from that frame on. It logs `[CINE]`.
6. **Space is safe during a capture** — the writer cannot stall or disarm.

---

**Last Updated:** 2026-09-05 12:47:07  *(the `near = 1.0` safety bound is `kMinRho`, added to §6.17 on his order. Previous stamp 2026-09-05 12:14:00.)*  *(POV session: the shake was the near plane (§6.17); POV zoom inverted for him; takes 8 and 9 recipe in §5.1 on his order; §6.18. Previous stamp 2026-09-04 19:01:04.)*  *(evening session: seven takes rendered; the note-sustain cost driver found and the "spin costs 3.3x" claim RETRACTED; center-only test renders ruled in at 1.34x; CC-driven spin shipped `f0cac86`; sections 4, 5 and 6.13-6.16 are new. Previous stamp 2026-09-04 15:15:19.)*
