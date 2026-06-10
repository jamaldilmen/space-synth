#include <metal_stdlib>
using namespace metal;

// Phase 18: Kerr-Metric Hollywood Raytracer
// ── CANONICAL BH MASS — change here and update particles.metal:BH_M
// and render.metal:RS_CULL to match.
//   M = 0.5     → horizon ≈ 0.57 sim coords
//              → small BH; disk breathes from r=1 (silence) to r=3 (play)
constant float M = 0.5;
constant float a = 0.99 * M; // Spin parameter (Kerr, near-extremal)
constant int MAX_STEPS = 1500;     // Was 512; bumped for world-space traversal
                                   // (no more cameraDistScale rescale hack)
constant float STEP_BASE = 0.05f;  // Base step; adaptive sizing below

struct BlackHoleUniforms {
    float2 resolution;
    packed_float3 cameraPos;
    float time;
    float envelopePhase;
    float rotationX;
    float simScale;       // particle scale (plateRadius), see notes below
    float orthoFrustum;   // ortho half-extent in world units (0 = perspective)
    float shadowRadius;   // black shadow radius in sim coords (user-tunable)
    float bhStrength;     // emergent-hole signal r_s(M_enc)/R_ENC (0..1, Step 3)
};

// --- Spatial Hash Data Structures ---
struct Particle {
    float4 posW;   // x, y, z, mass
    float4 velW;   // vx, vy, vz, phase
    float4 prevW;  // prevX, prevY, prevZ, temperature
    float4 spinW;  // spinX, spinY, spinZ, charge
    uint4 entanglement; // x: entangledIndex, y: pad1, z: pad2, w: pad3
};

