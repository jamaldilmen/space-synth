# RESEARCH — 2026-07-28 — How SpaceEngine solves scale and size (software-side)

**Written:** 2026-07-28 10:46:46
**Answers:** `HANDOFF_2026-07-28_stars_lens_and_todos.md` §3.2b (his ask, 2026-07-28)
**Rule followed:** extract the ARCHITECTURE, do not copy code (`feedback_understand_the_dna`).

Every claim below is tagged:
**[SE]** = stated by SpaceEngine's own dev blog / manual / settings.
**[FIELD]** = the standard technique from the wider large-scale-rendering literature (Outerra, O'Neil), not SE-specific.
**[OURS]** = measured in our repo today, this session.
**[INFERENCE]** = my reading, not stated anywhere. Treat as a hypothesis to measure.

---

## 0. THE HEADLINE

SpaceEngine does **not** solve scale with one clever trick. It solves it by refusing to
let any single number span the whole range. Four separate separations:

1. **Position is not a float.** World coordinates are **128-bit fixed point**. **[SE]**
2. **Rendering never sees a world coordinate.** Everything is made camera-relative
   before it reaches a matrix. **[FIELD]**
3. **Depth is logarithmic**, not reciprocal. **[FIELD]**
4. **Representation is chosen by ANGULAR SIZE**, and the representations are
   **switched, never overlaid**. **[SE + FIELD]**

Point 4 is the one that bites us hardest. See §4.

---

## 1. COORDINATES — 128-bit FIXED point, not double float

> "128-bit fixed point numbers" — used as the universe coordinate system,
> explicitly to eliminate camera jittering during movement. **[SE]**
> (`spaceengine.org/news/blog120306`, procedural galaxies devblog)

The choice of **fixed** point over **double float** is the interesting part, and it is
deliberate:

- A float's precision is **relative** — it halves every power of two away from the
  origin. Good for ratios, terrible for a world position.
- A fixed-point integer's precision is **absolute and uniform everywhere**. One LSB is
  the same physical distance at the galactic rim as at the origin.

With 128 bits you can hold sub-millimetre resolution across a galaxy in one number, with
no "precision cliff" anywhere in the range. **[FIELD]**

Precision limits that motivate this, quoted directly: **[FIELD]**
- "A 32-bit float has a maximum of 6 significant digits of accuracy, and a 64-bit double
  has a maximum of 15."
- float breaks down "around 1,000 km" at millimetre precision; "a 32-bit float isn't
  sufficient to accurately model one Earth-sized planet."
  (O'Neil, *A Real-Time Procedural Universe, Part Three: Matters of Scale*)

**The architectural rule: the position TYPE is decoupled from the rendering TYPE.** SE
also lists "Ported to 64-bit" in its 0.990 release notes **[SE]** — that is the
application, separate from the coordinate system.

---

## 2. CAMERA-RELATIVE RENDERING — the free half of the fix

The standard formulation, and it costs almost nothing: **[FIELD]**

> "Start out by pretending the camera is at the origin when you calculate your view
> matrix... Then calculate each model matrix relative to the camera's actual position by
> subtracting the camera's position from the model's position."

Consequence, and this is the point people miss:

> "Only object positions require 64-bit doubles. **Everything else can still be
> represented with floats, and almost every math operation you perform will still be a
> single-precision operation.**"

So you pay double/fixed-point cost on **one subtraction per object**, and the entire
shader pipeline stays float. The big numbers are cancelled *before* they enter a matrix,
so you never form the catastrophic `bigNumber - bigNumber` inside a float.

---

## 3. DEPTH — logarithmic z, one line in the vertex shader

Outerra's formulation, verbatim: **[FIELD]**

```
DirectX (0..1):  z = log(C*w + 1) / log(C*Far + 1) * w
OpenGL (-1..1):  z = (2*log(C*w + 1) / log(C*Far + 1) - 1) * w
```

`w` = view-space depth after projection, `C` = constant setting near-camera resolution.
Buys ~10,000 km of range with **no near-plane clipping** on a 24-bit depth buffer.

⚠️ **Caveat, stated by Outerra:** "The depth is interpolated linearly and not
logarithmically" → artifacts on large triangles near the camera unless you either
tessellate or move the calculation to the fragment shader (which disables fast-Z; they
measured the cost as "negligible").

**[OURS]** Probably not our bottleneck — our particles never write depth at all (that
is exactly why the 2026-07-24 full-frame darkening pass was depth-blind). Logged for
completeness; do not spend time here.

An alternative from the same literature, for the far field: **exponentially compress
distance** so everything beyond `FCP/2` maps into `[FCP/2, FCP]`, "and to make the size
of the body appear accurate, scale the size by the same factor you scale the distance."
**[FIELD]** That is a real, honest way to draw the unreachably-far without breaking the
frustum — the size scales with the distance so the angular size is preserved.

---

## 4. ⭐ REPRESENTATION SWAPPING BY ANGULAR SIZE — the part that is our problem

This is what §3.2b was really asking for.

### 4.1 The switch metric is ANGULAR, not distance
> "Screen-size based LOD metrics align switches with what the player can perceive, while
> distance alone ignores field of view and device resolution." **[FIELD]**

O'Neil's concrete threshold for the impostor→mesh swap: **[FIELD]**
> "Switch to normal rendering when a planet takes up **90 degrees or more** of the field
> of view."

And the impostor's own resolution is chosen by distance: **[FIELD]**
> "I choose impostor resolutions from **512x512 all the way down to 8x8** based on the
> planet's distance to the camera."

### 4.2 SE switches representations aggressively — and exposes it
- **"More aggressive LOD switching for galaxy and nebula sprite models to save
  performance"** (0.990 release notes) **[SE]**
- **"Smooth appearance of generated stars and galaxies while moving at large speed"**
  **[SE]** — the fade between representations is itself an engineered feature.
- **Star Points Style** is a user-facing dropdown with four values: **Points, Sprites,
  Motion blur, Motion and rotation blur.** Same dropdown exists for planet points. **[SE]**
- **"Link Points Scale with Window Resolution"** — point sizes scale to keep constant
  proportion relative to a **1080 px reference height**. **[SE]**

### 4.3 ⭐ SE runs sprites AND volumetrics — but at different LOD, and cheaper
- Galaxies/nebulae are **sprite models** built from a **texture atlas of 8 tiles: 2
  emission (glow) + 6 absorption (dust)**. **[SE]**
- Nebulae are ALSO **"procedural volumetric raymarched"**, with **"Hi-quality (bicubic)
  upsampling for rendering of volumetrics (galaxies, nebulae, comet tails, aurora)"**
  and a user setting for **"Volumetric objects resolution"**. **[SE]**

So the volumetric is deliberately rendered at **reduced resolution and bicubically
upsampled**, and it is a **different LOD tier**, not a layer added on top of the sprites.

**[OURS]** That is precisely §1.3 of the handoff: our lens sprites and the bit19 march
were **additively overlaid** — two pictures of one disk ~100× apart in resolution — and
that is his *"it doesn't connect to the rings"*. **SpaceEngine's answer to the same
problem is: pick one per LOD tier and cross-fade; never sum them.** Turning bit19 off
was, by this reading, the architecturally correct move and not just a taste call.

### 4.4 Transparency blending is the expensive thing, and they bake it out
SE measured their own galaxy rendering: **[SE]**
> "When skybox is disabled, my PC gives only **17 FPS**, while when skybox is enabled,
> FPS is over **125**."

Their fix: render the far field **once into a skybox** and reuse it, at **`TRSkyResolution
0.5`** — full-HD would be `1920*1920*6 = 22,118,400` pixels ≈ **337.5 MB VRAM**; at half
resolution it costs **27 MB**.

**[OURS]** Direct relevance to the standing "30 fps playing / 120 paused" suspect: SE's
own measurement says the cost of a million overlapping transparent sprites is **fill and
blending**, and their solution was not to shrink the sprites but to **stop re-rendering
the static far field every frame.** Note this does NOT contradict our finding that
exposure is not an fps lever — different mechanism.

---

## 5. ⭐ BRIGHTNESS AND COLOUR — SE treats "hot star goes white" as a DIAL

This is the unexpected payoff. Our §3.2 ("why is every star the same colour") and §3.3
(the 27,000:1 clip) are, in SpaceEngine, **two named user settings and a colorimetry
choice.**

### 5.1 They have three brightness REGIMES, switchable **[SE]**
(`spaceengine.org/news/blog170415`)
1. **Auto** — "realistic rendering mode with a real (physically based) brightness of all
   objects", with automatic camera adaptation "analyzing screen brightness in the central
   area."
2. **Manual** — same physically-based rendering, auto-adaptation **off**, you set exposure.
3. **HDR (legacy)** — "the engine simply renders each kind of object with its **own
   brightness multiplier (not physically based)**."

**[INFERENCE]** Mode 3 is worth noting: SE's own author kept a **non-physical per-object
brightness multiplier** mode around, because physically-correct relative brightness alone
did not give the picture he wanted. That is a licence for a "star brightness" dial that
is not `M^3.5`.

### 5.2 Approach behaviour is explicitly compensated **[SE]**
> "In the HDR mode star surface automatically become darker on approach to reveal details."

The engine *fights* saturation as a star fills the screen, rather than letting the
tonemapper deal with it.

### 5.3 ⭐ "Illumination Saturation" — a dial for how much colour survives brightness **[SE]**
> "Controls color saturation of incandescent light sources like stars (0–2, default 1). An
> **'Auto' checkbox enables human-eye perception modeling where light colors near the white
> point appear white.**"

SpaceEngine has a **first-class dial for exactly the symptom he is complaining about.**
Colour washing toward white at high brightness is modelled, named, and adjustable — with a
physiologically-motivated "Auto" and a manual override that lets you push saturation back
up to 2×.

### 5.4 ⭐ "Black Body Coloration" — the white point is a CHOICE **[SE]**
> Six options: **SDTV, HDTV/sRGB, UHDTV, CIE RGB, Adobe RGB, Display P3** — "each with
> different white points and correlated color temperatures."

SE converts thermal radiation → RGB through **real colorimetry with a selectable white
point and primaries**. The same Kelvin lands on a different hue depending on that choice.

### 5.5 Bloom desaturates — and they had to add a pass to claw it back **[SE]**
> saturation and vibrance adjustments were added to "fix losing of color saturation caused
> by the new bloom effect."

Also: SE's **Saturation** slider "implements a **vibrance** filter rather than linear
saturation" (0–2, default 1) — vibrance protects already-saturated pixels and lifts the
weak ones, which is the correct tool when your problem is *"most things are white, a few
are strongly coloured."* **[SE]**

⚠️ **[OURS]** Our postfx is **RULED OUT** — he ran the N/B isolation keys and it did not
help. §5.5 is recorded as background only. **Do not re-suggest that test.**

### 5.6 The dials he is asking for already have precedent, one-to-one **[SE]**
| Handoff §3.1 wants | SpaceEngine ships |
|---|---|
| spike weight / falloff | **Diffraction Spikes**: toggle + style + **Size (0.1–10, log)** + **Brightness (0.1–10, log)** |
| luminance clip / soft-knee | **Tone mapping**: 5 selectable curves — Bruneton, Exposure, Filmic Hejl, Filmic, Reinhard |
| Kelvin law | **Black Body Coloration**: 6 colorimetry targets |
| bleach window | **Illumination Saturation** (0–2) + Auto; **Bloom** (0–1) |
| star size law | **Star Points Style** + **Link Points Scale with Window Resolution** |
| — | **Glare Brightness (0.1–10, logarithmic)** |

**Every one of these ranges is logarithmic.** For a quantity spanning 27,000:1 that is the
only sane dial geometry — a linear slider spends 99% of its travel in the top decade.

---

## 6. WHAT THIS RESEARCH DOES **NOT** TELL US

Being explicit, because the temptation is to over-read:

- **No source gives SE's actual formulas.** The HDR devblog is a progress post; the only
  number in it is an FPS figure. Everything colorimetric above is from the **settings
  descriptions**, i.e. what the dial does, not how it is computed.
- **No confirmed detail on SE's star point→sprite→sphere transition thresholds.** Searched;
  the public sources do not state them. O'Neil's 90°-FOV planet rule is **[FIELD]**, not SE.
- **The 128-bit fixed point claim comes from a 2012 devblog.** It may have changed by 0.990
  ("Ported to 64-bit" is listed separately and refers to the build). Treat the *principle*
  as solid, the *current implementation detail* as unverified.
- Galaxy rendering was, at the time of that post, **"not 3D models of galaxies"** — "all
  galaxies are using standard models", with procedural 3D models listed as future work.

---

## 7. WHAT ACTUALLY TRANSFERS TO US, RANKED

**1. Log-scale dials, every one of them (§3.1).** Cheap, and it is what SE does for every
brightness-like quantity. Build the dials with `0.1–10` logarithmic travel, not linear.

**2. Switch representations, never sum them (§1.3).** Already half-done by defaulting bit19
off. The architecture to aim at is: one representation per angular-size tier, cross-faded.

**3. Separate "physically based" from "looks right" as an explicit MODE, not a fudge.** SE
kept all three regimes. Our `M^3.5` + `min(...,1000)` is currently a *hidden* mode-3 fudge
pretending to be physics. Making it an honest, labelled, dialable curve is the fix.

**4. The white point / saturation-vs-brightness relationship is a CHOICE with a dial.** SE
proves it deserves its own control rather than being an emergent accident of the pipeline.

**5. Camera-relative + fixed-point positions.** Correct and standard, but **[OURS]** we do
not currently have evidence this is hurting us — our sim lives in `±64` sim units, not
across 40 decades. **File it; do not act on it without a measured precision failure.**

---

## 8. ⭐ ONE CODE FINDING FROM TODAY, AND A CORRECTION

While grounding §5 against our own code I checked two things:

**[OURS] The scene render targets are `MTLPixelFormatRGBA16Float` everywhere**
(`renderer.mm:627, 656, 683, 709, 841, 871, 886, 901`, window layer `window.mm:288`).
Half-float maxes out around 65504 and `starLum` clips at 1000. **So there is no 8-bit
framebuffer clamp eating the hue before postfx.** That candidate is dead — which matters,
because it was the obvious explanation for "postfx bypass didn't help" and it is wrong.

**[OURS] `blackbodyRGB` (`render.metal:146`) is EXONERATED.** I initially misread the
branch and thought it pinned R and B to 1.0 for hot stars. It does not. Evaluating the
literal code:

| Kelvin | RGB out | reads as |
|---|---|---|
| 2,944 K (0.3 M☉) | (1.00, 0.69, 0.42) | orange |
| 6,600 K | (1.00, 0.99, 1.00) | white |
| 14,140 K (5 M☉) | (0.72, 0.81, 1.00) | blue-white |
| 40,000 K (clamp) | (0.60, 0.73, 1.00) | blue |

The function produces a correct orange→white→blue spread. **The hue is not being destroyed
by the colour function.**

**[INFERENCE] — the surviving candidate for "too many blueish stars", and it makes §3.2 and
§3.3 the SAME bug:** `starLum = M^3.5` means the *visible* population is almost entirely
high-mass, and high mass → high Kelvin → the blue end of that table. Dwarfs sit at
`Lstar = 0.037` and are invisible. So the field could be rendering a perfectly correct
colour spread over a **population that is selection-biased blue**. This also explains why
three luminance changes did not move the colour: the clip at 1000 kept roughly the same set
of stars visible each time.

**This is a hypothesis, not a finding.** The measurement that settles it, before any code
change: **histogram `kelvinU` weighted by on-screen contribution** — i.e. what Kelvin does
the light actually come from, not what Kelvin exists. If the luminance-weighted histogram
is a blue spike while the unweighted one is broad, §3.2 is a brightness-law problem and the
dials in §3.1 fix both at once.

---

## SOURCES

- [Procedural galaxies — SpaceEngine devblog](https://spaceengine.org/news/blog120306) — 128-bit fixed point
- [Galaxy rendering update — SpaceEngine devblog](https://spaceengine.org/news/blog121021) — sprite atlas, skybox FPS numbers
- [HDR rendering — SpaceEngine devblog](https://spaceengine.org/news/blog170312)
- [HDR rendering 2 — SpaceEngine devblog](https://spaceengine.org/news/blog170415) — the three brightness regimes
- [SpaceEngine 0.990 release notes](https://spaceengine.org/news/blog190611) — LOD, volumetrics, autoexposure
- [All Visual Style Settings Explained (Steam guide)](https://steamcommunity.com/sharedfiles/filedetails/?id=2025917480) — the full dial list with ranges
- [SpaceEngine user manual — graphics settings](https://spaceengine.org/manual/user-manual/)
- [Creating a star — SpaceEngine manual](https://spaceengine.org/manual/making-addons/creating-a-star/)
- [A Real-Time Procedural Universe, Part Three: Matters of Scale — Sean O'Neil](https://www.gamedeveloper.com/programming/a-real-time-procedural-universe-part-three-matters-of-scale)
- [Outerra: Logarithmic Depth Buffer](https://outerra.blogspot.com/2009/08/logarithmic-z-buffer.html)
- [Floating origin — Wikipedia](https://en.wikipedia.org/wiki/Floating_origin)
- [Inner Worlds: Vladimir Romanyuk interview](https://medium.com/inner-worlds/inner-worlds-i-vladimir-romanyuk-the-space-engineer-276fccfc36dc)
