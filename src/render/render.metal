#include <metal_stdlib>
using namespace metal;

struct Particle {
    float4 posW;   // x, y, z, pad  (normalized plate coords)
    float4 velW;   // vx, vy, vz, pad
};

struct CameraUniforms {
    float4x4 viewProjection;
    float4 cameraPos; // Use float4 to match 16-byte alignment and C++ padding
    float particleSize;
    float plateRadius;
    float padding[2];
};

struct VertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float3 color;
};

vertex VertexOut particle_vertex(
    uint vid [[vertex_id]],
    device const Particle* particles [[buffer(0)]],
    constant CameraUniforms& cam [[buffer(1)]])
{
    VertexOut out;
    device const Particle& p = particles[vid];
    float R = cam.plateRadius;

    // Map normalized plate coords to world: x*R, z (wave depth), y*R
    // Top-down orthographic: Y is up (wave depth), X/Z are the plate
    float3 worldPos = float3(p.posW.x * R, p.posW.z, p.posW.y * R);

    out.position = cam.viewProjection * float4(worldPos, 1.0);
    out.pointSize = cam.particleSize;

    // Color: warm sand tones based on wave height
    float h = clamp(p.posW.z / 120.0f, -1.0f, 1.0f);
    float base = 0.55f + h * 0.25f;

    // Sand palette: warm browns/golds — boosted base
    out.color = float3(
        base * 1.6f,
        base * 1.3f,
        base * 0.9f
    );

    // Speed-based brightness boost
    float speed = length(p.velW.xyz);
    float boost = clamp(speed * 4.0f, 0.0f, 0.6f);
    out.color += float3(boost * 0.5f, boost * 0.3f, boost * 0.1f);

    return out;
}

fragment float4 particle_fragment(
    VertexOut in [[stage_in]],
    float2 pointCoord [[point_coord]])
{
    // High-visibility bloom-like falloff
    float dist = length(pointCoord - 0.5f) * 2.0f;
    float alpha = saturate(1.2f - dist);
    alpha = pow(alpha, 1.2f); // Flatter falloff for more "solid" particles
    
    // Return boosted color with alpha
    return float4(in.color * alpha, alpha);
}
