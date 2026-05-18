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
    float2 padding;
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
    
    // VJ Sustain: Particle size grows with thermal energy (audio activity)
    // Hot particles at harmonic nodes become slightly larger during sustain
    float temp = in.prevW.w;
    float heatSizeBoost = 1.0f + clamp(temp, 0.0f, 1.0f) * 1.5f; // 1x → 2.5x
    float rawSize = cam.particleSize * heatSizeBoost * (800.0f / max(0.0001f, dist));
    out.pointSize = clamp(rawSize, 1.0f, 32.0f); // Hard cap at 32px to prevent overdraw

    // HDR luminance from thermal energy (ODS-03)
    out.luminance = 1.0f + max(0.0f, temp) * 2.0f; // Subtle warm glow, not blinding white

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
    float RS_CULL = 0.40f;
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
    // Sphere impostor: reconstruct a hemisphere normal from the point-sprite
    // UV. Lambertian shade against a fixed key light + small ambient so the
    // phase-viz and motion read as 3D balls instead of 2D confetti.
    // String Theory elongation removed — was streaking particles into 1D
    // strings along velocity (the confetti look). Particles are spheres now.
    float2 pc = (pointCoord - 0.5f) * 2.0f;   // [-1, 1] over the quad
    float r2 = dot(pc, pc);
    if (r2 > 1.0f) discard_fragment();         // clip to the disc

    float z = sqrt(1.0f - r2);
    float3 n = float3(pc.x, -pc.y, z);         // flip Y to match screen orientation

    // Fixed key light from upper-right-front, plus rim from behind.
    float3 keyDir = normalize(float3(0.4f, 0.6f, 0.7f));
    float diff = max(0.0f, dot(n, keyDir));
    float rim  = pow(1.0f - max(0.0f, n.z), 3.0f) * 0.6f;
    float spec = pow(max(0.0f, dot(n, keyDir)), 24.0f) * 0.5f;

    float3 baseColor = in.color;
    float3 finalColor = baseColor * (0.25f + 0.85f * diff) + float3(spec) + baseColor * rim;
    finalColor *= in.luminance;

    // Alpha: solid in the center, soft edge from the implicit sphere silhouette.
    float baseAlpha = 0.5f + clamp(in.luminance - 1.0f, 0.0f, 2.0f) * 0.15f;
    float edge = smoothstep(1.0f, 0.85f, r2);  // softens silhouette slightly
    float alpha = edge * baseAlpha;

    float fadeDistance = 6.0f;
    float fadeAmount = smoothstep(0.1f, fadeDistance, max(0.0001f, in.dist));

    return float4(finalColor * alpha * fadeAmount, alpha * fadeAmount);
}
