# SPACE Synth Physics Engine - Deep Analysis

## Architecture Overview

The physics engine runs entirely on GPU via a Metal compute shader (`particles.metal`). Each thread processes one particle per frame. The CPU side manages voice state (synth, envelope, mode mapping) and uploads per-frame uniforms. No CPU-side particle physics exists at runtime - the GPU owns all particle state after the initial upload.

```
CPU (per frame):
  Synth.updateEnvelopes(dt)
  -> getActiveVoices() -> VoiceGPUData[]
  -> PhysicsUniforms (dt, voiceCount, totalAmplitude, tunables)
  -> Upload to Metal buffers

GPU (per frame, per particle):
  particle_physics kernel
  -> Read particle state (pos, vel)
  -> Accumulate forces from all active voices
  -> Apply retraction, friction, speed cap
  -> Integrate (Euler)
  -> Boundary clamp
  -> Write particle state
```

---

## 1. Coordinate System

### Particle Space (Normalized)
- **x, y**: Position on circular plate, range [-1, 1], unit circle boundary
- **z**: Wave displacement (depth), range [-maxWaveDepth, +maxWaveDepth]
- **vx, vy**: Velocity in plate plane (normalized units)
- **vz**: Velocity in depth axis (scaled by plateRadius for energy equivalence)

### World Space (Rendering)
The vertex shader maps normalized coords to world:
```metal
float3 worldPos = float3(p.posW.x * R, p.posW.z, p.posW.y * R);
```
- World X = plate X * plateRadius
- World Y = wave depth z (unmapped, raw depth value)
- World Z = plate Y * plateRadius

This puts the plate in the XZ plane with Y as the vertical displacement axis.

### GPU Buffer Layout
```cpp
struct GPUParticle {  // alignas(16), 32 bytes total
    float x, y, z, pad0;   // position float4
    float vx, vy, vz, pad1; // velocity float4
};
```

---

## 2. The Bessel Function Engine

### Power Series Implementation
Two implementations exist:
1. **CPU** (`bessel.cpp`): 25-term series, double precision, used for LUT generation
2. **GPU** (`particles.metal`): 15-term series, float precision, inlined per-thread

GPU version (the one that matters at runtime):
```metal
static float besselJ(int n, float x) {
    // Initial term: (x/2)^n / n!
    // Series: sum_{k=0}^{14} (-1)^k * (x/2)^{2k+n} / (k! * (k+n)!)
    // Early exit when |term| < 1e-10
}
```

The series converges quickly for small arguments. For the alpha values used (2.4 to 20.3), 15 terms provides sufficient accuracy on GPU float32.

### Zeros Table
```
J_0 zeros: 2.4048,  5.5201,  8.6537, 11.7915
J_1 zeros: 3.8317,  7.0156, 10.1735, 13.3237
J_2 zeros: 5.1356,  8.4172, 11.6198, 14.7960
J_3 zeros: 6.3802,  9.7610, 13.0152, 16.2235
J_4 zeros: 7.5883, 11.0647, 14.3725, 17.6160
J_5 zeros: 8.7715, 12.3386, 15.7002, 18.9801
J_6 zeros: 9.9361, 13.5893, 17.0038, 20.3208
```

These are the alpha values where J_m(alpha) = 0. Each zero defines a resonant mode of the circular plate. The zero value directly determines:
- The nodal pattern (where displacement = 0)
- The frequency complexity (higher alpha = more nodal lines)
- The mode mapping order (sorted ascending)

### Analytical Derivatives
The GPU uses the Bessel recurrence relation for exact gradients:
```
J'_0(x) = -J_1(x)
J'_m(x) = 0.5 * (J_{m-1}(x) - J_{m+1}(x))    for m >= 1
```

This replaced numerical central differencing. Each gradient evaluation requires 2-3 Bessel function calls (J_{m-1}, J_m, J_{m+1}).

---

## 3. The 28 Chladni Modes

### Mode Definition
Each mode is a triple `(m, n, alpha)`:
- **m**: Angular order (0-6) - number of angular nodal lines
- **n**: Radial zero index (1-4) - number of circular nodal lines
- **alpha**: The n-th zero of J_m - determines the radial pattern

Total: 7 orders x 4 zeros = 28 modes

### Sorting
Modes are sorted by alpha ascending:
```
Index 0:  (0,1) alpha=2.4048  - simplest (one central peak)
Index 1:  (1,1) alpha=3.8317  - one angular line
Index 2:  (2,1) alpha=5.1356  - two angular lines
...
Index 27: (6,4) alpha=20.3208 - most complex
```

Low index = simple, slow patterns. High index = complex, fast patterns.

### MIDI Mapping
Two mapping modes:

