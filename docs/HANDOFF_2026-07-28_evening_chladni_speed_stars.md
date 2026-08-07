# HANDOFF — 2026-07-28 evening — Chladni is broken, the 64× wall, and the two holes

**Written:** 2026-07-28 19:26:53. Branch `session-2026-06-30-honest-spacetime-friction`, on `b047744` + uncommitted.
**Companion:** `HANDOFF_2026-07-28_stars_lens_and_todos.md` (§0a has the star measurements + the dials shipped today).
**Also today:** `RESEARCH_2026-07-28_spaceengine_scale.md` — how SpaceEngine solves scale/size.
**Context:** he is working on UI and the audio engine in two other windows. This document is the render/physics thread.

---

## 0. THE HEADLINE — ⭐ THE CHLADNI PATTERN IS MATHEMATICALLY WRONG

**Found by code reading, 2026-07-28 19:2x. Not a hypothesis — the constant is in the file.**

His report: *"the chladni shapes look wrong its only rings now on almost all notes."*

He is right, and it is one line.

`src/core/modes.cpp:24`
```cpp
double alpha = 440.0 * std::pow(2.0, (midi - 69) / 12.0);   // ← the frequency in Hz
```

That `alpha` is fed straight into the Bessel argument, `src/core/bessel.cpp:41`:
```cpp
double Z2(int m, double alpha, double r, double th) {
    double j = besselJ(m, alpha * r);          // ← alpha·r
    double a = (m == 0) ? 1.0 : std::cos(m * th);
    return j * a * j * a;
}
```

**`J_m(alpha·r)` with alpha in HERTZ.** For middle C, alpha = 261.6, and `J_m` oscillates
roughly every π in its argument — so over r ∈ [0,1] you get **~83 concentric radial nodes**.

| note | alpha (Hz) | radial rings produced |
|---|---|---|
| C3 (48) | 130.8 | ~42 |
| C4 (60) | 261.6 | ~83 |
| C6 (84) | 1046.5 | ~333 |

The angular term `cos(m·θ)` is still there and still correct — but m ranges 0..11, so you
are asking the eye to see 11 angular lobes underneath **83 to 333 concentric rings**.
It reads as rings. On every note. Exactly as reported.

### The correct alpha is already in the codebase, unused
`src/core/bessel.cpp:7` — a validated table of **Bessel zeros**, sourced from
Abramowitz & Stegun and cross-checked against `SOUND ARCHITECT.html`:

```
J_0: 2.4048  5.5201  8.6537  11.7915
J_1: 3.8317  7.0156  10.1735 13.3237
...through J_6
```

For a circular Chladni plate the mode `(m, n)` has `alpha = ZEROS[m][n-1]` — a number
between **2.4 and 20.3**, not 130 to 1046. That is what puts the boundary node exactly at
r = 1 and gives **n** rings and **2m** angular lobes. The table is present, correct, and
nothing reads it for this purpose.

### Two corroborating dead giveaways
1. **`n` is passed to `makeLUT(int m, int n, double alpha)` and never used** — check
   `src/core/lut.cpp:8-53`. It is only used to build the cache key at `:79`. `n` was
   supposed to be the **zero index**. That is the missing link, and its disuse is the
   fingerprint of the regression.
2. `modes.cpp:22` calls alpha *"mostly vestigial in Phase 9, but map it to Hz for
   safety."* It is **not** vestigial — it is the single most important number in the
   pattern. That comment is how this survived.

### The fix (NOT applied — this is a law change, needs his word first)
`modes.cpp`: `alpha = ZEROS[min(m,6)][min(n,4)-1]`, and thread `n` into `makeLUT`.
⚠️ Two range problems to settle before touching it, because they change the instrument's
note→shape mapping and that is his call, not mine:
- `m = midi % 12` gives m up to **11**, but `ZEROS` only covers **m ≤ 6** (`MAX_ORDER 7`).
- `n = max(1, octave)` gives n up to **9**, but `MAX_ZEROS` is **4**.
Either extend the table (the zeros are standard and easy to source) or remap the
keyboard. **Extending the table is the honest option** — clamping would make 5 pitch
classes collide onto the same shape.

