#pragma once
#include "core/particles.h"
#include <cmath>
#include <cstdint>

namespace space {

struct RenderConfig {
  int width = 1920;
  int height = 1080;
  float particleSize = 2.0f;
  float plateRadius = 400.0f;
  float sharpness = 5.0f;   // particle Gaussian falloff (live-tunable)
  float grainAlpha = 0.08f; // per-particle base alpha (live-tunable)
  float oscAmount = 0.0f;   // oscilloscope scope-line gate (driven by spin)
  float spinX = 0.0f;       // live spin rate around X (rad/s) → trail/Doppler vel
  float spinY = 0.0f;       // live spin rate around Y (rad/s) → trail/Doppler vel
  float spinZ = 0.0f;       // live roll rate around Z (rad/s) — Option+←/→ (2026-07-19)
  float spinAngleX = 0.0f;  // accumulated spin angle X (rad) → rigid render spin
  float spinAngleY = 0.0f;  // accumulated spin angle Y (rad) → rigid render spin
  float spinAngleZ = 0.0f;  // accumulated roll angle Z (rad) → rigid render spin
  float pixelStretch = 0.0f;// 0-1 "5D look" radial pixel-stretch (driven by spin)

  // Post-FX
  float bloomIntensity = 0.0f;
  float exposure = 1.0f;    // global HDR exposure (1.0 = neutral, <1 stops down)
  float trailDecay = 0.0f; // Persistence of previous frame (user-controlled via POST-FX)
  float chromaticAmount = 0.0f;
  bool debugBypassPostFX = false; // B-key whiteout bisect: raw scene + Reinhard only
  bool debugNoBleach = false;     // N-key: disable sensor bleach (yellow-zone isolation)
  bool simPaused = false; // SPACE pause: freezes the emergent time-lapse clock too (pause = pause everything)
  bool pauseHoldTimelapse = false; // SPACE held during pause: let the time-lapse clock run
  // DECLARED TIME-LAPSE, as a PHYSICAL quantity: how many screen-seconds one
  // ISCO orbit takes. The compression factor is DERIVED from the hole's own
  // mass (T_isco = kIscoPeriodPerGM * GM), never picked — so it re-derives
  // itself as the hole eats, where a bare "x20" would drift. spacetime.h
  // reserves T_lapse as the user's decision, hence a dial. RENDER CLOCK ONLY.
  float iscoScreenSeconds = 3.8f;
  int   physicsSubsteps = 1;      // N fixed-dt physics steps per frame (fast sweep w/o dt-blowup)

  // New Simulation
  float modeP = 1.0f; // Depth Mode multiplier
  float cameraRho = 800.0f;
  float cameraPos[3] = {0.0f, 0.0f, 0.0f};  // World-space camera position
                                             // (set from main.cpp each frame)
  // World-space UNIT forward (eye → target). F5 2026-08-10: the shader used to
  // re-derive this as normalize(-cameraPos), which assumes the camera looks at
  // the origin. Default points down -Z so a config built without main.cpp still
  // has a unit axis rather than a zero vector.
  float cameraForward[3] = {0.0f, 0.0f, -1.0f};
  bool orthoMode = true;
  bool  phaseViz = true;            // default ON 2026-08-24 (blend, not replace)
  float phaseVizAmount = 0.35f;     // 0..1 blend toward the phase hue

  // Debugging Suite (Phase 7)
  bool fixedTimestep = false;
  uint32_t debugFlags = 0xFFFFFFFF; // All forces ON by default

  // Phase 17: Black Hole Rendering Gate
  float envelopePhase = 0.0f;
  float envelopeProgress = 0.0f;

  // Phase 18: Aesthetics
  float rotationX = 0.0f;
  float rotationY = 0.0f;
  float rotationZ = 0.0f;

