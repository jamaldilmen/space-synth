#include <metal_stdlib>
using namespace metal;

struct Particle {
    float4 posW;   // x, y, z, mass  (normalized plate coords)
    float4 velW;   // vx, vy, vz, phase
    float4 prevW;  // prevX, prevY, prevZ, temperature
    float4 spinW;  // spinX, spinY, spinZ, charge
    uint4 entanglement; // x: entangledIndex, y: pad1, z: pad2, w: pad3
};

struct CameraUniforms {
    float4x4 viewProjection;
    float4 cameraPos; // Use float4 to match 16-byte alignment and C++ padding
    float particleSize;
    float plateRadius;
    float phaseViz;    // 1.0 = phase coloring, 0.0 = default
    float waveDepth;
    float envelopePhase; // 0=silence(black hole), 1-4=ADSR
    float orthoMode;
    float bhShadowNdcRadius; // shadow's on-screen radius = lens Einstein radius
    float aspect;            // width/height, to make the lens screen-isotropic
};

// (safe_normalize removed to fix unused warning)

struct VertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float3 color;
    float dist;        // Camera distance for fade
    float luminance;   // HDR emission intensity
    float originDist;  // Distance from universe origin (0,0,0) for event horizon
    float2 velDir2D;   // Phase 11: Screen-space velocity direction for string elongation
    float2 strDir2D;   // Partner string connection vector
};

// Decode packed phase + band ID from velW.w
static void decodePhaseAndBand(float packed, thread float &phase, thread int &bandId) {
    uint bits = as_type<uint>(packed);
    bandId = int((bits >> 29) & 0x7);
    uint phaseBits = bits & 0x1FFFFFFFu;
    phase = ((float)phaseBits / (float)0x1FFFFFFFu) * (2.0f * M_PI_F) - M_PI_F;
}

// Per-band color palette (6 perceptual frequency groups)
constant float3 kBandColors[6] = {
    float3(1.0, 0.4, 0.1),  // Sub (orange)
    float3(1.0, 0.8, 0.2),  // Kick (gold)
    float3(0.4, 1.0, 0.3),  // Low-mid (green)
    float3(0.2, 0.9, 1.0),  // Mid (cyan)
    float3(0.6, 0.7, 1.0),  // Hi-mid (blue)
    float3(1.0, 0.6, 1.0),  // Air (magenta)
};

// HSV to RGB conversion
static float3 hsv2rgb(float h, float s, float v) {
    float c = v * s;
    float hp = h * 6.0f;
    float x = c * (1.0f - abs(fmod(hp, 2.0f) - 1.0f));
    float3 rgb;
    if (hp < 1.0f)      rgb = float3(c, x, 0);
    else if (hp < 2.0f) rgb = float3(x, c, 0);
    else if (hp < 3.0f) rgb = float3(0, c, x);
    else if (hp < 4.0f) rgb = float3(0, x, c);
    else if (hp < 5.0f) rgb = float3(x, 0, c);
    else                 rgb = float3(c, 0, x);
    float m = v - c;
    return rgb + float3(m, m, m);
}

