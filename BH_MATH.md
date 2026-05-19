# SPACE Synth — Black-Hole Math Report

Complete mathematical breakdown of every piece of code that contributes to the
rest-state "black hole" visual, across the entire codebase.

**Snapshot date:** 2026-05-18
**Generated after:** disk-physics rescue (central pull off, EH freeze off,
stable orbital angle, wider void), grid bump (32³ → 64³), universal lensing
(depth gate removed), plasma fragment shader.

---

## 1. Particle spawn — `src/core/particles.cpp:7-30`

N = 5,000,000 (default). Each particle:

```
x, y, z  ~  N(μ=0, σ=1.2)         independent per axis
vx = vy = vz = 0
```

Then in `packForGPU`:

```
r       = √(x² + y² + z²)
invMass = (r > 3.0)  ?  0  :  1
```

Walls (`invMass = 0`) are culled in the vertex shader and never written-back.
With σ=1.2 and threshold 3.0, ~99% live.

---

## 2. Per-particle silence physics — `src/render/particles.metal:154-244`

Gated on `envPhase < 0.5`.

**Constants:**

```
RS                = 0.40
dt               ≈ 0.0083
diskThickness     = 0.15
orbitalAngle_id   = fract(id · 0.31415926) · 2π       fixed per particle
orbitalRadius_id  = RS · 2.5 + fract(id · 0.123456) · 0.8
                  = 1.0 + [0, 0.8]   →   r ∈ [1.0, 1.8]
diskDir_id        = (cos orbitalAngle, sin orbitalAngle)
z_target_id       = (fract(id · 1.618) − 0.5) · diskThickness   ∈ [−0.075, 0.075]
```

### Forces at rest

**(a) Central pull — DISABLED.**

Was `2 / (rLen³ + ε)`. 1/r³ singular near origin → vacuumed particles past disk
physics → 80% of live particles ended up frozen inside RS, invisible.

**(b) Disk confinement** (the only force shaping the disk now), fires
`rLen > RS`:

```
diskTarget = (diskDir_id.x · orbitalRadius_id,
              diskDir_id.y · orbitalRadius_id,
              z_target_id)
toDisk     = diskTarget − p
diskForce  = (toDisk / |toDisk|) · 80 · 1 / (|toDisk| + 0.1)
shiftV    += diskForce · dt
```

**(c) Kerr frame-dragging**, fires `rXY > RS·1.05` AND `|z| < diskThickness·1.5`:

```
rXY        = √(px² + py²)
angularVel = 15 / √(rXY + 0.1)
tangent    = (−py, px) / (rXY + 0.001)
shiftVx   += tangent.x · angularVel · dt
shiftVy   += tangent.y · angularVel · dt
shiftVz   −= pz · 0.5 · angularVel / (diskThickness + 0.1) · dt
```

**(d) Hawking noise**, fires `rLen < RS · 4 = 1.6`:

```
shiftV += noise(id, frame) · 0.8 · dt    (x, y)
shiftV += noise(id, frame) · 0.4 · dt    (z)
currentTemp = lerp(currentTemp, 0.3, 0.05)
```

**(e) Event-horizon freeze — DISABLED.**

Was a trapdoor: zeroed both vel and shift forces when `rLen < RS`. Disk
confinement was gated `if (rLen > RS)` so it couldn't rescue trapped
particles. Particles drifted into RS, accumulated, never came back, decayed
the visible field away.

**(f) Photosphere temperature**, when `distFromDisk < diskThickness`:

```
currentTemp = lerp(currentTemp, 5/(rXY + 0.2), 0.1·dt)
```

---

## 3. Integration & write-back — `particles.metal:786-876`

Every frame, regardless of envPhase:

```
dynamicFric  = pow(0.06, dt)              ≈ 0.954
finalV       = vpx · dynamicFric  +  shiftV          // damped + accumulated
|finalV|    ≤ u.speedCap
nextPos      = pos + finalV
```

Phase-19 elastic shell and ENVELOPE→RADIUS coupling both wrapped in
`if (false)`.

Write-back (only live):