// Mirrors spatial_hash.metal. Layout must match.
struct SpatialHashUniforms {
    int gridSize;
    int particleCount;
    float cellSize;
    float invCellSize;
    int gridSizeZ;
    float halfExtent;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// ── Kerr Metric Tensors ──────────────────────
struct Metric {
    float g_tt, g_rr, g_thth, g_phph, g_tph;
};

struct CovariantMetric {
    float g_tt, g_rr, g_thth, g_phph, g_tph;
};

CovariantMetric get_covariant_metric(float r, float th) {
    float r2 = r * r;
    float a2 = a * a;
    float sin_th = sin(th);
    float cos_th = cos(th);
    float sin2 = sin_th * sin_th;
    float cos2 = cos_th * cos_th;
    
    float rho2 = r2 + a2 * cos2;
    float Delta = r2 - 2.0 * M * r + a2;
    float Sigma = (r2 + a2) * (r2 + a2) - a2 * Delta * sin2;
    
    CovariantMetric g;
    g.g_tt = -(1.0 - 2.0 * M * r / rho2);
    g.g_rr = rho2 / Delta;
    g.g_thth = rho2;
    g.g_phph = Sigma / rho2 * sin2;
    g.g_tph = -2.0 * M * r * a * sin2 / rho2;
    return g;
}

Metric get_inverse_metric(float r, float th) {
    float r2 = r * r;
    float a2 = a * a;
    float sin_th = sin(th);
    float cos_th = cos(th);
    float sin2 = sin_th * sin_th;
    float cos2 = cos_th * cos_th;
    
    float rho2 = r2 + a2 * cos2;
    float Delta = r2 - 2.0 * M * r + a2;
    float Sigma = (r2 + a2) * (r2 + a2) - a2 * Delta * sin2;
    float sin2_safe = max(sin2, 1e-6);
    
    Metric g;
    g.g_tt = -Sigma / (Delta * rho2);
    g.g_rr = Delta / rho2;
    g.g_thth = 1.0 / rho2;
    g.g_phph = (Delta - a2 * sin2) / (Delta * rho2 * sin2_safe);
    g.g_tph = -2.0 * M * r * a / (Delta * rho2);
    return g;
}

// ── RK4 Geodesic Integrator ──────────────────
struct RayState {
    float r;
    float th;
    float ph;
    float p_r;
    float p_th;
    float p_t;
    float p_ph; 
};

struct RayDeriv {
    float dr, dth, dph, dp_r, dp_th;
};

RayDeriv get_derivatives(RayState s) {
    float h = 1e-4; // Num diff step
    Metric g = get_inverse_metric(s.r, s.th);
    
    RayDeriv d;
    d.dr = g.g_rr * s.p_r;
    d.dth = g.g_thth * s.p_th;
    d.dph = g.g_phph * s.p_ph + g.g_tph * s.p_t;
    
    // Evaluate metric derivatives wrt r
    Metric gr_plus = get_inverse_metric(s.r + h, s.th);
    Metric gr_minus = get_inverse_metric(s.r - h, s.th);
    float dg_tt_dr = (gr_plus.g_tt - gr_minus.g_tt) / (2.0 * h);
    float dg_rr_dr = (gr_plus.g_rr - gr_minus.g_rr) / (2.0 * h);
    float dg_thth_dr = (gr_plus.g_thth - gr_minus.g_thth) / (2.0 * h);
    float dg_phph_dr = (gr_plus.g_phph - gr_minus.g_phph) / (2.0 * h);
    float dg_tph_dr = (gr_plus.g_tph - gr_minus.g_tph) / (2.0 * h);
    
    d.dp_r = -0.5 * (dg_tt_dr * s.p_t * s.p_t + dg_rr_dr * s.p_r * s.p_r + 
                     dg_thth_dr * s.p_th * s.p_th + dg_phph_dr * s.p_ph * s.p_ph + 
                     2.0 * dg_tph_dr * s.p_t * s.p_ph);
                     
    // Evaluate metric derivatives wrt th
    Metric gth_plus = get_inverse_metric(s.r, s.th + h);
    Metric gth_minus = get_inverse_metric(s.r, s.th - h);
    float dg_tt_dth = (gth_plus.g_tt - gth_minus.g_tt) / (2.0 * h);
    float dg_rr_dth = (gth_plus.g_rr - gth_minus.g_rr) / (2.0 * h);
    float dg_thth_dth = (gth_plus.g_thth - gth_minus.g_thth) / (2.0 * h);
    float dg_phph_dth = (gth_plus.g_phph - gth_minus.g_phph) / (2.0 * h);
    float dg_tph_dth = (gth_plus.g_tph - gth_minus.g_tph) / (2.0 * h);
    
    d.dp_th = -0.5 * (dg_tt_dth * s.p_t * s.p_t + dg_rr_dth * s.p_r * s.p_r + 
                      dg_thth_dth * s.p_th * s.p_th + dg_phph_dth * s.p_ph * s.p_ph + 
                      2.0 * dg_tph_dth * s.p_t * s.p_ph);
    return d;
}

RayState step_rk4(RayState state, float dt) {
    RayDeriv k1 = get_derivatives(state);
    
    RayState s2 = state;
    s2.r += 0.5 * dt * k1.dr; s2.th += 0.5 * dt * k1.dth; s2.ph += 0.5 * dt * k1.dph;
    s2.p_r += 0.5 * dt * k1.dp_r; s2.p_th += 0.5 * dt * k1.dp_th;
    RayDeriv k2 = get_derivatives(s2);
    
    RayState s3 = state;
    s3.r += 0.5 * dt * k2.dr; s3.th += 0.5 * dt * k2.dth; s3.ph += 0.5 * dt * k2.dph;
    s3.p_r += 0.5 * dt * k2.dp_r; s3.p_th += 0.5 * dt * k2.dp_th;
    RayDeriv k3 = get_derivatives(s3);
    
    RayState s4 = state;
    s4.r += dt * k3.dr; s4.th += dt * k3.dth; s4.ph += dt * k3.dph;
    s4.p_r += dt * k3.dp_r; s4.p_th += dt * k3.dp_th;
    RayDeriv k4 = get_derivatives(s4);
    
    RayState next = state;
    next.r += (dt / 6.0) * (k1.dr + 2.0*k2.dr + 2.0*k3.dr + k4.dr);
    next.th += (dt / 6.0) * (k1.dth + 2.0*k2.dth + 2.0*k3.dth + k4.dth);
    next.ph += (dt / 6.0) * (k1.dph + 2.0*k2.dph + 2.0*k3.dph + k4.dph);
    
    // Prevent th from going out of bounds [0, pi]
    if(next.th < 0.0) next.th = -next.th;
    if(next.th > 3.14159) next.th = 2.0*3.14159 - next.th;
    
    next.p_r += (dt / 6.0) * (k1.dp_r + 2.0*k2.dp_r + 2.0*k3.dp_r + k4.dp_r);
    next.p_th += (dt / 6.0) * (k1.dp_th + 2.0*k2.dp_th + 2.0*k3.dp_th + k4.dp_th);
    return next;
}

// ── Ray Initialization ───────────────────────
RayState init_ray(float3 camPos, float3 rayDir) {
    float r = length(camPos);
    
    // Prevent divide by zero if exactly at origin
    r = max(r, 0.001);
    float costh = clamp(camPos.z / r, -1.0, 1.0);
    float th = acos(costh);
    float ph = atan2(camPos.y, camPos.x);
    
    float sin_th = sin(th); float cos_th = cos(th);
    float sin_ph = sin(ph); float cos_ph = cos(ph);
    
    float3 hat_r = float3(sin_th * cos_ph, sin_th * sin_ph, cos_th);
    float3 hat_th = float3(cos_th * cos_ph, cos_th * sin_ph, -sin_th);
    float3 hat_ph = float3(-sin_ph, cos_ph, 0.0);
    
    float v_r = dot(rayDir, hat_r);
    float v_th = dot(rayDir, hat_th);
    float v_ph = dot(rayDir, hat_ph);
    
    CovariantMetric cov = get_covariant_metric(r, th);
    float Omega = -cov.g_tph / cov.g_phph;
    float D = cov.g_tt * cov.g_phph - cov.g_tph * cov.g_tph;
    float alpha = sqrt(-D / cov.g_phph);
    
    RayState s;
    s.r = r; s.th = th; s.ph = ph;
    // We reverse the momentum because we trace BACKWARDS from camera
    s.p_r = -sqrt(cov.g_rr) * v_r;
    s.p_th = -sqrt(cov.g_thth) * v_th;
    s.p_ph = -sqrt(cov.g_phph) * v_ph;
    s.p_t = -alpha - Omega * s.p_ph;
    return s;
}

// Converts B-L to Cartesian
float3 bl_to_cartesian(float r, float th, float ph) {
    float r_a = sqrt(r*r + a*a);
    float sin_th = sin(th);
    return float3(r_a * sin_th * cos(ph), r_a * sin_th * sin(ph), r * cos(th));
}

// ── Procedural Starfield ──────────────────────
// Maps final ray direction (th, ph) to a field of stars.
// The gravitational lensing warps th/ph, so distant stars appear bent around the hole.
static float starHash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * float3(443.897, 441.423, 437.195));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

