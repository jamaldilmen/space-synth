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
    float pad;
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
    float collisionRadius;
    int collisionsOn;
    float uncertaintyStrength;
    float eFieldStiffness;
    float bFieldCirculation;
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
    float k = u.modeP * M_PI_F / u.maxWaveDepth;

    float dynamicFric = baseFric;

    // Track potential energy for phase accumulation
    float PE = 0.0f;

    // Accumulate forces as position deltas (acceleration * dt²)
    float ax = 0.0f, ay = 0.0f, az = 0.0f;

    // Emitter Interactions (Macro forces)
    if (u.voiceCount > 0) {
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

            // Emitters induce a strong coherent spin field (B-field)
            // The spin magnitude and axis are modulated by the harmonic parameters m and n
            float spinMag = amp * 50.0f * (m_f == 0.0f ? 1.0f : sign(m_f));
            float3 emitterSpin = float3(
                sin(n_f * th) * spinMag * 0.5f, 
                cos(n_f * th) * spinMag * 0.5f, 
                spinMag * cos(m_f * r * 0.1f)
            );
            float3 rVec = float3(dx, dy, dz);
            
            // Biot-Savart induced velocity from the emitter's virtual vortex
            float3 inducedV = cross(emitterSpin, rVec) / (r2 * r);
            ax += inducedV.x * 0.15f;
            ay += inducedV.y * 0.15f;
            az += inducedV.z * 0.1f;

            // Simple radial pressure waves, layered with m and n spatial variations
            float wavePhase = k * r - m_f * th - n_f * phase;
            float pressure = cos(wavePhase) * amp * (5.0f + n_f);
            ax += (dx / r) * pressure;
            ay += (dy / r) * pressure;
            az += (dz / r) * pressure;

            jitterTotal += amp * abs(cos(m_f * th));
        }

        if (jitterTotal > 0.01f) {
            float n_strength = jitterTotal * 6.0f * u.dt;
            ax += noise(id, u.frameCounter) * n_strength;
            ay += noise(id + 1, u.frameCounter) * n_strength;
            az += noise(id + 2, u.frameCounter) * n_strength * (u.maxWaveDepth / 400.0f);
        }
    }

    // ── Noether Symmetry Breaking ─────────────────────────────────────
    if (u.symmetryBreakImpulse > 0.0f) {
        float angle = noise(id * 3u, u.frameCounter) * M_PI_F;
        float strength = u.symmetryBreakImpulse * (0.5f + noise(id * 7u, u.frameCounter) * 0.5f);
        ax += cos(angle) * strength;
        ay += sin(angle) * strength;
    }

    // ── Particle-Particle Collisions (spatial hash neighbor scan) ─────
    if (u.collisionsOn > 0 && su.gridSize > 0 && u.voiceCount > 0) {
        int cellX = clamp(int((px + 1.0f) * su.invCellSize), 0, su.gridSize - 1);
        int cellY = clamp(int((py + 1.0f) * su.invCellSize), 0, su.gridSize - 1);

        float colRad = u.collisionRadius;
        float colRad2 = colRad * colRad;

        int startCellX = max(0, cellX - 1);
        int endCellX = min(su.gridSize - 1, cellX + 1);
        int startCellY = max(0, cellY - 1);
        int endCellY = min(su.gridSize - 1, cellY + 1);

        float orig_px = px;
        float orig_py = py;
        float shiftX = 0.0f;
        float shiftY = 0.0f;
        float shiftVx = 0.0f;
        float shiftVy = 0.0f;

        float selfCharge = p.spinW.w;

        for (int y = startCellY; y <= endCellY; y++) {
            for (int x = startCellX; x <= endCellX; x++) {
                uint cID = uint(y * su.gridSize + x);
                uint count = min(cellCounts[cID], uint(MAX_PER_CELL));
                if (count == 0) continue;
                uint startIdx = cellStarts[cID];

                for (uint i = 0; i < count; i++) {
                    Particle np = sortedParticles[startIdx + i];

                    float ddx = orig_px - np.posW.x;
                    float ddy = orig_py - np.posW.y;
                    float dist2 = ddx * ddx + ddy * ddy;

                    if (dist2 > colRad2 || dist2 < 1e-12f) continue;

                    float dist = sqrt(dist2);
                    float nx_dir = ddx / dist;
                    float ny_dir = ddy / dist;
                    
                    // 1. E-Field Analog (Stiffness / Repulsion)
                    // Inverse-square repulsion to maintain spacing in the medium
                    float q1q2 = selfCharge * np.spinW.w;
                    float eForce = (u.eFieldStiffness * q1q2) / (dist2 + 1e-4f);
                    shiftVx += nx_dir * eForce * u.dt;
                    shiftVy += ny_dir * eForce * u.dt;

                    // 2. B-Field Analog (Circulation / Lorentz Force)
                    // Neighbor's spin induces a Biot-Savart velocity field on us
                    float3 neighborSpin = float3(np.spinW.x, np.spinW.y, np.spinW.z);
                    float3 rVec = float3(ddx, ddy, 0.0f); // 2D projection for now
                    float3 inducedV = cross(neighborSpin, rVec) / ((dist2 + 1e-4f) * dist);
                    
                    // The Lorentz force F = q(E + v x B)
                    // Here we simply add the induced velocity to our velocity proxy
                    shiftVx -= inducedV.x * u.bFieldCirculation * u.dt;
                    shiftVy -= inducedV.y * u.bFieldCirculation * u.dt;

                    // 3. Simple Elastic Physical Collision (for overlap resolution)
                    float overlap = colRad - dist;
                    float omass = np.posW.w;
                    float totalMass = mass + omass;
                    float pushRatio = omass / totalMass;
                    shiftX += nx_dir * overlap * pushRatio * 0.5f;
                    shiftY += ny_dir * overlap * pushRatio * 0.5f;

                    float np_vpx = np.posW.x - np.prevW.x;
                    float np_vpy = np.posW.y - np.prevW.y;
                    float dvx = vpx - np_vpx;
                    float dvy = vpy - np_vpy;
                    float dvDotN = dvx * nx_dir + dvy * ny_dir;

                    if (dvDotN < 0.0f) {
                        float impulse = (1.0f + COLLISION_RESTITUTION) * dvDotN * omass / totalMass;
                        shiftVx -= impulse * nx_dir;
                        shiftVy -= impulse * ny_dir;
                    }
                }
            }
        }

        // Position correction applied directly
        px += shiftX;
        py += shiftY;
        // Velocity impulse → adjust velocity proxy
        vpx += shiftVx;
        vpy += shiftVy;
    }

    // ── Retraction ────────────────────────────────────────────────────
    float R = 400.0f;
    float retractPull = (1.0f - min(u.totalAmplitude, 1.0f)) * 15.0f * u.retractionPull;

    if (u.sphereMode == 1) {
        float rx = px, ry = py, rz = pz / R;
        float rMag = sqrt(rx * rx + ry * ry + rz * rz);
        if (rMag > 0.001f) {
            float pull = (rMag - 0.35f) * retractPull;
            ax -= (rx / rMag) * pull * u.dt;
            ay -= (ry / rMag) * pull * u.dt;
            az -= (rz / rMag) * pull * u.dt * R;
        }
    } else {
        float rx = px, ry = py;
        float rMag = sqrt(rx * rx + ry * ry);
        if (rMag > 0.001f) {
            float pull = (rMag - 0.35f) * retractPull;
            ax -= (rx / rMag) * pull * u.dt;
            ay -= (ry / rMag) * pull * u.dt;
        }
        az -= (pz / R) * retractPull * u.dt * R * 0.5f;
    }

    // ── Störmer-Verlet integration (damped) ──────────────────────────
    // vpx/vpy/vpz = velocity proxy (displacement per frame)
    // ax/ay/az = force accumulated as position delta
    // dynamicFric = damping factor on velocity proxy

    vpx = vpx * dynamicFric + ax;
    vpy = vpy * dynamicFric + ay;
    vpz = vpz * dynamicFric + az;

    // Speed cap on velocity proxy
    float speedU = sqrt(vpx * vpx + vpy * vpy + (vpz / R) * (vpz / R));
    if (speedU > u.speedCap) {
        float s = u.speedCap / speedU;
        vpx *= s; vpy *= s; vpz *= s;
    }

    // Feynman phase accumulation: phase += (KE - PE) * dt
    float KE = 0.5f * mass * speedU * speedU;
    phase += (KE - PE) * u.dt;
    phase = fmod(phase + M_PI_F, 2.0f * M_PI_F) - M_PI_F;

    // New position = current + damped velocity proxy + acceleration
    float newX = px + vpx;
    float newY = py + vpy;
    float newZ = pz + vpz;

    // ── Boundary clamp ───────────────────────────────────────────────
    float R2 = 400.0f;
    if (u.sphereMode == 1) {
        float r3d = sqrt(newX * newX + newY * newY + (newZ / R2) * (newZ / R2));
        if (r3d > 0.96f) {
            float s = 0.95f / r3d;
            newX *= s;
            newY *= s;
            newZ *= s;
            // Bounce: invert velocity proxy
            vpx *= -0.3f; vpy *= -0.3f; vpz *= -0.3f;
        }
    } else {
        float rr = sqrt(newX * newX + newY * newY);
        if (rr > 0.96f) {
            newX = newX / rr * 0.95f;
            newY = newY / rr * 0.95f;
            vpx *= -0.3f; vpy *= -0.3f;
        }
        if (abs(newZ) > u.maxWaveDepth) {
            newZ = sign(newZ) * u.maxWaveDepth * 0.95f;
            vpz *= -0.3f;
        }
    }

    // ── Write back ───────────────────────────────────────────────────
    // Store previous position for next frame's Verlet step
    p.prevW = float4(px, py, pz, 0.0f);
    p.posW = float4(newX, newY, newZ, mass);
    // Store velocity proxy (for collision response and stats readback)
    p.velW = float4(vpx, vpy, vpz, phase);
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
        float R = 400.0f;
        ke = 0.5f * mass * (vx * vx + vy * vy + (vz / R) * (vz / R));
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