⚠️ Note `keyboardMode_` defaults **false** (`synth.h:128`), so `midiToModeIndex` is the
live path and m does vary per note. If he ever turns keyboard mode ON, note that
`keyboardToModeIndex` clamps to a 16-note window (`modes.cpp:36`) and everything outside
it collapses onto one shape — a second, independent ring-maker waiting to happen.

---

## 1. ⭐ WHY BLACK HOLES EXPLODE AT ×64 — mechanism, and the way past it

His ask: *"i want to know why black holes explode at 64 and if we can take that speed up
even higher. while maintaining our fps."*

### The mechanism, from the code
`src/main.cpp:2436`
```cpp
float simDt = 0.0165f * timeWarp;
```
and `main.cpp:351` clamps `timeWarp` to **64**. So at ×64 the integrator step is
**dt = 1.056 sim-seconds**, up from the pinned 0.0165.

That pinned dt is not arbitrary — see `space_synth_gravity_pump_2026-06-30`: **variable
timestep WAS the energy pump**, and pinning dt is what made the cluster hold.

A symplectic/leapfrog integrator is stable only while

> **dt ≲ 2 / ω_max**,  where ω(r) = √(GM / r³)

ω is set by the **innermost** orbit, and it diverges as r shrinks. Near a hole, r is small
by definition. So the black hole is *precisely* the place where the stability limit is
tightest, and ×64 blows past it there first while the outer field still looks fine. Past
the limit a leapfrog does not degrade gracefully — it **pumps energy every step** and the
matter flies apart. That is the explosion, and it is not a bug, it is the integrator
being used outside its domain.

### Why it is the black hole specifically
At r = 1.5·r_s with r_s = 1.0 sim, ω is ~30× larger than at r = 10. A single global dt
must satisfy the *worst* particle. One global dt for a field spanning r = 1.5 to r = 33
(measured meanR) is asking one number to serve a **~100× spread in ω**. It cannot.

### What already exists
`app.uiPhysicsSubsteps` (1–32, `main.cpp:1305`), whose own tooltip states the case:
> *"advances Nx time per frame (fast trails, volume fill) WITHOUT the dt-blowup that x64
> causes. Full physics runs ONCE; the extra N-1 are the LIGHT orbit kernel (central
> gravity only) so it stays cheap."*

So ×32 of extra advance is **already available and already stable**, and it composes with
timeWarp. That is the immediate answer to "can we go higher": yes, via substeps, today.

### ⭐ The real answer — BLOCK / HIERARCHICAL TIMESTEPS
Uniform substepping costs **N× everything** — that is his "costs N× FPS" from
`space_synth_stars_not_trails_2026-07-25`. The standard fix in production N-body codes
(Gadget, ChaNGa, and the same idea as `space_synth_gmat_adaptive_integrator`) is:

> **Give each particle its own dt, quantised to power-of-two blocks, chosen from its own
> ω. Only the particles that NEED the small step take it.**

The reason this wins here is a measured fact about our own field: **86% of the mass sits
in the outer, slow region** and only a small population is deep in the well. Halving dt
for 5% of particles costs 5% more work, not 100%. A ×8 block ladder could buy an order of
magnitude of global speed at a small fraction of the FPS cost of uniform substepping.

⚠️ **Do not build this from theory.** The first step is a measurement, and it is cheap
because the probe pattern already exists (`[KPROBE]`, added today):
**histogram ω(r) = √(GM/r³) across the live field, and report `dt_max = 2/ω` per
percentile.** That single number tells us exactly how many block levels are needed and
what the true ceiling is. Build `[WPROBE]` before writing any integrator code.

---

## 2. ⭐ THE TWO BLACK HOLES — he named it, and he is right

