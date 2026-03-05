#include <metal_stdlib>
using namespace metal;

// ── Post-processing: HDR tonemap, bloom, chromatic aberration, trails ───────

struct PostFXUniforms {
    float2 resolution;
    float bloomIntensity;   // 0-1
    float trailDecay;       // 0-1 (0 = no trails)
    float chromaticAmount;  // 0-0.02 typical
    float padding[3];
};

struct PostVertexOut {
    float4 position [[position]];
    float2 uv;
};

// ACES filmic tonemapping (approximation by Krzysztof Narkowicz)
static float3 acesTonemap(float3 x) {
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
}

vertex PostVertexOut postfx_vertex(uint vertexId [[vertex_id]]) {
    PostVertexOut out;
    float2 pos;
    pos.x = (vertexId == 1) ? 3.0 : -1.0;
    pos.y = (vertexId == 2) ? 3.0 : -1.0;
    out.position = float4(pos, 0.0, 1.0);
    out.uv = pos * 0.5 + 0.5;
    out.uv.y = 1.0 - out.uv.y;  // Flip Y for Metal
    return out;
}

fragment float4 postfx_fragment(
    PostVertexOut in [[stage_in]],
    texture2d<float> currentFrame [[texture(0)]],
    texture2d<float> previousFrame [[texture(1)]],
    constant PostFXUniforms& u [[buffer(0)]])
{
    constexpr sampler s(mag_filter::linear, min_filter::linear);
    float2 uv = in.uv;

    // ── Chromatic aberration ────────────────────────────────────────────
    float2 d = uv - 0.5;
    float dist = length(d);
    float2 offset = d * dist * u.chromaticAmount;

    float r = currentFrame.sample(s, uv + offset).r;
    float g = currentFrame.sample(s, uv).g;
    float b = currentFrame.sample(s, uv - offset).b;
    float4 color = float4(r, g, b, 1.0);

    // ── Bloom: cross-shaped bright-pass blur ────────────────────────────
    if (u.bloomIntensity > 0.0) {
        float4 bloom = float4(0.0);
        float2 px = u.bloomIntensity * 1.5 / u.resolution;

        // Horizontal samples
        bloom += currentFrame.sample(s, uv + float2(-3.0, 0.0) * px);
        bloom += currentFrame.sample(s, uv + float2(-2.0, 0.0) * px);
        bloom += currentFrame.sample(s, uv + float2(-1.0, 0.0) * px);
        bloom += currentFrame.sample(s, uv);
        bloom += currentFrame.sample(s, uv + float2(1.0, 0.0) * px);
        bloom += currentFrame.sample(s, uv + float2(2.0, 0.0) * px);
        bloom += currentFrame.sample(s, uv + float2(3.0, 0.0) * px);

        // Vertical samples
        bloom += currentFrame.sample(s, uv + float2(0.0, -3.0) * px);
        bloom += currentFrame.sample(s, uv + float2(0.0, -2.0) * px);
        bloom += currentFrame.sample(s, uv + float2(0.0, -1.0) * px);
        bloom += currentFrame.sample(s, uv + float2(0.0, 1.0) * px);
        bloom += currentFrame.sample(s, uv + float2(0.0, 2.0) * px);
        bloom += currentFrame.sample(s, uv + float2(0.0, 3.0) * px);

        bloom /= 13.0;
        color.rgb += bloom.rgb * u.bloomIntensity * 2.0;
    }

    // ── ACES Tonemapping (HDR → SDR) ────────────────────────────────────
    color.rgb = acesTonemap(color.rgb);

    // ── Motion blur / trails: blend with previous frame ─────────────────
    if (u.trailDecay > 0.0) {
        float4 prev = previousFrame.sample(s, uv);
        color = max(color, prev * u.trailDecay);
    }

    return color;
}
