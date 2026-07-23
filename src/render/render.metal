#include <metal_stdlib>
using namespace metal;

struct Particle {
    float4 posW;   // x, y, z, mass  (normalized plate coords)
    float4 velW;   // vx, vy, vz, phase
    float4 prevW;  // prevX, prevY, prevZ, temperature
    float4 spinW;  // spinX, spinY, spinZ, charge
    uint4 entanglement; // x: entangledIndex, y: pad1, z: pad2, w: pad3
};

// MUST match src/render/particles.metal exactly (same buffer, same layout).
// Bound to particle_vertex so the render can read each particle's local cell
// density (the hash-grid count) and gate the gaseous kernel on it.
struct SpatialHashUniforms {
    int   gridSize;
    int   particleCount;
    float cellSize;
    float invCellSize;
    int   gridSizeZ;
    float halfExtent;   // particle field half-extent in sim coords
};

struct CameraUniforms {
    float4x4 viewProjection;
    float4 cameraPos; // Use float4 to match 16-byte alignment and C++ padding
    float particleSize;
    float plateRadius;
    float phaseViz;    // 1.0 = phase coloring, 0.0 = default
    float waveDepth;
    float envelopePhase; // 0=silence(black hole), 1-4=ADSR
    float envelopeProgress; // 0→1 within phase (ramps the lens in over release)
    float orthoMode;
    float bhShadowNdcRadius; // shadow's on-screen radius = lens Einstein radius
    float aspect;            // width/height, to make the lens screen-isotropic
    float sharpness;         // particle Gaussian falloff exponent (live-tunable)
    float grainAlpha;        // per-particle base alpha (live-tunable)
    float oscAmount;         // oscilloscope scope-line gate (0 = off → no lines)
    float spinX;             // spin rate around X (rad/s) — trail/Doppler velocity
    float spinY;             // spin rate around Y (rad/s) — trail/Doppler velocity
    float spinAngleX;        // accumulated spin angle X (rad) — rigid render spin
    float spinAngleY;        // accumulated spin angle Y (rad) — rigid render spin
    float bhStrength;        // emergent-hole signal r_s(M_enc)/R_ENC (0..1, Step 3)
    float tuneLens;          // lens bend blend (UI dial)
    float tuneArcWrap;       // max arc sweep, rad (UI dial)
    float tuneArcGain;       // horizon exposure gain (UI dial)
    float tuneTrailGain;     // arc brightness multiplier (UI dial)
    float tuneStreakLen;     // motion-streak length multiplier (UI dial)
    float tuneColorK;        // colour spectrum: |v|²→Kelvin gain (UI dial, was pad)
    float tuneHeatK;         // thermal heat→Kelvin gain (UI dial): low = warm/red, high = white plasma
    uint bhToggles;          // BH-mechanism on/off bitmask (UI); bit7 seed-render, bit8 lens/shadow
    float bhDiskGM;          // posed BH: GM in sim units (0 = not posed → no disk spin)
    float bhPoseTime;        // posed BH: elapsed seconds since pose (drives Ω(r)·t)
    float bhPoseDt;          // posed BH: last frame dt (rotate prev by one frame less)
    float horizonR;          // honest geometric r_h [sim] (0 = no hole) → hole pass
    float bhDiskAxisY;       // 1 = emergent time-lapse about Y (honest hole); 0 = posed legacy Z
    float bhX;               // emergent hole centre (= bhPos) — spin/cull about this, not origin
    float bhY;               // (after PLAY the collapsed hole forms off-centre)
    float bhZ;
    float spinZ;             // roll rate around Z (rad/s) — appended 2026-07-19, keep LAST
    float spinAngleZ;        // accumulated roll angle Z (rad) — mirror order = renderer.h
};

// Rigid-body spin: rotate a sim-space position by the accumulated spin angle
// (around Y then X). The whole shape rotates as one solid body in the render —
// physics stays spin-free, so there's no force-fighting (no rest-scatter, no
// note-pinning). Rotation preserves length, so the horizon/colour radius is
// unchanged.
static float3 applySpin(float3 p, float ax, float ay, float az) {
    // Roll about Z first (Option+←/→, 2026-07-19), then the original Y→X.
    float cz = cos(az), sz = sin(az);
    p = float3(p.x * cz - p.y * sz, p.x * sz + p.y * cz, p.z);
    float cy = cos(ay), sy = sin(ay);
    float3 r = float3(p.x * cy + p.z * sy, p.y, -p.x * sy + p.z * cy);
    float cx = cos(ax), sx = sin(ax);
    return float3(r.x, r.y * cx - r.z * sx, r.y * sx + r.z * cx);
}

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
    float sharpness;   // live render control (Gaussian falloff exponent)
    float grainAlpha;  // live render control (per-particle base alpha)
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

// ── Real blackbody colour: Tanner Helland K→RGB (T in Kelvin) ──────────────
// Physically-grounded Planckian-locus approximation (no hand-tuned ramp).
// 1000K deep red → 3000K orange → ~4500K yellow → 6500K white → >8000K blue.
static float3 blackbodyRGB(float kelvin) {
    float t = clamp(kelvin, 1000.0f, 40000.0f) / 100.0f;
    float r, g, b;
    if (t <= 66.0f) r = 255.0f;
    else            r = clamp(329.698727446f * pow(t - 60.0f, -0.1332047592f), 0.0f, 255.0f);
    if (t <= 66.0f) g = clamp(99.4708025861f * log(t) - 161.1195681661f, 0.0f, 255.0f);
    else            g = clamp(288.1221695283f * pow(t - 60.0f, -0.0755148492f), 0.0f, 255.0f);
    if (t >= 66.0f) b = 255.0f;
    else if (t <= 19.0f) b = 0.0f;
    else            b = clamp(138.5177312231f * log(t - 10.0f) - 305.0447927307f, 0.0f, 255.0f);
    return float3(r, g, b) / 255.0f;
}

// ── Artistic temperature ramp — WHITE IS RARE ──────────────────────────────
// Rich red→orange→yellow→white→blue, with white & blue compressed into the top
// ~15% (white only near peak temperature), so the field stays COLOURFUL instead
// of washing to white the moment anything gets hot. t is the physical
// temperature normalised to PEAK_KELVIN. (The literal blackbody curve whites
// out at ~6500K — true physics, dead picture; this keeps the colour dynamic.)
static float3 heatRamp(float t) {
    t = clamp(t, 0.0f, 1.0f);
    if (t < 0.35f)      return mix(float3(0.45,0.02,0.0), float3(1.0,0.35,0.02), t / 0.35f);
    else if (t < 0.65f) return mix(float3(1.0,0.35,0.02), float3(1.0,0.82,0.20), (t-0.35f)/0.30f);
    else if (t < 0.86f) return mix(float3(1.0,0.82,0.20), float3(1.0,0.98,0.95), (t-0.65f)/0.21f);
    else                return mix(float3(1.0,0.98,0.95), float3(0.55,0.72,1.0), (t-0.86f)/0.14f);
}

// ── SUPERNOVA emission-line palette (NASA physics, NOT blackbody) ───────────
// A supernova remnant emits discrete shock-ionization EMISSION LINES, not a
// thermal continuum. By increasing shock temperature / ionization:
//   cool recombination  Hα 656 / [SII] 672 / [NII] 658  → RED
//   faster shock >100km/s  [OIII] 501                    → GREEN-TEAL (the tell;
//                                                          a blackbody is never green)
//   high ionization     Hβ 486 / He II                   → CYAN
//   hot X-ray plasma (10^6–10^7 K) / synchrotron         → BLUE-WHITE
// This is what makes the played "supernova" state look different from the
// thermal black-hole disk. t = sim temperature normalised to SN_TEMP_PEAK.
static float3 supernovaRamp(float t) {
    t = clamp(t, 0.0f, 1.0f);
    float3 cRed    = float3(0.85, 0.06, 0.05);  // Hα / [SII]  656–672nm
    float3 cOrange = float3(1.00, 0.45, 0.08);  // [OI]        630nm
    float3 cGreen  = float3(0.10, 0.90, 0.45);  // [OIII]      501nm  ← signature
    float3 cCyan   = float3(0.05, 0.65, 1.00);  // Hβ          486nm
    float3 cBlue   = float3(0.25, 0.45, 1.00);  // X-ray / synchrotron — SATURATED
                                                // blue plasma (not blue-white), so
                                                // the hottest core stays coloured
    if (t < 0.22f)      return mix(float3(0.45,0.02,0.05), cRed, t / 0.22f);
    else if (t < 0.45f) return mix(cRed,    cOrange, (t-0.22f)/0.23f);
    else if (t < 0.65f) return mix(cOrange, cGreen,  (t-0.45f)/0.20f);
    else if (t < 0.85f) return mix(cGreen,  cCyan,   (t-0.65f)/0.20f);
    else                return mix(cCyan,   cBlue,   (t-0.85f)/0.15f);
}

// ── Shakura–Sunyaev thin-disk temperature shape (relative, r in sim units) ──
// T(r) ∝ (r_in/r)^(3/4) · (1 − √(r_in/r))^(1/4): the real thin-disk profile —
// peaks just outside the inner edge, falls as r^(−3/4). Zero inside r_in.
static float ssDiskTempShape(float rSim, float rIn) {
    if (rSim <= rIn) return 0.0f;
    float x = rIn / rSim;
    return pow(x, 0.75f) * pow(max(0.0f, 1.0f - sqrt(x)), 0.25f);
}

// M87* anchor (see blackhole physics plan). Disk inner edge = the horizon cull.
constant float BH_R_IN_SIM   = 0.57f;     // disk inner edge (= RS_CULL)
constant float DISK_T_STAR_K = 7500.0f;   // S–S temperature scale (∝ accretion
                                          // rate Ṁ). M87* is an underfed low-Ṁ
                                          // AGN → COOL disk: rest ring ≈ 3500K
                                          // (orange), outer ≈ 1900K (deep red).
                                          // Play-heat drives it up to white→blue.
                                          // Tunable = the disk Ṁ.