His words: *"we now kinda have two black holes like back in the day lol. a full 3d thingy
that i said was gorgeous and the physical particles. its not the same thing and ive been
too quiet about that. the used to be orange blob hole was the later addition this week and
its layering and only properly visible when i add a ridiculous amount of stars."*

**Both objects are real and both are in the code.** They are separate passes:

| # | Pass | What it actually is | State |
|---|---|---|---|
| 1 | `holePipeline` (`renderer.mm:3247`, `hole_vertex` `render.metal:2314`) | **The particles inside r_h, splatted black.** Real matter, real 3D shell. Rim-weighted: every splat at r > 0.7·r_h, 1-in-16 of the deep pile. | **This is the gorgeous one.** Visible in his 19:23 shot as the soft dark sphere in the cluster core. |
| 2 | `bhMarchPipeline` (bit19, `renderer.mm:3304`) | Box-average of a 128³ density grid, painted **one hardcoded orange** (`render.metal:2474`). | The "orange blob". Added this week. **Default OFF since 2026-07-28.** |

They are gated against each other at `renderer.mm:3244-3247`:
```cpp
bool metricShadow = (config.bhToggles & (1u << 15)) != 0u && …
if (!metricShadow && holePipeline && lastHorizonR > 0.0f) { … }
```
— so the hole pass is **skipped whenever bit15 metric-shadow is live.** That gate is the
thing to audit: it means turning on the metric shadow silently *removes* the object he
called gorgeous. Nobody has A/B'd that trade deliberately.

**Verdict to carry forward: #1 is the keeper.** It satisfies the BH core directive (the
hole IS the particles) and it is the one he has praised twice. #2 can never make Chladni
structure — settled 2026-07-26, see `HANDOFF_2026-07-28_stars_lens_and_todos.md` §1.2.

**Action:** stop treating these as one feature. Decide explicitly which draws the hole,
and make bit15's gate a deliberate choice rather than an accidental override.

---

## 3. STARS — better, not there. "still looks like little cubes"

Today's measurements (full detail in the companion handoff §0a):

- `[KPROBE]` Kelvin: **73% of stars below 2,515 K deliver 15% of the light; ~1% above
  10,000 K deliver 75%.** The colour law is correct; `M^3.5` hides the warm bulk.
- `[KPROBE-SCALE]`: **meanPx 1.02, maxPx 16.3, 99.2% of stars pinned to the 1 px floor**
  (`STAR_MIN_PX`). Mass mode 0.087 M☉ = the Kroupa cutoff, working as designed.
- **9 dials shipped today**, all identity-default: Lum Exponent/Gain/Ceiling, Kelvin
  Scale/Exponent, Size Gain/Exponent/Floor/Ceiling.

His verdict after tuning: *"its better with the tuning but still not there yet."* Colour
IS now visibly present in his 19:22 shot — greens, blues, oranges, whites across the
field. That is real progress and it came from the size dials, which supports the reading
that **hue needed area to land on**.

### ⭐ THE REMAINING DEFECT: "little cubes" — a concrete, unchecked hypothesis
A Metal point sprite is a **SQUARE quad**. Roundness comes only from the fragment kernel
falling to zero before the quad edge. If `glow`/`core` (`render.metal:~2123`) still has
energy at |pointCoord| → the corners, you see **the quad**, not a star — a little cube.
At 1 px this was invisible; the moment the size dials gave sprites real area, the square
became visible. That is consistent with the defect appearing exactly now.

**Check first, before changing anything:** evaluate the kernel at the corner
(|pc| = √2/2 ≈ 0.707) versus the edge-centre (0.5). If corner response is non-negligible,
that is the cube. The spike cross (`:2102`, falloff 90) is the *other* candidate and is
still hardcoded.

### ⭐ HIS DIRECTION: the long shot is right, bring it to the Chladni
> *"long distace virew way better. we need that ultra hi res also with the chladni."*

His 19:23 globular-cluster shot is the target look: dense warm core, colour surviving into
the fringe, smooth density gradient, real dark sphere in the middle. **At long distance
the sprites are ~1 px and the field reads as a continuum.** Up close the same sprites read
as discrete cubes.