**Full Range** (88-key): Linear map across all 28 modes
```cpp
float normalized = (midi - 21) / 87.0f;  // A0=21 to C8=108
int modeIndex = normalized * 27.99f;     // clamp to [0,27]
```

**Keyboard Mode** (17 keys): Maps the A-; keyboard range
```cpp
float normalized = (midi - kbStart) / 16.0f;  // 17 keys = 0..16
int modeIndex = normalized * 27.99f;
```

---

## 4. Force Model (GPU Compute Kernel)

The kernel runs per-particle, per-frame. Forces accumulate across all active voices.

### 4.1 Potential Field

The fundamental potential is the squared Chladni displacement:

```
P(r, theta) = [J_m(alpha * r) * cos(m*theta - k*z)]^2
```

Where:
- `k = modeP * pi / maxWaveDepth` (depth wave number)
- `kz = k * pz` (phase shift from depth)

Particles are driven toward **minima** of this potential (the nodal lines), where P = 0.

### 4.2 Radial Gradient (dP/dr)

```
dP/dr = 2 * J_m * J'_m * alpha * cos^2(phase)
```

This uses the analytical Bessel derivative. The force points toward nodal lines in the radial direction.

### 4.3 Angular Gradient (dP/dtheta)

```
dP/dtheta = -m * J_m^2 * sin(2 * phase)
```

This creates rotational forces around angular nodal lines. For m=0 modes (radially symmetric), this term vanishes. For m>0, particles experience tangential forces that create vortex-like motion around the angular nodes.

### 4.4 Polar-to-Cartesian Conversion

The chain rule converts polar gradients to Cartesian forces:
```metal
r_inv = 1 / (r + 1e-6)
dr/dx  = px * r_inv       dr/dy  = py * r_inv
dth/dx = -py * r_inv^2    dth/dy = px * r_inv^2

gx = dP_dr * dr_dx + dP_dth * dth_dx
gy = dP_dr * dr_dy + dP_dth * dth_dy
```

The epsilon (1e-6) prevents division by zero at the origin.

### 4.5 Depth Force (Z-axis)

```
gz = k * J_m^2 * sin(2 * phase)
```

Scaled by 200x to match HTML reference scaling. Drives vertical displacement oscillation.

Special case: For m=0 modes near z=0, noise is injected to break symmetry:
```metal
if (m == 0 && abs(pz) < 2.0) {
    gz += noise(id) * J_m^2 * k;
}
```

### 4.6 Boundary Potential

Cubic ramp near the plate edge:
```metal
if (r > 0.85) {
    float t = (r - 0.85) / 0.13;
    dP_dr += (0.5 * 3.0 / 0.13) * t^2;
}
```

This creates an increasing repulsive force from r=0.85 to r=0.98, pushing particles inward.

### 4.7 Polyphonic Normalization

```metal
float polyNorm = 1.0 / sqrt(voiceCount);
float w = min(amp, 1.0) * 0.45 * polyNorm;
```

Force weight per voice scales as `1/sqrt(N)`, preventing the total force from growing unbounded with polyphony. The 0.45 coefficient controls overall force strength. Amplitude is capped at 1.0 per voice.

### 4.8 No Gradient Normalization

Critical design decision: the gradient magnitude naturally approaches zero at nodal lines. Previous implementations normalized gradients to unit length, which caused particles to overshoot nodes at high speed. The current implementation preserves the raw gradient magnitude, allowing particles to decelerate naturally as they approach nodes.

---

## 5. Dissipation and Stability

### 5.1 Base Friction

```metal
float baseFric = pow(0.06, dt);
```

Frame-rate independent exponential decay. At 60fps (dt=0.0167): `pow(0.06, 0.0167) = 0.954`. This means velocity retains ~95.4% per frame, giving a half-life of about 0.4 seconds.

### 5.2 Dynamic Friction (Node Braking)

When voices are active, friction becomes position-dependent:
```metal
float distToNode = jitterTotal / totalAmplitude;
float nodeBrake = min(1.0, distToNode * 3.5 + 0.15);
dynamicFric = pow(damping, dt) * nodeBrake;
```

- Near nodes: `jitterTotal` is low (since `|J_m * cos(phase)|` is small), so `distToNode` is small, `nodeBrake` is ~0.15, and friction is HIGH
- Away from nodes: `jitterTotal` is high, `nodeBrake` approaches 1.0, and friction is LOW

This is the key mechanism that makes particles settle on nodal lines. Particles slow down dramatically at nodes and speed through anti-nodes.

The `damping` parameter (default 0.95, UI range 0.8-1.0) replaces `0.06` as the friction base when voices are active.

### 5.3 Speed Cap

```metal
float speedU = sqrt(vx^2 + vy^2 + (vz/R)^2);
if (speedU > speedCap) {
    float s = speedCap / speedU;
    vx *= s; vy *= s; vz *= s;
}
```

