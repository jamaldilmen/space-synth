#include <metal_stdlib>
using namespace metal;

// GPU particle state — matches GPUParticle struct in C++ (64 bytes)
struct Particle {
    float4 posW;   // x, y, z, mass
    float4 velW;   // vx, vy, vz, phase
    float4 prevW;  // prevX, prevY, prevZ, temperature
    float4 spinW;  // spinX, spinY, spinZ, charge
};

struct VoiceData {
    int m;
    int n;
    float alpha;
    float amplitude;
    float emitterX;
    float emitterY;
    float emitterZ;
    float frequency; // explicitly carries frequency for E=mc2
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
};

struct SpatialHashUniforms {
    int gridSize;
    int particleCount;
    float cellSize;
    float invCellSize;
    int gridSizeZ;
};

// (Removed Bessel functions - no longer used)

// Temporal noise — hash uses frame counter for proper Brownian motion
static float noise(uint id, uint frame) {
    uint x = (id * 1103515245u + 12345u) ^ (frame * 2654435761u);
    x ^= x >> 16;
    x *= 0x45d9f3bu;
    x ^= x >> 16;
    return (float(x & 0x7FFFu) / 32767.0f) - 0.5f;
}

// Collision constants
constant int MAX_PER_CELL = 16;            // Safety valve for dense clusters
constant float COLLISION_RESTITUTION = 0.85f; // Slight energy loss per collision

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

    // Accumulate velocity pulses and position corrections globally
    float shiftX = 0.0f, shiftY = 0.0f, shiftZ = 0.0f;
    float shiftVx = 0.0f, shiftVy = 0.0f, shiftVz = 0.0f;

    // ── Global Harmonic Centering (The "Home" Force) ─────
    // F = -k * r. This ensures a crisp snapback to the center (0,0,0).
    float k_center = 0.15f * dt; 
    shiftVx -= px * k_center;
    shiftVy -= py * k_center;
    shiftVz -= pz * k_center;

    // Emitter Interactions (Macro forces)
    float baseMass = (mass > 1000.0f) ? mass : 1.0f;
    float dynamicMass = baseMass;

    if (u.voiceCount > 0 && baseMass < 1000.0f) {
        float massAdd = 0.0f;
        float jitterTotal = 0.0f;

        for (int vi = 0; vi < u.voiceCount; vi++) {
            float amp = voices[vi].amplitude;

            // Global attractive/repulsive forces from the emitter
            float dx = px - voices[vi].emitterX;
            float dy = py - voices[vi].emitterY;
            float dz = pz - voices[vi].emitterZ;
            float r2 = dx * dx + dy * dy + dz * dz + 1e-4f;
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

            // Phase 4: Mechanical Point Source Impulse (Death of Bessel)
            float pushRadius = 2.0f;
            if (r < pushRadius) {
                float impulseForce = amp * (1.0f - r / pushRadius) * 20.0f;
                shiftVx += (dx / r) * impulseForce;
                shiftVy += (dy / r) * impulseForce;
                shiftVz += (dz / r) * impulseForce;
            }

            jitterTotal += amp * abs(cos(m_f * th));
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
    if (u.symmetryBreakImpulse > 0.0f && u.voiceCount > 0) {
        float angle = noise(id * 3u, u.time) * M_PI_F;
        float strength = u.symmetryBreakImpulse * (0.5f + noise(id * 7u, u.time) * 0.5f);
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

    // ── Global Gravity Anchor (Potato Core) ───────────────────────────
    // Instead of forcing the medium flat onto the Z-plane, we use a 3D spherical 
    // harmonic trap. This balances the local E-Field repulsion to form a solid, 
    // uniform spherical volume (a true "Potato") rather than a hollow shell.
    // Heavy Walls (dynamicMass == 0) ignore global gravity.
    // ── Global Gravity Anchor (Potato Core) ───────────────────────────
    if (dynamicMass > 0.0f && u.voiceCount > 0) {
        float globalPull = u.gravityConstant * 5.0f * dt; 
        shiftVx -= px * globalPull;
        shiftVy -= py * globalPull;
        shiftVz -= pz * globalPull;
    }

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

                        if (dist2 > colRad2 || dist2 < 1e-12f) continue;

                        float dist = sqrt(dist2);
                        float nx_dir = ddx / dist;
                        float ny_dir = ddy / dist;
                        float nz_dir = ddz / dist;

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
    // vpx/vpy/vpz = velocity proxy (displacement per frame)
    // ax/ay/az = force accumulated as position delta
    // dynamicFric = damping factor on velocity proxy

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
    float3 nextPos = float3(px, py, pz) + finalV + float3(shiftX, shiftY, shiftZ);

    // Phase accumulation
    float newPhase = p.velW.w + speed * dt;

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