  // ── BLACK HOLE TUNING dials ──
  float smearShutter = 24.0f; // motion-smear length multiplier
  float smearHold = 1.0f;     // 1 = solid bands, 0 = fading blur
  float streakLen = 1.0f;
  float colorTempK = 27000.0f; // colour spectrum: |v|²→Kelvin gain (live tune)
  float heatGain = 3000.0f;    // thermal heat→Kelvin gain (live tune; was HEAT_K_PER_T)
  // STAR LAW DIALS (2026-07-28) — see CameraUniforms below for what each does.
  float starLumExp = 3.5f;
  float starLumGain = 2.5f;
  float starLumCeil = 1000.0f;
  float starKelvinA = 5772.0f;
  float starKelvinP = 0.55f;
  float starSizeGain = 1.0f;
  float starSizeExp = 0.8f;
  float starSizeFloor = 1.0f;
  float starSizeCeil = 48.0f;
  float collapseFrac = 0.25f; // fraction of field mass in core = hole 100%
  float sphCoolTau = 2.0f;    // slice-4 radiative cooling τ₀ [simt] at T_cap, ρ=1 (~1 simt ≈ 1 s wall)

  // Black-hole shadow radius (sim coords). The physical photon-capture
  // value is 3√3·M ≈ 2.6, but the disk here is scaled tight (r≈3), so a
  // smaller shadow reads more proportionally. User-tunable via "BH Size".
  float shadowRadius = 1.0f;

  // Creative post-FX (cyberpunk / techno / cinematic)
  float glitchAmount = 0.0f;   // RGB block displacement, beat-reactive
  float neonGrade = 0.0f;      // cyberpunk color grade
  float gradeAmount = 0.0f;    // display grade LUT blend (grade_lut.h); 0 = bypass
  float vignette = 0.0f;       // edge darkening
  float audioLevel = 0.0f;     // total amplitude (drives reactive FX)
  float fxTime = 0.0f;         // running seconds for animated FX

