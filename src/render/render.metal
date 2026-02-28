#include <metal_stdlib>
using namespace metal;

// ── Shared types ────────────────────────────────────────────────────────────

struct Particle {
    float4 posW;
    float4 velW;
};

struct CameraUniforms {
    float4x4 viewProjection;
    float3 cameraPos;
    float particleSize;
    float plateRadius;
    float padding[3];
};

struct VertexOut {
    float4 position [[position]];
    float3 color;
    float3 normal;
    float pointSize [[point_size]];
};

// ── Low-poly sphere vertices (generated procedurally) ───────────────────────

// For instanced rendering: each instance = one particle
// Using point sprites initially, upgrade to sphere mesh later

vertex VertexOut particle_vertex(
    uint vertexId [[vertex_id]],
    uint instanceId [[instance_id]],
    device const Particle* particles [[buffer(0)]],
    constant CameraUniforms& cam [[buffer(1)]])
{
    VertexOut out;

    device const Particle& p = particles[instanceId];
    float R = cam.plateRadius;

    // Map from normalized plate coords to world space
    // x,y are plate coords [-1,1], z is wave depth
    float3 worldPos = float3(p.posW.x * R, p.posW.z, p.posW.y * R);

    out.position = cam.viewProjection * float4(worldPos, 1.0);

    // Color based on height (z displacement)
    float h = p.posW.z / 100.0;  // normalize
    float hue = 0.08 + h * 0.15;  // warm sand tones
    // HSL to RGB approximation
    float r = clamp(abs(hue * 6.0 - 3.0) - 1.0, 0.0, 1.0);
    float g = clamp(2.0 - abs(hue * 6.0 - 2.0), 0.0, 1.0);
    float b = clamp(2.0 - abs(hue * 6.0 - 4.0), 0.0, 1.0);
    out.color = float3(r, g, b) * 0.8;

    out.normal = float3(0, 1, 0);
    out.pointSize = cam.particleSize;

    return out;
}

fragment float4 particle_fragment(
    VertexOut in [[stage_in]])
{
    // Simple shading
    float3 lightDir = normalize(float3(0.3, 1.0, 0.2));
    float diffuse = max(dot(in.normal, lightDir), 0.3);
    float3 color = in.color * diffuse;

    return float4(color, 1.0);
}