static float3 sampleStarfield(float th, float ph, float time) {
    // Convert spherical exit direction to a 2D UV on the celestial sphere
    float2 starUV = float2(ph / (2.0 * 3.14159265), th / 3.14159265);

    // Tile the sky into a grid of potential star positions
    float2 gridScale = float2(200.0, 100.0); // Star density
    float2 cell = floor(starUV * gridScale);
    float2 frac_uv = fract(starUV * gridScale);

    float brightness = 0.0;
    float3 starColor = float3(0.0);

    // Check this cell and neighbors for star points
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            float2 neighbor = cell + float2(dx, dy);
            float h = starHash(neighbor);
            float2 starPos = float2(h, starHash(neighbor + 100.0));

            float2 diff = (frac_uv - starPos) - float2(dx, dy);
            float dist = length(diff);

            // Only ~15% of cells have visible stars
            if (h > 0.85) {
                float mag = (h - 0.85) / 0.15; // 0-1 magnitude
                float pointSpread = exp(-dist * dist * 800.0); // Tight point
                float glow = exp(-dist * dist * 80.0) * 0.15;  // Soft halo

                float star = (pointSpread + glow) * mag;
                brightness += star;

                // Color temperature variation (blue-white to warm)
                float temp = starHash(neighbor + 50.0);
                float3 col = mix(
                    float3(0.8, 0.85, 1.0),  // Cool blue-white
                    float3(1.0, 0.9, 0.7),   // Warm yellow
                    temp
                );
                // Rare bright blue giants
                if (temp > 0.9) col = float3(0.7, 0.8, 1.0) * 1.5;

                starColor += col * star;
            }
        }
    }

    // Subtle Milky Way band (galactic plane glow near equator)
    float milkyWay = exp(-pow((th - 1.5707) * 3.0, 2.0)) * 0.03;
    float mwNoise = starHash(floor(starUV * 500.0)) * 0.5 + 0.5;
    starColor += float3(0.6, 0.55, 0.5) * milkyWay * mwNoise;

    return starColor;
}

