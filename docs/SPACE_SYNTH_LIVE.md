# SPACE SYNTH — LIVE

**The bible of the show.** Event facts, the scale, the delivery pipeline, and every lesson
that cost us a take. Created on his order 2026-09-04 15:12:04.

> **How to use this file:** everything below is either MEASURED (a number from a log or a
> file on disk) or HIS RULING (his words, quoted). Nothing here is inferred. If a line has
> no measurement and no quote behind it, it does not belong in this file.

**Last Updated:** 2026-09-04 15:15:19

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
| exposure / fluid / glitch / chromatic | 22–25 | available, **not used since take 2** |

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

**Last Updated:** 2026-09-04 15:15:19