  // Resolume-style VJ effects
  float mirrorMode = 0.0f;
  float kaleidoSegments = 0.0f;
  float tileCount = 1.0f;
  float twirl = 0.0f;
  float hueShift = 0.0f;
  float strobe = 0.0f;
  float invert = 0.0f;
  float posterize = 0.0f;
  float blurAmount = 0.0f; // multi-pass Gaussian blur (ping-pong)
  unsigned int bhToggles = 0x1FFu; // BH-mechanism on/off bitmask (UI toggles), default all-on
};

// Debug bitmasks for PhysicsUniforms.debugFlags
enum DebugFlag : uint32_t {
  DEBUG_NONE = 0x0,
  DEBUG_E_FIELD = 1 << 0,
  DEBUG_B_FIELD = 1 << 1,
  DEBUG_GRAVITY = 1 << 2,
  DEBUG_STRINGS = 1 << 3,
  // bit 4 free — was DEBUG_JITTER (jitter KILLED 2026-09-01, his order)
  DEBUG_COLLISIONS = 1 << 5,
  DEBUG_FIXED_DT = 1 << 6,
  DEBUG_ODS01 = 1 << 7, // Telepathy (Phase 9)
  DEBUG_ODS06 = 1 << 8, // Black Holes (Phase 9)
  DEBUG_ODS04 = 1 << 9, // Stealth/ANC (Phase 9)
  DEBUG_ALL = 0xFFFFFFFF
};

// Matches postfx.metal struct
struct PostFXUniforms {
  float resolution[2];
  float bloomIntensity;
  float trailDecay;
  float chromaticAmount;
  float time;          // seconds, drives animated glitch
  float glitchAmount;  // 0-1 cyberpunk RGB block displacement
  float postPad0;      // FREE (was scanlineAmount, deleted 2026-08-22). KEPT as
                       // a pad on purpose — removing it would move the matrices
                       // on this side only. See the mismatch note below.
  float neonGrade;     // 0-1 cyberpunk color grade
  float vignette;      // 0-1 edge darkening
  float audioLevel;    // 0-1 total amplitude → beat-reactive FX
  // Resolume-style VJ effects
  float mirrorMode;      // 0 off, 1 H, 2 V, 3 quad
  float kaleidoSegments; // 0 off, else 2-16
  float tileCount;       // <=1 off, else NxN
  float twirl;           // -1..1
  float hueShift;        // 0-1
  float strobe;          // 0-1
  float invert;          // 0-1
  float posterize;       // 0 off, else 2-16
  float edrHeadroom;   // display EDR headroom (1.0 = SDR); keeps 80-byte align
  float pixelStretch;  // 0-1 "5D look" radial pixel-stretch (driven by spin)
  float exposure;      // global HDR exposure multiplier (1.0 = neutral)
  float debugBypass;   // >0.5 = raw scene + Reinhard (whiteout bisect)
  // ⚠️ MEASURED 2026-08-22 — THIS COMMENT WAS WRONG AND THE INVARIANT IS
  // ALREADY VIOLATED. It claimed "now 28 (=112 B)". The real count is 27
  // scalars = 108 B. Compiler-verified: MSL sizeof 240, matrices at 112;
  // C++ sizeof 236, matrices at 108. THE TWO SIDES ARE 4 BYTES APART RIGHT NOW.
  // Dormant only because the sole reader of both matrices is the
  // `if (false && ...)` block at postfx.metal:476. Do NOT add or remove a
  // scalar here until it is fixed. `postPad0` above is free.
  float gradeAmount;   // 0-1 display grade LUT blend (0 = exact bypass)
  // COVERAGE RESOLVE (2026-08-11, board §H9): 1 = on, 0 = off. Repurposed from
  // gradePad0 ON PURPOSE — a pad float is the one place a new scalar can be
  // added with NO size change and NO offset change, so the CPU/GPU mirror
  // cannot drift. Appending instead is what produced G8's 276-vs-288 C++/Metal
  // mismatch. Two pads remain if another scalar is ever needed.
  float coverageResolve;
  float smearShutter;  // SMEAR LENGTH (2026-08-20) — multiplies the star pass's
                       // measured 0.05 s of travel. Was a hardcoded 8. (gradePad1)
  float smearHold;     // 0 = band fades (blur), 1 = holds colour (bands). (gradePad2)
  // ⭐ ALIGNMENT PAD — added 2026-08-22, this is the actual fix for the 4-byte
  // CPU/GPU split. 27 scalars = 108 B; MSL's `float4x4` forces 16-byte
  // alignment and pads 108 -> 112, while `float[16]` here needs only 4 and does
  // not. That put every matrix read in postfx.metal one float out of place.
  // 28 scalars = 112 B makes both sides land identically WITHOUT relying on
  // either compiler's implicit padding. Free to repurpose as a real scalar
  // later — but the COUNT must stay a multiple of 4.
  float postPad1;
  float inverseViewProj[16];
  float prevViewProj[16];
};

// ── PostFXUniforms layout guard (2026-08-22) ────────────────────────────────
// Same pattern as CameraUniforms below: the mirror is bound by the compiler,
// not by a comment. It was a COMMENT that guarded this struct before, it said
// "28 (=112 B)" while the truth was 27 (=108 B), and the mirror had been broken
// for an unknown length of time. Written identically into the top of
// src/render/postfx.metal.
static_assert(sizeof(PostFXUniforms) == 240,
              "PostFXUniforms layout — update the mirrored struct at the top of "
              "src/render/postfx.metal AND its matching static_asserts");
static_assert(__builtin_offsetof(PostFXUniforms, chromaticAmount) == 16,
              "PostFXUniforms head anchor — layout drift vs postfx.metal");
static_assert(__builtin_offsetof(PostFXUniforms, smearHold) == 104,
              "PostFXUniforms scalar-tail anchor — layout drift vs postfx.metal");
static_assert(__builtin_offsetof(PostFXUniforms, inverseViewProj) == 112,
              "PostFXUniforms matrix anchor — THE bug this guard exists for");

// Camera uniforms — matches the struct in render.metal
struct CameraUniforms {
  float viewProj[16]; // 4x4 column-major
  float cameraPos[3];
  float cameraPad; // Explicit padding for 16-byte alignment (Metal float3)
  float particleSize;
  float plateRadius;
  float phaseViz; // BLEND AMOUNT 0..1 toward phase hue (was a 0/1 switch)
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
  // ── BLACK HOLE TUNING dials (UI-driven, defaults = tuned look) ──
  float tuneStreakLen;     // motion-streak length multiplier (default 1)
  float tuneColorK;        // colour spectrum: |v|²→Kelvin gain (live tune, was pad)
  float tuneHeatK;         // thermal heat→Kelvin gain (live tune): low = warm/red, high = white
  unsigned int bhToggles = 0x7Fu; // BH-mechanism on/off bitmask (UI); bit7 seed-render, bit8 lens
  float bhDiskGM = 0.0f;   // posed BH: GM in sim units (0 = not posed → no disk spin)
  float bhPoseTime = 0.0f; // posed BH: elapsed seconds since pose (drives Ω(r)·t)
  float bhPoseDt = 0.0f;   // posed BH: last frame dt (rotate prev by one frame less)
  float horizonR = 0.0f;   // honest geometric r_h [sim] (0 = no hole) → hole pass
  float bhDiskAxisY = 0.0f; // 1 = emergent time-lapse about Y (honest hole); 0 = posed legacy Z
  float bhX = 0.0f;        // emergent hole CENTRE (= bhPos, sim coords): render spins/culls
  float bhY = 0.0f;        // about THIS, not the origin. Matters after PLAY — the cymatics
  float bhZ = 0.0f;        // displaces matter so the collapsed hole forms off-centre.
  float spinZ = 0.0f;      // roll rate around Z (rad/s)
  float viewportH = 1080.0f; // framebuffer height px — NDC->px for the flux-conserving
                             // streak arc (appended 2026-07-24, keep LAST)
  float spinAngleZ = 0.0f; // accumulated roll angle Z (rad) — mirror order = render.metal
  // ── STAR LAW DIALS (2026-07-28) — the two laws the [KPROBE] histogram
  // measured. Every default below reproduces the previous hardcoded constant
  // EXACTLY, so at defaults the picture is unchanged. Mirror order = render.metal.
  float tuneStarLumExp = 3.5f;    // L = M^this          (was hardcoded 3.5)
  float tuneStarLumGain = 2.5f;   // starLum = L * this  (was hardcoded 2.5)
  float tuneStarLumCeil = 1000.0f;// min(starLum, this)  (was hardcoded 1000)
  float tuneStarKelvinA = 5772.0f;// K = this * M^p      (was hardcoded 5772)
  float tuneStarKelvinP = 0.55f;  // K = A * M^this      (was hardcoded 0.55)
  // ── STAR SIZE DIALS (2026-07-28 15:21, measured: meanPx 1.02, 99.2% of stars
  // pinned at the 1 px FLOOR). Defaults reproduce the old constants exactly.
  float tuneStarSizeGain = 1.0f;  // rawStar *= this     (new, identity at 1.0)
  float tuneStarSizeExp = 0.8f;   // Rstar = M^this      (was hardcoded 0.8)
  float tuneStarSizeFloor = 1.0f; // STAR_MIN_PX         (was hardcoded 1.0)
  float tuneStarSizeCeil = 48.0f; // tanh soft ceiling   (was hardcoded 48.0)
  // ── VIEW AXIS (F5, 2026-08-10) — APPENDED, mirror order = render.metal ──
  // World-space UNIT forward (eye → target). The shader used to re-derive this
  // inline as normalize(-cameraPos), which is only the view axis while the
  // camera looks at the ORIGIN. Three scalars, not a float3/float4, so there is
  // no 16-byte alignment padding to keep in sync by hand — same house style as
  // bhX/bhY/bhZ above. Defaults to -Z (unit) so an unset config is still valid.
  float viewForwardX = 0.0f;
  float viewForwardY = 0.0f;
  float viewForwardZ = -1.0f;
  // ── RAW HORIZON FOR THE CAPTURE CULL (2026-08-11 03:26:00) — APPENDED ──
  // MEASURED 2026-08-11 03:18: on the frame a hole forms, lastHorizonR (raw)
  // = 0.0781 while lastHorizonRSmooth = 0.0130 — the eased value is 6× SMALLER
  // than the true horizon and needs ~2 s of frames (×0.03/frame, renderer.mm:1494)
  // to converge. The star-pass capture cull (render.metal, "distance from the
  // HOLE CENTRE") was gated on the eased value, so every shell between r=0.013
  // and r=0.078 was INSIDE the real horizon and still being drawn. That is
  // Jamal's "why are particles still rendered once they crossed the black hole
  // tummy", and it fires every single time a hole forms.
  //
  // ⭐ WHY A SECOND FIELD instead of pointing cam.horizonR at the raw value:
  // the easing is not a bug. It exists because the horizon probe steps every
  // few seconds and the drawn hole "visibly JUMPED size" (renderer.h:211,
  // 2026-07-19). horizonR still drives the hole pass / membrane / pose / lens
  // RADIUS, which must stay smooth. Only the CULL — a yes/no question about
  // whether a star is behind the horizon — must use truth. Physics already
  // uses raw (renderer.mm:1980), so this makes the render cull agree with the
  // physics instead of with the visual easing.
  float horizonRRaw = 0.0f;
  // ⚠️ 16-BYTE TAIL RULE — learned the hard way 2026-08-11 03:29:00, and the
  // layout guard is what caught it. MSL rounds a struct's size UP to its
  // largest member alignment (float4x4 ⇒ 16), while the C++ half here declares
  // that matrix as float[16] (alignment 4) and does NOT round. Appending
  // horizonRRaw alone gave sizeof 276 in C++ and 288 in Metal — the field
  // offsets still agreed, but the sizeof assert could no longer be satisfied on
  // both sides at once, which would have meant weakening the guard.
  // Fix: keep the struct a MULTIPLE OF 16 by padding the tail. The next person
  // to append should consume these pads first, then add a fresh 16-byte block.
  // FIELD HALF-DEPTH along the view axis, sim units (2026-08-11, board §H10).
  // Consumes horizonRPad0 exactly as that block's own comment instructs, so
  // sizeof stays 288 and all four offset anchors are unchanged.
  // ⭐ Fed from the MEASURED mean particle radius (the [GRAV] line's meanR),
  // NOT from a cap constant. The first version mirrored STAR_MAP_CAP /
  // ORBIT_R_CHLADNI and was wrong by ~15x, because a cap describes what matter
  // may occupy, not where it is. Using the measurement also removed the
  // cross-file constant duplication that version had to declare.
  float fieldHalfDepth = 100.0f;
  // S2 / RESOLUTION-NORMALISED STAR SIZE (2026-08-21).
  // drawableHeight / 2260.0. The star size law is in DEVICE PIXELS and knew
  // nothing about the drawable, so the same scene drew the same pixel sizes at
  // 1.0 MP and at 8.1 MP (MEASURED: meanPx 1.02 vs 1.26 for an 8x pixel
  // increase, 2026-08-21 21:28:59). That makes any RECORDING resolution-
  // dependent, which is permanent once it is in a file.
  // The reference 2260 is his fullscreen drawable height, measured the same
  // run — so at fullscreen this is exactly 1.0 and the look is UNCHANGED by
  // construction. That is the whole safety argument for this change.
  //
  // ⭐ ONE VALUE, ONE LAW (his order 2026-08-21: "we dont want two values for
  // a single thing ever"). Every pixel size in particle_vertex — rawSize, the
  // zoom cap, the nova pulse and its 150 cap, the seed sprite's 3..220 clamp,
  // the gas spread's 150 cap, tuneStarSizeCeil/Floor — is expressed in
  // REFERENCE pixels (pixels on a 2260-tall drawable). They are converted to
  // device pixels by a SINGLE multiply at the tail of particle_vertex. Do not
  // apply this factor anywhere else; a second application is a second law.
  // Reuses the dead tuneTrailWidth slot (ribbon pass deleted 2026-08-20, zero
  // readers) rather than appending — appending is what produced the 276-vs-288
  // mismatch. sizeof stays 288; horizonRPad2 is still spare.
  float sizeResScale = 1.0f;
  float horizonRPad2 = 0.0f;
};

// ── LAYOUT GUARD (F5 / board A0h′, 2026-08-10) ──────────────────────────────
// This struct is hand-mirrored in render.metal and the two are bound by NOTHING
// but a comment. They deliberately differ in declared TYPE while agreeing on
// LAYOUT (float[16] here vs float4x4 there; float[3]+cameraPad here vs float4
// cameraPos there), so a size match is meaningful rather than trivially true.
//
// The SAME numbers appear at the bottom of render.metal's copy. Append a field
// to one file and forget the other and that file's compile fails — the Metal
// build runs as the MetalShaders target in package_macos.sh, so both halves
// break the normal build loop.
//
// APPEND-ONLY RULE: new fields go at the END, never inserted mid-struct. An
// append that goes wrong makes ONE new field read garbage; a mid-struct insert
// silently shifts EVERY field after it, which presents as a physics bug.
//
// sizeof alone would NOT catch two transposed fields (same size, different
// layout) — verified 2026-08-10 by compiling exactly that case. Hence the
// offset anchors. HONEST LIMIT: three anchors across ~40 fields catch size
// drift, a bad append, and any transposition ACROSS an anchor. A transposition
// strictly BETWEEN two anchors still slips through. This is a guard, not a proof.
//
// Precedent: renderer.mm does the same for BHMarchUniforms (grep static_assert).
static_assert(sizeof(CameraUniforms) == 272,
              "CameraUniforms layout — update the mirrored struct at the top of "
              "src/render/render.metal AND its matching static_asserts");
// __builtin_offsetof, not offsetof: the macro needs <cstddef>, which this header
// does not include, and the Metal half CANNOT use it at all (MSL has no cstddef).
// Using the builtin on both sides keeps the two blocks literally identical.
static_assert(__builtin_offsetof(CameraUniforms, bhShadowNdcRadius) == 108,
              "CameraUniforms anchor bhShadowNdcRadius — layout drift vs render.metal");
static_assert(__builtin_offsetof(CameraUniforms, bhX) == 184,
              "CameraUniforms anchor bhX — layout drift vs render.metal");
static_assert(__builtin_offsetof(CameraUniforms, viewForwardZ) == 252,
              "CameraUniforms anchor viewForwardZ — layout drift vs render.metal");
static_assert(__builtin_offsetof(CameraUniforms, horizonRRaw) == 256,
              "CameraUniforms tail anchor — layout drift vs render.metal");

// Voice data for GPU compute (matches VoiceData in particles.metal)
struct VoiceGPUData {
  int m;
  int n;
  float alpha;
  float amplitude;
  float emitterX;
  float emitterY;
  float emitterZ;
  float frequency;
  float deltaAmp;   // Transient spike detection
  float phase;      // Audio-rate oscillator phase
  int bandGroup;    // Perceptual frequency group (0-5) for color mapping
  float padding;    // Alignment to 48 bytes (16x3)
};

// Physics uniforms for compute shader
struct PhysicsUniforms {
  float dt;
  float totalAmplitude;
  int voiceCount;
  int particleCount;
  float maxWaveDepth;
  float plateRadius;
  float deadJitterPad;        // was jitterFactor — jitter KILLED 2026-09-01 (his
                              // order). Field kept as a pad: PhysicsUniforms has
                              // NO static_asserts and removing one scalar shifts
                              // ~38 fields while still compiling. Keep in sync
                              // with particles.metal.
  float speedCap;
  uint32_t frameCounter;      // For temporal noise
  float symmetryBreakImpulse; // >0 on mode change (Noether)
  float collisionRadius;      // Interaction radius for collisions
  int collisionsOn;           // 1 = collisions enabled
  float uncertaintyStrength;  // Heisenberg noise scale
  float eFieldStiffness;      // E-Field analog repulsion multiplier
  float bFieldCirculation;    // B-Field analog circulation force
  float time;                 // True continuous time for Brownian noise
  float gravityConstant;      // G for Potato Radius
  float stringStiffness;      // Hooke's Law Tensegrity Constant
  float restLength;           // Ideal neighbor distance for Strings
  uint32_t debugFlags;        // Solo/Mute force flags

