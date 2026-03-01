#include <metal_stdlib>
using namespace metal;

// GPU particle state — matches GPUParticle struct in C++
struct Particle {
    float4 posW;   // x, y, z, mass
    float4 velW;   // vx, vy, vz, phase
};

struct VoiceData {
    int m;
    int n;
    float alpha;
    float amplitude;
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
constant int MAX_PER_CELL = 32;            // Safety valve for dense clusters
constant float COLLISION_RESTITUTION = 0.85f; // Slight energy loss per collision

// ── Compute kernel: update particle positions/velocities ────────────────────

kernel void particle_physics(
    device Particle* particles [[buffer(0)]],
    device const VoiceData* voices [[buffer(1)]],
    constant PhysicsUniforms& u [[buffer(2)]],
    device const Particle* particlesRead [[buffer(3)]],
    device const uint* sortedIndices [[buffer(4)]],
    device const uint* cellStarts [[buffer(5)]],
    device const uint* cellCounts [[buffer(6)]],
    constant SpatialHashUniforms& sh [[buffer(7)]],
    uint id [[thread_position_in_grid]])
{
    if (int(id) >= u.particleCount) return;

    device Particle& p = particles[id];
    float px = p.posW.x;
    float py = p.posW.y;
    float pz = p.posW.z;
    float mass = p.posW.w;
    float vx = p.velW.x;
    float vy = p.velW.y;
    float vz = p.velW.z;
    float phase = p.velW.w;

    float r = sqrt(px * px + py * py);
    float th = atan2(py, px);

    float baseFric = pow(0.06f, u.dt);
    float k = u.modeP * M_PI_F / u.maxWaveDepth;
    float kz = k * pz;

    float dynamicFric = baseFric;

    // Track potential energy for phase accumulation
    float PE = 0.0f;

    if (u.voiceCount > 0) {
        float polyNorm = 1.0f / sqrt(float(u.voiceCount));
        float fxTotal = 0.0f, fyTotal = 0.0f, fzTotal = 0.0f;
        float jitterTotal = 0.0f;

        for (int vi = 0; vi < u.voiceCount; vi++) {
            float m_f = float(voices[vi].m);
            float alpha = voices[vi].alpha;
            float amp = voices[vi].amplitude;

            float w = min(amp, 1.0f) * 27.0f * polyNorm;

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

            if (r > 0.85f) {
                float t = (r - 0.85f) / 0.13f;
                dP_dr += (0.5f * 3.0f / 0.13f) * t * t;
            }

            float dP_dth = -m_f * jm * jm * sin(2.0f * phaseAngle);

            float r_inv = 1.0f / (r + 1e-6f);
            float dr_dx = px * r_inv;
            float dr_dy = py * r_inv;
            float dth_dx = -py * r_inv * r_inv;
            float dth_dy = px * r_inv * r_inv;

            float gx = (dP_dr * dr_dx + dP_dth * dth_dx);
            float gy = (dP_dr * dr_dy + dP_dth * dth_dy);

            fxTotal -= gx * w;
            fyTotal -= gy * w;

            float gz = k * jm * jm * sin(2.0f * phaseAngle);
            if (voices[vi].m == 0 && abs(pz) < 2.0f) {
                gz += noise(id + 1000, u.frameCounter) * jm * jm * k;
            }
            fzTotal -= gz * w * 200.0f;

            jitterTotal += abs(h3d) * amp;
        }

        // Apply Bessel forces (F = ma, a = F/m)
        float invMass = 1.0f / mass;
        vx += fxTotal * u.dt * invMass;
        vy += fyTotal * u.dt * invMass;
        vz += fzTotal * u.dt * invMass;

        // Uncertainty-motivated jitter
        if (jitterTotal > 0.01f) {
            float distToNode = jitterTotal / u.totalAmplitude;
            float uncertainty = max(0.0f, 1.0f - distToNode * 3.0f);
            float n_strength = (jitterTotal * 6.0f + uncertainty * 12.0f) * u.dt * u.jitterFactor;
            vx += noise(id, u.frameCounter) * n_strength;
            vy += noise(id + 1, u.frameCounter) * n_strength;
            vz += noise(id + 2, u.frameCounter) * n_strength * (u.maxWaveDepth / 400.0f);
        }

        // Node braking
        if (u.totalAmplitude > 0.01f) {
            float distToNode = jitterTotal / u.totalAmplitude;
            float nodeBrake = min(1.0f, distToNode * 3.5f + 0.15f);
            dynamicFric = pow(u.damping, u.dt) * nodeBrake;
        }
    }

    // ── Noether Symmetry Breaking ─────────────────────────────────────
    // On mode change, inject random impulse (energy release)
    if (u.symmetryBreakImpulse > 0.0f) {
        float angle = noise(id * 3u, u.frameCounter) * M_PI_F;
        float strength = u.symmetryBreakImpulse * (0.5f + noise(id * 7u, u.frameCounter) * 0.5f);
        vx += cos(angle) * strength;
        vy += sin(angle) * strength;
    }

    // ── Particle-Particle Collisions (spatial hash neighbor scan) ────────
    if (u.collisionsOn > 0 && sh.gridSize > 0) {
        int cellX = clamp(int((px + 1.0f) * sh.invCellSize), 0, sh.gridSize - 1);
        int cellY = clamp(int((py + 1.0f) * sh.invCellSize), 0, sh.gridSize - 1);

        float collRadius = u.collisionRadius;
        float collRadius2 = collRadius * collRadius;

        // Scan 9 neighbor cells
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                int nx = cellX + dx;
                int ny = cellY + dy;
                if (nx < 0 || nx >= sh.gridSize || ny < 0 || ny >= sh.gridSize) continue;

                int cellID = ny * sh.gridSize + nx;
                uint start = cellStarts[cellID];
                uint count = min(cellCounts[cellID], uint(MAX_PER_CELL));

                for (uint j = 0; j < count; j++) {
                    uint otherIdx = sortedIndices[start + j];
                    if (otherIdx == id) continue;

                    // Read other particle from snapshot (double-buffer)
                    float ox = particlesRead[otherIdx].posW.x;
                    float oy = particlesRead[otherIdx].posW.y;
                    float omass = particlesRead[otherIdx].posW.w;
                    float ovx = particlesRead[otherIdx].velW.x;
                    float ovy = particlesRead[otherIdx].velW.y;

                    // 2D distance check (collisions in XY plane)
                    float ddx = px - ox;
                    float ddy = py - oy;
                    float dist2 = ddx * ddx + ddy * ddy;

                    if (dist2 < collRadius2 && dist2 > 1e-12f) {
                        float dist = sqrt(dist2);
                        float nx_dir = ddx / dist;
                        float ny_dir = ddy / dist;

                        // Position correction: push apart by half overlap
                        float overlap = collRadius - dist;
                        float totalMass = mass + omass;
                        float pushRatio = omass / totalMass;
                        px += nx_dir * overlap * pushRatio * 0.5f;
                        py += ny_dir * overlap * pushRatio * 0.5f;

                        // Elastic collision impulse along normal
                        float dvx = vx - ovx;
                        float dvy = vy - ovy;
                        float dvDotN = dvx * nx_dir + dvy * ny_dir;

                        // Only resolve if approaching
                        if (dvDotN < 0.0f) {
                            float impulse = (1.0f + COLLISION_RESTITUTION) * dvDotN * omass / totalMass;
                            vx -= impulse * nx_dir;
                            vy -= impulse * ny_dir;
                        }
                    }
                }
            }
        }
    }

    // 3D Spherical Retraction Pull
    float R = 400.0f;
    float rx = px;
    float ry = py;
    float rz = pz / R;
    float rMag = sqrt(rx * rx + ry * ry + rz * rz);

    float retractPull = (1.0f - u.totalAmplitude) * 15.0f * u.retractionPull;
    if (rMag > 0.001f) {
        float targetR = (u.sphereMode == 1) ? 0.75f : 0.35f;
        float pullMultiplier = (u.sphereMode == 1) ? 2.0f : 1.0f;
        float pull = (rMag - targetR) * retractPull * pullMultiplier;
        vx -= (rx / rMag) * pull * u.dt;
        vy -= (ry / rMag) * pull * u.dt;
        vz -= (rz / rMag) * pull * u.dt * R;
    }

    // Friction
    vx *= dynamicFric;
    vy *= dynamicFric;
    vz *= dynamicFric;

    // Speed cap
    float speedU = sqrt(vx * vx + vy * vy + (vz / R) * (vz / R));
    if (speedU > u.speedCap) {
        float s = u.speedCap / speedU;
        vx *= s; vy *= s; vz *= s;
    }

    // Feynman phase accumulation: phase += (KE - PE) * dt
    float KE = 0.5f * mass * (vx * vx + vy * vy + (vz / R) * (vz / R));
    phase += (KE - PE) * u.dt;
    phase = fmod(phase + M_PI_F, 2.0f * M_PI_F) - M_PI_F;

    // Integrate position (frame-rate independent)
    px += vx * u.dt;
    py += vy * u.dt;
    pz += vz * u.dt;

    // Boundary clamp
    float R2 = 400.0f;
    if (u.sphereMode == 1) {
        float r3d = sqrt(px * px + py * py + (pz / R2) * (pz / R2));
        if (r3d > 0.96f) {
            float s = 0.95f / r3d;
            px *= s;
            py *= s;
            pz *= s;
            vx *= -0.3f; vy *= -0.3f; vz *= -0.3f;
        }
    } else {
        float rr = sqrt(px * px + py * py);
        if (rr > 0.96f) {
            px = px / rr * 0.95f;
            py = py / rr * 0.95f;
            vx *= -0.3f; vy *= -0.3f;
        }
        if (abs(pz) > u.maxWaveDepth) {
            pz = sign(pz) * u.maxWaveDepth * 0.95f;
            vz *= -0.3f;
        }
    }

    p.posW = float4(px, py, pz, mass);
    p.velW = float4(vx, vy, vz, phase);
}

// ── Conservation law reduction kernel ───────────────────────────────────────
// Per-threadgroup partial sums written to buffer, CPU does final sum.
// With 800k/256 = 3125 threadgroups, CPU sum is trivial.

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

    // Tree reduction within threadgroup
    for (uint stride = tgSize / 2; stride > 0; stride >>= 1) {
        if (tid < stride) {
            sharedKE[tid] += sharedKE[tid + stride];
            sharedMX[tid] += sharedMX[tid + stride];
            sharedMY[tid] += sharedMY[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // First thread writes this threadgroup's partial sum
    if (tid == 0) {
        partialSums[tgId].kineticEnergy = sharedKE[0];
        partialSums[tgId].momentumX = sharedMX[0];
        partialSums[tgId].momentumY = sharedMY[0];
    }
}
