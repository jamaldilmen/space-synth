# DESIGN — SPECTRAL STARMAP: one colour law, two consumers

**Created:** 2026-07-24 14:13:20
**Branch:** `starmap-spectral` (worktree `/Users/airy/SPACE SYNTH/SS-STARMAP`)
**Base:** `a041600` — "The BH shadow is now pure ABSENCE, not a painted disc"
**Runs parallel to:** the metric-native BH window (`docs/DESIGN_2026-07-24_metric_native_blackhole.md`)
**Status:** approved by Jamal 2026-07-24, not yet implemented

---

## 1. WHY — the finding that started this

Jamal's ask: *"find out how NASA actually renders it. what the infrared thing does."*

### How NASA/ESA actually build those images

There is **no colour decision per object**. Every reference image is built the same way:

1. **N greyscale exposures**, one per narrowband filter. Webb's First Deep Field
   (SMACS 0723) used six NIRCam filters, ~2h each: F090W, F150W, F200W, F277W,
   F356W, F444W.
2. **Chromatic ordering** — sort by wavelength, blue→shortest, red→longest.
   SMACS 0723: F090W+F150W→blue, F200W+F277W→green, F356W+F444W→red.
   Alyssa Pagan (STScI): *"we generally do some standard chromatic ordering
   because it has the most scientific value and meaning."*
3. **Stretch** — raw frames open "almost totally black"; a nonlinear function
   lifts faint pixels while holding bright ones. This is Lupton 2004 asinh,
   which we already have at `render.metal:1034`.
4. **Composite** the colourised layers.

`esahubble.org/images/heic1502a/` (Andromeda, which Jamal linked) is the
degenerate case: Hubble/ACS, **two** filters only — 475nm→blue, 814nm→red,
green interpolated. 1.5 gigapixels, >100M stars. That two-filter choice is
exactly why it reads blue-white core with warm dust lanes and nothing else.

`aladin.cds.unistra.fr` — HEALPix-tessellated multi-resolution sky tiles
(HiPS, A&A 578 A114), ~1100 surveys / 900TB of real archival pixels. Useful
to us as ground truth for comparison, not as a technique to copy.

### What "the infrared thing" does — three jobs, three counterparts here

| Infrared does | Because | Our counterpart |
|---|---|---|
| Sees **through** dust | dust opacity rises steeply toward blue | dust extinction (shipped §2b) is currently **grey**, should be wavelength-dependent |
| Catches **redshifted** light | expansion stretches distant UV/visible into IR | **gravitational redshift near the hole is the same operation on a spectrum** |
| Sees **cool** things | Wien: 300–3000K peaks in IR | cool particles should read red, not merely dim |

So in a deep field: pale blue-white spiked points = nearby Milky Way foreground
stars. Smooth white/yellow blobs = cluster ellipticals at moderate z. Small
orange arcs and dots = high-redshift galaxies. **Red means far or dusty, blue
means near or hot.** The colour is a distance/temperature readout.

### Measured: the reference palette is NOT a band choice we can copy

Planck integrated over three candidate band sets, normalised R,G,B:

| T (K) | JWST NIRCam bands | Visible / eye-like | Hubble ACS-like |
|---|---|---|---|
| 2400 | R.27 G.75 **B1.0** | **R1.0** G.35 B.09 | **R1.0** G.24 B.05 |
| 4500 | R.06 G.26 **B1.0** | **R1.0** G.76 B.45 | **R1.0** G.68 B.53 |
| 5772 | R.04 G.20 **B1.0** | **R1.0** G.92 B.67 | **R1.0** G.87 B.95 |
| 20000 | R.02 G.11 **B1.0** | R.61 G.86 **B1.0** | R.27 G.41 **B1.0** |
| 40000 | R.02 G.10 **B1.0** | R.53 G.80 **B1.0** | R.22 G.36 **B1.0** |

**Every star is blue in NIRCam bands, at every temperature.** Our stars peak
shortward of 0.8µm, so the shortest band always wins; only the *degree* of blue
changes. Adopting JWST bands for a pure stellar population yields a monochrome
blue field.

Therefore **the oranges in the reference images are not stars.** They are
redshifted and dust-reddened sources. The point sources in those same frames
are white and blue-white, exactly as the table predicts.