  // ═══ BLACK HOLE LIFECYCLE (Phase 17) ═══
  float envelopePhase;    // 0=silence, 1=attack, 2=decay, 3=sustain, 4=release
  float envelopeProgress; // 0.0→1.0 within current phase
  float lifecycleIntensity; // Combined amplitude measure
  float massTotal;          // Σ stellar mass of the field, M_sun (was padding)
  float diskThickness;      // accretion-disk vertical thickness (UI)
  float spinX;              // user spin torque around X axis (rad/s)
  float spinY;              // user spin torque around Y axis (rad/s)
  float bondNetworkOn;      // >0.5 = find nearest-neighbour bonds in sustain

  // ═══ SELF-GRAVITY (emergent BH, Step 1) ═══
  float comX;               // live-mass centre of mass (reduce_stats, 1-frame lag)
  float comY;
  float comZ;
  float gravGM;             // G_sim·M_total — 0 disables self-gravity

  // ═══ EMERGENT-BH SIGNAL (Step 2) ═══
  float bhX;                // densest-region position (1-frame lag, self-refining)
  float bhY;
  float bhZ;
  float bhMass;             // stars (M_sun) enclosed within R_ENC of (bhX,bhY,bhZ)
  float horizonR = 0.0f;    // honest geometric horizon r_h [sim] (0 = no hole); pressure yields inside it
  float dtPrev = 1.0f / 120.0f; // previous frame's dt → time-corrected Verlet (framerate-independent orbits)
  float centerGM = 0.0f;        // GM of the hard-coded central SMBH (Sgr A*) the cluster orbits
  unsigned int bhToggles = 0x7Fu; // BH-mechanism on/off bitmask (UI toggles); default all-on
  float uAmbient = 6e-3f;   // live mass-weighted mean u (SPH ledger, ~2 s lag) → display ambient
  float fieldMassMsun = 0.0f; // Σ stellar mass, UNSCALED M_sun — the mass books
  // ── RETURN PULL (2026-09-03, HIS SHOW FIX: "the energy we put in through play
  // gets handed back through the inward pull to the center… cinematically
  // speeded"). 0 = off. Ramps 0→1 after silence (CPU: delay, ramp), holds until
  // the hole forms, resets on any note. The kernel only multiplies by it.
  // A CINEMATIC FORCE, not physics — labelled so at both ends.
  // APPENDED LAST on BOTH sides (particles.metal PhysicsUniforms, offset 168).
  float returnPull = 0.0f;
};

// Spatial hash uniforms for collision grid
struct SpatialHashUniforms {
  int gridSize;
  int particleCount;
  float cellSize;    // 2*halfExtent / gridSize
  float invCellSize; // gridSize / (2*halfExtent)
  int gridSizeZ;
  float halfExtent;  // particle field half-extent in sim coords
};

// Stats readback from GPU (conservation laws)
struct PhysicsStats {
  float kineticEnergy;
  float momentumX;
  float momentumY;
  int collisionCount;
  int errorState; // 0 = OK, 1 = NaN detected, 2 = Explosion detected
  float avgTemp;  // mean particle temperature (sim units)
  float maxTemp;  // max particle temperature
  float avgSpeed; // mean particle speed |v|
  float maxSpeed; // max particle speed
  // ── Emergent black hole (the collapse readout) ──
  float coreMassMsun;  // mass gathered in the core sphere (M_sun)
  float fieldMassMsun; // total field mass budget (M_sun)
  float maxBodyMsun;   // heaviest single body (M_sun)
  float bhStrength;    // 0..1 collapse fraction signal (1 = full shadow)
  // ── Honest horizon, MEASURED (2026-08-08) ────────────────────────────────
  // These existed in the renderer since the geometric-criterion work but were
  // never exposed, so the UI had no live horizon to show and the GALAXY panel
  // fell back on Sgr A* constants. Jamal 2026-08-08 00:36: "Static info in a ui
  // is stupid... this is groundwork everything else builds on."
  float horizonR;        // largest r where r_s(M(<r)) >= r  [sim units], 0 = none
  float horizonMassMsun; // enclosed mass inside horizonR    [M_sun]
  float horizonRatio;    // sup of r_s(M(<r))/r — continuous approach, 1.0 = horizon
  // ── Accuracy measurement (Step 2 slice) ──
  float maxAccRatio;   // field-wide max gravity-kick / light-step (gkmag/gkmax),
  int   accOverCount;  // particles whose kick exceeded the c·dt budget this frame (clamp fired)
                       // 1-frame lag. >1 = integrator clamp firing (inaccurate);
                       // required accurate sub-steps ≈ ceil(4·ratio).
};

class Renderer {
public:
  Renderer();
  ~Renderer();

