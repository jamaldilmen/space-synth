# HANDOFF — 2026-07-28 — The lens won. The stars are the wall. The dials don't exist.

**Written:** 2026-07-28 09:52:14. Branch `session-2026-06-30-honest-spacetime-friction`, on `b047744` + uncommitted.
**Supersedes:** `HANDOFF_2026-07-26_metric_hole_proven.md` §0 and §5.3 (they say retire the sprite lens and build on the march — **that is backwards**, see §1).
**Companion:** `REPORT_2026-07-28_failures_and_fixes.md` — what was tried, what missed, and why.

---

## 0a. STATUS UPDATE — 2026-07-28 12:34:43 — §3.2 IS ANSWERED, MEASURED

**`[KPROBE]` shipped** (`render.metal` `particle_vertex` buffer(9), `renderer.mm`
clear/read/print). 16 log Kelvin bins, ~24k particles sampled/frame, star path,
primary image only. Write-only — it changes nothing in the picture.

**The measurement, at rest, stable across frames (2026-07-28 12:23):**

| Kelvin | % of stars | % of light | bias (light÷count) |
|---|---|---|---|
| 1,259 K | 20.1 | 3.9 | 0.19× |
| 1,586 K | 33.5 | 6.8 | 0.20× |
| 1,997 K | 19.3 | 4.0 | 0.21× |
| 12,630 K | 0.3 | 21.1 | **70×** |
| 15,905 K | 0.2 | 21.7 | **108×** |

**73% of the stars are below 2,515 K and deliver 15% of the light. ~1% are above
10,000 K and deliver 75%.** `culled=0`.

⇒ **§3.2's premise is WRONG and can be closed.** The hue is NOT computed then
destroyed downstream. `blackbodyRGB` was hand-evaluated the same session and is
correct (2944 K→(1.00,0.69,0.42) orange; 14,140 K→(0.72,0.81,1.00) blue-white).
The orange stars exist. **`L = M^3.5` makes them invisible.** §3.2 and §3.3 are
ONE bug, and it lives in the brightness law.

⇒ Explains both dead ends: postfx bypass didn't help because the hue was never in
the frame to begin with; three luminance changes didn't move the colour because the
clip at 1000 kept the same ~1% visible each time.

⇒ **Direction, and it is the OPPOSITE of the 07-26 asinh attempt:** asinh raised the
bright end (1000→4450), pushed more pixels into the sensor bleach, and lifted **zero**
dwarfs. To get colour you must lift the FAINT end — lower the exponent, do not raise
the ceiling.

**⚠️ Not covered by this probe:** the gas block, the lensed secondary image, and the
fragment kernel. Also note `[LUMPROBE]` read (1.48, 0.67, 0.62) — the frame AVERAGE is
warm even though the resolvable points are blue. Not a contradiction: many dim dwarfs
make the diffuse total red; the few giants make the visible points. That is exactly
"too many blueish stars".

### §3.1 DIALS — first five shipped, 2026-07-28 12:32:36
`Mod menu → COLOUR → STAR LAWS`. **Every default equals the constant it replaced**, so
at defaults the picture is unchanged. Log ranges where the quantity spans decades
(SpaceEngine ships every brightness dial logarithmic — see
`RESEARCH_2026-07-28_spaceengine_scale.md` §5.6). Right-click any slider = reset.

| Dial | Default | Was |
|---|---|---|
| **Lum Exponent** ⭐ | 3.5 | `pow(Mstar, 3.5f)` |
| Lum Gain | 2.5 | `Lstar * 2.5f` |
| Lum Ceiling | 1000 | `min(…, 1000.0f)` |
| Kelvin Scale | 5772 | `5772.0f * pow(…)` |
| Kelvin Exponent | 0.55 | `pow(Mstar, 0.55f)` |

**Verified:** rebuilt + redeployed (bundle 12:32:36 > all sources), relaunched, and the
`[KPROBE]` Kelvin distribution reproduces the pre-dial run to within 0.4 percentage
points — which proves the `CameraUniforms` mirror between `renderer.h` and
`render.metal` is correct and the dials arrive at the shader with their intended
values. (The area-weighted column differs between the two runs; they are different
moments of a live field, and nothing touched the size law.)

### ⭐ THE SCALE — MEASURED 2026-07-28 15:21:23, his call ("maybe our scale should be checked")