constant float HEAT_K_PER_T  = 3000.0f;   // shock/play heat → Kelvin (sim temp
                                          // 0–5 adds 0–15000K → blue-white shapes)
// |v|² → Kelvin gain for the true-temperature spectrum is now a LIVE UI dial:
// cam.tuneColorK (default 27000). Slide it to spread red↔blue.
constant float PEAK_KELVIN   = 25000.0f;  // temperature that maps to the ramp's
                                          // peak (white/blue). High → white rare.
constant float SN_TEMP_PEAK  = 12.0f;     // sim temp → supernova ramp peak.
                                          // MEASURED 2026-06-25 (COLOR-TEMP probe,
                                          // main.cpp): during PLAY prevW.w avg≈6–10,
                                          // MAX≈12, min≈3. The old 6.0 clamped
                                          // temp/PEAK to 1.0 → ramp PINNED to BLUE,
                                          // no sweep. 12 = the measured play max, so
                                          // the real per-particle spread maps across
                                          // the full ramp: cool→orange/red, mid→green
                                          // [OIII], hot collision/node spots→cyan→blue.

// ── Interstellar/DNGR disk maths (applied to particles, not a raytracer) ────
constant float KERR_A    = 0.5f;   // BH spin in the Ω(r)=1/(r^1.5+a) speed law
// Doppler is split into COLOUR shift and BEAMING intensity so we can have a
// strong colour swing (blue approaching / red receding) WITHOUT the beaming
// blowing one side away (the "half black hole").
constant float DOPPLER_K_COLOR = 5.0f;  // colour frequency shift — MODERATE: a
                                        // warm lopsidedness (bright gold-white
                                        // approaching → amber receding), toward the
                                        // movie's mostly-symmetric warm disk rather
                                        // than crashing the far side to the red
                                        // floor. Beaming stays gentle (whole disk).
constant float DOPPLER_K_BEAM  = 0.8f; // beaming intensity — gentle (whole disk)
constant float DOPPLER_EXP     = 1.4f; // beaming exponent
constant float SPIN_VEL_SCALE  = 0.08f;// brings spin (rad/s) into orbital-velocity
                                       // scale so spinning drives the colour shift
constant float STREAK_EXPOSURE = 0.05f; // motion-blur length (SHORT → crisp
                                        // particles, not soft smears)
constant float STREAK_GAIN     = 3.0f;  // screen-space streak amplification (low)

// ── DEFLECTION MAP (2026-07-17) — exact Schwarzschild bending angle α(b) ──
// 256-entry LUT computed once on the CPU by integrating the real null-geodesic
// deflection integral (renderer.mm schwarzschildAlpha). Scale-free: indexed by
// x = b/r_s, log-spaced x ∈ [2.60, 200] (x_crit = 3√3/2 ≈ 2.598 = capture).
// This is the DNGR-doc verdict (docs/blackhole_render_research_notes.md §0/§5):
// the light of the particles bends through the metric in WORLD space — the
// particles stay the only source, the map only bends their light.
static float lensAlphaSample(device const float* lut, float x) {
    float t = clamp(log(x / 2.60f) / log(200.0f / 2.60f), 0.0f, 1.0f) * 255.0f;
    uint  i = (uint)t;
    return mix(lut[i], lut[min(i + 1u, 255u)], t - (float)i);
}