  bool init(void *metalDevice, void *metalLayer, int width, int height);

  void uploadParticles(const GPUParticle *data, int count);
  void resetParticles();
  // Analytic-BH pose: declare a formed hole of the given mass so the EXISTING
  // real lens maths (shadow radius b=2.6·r_s(M), point-mass lens equation,
  // secondary fold-over image, raytracer) all activate on a posed disk instead
  // of waiting for an emergent collapse. on=false releases it. Pause the sim
  // while posed so the collapse computation doesn't overwrite these.
  void setBlackHolePose(bool on, float bhMassMsun);
  // Compute physics step (runs async)
  void computeStep(float dt, const VoiceGPUData *voices, int voiceCount,
                   float totalAmplitude, float maxWaveDepth,
                   float speedCap, float eFieldStiffness,
                   float bFieldCirculation, float gravityConstant,
                   float stringStiffness, float restLength,
                   uint32_t debugFlags);

  // The single-argument overload was deleted 2026-08-11 04:11:00 — it had zero
  // callers and its ortho-only body was being misread as the live renderer.
  // Every caller supplies a viewProj.
  void render(const RenderConfig &config, const float *viewProj);

  void resize(int width, int height);

  void renderImGui(void *renderEncoder);

  // ── TWO-WINDOW MODE (2026-08-23) ──────────────────────────────────────────
  // Hand this the settings window's CAMetalLayer and the ImGui UI is drawn
  // THERE instead of on top of the show. Pass nullptr to go back to a single
  // window. The output drawable is then never touched by the UI pass at all —
  // this is not a hide, the panels are simply not composited into the feed.
  void setUILayer(void *metalLayer);

