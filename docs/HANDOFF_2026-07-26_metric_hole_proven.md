# HANDOFF — 2026-07-26 (evening) — THE METRIC HOLE IS PROVEN. Now: blob → divine geometry.

**Written:** 2026-07-26 20:15:00. Branch `session-2026-06-30-honest-spacetime-friction`.
**Supersedes** `HANDOFF_2026-07-26_bending_and_rotation.md` (its §0 is DONE; its §3.6 premise is REFUTED).
**Verdict at handoff (Jamal):** lens OFF + march emission at −2.63 → *"we're on it bro"*.

---

## 0. THE ONE THING THAT MATTERS NEXT

**The metric ray-march CAN carry the hole. That is now demonstrated, not argued.**
With the sprite lens OFF and `BH emission (log10 gain)` raised from its −7.5 default to
−2.63, the march produced a real shadow with real geodesic structure — concentric
lensed arcs, light wrapping over and under. The sprite lens is not needed for it and
should be retired.

**What it is NOT yet: divine geometry.** It is an orange/brown BALL with a hole in it.
The gap between here and Gargantua is **not** the renderer. It is these three, in order:

### 0.1 The matter is a BALL, not a disk (physics — the real blocker)
Measured at 20:07 (`[GRAV]`): `meanR=3.92 maxR=4.4`. Twenty minutes earlier the same
field was `meanR=33 maxR=100` with a genuine thick torus (`[DISKZ]` H/R = 0.14–0.18).
**It collapsed into a ball.** The march is drawing exactly what the physics produced —
a diffuse sphere — so it reads as a glowing blob rather than a thin bright disk with
over/under lensed images. Divine geometry needs the matter to STAY a disk. This is the
B-front "park a real orbiting disk instead of draining" work, and it is now the
critical path for the LOOK, not just for physical honesty.

### 0.2 `bCull` is marching mostly vacuum (free frames, one dial)
At handoff: `bCull = 40 r_s` with `r_h = 0.80` ⇒ ~32 sim of marched radius around
**4.4 sim** of matter — ~7× too wide in radius, and marched screen area goes as
`bCull²`, with 256 steps per ray. Measured **7–15 fps** in that state. Dialling
BH extent to ~6–8 should return most of the frames with nothing lost, because there is
no matter out there to show. **Try this before optimising anything else.**

### 0.3 The emission dial's default is a trap
`uiRayEmitLog = -7.5` ⇒ `emitScale = 3.16e-8`. At that value the march draws a
whisper and looks like nothing — which is why "the march is drawn but does nothing"
persisted for two days. Anyone testing the march MUST raise this first.
⚠ It cost this session a wasted change: the fine-grid work below was written and
shipped while emission was at 3.16e-8, so it could not possibly show a difference.
**Read the live uniforms before writing shader code that feeds them.**

---

## 1. WHAT SHIPPED (this commit)

### 1.1 Playback phase integrated per particle — `pose_phase_advance` (VERDICT: passed)
Earlier commit `5d8fa5b`. The playback angle was `wEff * cam.bhPoseTime`, an absolute
angle off an unbounded accumulator, carrying a `bhPoseTime·(dω/dr)·v_r` drift term:
paused ⇒ `v_r=0` ⇒ vanishes (clean); running ⇒ reverses sign with `v_r` and grows
forever. Fixed with a per-particle `θ = ∫ω(r(t))dt` compute kernel, wrapped to
`[0,2π)`. Jamal: *"you actually fixed it in one prompt."*
Construction notes that matter: dispatch on the RENDER command buffer (runComputePass
is encoded before the frame's pose clock exists); NOT in the vertex shader (instances
0/1 are one draw call with no ordering guarantee → the secondary image would read
either side of the increment); `vid`-keyed state is safe because the spatial sort
writes a separate `sortedParticlesBuffer` and never permutes `particleBuffer`.

### 1.2 Time-lapse clock is now WALL-CLOCK, filtered (VERDICT: passed)
`dtP` was a FIXED `1.0/60.0` **per rendered frame**, so the spin RATE was proportional
to framerate: paused at 120 fps advanced 2.0 phase-s per real second, playing at 34 fps
only 0.57 — **pausing sped the disk up 3.5×**. Jamal: *"the paused mode is so much
smoother 120 fps and the spin is faster than at play, that doesn't make sense."*
Same class of defect as the c³ bug: a rate that depends on framerate.
Fixed via `Impl::emergentPoseDt()` — an EMA (~10-frame e-fold) of the true wall delta,
used by BOTH render overloads. The EMA is deliberate: the fixed step existed because
the RAW delta, multiplied by the time-lapse compression, amplified framerate jitter
into jumpy motion (07-25). Filtering gives the correct mean rate AND smoothness.
Verdict: *"they move the same apart from the fps diff."*