```
p.prevW = (px, py, pz, currentTemp)
p.posW  = (nextPos, mass)
p.velW  = (finalV, packed(phase, bandID))
```

---

## 4. Spatial hash — `renderer.mm:649-775`, `spatial_hash.metal`

Rebuilt every frame at rest or release.

```
kGridSize    = 64                          (up from 32)
cellSize     = 2.0 / 64 = 0.03125          (world units per side)
kTotalCells  = 64³ = 262,144
MAX_PER_CELL = 128                         (up from 32)
```

For each particle: `cellID = floor((p+1)/cellSize)`, atomic increment of
`cellCounts[cellID]` clipped at 128. 4-phase Blelloch prefix sum → `cellStarts`.
Scatter → `sortedParticlesBuffer`.

Average occupancy on 5M live: **~19/cell**. Disk-peak cells well under 128 cap.

---

## 5. Vertex shader — position + lensing — `src/render/render.metal:71-201`

```
worldPos = p · plateRadius                 // plateRadius = 1.0
clipPos  = cam.viewProjection · (worldPos, 1)
```

### Point size

```
heatSizeBoost = 1 + clamp(temp, 0, 1) · 1.5         ∈ [1, 2.5]
rawSize       = particleSize · heatSizeBoost · (800 / dist)
pointSize     = clamp(rawSize, 1, 64)               // pixels
```

### Lensing — ADSR-gated, UNIVERSAL (no depth gate)

```
lensScale(envPhase) =
  1.0                              if envPhase < 0.5
  lerp(1, 0, envPhase)             if 0.5 ≤ envPhase < 1.5
  0                                if 1.5 ≤ envPhase < 2.5
  lerp(0, 0.7, envPhase − 2.5)     if 2.5 ≤ envPhase < 3.5
  lerp(0.7, 1, envPhase − 3.5)     if envPhase ≥ 3.5
```

When `lensScale > 0.001`:

```
bhClip       = cam.viewProjection · (0, 0, 0, 1)
ndcP         = clipPos.xy / clipPos.w
ndcBH        = bhClip.xy / bhClip.w
dvec         = ndcP − ndcBH
impact       = max(|dvec|, 0.04)
deflection   = min(0.10 / impact, 0.45) · lensScale     // gain 0.10, cap 0.45
ndcP        += (dvec / impact) · deflection             // away from BH
clipPos.xy   = ndcP · clipPos.w
```

Universal — every particle gets bent in screen space proportional to
1/impact-from-projected-BH-center. The depth gate from commit `2af470c` was
reverted because it killed visible lensing in face-on ortho views (every
disk particle at ≈ BH depth → `behindFactor ≈ 0`).

### Color (blackbody, when not phase-viz)

```
T_norm    = clamp(temp / 5, 0, 1)
bbColor   = piecewise mix:
              red(0.6, 0.15, 0.02)      → orange(1, 0.4, 0.05)
            → warm-white(1, 0.75, 0.4)  → near-white(1, 0.95, 0.9)
            → blue-white(0.8, 0.85, 1.0)
bandColor = kBandColors[bandID]                  // 6-color frequency palette
out.color = mix(bbColor, bandColor, bandID > 0 ? 0.4 : 0)
out.color += speed · (0.3, 0.2, 0.1)             // doppler boost
```

### Event-horizon cull (only after lensing applied)

`RS_CULL = 0.40`:

```
if (|originalWorldPos| < 0.40)  pointSize = 0    // invisible inside RS
```

---

## 6. Fragment shader — plasma rendering — `src/render/render.metal:206-237`

For each sprite fragment, `pc = (pointCoord − 0.5) · 2` ∈ [−1, 1]²:

```
r²        = pc · pc
core      = exp(−r² · 9)             // tight bright spot
halo      = exp(−r² · 5) · 0.55      // tightened glow (was k=1.8 × 0.35)
intensity = core + halo
finalColor = in.color · intensity · in.luminance
baseAlpha  = 0.18 + clamp(in.luminance − 1, 0, 2) · 0.10
fadeAmount = smoothstep(0.1, 6, dist)
alpha      = baseAlpha · fadeAmount
output     = (finalColor · alpha, alpha)
```

