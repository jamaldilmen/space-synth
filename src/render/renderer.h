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
  float spinAngleX = 0.0f;  // accumulated spin angle X (rad) → rigid render spin
  float spinAngleY = 0.0f;  // accumulated spin angle Y (rad) → rigid render spin
  float pixelStretch = 0.0f;// 0-1 "5D look" radial pixel-stretch (driven by spin)

  // Post-FX
  float bloomIntensity = 0.0f;
  float exposure = 1.0f;    // global HDR exposure (1.0 = neutral, <1 stops down)
  float trailDecay = 0.0f; // Persistence of previous frame (user-controlled via POST-FX)
  float chromaticAmount = 0.0f;

  // New Simulation
  float modeP = 1.0f; // Depth Mode multiplier
  float cameraRho = 800.0f;
  float cameraPos[3] = {0.0f, 0.0f, 0.0f};  // World-space camera position
                                             // (set from main.cpp each frame)
  bool orthoMode = true;
  bool phaseViz = false;

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
  float jitterFactor = 0.1f;

  // ── BLACK HOLE TUNING dials ──
  float lensBend = 0.85f;
  float arcWrap = 2.2f;
  float arcGain = 5.0f;
  float trailGain = 1.0f;
  float streakLen = 1.0f;
  float colorTempK = 27000.0f; // colour spectrum: |v|²→Kelvin gain (live tune)
  float heatGain = 3000.0f;    // thermal heat→Kelvin gain (live tune; was HEAT_K_PER_T)
  float collapseFrac = 0.25f; // fraction of field mass in core = hole 100%
  float sphCoolTau = 2.0f;    // slice-4 radiative cooling τ₀ [simt] at T_cap, ρ=1 (~1 simt ≈ 1 s wall)

  // Black-hole shadow radius (sim coords). The physical photon-capture
  // value is 3√3·M ≈ 2.6, but the disk here is scaled tight (r≈3), so a
  // smaller shadow reads more proportionally. User-tunable via "BH Size".
  float shadowRadius = 1.0f;

  // Creative post-FX (cyberpunk / techno / cinematic)
  float glitchAmount = 0.0f;   // RGB block displacement, beat-reactive
  float scanlineAmount = 0.0f; // CRT scanlines
  float neonGrade = 0.0f;      // cyberpunk color grade
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
  DEBUG_JITTER = 1 << 4,
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
  float scanlineAmount;// 0-1 CRT scanlines
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
  float _pad0;         // 24 scalars = 96 B → matrices 16-byte aligned, matches MSL
  float inverseViewProj[16];
  float prevViewProj[16];
};

// Camera uniforms — matches the struct in render.metal
struct CameraUniforms {
  float viewProj[16]; // 4x4 column-major
  float cameraPos[3];
  float cameraPad; // Explicit padding for 16-byte alignment (Metal float3)
  float particleSize;
  float plateRadius;
  float phaseViz; // 1.0 = phase coloring, 0.0 = default
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
  float tuneLens;          // lens bend blend (0..1, default 0.85)
  float tuneArcWrap;       // max arc sweep, rad (default 2.2)
  float tuneArcGain;       // horizon exposure gain (default 5)
  float tuneTrailGain;     // arc brightness multiplier (default 1)
  float tuneStreakLen;     // motion-streak length multiplier (default 1)
  float tuneColorK;        // colour spectrum: |v|²→Kelvin gain (live tune, was pad)
  float tuneHeatK;         // thermal heat→Kelvin gain (live tune): low = warm/red, high = white
  unsigned int bhToggles = 0x7Fu; // BH-mechanism on/off bitmask (UI); bit7 seed-render, bit8 lens
  float bhDiskGM = 0.0f;   // posed BH: GM in sim units (0 = not posed → no disk spin)
  float bhPoseTime = 0.0f; // posed BH: elapsed seconds since pose (drives Ω(r)·t)
  float bhPoseDt = 0.0f;   // posed BH: last frame dt (rotate prev by one frame less)
  float horizonR = 0.0f;   // honest geometric r_h [sim] (0 = no hole) → hole pass
  float bhDiskAxisY = 0.0f; // 1 = emergent time-lapse about Y (honest hole); 0 = posed legacy Z
};

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
  float jitterFactor;
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
                   float totalAmplitude, float maxWaveDepth, float jitterFactor,
                   float speedCap, float eFieldStiffness,
                   float bFieldCirculation, float gravityConstant,
                   float stringStiffness, float restLength,
                   uint32_t debugFlags);

  void render(const RenderConfig &config);
  void render(const RenderConfig &config, const float *viewProj);

  void resize(int width, int height);

  void renderImGui(void *renderEncoder);

  int particleCount() const;
  void setActiveParticleCount(int count);
  void *getMetalDevice() const;

  // Read back particle positions from GPU buffer (for CPU-side access)
  void readbackParticles(GPUParticle *out, int count);

  void setScale(float s);
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