### 1.3 Auto-exposure floor 0.05 → 0.01
`autoExp = clamp(kExpKey/avgLum, floor, 1.0)`, `kExpKey = 0.35`. MEASURED with
`[LUMPROBE]` (which reads the SAME top mip of `offscreenTexture` the shader samples,
`renderer.mm` binding index 3):
```
early rest  avgRGB=(4.68 3.36 4.47) -> avgLum  3.72 -> needs 0.094   OK
late  rest  avgRGB=(17.2 13.1 16.5) -> avgLum 14.24 -> needs 0.0246  JAMMED
```
The iris ran out of travel at `avgLum > 0.35/0.05 = 7.0` and the rest state measured
twice that, so the frame could not be stopped down and the sensor bleach (correctly)
burned it white. Play/Chladni states are untouched: their avgLum is 0.03–0.5, far below
the key, so `autoExp` stays pinned at 1.0.
⚠ Does NOT stop the underlying light runaway — see §3.1.

### 1.4 The march samples the FINE AMR grid
Coarse hash = `cellSize 1.0` sim; fine AMR grid = same 128³ over ±4.0 ⇒ `cellSize
0.0625`, **16× finer**. Costs no new work: `bin_fine_mass` ALREADY runs every 2nd
frame (`pmGravityOn && sorFrame && totalAmplitude < 0.02`) — i.e. in silence, exactly
when a horizon exists — and `amrOn` defaults ON. Two extra bindings, fine inside the
box, coarse fallback outside (the fine box is origin-centred).
Units: `bin_fine_mass` stores `Σm × MASS_FP(64)`; the emission dial was tuned against
coarse per-cell COUNT, so it is rescaled by the cell-volume ratio.
⚠ CALIBRATION CAVEAT: that equivalence assumes ~1 M☉/particle; measured, the field is
~82% dwarfs below 0.5 M☉, so mass density under-reads count density ~2×.
⚠ **This only matters when the field fits the box.** At `meanR=33` it sampled almost
nothing; it started contributing only once the field collapsed to `maxR=4.4`. If the
fine grid proves its worth, make the box TRACK `r_h` instead of a fixed ±4.0 at origin.
**The 07-26 revert of this idea blamed the fine grid; the actual cost was a SECOND
binning pass added every frame. fps never returned after that revert, which already
said the grid was innocent.**

### 1.5 Probes added (keep them)
- `[DISKZ]` — per shell: `H = sqrt(<z²>)`, `Rcyl`, `H/R`. Answers "is the disk flat".
- `[MARCH]` — `camHorizonR`, `lastHorizonR`, `emitScale`, `innerR`, `bCull`, fine-box
  extent, fine buffers bound, and `DRAWING` vs `returns black (no r_h)`. The march
  self-gates in-shader on `cam.horizonR <= 0`, so it can be encoded every frame and
  draw nothing; without this line "I see no difference" is unattributable.
- `[LUMPROBE]` now also prints `exp=`.

---

## 2. PREMISES REFUTED THIS SESSION (do not rebuild on them)

1. **"The disk is flat / 0 depth / the L-wall is why the hole looks 2D."**
   FALSE about the matter. `[DISKZ]`: H/R = 0.14–0.18 across mid shells, inner region
   *thickening* 0.34 → 0.86 over 34 samples. A thick torus at all times. The flatness
   was **entirely in the render** — a screen-space sprite displacement is a camera bend
   and cannot make an over/under image no matter how thick the matter is.
   ⇒ `DESIGN_2026-07-24 §4`'s "hard requirement: make the disk a real 3D emitter" was
   **already satisfied**. The requirement that actually bites is keeping it a DISK
   rather than letting it collapse to a ball (§0.1).
2. **"Frame saturation costs framerate."** FALSE — tested properly. A temporary sweep of
   the manual exposure (1/3/10, 6 s per step, untouched silent run, 167 samples) with
   avgLum as the control: `lum<1` → 34.2/33.9/34.2 fps; `lum 1-4` → 34.6/35.5/35.0;
   `lum 4-8` → 33.5/34.0. **Flat.** The apparent fps-vs-brightness correlation inside a
   single run is the COLLAPSE driving both: density raises overlap (real fill cost) and
   raises brightness (free). Recorded as a comment at the dial in `main.cpp`.
   ⇒ The fps suspect remains sprite FILL. Do not re-chase exposure for performance.
3. **"bit18 / the diffraction-spike growth is a prerequisite for anything."** Dead end.
   Screen-space sprite stretching is rejected as a MECHANISM (twice, second time even
   with `starness /= sL`): *"the way that the sprites look now we never ever want them
   to move."* A `pc * sL` no-op from that line rode into `291e6bd`; it is inert
   (`sL ≡ 1`) and can be stripped.

---

## 3. STILL OPEN

