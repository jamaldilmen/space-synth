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
    float k = M_PI_F / u.maxWaveDepth;  // modeP=1 for now
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

            float jm = besselJ(voices[vi].m, alpha * r);
            float phase = m_f * th - kz;
            float h3d = jm * cos(phase);

            // Analytical gradient of Bessel function
            // J'_m(x) = 0.5 * (J_{m-1}(x) - J_{m+1}(x))
            // where x = alpha * r
            // Let F(r, th) = J_m(alpha * r) * cos(m*th - kz)
            // dF/dx = dF/dr * dr/dx + dF/dth * dth/dx
            // dr/dx = x/r,  dth/dx = -y/r^2
            // dr/dy = y/r,  dth/dy = x/r^2

            float alpha_r = alpha * r;
            // Derivative of J_m with respect to its argument
            float jm_prime;
            if (voices[vi].m == 0) {
                jm_prime = -besselJ(1, alpha_r);
            } else {
                jm_prime = 0.5f * (besselJ(voices[vi].m - 1, alpha_r) - besselJ(voices[vi].m + 1, alpha_r));
            }

            // Chain rule for dr
            float dJ_dr = alpha * jm_prime;
            float cos_term = cos(phase);
            float sin_term = sin(phase);

            // dF/dr = dJ_dr * cos_term
            float dF_dr = dJ_dr * cos_term;

            // dF/dth = J_m * (-m * sin_term)
            float dF_dth = jm * (-m_f * sin_term);

            // Convert polar gradients to Cartesian gradients
            float r_inv = 1.0f / (r + 1e-6f);
            float dr_dx = px * r_inv;
            float dr_dy = py * r_inv;
            float dth_dx = -py * r_inv * r_inv;
            float dth_dy = px * r_inv * r_inv;

            float gx = dF_dr * dr_dx + dF_dth * dth_dx;
            float gy = dF_dr * dr_dy + dF_dth * dth_dy;

            // Notice we subtracted gx*w earlier so we keep the sign.
            // The numerical code was (F(x+eps) - F(x-eps))/(2eps).
            // Here gx is exactly dF/dx.
            // Force is minus gradient of the 'potential' if w is positive amplitude.
            fxTotal -= gx * w;
            fyTotal -= gy * w;

            // Z-axis gradient
            float zGrad = k * jm * jm * sin(2.0f * phase);
            fzTotal -= zGrad * w * 200.0f;

            jitterTotal += abs(h3d) * amp;
        }

        vx += fxTotal;
        vy += fyTotal;
        vz += fzTotal;

        // Node braking
        if (u.totalAmplitude > 0.01f) {
            float distToNode = jitterTotal / u.totalAmplitude;
            float nodeBrake = min(1.0f, distToNode * 3.5f + 0.15f);
            dynamicFric = baseFric * nodeBrake;
        }
    }

    // Retraction pull (gentle — keep particles spread on the plate at rest)
    float retractPull = (1.0f - u.totalAmplitude) * 1.5f;
    float R = u.plateRadius;

    // Only retract Z toward 0 (flatten onto plate), leave XY alone
    float vzN = pz / (R > 0 ? R : 1.0f);
    vz -= vzN * retractPull * u.dt * R;

    // Boundary push — keep particles inside the plate radius
    float rXY = sqrt(px * px + py * py);
    if (rXY > 0.85f) {
        float push = (rXY - 0.85f) * retractPull * 8.0f;
        float rInv = 1.0f / (rXY + 1e-6f);
        vx -= px * rInv * push * u.dt;
        vy -= py * rInv * push * u.dt;
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

    // Boundary clamp (circular plate)
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
