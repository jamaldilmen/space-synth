#include <metal_stdlib>
using namespace metal;

struct Particle {
    float4 posW;   // x, y, z, mass  (normalized plate coords)
    float4 velW;   // vx, vy, vz, phase
};

struct CameraUniforms {
    float4x4 viewProjection;
    float4 cameraPos; // Use float4 to match 16-byte alignment and C++ padding
    float particleSize;
    float plateRadius;
    float phaseViz;    // 1.0 = phase coloring, 0.0 = default
    float padding[1];
};

struct VertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float3 color;
    float dist;      // Pass distance to fragment
    float luminance;  // HDR emission intensity
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

    // Map normalized plate coords to world: x*R, z (wave depth), y*R
    float3 worldPos = float3(p.posW.x * R, p.posW.z, p.posW.y * R);

    out.position = cam.viewProjection * float4(worldPos, 1.0);

    // Dynamic Point Size Scaling
    float isOrtho = cam.padding[0];
    float dist = mix(out.position.w, cam.cameraPos.w, isOrtho);
    out.dist = dist;
    out.pointSize = max(0.2f, cam.particleSize * (800.0f / max(0.0001f, dist)));

    // HDR luminance from kinetic energy
    float speed = length(p.velW.xyz);
    float ke = 0.5f * p.posW.w * speed * speed; // 0.5 * mass * v^2
    out.luminance = 1.0f + ke * 8.0f; // Base luminance + energy glow

    if (cam.phaseViz > 0.5f) {
        // Feynman phase arrow coloring: phase → hue
        float phase = p.velW.w; // phase in [-pi, pi]
        float hue = (phase + M_PI_F) / (2.0f * M_PI_F); // [0, 1]
        float speed = length(p.velW.xyz);
        float saturation = 0.85f;
        float value = 0.5f + clamp(speed * 3.0f, 0.0f, 0.5f);
        out.color = hsv2rgb(hue, saturation, value);
    } else {
        // Default: warm sand tones based on wave height
        float h = clamp(p.posW.z / 120.0f, -1.0f, 1.0f);
        float base = 0.55f + h * 0.25f;

        out.color = float3(
            base * 1.6f,
            base * 1.3f,
            base * 0.9f
        );

        // Speed-based brightness boost
        float speed = length(p.velW.xyz);
        float boost = clamp(speed * 4.0f, 0.0f, 0.6f);
        out.color += float3(boost * 0.5f, boost * 0.3f, boost * 0.1f);
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
    float alpha = core + glow * 0.4f;

    // HDR emission: scale by luminance (energy-based brightness)
    finalColor *= in.luminance;

    float fadeDistance = 6.0f;
    float fadeAmount = smoothstep(0.1f, fadeDistance, max(0.0001f, in.dist));

    return float4(finalColor * alpha * fadeAmount, alpha * fadeAmount);
}
