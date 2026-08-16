# HANDOFF — BH LENS, THEN TUBE/SPHERE BEFREIUNG
**Written:** 2026-08-14
**His order, verbatim:** *"HANDOFF BH LENSE THEN TUBE / SPHERE BEFREIUNG"*
**Branch:** `kill-the-tube-2026-08-11` @ `38b72f1`, worktree `SPACE-SYNTH-TUBE-killtube`
**Bundle these claims were verified against:** `SpaceSynth.app` @ **2026-08-13 14:56:47**
**Berlin:** 19 days out.

> This supersedes the board's ordering. Row 16 (the lens) was parked "later" on his own call
> at 15:05 on 2026-08-13; **eight hours later he named it first.** The newest signal wins —
> correct the board to match, do not quote the park back at him.

---

## 0. READ THIS BEFORE YOU CITE ANY LINE

Every file:line below was re-verified on 2026-08-14 against the working tree, not copied
forward. **Two citations in the older docs had already drifted** because of edits made on
2026-08-13:

- `ORBIT_R_CHLADNI` / `STAR_MAP_CAP` are at **`particles.metal:339` / `:340`**, not `:309` /
  `:310`. A ~30-line constant block was inserted at `:158` yesterday and pushed everything down.
- The board's A3②-white row cites `render.metal:1941` for the seed billboard. It is at
  **`:2075`**.

The standing failure mode on this project is citing a comment, a dead branch, or a stale
line as if it were live. Re-grep before you write a number into the board.

---

## 1. THE LENS — WHAT HE SAW, AND WHAT THE CODE ACTUALLY DOES

### 1a. His insight (2026-08-13, over breakfast, with photos)

> *"the bend we have is like the one on a plate — see the bending of the pavilion above the
> plate. that's exactly what our fakeish black hole lens looks like. it is never physically
> bending anything."*

He photographed a glossy dinner plate reflecting a garden pavilion. The pavilion's edge reads
as bent because the **surface** is curved — no light was deflected, the **picture** was. His
claim: our lens is that. And he tied it to a symptom he has reported for weeks —

> *"sometimes two rings stack on top of each other like rings, not like a black hole."*

A radial push around a screen-space centre can only ever move existing pixels around a circle,
so concentric rings are the only thing it can produce. That is a sound argument.

### 1b. ⚠️ WHAT I GOT WRONG, AND THE CORRECTION

**I first read the lens as a screen-space warp and I was reading a superseded comment.**
`render.metal:878-892` describes exactly that — *"the deflection magnitude is driven by each
particle's actual 3D impact parameter … Direction stays NDC-radial"* — and immediately below
it a second comment block replaces that design. **The older block is not live. Do not cite it.**

**What is actually live** (`render.metal:921` onward, inside `if (lensActive && cam.horizonR > 0.0f)`):

- A **thin-lens solve in ANGLE space**: `β = θ − α(θ)·D`, seeded weak-field and refined by
  Newton iteration, using an **α(b) LUT that is log-divergent at the photon sphere**, and each
  particle's **true depth D behind the hole**.
- `θ_E = sqrt(2·rsW·D)` (`:1003`) — derived from the Schwarzschild radius and the depth. Physical.
- The result is **re-projected through the camera**: `out.position = cam.viewProjection * …`
  (`~:993`). The particle is drawn where the solve says its image belongs.
- **Two images, not one layer**: instance 0 = primary θ₊, instance 1 = secondary θ₋
  (`:642 isSecondary`), the secondary dimmed by its real relative magnification μ₋/μ₊. The
  secondary early-outs beyond 8·θ_E for cost (`:686`).

**So the deflection itself is not a plate.** It is an angle-space solve with a real α LUT, and
it moves particles, not pixels.

### 1c. BUT HIS READING IS NOT WRONG — HERE IS WHERE THE PLATE IS

The honest position after one pass: **the bend is physical; the GATE and the SCALE are screen
quantities, and one of them is documented-wrong.**

- The entire lens is gated on `lensActive`, which requires **`cam.bhShadowNdcRadius > 1e-4f`** —
  an **NDC (screen) radius**.
- That radius is computed at **`renderer.mm:1642`**:
  `bhShadowNdcRadius = bSim * plateRadius / frustum`, else `0.0f`.
