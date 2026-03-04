#include <metal_stdlib>
using namespace metal;

struct Particle {
    float4 posW;   // x, y, z, mass  (normalized plate coords)
    float4 velW;   // vx, vy, vz, phase
    float4 prevW;  // prevX, prevY, prevZ, temperature
};

struct CameraUniforms {
    float4x4 viewProjection;
    float4 cameraPos; // Use float4 to match 16-byte alignment and C++ padding
    float particleSize;
    float plateRadius;
    float phaseViz;    // 1.0 = phase coloring, 0.0 = default
    float waveDepth;
    float padding[1];
};

struct VertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float3 color;
    float dist;        // Camera distance for fade
    float luminance;   // HDR emission intensity
    float originDist;  // Distance from universe origin (0,0,0) for event horizon
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
    device const Particle* particles [[buffer(0)]],
    constant CameraUniforms& cam [[buffer(1)]])
{
    VertexOut out;
    device const Particle& p = particles[vid];
    float R = cam.plateRadius;

    // Map normalized plate coords to world: scale all axes by R for isotropic 3D
    float3 worldPos = p.posW.xyz * R;

    out.position = cam.viewProjection * float4(worldPos, 1.0);

    // Dynamic Point Size Scaling
    float isOrtho = cam.padding[0];
    float dist = mix(out.position.w, cam.cameraPos.w, isOrtho);
    out.dist = dist;
    
    // VJ Sustain: Particle size grows with thermal energy (audio activity)
    // Hot particles at harmonic nodes become slightly larger during sustain
    float temp = p.prevW.w;
    float heatSizeBoost = 1.0f + clamp(temp, 0.0f, 1.0f) * 1.5f; // 1x → 2.5x
    float rawSize = cam.particleSize * heatSizeBoost * (800.0f / max(0.0001f, dist));
    out.pointSize = clamp(rawSize, 1.0f, 32.0f); // Hard cap at 32px to prevent overdraw

    // HDR luminance from thermal energy (ODS-03)
    out.luminance = 1.0f + max(0.0f, temp) * 6.0f; // Stronger heat-driven plasma glow

    if (cam.phaseViz > 0.5f) {
        // Feynman phase arrow coloring: phase → hue
        float phase = p.velW.w;
        float hue = (phase + M_PI_F) / (2.0f * M_PI_F);
        float speed = length(p.velW.xyz);
        float saturation = 0.85f;
        float value = 0.5f + clamp(speed * 3.0f, 0.0f, 0.5f);
        out.color = hsv2rgb(hue, saturation, value);
    } else {
        // Default: warm sand tones based on wave height (normalized Z)
        float h = clamp(p.posW.z, -1.0f, 1.0f);
        float base = 0.6f + h * 0.35f;
        out.color = float3(base * 1.6f, base * 1.3f, base * 0.9f);

        // Speed-based brightness boost
        float speed = length(p.velW.xyz);
        float boost = clamp(speed * 8.0f, 0.0f, 0.8f);
        out.color += float3(boost * 0.6f, boost * 0.4f, boost * 0.2f);
    }

    // ── Black Hole Event Horizon ──────────────────────────────────
    // Distance from universe origin in normalized coords
    float originR = length(p.posW.xyz);
    out.originDist = originR;
    
    // Schwarzschild radius: particles inside the event horizon are invisible
    float schwarzschild = 0.015f; // Tiny dark core
    float coronaRadius  = 0.08f;  // Accretion disk sweet-spot
    
    if (originR < schwarzschild) {
        // Inside the event horizon: swallowed by the singularity
        out.pointSize = 0.0f;
        out.color = float3(0.0f);
        out.luminance = 0.0f;
    } else if (originR < coronaRadius) {
        // Accretion corona: superhot ring glowing orange-white
        float coronaHeat = 1.0f - (originR - schwarzschild) / (coronaRadius - schwarzschild);
        coronaHeat = coronaHeat * coronaHeat; // Quadratic falloff
        
        // Shift color toward hot plasma (orange → white)
        float3 coronaColor = mix(
            float3(1.0f, 0.6f, 0.15f),  // Deep orange
            float3(1.0f, 0.95f, 0.85f), // Near-white
            coronaHeat
        );
        out.color = coronaColor;
        out.luminance += coronaHeat * 3.0f; // Extra HDR glow
    }

    return out;
}

fragment float4 particle_fragment(
    VertexOut in [[stage_in]],
    float2 pointCoord [[point_coord]])
{
    float d = length(pointCoord - 0.5f) * 2.0f;

    float core = pow(max(0.0f, 1.0f - d), 3.0f);
    float glow = exp(-d * d * 3.5f);

    float3 coreColor = float3(1.0f, 0.95f, 0.9f);
    float3 glowColor = in.color;

    float3 finalColor = mix(glowColor * glow, coreColor, core);
    
    // VJ Sustain Alpha: Base alpha scales up with luminance so sustained shapes
    // stay bold and visible. Cold/silent particles remain faint dust.
    float baseAlpha = 0.08f + clamp(in.luminance - 1.0f, 0.0f, 3.0f) * 0.12f; // 0.08 → 0.44
    float alpha = (core * 0.5f + glow * 0.3f) * baseAlpha;

    // HDR emission: scale by luminance (energy-based brightness)
    finalColor *= in.luminance;

    float fadeDistance = 6.0f;
    float fadeAmount = smoothstep(0.1f, fadeDistance, max(0.0001f, in.dist));

    return float4(finalColor * alpha * fadeAmount, alpha * fadeAmount);
}