// ── Volumetric Grid Sampling ──────────────────

// Single-cell read: returns float4(avgVel, density) for one spatial-hash
// cell, or zero if the cell is out of bounds / empty.
static float4 sample_one_cell(
    int cx, int cy, int cz,
    constant SpatialHashUniforms& gridU,
    device const uint* cellStarts,
    device const Particle* sortedParticles)
{
    if (cx < 0 || cx >= gridU.gridSize ||
        cy < 0 || cy >= gridU.gridSize ||
        cz < 0 || cz >= gridU.gridSizeZ) {
        return float4(0.0);
    }
    uint cellID = uint((cz * gridU.gridSize + cy) * gridU.gridSize + cx);
    uint startIdx = cellStarts[cellID];
    uint totalCells = uint(gridU.gridSize * gridU.gridSize * gridU.gridSizeZ);
    uint nextIdx = (cellID + 1 < totalCells)
                       ? cellStarts[cellID + 1]
                       : uint(gridU.particleCount);
    float count = float(nextIdx - startIdx);
    if (count == 0.0) return float4(0.0);

    // Average more of the cell's particles for a stable mean velocity. The
    // old 4-sample average flickered: the spatial sort reshuffles which
    // particles land first in the cell each frame, so a 4-wide window jumped
    // around frame-to-frame → visible temporal glitch in the disk colour.
    // 12 samples settle the mean without materially touching FPS (these reads
    // only happen on rays that actually hit the disk).
    float3 avgVel = float3(0.0);
    int samples = min(int(count), 12);
    for (int i = 0; i < samples; i++) {
        avgVel += sortedParticles[startIdx + i].velW.xyz;
    }
    avgVel /= float(samples);

    float countFactor = 5000000.0f / max(1.0f, float(gridU.particleCount));
    // Grid-aware density scale: total particles fixed, so cells at finer
    // resolution hold proportionally fewer particles each. Brightness per
    // ray-step would drop ∝ 1/gridVolume without this. Calibration: 0.008
    // was tuned at 64³; we rescale to keep visual density invariant under
    // grid resolution changes.
    float gridScale = float(gridU.gridSize) / 64.0f;
    // Base calib raised 0.008 → 0.016: the geodesically-lensed volumetric is
    // the REAL bent disk (RK4 rays sampling the particle density), but it was
    // too faint to see, so the crude NDC particle-smear won the frame and read
    // grainy/cheap. Bringing the volumetric forward lets the continuous lensed
    // band carry the disk instead of sparse particle streaks.
    float densityCalib = 0.016f * gridScale * gridScale * gridScale;
    float density = clamp(count * countFactor * densityCalib, 0.0f, 1.0f);
    return float4(avgVel, density);
}