- **The code's own comment immediately above it says the divisor is wrong** — the radius comes
  out *"~1.2/0.414214 = 2.897x TOO SMALL"* — and that `d` must be camera→**HOLE**, not
  camera→origin, *"the seed wanders, so the error should grow as it drifts off-origin."*
  Marked as the next change and deliberately not batched. **It was never made.**
- `bhLensActive` requires `totalAmplitude < 0.02` — **the lens is OFF during play.**

**So: a physical solve, switched on and sized by a screen-space number that is known to be
~2.9× too small and measured from the wrong point.** That is the seam his plate analogy is
pointing at, and it is a much sharper target than "rewrite the lens."

### 1d. THE TEST THAT SETTLES IT — from his own NASA reference

He attached the two NASA panels. They name three features, and **none can come from bending a
picture**:

1. **Image of the disk's far side** — light from behind, bent over the top.
2. **Image of the disk's underside** — light from beneath the far side, bent under.
3. **Photon ring** — light that orbited the hole 2–3× before escaping.

⭐ **The decisive one:** the NASA top-view panel shows that rays from beneath the far side
travel **more than 180°, so their paths cross — the far-side image arrives LEFT-RIGHT SWAPPED.**
No image-space warp can reproduce a parity flip. **Whether our secondary image swaps handedness
is a yes/no question, it is visual, and it costs one look.** That is the first thing to do.

### 1e. FIRST MOVES, IN ORDER

1. **Ask him to look for the parity swap** (1d). Free, decisive, needs his eyes.
2. **Fix the documented `bhShadowNdcRadius` divisor** (`renderer.mm:1642`) — the code already
   states the correct form and the 2.897× factor. One change, then his verdict.
3. Only then reopen whether the solve itself needs replacing.

🚨 **Do not start by rewriting the lens.** Two of the last three hypotheses on this project
were refuted by their own fixes.

---

## 2. TUBE / SPHERE BEFREIUNG — AND THE MEASUREMENT THAT NOW BACKS IT

**His standing complaint:** *"two things still piss me off. THE TUBE + THE SPHERE THAT IS OUR SPACE."*

### 2a. Both are literal clamps, eight lines apart

- **THE TUBE** — `ORBIT_R_CHLADNI = 6.0f` (**`particles.metal:339`**). During attack/decay/
  sustain the cap goes **cylindrical in XY** (`playCap`, **`:3319-3321`**), in the code's own
  words: *"PLAY: cylindrical (XY) cavity — the tube is the instrument's shape."*
- **THE SPHERE** — `STAR_MAP_CAP = 100.0f` (**`:340`**), a true 3D radial wall at silence.
- **The transition is a `mix()`** — attack lerps the cap 100 → 6, so playing squeezes the
  universe from a 100-sphere into a 6-tube and releasing lets it back out. **That breathing is
  why he sees both.**
- 🚨 **The comment on `:340` lies:** it reads *"silence: NO cap (the star map has no tube limit)"*
  on the line that defines the cap.

### 2b. ⭐ NEW — B7 IS NO LONGER A HYPOTHESIS. MEASURED 2026-08-13.

`H/R` (vertical scale height over cylindrical radius) had **never been read during play**.
It has now been, on his own play run:

| state | H/R |
|---|---|
| silence | 0.31 – 0.84 |
| **play** | **0.0047 – 0.071** (inner bins 0.010–0.033) |

**A 10–30× collapse — the board's own criterion for B7 confirmed.**

⭐ **And it settles the C1 question without C1.** `H` is `sqrt(<z²>)` computed in **world
space**, not from the screen. The camera sitting on +Z cannot manufacture it. **The field
genuinely is a sheet during play** — his *"0 depth, like an inward spiral of paper"* is
literally true in the physics. The orbit test he was asked for twice is no longer needed to
decide this; he dropped it himself (*"let go of that side on rotation thing"*).

### 2c. THE CONSTRAINT ON ANY BEFREIUNG

**Removing a confinement without a replacement lets the field evaporate.** The answer is a
better boundary, not a bigger number (LIMITS-ARE-PERCEPTUAL). The cavity is r≤6 AND |z|≤6 —
a can 12 wide by 12 tall, **roughly isotropic** — so "the tube makes it flat" is *not*
self-evident from the clamp dimensions. The measured H/R collapse says the flattening is real;
it does **not** yet say the clamp is what causes it. Establishing that is the first job here,
and `[DISKZ]` now gives a number to test any change against.