`[KPROBE-SCALE]`, same probe, two more histograms — sprite size in PIXELS and mass in M☉:

```
meanPx = 1.02   maxPx = 16.31
size px:  0.92 -> 99.2%   1.41 -> 0.4%   2.18 -> 0.2%   3.36 -> 0.1%
mass M☉:  0.087 -> 54.7%  0.178 -> 21.6%  0.080 -> 9.7%  0.365 -> 8.5%
          0.75 -> 3.3%    1.54 -> 1.3%    3.16 -> 0.5%   6.49 -> 0.3%
```

**99.2% of stars are drawn at ONE PIXEL,** and they are not spread across that bin —
they are PINNED to `STAR_MIN_PX = 1.0f` by the `max()` in the size law.

**The mass scale is not a bug:** mode 0.087 M☉ = `imf.h`'s lower cutoff 0.08, a correct
Kroupa `dN/dM ∝ M^-2.3` over [0.08, 50], mean 0.30 M☉ by design. But feed that mode
through the render laws and the whole picture falls out:

| | mode 0.087 M☉ | tail 6.5 M☉ |
|---|---|---|
| K = 5772·M^0.55 | **1,507 K** | 15,900 K |
| L = M^3.5·2.5 | **0.00049** | 700 |
| R ∝ M^0.8 | 0.142 → floor | ~1.4 |

A **1.4-million-to-one** brightness ratio, and it independently confirms the Kelvin
histogram (1,507 K predicted vs the 1,586 K bin measured).

⇒ **This is why the diamonds.** At 1 px the radial core is sub-pixel, so the only part
of the fragment kernel with spatial extent is the spike cross (`render.metal:2102`,
falloff 90). Raising brightness grows the cross on everything: *"if jacked up all looks
like only diamonds."*
⇒ **And why Lum Exponent read as pure brightness.** A 1-pixel dot cannot communicate
hue. Colour needs area to land on.
⚠️ **The irony, on the record:** the saturation-PSF law was REMOVED because it put
"99.9% of stars at exactly 1px" and he said *"all stars weirdly the same size"*. The
`STAR_MIN_PX` floor reintroduced the identical condition through a different door.

### §3.1 DIALS — size set shipped, 2026-07-28 15:51:36
`Mod menu → COLOUR → STAR SIZE (measured: mean 1.02 px)`. Identity defaults again.

| Dial | Default | Was |
|---|---|---|
| **Size Gain** ⭐ | 1.0 | (new — blunt multiplier) |
| Size Exponent | 0.8 | `pow(Mstar, 0.8f)` |
| **Size Floor (px)** ⭐ | 1.0 | `STAR_MIN_PX = 1.0f` |
| Size Ceiling (px) | 48.0 | `48.0f * tanh(...)` |

**Verified:** bundle 15:51:36 > all sources; relaunched; `[KPROBE-SCALE]` reads
meanPx 1.01 with 99.7% at the floor bin and an unchanged mass histogram — i.e. the
struct mirror is right and the defaults are behaviour-identical.

**Still hardcoded, next increment:** spike weight `0.6` / falloff `90.0` (both in the
FRAGMENT shader, which does not currently receive `CameraUniforms` — needs a fragment
buffer binding), gas/star thresholds `1.5`/`3.0`, and the bleach window
`smoothstep(3,8)` in `postfx.metal:321`. Deliberately not batched: the spike is
downstream of the size, so fixing size may remove the diamond without touching it.

---

## 0. THE ONE THING THAT MATTERS NEXT

**Every star attribute in `render.metal` is a hardcoded constant.** Spike weight `0.6`,
spike falloff `90.0`, luminance clip `1000`, size ceiling `48.0`, Kelvin law
`5772·M^0.55`, mass-to-gas thresholds `1.5/3.0`, bleach window `smoothstep(3,8)`.
Every experiment therefore costs a full rebuild + relaunch, and **none of them can be
A/B'd live.**

Jamal, 2026-07-28 09:07: *"we do want them just not in a way that we cant change them /
modify their attributes thats a real loophole."*

He is right and it is the reason this session burned four attempts on the stars for
zero net progress. **Build the star attribute dials before touching star appearance
again.** Everything in §3 gets faster and judgeable the moment they exist.

---

## 1. SETTLED — DO NOT RE-LITIGATE