vertex VertexOut particle_vertex(
    uint vid [[vertex_id]],
    device const Particle* particlesIn [[buffer(0)]],
    constant CameraUniforms& cam [[buffer(1)]],
    device const Particle* particlesRef [[buffer(2)]])
{
    VertexOut out;
    Particle in = particlesIn[vid];
    float R = cam.plateRadius;
    float mass = in.posW.w;

    // Wall particles (mass=0) are invisible — they're structural, not visual
    if (mass < 0.001f) {
        out.position = float4(0, 0, -2, 1); // Behind clip plane
        out.pointSize = 0.0f;
        out.color = float3(0);
        out.luminance = 0.0f;
        out.originDist = 0.0f;
        out.dist = 1.0f;
        out.velDir2D = float2(0);
        out.strDir2D = float2(0);
        return out;
    }

    // Map normalized plate coords to world: scale all axes by R for isotropic 3D
    float3 worldPos = in.posW.xyz * R;

    out.position = cam.viewProjection * float4(worldPos, 1.0);

    // ── Gravitational lensing — per-particle 3D bend, no 2D coherent pattern ──
    // The previous (ba85dcc) lens computed deflection from NDC distance —
    // every particle got pushed radially from the projected BH center with
    // magnitude ~1/NDC-distance. That creates a perfect coherent circle of
    // distortion on screen (the "2D locked shape" — always centered on
    // projected origin regardless of disk geometry).
    //
    // Now: the deflection magnitude is driven by each particle's actual
    // 3D impact parameter (perpendicular distance of the camera→particle
    // ray to the BH origin in world space). Direction stays NDC-radial
    // (so the bend is visible in screen). Particles in different 3D
    // positions bend by different amounts → no coherent circular ring
    // pattern emerges, just per-particle deflection of varying strengths.
    // ── Gravitational lensing — point-mass lens equation ────────────────
    // The old version pushed particles radially by an arbitrary 0.30/impact.
    // That bend had NO relation to the shadow radius, so the bright ring and
    // the dark hole were two different circles → it never read as a real BH.
    //
    // Real fix: the point-mass lens maps an unlensed angular offset β to an
    // image radius θ via  β = θ − θ_E²/θ , i.e.
    //     θ = ½(β + √(β² + 4·θ_E²)).
    // As β→0 the image piles up AT θ_E (the Einstein / photon ring); far out
    // (β≫θ_E) θ→β (no bend). We set θ_E = the shadow's on-screen radius
    // (cam.bhShadowNdcRadius), so the lensed ring sits exactly on the shadow
    // edge — ring radius == hole radius, which is what makes it a black hole.
    //
    // Gated to the silence phase: the lens belongs with the visible shadow,
    // and this keeps it from distorting the Chladni shapes during play.
    if (cam.bhShadowNdcRadius > 1e-4f && cam.envelopePhase < 0.5f) {
        float4 bhClip = cam.viewProjection * float4(0.0, 0.0, 0.0, 1.0);
        if (bhClip.w > 0.001f && out.position.w > 0.001f) {
            float2 ndcP  = out.position.xy / out.position.w;
            float2 ndcBH = bhClip.xy / bhClip.w;
            // Work in screen-isotropic coords: NDC x covers more world than y
            // by `aspect`, so scale x up to make a screen-circle a true circle.
            float asp = max(cam.aspect, 1e-4f);
            float2 d = (ndcP - ndcBH);
            d.x *= asp;
            float beta = length(d);
            if (beta > 1e-5f) {
                float thetaE = cam.bhShadowNdcRadius;
                float thetaFull = 0.5f * (beta + sqrt(beta * beta + 4.0f * thetaE * thetaE));
                // GENTLE lens. The full lens equation (and especially the old
                // tanh soft-cap) collapsed every particle onto the θ_E ring,
                // so the disk flattened into the same circle from every camera
                // angle — the side view stopped looking 3D. Blending only
                // partway toward the lensed image keeps the disk at its real
                // radius (3D preserved, rotates correctly) while still pulling
                // the inner material toward a photon-ring brightening at the
                // shadow edge. Cheap too — no per-particle tanh across 5M.
                float theta = mix(beta, thetaFull, 0.4f);
                float2 lensed = (d / beta) * theta; // image offset, isotropic
                lensed.x /= asp;                    // back to raw NDC
                float2 lensedP = ndcBH + lensed;
                out.position.xy = lensedP * out.position.w;
            }
        }
    }

    // out.position already set at line 102, modified by lensing block above.

    // Phase 11: Project velocity into screen-space for string elongation
    float3 velWorld = in.velW.xyz * R;
    float4 endClip = cam.viewProjection * float4(worldPos + velWorld * 0.5f, 1.0);
    float2 v1_screen = out.position.xy / out.position.w;
    float2 v2_screen = endClip.xy / endClip.w;
    
    out.velDir2D = (v2_screen - v1_screen) * 5.0f; // Pass raw screen-space velocity for dynamic elongation

    // ── Phase 18: Chord Connections (Entanglement Webbing) ──
    out.strDir2D = float2(0.0f);
    uint partnerID = in.entanglement.x;
    if (partnerID < 5000000 && partnerID != vid) { 
        float4 partnerPosW = float4(particlesRef[partnerID].posW.xyz, 1.0f);
        float4 partnerPosC = cam.viewProjection * partnerPosW; // Use cam.viewProjection
        
        float2 myNDC = out.position.xy / max(0.0001f, out.position.w);
        float2 partnerNDC = partnerPosC.xy / max(0.0001f, partnerPosC.w);
        
        float2 dirNDC = partnerNDC - myNDC;
        float screenDist = length(dirNDC);
        
        // Only draw strings between reasonably close particles
        if (screenDist < 0.15f && screenDist > 0.002f) {
             out.strDir2D = dirNDC * 20.0f; // Stretch to connect
        }
    }

    // Dynamic Point Size Scaling
    float isOrtho = cam.orthoMode;
    float dist = mix(out.position.w, cam.cameraPos.w, isOrtho);
    out.dist = dist;
    
    // Particle size. Baseline raised from 1.0 → 2.5 so rest particles render
    // at the SAME physical size as play particles. The sphere impostor needs
    // ~20+ pixels to read as a 3D sphere; the old 1.0× baseline made rest
    // particles ~10px and they looked like 2D dots. Heat now only boosts
    // *beyond* baseline (up to 4.0× for hot play particles).
    //
    // Sub-linear distance growth (was linear `800/dist`). Anchored at the
    // default ortho rho=400 so zoomed-out look is unchanged, but past that
    // the size grows as pow(2/1, 0.65) instead of doubling each halving
    // of distance. Without this, deep zoom (rho < 50) saturated every
    // close particle at the 64px cap → uniform fat blobs filling the BH
    // disk. The 1.275 = 2^0.35 anchors the formula so that at distRatio=2.0
    // (default zoom) sizeScale=2.0, identical to the old linear behavior.
    float temp = in.prevW.w;
    float heatSizeBoost = 2.5f + clamp(temp, 0.0f, 1.0f) * 1.5f; // 2.5x → 4.0x
    float distRatio = 800.0f / max(0.0001f, dist);
    float sizeScale = pow(distRatio, 0.65f) * 1.275f;
    float rawSize = cam.particleSize * heatSizeBoost * sizeScale;
    // Cap lowered 64 → 40: with sub-linear growth, hot particles at rho=25
    // hit ~40px naturally. A tighter cap keeps overdraw under control on
    // TBDR (each capped sprite is fewer tile-fragment ops).
    out.pointSize = clamp(rawSize, 1.0f, 40.0f);

    // HDR luminance from thermal energy (ODS-03). Particles render at full
    // brightness in ALL phases — they ARE the visual, both at rest (fast
    // orbital spin → light trails → accretion disk) and on play (Chladni
    // shapes). No multiplex dimming; the raytracer only draws the dark
    // void, it does not replace the particles.
    out.luminance = 1.0f + max(0.0f, temp) * 2.0f;

    // Decode packed phase + band ID
    float phase; int bandId;
    decodePhaseAndBand(in.velW.w, phase, bandId);
    int bClamped = clamp(bandId, 0, 5);

    if (cam.phaseViz > 0.5f) {
        // Feynman phase arrow coloring: phase → hue
        float hue = (phase + M_PI_F) / (2.0f * M_PI_F);
        float speed = length(in.velW.xyz);
        float saturation = 0.85f;
        float value = 0.5f + clamp(speed * 3.0f, 0.0f, 0.5f);
        out.color = hsv2rgb(hue, saturation, value);
    } else {
        // ── Blackbody temperature coloring (Interstellar Gargantua aesthetic) ──
        // Temperature is stored in prevW.w by the compute shader.
        // Inner disk is hot (white/blue), outer disk is cool (orange/red).
        float T = clamp(temp, 0.0f, 5.0f); // temp range from compute shader
        float tNorm = clamp(T / 5.0f, 0.0f, 1.0f); // 0 = cold, 1 = hottest

        // Blackbody ramp: deep red → orange → white → blue-white
        float3 bbColor;
        if (tNorm < 0.25f) {
            bbColor = mix(float3(0.6, 0.15, 0.02), float3(1.0, 0.4, 0.05), tNorm * 4.0f);
        } else if (tNorm < 0.5f) {
            bbColor = mix(float3(1.0, 0.4, 0.05), float3(1.0, 0.75, 0.4), (tNorm - 0.25f) * 4.0f);
        } else if (tNorm < 0.75f) {
            bbColor = mix(float3(1.0, 0.75, 0.4), float3(1.0, 0.95, 0.9), (tNorm - 0.5f) * 4.0f);
        } else {
            bbColor = mix(float3(1.0, 0.95, 0.9), float3(0.8, 0.85, 1.0), (tNorm - 0.75f) * 4.0f);
        }

        // Blend with per-band color when voices are active (bandId > 0)
        float3 bandColor = kBandColors[bClamped];
        float bandMix = (bClamped > 0) ? 0.4f : 0.0f;
        out.color = mix(bbColor, bandColor, bandMix);

        // Speed-based brightness boost (Doppler-like)
        float speed = length(in.velW.xyz);
        float boost = clamp(speed * 8.0f, 0.0f, 0.8f);
        out.color += float3(boost * 0.3f, boost * 0.2f, boost * 0.1f);
    }

    // ── Gargantua: Only cull particles inside the event horizon ──
    // The Schwarzschild radius is 0.40. Cull at RS so the raytracer's black
    // void shows through, but the entire accretion disk (r > 0.40) renders
    // as visible particles with temperature-based color.
    float originR = length(in.posW.xyz);
    out.originDist = originR;
    // RS_CULL = unified BH horizon. Must match BH_HORIZON in
    // particles.metal and `M + sqrt(M²-a²)` in blackhole.metal. With
    // M=0.5, a=0.99M → horizon ≈ 0.57 sim coords.
    float RS_CULL = 0.57f;
    if (originR < RS_CULL) {
        out.position = float4(0, 0, -2, 1);
        out.pointSize = 0.0f;
        out.color = float3(0.0f);
        out.luminance = 0.0f;
        out.originDist = 0.0f;
        out.dist = 1.0f;
        out.velDir2D = float2(0);
        out.strDir2D = float2(0);
        return out;
    }

    return out;
}

