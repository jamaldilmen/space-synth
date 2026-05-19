# SPACE Synth — Black-Hole Architecture Assessment

**Purpose:** External research document. We're trying to render a
real-time Gargantua-style black hole driven by 5M particles + audio synth,
and the current implementation has a fundamental architectural problem:
**there is no actual black hole** — there are four disconnected systems
each pretending to be one, none agreeing with the others.

This document describes what we have, what's broken, what the visual
target is, and where external advice would unblock us.

**Snapshot:** 2026-05-19, branch `v1-stable`, commit base `ba85dcc` +
uncommitted physics rebuild (soft gravity, ring spawn, world-space lens
attempt, light-streak fragment shader).

---

## 1. The visual target

NASA's Gargantua / Interstellar visualization
([NASA SVS, 2019](https://svs.gsfc.nasa.gov/14146/)). The defining
features we're trying to reproduce:

1. **Solid dark void at center** — the event-horizon shadow. A
   physically real object with apparent angular size on screen that
   changes with camera distance.
2. **Thin orange accretion disk** (in the orbital plane) wrapping the
   void.
3. **Gravitational lensing** that bends the BACK of the disk visibly
   OVER the top of the void and UNDER the bottom — the iconic horseshoe.
4. **Photon ring** just outside the horizon (light orbiting before
   escape).
5. **Doppler asymmetry** — the side moving toward the camera brighter.

The lensing is the load-bearing feature. Without it, the disk just
renders as a flat ring. The lensing is what bends the back-of-disk light
around the BH so it appears above + below the void from the observer's
POV.

---

## 2. What we currently have — four disconnected "BHs"

There is no single canonical "BH object" in this codebase. Instead,
**four separate systems** each implement a piece of the BH and none
share state or scale with each other.

### 2.1. Particle-physics gravity center

**Location:** `src/render/particles.metal`, line ~196
**What it is:** A force in the compute shader:

```metal
// at every particle, every frame during silence:
float G = 1.0;
float r0 = 0.5;
float gMag = G / (rLen * rLen + r0 * r0);   // soft-core 1/(r²+r0²)
shiftV -= dir * gMag * dt;                   // pull toward origin
```

- **Has no body, no radius, no extent.** Just a force field centered on
  world origin (0, 0, 0).
- Particles inside the soft-core radius `r0 = 0.5` feel finite force; no
  singularity.
- Particles initialized with tangential velocity `v = sqrt(G·r/(r²+r0²))`
  so they orbit in xy plane → emergent disk.

### 2.2. `RS_CULL` cull-radius in the particle vertex shader

**Location:** `src/render/render.metal`, line ~261
**What it is:** A render-side cull that makes particles invisible
inside a hardcoded world-space radius:

```metal
float RS_CULL = 0.80f;
if (length(originalWorldPos) < RS_CULL) {
    out.position = float4(0, 0, -2, 1);   // behind clip plane → invisible
    out.pointSize = 0;
}
```

- This is the "dark center" you actually see in the rendered output —
  it's just absence of particles, not a body.
- Has no relationship to the gravity center's `r0`, no relationship to
  the raytracer's horizon, no relationship to camera distance.
- Pure visual trick.

### 2.3. Screen-space lensing displacement

**Location:** `src/render/render.metal`, particle vertex shader after
projection
**What it is:** Per-particle 2D displacement in NDC space:

```metal
// for each particle's projected position:
float4 bhClip = cam.viewProjection * float4(0.0, 0.0, 0.0, 1.0);
float2 ndcP  = out.position.xy / out.position.w;
float2 ndcBH = bhClip.xy / bhClip.w;
float2 dvec  = ndcP - ndcBH;
float impact = max(length(dvec), 0.04f);     // NDC distance from projected BH
float deflection = min(0.08f / impact, 0.5f);// magnitude ~1/impact
ndcP += (dvec / impact) * deflection;        // push away from BH center in NDC
out.position.xy = ndcP * out.position.w;
```

- Pure 2D NDC operation. Pushes every particle radially from the
  projected BH center.
- Produces a **coherent circular distortion pattern** on screen
  regardless of disk geometry — the "2D locked shape" that Jamal calls
  out.
- Magnitude based on NDC distance, not world geometry → camera rotation
  changes which particles end up at low NDC distance, but the pattern
  always looks the same: a circular ring of distortion.
- Recent attempts to drive magnitude by world-space impact parameter
  while keeping NDC direction also produced a coherent pattern, just
  scaled differently.

### 2.4. Raytraced Kerr geodesic event horizon

**Location:** `src/render/blackhole.metal`, `fragment_black_hole`
**What it is:** A full Kerr null-geodesic raytracer rendered as a
fullscreen triangle:

```
For each screen pixel:
  Convert pixel → ray (camera+direction)
  Scale into "ray space": rayOrigin = cameraPos / (cameraDist/5)
  Set up Kerr metric (M = 0.40, a = 0.99·M, spin parameter)
  RK4-integrate the null geodesic equations
  At each step:
    if r ≤ horizon · 1.01:  return pure BLACK (event horizon shadow)
    sample particle density at bent ray position (via spatial hash)
    accumulate doppler-boosted blackbody color
  if escape: sample procedural starfield at warped exit direction
```

- This is the most physically real component. It does actual Kerr
  geodesic light bending.
- **But:** because of the `cameraDist/5` scaling in ray-space, the
  apparent horizon size on screen is **approximately constant
  regardless of camera distance**. The "BH" never gets bigger as you
  zoom in, never gets smaller as you zoom out.
- The horizon radius `r_horizon = M + sqrt(M² − a²) ≈ 0.46` is in
  ray-space units, completely decoupled from `RS_CULL = 0.80` (world
  units) and from the gravity center's soft core `r0 = 0.5`.
- It draws BEFORE the particle pass (it's the background), then particles
  draw over it via additive blending. With 5M bright particles covering
  the field, the small dark void from the raytracer is largely **bleached
  away** by the particles drawn on top.

### 2.5. Particle "light streak" fragment shader

Bonus 5th system: each particle renders as an emission Gaussian
stretched along its screen-space velocity direction. Photons-as-streaks
approximation to mimic raytraced light strands. Has its own per-particle
brightness/alpha, additive blending. Independent of the other four
systems.

---

## 3. Why this can't produce the Gargantua look

Three independent failure modes, any one of which would block:

### 3.1. The void doesn't scale with the camera

A real black hole has an apparent angular size on screen that scales
with `1/cameraDistance`. Ours doesn't:

- **`RS_CULL`** is a fixed 0.80 world units. As camera zooms out, the
  cull radius gets relatively smaller on screen.
- **Raytracer horizon** is scaled by `cameraDist/5`, which means the
  apparent angular size on screen is roughly constant regardless of
  camera distance (the very thing that hides physical scale).
- Neither matches the natural `1/distance` falloff of a real spherical
  body.

### 3.2. The lensing is screen-space, not geometric

Real Gargantua lensing bends light geodesically through the Kerr metric.
The deflection of a particular source depends on its 3D position relative
to the BH and the observer. Different sources at different 3D positions
get bent by different amounts and in different visible directions.

Our screen-space lensing is a 2D NDC trick:

- Every particle gets pushed radially from the same projected screen
  point with the same 1/distance falloff.
- Result: a coherent CIRCULAR PATTERN of distortion on screen, always
  centered on the projected BH origin.
- Does not produce the iconic horseshoe (back-of-disk arched over and
  under the void) because the deflection direction in NDC is always
  radially outward from one point — never the disk-wrap geometry.

Attempts to drive magnitude from 3D impact parameter (perpendicular
distance from camera→particle ray to BH origin) while keeping NDC
direction did not produce the horseshoe either, just modulated the
intensity of the same coherent circular pattern.

### 3.3. The disk and the void don't share coordinates

The particle disk forms at world radius ~1.0 (from Kepler orbital
velocity at the soft-core gravity). `RS_CULL = 0.80`. Raytracer horizon
is at 0.46 in ray-space. None of these scales agree with each other.
The void you see is whichever of these is largest in projected NDC at
the current camera position. There's no single physical BH body at a
single physical radius that everything respects.

---

## 4. What "physically correct" would look like

A single BH body, defined once:

```
BH = {
  position: float3 (world space, default origin),
  schwarzschild_radius: float (world units, e.g. 0.5),
  spin: float (Kerr a, dimensionless 0..1),
}
```

All four systems would respect this:

1. **Gravity** in particle physics: `G·M / (r² + softening²)` with M
   derived from `schwarzschild_radius`.
2. **Cull**: any particle whose world position crosses the horizon
   becomes invisible AND is consumed (removed/teleported, simulating
   accretion).
3. **Lensing**: per-particle geodesic ray bend computed in the SAME
   world-space units as the BH body. Apparent screen displacement is
   the PROJECTION of this 3D bend through the camera, not an NDC trick.
4. **Renderer**: dark void rendered at the BH's actual angular size on
   screen — the projected silhouette of a sphere of radius
   `schwarzschild_radius` at distance `length(cameraPos − BH.position)`.
   No `cameraDist/5` ray-space hack.

Zoom in → BH gets visibly bigger. Zoom out → smaller. Lensing
intensifies near the visible silhouette as it would in real GR. The
disk wraps around an actual physical sphere.

---

## 5. Specific questions for external research

In order of how much they would unblock progress:

### Q1. Real-time Gargantua lensing for sparse particle sources

The state-of-the-art for this look is the Interstellar VFX pipeline
([Double Negative, James et al., 2015](https://arxiv.org/abs/1502.03808),
a copy of which is at `/Users/airy/GARGANTY/1502.03808v2.pdf`). Their
approach: ray map (per-pixel) precomputed by integrating null geodesics
through Kerr, then sample disk texture through that map at runtime.

**Question:** Is there a known technique to apply this kind of geodesic
deflection to **discrete particle sprites** (not a continuous texture)
in real time? Per-particle ray tracing through Kerr is too expensive
for 5M particles at 60 fps. Is there a precomputed lensing LUT approach
that maps `(world_position, camera_position) → projected_screen_position`
that we could read per-particle in a vertex shader?

### Q2. Visible angular size of BH from a moving camera

What's the correct projection of a Schwarzschild silhouette to screen
for an arbitrary camera? Per
[Bardeen 1973](https://ui.adsabs.harvard.edu/abs/1973blho.conf..215B),
the apparent shadow radius is `b_crit = 3·sqrt(3)·M ≈ 5.2·M`, NOT
`R_horizon ≈ 2·M`. That's the photon-capture cross-section — what's
actually visible as the "dark disc" is the photon sphere shadow, not
the geometric horizon.

**Question:** Is the Bardeen `5.2·M` shadow what we should be projecting
as a sphere at the BH position, scaled by `1/camera_distance`? Should
we just draw a flat disc of that angular radius and let the lensing
math handle the wrap, instead of running a geodesic raytracer?

### Q3. Disconnected vs unified coordinate systems

We have particle physics in normalized world units `[-1, 1]`, the
raytracer in its own ray-space (`cameraDist/5` rescale), and the
lensing in NDC. Should we collapse everything into one consistent
world-space (with BH radius `M ≈ 0.5` world units, say) and ensure all
three systems compute relative to the same body? Are there published
real-time BH renderers that do this cleanly?

### Q4. Particle volume rendering with light accumulation

Gargantua's accretion disk in the Interstellar/NASA renders is a
continuous emission volume — light accumulates along bent ray paths. Our
disk is 5M discrete point sprites with additive blending. Each sprite is
a "light sample" but they read as discrete dots, not the continuous
flowing light bands of a raytraced volume.

**Question:** Is there a hybrid where particles act as sample positions
for a continuous emission field, and the rendering integrates emission
along (bent) rays through this field? That would turn discrete particles
into continuous light streaks naturally — closer to real photon
accumulation.

---

## 6. Reference: what we've already tried

- **Screen-space lens, magnitude = 1/NDC-distance** (ba85dcc) — produced
  a clear visible bend but coherent 2D circular distortion pattern, not
  Gargantua geometry. Jamal celebrated it as "FUCKING BREAKTHROUGH" at
  the time but later identified the 2D-pattern problem.
- **Depth-gated screen-space lens** — killed visibility in face-on views
  (most disk particles have ~same depth as BH).
- **World-space lens, displacement in world units** — displacements were
  too small at default camera distance (~100 world units) to project to
  visible NDC shift; cap of 0.20 world ≈ 0.002 NDC at default cam.
- **Hybrid: world-space magnitude × NDC direction** — same coherent 2D
  pattern as the original, just modulated.
- **Particle disk forming via Kepler orbits + soft gravity** — works,
  produces a real flat disk in xy plane via emergent physics. Verified
  via spatial-hash probe statistics.
- **`RS_CULL` bumped to 0.80** — makes the dark void visibly larger
  but no scale change with camera.
- **Raytracer enabled with internal Kerr geodesics** — runs at ~5ms,
  produces a dark void + starfield, but the void's apparent screen size
  doesn't change with zoom because of the ray-space `cameraDist/5`
  rescale, and gets bleached by the 5M particle sprites drawn on top.

---

## 7. Reference material on disk

- `/Users/airy/GARGANTY/1502.03808v2.pdf` — Double Negative paper,
  Interstellar's actual approach (precomputed null-geodesic ray maps
  through Kerr-Schild metric)
- `/Users/airy/GARGANTY/Kerr-Metrik_*.md` — Algebraic derivations for
  Kerr metric, prepared for shader integration
- `/Users/airy/GARGANTY/Sources/Shaders.metal` — Working real-time
  Kerr raytracer in Metal (323 lines, no particles, pure ray-bent
  procedural disk via FBM noise)
- `/Users/airy/SPACE SYNTH/SPACE-SYNTH-TUBE/BH_MATH.md` — Earlier
  math-only writeup of all the current rendering paths

---

## 8. The honest bottom line

We don't have a black hole. We have four shader effects that
collectively *approximate* the appearance of one when the camera is
positioned just right. Until we have a single physical BH body with a
real coordinate-consistent radius, the lensing can't bend the right
things by the right amounts, and the void can't be the right size at
the right place. That's the architecture problem to solve before any
more shader-tweaking can help.