---

## 3. TREE STATE — nothing committed, four changes live in the bundle

All of 2026-08-11 → 08-13 is **uncommitted** on `kill-the-tube-2026-08-11`.

| change | where | status |
|---|---|---|
| DEAD-COMPUTE corpse early-out | `particles.metal:1156` region | shipped; A/B could not attribute; **parked on his call** |
| `SS_NO_DEADSKIP` A/B control (bit28) | `main.cpp`, `particles.metal` | built + verified, unused since |
| `[CELLPROBE]` occupancy probe | `renderer.mm` (after `[GRIDPROBE]`) | live, 1.05 ms/120 frames |
| **Ghost-read fix** — `SCATTER_PER_CELL = 32u` | `particles.metal:158` + 2 read sites | shipped, **changed nothing measurable** |

### 3a. The ghost read — real bug, honest negative result

The scan clamped at `MAX_PER_CELL = 128` while the scatter writes only **32/cell**
(`spatial_hash.metal:351`) into ranges sized by the **uncapped** prefix sum. Measured:
**73.9% of the collision scan's reads were slots nothing wrote that frame**, in a buffer that
is never cleared. Fixed by matching the read depth to the write depth — the convention the
tiled kernel already used (`spatial_hash.metal:669`, `:714`).

🚨 **The fix changed nothing.** The clump runaway reproduces to **0.2%** (maxCell 407,660 vs
408,198; clump 5,338× vs 5,351×) and fps sat inside noise. **The ghosts were not driving the
collapse.** Keep the clamp because reading unwritten memory is wrong, not because it bought
anything.

### 3b. Still open, unexplained

- **The clump runaway.** At rest, 30 s from launch: one cell holds **408,198 particles = 20.4%
  of the field**, clump factor **5,351× and climbing**, 87% of matter in cells over 32. The
  driver is an uncapped path — self-gravity reads `cellMass`, deliberately honest — and is the
  obvious next suspect. Nothing measured yet.
- **The fps cliff** (13–14 fps with the field in clutter). Not the neighbour scans — both are
  bounded. Remaining suspect: fragment overdraw. **Five-second test only he can run: when it's
  clumped and slow, zoom the camera way out.** fps jumps → overdraw.
- **Frozen mergers** *("8 mergers that are stuck even at 64x speed")* — `seeds=8` in the log
  matches his count exactly. Undiagnosed.
- ⚠️ `[CELLPROBE]`'s `ghostReads` figure is computed against the OLD 128 depth. It measures the
  **mismatch**, not the live scan. Repoint it or drop it before anyone reads it as current.
- 🚨 **The temp `mrg=` gate counters are still in the tree** — four sites, strip before shipping.

---

## 4. METHOD NOTES EARNED YESTERDAY

1. **Measurement is the work while he is away** — his words: *"this is btw the perfect kinda
   thing to do when im on the go."* Soaks and A/B runs need no eyes. Visual verdicts do.
2. **Sequential A/B runs on this machine cannot attribute.** Order/thermal is ~15 fps —
   larger than most effects. A control that ran after 6 minutes of idle started at 55.7 fps;
   the treatment, launched 20 s later on a hot machine, started at 37.8. Same binary class.
   **Alternate the arms WITHIN one run, or don't claim a delta.**
3. **Check what else is on the GPU before starting a clock.** GTA and Ableton each cost a run.
   `ps -Ao pcpu,comm -r | head`.
4. **Measure the state the bug lives in.** I declared A3②-white a no-op from a rest run where a
   single body dominated; his play run showed `r_h = 0.0000` with `seeds` 3→10 and `Mmax`
   102,102 — the billboard *is* drawing. Right measurement, wrong state, wrong conclusion.
5. **A refuted hypothesis is a result.** Three of mine were killed yesterday by their own
   measurements — the neighbour-scan cost model, the ghost-read cause, the A3② no-op. Each cost
   under an hour because the probe came before the fix. **He noticed the circling and called it:**
   *"running in circles and burning hours and tokens."* The measuring earned its keep; the
   guessing between measurements did not.