### 3.1 The light runaway — ~1% of particles carry ~98% of the emitted light
`starLum = min(M^3.5 · 2.5, 1000)`. Applying the measured histogram with bucket
midpoints: 818 dwarfs at ~0.3 M☉ contribute ~30 total; the **12** particles in the
2–100 M☉ buckets contribute ~9,000. Dwarfs sit at 0.037, giants clip at 1000 — a
**27,000:1** dynamic range no single exposure can hold. Merging keeps feeding that tail.
This is why bit7 ("bright seed render") makes the field "look normal": it drops
`M ≥ 50` bodies from ~1000 to luminance 10 — a local hand-fix of the same overexposure.
The verified reference (`reference_stellar_render_sources`, Eker 2018 + Lupton 2004)
indicts this by name and notes `postfx.metal` is ALREADY a hue-preserving max-channel
tonemap — **the whitening is upstream, in the Kelvin pedestal + the luminance clip.**
Note Eker's MLR does NOT fix it (at 5 M☉ Eker gives MORE luminance than M^3.5).

### 3.2 Stars read as "blueish squares", want disco / iridescent / alive
His words: *"they should feel more disco, more iridescent, more alive… it's all flat
blurred to these squarish blue merger looking stars."* The "squarish" is literally the
diffraction cross: `spikeX/spikeY` with a 90.0 falloff draws a plus/diamond at 0.6
weight on every slow sprite. One shape and one colour repeated 2M times cannot read as
varied. Also `kelvinU = 5772·M^0.55` is UNBOUNDED in mass — ~82,000 K at 126 M☉, hotter
than any real star (real T_eff flattens ~40–50 kK); verified cross-check has it +21% at
59 M☉. Combine with §3.1 saturation ⇒ identical blue-white diamonds.
**This was the agreed next task after the circle feel.**

### 3.3 fps
7–15 fps with the march wide (`bCull=40`, 256 steps); 30 playing vs 120 paused without
it. §0.2 is the cheap win. Beyond that the standing suspect is sprite fill from the
star stand-down (1.0 px → ~6.5 px over ~1M particles); **measure `avgPtSize` at his
actual zoom, star branch on vs off, before touching sizes.** Still never priced.

### 3.4 The gritty/noisy Chladni after collapse
*"the Chladni pattern returns at a lower res once the field has collapsed — not
coarser, blurry, gritty, noisy."* Untouched, unmeasured. Candidate: post-merge mass
SPREAD driving per-particle size (`massSize ∝ M^0.4`) and luminance variance → speckle
where the bars used to be smooth. Unverified.

### 3.5 The horizon latch vs honest r_h
`hole=1.00L` (L = LATCH) is decoupled from the honest `r_h`, which was seen running
0.23 → 0.31 → **0.0000** while the HUD still read 100%. Two probes disagreed within one
run (`[HORIZON] r_h=0.0000` vs `[MARCH] camHorizonR=0.80`). Anything gated on the
horizon needs `camHorizonR`, never the HUD.

---

## 4. PROCESS — WHAT COST TIME (and what saved it)

1. **I shipped a shader change that fed a uniform I had not read.** The fine-grid march
   went in while `emitScale = 3.16e-8`; it could not show anything. Read the live
   uniform values first.
2. **I misread my own probe** — `%.3f` printed `emitScale=0.000` and I called it zero
   in writing. It was 3.16e-8. Use `%g` for anything spanning decades.
3. **I claimed a 5× fps win from a cross-run correlation, then killed it with an A/B
   I asked for myself.** Two runs with different scene histories are not an experiment.
   The A/B took ~15 minutes and prevented a lucky number being recorded as a mechanism.
   Jamal asked for it ("DO AB") — that instinct was right.
4. **Verify the LIVE branch before fixing.** `bhDiskAxisY` is `0.0f` at all 7
   assignment sites, so the previous handoff's "twin at :422" is unreachable: fixing it
   would have been a no-op. Both host branches select the z-axis block.
5. **What worked repeatedly: measure, don't reason.** Every premise overturned today
   (disk thickness, exposure-vs-fps, emitScale, the dead twin) fell to one probe.

---

## 5. FIRST MOVES FOR THE NEW WINDOW

1. **Dial `BH extent` from 40 → ~6–8** (§0.2). Free frames, no code. Confirm with fps.
2. **Keep the matter a DISK** (§0.1) — the real path from orange blob to divine
   geometry. Build on the B2 drain-exemption; the field currently collapses from a
   thick torus at `meanR 33` to a ball at `meanR 3.9`.
3. **Retire the sprite lens** for the hole now that the march is proven (§0).
4. **Then the stars** (§3.2) — bounded, instantly judgeable, and the agreed next task:
   cap `kelvinU` at a physical ceiling, break the one-shape diffraction cross, and
   address the 27,000:1 clip (§3.1).
5. Do NOT re-chase exposure for fps (§2.2). Do NOT re-land sprite streaking (§2.3).

Read first: this file, then `space_synth_seam_and_rotation_2026-07-26` (memory),
`DESIGN_2026-07-24_metric_native_blackhole.md` (§4 premise now refuted — see §2.1),
`reference_stellar_render_sources` (memory) before touching star colour.