fragment float4 particle_fragment(
    VertexOut in [[stage_in]],
    float2 pointCoord [[point_coord]])
{
    // LIGHT SAMPLE rendering — each particle is a photon STREAK, not a dot.
    // Real raytraced light accumulates ALONG the photon path through bent
    // geometry → continuous strands on screen, not discrete points. We
    // approximate this by stretching each particle's emission Gaussian
    // along its screen-space velocity (passed in by the vertex shader as
    // velDir2D). Orbital particles in the xy plane streak tangentially;
    // many overlapping streaks become continuous curved light bands as
    // the orbital motion sweeps around the BH.
    float2 pc = (pointCoord - 0.5f) * 2.0f;        // [-1, 1] over the quad

    // Rotate UV into a velocity-aligned frame. velDir2D from vertex is
    // already scaled by a visual gain — magnitude controls streak length.
    float2 vd     = in.velDir2D;
    float speed   = length(vd);
    float2 dir    = (speed > 1e-4f) ? vd / speed : float2(1.0f, 0.0f);
    float2 perp   = float2(-dir.y, dir.x);
    float along   = dot(pc, dir);
    float across  = dot(pc, perp);

    // Stretch factor:
    //   stationary (speed≈0) → circular Gaussian (a faint dot)
    //   high speed           → elongated streak along motion direction
    // Cap at 0.85 so the streak never collapses to a 1D line — keeps
    // some perpendicular thickness for visual softness.
    float elong  = clamp(speed * 0.6f, 0.0f, 0.85f);
    float widthY = mix(1.0f, 0.20f, elong);          // shrink across
    float lengthX = mix(1.0f, 1.6f,  elong);          // expand along

    // Distance in the warped frame (anisotropic Gaussian).
    float2 warped = float2(along / lengthX, across / widthY);
    float r2 = dot(warped, warped);

    // Pure emission, no discard — fades smoothly at edges so neighbor
    // sprites blend into continuous bands. Hotspot (white core) REMOVED
    // — it stacked under additive blending and bleached the disk to pure
    // white in dense regions, killing the blackbody color (red/orange
    // outer / blue inner). Now color comes ENTIRELY from in.color
    // (blackbody) so dense regions stay colorful.
    //
    // Falloff steepened from -r2·2.0 to -r2·5.0. The old soft Gaussian
    // made every sprite read as a fat ball — visible at zoom as discrete
    // chunky blobs. The tighter falloff keeps the bright core sharp so
    // many overlapping sprites blend additively into a continuous disk
    // instead of looking like individual chunks. The continuous-band
    // appearance comes from particle DENSITY (overlap), not from each
    // sprite's individual falloff being soft.
    float glow = exp(-r2 * 5.0f);

    // Emission multiplier reduced 1.8 → 0.5. With G=20 gravity, particles
    // orbit fast and the velocity-aligned streaks pile up under additive
    // blending → field saturated to white everywhere. Lower per-particle
    // emission lets dense regions glow bright but sparse stay dim, so the
    // BH void and disk structure remain visible against the field.
    float3 emission = in.color * in.luminance * glow * 0.5f;

    float baseAlpha = 0.08f + clamp(in.luminance - 1.0f, 0.0f, 2.0f) * 0.06f;
    float alpha = glow * baseAlpha;

    float fadeDistance = 6.0f;
    float fadeAmount = smoothstep(0.1f, fadeDistance, max(0.0001f, in.dist));

    return float4(emission * alpha * fadeAmount, alpha * fadeAmount);
}
