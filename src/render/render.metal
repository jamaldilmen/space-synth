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
    float spinZ;             // roll rate around Z (rad/s)
    float viewportH;         // framebuffer height in px — NDC->px for the streak arc (appended 2026-07-24, keep LAST)
    float spinAngleZ;        // accumulated roll angle Z (rad) — mirror order = renderer.h
    // ── STAR LAW DIALS (2026-07-28) — mirror order = renderer.h. Defaults
    // reproduce the previous hardcoded constants exactly.
    float tuneStarLumExp;    // L = M^this          (was 3.5)
    float tuneStarLumGain;   // starLum = L * this  (was 2.5)
    float tuneStarLumCeil;   // min(starLum, this)  (was 1000)
    float tuneStarKelvinA;   // K = this * M^p      (was 5772)
    float tuneStarKelvinP;   // K = A * M^this      (was 0.55)
    float tuneStarSizeGain;  // rawStar *= this     (new, identity at 1.0)
    float tuneStarSizeExp;   // Rstar = M^this      (was 0.8)
    float tuneStarSizeFloor; // STAR_MIN_PX         (was 1.0)
    float tuneStarSizeCeil;  // tanh soft ceiling   (was 48.0)
    // ── VIEW AXIS (F5, 2026-08-10) — APPENDED, mirror order = renderer.h ──
    // World-space UNIT forward (eye → target). Replaces the two inline
    // normalize(-cam.cameraPos.xyz) derivations below, which silently assumed
    // the camera looks at the origin. Three scalars (not float3) so there is no
    // 16-byte alignment padding to hand-mirror.
    float viewForwardX;
    float viewForwardY;
    float viewForwardZ;
    // RAW horizon r_h for the capture cull ONLY (2026-08-11) — APPENDED.
    // horizonR above is the EASED value and drives every drawn RADIUS; it lags
    // 6× behind at formation (measured raw=0.0781 vs smooth=0.0130), which left
    // stars inside the real horizon still drawn. Cull on truth, draw on eased.
    // Derivation of both lives in src/render/renderer.h.
    float horizonRRaw;
    // 16-byte tail padding — MSL rounds struct size up to 16 while the C++ half
    // (float[16] instead of float4x4) does not. Keep this struct a multiple of
    // 16 so ONE sizeof number is true on both sides. See renderer.h.
    float fieldHalfDepth;   // field half-extent along view, sim units (was horizonRPad0)
    float sizeResScale;      // drawableHeight/2260 — S2, resolution-normalised star size (was tuneTrailWidth)
    float horizonRPad2;
};

// ── LAYOUT GUARD (F5 / board A0h′, 2026-08-10) ──────────────────────────────
// Mirror of the guard in src/render/renderer.h — SAME NUMBERS, on purpose. This
// half is what makes the pair actually binding: a C++-only assert would catch
// "appended and forgot to update the number" but NOT "updated the number and
// forgot this file", which is the failure we care about.
//
// NOTE: plain `offsetof` DOES NOT EXIST IN MSL (no <cstddef>) — it fails with
// "use of undeclared identifier". Use __builtin_offsetof, which works and does
// fire. Both verified by compiling the passing AND failing cases, 2026-08-10.
// The same builtin is used on the C++ side via offsetof so the two blocks stay
// readable side by side. Do not "fix" this back to offsetof.
//
// APPEND-ONLY: new fields at the END of BOTH structs, never inserted.
static_assert(sizeof(CameraUniforms) == 288,
              "CameraUniforms layout — update src/render/renderer.h AND its static_asserts");
static_assert(__builtin_offsetof(CameraUniforms, bhShadowNdcRadius) == 108,
              "CameraUniforms anchor bhShadowNdcRadius — layout drift vs renderer.h");
static_assert(__builtin_offsetof(CameraUniforms, bhX) == 200,
              "CameraUniforms anchor bhX — layout drift vs renderer.h");
static_assert(__builtin_offsetof(CameraUniforms, viewForwardZ) == 268,
              "CameraUniforms anchor viewForwardZ — layout drift vs renderer.h");
static_assert(__builtin_offsetof(CameraUniforms, horizonRRaw) == 272,
              "CameraUniforms tail anchor — layout drift vs renderer.h");

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