  int particleCount() const;
  void setActiveParticleCount(int count);
  void *getMetalDevice() const;

  // Read back particle positions from GPU buffer (for CPU-side access)
  void readbackParticles(GPUParticle *out, int count);

  void setScale(float s);
  void setTimeWarp(float w); // x2/x4/x8 time controls — scales the pinned physics dt
  // ⏱️ TRUE TIME (E2, 2026-08-30): the sim SECONDS the last computeStep actually
  // integrated = dt x the steps the wall clock owed. The host must tick the
  // universe clock by THIS, never by a dt it recomputed itself — see main.cpp.
  double simSecondsLastStep() const;
  void triggerReset(); // Phase 12 stability: Force GPU re-seed
  void setCollisionsEnabled(bool enabled);
  bool collisionsEnabled() const;
  void setBondNetworkEnabled(bool enabled);
  bool bondNetworkEnabled() const;

  // Phase 17: Set ADSR lifecycle state for black hole dynamics
  void setEnvelopeState(float phase, float progress, float intensity);

  // Accretion-disk vertical thickness (UI-tunable)
  void setDiskThickness(float t);

  // User spin torque (rad/s) around X and Y — drives the physical spin of the
  // whole particle body (arrow-key hold ramps this with momentum/drag).
  void setSpin(float x, float y);

  // Physics stats (1-frame latency)
  PhysicsStats getPhysicsStats() const;

  // Camera helpers
  static void orthoMatrix(float *out, float left, float right, float bottom,
                          float top, float near, float far);
  static void perspectiveMatrix(float *out, float fovY, float aspect,
                                float near, float far);
  static bool invertMatrix4x4(const float *m, float *invOut);

private:
  struct Impl;
  Impl *impl_;
};

} // namespace space