That is textbook **angular-size LOD** — see `RESEARCH_2026-07-28_spaceengine_scale.md` §4:
SpaceEngine switches representation on angular size and **cross-fades, never sums**. We
currently use one representation at all distances. This is the same class of problem as
the sprite-vs-march conflict, and it is solved.

**He also has NASA references on file** and says they are enough to specify the target —
`docs/` has the deep-field / Gargantua / globular-cluster set referenced in the companion
handoff §2. Use them as the spec.

---

## 4. FULL OPEN LIST (carried, with today's status)

### Blocking / next
1. ⭐ **Chladni alpha = Hz instead of Bessel zero** (§0). Root cause found, fix NOT applied
   — needs his call on the m>6 / n>4 table extension.
2. ⭐ **`[WPROBE]` ω-histogram** before any integrator work (§1). Measure, then build.
3. ⭐ **Block/hierarchical timesteps** — the real answer to ×64 (§1).
4. ⭐ **Decide which hole draws** and audit the bit15 gate (§2).
5. **"Little cubes"** — evaluate the fragment kernel at the quad corner (§3).
6. **Angular-size LOD** so the close view matches the long view (§3).

### Still hardcoded (dials not yet built)
- Spike weight `0.6` / falloff `90.0` — **in the FRAGMENT shader, which does not currently
  receive `CameraUniforms`**; needs a fragment buffer binding first.
- Gas/star mass thresholds `1.5` / `3.0`.
- Bleach window `smoothstep(3,8)` — `postfx.metal:321`.

### Carried, unchanged
- **Matter collapses from a torus (meanR 33) to a ball (meanR 3.9).** Still the deepest
  geometry problem.
- **No sim-state save exists.** `presets/` is render presets only. It has cost him the
  good black hole twice — *"it was an accident lol"*. High value, low difficulty.
- **Post-collapse lifecycle bug**: good window → spurious second hole → inert ring of stars
  (the L-wall failure).
- **ISCO dial does nothing** — unexplained; both prior explanations retracted.
- **"Accuracy meter flashing all crazy"** — never located in code.
- **fps 30 playing / 120 paused** — standing suspect is sprite fill. Note the size dials
  now make this directly measurable and directly worse if pushed; watch it.
- **bit18 dead code** (`sL ≡ 1`, uninitialised read).
- **`bhDiskAxisY` is 0.0f at all 7 assignment sites** — two "plane fixes" were dead code.
- **`bCull = 7`** tracks the collapsed ball; will clip a real disk if the disk work lands.

### ⚠️ Rules earned the hard way — do not re-litigate
- **POSTFX IS RULED OUT** for the star colour. He ran the N/B isolation keys. **Never
  suggest that test again.**
- **The sprite lens (bit8) is the hero**, not the march. His A/B, 2026-07-26 21:20.
- **The dilation shear at `render.metal:624` is a FEATURE** — his *"beautiful time
  warpeyssss"*. It was deleted once as a "correctness fix"; he noticed in 9 minutes.
- **Do not raise the luminance ceiling to chase colour** — that is the 07-26 asinh failure.
- **Measure before changing.** Every miss this session was a change made ahead of a
  measurement; every win was a probe or a grep.

---

## 5. LIVE STATE

Uncommitted on `b047744`: `app_state.h`, `main.cpp`, `render.metal`, `renderer.h`,
`renderer.mm` — the 9 star dials, `[KPROBE]` + `[KPROBE-SCALE]`, bit19 default off,
`bCull` 16→7, the restored dilation shear.

**Build:** `bash package_macos.sh` (never bare `make`) → verify bundle timestamps ≥ source
→ `pkill -x SpaceSynth; open -n SpaceSynth.app`.
**Probes print ~1/s to stdout:** `[KPROBE]`, `[KPROBE-SCALE]`, `[MARCH]`, `[LUMPROBE]`.
Capture with `script -q <log> ./SpaceSynth.app/Contents/MacOS/SpaceSynth`.
