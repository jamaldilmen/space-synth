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

kernel void compute_physics(
    device Particle* particles [[buffer(0)]],
    device const VoiceData* voices [[buffer(1)]],
    constant PhysicsUniforms& u [[buffer(2)]],
    device const Particle* prevParticles [[buffer(3)]],
    device const Particle* sortedParticles [[buffer(4)]],    // <--- Cache coherent structs
    device const uint* cellStarts [[buffer(5)]],
    device const uint* cellCounts [[buffer(6)]],
    constant SpatialHashUniforms& su [[buffer(7)]],
    uint id [[thread_position_in_grid]])
{
    if (int(id) >= u.particleCount) return;

    Particle p0 = prevParticles ? prevParticles[id] : particles[id];
    float px = p0.posW.x;
    float py = p0.posW.y;
    float pz = p0.posW.z;
    float mass = p0.posW.w;
    float vx = p0.velW.x;
    float vy = p0.velW.y;
    float vz = p0.velW.z;
    float phase = p0.velW.w;

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
    if (u.collisionsOn > 0 && su.gridSize > 0) {
        int cellX = clamp(int((px + 1.0f) * su.invCellSize), 0, su.gridSize - 1);
        int cellY = clamp(int((py + 1.0f) * su.invCellSize), 0, su.gridSize - 1);

        float colRad = u.collisionRadius;
        float colRad2 = colRad * colRad;

        int startCellX = max(0, cellX - 1);
        int endCellX = min(su.gridSize - 1, cellX + 1);
        int startCellY = max(0, cellY - 1);
        int endCellY = min(su.gridSize - 1, cellY + 1);

        // Iterate over neighbor cells (3x3 grid)
        for (int y = startCellY; y <= endCellY; y++) {
            for (int x = startCellX; x <= endCellX; x++) {
                uint cID = uint(y * su.gridSize + x);
                uint startIdx = cellStarts[cID];
                uint count = cellCounts[cID];

                for (uint i = 0; i < count; i++) {
                    uint nIdx = startIdx + i;
                    // We no longer read sortedIndices[nIdx]! 
                    // This is perfectly contiguous, cache-hot memory read.
                    Particle np = sortedParticles[nIdx]; 

                    // Skip self 
                    // (Since we don't have the explicit ID, we skip if distance is identically 0)
                    float4 nPos = np.posW;
                    float2 diff = float2(px, py) - nPos.xy;
                    float dist2 = dot(diff, diff);

                    if (dist2 > 0.01f && dist2 < colRad2) {
                        float dist = sqrt(dist2);
                        float overlap = colRad - dist;
                        float2 dir = diff / dist;
                        
                        // Push apart
                        px -= dir.x * overlap * 0.5f;
                        py -= dir.y * overlap * 0.5f;
                        
                        // Elastic collision impulse
                        float2 rVel = float2(vx, vy) - np.velW.xy;
                        float relVelAlongNormal = dot(rVel, dir);
                        if (relVelAlongNormal > 0.0f) {
                            float restitution = 0.5f;
                            float j = -(1.0f + restitution) * relVelAlongNormal;
                            // Assume equal mass for simplicity in the GPU step
                            j /= 2.0f; 
                            
                            vx += j * dir.x;
                            vy += j * dir.y;
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

    // Write back
    particles[id].posW = float4(px, py, pz, mass);
    particles[id].velW = float4(vx, vy, vz, phase);
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
