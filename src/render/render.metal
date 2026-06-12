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
};

// Rigid-body spin: rotate a sim-space position by the accumulated spin angle
// (around Y then X). The whole shape rotates as one solid body in the render —
// physics stays spin-free, so there's no force-fighting (no rest-scatter, no
// note-pinning). Rotation preserves length, so the horizon/colour radius is
// unchanged.
static float3 applySpin(float3 p, float ax, float ay) {
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
constant float PEAK_KELVIN   = 25000.0f;  // temperature that maps to the ramp's
                                          // peak (white/blue). High → white rare.
constant float SN_TEMP_PEAK  = 6.0f;      // sim temp → supernova ramp peak. From
                                          // the logged data: NOTE~0.85 (red),
                                          // CHORD~3.4 (green [OIII]), spin spikes
                                          // (blue-white X-ray).

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
    float3 spinPos = applySpin(in.posW.xyz, cam.spinAngleX * tDilate, cam.spinAngleY * tDilate);
    float3 worldPos = spinPos * R;

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
    if (cam.bhShadowNdcRadius > 1e-4f && lensRamp > 0.001f) {
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
                float theta = mix(beta, thetaFull, 0.4f * lensRamp);
                float2 lensed = (d / beta) * theta; // image offset, isotropic
                lensed.x /= asp;                    // back to raw NDC
                float2 lensedP = ndcBH + lensed;
                out.position.xy = lensedP * out.position.w;
            }
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
    float rXYv   = max(length(spinPos.xy), 1e-3f);
    float omegaV = 1.0f / (pow(rXYv, 1.5f) + KERR_A);
    float3 vOrb  = float3(-spinPos.y, spinPos.x, 0.0f) / rXYv * (omegaV * rXYv);
    float3 vSpin = cross(float3(cam.spinX, cam.spinY, 0.0f), spinPos);
    float3 velWorld = (vOrb + vSpin) * R;
    float4 endClip = cam.viewProjection * float4(worldPos + velWorld * STREAK_EXPOSURE, 1.0);
    float2 v1_screen = out.position.xy / out.position.w;
    float2 v2_screen = endClip.xy / endClip.w;
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
    out.pointSize = clamp(rawSize, 1.0f, 40.0f);

    // HDR luminance from thermal energy (ODS-03). Particles render at full
    // brightness in ALL phases — they ARE the visual, both at rest (fast
    // orbital spin → light trails → accretion disk) and on play (Chladni
    // shapes). No multiplex dimming; the raytracer only draws the dark
    // void, it does not replace the particles.
    // Brightness from temperature, but the temp driving BRIGHTNESS is capped so
    // the densest/hottest core can't blow out to white (the COLOUR still uses
    // the full temp, so it stays a saturated hot plasma instead of going white).
    out.luminance = 1.0f + min(max(0.0f, temp), 2.5f) * 2.0f;

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
        float rXY = length(spinPos.xy);
        if (rXY > 1e-3f) {
            float omega = 1.0f / (pow(rXY, 1.5f) + KERR_A);   // Kerr Ω(r)
            float3 tang = float3(-spinPos.y, spinPos.x, 0.0f) / rXY; // prograde
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
        float rSim    = length(in.posW.xyz);
        float diskK   = ssDiskTempShape(rSim, BH_R_IN_SIM) * DISK_T_STAR_K;
        float heatK   = clamp(temp, 0.0f, 5.0f) * HEAT_K_PER_T;
        // Frequency-shift colour: Doppler (approaching→bluer/hotter, receding→
        // redder) × gravitational redshift (inner edge redder). Exact for a
        // blackbody — the observed temperature just rescales by the shift.
        float kelvin  = max(1000.0f, (diskK + heatK) * dopplerColor * gravShift);
        // THERMAL black-hole disk (rest): the AUTHENTIC Interstellar/DNGR
        // palette (Thorne et al.) — dark-red → orange → warm-gold-white, white
        // only at pow(t,2) so it stays rare and WARM (no blue; Gargantua's disk
        // is warm — blue lives in the supernova). colWhite is HDR for the glow.
        float thT = clamp((kelvin - 1000.0f) / (PEAK_KELVIN - 1000.0f), 0.0f, 1.0f);
        // TRUE BLACKBODY CONTINUUM (Jamal 2026-06-11): the movie-amber 3-stop
        // ramp quantized everything into "3 colors that switch". kelvin above
        // is already the physical display temperature — render it through the
        // same Tanner-Helland blackbody the star map uses: dark red → orange →
        // yellow-white → BLUE, continuous, how heat actually looks. HDR
        // headroom scales with thT so the hottest matter still blooms.
        float3 thermalCol = blackbodyRGB(kelvin) * (0.7f + 0.9f * thT);
        // PLAYED state: TEMPERATURE owns the colour here too (Jamal: no RGB,
        // plasma colours in ALL phases). The heat continuum — deep red →
        // orange → yellow → white-hot → blue extreme, white rare — replaces
        // the supernova emission-line ramp (its green/cyan lines read as
        // arbitrary RGB; physical, but parked until the SN event rung).
        float3 snCol = heatRamp(temp / SN_TEMP_PEAK);
        // Cross-fade by envelope: SILENCE → thermal disk, PLAYING → supernova.
        float playMix = smoothstep(0.5f, 1.5f, cam.envelopePhase);
        float3 bbColor = mix(thermalCol, snCol, playMix);

        // Per-band RGB tint REMOVED (Jamal 2026-06-11): it painted the field
        // in primary red/green/blue per voice — the "ocean of RGB" — and
        // fought the physical blackbody continuum. Temperature is the only
        // colour authority now. (bandId still tracked for future use.)
        out.color = bbColor;

        // Speed-based brightness boost (Doppler-like)
        float speed = length(in.velW.xyz);
        float boost = clamp(speed * 8.0f, 0.0f, 0.8f);
        out.color += float3(boost * 0.3f, boost * 0.2f, boost * 0.1f);
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
        float Teff  = 5772.0f * pow(Mstar, 0.55f);                   // K (main-seq)
        float Lstar = pow(Mstar, 3.5f);                             // L_sun
        float Rstar = pow(Mstar, 0.8f);                             // R_sun (size)
        float3 starColor = blackbodyRGB(Teff);
        // ── SUB-PIXEL FLUX CONSERVATION = the depth cue ──────────────────────
        // The old clamp(…, 1.0, 40) gave every distant star a full-bright 1px
        // point → zoomed out, the field collapsed into a uniform noise carpet
        // with no sense of depth. Physics: a star whose projected size falls
        // below the sprite minimum keeps its total FLUX, not its surface
        // brightness — render at the minimum size, dimmed by the area ratio
        // (raw/min)². Distant dwarfs fade smoothly toward black, near giants
        // stay bold; the d-dependence rides the existing sizeScale zoom law.
        float rawStar = cam.particleSize * (0.5f + 0.8f * sqrt(Rstar)) * sizeScale;
        const float STAR_MIN_PX = 2.0f;   // ≥2px so the falloff can antialias
        float starSize = clamp(rawStar, STAR_MIN_PX, 40.0f);
        float starLum  = 0.6f + 2.5f * log2(1.0f + Lstar);          // compress huge L range
        if (rawStar < STAR_MIN_PX) {
            float f = rawStar / STAR_MIN_PX;
            starLum *= f * f;             // flux conserved: smaller → dimmer
        }
        // ── MERGER FLASH — the "sense of collision" ──────────────────────────
        // A star that just ATE carries a temperature spike (merge kernel,
        // base 2.0 + violence) that the T⁴ cooling decays over seconds:
        // luminance surge, colour shifted hot, size pulse. Threshold 2.5
        // sits ABOVE the post-play residual heat (~1-2) — a played note must
        // not paint the whole field as novae; the rest look returns as the
        // field cools, only true fresh mergers flash.
        float flashT = clamp(temp - 2.5f, 0.0f, 5.0f);
        if (flashT > 0.01f) {
            starLum += flashT * 3.0f;
            starColor = mix(starColor, blackbodyRGB(Teff + flashT * 6000.0f),
                            clamp(flashT * 0.5f, 0.0f, 1.0f));
            starSize = min(starSize * (1.0f + 0.3f * flashT), 40.0f);
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
    // the global geometric signal trips. Overrides every phase.
    if (in.posW.w >= 50.0f) {
        float Mbh = in.posW.w;
        float capR = 0.0313f * pow(Mbh * (1.0f / 0.3f), 1.0f / 3.0f); // sim units
        float Req = capR / 0.0549f;                                    // in R_sun
        float flare = clamp(in.prevW.w - 2.5f, 0.0f, 5.0f);
        float sz = cam.particleSize * (0.5f + 0.8f * sqrt(Req)) * sizeScale;
        out.pointSize = clamp(sz * (1.0f + 0.25f * flare), 3.0f, 64.0f);
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
    bool bhVisible = cam.bhStrength > 0.9f;
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
    float glow = exp(-r2 * in.sharpness);
    // Crisp bright CORE — restored from the pre-impostor render. This sharp
    // center is what makes each particle read as a crisp point instead of a
    // soft sprite-ball. Tinted by the particle color (not pure white) so dense
    // additive regions don't bleach out. Scales with Sharpness too.
    float dCore = sqrt(r2);
    float core = pow(max(0.0f, 1.0f - dCore), 3.0f);

    // Emission multiplier reduced 1.8 → 0.5. With G=20 gravity, particles
    // orbit fast and the velocity-aligned streaks pile up under additive
    // blending → field saturated to white everywhere. Lower per-particle
    // emission lets dense regions glow bright but sparse stay dim, so the
    // BH void and disk structure remain visible against the field.
    float3 emission = in.color * in.luminance * (glow * 0.5f + core);

    float baseAlpha = in.grainAlpha + clamp(in.luminance - 1.0f, 0.0f, 2.0f) * 0.06f;
    float alpha = (glow * 0.5f + core) * baseAlpha;

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
    float omega = 1.0f / (pow(rXY, 1.5f) + KERR_A);
    float spinMag = length(float2(cam.spinX, cam.spinY));
    // HORIZON EXPOSURE — spacetime made visible by the hole itself. The arc
    // is the particle's real orbital path over the exposure window; near the
    // horizon Ω explodes (inner-fast differential law above), so matter
    // there stretches into the light-trail ribbons Jamal gets from fast
    // manual spin — but earned by the physics, on whenever the hole exists.
    // Far from the hole the exposure dies off: the calm field stays points.
    float horizonExp = cam.bhStrength * exp(-rXY * 0.8f);
    float exposure = TRAIL_EXPOSURE *
                     (1.0f + 4.0f * cam.oscAmount + 8.0f * horizonExp);
    // Wrap clamp: differential rotation is the physics (inner MUST be
    // faster), but unbounded wrap made the inner arcs lap into a closed
    // ring while the outer barely dashed — two objects instead of one
    // fused disk. Cap the sweep; speed still reads via arc length below.
    float totalPhi = min(omega * exposure + spinMag * 0.05f, 4.0f);
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
    out.intensity = (1.0f - (float)k / float(TRAIL_SEG - 1)) *
                    mix(0.25f, 1.0f, innerFade);
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