### 1.1 The sprite lens is the hero. The march is not. ✅ HIS VERDICT
2026-07-26 21:20:35, his own A/B: lens bit8 **ON** → *"ITS FINALLY THW CORRECT FEEL"*.
Lens OFF, same frame → only a bottom arc, a "smile".

Verified in code, not assumed:
- `renderer.mm:3101` — instance 0 = primary, **instance 1 = the SECONDARY lensed image**,
  instanced whenever `bhStrength > 0.5`.
- `render.metal:743-754` — its own comment records the OLD lens computed deflection from
  **NDC distance** (that one *was* a camera bend, and is what "flat/2D" really meant). It
  was **replaced**: deflection now comes from each particle's **actual 3D position** via a
  Schwarzschild LUT (`lensAlphaSample`, `:845`).
- `:806`, `:933` — second image culled for matter in FRONT of the hole. Correct physics,
  and exactly the NASA diagram: only the far side and the underside fold over.
- `app_state.h:52` — bit8 DEFAULT ON, his own call 2026-07-19: "always launch with lensing on."

### 1.2 The march cannot ever make Chladni structure
Its output is a **box-average of a 128³ density grid painted one hardcoded orange**
(`render.metal:2474`, `float3(1.0, 0.55, 0.25)`, no temperature input — and **no
temperature grid exists anywhere in the renderer**). Chladni structure is sub-pixel
sprite detail. Two different kinds of image; no resolution converts one into the other.
Proven the expensive way: trilinear sampling changed nothing he could see and was pulled.
⇒ **bit19 now defaults OFF** (2026-07-28). That is the orange he wanted gone.
The SHADOW is unaffected — that's bit15 + the capture cull, both still on.

### 1.3 They were fighting each other the whole time
Lens and march were **additively overlaid**: two pictures of one disk ~100× apart in
resolution. That is his "it doesn't connect to the rings". Separating them was one
checkbox and nobody had run it since the march landed.

### 1.4 The dilation shear is a FEATURE, not a bug
`render.metal:624` scales the view rotation by a per-particle `tDilate`. That is a SHEAR —
inner radii turn less than outer — and it is his *"beautiful time warpeyssss"*. It was
removed at 20:58 as a "rigid camera" correctness fix and he noticed in 9 minutes.
Restored, and the march now recovers the same `tDilate` from its sample radius so both
live in the same sheared frame (exactly invertible: rotations preserve |p|, and tDilate
is a function of |p| alone). **Do not "fix" this again.**

---

## 2. THE TO-BE STATE (his references, 2026-07-28)

| Reference | What it dictates |
|---|---|
| NASA Gargantua diagram | far-side image arching OVER the shadow, underside image BELOW, thin bright **photon ring**, **Doppler beaming** asymmetry (approaching side brighter) |
| NASA/Hubble deep field | stars in MANY colours — orange, gold, blue, white, red — at MANY brightnesses. Diffraction spikes on **a handful** of stars, not all |
| Globular cluster shot | dense blue-white core, colour surviving in the fringe, smooth density gradient |
| Slit-scan / light-trail reels | motion reads as continuous coloured **streaks**, not dots |
| His own "coat of gas" BH (2026-07-26 21:20) | *"clearly not a line of stars, it was a coat of gas, a ring of depth, it was perfect"* |
| His play-formed horizon (2026-07-26 21:19) | *"looks stunning… it has a depth to it"* — protect whatever makes this |

His summary of current vs target: ***"light years apart. lightyears."***

---

## 3. TO DO

### 3.1 ⭐ STAR ATTRIBUTE DIALS — build these FIRST (§0)
Expose as live UI dials, no rebuild per experiment:
spike weight · spike falloff · spike brightness threshold · luminance clip / soft-knee ·
Kelvin law slope+offset · size law slope+ceiling · gas/star mass thresholds ·
bleach window (`smoothstep(3,8)` → two dials).
Until this exists, every star change is a blind rebuild. This is the bottleneck.

### 3.2 ⭐ WHY IS EVERY STAR THE SAME COLOUR — hue is computed then destroyed
`kelvinU = 5772·M^0.55` alone spans 2944 K at 0.3 M☉ (orange-red) → 5772 K at 1 M☉ →
14,140 K at 5 M☉ (blue). **The spread is computed correctly and lost downstream.**
Evidence: colour did not move across three separate luminance changes; and raising
luminance (asinh) made it *whiter*, which points at saturation.
- Jamal: *"color temperature only ever worked in chladni form"* — there are TWO Kelvin
  paths, `:1276` (Chladni) and `:1416` (star). The dial feeds both. Star path loses it.
