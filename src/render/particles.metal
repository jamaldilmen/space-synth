#include <metal_stdlib>
using namespace metal;

// GPU particle state — matches GPUParticle struct in C++ (64 bytes)
struct Particle {
    float4 posW;   // x, y, z, mass
    float4 velW;   // vx, vy, vz, phase
    float4 prevW;  // prevX, prevY, prevZ, pad (Störmer-Verlet)
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
    float dt;
    float totalAmplitude;
    int voiceCount;
    int particleCount;
    float maxWaveDepth;
    float plateRadius;
    float jitterFactor;
    float retractionPull;
    float damping;
    float speedCap;
    float modeP;
    int simMode;
    int sphereMode;
    uint frameCounter;
    float symmetryBreakImpulse;
    float collisionRadius;      // Interaction radius for collisions
    int collisionsOn;           // 1 = collisions enabled
    float uncertaintyStrength;
    float eFieldStiffness;      // E-Field repulsion multiplier
    float bFieldCirculation;    // B-Field circulation force
    float time;                 // Continuous time
    float gravityConstant;      // G for Newtonian Self-Gravity
    float stringStiffness;      // Hooke's Law Tensegrity Constant
    float restLength;           // Ideal neighbor distance for Strings
    int gridSizeZ;              // Height of 3D grid
};

struct SpatialHashUniforms {
    int gridSize;
    int particleCount;
    float cellSize;
    float invCellSize;
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
    // This IS the velocity in frame-time units (removes * 60 hack)
    float vpx = px - prevX;
    float vpy = py - prevY;
    float vpz = pz - prevZ;

    float baseFric = pow(0.06f, u.dt);

    float dynamicFric = baseFric;

    // Track potential energy for phase accumulation
    float PE = 0.0f;

    // Accumulate velocity pulses and position corrections globally
    float shiftX = 0.0f, shiftY = 0.0f, shiftZ = 0.0f;
    float shiftVx = 0.0f, shiftVy = 0.0f, shiftVz = 0.0f;

    // ── Global Harmonic Centering (The "Home" Force) ─────
    // F = -k * r. This ensures a crisp snapback to the center (0,0,0).
    float k_center = 0.15f * u.dt; 
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

