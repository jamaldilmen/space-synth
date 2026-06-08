#include <metal_stdlib>
using namespace metal;

// Decode the packed phase out of velW.w (band ID lives in the upper 3 bits).
// velW.w holds as_type<float>((bandBits<<29)|phaseBits) — a reinterpreted int,
// NOT a usable float. Reading it directly as a float is garbage. This is the
// inverse of the pack at the end of compute_physics and mirrors
// render.metal::decodePhaseAndBand so producer and consumer stay in sync.
static inline float decodePhase(float packed) {
    uint bits = as_type<uint>(packed);
    uint phaseBits = bits & 0x1FFFFFFFu;
    return ((float)phaseBits / (float)0x1FFFFFFFu) * (2.0f * M_PI_F) - M_PI_F;
}

// GPU particle state — matches GPUParticle struct in C++ (80 bytes)
struct Particle {
    float4 posW;   // x, y, z, mass
    float4 velW;   // vx, vy, vz, phase
    float4 prevW;  // prevX, prevY, prevZ, temperature
    float4 spinW;  // spinX, spinY, spinZ, charge
    uint4 entanglement; // x: entangledIndex, y: pad1, z: pad2, w: pad3
};

struct VoiceData {
    int m;
    int n;
    float alpha;
    float amplitude;
    float emitterX;
    float emitterY;
    float emitterZ;
    float frequency;
    float deltaAmp;
    float phase;
    int bandGroup;
    float padding;
};

struct PhysicsUniforms {
    float dt;                   // 0
    float totalAmplitude;       // 4
    int voiceCount;             // 8
    int particleCount;          // 12
    float maxWaveDepth;         // 16
    float plateRadius;          // 20
    float jitterFactor;         // 24
    float speedCap;             // 28
    uint frameCounter;          // 32
    float symmetryBreakImpulse; // 36
    float collisionRadius;      // 40
    int collisionsOn;           // 44
    float uncertaintyStrength;  // 48
    float eFieldStiffness;      // 52
    float bFieldCirculation;    // 56
    float time;                 // 60
    float gravityConstant;      // 64
    float stringStiffness;      // 68
    float restLength;           // 72
    uint debugFlags;            // 76

    // ═══ BLACK HOLE LIFECYCLE (Phase 17) ═══
    float envelopePhase;         // 80: 0=silence, 1=attack, 2=decay, 3=sustain, 4=release
    float envelopeProgress;      // 84: 0.0→1.0 within current phase
    float lifecycleIntensity;    // 88: master intensity multiplier
    float lifecyclePad;          // 92: alignment
    float diskThickness;         // 96: accretion-disk vertical thickness (UI)
    float spinX;                 // 100: user spin torque around X axis (rad/s)
    float spinY;                 // 104: user spin torque around Y axis (rad/s)
};

struct SpatialHashUniforms {
    int gridSize;
    int particleCount;
    float cellSize;
    float invCellSize;
    int gridSizeZ;
    float halfExtent;   // particle field half-extent in sim coords
};

// (Removed Bessel functions - no longer used)

// Physical Constants
#ifndef TWO_PI
#define TWO_PI 6.283185307f
#endif

// Temporal noise — hash uses frame counter for proper Brownian motion
static float noise(uint id, uint frame) {
    uint x = (id * 1103515245u + 12345u) ^ (frame * 2654435761u);
    x ^= x >> 16;
    x *= 0x45d9f3bu;
    x ^= x >> 16;
    return (float(x & 0x7FFFu) / 32767.0f) - 0.5f;
}

// Collision constants
constant int MAX_PER_CELL = 128; // Was 32 (sized for 1M); bumped for 5M+ so
                                  // dense disk regions don't clip the neighbor
                                  // scan / density readback. Must match the
                                  // atomic cap in spatial_hash.metal.

// Phase 11.3: Planck-length softening (regularizes point-particle infinities)
constant float PLANCK_LENGTH_SQ = 0.0001f; // Minimum interaction distance²

// ── Unified BH constants ────────────────────────────────────────────────────
// All BH-related sizes derive from BH_M (the visual Schwarzschild radius in
// sim coords). Must match `M` in blackhole.metal:5.
//   BH_M       = mass / Schwarzschild radius (sim coords)
//   BH_HORIZON = Kerr outer horizon = M + sqrt(M² − a²) for a=0.99M ≈ 1.14·M
// All gates that previously used the stale `SCHWARZSCHILD_RS = 0.40` constant
// now derive from these so the particle physics' notion of "near horizon"
// matches what the raytracer actually draws as the horizon.
//
// NOTE: gravity strength is a SEPARATE physical parameter (not derived from
// BH_M) because using M_visual=0.025 as the gravitational mass would give
// orbital periods of ~40s — too slow to be visually interesting. Real BHs
// have decoupled "apparent shadow size" from "orbital timescale" anyway
// (the shadow scales with M, orbital periods scale with M but also with r³,
// so picking a usable r where M is visible is a separate tuning).
constant float BH_M       = 0.5f;
constant float BH_HORIZON = 0.57f;          // ≈ M + sqrt(M² − a²), a = 0.99M
constant float SCHWARZSCHILD_RS = BH_HORIZON; // legacy alias (existing gates)
// Outer cap is now DYNAMIC — see compute_physics for the per-frame
// blend. The values below are the two endpoints:
//   ORBIT_R_BH      = silence/BH state, tight ring just past horizon.
//                     Disk reads as a thin Saturn-ring around the BH.
//   ORBIT_R_CHLADNI = play state, the godlike-creating cap. Bessel
//                     voice forces fill this radius with structured
//                     pattern.
// totalAmplitude drives the blend: 0 → BH cap, > ~0.5 → CHLADNI cap.
// Result: "explodes out of the BH on note attack, sucked back in on
// release."
constant float ORBIT_R_BH      = 2.0f; // widened from 1.0: the rest disk now has
                                       // RADIAL WIDTH [0.75→2.0] instead of a thin
                                       // 1-radius ring, so the Shakura–Sunyaev
                                       // temperature gradient (hot inner → cool
                                       // outer) is visible. Still breathes out to
                                       // ORBIT_R_CHLADNI on play.
constant float ORBIT_R_CHLADNI = 3.0f;

// ── ERUPTIONS in the hardened areas (magnetic-reconnection / solar-flare) ──
// Where the Chladni pattern hardens (dense nodes), stress builds; past a
// threshold the node ERUPTS — a sudden outward plasma burst + heat flash. See
// [[space-synth-tube-supernova-vision]].
constant uint  ERUPT_DENSITY   = 20u;   // cell particle count = a "hardened" node
constant float ERUPT_THRESHOLD = 0.80f; // intermittency gate (per-cell flare clock)
constant float ERUPT_FORCE     = 80.0f; // outward burst velocity scale
constant float ERUPT_TEMP      = 4.0f;  // flash temperature (hot plasma)

// ── Compute kernel: Störmer-Verlet particle physics ─────────────────────────