// Exact inverse of applySpin (transpose of each rotation, undone in reverse
// order Rx→Ry→Rz). The ray-march works in spun-world coords; the hash grid is
// indexed in physics coords — this maps a world sample point back to physics
// so the metric ray can read the REAL deposited particle field (2026-07-25).
static float3 applyInverseSpin(float3 p, float ax, float ay, float az) {
    float cx = cos(ax), sx = sin(ax);
    float3 r = float3(p.x, p.y * cx + p.z * sx, -p.y * sx + p.z * cx);
    float cy = cos(ay), sy = sin(ay);
    r = float3(r.x * cy - r.z * sy, r.y, r.x * sy + r.z * cy);
    float cz = cos(az), sz = sin(az);
    return float3(r.x * cz + r.y * sz, -r.x * sz + r.y * cz, r.z);
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
    float streakLen;   // arc length in QUAD-HALF units (1 = round dot). Flux-conserving.
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

// Inverse of hsv2rgb, added 2026-08-24 for the phase tint: to shift a HUE we
// first have to know the base colour's hue, saturation and value. Mixing in RGB
// instead — which is what the first version of the tint did — DESATURATES
// whenever the two hues are opposed: measured 24.8% of lit pixels washed to
// white/grey at amount 0.35. A rotation on the hue circle has no such failure.
static float3 rgb2hsv(float3 c) {
    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    float d  = mx - mn;
    float h  = 0.0f;
    if (d > 1e-6f) {
        if (mx == c.r)      h = (c.g - c.b) / d + (c.g < c.b ? 6.0f : 0.0f);
        else if (mx == c.g) h = (c.b - c.r) / d + 2.0f;
        else                h = (c.r - c.g) / d + 4.0f;
        h *= (1.0f / 6.0f);
    }
    return float3(h, mx <= 1e-6f ? 0.0f : d / mx, mx);
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
// DOPPLER_K_COLOR DELETED 2026-08-11 12:31:44 (C7b) — its only consumer was
// `dopplerColor`, which was assigned and never read. See the note at the
// Doppler block in particle_vertex. Beaming (DOPPLER_K_BEAM) is the surviving
// line-of-sight term and is unchanged.
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
// ⚠ THIS SCHEDULE IS MIRRORED IN renderer.mm's TABLE BUILD. Change both or
// neither — they are one encoding, and a mismatch is silent (wrong angles, no
// error). Log-spaced in (b − b_c) since 2026-08-22 so the DIVERGENCE at the
// photon ring is resolved; the old log-in-b schedule put the entire band
// 2.600–2.645 in ONE interval (23.6% error) and saturated everything below
// 2.60 to a constant. See the measurement table in renderer.mm.
constant float kLensBc   = 2.5980762f;      // 3√3/2, capture radius in r_s
constant float kLensDMin = 1e-5f;
constant float kLensDMax = 197.4019238f;    // 200 − b_c
static float lensAlphaSample(device const float* lut, float x) {
    // x < b_c is captured light — it does not arrive. Clamping to dMin hands
    // back the max tabulated deflection; the capture tests are what remove it.
    float d = max(x - kLensBc, kLensDMin);
    float t = clamp(log(d / kLensDMin) / log(kLensDMax / kLensDMin),
                    0.0f, 1.0f) * 255.0f;
    uint  i = (uint)t;
    return mix(lut[i], lut[min(i + 1u, 255u)], t - (float)i);
}

// ── SPECTRAL STARMAP — the one colour law ───────────────────────────────────
// DESIGN_2026-07-24_spectral_starmap.md §3. ONE spectrum→colour step, TWO
// consumers: the particle vertex path, and the BH ray-march. PURE — depends
// only on its scalar arguments plus the two baked LUTs. No Particle, no vid,
// no position, so a ray sample reading the CIC grid can call it.
//
// g IS AN AXIS, NOT A CALLER MULTIPLIER. A shifted blackbody is exactly a
// blackbody at g·T (g³·B_ν(ν/g,T) ≡ B_ν(ν,g·T)), so the continuum table is
// indexed by T_eff = g·T and already contains the full g⁴ amplitude. NOTHING
// multiplies the result by g afterwards — doing so double-counts the shift.
// (That double-count was an error in RESEARCH_2026-07-24_interstellar_dngr.md
// §3/§7.3, corrected 2026-07-24 after both windows checked it numerically.)
// ⚠ SCOPE: exact for SPECIFIC INTENSITY. A march accumulating VOLUME
// EMISSIVITY carries an extra factor in its TRANSFER step — that factor stays
// on the march side and must never be folded in here, or the particle path
// (a point emitter) inherits a term that is meaningless for it.
//
// MOTTLE IS DELIBERATELY OUTSIDE. The caller perturbs lineStrength before
// calling — the particle path hashes POSITION, the ray-march hashes its SAMPLE
// POINT. That is what retires the vid dependency this file used to have.
//
// INCREMENT 1: defined and baked, NEVER CALLED. Verified by [SPEC-LUT] against
// docs/spectral_bands_reference.txt, not by looking at the screen.

constant int   SPEC_CONT_N    = 256;    // must match spectral_lut.h
constant float SPEC_CONT_TMIN = 300.0f;
constant float SPEC_CONT_TMAX = 80000.0f;
constant int   SPEC_LINES_N   = 128;
constant float SPEC_LINES_GMIN = 0.30f;
constant float SPEC_LINES_GMAX = 2.00f;

static float4 specSampleLog(device const float4* lut, int n,
                            float x, float xMin, float xMax) {
    float u = log(clamp(x, xMin, xMax) / xMin) / log(xMax / xMin) * float(n - 1);
    int   i = clamp(int(u), 0, n - 2);
    return mix(lut[i], lut[i + 1], clamp(u - float(i), 0.0f, 1.0f));
}

static float4 specSampleLin(device const float4* lut, int n,
                            float x, float xMin, float xMax) {
    float u = (clamp(x, xMin, xMax) - xMin) / (xMax - xMin) * float(n - 1);
    int   i = clamp(int(u), 0, n - 2);
    return mix(lut[i], lut[i + 1], clamp(u - float(i), 0.0f, 1.0f));
}

// Returns UN-NORMALISED observer-frame band flux. LUT channel order is
// (B,G,R) — the generator's ordering — and is swizzled to (R,G,B) on the way
// out so callers get the render's convention.
static float3 spectrumToBands(device const float4* contLUT,
                              device const float4* linesLUT,
                              float T_kelvin,      // REST-frame temperature
                              float g,             // shift factor; 1 = none
                              float lineStrength)  // 0 = pure continuum … 1 = line-dominated
{
    float4 cont = specSampleLog(contLUT, SPEC_CONT_N, T_kelvin * max(g, 1e-4f),
                                SPEC_CONT_TMIN, SPEC_CONT_TMAX);
    float3 c = float3(cont.z, cont.y, cont.x);          // (B,G,R) → (R,G,B)
    // ── LINES CAN NEVER FULLY REPLACE THE CONTINUUM — 2026-08-02 18:4x ──────
    // Jamal, A/B on the bit16 checkbox: spectral ON = "everything is salmon
    // pinkish", OFF = "i have color variety". Same scene, same physics.
    //
    // THE MECHANISM (not the line weights — those were a red herring I chased
    // first). The mix below is
    //     c*(1-s) + (w/wt)*(total*s)
    // where w/wt is a FIXED normalised hue. At s = 1 the continuum term is
    // multiplied by ZERO, so every particle returns the identical line colour
    // and TEMPERATURE IS COMPLETELY DISCARDED. The play-path proxy is
    // lineStrength = clamp(temp/5, 0, 1) (:1325) on a temperature scale whose
    // play values sit far above 5 — so s SATURATES AT 1.0 for essentially the
    // whole field, and 2M particles collapse onto one hue. With the old equal
    // (1,1,1) weights that hue was grey (the documented "desaturates" defect);
    // with Case B weights it is salmon. Same flaw, different tint — which is
    // why fixing the weights alone did not help.
    //
    // THE PHYSICS: emission lines sit ON TOP of a continuum. An ionised gas
    // still radiates free-free and bound-free continuum — a spectrum with
    // lines and NO continuum does not exist. So the line-to-continuum ratio
    // must be bounded below 1. LINE_FRAC_MAX = 0.5 is the statement "lines may
    // at most EQUAL the continuum, never replace it", which keeps the Planck
    // temperature signature (and therefore the colour variety he can see with
    // bit16 off) alive at every ionisation level.
    //
    // ⚠ 0.5 IS THE DIAL for a "too washed"/"not gassy enough" verdict. It is a
    // bound, not a measurement — unlike the Case B ratios, which are atomic
    // physics. Lower = more temperature colour, higher = more line character.
    const float LINE_FRAC_MAX = 0.5f;
    float s = clamp(lineStrength, 0.0f, 1.0f) * LINE_FRAC_MAX;
    if (s <= 0.0f) return c;

    // Lines carry a FRACTION of the same flux, redistributed into whichever
    // bands they currently land in — so lineStrength is a line-to-continuum
    // RATIO (§4.3), not an additive brightness. Under redshift the lines walk
    // out of the band set and the weights go to zero on their own: the gas
    // reddens and then darkens with no special case (§3.1).
    float4 lw = specSampleLin(linesLUT, SPEC_LINES_N, g,
                              SPEC_LINES_GMIN, SPEC_LINES_GMAX);
    float3 w = float3(lw.z, lw.y, lw.x);
    float  wt = w.r + w.g + w.b;
    if (wt < 1e-6f) return c * (1.0f - s);   // all lines redshifted out
    float total = c.r + c.g + c.b;
    return c * (1.0f - s) + (w / wt) * (total * s);
}

// ── THE UNIFIED KELVIN LAW — ONE definition, both consumers ─────────────────
// Checkpoint A2, 2026-07-08, Jamal: "UNIFIED. not phases." The law was ALWAYS
// meant to be one continuum for every state; :1443 still claims the star path
// uses "the SAME kelvin law the play path uses". It did not. The two had
// drifted into separate expressions:
//
//   PLAY (:1317)  clamp(5772*pow(max(M,0.08),0.55)          <- hardcoded A,p
//                       + clamp(temp,0,5)*tuneHeatK          <- heat pedestal
//                       + ke*tuneColorK, 1000, 40000)
//   STAR (:1462)  clamp(tuneStarKelvinA*pow(min(M,500),      <- dialed A,p
//                                            tuneStarKelvinP)
//                       + ke*tuneColorK, 1000, 40000)        <- NO heat term
//
// Three real divergences: the star path was dialable and the play path was
// hardcoded (so the 2026-07-28 A/p dials silently did nothing while a note
// sounded); the mass was floored at 0.08 in one and ceilinged at 500 in the
// other; and the HEAT PEDESTAL was removed from the star path on 2026-07-10
// (":1451 — +4500 K on a 3000 K dwarf → white … buried after the first note")
// but LEFT LIVE in the play path. That last one is why Jamal saw "white f" at
// play and colour only at release: clamp(temp,0,5) saturates while a note
// sounds, so every particle took a flat +15,000 K at the old 3000 gain and the
// whole OBAFGKM spread collapsed onto one blue-white.
//
// One function now. Fixing the law in one place fixes it in every state, which
// is the entire point of a unified system — and a divergence like the one above
// becomes impossible to reintroduce by editing a single call site.
// Dials are passed in rather than reading `cam` so this stays a pure function
// of scalars, the same contract spectrumToBands holds.
static inline float unifiedKelvin(float massMsun, float temp, float ke,
                                  float kelvinA, float kelvinP,
                                  float heatGain, float colorK)
{
    // Mass bounds are the UNION of what the two paths used: floor 0.08 (the
    // play path's guard against pow(0) at the IMF's low end) and ceiling 500
    // (the star path's guard on merger-grown monsters).
    float M = clamp(massMsun, 0.08f, 500.0f);
    return clamp(kelvinA * pow(M, kelvinP)
                 + clamp(temp, 0.0f, 5.0f) * heatGain
                 + ke * colorK,
                 1000.0f, 40000.0f);
}

// ── POSED / TIME-LAPSE ORBITAL RATE — ONE definition ────────────────────────
// Used by BOTH pose_phase_advance (which integrates it) and particle_vertex
// (which needs it for the one-frame back-step). Duplicating the expression in
// two places is how the integrator and the renderer would silently drift apart.
// r_s in the dilation = the HONEST r_h when the emergent hole drives, else the
// legacy posed 1.0; floor 0.4 so the inner edge visibly whips while clearly
// slowed against the outer.
static inline float poseOmegaEff(float rxy, float diskGM, float horizonR) {
    float rsDil = (horizonR > 0.0f) ? horizonR : 1.0f;
    float omega = sqrt(diskGM / (rxy * rxy * rxy));
    float tdil  = sqrt(max(0.4f, 1.0f - rsDil / max(rxy, rsDil + 1e-3f)));
    return omega * tdil;
}

// ── THE PLAYBACK'S GEOMETRY — ONE definition for every call site ─────────────
// (2026-08-15, his order.) The playback spun the ENTIRE FIELD about a global +Z
// at Ω on the CYLINDRICAL radius |xy − c|. Right for the 75% thin disk, wrong
// for everything else — the last surviving copy of the 90°-off-plane fault, on
// its FIFTH sighting:
//   №1 Doppler · №2 arcs · №3 arc plane · №4 arc radius · №5 THIS, the playback.
// A halo star at 45° latitude orbits at 45° inclination; spinning it about +Z
// moved ~300k stars along a path they do not travel, and no arc could be right
// while the motion it traced was wrong.
//
// ⚠️ THE FIRST ATTEMPT AT THIS USED L̂ = r × v AND WAS REJECTED ON SIGHT
// (2026-08-15 03:28:47 — the disk was destroyed, the field scattered onto a few
// bright great circles). THE LESSON, and it is reusable:
//   **r × v is the orbit normal only for a CLEAN CIRCULAR orbit.**
// It is not one here, and not because of the collapse — it is contaminated at
// SPAWN. particles.cpp:268-270 adds `sig*gauss` to vx, vy AND vz for "organic
// character", and :272-273 scales vx,vy by (1+ecc) for eccentricity. So the
// instantaneous r × v carries that noise on frame zero, and by 28 min / 32%
// collapsed it is dominated by infall.
// AND THE TOLERANCES ARE NOT THE SAME. An arc sweeps at most tuneArcWrap
// (2.2 rad), so a wrong axis only BENDS a short ribbon. The playback rotates by
// the accumulated posePhase, which wraps the FULL 2π — the same axis error
// TELEPORTS the star up to a whole orbit away. A geometry that merely looks
// wrong on the trail is catastrophic on the motion. Never reuse an axis between
// those two without re-checking the tolerance.
//
// THE AXIS THE SPAWN ACTUALLY HANDS US, and it needs no velocity at all.
// particles.cpp:260-262 sets the launch velocity to
//     p.vx = −vmag·y/|xy| , p.vy = +vmag·x/|xy| , p.vz = 0
// i.e. v ∝ ẑ × r, with ZERO z-component, for every star including the halo.
// The orbit normal of that launch is therefore a pure function of POSITION:
//     r × (ẑ × r) = ẑ|r|² − r·z  ∝  (−z·x, −z·y, x² + y²)
// which is the same expression the halo note has carried all along. Being a
// function of position it is SMOOTH and NOISE-FREE — coherent neighbours get
// coherent axes, which is exactly what the r × v version could not do. It is
// derived from the spawn law, not tuned, and on the disk plane (z = 0) it is
// exactly +Z, so the 75% is bit-for-bit unchanged.
//
// ⚠️ HONEST LIMIT: this is the normal of the orbit a star at that position was
// LAUNCHED on, not of the orbit an evolved star is on now. It is a coherent
// field, not a conserved quantity — it does not stay constant along a real
// trajectory. A truly conserved axis means carrying spawn L̂ per particle in the
// buffer; that is a spawn + buffer change, not a render one.
static inline float3 poseCentre(constant CameraUniforms& cam) {
    // The sprite playback has only ever re-centred in x–y (:594). ORIGIN LOCK
    // hard-sets bhX/Y/Z = 0 (renderer.mm:3293-3295), so this is (0,0,0) today;
    // written as the centre so it stays correct if the lock is ever lifted.
    return float3(cam.bhX, cam.bhY, 0.0f);
}
// Orbit normal from POSITION ALONE — see the derivation above. Deliberately
// takes no velocity: that was the rejected version.
static inline float3 poseAxis(float3 rel) {
    float3 L = float3(-rel.z * rel.x, -rel.z * rel.y,
                       rel.x * rel.x + rel.y * rel.y);
    float  m = length(L);
    // +Z fallback on the polar axis (x = y = 0), where the launch law gives a
    // radial orbit with no plane at all (particles.cpp:264 zeroes v there).
    return (m > 1e-12f) ? (L / m) : float3(0.0f, 0.0f, 1.0f);
}
// FULL Rodrigues. The reduced form (drop the parallel term) is exact only for a
// vector perpendicular to the axis — true for r by construction, NOT true for
// prevW, which is one frame off the plane. Using the reduced form on prevW would
// shorten it slightly every frame and corrupt the per-frame velocity that the
// Doppler shift and the motion streaks are both measured from.
static inline float3 rotAboutAxis(float3 v, float3 k, float ang) {
    float c = cos(ang), s = sin(ang);
    return v * c + cross(k, v) * s + k * dot(k, v) * (1.0f - c);
}

// ── PLAYBACK PHASE INTEGRATOR (2026-07-26) ──────────────────────────────────
// THE BUG THIS EXISTS TO KILL. The playback angle used to be built as an
// ABSOLUTE angle from an unbounded accumulator: aNow = wEff * cam.bhPoseTime.
// Differentiate that and you get
//     dtheta/dt = omega * (dPoseTime/dt)  +  bhPoseTime * (domega/dr) * v_r
// The second term is not a rotation rate at all — it is radial drift amplified
// by TOTAL elapsed pose time. Consequences, all of which Jamal reported:
//   • paused: physics frozen, v_r = 0, the term VANISHES -> one clean coherent
//     spin, "everything follows". That is why the held pause always looked right.
//   • running: v_r != 0, so neighbouring particles at the same radius rotate at
//     wildly different rates, and the apparent rotation REVERSES sign with the
//     sign of v_r — infalling and outward matter spin opposite ways on the same
//     ring. "It just runs in weird directions." Measured: reverses at
//     v_r = 1.31e-3 sim/s after 10 min of runtime (docs handoff 2026-07-26 §0).
//   • it degrades monotonically the longer the app runs, which is why earlier in
//     a session always looked better.
// The fix is not a render trick, it is an integration error: accumulate the
// phase per particle, theta = INTEGRAL omega(r(t)) dt, instead of evaluating
// omega now and multiplying by all of history.
//
// Runs as its own dispatch on the RENDER command buffer (not runComputePass,
// which executes BEFORE the pose clock for this frame is computed), so it sees
// this frame's bhPoseDt and is ordered ahead of the vertex shader that reads it.
// It must NOT live in the vertex shader: instance 0 and instance 1 (the
// secondary lensed image) are one draw call with no ordering guarantee between
// them, so the secondary would nondeterministically read the pre- or
// post-increment value — a flickering ~0.05 rad offset between the two images.
//
// Phase is WRAPPED to [0, 2pi). cos/sin are periodic so the wrap is exact, and
// it holds float32 resolution constant forever instead of decaying as the
// accumulator grows (the old form reached 1987 rad in 10 minutes).
kernel void pose_phase_advance(
    device const Particle* particlesIn [[buffer(0)]],
    constant CameraUniforms& cam       [[buffer(1)]],
    device float* posePhase            [[buffer(2)]],
    uint vid [[thread_position_in_grid]])
{
    // Mirror the vertex gate EXACTLY (bit20 + a posed/emergent hole + the
    // legacy z-axis branch, which is the only one the host ever selects).
    // PLAY GATE (2026-08-03, Jamal: "these rings appear after black hole first
    // formed and i play again + then the shapes are only rings and blurry").
    // wEff is Keplerian, √(GM/r³) — RADIUS-DEPENDENT, so this playback is
    // DIFFERENTIAL rotation. Differential rotation destroys angular structure
    // by construction: neighbouring radii sweep at different rates, so every
    // m≠0 Chladni lobe is sheared azimuthally into a concentric RING and the
    // shear smears it (the "blurry"). bhDiskGM goes non-zero the frame a hole
    // forms and never returns to 0, and bit20 is DEFAULT ON (app_state.h:56) —
    // so from the first hole onward the render spun the field FOREVER, through
    // every subsequent note. Canon it broke: PLAY MUST BE PURE CYMATICS
    // (space_synth_tube_play_vs_bh_regime) — the time-lapse belongs to the
    // silence/BH regime only. envelopePhase: 0 = silence, 1-4 = ADSR.
    if (!(cam.bhToggles & 0x100000u) || cam.bhDiskGM <= 0.0f ||
        cam.bhDiskAxisY >= 0.5f || cam.envelopePhase >= 0.5f) return;
    // ORBITAL RADIUS, NOT CYLINDRICAL (2026-08-15) — the star turns about its own
    // axis now, so Ω must be evaluated at the radius that orbit runs at, |r − c|.
    // Disk (z ≈ 0): the same number as before. Inclined halo star: the old |xy|
    // understated the radius and spun it far too fast.
    float3 rel = particlesIn[vid].posW.xyz - poseCentre(cam);
    float  r3  = length(rel);
    // Inside the honest horizon the matter is causally dead (membrane) and does
    // not playback-rotate — hold its phase rather than advancing it. The horizon
    // is a SPHERE, so this is the spherical radius; the old cylindrical test
    // compared a cylinder against a sphere and froze matter merely beside it.
    if (r3 <= max(1e-3f, cam.horizonR)) return;
    float ph = posePhase[vid] +
               poseOmegaEff(r3, cam.bhDiskGM, cam.horizonR) * cam.bhPoseDt;
    posePhase[vid] = ph - 6.28318530718f * floor(ph * (1.0f / 6.28318530718f));
}

vertex VertexOut particle_vertex(
    uint vid [[vertex_id]],
    uint iid [[instance_id]],
    device const Particle* particlesIn [[buffer(0)]],
    constant CameraUniforms& cam [[buffer(1)]],
    device const Particle* particlesRef [[buffer(2)]],
    device const float* lensAlphaLUT [[buffer(3)]],
    device const uint* cellCounts [[buffer(4)]],        // hash-grid density (per cell)
    constant SpatialHashUniforms& su [[buffer(5)]],     // grid params for the cell lookup
    device const float4* specContLUT [[buffer(6)]],     // spectral: Planck band flux vs T_eff = g·T
    device const float4* specLinesLUT [[buffer(7)]],    // spectral: line weight per band vs g
    device const float* posePhase [[buffer(8)]],        // integrated playback phase (pose_phase_advance)
    device atomic_uint* kProbe [[buffer(9)]])           // [KPROBE] Kelvin histogram — MEASUREMENT ONLY, never read back into the picture
{
    VertexOut out;
    Particle in = particlesIn[vid];
    // PHYSICS position, captured BEFORE the Keplerian pose playback mutates
    // in.posW below. The hash-grid density lives at physics coordinates —
    // sampling it at the RENDER-rotated position made the gas hue a static
    // decal the rotating disk swept through (Jamal 15:45: "the blue is like
    // an overlay I can look away from til it disappears"). Hue must ride
    // the matter: always sample density HERE.
    float3 physPosW = in.posW.xyz;

    // ── POSED-BH DISK ROTATION — real Keplerian Ω(r), differential ───────────
    // While a black hole is POSED (cam.bhDiskGM>0, sim paused), spin the disk in
    // its plane (about Z) at the physical orbital rate Ω(r)=√(GM/r³): inner edge
    // whips around (~0.4c at ISCO), outer crawls. Slowed near the hole by the
    // relativistic time dilation √(1−r_s/r) (r_s=1.0 sim) — the inner edge nearly
    // freezes, the BH altering time made visible. pos and prev are rotated (prev
    // by one frame less) so the per-frame velocity stays the TRUE orbital motion,
    // keeping the Doppler/streaks honest. No physics — pure analytic playback.
    // bit20 gate (2026-07-25): the analytic playback is a RENDER FAKE — it spins
    // the sprites while the real physics barely moves, and the ray-march samples
    // the real (slow) field, so the two never agree (Jamal: "a low-res copy of
    // something slower, sped up weirdly").
    // ⚠ COMMENT CORRECTED 2026-08-11 12:31:44 (P5). This block read "DEFAULT OFF
    // → sprites follow the REAL physics motion". That was true for ~4 hours on
    // 2026-07-25 and has been FALSE ever since: `app_state.h:56` sets
    // `uiTogAnalyticSpin = true` at 19:15 the same day ("build the clean
    // time-lapse"), and main.cpp:2215 packs it into bit20. **THIS BLOCK IS THE
    // LIVE PATH**, not an A/B path — anyone reading the old comment concluded
    // they were looking at dead code. OFF = raw physics motion (~38 s/orbit).
    // + PLAY GATE (2026-08-03): must mirror pose_phase_advance EXACTLY. The
    // phase is frozen during a note there, and here it is not APPLIED, so a
    // played note renders at the true physics positions — pure cymatics. See
    // the full mechanism note on pose_phase_advance above.
    if ((cam.bhToggles & 0x100000u) && cam.bhDiskGM > 0.0f && cam.bhDiskAxisY < 0.5f &&
        cam.envelopePhase < 0.5f) {
        // ⚠ COMMENT CORRECTED 2026-08-11 12:31:44. This read "hole centre
        // (off-origin after PLAY)". It is NEVER off-origin: the ORIGIN LOCK
        // hard-sets bhPosX/Y/Z = 0.0f (renderer.mm:3293-3295) and the only
        // refinement that could move them is inside `if (false)`
        // (renderer.mm:2935). So c2 is ALWAYS (0,0) — this is a rotation about
        // the world origin, and re-centring it on cam.bhX/Y would be a NO-OP.
        float3 c3  = poseCentre(cam);           // == (0,0,0) always, see above
        float3 rel = in.posW.xyz - c3;
        float  rxy = length(rel);               // ORBITAL radius now, not cylindrical
        // REAL RELATIVISTIC TIME BENDING (2026-07-16, Jamal item 3: "finally
        // introduce the realistic relativistic time bending in proportion to
        // the black hole — it is still way too small"). r_s = the HONEST r_h
        // when the emergent hole drives (legacy posed keeps 1.0); dilation
        // floor 0.4: inner edge visibly whips while clearly slowed vs the outer.
        // Matter inside r_h doesn't playback-rotate at all (membrane).
        if (rxy > max(1e-3f, cam.horizonR)) {
            // INTEGRATED PHASE (2026-07-26). Was `wEff * cam.bhPoseTime` — an
            // absolute angle off an unbounded accumulator, which carried a
            // `bhPoseTime * (domega/dr) * v_r` drift term that vanished when
            // paused and reversed sign with v_r when running. See the full
            // derivation and the measured magnitudes on pose_phase_advance above.
            // aPrev is one frame BACK along the same phase, so the per-frame
            // velocity the Doppler/streak path measures stays the true orbital
            // motion, exactly as before.
            // ── ONE AXIS FOR THE FIELD AGAIN (2026-08-22, his order) ────────
            // His words: "the axis is lose its turnign wihtin itself and that
            // looks like ass why is it a gyroscope" — and, correctly recalling
            // the cause a week later: "i think the thing with the rings came
            // when we unified the orbits ... we had two systems at work made it
            // 1 since then its fucked."
            //
            // HE WAS RIGHT, AND THIS IS THE LINE. From 2026-08-15 this read
            // `float3 axis = poseAxis(rel)` — a DIFFERENT rotation axis for
            // every star, tilted from +Z by exactly that star's own elevation
            // atan(|z|/rho). Stars at different heights therefore turned about
            // different axes and the field SHEARED ITSELF into nested tilted
            // rings. That is the gyroscope. It is not the spawn (which only
            // supplies the z spread) and not the lens; it is this rotation.
            //
            // WHY +Z IS THE DERIVED ANSWER, NOT A MAGIC CONSTANT: the launch law
            // at particles.cpp:256-262 gives EVERY particle v = z_hat x r, so
            // the field's total angular momentum points along +Z by
            // construction. One field, one orbit normal. (poseAxis is in fact
            // algebraically identical to r x v FOR THAT LAUNCH LAW — expand it:
            // r x (z_hat x r) = (-zx, -zy, x^2+y^2), term for term. So the
            // "position-only, not r x v" claim in its rejection note is not the
            // distinction it says it is.)
            //
            // WHY THE 08-15 ORDER NO LONGER BINDS: it existed because the ARC
            // RIBBONS swept each star about its own plane, so a global Z-turn
            // placed a halo star's head and its ribbon inconsistently. THE
            // RIBBON PASS WAS DELETED 2026-08-20 (~370 lines, his order). The
            // mismatch that motivated per-star axes no longer has a second half.
            //
            // ⚠ STILL SPLIT, STATED NOT HIDDEN: the ray-march at :3463 keeps
            // poseAxis(). Playback and the sprite path now agree on +Z; the
            // march does not. That is board row BH2 and it is NOT fixed here.
            float3 axis = float3(0.0f, 0.0f, 1.0f);
            float wEff  = poseOmegaEff(rxy, cam.bhDiskGM, cam.horizonR);
            float aNow  = posePhase[vid];
            float aPrev = aNow - wEff * cam.bhPoseDt;
            // prev is rotated one frame LESS about the SAME axis, so the
            // per-frame velocity the Doppler and the streaks measure stays the
            // true orbital motion — unchanged in intent from the .xy form.
            in.posW.xyz  = c3 + rotAboutAxis(rel, axis, aNow);
            in.prevW.xyz = c3 + rotAboutAxis(in.prevW.xyz - c3, axis, aPrev);
        }
    }
    // ── THE Y-AXIS TIME-LAPSE TWIN — DELETED 2026-08-11 04:11:00 ─────────────
    // A second copy of the Keplerian playback, gated on `cam.bhDiskAxisY > 0.5f`.
    // Re-verified before deletion: bhDiskAxisY is assigned 0.0f at ALL SEVEN of
    // its sites (renderer.h:205 default + renderer.mm:1561, :1599, :1602, :1833,
    // :1871, :1874) and is never written anywhere else, so the branch was
    // unreachable in every configuration and had been since 2026-07-26. It also
    // still carried the OLD absolute-angle form (wEff * bhPoseTime) that the
    // live block above replaced with the integrated posePhase[vid] — so reviving
    // it as written would have reintroduced the counter-rotation drift.
    // If a Y-axis (x–z) time-lapse is ever wanted, write it fresh off the live
    // block above; do not resurrect this one from git.
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
    // ⭐ RAW horizon, not the eased one (2026-08-11 03:26:00). Whether a star is
    // behind the horizon is a fact about the PHYSICS, so it must use the same
    // r_h the physics uses (renderer.mm:1980), not the value that exists to keep
    // the DRAWN radius from jumping. Measured at formation: raw 0.0781 vs eased
    // 0.0130 — a 6× under-cull lasting ~2 s every time a hole forms, which is
    // exactly the "particles still rendered after they crossed" report.
    if (cam.horizonRRaw > 0.0f && mass > 0.001f) {
        // distance from the HOLE CENTRE (off-origin after PLAY), not the origin
        if (length(in.posW.xyz - float3(cam.bhX, cam.bhY, cam.bhZ)) < cam.horizonRRaw) {
            out.position = float4(0, 0, -2, 1);
            out.pointSize = 0.0f;
            out.color = float3(0);
            out.luminance = 0.0f;
            out.originDist = 0.0f;
            out.dist = 1.0f;
            out.velDir2D = float2(0);
            out.streakLen = 1.0f;
        out.streakLen = 1.0f;
            out.strDir2D = float2(0);
            out.sharpness = 5.0f;
            out.grainAlpha = 0.08f;
            return out;
        }
    }

    // ── C1 (BH OVERHAUL, 2026-07-23): SECONDARY-INSTANCE EARLY-OUT ─────────
    // The fold-over image only exists within a few Einstein radii of the hole
    // (relative magnification μ₋/μ₊ < 0.5% beyond u≈6), yet the second
    // instance ran the FULL heavy shader for all 2M particles whenever a hole
    // existed — doubling the most expensive pass for matter that can never
    // fold. Project once, cheaply, and bail beyond 8·θ_E (the margin absorbs
    // the aspect + dilation approximations of this quick projection).
    if (isSecondary && mass > 0.001f) {
        float3 pSpin = applySpin(in.posW.xyz, cam.spinAngleX, cam.spinAngleY,
                                 cam.spinAngleZ);
        float3 bSpin = applySpin(float3(cam.bhX, cam.bhY, cam.bhZ),
                                 cam.spinAngleX, cam.spinAngleY, cam.spinAngleZ);
        float4 pClip = cam.viewProjection * float4(pSpin * R, 1.0f);
        float4 bClip = cam.viewProjection * float4(bSpin * R, 1.0f);
        bool cullFar = (pClip.w <= 0.0f) || (bClip.w <= 0.0f);
        if (!cullFar) {
            float2 dNdc = pClip.xy / pClip.w - bClip.xy / bClip.w;
            cullFar = length(dNdc) > 8.0f * max(cam.bhShadowNdcRadius, 1e-4f);
        }
        if (cullFar) {
            out.position = float4(0, 0, -2, 1);
            out.pointSize = 0.0f;
            out.color = float3(0);
            out.luminance = 0.0f;
            out.originDist = 0.0f;
            out.dist = 1.0f;
            out.velDir2D = float2(0);
            out.streakLen = 1.0f;
        out.streakLen = 1.0f;
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
        out.streakLen = 1.0f;
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
    // ── THE DILATION SHEAR IS A FEATURE. KEEP IT, AND MATCH IT. ─────────────
    // (2026-07-26 21:06:52, restored after a 9-minute regression.)
    // spinAngle{X,Y,Z} scaled by a PER-PARTICLE tDilate means the view rotation
    // is a SHEAR: inner radii turn less than outer ones, so rotating the view
    // smears the field differentially. That smear is Jamal's "time warp traces"
    // — 21:00: "rotating the thingy doesn't time warp traces any more, like no
    // more beautiful time warpeyssss." I removed it at 20:58 as a rigid-camera
    // correctness fix and it killed the effect on sight. A rigid rotation moves
    // the whole cloud together, so there is nothing left to trail.
    // WHAT I GOT WRONG in that diagnosis: the capture cull (:697) tests the
    // DRAWN worldPos, so it follows the shear and was never inconsistent. The
    // only consumer that actually disagreed is the RAY-MARCH, which samples the
    // hash grid through applyInverseSpin at the FULL angle while the sprites are
    // drawn sheared — two images of one field, rotated differently. That is the
    // "hole in front of the ring".
    // WHY BOTH ARE POSSIBLE: applySpin is a rotation, so it preserves |p|, and
    // tDilate depends only on |p|. The shear is therefore EXACTLY invertible —
    // the march recovers the same tDilate from the radius of its sample point
    // (see the matching block in bhmarch_fragment). Sprites and march now live
    // in the same sheared frame instead of one being "fixed" to the other.
    // ⚠ hole_vertex (:2135) uses the same pattern with a DIFFERENT profile
    // (rsDil = live horizonR, floor 0.02, vs 0.57/0.4 here) despite its comment
    // claiming they must match exactly. Not encoded while bit15 is ON (default),
    // so it is off the live path; reconcile before trusting the bit15-OFF A/B.
    // ⚠ P6 CLAIM REFUTED HERE, 2026-08-11 12:31:44. The board (§H1 P6, §G5)
    // says this measures dilation "from the ORIGIN while the hole sits at
    // r=3.8-5.9 sim", implying a fix: re-centre on cam.bhX/Y/Z. **That fix is
    // a NO-OP.** cam.bhX/Y/Z are hard-zeroed by the ORIGIN LOCK
    // (renderer.mm:3293-3295; the refinement is inside `if (false)` at :2935),
    // so the renderer's hole centre IS the origin and length(posW.xyz) already
    // measures from it. The r=3.8-5.9 figure describes where the physical MASS
    // is, which is a different quantity the render never sees. If this is ever
    // to become honest, the work is to give the renderer a real hole position —
    // i.e. A3② — not to swap the vector here. 4th no-op "fix" logged on this
    // project (cf. A3①'s kREnc, A3③'s latch).
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

    // ── HORIZON-INTERIOR CULL (bit15, 2026-07-24) ───────────────────────
    // Matter inside r_h emits nothing that can reach the camera — that IS the
    // horizon. Culling it here is what lets the black-painting occluder pass
    // die: that pass existed ONLY to hide this pile, and it hid it with a
    // multiply over the finished frame, which also blacked out every particle
    // in FRONT of the hole (Jamal 2026-07-24: "a black circle that overlays in
    // front of everything even in front of particles clearly far in front").
    // A fullscreen multiply cannot know what is in front — renderer.mm:784
    // disables depth WRITE for the particles so they additively blend, so no
    // depth information exists for any later pass to order against. Removing
    // the light at its source is the fix that needs no depth at all.
    if ((cam.bhToggles & 0x8000u) && cam.horizonR > 0.0f) {
        float rIn = length(in.posW.xyz - float3(cam.bhX, cam.bhY, cam.bhZ));
        if (in.posW.w >= 0.001f && rIn < cam.horizonR) {
            out.position = float4(0, 0, -2, 1);
            out.pointSize = 0.0f;
            out.color = float3(0);
            out.luminance = 0.0f;
            out.originDist = 0.0f;
            out.dist = 1.0f;
            out.velDir2D = float2(0);
            out.streakLen = 1.0f;
        out.streakLen = 1.0f;
            out.strDir2D = float2(0);
            out.sharpness = 5.0f;
            out.grainAlpha = 0.08f;
            return out;
        }
    }

    if (cam.horizonR > 0.0f && !isSecondary) {
        float3 camP = cam.cameraPos.xyz;
        float  camL = length(camP);
        if (camL > 1e-3f) {
            float3 d = -camP / camL;                    // view dir, camera → origin
            float  along = dot(worldPos, d);            // >0 = beyond the hole plane
            float3 perp  = worldPos - along * d;
            // EXACT photon-capture radius (2026-07-24): b_c = 3√3·M = (3√3/2)·r_s
            // = 2.5980762 r_s. Was the rounded 2.6f. This is the analytic
            // point-mass value — it only becomes non-trivial (and needs the
            // geodesic march) once the enclosed mass M(<r) is extended, which
            // is the increment that follows.
            float  bCapt = 2.5980762f * cam.horizonR * R; // capture radius, world units
            // SLAB CULL REMOVED (2026-07-19 17:58): the "hole-depth slab"
            // exception carved a straight-edged band across the shadow region
            // (Jamal: "it looks like a pokeball"). With the lens on, the lens
            // + membrane are the ONLY transport — no straight-line culls.
            if (along > 0.0f && length(perp) < bCapt) {
                out.position = float4(0, 0, -2, 1);     // captured: no light arrives
                out.pointSize = 0.0f;
                out.color = float3(0);
                out.luminance = 0.0f;
                out.originDist = 0.0f;
                out.dist = 1.0f;
                out.velDir2D = float2(0);
                out.streakLen = 1.0f;
            out.streakLen = 1.0f;
        out.streakLen = 1.0f;
                out.strDir2D = float2(0);
                out.sharpness = 5.0f;
                out.grainAlpha = 0.08f;
                return out;
            }
        }
    }

    out.position = cam.viewProjection * float4(worldPos, 1.0);
    // ═══════════════════════════════════════════════════════════════════
    // 🔪 THE LENS IS DEAD — 2026-08-27 21:02:15, HIS ORDER
    // ═══════════════════════════════════════════════════════════════════
    // "a black hole is not a lense. i want u to kill the lense like u killed
    //  the tube. FUCK THE LENSE. this enitre approach is ass."   [HIS WORDS]
    //
    // ~320 lines removed: the bit8 gate, the angle-space thin-lens solve
    // beta = theta - alpha(theta)*D with its Newton iteration on the exact
    // deflection LUT, the second instance and its magnification weight, the
    // hole-centred screen fallback, and every lensRamp/imageWeight/preLensNDC
    // consumer in this function.
    //
    // WHY HE IS RIGHT, and it is not a matter of taste. A lens is a SURFACE
    // that refracts: you place it, and it maps one image to another image.
    // A black hole has no surface. Light follows null geodesics of a curved
    // metric, and what you see is decided by where each RAY came from — which
    // is a per-pixel question, not a per-particle one. NASA/Goddard's own
    // answer (Schnittman & Powell, May 2024, the "falling into a black hole"
    // visualisation) is RAY TRACING ALONG GEODESICS, 10 TB over 5 days on
    // 129,000 processors. There is no lens anywhere in it. Ours was a forward
    // per-sprite screen displacement, so it could produce exactly as many
    // images as we coded roots for — TWO — while the photon ring is the
    // n -> infinity stack. It was never going to arrive by tuning.
    //
    // WHAT THIS RESTORES ON ITS OWN: the straight-line photon-capture cull at
    // :1029 was gated OFF whenever the lens was imaging (!lensWillImage). With
    // the lens gone it applies to every ray again, so the shadow is still
    // carved by ABSENCE at the exact b_c = 2.5980762 r_s. The shadow does not
    // depend on the lens and never did.
    //
    // WHAT IS NOW MISSING AND MUST COME FROM THE MARCH: R5 (far-side arch),
    // R6 (underside arc) and R2 (photon ring). ⚠️ UPDATED 2026-08-27 21:12:40:
    // this used to say "that is bhmarch_fragment's job" — the march was deleted
    // an hour later, on his order, so NOTHING in this codebase produces those
    // three features today. See docs/blackhole-library/ before proposing what
    // does. The short version: every renderer that has ever got this right —
    // Luminet 1979, DNGR/Interstellar, NASA/Schnittman 2024, and the EHT's own
    // forward models — asks a BACKWARD, PER-PIXEL question. Ours asked a
    // forward, per-particle one twice, and died twice.
    //
    // ⛔ DO NOT REBUILD THIS. The deflection LUT in renderer.mm is real physics
    // and stays — the march can use it. The forward sprite displacement does
    // not come back.
    if (isSecondary) cullThis = true;   // no second image without a lens


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
    // ── A1 ORBIT-ARC CONTINUUM (BH OVERHAUL front A, 2026-07-23 16:52) ──
    // The settled ring is sparse popcorn: a few thousand dots standing in
    // for a continuum, each nearly motionless on screen → "circles stacked
    // on each other". A bound particle near the hole is a SAMPLE of its
    // whole orbit — so its streak uses the analytic Kepler tangential
    // velocity v=√(GM/r) under the DECLARED time-compression clock (07-15
    // canon: a declared time-lapse, not a fake force; physics untouched —
    // this is the streak VECTOR only). Dots stretch into tangential arcs;
    // overlapping arcs fuse into continuous flowing bands (the reference
    // anatomy: thin streaks that run into each other). Zone-gated to the
    // disk band around the honest hole; ramps OFF during play (the shape
    // regime keeps its true-motion streaks).
    if (cam.horizonR > 0.0f && cam.bhDiskGM > 0.0f &&
        cam.envelopePhase < 0.5f) {
        float2 rel = in.posW.xy - float2(cam.bhX, cam.bhY);
        float rxy = length(rel);
        float zRel = fabs(in.posW.z - cam.bhZ);
        // Disk band: outside the horizon, inside the visible ring region,
        // near the disk plane — each edge smoothed so the arcs fade, not cut.
        float zone = smoothstep(cam.horizonR, cam.horizonR * 1.6f, rxy) *
                     (1.0f - smoothstep(8.0f * cam.horizonR,
                                        16.0f * cam.horizonR, rxy)) *
                     (1.0f - smoothstep(2.0f * cam.horizonR,
                                        5.0f * cam.horizonR, zRel));
        if (zone > 0.01f && rxy > 1e-4f) {
            float vK = sqrt(cam.bhDiskGM / max(rxy, cam.horizonR));
            float2 tang = float2(-rel.y, rel.x) / rxy;  // +Ω about z, matches
                                                        // the pose playback
            // Declared clock: fixed here (A1); becomes the B1 flow dial.
            const float ARC_TIME_COMPRESS = 6.0f;
            float3 vArc = float3(tang * vK * ARC_TIME_COMPRESS, 0.0f);
            velReal = mix(velReal, vArc, zone);
        }
    }
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
    out.velDir2D = (v2_screen - v1_screen) * STREAK_GAIN;

    // ── FLUID STREAK (bit18, 2026-07-24) — THE ARC GETS ITS OWN ROOM ────────
    // Jamal: "no fluid streak". Two compounding defects, both fixed here:
    //  (1) the arc was drawn INSIDE a fixed sprite quad (along/lengthX) and the
    //      radial window zeroed it before the quad edge, so a trail could never
    //      be longer than ONE sprite no matter how fast the matter moved. Speed
    //      past elong=1 (clamp(speed*1.4,0,1)) changed nothing at all — that is
    //      why raising the tempo turned the field to mush instead of flow.
    //  (2) stretching MULTIPLIED flux: core=pow(1-sqrt(r2),3) in warped coords
    //      held near-peak brightness over a bigger area, so fast matter emitted
    //      MORE total light — the blown-out white core.
    // Now the quad grows with the arc and the fragment divides brightness by
    // the same factor, so a fast particle draws a LONG DIM trail at conserved
    // flux — Front A1's "arc length ~ Omega*exposure, luminance conserved".
    // ⚠ KNOWN DEFECT, DELIBERATELY LEFT IN PLACE (measured + reverted
    // 2026-07-25 22:33:00). out.pointSize is not assigned until line ~986 —
    // every write before this point is `= 0.0f` in a branch that returns
    // immediately — so the `> 0.0f` gate below reads uninitialised memory,
    // never opens, and lenFac is 1.0 for EVERY particle in the app. Measured:
    // [STREAKPROBE] ptSize=0.0 streakLen=1.00 over ~973k ring-band particles.
    // bit18 has therefore never done anything since it was written 2026-07-24.
    //
    // Moving it after line 986 WAS tried (21:52) and REVERTED on Jamal's
    // verdict ("ugly blue sprites", "ugly stripes"): with the growth live, 76%
    // of ALL drawn particles grew ~9.5x ([SIZEPROBE] avgStreakLen=9.305,
    // grown>1.5=75.8%), and because the diffraction spikes at :1742 are drawn
    // in the RAW quad coord they grew with it — giant crosses over the whole
    // star map, and 21 fps from the ~90x fill area. Re-landing this needs the
    // spike/star-core interaction solved FIRST (starness must know about sL),
    // not just the ordering. Do not move it again on its own.
    //
    // 2026-07-26 12:33:00 — re-landed at the end of this shader WITH the
    // starness/sL fix in place (so no star crosses this time), and REJECTED
    // AGAIN on sight 12:35: "the way that the sprites look now we never ever
    // want them to move — the entire mechanix is broken and is a relict from
    // very early days". So the verdict is NOT about the ordering, and NOT about
    // the spikes: screen-space velocity-stretching of a point sprite is the
    // wrong mechanism for trails, full stop. Do not re-land this by fixing
    // details. It needs replacing, not repairing.
    // (`starness /= sL` at :1757 is KEPT — verified no-op while sL == 1.)
    out.streakLen = 1.0f;

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
    // ══ P2 — REAL PER-PARTICLE DEPTH IN ORTHO (2026-08-11, board §H1) ════════
    // WAS: `mix(out.position.w, cam.cameraPos.w, isOrtho)`. In ortho — THE
    // DEFAULT (renderer.h:54) — `out.position.w` is 1 (a parallel projection has
    // no perspective divide), so this fell back to `cam.cameraPos.w`, which
    // renderer.mm sets to `config.cameraRho`: the camera's distance from the
    // ORIGIN. ONE SCALAR, HANDED TO ALL 2M PARTICLES. It then drives point size
    // (distRatio below) and the fragment's fadeAmount. **A depth cue with zero
    // variance across the field cannot produce depth**, and the fade was inert
    // besides (fadeDistance = 6.0 vs a cameraRho clamped >= 50, so it saturated
    // at 1 for every particle, always).
    //
    // NOW: the true depth along the VIEW AXIS.
    // ⭐ It must be dot(delta, forward), NOT length(delta). Ortho rays are
    // PARALLEL, so depth is the projection onto the view direction; Euclidean
    // distance to the camera POINT would make off-axis particles read as
    // farther and bend the size falloff into a fisheye toward the screen edges.
    // ⭐ Second real consumer of F5's `viewForward` (A9 was the first) — using
    // it instead of normalize(-cameraPos) means this stays correct the moment
    // the camera stops looking at the origin, which is exactly what F6 does.
    //
    // ⚠️ HONEST FRAMING — this makes ortho a hybrid and that is deliberate.
    // In a strict parallel projection apparent SIZE does not vary with depth.
    // But our sprites are PSF-limited point sources, not geometry: a point
    // source's flux falls as 1/d^2 and its drawn size follows its brightness.
    // "Farther = dimmer = smaller PSF" is about flux, not projection, so it is
    // physically defensible under ortho — while a geometric size falloff would
    // not be. That distinction is the whole justification for this change.
    float3 vFwd = normalize(float3(cam.viewForwardX, cam.viewForwardY,
                                   cam.viewForwardZ));
    float orthoDepth = max(dot(worldPos - cam.cameraPos.xyz, vFwd), 1e-3f);
    // ⚠️ `dist` STAYS THE PRE-P2 VALUE ON PURPOSE — corrected 2026-08-11 14:56
    // after his report: "stuff disappears out of frame weirdly when i zoom in".
    // My regression, and the mechanism is exact. The ONLY consumer of out.dist
    // is the fragment's `fadeAmount = smoothstep(0.1, fadeDistance=6.0, dist)`,
    // which is a PERSPECTIVE NEAR-CLIP fade: it exists to kill sprites right on
    // the lens. In ortho it was always INERT, because dist was cameraRho and
    // rho is clamped >= 50, so smoothstep(0.1, 6, >=50) == 1 for every particle
    // forever. Feeding it a true per-particle depth switched a dormant near-clip
    // into a live one: any particle within 6 sim of the camera PLANE fades to
    // zero, and zooming in drags more of the near field across that line — so
    // matter vanished exactly as he described.
    // ⭐ THE LESSON, worth more than the fix: P2 did not "add depth", it
    // ACTIVATED EVERY DORMANT CONSUMER OF A CONSTANT. Two have now bitten
    // (zoomCap/flux, and this fade). Before feeding a real value into any
    // long-constant variable, enumerate its readers — a consumer written
    // against a constant may be dead code that only LOOKS live.
    // Depth now travels by exactly one route: `depthCue`, applied to size only.
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
    // ══ ZOOM AND DEPTH ARE TWO DIFFERENT QUANTITIES (2026-08-11, P2 follow-up)
    // BUG THIS FIXES — his report: "stars near camera are too buggy and big",
    // "the rest of the chain is not properly adapted to it yet". Correct on both
    // counts, and it was introduced by P2 an hour earlier.
    //
    // `distRatio` was a PER-FRAME ZOOM number: dist was `cameraRho`, identical
    // for every particle, and everything downstream was written against that
    // reading — `zoomCap` says so in its own comment ("Cap sprite size by
    // ZOOM"), and the flux-conservation branch pours capped AREA into luminance
    // on the same assumption. P2 made `dist` PER-PARTICLE, so those consumers
    // silently started receiving a per-particle number and the near field
    // diverged: at a depth approaching the camera plane the old
    // `max(dist, 1e-3)` floor allows distRatio ~ 8e5, and pow(8e5, 0.65) is a
    // sprite thousands of pixels across. That is the blowup he saw.
    //
    // THE SPLIT:
    //   zoomRatio — per FRAME, from cameraRho. Restores every downstream
    //               consumer (zoomCap, flux comp) to exactly its pre-P2 input.
    //   depthCue  — per PARTICLE, bounded, and applied ONLY to sizeScale. It is
    //               1.0 at the field centre, >1 nearer, <1 farther, so with a
    //               flat field it is identically the old behaviour.
    // The depth term uses the SAME 0.65 exponent as zoom because both describe
    // "distance to this sprite" — using a second, different law would be an
    // invented number.
    //
    // THE BOUND IS DERIVED, NOT PICKED: the floor is a quarter of the camera's
    // own distance. At that depth the cue saturates at pow(4, 0.65) = 2.46x,
    // and it scales WITH the camera instead of being a magic pixel constant.
    // Anything nearer than a quarter of the view distance is effectively at the
    // camera in a parallel projection and earns no further growth.
    float zoomRatio = 800.0f / max(1e-3f, cam.cameraPos.w);
    float depthCue = 1.0f;
    if (isOrtho > 0.5f) {
        // ══ SCALE-INVARIANT DEPTH CUE (2026-08-11, board §H10) ══════════════
        // HIS QUESTION: "is our new understanding of depth part of the chladni
        // modes?" MEASURED ANSWER: it was not, and the reason was this line.
        // The cue normalised against the camera's ABSOLUTE distance, so the
        // size spread it produced was (field half-depth / cameraRho):
        //     Chladni cavity  R=6   at rho=800  ->  0.75%   invisible
        //     star map        R=100 at rho=800  -> 12.5%    clearly visible
        // The Chladni eigenmode is genuinely 3D (§H2: pAx never 0, k_z > 0, a
        // real dPdz in the force) — it was the CUE that could not see it. A
        // 12-sim-deep cavity and a 200-sim-deep star map cannot share a law
        // written against absolute distance.
        //
        // FIX: normalise to the FIELD'S OWN half-depth, so every field reads
        // with the same depth regardless of its physical size.
        //
        // THE EFFECTIVE DISTANCE IS DERIVED, NOT PICKED. Use the distance at
        // which an object of half-extent R exactly fills the frame at this
        // project's own perspective FOV (45 deg, main.cpp's perspectiveMatrix):
        //     d_eff = R / tan(45/2) = R / 0.414214 = 2.41421 * R
        // Then cue = d_eff / (d_eff + delta), delta = depth from field centre.
        // At the near face (delta = -R): 2.41421/1.41421 = 1.7071 = 1 + 1/sqrt2
        // At the far  face (delta = +R): 2.41421/3.41421 = 0.7071 =     1/sqrt2
        // A 2.414x span, identical for the cavity and the star map. Through the
        // existing pow(.,0.65) that is a 1.76x near-to-far size ratio.
        // Zero free parameters: 45 deg is ours, R is the physics cap, 0.65 is
        // the size law already in this file.
        const float kTanHalfFov = 0.414214f;              // tan(22.5 deg)
        float R = max(cam.fieldHalfDepth, 0.5f);
        float dEff = R / kTanHalfFov;
        float delta = orthoDepth - cam.cameraPos.w;       // signed, - = nearer
        // Clamp delta to the field itself: matter outside the cap is either
        // escaping or mid-transition, and must not drive the cue past the range
        // the derivation covers.
        delta = clamp(delta, -R, R);
        depthCue = dEff / max(dEff + delta, 1e-3f);
    }
    // Perspective keeps its true per-fragment w; ortho now feeds the chain the
    // ZOOM again, with depth carried separately by depthCue.
    float distRatio = mix(800.0f / max(0.0001f, dist), zoomRatio, isOrtho);
    float sizeScale = pow(distRatio, 0.65f) * 1.275f * pow(depthCue, 0.65f);
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
    // ── C7b: `dopplerColor` DELETED 2026-08-11 12:31:44 ─────────────────────
    // It was declared here, assigned once from DOPPLER_K_COLOR·v_los below, and
    // NEVER READ — verified by grep (3 hits: the decl, the assign, and a comment
    // that claimed it was applied). The surviving line-of-sight term is BEAMING
    // on luminance (DOPPLER_K_BEAM), which is real and untouched. Doppler-as-hue
    // was removed 2026-06-26 on Jamal's verdict — do NOT re-propose it.
    // DOPPLER_K_COLOR (:292) is deleted with it; it had no other reader.
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
            // ⛔ REVERTED 2026-08-14 12:35:00 — BOTH of my beaming changes are out.
            // Baseline restored bit-for-bit: max(0.35, 1+0.8*vLos)^1.4.
            //
            // WHY. Attempt 1 (raw g³, 12:01:52) blew the peak from 1.69 to 6.4 and
            // washed the field to blue-white under additive blending. Attempt 2
            // (12:19:20) divided by the ring's azimuthal mean <g³> = (1+β²/2)/(1-β²)
            // to hold average exposure — and that was the worse error, because
            // normalising by the MEAN of a heavily skewed distribution crushes the
            // TYPICAL value. Measured at the disk's peak β ≈ 0.6:
            //     <g³>                    = (1+0.18)/(1-0.36) = 1.84
            //     g³ for TRANSVERSE matter = (1-β²)^{3/2}      = 0.512
            //     ⟹ typical particle drew 0.512/1.84 = 0.28 → 3.6x DIMMER
            // Most of a ring moves transversely to the line of sight, so most of the
            // ring went dark and one narrow approaching arc survived. His verdict
            // 12:30: "its just black mush over half the screen". The ring mean was
            // exactly 1.0 as designed — carried entirely by the crescent.
            //
            // 🚨 THE REAL LESSON, and the reason this is a REVERT and not attempt 3:
            // g³ is correct physics, but a 41x intra-frame range cannot be carried by
            // an ADDITIVE point cloud with no opacity floor. The reference (DNGR Fig
            // 15c) is a THICK disk rendered to film — its dim side still reads because
            // it is a lit surface, not a sum of sparse sprites. Beaming is therefore
            // downstream of the surface problem (§4d.1), not independent of it.
            // 🚨 AND IT IS NOT MINE TO TUNE. His order 12:26: "i will create a new
            // preset in the ui at a later point, it cant be constructed from the
            // parameters in the engine rn." Brightness/colour is his via presets.
            // Do not touch this block again without him asking.
            //
            // The dead code below is kept verbatim for whoever revisits it WITH the
            // dials and an opacity floor in place. DOPPLER_K_BEAM/_EXP are live again.
            // ── T1: THE HONEST BEAMING LAW (2026-08-14) — DISABLED, see above ──
            // Was: beam = max(0.35, 1 + 0.8*vLos), luminance *= pow(beam, 1.4).
            // Three departures from the physics, all in those two lines:
            //   (a) exponent 1.4. Liouville's theorem says specific intensity
            //       transforms as I_v ∝ v³ (DNGR §3, their Fig. 15c caption) —
            //       the exponent is 3, not 1.4, i.e. we ran less than half the
            //       real power law.
            //   (b) K = 0.8 in a linearised (1 + K·β_los). The real Doppler
            //       factor has NO free gain. And the units already line up:
            //       vOrbit = Ω(r)·r runs 0.23..0.67 over the disk, which IS β
            //       with c = 1 (units note, DNGR doc) — so any K ≠ 1 was pure
            //       fudge on top of an already-correct velocity.
            //   (c) the 0.35 floor held the receding side at 23% brightness.
            //       DNGR: it should nearly vanish. The floor existed to stop a
            //       SEAM from hard-clamping to black — but g below is smooth and
            //       never reaches zero, so the seam it guarded against cannot
            //       occur and the floor is not needed to prevent it.
            // Measured contrast at β≈0.55: the old law gives 1.69 vs 0.23 = 7.3x.
            // The real one gives 11.4 vs 0.088 = 129x. We were running ~1/18 of
            // the true asymmetry in ratio terms.
            // 🚨 THIS IS THE EFFECT NOLAN DELIBERATELY TURNED OFF (DNGR §3,
            // "movie cheat") because the true lopsidedness was "too confusing
            // for a mass audience". Their Fig. 15c is what it really looks like,
            // and that — not the film frame — is our reference.
            // Gravitational redshift is a SEPARATE factor (the √(1−2M/r) term of
            // A.16) and is deliberately NOT folded in here: one change at a time.
            float b2     = min(dot(vOrbit, vOrbit), 0.9801f);  // |β|² < 1, guard γ
            float gamma  = rsqrt(max(1.0f - b2, 1e-4f));
            float gDop   = 1.0f / max(gamma * (1.0f - vLos), 1e-3f);
            // ── FLUX-NORMALISED BEAMING (2026-08-14 12:2x) ───────────────────
            // g³ is the correct law, but the field's absolute luminance scale was
            // tuned for a law that PEAKED at 1.69 (max(0.35,1+0.8β)^1.4). Raw g³
            // peaks at 6.4 for β=0.55 — 3.8x hotter — and with ~2M sprites under
            // ADDITIVE blending the bright limb saturates locally and washes to
            // white. That is his "its still just blue grey ish": changing the law
            // without changing the exposure it was built for is a photographic
            // error, not a physics one.
            // The cure is exposure, NOT the exponent (never put 1.4 back). The
            // azimuthal mean of g³ around a ring has a closed form:
            //     g³      = (1-β²)^{3/2} / (1-β·cosφ)³
            //     <(1-β·cosφ)^-3>_φ = (1+β²/2)/(1-β²)^{5/2}
            //   ⟹ <g³>_φ = (1+β²/2)/(1-β²)
            // Dividing by it holds the ring's AVERAGE brightness exactly where it
            // was and lets ONLY the asymmetry show. Zero free parameters, and the
            // full physical contrast ratio ((1+β)/(1-β))³ = 41x at β=0.55 is
            // preserved untouched — it is redistributed, not rescaled.
            // ⚠ ASSUMES EDGE-ON: the LOS modulation amplitude is |β|·sin(i), so
            // at low inclination this slightly over-corrects (dims the disk). The
            // hole is viewed near edge-on in the shots that matter; revisit if a
            // face-on view reads flat.
            float meanG3 = (1.0f + 0.5f * b2) / max(1.0f - b2, 1e-4f);
            (void)gDop; (void)meanG3; (void)gamma;   // kept for the record, not applied
            // ── LIVE LAW: the pre-2026-08-14 baseline, restored ──────────────
            // Soft floor (0.35) so the receding side fades SMOOTHLY instead of
            // hard-clamping to black → no seam.
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
        out.streakLen = 1.0f;
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

    // ── PHASE VIZ NO LONGER REPLACES THE COLOUR (2026-08-24 22:2x) ──────────
    // This was `if (cam.phaseViz > 0.5f) { out.color = hsv2rgb(...); } else {`
    // — an if/else, so switching it on made the ENTIRE blackbody + spectral
    // band path below dead code and the field became a flat HSV rainbow. That
    // also contradicted the standing directive a few lines down ("ONE
    // universal law ... no ramps, no per-phase palettes", 2026-06-14).
    // His call 2026-08-24: **blend, do not replace.** The physical path now
    // ALWAYS runs; the phase tint is applied once, late, at the bottom of this
    // function where both regimes have finished writing out.color.
    {
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
        float ke     = dot(in.velW.xyz, in.velW.xyz);       // |v|² ∝ kinetic temperature
        // INTRINSIC temperature → colour (2026-06-26). Doppler/gravShift are
        // VIEW-DEPENDENT (line-of-sight); folding them into the colour made the
        // whole field a screen-space red/blue gradient that ROTATED with the
        // camera ("linear filter", not colour the particles own — Jamal). Colour
        // now comes from the particle's OWN state only: mass + play-heat +
        // kinetic. Doppler still drives BEAMING (out.luminance, above), not hue.
        // UNIFIED 2026-08-02: was its own expression with hardcoded 5772/0.55
        // and a live heat pedestal. Now THE one law (see unifiedKelvin).
        float kelvin = unifiedKelvin(in.posW.w, temp, ke,
                                     cam.tuneStarKelvinA, cam.tuneStarKelvinP,
                                     cam.tuneHeatK, cam.tuneColorK);
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

        // ── INCREMENT 4 (bit16): THE playMix PHASE GATE DIES ────────────────
        // There stops being a "play colour" and a "rest colour". powder_toy
        // lessons: thresholds, NOT phases — kill envelopePhase gating. The two
        // branches this mix chose between were a blackbody continuum and an
        // emission-line RAMP; the spectral law contains both at once, so the
        // choice is no longer needed. Play does not SWITCH the colour, it
        // raises shock temperature → ionisation → line strength → the colour
        // moves. The state emerges from the physics instead of from the
        // envelope.
        //
        // lineStrength here is the shock-ionisation proxy clamp(temp/5,0,1) —
        // the SAME tN the rest path uses, so the two ends of the envelope
        // agree on what "ionised" means and there is no seam to cross.
        //
        // The (0.7 + 0.9·thT) term is PRESERVED verbatim: it is a BRIGHTNESS
        // modulation that happens to live on thermalCol, and §2 says only the
        // COLOUR term is replaced. Dropping it here would have dimmed play
        // while pretending to be a hue change.
        if (cam.bhToggles & 0x10000u) {
            float lsPlay = clamp(temp * (1.0f / 5.0f), 0.0f, 1.0f);
            float3 sb = spectrumToBands(specContLUT, specLinesLUT,
                                        kelvin, 1.0f, lsPlay);
            sb /= max(max(sb.r, max(sb.g, sb.b)), 1e-20f);
            out.color = sb * (0.7f + 0.9f * thT);
        } else {
            out.color = mix(thermalCol, snCol, playMix);
        }

        // Speed-based warm boost REMOVED (2026-06-25): this added a warm
        // (0.3,0.2,0.1)·boost wash to every moving particle, clamped to 0.8 and
        // saturated almost instantly (speed*8). It is NOT slider-gated, so it
        // painted the whole PLAY field orange-white even with Colour Spectrum +
        // Plasma Heat all the way down (Jamal's "flat 2D filter"). It only ever
        // affected PLAY (at rest the star-map mix overwrites out.color; BH seeds
        // override). It was also a fake Doppler hack.
        // ⚠ COMMENT CORRECTED 2026-08-11 12:31:44 (C7b). This used to read "the
        // REAL relativistic Doppler shift is already applied above via
        // dopplerColor". That was FALSE — dopplerColor was computed and never
        // read, so NO colour Doppler shift is applied anywhere. What IS applied
        // is relativistic BEAMING on luminance (DOPPLER_K_BEAM). Colour during
        // play is blackbody-of-temperature only.
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
    // ── STAR BRANCH STANDS DOWN IN THE ACCRETION DOMAIN (2026-07-26 12:56:00) ──
    // Jamal, pointing at the Chladni shapes: "this is our only mechanic for light
    // trails — hyper speed and hyper density… that's what we want, the feel, the
    // look and the way it's rendered at 120 fps at basically zero cost… we need at
    // least the same way it's rendered for the black hole horizon."
    //
    // The bars in those shapes and the dots around the hole come out of the SAME
    // sprite pass, on opposite sides of this branch. The hole exists ONLY at
    // silence, and starMix is keyed to silence — so the whole accretion disk was
    // drawn 100% by the star-map branch below: size from the STELLAR radius law
    // (R ∝ M^0.8), luminance L ∝ M^3.5, OBAFGKM colour by mass. Through that law a
    // 1 M☉ particle is sub-pixel, which is exactly the measured near-hole
    // [STREAKPROBE] ptSize = 1.0 — the disk was a field of dim red dwarfs. Matter
    // falling onto a black hole is not a field of dwarf stars; it is the same
    // shocked plasma the play regime draws as bright dense bars.
    //
    // Same idiom the nova flash already uses to stand down in this domain (:1487).
    // Inside ~4 r_h the disk takes the plasma path (heat-driven luminance +
    // heatSizeBoost + the play colour law); beyond 16 r_h the star field is
    // untouched; smooth between. No sprite is stretched, nothing is painted, no
    // new pass — this is a branch selection, so it costs nothing.
    // DOMAIN WIDENED 16 -> 32 r_h (2026-07-26 13:04:00). At 4..16 with r_h ~ 0.15
    // this only converted matter inside ~2.5 sim, so most of the visible ring kept
    // the star branch — Jamal: "a lot that read as the blueish stars… just our
    // stars". Those are merger remnants: kelvinU = 5772*M^0.55 puts the 126 M☉
    // biggest body at ~80,000 K (blue-white) with starSize from R ∝ M^0.8, so a few
    // heavy bodies dominate the ring. 32 r_h is this repo's own outer edge of the
    // accretion domain (accGas uses 4..32 at :1609, the nova stand-down 16..32 at
    // :1487) — not a fresh guess.
    if (cam.horizonR > 0.0f) {
        float rBHs = length(in.posW.xyz - float3(cam.bhX, cam.bhY, cam.bhZ));
        starMix *= smoothstep(4.0f * cam.horizonR, 32.0f * cam.horizonR, rBHs);
    }
    // [KPROBE] (2026-07-28) captured for the Kelvin histogram at the end of this
    // shader. 0 = the star branch never ran for this particle, so it is excluded
    // from the histogram entirely (it emitted no starlight to attribute).
    float probeKelvin = 0.0f;
    if (starMix > 0.001f) {
        float Mstar = min(in.posW.w, 500.0f);            // M_sun, merger-grown
        float Lstar = pow(Mstar, cam.tuneStarLumExp);               // L_sun (dialed 2026-07-28, was 3.5)
        float Rstar = pow(Mstar, cam.tuneStarSizeExp);              // R_sun (size; dialed 2026-07-28, was 0.8)
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
        // DIALED 2026-07-28: A and p were hardcoded 5772 / 0.55. Same numbers by
        // default — this is plumbing, not a law change.
        // UNIFIED 2026-08-02: THE one law, identical to the play path above.
        // This path had no heat term at all (removed 2026-07-10) while play
        // kept it — the divergence that made colour state-dependent.
        float kelvinU = unifiedKelvin(Mstar, temp,
                                      dot(in.velW.xyz, in.velW.xyz),
                                      cam.tuneStarKelvinA, cam.tuneStarKelvinP,
                                      cam.tuneHeatK, cam.tuneColorK);
        probeKelvin = kelvinU;   // [KPROBE]
        // ── SPECTRAL COLOUR LAW (bit16, increment 2, 2026-07-24) ───────────
        // Replaces the Tanner-Helland blackbody FIT with the real Planck
        // integral over the band set (spectral_lut.h / [SPEC-LUT]). Same
        // convention as blackbodyRGB — max-channel normalised, 0..1 — so the
        // LUMINANCE AND SIZE LAWS ARE UNTOUCHED (spec §2) and Lupton holds:
        // brightness never recolours. g = 1 and lineStrength = 0 here; the
        // lines come back at increment 3 through lineStrength, and g becomes
        // live when the BH window calls the same function per ray sample.
        // Measured difference at 5772 K: fit gives (1.000,0.950,0.904),
        // the Planck band integral gives (1.000,0.922,0.668) — warmer, less
        // blue. That is the expected visible change, not a regression.
        // INCREMENT 3 (2026-07-24): the spectral call moved BELOW the gas block
        // so it can consume lineStrength, which the gas block now computes.
        // bit16 OFF keeps the old fit here and the old ramp mix below.
        float3 starColor = blackbodyRGB(kelvinU);
        float  lineStrength = 0.0f;   // 0 = pure continuum; set by the gas block
        // ── GAS STATE (design §2, increment 2 — 2026-07-23 04:38): one
        // population, two render states, per-particle — NO global phase gate.
        // The light IMF bulk (M≲2, "they ARE the gas") glows with the
        // shock-ionization emission-line spectrum WHERE the local medium is
        // excited (dense + warm); isolated dwarfs and every massive star keep
        // the honest mass-blackbody. Excitation reads TRILINEAR density from
        // the hash grid (own-cell counts = square hue patches, the 07-19
        // de-block lesson) blended with the particle's own temp. HUE ONLY —
        // luminance/size laws untouched, so no new overdraw and the Lupton
        // rule (brightness never recolors) survives.
        // PERF: the secondary lensed instance skips the 8-read trilinear —
        // its fold-over image is heavily attenuated (imageWeight), hue
        // precision there is invisible, and at hole-state it doubled the
        // most expensive pass in the app.
        if (su.gridSize > 0 && !isSecondary && in.posW.w < 3.0f) {
            // physPosW, not in.posW: the pose playback rotates in.posW but the
            // density grid is in physics space (the "overlay" bug fix).
            float3 gp = (physPosW + su.halfExtent) * su.invCellSize - 0.5f;
            int3  c0 = int3(floor(gp));
            float3 f = gp - float3(c0);
            float triCount = 0.0f;
            for (int dz = 0; dz <= 1; dz++)
            for (int dy = 0; dy <= 1; dy++)
            for (int dx = 0; dx <= 1; dx++) {
                int3 cc = clamp(c0 + int3(dx, dy, dz),
                                int3(0), int3(su.gridSize - 1));
                float w = (dx ? f.x : 1.0f - f.x) *
                          (dy ? f.y : 1.0f - f.y) *
                          (dz ? f.z : 1.0f - f.z);
                triCount += w * float(cellCounts[
                    uint((cc.z * su.gridSize + cc.y) * su.gridSize + cc.x)]);
            }
            // Rest grid = ±64 at 128³ → cell 1.0³; the r≈40-70 shell runs
            // ~1-2/cell, so only genuine clumps (clusters, the collapse knot,
            // stream cores) excite. Sparse space stays blackbody-honest.
            // DE-SATURATED 2026-07-23 15:58 (Jamal: "still the same feel,
            // blue way larger than the hole"). The old 2..16 range pegged
            // exc=1 across the whole inner field → one flat cyan, and on the
            // view-anchored lens arch a flat color reads as a DECAL. Spread
            // density across the full ramp instead: most excited gas sits
            // Hα red/orange (real HII regions are red), teal/cyan only in
            // genuine dense cores. Varied color = the arch reads as body.
            float exc     = smoothstep(3.0f, 90.0f, triCount);
            float gasMass = 1.0f - smoothstep(1.5f, 3.0f, in.posW.w);
            float tN      = clamp(temp * (1.0f / 5.0f), 0.0f, 1.0f);
            // PER-PARTICLE TURBULENT MIXING (2026-07-23 16:38, Jamal: "the
            // yellow stuff still there" — his shots show it's not a sprite,
            // it's THOUSANDS of particles painted the same mid-ramp yellow).
            // Hue purely as f(density) makes each density band ONE monotone
            // colour ZONE (teal arms / yellow core) that reads as paint
            // attached to the hole. Real nebulae are turbulently mixed:
            // deterministic per-particle scatter on ramp position + blend
            // strength breaks the bands into natural mottle. Stable per id —
            // no flicker, the variation rides each particle.
            float h1 = fract(sin(float(vid) * 12.9898f) * 43758.5453f);
            float h2 = fract(sin(float(vid) * 78.233f) * 12543.853f);
            float3 gasCol = supernovaRamp(
                clamp(0.08f + 0.42f * exc + 0.25f * tN + (h1 - 0.5f) * 0.22f,
                      0.0f, 0.8f));
            // Engage the gas hue early (any excitation shifts hue off pure
            // blackbody) while the ramp POSITION stays low → red/orange.
            // ── INCREMENT 3 (bit16): SAME GATE, NEW TARGET ──────────────────
            // The supernovaRamp hue mix is retired. exc/tN drove a RAMP
            // POSITION — a lookup that REPLACED the continuum, which is why it
            // read as paint and pegged whole clumps to one hue. They now drive
            // the LINE-TO-CONTINUUM RATIO, so the lines are ADDED over the
            // blackbody as flux, which is what the physics does. Same threshold
            // mechanism the code already had (threshold, not phase — canon);
            // only its output target changed. Stated honestly: this is a proxy
            // for emission measure × ionisation, NOT a Saha calculation.
            //
            // The ×4 on exc is DROPPED. It existed to "engage the gas hue
            // early" because hue came from ramp POSITION, so a low position had
            // to be pushed off pure blackbody to show anything. With a ratio, a
            // low value already means "mostly continuum" — the early-engage is
            // not just unnecessary, it is what saturated exc at triCount≈25 and
            // pegged whole clumps. lineStrength now tracks exc directly across
            // its full 3→90 range, so only GENUINELY dense cores go
            // line-dominated. This is the dial to move if the verdict is
            // "too much" or "too little".
            //
            // MOTTLE STAYS KEYED TO vid, DEVIATING FROM THE SPEC (§3, "the
            // particle path hashes position"). Hashing the live position
            // re-hashes every frame as the particle moves = flicker, which is
            // exactly what the 2026-07-23 16:38 note above says vid-keying
            // fixed. The contract that matters is unaffected: spectrumToBands
            // stays a pure 3-scalar map with no vid — the mottle is applied by
            // the CALLER, outside it, so the ray-march is free to hash its
            // sample point instead.
            if (cam.bhToggles & 0x10000u) {
                lineStrength = gasMass
                             * clamp(exc + tN * 0.3f, 0.0f, 1.0f)
                             * (0.6f + 0.4f * h2);
            } else {
                starColor = mix(starColor, gasCol,
                                gasMass * clamp(exc * 4.0f + tN * 0.3f, 0.0f, 1.0f)
                                        * (0.6f + 0.4f * h2));
            }
        }

        // ── THE ONE COLOUR LAW (bit16) ──────────────────────────────────────
        // Continuum + lines in a single band-integrated evaluation. Max-channel
        // normalised, matching blackbodyRGB's convention, so the luminance and
        // size laws stay untouched (spec §2) and Lupton holds. g = 1 here; it
        // goes live when the BH window calls the same function per ray sample
        // with its own shift factor.
        if (cam.bhToggles & 0x10000u) {
            float3 sb = spectrumToBands(specContLUT, specLinesLUT,
                                        kelvinU, 1.0f, lineStrength);
            starColor = sb / max(max(sb.r, max(sb.g, sb.b)), 1e-20f);
        }
        // ── ACCRETION-DISK T(r) — Shakura–Sunyaev (2026-07-23 18:20, Jamal:
        // "two halves, green and yellow, cut with a knife — the culprit of
        // the colours around the black hole"). The knife edge was the gas
        // excitation BANDS meeting at the hole. A real disk has no bands:
        // its colour IS its temperature profile, T ∝ r^(−3/4), CONTINUOUS —
        // white-hot at the inner edge cooling to deep orange-red outward
        // (the reference image's palette is exactly this law; approved plan:
        // anchor M87*, S–S T(r), blackbody RGB). Inside the disk zone the
        // radial law replaces the banded hue. Luminance law untouched.
        if (cam.horizonR > 0.0f) {
            float2 relD = in.posW.xy - float2(cam.bhX, cam.bhY);
            float rD = length(relD);
            float zD = fabs(in.posW.z - cam.bhZ);
            float dzone = smoothstep(cam.horizonR, cam.horizonR * 1.6f, rD) *
                          (1.0f - smoothstep(8.0f * cam.horizonR,
                                             16.0f * cam.horizonR, rD)) *
                          (1.0f - smoothstep(2.0f * cam.horizonR,
                                             5.0f * cam.horizonR, zD));
            if (dzone > 0.01f) {
                float rIn   = cam.horizonR * 1.5f;   // ISCO-ish inner edge
                float Tdisk = 26000.0f * pow(rIn / max(rD, rIn), 0.75f);
                starColor = mix(starColor,
                                blackbodyRGB(clamp(Tdisk, 1500.0f, 26000.0f)),
                                dzone);
            }
        }
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
        // ── THE CLIP WAS THE FLATTENER (2026-07-26 21:52:40) ────────────────
        // WAS: min(Lstar * 2.5f, 1000.0f). Lstar = M^3.5, so the cap binds at
        // M^3.5 * 2.5 = 1000 => M ~ 5.5 M_sun. EVERY star above 5.5 M_sun came
        // out at EXACTLY 1000 — and those are precisely the ones bright enough
        // to see, so the entire visible population was one single brightness,
        // then bleached to one single white. Jamal 21:45, after the spike test:
        // "ok fewer diamonds but just the shape changed not the brightness or
        // color." Shape was never the complaint; this is.
        // The old comment defended it as "a handful of stars dominate" — true
        // for a handful, but at 2-10M particles the >5.5 M_sun population is
        // thousands of bodies, all clipped identical. A hard min() destroys the
        // ordering BEFORE the tonemap, so no display transform can recover it;
        // that is also why postfx being a hue-preserving max-channel tonemap
        // (already true) never fixed the whitening.
        // NOW: Lupton 2004 asinh softening — the VERIFIED reference already on
        // file (reference_stellar_render_sources). asinh is linear at the faint
        // end and logarithmic at the bright end, so it PRESERVES the exposure
        // calibration exactly where it was tuned and only compresses where the
        // clip used to amputate:
        //   M=1  -> 2.5   (unchanged: the sun-type calibration point)
        //   M=2  -> 28    (unchanged)
        //   M=5  -> 437   (was 699)
        //   M=10 -> 1036  (was 1000, clipped)
        //   M=50 -> 2444  (was 1000, clipped)
        //  M=500 -> 4450  (was 1000, clipped)
        // Ordering now survives across the whole mass range instead of pinning.
        // Peak rises ~4.5x over the old 1000 "full well". Half-float additive
        // accumulation is fine with that (max 65504) and the auto-exposure iris
        // has the travel since its floor went 0.05 -> 0.01 earlier today. If it
        // blooms too hot, LOWER kLumSoft — do not put the min() back.
        // REVERTED 2026-07-26 21:53:10 — asinh made it WORSE on sight (Jamal:
        // "now they all look like theyre not supposed to"): plain round white
        // dots. Raising the peak 1000 -> 4450 pushed MORE stars past the sensor
        // bleach, so hue was destroyed in more of the field, not less. The clip
        // is ugly but it BOUNDS the saturation. The real lesson from the A/B:
        // colour never changed across the spike gate, spike=0, OR asinh — so
        // the whiteness does not live in the luminance path at all. Do not
        // re-try this until the bleach/hue path is understood; then it may be
        // the right change with the ceiling handled downstream.
        // ── MEASURED 2026-07-28 12:23 ([KPROBE], 23.8k samples/frame) ────────
        // 73% of stars are below 2515 K and deliver 15% of the light; ~1% are
        // above 10,000 K and deliver 75%. A 15,905 K star counts 108x its
        // abundance on screen, a 1,586 K star 0.2x. So the field's hue is NOT
        // dying downstream — the orange stars are there and this law makes them
        // invisible. The lever is tuneStarLumExp: LOWERING it compresses the
        // M-to-L range and lifts the faint end into view. That is the opposite
        // direction from the 07-26 asinh attempt, which raised the bright end
        // (peak 1000 -> 4450), pushed more pixels into the sensor bleach and
        // made it worse WITHOUT lifting a single dwarf. Do not raise the ceiling
        // to fix colour; lower the exponent.
        float starLum = min(Lstar * cam.tuneStarLumGain, cam.tuneStarLumCeil);
        // SIZE = the approved law (Checkpoint A1): linear in the true stellar
        // radius R∝M^0.8, tanh soft ceiling so ordering survives at any slider
        // setting (bbbe6c8, Jamal: "looks amazing"). The saturation-PSF law
        // (99.9% of stars at exactly 1px) is out — his on-screen verdict:
        // "all stars weirdly the same size".
        // ── MEASURED 2026-07-28 15:21 ([KPROBE-SCALE]) ───────────────────────
        // meanPx = 1.02, maxPx = 16.3, and 99.2% of all stars land in the
        // 0.92-1.41 px bin. They are not spread across it — they are PINNED to
        // STAR_MIN_PX by the max() below. With the Kroupa mode at 0.087 M_sun,
        // Rstar = 0.087^0.8 = 0.142, so rawStar is ~0.14 px and the floor takes
        // over for the entire dwarf bulk.
        // Note the irony recorded in the comment above: the saturation-PSF law
        // was REMOVED because it put "99.9% of stars at exactly 1px" and Jamal
        // said "all stars weirdly the same size". This floor reintroduced the
        // identical condition through a different door, and it has been the
        // state ever since.
        // A 1 px sprite cannot carry hue and cannot show a core — which is why
        // raising brightness only grows the spike cross ("all looks like only
        // diamonds", 2026-07-28).
        float rawStar = cam.particleSize * Rstar * sizeScale * 0.5f
                        * cam.tuneStarSizeGain;
        float starSize = max(cam.tuneStarSizeCeil
                             * tanh(rawStar / max(cam.tuneStarSizeCeil, 1e-3f)),
                             cam.tuneStarSizeFloor);
        // ── MERGER FLASH — the "sense of collision" ──────────────────────────
        // A star that just ATE carries a temperature spike (merge kernel,
        // base 2.0 + violence) that the T⁴ cooling decays over seconds:
        // luminance surge, colour shifted hot, size pulse. Threshold 2.5
        // sits ABOVE the post-play residual heat (~1-2) — a played note must
        // not paint the whole field as novae; the rest look returns as the
        // field cools, only true fresh mergers flash.
        float flashT = clamp(temp - 2.5f, 0.0f, 5.0f);
        // ── NOVA STANDS DOWN IN THE ACCRETION DOMAIN (2026-07-24 00:12,
        // Jamal: "the ring still gives low res"). MEASURED with the [BALANCE]
        // flash/hot columns: in the disk shells (r≈2–8) 78–85% of particles
        // sit permanently above the 2.5 flash threshold (mean flash 1.25–1.75)
        // — so EVERY ring particle carried a permanent +5–7px swell and a
        // ×25–35 luminance surge. That is the fat, blown-out "low res" ring.
        // The threshold was calibrated (06-26) to clear post-play residual
        // heat; nobody had measured that ACCRETING matter is chronically
        // hotter than it. A nova is a TRANSIENT merger event out in the
        // field; the disk's continuous shock heat is not one — its light is
        // already rendered honestly by the T(r) blackbody law above. So the
        // swell fades out inside the hole's accretion domain and stays fully
        // alive everywhere else (real mergers keep flashing).
        if (cam.horizonR > 0.0f) {
            float rBHf = length(in.posW.xyz -
                                float3(cam.bhX, cam.bhY, cam.bhZ));
            flashT *= smoothstep(16.0f * cam.horizonR,
                                 32.0f * cam.horizonR, rBHf);
        }
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
    // STAND-DOWN WIRED (2026-07-23 16:25, Jamal: "a yellow thing, unnatural,
    // attached to the black hole, super low-res, tilting with the camera").
    // This blob is ONE billboard sprite; at a 5e5 M☉ core its R∝M^0.8 size
    // pins the 220px cap = the giant pale wedge (the hole pass bites the
    // circle out of it). Its own comment always said the honest shadow
    // "takes over once the geometric signal trips" — now it actually does:
    // once the honest horizon exists, the blob stands down and the hole is
    // ONLY the particles + lens (BH core directive).
    if ((cam.bhToggles & 0x80u) && in.posW.w >= 50.0f && starMix > 0.5f &&
        cam.horizonR <= 0.0f) {  // bit7: seed render (pre-horizon only)
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
        // ── PLAY-PHASE GAS SPLAT DISABLED — 2026-07-30 02:2x ────────────────
        // THE SHARPNESS REGRESSION. Located by building 0edde58 (2026-07-18,
        // pre-eigenmode) and comparing on screen: that build draws thin bright
        // filaments and discrete sparkling points — Jamal's reference, "harry
        // potter vs voldemort wand flashes" — and he confirmed "this lvl of
        // detail is non existent in the new version".
        //
        // This block landed 2026-07-19 23:44 in 1bb9c70, the commit he named.
        // The old expression was:
        //   gasNess = smoothstep(0.5, 1.5, cam.envelopePhase)
        //           * (1 - smoothstep(1.5, 3.0, clamp(in.posW.w, 0.05, 500)));
        // i.e. gated on ENVELOPE PHASE (play only) and on mass ≲2 M☉ — which
        // this block's own comment puts at ~90% of the field. It then applied,
        // to nine tenths of the particles, only while playing:
        //   pointSize ×3, luminance ÷9, and Gaussian falloff 5.0 → 1.2.
        // The falloff is the decisive one: a tight core becomes a wide soft
        // cloud. That is why the uiParticleSize dial could not fix it — the
        // dial scales the base size, GAS_SPREAD multiplies on top, and
        // sharpness=1.2 keeps every dot soft at any size. It is also why every
        // physics-side change measured "unchanged": the render widened and
        // softened whatever the physics delivered.
        //
        // A LATER SESSION FOUND THE SAME BUG AND HALF-FIXED IT: the near-hole
        // copy directly below is behind bit17, default OFF, with the comment
        // "this block is the prime suspect and it is MINE". The play-phase copy
        // was left on and never gated. This completes that fix.
        //
        // TO RESTORE the gaseous play look, put the two smoothsteps back.
        // The bit17 accretion path below is UNTOUCHED and still works —
        // it raises gasNess via max(), so it is independent of this line.
        float gasNess = 0.0f;
        // ── ACCRETION MATTER IS GAS, NOT STARS (2026-07-24 11:40, Jamal:
        // "we want the gaseous form for particles near the horizon, not
        // stars at all"). Matter falling onto the hole is tidally shredded
        // plasma — a fluid, not discrete suns. So inside the accretion
        // domain the gas kernel fires REGARDLESS of play phase or mass:
        // every disk particle spreads into a soft flux-conserving splat and
        // overlapping splats fuse into a continuous gaseous ring. Field
        // stars (r ≫ horizon) stay sharp points. Ramp in from 32→4 horizon
        // radii so the transition from starfield to gas is smooth.
        // ── A/B GATE (bit17, 2026-07-24) — IS THIS THE "FUZZY AND BLURRY"? ──
        // Jamal: play forces particles into the shape and makes "the sharp
        // lines we love", but the hole "is still just fuzzy and blurr". This
        // block is the prime suspect and it is MINE, from 11:40 today: inside
        // 4 r_h (ramping out to 32) it multiplies pointSize x3, divides
        // luminance by 9, and drops the Gaussian falloff exponent from
        // cam.sharpness (5.0) to 1.2 — a deliberate blur applied to exactly
        // the region he is calling blurry. He asked for "the gaseous form near
        // the horizon" and this delivered it as SOFT WIDE SPLATS, which is a
        // different thing from sharp coherent lines.
        // OFF (default) = near-hole matter renders as sharp as the field.
        // ON = today's gaseous softening, unchanged.
        if ((cam.bhToggles & 0x20000u) && cam.horizonR > 0.0f) {
            float rBHg = length(in.posW.xyz -
                                float3(cam.bhX, cam.bhY, cam.bhZ));
            float accGas = 1.0f - smoothstep(4.0f * cam.horizonR,
                                             32.0f * cam.horizonR, rBHg);
            gasNess = max(gasNess, accGas);
        }
        if (gasNess > 0.01f) {
            const float GAS_SPREAD = 3.0f;
            float spread = 1.0f + (GAS_SPREAD - 1.0f) * gasNess;
            out.pointSize = min(out.pointSize * spread, 150.0f);
            out.luminance /= (spread * spread);
            out.sharpness  = mix(cam.sharpness, 1.2f, gasNess); // soft kernel
        }
    }
    out.grainAlpha = cam.grainAlpha;

    // ── SPHERE+CYLINDER HORIZON CULL — DELETED 2026-08-11 04:11:00 ───────────
    // Deleted a `bool bhVisible = false;` block whose body could therefore never
    // run. It punched an elliptical void that wobbled with the camera ("the weird
    // shadow upon rotation") and was disabled — but not removed — when the
    // billboard went; the darkness comes from the lens + the seed having eaten
    // the plunge zone, which is physics rather than deletion. Its `rXYcull =
    // length(in.posW.xy)` was still evaluated for every vertex of every frame
    // ahead of a constant-false gate. Note if this is ever revived: the test was
    // a 2D XY radius, so it culled a polar CYLINDER, not a sphere.

    // ── [KPROBE] KELVIN HISTOGRAM (2026-07-28) — MEASUREMENT ONLY ────────────
    // Question it answers, and ONLY this one: what Kelvin does the light on
    // screen actually COME FROM — as opposed to what Kelvin exists in the field?
    // §3.2 of the 07-28 handoff says the hue is computed correctly and lost
    // downstream. blackbodyRGB was checked by hand this session and is fine
    // (2944K→orange, 14140K→blue-white), so the surviving candidate is that the
    // VISIBLE POPULATION is selection-biased blue: starLum = M^3.5 means only
    // high-mass (= high-Kelvin) stars are bright enough to see, and dwarfs sit
    // at 0.037. If that is what is happening, §3.2 and §3.3 are ONE bug.
    //
    // Three histograms over the same 16 log-spaced Kelvin bins (1000..40000 K):
    //   [0..15]  raw COUNT           — what Kelvin EXISTS
    //   [16..31] LUMINANCE-weighted  — what Kelvin the light comes from
    //   [32..47] luminance×AREA      — same, but paying for sprite footprint
    // A broad count histogram against a blue-spiked luminance histogram is the
    // signature of the population bias. If BOTH are broad, the hue really is
    // dying downstream and this hypothesis is dead — which is equally useful.
    //
    // Cost: every 64th particle, primary instance only (the secondary is the
    // same matter counted twice) ≈ 15k atomics/frame at 1M, not 1M. Nothing here
    // is read back into the picture — `out` is already final above this point.
    // ── PHASE TINT — his order 2026-08-24: "the phase thingy needs to be
    // standard on" ─────────────────────────────────────────────────────────
    // Applied HERE, after BOTH regimes have written out.color: the play path
    // (:1866) and the star-map mix (:2322). One site, so Chladni and the
    // starfield get the SAME treatment — that is the unification, not two
    // copies of one effect.
    // 🚨 HUE ONLY. The tint takes its VALUE from the base colour's max
    // channel, so brightness is carried through untouched. Lupton holds:
    // brightness never recolours and colour never rebrightens. Replacing the
    // colour outright (the old behaviour) broke that in both directions.
    // cam.phaseViz is now an AMOUNT in 0..1, not a 0/1 switch.
    if (cam.phaseViz > 0.001f) {
        // TRUE HUE ROTATION, not an RGB mix. S and V are carried through
        // UNCHANGED, so the tint can only move hue — it cannot desaturate a
        // star, cannot brighten one, and cannot wash the field toward grey.
        // (The first version mixed in RGB and did all three: measured 24.8%
        // of lit pixels pushed to white/grey at amount 0.35, 2026-08-24.)
        float3 hsvB = rgb2hsv(out.color);
        float  hueP = (phase + M_PI_F) * (1.0f / (2.0f * M_PI_F));
        // shortest way round the circle, so a hue near 0.99 rotates toward
        // 0.01 forwards rather than sweeping the whole wheel backwards
        float dh = hueP - hsvB.x;
        dh -= floor(dh + 0.5f);
        float h = fract(hsvB.x + dh * clamp(cam.phaseViz, 0.0f, 1.0f) + 1.0f);
        out.color = hsv2rgb(h, hsvB.y, hsvB.z);
    }

    if ((vid & 63u) == 0u && !isSecondary && probeKelvin > 0.0f) {
        // log2(40000/1000) = log2(40) = 5.321928
        float u   = log2(probeKelvin / 1000.0f) * (1.0f / 5.321928f);
        uint  bin = uint(clamp(u * 16.0f, 0.0f, 15.0f));
        // lum×64: keeps the full 27,000:1 span inside uint32 while still
        // resolving a 0.037 dwarf as 2 rather than truncating it to zero.
        uint qLum  = uint(clamp(out.luminance, 0.0f, 1000.0f) * 64.0f);
        // Saturates at 65535 for the very brightest+biggest sprites. That bias
        // UNDERSTATES the bright end, i.e. it argues against the hypothesis —
        // so a blue spike that survives this clamp is real.
        uint qArea = uint(min(out.luminance * out.pointSize * out.pointSize,
                              65535.0f));
        atomic_fetch_add_explicit(&kProbe[bin],            1u,    memory_order_relaxed);
        atomic_fetch_add_explicit(&kProbe[16u + bin],      qLum,  memory_order_relaxed);
        atomic_fetch_add_explicit(&kProbe[32u + bin],      qArea, memory_order_relaxed);
        atomic_fetch_add_explicit(&kProbe[48u],            1u,    memory_order_relaxed);
        if (out.pointSize <= 0.0f)
            atomic_fetch_add_explicit(&kProbe[49u],        1u,    memory_order_relaxed);

        // ── SCALE (2026-07-28, his ask: "the SCALE of weight is still issue…
        // if jacked up all looks like only diamonds… maybe our scale should be
        // checked"). §4 of the handoff has said since 07-26 that avgPtSize at
        // his real zoom has NEVER been measured. These two histograms are that
        // number. out.pointSize is in PIXELS (Metal [[point_size]]), so this is
        // literally how many pixels each star covers on his screen.
        //   [50..65] sprite size, 16 log2 bins over 0.25 px .. 256 px
        //   [66..81] mass,        16 log10 bins over 0.01 .. 1000 M_sun
        //   [82] max size x100 (atomic_max)   [83] sum size x100 (-> mean)
        if (out.pointSize > 0.0f) {
            float su2 = clamp((log2(out.pointSize) + 2.0f) * (16.0f / 10.0f),
                              0.0f, 15.0f);
            atomic_fetch_add_explicit(&kProbe[50u + uint(su2)], 1u,
                                      memory_order_relaxed);
            uint qsz = uint(min(out.pointSize * 100.0f, 1.0e7f));
            atomic_fetch_max_explicit(&kProbe[82u], qsz, memory_order_relaxed);
            atomic_fetch_add_explicit(&kProbe[83u], qsz, memory_order_relaxed);
        }
        // ── G2 PRE-CLAMP SIZE (2026-08-22) — MEASUREMENT ONLY ───────────────
        // The [50..65] histogram bins `out.pointSize`, which is POST-clamp
        // (`drawn = clamp(rawSize, 1.0f, zoomCap)`). Every floored star lands
        // at exactly 1.0 px, i.e. in bin 3, so that histogram CANNOT tell
        // "rawSize 0.46, floored" from "rawSize 1.2, natural" — which is why
        // the 96%-in-one-bin reading has never settled what actually drives it.
        // These slots bin rawSize BEFORE the clamp, on the same log2 ladder and
        // inside the same every-64th gate, so the two are directly comparable.
        //   [84..99] rawSize, 16 log2 bins over 0.25 px .. 256 px
        //   [100] count floored (rawSize < 1)   [101] count capped (rawSize > zoomCap)
        //   [102] sum rawSize x100 (-> mean). No atomic_min: the buffer is
        //   zero-cleared each frame, so a min would always report 0.
        // Nothing here is read back into the picture.
        if (rawSize > 0.0f) {
            float ru = clamp((log2(rawSize) + 2.0f) * (16.0f / 10.0f), 0.0f, 15.0f);
            atomic_fetch_add_explicit(&kProbe[84u + uint(ru)], 1u,
                                      memory_order_relaxed);
            if (rawSize < 1.0f)
                atomic_fetch_add_explicit(&kProbe[100u], 1u, memory_order_relaxed);
            if (rawSize > zoomCap)
                atomic_fetch_add_explicit(&kProbe[101u], 1u, memory_order_relaxed);
            uint qraw = uint(min(rawSize * 100.0f, 1.0e7f));
            atomic_fetch_add_explicit(&kProbe[102u], qraw, memory_order_relaxed);
        }
        float mB = clamp((log10(max(in.posW.w, 1.0e-4f)) + 2.0f) * (16.0f / 5.0f),
                         0.0f, 15.0f);
        atomic_fetch_add_explicit(&kProbe[66u + uint(mB)], 1u, memory_order_relaxed);
    }

    // ── A9: EXTINCTION — DENSITY REMOVES LIGHT (2026-08-10 20:14:00) ─────────
    // His question, and it is the right one: "why does matter at high
    // concentrations look like ass. it's supposed to look amazing."
    //
    // Because until this block, density could only ever ADD light. The particle
    // pass blends One+One (renderer.mm:658-663), so N particles in a pixel is N×
    // the light without bound: every dense region climbs to saturation and
    // flattens into a white lump with no interior structure and no depth cue.
    // In real astronomy images essentially ALL the structure inside a dense
    // region comes from what BLOCKS light — dust lanes, silhouettes, reddened
    // cores, and the bright rims where an absorbing body cuts into a glow.
    // Emission alone cannot produce any of those shapes.
    //
    // The dust pass (dust_vertex below) already implements absorption and is
    // DISABLED at renderer.mm:3504. It was killed on his field verdict
    // 2026-07-23 16:34 ("a low-res shadow thingy / yellow underbelly") because
    // it COMPOSITES absorbing splats over the additive image while UN-DEPTH-
    // SORTED — so instead of a silhouette it painted a flat bounded wash.
    //
    // ⭐ This does the same physics WITHOUT compositing, so the thing that killed
    // v1 cannot recur: march the density grid from this particle TOWARD THE
    // CAMERA, accumulate optical depth τ, and scale THIS PARTICLE'S OWN emission
    // by exp(−τ). Multiplying a particle's own luminance is ORDER-INDEPENDENT by
    // construction — there is no blend order to get wrong and no second pass.
    // Lanes and rims appear on their own: the far side of a clump is attenuated
    // by the near side, which is exactly what extinction is.
    //
    // COORDINATES: the march runs in PHYSICS space, where the hash grid is
    // indexed (physPosW, per the note at the top of this function — sampling
    // density at render-rotated coords made the hue a static decal). The camera
    // direction is world-space, so applyInverseSpin maps it back — the exact
    // inverse written for the metric ray on 2026-07-25, reused rather than
    // re-derived.
    // ⭐ Direction comes from cam.viewForward (F5) instead of
    // normalize(-cameraPos), so this stays correct the moment the camera stops
    // looking at the origin. First real consumer of F5 beyond the no-op.
    //
    // ⚖️ kAbsorb and the 6 steps are FIRST VALUES, not derived, and the per-cell
    // count is clamped to 128 (the same MAX_PER_CELL ceiling the flare stress
    // uses) so an uncapped 50k core cannot drive τ to infinity and punch an
    // absolute black hole in the image. Ceiling: τ_max = 6·128·0.004 ≈ 3.07,
    // i.e. at most ~95% absorbed. Turn kAbsorb up for heavier dust.
    if (su.gridSize > 0 && out.pointSize > 0.0f && out.luminance > 0.0f) {
        float3 dWorld = -float3(cam.viewForwardX, cam.viewForwardY, cam.viewForwardZ);
        float3 dPhys = applyInverseSpin(dWorld, cam.spinAngleX, cam.spinAngleY,
                                        cam.spinAngleZ);
        float dLen = length(dPhys);
        if (dLen > 1e-6f) {
            dPhys /= dLen;
            const int   kSteps  = 6;
            const float kAbsorb = 0.45f;          // optical depth per FULLY DENSE step
            float stepLen = 1.5f * su.cellSize;   // 1.5 cells per step
            // ⚠️ v1 (20:47:36) used `tau += 0.004 * min(cnt,128)` — RAW COUNT, no
            // threshold. MEASURED WRONG before he ever saw it: [LUMPROBE] avgRGB
            // fell 0.443/0.637/0.755 → 0.210/0.304/0.364 on the SAME 2M field at
            // rest, i.e. it dimmed the WHOLE SCENE by 53% including the sparse
            // star map. That is a global dimmer, not structure.
            // Fix: threshold each sample the way the dust shader already does —
            // `smoothstep(6,30)`, whose own comment reads "only genuinely dense
            // BODIES absorb; the ambient diffuse keeps glowing". Reusing the
            // project's calibrated number instead of inventing a second one.
            float tauN = 0.0f;                    // dimensionless column, 0..kSteps
            for (int s = 1; s <= kSteps; ++s) {
                float3 sp = physPosW + dPhys * (stepLen * float(s));
                if (max(max(abs(sp.x), abs(sp.y)), abs(sp.z)) >= su.halfExtent)
                    break;   // outside the hash extent the border cells are garbage
                float3 g = (sp + su.halfExtent) * su.invCellSize;
                int3 c = clamp(int3(g), int3(0), int3(su.gridSize - 1));
                float cnt = float(cellCounts[
                    uint((c.z * su.gridSize + c.y) * su.gridSize + c.x)]);
                // ⚠️ THIRD VALUE, AND THE FIRST TWO WERE MEASURED WRONG — both
                // before he saw either. `smoothstep(6,30)` (borrowed from the
                // dust shader) still dimmed the whole scene: [LUMPROBE] gave
                // transmission R .392 / G .315 / B .257 at rest, and inverting
                // it says the mean column was tauN≈3.0 of a possible 6 — i.e.
                // HALF of every sightline was reading "fully dense". That
                // threshold works in the dust shader only because it ALSO gates
                // on cold + gas-mass, which rejects most particles before the
                // density ever matters; lifted on its own it catches everything.
                // The grid's real dynamic range is wide — the flare code clamps
                // to MAX_PER_CELL=128 and warns an uncapped cell hits ~50k — so
                // "genuinely dense" for an UNGATED march has to sit far higher.
                // His question was specifically about matter at HIGH
                // CONCENTRATION; this now triggers only there and leaves the
                // ordinary star map alone.
                tauN += smoothstep(150.0f, 1500.0f, cnt);
            }
            // ⭐ PER-CHANNEL — this is what makes dust read as DUST. v1 scaled the
            // scalar `luminance`, so it could only ever grey the image down:
            // measured R/G/B transmission 0.474 / 0.477 / 0.482 — flat, no colour
            // signature at all. Real extinction absorbs BLUE hardest, so whatever
            // shines through REDDENS, and that reddening is most of why a dust
            // lane looks like a dust lane. The disabled dust pass says the same
            // thing in its own header (render.metal, DUST EXTINCTION PASS §2b).
            // Applied to out.color because the fragment forms the final emission
            // as `in.color * in.luminance` (grep `float3 emission = in.color`),
            // so a per-channel factor here lands correctly and exactly once.
            float3 kExt = float3(0.55f, 0.78f, 1.00f) * kAbsorb;
            out.color *= exp(-tauN * kExt);
        }
    }

    // ── S2: REFERENCE PIXELS → DEVICE PIXELS. THE ONLY CONVERSION. ─────────
    // (2026-08-21, his order: "normalize it too we dont want two values for a
    // single thing ever".) The first version multiplied a resScale into
    // rawSize and zoomCap and left FIVE other pixel laws unscaled: the nova
    // pulse (+4px, cap 150), the seed sprite (clamp 3..220), the gas spread
    // cap (150), and the tuneStarSizeCeil/Floor dials. Six values for one
    // quantity — exactly the split this project exists to kill.
    //
    // THE LAW: every pixel quantity above is in REFERENCE pixels — pixels as
    // seen on a 2260-tall drawable, the height he tunes at. Caps, floors,
    // pulses and dials all live in that one space, so they compare against
    // each other honestly. THIS multiply is where they become device pixels.
    // New size code goes ABOVE this line, in reference pixels, and is
    // normalised for free.
    //
    // Every early return above is a cull that already wrote pointSize = 0
    // (:749 :785 :803 :910 :944 :1852) and 0 * resScale = 0, so those paths
    // need no conversion of their own.
    // == 1.0 at his fullscreen height ⇒ fullscreen unchanged by construction.
    out.pointSize *= max(cam.sizeResScale, 1e-3f);
    return out;
}

// ── THE MOTION-VECTOR OUTPUT (2026-08-20, his order: "we need to touch the
// main star pass") ─────────────────────────────────────────────────────────
// Second render target: how far this star REALLY moved on screen. Not the
// playback rate — that is the time-lapse, and driving a smear with it produced
// the spirograph he rejected at 14:48. This is `velReal + spin`, the physics
// velocity, projected through the CURRENT viewProjection at BOTH ends (:1320),
// so camera motion cancels identically and rotating the camera cannot move it.
struct ParticleFragOut {
    float4 color    [[color(0)]];
    float2 velocity [[color(1)]];   // screen motion in UV, per streak exposure
};

fragment ParticleFragOut particle_fragment(
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
    // FLUID STREAK (bit18): the VERTEX already grew this quad by in.streakLen,
    // so the arc spans the full quad along the motion direction — lengthX is 1
    // in quad units. The quad grew isotropically (point sprites are square), so
    // ACROSS must be narrowed by the same factor to hold the physical width
    // constant: that is what makes a fast particle a long THIN ribbon instead
    // of a big blob. streakLen == 1 for stationary matter → identical to the
    // old round-dot path.
    float sL = max(in.streakLen, 1.0f);
    float elong  = clamp(speed * 1.4f, 0.0f, 1.0f);
    float widthY = (sL > 1.001f) ? (1.0f / sL) : mix(1.0f, 0.12f, elong);
    // ── ALONG-MOTION STRETCH RESTORED — 2026-07-30 02:2x ────────────────────
    // Was `float lengthX = 1.0f;`. In 0edde58 (2026-07-18, the build Jamal
    // verified sharp: "DO U SEE THE LVL OF DETAIL IN THIS", "harry potter vs
    // voldemort wand flashes, which was the reference") this line read
    //     float lengthX = mix(1.0f, 5.0f, elong);   // much longer along
    // Together with widthY = mix(1, 0.12, elong) a moving particle was drawn
    // 5× LONG and 0.12 THIN — a fine bright line. Thousands of those ARE the
    // filament look. Flattening it to 1.0 left only the across-narrowing, so a
    // fast particle became a short dash and the field reads as round grain.
    //
    // It was flattened when bit18 (flux-conserving arc, 2026-07-24) took over
    // elongation by growing the QUAD instead of warping inside it — but bit18
    // has never executed: `sL ≡ 1` for every particle in the app, from a
    // documented uninitialised read of out.pointSize (measured
    // [STREAKPROBE] ptSize=0.0 streakLen=1.00). So the mechanism was removed
    // and its replacement never ran.
    //
    // Branch kept: if bit18 is ever revived (sL > 1) the quad already carries
    // the arc length, so lengthX must stay 1 there. Live path is the else.
    float lengthX = (sL > 1.001f) ? 1.0f : mix(1.0f, 5.0f, elong);

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
    // Window on the WARPED radius, not the raw quad radius: on the raw one a
    // stretched arc got its ends cut off by the very clip this was added to
    // fix (square corners). Elliptical window = smooth ends, no corners.
    float window = 1.0f - smoothstep(0.68f, 0.97f,
                                     (sL > 1.001f) ? length(warped) : length(pc));
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
    // SCALE-AWARE (2026-07-26 12:31:00). The spikes are drawn in the RAW quad
    // coord pc, so they span whatever the quad is — but the quad is grown by
    // in.streakLen (sL) when bit18 is live, which multiplied the cross by the
    // same factor: giant 4-point crosses over the whole star map ("ugly blue
    // sprites", "ugly stripes", 2026-07-25 22:26). The `1 - elong` gate was
    // meant to stop this (its own comment: "so the orbiting disk and supernova
    // streaks stay clean") but elong is computed from SPEED and knows nothing
    // about the quad growth. Divide by sL so the star signature falls off as
    // the sprite stretches into a ribbon: a streak is not a star. Flux-
    // consistent with the emission below, which already divides by sL.
    // NO-OP while bit18 is dead (sL == 1.0 for every particle) — landed alone,
    // ahead of the bit18 re-land, so the two can be judged separately.
    float starness = (1.0f - elong) / sL;   // sL from :1706
    // GROWTH-INVARIANT SPIKE COORD (2026-07-25 23:xx). pc is QUAD-RELATIVE, so a
    // cross drawn in pc has a pixel length equal to the quad half-width — it grows
    // with any bit18 quad growth. That is the giant-crosses / "ugly stripes"
    // defect measured at 21:52 (76% of particles grew ~9.5x, every cross with
    // them). The optics do not care how far the matter moved during the exposure:
    // spike length is a property of the sprite's own radius. sL == lenFac (:934)
    // and the growth is isotropic, so multiplying by sL undoes it exactly and the
    // cross holds a CONSTANT pixel size at any streak length.
    // NOTE this supersedes the "starness must know about sL" plan: scaling the
    // gate would only DIM an oversized cross; this stops it being oversized.
    // sL == 1.0 for every particle today (the bit18 gate at :928 reads
    // out.pointSize before it is assigned, see the comment there), so this line
    // is arithmetically identical to the old one until bit18 is re-landed.
    // ⚠ RESIDUAL: pointSize is also clamped to 400px (:932). Where that cap bites
    // (drawn*lenFac > 400, i.e. deep zoom) the achieved growth is less than sL, so
    // this over-corrects and draws the cross SMALLER than baseline. That is the
    // safe direction — never stripes — so it is left as-is rather than adding a
    // second interpolant to carry the achieved factor.
    // ── SPIKES ARE FOR BRIGHT SOURCES ONLY (2026-07-26 21:38:09) ────────────
    // Jamal 21:33, at 10M particles: "the fucking stars bro we need to tackle
    // em" + "it still looks wrong but its what we need... we need to unify it
    // now". The screenshot is a uniform field of identical 4-point diamonds.
    // MECHANISM: sL == 1 for every particle (bit18 is dead), so `starness`
    // reduced to (1 - elong) — a SPEED gate and nothing else. At rest elong ~ 0,
    // so EVERY particle drew a full-strength cross. The block comment above
    // claims the strength "scales with the star's brightness (in.luminance)",
    // but it does not: `spike` is a fixed 0.6 fraction of each particle's own
    // luminance (see the emission line below), so a dwarf at luminance 0.037 and
    // a giant at 1000 draw the SAME cross shape, just scaled. Relative, never
    // absolute — so the signature that is supposed to say "this one is a star"
    // was stamped on all 10 million.
    // FIX: a real diffraction cross is a property of the TELESCOPE and only
    // appears on sources bright enough to saturate it. Gate on ABSOLUTE
    // luminance. starLum = min(M^3.5 * 2.5, 1000), so this threshold selects
    // by mass: fade in at ~1.5 M_sun, full cross by ~2.6 M_sun. Measured field
    // is ~82% dwarfs below 0.5 M_sun (luminance < 0.22) — those now draw as
    // clean points, which is what lets the gas coat read as ONE surface instead
    // of a carpet of stamps.
    // ⛔ REVERTED 2026-07-28 09:31:05 — the brightness gate above is REMOVED.
    // It was a logical no-op for what can be SEEN (it stripped spikes from
    // dwarfs, but dwarfs are too dim to see; the bright stars filling the screen
    // are exactly the ones it kept) and it left the star path in a state Jamal
    // could no longer reason about: "u need to undo more than u did. its still
    // broken". The star render is now bit-for-bit the pre-2026-07-26 baseline.
    // DO NOT re-add a gate here until the STAR ATTRIBUTE DIALS exist — see the
    // handoff's "the real loophole": every star attribute in this file is a
    // hardcoded constant, so each experiment costs a rebuild and none of them
    // can be A/B'd live. Build the dials first, then tune.
    float2 ps = pc * sL;
    float spikeX = exp(-ps.y * ps.y * 90.0f) * pow(max(0.0f, 1.0f - abs(ps.x)), 1.5f);
    float spikeY = exp(-ps.x * ps.x * 90.0f) * pow(max(0.0f, 1.0f - abs(ps.y)), 1.5f);
    float spike  = max(spikeX, spikeY) * starness;
    // DIAGNOSTIC REMOVED 2026-07-28 09:12:44. `spike = 0.0f` sat here from
    // 21:48 to answer one question and it did: with it forced off Jamal saw
    // "fewer diamonds but just the shape changed not the brightness or color".
    // So SOME of the diamond is this cross and some is the radial core at small
    // sprite size — but neither is the actual complaint, which is that every
    // star is the same brightness and the same colour. Leaving it in turned the
    // field into plain dots ("turn them back into stars theire just dots rn").
    // Spikes are back on, gated by kSpikeLumKnee/kSpikeLumFull above.

    // Emission multiplier reduced 1.8 → 0.5. With G=20 gravity, particles
    // orbit fast and the velocity-aligned streaks pile up under additive
    // blending → field saturated to white everywhere. Lower per-particle
    // emission lets dense regions glow bright but sparse stay dim, so the
    // BH void and disk structure remain visible against the field.
    // FLUX CONSERVED ALONG THE ARC (bit18): the arc covers sL times the area, so
    // surface brightness must fall as 1/sL or a fast particle would emit MORE
    // total light than a slow one — that was the blown-out white core. With
    // this, fast matter draws a LONG DIM trail and total energy is unchanged.
    float3 emission = in.color * in.luminance *
                      (glow * 0.3f + core + spike * 0.6f) / sL;

    // Luminance boost DELETED from alpha (2026-07-08): alpha is COVERAGE,
    // emission carries the energy. The old `+ clamp(lum-1,0,2)·0.06` term
    // dominated grainAlpha for every star ≥1 M☉ — it's why the Grain fader
    // measurably did nothing (Jamal). Grain is now an honest iris again.
    float baseAlpha = in.grainAlpha;
    float alpha = (glow * 0.3f + core + spike * 0.6f) * baseAlpha / sL;

    float fadeDistance = 6.0f;
    float fadeAmount = smoothstep(0.1f, fadeDistance, max(0.0001f, in.dist));

    ParticleFragOut fo;
    fo.color = float4(emission * alpha * fadeAmount, alpha * fadeAmount);
    // velDir2D is (v2 − v1) in NDC times STREAK_GAIN, the streak's own art
    // amplification. Undo it so the smear reads TRUE motion and is not silently
    // 3x long. NDC delta → UV delta: halve, and y flips (no offset — a delta has
    // no origin). Weighted by alpha so a nearly-transparent fragment cannot
    // stamp its velocity over a solid one.
    float2 dNDC = in.velDir2D / STREAK_GAIN;
    fo.velocity = float2(dNDC.x * 0.5f, -dNDC.y * 0.5f) * saturate(alpha * fadeAmount);
    return fo;
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
                                       // NO-HOLE branch only, see :2821.
// Shutter window as a fraction of one ISCO orbit — the only physical time the
// hole defines. 0.35 orbit = 2.2 rad swept at the ISCO, which is exactly the
// existing tuneArcWrap cap, so this states the current look as a real exposure
// time instead of an unnamed constant.
constant float TRAIL_SHUTTER_ORBITS = 0.35f;
// ── THE TRACK IS A SPIRAL, NOT A RAIL (2026-08-16, his verdict: "the Schienen
// on which the Bahn rolls are wrong… we can see that its circles and not a
// black hole, so do the math") ───────────────────────────────────────────────
// He is right and it is arithmetic, not taste. The sweep was a PURE ROTATION —
// Rodrigues preserves |r| exactly — so dr/dt ≡ 0 and the locus it draws is a
// closed circle BY CONSTRUCTION. No exposure, colour or plane change could ever
// have made that read as accretion, because nothing was falling in.
//
// Accreting matter sheds angular momentum and drifts inward at the α-disc rate
//     v_r = α·(h/r)²·v_φ
// Divide by the orbital motion and TIME CANCELS, leaving pure geometry:
//     dr/r = −α·(h/r)²·dφ   ⟹   r(φ) = r₀·exp(−α·(h/r)²·φ)
// — a LOGARITHMIC SPIRAL. Both constants are already in this codebase and both
// are derived, not chosen (particles.metal:244-245): α = 0.1 Shakura–Sunyaev,
// and h/r = 0.746 MEASURED from our own disc at two independent radii that agree
// to 3%. Same two numbers the accretion rate limit is built from, so the trail
// and the hole's growth now obey ONE viscosity.
//   pitch = α·(h/r)² = 0.1 × 0.746² = 0.05565 rad⁻¹
// The trail runs BACKWARD in time, so the tail sits FARTHER OUT: at the 2.2 rad
// wrap the tail is exp(0.05565 × 2.2) = 1.130 → 13% outside the head. The head
// (φ = 0) is scaled by exactly 1, so it stays welded to its star.
// ⚠️ ARC ONLY, deliberately. The playback must NOT spiral: its posePhase wraps
// at 2π, so a cumulative radius factor would snap by exp(0.05565·2π) = 1.42 on
// every wrap. The arc's angle is bounded by tuneArcWrap and measured from the
// head, so it has no such discontinuity.
constant float SS_ALPHA_R      = 0.1f;      // = particles.metal SS_ALPHA
constant float DISK_H_OVER_R_R = 0.746f;    // = particles.metal DISK_H_OVER_R
constant float SPIRAL_PITCH    = SS_ALPHA_R * DISK_H_OVER_R_R * DISK_H_OVER_R_R;

// ── THE ARC / RIBBON PASS — DELETED 2026-08-20 ──────────────────────────────
// His order, after the thickness slider made the ribbons wide enough to judge:
// "this provers the trail theory dead ... its the wrong approach" and "delete
// the fucking code and put it 6 feet under".
//
// WHAT DIED: struct TrajOut, trajectory_vertex, trajectory_fragment — a
// per-particle ribbon drawn as its own geometry, ~370 lines. At 1 px it read
// as hair; widened, it read as slabs. The fault was never the width, the
// falloff, the luminosity or the plane — all four were fixed in turn and the
// look did not survive any of them. Drawing one stroke per star cannot make
// a continuous body, because a million separate strokes with gaps between
// them is what hair IS.
//
// WHAT REPLACES IT: the motion smear in postfx.metal, which stretches the
// PICTURE along the matter's own screen velocity (attachment 1, written by
// particle_fragment). One image being stretched has no gaps by construction.
//
// ⛔ DO NOT REBUILD THIS. If a future session wants trails, the answer is the
// smear's length and hold, not a stroke per particle. Full history is in git
// at 5ee213d and in docs/BOARD_CLOSED.md.

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

// ── DUST EXTINCTION PASS (design §2b, 2026-07-23) ───────────────────────────
// The Pillars' BODIES are dark — dust silhouettes absorbing the glow behind
// them; additive light can never draw dark-in-front-of-bright. The COLD+DENSE
// gas population re-draws as an ABSORBING splat over the additive image
// (Splotch/SPH-volume-render approach, same blend family as the hole pass).
// Per-channel: dst × (1 − src_rgb), and dust absorbs BLUE preferentially, so
// whatever shines through REDDENS — the physical extinction signature
// (research doc §3: densest dust = deep indigo / dark). Bright rims then
// emerge FREE: a rim is where an absorbing body cuts into the emissive glow.
// Hot gas emits instead of absorbing (cold factor → 0), so PLAY matter and
// fresh shock knots never darken — no phase gate needed, state does it.
struct DustVertexOut {
    float4 position [[position]];
    float  pointSize [[point_size]];
    float  alpha;
};

vertex DustVertexOut dust_vertex(
    uint vid [[vertex_id]],
    device const Particle* particlesIn [[buffer(0)]],
    constant CameraUniforms& cam [[buffer(1)]],
    device const uint* cellCounts [[buffer(2)]],
    constant SpatialHashUniforms& su [[buffer(3)]])
{
    DustVertexOut out;
    out.position = float4(0, 0, -2, 1);
    out.pointSize = 0.0f;
    out.alpha = 0.0f;
    Particle in = particlesIn[vid];
    float M = in.posW.w;
    if (M < 0.001f || M > 3.0f || su.gridSize <= 0) return out;   // gas-mass only
    // PERF (2026-07-23): reject on the CHEAP per-particle terms BEFORE the
    // 8-read trilinear — at the formed hole the ring matter is hot, so the
    // whole 2M-particle pass was paying the density reads just to compute
    // α=0. If even maximum density can't reach visible α, skip the reads.
    float cold = 1.0f - clamp(in.prevW.w * (1.0f / 2.5f), 0.0f, 1.0f);
    float gasM = 1.0f - smoothstep(1.5f, 3.0f, M);
    if (0.30f * cold * gasM < 0.02f) return out;
    float3 p = in.posW.xyz;
    // Outside the hash extent (play grid is ±3) the clamped border cells
    // would report garbage density — no dust there.
    if (max(max(abs(p.x), abs(p.y)), abs(p.z)) >= su.halfExtent) return out;
    // Trilinear density (own-cell counts = square patches — 07-19 lesson).
    float3 gp = (p + su.halfExtent) * su.invCellSize - 0.5f;
    int3  c0 = int3(floor(gp));
    float3 f = gp - float3(c0);
    float tri = 0.0f;
    for (int dz = 0; dz <= 1; dz++)
    for (int dy = 0; dy <= 1; dy++)
    for (int dx = 0; dx <= 1; dx++) {
        int3 cc = clamp(c0 + int3(dx, dy, dz), int3(0), int3(su.gridSize - 1));
        float w = (dx ? f.x : 1.0f - f.x) *
                  (dy ? f.y : 1.0f - f.y) *
                  (dz ? f.z : 1.0f - f.z);
        tri += w * float(cellCounts[
            uint((cc.z * su.gridSize + cc.y) * su.gridSize + cc.x)]);
    }
    // Stricter than the emission gate (2..16): only genuinely dense BODIES
    // absorb; the ambient diffuse keeps glowing.
    float dens = smoothstep(6.0f, 30.0f, tri);
    // cold/gasM hoisted above the trilinear (cheap pre-reject).
    float a = 0.30f * dens * cold * gasM;
    if (a < 0.02f) return out;
    float3 spinPos = applySpin(p, cam.spinAngleX, cam.spinAngleY, cam.spinAngleZ);
    float3 worldPos = spinPos * cam.plateRadius;
    out.position = cam.viewProjection * float4(worldPos, 1.0);
    float dist = max(0.0001f, length(worldPos - cam.cameraPos.xyz));
    float sizeScale = pow(800.0f / dist, 0.65f);
    // Diffuse body: wider, soft splat (×3 the star point), capped well below
    // the 150px star ceiling — extinction must never become the overdraw bug.
    out.pointSize = clamp(cam.particleSize * 3.0f * sizeScale, 2.0f, 60.0f);
    out.alpha = a;
    return out;
}

fragment float4 dust_fragment(DustVertexOut in [[stage_in]],
                              float2 pc [[point_coord]])
{
    float d = length(pc * 2.0f - 1.0f);
    float k = smoothstep(1.0f, 0.25f, d) * in.alpha;   // soft body, no crisp edge
    // Per-channel absorption (blend dst × (1 − src_rgb)): blue eaten hardest
    // → transmitted light reddens; alpha channel untouched (dst factor One).
    return float4(k * 0.55f, k * 0.75f, k * 1.0f, 0.0f);
}

// ── METRIC-NATIVE BLACK HOLE — backward geodesic ray-march ───────────────────
// (DESIGN_2026-07-24_metric_native_blackhole.md; ratified by Jamal 2026-07-24.)
//
// WHY THIS IS NOT THE 2026-06-28 DELETION. That geodesic fullscreen pass was
// deleted because it PAINTED A DISK — a shader inventing an analytic hole with
// no connection to the matter. This pass computes the CAPTURE SET of the honest
// metric g(M) the field itself produces: r_s here is the emergent horizon r_h
// measured from enclosed mass, and every dark pixel is a null geodesic that was
// integrated and found to cross it. Nothing is placed. Increment 1 draws only
// that capture set; the following increments march the SAME rays through the
// real deposited particle field for emission (the whole point of the pivot).
//
// THE ODE (Schwarzschild, Cartesian, the a=0 limit of DNGR's A.15):
//     d2x/dl2 = -(3/2) * r_s * h^2 * x / r^5 ,   h^2 = |x x v|^2 (conserved)
// NOTE THE COEFFICIENT. RESEARCH_2026-07-24_interstellar_dngr.md §7.1 prints
// -(3/2)*M*h^2*x/r^5, which is HALF the correct value and does not reproduce
// the known shadow. Derivation: the null geodesic gives
//     r'' = h^2/r^3 - (3/2) h^2 r_s / r^4
// and the flat-space polar decomposition gives r'' = a_r + h^2/r^3, so
//     a_r = -(3/2) h^2 r_s / r^4   =>   a = -(3/2) r_s h^2 x / r^5 = -3M h^2 x/r^5.
// VERIFIED offline before this shipped (scratchpad bc_validate.cpp): the wrong
// coefficient measures b_c = sqrt(2) (the r=r_s turning point of a half-strength
// field, no photon sphere at all); the correct one measures b_c = 2.598071 vs
// the exact 3*sqrt(3)*M = 2.598076 (rel err 1.4e-6), with rays just outside b_c
// skimming rmin = 1.518 -> the photon sphere at 1.5 r_s, and |dh^2|/h^2 < 5e-10.
//
// STEP BUDGET (measured, same file): step scale 0.03 with the march started at
// 60 r_s costs 264 RK4 steps worst-case (the near-critical rays) and lands b_c
// to 1.5e-5. Step scale 0.10 BREAKS (b_c collapses to 0.5) — do not raise it.
//
// ORTHO = OBSERVER AT INFINITY. The camera sits ~8.5 r_s out, but an ortho
// projection is parallel rays, i.e. a telescope at infinity. So each ray is
// back-extended along its own direction to r = 60 r_s and integrated from

struct BHMarchUniforms {
    float inverseViewProj[16]; // same CPU helper the postfx pass already uses
    float rMarchStart;         // start radius in units of r_s (60)
    float stepScale;           // dl = stepScale * r^1.5   (0.03; 0.10 breaks)
    float bCull;               // skip pixels with impact parameter > bCull*r_s
    int   maxSteps;            // 512 (worst measured 264)
    float emitScale;           // emission gain: emit += colour * density * dl * emitScale
    float emitInnerR;          // no emission inside this radius (r_s) → the dark shadow
};

struct BHMarchOut {
    float4 position [[position]];
    float2 ndc;
};

// ═══════════════════════════════════════════════════════════════════════════
// THE HOLE AS A BODY — depth only, zero colour (2026-08-14)
// ═══════════════════════════════════════════════════════════════════════════
// His verdict: "we need to fix the hole / not fix but actually CREATE it. as of
// now we are still faking it and you dont seem to understand that."
//
// WHAT WAS FAKE, MECHANICALLY. Nothing in this renderer drew a black hole. The
// "hole" was the region where we chose not to stamp sprites — three culls and a
// gap (render.metal:821 interior, :857 capture, :1019 image-capture). Every
// optical fix still left an ARRANGED ABSENCE, because:
//   • the particle pass is ADDITIVE with depth WRITE OFF (renderer.mm:1077),
//   • the main pass DISCARDS its depth (storeAction DontCare, renderer.mm:3618),
//   • depthPrepassTexture is written every frame and SAMPLED BY NOTHING —
//     there is not one texture2d<> declaration in this file.
// So nothing in the scene occluded anything. There was no "in front" and no
// "behind", only sums of light. A black hole is, before it is any optics, A
// THING THAT BLOCKS. Ours could not block, so it could not be an object.
// That is also exactly why the 2026-07-24 fullscreen paint had to be withdrawn
// the day it shipped: it had no depth either, so it blacked out matter clearly
// in FRONT of the hole.
//
// THE FIX IS NOT PAINT. This pass writes DEPTH ONLY and NO COLOUR (the pipeline
// sets an empty write mask). It removes light by BEING IN THE WAY — the most
// literal reading of his own standing verdict "SHADOW = ABSENCE, NEVER PAINT".
// And it cannot repeat the withdrawn overlay's failure, because it participates
// in depth ordering instead of multiplying over a finished frame: the particle
// pass already tests depth (MTLCompareFunctionLess, renderer.mm:1074) — it has
// simply never had anything to test against.
//
// GEOMETRY. Schwarzschild is spherically symmetric, so the photon-capture
// surface is a SPHERE of radius b_c = 3√3·M = 2.5980762 r_s, and its silhouette
// is a disc of that radius from every direction. We ray-sphere intersect per
// pixel rather than billboard it, so the silhouette is exact in perspective and
// the depth written is the NEAR SURFACE — what actually blocks the ray.
//
// WHAT THIS DOES NOT TOUCH: the wrap. A lensed image is re-projected to
// bhWorld + along·dHat + pHat·thEff with thEff ≥ 2.62 r_s, i.e. OUTSIDE b_c, so
// it lands beyond the silhouette and is never occluded — the far side still
// arrives over the top. Only light whose image falls inside the capture radius
// is blocked, which is the same criterion as :1019 and is the physics.
// Defined below (:3058) alongside the march; forward-declared so this pass can
// sit next to the banner that explains it.
static float4 mulM4(constant float* m, float4 v);

struct BHBodyOut {
    float depth [[depth(any)]];
};

fragment BHBodyOut bhbody_fragment(BHMarchOut in [[stage_in]],
                                   constant CameraUniforms& cam [[buffer(0)]],
                                   constant BHMarchUniforms& mu [[buffer(1)]])
{
    BHBodyOut o;
    o.depth = 1.0f;
    if (cam.horizonR <= 0.0f) { discard_fragment(); return o; }

    float3 bhWorld = applySpin(float3(cam.bhX, cam.bhY, cam.bhZ),
                               cam.spinAngleX, cam.spinAngleY,
                               cam.spinAngleZ) * cam.plateRadius;
    float rsW = cam.horizonR * cam.plateRadius;
    if (rsW <= 1e-6f) { discard_fragment(); return o; }
    float bc = 2.5980762f * rsW;          // exact 3√3·M capture radius

    // Unproject this pixel to a world ray — ortho AND perspective, the same
    // construction bhmarch_fragment uses (:2971).
    float4 pn = mulM4(mu.inverseViewProj, float4(in.ndc, 0.0f, 1.0f));
    float4 pf = mulM4(mu.inverseViewProj, float4(in.ndc, 1.0f, 1.0f));
    float3 ro = pn.xyz / pn.w;
    float3 rd = normalize(pf.xyz / pf.w - ro);

    // Ray vs capture sphere.
    float3 oc = ro - bhWorld;
    float  b  = dot(oc, rd);
    float  c  = dot(oc, oc) - bc * bc;
    float  disc = b * b - c;
    if (disc <= 0.0f) { discard_fragment(); return o; }   // misses the body
    float t = -b - sqrt(disc);                            // NEAR surface
    if (t <= 0.0f) { discard_fragment(); return o; }      // behind / inside camera

    float4 clip = cam.viewProjection * float4(ro + rd * t, 1.0f);
    if (clip.w <= 1e-6f) { discard_fragment(); return o; }
    o.depth = clamp(clip.z / clip.w, 0.0f, 1.0f);
    return o;
}

// Fullscreen triangle — no vertex buffer.
vertex BHMarchOut bhmarch_vertex(uint vid [[vertex_id]]) {
    float2 p = float2((vid == 2) ? 3.0f : -1.0f, (vid == 1) ? 3.0f : -1.0f);
    BHMarchOut o;
    o.position = float4(p, 0.0f, 1.0f);
    o.ndc = p;
    return o;
}

static float4 mulM4(constant float* m, float4 v) {
    // column-major, matching Renderer::orthoMatrix / invertMatrix4x4
    return float4(m[0]*v.x + m[4]*v.y + m[8]*v.z  + m[12]*v.w,
                  m[1]*v.x + m[5]*v.y + m[9]*v.z  + m[13]*v.w,
                  m[2]*v.x + m[6]*v.y + m[10]*v.z + m[14]*v.w,
                  m[3]*v.x + m[7]*v.y + m[11]*v.z + m[15]*v.w);
}

// (triSampleGrid removed 2026-07-28 09:33:41 — the trilinear gather was
// pulled on 2026-07-26 and the helper has been dead code since. The blob was
// never a sampling problem; see the handoff.)

// ═══════════════════════════════════════════════════════════════════════════
// 🔪 THE GEODESIC RAY-MARCH IS DELETED — 2026-08-27 20:49:10, HIS ORDER
// ═══════════════════════════════════════════════════════════════════════════
// "the march as it is rn is dead too delete it all of it to never retun its
//  the oranghe blob itsnot what we want."                        [HIS WORDS]
//
// ~410 lines removed: bhmarch_fragment in full — the backward null-geodesic
// RK4, the CIC/fine-grid emission gather, the Shakura-Sunyaev T(r), the g
// factor and its g^3 beaming, the radiative transfer, and both of today's
// fixes to it (the step-rule ceiling kMarchStepRefRs and the visible-band
// Planck amplitude visBandWeight). Its pipeline, its encode block, its bit19
// toggle and its three dials go with it.
//
// WHY, and it is not the geodesics. Integrating null geodesics backward is the
// right idea and it is what NASA/Goddard do (Schnittman & Powell 2024). The
// defect was WHAT THIS ONE GATHERED: it accumulated emission from a 128^3
// density grid, NEAREST-sampled, with no temperature of its own. That is a
// volumetric FOG renderer. NASA's rays terminate on a disc and take that
// disc's emission; ours summed a cloud along the whole path. A fog integral
// over a box can only ever produce a soft blob, and dressing it in a colour
// law (2026-08-17) or a Planck amplitude (2026-08-27) does not change what it
// is. He banned it for being orange on 2026-07-28, it came back orange by a
// different route, and today he ended it.
//
// ⛔ DO NOT REBUILD THIS PASS. Anything that replaces it must terminate rays
// on the matter that is actually there, at the resolution the sprites are
// drawn at — not average a grid along a line.
//
// KEPT ON PURPOSE, because bhbody_fragment below still needs them:
//   bhmarch_vertex, struct BHMarchOut, struct BHMarchUniforms (only its
//   inverseViewProj is read now) and bhMarchUniformBuffer. That pass is the
//   depth-only capture sphere he PASSED on 2026-08-14 ("THE HOLE IS A BODY"),
//   and it is what makes the hole occlude as geometry. It is not the march.