        if (jitterTotal > 0.01f) {
            float n_strength = jitterTotal * 6.0f * u.dt;
            shiftVx += noise(id, u.time) * n_strength;
            shiftVy += noise(id + 1, u.time) * n_strength;
            shiftVz += noise(id + 2, u.time) * n_strength;
        }
    }

    // ── Noether Symmetry Breaking ─────────────────────────────────────
    if (u.symmetryBreakImpulse > 0.0f && u.voiceCount > 0) {
        float angle = noise(id * 3u, u.time) * M_PI_F;
        float strength = u.symmetryBreakImpulse * (0.5f + noise(id * 7u, u.time) * 0.5f);
        shiftVx += cos(angle) * strength;
        shiftVy += sin(angle) * strength;
    }

    // ── Global Gravity Anchor (Potato Core) ───────────────────────────
    // Instead of forcing the medium flat onto the Z-plane, we use a 3D spherical 
    // harmonic trap. This balances the local E-Field repulsion to form a solid, 
    // uniform spherical volume (a true "Potato") rather than a hollow shell.
    // Heavy Walls (dynamicMass == 0) ignore global gravity.
    // ── Global Gravity Anchor (Potato Core) ───────────────────────────
    if (dynamicMass > 0.0f && u.voiceCount > 0) {
        float globalPull = u.gravityConstant * 5.0f * u.dt; 
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
                        float r2_clamped = max(dist2, 1e-7f);
                        float q1q2 = selfCharge * np.spinW.w;
                        float eForce = (u.eFieldStiffness * q1q2) / r2_clamped;
                        
                        if (dynamicMass > 0.0f) {
                            float eAcc = (eForce / dynamicMass) * u.dt;
                            shiftVx += nx_dir * eAcc;
                            shiftVy += ny_dir * eAcc;
                            shiftVz += nz_dir * eAcc;
                        }

                        // 2. Strong Nuclear / Hooke's Law Tensegrity (String Theory Phase 5)
                        float stringForce = u.stringStiffness * (dist - u.restLength);
                        if (dynamicMass > 0.0f) {
                            float sAcc = (stringForce / dynamicMass) * u.dt;
                            shiftVx -= nx_dir * sAcc;
                            shiftVy -= ny_dir * sAcc;
                            shiftVz -= nz_dir * sAcc;
                        }

                        // 3. The Potato Radius (Newtonian Self-Gravity Phase 5)
                        float nMass = (np.posW.w == 0.0f) ? 1.0f : np.posW.w;
                        float massProd = dynamicMass * nMass;
                        float gravForce = u.gravityConstant * massProd / r2_clamped;
                        if (dynamicMass > 0.0f) {
                            float gAcc = (gravForce / dynamicMass) * u.dt;
                            shiftVx -= nx_dir * gAcc;
                            shiftVy -= ny_dir * gAcc;
                            shiftVz -= nz_dir * gAcc;
                        }

                        // 4. B-Field Analog (Circulation / Lorentz Force)
                        float3 neighborSpin = float3(np.spinW.x, np.spinW.y, np.spinW.z);
                        float3 rVec = float3(ddx, ddy, ddz);
                        float3 inducedV = cross(neighborSpin, rVec) / (r2_clamped * dist);
                        if (dynamicMass > 0.0f) {
                            shiftVx -= inducedV.x * u.bFieldCirculation * u.dt;
                            shiftVy -= inducedV.y * u.bFieldCirculation * u.dt;
                            shiftVz -= inducedV.z * u.bFieldCirculation * u.dt;
                        }

                        // 5. Simple Elastic Physical Collision (overlap resolution)
                        float overlap = colRad - dist;
                        float omass = np.posW.w;
                        if (dynamicMass > 0.0f) {
                            float pushRatio = (omass == 0.0f) ? 1.0f : (omass / (dynamicMass + omass));
                            shiftX += nx_dir * overlap * pushRatio * 0.5f;
                            shiftY += ny_dir * overlap * pushRatio * 0.5f;
                            shiftZ += nz_dir * overlap * pushRatio * 0.5f;

                            float np_vpx = np.posW.x - np.prevW.x;
                            float np_vpy = np.posW.y - np.prevW.y;
                            float np_vpz = np.posW.z - np.prevW.z;
                            float dvx = vpx - np_vpx;
                            float dvy = vpy - np_vpy;
                            float dvz = vpz - np_vpz;
                            float dvDotN = dvx * nx_dir + dvy * ny_dir + dvz * nz_dir;

                            if (dvDotN < 0.0f) {
                                float impulse = (1.0f + COLLISION_RESTITUTION) * dvDotN * pushRatio;
                                shiftVx -= impulse * nx_dir;
                                shiftVy -= impulse * ny_dir;
                                shiftVz -= impulse * nz_dir;
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
    vpx = vpx * dynamicFric + shiftVx;
    vpy = vpy * dynamicFric + shiftVy;
    vpz = vpz * dynamicFric + shiftVz;

    // Speed cap on velocity proxy
    float speedU = sqrt(vpx * vpx + vpy * vpy + vpz * vpz);
    if (speedU > u.speedCap) {
        float s = u.speedCap / speedU;
        vpx *= s; vpy *= s; vpz *= s;
    }

    // Feynman phase accumulation: phase += (KE - PE) * dt
    float KE = 0.5f * mass * speedU * speedU;
    phase += (KE - PE) * u.dt;
    phase = fmod(phase + M_PI_F, 2.0f * M_PI_F) - M_PI_F;

    // New position = current + damped velocity proxy + acceleration
    // New position = current + velocity proxy + position resolution (shiftX)
    float newX = px + vpx + shiftX;
    float newY = py + vpy + shiftY;
    float newZ = pz + vpz + shiftZ;

    // ── Write back ───────────────────────────────────────────────────
    // Store previous position for next frame's Verlet step
    // HEAVY WALLS (mass == 0) ARE IMMUTABLE
    if (mass > 0.0f) {
        p.prevW = float4(px, py, pz, 0.0f);
        p.posW = float4(newX, newY, newZ, mass);
        // Store velocity proxy (for collision response and stats readback)
        p.velW = float4(vpx, vpy, vpz, phase);
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
