#include <metal_stdlib>
using namespace metal;

// GPU particle state — matches GPUParticle struct in C++ (64 bytes)
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
    float padding[2];
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
};

struct SpatialHashUniforms {
    int gridSize;
    int particleCount;
    float cellSize;
    float invCellSize;
    int gridSizeZ;
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
constant int MAX_PER_CELL = 32; // Optimized for 1M particle neighbor scans
constant float COLLISION_RESTITUTION = 0.85f;

// Phase 11.3: Planck-length softening (regularizes point-particle infinities)
constant float PLANCK_LENGTH_SQ = 0.0001f; // Minimum interaction distance²
constant float SCHWARZSCHILD_RS = 0.1f;    // Phase 16: Supermassive Event Horizon

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
    float phase = p.velW.w;

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
    
    // Base friction (damps previous velocity)
    float baseFric = pow(0.02f, dt); 

    float dynamicFric = baseFric;

    // Track potential energy for phase accumulation
    float PE = 0.0f;
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

    // ─── PHASE 0: SILENCE → BLACK HOLE SINGULARITY ───────────────────────
    if (u.envelopePhase < 0.5f) {
        // Direct position collapse — bypasses all velocity forces
        float collapseRate = 0.08f;
        float keep = 1.0f - collapseRate;
        px *= keep; py *= keep; pz *= keep;
        prevX = px; prevY = py; prevZ = pz;
        vpx = 0.0f; vpy = 0.0f; vpz = 0.0f;

        // Hawking radiation flicker near event horizon
        if (r_curr < SCHWARZSCHILD_RS * 2.5f && r_curr > SCHWARZSCHILD_RS) {
            float flicker = noise(id, u.frameCounter) * 0.015f;
            float3 dir = pvec / max(r_curr, 0.001f);
            shiftVx += dir.x * flicker;
            shiftVy += dir.y * flicker;
            shiftVz += dir.z * flicker;
        }
        currentTemp *= 0.95f; // Cool toward absolute zero
    }
    // ─── PHASE 1: ATTACK → BIG BANG EXPLOSION ────────────────────────────
    else if (u.envelopePhase < 1.5f) {
        float explosionPower = (1.0f - t) * 80.0f * lcI;

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
    // ─── PHASE 2/3: DECAY/SUSTAIN → SUN (Radiating Sphere) ──────────────
    else if (u.envelopePhase < 3.5f) {
        float targetRadius = 0.75f;
        if (r_curr > 0.001f) {
            float3 dir = pvec / r_curr;
            // Hooke's law spring toward shell surface
            float displacement = (r_curr - targetRadius);
            float springForce = displacement * 25.0f * lcI;
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
        }
    }
    // ─── PHASE 4: RELEASE → GRAVITATIONAL COLLAPSE ───────────────────────
    else {
        if (r_curr > 0.001f) {
            float3 dir = pvec / r_curr;
            // Collapse intensity grows with release progress
            float collapseBase = 50.0f * lcI;
            float progressFactor = 1.0f + t * t * 8.0f;
            float gamma2 = 1.0f / max(0.01f, 1.0f - (SCHWARZSCHILD_RS * t) / r_curr);
            float collapsePull = collapseBase * progressFactor * gamma2;

            shiftVx -= dir.x * collapsePull * dt;
            shiftVy -= dir.y * collapsePull * dt;
            shiftVz -= dir.z * collapsePull * dt;

            // Kerr frame-dragging (accretion disk spiral)
            float3 galacticUp = normalize(float3(0.2f, 1.0f, 0.3f));
            float3 spinForce = cross(galacticUp, dir);
            float dragStrength = collapsePull * t * (2.0f / (r_curr + 0.5f));
            shiftVx += spinForce.x * dragStrength * dt;
            shiftVy += spinForce.y * dragStrength * dt;
            shiftVz += spinForce.z * dragStrength * dt;

            // Cosmological redshift
            float redshift = 1.0f / (1.0f + t * t * 2.0f);
            vpx *= redshift; vpy *= redshift; vpz *= redshift;
            currentTemp *= (1.0f - t * 0.02f);

            // Event horizon capture at collapse completion
            if (t > 0.9f && r_curr < SCHWARZSCHILD_RS * 2.0f) {
                vpx = 0.0f; vpy = 0.0f; vpz = 0.0f;
                shiftVx *= 0.1f; shiftVy *= 0.1f; shiftVz *= 0.1f;
            }
        }
    }

    // Safety Snapback for runaway particles
    if (r_curr > 1000.0f) {
        px *= 0.5f; py *= 0.5f; pz *= 0.5f;
    }
    pvec = float3(px, py, pz);
    r_curr = length(pvec);

    // Emitter Interactions (Macro forces)
    float baseMass = (mass > 1000.0f) ? mass : 1.0f;
    float dynamicMass = baseMass;

    // Safety: Clamp voiceCount to prevent reading beyond buffer or into uninitialized memory
    int numVoices = min((int)u.voiceCount, 16); 

    if (numVoices > 0 && baseMass < 1000.0f) {
        float massAdd = 0.0f;
        float jitterTotal = 0.0f;

        for (int vi = 0; vi < u.voiceCount; vi++) {
            float amp = voices[vi].amplitude;

            // Global attractive/repulsive forces from the emitter
            float dx = px - voices[vi].emitterX;
            float dy = py - voices[vi].emitterY;
            float dz = pz - voices[vi].emitterZ;
            float r2 = dx * dx + dy * dy + dz * dz + PLANCK_LENGTH_SQ;
            float r = sqrt(r2);
            float th = atan2(dy, dx);
            
            float m_f = float(voices[vi].m);
            float n_f = float(voices[vi].n);

            // Phase 4: Dynamic Heaviness (E=mc^2)
            // Energy = frequency * amplitude. Increase mass for the medium where the wave travels.
            float localEnergy = (voices[vi].frequency * amp) / (r2 * 0.5f + 1.0f);
            massAdd += localEnergy * 0.005f; // scaling factor

            // Emitters induce a strong coherent spin field (B-field)
            float spinMag = amp * 50.0f * (m_f == 0.0f ? 1.0f : sign(m_f));
            float3 emitterSpin = float3(
                sin(n_f * th) * spinMag * 0.5f, 
                cos(n_f * th) * spinMag * 0.5f, 
                spinMag * cos(m_f * r * 0.1f)
            );
            float3 rVec = float3(dx, dy, dz);
            
            // Biot-Savart induced velocity from the emitter's virtual vortex
            float3 inducedV = cross(emitterSpin, rVec) / (r2 * r);
            shiftVx += inducedV.x * 0.15f;
            shiftVy += inducedV.y * 0.15f;
            shiftVz += inducedV.z * 0.1f;

            // Phase 4 & 12: Mechanical Point Source Impulse + Shockwaves
            float pushRadius = 2.0f;
            if (r < pushRadius) {
                // Phase 14: Density-Aware Pulse (Proportional to plate scale)
                float3 radialDir = float3(dx / r, dy / r, dz / r);
                float impulseForce = amp * (1.0f - r / pushRadius) * 20.0f;
                
                // Shockwave scales inversely with zoom (smaller plate = more intense local pulse)
                float densityScale = 1.0f / max(0.1f, u.plateRadius / 400.0f);
                float shockwave = voices[vi].deltaAmp * 400.0f * (1.0f - r / pushRadius) * densityScale;
                impulseForce += shockwave;
                
                shiftVx += radialDir.x * impulseForce;
                shiftVy += radialDir.y * impulseForce;
                shiftVz += radialDir.z * impulseForce;
                
                // Transient heat peak
                currentTemp += voices[vi].deltaAmp * 2.0f;
            }

            // ── The Atom Model (Gradient-Driven Harmonic Sculpting) ────────
            // Compute the spherical harmonic field Y(θ, φ) and its angular gradient.
            // Instead of pushing radially (always a ball), we push particles
            // TOWARD the lobe maxima via the gradient in θ and φ.
            float phi = acos(clamp(dz / r, -1.0f, 1.0f)); // Polar angle [0, pi]
            
            // The harmonic field and its finite-difference gradient
            float Y_here  = cos(m_f * th) * sin(n_f * phi);
            float Y_dth   = cos(m_f * (th + 0.02f)) * sin(n_f * phi);
            float Y_dphi  = cos(m_f * th) * sin(n_f * (phi + 0.02f));
            
            float dYdth  = (Y_dth - Y_here) / 0.02f;
            float dYdphi = (Y_dphi - Y_here) / 0.02f;
            
            // Convert angular gradients to Cartesian force directions
            // θ-direction (azimuthal): perpendicular to radial in the XY plane
            float3 thetaDir = float3(-sin(th), cos(th), 0.0f);
            // φ-direction (polar): perpendicular to radial in the vertical plane
            float sinPhi = sin(phi);
            float3 phiDir = float3(
                cos(th) * cos(phi),
                sin(th) * cos(phi),
                -sinPhi
            );
            
            // The sculpting force: push toward lobe maxima
            // Phase 12: Audio-Rate LFO (Moog Shimmer)
            // Modulate sculpting strength with the actual note frequency
            // This makes the harmonic shapes vibrate/shimmer at the pitch rate.
            float acMod = 1.0f + 0.3f * sin(voices[vi].frequency * u.time * 0.1f + voices[vi].phase);
            float sculptStrength = amp * voices[vi].alpha * 20.0f * acMod;
            
            shiftVx += (dYdth * thetaDir.x + dYdphi * phiDir.x) * sculptStrength;
            shiftVy += (dYdth * thetaDir.y + dYdphi * phiDir.y) * sculptStrength;
            shiftVz += (dYdth * thetaDir.z + dYdphi * phiDir.z) * sculptStrength;
            
            // Radial breathing: expand/contract based on harmonic value (not just outward)
            float radialForce = amp * Y_here * 8.0f;
            float3 centerVec = float3(px, py, pz);
            float cLen = length(centerVec);
            if (cLen > 0.0001f) {
                float3 outDir = centerVec / cLen;
                shiftVx += outDir.x * radialForce;
                shiftVy += outDir.y * radialForce;
                shiftVz += outDir.z * radialForce;
            }
            
            jitterTotal += amp * abs(Y_here);
        }

        // Apply dynamic relativistic mass
        dynamicMass += massAdd;

        // ODS-03: Thermal Energy Evolution
        // Target temp is driven by auditory excitation (jitterTotal)
        float targetTemp = clamp(jitterTotal * 0.5f, 0.0f, 1.0f);
        currentTemp = mix(currentTemp, targetTemp, 0.05f); // Thermal inertia
    }

    // ODS-03: Dynamic Brownian Jitter
    if ((u.debugFlags & (1 << 4)) && currentTemp > 0.001f) {
        float n_strength = currentTemp * u.jitterFactor * 5.0f * dt;
        shiftVx += noise(id, u.time) * n_strength;
        shiftVy += noise(id + 1, u.time) * n_strength;
        shiftVz += noise(id + 2, u.time) * n_strength;
    }

    // ── Noether Symmetry Breaking ─────────────────────────────────────
    // Constantly adds a subtle ambient swirl to prevent perfect dead-center grid-lock if needed
    if (u.symmetryBreakImpulse > 0.0f) {
        float angle = noise(id * 3u, u.time) * M_PI_F;
        float strength = u.symmetryBreakImpulse * (0.1f + noise(id * 7u, u.time) * 0.1f);
        shiftVx += cos(angle) * strength;
        shiftVy += sin(angle) * strength;
    }

    // Jitter (Heisenberg uncertainty)
    if (u.debugFlags & (1 << 4)) {
        float noisy = noise(id, u.time + 1.234f);
        float noisx = noise(id, u.time + 5.678f);
        float noisz = noise(id, u.time + 9.012f);
        shiftVx += noisx * u.jitterFactor * 0.05f * dt;
        shiftVy += noisy * u.jitterFactor * 0.05f * dt;
        shiftVz += noisz * u.jitterFactor * 0.05f * dt;
    }

    // (Schwarzschild gravity replaced by ADSR lifecycle above)

    // ── Particle-Particle Collisions (spatial hash neighbor scan) ─────
    if (u.collisionsOn > 0 && su.gridSize > 0) {
        int cellX = clamp(int((px + 1.0f) * su.invCellSize), 0, su.gridSize - 1);
        int cellY = clamp(int((py + 1.0f) * su.invCellSize), 0, su.gridSize - 1);
        int cellZ = clamp(int((pz + 1.0f) * su.invCellSize), 0, su.gridSize - 1);

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
        // shiftX/Y/Z and shiftVx/Vy/Vz are now declared at kernel scope

        float selfCharge = p.spinW.w;

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
                                float3 spin1 = float3(0, 0, p.velW.w); // Simplified spin (using phase)
                                float3 spin2 = float3(0, 0, p2.velW.w); // Simplified spin (using phase)
                                float3 bForceVec = cross(spin1, normalize(r_vec)) * u.bFieldCirculation * dt;
                                shiftVx += bForceVec.x; shiftVy += bForceVec.y; shiftVz += bForceVec.z;
                            }

                            // Tensegrity Strings (Hooke's Law)
                            if (u.debugFlags & (1 << 3)) {
                                float strain = r - u.restLength;
                                float3 stringF = normalize(r_vec) * strain * u.stringStiffness * dt;
                                shiftVx += stringF.x; shiftVy += stringF.y; shiftVz += stringF.z;
                            }

                            // Newtonian Self-Gravity (1/r^2)
                            if (u.debugFlags & (1 << 2)) {
                                float massProd = dynamicMass * p2.posW.w; // Use actual masses
                                if (massProd == 0.0f) massProd = 1.0f; // Avoid division by zero if one mass is 0
                                float gravForce = u.gravityConstant * massProd / r2_clamped;
                                float3 fG = normalize(-r_vec) * gravForce * dt;
                                shiftVx += fG.x; shiftVy += fG.y; shiftVz += fG.z;
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

    // Apply unified velocity shifts to damped proxy
    vpx = vpx * dynamicFric;
    vpy = vpy * dynamicFric;
    vpz = vpz * dynamicFric;

    // Combine proxy with force pulses
    float3 finalV = float3(vpx, vpy, vpz) * dynamicFric + float3(shiftVx, shiftVy, shiftVz);
    
    // Speed cap
    float speed = length(finalV);
    if (speed > u.speedCap) {
        finalV = (finalV / max(speed, 0.0001f)) * u.speedCap;
    }
    
    // Final position integration
    // PHASE 14 BUG FIX: Do NOT add shiftX/Y/Z here, they were already added to px/py/pz
    float3 nextPos = float3(px, py, pz) + finalV;

    // Phase accumulation
    float newPhase = p.velW.w + speed * dt;

    // ── ODS-04: Dimming My Light (Stealth / ANC) ───────────────────────────
    if (u.debugFlags & (1 << 9)) {
        // Define the "User" cluster (~5% of particles)
        if ((id % 20) == 0) {
            // Active Noise Cancelling: Destructive interference by phase inversion
            newPhase = fmod(p.velW.w + M_PI_F, 2.0f * M_PI_F);
            
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
                newPhase = mix(newPhase, prevParticles[partnerID].velW.w, 0.1f * dt); // Phase sync
            }
        }
    }

    // ── Write back ───────────────────────────────────────────────────
    if (mass > 0.0f) {
        p.prevW = float4(px, py, pz, currentTemp);
        p.posW = float4(nextPos, mass);
        p.velW = float4(finalV, newPhase);
    }
}

// ── Conservation law reduction kernel ───────────────────────────────────────

struct PartialStats {
    float kineticEnergy;
    float momentumX;
    float momentumY;
    float pad;
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

    float ke = 0.0f, mx = 0.0f, my = 0.0f;

    if (int(id) < u.particleCount) {
        float mass = particles[id].posW.w;
        float vx = particles[id].velW.x;
        float vy = particles[id].velW.y;
        float vz = particles[id].velW.z;
        ke = 0.5f * mass * (vx * vx + vy * vy + vz * vz);
        mx = mass * vx;
        my = mass * vy;
    }

    sharedKE[tid] = ke;
    sharedMX[tid] = mx;
    sharedMY[tid] = my;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = tgSize / 2; stride > 0; stride >>= 1) {
        if (tid < stride) {
            sharedKE[tid] += sharedKE[tid + stride];
            sharedMX[tid] += sharedMX[tid + stride];
            sharedMY[tid] += sharedMY[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0) {
        partialSums[tgId].kineticEnergy = sharedKE[0];
        partialSums[tgId].momentumX = sharedMX[0];
        partialSums[tgId].momentumY = sharedMY[0];
    }
}