float4 sample_spatial_grid_velocity(
    float3 cartPos,
    constant SpatialHashUniforms& gridU,
    device const uint* cellStarts,
    device const Particle* sortedParticles)
{
    // Inside the event horizon → no emission (the void).
    if (length(cartPos) < M + sqrt(M*M - a*a)) {
        return float4(0.0);
    }

    // Outside the actual particle field → no emission. Tracks the
    // orbital cap (ORBIT_R_MAX=3.0) via gridU.halfExtent — both match.
    float r = length(cartPos.xy);
    if (r > gridU.halfExtent) return float4(0.0);

    // Trilinear interpolation between the 8 cells whose centers form a
    // cube around cartPos. Without this, the volumetric paints in
    // visible cubic steps (one cell ≈ 16% of half-screen at max zoom).
    // Center-aligned: cell (i,j,k) is centered at ((i+0.5)·cellSize
    // − halfExtent), so we shift by 0.5 before flooring.
    float3 f = (cartPos + gridU.halfExtent) * gridU.invCellSize - 0.5;
    int3 i0 = int3(floor(f));
    float3 t = f - float3(i0);

    // Hermite-smooth the interpolation weights (smoothstep per axis). Plain
    // trilinear is only C0 — the gradient is discontinuous at every cell
    // centre, which at deep zoom reads as faceted, blocky creases across the
    // disk. t·t·(3−2t) makes the blend C1 (zero gradient at cell boundaries),
    // so neighbouring voxels melt together instead of showing flat facets.
    t = t * t * (3.0 - 2.0 * t);

    float4 c000 = sample_one_cell(i0.x,     i0.y,     i0.z,     gridU, cellStarts, sortedParticles);
    float4 c100 = sample_one_cell(i0.x + 1, i0.y,     i0.z,     gridU, cellStarts, sortedParticles);
    float4 c010 = sample_one_cell(i0.x,     i0.y + 1, i0.z,     gridU, cellStarts, sortedParticles);
    float4 c110 = sample_one_cell(i0.x + 1, i0.y + 1, i0.z,     gridU, cellStarts, sortedParticles);
    float4 c001 = sample_one_cell(i0.x,     i0.y,     i0.z + 1, gridU, cellStarts, sortedParticles);
    float4 c101 = sample_one_cell(i0.x + 1, i0.y,     i0.z + 1, gridU, cellStarts, sortedParticles);
    float4 c011 = sample_one_cell(i0.x,     i0.y + 1, i0.z + 1, gridU, cellStarts, sortedParticles);
    float4 c111 = sample_one_cell(i0.x + 1, i0.y + 1, i0.z + 1, gridU, cellStarts, sortedParticles);

    float4 c00 = mix(c000, c100, t.x);
    float4 c10 = mix(c010, c110, t.x);
    float4 c01 = mix(c001, c101, t.x);
    float4 c11 = mix(c011, c111, t.x);
    float4 c0  = mix(c00,  c10,  t.y);
    float4 c1  = mix(c01,  c11,  t.y);
    float4 result = mix(c0, c1, t.z);

    // Gaussian z-taper for disk thickness — applied AFTER interp so the
    // thickness is smooth, not stepped per cell.
    float diskThickness = 0.2f;
    float zMask = exp(-(cartPos.z * cartPos.z) / (diskThickness * diskThickness));
    result.a *= zMask;

    return result;
}

