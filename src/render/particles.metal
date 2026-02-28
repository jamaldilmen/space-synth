#include <metal_stdlib>
using namespace metal;

// GPU particle state — matches GPUParticle struct in C++
struct Particle {
    float4 posW;   // x, y, z, pad
    float4 velW;   // vx, vy, vz, pad
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
    float padding[2];
};

// ── Bessel J_n(x) — power series, 15 terms sufficient for GPU ───────────────

static float besselJ(int n, float x) {
    if (abs(x) < 1e-6f) return n == 0 ? 1.0f : 0.0f;

    float sum = 0.0f;
    float hx = x * 0.5f;
    float term = 1.0f;

    // Compute initial term: (x/2)^n / n!
    for (int i = 1; i <= n; i++) {
        term *= hx / float(i);
    }
    sum = term;

    // Add remaining terms of series
    float hx2 = -hx * hx;  // negative for alternating sign
    for (int k = 1; k < 15; k++) {
        term *= hx2 / (float(k) * float(k + n));
        sum += term;
        if (abs(term) < 1e-10f) break;
    }

    return sum;
}

// Simple hash for noise
static float noise(uint id, float dt) {
    uint x = id * 1103515245 + 12345;
    return (float((x / 65536) % 32768) / 32767.0f) - 0.5f;
}

// ── Compute kernel: update particle positions/velocities ────────────────────

kernel void particle_physics(
    device Particle* particles [[buffer(0)]],
    device const VoiceData* voices [[buffer(1)]],
    constant PhysicsUniforms& u [[buffer(2)]],
    uint id [[thread_position_in_grid]])
{
    if (int(id) >= u.particleCount) return;

    device Particle& p = particles[id];
    float px = p.posW.x;
    float py = p.posW.y;
    float pz = p.posW.z;
    float vx = p.velW.x;
    float vy = p.velW.y;
    float vz = p.velW.z;

    float r = sqrt(px * px + py * py);
    float th = atan2(py, px);

    float baseFric = pow(0.06f, u.dt);
    float k = M_PI_F / u.maxWaveDepth;
    float kz = k * pz;

    float dynamicFric = baseFric;

    if (u.voiceCount > 0) {
        float polyNorm = 1.0f / sqrt(float(u.voiceCount));
        float fxTotal = 0.0f, fyTotal = 0.0f, fzTotal = 0.0f;
        float jitterTotal = 0.0f;

        for (int vi = 0; vi < u.voiceCount; vi++) {
            float m_f = float(voices[vi].m);
            float alpha = voices[vi].alpha;
            float amp = voices[vi].amplitude;

            float w = min(amp, 1.0f) * 0.45f * polyNorm;

            float alpha_r = alpha * r;
            float jm = besselJ(voices[vi].m, alpha_r);
            float phase = m_f * th - kz;
            float cos_p = cos(phase);
            float h3d = jm * cos_p;

            // Potential P = (J_m(alpha*r) * cos(phase))^2
            // dP/dr = 2 * J_m * J'_m * alpha * cos^2(phase)
            float jm_prime;
            if (voices[vi].m == 0) {
                jm_prime = -besselJ(1, alpha_r);
            } else {
                jm_prime = 0.5f * (besselJ(voices[vi].m - 1, alpha_r) - besselJ(voices[vi].m + 1, alpha_r));
            }

            float dP_dr = 2.0f * jm * jm_prime * alpha * cos_p * cos_p;
            
            // Boundary potential
            if (r > 0.85f) {
                float t = (r - 0.85f) / 0.13f;
                dP_dr += (0.5f * 3.0f / 0.13f) * t * t;
            }

            // dP/dth = -m * J_m^2 * sin(2*phase)
            float dP_dth = -m_f * jm * jm * sin(2.0f * phase);

            // Polar to Cartesian
            float r_inv = 1.0f / (r + 1e-6f);
            float dr_dx = px * r_inv;
            float dr_dy = py * r_inv;
            float dth_dx = -py * r_inv * r_inv;
            float dth_dy = px * r_inv * r_inv;

            float gx = (dP_dr * dr_dx + dP_dth * dth_dx);
            float gy = (dP_dr * dr_dy + dP_dth * dth_dy);

            // Normalize analytical gradient to match HTML's LUT behavior
            float gradMag = sqrt(gx * gx + gy * gy + 1e-6f);
            if (gradMag > 0.001f) {
                gx /= gradMag;
                gy /= gradMag;
            }

            fxTotal -= gx * w;
            fyTotal -= gy * w;

            // dP/dz = k * J_m^2 * sin(2*phase)
            float gz = k * jm * jm * sin(2.0f * phase);
            // Specific center jitter for m=0 (from reference)
            if (voices[vi].m == 0 && abs(pz) < 2.0f) {
                gz += noise(id + 1000, u.dt) * jm * jm * k;
            }
            fzTotal -= gz * w * 200.0f; // Align with HTML scaling

            jitterTotal += abs(h3d) * amp;
        }

        vx += fxTotal;
        vy += fyTotal;
        vz += fzTotal;

        // Amplitude-modulated noise (Jitter)
        if (jitterTotal > 0.01f) {
            float velMagU = sqrt(vx * vx + vy * vy + (vz / 400.0f) * (vz / 400.0f));
            if (velMagU > 0.001f) {
                float n = jitterTotal * 6.0f * u.dt;
                vx += noise(id, u.dt) * n;
                vy += noise(id + 1, u.dt) * n;
                vz += noise(id + 2, u.dt) * n * 400.0f;
            }
        }

        // Apply jitter
        if (jitterTotal > 0.01f) {
            float n = jitterTotal * 12.0f * u.dt;
            vx += noise(id, u.dt) * n;
            vy += noise(id + 1, u.dt) * n;
            vz += noise(id + 2, u.dt) * n * (u.maxWaveDepth / 400.0f);
        }

        // Node braking
        if (u.totalAmplitude > 0.01f) {
            float distToNode = jitterTotal / u.totalAmplitude;
            float nodeBrake = min(1.0f, distToNode * 3.5f + 0.15f);
            dynamicFric = baseFric * nodeBrake;
        }
    }

    // 3D Spherical Retraction Pull
    float R = 400.0f;
    float rx = px;
    float ry = py;
    float rz = pz / R;
    float rMag = sqrt(rx * rx + ry * ry + rz * rz);
    
    float retractPull = (1.0f - u.totalAmplitude) * 15.0f;
    if (rMag > 0.001f) {
        float pull = (rMag - 0.35f) * retractPull;
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
    if (speedU > 1.2f) {
        float s = 1.2f / speedU;
        vx *= s; vy *= s; vz *= s;
    }

    // Integrate
    px += vx * u.dt * 60.0f;
    py += vy * u.dt * 60.0f;
    pz += vz * u.dt * 60.0f;

    // Boundary clamp
    float rr = sqrt(px * px + py * py);
    if (rr > 0.96f) {
        px = px / rr * 0.95f;
        py = py / rr * 0.95f;
        vx *= -0.3f; vy *= -0.3f;
    }

    // Z clamp
    if (abs(pz) > u.maxWaveDepth) {
        pz = sign(pz) * u.maxWaveDepth * 0.95f;
        vz *= -0.3f;
    }

    p.posW = float4(px, py, pz, 0.0f);
    p.velW = float4(vx, vy, vz, 0.0f);
}