The Z velocity is normalized by plateRadius (400) for energy equivalence with XY. Default cap: 1.2 (UI range 0.1-5.0).

### 5.4 Jitter (Noise Injection)

Two layers of amplitude-modulated noise:

**Layer 1** (velocity-gated):
```metal
if (jitterTotal > 0.01 && velMag > 0.001) {
    float n = jitterTotal * 6.0 * dt * jitterFactor;
    v += noise(id) * n;
}
```

**Layer 2** (unconditional when jitter > threshold):
```metal
if (jitterTotal > 0.01) {
    float n = jitterTotal * 12.0 * dt * jitterFactor;
    v += noise(id) * n;
}
```

Both scale with `jitterTotal` (sum of `|J_m * cos(phase)| * amplitude` across voices), so noise is strongest at anti-nodes and weakest at nodes. Z-axis jitter is scaled by `maxWaveDepth/400` for depth proportionality.

The noise function is a simple LCG hash:
```metal
uint x = id * 1103515245 + 12345;
return float((x / 65536) % 32768) / 32767.0 - 0.5;
```

Note: This is deterministic per-particle (same noise each frame for a given id). This means jitter acts as a constant displacement bias, not true random diffusion. The `dt` factor provides frame-rate scaling but not temporal variation.

---

## 6. Retraction System

### 3D Spherical Pull
When no sound is active, particles retract toward a target sphere:

```metal
float retractPull = (1.0 - totalAmplitude) * 15.0 * retractionPull;
```

The pull strength is inversely proportional to `totalAmplitude` - it fades to zero when sound is playing and maximizes when silent.

**Sphere Mode** (sphereMode=1):
- Target radius: 0.75
- Pull multiplier: 2.0x
- Particles form a 3D spherical shell

**Flat Mode** (sphereMode=0):
- Target radius: 0.35
- Pull multiplier: 1.0x
- Particles collapse to a smaller disk

The retraction direction is radial from origin:
```metal
float rx = px, ry = py, rz = pz / R;
float rMag = length(rx, ry, rz);
float pull = (rMag - targetR) * retractPull * pullMultiplier;
v -= (r/rMag) * pull * dt;
```

Z velocity gets an extra `* R` factor to match the coordinate scaling.

---

## 7. Integration and Boundary

### Euler Integration
```metal
px += vx * dt * 60.0;
py += vy * dt * 60.0;
pz += vz * dt * 60.0;
```

The `* 60.0` factor means velocities are calibrated for 60fps. At lower framerates, larger dt compensates, but the 60x multiplier means the effective velocity units are "displacement per 1/60th second."

### Boundary Clamping

**Sphere Mode**: Hard sphere at r3d = 0.96
```metal
float r3d = sqrt(px^2 + py^2 + (pz/R)^2);
if (r3d > 0.96) {
    scale = 0.95 / r3d;  // Push inside
    pos *= scale;
    vel *= -0.3;  // Elastic bounce (30% restitution)
}
```

**Flat Mode**: Circular plate + Z walls
```metal
// Plate boundary
float rr = sqrt(px^2 + py^2);
if (rr > 0.96) {
    pos.xy = pos.xy / rr * 0.95;  // Push to r=0.95
    vel.xy *= -0.3;
}
// Depth walls
if (abs(pz) > maxWaveDepth) {
    pz = sign(pz) * maxWaveDepth * 0.95;
    vz *= -0.3;
}
```

---

## 8. Voice System (CPU)

### Polyphonic Architecture
- Voices stored in `unordered_map<int, Voice>` keyed by MIDI note
- Thread-safe via `std::mutex` (audio thread writes, render thread reads)
- Each voice holds: oscillator phase, ADSR envelope, Bessel mode pointer

### Envelope (ADSR)
```
Attack:  Linear ramp from current to target (default 20ms)
Decay:   Linear ramp from peak to sustain level (default 100ms)
Sustain: Hold at sustain * velocity (default 0.7)
Release: Linear ramp from current to zero (default 400ms)
Off:     Amplitude = 0, voice removed from map
```

Retrigger smoothing: attack starts from current amplitude, not zero.

### Voice -> GPU Data
Each frame, active voices are packed into `VoiceGPUData`:
```cpp
struct VoiceGPUData {
    int m;           // Bessel angular order
    int n;           // Radial zero index
    float alpha;     // Bessel zero value
    float amplitude; // Current envelope amplitude
};
```

`totalAmplitude` = sum of all voice amplitudes, capped at 1.5.

---

## 9. Rendering Pipeline

### Vertex Shader
- Point sprites (`MTLPrimitiveTypePoint`)
- World position: `(x*R, z, y*R)`
- Dynamic point size: `particleSize * (800 / distance)`
- Ortho/perspective mode flag in `cam.padding[0]`
- Color: sand palette (warm brown/gold), height-mapped, speed-boosted

