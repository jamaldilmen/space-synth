#include <metal_stdlib>
using namespace metal;

// ─────────────────────────────────────────────────────────────────────────────
// REAL Schwarzschild geodesic black-hole render (Approach A, 2026-06-28).
// Per screen pixel we integrate an actual null geodesic in the Schwarzschild
// metric (units: r_s = 1.0 sim, M = r_s/2) and render the analytic accretion
// disk it crosses — front disk + the far side lensed OVER and UNDER the round
// photon-capture shadow + the photon ring. This is the maths rendered, validated
// against b_crit = 2.598 r_s and the deflection table. NOT a 2D shadow circle.
// Disk geometry/temperature match the posed particle disk (r_in=3 r_s, r_out=12).
// ─────────────────────────────────────────────────────────────────────────────

struct GeoUniforms {
    float resX, resY;
    float camX, camY, camZ;   // world camera (divided by simScale → sim coords)
    float simScale;           // plateRadius (world per sim unit)
    float orthoFrustum;       // world half-extent (cameraRho·1.2); 0 = perspective
    float aspect;             // width / height
    float r_s;                // 1.0 sim
    float r_in;               // disk inner edge (sim)
    float r_out;              // disk outer edge (sim)
    float tempScale;          // disk brightness/temperature scale
    float poseTime;           // elapsed seconds (disk rotation / Doppler — later)
};

struct VOut { float4 pos [[position]]; float2 ndc; };

// Spatial-hash uniforms — MUST match SpatialHashUniforms in particles.metal.
struct HashU {
    int gridSize;
    int particleCount;
    float cellSize;
    float invCellSize;
    int gridSizeZ;
    float halfExtent;
};

// Fullscreen triangle.
vertex VOut geo_vertex(uint vid [[vertex_id]]) {
    float2 uv = float2((vid << 1) & 2, vid & 2);  // (0,0)(2,0)(0,2)
    VOut o;
    o.pos = float4(uv * 2.0 - 1.0, 0.0, 1.0);     // (-1,-1)(3,-1)(-1,3)
    o.ndc = uv * 2.0 - 1.0;                        // -1..1 over the visible area
    return o;
}

// Blackbody-ish disk hue from cylindrical radius (matches the posed mass gradient:
// heavy/hot inner → light/cool outer). The DENSITY comes from the real particles.
static float3 diskHue(float rad, float r_in) {
    float t = clamp(pow(r_in / rad, 0.75), 0.0, 1.0);
    return float3(min(1.0, 0.55 + 1.4 * t),
                  min(1.0, 0.18 + 1.3 * t * t),
                  min(1.0, 0.55 * t * t * t));
}

// Real particle density at a sim-space point: trilinear-ish nearest sample of the
// cell-mass grid (Σ M_sun ×64 per cell). 0 outside the grid.
static float sampleDensity(float3 p, constant HashU& h, device const uint* cellMass) {
    float he = h.halfExtent;
    if (fabs(p.x) >= he || fabs(p.y) >= he || fabs(p.z) >= he) return 0.0;
    int gx = clamp(int((p.x + he) * h.invCellSize), 0, h.gridSize - 1);
    int gy = clamp(int((p.y + he) * h.invCellSize), 0, h.gridSize - 1);
    int gz = clamp(int((p.z + he) * h.invCellSize), 0, h.gridSizeZ - 1);
    uint cid = uint((gz * h.gridSize + gy) * h.gridSize + gx);
    return float(cellMass[cid]) * (1.0 / 64.0);    // M_sun in this cell
}

fragment float4 geo_fragment(VOut in [[stage_in]],
                             constant GeoUniforms& u [[buffer(0)]],
                             device const uint* cellMass [[buffer(1)]],
                             constant HashU& h [[buffer(2)]]) {
    float2 ndc = float2(in.ndc.x, -in.ndc.y);

    // ── Camera (sim coords) + ortho ray for this pixel ──────────────────────
    float3 camW = float3(u.camX, u.camY, u.camZ) / max(u.simScale, 1e-4);
    float3 fwd  = normalize(-camW);
    float3 wup  = float3(0.0, 1.0, 0.0);
    if (abs(dot(fwd, wup)) > 0.99) wup = float3(1.0, 0.0, 0.0);
    float3 right = normalize(cross(fwd, wup));
    float3 up    = cross(right, fwd);

    float halfH = max(u.orthoFrustum, 1e-4) / max(u.simScale, 1e-4);
    float halfW = halfH * u.aspect;
    float3 Ro = camW + ndc.x * halfW * right + ndc.y * halfH * up; // ray origin (sim)
    float3 Rd = fwd;                                               // ortho: parallel

    // ── Null geodesic: conserved impact parameter b; integrate dφ/dr ────────
    float b = length(cross(Ro, Rd));
    if (b < 1e-5) return float4(0.0);
    float3 e1 = normalize(Ro);                       // φ = 0 reference (ray origin dir)
    float3 e2 = Rd - dot(Rd, e1) * e1;
    if (length(e2) < 1e-6) return float4(0.0);
    e2 = normalize(e2);                              // travel/transverse direction

    float M  = 0.5 * u.r_s;
    float r  = length(Ro);
    float r0 = r;
    float phi = 0.0;
    float dr = -max(0.02, r * 0.0035);              // inward, mildly r-scaled step
    bool inward = true;
    float3 acc = float3(0.0);                        // accumulated emission
    float3 camDir = camW;                            // for Doppler line-of-sight
    const float halfThick = 0.7;                     // disk half-thickness (sim)
    const float DENS = 6.0e-4 * u.tempScale;         // M_sun→emission scale (tunable)

    for (int i = 0; i < 4000; i++) {
        float Wv = 1.0 / (b * b) - (1.0 - 2.0 * M / r) / (r * r);
        if (Wv <= 0.0) {                            // periapsis → turn outward
            if (inward) { inward = false; dr = -dr; continue; }
            else break;
        }
        phi += fabs(dr) / (r * r * sqrt(Wv));
        r += dr;
        if (r <= u.r_s * 1.02) return float4(acc, 1.0);    // captured → shadow
        if (r > r0 * 1.4) break;                            // escaped → background

        float3 P = e1 * (r * cos(phi)) + e2 * (r * sin(phi));
        float rad = length(P.xy);                           // cylindrical radius (disk plane = z)
        if (fabs(P.z) < halfThick && rad >= u.r_in && rad <= u.r_out) {
            float dens = sampleDensity(P, h, cellMass);     // REAL particle density here
            if (dens > 0.0) {
                float zt = exp(-(P.z * P.z) / (halfThick * halfThick * 0.35)); // disk z-taper
                // Doppler beaming from the REAL Keplerian orbital speed at this radius.
                float beta = sqrt(M / max(rad, u.r_s));     // v/c (geometric units)
                float3 tang = normalize(cross(float3(0,0,1), P)); // prograde direction
                float3 view = normalize(camDir - P);
                float blos = clamp(beta * dot(tang, view), -0.85, 0.85);
                float g = 1.0 / sqrt(1.0 - beta * beta);
                float delta = 1.0 / (g * (1.0 - blos));      // relativistic Doppler
                float beam = clamp(delta * delta * delta, 0.2, 6.0); // δ³ beaming
                acc += diskHue(rad, u.r_in) * (dens * DENS * zt * beam * fabs(dr));
            }
        }
    }

    if (dot(acc, acc) <= 1e-6) return float4(0.0);          // transparent background
    return float4(min(acc, float3(8.0)), 1.0);              // HDR (bloom handles glow)
}