// ── Main Shader Raymarcher ───────────────────
fragment float4 fragment_black_hole(
    VertexOut in [[stage_in]],
    constant BlackHoleUniforms& uniforms [[buffer(0)]],
    constant SpatialHashUniforms& gridU [[buffer(1)]],
    device const uint* cellStarts [[buffer(2)]],
    device const Particle* sortedParticles [[buffer(3)]])
{
    // EMERGENT opacity (Step 3): the raytraced shadow fades in as the core
    // approaches the geometric hole criterion — mass decides, not the ADSR.
    float opacity = smoothstep(0.5, 0.95, uniforms.bhStrength);
    if (opacity <= 0.001) return float4(0.0);
    
    float2 uv = in.uv * 2.0 - 1.0; uv.y *= -1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float3 cameraWo = float3(uniforms.cameraPos[0], uniforms.cameraPos[1], uniforms.cameraPos[2]);
    float3 forward = -normalize(cameraWo); 
    float3 right = normalize(cross(forward, float3(0.0, 1.0, 0.0)));
    float3 up = normalize(cross(right, forward));
    
    // Match the scene's projection mode. The rest of the scene uses ORTHO
    // with frustum = plateRadius * 1.2 in world units; the raytracer was
    // doing perspective with fov 0.6 → BH rendered at perspective size,
    // disconnected from the ortho-projected particles. That's why the BH
    // looked "frozen at one big size" regardless of zoom.
    //
    // For ortho: every pixel is a parallel ray with the same direction
    // (`forward`); the ray origin is offset across the camera's right/up
    // axes by uv·frustum_half. BH apparent size = horizon/frustum_half →
    // scales properly with zoom (rho up → frustum up → BH smaller).
    //
    // Also: divide cameraWo by simScale so the integrator runs in particle
    // sim coords (matches BH horizon at M=0.025 sim).
    float camDist = length(cameraWo);
    float3 rayOrigin, rayDir;
    if (uniforms.orthoFrustum > 0.0f) {
        // Ortho: per-pixel origin offset, constant direction.
        float aspect = uniforms.resolution.x / uniforms.resolution.y;
        float halfW = uniforms.orthoFrustum * aspect / uniforms.simScale;
        float halfH = uniforms.orthoFrustum / uniforms.simScale;
        rayOrigin = (cameraWo / uniforms.simScale)
                  + uv.x * halfW * right
                  + uv.y * halfH * up;
        rayDir = forward;
    } else {
        // Perspective fallback.
        rayOrigin = cameraWo / uniforms.simScale;
        float fovFactor = 0.6;
        rayDir = normalize(forward + uv.x * right * fovFactor + uv.y * up * fovFactor);
    }
    
    // ── Analytic shadow (photon capture cross-section) ──────────────
    // The APPARENT black disk of a BH is NOT the coordinate horizon — it's
    // the photon-capture cross-section, which strong lensing magnifies to
    // b_crit = 3√3·M ≈ 2.6·M (Schwarzschild), i.e. ~2.6× the horizon
    // radius. Drawing only the horizon (r_+ ≈ 1.14·M) made the shadow
    // ~4.5× too small — the "pea on a plate" look. Ref: James, von
    // Tunzelmann, Franklin & Thorne 2015 (arXiv:1502.03808); the Kerr
    // shadow is D-shaped but its equivalent radius stays ≈ 5M for all spins.
    //
    // A ray whose straight-line impact parameter b < b_crit is captured →
    // pure black. Computing this analytically (a) renders the shadow at its
    // physically-correct large size, and (b) lets shadow pixels skip the
    // 1500-step geodesic march entirely → big FPS win when the BH fills
    // the frame at zoom.
    // Physical photon-capture radius is 3√3·M ≈ 2.6 sim, but that dwarfs
    // this build's tight disk (r≈3). shadowRadius (UI "BH Size") lets the
    // shadow be dialed to read proportionally against the disk.
    float b_crit = uniforms.shadowRadius;
    {
        float alongBH = dot(-rayOrigin, rayDir);  // BH at origin
        float3 perpBH = -rayOrigin - alongBH * rayDir;
        float b = length(perpBH);
        if (b < b_crit) {
            return float4(0.0, 0.0, 0.0, 1.0 * opacity); // shadow, no march
        }
    }

    RayState state = init_ray(rayOrigin, rayDir);
    float4 accumulatedColor = float4(0.0);
    bool hitHorizon = false;
    float r_horizon = M + sqrt(M*M - a*a);
    float min_r = state.r; // Track closest approach to singularity
    float prev_r = state.r; // Track previous r to detect outbound escape
    
    for (int step = 0; step < MAX_STEPS; step++) {
        min_r = min(min_r, state.r);

        if (state.r <= r_horizon * 1.01) {
            hitHorizon = true;
            break;
        }
        // Escape: bail if ray flies far past the BH (matches Garganty).
        if (state.r > 50.0) break;

        // Adaptive step size — big steps far from horizon, small near.
        // Without this, fixed step=0.05 needs 1000+ steps to traverse from
        // cam=10 to horizon. Adaptive matches Garganty's approach.
        float radial_limit = max(0.01f, 0.2f * (state.r - r_horizon));
        float polar_limit  = max(0.002f, abs(sin(state.th)) * 0.4f);
        float dlambda = min(min(radial_limit, polar_limit), 0.5f);

        state = step_rk4(state, dlambda);
        float3 cartPos = bl_to_cartesian(state.r, state.th, state.ph);
        
        // Apply inverse rotation so the spatial grid appears rotated
        float c = cos(-uniforms.rotationX);
        float s = sin(-uniforms.rotationX);
        float3x3 rotX = float3x3(
            1.0, 0.0, 0.0,
            0.0, c,   -s,
            0.0, s,    c
        );
        
        float3 gridPos = rotX * cartPos;
        float4 partData = sample_spatial_grid_velocity(gridPos, gridU, cellStarts, sortedParticles);
        
        if (partData.a > 0.001) {
            float3 vel = partData.xyz;
            float speed = length(vel);
            
            float v_obs = dot(normalize(vel + float3(1e-6)), normalize(cameraWo)); 
            
            float doppler = 1.0 - v_obs * 0.5; 
            doppler = clamp(doppler, 0.2, 3.0);
            
            float brightnessFactor = pow(doppler, 3.0); // I ∝ D^3
            
            // Blackbody approximation: T_obs = D * T_emit
            // Base temperature mapping (K) based on speed/location
            float baseTemp = 3000.0; // Warm orange/red base
            if (speed > 5.0) baseTemp = 10000.0; // Hot white/blue
            else if (speed > 2.0) baseTemp = 6000.0; // Yellow/white
            
            float obsTemp = baseTemp * doppler;
            
            // Simple blackbody RGB mapping (normalized)
            float3 bbColor;
            if (obsTemp > 8000.0) bbColor = float3(0.7, 0.8, 1.0); // Blue-ish
            else if (obsTemp > 5000.0) bbColor = float3(1.0, 0.95, 0.9); // White-ish
            else if (obsTemp > 3500.0) bbColor = float3(1.0, 0.6, 0.2); // Orange
            else bbColor = float3(1.0, 0.2, 0.05); // Deep red
            
            float3 color = bbColor * brightnessFactor * 2.5f; // emission boost

            // Removed channel hacks - handled by blackbody mapping above
            
            // Soften alpha accumulation but boost base density visibility
            float alpha = partData.a * (1.0 - accumulatedColor.a) * 0.95;
            accumulatedColor.rgb += color * alpha;
            accumulatedColor.a += alpha;
            if (accumulatedColor.a > 0.99) break;
        }
        
        // Escape ONLY if the ray has passed closest approach AND is now
        // heading outward past the disk's outer edge. This is what makes
        // the lensing visible: rays must fully integrate through the
        // approach, bend around the BH, then escape carrying disk
        // material from the FAR side of the BH back to the camera (the
        // famous Gargantua top arc).
        if (state.r > prev_r && state.r > 3.0) break;
        prev_r = state.r;
    }
    
    // ANALYTIC THIN DISK LAYER REMOVED — was a hardcoded 2D orange ring in
    // the z=0 plane (ray-plane intersection) drawn on top of the proper
    // Kerr raytraced volumetric. Color was hardcoded float3(1.0, 0.5, 0.1)
    // independent of particle state, so it acted as a "second BH entity"
    // visually layered on the real one. The geodesic raymarcher above
    // already produces the disk from the actual particle field.

    if (hitHorizon) {
        // Pure black inside event horizon, but composite over starfield for opacity
        return float4(0.0, 0.0, 0.0, 1.0 * opacity);
    }

    // PHOTON SPHERE GLOW REMOVED — was a hardcoded white-ish ring at
    // r = 1.5·R_horizon overlaid on the raymarched output. Same problem as
    // the analytic disk: a hand-painted ring layered on the actual
    // raytracer. The geodesic accumulation already creates a photon-sphere
    // brightening where rays orbit before falling in.

    // STARFIELD REMOVED — was painting a procedural sky on escape rays
    // that clashed with the particle field and looked like a static
    // background texture. The BH visual is now just void + accretion;
    // escape rays render transparent.

    accumulatedColor.a = hitHorizon ? 1.0 : accumulatedColor.a;
    accumulatedColor *= opacity;
    return accumulatedColor;
}

vertex VertexOut vertex_black_hole(uint vertexID [[vertex_id]]) {
    float2 positions[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = positions[vertexID] * 0.5 + 0.5;
    return out;
}