The deep-field palette is what happens when objects span many redshifts. We have
exactly one mechanism that does the same thing to a spectrum: **the hole's
gravitational redshift.** Build the starmap on visible bands and stars redden as
they fall, for the same physical reason distant galaxies are red. The reference
palette then *emerges* rather than being painted.

### The structural defect this exposes

We compute an honest `blackbodyRGB(kelvinU)` at `render.metal:1040`, then
**override it with a hand-authored ramp** at `:1131`:

```metal
float3 gasCol = supernovaRamp(clamp(0.08 + 0.42*exc + 0.25*tN + (h1-0.5)*0.22, 0, 0.8));
starColor = mix(starColor, gasCol, gasMass * clamp(exc*4 + tN*0.3, 0, 1) * (0.6+0.4*h2));
```

Confirmed live **at rest** — this is the cyan in Jamal's 2026-07-24 12:40
screenshot. `supernovaRamp` is deliberately off the Planckian locus (its own
comment: *"a blackbody is never green"*). Driven by trilinear neighbour density,
so **every clump** gets emission-line hue; collapse makes clumps everywhere, so
the field goes teal.

The emission-line physics is **correct** — [OIII] 501nm and Hβ 486nm really are
emitted by shocked ionised gas. The defect is that the lines *replace* the
continuum via a ramp lookup instead of *adding* to it as flux. That is why it
reads as paint and why it pegs whole clumps to one hue.

Cost of baking RGB early, concretely: **gravitational redshift, dust reddening
and Doppler cannot be applied correctly to an RGB triple.** They are all
operations on a *spectrum*. Today the hole can only tint what it lenses.

### Canon this serves

- `space_synth_governing_model` — "3 scalars, one law, states emerge".
- `space_synth_powder_toy_lessons_2026-07-04` — "thresholds, NOT phases; kill
  envelopePhase gating". The colour path currently has **two** envelopePhase
  gates: `playMix` (`:1018`) and `starMix` (`:1049`). A spectral pipeline
  dissolves both — there stops being a play colour and a rest colour.

---

## 2. WHAT IS NOT CHANGING

Explicit, so no drift:

- **The accretion-disk `T(r)` block (`:1140`)** — owned by the BH window, being
  rewritten into the ray-march emitter. Not touched here.
