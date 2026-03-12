#include <metal_stdlib>
using namespace metal;

// Phase 18: Kerr-Metric Hollywood Raytracer
constant float M = 0.40;   // Black hole mass (matches RS = 0.40)
constant float a = 0.99 * M; // Spin parameter (Kerr)
constant int MAX_STEPS = 512;
constant float STEP_SIZE = 0.05; // Larger step size since RK4 is more stable

struct BlackHoleUniforms {
    float2 resolution;
    packed_float3 cameraPos;
    float time;
    float envelopePhase;
    float rotationX;
};

// --- Spatial Hash Data Structures ---
struct Particle {
    float4 posW;   // x, y, z, mass
    float4 velW;   // vx, vy, vz, phase
    float4 prevW;  // prevX, prevY, prevZ, temperature
    float4 spinW;  // spinX, spinY, spinZ, charge
    uint4 entanglement; // x: entangledIndex, y: pad1, z: pad2, w: pad3
};

struct SpatialHashUniforms {
    int gridSize;       // 256
    int particleCount;
    float cellSize;     // 2.0 / gridSize
    float invCellSize;  // gridSize / 2.0
    int gridSizeZ;      // 32
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
float4 sample_spatial_grid_velocity(
    float3 cartPos,
    constant SpatialHashUniforms& gridU,
    device const uint* cellStarts,
    device const Particle* sortedParticles) 
{
    // The particle grid is scaled 1.0 = Edge of screen. 
    // The shader black hole `RS` is 0.40. 
    // We map the physical `cartPos` directly to the grid coordinates.
    // If the ray is INSIDE the event horizon, we return exactly 0 density so it stays pitch black.
    if (length(cartPos) < M + sqrt(M*M - a*a)) {
        return float4(0.0);
    }
    
    int cx = int((cartPos.x + 1.0f) * gridU.invCellSize);
    int cy = int((cartPos.y + 1.0f) * gridU.invCellSize);
    int cz = int((cartPos.z + 1.0f) * gridU.invCellSize);
    
    if (cx < 0 || cx >= gridU.gridSize || cy < 0 || cy >= gridU.gridSize || cz < 0 || cz >= gridU.gridSize) {
        return float4(0.0);
    }
    
    uint cellID = (cz * gridU.gridSize + cy) * gridU.gridSize + cx;
    uint startIdx = cellStarts[cellID];
    uint nextIdx = cellStarts[cellID + 1];
    float count = float(nextIdx - startIdx);
    
    if (count == 0.0) return float4(0.0);
    
    float3 avgVel = float3(0.0);
    int samples = min(int(count), 4);
    for (int i = 0; i < samples; i++) {
        avgVel += sortedParticles[startIdx + i].velW.xyz;
    }
    avgVel /= float(samples);
    
    // Density calibration: 
    // The image shows a massive glowing sphere because density is too high everywhere.
    // Scale inversely by particleCount so it looks consistent regardless of slider
    float density = clamp(count * (1000000.0f / max(1.0f, float(gridU.particleCount))) * 0.003f, 0.0f, 1.0f);
    
    // MATHEMATICALLY THIN DISK:
    // The particles might be scattered in a 3D sphere, but a real accretion disk is extremely thin.
    // We enforce a hard cutoff near the equatorial plane (z = 0).
    float diskThickness = 0.05f; 
    if (abs(cartPos.z) > diskThickness) {
        return float4(0.0);
    }
    
    // Soft blend at the edges of the disk height
    float z_mask = 1.0f - (abs(cartPos.z) / diskThickness);
    density *= z_mask * z_mask;
    
    // Suppress density at the outer edges of the screen to focus on the hole
    float r = length(cartPos.xy);
    if (r > 1.2f) return float4(0.0);
    
    return float4(avgVel, density);
}

// ── Main Shader Raymarcher ───────────────────
fragment float4 fragment_black_hole(
    VertexOut in [[stage_in]],
    constant BlackHoleUniforms& uniforms [[buffer(0)]],
    constant SpatialHashUniforms& gridU [[buffer(1)]],
    device const uint* cellStarts [[buffer(2)]],
    device const Particle* sortedParticles [[buffer(3)]])
{
    if (uniforms.envelopePhase > 0.5) return float4(0.0);
    float opacity = saturate(1.0 - (uniforms.envelopePhase / 0.5));
    
    float2 uv = in.uv * 2.0 - 1.0; uv.y *= -1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float3 cameraWo = float3(uniforms.cameraPos[0], uniforms.cameraPos[1], uniforms.cameraPos[2]);
    float3 forward = -normalize(cameraWo); 
    float3 right = normalize(cross(forward, float3(0.0, 1.0, 0.0)));
    float3 up = normalize(cross(right, forward));
    
    float cameraDistScale = 250.0f; 
    float3 rayOrigin = cameraWo / cameraDistScale; 
    float fovFactor = 0.6;
    float3 rayDir = normalize(forward + uv.x * right * fovFactor + uv.y * up * fovFactor);
    
    RayState state = init_ray(rayOrigin, rayDir);
    float4 accumulatedColor = float4(0.0);
    bool hitHorizon = false;
    float r_horizon = M + sqrt(M*M - a*a); 
    float min_r = state.r; // Track closest approach to singularity
    
    for (int step = 0; step < MAX_STEPS; step++) {
        // Track the closest approach to the singularity for photon-sphere glow
        min_r = min(min_r, state.r);
        
        if (state.r <= r_horizon * 1.01) {
            hitHorizon = true;
            break;
        }
        
        state = step_rk4(state, STEP_SIZE);
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
            
            float3 color;
            if (speed > 5.0) color = float3(1.0, 0.95, 0.9);
            else if (speed > 2.0) color = float3(1.0, 0.6, 0.2);
            else color = float3(1.0, 0.4, 0.1); // Warmer base color for the disk
            
            float brightnessFactor = pow(doppler, 2.5);
            
            if (doppler > 1.0) {
                 color.b *= brightnessFactor;
                 color.r /= doppler;
            } else {
                 color.r *= pow(1.0/doppler, 2.0);
                 color.b *= doppler;
            }
            
            // Soften alpha accumulation but boost base density visibility
            float alpha = partData.a * (1.0 - accumulatedColor.a) * 0.95;
            accumulatedColor.rgb += color * alpha;
            accumulatedColor.a += alpha;
            if (accumulatedColor.a > 0.99) break;
        }
        
        if (state.r > 2.0) break; // Allow a slightly larger escape radius
    }
    