vertex VertexOut particle_vertex(
    uint vid [[vertex_id]],
    uint iid [[instance_id]],
    device const Particle* particlesIn [[buffer(0)]],
    constant CameraUniforms& cam [[buffer(1)]],
    device const Particle* particlesRef [[buffer(2)]],
    device const float* lensAlphaLUT [[buffer(3)]],
    device const uint* cellCounts [[buffer(4)]],        // hash-grid density (per cell)
    constant SpatialHashUniforms& su [[buffer(5)]])     // grid params for the cell lookup
{
    VertexOut out;
    Particle in = particlesIn[vid];

    // ── POSED-BH DISK ROTATION — real Keplerian Ω(r), differential ───────────
    // While a black hole is POSED (cam.bhDiskGM>0, sim paused), spin the disk in
    // its plane (about Z) at the physical orbital rate Ω(r)=√(GM/r³): inner edge
    // whips around (~0.4c at ISCO), outer crawls. Slowed near the hole by the
    // relativistic time dilation √(1−r_s/r) (r_s=1.0 sim) — the inner edge nearly
    // freezes, the BH altering time made visible. pos and prev are rotated (prev
    // by one frame less) so the per-frame velocity stays the TRUE orbital motion,
    // keeping the Doppler/streaks honest. No physics — pure analytic playback.
    if (cam.bhDiskGM > 0.0f && cam.bhDiskAxisY < 0.5f) {
        float2 c2 = float2(cam.bhX, cam.bhY);   // hole centre (off-origin after PLAY)
        float rxy = length(in.posW.xy - c2);
        // REAL RELATIVISTIC TIME BENDING (2026-07-16, Jamal item 3: "finally
        // introduce the realistic relativistic time bending in proportion to
        // the black hole — it is still way too small"). r_s = the HONEST r_h
        // when the emergent hole drives (legacy posed keeps 1.0); dilation
        // floor 0.4 → 0.02: the inner edge now genuinely FREEZES toward the
        // horizon — time visibly stopping, scaling with the hole as it eats.
        // Matter inside r_h doesn't playback-rotate at all (membrane).
        float rsDil = (cam.horizonR > 0.0f) ? cam.horizonR : 1.0f;
        if (rxy > max(1e-3f, cam.horizonR)) {
            float omega = sqrt(cam.bhDiskGM / (rxy * rxy * rxy));
            // Dilation floor 0.02 → 0.4 (2026-07-19 18:30, Jamal: "stuff in
            // the inner horizon basically doesn't spin at all"): at 0.02 the
            // inner edge froze solid — GR-correct for a distant observer, but
            // it reads as DEAD matter. At 0.4 the inner edge visibly whips
            // while still clearly slowed vs the outer disk: time bending
            // stays readable without the freeze.
            float tdil  = sqrt(max(0.4f, 1.0f - rsDil / max(rxy, rsDil + 1e-3f)));
            float wEff  = omega * tdil;
            float aNow  = wEff * cam.bhPoseTime;
            float aPrev = wEff * (cam.bhPoseTime - cam.bhPoseDt);
            float cN = cos(aNow),  sN = sin(aNow);
            float cP = cos(aPrev), sP = sin(aPrev);
            float2 p = in.posW.xy - c2,  q = in.prevW.xy - c2;   // rotate ABOUT the hole centre
            in.posW.xy  = c2 + float2(p.x * cN - p.y * sN, p.x * sN + p.y * cN);
            in.prevW.xy = c2 + float2(q.x * cP - q.y * sP, q.x * sP + q.y * cP);
        }
    }
    // ── EMERGENT-HOLE TIME-LAPSE (2026-07-15, Jamal's breakthrough: "rotation
    // means time passes on a trajectory") — the SAME Keplerian playback, keyed
    // to the HONEST hole: GM = real M(<r_h) (CPU: lastHorizonMass), rotation
    // about the disk's true axis Y, r_s = the honest r_h in the dilation, LIVE
    // physics untouched underneath (this compresses the render clock only —
    // the declared time-lapse, cf. fRelax/F_LTRANS; the trails then draw the
    // orbits as light = the BH's visual identity, his 20:24 screenshots).
    // r > r_h ONLY (2026-07-16): the interior is causally dead (membrane) —
    // playback-rotating it fought the frozen physics at the boundary
    // (Jamal: "the spin in the center and outside don't add up").
    if (cam.bhDiskGM > 0.0f && cam.bhDiskAxisY > 0.5f) {
        // PLANE FIX (2026-07-19): this block was written 07-15 when the disk
        // orbited about Y (x–z). The 07-16 plate-plane alignment moved the
        // physical disk to x–y about Z — posing about Y on a Z-orbiting disk
        // superimposes two rotation axes near the centre (Jamal: "rotating in
        // two directions at once"). Now: same plane (x–y about Z), same CCW
        // sense as the spawn orbits (+z×r), about the hole centre like the
        // dial pose above. Dilation floor/r_s semantics unchanged.
        float2 c2 = float2(cam.bhX, cam.bhY);   // hole centre (off-origin after PLAY)
        float rxy = length(in.posW.xy - c2);
        if (rxy > max(1e-3f, cam.horizonR)) {
            float rs = max(cam.horizonR, 1e-3f);
            float omega = sqrt(cam.bhDiskGM / (rxy * rxy * rxy));
            float tdil  = sqrt(max(0.4f, 1.0f - rs / max(rxy, rs + 1e-3f)));
            float wEff  = omega * tdil;
            float aNow  = wEff * cam.bhPoseTime;
            float aPrev = wEff * (cam.bhPoseTime - cam.bhPoseDt);
            float cN = cos(aNow),  sN = sin(aNow);
            float cP = cos(aPrev), sP = sin(aPrev);
            float2 p = in.posW.xy - c2,  q = in.prevW.xy - c2;
            in.posW.xy  = c2 + float2(p.x * cN - p.y * sN, p.x * sN + p.y * cN);
            in.prevW.xy = c2 + float2(q.x * cP - q.y * sP, q.x * sP + q.y * cP);
        }
    }
    // SECONDARY LENSED IMAGE (2026-06-13, Jamal: "secondary lensing, stick to
    // the science"). The point-mass lens has TWO solutions: the primary image
    // θ₊ (outside the Einstein ring, the current bend) and the SECONDARY θ₋
    // (opposite side, inside the ring) — the fold-over arc that makes Gargantua
    // read as ONE body. Instance 0 = primary, instance 1 = secondary. The
    // secondary is the same particle's light, drawn at θ₋ and dimmed by its real
    // relative magnification μ₋/μ₊ (→1 at the ring, →0 far out), so only
    // near-hole matter shows a fold. No second layer, no billboard — the same
    // particles, where curved spacetime puts their second image.
    bool isSecondary = (iid == 1u);
    float imageWeight = 1.0f;   // primary = full brightness
    bool  cullThis    = false;  // secondary culled where no 2nd image exists
    float R = cam.plateRadius;
    float mass = in.posW.w;

    // ── RENDER MEMBRANE (2026-07-16): matter inside the honest horizon emits
    // NOTHING — its light cannot escape. The membrane made it cold, but star
    // sprites carry baseline luminance beyond heat, so the swallowed pile
    // (400k+ stacked) still glowed through as "the all-eating black circle
    // of fuzziness" / "middle is just noise" (Jamal 00:24, 11:33). The hole
    // pass draws these same particles as the black body; the star pass now
    // draws them not at all. Light stays one-way.
    if (cam.horizonR > 0.0f && mass > 0.001f) {
        // distance from the HOLE CENTRE (off-origin after PLAY), not the origin
        if (length(in.posW.xyz - float3(cam.bhX, cam.bhY, cam.bhZ)) < cam.horizonR) {
            out.position = float4(0, 0, -2, 1);
            out.pointSize = 0.0f;
            out.color = float3(0);
            out.luminance = 0.0f;
            out.originDist = 0.0f;
            out.dist = 1.0f;
            out.velDir2D = float2(0);
            out.strDir2D = float2(0);
            out.sharpness = 5.0f;
            out.grainAlpha = 0.08f;
            return out;
        }
    }

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
        out.sharpness = 5.0f;
        out.grainAlpha = 0.08f;
        return out;
    }

    // Map normalized plate coords to world: scale all axes by R for isotropic 3D
    // RIGID-FRAME SPIN: rotate the sim position by the accumulated spin angle.
    // The whole shape rotates as one solid body here in the render; the physics
    // is spin-free, so nothing fights (no rest-scatter, no note-pinning). Cull
    // and colour use length() (rotation-invariant); the trail/Doppler velocity
    // uses spinPos so the rotation drives them.
    // GRAVITATIONAL TIME DILATION on the spin. A clock on a circular orbit at
    // radius r runs slow vs infinity by dτ/dt = √(1 − 1.5·r_s/r) (gravitational
    // + orbital-velocity dilation; → 0 at the photon sphere where v=c). So the
    // inner edge's clock is slow → it rotates LESS than the outer → the spinning
    // shape WINDS into a relativistic spiral, and the inner edge nearly FREEZES.
    // That's the black hole altering time, made visible — not just speed.
    // Gentle gravitational dilation (√(1−r_s/r), floor 0.4) — the OUTER disk
    // stays fast (the trails live there) and only the INNER edge lags, so it
    // winds subtly without freezing. (The 1.5·r_s/r circular-orbit form froze
    // the whole inner disk inside the photon sphere → "not moving fast enough".)
    float rDil  = length(in.posW.xyz);
    float tDilate = sqrt(max(0.4f, 1.0f - BH_R_IN_SIM / max(rDil, BH_R_IN_SIM + 1e-3f)));
    float3 spinPos = applySpin(in.posW.xyz, cam.spinAngleX * tDilate, cam.spinAngleY * tDilate, cam.spinAngleZ * tDilate);
    float3 worldPos = spinPos * R;

    // ── PHOTON-CAPTURE SHADOW (2026-07-15, Jamal: "it's a black circle with
    // fuzz, not a 3D body") — honest light transport, not an overlay: light
    // from a star BEHIND the hole whose straight-line path to the camera
    // passes within the photon-capture radius b < 2.6·r_s CANNOT reach us
    // (it spirals into the hole). Culling exactly those stars carves the
    // observable SHADOW — 2.6× the horizon, crisp-edged — out of the
    // BACKGROUND only. Stars IN FRONT keep shining and visibly cross the
    // black disc: the front/behind asymmetry is what reads as a 3D body.
    // Ortho camera → parallel rays along d = view direction through origin
    // (where comShift pins the hole).
    // DOUBLE-BOOKED PHOTONS FIX (2026-07-19): when the world-space lens is on,
    // it ALREADY transports every behind-the-hole ray — primary images are
    // floored at θ≥2.62·r_s, so the θ<2.6·r_s shadow carves itself, and the
    // small-β sources directly behind the hole become the bright arcs OVER the
    // shadow (max magnification). Straight-line-culling those same rays here
    // deleted exactly that arch light (the empty top, "resolving wrong").
    // The straight-line cull now only handles what the lens can't: the thin
    // slab at the hole's own depth (along ≤ r_s), or everything when the
    // lens is off.
    bool lensWillImage = (cam.bhToggles & 0x100u) &&
                         (cam.bhShadowNdcRadius > 1e-4f) &&
                         (smoothstep(0.2f, 0.9f, cam.bhStrength) > 0.001f);
    if (cam.horizonR > 0.0f && !isSecondary) {
        float3 camP = cam.cameraPos.xyz;
        float  camL = length(camP);
        if (camL > 1e-3f) {
            float3 d = -camP / camL;                    // view dir, camera → origin
            float  along = dot(worldPos, d);            // >0 = beyond the hole plane
            float3 perp  = worldPos - along * d;
            float  bCapt = 2.6f * cam.horizonR * R;     // capture radius, world units
            // SLAB CULL REMOVED (2026-07-19 17:58): the "hole-depth slab"
            // exception carved a straight-edged band across the shadow region
            // (Jamal: "it looks like a pokeball"). With the lens on, the lens
            // + membrane are the ONLY transport — no straight-line culls.
            if (along > 0.0f && length(perp) < bCapt && !lensWillImage) {
                out.position = float4(0, 0, -2, 1);     // captured: no light arrives
                out.pointSize = 0.0f;
                out.color = float3(0);
                out.luminance = 0.0f;
                out.originDist = 0.0f;
                out.dist = 1.0f;
                out.velDir2D = float2(0);
                out.strDir2D = float2(0);
                out.sharpness = 5.0f;
                out.grainAlpha = 0.08f;
                return out;
            }
        }
    }

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
    // STAR-MAP FLIP: at silence the rest state is a STAR MAP, not a black hole,
    // so there is NO lensing at rest (lensing was what bent every particle onto
    // the photon ring → the donut/hole). The bend now ONLY appears as matter
    // collapses on RELEASE — the hole forms with the BH, not before.
    // 0 during play (no distortion of the Chladni shape).
    // EMERGENT lensing (Step 3): light bending scales with how close the
    // central mass is to forming a hole — weak lensing as mass gathers,
    // full deflection as r_s(M_enc) approaches the enclosure radius. The
    // envelope phase no longer gates this: mass does.
    float lensRamp = smoothstep(0.2f, 0.9f, cam.bhStrength);
    bool lensActive = (cam.bhToggles & 0x100u) &&  // bit8: lens/shadow toggle
                      (cam.bhShadowNdcRadius > 1e-4f && lensRamp > 0.001f);
    // Pre-lens screen position — the streak block below needs it to keep
    // streaks = MOTION through the lens (see LENS-COHERENT STREAK).
    float2 preLensNDC = out.position.xy / max(out.position.w, 1e-4f);
    // No hole (no lens, or perspective) → the secondary image doesn't exist.
    if (isSecondary && !lensActive) cullThis = true;
    if (lensActive && cam.horizonR > 0.0f) {
        // ── WORLD-SPACE DEFLECTION MAP (2026-07-17) — the honest hole bends
        // for real. Thin-lens geometry with each particle's TRUE depth D
        // behind the hole and the exact α(b) LUT (log-divergent at the photon
        // sphere): back-of-disk light wraps OVER and UNDER the shadow, arcs
        // hug the photon ring — the Gargantua horseshoe the flat-NDC lens
        // could never produce. Ortho camera: transverse world lengths ≡
        // angles, lens plane through the origin.
        float rsW   = cam.horizonR * cam.plateRadius;      // r_s in world units
        float3 dHat = normalize(-cam.cameraPos.xyz);       // camera → hole
        float along = dot(worldPos, dHat);                 // + = behind the hole
        if (isSecondary && along <= rsW) cullThis = true;  // front: no 2nd image
        if (along > rsW) {
            float3 perp = worldPos - along * dHat;
            float beta  = length(perp);
            float D     = along;
            if (beta > 1e-4f * rsW) {
                float3 pHat = perp / beta;
                if (!isSecondary) {
                    // PRIMARY image: solve β = θ − α(θ)·D. Weak-field seed
                    // (α=2r_s/θ) then 3 Newton steps on the exact LUT.
                    float th = 0.5f * (beta + sqrt(beta * beta + 8.0f * rsW * D));
                    for (int it = 0; it < 3; ++it) {
                        float a  = lensAlphaSample(lensAlphaLUT, th / rsW);
                        float a2 = lensAlphaSample(lensAlphaLUT, th * 1.02f / rsW);
                        float da = (a2 - a) / (0.02f * th);
                        th -= (th - a * D - beta) / max(1.0f - da * D, 0.25f);
                        th  = max(th, 2.62f * rsW);
                    }
                    float thEff = mix(beta, th, cam.tuneLens * lensRamp);
                    out.position = cam.viewProjection *
                                   float4(along * dHat + pHat * thEff, 1.0f);
                    // PRIMARY MAGNIFICATION (2026-07-19): lensing conserves
                    // surface brightness — a stretched image is a BRIGHTER
                    // image, by the point-lens μ₊(u) = (u²+2)/(2u√(u²+4)) + ½
                    // with u = β/θ_E. This fills the evacuated Einstein zone
                    // with the smooth faint→blazing gradient of the real arcs
                    // instead of equal-brightness dots. Clamped ×6 (μ₊→∞ on
                    // axis); blended by the same tuneLens·lensRamp as the
                    // displacement so dialing the lens off is honest.
                    float thetaE = sqrt(2.0f * rsW * D);
                    float u   = beta / max(thetaE, 1e-5f * rsW);
                    float muP = (u * u + 2.0f) /
                                (2.0f * u * sqrt(u * u + 4.0f)) + 0.5f;
                    imageWeight = mix(1.0f, min(muP, 6.0f),
                                      cam.tuneLens * lensRamp);
                } else {
                    // SECONDARY image: opposite side, β = α(θ)·D − θ.
                    float th = 0.5f * (sqrt(beta * beta + 8.0f * rsW * D) - beta);
                    th = max(th, 2.62f * rsW);
                    for (int it = 0; it < 3; ++it) {
                        float a  = lensAlphaSample(lensAlphaLUT, th / rsW);
                        float a2 = lensAlphaSample(lensAlphaLUT, th * 1.02f / rsW);
                        float da = (a2 - a) / (0.02f * th);
                        th -= (a * D - th - beta) / min(da * D - 1.0f, -0.25f);
                        th  = max(th, 2.60f * rsW);
                    }
                    if (th <= 2.605f * rsW) {
                        cullThis = true;   // folded into the photon sphere
                    } else {
                        float3 target = along * dHat - pHat * th;
                        out.position = cam.viewProjection *
                                       float4(mix(worldPos, target, lensRamp), 1.0f);
                        // Honest relative magnification, real Einstein radius.
                        float thetaE = sqrt(2.0f * rsW * D);
                        float u = beta / max(thetaE, 1e-5f * rsW);
                        float A = (u * u + 2.0f) / (u * sqrt(u * u + 4.0f));
                        imageWeight = lensRamp * clamp((A - 1.0f) / (A + 1.0f), 0.0f, 1.0f);
                    }
                }
            } else {
                // on-axis (β≈0): the true image is a full Einstein ring a
                // sprite can't represent; an unlensed draw would leak a dot
                // INSIDE the shadow (the cull no longer removes it) — cull.
                cullThis = true;
            }
        }
    } else if (lensActive) {
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
            // DEPTH-AWARE LENSING (Phase D1, 2026-06-13 — Jamal's flaw #1: "the
            // BH is a 2D layer, not in the room"). Light is only gravitationally
            // bent if it passes BEHIND the hole. A particle in FRONT of the BH
            // (nearer the camera than the origin) is NOT lensed — it renders at
            // its true 3D position and OCCLUDES the shadow. So the hole sits
            // inside the scene with matter correctly in front of / behind it,
            // instead of the lens always painting a flat disc over everything.
            float3 viewDir = normalize(-cam.cameraPos.xyz);   // camera → origin/BH
            bool behindBH = dot(worldPos, viewDir) > 0.0f;    // farther than the BH
            if (isSecondary && !behindBH) cullThis = true;    // front matter casts no 2nd image
            if (beta > 1e-5f && behindBH) {
                float thetaE = cam.bhShadowNdcRadius;
                float disc   = sqrt(beta * beta + 4.0f * thetaE * thetaE);
                if (!isSecondary) {
                    // PRIMARY image θ₊ = ½(β+√(β²+4θ_E²)), outside the ring.
                    // Gentle blend keeps the disk's real 3D radius while pulling
                    // inner material toward the photon-ring brightening.
                    float thetaPlus = 0.5f * (beta + disc);
                    float theta = mix(beta, thetaPlus, cam.tuneLens * lensRamp);
                    float2 lensed = (d / beta) * theta;
                    lensed.x /= asp;
                    out.position.xy = (ndcBH + lensed) * out.position.w;
                } else {
                    // SECONDARY image θ₋ = ½(β−√(β²+4θ_E²)) < 0 → opposite side,
                    // inside the ring: the fold-over arc. Brightness = the real
                    // relative magnification μ₋/μ₊ (→1 at ring, →0 far), faded
                    // in by lensRamp — the honest faintness of the 2nd image.
                    float thetaMinus = 0.5f * (beta - disc);          // negative
                    float2 lensed = (d / beta) * (thetaMinus * lensRamp);
                    lensed.x /= asp;
                    out.position.xy = (ndcBH + lensed) * out.position.w;
                    float u = beta / max(thetaE, 1e-5f);
                    float A = (u * u + 2.0f) / (u * sqrt(u * u + 4.0f));
                    imageWeight = lensRamp * clamp((A - 1.0f) / (A + 1.0f), 0.0f, 1.0f);
                }
            } else if (isSecondary) {
                cullThis = true;   // front / degenerate: no second image
            }
        } else if (isSecondary) {
            cullThis = true;
        }
    }

    // out.position already set at line 102, modified by lensing block above.

    // ── Light-sample motion streak (ONE entity, no second trail layer) ──
    // A glowing particle moving fast IS a light streak — motion blur of a light
    // source. Stretch the sprite along its REAL velocity = Kerr orbital
    // (Ω(r)=1/(r^1.5+a), inner-fast) + body spin (ω×r). velW was ~0 at rest
    // (analytic orbit) → no streak; the analytic velocity fixes that, so the
    // resting disk swirls into streaks and spin stretches them further. Slow →
    // a dot, fast → a streak. Same sprite, same colour. Speeds only get high at
    // rest (inner orbit) and under arrow-spin — exactly where streaks belong.
    // REAL velocity (Jamal: "true physics at play, not a visual layer").
    // The old analytic Ω(r) ignored the SIMULATED motion entirely — matter
    // orbiting the horizon at a real 0.3c drew as calm balls while only the
    // decorative formula streaked. The streak is now the particle's actual
    // per-frame displacement (pos − prev, ×120 → sim/s), rotated with the
    // render spin: horizon orbits, chord slingshots and supernova node-jumps
    // ALL streak in proportion to their true speed — one law everywhere.
    float3 velReal = (in.posW.xyz - in.prevW.xyz) * 120.0f;
    // Teleports are not motion: recycle/respawn moves a star across the
    // field in one frame — streaking that jump painted random bright
    // dashes everywhere. Real speeds top out ~60 sim/s; beyond = a jump.
    if (length(velReal) > 60.0f) velReal = float3(0.0f);
    velReal = applySpin(velReal, cam.spinAngleX, cam.spinAngleY, cam.spinAngleZ);
    float3 vSpin = cross(float3(cam.spinX, cam.spinY, cam.spinZ), spinPos);
    float3 velWorld = (velReal + vSpin) * R;
    float4 endClip = cam.viewProjection *
        float4(worldPos + velWorld * STREAK_EXPOSURE * cam.tuneStreakLen, 1.0);
    float2 v1_screen = out.position.xy / out.position.w;
    float2 v2_screen = endClip.xy / endClip.w;
    // LENS-COHERENT STREAK (2026-07-19): v1 is the LENSED image position but
    // endClip is projected from the UNLENSED world point — near the ring the
    // "streak" was dominated by the lens displacement itself, drawing bright
    // scratches in arbitrary directions (the cheap look). Shift the end by
    // the same image displacement: first-order, both ends of a short streak
    // bend alike, so the streak is pure motion again. No-op when unlensed.
    v2_screen += (v1_screen - preLensNDC);
    out.velDir2D = (v2_screen - v1_screen) * STREAK_GAIN;

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
    float heatSizeBoost = 1.0f + clamp(temp, 0.0f, 1.0f) * 1.5f; // 1x → 2.5x (crisp points, pre-impostor)
    float distRatio = 800.0f / max(0.0001f, dist);
    float sizeScale = pow(distRatio, 0.65f) * 1.275f;
    // MASS drives size in EVERY phase (was rest-only): the render is the
    // readout of the physics — a star that has eaten stays visibly bigger
    // through play and release too. R ∝ M^0.8, screen size ∝ √R, normalized
    // so the IMF mean (0.3 M_sun) ≈ 1× (the old look for an average star).
    float Mphys = clamp(in.posW.w, 0.05f, 500.0f);
    float massSize = 0.5f + 0.8f * sqrt(pow(Mphys, 0.8f));
    float rawSize = cam.particleSize * heatSizeBoost * massSize * sizeScale;
    // Cap lowered 64 → 40: with sub-linear growth, hot particles at rho=25
    // hit ~40px naturally. A tighter cap keeps overdraw under control on
    // TBDR (each capped sprite is fewer tile-fragment ops).
    // ── FLUX-CONSERVING FAR-FIELD POINT SOURCES (2026-07-16, Jamal: the
    // far-view blending is "too bright" AND the fps killer — measured 60fps
    // zoomed-in vs 26 zoomed-out, pure fill cost). Physically a distant star
    // is a POINT: its image shrinks and its flux concentrates — it does NOT
    // smear into a soft multi-pixel disc. Cap sprite size by zoom
    // (distRatio<2 = farther than default) and pour the lost AREA into
    // luminance: same photons, sharper image, quadratically fewer blended
    // fragments. Near view (distRatio ≥ 2) unchanged.
    float zoomCap = clamp(75.0f * pow(distRatio * 0.5f, 1.3f), 2.5f, 150.0f);
    float drawn = clamp(rawSize, 1.0f, zoomCap);
    float fluxComp = 1.0f;
    if (rawSize > drawn) {
        float ratio = rawSize / drawn;
        fluxComp = min(ratio * ratio, 16.0f);   // area → brightness, capped
    }
    out.pointSize = drawn;

    // HDR luminance from thermal energy (ODS-03). Particles render at full
    // brightness in ALL phases — they ARE the visual, both at rest (fast
    // orbital spin → light trails → accretion disk) and on play (Chladni
    // shapes). No multiplex dimming; the raytracer only draws the dark
    // void, it does not replace the particles.
    // Brightness from temperature, but the temp driving BRIGHTNESS is capped so
    // the densest/hottest core can't blow out to white (the COLOUR still uses
    // the full temp, so it stays a saturated hot plasma instead of going white).
    // Per-particle luminance DROPPED (2026-06-25): at 1+temp·2 (≤6) the additive
    // blend summed dense regions far past white → the temperature COLOUR washed
    // out to white no matter the sliders. Lower per-particle brightness so the
    // colour survives the sum; bloom/HDR still carry the overall glow.
    // ×fluxComp (2026-07-16): flux conserved when the far-field point-source
    // cap shrinks the sprite (see the pointSize block) — same photons in
    // fewer pixels.
    out.luminance = (0.45f + min(max(0.0f, temp), 2.5f) * 0.7f) * fluxComp;

    // ── Relativistic Doppler factor from the analytic Kerr orbital velocity ──
    // δ = 1 + β_los, β_los = line-of-sight component of the prograde orbital
    // velocity (Ω(r)=1/(r^1.5+a), inner-fast/outer-slow). Drives BOTH the
    // beaming (intensity ∝ δ^~3 → the asymmetric Gargantua glow) AND the colour
    // frequency shift (a blackbody under a shift just rescales temperature → the
    // approaching side goes bluer/hotter, the receding side redder). Computed
    // analytically so it works at rest where velW≈0. From the DNGR paper, per
    // particle, no raytracer. Maximal edge-on, ~0 face-on (correct physics).
    float dopplerColor = 1.0f;
    {
        // PLANE FIX (2026-07-16, Jamal: stars FLIP white↔orange in cluster
        // pops, synced to the black circle's rotation): this block was built
        // for the POSED disk (orbits about Z, plane x–y). The emergent hole's
        // disk orbits about Y (plane x–z) — computing β_los from the x–y
        // projection put the "orbital tangent" 90° off, so the time-lapse
        // sweep oscillated vLos through the floor and flipped whole
        // same-radius arcs at once. Branch on the active disk axis.
        // PLANE FIX №2 (2026-07-19 18:14): the 07-16 branch put the EMERGENT
        // hole's tangent in x–z (about Y) — true then, wrong since the
        // plate-plane alignment moved the physical disk to x–y about Z (and
        // today's pose fix moved the emergent time-lapse with it). The 90°-off
        // tangent made vLos noise → azimuthally UNIFORM ring, no approaching-
        // limb glow ("the lens is not spinning as the black hole" / fake
        // overlay). Both disks orbit Z now — one plane, one prograde sense
        // (+z×r, the spawn sense), no branch.
        float rXY = length(spinPos.xy);
        if (rXY > 1e-3f) {
            float omega = 1.0f / (pow(rXY, 1.5f) + KERR_A);   // Kerr Ω(r)
            float3 tang = float3(-spinPos.y, spinPos.x, 0.0f) / rXY; // prograde about Z
            float3 vOrbit = tang * (omega * rXY);             // REAL orbital β
            // Doppler from the REAL orbital velocity ONLY — NOT the spin. The
            // spin is a time-lapse PLAYBACK rate (~150 rad/s); feeding it here
            // made 1+K·vLos explode to ~176 on one half and floor on the other
            // → the hard light/dark SEAM. vOrbit is taken at the SPUN position,
            // so the bright side still sweeps around smoothly as you spin —
            // bounded to the real ~0.6c asymmetry, a cosine gradient, no seam.
            float3 toCam = normalize(cam.cameraPos.xyz - worldPos);
            float vLos   = dot(vOrbit, toCam);                // + toward camera
            // Soft floors (0.25 / 0.35) so the receding side fades SMOOTHLY
            // instead of hard-clamping to black → no seam.
            dopplerColor = max(0.25f, 1.0f + DOPPLER_K_COLOR * vLos);
            float beam   = max(0.35f, 1.0f + DOPPLER_K_BEAM * vLos);
            out.luminance *= pow(beam, DOPPLER_EXP);
        }
    }

    // ── SECONDARY-IMAGE finalization ─────────────────────────────────────────
    // Apply the second image's real (faint) magnification to its brightness, and
    // CULL it where there's no second image (no hole) or it's demagnified to
    // nothing — so the secondary pass adds only the near-hole fold-over arcs and
    // costs no fragment work elsewhere. Streaks are zeroed (the mirror image's
    // screen-velocity isn't the particle's real motion → would smear wrong).
    if (isSecondary) {
        out.luminance *= imageWeight;
        out.velDir2D = float2(0.0f);
        out.strDir2D = float2(0.0f);
        if (cullThis || imageWeight < 0.02f) out.pointSize = 0.0f;
    }

    // Gravitational redshift T_obs = T·√(1 − r_h/r): inner edge reddens. Kept
    // MILD (blended mostly toward 1) — at full strength it halved the kelvin at
    // the inner edge and cancelled the Doppler BLUE exactly where it should be
    // bluest, so nothing but white/orange ever showed.
    float gravShift = mix(1.0f, sqrt(max(0.05f,
        1.0f - BH_R_IN_SIM / max(length(in.posW.xyz), BH_R_IN_SIM + 1e-3f))), 0.3f);

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
        // ── REAL blackbody temperature colour (M87* scale, Shakura–Sunyaev) ──
        // Display temperature in KELVIN = a real radial disk profile (orange
        // outer → white inner) PLUS shock/play heat (→ blue-white when hot).
        // Coloured by the physical Tanner-Helland blackbody function. This is
        // the orange→yellow→white→blue of real incandescent matter, not a ramp.
        // ── ONE UNIVERSAL LAW: colour = blackbody of TRUE TEMPERATURE, ALWAYS ──
        // (Jamal 2026-06-14: 100% physical, EVERY phase, not just play.) The
        // observed temperature [K] sums the real heat sources, rendered through
        // the continuous Tanner-Helland blackbody (deep red → orange → yellow →
        // white → blue — how incandescent matter actually looks). No ramps, no
        // per-phase palettes: ONE continuum everywhere.
        //   • diskK   — Shakura–Sunyaev radial disk profile (viscous heat)
        //   • heatK   — shock / collision / play thermal heat (currentTemp)
        //   • kinetic — T ∝ |v|² (equipartition): fast matter hot, still cold
        //   • × Doppler colour shift × gravitational redshift (real observed-T)
        float rSim   = length(in.posW.xyz);
        // REAL stellar temperature from the star's MASS (main-sequence Teff ≈
        // 5772·(M/M☉)^0.55 K) — the OBAFGKM range: M-dwarf ~0.3 M☉ ≈ 2900 K
        // (deep red), Sun 5772 K (white-yellow), O-star 50 M☉ ≈ 48000 K (blue).
        // Replaces the disk-temperature baseline that pinned everything to
        // orange/white (the "2D filter" — Jamal 2026-06-25). Shock/play heat
        // (heatK) and kinetic add ON TOP, so collisions/supernovae go blue-white.
        float diskK  = 5772.0f * pow(max(in.posW.w, 0.08f), 0.55f);
        float heatK  = clamp(temp, 0.0f, 5.0f) * cam.tuneHeatK;
        float ke     = dot(in.velW.xyz, in.velW.xyz);       // |v|² ∝ kinetic temperature
        // INTRINSIC temperature → colour (2026-06-26). Doppler/gravShift are
        // VIEW-DEPENDENT (line-of-sight); folding them into the colour made the
        // whole field a screen-space red/blue gradient that ROTATED with the
        // camera ("linear filter", not colour the particles own — Jamal). Colour
        // now comes from the particle's OWN state only: mass + play-heat +
        // kinetic. Doppler still drives BEAMING (out.luminance, above), not hue.
        float kelvin = clamp(diskK + heatK + ke * cam.tuneColorK, 1000.0f, 40000.0f);
        float thT    = clamp((kelvin - 1000.0f) / (40000.0f - 1000.0f), 0.0f, 1.0f);
        float3 thermalCol = blackbodyRGB(kelvin) * (0.7f + 0.9f * thT);

        // ── NASA SUPERNOVA TRUE COLOUR RESTORED (2026-06-25) ─────────────────
        // The play state is a SUPERNOVA — its colour is the discrete shock-
        // ionization EMISSION-LINE spectrum (Hα/[SII] red → [OIII] GREEN → Hβ
        // cyan → X-ray/synchrotron blue), NOT a blackbody continuum. That green
        // is the physical tell — a blackbody is never green. An earlier session
        // parked this ("green reads as arbitrary RGB") and forced blackbody-of-
        // mass everywhere, which collapsed PLAY to a flat orange↔white wash
        // (Jamal 2026-06-25: "we HAD the NASA data, true temp true colours").
        // Driven by the per-particle sim shock temperature, normalised to
        // SN_TEMP_PEAK. Cross-fade by envelope: SILENCE → thermal disk,
        // PLAYING → the NASA supernova spectrum.
        // PLAY/supernova colour driven by the FULL observed temperature thT
        // (2026-06-26, Jamal: "spectrum linked to our temps AND forces, like
        // NASA — not 4 colours that switch"). thT = normalised kelvin =
        // diskK(mass) + heatK(play heat) + ke·tuneColorK(KINETIC force), ×Doppler
        // ×gravShift — so heat, motion and the relativistic shift ALL move the
        // colour continuously up the emission-line ramp (Hα red → [OIII] green →
        // Hβ cyan → X-ray blue). Replaces bare temp/SN_TEMP_PEAK which clustered
        // everything at the red end. The Colour-Spectrum + Plasma-Heat sliders
        // now actually drive this (they were inert before).
        float3 snCol   = supernovaRamp(thT);
        float  playMix = smoothstep(0.5f, 1.5f, cam.envelopePhase);
        out.color = mix(thermalCol, snCol, playMix);

        // Speed-based warm boost REMOVED (2026-06-25): this added a warm
        // (0.3,0.2,0.1)·boost wash to every moving particle, clamped to 0.8 and
        // saturated almost instantly (speed*8). It is NOT slider-gated, so it
        // painted the whole PLAY field orange-white even with Colour Spectrum +
        // Plasma Heat all the way down (Jamal's "flat 2D filter"). It only ever
        // affected PLAY (at rest the star-map mix overwrites out.color; BH seeds
        // override). It was also a fake Doppler hack — the REAL relativistic
        // Doppler shift is already applied above via dopplerColor. Colour is now
        // blackbody-of-temperature ONLY during play.
    }

    // ── DEAD STARS (eaten by a merger): gone in EVERY phase ──────────────────
    // The merge kernel zeroes posW.w and parks the body outside the domain;
    // the render must never show it again. Zero size + fully transparent.
    if (in.posW.w <= 0.001f) {
        out.pointSize = 0.0f;
        out.color = float3(0.0f);
        out.luminance = 0.0f;
        out.position = float4(0.0f, 0.0f, -2.0f, 1.0f); // clipped (z < -w)
        return out;
    }

    // ── STAR MAP (open/rest state): each particle is a real STAR ─────────────
    // At rest, render the field as a star map. Each particle's stellar mass is
    // its REAL physics mass (posW.w — Kroupa-IMF at spawn, and it GROWS when
    // the star eats another in a merger: the render is the READOUT of the
    // physics). SIZE, BRIGHTNESS and COLOUR come from that mass (R∝M^0.8,
    // L∝M^3.5, T_eff(M) → blackbody). Most are tiny dim red dwarfs, a rare few
    // are blazing blue giants. Fades to the gas/supernova look as you play.
    float starMix = 1.0f - smoothstep(0.0f, 0.5f, cam.envelopePhase); // 1 at silence
    if (starMix > 0.001f) {
        float Mstar = min(in.posW.w, 500.0f);            // M_sun, merger-grown
        float Lstar = pow(Mstar, 3.5f);                             // L_sun
        float Rstar = pow(Mstar, 0.8f);                             // R_sun (size)
        // ── UNIFIED COLOUR LAW (Checkpoint A2, 2026-07-08, Jamal: "UNIFIED.
        // not phases.") — the SAME kelvin law the play path uses (line ~610):
        // mass-Teff baseline + collision/play heat × Plasma-Heat slider +
        // kinetic |v|² × Colour-Spectrum slider. One continuum for every
        // state; the sliders are live on the star map (they were play-only —
        // the star branch overrode colour with a slider-blind blackbody).
        // At rest the mass term dominates (OBAFGKM spread); hot merger
        // remnants shift blue-white through the same law, no phase gate.
        // HEAT TERM REMOVED (2026-07-10). `clamp(temp,0,5)*tuneHeatK` added a
        // flat pedestal to every star's Kelvin: at the rest temp the field
        // settles to (~1.5, see particles.metal:1700 targetTemp, and the T⁴
        // cooling at :2355 is ~0.0025/s there — it never cools back) that is
        // +4500 K on a 3000 K dwarf → white. The mass Teff spread, which IS
        // the OBAFGKM colour, was buried under it after the first note.
        // Lupton 2004 (PASP 116,133), the standard NASA/SDSS composite: an
        // object's COLOUR must not depend on its brightness — stretch the
        // intensity, never the hue. Heat belongs in luminance, not in Kelvin.
        float kelvinU = clamp(5772.0f * pow(Mstar, 0.55f)
                              + dot(in.velW.xyz, in.velW.xyz) * cam.tuneColorK,
                              1000.0f, 40000.0f);
        float3 starColor = blackbodyRGB(kelvinU);
        // ── SUB-PIXEL FLUX CONSERVATION = the depth cue ──────────────────────
        // The old clamp(…, 1.0, 40) gave every distant star a full-bright 1px
        // point → zoomed out, the field collapsed into a uniform noise carpet
        // with no sense of depth. Physics: a star whose projected size falls
        // below the sprite minimum keeps its total FLUX, not its surface
        // brightness — render at the minimum size, dimmed by the area ratio
        // (raw/min)². Distant dwarfs fade smoothly toward black, near giants
        // stay bold; the d-dependence rides the existing sizeScale zoom law.
        // ── PSF SIZE LAW (2026-07-07, Jamal: "the scale is so broken — sub-pixel
        // invisible, mergers become same-size squares forever"). A camera never
        // images a star's RADIUS — at any real distance every star is a point
        // source; the apparent size in a Hubble/JWST frame is its BRIGHTNESS
        // spread by the optics (PSF + diffraction). The old R∝M^0.8 law was so
        // flat that the dwarf bulk never left 1px and everything 50–400 M☉
        // pinned identical in the tanh ceiling (a seed tripling its mass didn't
        // change a pixel — "same size for the rest of their lifetime").
        // Apparent size now follows log-luminosity: L∝M^3.5 spans 9 decades, so
        // log2 turns EVERY mass doubling into a visible size step across the
        // whole ladder — a body that eats keeps visibly growing, forever.
        // R∝M^0.8 stays in the PHYSICS (contact/merge radii) — render-only.
        //
        // SATURATION ZERO-POINT (2026-07-07 second pass, Jamal: "vastly
        // oversized, doesn't read as a starmap at all"): in a real frame the
        // size is CONSTANT — the PSF width, ~1px — until the sensor
        // SATURATES; only past saturation does the halo bloom, ∝ log flux.
        // The first pass sized ALL stars by log L, so every 2 M☉ star
        // ballooned to ~9px and the field stopped being a starmap. Below
        // L_SAT brightness lives in INTENSITY (starLum), not size — dwarfs
        // dim red points, sun-types bright points, and only the genuinely
        // massive (≳4 M☉, the rare IMF tail) grow halos: 10 M☉ ~12px,
        // 100 M☉ ~40px, each further doubling still a visible step.
        // CALIBRATION 3rd pass (2026-07-07, "still fucked / goofy"): L_SAT=100
        // let the whole 4–5 M☉ IMF crowd (tens of thousands of stars in 2M)
        // grow halos, and the full slider·sizeScale slope (≈2.55px/step) made
        // each one 6–15px → a field of fat diamonds, not a starmap. Bar raised
        // to ~5 M☉ and slope halved: 10 M☉ ~4px, 100 M☉ ~19px, 400 M☉ ~27px,
        // 99.9% of the field stays a 1px point with brightness carrying mass.
        // ── TRUE-FLUX CAMERA MODEL (2026-07-08, Jamal: "THE SCIENCE IS OFF") ──
        // L∝M^3.5 spans ~9 decades; the old starLum log-compressed it to ~14×
        // (plus a 0.45 sub-pixel floor and the ×2.2 saturation hack above) —
        // 2M stars all within a decade of brightness = the uniform golden
        // carpet. A real cluster frame looks real BECAUSE of the violent
        // luminosity function: a handful of stars dominate, thousands sit
        // near-invisible, and the unresolved dwarf bulk is the soft background
        // glow. So luminance IS the relative flux in solar units — no
        // compression, no floors. The display transform is the honest camera:
        // Exposure iris (postfx) + tonemap + sensor bleach. Full-well cap 4096
        // keeps half-float additive accumulation finite (a >10 M☉ star is
        // bleached white + PSF-haloed anyway — nothing left to preserve).
        // The sub-pixel f² dimming is GONE for a physical reason too: a camera
        // never resolves a stellar radius — every star is a point source whose
        // ENTIRE flux lands in the PSF regardless of physical size.
        // EXPOSURE CALIBRATION (Checkpoint A3, 2026-07-08). True relative flux
        // (L∝M^3.5, no compression) but the DEFAULT exposure is the deliverable:
        // giants-at-peak hid the whole field (the dead "weird blob" launch).
        // Calibrated so at Exposure 1.0 the sun-type population reads as visible
        // points (lum 2.5 × grain 0.08 ≈ 0.2), the dwarf bulk is a faint
        // collective glow, and everything ≥~5 M☉ saturates → bleaches white.
        // Full well 1000 keeps half-float accumulation + bloom energy sane.
        float starLum = min(Lstar * 2.5f, 1000.0f);
        // SIZE = the approved law (Checkpoint A1): linear in the true stellar
        // radius R∝M^0.8, tanh soft ceiling so ordering survives at any slider
        // setting (bbbe6c8, Jamal: "looks amazing"). The saturation-PSF law
        // (99.9% of stars at exactly 1px) is out — his on-screen verdict:
        // "all stars weirdly the same size".
        float rawStar = cam.particleSize * Rstar * sizeScale * 0.5f;
        const float STAR_MIN_PX = 1.0f;
        float starSize = max(48.0f * tanh(rawStar * (1.0f / 48.0f)), STAR_MIN_PX);
        // ── MERGER FLASH — the "sense of collision" ──────────────────────────
        // A star that just ATE carries a temperature spike (merge kernel,
        // base 2.0 + violence) that the T⁴ cooling decays over seconds:
        // luminance surge, colour shifted hot, size pulse. Threshold 2.5
        // sits ABOVE the post-play residual heat (~1-2) — a played note must
        // not paint the whole field as novae; the rest look returns as the
        // field cools, only true fresh mergers flash.
        float flashT = clamp(temp - 2.5f, 0.0f, 5.0f);
        if (flashT > 0.01f) {
            // COLOUR SHIFT REMOVED (2026-06-26). This used to push a hot star to
            // blackbodyRGB(Teff + flashT·6000) → blue-white. At rest the engine's
            // continuous collision heating kept a fraction of stars above the 2.5
            // threshold AND this flash brightened them, so the blue-white flashers
            // DOMINATED the field and buried the real mass-blackbody dwarf colours
            // → "all white-blue" (Jamal 2026-06-26, found via the starMix/ramp
            // diagnostics). Colour now stays the star's mass-blackbody; collision
            // heat is a brightness flicker only, not a blue override.
            //
            // LUMINOUS RED NOVA (2026-07-07): a merger physically BALLOONS —
            // V838 Mon / V1309 Sco went ~1 → several hundred R☉ within days;
            // at our time-lapse that is a visible swell-and-fade, not a
            // flicker. The old ×(1+0.2·flashT) multiplier on a ~2px dot was
            // sub-perceptual — every merge read as silent deletion (Jamal
            // 2026-07-07: "stars just keep disappearing out of nowhere").
            // Size is now ADDITIVE pixels driven by the flash temp, which the
            // T⁴ cooling decays → the nova swells at the eat and shrinks back
            // over seconds. Colour stays the star's own mass-blackbody.
            // Nova size reined in (3rd pass): the merge cascade keeps ~20k
            // remnants simultaneously above the flash threshold (36 merges/
            // frame × ~10s of T⁴ decay) — at +12px each they consumed the
            // field. +4px/flashT still swells a 1px star to 5-9px at the eat.
            // True-flux units: +2 was calibrated against the compressed scale
            // (dwarf≈1.2) and would now be invisible. A luminous red nova
            // peaks 1e4–1e6 L☉; we book ~250 L☉ max deliberately UNDER-real
            // because the rest-state heating keeps ~20k remnants above the
            // flash threshold at once — at physical LRN flux they would fog
            // the field. Raise toward real once that regime is cleaned up.
            starLum += flashT * 20.0f; // nova peak ≈ 40 suns in calibrated units — clearly visible transient, far below giant full-well
            starSize = min(starSize + flashT * 4.0f, 150.0f);
        }
        out.pointSize = mix(out.pointSize, starSize, starMix);
        out.color     = mix(out.color, starColor, starMix);
        out.luminance = mix(out.luminance, starLum, starMix);
    }

    // ── BLACK HOLE SEEDS: accretion-luminous — VISIBLE accumulation ─────────
    // The hole's dark shadow is sub-pixel until ~10⁶ M_sun (r_s = M·2.33e-7
    // sim units); what you SEE of a feeding black hole is its ACCRETION
    // LIGHT — the brightest object there is (X-ray binaries, quasars). Render
    // size = the CAPTURE radius, which grows as M^(1/3) with every meal: the
    // object visibly fattens as it eats. Flares (fresh meals, temp spike)
    // surge it hotter, bluer and bigger; the raytracer shadow takes over once
    // the global geometric signal trips.
    // GATED TO REST (2026-06-26): only render the discrete bright accretion blob
    // at REST (starMix high). During PLAY the star SUPERNOVAS — it must STOP
    // being a discrete star and disperse into the ejecta GAS like everything
    // else (the Veil Nebula has NO stars inside the remnant — Jamal). So during
    // play this branch is skipped and the big star falls through to the play/gas
    // colour path. Render-only: the physics mass is untouched, so rest-state
    // accretion is unaffected.
    if ((cam.bhToggles & 0x80u) && in.posW.w >= 50.0f && starMix > 0.5f) {  // bit7: seed render
        float Mbh = in.posW.w;
        // VISIBLE ACCUMULATION (2026-06-22): render radius grows on the REAL
        // stellar relation R∝M^0.8 (the proof + the star branch + this file's
        // own comment), NOT the weak M^(1/3) capture radius that kept a 8859 M☉
        // seed a tiny dot. Cap raised 64→220 (heavy bodies are RARE → overdraw
        // is fine) so a body that eats VISIBLY fattens into a giant.
        float Req = pow(Mbh, 0.8f);                                    // R_sun, R∝M^0.8
        float flare = clamp(in.prevW.w - 2.5f, 0.0f, 5.0f);
        float sz = cam.particleSize * (0.5f + 0.8f * sqrt(Req)) * sizeScale;
        out.pointSize = clamp(sz * (1.0f + 0.25f * flare), 3.0f, 220.0f);
        out.color     = blackbodyRGB(20000.0f + 4000.0f * flare);
        out.luminance = 10.0f + 4.0f * flare;
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
    out.sharpness = cam.sharpness;
    // ── GAS KERNEL SPLATS (2026-07-19 23:44 — increment 2 render-half; Jamal:
    // "it should look full at 2 mio particles"). A particle is a SAMPLE of a
    // fluid: drawn as a sharp point it shows dots and voids; drawn as a soft
    // smoothing kernel (the SPLASH/Splotch standard) overlapping samples FUSE
    // into a continuous medium. In PLAY the diffuse population (the ~90%
    // dwarf stars, M≲2 — they ARE the gas) spreads ×3 with a soft falloff,
    // luminance ÷ spread² — flux conserved, same photons over more pixels.
    // Massive stars stay sharp points riding on top. Rest is untouched.
    {
        // REVERTED 2026-07-23 04:xx — the speed-gated (2026-07-22) and
        // density-gated (2026-07-23) gas triggers are removed: both failed
        // their own goals (settled ring stayed popcorn), and the density gate
        // fired on the paused packed shape — the whole field at ×3 splats =
        // fragment-overdraw suspect for the pause whiteout + 5 FPS. Back to
        // the committed PLAY-phase gate only. (cellCounts/su plumbing kept,
        // unused, for future volumetric work.)
        float gasNess = smoothstep(0.5f, 1.5f, cam.envelopePhase) *
                        (1.0f - smoothstep(1.5f, 3.0f,
                                           clamp(in.posW.w, 0.05f, 500.0f)));
        if (gasNess > 0.01f) {
            const float GAS_SPREAD = 3.0f;
            float spread = 1.0f + (GAS_SPREAD - 1.0f) * gasNess;
            out.pointSize = min(out.pointSize * spread, 150.0f);
            out.luminance /= (spread * spread);
            out.sharpness  = mix(cam.sharpness, 1.2f, gasNess); // soft kernel
        }
    }
    out.grainAlpha = cam.grainAlpha;

    // Cull the horizon SPHERE and the polar CYLINDER: any particle whose XY
    // radius is inside the horizon (drifted onto the spin axis) is unphysical
    // disk material and projects as a bright vertical SPIKE through the shadow
    // when zoomed in / edge-on. The disk lives at XY-radius ≥ 0.75, so this
    // only removes on-axis strays.
    float RS_CULL = 0.57f;
    float rXYcull = length(in.posW.xy);
    // STAR-MAP LIFECYCLE: the black hole exists ONLY on RELEASE (after the
    // supernova collapses). So the horizon cull only applies on the release
    // phase — at rest (star map) and during play there's no hole to cull.
    // Cull stars inside the horizon only when the hole actually EXISTS
    // (geometric criterion), not when a note is released.
    // CULL DISABLED with the billboard gone: this sphere+cylinder delete
    // punched the elliptical void that wobbled with the camera ("the weird
    // shadow upon rotation"). The hole's darkness now comes from the LENS
    // (light bends away from the centre) + the seed having eaten the
    // plunge zone — physics, not deletion.
    bool bhVisible = false;
    if (bhVisible && (originR < RS_CULL || rXYcull < RS_CULL)) {
        out.position = float4(0, 0, -2, 1);
        out.pointSize = 0.0f;
        out.color = float3(0.0f);
        out.luminance = 0.0f;
        out.originDist = 0.0f;
        out.dist = 1.0f;
        out.velDir2D = float2(0);
        out.strDir2D = float2(0);
        out.sharpness = 5.0f;
        out.grainAlpha = 0.08f;
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
    // Speed → long light-trails. Boosted so fast particles (the spinning disk)
    // streak dramatically — the same trail feel as whipping the camera in
    // perspective. Slow particles stay round dots; fast ones stretch long+thin.
    float elong  = clamp(speed * 1.4f, 0.0f, 1.0f);
    float widthY = mix(1.0f, 0.12f, elong);          // thinner across when fast
    float lengthX = mix(1.0f, 5.0f,  elong);          // much longer along

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
    // QUAD WINDOW (2026-07-07, Jamal: "2D cubes, no mass/depth"): the Gaussian
    // was truncated by the sprite rectangle (still ~0.13 at the edge) so every
    // big star rendered as a SQUARE. Force the profile to true zero before the
    // quad boundary — round core + soft halo, corners gone. Radial window so
    // streaks stay smooth too.
    float window = 1.0f - smoothstep(0.68f, 0.97f, length(pc));
    float glow = exp(-r2 * in.sharpness) * window;
    // Crisp bright CORE — restored from the pre-impostor render. This sharp
    // center is what makes each particle read as a crisp point instead of a
    // soft sprite-ball. Tinted by the particle color (not pure white) so dense
    // additive regions don't bleach out. Scales with Sharpness too.
    float dCore = sqrt(r2);
    float core = pow(max(0.0f, 1.0f - dCore), 3.0f);

    // ── DIFFRACTION SPIKES — make bright STARS read as stars, not dots ───────
    // A point source imaged through a telescope shows diffraction spikes (the
    // JWST/Hubble "this is a star" signature); a faint dot does not. We draw a
    // 4-point screen-axis cross whose strength scales with the star's brightness
    // (in.luminance) and is GATED to slow, non-streaking particles via
    // starness = 1 - elong — so the orbiting disk and supernova streaks (high
    // elong) stay clean and only the star-map points spike. Uses the raw quad
    // coord (pc), NOT the velocity-aligned frame, so spikes are screen-aligned.
    // The spike length = the sprite radius, so big bright stars spike long and
    // tiny dim dwarfs barely spike — physically consistent.
    float starness = 1.0f - elong;
    float spikeX = exp(-pc.y * pc.y * 90.0f) * pow(max(0.0f, 1.0f - abs(pc.x)), 1.5f);
    float spikeY = exp(-pc.x * pc.x * 90.0f) * pow(max(0.0f, 1.0f - abs(pc.y)), 1.5f);
    float spike  = max(spikeX, spikeY) * starness;

    // Emission multiplier reduced 1.8 → 0.5. With G=20 gravity, particles
    // orbit fast and the velocity-aligned streaks pile up under additive
    // blending → field saturated to white everywhere. Lower per-particle
    // emission lets dense regions glow bright but sparse stay dim, so the
    // BH void and disk structure remain visible against the field.
    float3 emission = in.color * in.luminance * (glow * 0.3f + core + spike * 0.6f);

    // Luminance boost DELETED from alpha (2026-07-08): alpha is COVERAGE,
    // emission carries the energy. The old `+ clamp(lum-1,0,2)·0.06` term
    // dominated grainAlpha for every star ≥1 M☉ — it's why the Grain fader
    // measurably did nothing (Jamal). Grain is now an honest iris again.
    float baseAlpha = in.grainAlpha;
    float alpha = (glow * 0.3f + core + spike * 0.6f) * baseAlpha;

    float fadeDistance = 6.0f;
    float fadeAmount = smoothstep(0.1f, fadeDistance, max(0.0001f, in.dist));

    return float4(emission * alpha * fadeAmount, alpha * fadeAmount);
}

// ─────────────────────────────────────────────────────────────────────────
// Orbital-arc light-trail pass (ISOLATED — drawn AFTER the points). Each
// particle draws its REAL orbital PATH as a fine multi-segment line: a clean
// long-exposure light streak that follows the Kerr orbit Ω(r)=1/(r^1.5+a),
// not a screen-space smear. Inner particles (fast Ω) draw longer arcs than the
// outer disk → the differential swirl of the Interstellar/Garganty disk. The
// arc is generated by rotating the current position BACKWARD around the spin
// axis (analytic, exact), so it traces where the particle came from.
// ─────────────────────────────────────────────────────────────────────────
constant int   TRAIL_SEG      = 12;    // points along each arc (SEG-1 segments)
constant float TRAIL_EXPOSURE = 0.45f; // arc length scale (SHORT — subtle streak,
                                       // not full loops that form inner rings)

struct TrajOut {
    float4 position [[position]];
    float3 color;
    float intensity;   // bright at the head (particle) → fades along the trail
};

vertex TrajOut trajectory_vertex(
    uint vid [[vertex_id]],
    device const Particle* particlesIn [[buffer(0)]],
    constant CameraUniforms& cam [[buffer(1)]])
{
    TrajOut out;
    // Line list: 2*(SEG-1) verts per particle. Decode particle + arc point.
    uint vpp   = (uint)(2 * (TRAIL_SEG - 1));
    uint pid   = vid / vpp;
    uint local = vid - pid * vpp;
    uint k     = (local >> 1) + (local & 1u);   // point index 0..SEG-1
    Particle in = particlesIn[pid];
    float R     = cam.plateRadius;
    float mass  = in.posW.w;
    float originR = length(in.posW.xyz);

    // Same masks as the points — never trail out of a wall particle (mass 0)
    // or anything culled inside the event horizon.
    if (mass < 0.001f || originR < 0.57f) {
        out.position  = float4(0, 0, -2, 1);
        out.color     = float3(0);
        out.intensity = 0.0f;
        return out;
    }

    // Backward orbital rotation: total arc = Ω(r)·exposure (inner-fast/outer-
    // slow → differential streaks). Prograde orbit is +Z; the trail goes back
    // (−Z). Spin lengthens the exposure so spinning draws longer ribbons.
    // Orbit plane is about +Y (the star-map/disk convention) — this pass
    // predates it and swept XY/Z-axis arcs: trails cut ACROSS the real
    // motion and swirled off-centre ("distorted like wrongly").
    float rXY   = max(length(in.posW.xz), 1e-3f);
    // Differential compressed (1.5 → 0.9): inner still leads (Kepler order
    // preserved — gravity must read), but the inner/outer ratio no longer
    // tears the disk into two populations ("not fusing into one form").
    float omega = 1.0f / (pow(rXY, 0.9f) + KERR_A);
    float spinMag = length(float3(cam.spinX, cam.spinY, cam.spinZ));
    // HORIZON EXPOSURE — spacetime made visible by the hole itself. The arc
    // is the particle's real orbital path over the exposure window; near the
    // horizon Ω explodes (inner-fast differential law above), so matter
    // there stretches into the light-trail ribbons Jamal gets from fast
    // manual spin — but earned by the physics, on whenever the hole exists.
    // Far from the hole the exposure dies off: the calm field stays points.
    float horizonExp = cam.bhStrength * exp(-rXY * 0.8f);
    float exposure = TRAIL_EXPOSURE *
                     (1.0f + 4.0f * cam.oscAmount + cam.tuneArcGain * horizonExp);
    // Wrap clamp: differential rotation is the physics (inner MUST be
    // faster), but unbounded wrap made the inner arcs lap into a closed
    // ring while the outer barely dashed — two objects instead of one
    // fused disk. Cap the sweep; speed still reads via arc length below.
    // Wrap ≤ 2.2 rad: longer arcs closed into per-particle CIRCLES — the
    // hole read as concentric rings instead of flowing matter.
    float totalPhi = min(omega * exposure + spinMag * 0.05f, cam.tuneArcWrap);
    // At rest (no spin) keep the ribbons local to the hole: beyond its
    // sphere of influence emit nothing — cheap degenerate output.
    if (spinMag < 0.01f && cam.oscAmount < 0.01f && rXY > 8.0f) {
        out.position  = float4(0, 0, -2, 1);
        out.color     = float3(0);
        out.intensity = 0.0f;
        return out;
    }
    float ang = -totalPhi * ((float)k / float(TRAIL_SEG - 1)); // 0 at head

    float c = cos(ang), s = sin(ang);
    float3 pos = in.posW.xyz;
    // Rotate about +Y — the arc traces the particle's actual orbit.
    float3 rot = float3(pos.x * c + pos.z * s, pos.y, -pos.x * s + pos.z * c);
    out.position = cam.viewProjection * float4(rot * R, 1.0);

    // Blackbody colour from temperature — matches the disk palette.
    float temp  = in.prevW.w;
    float tNorm = clamp(temp / 5.0f, 0.0f, 1.0f);
    float3 bb;
    if (tNorm < 0.25f)      bb = mix(float3(0.6,0.15,0.02), float3(1.0,0.4,0.05),  tNorm*4.0f);
    else if (tNorm < 0.5f)  bb = mix(float3(1.0,0.4,0.05),  float3(1.0,0.75,0.4), (tNorm-0.25f)*4.0f);
    else if (tNorm < 0.75f) bb = mix(float3(1.0,0.75,0.4),  float3(1.0,0.95,0.9), (tNorm-0.5f)*4.0f);
    else                    bb = mix(float3(1.0,0.95,0.9),  float3(0.8,0.85,1.0), (tNorm-0.75f)*4.0f);
    out.color     = bb;
    // Fade along the trail: bright at the particle, fading down the arc.
    // Inner fade keeps the additive sum from blowing the centre to white.
    float innerFade = smoothstep(0.57f, 1.2f, rXY);
    // EXPOSURE-NORMALIZED brightness: a longer exposure spreads the SAME
    // light over a longer arc — per-segment intensity falls as the arc
    // grows. Fast spin lengthens trails, it must not blow them to white.
    float expNorm = 1.5f / (1.5f + totalPhi);
    out.intensity = (1.0f - (float)k / float(TRAIL_SEG - 1)) *
                    mix(0.25f, 1.0f, innerFade) * expNorm * cam.tuneTrailGain;
    return out;
}

fragment float4 trajectory_fragment(TrajOut in [[stage_in]])
{
    // Additive light-streak. LOW per-line gain so many overlapping arcs SUM
    // into a smooth gradient curtain instead of blowing to white (the max-
    // channel tonemap then preserves the hue).
    float a = in.intensity;
    float3 emission = in.color * a * 0.18f;
    return float4(emission, a * 0.12f);
}

// ── THE HOLE PASS (2026-07-15) — the honest event horizon made VISIBLE ───────
// The particles INSIDE the honest geometric r_h ARE the black hole (bh core
// directive: never a shader ball or overlay). The additive star pass renders
// them as a white blob (Jamal 2026-07-15: "white blob eating all the stars");
// physically their light cannot escape. This pass re-draws EXACTLY those
// particles as soft BLACK OCCLUDING splats (blend: dst *= 1−α, encoded after
// the additive pass): hundreds of thousands of them stack into the solid
// shadow, while the additive rim OUTSIDE r_h stays bright → black core with a
// glowing edge. Same spin/dilation/projection path as particle_vertex so each
// splat lands on the same pixels as its star image.
struct HoleVertexOut {
    float4 position [[position]];
    float  pointSize [[point_size]];
};

vertex HoleVertexOut hole_vertex(
    uint vid [[vertex_id]],
    device const Particle* particlesIn [[buffer(0)]],
    constant CameraUniforms& cam [[buffer(1)]])
{
    HoleVertexOut out;
    Particle in = particlesIn[vid];
    float r = length(in.posW.xyz - float3(cam.bhX, cam.bhY, cam.bhZ)); // from HOLE centre (off-origin after PLAY)
    // Only real matter inside the horizon; walls and everything outside cull.
    if (cam.horizonR <= 0.0f || in.posW.w < 0.001f || r >= cam.horizonR) {
        out.position = float4(0, 0, -2, 1);
        out.pointSize = 0.0f;
        return out;
    }
    // OVERDRAW CAP (2026-07-17): the silhouette is painted entirely by the
    // rim shell (r > 0.7·r_h) — splats are ≥2px and the pile is dense, so
    // deep-inside splats only re-fill already-black pixels. As the hole eats
    // the field, the deep pile grows toward 2M and measured Render+PostFX
    // 6→40ms (relaunch_1230.log) with nothing visible. Keep every rim splat,
    // draw 1-in-16 of the deep pile (still particles, still the hole).
    if (r < 0.7f * cam.horizonR && ((vid * 2654435761u) >> 4 & 0xFu) != 0u) {
        out.position = float4(0, 0, -2, 1);
        out.pointSize = 0.0f;
        return out;
    }
    // DILATION SYNC (2026-07-17, review finding #2): must match the star
    // pass's live profile EXACTLY (rsDil = honest r_h, floor 0.02) or the
    // black occluders slide off their star images near the rim — the fuzz.
    float rsDil = (cam.horizonR > 0.0f) ? cam.horizonR : 1.0f;
    float tDilate = sqrt(max(0.02f, 1.0f - rsDil / max(r, rsDil + 1e-3f)));
    float3 spinPos = applySpin(in.posW.xyz, cam.spinAngleX * tDilate, cam.spinAngleY * tDilate, cam.spinAngleZ * tDilate);
    float3 worldPos = spinPos * cam.plateRadius;
    out.position = cam.viewProjection * float4(worldPos, 1.0);
    float dist = max(0.0001f, length(worldPos - cam.cameraPos.xyz));
    // Star pass's distance scaling; FLAT mass term — the shadow is geometry,
    // not luminosity. ~1.5× a mean star so the splats tile into a solid disc.
    float sizeScale = pow(800.0f / dist, 0.65f) * 1.275f;
    out.pointSize = clamp(cam.particleSize * 1.5f * sizeScale, 2.0f, 150.0f);
    return out;
}

fragment float4 hole_fragment(HoleVertexOut in [[stage_in]],
                              float2 pc [[point_coord]])
{
    float d = length(pc * 2.0f - 1.0f);
    // Hard-edged, near-opaque: the aggregate silhouette must be CRISP (the
    // soft 0.55 ramp stacked into the "fuzz" — Jamal 2026-07-15); the real
    // shadow boundary is a sharp light-transport edge.
    float a = smoothstep(1.0f, 0.85f, d);
    return float4(0.0f, 0.0f, 0.0f, a);
}