- **Doppler stays off hue in the starmap.** Jamal killed view-dependent hue
  (`render.metal:951-957`: "a screen-space red/blue gradient that ROTATED with
  the camera"). Gravitational redshift depends only on depth in the potential,
  **not** on line of sight, so it does not rotate with the camera and is safe.
  Relativistic Doppler is view-dependent and stays on beaming/luminance only.
  *The disk is the exception and belongs to the other window:* there
  Doppler-on-hue is real (the approaching-side-bluer crescent), which is
  precisely why the disk has a different owner with a different rule.
- **The PSF size law and the luminance law.** `starMix` drives size, colour AND
  luminance (`:1293-1295`). Only the **colour** term is replaced. Size and
  luminance are untouched.
- **Lupton asinh** (`:1034`) stays as the display stretch. It operates after
  band flux, which is exactly where NASA puts it.
- **The photographic layer** — black sky, tiny sharp cores, JWST 6+2 diffraction
  spikes (ours at `:1471`+offset is a 4-way screen-aligned cross). Deferred;
  Jamal chose pipeline-first. Logged in §7.

---

## 3. THE CONTRACT

The BH window's binding requirement, accepted verbatim: the spectrum→colour step
must be callable from a ray sample, which reads the CIC grid and has no
`Particle` and no `vid`.

```metal
// ONE colour law. Two consumers: the particle vertex path, and the BH ray-march.
// PURE — depends only on its scalar arguments. No vid, no Particle struct,
// no position. Returns UN-NORMALISED observer-frame band flux (R,G,B),
// with the shift factor g already fully applied.
float3 spectrumToBands(float T_kelvin,      // rest-frame temperature
                       float g,             // shift factor; 1.0 = no shift
                       float lineStrength); // 0 = pure continuum … 1 = line-dominated
```

**Mottle is deliberately outside the function.** The caller perturbs
`lineStrength` before calling — the particle path hashes *position*, the
ray-march hashes its *sample point*. This removes the `vid` dependency at
`:1129` at the source and keeps the shared function a pure 3-scalar map.

### g belongs in the LUT, not in the caller

Numerically verified 2026-07-24, T=6000K, G band (500–590nm), fixed observer band:

```
g=0.60   B(g·T) over fixed observer band = 1.4510e+05
         g³ × emitter-frame flux         = 2.4183e+05   (ratio 0.600)
         g⁴ × emitter-frame flux         = 1.4510e+05   (ratio 1.0000)
g=1.60   B(g·T) over fixed observer band = 1.5294e+07
         g³ × emitter-frame flux         = 9.5585e+06   (ratio 1.600)
         g⁴ × emitter-frame flux         = 1.5294e+07   (ratio 1.0000)
```

Exact to four decimals across g = 0.6–1.6. This is the `I_ν/ν³` invariant:

```
g³·B_ν(ν/g, T) ≡ B_ν(ν, g·T)
```

**A shifted blackbody is exactly a blackbody at `g·T`.** Evaluating the function
at `g·T` over the fixed observer bands therefore already contains the full g⁴
amplitude; multiplying by g³ on top over-counts.

⚠️ **Scope of that result:** exact for **specific intensity along a ray**. If the
ray-march accumulates **volume emissivity per unit path length**, the emission
coefficient and path-length terms transform separately and a g³ may legitimately
belong there. The BH window must confirm which quantity it accumulates.

**Resolution that removes the ambiguity for both windows:** `g` is an axis of the
LUT. Neither side applies a multiplier; there is no factor to get wrong in
either window.

### 3.1 Consequence for the BH window: lines leave the bands under redshift

From `docs/spectral_bands_reference.txt`, visible band set, line position vs g:

| line | rest | g=0.80 | g=1.00 | g=1.25 |
|---|---|---|---|---|
| Hα | 0.6563µm | 0.820µm — **out** | 0.656µm — **R** | 0.525µm — **G** |
| [OIII] | 0.5007µm | 0.626µm — **R** | 0.501µm — **G** | 0.401µm — out |
| Hβ | 0.4861µm | 0.608µm — **R** | 0.486µm — **B** | 0.389µm — out |

Two things follow, both intended:

1. At rest (`g=1`) the three lines land in **three different bands** — R, G, B.
   That is *why* shocked gas reads teal-green. It is a real three-band
   signature, not an arbitrary hue choice. This is the physics
   `supernovaRamp` was reaching for; the pipeline just derives it instead of
   hard-coding it.
2. Under redshift the lines **migrate red and then leave the visible bands
   entirely** (by `g≈0.6` all three are gone). So gas deep in the potential
   reddens and then goes dark, on its own, with no special case.

That is correct physics — it is exactly why observatories switch to infrared for
high-z sources (§1). For the BH window it means **the region near the hole
naturally darkens and reddens**, which reinforces rather than fights the
"shadow = absence, never paint" verdict from `a041600`. No darkening pass is
implied or needed.

⚠️ It also means: if the hole's vicinity is ever wanted *bright* under strong
redshift, that is a **band-set** decision (switch to `nircam`), not a brightness
multiplier. Reaching for a multiplier there would be re-introducing paint.

---

## 4. IMPLEMENTATION

### 4.1 Two LUTs, built CPU-side in `renderer.mm`

Follows the existing `lensAlphaLUT` pattern verbatim (`renderer.mm:656-690`):
double-precision CPU integration → `newBufferWithBytes` /
`MTLResourceStorageModeShared` → `NSLog` of spot values for verification.

- **`LUT_continuum(T, g)`** → float4 band flux (RGB + pad).
  Planck integrated against the active band set.
  T log-spaced 1000–40000K; g linear ~0.3–2.0. Start 64×32, tune if banding.
- **`LUT_lines(g)`** → float4: how Hα 656.3, [OIII] 500.7, Hβ 486.1 distribute
  into bands at that shift, weighted by band response. Scaled by `lineStrength`
  and added to the continuum.

A line crossing a band edge as g changes is the real deep-field behaviour and
falls out of the g axis for free.

Verification hook, mirroring `[LENS-LUT]`:
```
NSLog(@"[SPEC-LUT] band=%s  T=2400 (%.3f,%.3f,%.3f)  T=5772 (%.3f,%.3f,%.3f)  T=40000 (%.3f,%.3f,%.3f)", …);
```
These must match `docs/spectral_bands_reference.txt` (the offline table in §1).

### 4.2 Switchable band sets

Band set is a CPU-side constant driving the bake; LUTs rebake on switch.

| set | B | G | R |
|---|---|---|---|
| **visible (default)** | 435–500nm | 500–590nm | 590–700nm |
| hubble-like | 400–550 | 550–700 | 700–950 |
| nircam | 0.80–1.65µm | 1.75–3.10µm | 3.10–5.00µm |

### 4.3 Line strength — existing mechanism, new target

`exc = smoothstep(3, 90, triCount)` and `tN` currently set a **ramp position**.
They will set the **line-to-continuum ratio** instead.

Stated honestly: this is a proxy for emission measure × ionisation, **not** a
Saha calculation. It is the same threshold mechanism already in the code
(threshold, not phase — canon-compliant); only its output target changes.

The gas then reads as pale lines over a continuum instead of replacing it.

### 4.4 Deletions

- `supernovaRamp` as a **hue source** at `:1018` and `:1131`.
- The `playMix` phase gate at `:1018`.
- The **colour** term of `starMix` at `:1294`.
- `heatRamp` (`:150`) — **verified dead** 2026-07-24 14:12: defined, zero call
  sites anywhere in `src/`.

---

## 5. INCREMENTS

Protocol: ONE verifiable change → confirm it landed → say what to look at → STOP.

| # | Change | Verification — what Jamal looks at |
|---|---|---|
| 1 | Add `spectrumToBands()` + both LUTs, wired but **never called** | **Nothing changes on screen.** `[SPEC-LUT]` log values match the offline table. |
| 2 | Route **rest** colour through it, `g=1`, `lineStrength=0` | **Cyan gone.** Rest field is pure blackbody orange/white. |
| 3 | Feed `lineStrength` from `exc`/`tN` | Gas hue returns — pale, line-over-continuum, only in genuinely dense cores. |
| 4 | Route **play** colour through it, delete `playMix` | Play/rest colour seam gone. One law across the envelope. |
| 5 | Hand the function to the BH window | They call it per ray sample with their `g`. |

Increments 2 and 4 are the ones that change what he sees. Each stops for verdict.

---

## 6. RISKS

- **Band-set switch invalidates a tuned look.** Defaults must be calibrated so
  his *first* glance is the intended look — never ship "the right value is
  somewhere on the fader" (`feedback_starmap_2of10_postmortem`).
- **LUT resolution banding**, particularly on the g axis near the hole where g
  varies fastest. Mitigation: bilinear sample; raise the g axis if banding shows.
- **Increment 2 will look plainer than today.** Removing emission-line hue from
  every clump is the *intent*, but the honest expectation is a less colourful
  frame until increment 3 restores lines properly. Say so before he looks.
- **Perf.** Two buffer reads replacing `blackbodyRGB`'s `pow`/`log`. Expected
  neutral-to-cheaper, but FPS is a live concern — measure, do not assume.

---

## 7. DEFERRED (photographic layer, not this spec)

- JWST **6+2 diffraction spikes** (hexagonal segments + secondary struts, four
  strut spikes deliberately hidden under mirror spikes). Ours is a 4-way
  screen-aligned cross — a different telescope's signature.
- Black sky / sparse-field density, tiny sharp cores.
- Wavelength-dependent **dust extinction** — the shipped §2b extinction is grey;
  making it band-dependent is the "sees through dust" job from §1 and is the
  natural follow-on once band flux exists.

---

## 8. SOURCES

- STScI — *How Are Webb's Full-Color Images Made?* webbtelescope.org
- ESA/Webb — *Image Processing*, esawebb.org/about/general/image-processing/
- SPIE Photonics Focus, Sept/Oct 2025 — Pagan & DePasquale interviews
- ESA/Hubble heic1502a — Andromeda, ACS 475nm/814nm
- Fernique et al. 2015, A&A 578 A114 — HiPS
- Lupton et al. 2004, PASP 116 133 — asinh composite (already in `memory/reference_stellar_render_sources.md`)
- Eker et al. 2018, MNRAS 479 5491 — mass→L/R/Teff (already in memory)

---

**Last Updated:** 2026-07-24 14:13:20
