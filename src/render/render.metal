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

// Safe normalization to prevent NaNs at rest (Phase 12 bug fix)
static float2 safe_normalize(float2 v) {
    float l = length(v);
    return (l > 1e-9f) ? v / l : float2(0.0f, 0.0f);
}

struct VertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float3 color;
    float dist;        // Camera distance for fade
    float luminance;   // HDR emission intensity
    float originDist;  // Distance from universe origin (0,0,0) for event horizon
    float2 velDir2D;   // Phase 11: Screen-space velocity direction for string elongation
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
    float mass = p.posW.w;

    // Wall particles (mass=0) are invisible — they're structural, not visual
    if (mass < 0.001f) {
        out.position = float4(0, 0, -2, 1); // Behind clip plane
        out.pointSize = 0.0f;
        out.color = float3(0);
        out.luminance = 0.0f;
        out.originDist = 0.0f;
        out.dist = 1.0f;
        out.velDir2D = float2(0);
        return out;
    }

    // Map normalized plate coords to world: scale all axes by R for isotropic 3D
    float3 worldPos = p.posW.xyz * R;

    out.position = cam.viewProjection * float4(worldPos, 1.0);
    
    // Phase 11: Project velocity into screen-space for string elongation
    float3 velWorld = p.velW.xyz * R;
    float4 endClip = cam.viewProjection * float4(worldPos + velWorld * 0.5f, 1.0);
    float2 v1_screen = out.position.xy / out.position.w;
    float2 v2_screen = endClip.xy / endClip.w;
    
    out.velDir2D = (v2_screen - v1_screen) * 5.0f; // Pass raw screen-space velocity for dynamic elongation

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
    out.luminance = 1.0f + max(0.0f, temp) * 2.0f; // Subtle warm glow, not blinding white

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

    // ── Phase 16: Gargantua Cosmics ──────────────────────────────
    float originR = length(p.posW.xyz);
    out.originDist = originR;
    
    // Volumetric Obscuration Approximation:
    // Particles behind the black hole from the camera's perspective should be dimmed/reddened
    float3 camToPart = normalize(worldPos - cam.cameraPos.xyz);
    float3 camToHole = normalize(-cam.cameraPos.xyz);
    float alignment = dot(camToPart, camToHole);
    bool isBehind = (alignment > 0.999f && length(cam.cameraPos.xyz) > originR * R);
    
    // Schwarzschild radius: particles inside the event horizon are invisible
    float schwarzschild = 0.1f;  // Phase 16: Supermassive dark core
    float coronaRadius  = 0.55f; // Widened accretion disk to match physics
    
    if (originR < schwarzschild) {
        // Inside the event horizon: swallowed by the singularity
        out.pointSize = 0.0f;
        out.color = float3(0.0f);
        out.luminance = 0.0f;
    } else if (originR < coronaRadius) {
        // Accretion disk: superhot plasma spiraling in
        float coronaHeat = 1.0f - (originR - schwarzschild) / (coronaRadius - schwarzschild);
        coronaHeat = pow(coronaHeat, 2.0f); // Smooth falloff
        
        float3 coronaColor = mix(
            float3(1.0f, 0.3f, 0.02f),  // Deep orange at edge
            float3(1.0f, 0.95f, 0.7f),  // White-hot near core
            coronaHeat
        );
        out.color = coronaColor;
        out.luminance = 1.0f + coronaHeat * 8.0f;
        out.pointSize *= (1.0f + coronaHeat * 1.5f);
        
        if (isBehind) {
            out.color *= 0.2f;
            out.luminance *= 0.1f;
        }
    }

    return out;
}

fragment float4 particle_fragment(
    VertexOut in [[stage_in]],
    float2 pointCoord [[point_coord]])
{
    // Phase 11: String Theory Rendering
    // Stretch the circular point sprite into an ellipse along velocity direction
    // This replaces 0D point particles with 1D vibrating "strings"
    float2 pc = pointCoord - 0.5f;
    
    // Rotate pointCoord into velocity-aligned frame
    float2 vd = in.velDir2D;
    float speedSq = dot(vd, vd);
    float speed = sqrt(speedSq);
    float2 dir = (speed > 1e-4f) ? vd / speed : float2(1, 0);
    float2 perp = float2(-dir.y, dir.x);
    float along = dot(pc, dir);  
    float across = dot(pc, perp); 
    
    // Dynamic elongation: 1.0 = circle at rest, 0.1 = thin string at high speed
    float elongation = clamp(speed, 0.0f, 1.0f);
    float stringWidth = mix(1.0f, 0.25f, elongation);
    float d = length(float2(along, across / stringWidth)) * 2.1f;

    // Sharper core falloff
    float core = pow(max(0.0f, 1.0f - d), 2.5f);
    float glow = exp(-d * d * 5.0f);

    float3 coreColor = float3(1.0f, 0.98f, 0.95f);
    float3 glowColor = in.color;

    float3 finalColor = mix(glowColor * glow, coreColor, core);
    
    // High-contrast Alpha: 0.15 base + energy boost
    float baseAlpha = 0.15f + clamp(in.luminance - 1.0f, 0.0f, 2.0f) * 0.05f;
    float alpha = (core * 0.6f + glow * 0.25f) * baseAlpha;

    finalColor *= in.luminance;

    float fadeDistance = 6.0f;
    float fadeAmount = smoothstep(0.1f, fadeDistance, max(0.0001f, in.dist));

    return float4(finalColor * alpha * fadeAmount, alpha * fadeAmount);
}