- ⚠️ 2026-07-28: still *"too many blueish stars"*.
- ✅ **RULED OUT — POSTFX IS NOT WHERE THE COLOUR DIES.** He ran the `postfx.metal:103`
  isolation keys (N = sensor bleach off, B = full postfx bypass) and reported it did not
  help. **Do not suggest this test again — it is spent.** The consequence is large and
  narrows the hunt sharply: the bleach, the tonemap, the auto-exposure and the grade are
  all **exonerated**. The hue is already gone by the time the frame reaches postfx, so it
  is being lost in the **vertex/fragment star path or in the additive accumulation itself**
  (`render.metal`), between `blackbodyRGB(kelvinU)` at `:1432` and the framebuffer.
  Start there: `starMix`, `imageWeight`, the `spectral` LUT path (bit16), the gas-block
  hue blend, and `emission = in.color * in.luminance * (...)`.
- `tuneColorK` (default **27000**) adds `|v|²·27000` to Kelvin, clamped 40000. Live dial,
  live code. Investigated but NOT confirmed as the cause — his "only works in Chladni
  form" argues against it. Verify, don't assume.

### 3.2b ⭐ RESEARCH: how SpaceEngine solves scale and size (HIS ASK, 2026-07-28)
Software-side, not aesthetics. SpaceEngine renders from planet-surface to
whole-universe scale in one continuous space — the exact class of problem this project
keeps hitting (`plateRadius` vs sim units vs real AU, the `±4.0` fine box, `bCull` in
r_s, particles at 1 M☉ vs a 4.3e6 M☉ hole, float precision at both ends).
Worth extracting: their **floating-origin / camera-relative coordinates**, **hierarchical
LOD across scale octaves**, **double vs float precision splits**, how they avoid z-fighting
and precision collapse at extreme range, and how they swap representations (point → sprite
→ mesh → volumetric) as an object's angular size changes. That last one is directly the
sprite-vs-march problem in §1.2, solved by someone else already.
⚠️ Extract the ARCHITECTURE, do not copy code — see `feedback_understand_the_dna`.

### 3.3 ⭐ THE 27,000:1 LUMINANCE CLIP (was §3.1 of the 07-26 handoff — STILL OPEN)
`starLum = min(Lstar·2.5, 1000)`, `Lstar = M^3.5`. Binds at **M ≈ 5.5**, so every star
above that is *exactly* the same brightness — and those are the only ones you can see.
Dwarfs sit at 0.037, giants clip at 1000.
⚠️ Replacing the clip with asinh (Lupton 2004) was tried 2026-07-26 21:52 and made it
**worse** on sight: peak 1000 → 4450 fed MORE pixels into the bleach → plain white dots.
**The clip and the bleach have to be solved together, not separately.** Do not retry
asinh alone. This is also why bit7 ("bright seed render") exists — a local hand-fix of
the same overexposure.

### 3.4 THE ORANGE SHADOW — done at source, verify
bit19 now defaults OFF. Confirm no orange on a fresh launch. If any remains, it is NOT
the march and needs a fresh hunt.

### 3.5 THE POST-COLLAPSE LIFECYCLE BUG (new, 2026-07-28)
His report: *"there is a small window when if i play after the blackhole has formed the
shape settles and the black hole returns quickly, which looks amazing — but then
sometimes the blackhole kinda falls into a new blackhole being formed from the collision
of the post-chladni stars, and then these new black-hole-to-bes turn into a ring of stars
that doesn't really do anything."*
Three distinct things in there:
1. the good window (settle → hole returns fast) — **find it and make it reachable on demand**
2. a spurious SECOND hole nucleating from post-Chladni star collisions
3. those proto-holes degenerating into an inert "ring of stars"
(3) is the old **L-wall ring** failure — see `space_synth_stars_not_trails_2026-07-25`.
Related: he cannot reproduce the good hole at all — *"it was an accident lol"*. **There is
no state save.** `presets/` holds render presets only, not sim state. A sim-state
snapshot would have saved this session twice.

