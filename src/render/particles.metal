#include <metal_stdlib>
using namespace metal;

// GPU particle state — matches GPUParticle struct in C++ (48 bytes)
struct Particle {
    float4 posW;   // x, y, z, mass
    float4 velW;   // vx, vy, vz, phase
    float4 prevW;  // prevX, prevY, prevZ, pad (Störmer-Verlet)
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
};

struct SpatialHashUniforms {
    int gridSize;
    int particleCount;
    float cellSize;
    float invCellSize;
};

// ── Bessel J_n(x) — power series, 15 terms sufficient for GPU ───────────────

static float besselJ(int n, float x) {
    if (abs(x) < 1e-6f) return n == 0 ? 1.0f : 0.0f;

    float sum = 0.0f;
    float hx = x * 0.5f;
    float term = 1.0f;

    for (int i = 1; i <= n; i++) {
        term *= hx / float(i);
    }
    sum = term;

    float hx2 = -hx * hx;
    for (int k = 1; k < 15; k++) {
        term *= hx2 / (float(k) * float(k + n));
        sum += term;
        if (abs(term) < 1e-10f) break;
    }

    return sum;
}

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

    if (u.voiceCount > 0) {
        float polyNorm = 1.0f / sqrt(float(u.voiceCount));
        float jitterTotal = 0.0f;

        for (int vi = 0; vi < u.voiceCount; vi++) {
            float m_f = float(voices[vi].m);
            float amp = voices[vi].amplitude;

            // Compute r and theta relative to emitter position
            float dx = px - voices[vi].emitterX;
            float dy = py - voices[vi].emitterY;
            float dz = pz - voices[vi].emitterZ;
            float r = sqrt(dx * dx + dy * dy);
            float th = atan2(dy, dx);
            float kz = k * dz;

            // Match HTML: w = min(amp, 1) * 0.45 * polyNormalizer
            float w = min(amp, 1.0f) * 0.45f * polyNorm;

            float alpha = voices[vi].alpha;
            float alpha_r = alpha * r;
            float jm = besselJ(voices[vi].m, alpha_r);
            float phaseAngle = m_f * th - kz;
            float cos_p = cos(phaseAngle);
            float h3d = jm * cos_p;

            PE += h3d * h3d * w;

            float jm_prime;
            if (voices[vi].m == 0) {
                jm_prime = -besselJ(1, alpha_r);
            } else {
                jm_prime = 0.5f * (besselJ(voices[vi].m - 1, alpha_r) - besselJ(voices[vi].m + 1, alpha_r));
            }

            float dP_dr = 2.0f * jm * jm_prime * alpha * cos_p * cos_p;

            float dP_dth = -m_f * jm * jm * sin(2.0f * phaseAngle);

            float r_inv = 1.0f / (r + 1e-6f);
            float dr_dx = dx * r_inv;
            float dr_dy = dy * r_inv;
            float dth_dx = -dy * r_inv * r_inv;
            float dth_dy = dx * r_inv * r_inv;

            float gx = (dP_dr * dr_dx + dP_dth * dth_dx) * 3.0f;
            float gy = (dP_dr * dr_dy + dP_dth * dth_dy) * 3.0f;

            ax -= gx * w;
            ay -= gy * w;

            float gz = k * jm * jm * sin(2.0f * phaseAngle);
            if (voices[vi].m == 0 && abs(dz) < 2.0f) {
                gz += noise(id + 1000, u.frameCounter) * jm * jm * k;
            }
            az -= gz * w * 800.0f;

            jitterTotal += abs(h3d) * amp;
        }

        // Match HTML jitter: simpler formula
        if (jitterTotal > 0.01f) {
            float n_strength = jitterTotal * 6.0f * u.dt;
            ax += noise(id, u.frameCounter) * n_strength;
            ay += noise(id + 1, u.frameCounter) * n_strength;
            az += noise(id + 2, u.frameCounter) * n_strength * (u.maxWaveDepth / 400.0f);
        }

        // Node braking
        if (u.totalAmplitude > 0.01f) {
            float distToNode = jitterTotal / u.totalAmplitude;
            float nodeBrake = min(1.0f, distToNode * 3.5f + 0.15f);
            dynamicFric = baseFric * nodeBrake;
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

                    // Push APART by half overlap
                    float overlap = colRad - dist;
                    float omass = np.posW.w;
                    float totalMass = mass + omass;
                    float pushRatio = omass / totalMass;
                    shiftX += nx_dir * overlap * pushRatio * 0.5f;
                    shiftY += ny_dir * overlap * pushRatio * 0.5f;

                    // Elastic collision impulse using derived velocities
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