### Fragment Shader
- Dual-layer rendering: sharp core + soft glow
- Core: `pow(1-d, 3)` - sharp distinct edge
- Glow: `exp(-d^2 * 3.5)` - tight intensity fallout
- Distance fade: `smoothstep(0.1, 6.0, dist)` for fill-rate optimization

### Post-FX Pipeline
Offscreen render -> post-processing -> drawable:
1. **Chromatic aberration**: RGB channel split, radial distortion
2. **Bloom**: 13-tap cross-shaped bright-pass blur
3. **Motion trails**: max-blend with previous frame * decay factor

### Blending
Additive: `src=One, dst=One` (RGB). This means overlapping particles brighten, creating natural density visualization.

---

## 10. Tunable Parameters

| Parameter | Uniform Field | Default | Range | Effect |
|-----------|--------------|---------|-------|--------|
| Particle Size | `particleSize` | 4.0 | 0.5-10 | Visual radius of each point sprite |
| Particle Count | `particleCount` | 800k | 10k-800k | Active particles in simulation |
| Jitter | `jitterFactor` | 1.0 | 0-5 | Noise displacement at anti-nodes |
| Damping | `damping` | 0.95 | 0.8-1.0 | Base friction when voices active |
| Retraction | `retractionPull` | 1.0 | 0-5 | Strength of idle-state pull |
| Wave Depth | `maxWaveDepth` | 140 | 5-100 | Maximum Z displacement |
| Speed Cap | `speedCap` | 1.2 | 0.1-5 | Maximum normalized velocity |
| ModeP | `modeP` | 1.0 | 1-4 | Depth wave number multiplier |
| Plate Radius | `plateRadius` | 400 | 100-1000 | World-space plate scale |
| Sim Mode | `simMode` | 0 | 0/1 | 0=Classic, 1=Vortex |
| Sphere Mode | `sphereMode` | 1 | 0/1 | 0=Flat plate, 1=Spherical shell |
| Bloom | `bloomIntensity` | 0 | 0-1 | Cross-shaped glow intensity |
| Trails | `trailDecay` | 0 | 0-0.99 | Frame persistence factor |
| Chromatic | `chromaticAmount` | 0 | 0-0.02 | RGB split amount |

---

## 11. Known Characteristics and Edge Cases

### Deterministic Noise
The noise function `noise(id, dt)` doesn't actually use `dt` for randomness - it's purely `id`-based. This means each particle gets the same noise offset every frame, creating a constant bias rather than Brownian motion. For true diffusion, the noise should incorporate a frame counter or time-based seed.

### Hardcoded R=400
The retraction system and speed cap use `R = 400.0` as a hardcoded constant instead of reading from `u.plateRadius`. If `plateRadius` is changed via the UI, retraction Z-scaling and speed normalization won't track.

### Double Jitter Application
Lines 166-174 and 177-182 both apply jitter when `jitterTotal > 0.01`, with different scaling factors (6.0 and 12.0). This effectively applies 18x total jitter scaling. May be intentional for feel, but the velocity-gating on the first block (`velMag > 0.001`) creates a subtle asymmetry where stationary particles only get the 12x jitter.

### Integration Timescale
The `* 60.0` in Euler integration means the simulation is calibrated for 60fps. At 30fps, `dt` doubles but the 60x multiplier is constant, so particles move at the same speed. However, the friction `pow(0.06, dt)` is frame-rate independent while the force application (`vx += fxTotal`) is not multiplied by dt. This means force impulses are frame-rate dependent - particles get stronger kicks at lower framerates.

### Polyphonic Voice Count in Envelope Logging
`activeVoiceCount()` counts voices with `amplitude > 0.001`, but `noteOn()` logs `activeVoiceCount()` before the mutex in `noteOn` fully inserts the voice. The logged count may be off by one.

---

## 12. Performance Profile

### GPU Compute Cost Per Particle
For each particle, per voice:
- 3 Bessel function evaluations (J_{m-1}, J_m, J_{m+1}), each up to 15 terms
- 2 trig calls (cos, sin of phase)
- Polar-to-Cartesian chain rule (6 multiplies, 4 adds)
- Boundary potential check

Total per particle: ~45 * voiceCount FLOPs for force computation, plus friction/retraction/integration overhead.

### Memory Bandwidth
- Particle buffer: 32 bytes read + 32 bytes write per particle = 64 bytes
- At 800k particles: 51.2 MB/frame particle I/O
- Voice buffer: 16 bytes * voiceCount (negligible)
- Uniforms: 56 bytes (negligible)

### Bottleneck Analysis
At 800k particles with 1-4 voices, the compute shader is ALU-bound (Bessel series evaluation), not bandwidth-bound. Increasing voice count linearly increases cost due to the inner loop over voices.