### 3.6 THE ISCO DIAL DOES NOTHING — UNEXPLAINED
*"the orbit didnt change anything, timelapse playback was on."*
Plumbed and live: `renderer.mm:1436` honest branch, `dtP *= tIsco / iscoScreenSeconds`,
`gmNow = gmSim(lastHorizonMass)`.
⚠️ Two explanations were floated and **both retracted**: the `bhSeedMass` 2,150× claim was
the WRONG BRANCH (`bhPosed` is only true via an explicit `setBlackHolePose()` demo call),
and the "r_h flicker" was monotone growth in that log. **Still unexplained. Measure it.**

### 3.7 "ACCURACY METER FLASHING ALL CRAZY" — UNIDENTIFIED
His words, 2026-07-26. Never located in the code. Find which HUD element he means first.

### 3.8 UNIFY THE TWO IMAGES
Primary and secondary lensed images should read as ONE object. His 21:34 shots show a
bright particle disk and a separate warm arc structure sitting on top of each other.

### 3.9 RGB / "DARK SIDE OF THE MOON" DISPERSION (his new idea)
Light splitting to spectrum as it hits the lens. **Honest physical hook available:** the
fold-over image and photon ring arrive with a *different gravitational redshift* than the
direct image (that light climbed out from deeper). Tinting each image by its own redshift
is real dispersion, not a pasted prism. Faint chromatic fringing is already visible on the
arc edges in the 2026-07-26 21:19 shots — **find what's producing it before adding anything.**

---

## 4. CARRIED OVER, STILL OPEN (older sessions — verified still unfixed)

- **§0.1 the matter collapses from a thick torus (meanR 33) to a BALL (meanR 3.9).**
  Keeping it a DISK is still the path to real geometry. Build on the B2 drain-exemption.
- **The fine AMR box is fixed at ±4.0 at the ORIGIN.** Should track `r_h`. (Moot while
  bit19 is off; matters again if the march is ever revived.)
- **fps** — 30 playing vs 120 paused. Standing suspect is sprite FILL (1.0 px → ~6.5 px over
  ~1M particles). **`avgPtSize` at his real zoom has NEVER been measured.** Do that before
  touching sizes. Exposure is NOT an fps lever (A/B'd, 167 samples, flat).
- **Gritty/noisy Chladni after collapse** — *"not coarser, blurry, gritty, noisy."*
  Untouched, unmeasured. Candidate: post-merge mass spread driving `massSize ∝ M^0.4`.
- **Horizon latch vs honest r_h** — HUD reads `hole=1.00L` (LATCH) while honest `r_h` has
  been seen at 0.0000. Anything gated on the horizon must use `camHorizonR`, never the HUD.
- **bit18 is dead code** (`sL ≡ 1` for every particle; uninitialised read). An inert
  `pc * sL` no-op rode into `291e6bd` and can be stripped.
- **`bhDiskAxisY` is 0.0f at all 7 assignment sites** — two "plane fixes" were dead code,
  RETRACTED. Verify the live branch before fixing anything near it.
- Inner-spin invisible · Doppler invisible · drain · heat `clamp(0..5)` flattener (07-19).
- Sprite streak/stretching is **REJECTED as a mechanism, twice**. Trail mechanic is settled
  as density×speed (Chladni), NOT sprite stretching.
- `bCull = 7` tracks the COLLAPSED ball (matter inside 5.5 r_s). If the disk work lands it
  will clip the whole disk — better: derive it from measured `maxR`, don't hardcode.

---

## 5. LIVE CODE STATE (uncommitted on `b047744`)

| File | Change | Verdict |
|---|---|---|
| `app_state.h` | `uiTogRayMarch` true → **false** (bit19 orange off) | his order, unverified |
| `app_state.h` + `renderer.h` | `bCull` 16 → 7 | never isolated |
| `render.metal` | march recovers sprite `tDilate` shear | untested pairing |
| `render.metal` | dilation shear RESTORED at `:624` | restores his traces |
| `render.metal` | **star path = ZERO functional diff vs `b047744`** | verified 09:48 |

Everything tried on the stars this session was reverted. `git diff` on the star block is
comments only. That is deliberate — see the companion report.

**Build:** `bash package_macos.sh` (never bare `make`), verify bundle timestamps, then
`pkill -x SpaceSynth; open -n SpaceSynth.app`.
