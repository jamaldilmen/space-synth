#include <metal_stdlib>
using namespace metal;

// ── Post-processing: HDR tonemap, bloom, chromatic aberration, trails ───────

struct PostFXUniforms {
    float2 resolution;
    float bloomIntensity;   // 0-1
    float trailDecay;       // 0-1 (0 = no trails)
    float chromaticAmount;  // 0-0.02 typical
    float padding[3];
    float4x4 inverseViewProj;
    float4x4 prevViewProj;
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

    // ── IMAX Veiling Glare (Point Spread Function) ────────────────────────────
    if (u.bloomIntensity > 0.0) {
        float4 bloom = float4(0.0);
        float2 px = u.bloomIntensity * 1.5 / u.resolution;
        
        // IMAX Anamorphic-style PSF:
        // Wide horizontal spread for cinematic "streak" flares, tighter vertical halo.
        // We sample exponentially further to create the "veiling" glare of a real lens.

        // Horizontal wide streak (Anamorphic proxy)
        const int h_samples = 12;
        float h_weight_sum = 0.0;
        for (int i = -h_samples; i <= h_samples; i++) {
            if (i == 0) continue;
            // Exponential falloff for the optical flare tail
            float weight = 1.0 / (1.0 + abs(float(i)) * 0.8);
            float2 offset = float2(float(i) * 3.0, 0.0) * px;
            
            // Extract only the brightest HDR pixels for the flare
            float4 sampleColor = currentFrame.sample(s, uv + offset);
            float luma = dot(sampleColor.rgb, float3(0.299, 0.587, 0.114));
            float threshold = 1.8; // Higher HDR threshold so disk core doesn't blowout
            float extraction = max(0.0, luma - threshold);
            
            bloom += sampleColor * extraction * weight;
            h_weight_sum += weight;
        }
        
        // Vertical soft halo (Standard spherical aberration proxy)
        const int v_samples = 8;
        float v_weight_sum = 0.0;
        for (int i = -v_samples; i <= v_samples; i++) {
            if (i == 0) continue;
            float weight = 1.0 / (1.0 + abs(float(i)) * 1.5);
            float2 offset = float2(0.0, float(i) * 2.0) * px;
            
            float4 sampleColor = currentFrame.sample(s, uv + offset);
            float luma = dot(sampleColor.rgb, float3(0.299, 0.587, 0.114));
            float threshold = 1.5; 
            float extraction = max(0.0, luma - threshold);
            
            bloom += sampleColor * extraction * weight * 0.3; // Less intense vertically
            v_weight_sum += weight * 0.5;
        }

        bloom /= (h_weight_sum + v_weight_sum + 0.001);
        
        // Lowered bloom multiplier so the disk remains sharp
        color.rgb += bloom.rgb * u.bloomIntensity * 1.2; // Reduced from 3.0
    }

    // ── ACES Tonemapping (HDR → SDR) ────────────────────────────────────
    color.rgb = acesTonemap(color.rgb);

    // ── Analytical Motion Blur (Ray-Bundle proxy) ───────────────────────
    // To simulate the streak of a ray-bundle over the camera exposure time,
    // we calculate the exact screen-space velocity of this pixel by un-projecting
    // it to world space, then re-projecting it with the previous frame's matrix.
    
    // We assume the Black Hole and accretion disk particles are far away, 
    // so we approximate their depth as far-plane (z=0.99) for the optical flow proxy.
    float4 ndcPos = float4(uv.x * 2.0 - 1.0, (1.0 - uv.y) * 2.0 - 1.0, 0.99, 1.0);
    
    // 1. Un-project to World Space
    float4 worldPos = u.inverseViewProj * ndcPos;
    worldPos /= worldPos.w;
    
    // 2. Re-project with previous frame's View-Projection
    float4 prevClipPos = u.prevViewProj * worldPos;
    prevClipPos /= prevClipPos.w;
    
    // 3. Calculate screen-space velocity vector
    float2 prevUV = prevClipPos.xy * 0.5 + 0.5;
    prevUV.y = 1.0 - prevUV.y;
    
    float2 velocity = uv - prevUV;
    
    // 4. Streak only the very brightest core pixels (reduced from 8 to 4 samples, HDR-gated)
    float velLen = length(velocity);
    if (velLen > 0.002) {
        // Only blur pixels that are actually bright (HDR luminance gate)
        float luma = dot(color.rgb, float3(0.299, 0.587, 0.114));
        if (luma > 0.3) {
            int blurSamples = 4; // Reduced from 8 for sharper disk
            float blurStrength = min(velLen * 0.5, 1.0); // Scale blur with velocity, cap at 1x
            float4 blurColor = color;

            for (int i = 1; i < blurSamples; i++) {
                float2 sampleUV = uv - velocity * blurStrength * (float(i) / float(blurSamples - 1));
                float4 sColor = currentFrame.sample(s, sampleUV);
                float3 mappedS = acesTonemap(sColor.rgb);
                blurColor.rgb += mappedS;
            }
            color.rgb = blurColor.rgb / float(blurSamples);
        }
    }

    // ── VRAM Trail Decay (persistence) ──────────────────────────────────
    if (u.trailDecay > 0.0) {
        float4 prev = previousFrame.sample(s, uv);
        color = max(color, prev * u.trailDecay);
    }

    return color;
}