    if (hitHorizon) {
        // Pure black inside event horizon, but composite over starfield for opacity
        return float4(0.0, 0.0, 0.0, 1.0 * opacity);
    }

    // ── PHOTON SPHERE GLOW (Gargantua Aesthetics) ──
    if (accumulatedColor.a < 0.99) {
        float photon_sphere = r_horizon * 1.5;
        if (min_r < photon_sphere * 1.25) {
            float proximity = 1.0 - abs(min_r - photon_sphere) / (photon_sphere * 0.25);
            if (proximity > 0.0) {
                float intensity = pow(proximity, 3.0) * 2.0;
                float3 glowColor = float3(1.0, 0.8, 0.5) * intensity;

                float alpha = intensity * (1.0 - accumulatedColor.a);
                accumulatedColor.rgb += glowColor * alpha;
                accumulatedColor.a += alpha;
            }
        }
    }

    // ── STARFIELD BACKGROUND (Gravitational Lensing Visible) ──
    // Rays that escape sample a procedural starfield at their warped exit direction.
    // The Kerr metric bends the ray's th/ph, so stars appear warped around the hole.
    if (!hitHorizon && accumulatedColor.a < 0.99) {
        float3 stars = sampleStarfield(state.th, state.ph, uniforms.time);
        float starAlpha = (1.0 - accumulatedColor.a);
        accumulatedColor.rgb += stars * starAlpha;
        accumulatedColor.a += starAlpha * saturate(length(stars) * 2.0);
    }

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