---

## 7. Pipeline blend state — `renderer.mm:224-230`

```
sourceRGB    = One                       // additive
destRGB      = One
sourceAlpha  = One
destAlpha    = OneMinusSourceAlpha
target       = RGBA16Float (HDR)
```

Each pixel = sum of all overlapping sprite halos. Density → plasma brightness
automatically.

---

## 8. BH raytracer — `src/render/blackhole.metal:340-498`

**Outer gate** (`renderer.mm:888-891`):

```
needRaytracer = (envPhase < 0.5 || envPhase > 2.5)
```

Runs at silence, sustain, release. Saves ~51B trig ops/frame during
attack/decay.

**Inner gate** (shader-side): same 5-phase ADSR opacity curve as the lensing's
`lensScale`.

Per pixel when active:

```
ray = (cameraPos / camDistScale) + t · normalize(forward + uv · 0.6)
RK4-integrate Kerr null geodesic (M = 0.40, a = 0.99·M)
for each step:
  if state.r ≤ r_horizon · 1.01:   return (0, 0, 0, opacity)
  sample cellStarts/sortedParticles at bent ray position
  if density > 0:
    color += doppler-boosted blackbody · density
  if state.r > 2: bail
escape → procedural starfield at warped exit direction
```

Removed in commit `2af470c`:

- Analytic 2D orange ring overlay (`float3(1, 0.5, 0.1)` z=0 plane intersection)
- Hardcoded photon-sphere glow ring at `r_horizon · 1.5`

---

## Net recipe for the visible "BH" at rest

1. Particles orbit a thin ring at **r ∈ [1.0, 1.8]**, ±0.075 in z, with stable
   per-particle angle. Kerr frame-drag spins them.
2. **`RS_CULL = 0.40`** hides anything inside r = 0.4.
3. **Plasma fragment shader** sums core+halo across overlapping sprites via
   additive blend → dense disk regions auto-bloom into continuous plasma.
4. **Universal screen-space lensing** (`0.10/impact`, cap `0.45`) pushes every
   drawn particle away from the projected BH center in NDC — wraps the disk
   visually around the void.
5. **Kerr raytracer** renders pure black inside the geodesic event horizon;
   samples particle density along bent rays for the accretion glow; starfield
   fills escapes.

---

## ADSR phase encoding

```
0 = silence (full BH visible)
1 = attack  (BH fades out)
2 = decay   (BH hidden, particles free)
3 = sustain (BH ramps back like aftertouch)
4 = release (BH collapses to full)
```

Both lensing and raytracer follow the same curve so they stay coherent.

---

## Key tunables

| Symbol                  | Current | Effect of bigger value          | File / Line                          |
|-------------------------|---------|---------------------------------|--------------------------------------|
| `orbitalRadius` inner   | RS·2.5  | wider central void              | `particles.metal:195`                |
| `orbitalRadius` span    | 0.8     | thicker disk radially           | `particles.metal:195`                |
| `diskThickness`         | 0.15    | thicker disk in z               | `particles.metal:174`                |
| disk-confinement gain   | 80      | tighter orbital lock            | `particles.metal:209`                |
| `RS_CULL`               | 0.40    | bigger dark center              | `render.metal:190`                   |
| lensing gain            | 0.10    | more dramatic bend              | `render.metal:120` (approx)          |
| lensing cap             | 0.45    | how far close-in particles fly  | `render.metal:120`                   |
| plasma core k           | 9       | tighter sharp dots              | `render.metal:222`                   |
| plasma halo k           | 5       | tighter glow                    | `render.metal:225`                   |
| plasma halo intensity   | 0.55    | brighter glow                   | `render.metal:225`                   |
| `kGridSize`             | 64      | finer collision/density bins    | `renderer.mm:45`                     |
| `MAX_PER_CELL`          | 128     | how much density actually reads | `particles.metal:82`, `spatial_hash.metal:60` |
| wall threshold          | 3.0     | how many particles are live     | `particles.cpp:50` (approx)          |
| Gaussian spawn σ        | 1.2     | how spread the initial cloud is | `particles.cpp:16`                   |
