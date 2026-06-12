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
    float massTotal;             // 92: Σ stellar mass of the field, M_sun
    float diskThickness;         // 96: accretion-disk vertical thickness (UI)
    float spinX;                 // 100: user spin torque around X axis (rad/s)
    float spinY;                 // 104: user spin torque around Y axis (rad/s)
    float bondNetworkOn;         // 108: >0.5 = bond-find nearest neighbour in sustain

    // ═══ SELF-GRAVITY (emergent BH, Step 1) ═══
    float comX;                  // 112: live-mass centre of mass (reduce_stats, 1-frame lag)
    float comY;                  // 116
    float comZ;                  // 120
    float gravGM;                // 124: G_sim·M_total — 0 disables self-gravity

    // ═══ EMERGENT-BH SIGNAL (Step 2) ═══
    float bhX;                   // 128: densest-region position (1-frame lag)
    float bhY;                   // 132
    float bhZ;                   // 136
    float bhMass;                // 140: stars enclosed within R_ENC of bh pos
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

// Bit-level non-finite test (exponent all-ones ⇒ inf or NaN). Metal compiles
// with fast-math, which makes isnan()/isinf() unreliable — integer bits don't
// lie and can't be optimized away.
static bool notFinite3(float3 v) {
    uint3 b = as_type<uint3>(v);
    return any(((b >> 23) & 0x000000FFu) == 0x000000FFu);
}
static bool notFinite1(float v) {
    uint b = as_type<uint>(v);
    return ((b >> 23) & 0x000000FFu) == 0x000000FFu;
}

// Collision constants
constant int MAX_PER_CELL = 128; // Read-site SCAN clamp only: bounds the
                                  // neighbor-loop iteration count so a hot
                                  // cell can't stall the GPU. cellCounts
                                  // itself is UNCAPPED (count_cells in
                                  // spatial_hash.metal) — it is the cell MASS
                                  // for self-gravity and must stay honest.

// Phase 11.3: Planck-length softening (regularizes point-particle infinities)
constant float PLANCK_LENGTH_SQ = 0.0001f; // Minimum interaction distance²