kernel void compute_physics(
    device Particle* particles [[buffer(0)]],
    device const VoiceData* voices [[buffer(1)]],
    constant PhysicsUniforms& u [[buffer(2)]],
    device const Particle* prevParticles [[buffer(3)]],
    device const Particle* sortedParticles [[buffer(4)]],
    device const uint* cellStarts [[buffer(5)]],
    device const uint* cellCounts [[buffer(6)]],
    constant SpatialHashUniforms& su [[buffer(7)]],
    uint id [[thread_position_in_grid]])
{
    if (int(id) >= u.particleCount) return;

    device Particle& p = particles[id];
    float px = p.posW.x;
    float py = p.posW.y;
    float pz = p.posW.z;
    float mass = p.posW.w;

    // ── Störmer-Verlet: derive velocity from position history ────────
    float prevX = p.prevW.x;
    float prevY = p.prevW.y;
    float prevZ = p.prevW.z;

    // Velocity proxy: displacement from previous frame
    float vpx = px - prevX;
    float vpy = py - prevY;
    float vpz = pz - prevZ;

    // ── Phase 7: Deterministic Debug Mode ──────────────────────────
    float dt = (u.debugFlags & (1 << 6)) ? (1.0f / 60.0f) : u.dt;
    
    // Base friction. Was pow(0.02, dt) ≈ 0.968/frame (heavy damping) which
    // killed orbital stability — Kepler orbits need energy conservation,
    // friction makes them spiral in. Bumped to pow(0.9, dt) ≈ 0.9991/frame
    // → nearly zero damping at rest, particles orbit cleanly.
    // During play, voice forces still dominate; the small friction prevents
    // runaway velocity buildup but doesn't crush orbital momentum.
    float baseFric = pow(0.9f, dt);

    float dynamicFric = baseFric;

    float currentTemp = p.prevW.w; // ODS-03: Thermal state

    // ── Snap Back: Pulse re-seed/Reset logic ──
    if (u.debugFlags & (1 << 8)) {
        uint seed = (uint)id + u.frameCounter;
        float r_new = sqrt(-2.0 * log(max(1e-7f, noise(id, seed)))) * 0.5f;
        float th_new = noise(id, seed + 1) * TWO_PI;
        float ph_new = noise(id, seed + 2) * M_PI_F;
        
        px = r_new * sin(ph_new) * cos(th_new);
        py = r_new * sin(ph_new) * sin(th_new);
        pz = r_new * cos(ph_new);
        vpx = 0.0f; vpy = 0.0f; vpz = 0.0f;
    }

    // Accumulate velocity pulses and position corrections globally
    float shiftX = 0.0f, shiftY = 0.0f, shiftZ = 0.0f;
    float shiftVx = 0.0f, shiftVy = 0.0f, shiftVz = 0.0f;

    // ══════════════════════════════════════════════════════════════════════
    // ═══ BLACK HOLE LIFECYCLE (ADSR-Synced Cosmic Evolution) ═══
    // ══════════════════════════════════════════════════════════════════════
    float3 pvec = float3(px, py, pz);
    float r_curr = length(pvec);
    float t = u.envelopeProgress; // Progress within current phase [0→1]
    float lcI = max(u.lifecycleIntensity, 0.001f); // Prevent division by zero
    bool collapsed = false; // Tracks if particle has been force-collapsed into singularity
    bool isSilence = (u.envelopePhase < 0.5f); // Gate for force immunity
    // While the user is spinning the body, the BH lifecycle pulls (gravity,
    // z-damping) yield so the spin is the dominant, clean force — otherwise the
    // competing pulls make it feel like a tug-of-war.
    float spinSuppress = 1.0f - clamp((abs(u.spinX) + abs(u.spinY)) * 0.3f, 0.0f, 1.0f);

    float globalTargetRadius = 0.75f;
    if (u.envelopePhase >= 0.5f && u.envelopePhase < 1.5f) {
        globalTargetRadius = 0.75f * t;
    } else if (u.envelopePhase >= 1.5f && u.envelopePhase < 3.5f) {
        // Linear limit bumped up "a notch" (2.0x instead of 0.9x) to give chords breathing room 
        globalTargetRadius = max(0.75f, lcI * 2.0f);
    } else if (u.envelopePhase >= 3.5f) {
        // Release: ease the target radius DOWN to the silence REST radius
        // (0.75) — NOT to 0. Collapsing to ~0 then snapping back to the rest
        // radius at the silence switch was the "disk → ring" pop. Easing to the
        // rest value makes release land exactly on the existing rest state →
        // one continuous draw-in. Rest state itself is unchanged.
        float sustainR = max(0.75f, lcI * 2.0f);
        globalTargetRadius = mix(sustainR, 0.75f, t);
    }

    // ─── PHASE 0: SILENCE → BLACK HOLE WITH ACCRETION DISK ───────────────
    if (u.envelopePhase < 0.5f) {
        float rLen = r_curr;
        if (rLen > 0.001f) {
            float3 dir = pvec / rLen;

            // ═══ ACCRETION DISK GEOMETRY ═══
            float diskRadius = 0.45f;      // Disk inner-to-outer span
            float diskThickness = u.diskThickness; // Vertical thickness (UI)

            // Project position onto disk plane
            float rXY = sqrt(px * px + py * py);  // Radial in disk plane
            float diskHeight = abs(pz);           // Height above/below disk

            // Distance from ideal disk torus
            float diskRadialDist = abs(rXY - diskRadius);
            float distFromDisk = sqrt(diskRadialDist * diskRadialDist + diskHeight * diskHeight);

            // ═══ MULTI-LAYER FORCES (fixed strength — no amplitude scaling) ═══

            // 1. GRAVITY — flat rotation curve, BH MUST DOMINATE.
            // G bumped 20 → 100 so the central pull dominates all other
            // forces including voice perturbations. r0 0.5 → 0.1 so the
            // gravity well is sharper near the BH (less softening fudge).
            // 1/(r+r0) falloff keeps gravity meaningful at large r so
            // escaped particles get pulled back, not lost.
            // MUST match the spawn velocity formula in particles.cpp.
            float G = 100.0f;
            float r0 = 0.1f;
            float gMag = (G / (rLen + r0)) * spinSuppress; // yields while spinning
            shiftVx -= dir.x * gMag * dt;
            shiftVy -= dir.y * gMag * dt;
            shiftVz -= dir.z * gMag * dt;

            // 1b. Z-PLANE DAMPING. Active pull toward z=0 so the disk stays flat.
            // Strength is now driven by the Disk Thickness fader: weaker damping
            // = fatter disk. zDamp = 0.75/thickness → at the 0.15 default this is
            // 5.0 (the original), at 0.30 it's 2.5 (thicker), etc.
            float zDamp = (0.75f / max(u.diskThickness, 0.02f)) * spinSuppress;
            shiftVz -= pz * zDamp * dt;

            // 2. DISK CONFINEMENT — TEMP DISABLED.
            // Was a hardcoded spring force pulling every particle to a
            // fixed orbital target on a thin xy-plane ring. That ring IS
            // the "2D hardcoded BH" — the shape was defined by code, not
            // emergent from physics. Disabling to see what particles do
            // without an imposed shape.

            // 3. KERR FRAME-DRAGGING — DISABLED.
            // Added a `15/sqrt(rXY)` tangential force ON TOP of the orbital
            // velocity the particles already have from spawn + gravity.
            // At r=1.5 that's ~12 units/s of extra spin vs the ~3.5
            // orbital velocity → particles got over-sped and flung
            // outward, breaking the orbit. The orbital velocity alone
            // (v² = G·r/(r²+r0²), set at spawn, maintained by gravity)
            // already makes particles spin around the BH cleanly.
            // The vertical-shear z-damping it also did is handled by the
            // thin spawn (z σ=0.05) instead.

            // 3b. DENSITY PRESSURE — TEMP DISABLED for Step 1 verification.
            // Was overpowering gravity (pressure scale 12 vs gravity scale 1)
            // and pushing all particles outward → blowing up the Gaussian
            // spawn instead of collapsing it. Re-enable in a later step
            // after we have orbital dynamics holding particles in place.
            if (false /* su.gridSize > 0 */) {
                int cx = clamp(int((px + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
                int cy = clamp(int((py + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
                int cz = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
                uint cID = uint((cz * su.gridSize + cy) * su.gridSize + cx);
                uint count = cellCounts[cID];
                if (count > 24u) {
                    // World-space cell-center position
                    float ccx = (float(cx) + 0.5f) * su.cellSize - 1.0f;
                    float ccy = (float(cy) + 0.5f) * su.cellSize - 1.0f;
                    float ccz = (float(cz) + 0.5f) * su.cellSize - 1.0f;
                    float3 outward = float3(px - ccx, py - ccy, pz - ccz);
                    float outLen = length(outward) + 1e-6f;
                    // log2(count/24) gives a smooth ramp from 1 (count=48) up
                    // to ~2.4 (count=128 cap). Pressure scale 12 chosen so
                    // disk confinement (max ~5 vel/frame at target) and
                    // pressure share the same dynamic range.
                    float pressure = log2(float(count) * (1.0f / 24.0f)) * 12.0f;
                    float3 push = (outward / outLen) * pressure;
                    shiftVx += push.x * dt;
                    shiftVy += push.y * dt;
                    shiftVz += push.z * dt;
                    // Heat the particle — dense regions are hot plasma.
                    currentTemp = mix(currentTemp,
                                      1.0f + log2(float(count) * (1.0f / 24.0f)) * 0.8f,
                                      0.15f);
                }
            }

            // 4. GRAVITATIONAL LENSING — removed from particle physics.
            // This force pushed particles perpendicular to the disk plane,
            // creating orbital "yoyo" rings. Lensing is a LIGHT effect handled
            // by the Kerr raytracer in blackhole.metal, not a matter force.

            // 5. HAWKING RADIATION (quantum fluctuations near horizon)
            if (rLen < SCHWARZSCHILD_RS * 4.0f) {
                shiftVx += noise(id, u.frameCounter) * 0.8f * dt;
                shiftVy += noise(id + 1000u, u.frameCounter) * 0.8f * dt;
                shiftVz += noise(id + 2000u, u.frameCounter) * 0.4f * dt;
                currentTemp = mix(currentTemp, 0.3f, 0.05f);
            }

            // 6. EVENT HORIZON FREEZE — DISABLED.
            // Was a trapdoor: any particle that crossed r < RS got both its
            // velocity AND accumulated shift forces zeroed, then `collapsed`
            // flag set. Disk confinement (block 2) is gated `if (rLen > RS)`
            // so it couldn't rescue trapped particles. Result: particles
            // drifted into RS over time, accumulated there, became invisible
            // via RS_CULL in render.metal. The visible field decayed away.
            // Removing the freeze lets particles pass through RS freely;
            // RS_CULL still hides them while inside but they re-emerge on
            // the other side or get pulled back out by disk confinement.

            // ═══ OPTICAL EFFECTS ═══
            if (distFromDisk < diskThickness) {
                float diskTemp = 5.0f / (rXY + 0.2f);
                currentTemp = mix(currentTemp, diskTemp, 0.1f * dt);
            }
            float approachingVel = -(vpx * py - vpy * px) / (rXY + 0.001f);
            if (approachingVel > 0.0f) {
                currentTemp *= (1.0f + approachingVel * 0.3f);
            }
        } else {
            // Particle at exact origin: freeze
            vpx = 0.0f; vpy = 0.0f; vpz = 0.0f;
            collapsed = true;
        }
    }
    // ─── PHASE 1: ATTACK → BIG BANG EXPLOSION ────────────────────────────
    else if (u.envelopePhase < 1.5f) {
        // Cap explosion power
        float explosionPower = (1.0f - t) * 80.0f * min(lcI, 3.0f);

        if (r_curr < 0.001f) {
            // Particle at singularity: initialize random direction
            float theta = noise(id * 3u, u.frameCounter) * M_PI_F * 2.0f;
            float phi = noise(id * 5u, u.frameCounter) * M_PI_F;
            pvec = float3(sin(phi)*cos(theta), sin(phi)*sin(theta), cos(phi));
            r_curr = 1.0f;
        }
        float3 dir = pvec / max(r_curr, 0.001f);
        shiftVx += dir.x * explosionPower * dt;
        shiftVy += dir.y * explosionPower * dt;
        shiftVz += dir.z * explosionPower * dt;

        // Blast wave temperature spike
        currentTemp = mix(8.0f, 2.0f, t);

        // Shockwave ripples
        float waveFront = abs(r_curr - t * 2.0f);
        if (waveFront < 0.3f) {
            float ripple = (0.3f - waveFront) * 20.0f * sin(r_curr * 20.0f - t * 50.0f);
            shiftVx += dir.x * ripple * dt;
            shiftVy += dir.y * ripple * dt;
            shiftVz += dir.z * ripple * dt;
        }
    }
    // ─── PHASE 2/3: DECAY/SUSTAIN → SUN (Radiating Sphere / Plasma) ──────────────
    else if (u.envelopePhase < 3.5f) {
        float targetRadius = globalTargetRadius;
        if (r_curr > 0.001f) {
            float3 dir = pvec / r_curr;
            float displacement = (r_curr - targetRadius);

            // Hard velocity brake: kill outward momentum so particles snap to shell
            // The further past targetRadius, the harder the brake
            float overshoot = max(0.0f, displacement) / (targetRadius + 0.1f);
            float brakeFactor = max(0.05f, 1.0f - overshoot * 3.0f);
            vpx *= brakeFactor;
            vpy *= brakeFactor;
            vpz *= brakeFactor;

            // Strong spring toward shell surface (matched to explosion force)
            float springForce = displacement * 80.0f * lcI;
            shiftVx -= dir.x * springForce * dt;
            shiftVy -= dir.y * springForce * dt;
            shiftVz -= dir.z * springForce * dt;

            // Solar wind: tangential circulation
            float3 galacticUp = normalize(float3(0.3f, 1.0f, 0.2f));
            float3 tangent = cross(galacticUp, dir);
            float circulationSpeed = 8.0f * lcI / (abs(displacement) + 0.5f);
            shiftVx += tangent.x * circulationSpeed * dt;
            shiftVy += tangent.y * circulationSpeed * dt;
            shiftVz += tangent.z * circulationSpeed * dt;

            // Photosphere temperature
            currentTemp = mix(currentTemp, 1.5f, 0.1f * dt);

            // ── Self-Oscillation Feature (Empty Space Resonance) ──
            // When lcI > 1.25 (filter/LFO resonance), standing wave plasma filaments emerge
            if (lcI > 1.25f) {
                // Cap resonance force to prevent string webbing logic tears
                float resonance = min(lcI - 1.25f, 5.0f);
                float ribs = sin(r_curr * 15.0f - u.time * 25.0f) * cos(atan2(py, px) * 8.0f);
                float waveForce = ribs * 150.0f * resonance;
                shiftVx += dir.x * waveForce * dt;
                shiftVy += dir.y * waveForce * dt;
                shiftVz += dir.z * waveForce * dt;
                
                float filament = sin(pz * 20.0f) * 100.0f * resonance;
                shiftVx += tangent.x * filament * dt;
                shiftVy += tangent.y * filament * dt;
                
                currentTemp += 5.0f * resonance * dt;
            }
        }
    }
    // ─── PHASE 4: RELEASE → GRAVITATIONAL COLLAPSE ───────────────────────
    else {
        if (r_curr > 0.001f) {
            float3 dir = pvec / r_curr;
            // SEAMLESS HAND-OFF to silence. The old code yanked everything to a
            // point at r=0 (and froze velocity), but the silence state wants an
            // accretion DISK — so the 4→0 phase switch popped. Instead, ramp in
            // the SAME forces the silence BH state uses (gravity G/(r+r0) +
            // z-plane damping), scaled by release progress t. By t=1 the
            // particles are already under silence-strength gravity, so entering
            // silence is continuous: they get drawn into the BH, not snapped.
            float G  = 100.0f;
            float r0 = 0.1f;
            float gMag = (G / (r_curr + r0)) * t; // ramp 0→full over the collapse
            shiftVx -= dir.x * gMag * dt;
            shiftVy -= dir.y * gMag * dt;
            shiftVz -= dir.z * gMag * dt;

            // Match silence's z-plane damping (ramped) so the disk flattens into
            // place rather than popping flat at the switch.
            shiftVz -= pz * (0.75f / max(u.diskThickness, 0.02f)) * t * dt;

            // Gentle Kerr spiral for the spiral-in look (scaled with gravity).
            float3 galacticUp = normalize(float3(0.2f, 1.0f, 0.3f));
            float3 spinForce = cross(galacticUp, dir);
            shiftVx += spinForce.x * gMag * 0.3f * dt;
            shiftVy += spinForce.y * gMag * 0.3f * dt;
            shiftVz += spinForce.z * gMag * 0.3f * dt;

            currentTemp *= (1.0f - t * 0.05f);
        }
    }

    // Safety Snapback for runaway particles
    if (r_curr > 1000.0f) {
        px *= 0.5f; py *= 0.5f; pz *= 0.5f;
    }
    pvec = float3(px, py, pz);
    r_curr = length(pvec);

    // ── ERUPTIONS in the hardened areas (magnetic-reconnection / solar-flare) ──
    // Where the Chladni pattern HARDENS (dense nodes), stress builds; past a
    // threshold the node ERUPTS — a sudden outward plasma burst + heat flash,
    // bursting from the dense NODE centre (local splash). A slow per-cell noise
    // clock makes flares INTERMITTENT (pop at different nodes over time, like the
    // sun), not all at once. Only during play (decay/sustain), where it hardens.
    if (su.gridSize > 0 && u.envelopePhase >= 1.5f && u.envelopePhase < 3.5f) {
        int ecx = clamp(int((px + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int ecy = clamp(int((py + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int ecz = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        uint ecID = uint((ecz * su.gridSize + ecy) * su.gridSize + ecx);
        uint ecount = cellCounts[ecID];
        if (ecount > ERUPT_DENSITY) {
            float stress = log2(float(ecount) / float(ERUPT_DENSITY)); // 0..~3
            // Intermittent per-cell flare clock (changes a few times/sec).
            float flare = noise(ecID * 2654435761u + 7u, uint(u.time * 2.0f));
            if (flare * stress > ERUPT_THRESHOLD) {
                float ccx = (float(ecx) + 0.5f) * su.cellSize - su.halfExtent;
                float ccy = (float(ecy) + 0.5f) * su.cellSize - su.halfExtent;
                float ccz = (float(ecz) + 0.5f) * su.cellSize - su.halfExtent;
                float3 outward = float3(px - ccx, py - ccy, pz - ccz);
                outward = outward / (length(outward) + 1e-4f);
                float burst = ERUPT_FORCE * stress;
                shiftVx += outward.x * burst * dt;
                shiftVy += outward.y * burst * dt;
                shiftVz += outward.z * burst * dt;
                currentTemp = max(currentTemp, ERUPT_TEMP * stress); // flash hot plasma
            }
        }
    }

    // Save lifecycle-only shifts before the force pipeline contaminates them
    float3 lifecycleShiftV = float3(shiftVx, shiftVy, shiftVz);
    float3 lifecycleShiftP = float3(shiftX, shiftY, shiftZ);

    // Emitter Interactions (Macro forces)
    float baseMass = (mass > 1000.0f) ? mass : 1.0f;
    float dynamicMass = baseMass;

    // Safety: Clamp voiceCount to prevent reading beyond buffer or into uninitialized memory
    int numVoices = min((int)u.voiceCount, 16);

    // Track which band exerts strongest force (for per-band color) — declared outside voice block
    int bestBand = 0;
    float bestForce = 0.0f;

    if (numVoices > 0 && baseMass < 1000.0f) {
        // Polyphony normalizer (the proven 1/sqrt(voiceCount)). Without it a
        // chord stacks every voice's sculpt force N× → particles over-cluster
        // onto the shared nodal lines and blow out to white. This makes total
        // shape force grow as sqrt(N), not N. Single notes (N=1) → 1.0, no change.
        float polyNorm = rsqrt(float(numVoices));
        float massAdd = 0.0f;
        float jitterTotal = 0.0f;
        float Y_total = 0.0f;
        float dynamicMass = baseMass;

        // Accumulators for Phase 18 Chord Webbing
        float sum_Y = 0.0f;
        float sum_dYdth = 0.0f;
        float sum_dYdphi = 0.0f;
        float sum_Y2 = 0.0f;
        float sum_YdYdth = 0.0f;
        float sum_YdYdphi = 0.0f;

        for (int vi = 0; vi < numVoices; vi++) {
            float amp = voices[vi].amplitude;
            if (amp < 0.001f) continue;

            // Global attractive/repulsive forces from the emitter
            float dx = px - voices[vi].emitterX;
            float dy = py - voices[vi].emitterY;
            float dz = pz - voices[vi].emitterZ;
            float r2 = dx * dx + dy * dy + dz * dz + PLANCK_LENGTH_SQ;
            float r = sqrt(r2);
            float th = atan2(dy, dx);
            float phi = acos(clamp(dz / r, -1.0f, 1.0f)); // Polar angle [0, pi]
            
            float m_f = float(voices[vi].m);
            float n_f = float(voices[vi].n);

            // Phase 4: Dynamic Heaviness (E=mc^2)
            float localEnergy = (voices[vi].frequency * amp) / (r2 * 0.5f + 1.0f);
            massAdd += localEnergy * 0.005f; 

            // Emitters induce a strong coherent spin field (B-field)
            float spinMag = amp * 50.0f * (m_f == 0.0f ? 1.0f : sign(m_f));
            float3 emitterSpin = float3(
                sin(n_f * th) * spinMag * 0.5f, 
                cos(n_f * th) * spinMag * 0.5f, 
                spinMag * cos(m_f * r * 0.1f)
            );
            float3 rVec = float3(dx, dy, dz);
            
            // Biot-Savart induced velocity
            float3 inducedV = cross(emitterSpin, rVec) / (r2 * r);
            shiftVx += inducedV.x * 0.15f;
            shiftVy += inducedV.y * 0.15f;
            shiftVz += inducedV.z * 0.1f;

            // Phase 4 & 12: Mechanical Point Source Impulse + Shockwaves
            // Base impulse uses deltaAmp (transient-only), not raw amp.
            // This prevents continuous outward push during sustain.
            float pushRadius = 2.0f;
            if (r < pushRadius) {
                float3 radialDir = float3(dx / r, dy / r, dz / r);
                float impulseForce = voices[vi].deltaAmp * 80.0f * (1.0f - r / pushRadius);

                float densityScale = 1.0f / max(0.1f, u.plateRadius / 400.0f);
                float shockwave = voices[vi].deltaAmp * 400.0f * (1.0f - r / pushRadius) * densityScale;
                impulseForce += shockwave;
                
                shiftVx += radialDir.x * impulseForce;
                shiftVy += radialDir.y * impulseForce;
                shiftVz += radialDir.z * impulseForce;
                
                currentTemp += voices[vi].deltaAmp * 2.0f;
            }

            // ── The Atom Model (Gradient-Driven Harmonic Sculpting) ────────
            float Y_here  = cos(m_f * th) * sin(n_f * phi);
            float Y_dth   = cos(m_f * (th + 0.02f)) * sin(n_f * phi);
            float Y_dphi  = cos(m_f * th) * sin(n_f * (phi + 0.02f));
            
            float dYdth  = (Y_dth - Y_here) / 0.02f;
            float dYdphi = (Y_dphi - Y_here) / 0.02f;
            
            float3 thetaDir = float3(-sin(th), cos(th), 0.0f);
            float sinPhi = sin(phi);
            float3 phiDir = float3(cos(th)*cos(phi), sin(th)*cos(phi), -sinPhi);
            
            float acMod = 1.0f + 0.3f * sin(voices[vi].frequency * u.time * 0.1f + voices[vi].phase);
            float visualAmp = pow(amp, 0.4f); 
            float sculptStrength = visualAmp * voices[vi].alpha * 25.0f * acMod * polyNorm;
            
            shiftVx += (dYdth * thetaDir.x + dYdphi * phiDir.x) * sculptStrength;
            shiftVy += (dYdth * thetaDir.y + dYdphi * phiDir.y) * sculptStrength;
            shiftVz += (dYdth * thetaDir.z + dYdphi * phiDir.z) * sculptStrength;

            // Track dominant band for per-band coloring
            float fMag = abs(dYdth) + abs(dYdphi);
            if (fMag * amp > bestForce) {
                bestForce = fMag * amp;
                bestBand = voices[vi].bandGroup;
            }

            // Radial breathing
            float radialForce = visualAmp * Y_here * 12.0f * polyNorm;
            float3 centerVec = float3(px, py, pz);
            float cLen = length(centerVec);
            if (cLen > 0.0001f) {
                float3 cDir = centerVec / cLen;
                shiftVx += cDir.x * radialForce;
                shiftVy += cDir.y * radialForce;
                shiftVz += cDir.z * radialForce;
            }

            Y_total += visualAmp * Y_here;
            jitterTotal += visualAmp;
            
            // Phase 18: Accumulate for Chord Webbing
            float Y_w = Y_here * visualAmp;
            sum_Y += Y_w;
            sum_dYdth += dYdth * visualAmp;
            sum_dYdphi += dYdphi * visualAmp;
            sum_Y2 += Y_w * Y_w;
            sum_YdYdth += Y_w * dYdth * visualAmp;
            sum_YdYdphi += Y_w * dYdphi * visualAmp;
        } // end of voice loop

        // Phase 11: String Theory
        dynamicMass += massAdd;

        // ── Phase 18: Chord Webbing (Inter-Harmonic Connectivity) ────────
        if (numVoices > 1) {
            float cross_dYdth = sum_Y * sum_dYdth - sum_YdYdth;
            float cross_dYdphi = sum_Y * sum_dYdphi - sum_YdYdphi;
            
            float3 thetaDir = float3(-sin(atan2(py, px)), cos(atan2(py, px)), 0.0f);
            float r_center = sqrt(px*px + py*py + pz*pz);
            float phi_global = acos(clamp(pz / max(r_center, 0.0001f), -1.0f, 1.0f));
            float3 phiDir = float3(cos(atan2(py, px))*cos(phi_global), sin(atan2(py, px))*cos(phi_global), -sin(phi_global));
            
            float webStrength = 60.0f * polyNorm; 
            shiftVx += (cross_dYdth * thetaDir.x + cross_dYdphi * phiDir.x) * webStrength;
            shiftVy += (cross_dYdth * thetaDir.y + cross_dYdphi * phiDir.y) * webStrength;
            shiftVz += (cross_dYdth * thetaDir.z + cross_dYdphi * phiDir.z) * webStrength;
        }

        // ── Phase 19: Elastic Shell Restoring Force (Staccato Bounce-Back) ──
        // DISABLED — was preventing particles from extending through the sphere.
        // HTML cymatics reference has no shell; shapes flow continuously across
        // the volume, connecting across both sides. Restore by changing `false`
        // back to `!isSilence` if needed.
        if (false) {
            float restingRadius = globalTargetRadius;
            float currentR = sqrt(px*px + py*py + pz*pz);
            if (currentR > 0.001f) {
                float displacement = currentR - restingRadius;
                float3 dir = float3(px, py, pz) / currentR;
                float springStiffness = 50.0f;
                shiftVx -= dir.x * displacement * springStiffness * dt;
                shiftVy -= dir.y * displacement * springStiffness * dt;
                shiftVz -= dir.z * displacement * springStiffness * dt;

                // ── VJ Azimuthal Restoring Force ──────────────────────────────
                // Only during play — prevents lobe sticking when voices drop.
                float3 n = dir;
                int N = u.particleCount;
                float offset_f = 2.0f / (float)N;
                float increment = M_PI_F * (3.0f - sqrt(5.0f));
                float yHome = 1.0f - (2.0f * (float)id + 1.0f) * offset_f * 0.5f;
                float r_xy = sqrt(max(0.0f, 1.0f - yHome * yHome));
                float phiHome = (float)id * increment;
                float3 h = float3(cos(phiHome) * r_xy, yHome, sin(phiHome) * r_xy);
                float3 h_tan = h - dot(h, n) * n;
                float hLen = length(h_tan);
                if (hLen > 0.001f) {
                    h_tan /= hLen;
                    float amp = clamp(u.totalAmplitude, 0.0f, 1.0f);
                    float spreadStrength = (1.0f - amp) * 0.4f;
                    shiftVx += h_tan.x * spreadStrength;
                    shiftVy += h_tan.y * spreadStrength;
                    shiftVz += h_tan.z * spreadStrength;
                }
            }
        }

        // ODS-03: Thermal Energy Evolution
        float targetTemp = clamp(pow(jitterTotal, 0.6f) * 0.8f, 0.0f, 1.5f);
        currentTemp = mix(currentTemp, targetTemp, 0.02f); 
    }

    // ── Noether Symmetry Breaking ─────────────────────────────────────
    // Constantly adds a subtle ambient swirl to prevent perfect dead-center grid-lock if needed
    if (u.symmetryBreakImpulse > 0.0f) {
        float angle = noise(id * 3u, u.time) * M_PI_F;
        float strength = u.symmetryBreakImpulse * (0.1f + noise(id * 7u, u.time) * 0.1f);
        shiftVx += cos(angle) * strength;
        shiftVy += sin(angle) * strength;
    }

    // (Second jitter block removed — temperature-driven jitter above is sufficient)

    // (Schwarzschild gravity replaced by ADSR lifecycle above)

    // ── Particle-Particle Collisions (spatial hash neighbor scan) ─────
    if (u.collisionsOn > 0 && su.gridSize > 0) {
        int cellX = clamp(int((px + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int cellY = clamp(int((py + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int cellZ = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);

        float colRad = u.collisionRadius;
        float colRad2 = colRad * colRad;

        int startCellX = max(0, cellX - 1);
        int endCellX = min(su.gridSize - 1, cellX + 1);
        int startCellY = max(0, cellY - 1);
        int endCellY = min(su.gridSize - 1, cellY + 1);
        int startCellZ = max(0, cellZ - 1);
        int endCellZ = min(su.gridSize - 1, cellZ + 1);

        float orig_px = px;
        float orig_py = py;
        float selfCharge = p.spinW.w;
        
        uint closest_id = p.entanglement.x;
        float min_dist2 = colRad2 * colRad2; // track closest neighbor

        for (int z = startCellZ; z <= endCellZ; z++) {
            for (int y = startCellY; y <= endCellY; y++) {
                for (int x = startCellX; x <= endCellX; x++) {
                    uint cID = uint((z * su.gridSize + y) * su.gridSize + x);
                    uint count = min(cellCounts[cID], uint(MAX_PER_CELL));
                    if (count == 0) continue;
                    uint startIdx = cellStarts[cID];

                    for (uint i = 0; i < count; i++) {
                        Particle np = sortedParticles[startIdx + i];

                        float ddx = orig_px - np.posW.x;
                        float ddy = orig_py - np.posW.y;
                        float ddz = pz - np.posW.z;
                        float dist2 = ddx * ddx + ddy * ddy + ddz * ddz;

                        // ODS-06: Schwarzschild Singularity (Black Hole)
                        // If local density hits critical mass, space collapses.
                        bool isBlackHole = (count >= uint(MAX_PER_CELL) - 1);

                        if (dist2 > colRad2 || dist2 < 1e-12f) continue;

                        float dist = sqrt(dist2);
                        
                        // Phase 14: Collision Optimization
                        // Early exit if we have too many interactions in this frame
                        if (i > 24 && dist > colRad * 0.5f) continue;

                        // Particles heat up significantly on collision
                        currentTemp += 0.03f; 
                        
                        // 1. The Inverse-Square Law (E-Field)
                        // float r2_clamped = max(dist2, 1e-7f); // This line is now part of the new block
                        float q1q2 = selfCharge * np.spinW.w;
                        // float eForce = (u.eFieldStiffness * q1q2) / r2_clamped; // This line is now part of the new block
                        float3 r_vec = float3(ddx, ddy, ddz);
                        float r2 = dist2; // Use dist2 directly
                        Particle p2 = np; // Alias for clarity in new code
                        uint p2_orig_id = p2.entanglement.y;

                        if (r2 > 1e-12f && r2 < min_dist2 && p2_orig_id != id) {
                            min_dist2 = r2;
                            closest_id = p2_orig_id;
                        }

                        if (r2 > 0.00001f) {
                            float r2_clamped = max(r2, 0.0001f);
                            float r = sqrt(r2_clamped);

                            // Coulomb-like electrostatic repulsion analog
                            if (u.debugFlags & (1 << 0)) {
                                float eForce = (u.eFieldStiffness * q1q2) / r2_clamped;
                                
                                // ODS-06: Invert repulsion to infinite attraction at singularity
                                if (isBlackHole) {
                                    eForce = -15.0f / r2_clamped; // Intense collapse
                                    currentTemp *= 0.5f; // Hawking radiation / freezing
                                }
                                
                                float3 fE = normalize(r_vec) * eForce * dt;
                                shiftVx += fE.x; shiftVy += fE.y; shiftVz += fE.z;
                            }

                            // Biot-Savart circulation analog (B-Field)
                            if (u.debugFlags & (1 << 1)) {
                                float3 spin1 = p.spinW.xyz;
                                float3 spin2 = p2.spinW.xyz;
                                float r3 = r2_clamped * r;
                                float3 bForceVec = cross(spin1 + spin2, normalize(r_vec)) * u.bFieldCirculation / r3 * dt;
                                shiftVx += bForceVec.x; shiftVy += bForceVec.y; shiftVz += bForceVec.z;
                            }

                            // Tensegrity Strings (Hooke's Law)
                            if (u.debugFlags & (1 << 3)) {
                                float strain = r - u.restLength;
                                // Negate r_vec: stretched → pull inward, compressed → push outward
                                float3 stringF = normalize(-r_vec) * strain * u.stringStiffness * dt;
                                shiftVx += stringF.x; shiftVy += stringF.y; shiftVz += stringF.z;
                            }

                            // Newtonian Self-Gravity (1/r^2)
                            if (u.debugFlags & (1 << 2)) {
                                float massProd = dynamicMass * p2.posW.w;
                                if (massProd != 0.0f) { // Skip gravity for zero-mass particles (walls)
                                    float gravForce = u.gravityConstant * massProd / r2_clamped;
                                    float3 fG = normalize(-r_vec) * gravForce * dt;
                                    shiftVx += fG.x; shiftVy += fG.y; shiftVz += fG.z;
                                }
                            }

                            // Hard-sphere Elastic Collision
                            if ((u.debugFlags & (1 << 5)) && (u.collisionsOn > 0)) {
                                float minDist = u.collisionRadius * 2.0f;
                                if (r < minDist) {
                                    float overlap = minDist - r;
                                    float3 resolve = normalize(r_vec) * (overlap * 0.5f);
                                    shiftX += resolve.x; shiftY += resolve.y; shiftZ += resolve.z;
                                }
                            }
                        }
                    }
                }
            }
        }

        // Update entanglement to point to closest neighbor
        p.entanglement.x = closest_id;

        // Position correction applied directly
        px += shiftX;
        py += shiftY;
        pz += shiftZ;
        vpx += shiftVx;
        vpy += shiftVy;
        vpz += shiftVz;
    }

    // ── Störmer-Verlet integration (damped) ──────────────────────────
    // Restored natural damping without extra cosmic over-drag.
    // Jitter and collision forces are now visible again.

    // ── Silence force immunity: restore lifecycle-only shifts ──────────────
    if (isSilence) {
        shiftVx = lifecycleShiftV.x; shiftVy = lifecycleShiftV.y; shiftVz = lifecycleShiftV.z;
        shiftX = lifecycleShiftP.x; shiftY = lifecycleShiftP.y; shiftZ = lifecycleShiftP.z;
        if (collapsed) {
            shiftVx = 0.0f; shiftVy = 0.0f; shiftVz = 0.0f;
            vpx = 0.0f; vpy = 0.0f; vpz = 0.0f;
        } else {
            // ── 3B: Ambient Idle State ──────────────────────────────────
            // Gentle motion during silence so particles feel alive, not dead.
            float r_idle = sqrt(px*px + py*py + pz*pz);
            if (r_idle > 0.01f) {
                // 1. Slow rotation around Y axis (~0.1 rad/s)
                float omega = 0.1f * dt;
                float cosO = cos(omega);
                float sinO = sin(omega);
                float newPx = px * cosO + pz * sinO;
                float newPz = -px * sinO + pz * cosO;
                px = newPx;
                pz = newPz;

                // 2. Breathing radius: ±5% at 0.2 Hz
                float breathe = 0.05f * sin(u.time * 0.2f * 2.0f * M_PI_F);
                float3 rDir = float3(px, py, pz) / r_idle;
                shiftVx += rDir.x * breathe * 0.5f * dt;
                shiftVy += rDir.y * breathe * 0.5f * dt;
                shiftVz += rDir.z * breathe * 0.5f * dt;

                // 3. Per-particle turbulence (slowly varying Perlin-like)
                uint slowFrame = u.frameCounter / 8u; // change every 8 frames
                float turbX = noise(id, slowFrame) * 0.02f;
                float turbY = noise(id + 7777u, slowFrame) * 0.02f;
                float turbZ = noise(id + 15555u, slowFrame) * 0.02f;
                shiftVx += turbX;
                shiftVy += turbY;
                shiftVz += turbZ;
            }
        }
    }

    // ── Envelope-Coupled Velocity Damping ──────────────────────────────
    // Release: kill momentum so collapse tracks the envelope fade
    // Sustain: let it breathe — no damping
    if (u.envelopePhase > 3.5f) {
        // Release: kill momentum so collapse tracks the envelope fade
        vpx *= 0.15f;
        vpy *= 0.15f;
        vpz *= 0.15f;
    } else if (u.envelopePhase > 2.5f) {
        // Sustain: HARDEN over hold time. envelopeProgress ramps 0→1 the longer
        // the note is held → damp velocity increasingly so motion slows, the
        // light trails shorten, and the shape sets/crisps in place.
        float harden = mix(1.0f, 0.80f, clamp(u.envelopeProgress, 0.0f, 1.0f));
        vpx *= harden;
        vpy *= harden;
        vpz *= harden;
    }

    // ── VJ Silence Damping ──────────────────────────────────────────────
    // When amplitude drops, apply extra friction so particles return to sphere
    float silence = 1.0f - clamp(u.totalAmplitude, 0.0f, 1.0f);
    if (silence > 0.5f) {
        float extra = mix(1.0f, 0.90f, (silence - 0.5f) * 2.0f);
        vpx *= extra;
        vpy *= extra;
        vpz *= extra;
    }

    // Combine proxy with force pulses
    float3 finalV = float3(vpx, vpy, vpz) * dynamicFric + float3(shiftVx, shiftVy, shiftVz);

    // Speed cap
    float speed = length(finalV);
    if (speed > u.speedCap) {
        finalV = (finalV / max(speed, 0.0001f)) * u.speedCap;
    }

    // Jitter (UI slider — now wired). Per-particle Brownian shimmer added as a
    // small position delta. u.jitterFactor was uploaded all along but never read.
    if (u.jitterFactor > 0.0001f) {
        float3 jit = float3(noise(id, u.frameCounter + 11u),
                            noise(id + 7919u, u.frameCounter + 23u),
                            noise(id + 104729u, u.frameCounter + 37u));
        finalV += jit * (u.jitterFactor * 0.02f);
    }

    // Final position integration
    float3 nextPos = float3(px, py, pz) + finalV;

    // ── BRUNETON-STYLE ANALYTIC ORBITS ──────────────────────────────────
    // Per-particle home orbit (r_home, phi_offset) set at spawn in spinW.
    // At REST (envPhase < 0.5 AND no voice amplitude): position is FULLY
    // analytic — no integration, no drift, no pulse. Particle is exactly
    // on its orbital trajectory at all times.
    // During PLAY: nextPos comes from the integrator (voice forces win) +
    // a small pull back toward analytic so particles don't fully escape.
    {
        float r_home    = p.spinW.x;
        float phi_offset = p.spinW.y;
        if (r_home > 0.001f) {
            // K=4 → ~1.57s period at r=1 (fast enough for strong trails).
            // omega = K/r^1.5 = K · rsqrt(r³) (avoids pow, faster on GPU).
            float r3 = r_home * r_home * r_home;
            float omega = 4.0f * rsqrt(r3);
            float phi   = phi_offset + omega * u.time;
            float3 target = float3(r_home * cos(phi),
                                   r_home * sin(phi),
                                   0.0f);

            float voiceMute = clamp(u.totalAmplitude, 0.0f, 1.0f);
            // Blend toward the analytic home orbit. The OLD code SNAPPED
            // (nextPos = target) the instant amplitude crossed 0.01 — that hard
            // switch was the release "pop" (shape → disk → ring). Now the weight
            // eases CONTINUOUSLY: ~0 during play (voice forces make the shape),
            // then smoothstep up to 1 as the note fades, so particles draw
            // smoothly onto the rest orbits and land exactly at rest (alpha→1,
            // pure analytic, no tug/pulse).
            float toHome = 1.0f - voiceMute;
            float conv = smoothstep(0.6f, 1.0f, toHome); // 0 in play → 1 at rest
            float alpha = max(0.5f * toHome * dt, conv);
            // Spin yields the home-orbit pull: ~0 while spinning, ramping back as
            // the spin coasts down → smooth re-engage (no snap from spin to rest).
            alpha *= spinSuppress;
            nextPos = mix(nextPos, target, alpha);
        }
    }

    // ── DIRECT ENVELOPE→RADIUS COUPLING ──────────────────────────────
    // DISABLED — every-frame radial blend toward globalTargetRadius was
    // preventing particles from extending through the sphere. HTML cymatics
    // lets particles flow freely. Restore by changing `false` to
    // `!collapsed && !isSilence` if needed.
    if (false) {
        float nextR = length(nextPos);
        if (nextR > 0.001f) {
            float3 dir = nextPos / nextR;

            if (u.envelopePhase < 1.5f) {
                // Attack: blend toward expanding target
                float blendedR = mix(nextR, globalTargetRadius, 0.25f);
                nextPos = dir * blendedR;
                finalV *= 0.75f;
            } else if (u.envelopePhase < 3.5f) {
                // Decay/Sustain: soft attractor proportional to amplitude
                // Gentle blend — allows expansion past target but always pulls back
                float blendedR = mix(nextR, globalTargetRadius, 0.05f);
                nextPos = dir * blendedR;
            } else {
                // Release: pull inward, tracking envelope fade
                float blendedR = mix(nextR, globalTargetRadius, 0.25f);
                nextPos = dir * blendedR;
                finalV *= 0.75f;
            }
        }
    }

    // ── BREATHING OUTER RADIUS CAP ──────────────────────────────────────
    // Tight (ORBIT_R_BH) during silence so the disk reads as a tight
    // Saturn-ring around the BH. Expands to ORBIT_R_CHLADNI when notes
    // play — gives Bessel voice forces room to push particles into the
    // godlike Chladni pattern. envelopePhase-driven so it tracks the
    // synth ADSR, not ambient amplitude. Phase: 0=silence, 0.5–1.5=
    // attack, 1.5–2.5=decay, 2.5–3.5=sustain, 3.5–4.5=release.
    {
        float ph = u.envelopePhase;
        float cap_t;
        if (ph < 0.5f)        cap_t = 0.0f;                                  // silence
        else if (ph < 1.5f)   cap_t = ph - 0.5f;                             // attack
        else if (ph < 3.5f)   cap_t = 1.0f;                                  // decay/sustain
        else                  cap_t = 1.0f - clamp(u.envelopeProgress, 0.0f, 1.0f); // release: ramp CHLADNI→BH (ph is a constant 4.0, so use progress, not ph-3.5)
        float dynamic_cap = mix(ORBIT_R_BH, ORBIT_R_CHLADNI, cap_t);
        // Yield the cap while spinning — otherwise the tumbling body periodically
        // hits the XY cap and gets yanked, flickering between two states.
        dynamic_cap += (1.0f - spinSuppress) * 8.0f;
        float rXY2 = nextPos.x * nextPos.x + nextPos.y * nextPos.y;
        if (rXY2 > dynamic_cap * dynamic_cap) {
            float rXY = sqrt(rXY2);
            float scale = dynamic_cap / rXY;
            nextPos.x *= scale;
            nextPos.y *= scale;
            float2 radialDir = float2(nextPos.x, nextPos.y) * (1.0f / dynamic_cap);
            float vRad = finalV.x * radialDir.x + finalV.y * radialDir.y;
            if (vRad > 0.0f) {
                finalV.x -= vRad * radialDir.x;
                finalV.y -= vRad * radialDir.y;
            }
        }
    }

    // Phase accumulation — decode prior phase first; p.velW.w is packed bits.
    speed = length(finalV);
    float newPhase = decodePhase(p.velW.w) + speed * dt;

    // ── ODS-04: Dimming My Light (Stealth / ANC) ───────────────────────────
    if (u.debugFlags & (1 << 9)) {
        // Define the "User" cluster (~5% of particles)
        if ((id % 20) == 0) {
            // Active Noise Cancelling: Destructive interference by phase inversion
            newPhase = decodePhase(p.velW.w) + M_PI_F; // +π = inverted; wrapped at pack
            
            // Absolute Energy Damping: Absorb incoming force without moving
            finalV = float3(0.0f);
            
            // Optical Stealth: Negative temperature kills HDR emission, rendering them black
            currentTemp = -5.0f;
        }
    }

    // ── ODS-01: Quantum Entanglement (Telepathy) ──────────────────────────────────
    if (u.debugFlags & (1 << 7)) { // Reserved bit 7 for ODS-01
        uint partnerID = p.entanglement.x;
        if (partnerID < (uint)u.particleCount) {
            float partnerTemp = prevParticles[partnerID].prevW.w;
            // Telepathic state transfer (instant action at a distance)
            if (partnerTemp > currentTemp) {
                currentTemp = mix(currentTemp, partnerTemp, 0.2f * dt); // Absorb heat
                newPhase = mix(newPhase, decodePhase(prevParticles[partnerID].velW.w), 0.1f * dt); // Phase sync
            }
        }
    }

    // ── USER SPIN: rotate the whole body by the spin torque (radius-preserving
    // so it stays a solid shape at any RPM). prevW stays the pre-spin position,
    // so the velocity proxy carries the rotation → light trails show the spin.
    {
        float3 preRot = nextPos;
        float aY = u.spinY * dt;            // around Y (left/right)
        if (aY != 0.0f) {
            float c = cos(aY), s = sin(aY);
            float nx =  nextPos.x * c + nextPos.z * s;
            float nz = -nextPos.x * s + nextPos.z * c;
            nextPos.x = nx; nextPos.z = nz;
        }
        float aX = u.spinX * dt;            // around X (up/down)
        if (aX != 0.0f) {
            float c = cos(aX), s = sin(aX);
            float ny = nextPos.y * c - nextPos.z * s;
            float nz = nextPos.y * s + nextPos.z * c;
            nextPos.y = ny; nextPos.z = nz;
        }
        // Fold the rotational displacement into the stored velocity so the
        // per-particle light trails (velDir2D) show the SPIN — otherwise it's a
        // rigid rotation with no trails and reads like a stuck camera.
        finalV += (nextPos - preRot);

        // RADIUS-SHELL LOCK while spinning. The fold above is re-integrated as
        // translation next frame, which pushes each particle off its circle
        // onto a slightly larger radius every frame → an outward tangent-drift
        // spiral that piles up against the cap (~11) → the "square brick wall"
        // clipped by the viewport at high RPM. Locking each particle back to
        // its own radius (the pre-integration distance) makes the whole body
        // rotate as a RIGID geometric shape — consistent at any speed.
        // Gated on spin: 0 at rest (no change), full at high RPM.
        float spinLock = 1.0f - spinSuppress;
        if (spinLock > 0.001f) {
            float r0 = length(float3(px, py, pz));
            float rN = length(nextPos);
            if (rN > 1e-4f) {
                float3 locked = nextPos * (r0 / rN);
                nextPos = mix(nextPos, locked, spinLock);
            }
        }
    }

    // ── Write back ───────────────────────────────────────────────────
    if (mass > 0.0f) {
        p.prevW = float4(px, py, pz, currentTemp);
        p.posW = float4(nextPos, mass);
        // Wrap phase into [0, 2π) before packing — a clamp here saturated every
        // particle to phaseBits=max → identical hue. fmod can return negative,
        // so add a turn to land in [0, 2π).
        float wrapped = fmod(newPhase + M_PI_F, 2.0f * M_PI_F);
        if (wrapped < 0.0f) wrapped += 2.0f * M_PI_F;
        // Pack band ID (3 bits) into upper bits of phase float
        uint phaseBits = (uint)((wrapped / (2.0f * M_PI_F)) * (float)0x1FFFFFFFu);
        uint bandBits = (uint)(bestBand & 0x7);
        uint packed = (bandBits << 29) | phaseBits;
        p.velW = float4(finalV, as_type<float>(packed));
    }
}

// ── Conservation law reduction kernel ───────────────────────────────────────

struct PartialStats {
    float kineticEnergy;
    float momentumX;
    float momentumY;
    float pad;
    float sumTemp;   // Σ temperature (→ avg)
    float maxTemp;   // max temperature
    float sumSpeed;  // Σ |v| (→ avg)
    float maxSpeed;  // max |v|
};

kernel void reduce_stats(
    device const Particle* particles [[buffer(0)]],
    device PartialStats* partialSums [[buffer(1)]],
    constant PhysicsUniforms& u [[buffer(2)]],
    uint id [[thread_position_in_grid]],
    uint tid [[thread_position_in_threadgroup]],
    uint tgSize [[threads_per_threadgroup]],
    uint tgId [[threadgroup_position_in_grid]])
{
    threadgroup float sharedKE[256];
    threadgroup float sharedMX[256];
    threadgroup float sharedMY[256];
    threadgroup float sharedST[256];  // sum temp
    threadgroup float sharedMT[256];  // max temp
    threadgroup float sharedSS[256];  // sum speed
    threadgroup float sharedMS[256];  // max speed

    float ke = 0.0f, mx = 0.0f, my = 0.0f;
    float temp = 0.0f, speed = 0.0f;
    bool real = false;

    if (int(id) < u.particleCount) {
        float mass = particles[id].posW.w;
        float vx = particles[id].velW.x;
        float vy = particles[id].velW.y;
        float vz = particles[id].velW.z;
        ke = 0.5f * mass * (vx * vx + vy * vy + vz * vz);
        mx = mass * vx;
        my = mass * vy;
        if (mass > 0.001f) {                 // skip wall particles
            temp  = particles[id].prevW.w;   // temperature field
            speed = sqrt(vx*vx + vy*vy + vz*vz);
            real  = true;
        }
    }

    sharedKE[tid] = ke;
    sharedMX[tid] = mx;
    sharedMY[tid] = my;
    sharedST[tid] = real ? temp : 0.0f;
    sharedMT[tid] = real ? temp : -1e9f;
    sharedSS[tid] = real ? speed : 0.0f;
    sharedMS[tid] = real ? speed : -1e9f;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = tgSize / 2; stride > 0; stride >>= 1) {
        if (tid < stride) {
            sharedKE[tid] += sharedKE[tid + stride];
            sharedMX[tid] += sharedMX[tid + stride];
            sharedMY[tid] += sharedMY[tid + stride];
            sharedST[tid] += sharedST[tid + stride];
            sharedSS[tid] += sharedSS[tid + stride];
            sharedMT[tid]  = max(sharedMT[tid], sharedMT[tid + stride]);
            sharedMS[tid]  = max(sharedMS[tid], sharedMS[tid + stride]);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0) {
        partialSums[tgId].kineticEnergy = sharedKE[0];
        partialSums[tgId].momentumX = sharedMX[0];
        partialSums[tgId].momentumY = sharedMY[0];
        partialSums[tgId].sumTemp  = sharedST[0];
        partialSums[tgId].maxTemp  = sharedMT[0];
        partialSums[tgId].sumSpeed = sharedSS[0];
        partialSums[tgId].maxSpeed = sharedMS[0];
    }
}