// ── Stellar scale + FATE LADDER constants (used by physics, merge, seeds) ───
// 1 R_sun in sim units (6.96e8 m / 1.269e10 m, the Sgr A* anchor).
constant float MERGE_RSUN_SIM = 0.0549f;
// The Kroupa draw tops out at 50 M_sun, so any body ABOVE it can only be a
// merger product — and a merger remnant that heavy collapses: it IS a black
// hole (single-scalar mass→fate, physics canon). Seeds are dark (render
// culls them except while flaring) and grow ONLY via victim-initiated
// feeding. Must match the 50.0f in render.metal's dark-cull.
constant float M_BH_SEED = 50.0f;

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
constant float STAR_MAP_CAP    = 100.0f; // silence: NO cap (the star map has no tube limit)

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
    device const float4* cellCentroids [[buffer(8)]],
    device const float4* cellVelocities [[buffer(9)]],
    device const uint* cellMass [[buffer(10)]],   // Σ M_sun ×64 per cell (count_cells)
    device const uint* cellSeedMap [[buffer(11)]],   // 0=none, else seed slot+1
    device const uint* seedIds [[buffer(12)]],       // registry (count_cells)
    device atomic_uint* seedAccum [[buffer(13)]],    // per-slot meal accumulator
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
    // friction makes them spiral in. pow(0.9, dt) ≈ 0.9991/frame still
    // e-folds velocity in ~9.5 s — fine for play (voice forces dominate,
    // damping prevents runaway), but at REST it kills orbits long before one
    // period completes, reducing self-gravity to terminal-velocity creep.
    // Rest friction is therefore near-conservative: pow(0.997, dt) e-folds in
    // ~5.5 min, so stars complete orbits and the gentle drag IS the accretion
    // mechanism (slow inspiral toward the mass centre — the dynamical-friction
    // analog). Blend by amplitude: rest → conservative, play → damped.
    float fricPlay = pow(0.9f, dt);
    // 0.99/s (e-fold ~100 s): conservative enough that inner orbits complete
    // (period 19 s at r=3), dissipative enough to (a) damp the grid-binning
    // force noise that otherwise slowly HEATS the map outward (measured:
    // +0.19 sim/s drift at pow(0.997,dt)) and (b) drive the visible inspiral
    // — the dynamical-friction analog that makes the untouched galaxy accrete.
    float fricRest = pow(0.99f, dt);
    float baseFric = mix(fricRest, fricPlay,
                         clamp(u.totalAmplitude * 4.0f, 0.0f, 1.0f));
    // RELEASE = heavy-drag inspiral. Physically: the post-supernova gas is
    // shocked and dissipative — orbital energy bleeds off fast while the
    // orbital DIRECTION (angular momentum) is untouched, so matter visibly
    // spirals onto the hole over ~tens of seconds and settles into the disk.
    // This drag (e-fold ~20 s) replaces the deleted scripted collapse.
    if (u.envelopePhase > 3.5f) baseFric = pow(0.95f, dt);

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

            // 1. GRAVITY — DISABLED AT REST. There is NO black-hole gravity before
            // a note is played. The rest state is the full STAR MAP (the box spawn,
            // particles.cpp L=42), held only by the gentle particle↔particle
            // cohesion + SPH pressure later in this kernel (which run every phase).
            // A central pull-to-origin here (the old G=100) instantly balled the
            // whole galaxy into a hole — exactly what we DON'T want at rest. The
            // hole must EMERGE from mass clumping (cohesion) over time, or from the
            // release collapse, never from a hardcoded central attractor.

            // 1b. Z-PLANE DAMPING — DISABLED. It flattened the star map into a thin
            // disk (the accretion-disk look). The rest state is a 3D star map, not
            // a disk; no z-confinement.

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

            // 5. HAWKING RADIATION — DISABLED AT REST. In the emergent model
            // there is NO black hole at rest, so nothing radiates: this block
            // was per-frame velocity noise on every particle inside r<2.3,
            // a random walk that (now that rest is undamped for orbits)
            // evaporates exactly the central region where infalling mass must
            // settle to build the hole. Re-introduce later keyed to the
            // EMERGENT bhStrength (Step 3), not to the rest phase.

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

    // ESCAPER RECYCLE — closes the energy budget. The old "snapback"
    // (pos ×0.5, outward velocity KEPT) made runaways ping-pong in shells
    // at r≈500-1000: the glowing line/wall on screen. Now an escaper
    // re-enters the simulation as fresh COLD infall at its star-map home —
    // mass conserved, the note's escape energy is removed (radiated), and
    // the recycled star becomes food for the hole.
    if (r_curr > 1000.0f) {
        float r_home = p.spinW.x;
        float theta  = as_type<float>(p.entanglement.z);
        float aphi   = as_type<float>(p.entanglement.w);
        float st = sin(theta);
        float3 home = r_home * float3(st * cos(aphi), st * sin(aphi), cos(theta));
        p.prevW = float4(home, 0.0f);   // cold
        p.posW  = float4(home, mass);
        p.velW  = float4(0.0f);
        return;
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
        // Clamp to the old 128 cap: cellCounts is uncapped now, and the flare
        // stress/temp tuning (log2 ramp 0..~2.7) was built against capped
        // counts — an uncapped 50k cell would flash 11× the intended burst.
        uint ecount = min(cellCounts[ecID], uint(MAX_PER_CELL));
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

    // ── SEED SINK — mass segregation, the express lane ───────────────────────
    // A body 100-1000× the field-star mass sinks to the potential minimum on
    // a dynamical time (Chandrasekhar friction ∝ M — far beyond the resolved
    // drag's stability cap). The minimum is the PINNED ORIGIN by design, so
    // seeds get a bounded spring + velocity damping straight to the centre —
    // measured failure without it: seeds orbited just off the knot, their
    // capture sphere grazed its edge, Mmax froze at ~105 while thousands of
    // stars piled at origin. The seed parks at the centre; the disk spins
    // around it.
    if (mass >= M_BH_SEED && mass < 1e8f) {
        float3 toO = -float3(px, py, pz);
        float3 kick = toO * (0.3f * dt);
        float kl = length(kick);
        if (kl > 0.01f) kick *= 0.01f / kl;          // bounded spring
        // HARD damping: a fast seed overshot the bounded spring and
        // slingshotted — a bright accretion point + trail ribbon roaming
        // the screen as a dotted beam (measured/screenshot). The hole
        // parks; it does not zip across the galaxy.
        float vdamp = min(2.5f * dt, 0.2f);
        shiftVx += kick.x - vpx * vdamp;
        shiftVy += kick.y - vpy * vdamp;
        shiftVz += kick.z - vpz * vdamp;
    }

    // ── BLACK-HOLE CAPTURE — victim-initiated accretion (step 3 v2) ──────────
    // If a registered seed is marked in one of my 27 neighbour cells and I'm
    // inside its capture radius (tidal + gravitational focusing), I am eaten:
    // I add my exact mass to the seed's accumulator and die, this thread, no
    // races. Seeds themselves and walls don't get eaten.
    if (su.gridSize > 0 && mass > 0.001f && mass < M_BH_SEED &&
        !(u.envelopePhase >= 0.5f && u.envelopePhase < 1.5f) &&
        fabs(px) < su.halfExtent && fabs(py) < su.halfExtent &&
        fabs(pz) < su.halfExtent) {
        int kcx = clamp(int((px + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int kcy = clamp(int((py + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int kcz = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        for (int z = max(0, kcz - 1); z <= min(su.gridSize - 1, kcz + 1); z++) {
            for (int y = max(0, kcy - 1); y <= min(su.gridSize - 1, kcy + 1); y++) {
                for (int x = max(0, kcx - 1); x <= min(su.gridSize - 1, kcx + 1); x++) {
                    uint cID = uint((z * su.gridSize + y) * su.gridSize + x);
                    uint slot = cellSeedMap[cID];
                    if (slot == 0u) continue;
                    uint sid2 = seedIds[slot - 1u];
                    if (sid2 == id || sid2 >= uint(u.particleCount)) continue;
                    float mS = particles[sid2].posW.w;
                    if (mS < M_BH_SEED || mS >= 1e8f) continue;
                    float3 sp = particles[sid2].posW.xyz;
                    if (notFinite3(sp)) continue;
                    float3 dS = float3(px, py, pz) - sp;
                    float dS2 = dot(dS, dS);
                    float rt2;
                    if (mS > 5000.0f) {
                        // FORMED-HOLE REGIME: only the PLUNGE ZONE (~3 r_s)
                        // swallows instantly. Matter in the tidal zone gets
                        // DISRUPTED, not eaten — the debris keeps its angular
                        // momentum and ORBITS: that is the accretion disk.
                        // With tidal capture all the way up (capped 1.4 sim),
                        // the hole vacuumed its own disk region — "no disk,
                        // just a few particles around a black screen".
                        float rs = mS * 2.327e-7f;   // Schwarzschild, sim units
                        float rc = max(3.0f * rs, 0.02f);
                        rt2 = rc * rc;
                    } else {
                        // GROWTH REGIME (small seed): tidal radius + grav
                        // focusing — slow passers-by captured from far beyond
                        // contact; this is what powers the runaway to forming.
                        float rt = 1.5f * MERGE_RSUN_SIM * pow(mass, 0.8f) *
                                   pow(mS / mass, 1.0f / 3.0f);
                        float3 dvS = (float3(vpx, vpy, vpz) -
                                      (sp - particles[sid2].prevW.xyz)) * 120.0f;
                        float vrel2 = max(dot(dvS, dvS), 1e-4f);
                        float G1s = u.gravGM / max(u.massTotal, 1.0f);
                        rt2 = rt * rt + rt * (2.0f * G1s * mS) / vrel2;
                        float reach = 1.4f * su.cellSize;
                        rt2 = min(rt2, reach * reach);
                    }
                    if (dS2 >= rt2) continue;
                    // EATEN: exact mass to the seed's plate, then die parked.
                    atomic_fetch_add_explicit(&seedAccum[(slot - 1u) * 4u + 0u],
                                              uint(mass * 64.0f + 0.5f),
                                              memory_order_relaxed);
                    atomic_fetch_add_explicit(&seedAccum[(slot - 1u) * 4u + 1u],
                                              1u, memory_order_relaxed);
                    float park = 4000.0f + float(id % 1024);
                    p.posW = float4(park, park, park, 0.0f);
                    p.prevW = float4(park, park, park, p.prevW.w);
                    return;
                }
            }
        }
    }

    // ── SELF-GRAVITY (always-on, EVERY phase — the emergent-BH engine) ───────
    // Real Newtonian gravity replaces the old cohesion spring: every star falls
    // toward the rest of the mass, so the galaxy accretes on its own — no note
    // required, no phase gate, no scripted central attractor. Stars collide,
    // clump, and the centre piles up until the density itself births the hole.
    // Barnes-Hut style split on the existing O(N) grid (no pairwise scan):
    //   NEAR = the 3×3×3 neighbour cells, each a point mass at its sampled
    //          centroid (local clumping — star↔star attraction). Cell mass is
    //          cellMass — the UNCAPPED Σ of REAL per-star IMF masses in M_sun
    //          (count_cells, fixed-point ×64), so piled-up mass really pulls
    //          harder and a heavy star counts for what it weighs (the
    //          centroid's .w still caps at 32 samples; only the POSITION is
    //          sampled, the mass is exact).
    //   FAR  = the rest of the galaxy as ONE monopole at the global COM
    //          (mass-weighted, from reduce_stats, 1-frame lag), near cells
    //          subtracted so mass isn't counted twice.
    // Stars carry their REAL Kroupa-IMF mass in posW.w (mean ≈ 0.30 M_sun);
    // u.massTotal = Σ masses and gravGM = gmSim(massTotal), both derived from
    // the Sgr A* anchor (units.h). Plummer ε² softening for numerics only.
    // MUST run BEFORE the lifecycle capture below — the silence-immunity
    // restore wipes everything after it, and gravity must act at rest.
    if (mass > 0.001f && mass < 1e8f && u.gravGM > 0.0f) {  // incl. BH seeds
        float Mtot = max(u.massTotal, 1.0f);
        float G1   = u.gravGM / Mtot;            // GM of ONE solar mass
        float3 gpos = float3(px, py, pz);
        float3 gacc = float3(0.0f);

        // NEAR field. Skip during attack (hash not rebuilt there → stale
        // centroids) and outside the hash extent (binning clamps to edge
        // cells, meaningless for this particle → monopole only).
        float nearM = 0.0f;
        float3 nearMP = float3(0.0f);
        bool hashFresh = !(u.envelopePhase >= 0.5f && u.envelopePhase < 1.5f);
        if (su.gridSize > 0 && hashFresh &&
            fabs(px) < su.halfExtent && fabs(py) < su.halfExtent &&
            fabs(pz) < su.halfExtent) {
            int gcx = clamp(int((px + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
            int gcy = clamp(int((py + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
            int gcz = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
            float softN = 4.0f * su.cellSize * su.cellSize;  // ε² ≈ (2·cell)²
            for (int z = max(0, gcz - 1); z <= min(su.gridSize - 1, gcz + 1); z++) {
                for (int y = max(0, gcy - 1); y <= min(su.gridSize - 1, gcy + 1); y++) {
                    for (int x = max(0, gcx - 1); x <= min(su.gridSize - 1, gcx + 1); x++) {
                        uint cID = uint((z * su.gridSize + y) * su.gridSize + x);
                        // True cell mass in M_sun (fixed-point ×64 → float)
                        float cm = float(cellMass[cID]) * (1.0f / 64.0f);
                        if (cm < 0.04f) continue;            // < half a red dwarf
                        float3 cpos = cellCentroids[cID].xyz;
                        if (notFinite3(cpos)) continue;      // poisoned cell: don't ingest
                        nearM  += cm;
                        nearMP += cpos * cm;
                        float3 toC = cpos - gpos;
                        float  d2  = dot(toC, toC) + softN;
                        gacc += toC * (G1 * cm * rsqrt(d2) / d2); // GM_c/(d²+ε²)^1.5
                    }
                }
            }
        }

        // FAR field: everything not in the near cells, as one monopole.
        float farM = max(Mtot - nearM, 0.0f);
        if (farM > 0.5f) {
            float3 farCom = (float3(u.comX, u.comY, u.comZ) * Mtot - nearMP) / farM;
            float3 toC = farCom - gpos;
            float  d2  = dot(toC, toC) + 0.25f;              // ε² far (horizon scale)
            gacc += toC * (G1 * farM * rsqrt(d2) / d2);
        }

        // dt² — NOT the usual force convention here. shiftV is a PER-FRAME
        // displacement, so a real acceleration [sim/s²] adds a·dt² per frame.
        // The other forces' `a·dt` makes their labels ~1/dt (120×) stronger
        // than written; gravity must be in REAL units so gravGM calibrates
        // physically (and so the Step-5 Sgr A* anchor lands on honest maths).
        // Measured failure without this: GM=3 acted like GM≈360 → radial
        // plunge at ~38 sim/s through the soft core → slingshot heating →
        // the whole star map inflated 4× within seconds.
        //
        // ACCELERATION BOUND: when play/release crushes all 2M stars into a
        // few grid cells, per-cell masses hit ~10⁶ and the near-field force
        // explodes the integrator (measured: post-note silence → exponential
        // velocity growth → NaN positions). Bound the per-frame kick well
        // below the softening scale so extreme density can't pump energy.
        // Division-free per-component clamp. The norm-scale version
        // (gkick *= MAX/len) manufactured NaN (inf · MAX/inf = NaN) and the
        // COM reduce then spread it to every star — the all-black field.
        // clamp() cannot create NaN from a finite/inf input.
        const float GKICK_MAX = 0.005f;   // sim units/frame, ≪ ε
        float3 gkick = clamp(gacc * (dt * dt), -GKICK_MAX, GKICK_MAX);
        shiftVx += gkick.x;
        shiftVy += gkick.y;
        shiftVz += gkick.z;
    }

    // ── COLLISIONAL RELAXATION (always-on — the ACCRETION-DISK force) ────────
    // Dense matter is collisional: stars/gas in a crowded cell exchange
    // momentum until their RANDOM motions thermalize away, while the bulk
    // flow (net rotation = angular momentum) survives. Numerically: relax
    // each star's velocity toward its cell's MEAN velocity, rate ∝ density.
    // Per-cell momentum is conserved exactly (every member relaxes toward
    // the shared mean by the same fraction), so rotation is untouched —
    // dispersion dies, and the gathered ball around the hole settles into a
    // thin rotating DISK in the plane ⊥ its angular momentum. This is how a
    // real accretion disk forms (energy dissipates, L conserved) — physics,
    // not a render aesthetic. Sparse regions (< ~16/cell) feel nothing.
    // Must sit BEFORE the lifecycle capture so it acts at rest.
    if (mass > 0.001f && mass < 1e8f && su.gridSize > 0 &&  // incl. BH seeds
        !(u.envelopePhase >= 0.5f && u.envelopePhase < 1.5f) && // attack: hash stale
        fabs(px) < su.halfExtent && fabs(py) < su.halfExtent &&
        fabs(pz) < su.halfExtent) {
        int rcx = clamp(int((px + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int rcy = clamp(int((py + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int rcz = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        uint rcID = uint((rcz * su.gridSize + rcy) * su.gridSize + rcx);
        float cnt = float(cellCounts[rcID]);
        if (cnt >= 2.0f) {
            float3 vMean = cellVelocities[rcID].xyz;
            if (!notFinite3(vMean)) {
                // CONTINUOUS in density — no activation cliff. The old
                // smoothstep(16,128) floor was why the post-release remnant
                // wobbled forever: at 1-2 stars/cell dissipation was exactly
                // zero, bound orbits never shrank, and the density needed to
                // wake the sink could never build (chicken-and-egg). Real
                // two-body relaxation has no threshold — its RATE just scales
                // with density (∝ n·σ·v). rate = (cnt/128)·2/s, capped at
                // 2/s: ~0.03/s e-fold in the diffuse remnant (visible sinking
                // within a minute) → runaway as density grows → core collapse
                // → contact mergers → the hole. Needs ≥2 stars (a cell's own
                // mean is a no-op for its only member). Per-cell momentum
                // conserved exactly, as before — rotation survives, random
                // motion thermalizes into the disk.
                float relax = min(cnt * (1.0f / 128.0f), 1.0f) * (2.0f * dt);
                // DYNAMICAL FRICTION / MASS SEGREGATION — the accretion
                // accelerator. Chandrasekhar drag scales LINEARLY with the
                // body's mass: a heavy body dumps its orbital energy into
                // the light background and SINKS to the core — how real
                // massive black holes reach their food. (Measured failure
                // without it: seeds born in the knot coasted off and
                // starved alone — probe read cnt=1, no candidates in
                // reach.) Normalized at the IMF mean (dwarfs unchanged),
                // capped ×8 to stay integrator-safe.
                relax *= clamp(mass * (1.0f / 0.3f), 1.0f, 8.0f);
                float3 dvR = vMean - float3(vpx, vpy, vpz);
                // SPIN-PRESERVING: damp only the RADIAL + VERTICAL parts of
                // the deviation — the TANGENTIAL (orbital, about +Y at the
                // origin-pinned hole) flow survives. Infalling stars keep
                // their angular momentum and spin UP as r shrinks (skater
                // effect) → matter SPIRALS into a fast rotating DISK instead
                // of plunging straight ("spinning pull, not square straight
                // gravity"). Jamal proved the look: fast spin = shadow +
                // rim + streams (2026-06-12 screenshot).
                float rXYt = sqrt(px * px + pz * pz);
                if (rXYt > 1e-4f) {
                    float3 tdir = float3(-pz, 0.0f, px) / rXYt; // orbit about +Y
                    dvR -= tdir * dot(dvR, tdir);   // orbital part untouched
                }
                shiftVx += dvR.x * relax;
                shiftVy += dvR.y * relax;
                shiftVz += dvR.z * relax;
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

    // INERTIA snapshot: the note's sculpt is a FORCE, and F = ma — a star
    // that has eaten its way to 30 M_sun must NOT dance like a red dwarf.
    // The voice block's velocity contribution gets scaled by 1/m below
    // (normalized to the IMF mean 0.3 → the average star feels the old
    // tuning exactly; monsters resist the crush and HOLD THE MIDDLE).
    float3 preVoiceV = float3(shiftVx, shiftVy, shiftVz);

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

    // INERTIA: scale the voice block's velocity contribution by the real
    // mass (see snapshot above). invInertia = 1 for the IMF mean star;
    // a 30 M_sun monster feels ~1% — it stays put at the centre, keeps
    // eating through the note, and the Chladni pattern forms around it.
    if (mass > 0.001f && mass < 1e8f) {
        float invInertia = clamp(0.3f / max(mass, 0.05f), 0.0005f, 1.0f);
        shiftVx = preVoiceV.x + (shiftVx - preVoiceV.x) * invInertia;
        shiftVy = preVoiceV.y + (shiftVy - preVoiceV.y) * invInertia;
        shiftVz = preVoiceV.z + (shiftVz - preVoiceV.z) * invInertia;
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

    // ── Bond-Network: nearest-neighbour link ("nervous system of light") ──
    // Independent of the collisions toggle. In the hardened (sustain) state each
    // particle finds its single closest physical neighbour via the same spatial
    // hash and records that neighbour's ORIGINAL index (carried in .w) into
    // entanglement.z. The render pass draws a 1px light-line self→bond so
    // adjacent particles fuse into continuous matter, closing the micro-gaps.
    // PURE DATA here — no force applied; quantum entanglement (.x) is untouched.
    if (u.bondNetworkOn > 0.5f && su.gridSize > 0 && u.envelopePhase > 2.5f) {
        int bcx = clamp(int((px + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int bcy = clamp(int((py + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int bcz = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);

        // Adjacency scale: ~one cell → only truly touching neighbours bond.
        float best2 = su.cellSize * su.cellSize;
        uint bestOrig = 0xFFFFFFFFu;
        uint selfOrig = p.entanglement.w;

        for (int z = max(0, bcz - 1); z <= min(su.gridSize - 1, bcz + 1); z++) {
            for (int y = max(0, bcy - 1); y <= min(su.gridSize - 1, bcy + 1); y++) {
                for (int x = max(0, bcx - 1); x <= min(su.gridSize - 1, bcx + 1); x++) {
                    uint cID = uint((z * su.gridSize + y) * su.gridSize + x);
                    uint count = min(cellCounts[cID], uint(MAX_PER_CELL));
                    uint startIdx = cellStarts[cID];
                    for (uint i = 0; i < count; i++) {
                        Particle np = sortedParticles[startIdx + i];
                        if (np.entanglement.w == selfOrig) continue; // skip self
                        float dx = px - np.posW.x;
                        float dy = py - np.posW.y;
                        float dz = pz - np.posW.z;
                        float d2 = dx * dx + dy * dy + dz * dz;
                        if (d2 < best2 && d2 > 1e-12f) {
                            best2 = d2;
                            bestOrig = np.entanglement.w;
                        }
                    }
                }
            }
        }
        p.entanglement.z = bestOrig;
    }

    // ── CRYSTALLIZATION: density-driven continuous hardness (US2 transition) ──
    // Local density (cellCounts) + dwell (slow ramp) → per-particle hardness H,
    // stored as float bits in entanglement.y. As H→1 a particle freezes its
    // degrees of freedom (velocity locks below; jitter dies) so a dense region
    // held over TIME crystallizes into a still solid instead of shimmering;
    // sparse (gas) stays free. The continuous gas→solid rung below our
    // critical-density black hole. See [[space-synth-tube-crystallization]].
    float hardness = as_type<float>(p.entanglement.y);
    if (su.gridSize > 0 && u.envelopePhase > 2.5f) {
        int hcx = clamp(int((px + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int hcy = clamp(int((py + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int hcz = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        uint hcID = uint((hcz * su.gridSize + hcy) * su.gridSize + hcx);
        float hTarget = smoothstep(8.0f, 48.0f, float(cellCounts[hcID]));
        hardness += (hTarget - hardness) * min(1.0f, 1.2f * dt); // dwell ~1-2s
    } else {
        hardness += (0.0f - hardness) * min(1.0f, 3.0f * dt);    // relax to gas
    }
    p.entanglement.y = as_type<uint>(hardness);

    // ── COHESION SPRING — REPLACED by real SELF-GRAVITY ──────────────────────
    // The grid cohesion spring (pull toward the 3×3×3 centroid) clumped locally
    // but never accumulated mass to a centre — and it was wiped at rest by the
    // silence-immunity restore anyway. Its job (local clumping) is now done by
    // the NEAR field of the always-on Newtonian self-gravity block above the
    // lifecycle capture, which also survives silence. Same grid, same O(N·27).

    // ── PRESSURE (grid-based SPH, O(N·27), ALWAYS-ON) — the gas force ────────
    // Push each particle DOWN the local density gradient: away from neighbouring
    // cells that are DENSER than its own → toward sparser space. This is the SPH
    // pressure law (density → pressure → −∇P), the real astrophysical gas force.
    // It prevents collapse and makes matter spread/expand/shock like gas, and
    // pairs with cohesion (pull toward centre) → a real fluid whose equilibrium
    // density IS the state. Grid-based (reads precomputed cell centroids, no
    // pairwise loop) → bounded, can't hit the collision wall → safe to be
    // always-on (the replacement for optional pairwise collisions).
    if (su.gridSize > 0) {
        int pcx = clamp(int((px + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int pcy = clamp(int((py + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        int pcz = clamp(int((pz + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
        float selfDensity = cellCentroids[uint((pcz * su.gridSize + pcy) * su.gridSize + pcx)].w;

        float3 pForce = float3(0.0f);
        for (int z = max(0, pcz - 1); z <= min(su.gridSize - 1, pcz + 1); z++) {
            for (int y = max(0, pcy - 1); y <= min(su.gridSize - 1, pcy + 1); y++) {
                for (int x = max(0, pcx - 1); x <= min(su.gridSize - 1, pcx + 1); x++) {
                    uint cID = uint((z * su.gridSize + y) * su.gridSize + x);
                    float4 c = cellCentroids[cID];      // xyz = centre, w = count
                    if (c.w < 0.5f) continue;           // skip empty
                    float dP = c.w - selfDensity;        // neighbour denser?
                    if (dP <= 0.0f) continue;            // only repel from DENSER cells
                    float3 toNb = c.xyz - float3(px, py, pz);
                    float d = length(toNb);
                    if (d > 1e-5f) pForce -= (toNb / d) * dP;  // push away (down-gradient)
                }
            }
        }
        float pStiff = 2.0f;
        shiftVx += pForce.x * pStiff * dt;
        shiftVy += pForce.y * pStiff * dt;
        shiftVz += pForce.z * pStiff * dt;
    }

    // ── COLLAPSE INTO THE BLACK HOLE (release / held-BH state) ───────────────
    // Once a note is let go, the star map falls into the hole under real central
    // gravity (Plummer-softened), SLOWLY — scaled by envelopeProgress, the
    // collapse ramp held by the CPU lifecycle. "Let go → slow collapse into a
    // black hole." Gated to the release/BH phase (>3.5), so rest/play untouched.
    // ALWAYS-ON central gravity → the galaxy self-collapses over time (the BH
    // is the EMERGENT physical sum of the mass falling in, no note required).
    // Release accelerates the collapse. Plummer-softened, gated only by mass>0.
    // Central "black hole" gravity does NOT exist at rest — only after a note is
    // released does the hole pull matter in (the collapse gesture). At rest the
    // ONLY attraction is particle↔particle (the grid cohesion above), which lets
    // mass slowly clump from where it is, NOT pull toward a fake origin/ball.
    // Legacy release-collapse REMOVED (Gstr=8 pull to the ORIGIN, ~120×
    // stronger than labeled in this integrator's units). It was the "whole
    // box falls down" yank and the second L-killer: a pure radial force
    // toward a fixed point erases orbital structure. The always-on
    // self-gravity (above, toward the real centre of mass) is the only
    // attractor now; release just turns the drag up (see baseFric) so the
    // same gravity reads as a watchable spiral-in.

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
        }
        // ── 3B "Ambient Idle State" — REMOVED (it was THE rest-state cheat) ──
        // The old block ran ONLY here (rest), AFTER the force wipe: a scripted
        // Y-rotation applied straight to position, a ±5% "breathing" radius,
        // and per-particle turbulence kicks of ±0.01/frame (no dt, re-rolled
        // every 8 frames). With the rest damper gone the turbulence was a free
        // deterministic velocity random walk — measured: the whole star map
        // ballooned outward at ~30 sim/s, identical curve every run, even with
        // gravity disabled. Rest motion is now REAL: Kepler spawn velocities +
        // always-on self-gravity make the map orbit, clump and accrete.
    }

    // ── Envelope-Coupled Velocity Damping ──────────────────────────────
    // Release: kill momentum so collapse tracks the envelope fade
    // Sustain: let it breathe — no damping
    if (u.envelopePhase > 3.5f) {
        // Release momentum-kill REMOVED (was vp ×= 0.15). It destroyed the
        // angular momentum of everything falling toward the hole, so matter
        // arrived with L≈0 and could only form a dead BALL — never a disk.
        // Release is now a drag-driven gravitational inspiral (see baseFric):
        // |v| decays, the ORBITAL DIRECTION survives, matter spirals in and
        // settles into the accretion disk. Dissipation, not amputation.
    } else if (u.envelopePhase > 2.5f) {
        // Sustain: CRYSTALLIZE by LOCAL hardness (density + dwell), not a global
        // envelope ramp. A dense region held over time has H→1 and locks its
        // velocity hard → it freezes into a still solid; sparse stays mobile
        // (gas). lock = 0.05 at full hardness (loses ~95%/frame). The render
        // spin is a rotation now, so this freezes matter WITHOUT killing trails.
        float lock = mix(1.0f, 0.05f, hardness);
        vpx *= lock;
        vpy *= lock;
        vpz *= lock;
    }

    // ── VJ Silence Damping ──────────────────────────────────────────────
    // When amplitude drops, apply extra friction so particles return to sphere
    // ── Extra silence damping — DISABLED for emergent gravity ───────────────
    // The old ×0.90/frame rest damper froze the map (kills velocity ~10⁻⁶/s),
    // which turned the always-on self-gravity into invisible terminal-velocity
    // creep (measured: ~0.02 sim units of infall in 2 min). Rest must be LIVE:
    // baseFric (pow(0.9, dt) ≈ 0.9991/frame, tuned above for Kepler orbits)
    // is the only damping, so the spawn rotation orbits and the core accretes.

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
        // Amplitude-gated: jitter feeds finalV, which IS next frame's Verlet
        // velocity — at rest (no damping since the rest state went
        // conservative for orbits) it was a free velocity random walk that
        // blew the star map up to 4× its radius within seconds (measured).
        // Shimmer belongs to play, where fricPlay contains it.
        float jitterGate = clamp(u.totalAmplitude * 4.0f, 0.0f, 1.0f);
        finalV += jit * (u.jitterFactor * 0.02f * jitterGate) * (1.0f - hardness); // crystallized matter stops shimmering
    }

    // Final position integration
    float3 nextPos = float3(px, py, pz) + finalV;

    // ── STAR-MAP HOME (fixed 3D point + slow rigid rotation) ─────────────
    // Each star holds a FIXED isotropic 3D home (r_home, theta, phi) set at
    // spawn — a filled cluster, NOT a flat disk orbit. The whole map rotates
    // slowly as a rigid body (calm star-cluster motion). At REST (no voice)
    // position eases fully onto home → no drift, no pulse, the star map.
    // During PLAY: nextPos comes from the integrator (voice forces win) +
    // a small pull back toward home so particles don't fully escape.
    // AT REST: the home-pin is OFF — real gravity governs, so the galaxy
    // self-collapses over time (emergent BH, not a scripted snap). Gated by
    // amplitude: the pin only helps recover the shape while a note sounds.
    if (u.totalAmplitude > 0.005f) {
        float r_home = p.spinW.x;
        if (r_home > 0.001f) {
            float theta = as_type<float>(p.entanglement.z);
            float aphi  = as_type<float>(p.entanglement.w);
            float st = sin(theta), ct = cos(theta);
            float3 home = r_home * float3(st * cos(aphi), st * sin(aphi), ct);
            // Slow rigid rotation of the whole star map about +Y (0.08 rad/s,
            // matches the spawn velocity in particles.cpp).
            float ang = 0.08f * u.time;
            float ca = cos(ang), sa = sin(ang);
            float3 target = float3(home.x * ca + home.z * sa,
                                   home.y,
                                  -home.x * sa + home.z * ca);

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
        float dynamic_cap;
        if (ph < 0.5f)        dynamic_cap = STAR_MAP_CAP;                                       // silence = wide STAR MAP (overflows frame)
        else if (ph < 1.5f)   dynamic_cap = mix(STAR_MAP_CAP, ORBIT_R_CHLADNI, ph - 0.5f);      // attack: stars rush IN toward the Chladni/supernova
        else if (ph < 3.5f)   dynamic_cap = ORBIT_R_CHLADNI;                                    // decay/sustain
        else                  dynamic_cap = STAR_MAP_CAP; // release: NO scripted crush — the
                                                          // collapse onto the hole is gravity's
                                                          // job (drag-driven inspiral), and the
                                                          // XY squeeze was the third L-killer
                                                          // (it erased orbits → ball, no disk)
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

    // ── RADIATIVE COOLING (Stefan-Boltzmann, dE/dt ∝ T⁴) ────────────────────
    // Hot matter radiates its energy away as light → it COOLS, fast when hot,
    // slow when cool (the real T⁴ law). Because it's T⁴ this targets the HOT
    // played/supernova matter (fading blue→red over time = the Crab's evolution)
    // and barely touches the cool ambient disk. Only positive temps cool;
    // stealth's negative temp is left alone. Floored at 0.
    if (currentTemp > 0.0f) {
        float T = currentTemp;
        currentTemp -= dt * 0.0005f * (T * T * T * T);
        currentTemp = max(currentTemp, 0.0f);
    }

    // ── Write back ───────────────────────────────────────────────────
    if (mass > 0.0f) {
        // NaN/INF TRIPWIRE — self-healing field. The play pipeline can emit
        // occasional non-finite particles (float-edge cases at star-map radii);
        // harmless when particles were independent, but the self-gravity
        // near-field READS neighbour centroids, so one bad star infects its
        // 27 cells and the whole field dies in seconds (measured: every
        // play→NaN blackout today). Containment: a star whose state goes
        // non-finite is respawned at its stored star-map home, at rest, cold —
        // same frame, before it can poison a centroid. Source rate of the
        // play-pipeline NaNs still TODO (the r≤3-domain voice-math audit).
        if (notFinite3(nextPos) || notFinite3(finalV)) {
            float r_home = p.spinW.x;
            float theta  = as_type<float>(p.entanglement.z);
            float aphi   = as_type<float>(p.entanglement.w);
            float st = sin(theta);
            float3 home = r_home * float3(st * cos(aphi), st * sin(aphi), cos(theta));
            p.prevW = float4(home, 0.0f);   // zero velocity, cold
            p.posW  = float4(home, mass);
            p.velW  = float4(0.0f);
            return;
        }
        if (notFinite1(currentTemp)) currentTemp = 0.0f; // T⁴ overflow → inf−inf
        // CENTER OF GRAVITY PINNED AT 0/0/0 (Jamal): drift the field gently
        // toward the origin by a SMALL, CLAMPED fraction of the measured COM
        // per frame. Full-gain subtraction destroyed the field (the COM
        // readback tears; one garbage value teleported everything, feedback
        // ran away, 99% of stars died — measured). Gain 2%/frame, max
        // 0.02 units/frame: converges in ~1 s, noise-immune, velocities
        // untouched (pos and prev shift equally).
        float3 comShift = float3(u.comX, u.comY, u.comZ) * 0.02f;
        comShift = clamp(comShift, -0.02f, 0.02f);
        if (notFinite3(comShift)) comShift = float3(0.0f);
        p.prevW = float4(float3(px, py, pz) - comShift, currentTemp);
        p.posW = float4(nextPos - comShift, mass);
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

// ── STELLAR MERGERS — the US2 "eating" (emergent-BH arc, step 2) ─────────────
// Real collisions are INELASTIC: two touching stars MERGE — the heavier eats
// the lighter, mass adds, momentum is conserved, the relative kinetic energy
// thermalizes (this is THE dissipation sink that lets piled mass STAY piled
// instead of bouncing back out — gravity alone is conservative).
// Scale honesty: at the Sgr A* anchor 1 R_sun = 0.0549 sim units, so stars in
// a crushed core (spacing ~0.008) physically OVERLAP — contact merging is the
// real outcome (runaway collisions in nuclear clusters are real astrophysics).
//
// Race-free GPU scheme: pair = MUTUAL nearest contact partner, decided by both
// threads independently from the SAME immutable snapshot (sortedParticles,
// built this frame before this kernel). Each thread writes ONLY its own
// particle: the winner (heavier; tie → lower id) absorbs, the loser dies
// (mass→0, parked outside the domain, frozen). At most one merge per star per
// frame. Resolution limits: partners come from the ≤32 scattered samples/cell,
// and contact reach is capped at 1.45·cellSize (the 27-cell scan); both only
// RATE-limit merging, never break conservation.


// ONE THREAD PER CELL (the centroid pass's architecture — the per-STAR version
// cost 120fps→37: 2M threads × random 80B struct reads; per-cell reads are
// contiguous and only dense cells do real work). Each cell-thread greedily
// pairs its own ≤32 scattered entries by nearest contact, sequentially —
// deterministic, no mutuality double-scan needed, and RACE-FREE because every
// particle belongs to exactly one cell: only its own cell's thread may write
// it. Cross-cell contact pairs are missed (rate-limit only, conservation safe).
kernel void merge_stars(
    device Particle* particles [[buffer(0)]],          // written by ORIGINAL id
    device const Particle* sorted [[buffer(1)]],       // immutable snapshot
    device const uint* cellStarts [[buffer(2)]],
    device const uint* cellCounts [[buffer(3)]],
    constant SpatialHashUniforms& su [[buffer(4)]],
    constant PhysicsUniforms& u [[buffer(5)]],
    uint cid [[thread_position_in_grid]])
{
    uint totalCells = uint(su.gridSize) * uint(su.gridSize) * uint(su.gridSizeZ);
    if (cid >= totalCells) return;
    // Attack: hash is stale (not rebuilt during attack) — no merging.
    if (u.envelopePhase >= 0.5f && u.envelopePhase < 1.5f) return;

    // BOUNDARY SHELL EXCLUDED (same rule as reduce_cell_max): assign_cells
    // clamps every escaper outside ±halfExtent into the outermost cells, and
    // the r≈1000 position wall physically piles them up until they touch —
    // ARTIFICIAL contact. Mergers there are clamp artifacts, and they were
    // BIRTHING SEEDS AT THE WALL (measured: registry led by out-of-domain
    // seeds, exit=304). Only interior cells merge.
    {
        int g = su.gridSize;
        int bx = int(cid) % g;
        int by = (int(cid) / g) % g;
        int bz = int(cid) / (g * g);
        if (bx == 0 || by == 0 || bz == 0 ||
            bx == g - 1 || by == g - 1 || bz == g - 1) return;
    }
    uint count = min(cellCounts[cid], 32u);            // scatter writes ≤32
    if (count < 2u) return;
    uint start = cellStarts[cid];

    bool used[32];
    for (uint i = 0; i < count; i++) used[i] = false;

    for (uint i = 0; i < count; i++) {
        if (used[i]) continue;
        Particle a = sorted[start + i];
        float ma = a.posW.w;
        // Seeds neither merge nor get merged here — they grow ONLY via the
        // victim-initiated feeding path (seed_mark/seed_apply), which keeps
        // them immortal: a dead seed would leak its in-flight accumulator.
        if (ma <= 0.001f || ma >= M_BH_SEED) continue; // dead / seed / wall
        if (notFinite3(a.posW.xyz)) continue;
        float aR = MERGE_RSUN_SIM * pow(ma, 0.8f);     // main-sequence R ∝ M^0.8

        // Nearest unused contact partner among the LATER entries.
        int best = -1;
        float bestD2 = 1e30f;
        for (uint j = i + 1; j < count; j++) {
            if (used[j]) continue;
            Particle b = sorted[start + j];
            float mb = b.posW.w;
            if (mb <= 0.001f || mb >= 1e8f) continue;
            float3 d = b.posW.xyz - a.posW.xyz;
            float d2 = dot(d, d);
            float rc;
            if (ma >= M_BH_SEED || mb >= M_BH_SEED) {
                // BH-SEED CAPTURE: tidal-disruption radius — the hole
                // shreds and swallows anything inside
                // R_t = R_star·(M_BH/m_star)^(1/3), far beyond stellar
                // contact; ×1.5 for gravitational focusing. Grows with
                // every meal → THE runaway breaker: the first seed
                // out-eats every competing cluster.
                float mBig = max(ma, mb), mSmall = min(ma, mb);
                float rStar = MERGE_RSUN_SIM * pow(mSmall, 0.8f);
                rc = 1.5f * rStar * pow(mBig / mSmall, 1.0f / 3.0f);
            } else {
                // Stellar contact: separation < R_a + R_b — real radii.
                rc = aR + MERGE_RSUN_SIM * pow(mb, 0.8f);
            }
            if (d2 < rc * rc && d2 < bestD2) {
                bestD2 = d2;
                best = int(j);
            }
        }
        if (best < 0) continue;
        used[i] = true;
        used[uint(best)] = true;

        Particle b = sorted[start + uint(best)];
        float mb = b.posW.w;
        uint aOrig = a.entanglement.y;                 // original ids (scatter)
        uint bOrig = b.entanglement.y;
        // The heavier eats (tie → lower id).
        bool aWins = (ma > mb) || (ma == mb && aOrig < bOrig);
        uint wOrig = aWins ? aOrig : bOrig;
        uint lOrig = aWins ? bOrig : aOrig;
        Particle w = aWins ? a : b;
        Particle l = aWins ? b : a;

        // INELASTIC MERGE: barycentre, momentum conserved, relative KE
        // thermalizes → temperature bump (full Rankine-Hugoniot shock heating
        // comes with the supernova rung).
        float mW = w.posW.w, mL = l.posW.w;
        float3 vw = w.posW.xyz - w.prevW.xyz;          // per-frame displacement
        float3 vl = l.posW.xyz - l.prevW.xyz;
        float mNew = mW + mL;
        float3 posNew = (w.posW.xyz * mW + l.posW.xyz * mL) / mNew;
        float3 vNew = (vw * mW + vl * mL) / mNew;
        // NOVA FLASH: the merger's thermalized energy, scaled by violence —
        // q = mL/mNew ∈ (0, 0.5], ½ = equal-mass head-on (brightest), tiny
        // snack ≈ +1. The T⁴ radiative cooling decays it over seconds; the
        // render shows it as a luminous-red-nova surge (the eat made visible).
        float q = mL / mNew;
        // Base 2.0 lifts every flash above the post-play residual heat
        // (~1-2 after T⁴ cooling) so the render threshold (2.5) separates
        // real novae from ambient warmth.
        float tNew = max(w.prevW.w, l.prevW.w) + 2.0f + 6.0f * q;
        // Stale ids can exceed the current buffer (count switched 5M→2M).
        if (wOrig >= uint(u.particleCount) || lOrig >= uint(u.particleCount))
            continue;

        // COMPARE-AND-WRITE GUARD — conservation insurance. The merge was
        // decided from the snapshot; if the LIVE buffer no longer matches
        // (stale sorted slot, wrong id, respawn transient — measured: stale
        // winner ids CREATED mass, Mlive 594k→2.8M), the data this merge is
        // based on is wrong: abort the pair. Valid merges (the vast
        // majority) see exact equality — posW.w is untouched between the
        // snapshot blit and this kernel.
        if (particles[wOrig].posW.w != mW || particles[lOrig].posW.w != mL)
            continue;

        particles[wOrig].posW = float4(posNew, mNew);
        particles[wOrig].prevW = float4(posNew - vNew, tNew);

        // EATEN: die. Mass → 0 (gravity/stats/render all gate on it), parked
        // far outside the domain and frozen so no force path resurrects it.
        float park = 4000.0f + float(lOrig % 1024);
        particles[lOrig].posW = float4(park, park, park, 0.0f);
        particles[lOrig].prevW = float4(park, park, park, l.prevW.w);
    }
}

// ── SEED MARK + VICTIM-INITIATED FEEDING (step 3's heart, v2) ────────────────
// The sample-based per-seed scan starved (sorted-slot desyncs measured for
// six straight probe cycles). INVERTED architecture: a tiny pass marks each
// seed's CELL in cellSeedMap; every star checks its 27 neighbour cells in
// compute_physics and, if inside a marked seed's capture radius, SACRIFICES
// ITSELF — parks, dies, and atomically adds its exact mass to the seed's
// accumulator. Each victim is its own thread: double-eating is structurally
// impossible. seed_apply then credits the seeds. No sampling, no sorted
// buffer, conservation exact by construction.

kernel void seed_mark(
    device const Particle* particles [[buffer(0)]],
    device uint* seedMeta [[buffer(1)]],               // [0]=count [4]=stable mirror
    device const uint* seedIds [[buffer(2)]],
    device uint* cellSeedMap [[buffer(3)]],            // 0 = none, else slot+1
    constant SpatialHashUniforms& su [[buffer(4)]],
    constant PhysicsUniforms& u [[buffer(5)]],
    uint tid [[thread_position_in_grid]])
{
    // Mirror the final registry count into the uncleared half of the buffer
    // so the CPU's log read can never land mid-clear and report a false 0.
    if (tid == 0u) seedMeta[4] = seedMeta[0];
    if (tid >= min(seedMeta[0], 256u)) return;
    if (su.gridSize <= 0) return;
    uint sid = seedIds[tid];
    if (sid >= uint(u.particleCount)) return;
    float m = particles[sid].posW.w;
    if (m < M_BH_SEED || m >= 1e8f) return;
    float3 pos = particles[sid].posW.xyz;
    if (notFinite3(pos)) return;
    if (fabs(pos.x) >= su.halfExtent || fabs(pos.y) >= su.halfExtent ||
        fabs(pos.z) >= su.halfExtent) return;
    int cx = clamp(int((pos.x + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
    int cy = clamp(int((pos.y + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
    int cz = clamp(int((pos.z + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
    cellSeedMap[uint((cz * su.gridSize + cy) * su.gridSize + cx)] = tid + 1u;
}

// seedAccum layout per slot (4 uints): [0] mass ×64, [1] meals, [2,3] reserved.
kernel void seed_apply(
    device Particle* particles [[buffer(0)]],
    device const uint* seedMeta [[buffer(1)]],
    device const uint* seedIds [[buffer(2)]],
    device const atomic_uint* seedAccum [[buffer(3)]],
    constant PhysicsUniforms& u [[buffer(4)]],
    uint tid [[thread_position_in_grid]])
{
    if (tid >= min(seedMeta[0], 256u)) return;
    uint sid = seedIds[tid];
    if (sid >= uint(u.particleCount)) return;
    float gain = float(atomic_load_explicit(&seedAccum[tid * 4u + 0u],
                                            memory_order_relaxed)) * (1.0f / 64.0f);
    if (gain <= 0.0f) return;
    float m = particles[sid].posW.w;
    if (m < M_BH_SEED || m >= 1e8f) return;   // seeds are immortal; safety only
    particles[sid].posW.w = m + gain;
    // TDE FLARE scaled by the meal; T⁴ cooling fades it back to dark.
    float t = particles[sid].prevW.w;
    particles[sid].prevW.w = max(t, 3.0f + 2.0f * min(1.0f, gain / m));
}

// ── (v1 sample-based seed_feed below: NOT dispatched — kept for reference) ───
// The per-cell merge pass samples ≤32 stars/cell, so a seed inside a 15k-star
// core cell got a merge chance ~0.2% of frames and STARVED (measured). Here
// every registered seed (count_cells appends ids of bodies ≥ M_BH_SEED) gets
// a dedicated thread that scans its 27-cell neighbourhood and EATS everything
// inside its tidal radius. Victims are CLAIMED by an atomic exchange on the
// mass word (posW.w): exactly one claimer receives the old bits — duplication
// is impossible by construction, so conservation is hardware-enforced even
// against the concurrent merge pass (whose compare-and-write guard then sees
// the mismatch and aborts its own attempt on the same star).
kernel void seed_feed(
    device Particle* particles [[buffer(0)]],          // live state
    device atomic_uint* particlesA [[buffer(1)]],      // SAME buffer, atomic view
    device const Particle* sorted [[buffer(2)]],       // immutable snapshot
    device const uint* cellStarts [[buffer(3)]],
    device const uint* cellCounts [[buffer(4)]],
    device atomic_uint* seedMeta [[buffer(5)]],        // [0]=count [1]=meals [2]=eaten×64
    device const uint* seedIds [[buffer(6)]],
    constant SpatialHashUniforms& su [[buffer(7)]],
    constant PhysicsUniforms& u [[buffer(8)]],
    uint tid [[thread_position_in_grid]])
{
    uint nSeeds = atomic_load_explicit(&seedMeta[0], memory_order_relaxed);
    // Staged exit-code probe (thread 0 always launches in the 256 dispatch):
    // 100+n = entry (n = nSeeds GPU-side), 200 = past count/grid, 300 = past
    // phase, then 301..304 = sid/mass/nan/extent rejects, 305 = scanning.
    if (tid == 0u)
        atomic_store_explicit(&seedMeta[7], 100u + min(nSeeds, 99u),
                              memory_order_relaxed);
    if (tid >= min(nSeeds, 256u)) return;
    if (su.gridSize <= 0) return;
    if (tid == 0u) atomic_store_explicit(&seedMeta[7], 200u, memory_order_relaxed);
    if (u.envelopePhase >= 0.5f && u.envelopePhase < 1.5f) return; // stale hash
    if (tid == 0u) atomic_store_explicit(&seedMeta[7], 300u, memory_order_relaxed);

    uint sid = seedIds[tid];
    // Exit-code probe (thread 0): which gate rejects the seed?
    #define SEED_EXIT(code) { if (tid == 0u) atomic_store_explicit(&seedMeta[7], (code), memory_order_relaxed); return; }
    if (sid >= uint(u.particleCount)) SEED_EXIT(301u);
    float mSeed = particles[sid].posW.w;               // LIVE (post-merge-pass)
    if (mSeed < M_BH_SEED || mSeed >= 1e8f) SEED_EXIT(302u);
    float3 pos = particles[sid].posW.xyz;
    if (notFinite3(pos)) SEED_EXIT(303u);
    if (fabs(pos.x) >= su.halfExtent || fabs(pos.y) >= su.halfExtent ||
        fabs(pos.z) >= su.halfExtent) SEED_EXIT(304u);
    if (tid == 0u) atomic_store_explicit(&seedMeta[7], 305u, memory_order_relaxed);

    float3 vSeed = pos - particles[sid].prevW.xyz;
    float tSeed = particles[sid].prevW.w;

    int cx = clamp(int((pos.x + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
    int cy = clamp(int((pos.y + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);
    int cz = clamp(int((pos.z + su.halfExtent) * su.invCellSize), 0, su.gridSize - 1);

    // BISECT meter: this seed thread passed every early-out and is scanning.
    atomic_fetch_add_explicit(&seedMeta[3], 1u, memory_order_relaxed);

    float bestD2 = 1e30f;   // nearest candidate, probe only

    float eaten = 0.0f;
    float3 eatenP = vSeed * mSeed;                     // momentum budget
    float3 posM = pos * mSeed;                         // barycentre budget
    int meals = 0;
    const int MAX_MEALS = 32;                          // bounded work per frame

    for (int z = max(0, cz - 1); z <= min(su.gridSize - 1, cz + 1) && meals < MAX_MEALS; z++) {
        for (int y = max(0, cy - 1); y <= min(su.gridSize - 1, cy + 1) && meals < MAX_MEALS; y++) {
            for (int x = max(0, cx - 1); x <= min(su.gridSize - 1, cx + 1) && meals < MAX_MEALS; x++) {
                uint cID = uint((z * su.gridSize + y) * su.gridSize + x);
                uint count = min(cellCounts[cID], 32u);
                uint start = cellStarts[cID];
                for (uint i = 0; i < count && meals < MAX_MEALS; i++) {
                    Particle v = sorted[start + i];
                    float mv = v.posW.w;
                    if (mv <= 0.001f || mv >= M_BH_SEED) continue;  // seeds don't eat seeds here
                    uint vOrig = v.entanglement.y;
                    if (vOrig == sid || vOrig >= uint(u.particleCount)) continue;
                    float3 d = v.posW.xyz - pos;
                    float d2 = dot(d, d);
                    bestD2 = min(bestD2, d2);
                    // Tidal disruption radius (the bare cross-section)…
                    float mNow = mSeed + eaten;
                    float rt = 1.5f * MERGE_RSUN_SIM * pow(mv, 0.8f) *
                               pow(mNow / mv, 1.0f / 3.0f);
                    // …boosted by GRAVITATIONAL FOCUSING — the accelerator.
                    // σ = πR_t²(1 + 2GM/(R_t·v_rel²)): a slow passer-by is
                    // captured from far beyond R_t, and the boost grows with
                    // the hole's mass → accretion self-accelerates as it
                    // eats. v_rel in sim/s (velW are per-frame, ×120).
                    float3 dv = ((v.posW.xyz - v.prevW.xyz) - vSeed) * 120.0f;
                    float vrel2 = max(dot(dv, dv), 1e-4f);
                    float G1 = u.gravGM / max(u.massTotal, 1.0f);
                    float rt2 = rt * rt + rt * (2.0f * G1 * mNow) / vrel2;
                    float reach = 1.4f * su.cellSize;
                    rt2 = min(rt2, reach * reach);
                    if (d2 >= rt2) continue;
                    // CLAIM: atomically swap the victim's mass word with 0.
                    // Particle = 80B = 20 uints; posW.w is uint index id·20+3.
                    uint old = atomic_exchange_explicit(&particlesA[vOrig * 20u + 3u],
                                                        0u, memory_order_relaxed);
                    float mClaim = as_type<float>(old);
                    uint ob = old;
                    bool claimFinite = ((ob >> 23) & 0xFFu) != 0xFFu;
                    if (!claimFinite || mClaim <= 0.001f || mClaim >= M_BH_SEED) {
                        // lost the race / already dead / not a valid snack —
                        // if it was a real body we must NOT destroy it: restore.
                        if (claimFinite && mClaim > 0.001f)
                            atomic_exchange_explicit(&particlesA[vOrig * 20u + 3u],
                                                     old, memory_order_relaxed);
                        continue;
                    }
                    // OWNED: exact claimed mass, momentum from the snapshot.
                    eaten  += mClaim;
                    eatenP += (v.posW.xyz - v.prevW.xyz) * mClaim;
                    posM   += v.posW.xyz * mClaim;
                    // Victim: freeze in place, dead (mass word already 0).
                    particles[vOrig].prevW = float4(v.posW.xyz, v.prevW.w);
                    meals++;
                }
            }
        }
    }

    // PROBE (thread for the first seed): my cell's population, nearest
    // candidate distance ×1000, my mass — decodes the starvation.
    if (tid == 0u) {
        uint myCell = uint((cz * su.gridSize + cy) * su.gridSize + cx);
        atomic_store_explicit(&seedMeta[4], cellCounts[myCell], memory_order_relaxed);
        // Raw first sorted entry of my cell: its mass ×1000 and its orig id —
        // decodes WHY every candidate fails the gates.
        Particle p0 = sorted[cellStarts[myCell]];
        atomic_store_explicit(&seedMeta[5],
                              uint(clamp(p0.posW.w, 0.0f, 4000000.0f) * 1000.0f),
                              memory_order_relaxed);
        atomic_store_explicit(&seedMeta[6], p0.entanglement.y, memory_order_relaxed);
    }
    if (meals > 0) {
        // Meal meter (telemetry): meals + eaten mass this frame, all seeds.
        atomic_fetch_add_explicit(&seedMeta[1], uint(meals), memory_order_relaxed);
        atomic_fetch_add_explicit(&seedMeta[2], uint(eaten * 64.0f + 0.5f),
                                  memory_order_relaxed);
    }
    if (eaten > 0.0f) {
        float mNew = mSeed + eaten;
        float3 posNew = posM / mNew;
        float3 vNew = eatenP / mNew;
        // TDE FLARE: a feeding hole flares (the darkSeed render exception
        // shows it while temp > 2.5); T⁴ cooling fades it back to dark.
        float tNew = max(tSeed, 3.0f + 2.0f * min(1.0f, eaten / mSeed));
        particles[sid].posW = float4(posNew, mNew);
        particles[sid].prevW = float4(posNew - vNew, tNew);
    }
}

// ── Conservation law reduction kernel ───────────────────────────────────────

struct PartialStats {
    float kineticEnergy;
    float momentumX;
    float momentumY;
    float sumMass;   // Σ stellar mass (M_sun) of live stars (was pad)
    float sumTemp;   // Σ temperature (→ avg)
    float maxTemp;   // max temperature
    float sumSpeed;  // Σ |v| (→ avg)
    float maxSpeed;  // max |v|
    float sumPx;     // Σ mass·position of live stars (→ mass-weighted COM)
    float sumPy;
    float sumPz;
    float sumCount;  // live star count
    float sumR;      // Σ |r| of live stars (→ mean radius)
    float maxR;      // farthest live star
    float maxMass;   // heaviest body (M_sun) — watches the seed grow
    float pad3;
    float sumEncX;   // Σ mass·position of stars within R_ENC of the candidate
    float sumEncY;   //   → enclosed MASS (M_sun) + refined core COM
    float sumEncZ;
    float sumEncMass;
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
    threadgroup float sharedPX[256];  // Σ live position → COM (self-gravity)
    threadgroup float sharedPY[256];
    threadgroup float sharedPZ[256];
    threadgroup float sharedCT[256];  // live star count
    threadgroup float sharedSM[256];  // Σ stellar mass (M_sun)
    threadgroup float sharedMM[256];  // max stellar mass (the seed watch)
    threadgroup float sharedSR[256];  // Σ radius
    threadgroup float sharedMR[256];  // max radius
    threadgroup float sharedEX[256];  // Σ m·pos within R_ENC of BH candidate
    threadgroup float sharedEY[256];
    threadgroup float sharedEZ[256];
    threadgroup float sharedEC[256];  // Σ mass (M_sun) within R_ENC

    float ke = 0.0f, mx = 0.0f, my = 0.0f;
    float temp = 0.0f, speed = 0.0f;
    float3 lpos = float3(0.0f);
    float pmass = 0.0f;
    bool real = false;

    if (int(id) < u.particleCount) {
        float mass = particles[id].posW.w;
        pmass = mass;
        float vx = particles[id].velW.x;
        float vy = particles[id].velW.y;
        float vz = particles[id].velW.z;
        ke = 0.5f * mass * (vx * vx + vy * vy + vz * vz);
        mx = mass * vx;
        my = mass * vy;
        if (mass > 0.001f) {                 // skip wall particles
            float px = particles[id].posW.x;
            float py = particles[id].posW.y;
            float pz = particles[id].posW.z;
            float r_sim = sqrt(px*px + py*py + pz*pz);
            // REAL orbital velocity as a fraction of c: v/c = sqrt(r_g/r), and
            // 1 sim unit = 2 r_g ⇒ v/c = sqrt(0.5 / r_sim). Pure geometry from
            // the Sgr A* anchor — the real Keplerian/Schwarzschild orbital speed
            // at this radius (reactive: mean drops as the field expands on play).
            speed = (r_sim > 1e-4f) ? min(0.999f, sqrt(0.5f / r_sim)) : 0.0f;
            // REAL virial plasma temperature: T = μ·m_p·v²/(3·k_B), v = orbital
            // speed. With v/c=sqrt(0.5/r_sim) it reduces to T[K] = 1.089e12/r_sim.
            // (μ=0.6 ionized plasma, m_p=1.673e-27, k_B=1.381e-23, c²=8.988e16).
            // The honest Sgr A* RIAF: ~10^11 K mean → ~10^12 K (quark-gluon) inner.
            temp  = (r_sim > 1e-4f) ? (1.089e12f / r_sim) : 0.0f;
            lpos  = float3(px, py, pz);
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
    // Mass-weighted: COM must be where the MASS is (stars carry real IMF
    // masses now), else a lucky cluster of O-stars pulls toward the wrong
    // point. Readback divides by sumMass.
    float lm = (real && pmass < 1e8f) ? pmass : 0.0f;  // incl. BH seeds
    sharedPX[tid] = lpos.x * lm;
    sharedPY[tid] = lpos.y * lm;
    sharedPZ[tid] = lpos.z * lm;
    sharedCT[tid] = real ? 1.0f : 0.0f;
    sharedSM[tid] = lm;
    sharedMM[tid] = lm;
    float lr = length(lpos);
    sharedSR[tid] = real ? lr : 0.0f;
    sharedMR[tid] = real ? lr : -1e9f;
    // Emergent-BH enclosure (Step 2): R_ENC = 0.5 sim units around the
    // densest region (u.bh*, 1-frame lag). Enclosed Σmass is the REAL
    // stellar mass in M_sun; the geometric BH criterion (Step 3) compares
    // it against M_crit(R_ENC) = R_ENC·unit/r_s(M_sun).
    float3 encD = lpos - float3(u.bhX, u.bhY, u.bhZ);
    bool enc = real && (dot(encD, encD) < 0.25f);   // R_ENC² = 0.25
    sharedEX[tid] = enc ? lpos.x * lm : 0.0f;
    sharedEY[tid] = enc ? lpos.y * lm : 0.0f;
    sharedEZ[tid] = enc ? lpos.z * lm : 0.0f;
    sharedEC[tid] = enc ? lm : 0.0f;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = tgSize / 2; stride > 0; stride >>= 1) {
        if (tid < stride) {
            sharedKE[tid] += sharedKE[tid + stride];
            sharedMX[tid] += sharedMX[tid + stride];
            sharedMY[tid] += sharedMY[tid + stride];
            sharedST[tid] += sharedST[tid + stride];
            sharedSS[tid] += sharedSS[tid + stride];
            sharedPX[tid] += sharedPX[tid + stride];
            sharedPY[tid] += sharedPY[tid + stride];
            sharedPZ[tid] += sharedPZ[tid + stride];
            sharedCT[tid] += sharedCT[tid + stride];
            sharedSM[tid] += sharedSM[tid + stride];
            sharedMM[tid]  = max(sharedMM[tid], sharedMM[tid + stride]);
            sharedSR[tid] += sharedSR[tid + stride];
            sharedEX[tid] += sharedEX[tid + stride];
            sharedEY[tid] += sharedEY[tid + stride];
            sharedEZ[tid] += sharedEZ[tid + stride];
            sharedEC[tid] += sharedEC[tid + stride];
            sharedMR[tid]  = max(sharedMR[tid], sharedMR[tid + stride]);
            sharedMT[tid]  = max(sharedMT[tid], sharedMT[tid + stride]);
            sharedMS[tid]  = max(sharedMS[tid], sharedMS[tid + stride]);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0) {
        partialSums[tgId].kineticEnergy = sharedKE[0];
        partialSums[tgId].momentumX = sharedMX[0];
        partialSums[tgId].momentumY = sharedMY[0];
        partialSums[tgId].sumMass  = sharedSM[0];
        partialSums[tgId].maxMass  = sharedMM[0];
        partialSums[tgId].sumTemp  = sharedST[0];
        partialSums[tgId].maxTemp  = sharedMT[0];
        partialSums[tgId].sumSpeed = sharedSS[0];
        partialSums[tgId].maxSpeed = sharedMS[0];
        partialSums[tgId].sumPx    = sharedPX[0];
        partialSums[tgId].sumPy    = sharedPY[0];
        partialSums[tgId].sumPz    = sharedPZ[0];
        partialSums[tgId].sumCount = sharedCT[0];
        partialSums[tgId].sumR     = sharedSR[0];
        partialSums[tgId].maxR     = sharedMR[0];
        partialSums[tgId].sumEncX  = sharedEX[0];
        partialSums[tgId].sumEncY  = sharedEY[0];
        partialSums[tgId].sumEncZ  = sharedEZ[0];
        partialSums[tgId].sumEncMass = sharedEC[0];
    }
}
