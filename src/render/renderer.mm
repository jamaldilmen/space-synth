#include "renderer.h"
#include "core/imf.h"
#include "core/units.h"
#include "spacetime/spacetime.h"  // thermodynamics: kUFloorSim (SPH internal energy floor)
#include "spectral_lut.h"          // spectral starmap: Planck band-flux bake (one colour law)
#include "grade_lut.h"             // display grade LUT bake (derivation of every number lives there)
#include "backends/imgui_impl_metal.h"
#include "imgui.h"
#include <Metal/Metal.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <AppKit/AppKit.h>
#import <QuartzCore/CAMetalLayer.h>
#if HAS_SYPHON
#import <Syphon/SyphonMetalServer.h>
#endif
#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <simd/simd.h>
#include <mach/mach_time.h>
#include <mach/mach.h>

namespace space {

// MUST match struct BHMarchUniforms in render.metal exactly (all 4-byte
// scalars, no vectors, so the layout is identical on both sides by inspection).
struct BHMarchUniforms {
  float inverseViewProj[16];
  float rMarchStart;  // march start radius, in units of r_s
  float stepScale;    // dl = stepScale * r^1.5
  float bCull;        // impact-parameter cull, in units of r_s
  int   maxSteps;
  float emitScale;    // emission gain (∫ρ ds → light)
  float emitInnerR;   // no emission inside this radius (r_s) → dark shadow
};
static_assert(sizeof(BHMarchUniforms) == 88, "BHMarchUniforms layout");

struct Renderer::Impl {
  id<MTLDevice> device;
  id<MTLCommandQueue> commandQueue;        // For rendering
  id<MTLCommandQueue> computeCommandQueue; // For async physics
#if HAS_SYPHON
  SyphonMetalServer *syphonServer = nil;   // live video out (Resolume/Arena etc.)
  id<MTLTexture> syphonTexture = nil;      // dedicated SDR-tonemapped feed (vibrant in SDR)
  CAMetalLayer *uiLayer = nil;             // TWO-WINDOW MODE: settings window, nil = single
#endif
  id<MTLEvent> frameEvent;                 // Synchronization fence
  uint64_t frameEventValue;                // Fence ticket

  id<MTLLibrary> library = nil;

  id<MTLComputePipelineState> physicsPipeline = nil;
  id<MTLComputePipelineState> orbitSubstepPipeline = nil; // light central-gravity substep
  id<MTLRenderPipelineState> particlePipeline = nil;
  id<MTLRenderPipelineState> postPipeline = nil;
  // Ping-pong HDR pool for multi-pass effects (blur/echo/feedback)
  id<MTLRenderPipelineState> blurPipeline = nil;
  id<MTLTexture> pingTexture[2] = {nil, nil};
  // HDR glow (bloom): bright-pass extraction → MIP PYRAMID → composite.
  // Dedicated buffers so the glow never collides with the user-facing blur
  // slider's ping-pong pool. bloomMip[0] IS bloomTexture (half-res, the
  // bright-pass target and the finished glow bound at texture(2)); levels 1..n
  // halve from there. 8 slots covers any display down to the 8 px floor.
  static constexpr int kBloomMaxLevels = 8;
  id<MTLRenderPipelineState> brightPipeline = nil;
  id<MTLRenderPipelineState> bloomDownPipeline = nil; // 13-tap partial box
  id<MTLRenderPipelineState> bloomUpPipeline = nil;   // 3x3 tent, additive
  id<MTLTexture> bloomTexture = nil;  // finished glow, bound at texture(2)
  id<MTLTexture> bloomMip[kBloomMaxLevels] = {nil, nil, nil, nil,
                                              nil, nil, nil, nil};
  int bloomLevels = 0;                // derived from resolution, not hardcoded
  // Display grade LUT: 33^3 RGBA16F 3D texture, hardware trilinear = exactly
  // the interpolation a .cube grade needs. Resolution-independent, so it is
  // baked ONCE at init and never touched by resize().
  id<MTLTexture> gradeLutTexture = nil;

  // Spatial hash pipelines
  id<MTLComputePipelineState> assignCellsPipeline = nil;
  id<MTLComputePipelineState> countCellsPipeline = nil;
  id<MTLComputePipelineState> prefixSumLocalPipeline = nil;
  id<MTLComputePipelineState> prefixSumBlocksPipeline = nil;
  id<MTLComputePipelineState> prefixSumAddPipeline = nil;
  id<MTLComputePipelineState> scatterPipeline = nil;
  id<MTLComputePipelineState> centroidPipeline = nil; // per-cell centroid (cohesion)
  id<MTLComputePipelineState> balsaraPipeline = nil;  // per-cell shear/shock switch (bit12 gate)
  id<MTLBuffer> cellBalsaraBuffer = nil;              // float per cell: 1 shock … 0 shear
  // CIC velocity moments (SS_CIC_MOMENTS, 2026-07-15): deposit-side anti-alias
  // of cellVelocities — see spatial_hash.metal cic_* kernels.
  id<MTLComputePipelineState> cicClearPipeline = nil;
  id<MTLComputePipelineState> cicDepositPipeline = nil;
  id<MTLComputePipelineState> cicFinalizePipeline = nil;
  id<MTLBuffer> cicMomentsBuffer = nil;               // 5 floats per cell
  id<MTLComputePipelineState> poissonPipeline = nil;  // PM gravity: red-black SOR Poisson sweep
  id<MTLComputePipelineState> sphDensityPipeline = nil; // SPH ρ per particle (reaction engine slice 1)
  id<MTLComputePipelineState> sphDensityFloorPipeline = nil; // per-particle cell-mean ρ floor (P/ρ² singularity fix)
  id<MTLComputePipelineState> sphPressurePipeline = nil; // SPH EOS pressure (reaction engine slice 2)
  id<MTLComputePipelineState> sphForcePipeline = nil;    // SPH pressure force (reaction engine slice 2b)

  // Conservation law reduction
  id<MTLComputePipelineState> reduceStatsPipeline = nil;
  id<MTLComputePipelineState> reduceCellMaxPipeline = nil;
  id<MTLComputePipelineState> mergeStarsPipeline = nil; // stellar mergers (US2 eating)
  id<MTLComputePipelineState> seedMarkPipeline = nil;   // mark seed cells (fate ladder)
  id<MTLComputePipelineState> seedApplyPipeline = nil;  // credit seed meals

  id<MTLBuffer> particleBuffer = nil;
  id<MTLBuffer> particleBufferRead = nil; // Double-buffer for collision reads

  // Spatial hash buffers
  static constexpr int kGridSize = 128; // 128³ = 2.1M cells. Bumped from 64
                                        // so the raytracer's volumetric
                                        // sample resolves finer detail in
                                        // the disk. cellSize = 6/128 ≈ 0.047
                                        // sim → ≈ 8% of half-screen at max
                                        // zoom (vs 16% at 64³). Trilinear
                                        // interp in sample_one_cell smooths
                                        // the rest.
  static constexpr int kTotalCells =
      kGridSize * kGridSize * kGridSize;     // 2,097,152
  // AMR (nested-mesh gravity): a 2nd 128³ grid over ±kAmrFineExtent at the
  // origin (the core, pinned there by comShift) → cellSize 2·2/128 = 0.03125
  // sim, ~32× finer than the coarse 1.0-sim cell, finally below the horizon
  // scale. Slice 1 = plumbing/measurement (SS_AMR); force wiring is Slice 2.
  // ── DAM TEST 2026-07-13 (Jamal go 18:38): 2.0 → 4.0. The L-transport soak
  // piled 3.8e5 M☉ at r≈2.66 = just OUTSIDE the old box (blend from 1.5);
  // his screen showed the core as a CUBE = matter stacked on the box faces.
  // Moving the face to 4.0 (blend from 3.0): pile falls inward → dam named;
  // re-parks at the new face → dam confirmed; stays at 2.66 → rotation
  // support is back as the answer. Costs resolution: fineCell 0.031 → 0.0625
  // (128³ unchanged) — still 16× finer than coarse, fine for the test.
  static constexpr float kAmrFineExtent = 4.0f;
  id<MTLBuffer> cellIndicesBuffer = nil;     // cell ID per particle
  id<MTLBuffer> cellCountsBuffer = nil;      // count per cell
  id<MTLBuffer> cellMassBuffer = nil;        // Σ stellar mass per cell (M_sun ×64, atomic)
  id<MTLBuffer> seedCountBuffer = nil;       // BH-seed registry counter (atomic, per frame)
  id<MTLBuffer> seedIdsBuffer = nil;         // BH-seed particle ids (≤256)
  id<MTLBuffer> cellSeedMapBuffer = nil;     // per-cell seed slot (victim lookup)
  id<MTLBuffer> seedAccumBuffer = nil;       // per-seed meal accumulator (8 uints: mass, meals, momentum ×3, reserved)
  id<MTLBuffer> accDiagBuffer = nil;         // [0]=max accuracy ratio ×1000 (Step 2 measurement, diagnostic)
  int lastOrtho = -1;                        // last config.orthoMode, for [PERF] (board item 12)
  id<MTLBuffer> sphClosureBuffer = nil;      // TEMP-CLOSURE ×1e6 int: [0]=W_sph, [1]=du dyn, [2]=du cool, [3]=du clamp (240f window)
  id<MTLBuffer> mergeClaimBuffer = nil;      // per-particle merge claim flags (cross-cell merging, zeroed each frame)
  id<MTLBuffer> cellStartsBuffer = nil;      // prefix sum offsets
  id<MTLBuffer> blockSumsBuffer = nil;       // block sums for parallel scan
  id<MTLBuffer> cellOffsetsBuffer = nil;     // atomic write offsets for scatter
  id<MTLBuffer> sortedParticlesBuffer = nil; // particle data in cell order
  id<MTLBuffer> cellCentroidsBuffer = nil;   // float4 per cell: xyz centroid, w count
  id<MTLBuffer> cellVelocitiesBuffer = nil;  // float4 per cell: xyz mean velocity (per-frame)
  id<MTLBuffer> cellMaxPartialsBuffer = nil; // {count,cid} per threadgroup (densest cell)
  id<MTLBuffer> phiBuffer = nil;             // PM gravity potential Φ per cell (float), warm-started across frames
  bool phiInitialized = false;               // zero Φ once on first alloc (warm-start persists after)
  // ── AMR nested-mesh gravity (Slice 1 plumbing, gated by SS_AMR) ──
  id<MTLComputePipelineState> binFineMassPipeline = nil; // fine-grid mass binning (bin_fine_mass)
  id<MTLComputePipelineState> poissonFinePipeline = nil; // fine SOR with nested (coarse-Φ) boundary
  id<MTLComputePipelineState> prolongatePipeline = nil;  // seed fine Φ from coarse Φ (2-level multigrid)
  id<MTLBuffer> fineCellMassBuffer = nil;    // Σ mass ×64 in the fine 128³ grid over ±kAmrFineExtent
  id<MTLBuffer> finePhiBuffer = nil;         // fine PM potential Φ (warm-started)
  id<MTLBuffer> coarsePhiPrevBuffer = nil;   // per-FINE-cell record of the coarse Φ already injected (delta-prolongation)
  id<MTLBuffer> fineHashUniformBuffer = nil; // SpatialHashUniforms with halfExtent=kAmrFineExtent
  // PLAYBACK PHASE (2026-07-26): per-particle INTEGRAL omega(r(t)) dt for the
  // time-lapse spin, replacing the absolute omega(r)*bhPoseTime angle that
  // carried the radial-drift counter-rotation. One float per particle (2M = 8 MB).
  id<MTLComputePipelineState> posePhasePipeline = nil; // pose_phase_advance
  id<MTLBuffer> posePhaseBuffer = nil;       // integrated playback phase, wrapped to [0, 2pi)
  float lastMFineEnc = 0.0f;                 // M within kAmrFineExtent (radial profile, 1-frame lag) → fine BC monopole
  float liveUAmbient = 6e-3f;                // mass-weighted mean u (SPH ledger window) → display ambient
  // SPH reaction engine (slice 0 plumbing): per-particle smoothed density ρ and
  // EOS pressure P, float each, sized to particle count (~28 MB at the 7M peak).
  // Written by sph_density (slice 1) / sph EOS (slice 2); inert until then.
  id<MTLBuffer> densityBuffer = nil;         // ρ_i = Σ_j m_j W(|r_ij|,h)  (M_sun / sim³)
  id<MTLBuffer> pressureBuffer = nil;        // P_i from the equation of state (sim units)
  id<MTLBuffer> uBuffer = nil;               // specific internal energy u_i (sim units, c²); PERSISTENT
  bool uInitialized = false;                 // seed u to the cold floor once, then it evolves
  id<MTLBuffer> sphForceBuffer = nil;        // float4/particle: SPH pressure acceleration (slice 2b)
  id<MTLBuffer> spatialHashUniformBuffer = nil;

  // Stats readback (partial sums from GPU reduction)
  id<MTLBuffer> partialSumsBuffer = nil;
  id<MTLBuffer> radialMassBuffer = nil;  // 256-shell enclosed-mass profile → honest horizon r_h
  // STABLE MIRROR (2026-07-15, readback-flicker fix): radialMassBuffer is blit-
  // zeroed EVERY frame, and the CPU stats read is async vs frames in flight —
  // a read between clear and re-accumulate saw all-zero shells → [HORIZON]
  // flickered r_h=0 (0.82→0→0.82 in the first-horizon soak). Same class as the
  // seedCount [4..7] persist slots. The reduce pass blit-copies the FINISHED
  // profile here (never cleared); the CPU only ever reads complete profiles.
  id<MTLBuffer> radialMassStableBuffer = nil;
  int numThreadgroups = 0;
  PhysicsStats latestStats = {};

  // Live-galaxy aggregates from the stats reduce (1-frame lag): centre of
  // mass + live star count. Feeds the self-gravity far-field monopole.
  float liveComX = 0.0f, liveComY = 0.0f, liveComZ = 0.0f;
  float liveCount = 0.0f;
  // Emergent-BH signal (Step 2, 1-frame lag): position of the densest
  // region + the stellar mass enclosed within R_ENC of it. The hole's
  // existence/strength derives from THIS, not from envelope phases.
  float bhPosX = 0.0f, bhPosY = 0.0f, bhPosZ = 0.0f;
  // Mean particle radius from the reduce (the [GRAV] line's meanR), retained
  // per frame to normalise the depth cue against WHERE MATTER ACTUALLY IS
  // rather than where it is permitted to be. See §H10. Seeded at the silence
  // cap so frame 0 is sane before the first reduce lands.
  float measuredMeanR = 100.0f;
  // Outermost live particle radius (the [GRAV] line's maxR), retained for the
  // same reason: the ray-march has to be back-extended to a radius OUTSIDE all
  // the matter, and that radius is a measured property of the field, not 60.
  float measuredMaxR = 100.0f;
  float bhMassEnc = 0.0f;     // stars (M_sun) within R_ENC of the peak
  float bhSeedMass = 0.0f;    // mass of the biggest body, RAW per-frame (= gMaxMass)
  // ⚠️ NOT monotonic, despite what this line said until 2026-08-28 10:00:00.
  // MEASURED over 17 captured runs (10,204 samples): gMaxMass FALLS between
  // consecutive samples in 8 of them, worst 108,670 → 40,776 M_sun in one step
  // (−62.5%), and three runs end at exactly 50 = M_BH_SEED (the seed is gone).
  // The 2026-06-13 note at the assignment site asserts "gMaxMass only grows via
  // eating, so the signal is monotonic and never flickers" — that is false.
  // Anything needing a hole that cannot shrink must use bhSeedMassMono below.
  float bhSeedMassMono = 0.0f; // THE HOLE'S MASS: running max of the seed while a
                               // seed-class body survives; 0 when none does. A black
                               // hole cannot shed mass, so its horizon cannot shrink.
  float lastHorizonR = 0.0f;  // honest geometric horizon r_h [sim] from the radial profile (1-frame lag)
  float lastHorizonMass = 0.0f; // M(<r_h) [M_sun] — drives the emergent time-lapse disk GM
  // HOW CLOSE THE FIELD IS TO BEING A HOLE, continuously: sup over the radial
  // profile of r_s(M(<r))/r. This is the SAME geometric criterion the horizon
  // search runs — the horizon is exactly where this crosses 1 — but kept as the
  // raw ratio instead of thresholded to a bool, so approach is a ramp, not a
  // step. The 2026-06-13 canon already specified strength = r_s(M_enc)/R_ENC;
  // it was unusable only because it was pinned to the single fixed shell
  // R_ENC=0.5 (needs 2.97e5 M_sun there). Measured where it is actually
  // largest, the same formula is live and reachable. (2026-08-03)
  float lastHorizonRatio = 0.0f;
  float bhDiskGMSmooth = 0.0f;  // eased posed-disk GM so rotation RAMPS in (no snap at hole-formation)
  float lastHorizonRSmooth = 0.0f; // eased r_h for RENDER keying only (shadow/lens/pose) — the probe steps every few seconds and the hole visibly JUMPED size (2026-07-19); physics keeps the raw value
  id<MTLRenderPipelineState> holePipeline = nil; // hole pass: r<r_h particles as black occluders
  // METRIC-NATIVE SHADOW (bit15, 2026-07-24): fullscreen backward geodesic
  // ray-march. Replaces the hole pass's r_h-sized particle silhouette with the
  // integrated capture set of the honest metric (b_c = 2.598 r_s). See the
  // shader banner in render.metal for the derivation + offline validation.
  // bhMarchPipeline deleted 2026-08-27 20:49:10 (the march is gone).
  id<MTLRenderPipelineState> bhBodyPipeline = nil; // hole-as-body, depth only
  id<MTLRenderPipelineState> dustPipeline = nil; // §2b: cold+dense gas as absorbing (reddening) dust splats
  id<MTLBuffer> lensAlphaLUT = nil; // 256×float exact Schwarzschild α(b/r_s), x∈[2.60,200] log-spaced
  // SPECTRAL STARMAP (increment 1, 2026-07-24): the one colour law's tables.
  // Baked but NOT YET BOUND — nothing calls spectrumToBands() until increment 2,
  // so this increment cannot change a single pixel. Verification is [SPEC-LUT]
  // against docs/spectral_bands_reference.txt, not the screen.
  id<MTLBuffer> spectralContinuumLUT = nil; // 256×float4 band flux (B,G,R,pad) vs T_eff = g·T
  id<MTLBuffer> spectralLinesLUT = nil;     // 128×float4 line weight per band vs g
  float lastDt = 1.0f / 120.0f; // previous frame's dt for time-corrected Verlet (init = spawn kDt → frame-1 correct)
  float timeWarpVal = 1.0f;     // physics-clock multiplier (x2/x4/x8 time controls); scales the pinned dt
  float lastParticleSize = 2.0f; // Size slider (1-frame lag) → scales the cluster's mass/gravity
  float bhStrength = 0.0f;    // collapse-fraction signal, smoothed+latched
  float bhStrengthEma = 0.0f; // eased raw signal (anti-flicker)
  bool bhFormedLatch = false; // once formed, stays formed (until reset)
  bool bhPosed = false;       // analytic BH pose active → spin the posed disk
  double bhPoseTime = 0.0;    // elapsed seconds since pose (render-clock driven)
  double bhPoseClock = 0.0;   // last render timestamp, for the pose dt
  double poseDtSmooth = 0.0;  // low-pass filtered wall frame delta (time-lapse clock)

  // ── EMERGENT TIME-LAPSE POSE dt (2026-07-26 19:3x) ────────────────────────
  // Was a FIXED 1.0/60.0 per RENDERED FRAME. That made the spin RATE
  // proportional to framerate: at 120 fps (paused, cheap frame) the clock
  // advanced 2.0 phase-seconds per real second; at 34 fps (playing) only 0.57 —
  // so pausing SPED THE DISK UP 3.5x. Jamal: "the paused mode is so much
  // smoother 120 fps and the spin is faster than at play, that doesn't make
  // sense." He is right; a rate that depends on framerate is a unit error, the
  // same class as the c3 clock bug.
  // The fixed step existed for a real reason (2026-07-25): the RAW wall delta
  // swung with the framerate and, multiplied by the ~10x time-lapse
  // compression, amplified that jitter into jumpy motion. So don't go back to
  // the raw delta — filter it. An EMA gives BOTH properties: the mean tracks
  // true wall time (rate is framerate-independent) while frame-to-frame noise
  // is smoothed over ~10 frames.
  double emergentPoseDt(bool paused, bool holdTimelapse) {
    double now = CACurrentMediaTime();
    double raw = (bhPoseClock > 0.0) ? (now - bhPoseClock) : (1.0 / 60.0);
    bhPoseClock = now;
    // Guard stalls and absurd frames before they enter the filter.
    raw = std::min(std::max(raw, 1.0 / 480.0), 0.1);
    if (poseDtSmooth <= 0.0) poseDtSmooth = raw;   // cold start = no ramp-in
    poseDtSmooth += (raw - poseDtSmooth) * 0.1;    // ~10-frame e-fold
    // Pause still freezes unless the time-lapse is explicitly held.
    return (paused && !holdTimelapse) ? 0.0 : poseDtSmooth;
  }
  float bhPoseMass = 0.0f;    // posed BH mass (M_sun) — re-pins bhSeedMass while posed
  float collapseFrac = 0.25f; // UI dial: core fraction = hole 100%
  float lastSphCoolTau = 2.0f; // slice-4 cooling τ₀ [simt] (mod-menu slider)
  uint32_t bhPeakCount = 0;   // densest single cell (true count, uncapped)
  float lastHashExtent = 64.0f; // extent the hash was actually built with
  // RENDER-side smoothed envelope phase: the raw phase is a DISCRETE state
  // id (0..4) — feeding it straight into the shader crossfades (starMix,
  // playMix) snapped the whole field's colour in one frame ("particles jump
  // from one color to the next"). Physics keeps the exact phase; the RENDER
  // eases toward it (~0.3 s) so every look transition is a motion.
  float renderPhaseSmooth = 0.0f;
  // G_sim·M_total is DERIVED, not tuned: N stars × 1 M_sun each, through the
  // Sgr A* unit anchor + K=130 time-lapse in core/units.h. At N = 2e6 this
  // gives ≈ 2.2 (the old hand-tuned 3.0 was unknowingly close).
  bool collisionsEnabled = false;  // OFF (Jamal 2026-07-07 14:25, A/B vs the god-forms look)
  unsigned int bhToggles = 0x7Fu; // BH-mechanism on/off bitmask (UI), default all-on
  int physicsSubsteps = 1;        // N fixed-dt physics steps/frame (set from config, read in runComputePass)
  // ⏱️ TRUE TIME (E1, 2026-08-30) — the wall-clock accumulator's state.
  // A FRAME IS NOT A UNIT OF TIME: the step SIZE is still pinned (0.0165*warp),
  // but the step COUNT is now owed by the real clock instead of assumed to be 1.
  double   trueTimeAcc  = 0.0;    // unspent real seconds carried between frames
  double   trueTimeLast = 0.0;    // CACurrentMediaTime() at the last computeStep
  int      pendingSteps = 1;      // steps the clock owes THIS frame (0, 1 or more)
  uint32_t simStepCounter = 0;    // monotonic count of steps ACTUALLY executed
  uint32_t ttStepsWindow = 0;     // [PERF] steps taken in the reporting window
  uint32_t ttClampWindow = 0;     // [PERF] frames the clamp had to drop debt
  bool bondNetworkEnabled = false; // OFF (Jamal 2026-07-07 14:25, A/B)

  // Noether symmetry breaking
  uint32_t prevVoiceHash = 0;
  float symmetryBreakImpulse = 0.0f;

  // Density heatmap
  id<MTLComputePipelineState> densityPipeline = nil;
  id<MTLTexture> densityTexture = nil;

  static const int kMaxInFlightFrames = 3;
  dispatch_semaphore_t inFlightSemaphore;
  int currentFrame = 0;

  id<MTLBuffer> voiceBuffer[kMaxInFlightFrames];
  id<MTLBuffer> uniformBuffer[kMaxInFlightFrames];
  id<MTLBuffer> cameraBuffer[kMaxInFlightFrames];
  id<MTLBuffer> postUniformBuffer[kMaxInFlightFrames];
  id<MTLBuffer> bhMarchUniformBuffer[kMaxInFlightFrames]; // metric ray-march (per-frame)
#if HAS_SYPHON
  id<MTLBuffer> postUniformSyphonBuffer[kMaxInFlightFrames]; // SDR uniform (headroom=1)
#endif

  id<MTLDepthStencilState> depthState = nil;
  id<MTLDepthStencilState> bgDepthState = nil;
  id<MTLTexture> depthTexture = nil;
  // ── DEPTH PRE-PASS (2026-08-11, board §H1/§H1b — P1 step 1) ───────────────
  // The project has never had a readable depth buffer: `depthState` is
  // write-OFF (:1033) and the main pass's depth attachment is
  // storeAction=DontCare (:3356), so the buffer is allocated, cleared every
  // frame, never written, and discarded. Consequences on the board: no
  // occlusion (P1), C4a's camera blur unprojects every pixel at a hardcoded
  // far-plane z=0.99 because there is nothing else to read, and C4b (per-
  // particle motion vectors → TAA) is blocked outright.
  // This writes NEAREST depth for the particle cloud into its OWN texture.
  // ⭐ A SEPARATE TEXTURE IS THE WHOLE POINT: the main colour pass keeps its own
  // cleared-and-discarded attachment, byte-for-byte untouched, so this cannot
  // change a pixel. Sharing one buffer would force the colour pass's `Less`
  // test to start REJECTING fragments the moment depth became non-empty —
  // a large, silent image change. Do not "simplify" these into one.
  id<MTLTexture> depthPrepassTexture = nil;
  id<MTLRenderPipelineState> depthPrepassPipeline = nil;
  id<MTLDepthStencilState> depthWriteState = nil;
  // particle_vertex's ONLY write target is the [KPROBE] atomic histogram
  // (buffer 9). Running the shader a second time would DOUBLE every bin, so
  // the pre-pass binds this scratch buffer instead and the probe stays honest.
  id<MTLBuffer> kProbeDummy = nil;
  id<MTLTexture> offscreenTexture = nil;
  id<MTLTexture> velocityTexture = nil;   // screen motion of the MATTER (2026-08-20)
  id<MTLTexture> prevFrameTexture = nil;
  // Whiteout probe (2026-07-23): 1×1 top-mip HDR frame average, read back
  // to CPU and printed ~1/s. Diagnostic only.
  id<MTLBuffer> lumProbeBuf = nil;
  double lumProbeLastPrint = 0.0;
  int lumProbeFrames = 0;
  // [KPROBE] (2026-07-28): 16-bin log-Kelvin histogram of the star path, three
  // weightings (count / luminance / luminance×area). Written by particle_vertex
  // buffer(9), cleared every frame, read back one frame late. Diagnostic only —
  // answers whether the visible star population is selection-biased blue.
  // Indexed by frameIdx: the semaphore guarantees the slot we are about to
  // overwrite belongs to a frame the GPU has FINISHED, so reading it before the
  // clear is race-free (no completion handler needed).
  id<MTLBuffer> kProbeBuf[kMaxInFlightFrames] = {nil};
  double kProbeLastPrint = 0.0;

  CAMetalLayer *metalLayer = nil;
  int particleCount = 0;
  int width = 0;
  int height = 0;
  uint32_t frameCount = 0;

  // Pending compute data (set before render)
  bool hasCompute = false;
  bool resetPending = false; // Phase 12 stability: Pulse trigger
  PhysicsUniforms physicsUniforms;

  // Phase 17: Envelope lifecycle state (set from main.cpp each frame)
  float envPhase = 0.0f;
  float envProgress = 0.0f;
  float envIntensity = 0.0f;
  // State that lives across computeStep's `physicsUniforms = {}` reset (set via
  // setters, copied into the uniform inside computeStep — like the envelope).
  float diskThicknessVal = 0.15f;
  float spinXVal = 0.0f;
  float spinYVal = 0.0f;

  float prevViewProj[16];

  // ═══ CIA-MODE WATERMARK STATE (Phase 19) ═══
  float wmOffsetX = 0.0f;
  float wmOffsetY = 0.0f;
  float wmVelX = 0.2f;
  float wmVelY = 0.15f;
  float wmShiftTimer = 0.0f;
  float wmShiftOffset = 0.0f;
  uint64_t lastRenderTime = 0;

  // GPU performance instrumentation
  float lastComputeMs = 0;
  float lastRenderMs = 0;
  int profileFrameCount = 0;
  // Per-window aggregation (steady-state vs spikes — one instantaneous sample
  // every 120f was lying about the cost; the 25ms reads were just whichever
  // frame coincided with a debug-readback stall).
  float profCompSum = 0, profCompMax = 0, profCompMin = 1e9f;
  float profRendSum = 0, profRendMax = 0, profRendMin = 1e9f;
  float profTotMax = 0;

  void runComputePass(id<MTLCommandBuffer> cmdBuf, int frameIdx);
  void renderWithCamera(id<CAMetalDrawable> drawable,
                        id<MTLCommandBuffer> cmdBuf, int frameIdx,
                        const RenderConfig &config);
};

Renderer::Renderer() : impl_(new Impl()) {}
Renderer::~Renderer() { delete impl_; }

bool Renderer::init(void *metalDevice, void *metalLayer, int width,
                    int height) {
  impl_->device = (__bridge id<MTLDevice>)metalDevice;
  impl_->metalLayer = (__bridge CAMetalLayer *)metalLayer;

  // Enable vsync (displaySyncEnabled defaults to YES, explicit for clarity)
  impl_->metalLayer.displaySyncEnabled = YES;

  impl_->commandQueue = [impl_->device newCommandQueue];
  impl_->computeCommandQueue = [impl_->device newCommandQueue];
#if HAS_SYPHON
  impl_->syphonServer = [[SyphonMetalServer alloc] initWithName:@"Main"
                                                         device:impl_->device
                                                        options:nil];
#endif
  impl_->frameEvent = [impl_->device newEvent];
  impl_->frameEventValue = 0;

  impl_->inFlightSemaphore =
      dispatch_semaphore_create(Impl::kMaxInFlightFrames);
  impl_->currentFrame = 0;

  NSError *error = nil;
  NSString *libPath = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"metallib"];
  if (!libPath) {
    // Fallback for build directory
    NSString *execPath = [[[NSProcessInfo processInfo] arguments][0] stringByDeletingLastPathComponent];
    libPath = [execPath stringByAppendingPathComponent:@"default.metallib"];
  }
  NSURL *libURL = [NSURL fileURLWithPath:libPath];
  impl_->library = [impl_->device newLibraryWithURL:libURL error:&error];

  if (!impl_->library) {
    NSLog(@"Failed to load Metal library at %@: %@", libPath, error);
    return false;
  }

  // ── Compute pipeline ────────────────────────────────────────────────
  id<MTLFunction> physicsFunc =
      [impl_->library newFunctionWithName:@"compute_physics"];
  if (physicsFunc) {
    impl_->physicsPipeline =
        [impl_->device newComputePipelineStateWithFunction:physicsFunc
                                                     error:&error];
    if (error)
      NSLog(@"Compute pipeline error: %@", error);
  }

  // Light orbit substep kernel (physics sub-stepping: cheap central-gravity
  // orbit advance between full passes).
  id<MTLFunction> orbitFunc =
      [impl_->library newFunctionWithName:@"orbit_substep"];
  if (orbitFunc) {
    impl_->orbitSubstepPipeline =
        [impl_->device newComputePipelineStateWithFunction:orbitFunc
                                                     error:&error];
    if (error)
      NSLog(@"orbit_substep pipeline error: %@", error);
  }

  // ── Spatial hash compute pipelines ──────────────────────────────────
  const char *spatialKernels[] = {"assign_cells",     "count_cells",
                                  "prefix_sum_local", "prefix_sum_blocks",
                                  "prefix_sum_add",   "scatter_particles",
                                  "compute_cell_centroids", "cell_balsara",
                                  "cic_clear_moments", "cic_deposit_moments",
                                  "cic_finalize_moments"};
  id<MTLComputePipelineState> *spatialPipelines[] = {
      &impl_->assignCellsPipeline,    &impl_->countCellsPipeline,
      &impl_->prefixSumLocalPipeline, &impl_->prefixSumBlocksPipeline,
      &impl_->prefixSumAddPipeline,   &impl_->scatterPipeline,
      &impl_->centroidPipeline,       &impl_->balsaraPipeline,
      &impl_->cicClearPipeline,       &impl_->cicDepositPipeline,
      &impl_->cicFinalizePipeline};
  for (int i = 0; i < 11; i++) {
    id<MTLFunction> fn = [impl_->library
        newFunctionWithName:[NSString stringWithUTF8String:spatialKernels[i]]];
    if (fn) {
      *spatialPipelines[i] =
          [impl_->device newComputePipelineStateWithFunction:fn error:&error];
      if (error)
        NSLog(@"Spatial hash pipeline error (%s): %@", spatialKernels[i],
              error);
    } else {
      NSLog(@"Missing spatial hash kernel: %s", spatialKernels[i]);
    }
  }

  // One-time capacity report: the prefix-sum pair must agree on block size
  // (pass 3b's kernel hardcodes 2048/block = 1024 threads in pass 3a).
  if (impl_->prefixSumLocalPipeline && impl_->prefixSumBlocksPipeline) {
    fprintf(stderr, "[HASH] tg caps: local=%lu blocks=%lu add=%lu\n",
            (unsigned long)impl_->prefixSumLocalPipeline.maxTotalThreadsPerThreadgroup,
            (unsigned long)impl_->prefixSumBlocksPipeline.maxTotalThreadsPerThreadgroup,
            (unsigned long)(impl_->prefixSumAddPipeline
                                ? impl_->prefixSumAddPipeline.maxTotalThreadsPerThreadgroup
                                : 0));
  }

  // ── PM gravity Poisson solver pipeline (red-black SOR) ──────────────
  id<MTLFunction> poissonFunc =
      [impl_->library newFunctionWithName:@"poisson_sor"];
  if (poissonFunc) {
    impl_->poissonPipeline =
        [impl_->device newComputePipelineStateWithFunction:poissonFunc
                                                     error:&error];
    if (error)
      NSLog(@"Poisson pipeline error: %@", error);
  } else {
    NSLog(@"Missing poisson_sor kernel");
  }

  // ── AMR fine-grid mass-binning pipeline (Slice 1) ───────────────────
  id<MTLFunction> binFineFunc =
      [impl_->library newFunctionWithName:@"bin_fine_mass"];
  if (binFineFunc) {
    impl_->binFineMassPipeline =
        [impl_->device newComputePipelineStateWithFunction:binFineFunc error:&error];
    if (error) NSLog(@"bin_fine_mass pipeline error: %@", error);
  } else {
    NSLog(@"Missing bin_fine_mass kernel");
  }

  // ── Playback phase integrator (2026-07-26) ──────────────────────────
  id<MTLFunction> posePhaseFunc =
      [impl_->library newFunctionWithName:@"pose_phase_advance"];
  if (posePhaseFunc) {
    impl_->posePhasePipeline =
        [impl_->device newComputePipelineStateWithFunction:posePhaseFunc error:&error];
    if (error) NSLog(@"pose_phase_advance pipeline error: %@", error);
  } else {
    NSLog(@"Missing pose_phase_advance kernel");
  }

  // ── AMR fine Poisson (nested coarse-Φ boundary) ─────────────────────
  id<MTLFunction> poissonFineFunc =
      [impl_->library newFunctionWithName:@"poisson_sor_fine"];
  if (poissonFineFunc) {
    impl_->poissonFinePipeline =
        [impl_->device newComputePipelineStateWithFunction:poissonFineFunc error:&error];
    if (error) NSLog(@"poisson_sor_fine pipeline error: %@", error);
  } else {
    NSLog(@"Missing poisson_sor_fine kernel");
  }

  // ── AMR prolongation (coarse Φ → fine grid initial guess) ───────────
  id<MTLFunction> prolongFunc =
      [impl_->library newFunctionWithName:@"prolongate_coarse_to_fine"];
  if (prolongFunc) {
    impl_->prolongatePipeline =
        [impl_->device newComputePipelineStateWithFunction:prolongFunc error:&error];
    if (error) NSLog(@"prolongate pipeline error: %@", error);
  } else {
    NSLog(@"Missing prolongate_coarse_to_fine kernel");
  }

  // ── SPH density pipeline (reaction engine slice 1) ──────────────────
  id<MTLFunction> sphDensityFunc =
      [impl_->library newFunctionWithName:@"sph_density"];
  if (sphDensityFunc) {
    impl_->sphDensityPipeline =
        [impl_->device newComputePipelineStateWithFunction:sphDensityFunc
                                                     error:&error];
    if (error)
      NSLog(@"SPH density pipeline error: %@", error);
  } else {
    NSLog(@"Missing sph_density kernel");
  }

  // ── SPH density FLOOR pipeline (per-particle cell-mean ρ) ────────────
  id<MTLFunction> sphDensityFloorFunc =
      [impl_->library newFunctionWithName:@"sph_density_floor"];
  if (sphDensityFloorFunc) {
    impl_->sphDensityFloorPipeline =
        [impl_->device newComputePipelineStateWithFunction:sphDensityFloorFunc
                                                     error:&error];
    if (error)
      NSLog(@"SPH density floor pipeline error: %@", error);
  } else {
    NSLog(@"Missing sph_density_floor kernel");
  }

  // ── SPH EOS pressure pipeline (reaction engine slice 2) ─────────────
  id<MTLFunction> sphPressureFunc =
      [impl_->library newFunctionWithName:@"sph_pressure"];
  if (sphPressureFunc) {
    impl_->sphPressurePipeline =
        [impl_->device newComputePipelineStateWithFunction:sphPressureFunc
                                                     error:&error];
    if (error)
      NSLog(@"SPH pressure pipeline error: %@", error);
  } else {
    NSLog(@"Missing sph_pressure kernel");
  }

  // ── SPH pressure-force pipeline (reaction engine slice 2b) ──────────
  id<MTLFunction> sphForceFunc =
      [impl_->library newFunctionWithName:@"sph_force"];
  if (sphForceFunc) {
    impl_->sphForcePipeline =
        [impl_->device newComputePipelineStateWithFunction:sphForceFunc
                                                     error:&error];
    if (error)
      NSLog(@"SPH force pipeline error: %@", error);
  } else {
    NSLog(@"Missing sph_force kernel");
  }

  // ── Density heatmap pipeline ────────────────────────────────────────
  id<MTLFunction> densityFunc =
      [impl_->library newFunctionWithName:@"density_heatmap"];
  if (densityFunc) {
    impl_->densityPipeline =
        [impl_->device newComputePipelineStateWithFunction:densityFunc
                                                     error:&error];
    if (error)
      NSLog(@"Density pipeline error: %@", error);
  }

  // ── Stellar-merger pipeline (US2 eating, emergent-BH arc step 2) ────
  id<MTLFunction> mergeFunc =
      [impl_->library newFunctionWithName:@"merge_stars"];
  if (mergeFunc) {
    impl_->mergeStarsPipeline =
        [impl_->device newComputePipelineStateWithFunction:mergeFunc
                                                     error:&error];
    if (error)
      NSLog(@"Merge pipeline error: %@", error);
  }

  // ── Seed mark/apply pipelines (victim-initiated feeding, step 3 v2) ──
  id<MTLFunction> seedMarkFunc =
      [impl_->library newFunctionWithName:@"seed_mark"];
  if (seedMarkFunc) {
    impl_->seedMarkPipeline =
        [impl_->device newComputePipelineStateWithFunction:seedMarkFunc
                                                     error:&error];
    if (error)
      NSLog(@"Seed-mark pipeline error: %@", error);
  }
  id<MTLFunction> seedApplyFunc =
      [impl_->library newFunctionWithName:@"seed_apply"];
  if (seedApplyFunc) {
    impl_->seedApplyPipeline =
        [impl_->device newComputePipelineStateWithFunction:seedApplyFunc
                                                     error:&error];
    if (error)
      NSLog(@"Seed-apply pipeline error: %@", error);
  }

  // ── Densest-cell reduce pipeline (emergent-BH signal) ───────────────
  id<MTLFunction> cellMaxFunc =
      [impl_->library newFunctionWithName:@"reduce_cell_max"];
  if (cellMaxFunc) {
    impl_->reduceCellMaxPipeline =
        [impl_->device newComputePipelineStateWithFunction:cellMaxFunc
                                                     error:&error];
    if (error)
      NSLog(@"Cell-max pipeline error: %@", error);
  }

  // ── Stats reduction pipeline ────────────────────────────────────────
  id<MTLFunction> reduceFunc =
      [impl_->library newFunctionWithName:@"reduce_stats"];
  if (reduceFunc) {
    impl_->reduceStatsPipeline =
        [impl_->device newComputePipelineStateWithFunction:reduceFunc
                                                     error:&error];
    if (error)
      NSLog(@"Reduce stats pipeline error: %@", error);
  }

  // ── Render pipeline ─────────────────────────────────────────────────
  id<MTLFunction> vertexFunc =
      [impl_->library newFunctionWithName:@"particle_vertex"];
  id<MTLFunction> fragmentFunc =
      [impl_->library newFunctionWithName:@"particle_fragment"];

  if (vertexFunc && fragmentFunc) {
    MTLRenderPipelineDescriptor *desc =
        [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = vertexFunc;
    desc.fragmentFunction = fragmentFunc;
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float; // HDR
    // ── MOTION VECTORS: attachment 1 (2026-08-20). The STAR pass is the only
    // thing that writes it — it is the only thing that is matter in motion.
    // Blending OFF: a velocity is a value, not light. Summing two stars'
    // velocities would give a direction neither of them travels.
    desc.colorAttachments[1].pixelFormat = MTLPixelFormatRG16Float;
    desc.colorAttachments[1].blendingEnabled = NO;
    desc.colorAttachments[0].blendingEnabled = YES;
    desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
    desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
    desc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    desc.colorAttachments[0].destinationAlphaBlendFactor =
        MTLBlendFactorOneMinusSourceAlpha;
    desc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;

    impl_->particlePipeline =
        [impl_->device newRenderPipelineStateWithDescriptor:desc error:&error];
    if (error)
      NSLog(@"Render pipeline error: %@", error);

    // ── DEPTH PRE-PASS pipeline — same vertex shader, NO fragment stage ──────
    // fragmentFunction = nil is a depth-only pipeline: the rasteriser runs and
    // writes depth, and no colour is produced because there is no colour
    // attachment. Reusing particle_vertex verbatim is deliberate — the depth
    // must land where the sprite lands, so any other vertex path would drift
    // out of agreement with the star pass the first time either changed.
    MTLRenderPipelineDescriptor *dpDesc =
        [[MTLRenderPipelineDescriptor alloc] init];
    dpDesc.vertexFunction = vertexFunc;
    dpDesc.fragmentFunction = nil;
    dpDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    NSError *dpErr = nil;
    impl_->depthPrepassPipeline =
        [impl_->device newRenderPipelineStateWithDescriptor:dpDesc error:&dpErr];
    if (dpErr)
      NSLog(@"Depth pre-pass pipeline error: %@", dpErr);
  } else {
    NSLog(@"Missing shader functions: vertex=%@, fragment=%@", vertexFunc,
          fragmentFunc);
  }

  // ── HOLE pipeline (2026-07-15): r<r_h particles as BLACK occluders ───
  // Darkening blend (dst *= 1−α) over the HDR target, drawn AFTER the
  // additive star pass — the particles inside the honest horizon eat the
  // light behind them (see render.metal hole_vertex for the physics note).
  {
    id<MTLFunction> holeV = [impl_->library newFunctionWithName:@"hole_vertex"];
    id<MTLFunction> holeF = [impl_->library newFunctionWithName:@"hole_fragment"];
    if (holeV && holeF) {
      MTLRenderPipelineDescriptor *hd = [[MTLRenderPipelineDescriptor alloc] init];
      hd.vertexFunction = holeV;
      hd.fragmentFunction = holeF;
      hd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float; // HDR
      // Attachment 1 must be DECLARED here (the pass has it). Masked off — but
      // ⛔ NOT for the reason this comment used to give. It said "this draw is not
      // moving matter", which is FALSE: the hole centre wanders (cam.bhX/Y/Z).
      // The REAL reason is that `hole_fragment` (render.metal:3080) returns a plain
      // float4 and declares no [[color(1)]], so unmasking would admit UNDEFINED data
      // into the velocity target, not motion. Give the shader a ParticleFragOut-style
      // velocity FIRST, then unmask. Corrected 2026-08-26, board row G6.
      hd.colorAttachments[1].pixelFormat = MTLPixelFormatRG16Float;
      hd.colorAttachments[1].writeMask = MTLColorWriteMaskNone;
      hd.colorAttachments[0].blendingEnabled = YES;
      hd.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorZero;
      hd.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
      hd.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorZero;
      hd.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
      hd.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
      impl_->holePipeline =
          [impl_->device newRenderPipelineStateWithDescriptor:hd error:&error];
      if (error) NSLog(@"Hole pipeline error: %@", error);
    } else {
      NSLog(@"Missing hole shader functions");
    }
  }

  // ── METRIC-NATIVE EMISSION pipeline (2026-07-25) ───────────────────────

  // ── THE HOLE AS A BODY (2026-08-14) — depth only, ZERO colour ────────────
  // See the banner above bhbody_fragment in render.metal. This is the pass that
  // makes the hole an OBJECT instead of an arranged gap: it writes the near
  // surface of the photon-capture sphere (b_c = 2.598 r_s) into the depth
  // attachment and writes NO colour at all. `writeMask = None` is the whole
  // point — it cannot paint, so the withdrawn 2026-07-24 fullscreen multiply
  // cannot recur; it removes light purely by occluding, which is exactly
  // "SHADOW = ABSENCE, NEVER PAINT".
  // The particle pass already depth-TESTS (MTLCompareFunctionLess, :1074) and
  // has simply never had anything to test against — so this one pass turns the
  // existing machinery on rather than adding a layer.
  {
    id<MTLFunction> bV = [impl_->library newFunctionWithName:@"bhmarch_vertex"];
    id<MTLFunction> bF = [impl_->library newFunctionWithName:@"bhbody_fragment"];
    if (bV && bF) {
      MTLRenderPipelineDescriptor *bd = [[MTLRenderPipelineDescriptor alloc] init];
      bd.vertexFunction = bV;
      bd.fragmentFunction = bF;
      bd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float;
      // Attachment 1 must be DECLARED here (the pass has it) and is masked off —
      // ⭐ THIS ONE IS CORRECT AND MUST STAY. bhBody is the DEPTH-ONLY capture sphere:
      // it writes no colour at all (see the attachment[0] mask just below). Invisible
      // geometry must never write motion vectors, or the smear drags colour along a
      // sphere nobody can see. Do NOT "fix" this one with the other three. (2026-08-26)
      bd.colorAttachments[1].pixelFormat = MTLPixelFormatRG16Float;
      bd.colorAttachments[1].writeMask = MTLColorWriteMaskNone;
      bd.colorAttachments[0].blendingEnabled = NO;
      bd.colorAttachments[0].writeMask = MTLColorWriteMaskNone; // DEPTH ONLY
      bd.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
      impl_->bhBodyPipeline =
          [impl_->device newRenderPipelineStateWithDescriptor:bd error:&error];
      if (error) NSLog(@"BH body pipeline error: %@", error);
    } else {
      NSLog(@"Missing bhbody shader functions");
    }
  }

  // ── DUST pipeline (design §2b, 2026-07-23): cold+dense gas as ABSORBING
  // splats. Per-channel darkening blend dst × (1 − src_rgb) — unlike the
  // hole's scalar (1−α), the colour factor lets dust absorb blue harder than
  // red, so light through it REDDENS (the physical extinction signature).
  {
    id<MTLFunction> dustV = [impl_->library newFunctionWithName:@"dust_vertex"];
    id<MTLFunction> dustF = [impl_->library newFunctionWithName:@"dust_fragment"];
    if (dustV && dustF) {
      MTLRenderPipelineDescriptor *dd = [[MTLRenderPipelineDescriptor alloc] init];
      dd.vertexFunction = dustV;
      dd.fragmentFunction = dustF;
      dd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float; // HDR
      // Attachment 1 must be DECLARED here (the pass has it). Masked off — but
      // ⛔ NOT for the reason this comment used to give. It said "this draw is not
      // moving matter", which is FALSE: the disk ROTATES.
      // The REAL reason is that `dust_fragment` (render.metal:3166) returns a plain
      // float4 and declares no [[color(1)]], so unmasking would admit UNDEFINED data.
      // Point sprite, so the star pass's method ports directly — project through the
      // CURRENT viewProjection at both ends. Corrected 2026-08-26, board row G6.
      dd.colorAttachments[1].pixelFormat = MTLPixelFormatRG16Float;
      dd.colorAttachments[1].writeMask = MTLColorWriteMaskNone;
      dd.colorAttachments[0].blendingEnabled = YES;
      dd.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorZero;
      dd.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceColor;
      dd.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorZero;
      dd.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
      dd.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
      impl_->dustPipeline =
          [impl_->device newRenderPipelineStateWithDescriptor:dd error:&error];
      if (error) NSLog(@"Dust pipeline error: %@", error);
    } else {
      NSLog(@"Missing dust shader functions");
    }
  }

  // ── DEFLECTION MAP LUT (2026-07-17): exact Schwarzschild bending angle ──
  // α(b) = 2∫₀^{u₀} du/√(1/b² − u²(1−u)) − π  (u = r_s/r, b in r_s units);
  // u₀ = turning point. Endpoint singularity killed by u = u₀(1−t²). The
  // shader samples this per particle (render.metal lensAlphaSample) — light
  // bends through the metric in world space; particles stay the only source.
  {
    const int N = 256;
    float table[N];
    // ── LUT RE-PARAMETERISED 2026-08-22: log-spaced in (b − b_c), not in b ──
    // The integral below is the EXACT Schwarzschild deflection and always was.
    // What was wrong is where we SAMPLED it. Log-spacing in b over [2.60, 200]
    // makes the first interval span 2.60000 → 2.64466 — a single linear segment
    // across the whole strong-deflection band, where α falls 6.8104 → 3.6624.
    // MEASURED against the integral at 200k quadrature points, same 256 entries:
    //     band 2.5985–2.600 (the photon ring):  18.16% error  →  0.000%
    //     band 2.600 –2.650 (the arcs):         23.58% error  →  0.000%
    //     band 20   –200   (far field):          0.00% error  →  0.053%
    // α DIVERGES as b → b_c⁺ (α = 6.81 rad at b−b_c = 0.0019; 11.20 rad at
    // 0.000024 — nearly two full turns). The old domain STARTED at 2.60, i.e.
    // 0.0019 above b_c, and `lensAlphaSample` saturated everything below it to
    // a constant 6.81. So the region that produces the photon ring — the one
    // place the strong field actually shows — was a flat line.
    // His words 2026-08-22: "there's no lens in the universe, just physics, and
    // we are hitting a brick wall of ours right there." The wall was ours: this
    // sampling schedule. Nothing is added here; the truncation is removed.
    // NOTE: the shader's lensAlphaSample MUST use the identical schedule.
    const double kBc  = 2.5980762;          // 3√3/2 — the capture radius, in r_s
    const double dMin = 1e-5, dMax = 200.0 - kBc;
    for (int k = 0; k < N; ++k) {
      double x = kBc + dMin * pow(dMax / dMin, (double)k / (N - 1));
      double invb2 = 1.0 / (x * x);
      double u0 = 1.0 / x;                       // Newton for the turning point
      for (int i = 0; i < 60; ++i) {
        double g  = invb2 - u0 * u0 * (1.0 - u0);
        double gp = -2.0 * u0 + 3.0 * u0 * u0;
        if (fabs(gp) < 1e-14) break;
        double step = g / gp;
        u0 = std::min(std::max(u0 - step, 1e-9), 0.66666);
        if (fabs(step) < 1e-14) break;
      }
      const int M = 1024;
      double sum = 0.0;
      for (int i = 0; i < M; ++i) {              // midpoint in t, u = u0(1−t²)
        double t = (i + 0.5) / M;
        double u = u0 * (1.0 - t * t);
        double g = invb2 - u * u * (1.0 - u);
        if (g > 0.0) sum += 2.0 * u0 * t / sqrt(g);
      }
      table[k] = (float)std::max(2.0 * (sum / M) - M_PI, 0.0);
    }
    impl_->lensAlphaLUT = [impl_->device newBufferWithBytes:table
                                                     length:sizeof(table)
                                                    options:MTLResourceStorageModeShared];
    auto idxOf = [&](double x) {
      return (int)(log((x - kBc) / dMin) / log(dMax / dMin) * (N - 1));
    };
    NSLog(@"[LENS-LUT] log(b-b_c) schedule | α(b_c+1e-5)=%.3f α(2.60)=%.3f "
          @"α(3.0)=%.3f α(10)=%.3f α(200)=%.4f rad",
          table[0], table[idxOf(2.60)], table[idxOf(3.0)],
          table[idxOf(10.0)], table[N - 1]);
  }

  // ── DISPLAY GRADE LUT (2026-08-03) ─────────────────────────────────────
  // Same contract as the spectral LUT below: the math lives in a shared header
  // (grade_lut.h) so the shipped bake and any offline verifier are the SAME
  // code and cannot drift. RGBA16Float because the chain is HDR throughout and
  // a half-float grade has no banding at 33 nodes.
  {
    using namespace space::grade;
    const int N = kGradeLutN;
    std::vector<float> lut((size_t)N * N * N * 4);
    bakeGradeLut(lut.data(), N);

    MTLTextureDescriptor *ld = [[MTLTextureDescriptor alloc] init];
    ld.textureType = MTLTextureType3D;
    ld.pixelFormat = MTLPixelFormatRGBA32Float; // bake is float32; no conversion step
    ld.width = (NSUInteger)N;
    ld.height = (NSUInteger)N;
    ld.depth = (NSUInteger)N;
    ld.usage = MTLTextureUsageShaderRead;
    impl_->gradeLutTexture = [impl_->device newTextureWithDescriptor:ld];
    [impl_->gradeLutTexture replaceRegion:MTLRegionMake3D(0, 0, 0, N, N, N)
                             mipmapLevel:0
                                   slice:0
                               withBytes:lut.data()
                             bytesPerRow:(NSUInteger)N * 4 * sizeof(float)
                           bytesPerImage:(NSUInteger)N * N * 4 * sizeof(float)];

    // Spot values, so the bake is verifiable from the log without a screenshot.
    // Pure black must receive the FULL tint (weight 1: no luma, no chroma), and
    // mid-grey must be untouched (above the toe), and a saturated red must be
    // untouched at ANY brightness (chroma guard — this is the one that proves
    // faint stars keep their colour).
    float k[3], mg[3], dr[3];
    gradeSample(0.0f, 0.0f, 0.0f, &k[0], &k[1], &k[2]);
    gradeSample(0.5f, 0.5f, 0.5f, &mg[0], &mg[1], &mg[2]);
    gradeSample(0.06f, 0.0f, 0.0f, &dr[0], &dr[1], &dr[2]);
    NSLog(@"[GRADE-LUT] %d^3  black→(%.4f,%.4f,%.4f) expect (%.3f,0,%.3f) · "
          @"mid-grey→(%.4f,%.4f,%.4f) expect identity · "
          @"faint red→(%.4f,%.4f,%.4f) expect identity (chroma guard)",
          N, k[0], k[1], k[2], kTintR * kLift, kTintB * kLift,
          mg[0], mg[1], mg[2], dr[0], dr[1], dr[2]);
  }

  // ── SPECTRAL STARMAP LUTs (increment 1, 2026-07-24) ────────────────────
  // DESIGN_2026-07-24_spectral_starmap.md §4.1. Same pattern as the lens LUT
  // above: double-precision CPU bake → shared buffer → NSLog spot values.
  // The math lives in spectral_lut.h, which the offline check
  // (scratchpad/spectral_check.cpp) also includes — the shipped table and the
  // verified table are the SAME code, so they cannot drift.
  //
  // ONE AXIS, NOT TWO. The spec sketched a 64×32 (T,g) table; g enters exactly
  // as a temperature scaling (g³·B_ν(ν/g,T) ≡ B_ν(ν,g·T)), so the continuum
  // collapses to a 1-D table in T_eff = g·T with NO approximation, and the
  // full g⁴ amplitude is already inside it. Nothing multiplies by g after.
  {
    using namespace space::spectral;
    // SS_BANDS=stellar|visible|hubble|nircam — default STELLAR as of 2026-08-24
    // 20:12:26, his order: "james webb and hubble as basis ... true to the
    // science and the gold standards: nasa". SS_BANDS=visible restores the
    // exact look shipped before that date. See the measured table in
    // spectral_lut.h before changing the default; nircam makes every star
    // above ~3000 K the same blue and is for the gas, not the stars.
    const char *bandEnv = getenv("SS_BANDS");
    const BandSet &bs = bandSetByName(bandEnv);
    printf("[SPECTRAL] band set '%s' (B %.3f-%.3f, G %.3f-%.3f, R %.3f-%.3f um)"
           " — SS_BANDS=stellar|visible|hubble|nircam\n",
           bs.name, bs.lo[0], bs.hi[0], bs.lo[1], bs.hi[1], bs.lo[2], bs.hi[2]);

    float cont[kContinuumN][4];
    for (int i = 0; i < kContinuumN; ++i) {
      double f[3];
      continuumBands(bs, continuumTempAt(i), f);
      cont[i][0] = (float)f[0];  // B
      cont[i][1] = (float)f[1];  // G
      cont[i][2] = (float)f[2];  // R
      cont[i][3] = 0.0f;
    }
    impl_->spectralContinuumLUT =
        [impl_->device newBufferWithBytes:cont
                                   length:sizeof(cont)
                                  options:MTLResourceStorageModeShared];

    float lines[kLinesN][4];
    for (int i = 0; i < kLinesN; ++i) {
      double w[3];
      lineBands(bs, linesGAt(i), w);
      lines[i][0] = (float)w[0];
      lines[i][1] = (float)w[1];
      lines[i][2] = (float)w[2];
      lines[i][3] = 0.0f;
    }
    impl_->spectralLinesLUT =
        [impl_->device newBufferWithBytes:lines
                                   length:sizeof(lines)
                                  options:MTLResourceStorageModeShared];

    // Spot values, NORMALISED per row exactly as the reference table is, so the
    // log can be compared line-for-line with docs/spectral_bands_reference.txt.
    auto row = [&](double T, float *r, float *g, float *b) {
      double f[3];
      continuumBands(bs, T, f);
      double m = std::max(f[0], std::max(f[1], f[2]));
      *r = (float)(f[2] / m); *g = (float)(f[1] / m); *b = (float)(f[0] / m);
    };
    float r1,g1,b1, r2,g2,b2, r3,g3,b3;
    row(2400.0, &r1,&g1,&b1); row(5772.0, &r2,&g2,&b2); row(40000.0, &r3,&g3,&b3);
    NSLog(@"[SPEC-LUT] band=%s  T=2400 (%.3f,%.3f,%.3f)  T=5772 (%.3f,%.3f,%.3f)  T=40000 (%.3f,%.3f,%.3f)",
          bs.name, r1,g1,b1, r2,g2,b2, r3,g3,b3);
    // Line membership at g=1 must read R,G,B (Hα→R, [OIII]→G, Hβ→B) — the
    // three-band signature that is WHY shocked gas reads teal-green (§3.1).
    double w1[3]; lineBands(bs, 1.0, w1);
    double w06[3]; lineBands(bs, 0.6, w06);
    // EXPECTATION UPDATED 2026-07-30: per-line Case B strengths replaced the
    // equal 1.0 weights (spectral_lut.h). At g=1 the three lands are unchanged
    // (Hα→R, [OIII]→G, Hβ→B) but the WEIGHTS are now Hβ=1.00, [OIII]=3.00,
    // Hα=2.86 → B/G/R = (1.00, 3.00, 2.86). Membership behaviour at g=0.60 is
    // untouched. Printed at 2dp so the ratios are actually checkable.
    // EXPECTATION IS NOW COMPUTED FROM THE LIVE BAND SET (2026-08-24). It used
    // to hardcode (1.00,3.00,2.86), which is only correct for band edges that
    // straddle all three lines; under `hubble` the real answer is (4.00,2.86,
    // 0.00) and the line read as a FAILURE when nothing was wrong.
    double we[3]; expectedLineBands(bs, we);
    NSLog(@"[SPEC-LUT] lines g=1.00 B/G/R weight (%.2f,%.2f,%.2f) — expect "
          @"(%.2f,%.2f,%.2f) for band set '%s'%s; g=0.60 (%.2f,%.2f,%.2f) — "
          @"expect (0,0,0), all three redshifted out",
          w1[0], w1[1], w1[2], we[0], we[1], we[2], bs.name,
          (we[0] > 0.0 && we[1] > 0.0 && we[2] > 0.0)
              ? " [one line per band]"
              : " [COLLAPSED — a channel has no line]",
          w06[0], w06[1], w06[2]);
  }

  // (Trajectory/ribbon pipeline DELETED 2026-08-20 — see render.metal.)

  // ── Post-FX pipeline ────────────────────────────────────────────────
  id<MTLFunction> postVertexFunc =
      [impl_->library newFunctionWithName:@"postfx_vertex"];
  id<MTLFunction> postFragmentFunc =
      [impl_->library newFunctionWithName:@"postfx_fragment"];

  if (postVertexFunc && postFragmentFunc) {
    MTLRenderPipelineDescriptor *desc =
        [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = postVertexFunc;
    desc.fragmentFunction = postFragmentFunc;
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float; // EDR drawable
    impl_->postPipeline =
        [impl_->device newRenderPipelineStateWithDescriptor:desc error:&error];
    if (error)
      NSLog(@"Post-FX pipeline error: %@", error);
  }

  // ── Ping-pong blur pipeline (HDR multi-pass building block) ──────────
  id<MTLFunction> blurFragmentFunc =
      [impl_->library newFunctionWithName:@"blur_fragment"];
  if (postVertexFunc && blurFragmentFunc) {
    MTLRenderPipelineDescriptor *desc =
        [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = postVertexFunc;       // reuse fullscreen triangle
    desc.fragmentFunction = blurFragmentFunc;
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float; // HDR
    impl_->blurPipeline =
        [impl_->device newRenderPipelineStateWithDescriptor:desc error:&error];
    if (error)
      NSLog(@"Blur pipeline error: %@", error);
  }

  // ── HDR bright-pass pipeline (bloom extraction) ──────────────────────
  id<MTLFunction> brightFragmentFunc =
      [impl_->library newFunctionWithName:@"bright_fragment"];
  if (postVertexFunc && brightFragmentFunc) {
    MTLRenderPipelineDescriptor *desc =
        [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = postVertexFunc;       // reuse fullscreen triangle
    desc.fragmentFunction = brightFragmentFunc;
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float; // HDR
    impl_->brightPipeline =
        [impl_->device newRenderPipelineStateWithDescriptor:desc error:&error];
    if (error)
      NSLog(@"Bright-pass pipeline error: %@", error);
  }

  // ── Bloom pyramid pipelines (downsample / upsample) ──────────────────
  // The downsample writes (DontCare → Store). The upsample is ADDITIVE: each
  // level is accumulated onto the level above, which is what makes the finished
  // glow the sum of every scale instead of one radius.
  id<MTLFunction> bloomDownFunc =
      [impl_->library newFunctionWithName:@"bloom_down_fragment"];
  if (postVertexFunc && bloomDownFunc) {
    MTLRenderPipelineDescriptor *desc =
        [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = postVertexFunc;       // reuse fullscreen triangle
    desc.fragmentFunction = bloomDownFunc;
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float; // HDR
    impl_->bloomDownPipeline =
        [impl_->device newRenderPipelineStateWithDescriptor:desc error:&error];
    if (error)
      NSLog(@"Bloom downsample pipeline error: %@", error);
  }
  id<MTLFunction> bloomUpFunc =
      [impl_->library newFunctionWithName:@"bloom_up_fragment"];
  if (postVertexFunc && bloomUpFunc) {
    MTLRenderPipelineDescriptor *desc =
        [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = postVertexFunc;       // reuse fullscreen triangle
    desc.fragmentFunction = bloomUpFunc;
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float; // HDR
    desc.colorAttachments[0].blendingEnabled = YES;
    desc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    desc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
    desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
    desc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    desc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
    impl_->bloomUpPipeline =
        [impl_->device newRenderPipelineStateWithDescriptor:desc error:&error];
    if (error)
      NSLog(@"Bloom upsample pipeline error: %@", error);
  }

  // Geodesic BH pipeline DELETED (2026-06-28) — fullscreen disk shader, not particles.

  // ── Depth state for Particles ───────────────────────────────────────
  MTLDepthStencilDescriptor *depthDesc =
      [[MTLDepthStencilDescriptor alloc] init];
  depthDesc.depthCompareFunction = MTLCompareFunctionLess;
  // VERY IMPORTANT: Turn off depth write for particles so they additively
  // blend!
  depthDesc.depthWriteEnabled = NO;

  impl_->depthState =
      [impl_->device newDepthStencilStateWithDescriptor:depthDesc];

  // ── Depth state for the DEPTH PRE-PASS: the one place that WRITES depth ───
  // Less + write ON = nearest-surface depth, the standard z-prepass. This is
  // the project's first and only depth write; `depthState` above stays
  // write-OFF so the additive star pass is unaffected (see the note on
  // depthPrepassTexture).
  MTLDepthStencilDescriptor *dpDepthDesc =
      [[MTLDepthStencilDescriptor alloc] init];
  dpDepthDesc.depthCompareFunction = MTLCompareFunctionLess;
  dpDepthDesc.depthWriteEnabled = YES;
  impl_->depthWriteState =
      [impl_->device newDepthStencilStateWithDescriptor:dpDepthDesc];

  // ── Depth state for Background (Black Hole) ─────────────────────────
  MTLDepthStencilDescriptor *bgDepthDesc =
      [[MTLDepthStencilDescriptor alloc] init];
  bgDepthDesc.depthCompareFunction = MTLCompareFunctionAlways; // Always draw
  bgDepthDesc.depthWriteEnabled = NO; // Don't write to depth buffer

  impl_->bgDepthState =
      [impl_->device newDepthStencilStateWithDescriptor:bgDepthDesc];

  for (int i = 0; i < Impl::kMaxInFlightFrames; i++) {
    impl_->cameraBuffer[i] =
        [impl_->device newBufferWithLength:sizeof(CameraUniforms)
                                   options:MTLResourceStorageModeShared];
    impl_->uniformBuffer[i] =
        [impl_->device newBufferWithLength:sizeof(PhysicsUniforms)
                                   options:MTLResourceStorageModeShared];
    impl_->postUniformBuffer[i] =
        [impl_->device newBufferWithLength:sizeof(PostFXUniforms)
                                   options:MTLResourceStorageModeShared];
    impl_->bhMarchUniformBuffer[i] =
        [impl_->device newBufferWithLength:sizeof(BHMarchUniforms)
                                   options:MTLResourceStorageModeShared];
#if HAS_SYPHON
    impl_->postUniformSyphonBuffer[i] =
        [impl_->device newBufferWithLength:sizeof(PostFXUniforms)
                                   options:MTLResourceStorageModeShared];
#endif
  }

  // Use layer's drawableSize directly to ensure sync with window backing
  // store
  CGSize dSize = impl_->metalLayer.drawableSize;
  resize((int)dSize.width, (int)dSize.height);

  return true;
}

void Renderer::uploadParticles(const GPUParticle *data, int count) {
  size_t size = count * sizeof(GPUParticle);
  impl_->particleCount = count;

  if (!impl_->particleBuffer || (size_t)impl_->particleBuffer.length < size) {
    impl_->particleBuffer =
        [impl_->device newBufferWithLength:size
                                   options:MTLResourceStorageModeShared];
  }
  memcpy(impl_->particleBuffer.contents, data, size);

  // TEMP-SLICE3 shock-tube harness (remove after slice-3 verdict). Env
  // SS_SPH_TEST=<v_rel in c> reseeds the field into TWO uniform spheres
  // (r=28, centers ±33 on x, 10 sim gap) closing at v_rel. Verlet encodes
  // velocity as prev = pos − v·dt (dt fixed 0.0165). Zero effect unless set.
  if (const char *tv = getenv("SS_SPH_TEST")) {
    float vrel = (float)atof(tv);
    if (vrel > 0.0f) {
      const float kDtFixed = 0.0165f;  // matches the pinned dt (renderer.mm computeStep)
      const float R = 28.0f, CX = 33.0f, vHalf = 0.5f * vrel;
      GPUParticle *p = (GPUParticle *)impl_->particleBuffer.contents;
      uint32_t rng = 0x9E3779B9u;
      auto frand = [&rng]() {  // xorshift → [0,1)
        rng ^= rng << 13; rng ^= rng >> 17; rng ^= rng << 5;
        return (float)(rng & 0x00FFFFFFu) / 16777216.0f;
      };
      // Only the RUNTIME live set goes in the blobs: the app runs the FIRST
      // 2M indices of the packed 10M buffer (measured: stride-97 mass>0
      // samples ≡ 2M/97 across all runs); the rest are killed after spawn.
      // Seeding all 10M put 54/cell in the blobs — over the ≤32 slot cap —
      // and poisoned every neighbour pass (measured). 2M at r=28 ≈ 11/cell.
      const int kLiveSet = 2000000;
      int nLive = 0;
      for (int i = 0; i < count && i < kLiveSet; ++i) {
        if (p[i].mass <= 0.0f) continue;
        float side = (nLive & 1) ? 1.0f : -1.0f;  // alternate LIVE → equal blobs
        nLive++;
        float x, y, z;
        do {  // uniform in the unit sphere (rejection)
          x = 2.0f * frand() - 1.0f;
          y = 2.0f * frand() - 1.0f;
          z = 2.0f * frand() - 1.0f;
        } while (x * x + y * y + z * z > 1.0f);
        p[i].x = side * CX + R * x;
        p[i].y = R * y;
        p[i].z = R * z;
        float vx = -side * vHalf;              // blobs close on each other
        p[i].prevX = p[i].x - vx * kDtFixed;
        p[i].prevY = p[i].y;
        p[i].prevZ = p[i].z;
      }
      fprintf(stderr,
              "[SPH] TEST HARNESS: 2 blobs r=%.0f centers ±%.0f, v_rel=%.3fc "
              "(live=%d of N=%d, masses/fields untouched)\n",
              R, CX, vrel, nLive, count);
    }
  }

  // Allocate spatial hash buffers (sized to particle count)
  size_t uintSize = count * sizeof(uint32_t);
  size_t cellSize = Impl::kTotalCells * sizeof(uint32_t);

  auto allocIfNeeded = [&](id<MTLBuffer> &buf, size_t sz) {
    if (!buf || (size_t)buf.length < sz) {
      buf = [impl_->device newBufferWithLength:sz
                                       options:MTLResourceStorageModeShared];
    }
  };

  allocIfNeeded(impl_->particleBufferRead, size);
  allocIfNeeded(impl_->cellIndicesBuffer, uintSize);
  allocIfNeeded(impl_->cellCountsBuffer, cellSize);
  allocIfNeeded(impl_->cellMassBuffer, cellSize);
  allocIfNeeded(impl_->phiBuffer, Impl::kTotalCells * sizeof(float)); // PM gravity Φ (warm-started)
  allocIfNeeded(impl_->fineCellMassBuffer, Impl::kTotalCells * sizeof(uint32_t)); // AMR fine grid mass
  allocIfNeeded(impl_->finePhiBuffer, Impl::kTotalCells * sizeof(float));         // AMR fine Φ
  allocIfNeeded(impl_->fineHashUniformBuffer, sizeof(SpatialHashUniforms));       // AMR fine uniforms
  allocIfNeeded(impl_->coarsePhiPrevBuffer, Impl::kTotalCells * sizeof(float));   // AMR delta-prolongation memory (zeroed by alloc)
  allocIfNeeded(impl_->densityBuffer, count * sizeof(float));  // SPH ρ per particle (slice 0 plumbing)
  allocIfNeeded(impl_->mergeClaimBuffer, count * sizeof(uint32_t)); // cross-cell merge claims
  allocIfNeeded(impl_->pressureBuffer, count * sizeof(float)); // SPH P per particle (slice 0 plumbing)
  // Integrated playback phase. Fresh MTLBuffers come back zeroed, so a cold
  // start has every phase at 0 → the render begins exactly at the physics
  // positions, identical to the old bhPoseTime = 0 behaviour.
  allocIfNeeded(impl_->posePhaseBuffer, count * sizeof(float));
  {
    // SPH internal energy u: allocate + seed the WHOLE buffer to the cold floor
    // (persistent; shocks heat it, radiation cools it). Re-seed on (re)alloc/upload.
    bool grew = (!impl_->uBuffer || (size_t)impl_->uBuffer.length < count * sizeof(float));
    allocIfNeeded(impl_->uBuffer, count * sizeof(float));
    if (grew || !impl_->uInitialized) {
      float *up = (float *)impl_->uBuffer.contents;
      float uf = (float)space::spacetime::kUFloorSim; // cold floor (rest ≈ collisionless)
      for (size_t i = 0; i < count; ++i) up[i] = uf;
      impl_->uInitialized = true;
    }
  }
  {
    bool grew = (!impl_->sphForceBuffer ||
                 (size_t)impl_->sphForceBuffer.length < count * 4 * sizeof(float));
    allocIfNeeded(impl_->sphForceBuffer, count * 4 * sizeof(float)); // float4/particle
    if (grew) memset(impl_->sphForceBuffer.contents, 0, count * 4 * sizeof(float));
  }
  allocIfNeeded(impl_->seedCountBuffer, 8 * sizeof(uint32_t)); // [0]=n [1]=meals [2]=eaten×64 [3]=scan [4..6]=probe
  allocIfNeeded(impl_->seedIdsBuffer, 1024 * sizeof(uint32_t)); // registry 256→1024 (2026-07-07: 347 live seeds measured, cap saturated)
  allocIfNeeded(impl_->cellSeedMapBuffer, cellSize);
  allocIfNeeded(impl_->seedAccumBuffer, 1024 * 8 * sizeof(uint32_t));
  // [0]=max accuracy ratio ×1e6, [1]=over-budget count.
  // TEMP A1″ MERGE-GATE COUNTERS (2026-08-13): [2]=merge attempts that reached
  // the CAS, [3]=merges that landed, [4]=merges refused by budget. CUMULATIVE
  // since launch — the per-frame clear below zeroes only [0..1] deliberately,
  // so these cannot be misread the way `feed=` was (a one-frame sample of a
  // per-frame-cleared buffer). Merge-side only: the capture-refusal counter
  // this replaced wrapped uint32 in 8 minutes and cost ~1.3e9 atomic adds.
  allocIfNeeded(impl_->accDiagBuffer, 8 * sizeof(uint32_t));
  allocIfNeeded(impl_->sphClosureBuffer, 8 * sizeof(int32_t)); // TEMP-CLOSURE window ledger (+poison count)
  allocIfNeeded(impl_->cellStartsBuffer, cellSize);
  size_t blockSumsSize = ((Impl::kTotalCells + 2047) / 2048) * sizeof(uint32_t);
  allocIfNeeded(impl_->blockSumsBuffer, blockSumsSize);
  allocIfNeeded(impl_->cellOffsetsBuffer, cellSize);
  allocIfNeeded(impl_->sortedParticlesBuffer, (NSUInteger)count * 48); // HOT sorted records (48B, was 80B Particle)
  allocIfNeeded(impl_->cellCentroidsBuffer, Impl::kTotalCells * 16); // float4/cell
  allocIfNeeded(impl_->cellVelocitiesBuffer, Impl::kTotalCells * 16); // float4/cell
  allocIfNeeded(impl_->cellBalsaraBuffer, Impl::kTotalCells * sizeof(float)); // shear/shock switch (zeroed by alloc)
  // DEFAULT ON since 2026-07-15 (Jamal's verdict on the live CIC bed; measured
  // cost ~3ms/frame at rest, show bed 33→30fps). SS_NO_CIC_MOMENTS=1 = A/B off.
  if (!getenv("SS_NO_CIC_MOMENTS"))                                // ~42MB
    allocIfNeeded(impl_->cicMomentsBuffer, Impl::kTotalCells * 5 * sizeof(float));
  allocIfNeeded(impl_->cellMaxPartialsBuffer,
                ((Impl::kTotalCells + 255) / 256) * 8); // {count,cid}/group
  allocIfNeeded(impl_->spatialHashUniformBuffer, sizeof(SpatialHashUniforms));

  // Density heatmap texture (256x256 R/W)
  if (!impl_->densityTexture) {
    MTLTextureDescriptor *densDesc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                     width:256
                                    height:256
                                 mipmapped:NO];
    densDesc.storageMode = MTLStorageModePrivate;
    densDesc.usage = MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead;
    impl_->densityTexture = [impl_->device newTextureWithDescriptor:densDesc];
  }

  // Partial sums buffer for reduction: 1 per threadgroup. SIZE IT FROM THE
  // PIPELINE'S REAL THREADGROUP CAPACITY — the fatter reduce_stats kernel
  // (16 threadgroup arrays) can push maxTotalThreadsPerThreadgroup below
  // 256; assuming 256 here undersizes the buffer → the kernel writes past
  // the end → corrupted stats (measured: live=8.9M of 2M, NaN COM).
  {
    NSUInteger tgCap = 256;
    if (impl_->reduceStatsPipeline) {
      tgCap = std::min(
          tgCap, impl_->reduceStatsPipeline.maxTotalThreadsPerThreadgroup);
      fprintf(stderr, "[GRAV] reduce_stats tgCap=%lu\n", (unsigned long)tgCap);
    }
    impl_->numThreadgroups = (count + (int)tgCap - 1) / (int)tgCap;
  }
  // 80 bytes = 20 floats per threadgroup, must match PartialStats in
  // particles.metal (8 stats + COM/live-count + radius + BH-enclosure).
  allocIfNeeded(impl_->partialSumsBuffer, impl_->numThreadgroups * 80);
  allocIfNeeded(impl_->radialMassBuffer, 256 * sizeof(uint32_t)); // 256-shell horizon profile
  allocIfNeeded(impl_->radialMassStableBuffer, 256 * sizeof(uint32_t)); // flicker-free CPU mirror
}

void Renderer::setBlackHolePose(bool on, float bhMassMsun) {
  // Declare a formed hole of mass bhMassMsun so the EXISTING real-lens maths all
  // activate on a posed disk: the shadow radius (b = 2.6·r_s(M) via bhSeedMass),
  // the point-mass lens equation + secondary fold-over image (gated on
  // bhStrength), and the raytracer (bhStrength>0.5). No per-frame maths is
  // changed — we just feed the renderer's own BH state from our geometry. The
  // sim must be paused while posed, else the collapse computation overwrites it.
  if (on) {
    impl_->bhSeedMass    = std::max(bhMassMsun, 0.0f); // → shadow b = 2.6·r_s(M)
    impl_->bhStrength    = 1.0f;
    impl_->bhStrengthEma = 1.0f;
    impl_->bhFormedLatch = true;
    impl_->bhPosed       = true;
    impl_->bhPoseMass    = std::max(bhMassMsun, 0.0f); // re-pin target (anti-clobber)
    impl_->bhPoseTime    = 0.0;   // restart the disk's orbital clock
    impl_->bhPoseClock   = 0.0;
  } else {
    impl_->bhFormedLatch = false; // release: recompute when physics resumes
    impl_->bhPosed       = false;
  }
}

void Renderer::resetParticles() {
  if (!impl_->particleBuffer || impl_->particleCount == 0)
    return;

  GPUParticle *gpuData = (GPUParticle *)impl_->particleBuffer.contents;
  for (int i = 0; i < impl_->particleCount; i++) {
    // Phase 10: Gaussian Universe Spawn via Box-Muller transform
    // This eradicates the visual "quadrat" and creates a soft void.
    float u1 = (float)rand() / RAND_MAX;
    float u2 = (float)rand() / RAND_MAX;
    float u3 = (float)rand() / RAND_MAX;
    float u4 = (float)rand() / RAND_MAX;

    // Generate two independent standard normal variables
    float z0 =
        sqrt(-2.0f * log(u1 > 0.0001f ? u1 : 0.0001f)) * cos(2.0f * M_PI * u2);
    float z1 =
        sqrt(-2.0f * log(u1 > 0.0001f ? u1 : 0.0001f)) * sin(2.0f * M_PI * u2);
    float z2 =
        sqrt(-2.0f * log(u3 > 0.0001f ? u3 : 0.0001f)) * cos(2.0f * M_PI * u4);

    gpuData[i].x = z0 * 1.2f; // StdDev 1.2
    gpuData[i].y = z1 * 1.2f;
    gpuData[i].z = z2 * 1.2f;
    gpuData[i].mass = 1.0f;

    gpuData[i].vx = gpuData[i].vy = gpuData[i].vz = 0.0f;
    gpuData[i].phase = 0.0f;
    gpuData[i].temperature = 0.0f;

    gpuData[i].prevX = gpuData[i].x;
    gpuData[i].prevY = gpuData[i].y;
    gpuData[i].prevZ = gpuData[i].z;

    gpuData[i].spinX = gpuData[i].spinY = gpuData[i].spinZ = 0.0f;
    gpuData[i].charge = (i % 2 == 0) ? 1.0f : -1.0f;
    gpuData[i].entanglementID = (uint32_t)rand() % impl_->particleCount;
    gpuData[i].pad1 = 0;
    gpuData[i].pad2 = 0xFFFFFFFFu;      // entanglement.z = bond target (none yet)
    gpuData[i].pad3 = (uint32_t)i;      // entanglement.w = own original index
  }
}

void Renderer::computeStep(float dt, const VoiceGPUData *voices, int voiceCount,
                           float totalAmplitude, float maxWaveDepth,
                           float jitterFactor, float speedCap,
                           float eFieldStiffness, float bFieldCirculation,
                           float gravityConstant, float stringStiffness,
                           float restLength, uint32_t debugFlags) {
  if (!impl_->physicsPipeline || impl_->particleCount == 0)
    return;

  // Upload voice data
  size_t voiceSize =
      std::max((size_t)(voiceCount * sizeof(VoiceGPUData)), (size_t)16);

  int frameIdx = impl_->currentFrame;
  if (!impl_->voiceBuffer[frameIdx] ||
      (size_t)impl_->voiceBuffer[frameIdx].length < voiceSize) {
    impl_->voiceBuffer[frameIdx] =
        [impl_->device newBufferWithLength:voiceSize
                                   options:MTLResourceStorageModeShared];
  }
  if (voiceCount > 0) {
    memcpy(impl_->voiceBuffer[frameIdx].contents, voices,
           voiceCount * sizeof(VoiceGPUData));
  }

  // Stage uniforms — will be dispatched in render()
  impl_->physicsUniforms = {};
  // ENERGY-CONSERVATION FIX 2026-06-30 (INTERIM — pending the proper integrator
  // decision): pin the physics dt to a FIXED step. The frame-rate-tied dt was
  // swinging ~4× (0.0086–0.033); the Verlet velocity carry-over is only a
  // first-order rescale (tcv=clamp(dt/dtPrev,0.5,2.5)), so ANY dt variation
  // injects energy when a force is present → the cluster heated to the cap and
  // dispersed. This was the root cause of the whole "no black hole" saga
  // (proven: fixed dt → cold cluster holds; variable/clamped dt → heats).
  // A 2:1 clamp still leaked (first-order correction); only a truly fixed step
  // conserves. NOTE: fixed dt decouples the sim rate from real FPS — the proper
  // fix is a fixed-dt accumulator (N substeps/frame) or velocity-Verlet; TBD.
  // TIMEWARP RESTORE (2026-07-23): the pinned base (0.0165) stays fixed frame-to-
  // frame — that's what kills the variable-FPS energy pump above — but it is now
  // scaled by the time-control multiplier so x2/x4/x8 and pause actually move the
  // physics clock again. Constant warp ⇒ dt still constant ⇒ tcv=1 ⇒ stability
  // intact; only a warp CHANGE causes a one-frame tcv blip (a deliberate action).
  dt = 0.0165f * impl_->timeWarpVal;
  impl_->physicsUniforms.dt = dt;
  impl_->physicsUniforms.dtPrev = dt; // tcv = dt/dtPrev = 1 exactly (fixed step)
  impl_->lastDt = dt;

  // ⏱️ TRUE TIME — E1, 2026-08-30. THE WALL-CLOCK ACCUMULATOR.
  // HIS LAW: "Our frames are just a window... the renderer is the readout of
  // the physics. Our shutter. A second is a second." Nothing physical may be
  // expressed per FRAME.
  // WAS: exactly one step per frame ⇒ sim-seconds per wall-second = 0.0165*fps.
  // Only 60.61 fps was honest. MEASURED 2026-08-29 (n=5): 119.5 fps → 1.97x
  // real time, 70.4 → 1.16x, 53.7 → 0.89x — a 2.2x spread from frame rate
  // alone, and the sequencer meanwhile advanced in WALL seconds, so his rhythm
  // and his universe ran on two clocks whose ratio was the frame rate.
  // NOW: the real clock says how many steps are owed; the frame just draws
  // whatever the universe reached.
  // ⭐ WHY THE WALL COST OF A STEP IS 0.0165 s AT EVERY WARP: a step advances
  // 0.0165*warp sim-seconds, and warp W is defined as "W sim-seconds per real
  // second", so wall-per-step = (0.0165*warp)/warp = 0.0165 exactly. The step
  // RATE is a constant 60.606 Hz — warp makes each step BIGGER, never more
  // frequent. That is why this half is affordable and why "warp = more steps"
  // (the other half, still open) is not: it would cost 23.65 ms per extra step.
  // SCOPE: step SIZE is untouched. Only the COUNT moves. At the frame rates he
  // actually runs this is 1 most frames, 0 when the shutter beat the universe,
  // 2 when it lagged.
  {
    static int sTrueTime = -1;
    if (sTrueTime < 0) {
      const char *e = getenv("SS_TRUE_TIME");
      sTrueTime = (e && e[0] == '0') ? 0 : 1;   // ON by default: this is the fix
      fprintf(stderr, "[TRUETIME] wall-clock accumulator %s\n",
              sTrueTime ? "ON" : "OFF (legacy: exactly 1 step per frame)");
    }
    // Anti-spiral clamp, and it defaults to ONE — MEASURED, not assumed.
    // A/B 2026-08-30, same machine, 2M particles, ortho on, warp 1:
    //   legacy (1 step/frame)  fps 47.5-51.9, realtime 0.78-0.86x, clamp 0
    //   accumulator, max 2     fps 15.0-16.2, realtime 0.50x, clamp 196-222/240
    // The second step does NOT buy time: this machine tops out near 50 physics
    // steps per WALL second, so asking for ~1.95 steps per frame just halved the
    // frame rate and delivered LESS real time for 2x the GPU. When the clock
    // outruns the machine the deficit is THROUGHPUT, not the clock — and the
    // cure for that is a cheaper step or an offline render, never more steps.
    // At max=1 this is >= legacy everywhere: above 60.61 fps it SKIPS steps and
    // pins the sim at real time (the fix); below it, it behaves exactly like
    // legacy and reports the shortfall as realtime<1 instead of hiding it.
    // SS_MAX_STEPS=N re-opens it for the catch-up experiment once a step is
    // cheap enough to be worth taking.
    static int sMaxSteps = -1;
    if (sMaxSteps < 0) {
      const char *e = getenv("SS_MAX_STEPS");
      sMaxSteps = e ? std::max(1, atoi(e)) : 1;
    }
    const double kStepWall = 0.0165;  // real seconds one step represents
    // Measured here, NOT taken from the frame callback: window.mm:712 clamps
    // that dt to 0.033 s, so any frame slower than 30 fps would under-report
    // real time — the exact class of hidden clock error this change removes.
    double nowTT = CACurrentMediaTime();
    double wall = (impl_->trueTimeLast > 0.0) ? (nowTT - impl_->trueTimeLast)
                                              : kStepWall;  // first frame
    impl_->trueTimeLast = nowTT;
    if (wall > 0.25) wall = 0.25;   // stall, or the far side of a SPACE pause
    if (!sTrueTime) {
      impl_->pendingSteps = 1;      // byte-for-byte the old behaviour
    } else {
      impl_->trueTimeAcc += wall;
      int n = (int)std::floor(impl_->trueTimeAcc / kStepWall);
      if (n < 0) n = 0;
      if (n > sMaxSteps) {
        // CANNOT KEEP UP. Cap the steps — but CARRY one step's worth of debt,
        // never zero it. MEASURED 2026-08-30 (interleaved n=3 pairs, fullscreen,
        // 2M): zeroing here DELETED real time. Legacy took 240 steps per 240
        // frames; this path took 208-238 and realtime fell 0.81 -> 0.58-0.79,
        // i.e. the clamp was worse than the bug it replaced. Capping the carry
        // at one step instead is spiral-proof (the debt can never grow) AND
        // lossless up to that bound: below 60.61 fps the accumulator then earns
        // exactly one step per frame, which IS the legacy path, and above it it
        // skips as intended. That is the "never worse than legacy" property the
        // zeroing broke.
        n = sMaxSteps;
        impl_->ttClampWindow++;
      }
      // SPEND ONLY WHAT WAS TAKEN — the clamped n, not the demanded n. Doing
      // this with the DEMANDED n (as the first cut did) silently discards the
      // steps the clamp refused, which is the same clock deletion in a new
      // dress: it left the carry a bare sub-step remainder and cost real time.
      impl_->trueTimeAcc -= (double)n * kStepWall;
      // Bounded carry: at most ONE step may ever be owed. That is what makes it
      // spiral-proof AND identical to legacy below 60.61 fps (every frame longer
      // than a step earns exactly one step, so steps == frames), while still
      // skipping above it.
      if (impl_->trueTimeAcc > kStepWall) impl_->trueTimeAcc = kStepWall;
      impl_->pendingSteps = n;
    }
    impl_->ttStepsWindow += (uint32_t)impl_->pendingSteps;
  }
  impl_->physicsUniforms.totalAmplitude =
      totalAmplitude; // Phase 17: Pass real synth amplitude for ADSR dynamics
  impl_->physicsUniforms.voiceCount = voiceCount; // Bug fix: Don't force 1 if 0
  impl_->physicsUniforms.particleCount = impl_->particleCount;
  impl_->physicsUniforms.maxWaveDepth = maxWaveDepth;
  impl_->physicsUniforms.plateRadius = 1.0f; // Normalized
  impl_->physicsUniforms.jitterFactor = jitterFactor;
  // FULLY PHYSICAL (Phase A1): the speed cap IS the speed of light, not a tuned
  // value. Stored as sim/(on-screen s); the kernel caps |v| = |finalV|/dt at it
  // so it's frame-rate-correct. (The UI 'speedCap'/'drive' still drives audio.)
  (void)speedCap;
  impl_->physicsUniforms.speedCap = (float)space::units::kCSimPerSec;
  impl_->physicsUniforms.frameCounter = impl_->frameCount++;

  // Noether symmetry breaking: detect voice config changes
  uint32_t voiceHash = 0;
  for (int i = 0; i < voiceCount; i++) {
    voiceHash ^= (uint32_t)(voices[i].m * 1000 + voices[i].n * 100);
    voiceHash = (voiceHash << 7) | (voiceHash >> 25); // rotate
  }
  if (voiceHash != impl_->prevVoiceHash && impl_->prevVoiceHash != 0) {
    impl_->symmetryBreakImpulse = 0.15f; // Trigger impulse
  } else {
    // Decay the impulse over time
    impl_->symmetryBreakImpulse *= 0.9f;
    if (impl_->symmetryBreakImpulse < 0.001f)
      impl_->symmetryBreakImpulse = 0.0f;
  }
  impl_->prevVoiceHash = voiceHash;

  impl_->physicsUniforms.symmetryBreakImpulse = impl_->symmetryBreakImpulse;
  impl_->physicsUniforms.collisionRadius = 0.02f;
  impl_->physicsUniforms.collisionsOn = impl_->collisionsEnabled ? 1 : 0;
  impl_->physicsUniforms.uncertaintyStrength = 1.0f;
  impl_->physicsUniforms.eFieldStiffness = eFieldStiffness;
  impl_->physicsUniforms.bFieldCirculation = bFieldCirculation;
  impl_->physicsUniforms.gravityConstant = gravityConstant;
  impl_->physicsUniforms.stringStiffness = stringStiffness;
  impl_->physicsUniforms.restLength = restLength;
  impl_->physicsUniforms.debugFlags = debugFlags;

  // Phase 17: Black Hole Lifecycle
  impl_->physicsUniforms.envelopePhase = impl_->envPhase;
  impl_->physicsUniforms.envelopeProgress = impl_->envProgress;
  impl_->physicsUniforms.lifecycleIntensity = impl_->envIntensity;
  // Survive the struct reset above (set via setters each frame).
  impl_->physicsUniforms.diskThickness = impl_->diskThicknessVal;
  impl_->physicsUniforms.spinX = impl_->spinXVal;
  impl_->physicsUniforms.spinY = impl_->spinYVal;
  impl_->physicsUniforms.bondNetworkOn = impl_->bondNetworkEnabled ? 1.0f : 0.0f;

  static float accumulatedTime = 0.0f;
  // ⏱️ TRUE TIME (E1): this clock is READ BY THE SHADER, so it must advance by
  // the sim time this frame actually integrates — dt per STEP, not dt per FRAME.
  accumulatedTime += dt * (float)impl_->pendingSteps;
  impl_->physicsUniforms.time = accumulatedTime;

  impl_->hasCompute = true;
}

// ── Renderer::render(config) — DELETED 2026-08-11 04:11:00 ──────────────────
// A 240-line ORTHO-ONLY duplicate of the render entry point, dead since the
// camera work moved every caller onto render(config, viewProj). Re-verified
// before deletion: main.cpp:2548 is the only call site in the tree and it
// passes a viewProj, so this overload had zero callers.
//
// It is worth knowing WHY this mattered beyond the line count: because it was
// compiled and grep-able but never executed, it kept answering questions about
// the live renderer with stale code. Two claims written into the board were
// read out of this body and were wrong about the running app — a hardcoded
// cameraPos, and a black-hole shadow radius still gated to ortho
// (`config.orthoMode && ...`) after the live path at :1783 had dropped that
// term in the A0 test. Deleting it removes the trap, not just the bytes.

void Renderer::render(const RenderConfig &config, const float *viewProj) {
  impl_->renderPhaseSmooth +=
      (config.envelopePhase - impl_->renderPhaseSmooth) * 0.04f;
  impl_->collapseFrac = config.collapseFrac;
  impl_->lastSphCoolTau = config.sphCoolTau;
  impl_->lastParticleSize = config.particleSize; // → mass/gravity scale in runComputePass
  if (impl_->particleCount == 0 || !impl_->particlePipeline)
    return;

  dispatch_semaphore_wait(impl_->inFlightSemaphore, DISPATCH_TIME_FOREVER);
  int frameIdx = impl_->currentFrame;

  id<CAMetalDrawable> drawable = [impl_->metalLayer nextDrawable];
  if (!drawable) {
    dispatch_semaphore_signal(impl_->inFlightSemaphore);
    return;
  }

  // 1. Async Compute Pass
  id<MTLCommandBuffer> computeCmdBuf =
      [impl_->computeCommandQueue commandBuffer];
  impl_->runComputePass(computeCmdBuf, frameIdx);

  impl_->frameEventValue++;
  uint64_t computeFinishedTicket = impl_->frameEventValue;
  [computeCmdBuf encodeSignalEvent:impl_->frameEvent
                             value:computeFinishedTicket];
  Impl *impl_ptr = impl_;
  [computeCmdBuf addCompletedHandler:^(id<MTLCommandBuffer> cb) {
    double gpuMs = (cb.GPUEndTime - cb.GPUStartTime) * 1000.0;
    impl_ptr->lastComputeMs = (float)gpuMs;
  }];
  [computeCmdBuf commit];

  // 2. Render Pass
  id<MTLCommandBuffer> renderCmdBuf = [impl_->commandQueue commandBuffer];

  __block dispatch_semaphore_t block_sema = impl_->inFlightSemaphore;
  [renderCmdBuf addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
    dispatch_semaphore_signal(block_sema);
    double gpuMs = (buffer.GPUEndTime - buffer.GPUStartTime) * 1000.0;
    impl_ptr->lastRenderMs = (float)gpuMs;
    float c = impl_ptr->lastComputeMs, r = impl_ptr->lastRenderMs, t = c + r;
    impl_ptr->profCompSum += c;  impl_ptr->profRendSum += r;
    impl_ptr->profCompMax = fmaxf(impl_ptr->profCompMax, c);
    impl_ptr->profRendMax = fmaxf(impl_ptr->profRendMax, r);
    impl_ptr->profCompMin = fminf(impl_ptr->profCompMin, c);
    impl_ptr->profRendMin = fminf(impl_ptr->profRendMin, r);
    impl_ptr->profTotMax  = fmaxf(impl_ptr->profTotMax, t);
    impl_ptr->profileFrameCount++;
    if (impl_ptr->profileFrameCount % 120 == 0) {
      const float inv = 1.0f / 120.0f;
      printf("[PROFILE/120f] Compute avg %.2f (min %.2f max %.2f) | Render+PostFX avg %.2f (min %.2f max %.2f) | Total avg %.2f max %.2f ms\n",
             impl_ptr->profCompSum * inv, impl_ptr->profCompMin, impl_ptr->profCompMax,
             impl_ptr->profRendSum * inv, impl_ptr->profRendMin, impl_ptr->profRendMax,
             (impl_ptr->profCompSum + impl_ptr->profRendSum) * inv, impl_ptr->profTotMax);
      impl_ptr->profCompSum = 0; impl_ptr->profRendSum = 0;
      impl_ptr->profCompMax = 0; impl_ptr->profRendMax = 0;
      impl_ptr->profCompMin = 1e9f; impl_ptr->profRendMin = 1e9f; impl_ptr->profTotMax = 0;
    }
  }];

  // Wait for compute
  [renderCmdBuf encodeWaitForEvent:impl_->frameEvent
                             value:computeFinishedTicket];

  // ── Camera ──────────────────────────────────────────────────────────
  CameraUniforms cam = {};
  memcpy(cam.viewProj, viewProj, 16 * sizeof(float));
  // World-space camera position — was previously NEVER set in this render
  // path, leaving cameraPos = (0,0,0). The raytracer then started rays AT
  // the BH origin → all rays inside the horizon → BH appeared huge.
  cam.cameraPos[0] = config.cameraPos[0];
  cam.cameraPos[1] = config.cameraPos[1];
  cam.cameraPos[2] = config.cameraPos[2];
  // F5 2026-08-10: the shader's view axis, supplied instead of re-derived from
  // cameraPos. See camera.h::getForward for why the inline derivation was a trap.
  cam.viewForwardX = config.cameraForward[0];
  cam.viewForwardY = config.cameraForward[1];
  cam.viewForwardZ = config.cameraForward[2];
  cam.cameraPad = config.cameraRho;
  cam.particleSize = config.particleSize;
  cam.plateRadius = config.plateRadius;
  // Was `? 1.0f : 0.0f` — a switch. Now an AMOUNT: the shader blends rather
  // than replaces, so this carries how far to go (2026-08-24).
  cam.phaseViz = config.phaseViz ? config.phaseVizAmount : 0.0f;
  cam.envelopePhase = impl_->renderPhaseSmooth; // smoothed (render-only)
  // ── FIELD HALF-DEPTH for the scale-invariant depth cue (2026-08-11, §H10) ──
  // Mirrors the PHYSICS cap law at particles.metal:3051 term for term, using
  // the same smoothed phase the shader sees, so the render's idea of "how deep
  // is the field" cannot drift from where the physics actually puts matter:
  //   play (0.5 <= ph < 3.5) -> ORBIT_R_CHLADNI, blended in over attack
  //   silence                -> STAR_MAP_CAP
  // Z is bounded by EIGEN_L*0.5 = 6.0 during play, the same 6.0, so one scalar
  // covers both axes and the camera may orbit freely.
  // ⭐ CORRECTED 2026-08-11 15:2x after his verdict "exact same look, unchanged".
  // The first version normalised by the CAP (STAR_MAP_CAP=100 in silence,
  // ORBIT_R_CHLADNI=6 in play), mirroring the physics cap law. **Measured, that
  // was wrong by ~15x.** The cap is what matter is ALLOWED to occupy; the field
  // actually sits at meanR 6.4-9.3 sim with r50 3.2-4.8 (its own [GRAV]/[DISKZ]
  // telemetry). Against R=100 the cue produced a 3.7% size spread — invisible,
  // which is precisely the verdict.
  // ⭐ It now uses the MEASURED mean radius, so the cue tracks the field as it
  // collapses or disperses instead of a constant that was never true.
  // ⭐ AND THIS REMOVES THE DUPLICATION I DECLARED AN HOUR AGO: no copy of
  // STAR_MAP_CAP / ORBIT_R_CHLADNI on the CPU any more. The measurement is the
  // single source of truth, which is what it should have been from the start.
  // ⚠️ 1-frame lag (every readback here is), invisible for a size cue.
  cam.fieldHalfDepth = std::max(impl_->measuredMeanR, 0.5f);
  cam.envelopeProgress = config.envelopeProgress;
  cam.orthoMode = config.orthoMode ? 1.0f : 0.0f;
  impl_->lastOrtho = config.orthoMode ? 1 : 0;   // recorded so [PERF] says which mode it measured
  // Lens Einstein radius = the shadow's on-screen radius, so the lensed
  // particle ring lands exactly on the raytraced shadow edge (ring radius ==
  // hole radius). Ortho only: half-screen (world) = cameraRho*1.2, and a
  // sim-radius r projects to NDC r*plateRadius/(cameraRho*1.2). Perspective
  // → 0 disables the lens.
  {
    float frustum = config.cameraRho * 1.2f;
    // PHYSICAL Einstein radius: the lens ring derives from the HOLE'S REAL
    // MASS (photon capture b = 2.6·r_s(M_core)), not an arbitrary UI size —
    // that mismatch made the lens sphere and the physical disk read as two
    // layered bodies. "BH Size" is now a ×multiplier (default 1 = physics):
    // the lens grows as the hole eats, always matching the disk it carved.
    // HONEST-HORIZON RE-KEY (2026-07-15): when the geometric criterion has
    // fired (lastHorizonR > 0 — real enclosed mass, no cheats), the lens
    // derives from THAT r_s. The legacy seed-mass path remains as fallback
    // for the posed/cheat modes (bhSeedMass ≈ 50 M☉ in the honest bed —
    // an invisible 2e-4 lens — which is why the first honest hole had no
    // lensing at all).
    // HONEST LENS KEY (2026-07-19): the lens exists iff the honest hole does.
    // The old unconditional seed-mass fallback kept rsEff > 0 after play
    // fattened the seeds, so the lens SURVIVED the hole's death and its size
    // stopped tracking r_h ("lensing stays even if black hole disappears...
    // not in scale with the actual event horizon"). Seed-mass keying now only
    // serves the DECLARED posed hole (setBlackHolePose).
    // SMOOTH HONEST r_h (2026-07-19 18:20): the probe updates r_h every few
    // seconds, so everything keyed to it JUMPED size at each step ("it just
    // jumps, doesn't smoothly grow"). Same cure as bhDiskGMSmooth: ease the
    // RENDER keying (~0.7 s e-fold). Physics keeps the raw honest value.
    impl_->lastHorizonRSmooth +=
        (impl_->lastHorizonR - impl_->lastHorizonRSmooth) * 0.03f;
    if (impl_->lastHorizonRSmooth < 1e-4f && impl_->lastHorizonR == 0.0f)
      impl_->lastHorizonRSmooth = 0.0f;   // settle the tail to true zero
    float rsEff = impl_->bhPosed
        ? std::max(impl_->lastHorizonRSmooth,
                   (float)space::units::kRsSimPerMsun *
                       std::max(impl_->bhSeedMass, 0.0f))
        : impl_->lastHorizonRSmooth;
    float bSim = 2.6f * rsEff * config.shadowRadius; // photon capture b = 2.6 r_s
    bool bhLensActive = (impl_->physicsUniforms.totalAmplitude < 0.02f); // lens OFF during play
    // A0 TEST, 2026-08-10 09:58:00 — the `config.orthoMode &&` term is REMOVED.
    // It forced this radius to literally 0.0f whenever ortho was off, and every
    // shader gate keys on `> 1e-4` (render.metal:671, :771, :879), so the hole
    // was not drawn AT ALL in perspective — it never degraded, it ceased to
    // exist. That is his standing "it needs to survive non-ortho mode".
    // The ortho path is UNCHANGED (the term was already true there); this only
    // adds the perspective case.
    // KNOWN-WRONG SCALE, stated BEFORE the measurement: `/frustum` is the ORTHO
    // world→NDC map (frustum = cameraRho*1.2 = the screen's world half-height).
    // Perspective's half-height is d*tan(fovY/2) = d*0.414214 at 45°, so this
    // radius should come out ~1.2/0.414214 = 2.897x TOO SMALL. And `d` must be
    // camera→HOLE, not cameraRho (camera→ORIGIN) — the seed wanders, so the
    // error should grow as it drifts off-origin. Fixing the divisor is the NEXT
    // change, deliberately not batched into this one.
    // ── L1 FIXED 2026-08-20 — the divisor is the screen half-height AT THE
    // HOLE, and it is not the same number in both projections ────────────────
    // `frustum` (= cameraRho*1.2) is the ORTHO world→NDC map and was being used
    // in BOTH modes. Under perspective the world half-height at distance d is
    // d*tan(fovY/2), and the fov main.cpp:776 actually passes is 45°, so
    // tan(22.5°) = 0.414214. Using the ortho map there made the shadow
    // 1.2/0.414214 = 2.897x TOO SMALL — exactly the factor the note above
    // predicted before anyone measured it.
    //
    // d is camera→HOLE, not camera→origin. Computed from the real vectors here
    // rather than assumed: under the origin lock (L5, bhPosX/Y/Z hard-zeroed)
    // they are the same number today, but writing cameraRho would bake that
    // lock into the lens and it would go wrong silently the day it lifts.
    const float kTanHalfFov = 0.414214f;      // tan(45°/2), the fov at main.cpp:776
    float hx = impl_->bhPosX * config.plateRadius;
    float hy = impl_->bhPosY * config.plateRadius;
    float hz = impl_->bhPosZ * config.plateRadius;
    float dx = config.cameraPos[0] - hx;
    float dy = config.cameraPos[1] - hy;
    float dz = config.cameraPos[2] - hz;
    float dHole = std::sqrt(dx * dx + dy * dy + dz * dz);
    float halfH = config.orthoMode ? frustum : (dHole * kTanHalfFov);
    cam.bhShadowNdcRadius =
        (halfH > 1e-4f && bhLensActive)
            ? bSim * config.plateRadius / halfH
            : 0.0f;
    cam.aspect = (float)impl_->width / (float)impl_->height;
  // S2: 2260 = his fullscreen drawable height, MEASURED 2026-08-21 21:28:59
  // ([DEPTHPREPASS] target 3600x2260). Fullscreen therefore lands on exactly
  // 1.0 and is unchanged; every other resolution is normalised to it.
  cam.sizeResScale = (float)impl_->height / 2260.0f;
  }
  cam.sharpness = config.sharpness;
  cam.grainAlpha = config.grainAlpha;
  cam.oscAmount = config.oscAmount;
  cam.spinX = config.spinX;
  cam.spinY = config.spinY;
  cam.spinZ = config.spinZ;
  cam.viewportH = (float)impl_->height;
  cam.spinAngleZ = config.spinAngleZ;
  cam.spinAngleX = config.spinAngleX;
  cam.spinAngleY = config.spinAngleY;
  cam.bhStrength = impl_->bhStrength;
  // ── Posed-BH disk rotation: feed real Keplerian Ω(r) to the vertex shader ──
  // Advance a render-clock (runs even while the sim is PAUSED) and pass GM +
  // elapsed time so the shader spins the posed disk at Ω(r)=√(GM/r³). Zeroed
  // when not posed → zero effect on the live sim. Only one render() overload
  // runs per frame, so the clock advances once.
  if (impl_->bhPosed) {
    double now = CACurrentMediaTime();
    double dtP = (impl_->bhPoseClock > 0.0) ? (now - impl_->bhPoseClock) : 0.0;
    impl_->bhPoseClock = now;
    dtP = std::min(std::max(dtP, 0.0), 0.1);   // guard stalls
    // DECLARED TIME-LAPSE, DERIVED FROM THE HOLE (2026-07-24). Physical Omega
    // at our GM gives 38 s per ISCO orbit and 12.5 min at R_DISK=18 — visually
    // static, and far below the screen-space speed the streak path needs
    // (elong = speed*1.4), so every sprite stayed a circular dot: THE reason
    // near-hole matter read as stars instead of gaseous trails. The old
    // comment claimed this clock was compressed; it was not, dtP was the raw
    // wall delta.
    // The factor is NOT a chosen multiplier. The dial states a PHYSICAL fact —
    // how many screen-seconds one ISCO orbit takes — and the compression falls
    // out of the hole's own mass, so it re-derives as the hole eats instead of
    // drifting. Scaling dtP (not just the accumulator) also scales bhPoseDt,
    // so the per-frame delta the streaks measure grows with it.
    double gmNow = space::units::gmSim((double)impl_->bhSeedMass);
    // c³ FIX (2026-07-25 22:00:00): was kIscoPeriodPerGM * gmNow, the c=1 form
    // applied to the WARPED (per-wall-s²) coupling — 43.4334x too large, so this
    // clock ran x145 the physics instead of the dial's x3.3. See units.h.
    double tIsco = space::units::iscoPeriodWallSec(gmNow);  // wall s, REAL
    if (config.iscoScreenSeconds > 1e-3f && tIsco > 0.0)
      dtP *= tIsco / (double)config.iscoScreenSeconds;
    impl_->bhPoseTime += dtP;
    cam.bhDiskGM   = (float)gmNow;
    cam.bhPoseTime = (float)impl_->bhPoseTime;
    cam.bhPoseDt   = (float)dtP;
    cam.bhDiskAxisY = 0.0f;                    // legacy posed disk lives in x–y
  } else if (impl_->lastHorizonR > 0.0f && impl_->lastHorizonMass > 0.5f) {
    // EMERGENT-HOLE TIME-LAPSE (2026-07-15, Jamal: "rotation means time
    // passes on a trajectory"): the same Keplerian playback clock, keyed to
    // the HONEST hole — GM from the real M(<r_h), disk axis y. Live physics
    // keeps running underneath; this compresses the RENDER clock only.
    // TIME-LAPSE CLOCK = FILTERED WALL DELTA (2026-07-26). The fixed 1/60 per
    // rendered frame made the spin rate proportional to framerate (paused at
    // 120 fps spun 3.5x faster than playing at 34) — see emergentPoseDt().
    double dtP = impl_->emergentPoseDt(config.simPaused,
                                       config.pauseHoldTimelapse);
    // DECLARED TIME-LAPSE, DERIVED FROM THE HOLE (2026-07-24). Physical Omega
    // at our GM gives 38 s per ISCO orbit and 12.5 min at R_DISK=18 — visually
    // static, and far below the screen-space speed the streak path needs
    // (elong = speed*1.4), so every sprite stayed a circular dot: THE reason
    // near-hole matter read as stars instead of gaseous trails. The old
    // comment claimed this clock was compressed; it was not, dtP was the raw
    // wall delta.
    // The factor is NOT a chosen multiplier. The dial states a PHYSICAL fact —
    // how many screen-seconds one ISCO orbit takes — and the compression falls
    // out of the hole's own mass, so it re-derives as the hole eats instead of
    // drifting. Scaling dtP (not just the accumulator) also scales bhPoseDt,
    // so the per-frame delta the streaks measure grows with it.
    double gmNow = space::units::gmSim((double)impl_->lastHorizonMass);
    // c³ FIX (2026-07-25 22:00:00): was kIscoPeriodPerGM * gmNow, the c=1 form
    // applied to the WARPED (per-wall-s²) coupling — 43.4334x too large, so this
    // clock ran x145 the physics instead of the dial's x3.3. See units.h.
    double tIsco = space::units::iscoPeriodWallSec(gmNow);  // wall s, REAL
    if (config.iscoScreenSeconds > 1e-3f && tIsco > 0.0)
      dtP *= tIsco / (double)config.iscoScreenSeconds;
    impl_->bhPoseTime += dtP;
    cam.bhDiskGM   = (float)gmNow;
    cam.bhPoseTime = (float)impl_->bhPoseTime;
    cam.bhPoseDt   = (float)dtP;
    // PLATE-PLANE ALIGNMENT (2026-07-16, item 4): the galaxy now orbits about
    // Z (the Chladni plate's plane, face-on at launch) — the emergent
    // time-lapse uses the legacy z-axis playback (which also matches the
    // legacy Doppler plane). The y-axis branch sleeps.
    cam.bhDiskAxisY = 0.0f;
  } else {
    cam.bhDiskGM = 0.0f; cam.bhPoseTime = 0.0f; cam.bhPoseDt = 0.0f;
    cam.bhDiskAxisY = 0.0f;
    impl_->bhPoseClock = 0.0;                  // clock re-arms on next hole
  }
  // ROTATION EASE-IN (2026-07-18 14:40:10): cam.bhDiskGM jumps 0→gmSim(M(<r_h)) the frame
  // the horizon forms, SNAPPING the posed spin on (Jamal: "snapped into rotation"). Ease it
  // so Ω=√(GM/r³) ramps in continuously (~30-frame e-fold) instead of a hard switch. Eases
  // back to 0 the same way when the hole dissolves.
  impl_->bhDiskGMSmooth += (cam.bhDiskGM - impl_->bhDiskGMSmooth) * 0.03f;
  cam.bhDiskGM = impl_->bhDiskGMSmooth;
  cam.horizonR = impl_->lastHorizonRSmooth; // eased honest r_h → hole pass/membrane/pose (0 = no hole; raw value stays in physics)
  // The star-pass capture cull uses THIS one, not the eased value above: being
  // behind the horizon is a physics fact, and the easing (×0.03/frame) leaves it
  // 6× short for ~2 s after formation. Measured 2026-08-11 03:18: raw 0.0781 vs
  // smooth 0.0130 on the forming frame. See renderer.h (horizonRRaw).
  cam.horizonRRaw = impl_->lastHorizonR;
  // ⚠ COMMENT CORRECTED 2026-08-11 12:31:44. This read "hole centre (after PLAY
  // it's off-origin)". It is NEVER off-origin. bhPosX/Y/Z are hard-set to 0.0f
  // at :3293-3295 (ORIGIN LOCK, his own call) and the enclosure-COM refinement
  // that would move them is inside `if (false)` at :2935. These three uniforms
  // are therefore ALWAYS (0,0,0), and every shader that "re-centres on the hole"
  // via cam.bhX/Y/Z is re-centring on the origin. Consequence, logged: the P6
  // fix in board §H1 is a no-op — see the note at `rDil` in render.metal.
  cam.bhX = impl_->bhPosX; cam.bhY = impl_->bhPosY; cam.bhZ = impl_->bhPosZ;
  cam.tuneLens = config.lensBend;
  cam.tuneArcWrap = config.arcWrap;
  cam.tuneArcGain = config.arcGain;
  cam.tuneTrailGain = config.trailGain;
  cam.tuneStreakLen = config.streakLen;
  cam.tuneColorK = config.colorTempK;
  cam.tuneHeatK = config.heatGain;
  // STAR LAW DIALS (2026-07-28) — identity defaults, see renderer.h.
  cam.tuneStarLumExp = config.starLumExp;
  cam.tuneStarLumGain = config.starLumGain;
  cam.tuneStarLumCeil = config.starLumCeil;
  cam.tuneStarKelvinA = config.starKelvinA;
  cam.tuneStarKelvinP = config.starKelvinP;
  cam.tuneStarSizeGain = config.starSizeGain;
  cam.tuneStarSizeExp = config.starSizeExp;
  cam.tuneStarSizeFloor = config.starSizeFloor;
  cam.tuneStarSizeCeil = config.starSizeCeil;
  cam.bhToggles = config.bhToggles;
  impl_->bhToggles = config.bhToggles; // → physics gates in runComputePass
  impl_->physicsSubsteps = config.physicsSubsteps; // → substep loop in runComputePass
  memcpy(impl_->cameraBuffer[frameIdx].contents, &cam, sizeof(cam));

  impl_->renderWithCamera(drawable, renderCmdBuf, frameIdx, config);
}

void Renderer::setScale(float s) { impl_->physicsUniforms.plateRadius = s; }
void Renderer::setTimeWarp(float w) { impl_->timeWarpVal = std::max(w, 1.0e-3f); }

// Internal helper for compute
void Renderer::triggerReset() { impl_->resetPending = true; }

void Renderer::Impl::runComputePass(id<MTLCommandBuffer> cmdBuf, int frameIdx) {
  // ── PERF TELEMETRY (2026-08-13) — board item 12 ──────────────────────────
  // There was NO timing telemetry in this build at all: no fps, no frame-time,
  // and the log carries no wall-clock stamps, so frame rate could not even be
  // reconstructed after the fact. That made his 2026-08-13 01:05 report —
  // "disabling ortho mode gave me huge fps back" — impossible to corroborate
  // or refute, and a claim we cannot measure is one we cannot regression-test.
  // ⚠️ physicsUniforms.dt IS NOT FRAME TIME. It is a FIXED step
  // (0.0165 * timeWarp, renderer.mm:1402) pinned deliberately to kill the
  // variable-FPS energy pump. Anyone deriving fps from dt gets the time warp,
  // not the frame rate. This reads the real clock instead.
  // Reported on the existing 240-frame cadence next to [GRAV]: mean fps over
  // the window, the WORST single frame in it (the spike is what he sees as a
  // stutter, and a mean hides it), and the state the measurement was taken in
  // — ortho, warp, particle count — so no future run has to guess.
  static double perfLast = 0.0, perfSum = 0.0, perfWorst = 0.0;
  static uint32_t perfN = 0;
  {
    double nowPf = CACurrentMediaTime();
    if (perfLast > 0.0) {
      double d = nowPf - perfLast;
      perfSum += d;
      perfN++;
      if (d > perfWorst) perfWorst = d;
    }
    perfLast = nowPf;
  }
  if ((physicsUniforms.frameCounter % 240u) == 0u && perfN > 0u) {
    // ⏱️ TRUE TIME (E1) — THE NUMBER THAT DECIDES THIS CHANGE.
    // Each step represents 0.0165 real seconds at EVERY warp (see computeStep),
    // so steps*0.0165 is the real time the universe actually lived through, and
    // dividing by the real time that elapsed gives 1.000 when the clock is
    // honest. It is warp-independent by construction, so one number covers x1
    // and x16. Before this change it was 0.0165*fps: 1.97 at 119.5 fps, 0.89 at
    // 53.7. clamp= counts frames where the machine could not keep up and the
    // debt was dropped — real lag, reported instead of hidden.
    double ttReal = (perfSum > 0.0) ? ((double)ttStepsWindow * 0.0165) / perfSum
                                    : 0.0;
    fprintf(stderr,
            "[PERF] fps=%.1f worst=%.1fms ortho=%d warp=%.2f sub=%d particles=%d n=%u "
            "steps=%u realtime=%.3fx clamp=%u\n",
            (double)perfN / perfSum, perfWorst * 1000.0, lastOrtho,
            (double)timeWarpVal, physicsSubsteps, particleCount, perfN,
            ttStepsWindow, ttReal, ttClampWindow);
    perfSum = 0.0;
    perfWorst = 0.0;
    perfN = 0u;
    ttStepsWindow = 0u;
    ttClampWindow = 0u;
  }
  // TEMP-PERF: SS_SPH_SKIP="density,pressure,force,centroid,merge,cellmax,stats"
  // (any subset) skips individual passes so [PROFILE/120f] deltas give exact
  // per-kernel cost. Measurement only — skipped passes leave stale buffers.
  // Function scope: guards live both inside and after the hash block.
  static bool sphSkipDensity = false, sphSkipPressure = false,
              sphSkipForce = false, sphSkipParsed = false;
  static bool skipCentroid = false, skipMerge = false, skipCellMax = false,
              skipStats = false;
  if (!sphSkipParsed) {
    sphSkipParsed = true;
    if (const char *sk = getenv("SS_SPH_SKIP")) {
      sphSkipDensity  = strstr(sk, "density") != nullptr;
      sphSkipPressure = strstr(sk, "pressure") != nullptr;
      sphSkipForce    = strstr(sk, "force") != nullptr;
      skipCentroid    = strstr(sk, "centroid") != nullptr;
      skipMerge       = strstr(sk, "merge") != nullptr;
      skipCellMax     = strstr(sk, "cellmax") != nullptr;
      skipStats       = strstr(sk, "stats") != nullptr;
    }
    // 🔬 TEMP-DIAG isolation ladder (docs/BUG_lines_2026-07-12.md): SS_INERT
    // must also silence merge_stars — it is NOT gated by bhToggles (only by
    // notPlaying), so clearing the force bits in main.cpp can't reach it.
    // SS_INERT_KEEP containing "merge" re-enables it (ladder rung).
    if (getenv("SS_INERT")) {
      const char *keep = getenv("SS_INERT_KEEP");
      if (!(keep && strstr(keep, "merge"))) skipMerge = true;
    }
  }
  if (hasCompute && physicsPipeline) {
    // Preserve debugFlags set by computeStep(); only add reset bit if needed
    if (resetPending) {
      physicsUniforms.debugFlags |= (1 << 8); // Reset bit
      resetPending = false;
    }

    // SELF-GRAVITY uniforms: last frame's COM + the DERIVED G·M_total
    // (Σ real per-star IMF masses through the Sgr A* anchor + time-lapse —
    // see units.h / imf.h; mean star ≈ 0.30 M_sun, NOT 1).
    // Set here (not in computeStep) — they're renderer-internal state from
    // the stats readback, and computeStep wholesale-resets physicsUniforms.
    physicsUniforms.comX = liveComX;
    physicsUniforms.comY = liveComY;
    physicsUniforms.comZ = liveComZ;
    static double sMassTotal = 0.0;
    static int sMassTotalCount = -1;
    if (sMassTotalCount != particleCount) {
      sMassTotal = space::imf::totalMassMsun(particleCount);
      sMassTotalCount = particleCount;
    }
    // SIZE↔MASS↔GRAVITY (Jamal 2026-06-25): the Size slider scales the stars'
    // effective MASS, so render size grows (handled in render.metal) AND the
    // field's self-gravity grows with it — heavier stars pull harder. Normalised
    // to the default Size=2 → ×1 (no change). Exponent 1.25 makes it physical:
    // render size ∝ Size, and since R∝M^0.8 the implied mass ∝ Size^1.25, so
    // gravity (∝M) ∝ Size^1.25. The central SMBH (centerGM) is NOT scaled — it's
    // the fixed anchor; only the cluster's own mass scales.
    float massScale = powf(fmaxf(lastParticleSize / 2.0f, 0.05f), 1.25f);
    physicsUniforms.massTotal = (float)(sMassTotal * massScale);
    // THE BOOKS, unscaled (2026-08-12 22:01:44). massTotal above is the GRAVITY
    // anchor and carries massScale, so at the default Size=2 it reads 189,044
    // against a real field of 594,276 — a 3.14× under-read. The accretion bound
    // used it and stalled the hole at 32,384 = 99.66% of 0.17188×189,044.
    // Anything that is a MASS BUDGET must read this field, not massTotal.
    physicsUniforms.fieldMassMsun = (float)sMassTotal;
    physicsUniforms.gravGM = (float)(space::units::gmSim(sMassTotal) * massScale);
    // Hard-coded CENTRAL mass at the origin — the dominant anchor the cluster
    // orbits. Sized so its ISCO (3·r_s = 3·M·kRsSimPerMsun) is SMALLER than the
    // cluster radius (~1–3 sim), so stars orbit OUTSIDE the ISCO (stable, ~0.4c)
    // instead of plunging from inside it. 1e5 M☉ → ISCO ≈ 0.5 sim. TUNABLE knob:
    // bigger = faster/tighter orbits (ISCO grows), smaller = wider/slower.
    physicsUniforms.centerGM = (float)space::units::gmSim(4297000.0);
    physicsUniforms.uAmbient = liveUAmbient;   // display ambient follows the live gas
    static int amrOn = -1;
    if (amrOn < 0) amrOn = getenv("SS_NO_AMR") ? 0 : 1;   // AMR nested-mesh gravity DEFAULT ON (2026-07-18 01:12:40, honest toggle stack); SS_NO_AMR disables
    // ── BH6 FIX 2026-08-22: AMR MOVED OFF bit15 ONTO bit21 ────────────────
    // bit15 was DOUBLE-BOOKED: uiTogMetricShadow packs it at main.cpp:2306 and
    // it ships DEFAULT ON (app_state.h:53), while this line OR'd AMR into the
    // same bit for the physics uniform. Because the shadow had already set it,
    // the OR was a NO-OP and **SS_NO_AMR NEVER DISABLED ANYTHING** — every A/B
    // run with that flag compared two identical configurations, which is
    // exactly how it produced a null result. AMR only ever switched off if you
    // ALSO unchecked Metric Shadow, which nobody would think to do.
    // bit21 is genuinely free: bhToggles is packed 0..20 (main.cpp:2290-2310)
    // and bits 21+ that appear elsewhere in the tree belong to `debugFlags`, a
    // DIFFERENT word. No preset serializes bhToggles, so there is no migration.
    // The render side is untouched — render.metal:906 reads cam.bhToggles,
    // which never received the OR, so the metric-shadow A/B was always clean.
    physicsUniforms.bhToggles = bhToggles | (amrOn ? 0x200000u : 0u); // bit21 = AMR fine force (Slice 2)
    physicsUniforms.horizonR = lastHorizonR;  // honest r_h (1-frame lag) → pressure-yield in the kernel
    physicsUniforms.bhX = bhPosX;
    physicsUniforms.bhY = bhPosY;
    physicsUniforms.bhZ = bhPosZ;
    physicsUniforms.bhMass = bhMassEnc;

    memcpy(uniformBuffer[frameIdx].contents, &physicsUniforms,
           sizeof(physicsUniforms));

    NSUInteger tgSize = 256;

    // ── Spatial hash build (4 phases) ──────────────────────────────
    // Build when collisions are on, during silence/release (raytracer needs
    // density), OR during decay/sustain (ERUPTIONS + CRYSTALLIZATION read
    // cellCounts to find/harden dense nodes). Cheap O(N) hash BUILD.
    bool needSpatialHash = collisionsEnabled ||
        physicsUniforms.envelopePhase < 0.5f || physicsUniforms.envelopePhase > 3.5f ||
        (physicsUniforms.envelopePhase >= 1.5f && physicsUniforms.envelopePhase < 3.5f);

    // ── TRUE SUB-STEP PROBE (SS_TRUE_SUBSTEPS=1, 2026-08-29) ────────────────
    // MEASUREMENT ONLY — default path is byte-for-byte unchanged (nTrue==1).
    // WHY: 22 of the 23 compute passes run ONCE per frame and only the physics
    // integrate re-runs per substep, so N substeps advance N steps against a
    // FROZEN force field (phi[], finePhi[], sphForce[], cellMass[], cellStarts
    // are all written above this point). Position-Verlet under a constant
    // acceleration is exact regardless of step count, which is why substeps
    // buy almost nothing over raw dt-scaling and both go chaotic together.
    // MEASURED 2026-08-29: at MATCHED sim time (elapsed substeps = 240*(k-1)*N,
    // [GRAV] and [PERF] share the %240u cadence) N=1/2/4 disagree by 2.5-3.6x
    // on Mmax. A faithful integrator CONVERGES as N rises; ours diverges.
    // This flag re-runs the WHOLE force pipeline + physics + seed_apply per
    // substep — what Universe Sandbox's IntegratorSubstepSystemGroup does —
    // so the divergence should collapse. Cost measured at 23.65 ms/substep, so
    // expect ~9 fps at N=4. That is fine: this proves the diagnosis, it does
    // not ship. If the divergence does NOT collapse, the diagnosis is wrong.
    static int sTrueSubstep = -1;
    if (sTrueSubstep < 0) sTrueSubstep = getenv("SS_TRUE_SUBSTEPS") ? 1 : 0;
    // ⏱️ TRUE TIME (E1, 2026-08-30): the count comes from the wall clock now,
    // not from the assumption "one frame = one step". SS_TRUE_SUBSTEPS keeps its
    // original probe semantics so the 08-29 measurements stay reproducible.
    const int nTrue = sTrueSubstep ? std::max(1, physicsSubsteps) : pendingSteps;
    if (sTrueSubstep && (physicsUniforms.frameCounter % 240u) == 0u)
      fprintf(stderr, "[TRUESUB] force pipeline re-run %d x/frame\n", nTrue);
    for (int tsub = 0; tsub < nTrue; tsub++) {
    // ⏱️ SUB-STEP TICK — the cadence clock. A FRAME IS NOT A UNIT OF TIME
    // (his thesis 2026-08-29). The two heavy passes below are throttled on a
    // cadence; gating them on frameCounter meant they refreshed once per FRAME
    // however many substeps that frame advanced, so gravity and SPH went stale
    // exactly when the sim ran fastest. This advances with the SIM, not the
    // display. IDENTITY ON THE DEFAULT PATH: nTrue==1, tsub==0 → stepTick is
    // frameCounter exactly, so the shipped build cannot change behaviour.
    // ⏱️ TRUE TIME (E1): was frameCounter*nTrue + tsub, which is only monotonic
    // while nTrue is CONSTANT. The clock now varies it per frame (0/1/2), so
    // that formula would jump backwards and scramble both cadences below.
    // A count of steps actually executed is the honest clock and is identity
    // with frameCounter on any run that took exactly one step per frame.
    const uint32_t stepTick = simStepCounter++;


    // ── Snapshot live particles → read buffer for the hash + collision reads.
    // MUST happen whenever the hash is built (not only for collisions): the hash
    // (assign_cells/scatter) reads particleBufferRead, so without this snapshot
    // the hash / cellCounts / sortedParticles are STALE when collisions are off
    // — which silently broke density-driven crystallization + cohesion + bonds.
    if (needSpatialHash && particleBufferRead) {
      id<MTLBlitCommandEncoder> blit = [cmdBuf blitCommandEncoder];
      [blit copyFromBuffer:particleBuffer
               sourceOffset:0
                   toBuffer:particleBufferRead
          destinationOffset:0
                       size:particleCount * sizeof(GPUParticle)];
      [blit endEncoding];
    }
    if (needSpatialHash && assignCellsPipeline && countCellsPipeline &&
        prefixSumLocalPipeline && prefixSumBlocksPipeline &&
        prefixSumAddPipeline && scatterPipeline) {
      // Upload spatial hash uniforms
      SpatialHashUniforms su = {};
      su.gridSize = kGridSize;
      // PHASE-SWITCHED EXTENT (the hash is rebuilt from zero every frame, so
      // the grid can resize freely between frames):
      //   PLAY (decay/sustain): ±3 — the Chladni tube. Eruptions, hardening
      //   and the disk machinery keep their tuned fine cells (6/128 ≈ 0.047).
      //   REST + RELEASE: ±64 — THE FIELD. The star map lives at r≈40-70;
      //   with the old fixed ±3 every grid force (relaxation, mergers,
      //   near-field gravity, density signal) existed only in a central
      //   sliver, so the post-release remnant could never dissipate or eat —
      //   it just wobbled, and the hole had no path to exist. ±64 covers the
      //   whole spawn box (|coords| ≤ 42) with drift margin; cells are 1.0
      //   sim — coarser viscosity/gravity sampling, but contact mergers stay
      //   exact (the d² test uses real stellar radii, the cell only scopes
      //   the partner search). The raytracer reads halfExtent from the same
      //   uniforms and scales with it.
      // UNIFIED DOMAIN SCALE (2026-07-18 14:33:10, "one scale + AMR"): was
      // tubePhase ? 3.0 : 64.0 — play (decay/sustain) ran the hash/merge at ±3,
      // rest/attack/release at ±64. So a note flipped ±64→±3→±64 and RELEASE
      // re-gridded the fine cymatics structure at the 21×-coarser rest cellSize
      // (1.0 vs 0.047) → the "gridy squarish shapes + new Dyson mergers after play"
      // mismatch (Jamal 2026-07-18). ONE ±64 domain now for play AND rest; the AMR
      // fine box (±4, cell 0.0625, default-on this baseline) carries the near-core
      // resolution the cymatics/collapse needs — the "adaptive sub-stepping not a
      // smaller domain" the old note asked for. A globally-fine ±8 made softening
      // tiny → sharp kicks → ejection; AMR gives fine cells LOCALLY instead.
      su.halfExtent = 64.0f;
      lastHashExtent = su.halfExtent;
      su.particleCount = particleCount;
      su.cellSize = 2.0f * su.halfExtent / (float)kGridSize;
      su.invCellSize = (float)kGridSize / (2.0f * su.halfExtent);
      su.gridSizeZ = kGridSize;
      memcpy(spatialHashUniformBuffer.contents, &su,
             sizeof(SpatialHashUniforms));
      // AMR (Slice 2): keep the fine uniforms valid EVERY frame so compute_physics
      // can sample −∇Φ_fine even on non-solve frames. Same 128³ over ±kAmrFineExtent.
      if (amrOn && fineHashUniformBuffer) {
        SpatialHashUniforms fu = su;
        fu.halfExtent = Impl::kAmrFineExtent;
        fu.cellSize = 2.0f * fu.halfExtent / (float)kGridSize;
        fu.invCellSize = (float)kGridSize / (2.0f * fu.halfExtent);
        memcpy(fineHashUniformBuffer.contents, &fu, sizeof(SpatialHashUniforms));
      }

      // Clear cell counts, masses and offsets
      id<MTLBlitCommandEncoder> clearBlit = [cmdBuf blitCommandEncoder];
      [clearBlit fillBuffer:cellCountsBuffer
                      range:NSMakeRange(0, kTotalCells * sizeof(uint32_t))
                      value:0];
      [clearBlit fillBuffer:cellMassBuffer
                      range:NSMakeRange(0, kTotalCells * sizeof(uint32_t))
                      value:0];
      // [0..3] cleared per frame; [4..7] persist — seed_mark mirrors the
      // final registry count into [4] so the CPU never reads a mid-clear 0.
      [clearBlit fillBuffer:seedCountBuffer
                      range:NSMakeRange(0, 4 * sizeof(uint32_t))
                      value:0];
      [clearBlit fillBuffer:cellSeedMapBuffer
                      range:NSMakeRange(0, kTotalCells * sizeof(uint32_t))
                      value:0];
      [clearBlit fillBuffer:seedAccumBuffer
                      range:NSMakeRange(0, 1024 * 8 * sizeof(uint32_t))
                      value:0];
      [clearBlit fillBuffer:accDiagBuffer    // accuracy measurement, re-maxed each frame
                      range:NSMakeRange(0, 2 * sizeof(uint32_t))
                      value:0];
      [clearBlit fillBuffer:mergeClaimBuffer // cross-cell merge claims, re-claimed each frame
                      range:NSMakeRange(0, (NSUInteger)particleCount * sizeof(uint32_t))
                      value:0];
      // TEMP-CLOSURE: zero the window ledger right AFTER the watchdog read
      // (%240==0) so each [CLOSURE] line integrates exactly one 240f window.
      if ((physicsUniforms.frameCounter % 240u) == 1u) {
        [clearBlit fillBuffer:sphClosureBuffer
                        range:NSMakeRange(0, 8 * sizeof(int32_t))
                        value:0];
      }
      [clearBlit fillBuffer:cellOffsetsBuffer
                      range:NSMakeRange(0, kTotalCells * sizeof(uint32_t))
                      value:0];
      // compute_physics adds sphForce[id] to gacc for EVERY particle (bit11), but
      // sph_force only WRITES the ≤32 particles per cell that scatter_particles
      // kept. An unwritten id used to keep its LAST force forever → a frozen
      // constant acceleration re-applied every frame → straight-line ejecta at the
      // speed cap, with no u debit booked (W huge, dyn=0). Zero it each frame:
      // unsampled ⇒ no SPH force this frame.
      if (sphForceBuffer) {
        [clearBlit fillBuffer:sphForceBuffer
                        range:NSMakeRange(0, (NSUInteger)particleCount * 4 * sizeof(float))
                        value:0];
      }
      [clearBlit endEncoding];

      // Phase 1+2 FUSED (2026-07-07): count_cells computes cell ids itself —
      // the separate assign pass (full extra particle read+write) is gone.
      {
        id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
        [comp setComputePipelineState:countCellsPipeline];
        [comp setBuffer:cellIndicesBuffer offset:0 atIndex:0];
        [comp setBuffer:cellCountsBuffer offset:0 atIndex:1];
        [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:2];
        [comp setBuffer:cellMassBuffer offset:0 atIndex:3];
        [comp setBuffer:particleBufferRead offset:0 atIndex:4];
        [comp setBuffer:seedCountBuffer offset:0 atIndex:5];
        [comp setBuffer:seedIdsBuffer offset:0 atIndex:6];
        NSUInteger tg =
            std::min(tgSize, countCellsPipeline.maxTotalThreadsPerThreadgroup);
        [comp dispatchThreads:MTLSizeMake(particleCount, 1, 1)
            threadsPerThreadgroup:MTLSizeMake(tg, 1, 1)];
        [comp endEncoding];
      }

      // Phase 3: Multi-pass Blelloch Prefix Sum (O(N) parallel scan)
      {
        // Pass 3a: Local block scan
        id<MTLComputeCommandEncoder> compLocal = [cmdBuf computeCommandEncoder];
        [compLocal setComputePipelineState:prefixSumLocalPipeline];
        [compLocal setBuffer:cellCountsBuffer offset:0 atIndex:0];
        [compLocal setBuffer:cellStartsBuffer offset:0 atIndex:1];
        [compLocal setBuffer:blockSumsBuffer offset:0 atIndex:2];
        [compLocal setBuffer:spatialHashUniformBuffer offset:0 atIndex:3];

        NSUInteger tgLocal =
            std::min((NSUInteger)1024,
                     prefixSumLocalPipeline.maxTotalThreadsPerThreadgroup);
        // Dispatch enough threadgroups to cover 65536 cells, 2048 cells per
        // threadgroup
        NSUInteger numBlocks =
            (Impl::kTotalCells + (tgLocal * 2) - 1) / (tgLocal * 2);
        [compLocal dispatchThreadgroups:MTLSizeMake(numBlocks, 1, 1)
                  threadsPerThreadgroup:MTLSizeMake(tgLocal, 1, 1)];
        [compLocal endEncoding];

        // Pass 3b: Scan block sums (single threadgroup for 32 blocks)
        id<MTLComputeCommandEncoder> compBlocks =
            [cmdBuf computeCommandEncoder];
        [compBlocks setComputePipelineState:prefixSumBlocksPipeline];
        [compBlocks setBuffer:blockSumsBuffer offset:0 atIndex:0];
        [compBlocks setBuffer:spatialHashUniformBuffer offset:0 atIndex:1];

        NSUInteger tgBlocks =
            std::min((NSUInteger)1024,
                     prefixSumBlocksPipeline.maxTotalThreadsPerThreadgroup);
        [compBlocks dispatchThreadgroups:MTLSizeMake(1, 1, 1)
                   threadsPerThreadgroup:MTLSizeMake(tgBlocks, 1, 1)];
        [compBlocks endEncoding];

        // Pass 3c: Add block sums back to local scans
        id<MTLComputeCommandEncoder> compAdd = [cmdBuf computeCommandEncoder];
        [compAdd setComputePipelineState:prefixSumAddPipeline];
        [compAdd setBuffer:cellStartsBuffer offset:0 atIndex:0];
        [compAdd setBuffer:blockSumsBuffer offset:0 atIndex:1];
        [compAdd setBuffer:spatialHashUniformBuffer offset:0 atIndex:2];

        // 1 thread per cell, grouped naturally
        NSUInteger tgAdd =
            std::min((NSUInteger)256,
                     prefixSumAddPipeline.maxTotalThreadsPerThreadgroup);
        [compAdd dispatchThreads:MTLSizeMake(Impl::kTotalCells, 1, 1)
            threadsPerThreadgroup:MTLSizeMake(tgAdd, 1, 1)];
        [compAdd endEncoding];
      }

      // Phase 4: scatter to sorted order
      {
        id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
        [comp setComputePipelineState:scatterPipeline];
        [comp setBuffer:particleBufferRead
                 offset:0
                atIndex:0]; // input snapshot
        [comp setBuffer:cellIndicesBuffer offset:0 atIndex:1];
        [comp setBuffer:cellStartsBuffer offset:0 atIndex:2];
        [comp setBuffer:cellOffsetsBuffer offset:0 atIndex:3];
        [comp setBuffer:sortedParticlesBuffer
                 offset:0
                atIndex:4]; // output physically sorted
        [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:5];
        NSUInteger tg =
            std::min(tgSize, scatterPipeline.maxTotalThreadsPerThreadgroup);
        [comp dispatchThreads:MTLSizeMake(particleCount, 1, 1)
            threadsPerThreadgroup:MTLSizeMake(tg, 1, 1)];
        [comp endEncoding];
      }

      // Phase 5: per-cell centroids (the local mass centre, for O(N) cohesion).
      // SKIP during play: its outputs (cellCentroids, cellVelocities) are read
      // ONLY by self-gravity, relaxation and pressure — all gated off during
      // play — so during play this builds 2.1M-cell aggregates that nothing
      // reads. Pure wasted compute every play frame. (No feature lost: unused
      // during play; runs normally at rest where the BH physics needs it.)
      if (centroidPipeline && cellCentroidsBuffer && !skipCentroid &&
          physicsUniforms.totalAmplitude < 0.02f) {
        id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
        [comp setComputePipelineState:centroidPipeline];
        [comp setBuffer:sortedParticlesBuffer offset:0 atIndex:0];
        [comp setBuffer:cellStartsBuffer offset:0 atIndex:1];
        [comp setBuffer:cellCountsBuffer offset:0 atIndex:2];
        [comp setBuffer:cellCentroidsBuffer offset:0 atIndex:3];
        [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:4];
        [comp setBuffer:cellVelocitiesBuffer offset:0 atIndex:5];
        NSUInteger tgC = std::min(
            (NSUInteger)256, centroidPipeline.maxTotalThreadsPerThreadgroup);
        [comp dispatchThreads:MTLSizeMake(Impl::kTotalCells, 1, 1)
            threadsPerThreadgroup:MTLSizeMake(tgC, 1, 1)];
        [comp endEncoding];
      }

      // Phase 5+: CIC velocity moments (2026-07-15) — deposit-side
      // anti-aliasing of cellVelocities. Runs AFTER the centroid pass and
      // OVERWRITES its cell-quantized mean/σ with the continuous CIC estimate
      // (all particles, 8-cell trilinear deposit). Same rest-only gate: the
      // consumers (dynfric, Balsara, bit5) are rest physics. DEFAULT ON since
      // 2026-07-15 (kills the z-pancake seed amplification — the lines bug;
      // his verdict on the live bed). SS_NO_CIC_MOMENTS=1 = A/B off.
      static bool cicMomentsOn = getenv("SS_NO_CIC_MOMENTS") == nullptr;
      if (cicMomentsOn && cicClearPipeline && cicDepositPipeline &&
          cicFinalizePipeline && cicMomentsBuffer && !skipCentroid &&
          physicsUniforms.totalAmplitude < 0.02f) {
        id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
        [comp setComputePipelineState:cicClearPipeline];
        [comp setBuffer:cicMomentsBuffer offset:0 atIndex:0];
        [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:1];
        NSUInteger tgZ = std::min(
            (NSUInteger)256, cicClearPipeline.maxTotalThreadsPerThreadgroup);
        [comp dispatchThreads:MTLSizeMake(Impl::kTotalCells * 5, 1, 1)
            threadsPerThreadgroup:MTLSizeMake(tgZ, 1, 1)];
        [comp endEncoding];

        comp = [cmdBuf computeCommandEncoder];
        [comp setComputePipelineState:cicDepositPipeline];
        [comp setBuffer:particleBufferRead offset:0 atIndex:0]; // same snapshot as scatter
        [comp setBuffer:cicMomentsBuffer offset:0 atIndex:1];
        [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:2];
        NSUInteger tgD = std::min(
            (NSUInteger)256, cicDepositPipeline.maxTotalThreadsPerThreadgroup);
        [comp dispatchThreads:MTLSizeMake(particleCount, 1, 1)
            threadsPerThreadgroup:MTLSizeMake(tgD, 1, 1)];
        [comp endEncoding];

        comp = [cmdBuf computeCommandEncoder];
        [comp setComputePipelineState:cicFinalizePipeline];
        [comp setBuffer:cicMomentsBuffer offset:0 atIndex:0];
        [comp setBuffer:cellVelocitiesBuffer offset:0 atIndex:1];
        [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:2];
        NSUInteger tgF = std::min(
            (NSUInteger)256, cicFinalizePipeline.maxTotalThreadsPerThreadgroup);
        [comp dispatchThreads:MTLSizeMake(Impl::kTotalCells, 1, 1)
            threadsPerThreadgroup:MTLSizeMake(tgF, 1, 1)];
        [comp endEncoding];
      }

      // Phase 5a: per-cell BALSARA switch (shear vs shock) from the fresh
      // cell mean-velocity field — gates the bit12 viscosity in sph_force so
      // the rotating rest map cannot shock-heat itself (the 61d3d40 blob).
      // Same gate as the centroid pass: its output is only consumed by SPH,
      // and a skipped centroid pass would leave it reading stale means.
      if (balsaraPipeline && cellBalsaraBuffer && !skipCentroid &&
          physicsUniforms.totalAmplitude < 0.02f) {
        id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
        [comp setComputePipelineState:balsaraPipeline];
        [comp setBuffer:cellVelocitiesBuffer offset:0 atIndex:0];
        [comp setBuffer:cellCountsBuffer offset:0 atIndex:1];
        [comp setBuffer:cellBalsaraBuffer offset:0 atIndex:2];
        [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:3];
        NSUInteger tgB = std::min(
            (NSUInteger)256, balsaraPipeline.maxTotalThreadsPerThreadgroup);
        [comp dispatchThreads:MTLSizeMake(Impl::kTotalCells, 1, 1)
            threadsPerThreadgroup:MTLSizeMake(tgB, 1, 1)];
        [comp endEncoding];
      }

      // SPH CADENCE: at rest the passes run every kSphCadence-th frame — rest
      // dynamical times are hundreds of frames, so a 2-frame-stale force field
      // is well inside the integration error already accepted. The force
      // buffer PERSISTS between passes (zeroed only right before a rewrite —
      // the phantom-thruster fix stays intact) and is applied every frame;
      // the energy integration uses dtU = dt·cadence to cover skipped frames.
      static uint32_t kSphCadence = 0;  // TEMP-PERF: SS_SPH_CADENCE overrides (A/B)
      if (kSphCadence == 0u) {
        kSphCadence = 2;
        if (const char *cd = getenv("SS_SPH_CADENCE")) {
          int v = atoi(cd);
          if (v >= 1 && v <= 8) kSphCadence = (uint32_t)v;
        }
      }
      bool sphFrame = (stepTick % kSphCadence) == 0u;  // SIM cadence, not frame

      // Phase 5a1.5: SPH DENSITY FLOOR — EVERY particle gets the uncapped
      // cell-mean ρ (cellMass/MASS_FP/h³, self-term minimum) BEFORE the ≤32-
      // sample refinement below, which may only RAISE it. Root fix for the
      // stale-ρ / 1e-12-floor P/ρ² singularity (poison=200k at ring density)
      // AND the ~100× dense-cell undercount. Same gates as the density pass.
      if (sphDensityFloorPipeline && densityBuffer && cellMassBuffer &&
          !sphSkipDensity && sphFrame &&
          physicsUniforms.totalAmplitude < 0.02f) {
        id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
        [comp setComputePipelineState:sphDensityFloorPipeline];
        [comp setBuffer:particleBuffer offset:0 atIndex:0];
        [comp setBuffer:cellMassBuffer offset:0 atIndex:1];
        [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:2];
        [comp setBuffer:densityBuffer offset:0 atIndex:3];
        NSUInteger tgF = std::min(
            (NSUInteger)256, sphDensityFloorPipeline.maxTotalThreadsPerThreadgroup);
        [comp dispatchThreads:MTLSizeMake(particleCount, 1, 1)
            threadsPerThreadgroup:MTLSizeMake(tgF, 1, 1)];
        [comp endEncoding];
      }

      // Phase 5a2: SPH DENSITY — ρ_i per particle (27-cell ≤32/cell neighbour
      // scan, cubic spline, h=cellSize). Rest only for now (matches centroids;
      // the play-state Chladni pattern explodes the neighbour scan — ungated
      // later at slice 5). SLICE 1 = measurement: densityBuffer is written but
      // nothing reads it yet (pressure force = slice 2).
      if (sphDensityPipeline && densityBuffer && !sphSkipDensity && sphFrame &&
          physicsUniforms.totalAmplitude < 0.02f) {
        id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
        [comp setComputePipelineState:sphDensityPipeline];
        [comp setBuffer:sortedParticlesBuffer offset:0 atIndex:0];
        [comp setBuffer:cellStartsBuffer offset:0 atIndex:1];
        [comp setBuffer:cellCountsBuffer offset:0 atIndex:2];
        [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:3];
        [comp setBuffer:densityBuffer offset:0 atIndex:4];
        // One threadgroup per cell, 32 threads (one per home-cell slot).
        [comp dispatchThreadgroups:MTLSizeMake(Impl::kTotalCells, 1, 1)
              threadsPerThreadgroup:MTLSizeMake(32, 1, 1)];
        [comp endEncoding];
      }

      // Phase 5a3: SPH EOS PRESSURE — P_i=(γ−1)ρ_i u_i (cheap per-particle). Needs
      // ρ (above) + u. Rest only. SLICE 2: written but not yet applied (force = next).
      if (sphPressurePipeline && pressureBuffer && densityBuffer && uBuffer &&
          !sphSkipPressure && sphFrame &&
          physicsUniforms.totalAmplitude < 0.02f) {
        id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
        [comp setComputePipelineState:sphPressurePipeline];
        [comp setBuffer:densityBuffer offset:0 atIndex:0];
        [comp setBuffer:uBuffer offset:0 atIndex:1];
        [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:2];
        [comp setBuffer:pressureBuffer offset:0 atIndex:3];
        NSUInteger tgP2 = std::min(
            (NSUInteger)256, sphPressurePipeline.maxTotalThreadsPerThreadgroup);
        [comp dispatchThreads:MTLSizeMake(particleCount, 1, 1)
            threadsPerThreadgroup:MTLSizeMake(tgP2, 1, 1)];
        [comp endEncoding];
      }

      // Phase 5a4: SPH FORCE + VISCOSITY + ENERGY (bit11 force, bit12 Π+du) —
      // tiled, a_i=−Σ m_j(P_i/ρ_i²+P_j/ρ_j²+Π_ij)∇W; bit12 adds Monaghan
      // viscosity + the energy equation (PdV + ½Π shock heating → uBuffer).
      // Writes sphForceBuffer; compute_physics adds it to gacc when bit11 is set.
      // Rest only. Gated OFF by default until verified (needs u>0 to do anything).
      bool sphPressureForceOn = (bhToggles & 0x800u) != 0u;
      bool sphViscosityOn = (bhToggles & 0x1000u) != 0u;
      if (sphForcePipeline && sphForceBuffer && densityBuffer && pressureBuffer &&
          uBuffer && sphPressureForceOn && !sphSkipForce && sphFrame &&
          physicsUniforms.totalAmplitude < 0.02f) {
        // u ceiling = min(physics, CFL):
        // PHYSICS: a relativistic ideal gas cannot exceed c_s = c/√3 → u ≤
        //   (c²/3)/(γ(γ−1)) = 0.3 sim (T ≈ 1.35e12 K, supernova-core scale).
        //   Without this, one hot outlier carries a superluminal c̄ and the
        //   α·c̄·μ viscosity turns it into a runaway infection center
        //   (measured 2026-07-06: rest cluster → 800+ particles at cap,
        //   c_s = 15c, E pumped 70k+; with PdV only it stayed ~clean).
        // CFL: fixed dt also demands c_s·dt/h ≤ C. At rest h=1 the physics
        //   cap is the binding one; at play h≈0.047 CFL binds. Proper hot-gas
        //   fix remains the sub-step accumulator (owed debt).
        float hSph = 2.0f * lastHashExtent / (float)Impl::kGridSize;  // = cellSize
        const float kCflC = 0.25f;
        float csMax = kCflC * hSph / physicsUniforms.dt;
        float uMax = (csMax * csMax) / ((5.0f / 3.0f) * (2.0f / 3.0f)); // c_s²/(γ(γ−1))
        const float kURelMax = (1.0f / 3.0f) / ((5.0f / 3.0f) * (2.0f / 3.0f)); // = 0.3
        uMax = std::min(uMax, kURelMax);
        // TEMP-SLICE3 debug: SS_SPH_AB="a,b" overrides α,β to isolate which
        // term pumps (PdV-only = "0,0"). Remove with the harness.
        static float sphAlpha = 1.0f, sphBeta = 2.0f;  // Monaghan (plan §3.4)
        static bool sphAbParsed = false;
        if (!sphAbParsed) {
          sphAbParsed = true;
          if (const char *ab = getenv("SS_SPH_AB"))
            sscanf(ab, "%f,%f", &sphAlpha, &sphBeta);
        }
        // Viscous-stability μ clamp: dt ≤ 0.25·h/v_sig, v_sig ≈ c̄+0.6(αc̄+βμ)
        // (Monaghan). Solve for μ at c̄=c/√3 and halve for margin.
        float csRelMax = 0.57735f;  // c/√3
        float muMax = ((kCflC * hSph / physicsUniforms.dt) -
                       csRelMax * (1.0f + 0.6f * sphAlpha)) /
                      std::max(0.6f * sphBeta, 1e-3f) * 0.5f;
        muMax = std::max(muMax, csRelMax);  // never clamp below the sound scale
        bool sphCoolingOn = (bhToggles & 0x2000u) != 0u;  // bit13 (slice 4)
        struct { float dt, dtU, alpha, beta, uFloor, uMax, viscOn, muMax,
                 coolOn, coolTau, horizonR, bhX, bhY, bhZ; } sphParams = {
            physicsUniforms.dt,
            physicsUniforms.dt * (float)kSphCadence,  // du + brake cover skipped frames
            sphAlpha,
            sphBeta,
            (float)space::spacetime::kUFloorSim,
            uMax,
            sphViscosityOn ? 1.0f : 0.0f,
            muMax,
            sphCoolingOn ? 1.0f : 0.0f,
            lastSphCoolTau,   // τ₀ [simt] from the mod-menu slider (~1 simt ≈ 1 s wall)
            // ONE-WAY MEMBRANE (2026-07-16): the honest horizon + its centre —
            // matter inside is causally dead to SPH (see sph_force).
            lastHorizonR, bhPosX, bhPosY, bhPosZ};
        // ZERO the force buffer first — sph_force only writes the ≤32 scattered
        // particles per cell; without the clear, a particle that drops out of
        // the sorted set (overflowing cell) REPLAYS its last kick every frame —
        // a phantom thruster (measured 2026-07-06: linear E growth + steady
        // 0.05c outflow at rest that no Π/μ clamp touched).
        {
          id<MTLBlitCommandEncoder> zf = [cmdBuf blitCommandEncoder];
          [zf fillBuffer:sphForceBuffer
                   range:NSMakeRange(0, (NSUInteger)particleCount * 4 * sizeof(float))
                   value:0];
          [zf endEncoding];
        }
        id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
        [comp setComputePipelineState:sphForcePipeline];
        [comp setBuffer:sortedParticlesBuffer offset:0 atIndex:0];
        [comp setBuffer:cellStartsBuffer offset:0 atIndex:1];
        [comp setBuffer:cellCountsBuffer offset:0 atIndex:2];
        [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:3];
        [comp setBuffer:densityBuffer offset:0 atIndex:4];
        [comp setBuffer:pressureBuffer offset:0 atIndex:5];
        [comp setBuffer:sphForceBuffer offset:0 atIndex:6];
        [comp setBytes:&sphParams length:sizeof(sphParams) atIndex:7];
        [comp setBuffer:uBuffer offset:0 atIndex:8];
        [comp setBuffer:sphClosureBuffer offset:0 atIndex:9]; // TEMP-CLOSURE du splits
        [comp setBuffer:cellBalsaraBuffer offset:0 atIndex:10]; // shear/shock gate on the Monaghan term
        [comp dispatchThreadgroups:MTLSizeMake(Impl::kTotalCells, 1, 1)
              threadsPerThreadgroup:MTLSizeMake(32, 1, 1)];
        [comp endEncoding];
      }

      // Phase 5b: PM GRAVITY — solve ∇²Φ = 4πG·ρ on the grid (red-black SOR),
      // warm-started from last frame's Φ. The force (−∇Φ) is sampled in
      // compute_physics when bit10 is set. Energy-conserving, replaces the
      // per-frame centroid/COM attractors that pumped the cluster apart.
      bool pmGravityOn = (bhToggles & 0x400u) != 0u;
      // SOR CADENCE: Φ is persistent + warm-started and the −∇Φ force samples
      // it EVERY frame; the mass field it solves for changes over hundreds of
      // frames at rest. Full 80-sweep convergence every 2nd frame beats
      // degraded sweeps every frame (measured: 10 sweeps/frame → meanR drift
      // 3× the verified-good rate; cadence keeps convergence quality).
      // OFFSET vs the SPH frames: each frame carries one heavy block instead
      // of one frame carrying both — steadier pacing. (First aligned-vs-offset
      // comparison was invalidated by stray app instances sharing the GPU;
      // re-measured clean.)
      bool sorFrame = (stepTick % 2u) == 1u;  // SIM cadence, not frame
      if (poissonPipeline && phiBuffer && pmGravityOn && sorFrame &&
          physicsUniforms.totalAmplitude < 0.02f) {  // rest only (matches centroids)
        // Zero Φ once on first use; afterward it persists (warm start).
        if (!phiInitialized) {
          id<MTLBlitCommandEncoder> zb = [cmdBuf blitCommandEncoder];
          [zb fillBuffer:phiBuffer range:NSMakeRange(0, Impl::kTotalCells * sizeof(float)) value:0];
          [zb endEncoding];
          phiInitialized = true;
        }
        float Gsim = physicsUniforms.gravGM / std::max(physicsUniforms.massTotal, 1.0f);
        // float2 {x=4πG_sim, y=gravGM(total)} — matches `constant float2&` in poisson_sor.
        float solverParams[2] = {(float)(4.0 * 3.14159265358979) * Gsim, physicsUniforms.gravGM};
        // TEMP-PERF: SS_SOR_SWEEPS overrides (measurement). 80 sweeps = 160
        // compute encoders/frame — encoder overhead is a prime suspect.
        static int kSorSweeps = 0;
        if (kSorSweeps == 0) {
          kSorSweeps = 80;  // warm-started; ω=1.9 in-kernel.
          if (const char *sw = getenv("SS_SOR_SWEEPS")) {
            int v = atoi(sw);
            if (v >= 1 && v <= 200) kSorSweeps = v;
          }
        }
        NSUInteger tgP = std::min((NSUInteger)256,
                                  poissonPipeline.maxTotalThreadsPerThreadgroup);
        for (int sweep = 0; sweep < kSorSweeps; sweep++) {
          for (uint color = 0; color < 2u; color++) {
            id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
            [comp setComputePipelineState:poissonPipeline];
            [comp setBuffer:cellMassBuffer offset:0 atIndex:0];
            [comp setBuffer:phiBuffer offset:0 atIndex:1];
            [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:2];
            [comp setBytes:&solverParams length:sizeof(solverParams) atIndex:3];
            [comp setBytes:&color length:sizeof(color) atIndex:4];
            [comp dispatchThreads:MTLSizeMake(Impl::kTotalCells, 1, 1)
                threadsPerThreadgroup:MTLSizeMake(tgP, 1, 1)];
            [comp endEncoding];
          }
        }
      }

      // [PM] confirm the PM path is live + Φ depth (reads last frame's Φ).
      if ((physicsUniforms.frameCounter % 240u) == 0u && phiBuffer && pmGravityOn) {
        const float *ph = (const float *)phiBuffer.contents;
        fprintf(stderr, "[PM] on dt=%.4f phi[ctr]=%.5f\n",
                physicsUniforms.dt, ph[(64 * 128 + 64) * 128 + 64]);
      }

      // ── AMR FINE-GRID PM SOLVE (Slice 1 plumbing; Slice 2 wires its force) ──
      // Solve a SECOND Poisson field on a 128³ grid over ±kAmrFineExtent at the
      // origin (cellSize ~0.031 sim), so gravity resolves BELOW one coarse cell.
      // Fine uniforms are populated every frame up in the uniform block.
      // Default OFF (SS_AMR) → zero cost/risk to the shipped star map.
      if (amrOn && binFineMassPipeline && poissonFinePipeline && fineCellMassBuffer &&
          finePhiBuffer && fineHashUniformBuffer && pmGravityOn && sorFrame &&
          physicsUniforms.totalAmplitude < 0.02f) {
        // clear fine mass → bin (skip-outside) → solve.
        {
          id<MTLBlitCommandEncoder> zb = [cmdBuf blitCommandEncoder];
          [zb fillBuffer:fineCellMassBuffer
                   range:NSMakeRange(0, Impl::kTotalCells * sizeof(uint32_t)) value:0];
          [zb endEncoding];
        }
        {
          id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
          [comp setComputePipelineState:binFineMassPipeline];
          [comp setBuffer:particleBuffer offset:0 atIndex:0];
          [comp setBuffer:fineCellMassBuffer offset:0 atIndex:1];
          [comp setBuffer:fineHashUniformBuffer offset:0 atIndex:2];
          NSUInteger tg = std::min((NSUInteger)256,
                                   binFineMassPipeline.maxTotalThreadsPerThreadgroup);
          [comp dispatchThreads:MTLSizeMake(particleCount, 1, 1)
              threadsPerThreadgroup:MTLSizeMake(tg, 1, 1)];
          [comp endEncoding];
        }
        // PROLONGATE: seed the fine grid with the coarse solution so SOR starts
        // from a field that ALREADY carries the full large-scale gradient (the
        // galaxy). Without this the interior stayed flat → gravity in the patch
        // came out WEAKER than coarse and the core spread (measured). The sweeps
        // below then only add the short-wavelength interior detail (fast for SOR).
        // DELTA-PROLONGATION every solve frame (2026-07-12 "moat" fix). The
        // cold-start-only seed went STALE as the coarse well deepened — the
        // fine interior became a relative potential HILL and infall parked in
        // a shell at the ±R_fine rim (measured: peakShell r≈2.2, M<Rfine→0).
        // The kernel now adds only the trilinear CHANGE in coarse Φ since the
        // last prolongation (coarsePhiPrev): the large scale tracks the live
        // galaxy, the sweeps' accumulated fine detail SURVIVES, and cold start
        // falls out of the zero-initialized prev buffer.
        if (prolongatePipeline && coarsePhiPrevBuffer) {
          id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
          [comp setComputePipelineState:prolongatePipeline];
          [comp setBuffer:finePhiBuffer offset:0 atIndex:0];
          [comp setBuffer:fineHashUniformBuffer offset:0 atIndex:1];
          [comp setBuffer:phiBuffer offset:0 atIndex:2];                // COARSE Φ
          [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:3]; // COARSE uniforms
          [comp setBuffer:coarsePhiPrevBuffer offset:0 atIndex:4];      // injected-Φ memory
          NSUInteger tgR = std::min((NSUInteger)256,
                                    prolongatePipeline.maxTotalThreadsPerThreadgroup);
          [comp dispatchThreads:MTLSizeMake(Impl::kTotalCells, 1, 1)
              threadsPerThreadgroup:MTLSizeMake(tgR, 1, 1)];
          [comp endEncoding];
        }
        float Gsim = physicsUniforms.gravGM / std::max(physicsUniforms.massTotal, 1.0f);
        // NESTED BC: the fine patch's boundary is the COARSE Φ (which carries all
        // the mass OUTSIDE the patch). sp.y is unused by poisson_sor_fine.
        float fineParams[2] = {(float)(4.0 * 3.14159265358979) * Gsim, 0.0f};
        NSUInteger tgP = std::min((NSUInteger)256,
                                  poissonFinePipeline.maxTotalThreadsPerThreadgroup);
        // 80 sweeps was the COLD-START number. With prolongation the solve now
        // starts from the correct large-scale field and only has to add
        // short-wavelength interior detail — which SOR kills fast. 16 sweeps.
        // (80 sweeps × 2 colours over 2.1M cells every other frame was doubling
        // the whole PM cost for nothing: 10 fps with merge on.) Tunable via
        // SS_AMR_SWEEPS if we need to trade accuracy back in.
        static int kFineSweeps = 0;
        if (kFineSweeps == 0) {
          kFineSweeps = 4;   // 2026-07-18: 4 = the approved honest-stack default (was 16); SS_AMR_SWEEPS overrides
          if (const char *fs = getenv("SS_AMR_SWEEPS")) {
            int v = atoi(fs);
            if (v >= 1 && v <= 200) kFineSweeps = v;
          }
        }
        for (int sweep = 0; sweep < kFineSweeps; sweep++) {
          for (uint color = 0; color < 2u; color++) {
            id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
            [comp setComputePipelineState:poissonFinePipeline];
            [comp setBuffer:fineCellMassBuffer offset:0 atIndex:0];
            [comp setBuffer:finePhiBuffer offset:0 atIndex:1];
            [comp setBuffer:fineHashUniformBuffer offset:0 atIndex:2];
            [comp setBytes:&fineParams length:sizeof(fineParams) atIndex:3];
            [comp setBytes:&color length:sizeof(color) atIndex:4];
            [comp setBuffer:phiBuffer offset:0 atIndex:5];                 // COARSE Φ → fine boundary
            [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:6];  // COARSE uniforms
            [comp dispatchThreads:MTLSizeMake(Impl::kTotalCells, 1, 1)
                threadsPerThreadgroup:MTLSizeMake(tgP, 1, 1)];
            [comp endEncoding];
          }
        }
      }
      // [AMR] compare fine vs coarse central well (reads last frame's Φ). The
      // fine grid resolves r=0.25/0.5/1.0 sim (8/16/32 fine cells); the coarse
      // grid (cell 1.0 sim) cannot distinguish anything inside 1 sim = the wall.
      if (amrOn && (physicsUniforms.frameCounter % 240u) == 2u &&
          finePhiBuffer && phiBuffer && pmGravityOn) {
        const float *fp = (const float *)finePhiBuffer.contents;
        const float *cp = (const float *)phiBuffer.contents;
        const int N = Impl::kGridSize, c = N / 2;
        auto ix = [&](int i, int j, int k) { return (k * N + j) * N + i; };
        float fineCell = 2.0f * Impl::kAmrFineExtent / (float)N;
        fprintf(stderr,
                "[AMR] fineCell=%.4f sim | finePhi r0=%.4f r.25=%.4f r.5=%.4f r1=%.4f | coarsePhi r0=%.4f r1=%.4f | M<Rfine=%.3e\n",
                fineCell, fp[ix(c, c, c)], fp[ix(c + 8, c, c)], fp[ix(c + 16, c, c)],
                fp[ix(c + 32, c, c)], cp[ix(c, c, c)], cp[ix(c + 1, c, c)], lastMFineEnc);
      }

      // ── [GRIDPROBE] — READ-ONLY. Is the Chladni pattern resolved by the
      // hash grid, and are the voids Jamal sees cell-shaped?
      // (2026-07-29, his pick. Measures; changes nothing.)
      // cellCounts is StorageModeShared and was filled by THIS frame's hash
      // dispatch; we read it on the next probe tick, so no fence is needed
      // (same access pattern as [AMR] above).
      // ⚠ CORRECTED 2026-08-11 12:31:44 — this probe was measuring the wrong
      // volume. The comment said "Cavity is EIGEN_R=3 / EIGEN_L=6 ... scan ±6
      // sim so we see the pattern AND its surroundings", inherited from a stale
      // comment on EIGEN_R (particles.metal:504, itself wrong by 2x). The real
      // cavity is EIGEN_R = ORBIT_R_CHLADNI = 6.0 and EIGEN_L = 12.0, so ±6
      // scanned EXACTLY the cavity and none of its surroundings — the probe
      // could never have seen the void/edge behaviour it was built to check.
      // Now ±9 = 1.5x the cavity radius, which restores the stated intent
      // (pattern + a half-radius of surroundings) while staying inside the
      // hash's ±64 extent. READ-ONLY: this changes logged numbers only.
      if (cellCountsBuffer && physicsUniforms.envelopePhase > 2.5f &&
          (physicsUniforms.frameCounter % 120u) == 7u) {
        const uint32_t *cc = (const uint32_t *)cellCountsBuffer.contents;
        const int N = Impl::kGridSize;
        const float cs = 2.0f * lastHashExtent / (float)N;   // sim per cell
        const int   c  = N / 2;                              // world origin cell
        const int   rad = (int)std::ceil(9.0f / cs);         // ±9 sim = 1.5x cavity r
        auto ix = [&](int i, int j, int k) { return (k * N + j) * N + i; };

        double sum = 0.0, sum2 = 0.0;
        uint32_t mn = 0xFFFFFFFFu, mx = 0;
        long occupied = 0, scanned = 0;
        int lo[3] = {N, N, N}, hi[3] = {-1, -1, -1};
        for (int k = c - rad; k <= c + rad; ++k)
          for (int j = c - rad; j <= c + rad; ++j)
            for (int i = c - rad; i <= c + rad; ++i) {
              if (i < 0 || j < 0 || k < 0 || i >= N || j >= N || k >= N) continue;
              uint32_t v = cc[ix(i, j, k)];
              ++scanned; sum += v; sum2 += (double)v * v;
              if (v < mn) mn = v;
              if (v > mx) mx = v;
              if (v > 0) {
                ++occupied;
                int p[3] = {i, j, k};
                for (int a = 0; a < 3; ++a) {
                  if (p[a] < lo[a]) lo[a] = p[a];
                  if (p[a] > hi[a]) hi[a] = p[a];
                }
              }
            }
        double mean = scanned ? sum / (double)scanned : 0.0;
        double var  = scanned ? (sum2 / (double)scanned) - mean * mean : 0.0;
        double cv   = (mean > 0.0) ? std::sqrt(std::max(var, 0.0)) / mean : 0.0;
        // "void" = a cell inside the occupied bounding box holding <10% of mean
        long voids = 0, inBox = 0;
        if (hi[0] >= lo[0])
          for (int k = lo[2]; k <= hi[2]; ++k)
            for (int j = lo[1]; j <= hi[1]; ++j)
              for (int i = lo[0]; i <= hi[0]; ++i) {
                ++inBox;
                if (cc[ix(i, j, k)] < (uint32_t)(0.1 * mean)) ++voids;
              }
        fprintf(stderr,
                "[GRIDPROBE] cellSize=%.4f sim | pattern spans %dx%dx%d CELLS "
                "(%.1fx%.1fx%.1f sim) | occupied=%ld/%ld | count mean=%.0f min=%u "
                "max=%u CV=%.2f | sub-10%% cells inside box=%ld/%ld (%.1f%%) | "
                "total=%.0f\n",
                cs, hi[0] - lo[0] + 1, hi[1] - lo[1] + 1, hi[2] - lo[2] + 1,
                (hi[0] - lo[0] + 1) * cs, (hi[1] - lo[1] + 1) * cs,
                (hi[2] - lo[2] + 1) * cs, occupied, scanned, mean, mn, mx, cv,
                voids, inBox, inBox ? 100.0 * (double)voids / (double)inBox : 0.0,
                sum);
      }

      // ── [CELLPROBE] — READ-ONLY. IS THE FPS CLIFF THE NEIGHBOUR SCAN?
      // (2026-08-13 14:31:00, his pick, after fps fell to 13-14 the moment the
      // field went to clutter: "jumps into weird clutter after being stuck in
      // rings after play. also then fps sharply drops".)
      //
      // WHY THIS AND NOT [GRIDPROBE]: that probe is gated to sustain
      // (envelopePhase > 2.5) and scans only ±9 sim around the ORIGIN. The
      // cliff arrives at REST, and the clumps are wherever the matter went —
      // his own shot shows them off-centre. A probe that can only see the
      // origin during a held note cannot measure this. This one scans the FULL
      // 128³ and runs in every phase.
      //
      // THE COST MODEL IT TESTS: the collision scan (particles.metal:2685) and
      // the SPH pressure scan (:2932) each walk the 3×3×3 cell neighbourhood.
      // Work is therefore NOT O(N) — it is Σ_cells n_c × (neighbourhood
      // population). The honest single number for that is
      //     meanOwnCell = Σn² / Σn
      // = the average number of particles sharing a particle's OWN cell,
      // i.e. what each thread pays per neighbour cell. Uniform spread over the
      // occupied cells would give Σn/occupied instead, so their RATIO is the
      // clumping penalty in units of "×more work per particle than a spread
      // field". A ratio near 1 exonerates the hash and sends me elsewhere; a
      // large ratio arriving together with the fps drop indicts it.
      // ⚠️ Σn² is a PROXY, not the true 27-cell cost — computing the real
      // neighbourhood sum is 27× this loop and would itself cost frames. It is
      // exact for the self-cell term, which dominates inside a clump.
      //
      // READ-ONLY: no buffer written, no uniform touched. Its own wall cost is
      // printed so it can never be blamed for the thing it measures.
      if (cellCountsBuffer && (physicsUniforms.frameCounter % 120u) == 11u) {
        uint64_t t0 = mach_absolute_time();
        const uint32_t *cc = (const uint32_t *)cellCountsBuffer.contents;
        const long   cells = (long)Impl::kGridSize * Impl::kGridSize * Impl::kGridSize;
        double   sumN = 0.0, sumN2 = 0.0;
        uint32_t mx = 0;
        long     occupied = 0, cellsOver1k = 0, cellsOverCap = 0, cellsOver32 = 0;
        double   sumInOverCap = 0.0, sumVisible = 0.0, sumInOver32 = 0.0;
        double   wReads = 0.0, wValid = 0.0;
        for (long t = 0; t < cells; ++t) {
          uint32_t v = cc[t];
          if (!v) continue;
          ++occupied;
          sumN  += (double)v;
          sumN2 += (double)v * (double)v;
          if (v > mx) mx = v;
          if (v > 1000u) ++cellsOver1k;
          // ── THE CAP TRUTH (his hypothesis, 2026-08-13 14:44:00: the
          // MAX_PER_CELL=128 truncation "would explain a lot of bs in this
          // engine rn"). Every capped read site — the collision scan
          // (particles.metal:2747, live: uiCollisions is engine-permanent),
          // the eruption stress (:1206), the flare colour (:1236), the
          // secondary scan (:2892) — sees min(n,128). So:
          //   sumVisible/N     = the fraction of the field a capped scan can
          //                      EVER see, however many particles are there.
          //   sumInOverCap/N   = the fraction living in a cell that is being
          //                      truncated at all.
          // These are the two numbers that turn "the cap might matter" into a
          // measurement. READ-ONLY, same loop, no extra pass.
          sumVisible += (double)std::min(v, 128u);
          if (v >= 128u) { ++cellsOverCap; sumInOverCap += (double)v; }
          // ── THE GHOST READ (found 2026-08-13 14:52:00). The READ site clamps
          // at MAX_PER_CELL=128 (particles.metal:2747) but the WRITE side caps
          // at 32 (spatial_hash.metal:351-356), while cellStarts is the prefix
          // sum of the UNCAPPED live counts. So a cell holding n particles
          // reserves n slots, has 32 filled, and is READ min(n,128) deep —
          // every read past 32 lands on a slot nothing wrote this frame, in a
          // buffer that is never cleared (the clear blit covers cellCounts,
          // cellMass, seedCount, cellSeedMap, seedAccum, accDiag — not
          // sortedParticles). Those reads return an EARLIER frame's record at a
          // stale position.
          //   reads  = min(n,128)   what the scan consumes
          //   valid  = min(n,32)    what the scatter actually wrote
          // Weighted by cell population, because a cell is read once per
          // particle in its 3x3x3 neighbourhood and the self-cell term
          // dominates inside a clump (same approximation as meanOwnCell, and
          // flagged the same way — a proxy, not the exact 27-cell count).
          if (v > 32u) { ++cellsOver32; sumInOver32 += (double)v; }
          wReads += (double)v * (double)std::min(v, 128u);
          wValid += (double)v * (double)std::min(v,  32u);
        }
        double meanOwn  = (sumN > 0.0) ? sumN2 / sumN : 0.0;      // per-particle
        double meanOcc  = occupied ? sumN / (double)occupied : 0.0; // if spread
        double ratio    = (meanOcc > 1e-9) ? meanOwn / meanOcc : 0.0;
        mach_timebase_info_data_t tb; mach_timebase_info(&tb);
        double probeMs = (double)(mach_absolute_time() - t0) * tb.numer /
                         (double)tb.denom / 1e6;
        fprintf(stderr,
                "[CELLPROBE] N=%.0f occupied=%ld/%ld (%.3f%%) maxCell=%u "
                "cells>1k=%ld meanOwnCell=%.1f meanOccCell=%.1f clump=%.1fx "
                "topCellShare=%.2f%% | CAP128 cells=%ld matterInCapped=%.1f%% "
                "scanCanSee=%.1f%% | WRITE32 cells=%ld matterOver32=%.1f%% "
                "ghostReads=%.1f%% | phase=%.1f probe=%.2fms\n",
                sumN, occupied, cells,
                100.0 * (double)occupied / (double)cells, mx, cellsOver1k,
                meanOwn, meanOcc, ratio,
                (sumN > 0.0) ? 100.0 * (double)mx / sumN : 0.0,
                cellsOverCap,
                (sumN > 0.0) ? 100.0 * sumInOverCap / sumN : 0.0,
                (sumN > 0.0) ? 100.0 * sumVisible / sumN : 0.0,
                cellsOver32,
                (sumN > 0.0) ? 100.0 * sumInOver32 / sumN : 0.0,
                (wReads > 0.0) ? 100.0 * (1.0 - wValid / wReads) : 0.0,
                physicsUniforms.envelopePhase, probeMs);
      }

      // ── [DENSPROBE] — READ-ONLY. WHAT IS THE DENSITY WHEN MASS LANDS IN ONE
      // PLACE? (2026-08-11 02:52:00, his pick.)
      //
      // His words, 2026-08-11 02:41: "at 64 speed why the balck hole always
      // breaks cause we dont knwo what actually happens when the mass / density
      // is that high", and for the buzzy clump "we dot have any science in
      // place here". Both are literally true and BOTH ARE UNMEASURED — nothing
      // in this engine has ever printed a physical density. This measures it.
      // It changes nothing: no buffer is written, no uniform is touched.
      //
      // ⭐ Reports MASS density, not particle count. Every "dense" gate in the
      // engine so far reads cellCounts — the extinction gate
      // (render.metal:2233, smoothstep(150,1500,count)), the flare cap
      // (MAX_PER_CELL=128). But `biggest body 5001 M` against `CORE 28 M` in
      // the 02:33 log says the collapsed state may be a LOT of mass in a FEW
      // particles, in which case every count-based gate reads it as empty
      // space. Printing count and mass for the SAME cell settles that, and the
      // gate value is printed explicitly so the answer needs no interpretation.
      //
      // ⭐ Density is converted to kg/m³ via the engine's OWN length anchor
      // (units.h: kUnitMeters = 2·r_g(field)/... = 1.75504e9 m per sim length),
      // not a scale I picked. M_sun in kg is derived from the file's own
      // kGMsunSI divided by G, rather than pasted in as a second literal. The
      // reference ladder below is what makes the number actionable: it names
      // which physical regime the clump is in, and therefore which physics is
      // missing (there is currently NO pressure of any kind opposing collapse).
      //
      // cellMass holds Σ M_sun × MASS_FP(64) (spatial_hash.metal:60,101) and is
      // StorageModeShared. Same no-fence access pattern as [GRIDPROBE] above.
      //
      // ⚠️ UNGATED on envelopePhase ON PURPOSE. His note 2026-08-11 02:41:
      // concentration happens mainly AFTER play ("theres no fake pull in after
      // play"), so a probe gated to the note would miss the exact state we are
      // trying to characterise. Phase is printed instead so the regime is
      // visible in the line. Cost: one 128³ scan every 120 frames (~2 s).
      if (cellCountsBuffer && cellMassBuffer &&
          (physicsUniforms.frameCounter % 120u) == 43u) {
        const uint32_t *cc = (const uint32_t *)cellCountsBuffer.contents;
        const uint32_t *cm = (const uint32_t *)cellMassBuffer.contents;
        const int  N  = Impl::kGridSize;
        const float cs = 2.0f * lastHashExtent / (float)N;   // sim per cell
        const double cellVolSim = (double)cs * cs * cs;      // sim³

        // Single pass: totals + top-8 cells BY MASS (insertion into a tiny table).
        double  totalMassFP = 0.0;
        long    occupied = 0;
        uint32_t topM[8] = {0,0,0,0,0,0,0,0};
        long     topI[8] = {-1,-1,-1,-1,-1,-1,-1,-1};
        const long NC = (long)N * N * N;
        for (long id = 0; id < NC; ++id) {
          const uint32_t m = cm[id];
          if (!m) continue;
          ++occupied;
          totalMassFP += (double)m;
          if (m > topM[7]) {
            int p = 7;
            while (p > 0 && topM[p - 1] < m) {
              topM[p] = topM[p - 1]; topI[p] = topI[p - 1]; --p;
            }
            topM[p] = m; topI[p] = id;
          }
        }

        if (topI[0] >= 0) {
          const double kMassFP  = 64.0;                       // spatial_hash.metal:60
          const double totalMsun = totalMassFP / kMassFP;
          // M_sun in kg from the engine's own GM_sun anchor: M = GM/G.
          const double kGSI     = 6.67430e-11;                // CODATA 2018, m³/(kg s²)
          const double kMsunKg  = space::spacetime::kGMsunSI / kGSI;
          const double L        = space::spacetime::kUnitMeters;   // m per sim length
          const double cellVolM3 = cellVolSim * L * L * L;

          const double topMsun = (double)topM[0] / kMassFP;
          const uint32_t topCnt = cc[topI[0]];
          const double rhoSim  = topMsun / std::max(cellVolSim, 1e-30);
          const double rhoSI   = topMsun * kMsunKg / std::max(cellVolM3, 1e-30);
          const double nH      = rhoSI / space::spacetime::kProtonMassSI;

          // Where is it? Decode the linear cell id back to (i,j,k) and sim coords.
          const long ti = topI[0] % N, tj = (topI[0] / N) % N, tk = topI[0] / ((long)N * N);
          const double px = ((double)ti + 0.5) * cs - lastHashExtent;
          const double py = ((double)tj + 0.5) * cs - lastHashExtent;
          const double pz = ((double)tk + 0.5) * cs - lastHashExtent;
          const double rad = std::sqrt(px * px + py * py + pz * pz);

          // The extinction gate, evaluated on the SAME cell, so no inference is
          // needed about whether it can fire here. smoothstep(150,1500,count).
          double g = ((double)topCnt - 150.0) / (1500.0 - 150.0);
          g = std::min(1.0, std::max(0.0, g));
          const double gate = g * g * (3.0 - 2.0 * g);

          // Reference ladder — names the regime instead of leaving a bare number.
          const char *regime =
              rhoSI < 1e-15 ? "below interstellar medium" :
              rhoSI < 1e-6  ? "interstellar gas" :
              rhoSI < 1e2   ? "thin gas / protostellar cloud" :
              rhoSI < 1e4   ? "STELLAR (Sun mean 1408)" :
              rhoSI < 1e7   ? "stellar core (Sun centre 1.5e5)" :
              rhoSI < 1e12  ? "WHITE DWARF — electron degeneracy" :
              rhoSI < 1e16  ? "between WD and NS" :
                              "NEUTRON STAR / nuclear (2.3e17)";

          // ── HORIZON ↔ AMR-BOX CORRELATION (2026-08-11 03:14:00, his pick) ──
          // THE QUESTION: does the hole stop existing exactly when the collapsed
          // clump leaves the AMR fine grid?
          //
          // The fine grid is 128³ over ±kAmrFineExtent (4.0) ABOUT THE ORIGIN —
          // SpatialHashUniforms (renderer.h:341) has no centre field, so it
          // cannot be anywhere else. Measured 02:47: the top cell wanders
          // r=0.87→5.89 sim, i.e. in and out of that box. If horizonR collapses
          // on the frames it is OUT, then the origin-lock is the mechanism
          // behind BOTH "the rotating BH is broken" and "particles still render
          // inside the hole" — because the star-pass capture cull
          // (render.metal:665) is gated on `cam.horizonR > 0`, and cam.horizonR
          // is lastHorizonRSmooth (renderer.mm:1610). horizonR → 0 means the
          // cull switches OFF and the swallowed pile pops back into view.
          //
          // All three horizon values are printed because they are NOT the same
          // number and only one of them drives the cull:
          //   lastHorizonR       — raw geometric r_h from the radial profile
          //   lastHorizonRSmooth — eased (×0.03/frame, renderer.mm:1494); THE CULL
          //   lastHorizonRatio   — sup r_s(M(<r))/r, the continuous approach
          // r_s is derived from the top cell's own mass via units.h:85
          // (kRsSimPerMsun), not a constant — so "is it a hole" is answered by
          // its own contents, not by BH_HORIZON=0.57 or any other fixed literal.
          const double rsTop   = topMsun * space::units::kRsSimPerMsun;
          const double fineCS  = 2.0 * (double)Impl::kAmrFineExtent / (double)N;
          const bool   inBox   = std::max(std::max(std::fabs(px), std::fabs(py)),
                                          std::fabs(pz)) <= (double)Impl::kAmrFineExtent;
          // Tracks the RAW value as of 2026-08-11 03:26:00 — the cull was moved
          // off the eased value (render.metal, cam.horizonRRaw). Kept in step on
          // purpose: a probe still reporting the old gate would quietly certify
          // a fix it is no longer measuring.
          const bool   cullOn  = lastHorizonR > 0.0f;

          double topShare = totalMsun > 0.0 ? 100.0 * topMsun / totalMsun : 0.0;
          double top8FP = 0.0;
          for (int b = 0; b < 8; ++b) top8FP += (double)topM[b];
          double top8Share = totalMassFP > 0.0 ? 100.0 * top8FP / totalMassFP : 0.0;

          fprintf(stderr,
              "[DENSPROBE] phase=%.2f cell=%.4f sim (%.3e m) occupied=%ld/%ld "
              "totalMass=%.0f Msun\n"
              "[DENSPROBE]   TOP CELL (%ld,%ld,%ld) r=%.2f sim | mass=%.1f Msun "
              "count=%u | M/particle=%.3f Msun\n"
              "[DENSPROBE]   rho = %.3e Msun/sim^3 = %.3e kg/m^3 = %.3e n_H/m^3 "
              "-> %s\n"
              "[DENSPROBE]   extinction gate smoothstep(150,1500,count=%u) = "
              "%.3f %s | mass share: top1=%.1f%% top8=%.1f%%\n"
              "[HORIZONBOX] inAmrBox(+/-%.1f)=%-5s | r_s(topcell)=%.4f sim "
              "= %.1f fine cells = %.2f coarse | horizonR raw=%.4f smooth=%.4f "
              "ratio=%.3f | star-pass capture cull = %s\n",
              physicsUniforms.envelopePhase, cs, (double)cs * L, occupied, NC,
              totalMsun, ti, tj, tk, rad, topMsun, topCnt,
              topCnt ? topMsun / (double)topCnt : 0.0,
              rhoSim, rhoSI, nH, regime,
              topCnt, gate, gate <= 0.0 ? "(CANNOT FIRE)" : "", topShare,
              top8Share,
              (double)Impl::kAmrFineExtent, inBox ? "IN" : "OUT",
              rsTop, rsTop / fineCS, rsTop / (double)cs,
              lastHorizonR, lastHorizonRSmooth, lastHorizonRatio,
              cullOn ? "ON" : "OFF (particles inside the hole are DRAWN)");
        }
      }

      // Phase 6: densest-cell reduce (the emergent-BH signal, Step 2)
      if (reduceCellMaxPipeline && cellMaxPartialsBuffer && !skipCellMax) {
        id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
        [comp setComputePipelineState:reduceCellMaxPipeline];
        [comp setBuffer:cellCountsBuffer offset:0 atIndex:0];
        [comp setBuffer:cellMaxPartialsBuffer offset:0 atIndex:1];
        [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:2];
        NSUInteger tgM = std::min(
            (NSUInteger)256, reduceCellMaxPipeline.maxTotalThreadsPerThreadgroup);
        [comp dispatchThreads:MTLSizeMake(Impl::kTotalCells, 1, 1)
            threadsPerThreadgroup:MTLSizeMake(tgM, 1, 1)];
        [comp endEncoding];
      }

      // Phase 7: STELLAR MERGERS (US2 eating) — touching stars merge, the
      // heavier eats the lighter. Runs on this frame's fresh snapshot
      // (sortedParticles), writes the live buffer BEFORE compute_physics.
      // The kernel itself skips the attack phase (stale-hash guard).
      // Skip the frame right after a particle-count change: the hash/sorted
      // state may still describe the OLD field (respawn transient).
      static int sLastMergeCount = -1;
      bool countStable = (sLastMergeCount == particleCount);
      sLastMergeCount = particleCount;
      // NO BUILDING DURING PLAY: while any note sounds, the mass-growth pipeline
      // (mergers + seed feeding) is OFF — no eating, no new bodies. Pure
      // cymatics. The BH only grows at rest/silence. (Jamal, 2026-06-14.)
      bool notPlaying = (physicsUniforms.totalAmplitude < 0.02f);
      if (mergeStarsPipeline && countStable && notPlaying && !skipMerge) {
        id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
        [comp setComputePipelineState:mergeStarsPipeline];
        [comp setBuffer:particleBuffer offset:0 atIndex:0];
        [comp setBuffer:sortedParticlesBuffer offset:0 atIndex:1];
        [comp setBuffer:cellStartsBuffer offset:0 atIndex:2];
        [comp setBuffer:cellCountsBuffer offset:0 atIndex:3];
        [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:4];
        [comp setBuffer:uniformBuffer[frameIdx] offset:0 atIndex:5];
        [comp setBuffer:mergeClaimBuffer offset:0 atIndex:6]; // cross-cell claims
        // One thread per CELL (see merge_stars) — only dense cells do work.
        NSUInteger tgMg = std::min(
            tgSize, mergeStarsPipeline.maxTotalThreadsPerThreadgroup);
        [comp dispatchThreads:MTLSizeMake(Impl::kTotalCells, 1, 1)
            threadsPerThreadgroup:MTLSizeMake(tgMg, 1, 1)];
        [comp endEncoding];
      }

      // Phase 8: SEED MARK — write each registered seed's cell into the
      // victim-lookup map. The eating itself is victim-initiated inside
      // compute_physics; seed_apply credits the meals after it.
      if (seedMarkPipeline && countStable && notPlaying) {
        id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
        [comp setComputePipelineState:seedMarkPipeline];
        [comp setBuffer:particleBuffer offset:0 atIndex:0];
        [comp setBuffer:seedCountBuffer offset:0 atIndex:1];
        [comp setBuffer:seedIdsBuffer offset:0 atIndex:2];
        [comp setBuffer:cellSeedMapBuffer offset:0 atIndex:3];
        [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:4];
        [comp setBuffer:uniformBuffer[frameIdx] offset:0 atIndex:5];
        [comp dispatchThreads:MTLSizeMake(1024, 1, 1)
            threadsPerThreadgroup:MTLSizeMake(64, 1, 1)];
        [comp endEncoding];
      }
    }

    // ── Density heatmap (compute from cell counts) ─────────────────
    if (collisionsEnabled && densityPipeline && densityTexture) {
      id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
      [comp setComputePipelineState:densityPipeline];
      [comp setBuffer:cellCountsBuffer offset:0 atIndex:0];
      [comp setTexture:densityTexture atIndex:0];
      [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:1];
      [comp dispatchThreads:MTLSizeMake(kGridSize, kGridSize, 1)
          threadsPerThreadgroup:MTLSizeMake(16, 16, 1)];
      [comp endEncoding];
    }

    // ── Physics kernel ─────────────────────────────────────────────
    // Posed-BH mode FREEZES the integrator (positions stay analytically posed)
    // while the spatial hash above keeps rebuilding — so the geodesic raytracer
    // has a fresh grid of the posed disk to sample. Skipped only when posed.
    if (!bhPosed) {
     // PHYSICS SUB-STEPPING (2026-07-25): N× the FULL physics per frame — the
     // STABLE version. The cheap light-kernel substep (central gravity only)
     // EXPLODED: it strips the field's self-gravity/pressure/boundary balance,
     // so matter flew off its constrained paths (v→0.33c, COLLAPSE 0%). The full
     // loop keeps every force each step → stable, but costs ~N× physics (FPS)
     // and runs drain/merge N× too. Keep N small.
     int nSub = sTrueSubstep ? 1 : std::max(1, physicsSubsteps);
     for (int ssub = 0; ssub < nSub; ssub++) {
      id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
      [comp setComputePipelineState:physicsPipeline];
      [comp setBuffer:particleBuffer offset:0 atIndex:0];
      [comp setBuffer:voiceBuffer[frameIdx] offset:0 atIndex:1];
      [comp setBuffer:uniformBuffer[frameIdx] offset:0 atIndex:2];

      // Always bind collision buffers (shader checks u.collisionsOn)
      if (particleBufferRead && sortedParticlesBuffer && cellStartsBuffer &&
          cellCountsBuffer && spatialHashUniformBuffer) {
        [comp
            setBuffer:(collisionsEnabled ? particleBufferRead : particleBuffer)
               offset:0
              atIndex:3];
        [comp setBuffer:sortedParticlesBuffer offset:0 atIndex:4];
        [comp setBuffer:cellStartsBuffer offset:0 atIndex:5];
        [comp setBuffer:cellCountsBuffer offset:0 atIndex:6];
        [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:7];
        [comp setBuffer:cellCentroidsBuffer offset:0 atIndex:8];
        [comp setBuffer:cellVelocitiesBuffer offset:0 atIndex:9];
        [comp setBuffer:cellMassBuffer offset:0 atIndex:10];
        [comp setBuffer:cellSeedMapBuffer offset:0 atIndex:11];
        [comp setBuffer:seedIdsBuffer offset:0 atIndex:12];
        [comp setBuffer:seedAccumBuffer offset:0 atIndex:13];
        [comp setBuffer:accDiagBuffer offset:0 atIndex:14];
        [comp setBuffer:phiBuffer offset:0 atIndex:15]; // PM gravity Φ (force = −∇Φ)
        [comp setBuffer:sphForceBuffer offset:0 atIndex:16]; // SPH pressure accel (bit11, slice 2b)
        [comp setBuffer:sphClosureBuffer offset:0 atIndex:17]; // TEMP-CLOSURE W_sph
        [comp setBuffer:uBuffer offset:0 atIndex:18]; // SPH u → display radiance-temp bridge
        [comp setBuffer:finePhiBuffer offset:0 atIndex:19];         // AMR fine Φ (bit15: force = −∇Φ_fine)
        [comp setBuffer:fineHashUniformBuffer offset:0 atIndex:20]; // AMR fine-grid uniforms
      }

      NSUInteger tg =
          std::min(tgSize, physicsPipeline.maxTotalThreadsPerThreadgroup);
      [comp dispatchThreads:MTLSizeMake(particleCount, 1, 1)
          threadsPerThreadgroup:MTLSizeMake(tg, 1, 1)];
      [comp endEncoding];
     }
    }

    // ── Seed apply: credit each black hole its meals (after physics) ──
    // GATE MOVED INTO THE SHADER (2026-08-04 22:46:41). This condition used to
    // carry `physicsUniforms.totalAmplitude < 0.02f`, which skipped the whole
    // dispatch while playing. Sustain rebirth now WITHDRAWS mass from the hole
    // and seed_apply is what applies that withdrawal — and it only ever happens
    // while playing, so the kernel must run then. seed_apply re-tests the same
    // amplitude condition internally before crediting meals, so meal-crediting
    // behaviour is unchanged.
    if (seedApplyPipeline && seedAccumBuffer) {
      id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
      [comp setComputePipelineState:seedApplyPipeline];
      [comp setBuffer:particleBuffer offset:0 atIndex:0];
      [comp setBuffer:seedCountBuffer offset:0 atIndex:1];
      [comp setBuffer:seedIdsBuffer offset:0 atIndex:2];
      [comp setBuffer:seedAccumBuffer offset:0 atIndex:3];
      [comp setBuffer:uniformBuffer[frameIdx] offset:0 atIndex:4];
      [comp dispatchThreads:MTLSizeMake(1024, 1, 1)
          threadsPerThreadgroup:MTLSizeMake(64, 1, 1)];
      [comp endEncoding];
    }

    }  // ── end TRUE SUB-STEP loop (nTrue==1 on the default path) ──

    // ── Stats reduction ────────────────────────────────────────────
    // ⏱️ TRUE TIME (E1, 2026-08-30): radialMassBuffer's clear USED TO LIVE inside
    // the step loop (next to the other per-frame clears) while reduce_stats, its
    // only consumer, ACCUMULATES into it out here. That paired a clear that can
    // now run 0 times with an accumulate that always runs once, so on any frame
    // the clock owed no step the 256-shell profile double-accumulated and
    // lastHorizonR — the honest r_h fed back into pressure-yield — inflated.
    // The clear belongs with its consumer, not with the loop.
    if (reduceStatsPipeline && partialSumsBuffer && !skipStats && radialMassBuffer) {
      id<MTLBlitCommandEncoder> rmClear = [cmdBuf blitCommandEncoder];
      [rmClear fillBuffer:radialMassBuffer
                    range:NSMakeRange(0, 256 * sizeof(uint32_t))
                    value:0];
      [rmClear endEncoding];
    }
    if (reduceStatsPipeline && partialSumsBuffer && !skipStats) {
      id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
      [comp setComputePipelineState:reduceStatsPipeline];
      [comp setBuffer:particleBuffer offset:0 atIndex:0];
      [comp setBuffer:partialSumsBuffer offset:0 atIndex:1];
      [comp setBuffer:uniformBuffer[frameIdx] offset:0 atIndex:2];
      [comp setBuffer:radialMassBuffer offset:0 atIndex:3];

      NSUInteger tg = std::min(
          (NSUInteger)256, reduceStatsPipeline.maxTotalThreadsPerThreadgroup);
      [comp dispatchThreads:MTLSizeMake(particleCount, 1, 1)
          threadsPerThreadgroup:MTLSizeMake(tg, 1, 1)];
      [comp endEncoding];

      // Mirror the FINISHED radial profile for the CPU (readback-flicker fix,
      // 2026-07-15): the working buffer is cleared every frame, so an async
      // CPU read could catch all-zero shells (the r_h=0 flicker). This copy
      // runs after the accumulate in GPU queue order; the stable buffer is
      // never cleared → the CPU only ever sees complete profiles.
      if (radialMassStableBuffer) {
        id<MTLBlitCommandEncoder> mirror = [cmdBuf blitCommandEncoder];
        [mirror copyFromBuffer:radialMassBuffer sourceOffset:0
                      toBuffer:radialMassStableBuffer destinationOffset:0
                          size:256 * sizeof(uint32_t)];
        [mirror endEncoding];
      }

      // CPU-side final sum (from partial sums) — 1-frame latency is fine
      // Schedule readback after commit completes
      // For now, read previous frame's data synchronously
      if (numThreadgroups > 0) {
        struct PartialStats {
          float ke, mx, my, sumMass;
          float sumTemp, maxTemp, sumSpeed, maxSpeed;
          float sumPx, sumPy, sumPz, sumCount;
          // sumSeedMass was pad3 (2026-08-03) — MUST stay in lockstep with
          // PartialStats in particles.metal or every field after it misreads.
          float sumR, maxR, maxMass, sumSeedMass;
          float sumEncX, sumEncY, sumEncZ, sumEncMass;
        };
        const PartialStats *sums =
            (const PartialStats *)partialSumsBuffer.contents;
        float totalKE = 0, totalMX = 0, totalMY = 0;
        float totalSumTemp = 0, totalSumSpeed = 0;
        float gMaxTemp = -1e9f, gMaxSpeed = -1e9f;
        // double accumulation: at 5M+ stars float32 partial-sum rounding read
        // as ±0.2% fake mass loss in the conservation watchdog.
        double totalPX = 0, totalPY = 0, totalPZ = 0, totalCT = 0;
        double totalSM = 0;
        float gMaxMass = 0;
        double totalSeedM = 0;   // Σ mass in seed-class bodies (m ≥ M_BH_SEED)
        double totalSR = 0;
        float gMaxR = -1e9f;
        double totalEX = 0, totalEY = 0, totalEZ = 0, totalEC = 0;
        // Only sum the threadgroups actually dispatched this frame. The kernel
        // writes one partial per ceil(particleCount/tg) groups; numThreadgroups
        // is the buffer-alloc size (capacity), so looping it summed STALE
        // partials → averages inflated above the max (impossible). Bound it.
        int dispatchedTGs = std::min(numThreadgroups,
                                     (int)((particleCount + (int)tg - 1) / (int)tg));
        for (int i = 0; i < dispatchedTGs; i++) {
          totalKE += sums[i].ke;
          totalMX += sums[i].mx;
          totalMY += sums[i].my;
          totalSumTemp += sums[i].sumTemp;
          totalSumSpeed += sums[i].sumSpeed;
          totalPX += sums[i].sumPx;
          totalPY += sums[i].sumPy;
          totalPZ += sums[i].sumPz;
          totalCT += sums[i].sumCount;
          totalSM += sums[i].sumMass;
          totalSR += sums[i].sumR;
          if (sums[i].maxR > gMaxR) gMaxR = sums[i].maxR;
          if (sums[i].maxMass > gMaxMass) gMaxMass = sums[i].maxMass;
          totalSeedM += sums[i].sumSeedMass;
          totalEX += sums[i].sumEncX;
          totalEY += sums[i].sumEncY;
          totalEZ += sums[i].sumEncZ;
          totalEC += sums[i].sumEncMass;
          if (sums[i].maxTemp > gMaxTemp) gMaxTemp = sums[i].maxTemp;
          if (sums[i].maxSpeed > gMaxSpeed) gMaxSpeed = sums[i].maxSpeed;
        }
        // ── THE HOLE'S MASS (2026-08-28) ───────────────────────────────────
        // One quantity, and it only grows. No-hair: a hole has M and a, so the
        // drawn hole must key off a single M — not the radial profile, which is
        // a WINDOW (particles.metal:405, RADIAL_MAX_R = 5.0 sim) that stops
        // counting mass past 5 sim and was calibrated when the field collapsed
        // to meanR 3.92. The field now runs far wider, so the profile reads 0
        // and the hole vanishes with a 34,280 M_sun seed still sitting there.
        // Reset ONLY when no seed-class body survives — that is the hole dying,
        // which must stay reversible; a shrinking gMaxMass is not.
        {
          // M_BH_SEED, particles.metal:218. Hand-synced: no build-time link.
          constexpr float kMBhSeedMsun = 50.0f;
          if (gMaxMass >= kMBhSeedMsun)
            bhSeedMassMono = std::max(bhSeedMassMono, gMaxMass);
          else
            bhSeedMassMono = 0.0f;  // seed gone → the hole un-forms
        }
        // HONEST GEOMETRIC HORIZON (observe-only — full_physics_todo B2). From the
        // radial mass profile (mass binned by distance from the BH candidate), find
        // the largest r where r_s(M(<r)) ≥ r. This resolves r_s far below the coarse
        // 1.0-sim cell, so a small dense core can show a REAL horizon. NOT yet wired
        // to formation — just logged, so we can SEE r_h appear when a core crushes.
        if (radialMassStableBuffer) {
          // Read the STABLE mirror, not the per-frame-cleared working buffer
          // (the r_h=0 readback flicker — see the buffer's decl comment).
          const uint32_t *radial = (const uint32_t *)radialMassStableBuffer.contents;
          const double dr = 5.0 / 256.0;           // RADIAL_MAX_R / RADIAL_SHELLS
          const double kRsSimPerMsun = 1.6825e-6;  // units.h
          double cum = 0.0, r_h = 0.0, mEncRh = 0.0, maxRatio = 0.0;
          for (int s = 0; s < 256; s++) {
            cum += radial[s] / 256.0;              // un-scale fixed-point → M_sun
            double r = (s + 1) * dr;
            // The criterion itself, as a number: r_s(M(<r))/r. >= 1 IS a horizon.
            double ratio = kRsSimPerMsun * cum / r;
            if (ratio > maxRatio) maxRatio = ratio;
            if (ratio >= 1.0) { r_h = r; mEncRh = cum; } // horizon here
          }
          // r_h from the profile is still computed above and still LOGGED — it
          // is the honest enclosed-mass reading and we want to see it move. It
          // is no longer what gets drawn. The drawn hole is r_s of the seed:
          // matter merely ORBITING inside a radius is not inside the hole, and
          // counting it is why the old value sloshed and vanished.
          lastHorizonR = (float)(kRsSimPerMsun * (double)bhSeedMassMono);
          lastHorizonMass = (float)mEncRh; // → emergent time-lapse disk GM
          lastHorizonRatio = (float)maxRatio; // continuous approach signal → formation ramp
          if ((physicsUniforms.frameCounter % 120u) == 0u) {
            fprintf(stderr,
                    "[HORIZON] profile r_h=%.4f M(<r_h)=%.3e | DRAWN r_h=%.4f "
                    "from seed M=%.0f (raw seed %.0f)\n",
                    r_h, mEncRh, (double)lastHorizonR,
                    (double)bhSeedMassMono, (double)gMaxMass);
            // ── SLICE 0 (2026-07-11): MEASURE THE WALL — how tightly does the
            // core actually concentrate at rest? Baseline for the AMR before/after.
            // Second pass over the SAME radial profile (mass binned 0..5 sim, 256
            // shells). Reports enclosed mass at key radii, the half-mass radius,
            // and the densest shell. If mass never packs below ~1 sim (the
            // softening floor), r50 stays high and M(<0.5) stays tiny = the wall.
            double mTot5 = cum;                       // total profiled mass within 5 sim
            double c2 = 0.0, m05 = 0.0, m10 = 0.0, m20 = 0.0, r50 = 0.0;
            double mPeak = 0.0; double rPeak = 0.0;
            for (int s = 0; s < 256; s++) {
              double ms = radial[s] / 256.0;
              double r  = (s + 1) * dr;
              c2 += ms;
              if (r <= 0.5) m05 = c2;
              if (r <= 1.0) m10 = c2;
              if (r <= 2.0) m20 = c2;
              if (r50 == 0.0 && c2 >= 0.5 * mTot5 && mTot5 > 0.0) r50 = r;
              if (ms > mPeak) { mPeak = ms; rPeak = r; }
            }
            lastMFineEnc = (float)m20;    // AMR fine-grid BC monopole (M within ±2 sim = kAmrFineExtent)
            fprintf(stderr,
                    "[CORE] Mtot(<5)=%.3e  M(<0.5)=%.3e  M(<1)=%.3e  M(<2)=%.3e  r50=%.3f sim  peakShell r=%.3f m=%.3e  (horizon needs 2.97e5 within 0.5)\n",
                    mTot5, m05, m10, m20, r50, rPeak, mPeak);
          }
        }
        // MASS-WEIGHTED centre of mass of the live stars (real IMF masses) →
        // next frame's self-gravity far-field monopole. Guard NaN/empty.
        if (totalSM > 0.5f && std::isfinite(totalPX) && std::isfinite(totalPY) &&
            std::isfinite(totalPZ)) {
          liveComX = totalPX / totalSM;
          liveComY = totalPY / totalSM;
          liveComZ = totalPZ / totalSM;
          liveCount = totalCT;
        }
        // ── MEASURED field extent for the depth cue (2026-08-11, §H10 fix) ───
        // The same mean radius the [GRAV] line prints as meanR, kept instead of
        // discarded. This replaces the CAP (STAR_MAP_CAP=100 / ORBIT_R_CHLADNI
        // =6) as the depth normaliser. Measured, that was wrong by ~15x: the
        // caps are what matter is ALLOWED to occupy, while the field actually
        // sits at meanR 6.4-9.3 with r50 3.2-4.8. Normalising by 100 gave a
        // 3.7% size spread — his verdict, exactly: "exact same look, unchanged".
        if (totalCT > 0.5) {
          float mR = (float)(totalSR / totalCT);
          if (std::isfinite(mR) && mR > 0.01f) measuredMeanR = mR;
        }
        if (std::isfinite(gMaxR) && gMaxR > 0.01f) measuredMaxR = gMaxR;
        // Emergent-BH enclosure (Step 2): stars within R_ENC of the BH
        // candidate, counted by the same reduce → enclosed mass + refined
        // core position (its COM). Saturation-free, like cellCounts now is
        // (count_cells uncapped — both mass signals are honest).
        // totalEC is now Σ MASS (M_sun) within R_ENC, not a star count; the
        // enclosure positions are mass-weighted to match.
        if (totalEC > 0.5f && std::isfinite(totalEX) && std::isfinite(totalEY) &&
            std::isfinite(totalEZ)) {
          bhMassEnc = totalEC;
          if (false) { // ORIGIN LOCK: refinement disabled — see below
            bhPosX = totalEX / totalEC;
            bhPosY = totalEY / totalEC;
            bhPosZ = totalEZ / totalEC;
          }
        } else {
          bhMassEnc = 0.0f;
        }
        // REAL GEOMETRIC SCHWARZSCHILD CRITERION (2026-06-13 audit — Jamal:
        // "keep it real"). A region IS a black hole only when its mass is
        // crushed inside its own Schwarzschild radius: r_s(M_enc) ≥ R_enc
        // (the physics canon, the same geometric rule everywhere). strength =
        // r_s(M_enc)/R_ENC, = 1 exactly at the true horizon. NO fraction
        // cheat (the old Menc/(0.25·Mtot) declared "formed" at 25% gathered
        // regardless of whether light could escape — that was the lie behind
        // "says formed but isn't").
        //   r_s(M)[sim] = kRsSimPerMsun·M  (units.h, ≈2.327e-7 per M_sun);
        //   R_ENC = 0.5 sim (the enclosure-measurement radius).
        // HONEST CONSEQUENCE at the current scale: 164k M_sun in R_ENC gives
        // strength ≈ 0.08 ≪ 1 → no hole. The science telling the truth — a
        // 594k-M_sun field is a dense cluster, not a Gargantua. A real
        // visible hole needs the mass crushed to the r_s scale (resolution,
        // see the gravity-softening floor) AND more mass (more particles).
        const float kRsSimPerMsun = (float)space::units::kRsSimPerMsun; // single source
        const float kREnc = (float)space::units::kREnc;
        // The hole's mass is the ACCRETED SEED (the biggest body) — the matter
        // actually SWALLOWED, which is conserved and only grows (2026-06-13).
        // The enclosure mass (bhMassEnc) is transient orbiting disk: it sloshes
        // as the disk moves, so basing the hole on it made the hole "form then
        // vanish". The seed IS the black hole (conservation model); r_s(M_seed)
        // is its real horizon, monotonic → the hole forms and STAYS, growing as
        // it eats. Use the seed ALONE (not max'd with the enclosure — that
        // would re-import the slosh); gMaxMass only grows via eating, so the
        // signal is monotonic and never flickers.
        bhSeedMass = gMaxMass;
        float seedTarget = (float)(kRsSimPerMsun * bhSeedMass / kREnc); // slow at-rest accretion path (geometric, seed mass)
        // DENSITY-POP (2026-06-20, Jamal's vision): the chord-snapback implosion
        // crushes a large FRACTION of the field's mass into the core (R_ENC) all
        // at once — "so many stars collide they gain all the mass at once and
        // explode into a BH". Fire the horizon on that concentration (density
        // proxy = enclosed mass / total). The literal Schwarzschild criterion at
        // R_ENC=0.5 is unreachable at our field mass, so concentration is the
        // honest trigger for the at-once collapse. Latched below → forms and stays.
        // DENOMINATOR FIX (2026-08-03): was physicsUniforms.massTotal — the SAME
        // wrong denominator caught on 2026-07-18 02:38:40 for fieldMassMsun, left
        // behind here. massTotal is sMassTotal × the Size-slider massScale, a
        // scaled GRAVITY anchor; bhMassEnc is a sum of real posW.w masses. Mixing
        // them made this ratio read Size-dependent nonsense: measured live at
        // Size=0.80, massScale=0.318 → Menc 105096 / 189044 = 56% "gathered" when
        // the honest figure against Σ posW.w (594276) is 17.7%, a 3.14× inflation
        // that fed straight into densTarget and the on-screen hole %. totalSM is
        // the live Σ the same reduce already computed — one mass definition.
        float encFrac = bhMassEnc / std::max((float)totalSM, 1.0f);
        float dt01 = (encFrac - 0.40f) / 0.30f;          // ramp 40%→70% gathered
        dt01 = dt01 < 0.0f ? 0.0f : (dt01 > 1.0f ? 1.0f : dt01);
        float densTarget = dt01 * dt01 * (3.0f - 2.0f * dt01); // smoothstep
        // HONEST HORIZON (2026-07-15): r_h > 0 IS "a black hole formed" —
        // the literal geometric criterion this proxy was invented to
        // approximate is now reachable and firing (first: r_h=0.82,
        // 2026-07-15 14:27:08). It drives the formed-latch (secondary
        // lensed image, raytracer gates) directly.
        // THE TRANSITION STEP (2026-08-03): this was `(lastHorizonR > 0) ? 1 : 0`
        // — a BOOLEAN. The frame the innermost shell crossed the criterion, the
        // target went 0 → 1 and the latch pinned bhStrength to 1, so everything
        // keyed to it switched on at once: the lens ramp (smoothstep 0.2→0.9),
        // the raytracer gate (>0.5) and the doubled particle instancing (>0.5).
        // That one-frame snap is the "jumps to a weird stage" — the sim wasn't
        // entering a wrong state, it was entering the RIGHT state instantly.
        // The criterion is a continuous quantity; only the thresholding made it
        // binary. Feed the ratio itself, so formation ARRIVES instead of firing.
        float honestTarget = std::min(lastHorizonRatio, 1.0f);
        float target = std::max({seedTarget, densTarget, honestTarget});
        (void)collapseFrac;                      // UI dial now unused by formation
        // SMOOTH + LATCH: the raw enclosure signal wobbles with disk slosh
        // and made the raytracer flicker on/off ("seconds of black hole
        // greatness"). Ease toward it; once FORMED, a black hole stays a
        // black hole — mass inside doesn't leave. The latch clears only on
        // true dissolution (field reset: Menc < 1% of total).
        bhStrengthEma += (target - bhStrengthEma) * 0.04f;
        // ── FORMED == THE HONEST HORIZON EXISTS (2026-08-03) ─────────────────
        // Was: set on `target >= 1` (the max of the seed-mass and density-
        // concentration PROXIES) and cleared on
        // `bhMassEnc < 1% of total && gMaxMass < 50`. Both halves of that clear
        // are unreachable by construction, so the latch could only ever be set:
        //   - gMaxMass is MONOTONE (mass is conserved into the seed and the
        //     seed only ever eats), so once a merger product passes 50 M_sun it
        //     never drops below it again while that body exists;
        //   - bhMassEnc is the mass within R_ENC=0.5 of the ORIGIN, which is a
        //     few percent for ANY centrally-concentrated cluster — even a
        //     perfect respawn lands around 2%, never under 1%.
        // Result: "BH FORMED" survived the hole being destroyed, and with it
        // bhStrength pinned at 1 (lens, secondary image, raytracer, and the
        // doubled particle instancing at renderer.mm:3355 all stayed on).
        // The proxies were invented in 2026-06 BECAUSE the literal geometric
        // criterion was unreachable at our field mass. It has been reachable
        // and firing since 2026-07-15 (first r_h=0.82), so the proxy is no
        // longer needed to declare formation — and, being unlatched from any
        // physical horizon, it was the thing declaring a hole that isn't there.
        // A black hole exists exactly while its horizon does. r_h is recomputed
        // every frame from the radial mass profile (via the flicker-free stable
        // mirror), so this is reversible without being twitchy: destroy the
        // mass concentration and r_h goes to 0 and the hole un-forms; leave the
        // seed alive and r_h stays > 0 and it correctly STAYS formed — a
        // scattered disk around a surviving 5e5 M_sun body is still a hole.
        // The proxies keep driving the sub-1 EMA ramp; they no longer latch.
        if (honestTarget >= 1.0f) bhFormedLatch = true;
        if (lastHorizonR <= 0.0f)  bhFormedLatch = false;
        bhStrength = bhFormedLatch ? std::max(bhStrengthEma, 1.0f)
                                   : bhStrengthEma;
        // POSE OVERRIDE: a posed BH is declared formed of bhPoseMass — the posed
        // disk has no central core, so the emergent computation above would
        // un-form it (bhStrength→0, killing the lens + raytracer). Re-pin it.
        if (bhPosed) {
          bhSeedMass    = bhPoseMass;
          bhStrengthEma = 1.0f;
          bhStrength    = 1.0f;
          bhFormedLatch = true;
        }
        if ((physicsUniforms.frameCounter % 120u) == 0u) {
          fprintf(stderr,
                  "[BH-POP] rs/r=%.3f encFrac=%.2f densTarget=%.2f seedTarget=%.3f -> bhStrength=%.2f%s\n",
                  lastHorizonRatio, encFrac, densTarget, seedTarget, bhStrength,
                  bhFormedLatch ? " LATCH" : "");
          // ── REBIRTH WITHDRAWAL (2026-08-04 22:46:41) ───────────────────────
          // seedAccum slot-0 word [6] is the global per-frame withdrawal ledger
          // (mass ×64), cleared every frame like the rest of the buffer, so this
          // is a PER-FRAME rate, not a running total (1-frame readback lag, same
          // as the meal figures above). `hole` is gMaxMass: watch it FALL under
          // a held note — that is the whole point of the change, and it is the
          // first time this quantity has ever been non-monotone.
          if (seedAccumBuffer) {
            const uint32_t *a = (const uint32_t *)seedAccumBuffer.contents;
            float wdraw = (float)a[6] / 64.0f;
            if (wdraw > 0.0f)
              fprintf(stderr,
                      "[REBIRTH] withdraw=%.1f Msun/frame  hole=%.1f  seedTarget=%.3f%s\n",
                      wdraw, gMaxMass, seedTarget,
                      (wdraw > gMaxMass) ? "  SHORTFALL(minted)" : "");
          }
          // ── FAKE-PULL GATE MEASUREMENT (2026-08-03, step 1 of 2) ───────────
          // Jamal: the origin spring "must only exist once multiple bodies of a
          // lot of mass have already formed and a lot of all particles is about
          // to collapse". Measure BOTH terms of that sentence over a natural
          // collapse FIRST; the thresholds get derived from this curve, not
          // picked. share = fraction of live mass already organised into
          // seed-class bodies; biggest = how much of that is one body (share
          // high with nSeed 1 means ONE lump, not "multiple bodies").
          // nReg/nProbe: the registry counter is read at [4] by the `seeds=`
          // field above while its alloc comment calls [0] the count — printing
          // both, because the gate must key off whichever is truly the count.
          {
            const uint32_t *sc =
                seedCountBuffer ? (const uint32_t *)seedCountBuffer.contents : nullptr;
            double share = (totalSM > 1.0) ? (totalSeedM / totalSM) : 0.0;
            fprintf(stderr,
                    "[PULLGATE] nReg=%u nProbe=%u seedM=%.0f share=%.4f "
                    "biggest=%.0f bigShare=%.4f Mlive=%.0f\n",
                    sc ? sc[0] : 0u, sc ? sc[4] : 0u,
                    totalSeedM, share, gMaxMass,
                    (totalSM > 1.0) ? (gMaxMass / totalSM) : 0.0, totalSM);
          }
        }

        // TEMP validation log (Step-1 bring-up): liveCount MUST read the full
        // particle count and COM ≈ 0 at spawn, else the 48B reduce is broken.
        if ((physicsUniforms.frameCounter % 240u) == 0u) {
          // CONSERVATION WATCHDOG: Mlive (Σ mass of living stars) must equal
          // Mtot (spawn total) through ANY number of mergers — mass moves
          // between stars, never appears or vanishes. live (count) dropping
          // while Mlive holds = stars being EATEN, working as designed.
          fprintf(stderr,
                  "[GRAV] live=%.0f Mlive=%.0f/%.0f Mmax=%.1f hole=%.2f%s seeds=%u feed=%u/%.1f scan=%u s0[cnt=%u e0m=%.3f e0id=%u exit=%u] com=(%.2f %.2f %.2f) "
                  "meanR=%.2f maxR=%.1f "
                  "phase=%.1f amp=%.3f gm=%.3f bh=(%.2f %.2f %.2f) Menc=%.0f peak=%u "
                  "mrg=%u/%u/%u\n",   // TEMP A1″: reached-CAS / landed / refused
                  liveCount, totalSM, physicsUniforms.massTotal, gMaxMass,
                  bhStrength, bhFormedLatch ? "L" : "",

                  seedCountBuffer ? ((const uint32_t *)seedCountBuffer.contents)[4] : 0u,
                  [&]() -> uint32_t {
                    if (!seedAccumBuffer) return 0;
                    const uint32_t *a = (const uint32_t *)seedAccumBuffer.contents;
                    uint32_t meals = 0;
                    // full 1024-slot registry (256 was stale from the old cap)
                    for (int i = 0; i < 1024; i++) meals += a[i * 8 + 1];
                    return meals;
                  }(),
                  [&]() -> float {
                    if (!seedAccumBuffer) return 0.0f;
                    const uint32_t *a = (const uint32_t *)seedAccumBuffer.contents;
                    uint64_t fp = 0;
                    for (int i = 0; i < 1024; i++) fp += a[i * 8 + 0];
                    return (float)fp / 64.0f;
                  }(),
                  seedCountBuffer ? ((const uint32_t *)seedCountBuffer.contents)[3] : 0u,
                  seedCountBuffer ? ((const uint32_t *)seedCountBuffer.contents)[4] : 0u,
                  seedCountBuffer
                      ? ((const uint32_t *)seedCountBuffer.contents)[5] / 1000.0f
                      : 0.0f,
                  seedCountBuffer ? ((const uint32_t *)seedCountBuffer.contents)[6] : 0u,
                  seedCountBuffer ? ((const uint32_t *)seedCountBuffer.contents)[7] : 0u,
                  liveComX, liveComY, liveComZ,
                  (totalCT > 0.5f) ? (totalSR / totalCT) : -1.0f, gMaxR,
                  physicsUniforms.envelopePhase,
                  physicsUniforms.totalAmplitude, physicsUniforms.gravGM,
                  bhPosX, bhPosY, bhPosZ, bhMassEnc, bhPeakCount,
                  accDiagBuffer ? ((const uint32_t *)accDiagBuffer.contents)[2] : 0u,
                  accDiagBuffer ? ((const uint32_t *)accDiagBuffer.contents)[3] : 0u,
                  accDiagBuffer ? ((const uint32_t *)accDiagBuffer.contents)[4] : 0u);
        }
        // TEMP-SLICE3 [SPH] conservation watchdog (remove after slice-3 verdict):
        // sampled momentum / KE / internal energy from the live particle buffer
        // (shared memory, 1-frame lag like every readback here). Viscosity must
        // MOVE energy KE→U, not create it: E=KE+U ≈ flat, p ≈ flat through a shock.
        if ((physicsUniforms.bhToggles & 0x800u) != 0u &&
            (physicsUniforms.frameCounter % 240u) == 0u && particleBuffer &&
            uBuffer) {
          const GPUParticle *pp = (const GPUParticle *)particleBuffer.contents;
          const float *up = (const float *)uBuffer.contents;
          const int stride = 97;  // ~1% sample, prime stride → unbiased
          // TWO LEDGERS: interior (r<64, the physical domain) vs escapers
          // (r≥64, clamped/ejected). If the momentum drift lives only in the
          // escaper bin, the interior book is clean and the question is "who
          // ejects, and why asymmetric" — not a force error in the bulk.
          double m = 0, px = 0, py = 0, pz = 0, ke = 0, uu = 0, umax = 0;
          static std::vector<float> uSamp; uSamp.clear();  // u percentile → display ambient
          double opx = 0, opy = 0, opz = 0, oke = 0;
          int nOut = 0;
          double rMaxU = 0;
          float invDt = 1.0f / physicsUniforms.dt;
          int n = 0;
          // PE from the PM Poisson Φ (same field the force kernel differentiates,
          // so same energy units as KE): PE = ½Σ m·Φ over the interior sample.
          // Decides honest-vs-leak for interior KE bursts: a core collapse pays
          // for its KE out of PE (grand total flat); a numerics pump does not.
          const float *ph = ((physicsUniforms.bhToggles & 0x400u) && phiBuffer)
                                ? (const float *)phiBuffer.contents
                                : nullptr;
          double pe = 0;
          const int NgW = Impl::kGridSize;
          const float heW = lastHashExtent;
          const float invCsW = (heW > 0.0f) ? (float)NgW / (2.0f * heW) : 0.0f;
          for (int i = 0; i < particleCount; i += stride) {
            const GPUParticle &q = pp[i];
            if (q.mass <= 0.0f) continue;
            n++;
            float vx = (q.x - q.prevX) * invDt;
            float vy = (q.y - q.prevY) * invDt;
            float vz = (q.z - q.prevZ) * invDt;
            double r = std::sqrt((double)q.x * q.x + (double)q.y * q.y +
                                 (double)q.z * q.z);
            if (r < 64.0) {
              m += q.mass;
              px += q.mass * vx; py += q.mass * vy; pz += q.mass * vz;
              ke += 0.5 * q.mass * (vx * vx + vy * vy + vz * vz);
              uu += q.mass * up[i];
              if (ph && invCsW > 0.0f) {
                int gi = std::min(std::max(int((q.x + heW) * invCsW), 1), NgW - 2);
                int gj = std::min(std::max(int((q.y + heW) * invCsW), 1), NgW - 2);
                int gk = std::min(std::max(int((q.z + heW) * invCsW), 1), NgW - 2);
                pe += 0.5 * q.mass * ph[(gk * NgW + gj) * NgW + gi];
              }
            } else {
              nOut++;
              opx += q.mass * vx; opy += q.mass * vy; opz += q.mass * vz;
              oke += 0.5 * q.mass * (vx * vx + vy * vy + vz * vz);
            }
            if (up[i] > umax) { umax = up[i]; rMaxU = r; }
            if (r < 64.0) uSamp.push_back(up[i]);
          }
          // PERCENTILE ambient (2026-07-12 23:5x): the mean can't gate a glow —
          // half the gas is above it by definition and the ^0.25 colour curve
          // lights ANY excess. p90 of the sampled u → 90% of the field renders
          // dark by construction; only the genuinely hot tail glows.
          if (uSamp.size() > 100) {
            size_t k90 = (uSamp.size() * 9) / 10;
            std::nth_element(uSamp.begin(), uSamp.begin() + k90, uSamp.end());
            liveUAmbient = uSamp[k90];
          }
          fprintf(stderr,
                  "[SPH] f=%u nIn=%d m=%.0f pIn=(%.4g %.4g %.4g) KEin=%.6g U=%.6g "
                  "Ein=%.6g PEin=%.6g Etot=%.6g | nOut=%d pOut=(%.4g %.4g %.4g) "
                  "KEout=%.6g | umax=%.4g@r=%.1f\n",
                  physicsUniforms.frameCounter, n - nOut, m, px, py, pz, ke, uu,
                  ke + uu, pe, ke + uu + pe + oke, nOut, opx, opy, opz, oke,
                  umax, rMaxU);
          // TEMP-CLOSURE: window-integrated books. Honest pairwise physics ⇒
          // S = W + dyn ≈ 0 (the force's work is exactly the heat's source).
          // Persistent S > 0 = energy created inside the SPH pair machinery.
          if (sphClosureBuffer) {
            const int32_t *cl = (const int32_t *)sphClosureBuffer.contents;
            double W = cl[0] * 1.0, dyn = cl[1] * 1.0, cool = cl[2] * 1.0,
                   clmp = cl[3] * 1.0;  // ×1.0: GPU ledger rescaled
            fprintf(stderr,
                    "[CLOSURE] f=%u W=%.4g dyn=%.4g S=%.4g cool=%.4g clamp=%.4g "
                    "poison=%d\n",
                    physicsUniforms.frameCounter, W, dyn, W + dyn, cool, clmp,
                    cl[4]);
          }
        }
        latestStats.kineticEnergy = totalKE;
        latestStats.momentumX = totalMX;
        latestStats.momentumY = totalMY;
        latestStats.collisionCount = 0;
        float invN = (particleCount > 0) ? 1.0f / (float)particleCount : 0.0f;
        latestStats.avgTemp = totalSumTemp * invN;
        latestStats.avgSpeed = totalSumSpeed * invN;
        latestStats.maxTemp = gMaxTemp;
        latestStats.maxSpeed = gMaxSpeed;
        latestStats.coreMassMsun = bhMassEnc;
        // MASS-COUNT FIX (2026-07-18 02:38:40): was physicsUniforms.massTotal — a
        // SCALED ANCHOR (sMassTotal × Size massScale) that does NOT match the real
        // Σ posW.w the radial profile / COLLAPSE% numerator sum. That made enclosed
        // M(<r_h)=2.58e5 EXCEED the reported field 1.89e5 (impossible → COLLAPSE
        // >100%). Use the true live mass sum (totalSM) the reduce already computes,
        // so numerator & denominator share ONE mass definition. Gravity is untouched:
        // G1 = gravGM/massTotal cancels to gmSim(1 M☉) regardless of this value.
        latestStats.fieldMassMsun = (float)totalSM;
        latestStats.maxBodyMsun = gMaxMass;
        latestStats.bhStrength = bhStrength;
        // Expose the MEASURED horizon to the UI (2026-08-08). Computed every
        // frame from the radial mass profile since the geometric-criterion work
        // but never published, so the GALAXY panel had nothing live to read.
        latestStats.horizonR        = lastHorizonR;
        latestStats.horizonMassMsun = lastHorizonMass;
        latestStats.horizonRatio    = lastHorizonRatio;
        // Accuracy measurement readback (1-frame lag, like seedAccum). uint
        // milli-ratio → fraction of a light-step the worst gravity kick wanted.
        if (accDiagBuffer) {
          uint32_t micro = *(const uint32_t *)accDiagBuffer.contents;
          latestStats.maxAccRatio = (float)micro * 1.0e-6f;
          latestStats.accOverCount =
              (int)((const uint32_t *)accDiagBuffer.contents)[1];
        }

        // Physical Assert: Check for NaNs or Infinity (Energy Explosion)
        if (std::isnan(totalKE) || std::isinf(totalKE) || totalKE > 1e12f) {
          latestStats.errorState = (std::isnan(totalKE)) ? 1 : 2;
        } else {
          latestStats.errorState = 0;
        }
      }
    }

    // ── Densest-cell readback (Step 2, 1-frame lag): seeds/locates the
    // BH-candidate position. The enclosure COM (above) refines it once
    // real mass gathers; the raw peak cell is the cold-start seed.
    if (reduceCellMaxPipeline && cellMaxPartialsBuffer) {
      struct CellMaxPartial { uint32_t count, cid; };
      const CellMaxPartial *cm =
          (const CellMaxPartial *)cellMaxPartialsBuffer.contents;
      int nTG = (Impl::kTotalCells + 255) / 256;
      uint32_t best = 0, bestCid = 0;
      for (int i = 0; i < nTG; i++) {
        if (cm[i].count > best) { best = cm[i].count; bestCid = cm[i].cid; }
      }
      bhPeakCount = best;
      // ORIGIN LOCK (Jamal: lensing and the hole drifted apart after seconds
      // of correctness): the centre of gravity is PINNED at 0/0/0 by design
      // and the seed sinks there — the hole IS at the origin, always. The
      // wandering enclosure-COM refinement made the rendered shadow chase
      // disk slosh while the disk stayed centred: misalignment + flicker.
      bhPosX = 0.0f;
      bhPosY = 0.0f;
      bhPosZ = 0.0f;
    }

    hasCompute = false;
  }
}

// Internal helper for render pass
void Renderer::Impl::renderWithCamera(id<CAMetalDrawable> drawable,
                                      id<MTLCommandBuffer> cmdBuf, int frameIdx,
                                      const RenderConfig &config) {
  // ── PLAYBACK PHASE INTEGRATION (2026-07-26) ────────────────────────
  // Advance each particle's integrated orbital phase for the time-lapse spin.
  // MUST be here and not in runComputePass: that pass is encoded BEFORE this
  // frame's pose clock (bhPoseTime/bhPoseDt/bhDiskGM) is computed, so it would
  // integrate with a one-frame-stale dt. Encoded on the render command buffer
  // ahead of the particle pass, so the vertex shader reads a phase that is
  // already advanced for this frame. Runs every rendered frame regardless of
  // whether physics is stepping — the held-pause playback keeps spinning.
  // HOST-SIDE GATE (2026-08-11 04:11:00). The kernel self-gates, but a self-gate
  // still launches every thread: this was a 2M-thread dispatch every rendered
  // frame that returned on its first branch whenever no time-lapse was running —
  // which is every frame before the first hole forms, and every frame of every
  // note after it. The condition below MIRRORS the kernel's opening test
  // (render.metal pose_phase_advance) TERM FOR TERM against the same values the
  // camera was built from this frame: bit20, the eased bhDiskGM (renderer.mm:1882
  // writes bhDiskGMSmooth into cam.bhDiskGM), and the smoothed envelope phase
  // (:1727 writes renderPhaseSmooth into cam.envelopePhase). bhDiskAxisY is
  // omitted deliberately — it is 0.0f at all seven assignment sites, so
  // `< 0.5f` is a constant true; if that ever changes, this gate must gain the
  // term. ⚠ IF THE KERNEL'S GATE CHANGES, CHANGE THIS ONE IN THE SAME COMMIT —
  // a host gate that is stricter than the kernel's silently freezes the phase.
  const bool poseTimeLapseActive =
      (config.bhToggles & 0x100000u) != 0u &&
      bhDiskGMSmooth > 0.0f &&
      renderPhaseSmooth < 0.5f;
  if (posePhasePipeline && posePhaseBuffer && particleCount > 0 &&
      poseTimeLapseActive) {
    id<MTLComputeCommandEncoder> pp = [cmdBuf computeCommandEncoder];
    [pp setComputePipelineState:posePhasePipeline];
    [pp setBuffer:particleBuffer offset:0 atIndex:0];
    [pp setBuffer:cameraBuffer[frameIdx] offset:0 atIndex:1];
    [pp setBuffer:posePhaseBuffer offset:0 atIndex:2];
    NSUInteger tg = std::min((NSUInteger)256,
                             posePhasePipeline.maxTotalThreadsPerThreadgroup);
    [pp dispatchThreads:MTLSizeMake(particleCount, 1, 1)
        threadsPerThreadgroup:MTLSizeMake(tg, 1, 1)];
    [pp endEncoding];
  }

  // ── First Pass: Render particles to offscreen texture ──────────────
  MTLRenderPassDescriptor *offscreenPass =
      [MTLRenderPassDescriptor renderPassDescriptor];
  offscreenPass.colorAttachments[0].texture = offscreenTexture;
  // Attachment 1 = motion vectors, cleared to zero so any pixel no star wrote
  // reads as "not moving" and the smear leaves it alone.
  offscreenPass.colorAttachments[1].texture = velocityTexture;
  offscreenPass.colorAttachments[1].loadAction = MTLLoadActionClear;
  offscreenPass.colorAttachments[1].clearColor = MTLClearColorMake(0, 0, 0, 0);
  offscreenPass.colorAttachments[1].storeAction = MTLStoreActionStore;
  offscreenPass.colorAttachments[0].loadAction = MTLLoadActionClear;
  offscreenPass.colorAttachments[0].storeAction = MTLStoreActionStore;
  offscreenPass.colorAttachments[0].clearColor =
      MTLClearColorMake(0, 0, 0, 0); // Transparent black

  offscreenPass.depthAttachment.texture = depthTexture;
  offscreenPass.depthAttachment.loadAction = MTLLoadActionClear;
  offscreenPass.depthAttachment.storeAction = MTLStoreActionDontCare;
  offscreenPass.depthAttachment.clearDepth = 1.0;

  // [KPROBE] (2026-07-28): allocate once, zero every frame BEFORE the particle
  // pass writes into it, so the readback below is exactly one frame's histogram
  // and not an unbounded accumulation. 64 uints = 256 B (52 used).
  if (!kProbeBuf[frameIdx])
    kProbeBuf[frameIdx] = [device newBufferWithLength:128 * sizeof(uint32_t)
                                             options:MTLResourceStorageModeShared];
  // Scratch [KPROBE] target for the depth pre-pass. particle_vertex atomically
  // increments this histogram, so running the shader twice per frame against
  // the REAL buffer would double every bin and silently corrupt the readback
  // above. Never read; exists only to absorb those writes. Private storage —
  // the CPU has no reason to see it.
  if (!kProbeDummy)
    kProbeDummy = [device newBufferWithLength:128 * sizeof(uint32_t)
                                      options:MTLResourceStorageModePrivate];
  {
    // READ FIRST (this slot's last completed frame), THEN clear for this frame.
    const uint32_t *kp = (const uint32_t *)kProbeBuf[frameIdx].contents;
    double nowK = CACurrentMediaTime();
    if (kProbeLastPrint == 0.0) kProbeLastPrint = nowK;
    if (nowK - kProbeLastPrint >= 1.0 && kp[48] > 0) {
      kProbeLastPrint = nowK;
      double cSum = 0, lSum = 0, aSum = 0;
      for (int b = 0; b < 16; b++) {
        cSum += kp[b]; lSum += kp[16 + b]; aSum += kp[32 + b];
      }
      // Bin b covers [1000·40^(b/16), 1000·40^((b+1)/16)) K.
      printf("[KPROBE] sampled=%u culled=%u  (bin: Kmin  count%%  lum%%  area%%)\n",
             kp[48], kp[49]);
      for (int b = 0; b < 16; b++) {
        if (!kp[b] && !kp[16 + b] && !kp[32 + b]) continue;
        double kmin = 1000.0 * pow(40.0, b / 16.0);
        printf("[KPROBE]  %2d %7.0fK  %5.1f%%  %5.1f%%  %5.1f%%\n", b, kmin,
               cSum > 0 ? 100.0 * kp[b] / cSum : 0.0,
               lSum > 0 ? 100.0 * kp[16 + b] / lSum : 0.0,
               aSum > 0 ? 100.0 * kp[32 + b] / aSum : 0.0);
      }
      // ── SCALE (2026-07-28): the never-measured number. out.pointSize is in
      // PIXELS, so szSum/drawn is literally the average star's on-screen
      // diameter at his real zoom.
      double szN = 0, mN = 0;
      for (int b = 0; b < 16; b++) { szN += kp[50 + b]; mN += kp[66 + b]; }
      printf("[KPROBE-SCALE] drawn=%.0f  meanPx=%.2f  maxPx=%.2f\n", szN,
             szN > 0 ? (kp[83] / 100.0) / szN : 0.0, kp[82] / 100.0);
      printf("[KPROBE-SCALE] size px:");
      for (int b = 0; b < 16; b++) {
        if (!kp[50 + b]) continue;
        printf("  %.2f:%.1f%%", pow(2.0, -2.0 + b * 10.0 / 16.0),
               100.0 * kp[50 + b] / (szN > 0 ? szN : 1));
      }
      // ── G2 PRE-CLAMP (2026-08-22) ────────────────────────────────────────
      // The bins above are POST-clamp, so every floored star reads as 1.0 px
      // and the histogram cannot say what drove it. These are rawSize BEFORE
      // `drawn = clamp(rawSize, 1.0f, zoomCap)`, same gate, same log2 ladder.
      {
        double rN = 0;
        for (int b = 0; b < 16; b++) rN += kp[84 + b];
        if (rN > 0) {
          printf("\n[KPROBE-RAW] n=%.0f  meanRaw=%.3f px  FLOORED=%.1f%%  "
                 "capped=%.1f%%",
                 rN, (kp[102] / 100.0) / rN,
                 100.0 * kp[100] / rN, 100.0 * kp[101] / rN);
          printf("\n[KPROBE-RAW] rawSize px:");
          for (int b = 0; b < 16; b++) {
            if (!kp[84 + b]) continue;
            printf("  %.2f:%.1f%%", pow(2.0, -2.0 + b * 10.0 / 16.0),
                   100.0 * kp[84 + b] / rN);
          }
        }
      }
      printf("\n[KPROBE-SCALE] mass Msun:");
      for (int b = 0; b < 16; b++) {
        if (!kp[66 + b]) continue;
        printf("  %.3g:%.1f%%", pow(10.0, -2.0 + b * 5.0 / 16.0),
               100.0 * kp[66 + b] / (mN > 0 ? mN : 1));
      }
      printf("\n");
      fflush(stdout);
    }
    id<MTLBlitCommandEncoder> zk = [cmdBuf blitCommandEncoder];
    [zk fillBuffer:kProbeBuf[frameIdx]
             range:NSMakeRange(0, 128 * sizeof(uint32_t)) value:0];
    [zk endEncoding];
  }

  // ══ DEPTH PRE-PASS (2026-08-11 — board §H1 P1, step 1) ═══════════════════
  // Writes NEAREST depth for the particle cloud into depthPrepassTexture and
  // stores it. Colour is not touched: this pass has NO colour attachment and
  // NO fragment stage, and it targets its own depth texture, so the offscreen
  // pass below is byte-for-byte what it was.
  //
  // 🚨 WHAT THIS IS FOR — it buys three separate board rows, not one:
  //   P1  — occlusion becomes possible at all (nothing has ever written depth).
  //   C4a — the camera motion blur unprojects every pixel at a hardcoded
  //         z=0.99 "far-plane proxy" (postfx.metal) purely because no depth was
  //         readable. With this stored, that fake can be retired.
  //   C4b — per-particle motion vectors / TAA, currently blocked outright.
  // Nothing consumes the texture YET — wiring it into post-FX CHANGES THE
  // IMAGE and is therefore a separate, verdicted step. This step is the
  // no-op half, on purpose.
  //
  // ⚠️ COST IS REAL AND UNMEASURED AT WRITE TIME: this re-runs particle_vertex
  // for every particle (and every instance), and that shader is the most
  // expensive in the app — §H4 measured the whole star pass at 2.4–3.3 ms.
  // A depth-only pass has no fragment stage so it should cost less than that,
  // but "should" is not a measurement. SS_NO_DEPTH_PREPASS=1 skips encoding it
  // entirely, so [PROFILE/120f] A/B gives the number the same way
  // SS_NO_STARPASS bounded §G6. If it proves too expensive, the cheap fix is a
  // dedicated minimal vertex shader — position and point size only.
  static const bool kNoDepthPrepass =
      (getenv("SS_NO_DEPTH_PREPASS") != nullptr);
  if (!kNoDepthPrepass && depthPrepassPipeline && depthPrepassTexture &&
      particleCount > 0) {
    MTLRenderPassDescriptor *depthPass =
        [MTLRenderPassDescriptor renderPassDescriptor];
    depthPass.depthAttachment.texture = depthPrepassTexture;
    depthPass.depthAttachment.loadAction = MTLLoadActionClear;
    depthPass.depthAttachment.clearDepth = 1.0;
    // STORE, unlike the main pass's DontCare — being readable afterwards is
    // the entire reason this pass exists.
    depthPass.depthAttachment.storeAction = MTLStoreActionStore;

    // One-shot proof that this pass actually ENCODES. A successful pipeline
    // creation only proves the pipeline exists; the guard above could still
    // skip every frame on a nil texture or zero count and the failure would be
    // silent — the exact "change did nothing" trap the protocol says to suspect
    // first. Prints once per process, never per frame.
    static bool announcedPrepass = false;
    if (!announcedPrepass) {
      announcedPrepass = true;
      printf("[DEPTHPREPASS] ENCODING — %u particles x %u instance(s), "
             "target %lux%lu, storeAction=Store\n",
             (unsigned)particleCount, (unsigned)((bhStrength > 0.5f) ? 2u : 1u),
             (unsigned long)depthPrepassTexture.width,
             (unsigned long)depthPrepassTexture.height);
      fflush(stdout);
    }
    id<MTLRenderCommandEncoder> dpe =
        [cmdBuf renderCommandEncoderWithDescriptor:depthPass];
    [dpe setRenderPipelineState:depthPrepassPipeline];
    [dpe setDepthStencilState:depthWriteState];
    // Bindings mirror the star pass EXACTLY (same buffers, same indices) so the
    // depth lands where the sprite lands — with ONE deliberate difference at
    // index 9, the [KPROBE] histogram, which gets the scratch buffer so this
    // second invocation cannot double-count the measurement.
    [dpe setVertexBuffer:particleBuffer offset:0 atIndex:0];
    [dpe setVertexBuffer:cameraBuffer[frameIdx] offset:0 atIndex:1];
    [dpe setVertexBuffer:particleBuffer offset:0 atIndex:2];
    [dpe setVertexBuffer:lensAlphaLUT offset:0 atIndex:3];
    [dpe setVertexBuffer:cellCountsBuffer offset:0 atIndex:4];
    [dpe setVertexBuffer:spatialHashUniformBuffer offset:0 atIndex:5];
    [dpe setVertexBuffer:spectralContinuumLUT offset:0 atIndex:6];
    [dpe setVertexBuffer:spectralLinesLUT offset:0 atIndex:7];
    [dpe setVertexBuffer:posePhaseBuffer offset:0 atIndex:8];
    [dpe setVertexBuffer:kProbeDummy offset:0 atIndex:9];
    // Same instancing rule as the star pass — the secondary lensed image is a
    // real image and owns depth too, so it must be present or the two passes
    // would disagree about what is on screen.
    [dpe drawPrimitives:MTLPrimitiveTypePoint
            vertexStart:0
            vertexCount:particleCount
          // 🔪 LENS DEAD 2026-08-27 21:02:15 (his order) — instance 1 WAS the
          // lens's second image, solved from the opposite root of
          // beta = theta - alpha(theta)*D. With the lens gone there is no
          // second root and no second image: one instance per particle. The
          // far-side and underside images (R5/R6) now have to come from
          // bhmarch_fragment, which is the only thing that can make them
          // honestly. Was: ((bhStrength > 0.5f) ? 2u : 1u).
          instanceCount:1u];
    [dpe endEncoding];
  }

  id<MTLRenderCommandEncoder> enc =
      [cmdBuf renderCommandEncoderWithDescriptor:offscreenPass];

  // Geodesic fullscreen BH render DELETED (2026-06-28) — it was a shader painting
  // a disk, NOT the particles. The black hole must be the actual particle cloud,
  // gravitationally lensed. Particles always render.

  // ── THE HOLE AS A BODY — depth only, drawn BEFORE the particles ──────────
  // This is the pass that makes the hole an OBJECT. It writes the near surface
  // of the photon-capture sphere (b_c = 2.598 r_s) into the depth attachment
  // and writes NO colour (writeMask None on the pipeline). Everything drawn
  // after it depth-tests Less, so matter behind the hole is hidden BY GEOMETRY
  // rather than by a hand-written cull, and matter in front draws over it.
  // Must precede the particle draw — the depth has to exist before anything
  // tests against it.
  if (bhBodyPipeline && lastHorizonR > 0.0f) {
    CameraUniforms *camB = (CameraUniforms *)cameraBuffer[frameIdx].contents;
    BHMarchUniforms bu = {};
    invertMatrix4x4(camB->viewProj, bu.inverseViewProj);
    memcpy(bhMarchUniformBuffer[frameIdx].contents, &bu, sizeof(bu));
    [enc setRenderPipelineState:bhBodyPipeline];
    [enc setDepthStencilState:depthWriteState];   // Less + WRITE ON
    [enc setFragmentBuffer:cameraBuffer[frameIdx] offset:0 atIndex:0];
    [enc setFragmentBuffer:bhMarchUniformBuffer[frameIdx] offset:0 atIndex:1];
    [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
  }

  // Draw Particles — ALWAYS (the particles ARE the black hole)
  [enc setRenderPipelineState:particlePipeline];
  [enc setDepthStencilState:depthState];
  [enc setVertexBuffer:particleBuffer offset:0 atIndex:0];
  [enc setVertexBuffer:cameraBuffer[frameIdx] offset:0 atIndex:1];
  [enc setVertexBuffer:particleBuffer
                offset:0
               atIndex:2]; // Random-access for Webbing
  [enc setVertexBuffer:lensAlphaLUT
                offset:0
               atIndex:3]; // deflection map α(b/r_s) — world-space lens
  // Hash-grid density → density-gated gaseous kernel (dense BH ring/collapse =
  // gas, not sharp points). Guarded in-shader by su.gridSize>0, so a stale/unbuilt
  // hash frame just falls back to the phase/speed gate.
  [enc setVertexBuffer:cellCountsBuffer offset:0 atIndex:4];
  [enc setVertexBuffer:spatialHashUniformBuffer offset:0 atIndex:5];
  // Spectral starmap LUTs (increment 2, bit16): the one colour law's tables.
  [enc setVertexBuffer:spectralContinuumLUT offset:0 atIndex:6];
  [enc setVertexBuffer:spectralLinesLUT offset:0 atIndex:7];
  // Integrated playback phase (pose_phase_advance, dispatched above this pass).
  [enc setVertexBuffer:posePhaseBuffer offset:0 atIndex:8];
  // [KPROBE] Kelvin histogram target — write-only from the vertex shader.
  [enc setVertexBuffer:kProbeBuf[frameIdx] offset:0 atIndex:9];
  // instanceCount — instance 0 = primary image, instance 1 = the SECONDARY
  // lensed image (the Gargantua fold-over). The secondary only EXISTS when a
  // hole is lensing; with no hole it was culled in-shader to pointSize 0 — but
  // the heavy vertex shader (lensing + Doppler + blackbody + streak + webbing
  // partner read) STILL RAN for all 2×N particles, doubling the most expensive
  // pass in the app every frame for nothing. Only instance the secondary when a
  // hole is actually present → no-hole (play/rest) runs 1×, halving the pass.
  NSUInteger particleInstances = (bhStrength > 0.5f) ? 2u : 1u;
  // [G6PROBE] 2026-08-11 — MEASUREMENT INSTRUMENT, NOT A FEATURE, NOT A FIX.
  // §G6 is "2M vertex invocations run every frame no matter what". Before any
  // culling/compaction scheme is designed, the prize has to be bounded: how many
  // ms of the frame is this one draw actually worth? SS_NO_STARPASS=1 skips
  // encoding it entirely, so the existing [PROFILE/120f] "Render+PostFX avg"
  // reports the same frame WITHOUT the pass. A − B = the entire star pass
  // (vertex + rasterisation together); no cull can ever win more than that.
  // Everything the pass writes back ([KPROBE] buffer(9), the whiteout probe) is
  // diagnostic-only, so dropping it perturbs no physics. Read once, never per
  // frame. Default OFF — an unset env is byte-for-byte the shipping path.
  static const bool kNoStarPass = (getenv("SS_NO_STARPASS") != nullptr);
  if (!kNoStarPass) {
    [enc drawPrimitives:MTLPrimitiveTypePoint
            vertexStart:0
            vertexCount:particleCount
          instanceCount:particleInstances];
  }

  // ── DUST EXTINCTION PASS (design §2b, 2026-07-23): cold+dense gas re-drawn
  // as absorbing splats OVER the additive image — dark silhouette bodies with
  // free bright rims where they cut into the glow. Hot/play matter self-gates
  // to zero (cold factor), so this only lives where matter is settled+dense.
  // DISABLED 2026-07-23 16:34 — FIELD VERDICT (Jamal): the extinction region
  // reads as "a low-res shadow thingy / yellow underbelly attached to the
  // hole" — the un-depth-sorted absorbing splats paint a smooth bounded
  // yellow zone over the dense core (teal minus absorbed blue = cream).
  // The CONCEPT (design §2b) stays for the BH overhaul with depth ordering;
  // this v1 draw is off. Pipeline + shaders kept.
  if (false && dustPipeline) {
    [enc setRenderPipelineState:dustPipeline];
    [enc setDepthStencilState:depthState];
    [enc setVertexBuffer:particleBuffer offset:0 atIndex:0];
    [enc setVertexBuffer:cameraBuffer[frameIdx] offset:0 atIndex:1];
    [enc setVertexBuffer:cellCountsBuffer offset:0 atIndex:2];
    [enc setVertexBuffer:spatialHashUniformBuffer offset:0 atIndex:3];
    [enc drawPrimitives:MTLPrimitiveTypePoint
            vertexStart:0
            vertexCount:particleCount];
  }

  // THE HOLE PASS (2026-07-15): re-draw the r<r_h particles as black
  // occluding splats over the additive image — the matter inside the honest
  // horizon eats the light behind it (render.metal hole_vertex). Only encoded
  // when the horizon actually exists; zero cost otherwise.
  // SHADOW = PURE ABSENCE (bit15, 2026-07-24). The hole is not painted at all:
  // nothing arrives from BEHIND it (the capture cull in particle_vertex, at the
  // exact b_c = 2.5980762 r_s) and nothing leaves its INSIDE (the new
  // horizon-interior cull). So the occluder pass — whose only unique job was
  // hiding the interior pile — stands down.
  //
  // WHY THE FULLSCREEN GEODESIC PAINT WAS WITHDRAWN (same day it shipped):
  // it was a fullscreen multiply drawn AFTER the particles, so it blacked out
  // matter clearly in FRONT of the hole (Jamal's verdict). It could not do
  // otherwise — depth WRITE is off for the particles (see the depthDesc note
  // above) so no later pass has any depth to order against. Painting a disc
  // over the finished frame is also exactly the "second layer" the BH core
  // directive forbids. The march itself is kept (bhmarch_* in render.metal,
  // pipeline built above, not drawn): it earns its keep at the next increment,
  // where the ray ACCUMULATES emission from the real particle field — at which
  // point foreground matter is picked up along the ray and the ordering
  // problem disappears by construction rather than by a depth test.
  bool metricShadow = (config.bhToggles & (1u << 15)) != 0u &&
                      lastHorizonR > 0.0f;

  if (!metricShadow && holePipeline && lastHorizonR > 0.0f) {
    [enc setRenderPipelineState:holePipeline];
    [enc setDepthStencilState:depthState];
    [enc setVertexBuffer:particleBuffer offset:0 atIndex:0];
    [enc setVertexBuffer:cameraBuffer[frameIdx] offset:0 atIndex:1];
    [enc drawPrimitives:MTLPrimitiveTypePoint
            vertexStart:0
            vertexCount:particleCount];
  }

  // 2b. Scope lines (oscilloscope) — ISOLATED additive pass over the points.
  // Only encoded when oscillation (spin) is active; the vertex shader also
  // collapses every line to a point when oscAmount≈0, but skipping the draw
  // entirely saves the 2×N vertex work when there's nothing to show. Two
  // verts per particle (head + tail) → line primitive.
  // Orbital-arc trail pass DISABLED — it spawned a second ring inside the
  // black hole. One black hole only. (Pipeline kept for later; not drawn.)
  // Re-enabled (was parked during the scope-line experiments): the orbital
  // long-exposure arcs ARE the "spacetime flow" visual. Drawn when the
  // emergent hole exists (its horizon region is where Ω is fastest) or
  // when the user spins (the manual exposure gesture).
  // STRIPPED 2026-06-25 (Jamal: "fake trails centered to a tube shape" — one of
  // the stacked layers hiding the real physics). These are 22-vertex ANALYTIC
  // Ω(r) arc ribbons per particle, NOT the particles' real paths — a fake tube
  // shape painted over the field. Disabled so trails come ONLY from real motion
  // (the velWorld screen-space streak + the post-fx frame-feedback). Set the
  // gate back to (bhStrength>0.5f || oscAmount>0.01f) to restore. Pipeline kept.
  // ── RE-ENABLED 2026-08-14 12:38:00 — "LETS SPAGHETTIFI THE LIGHT" ────────
  // Stripped 2026-06-25 as "fake trails centered to a tube shape". That verdict
  // was earned by PLANE FIX №3 (render.metal, trajectory_vertex): the arcs swept
  // about +Y while the disk orbits +Z, so every ribbon ran 90° ACROSS the real
  // motion — a tube painted over the field, exactly as he called it. With the
  // plane corrected the arc IS the particle's own orbital path over the exposure
  // window, inner-fast, so matter near the hole spaghettifies and the calm field
  // stays points. Gate is the original: an emergent hole, or manual spin.
  // (The arc/ribbon draw DELETED 2026-08-20 — the motion smear replaces it.)

  // Black-hole raytracer shadow pass DELETED (2026-06-28). It was a screen-space
  // 2D circle that sampled no useful disk. Real gravitational lensing is applied
  // to the particles in the vertex shader (render.metal).

  // 🔪 THE RAY-MARCH EMISSION PASS IS DELETED — 2026-08-27 20:49:10, his order:
  // "the march as it is rn is dead too delete it all of it to never retun its
  //  the oranghe blob itsnot what we want."  The pass gathered emission from a
  // 128^3 density grid along each geodesic — a fog integral over a box, which
  // can only ever be a soft blob. Its pipeline, uniforms block, bit19 toggle
  // and three dials are gone with it. See the banner in render.metal.
  // ⛔ Do not rebuild it. bhMarchUniformBuffer SURVIVES — the hole-as-a-body
  // depth pass below is its only remaining user.

  [enc endEncoding];

  // AUTO-EXPOSURE mip chain (2026-07-16): reduce the freshly rendered HDR
  // scene to its average (top mip). The tonemap samples it to adapt the iris
  // — STOP-DOWN ONLY — so the queue at the hole reads as fire structure
  // instead of clipped white paste (Jamal: "still this blob thing").
  if (offscreenTexture.mipmapLevelCount > 1) {
    id<MTLBlitCommandEncoder> mipBlit = [cmdBuf blitCommandEncoder];
    [mipBlit generateMipmapsForTexture:offscreenTexture];
    // WHITEOUT PROBE (2026-07-23): copy the 1×1 top mip (frame-average HDR
    // radiance of the RAW scene, pre-postfx) to a shared buffer, print ~1/s
    // with fps + envelope phase. Question it answers: is the scene already
    // blown at the moment of pause (constant high number), or does it CLIMB
    // after pause (something still advancing)?
    if (!lumProbeBuf)
      lumProbeBuf = [device newBufferWithLength:8
                                        options:MTLResourceStorageModeShared];
    [mipBlit copyFromTexture:offscreenTexture
                 sourceSlice:0
                 sourceLevel:offscreenTexture.mipmapLevelCount - 1
                sourceOrigin:MTLOriginMake(0, 0, 0)
                  sourceSize:MTLSizeMake(1, 1, 1)
                    toBuffer:lumProbeBuf
           destinationOffset:0
      destinationBytesPerRow:8
    destinationBytesPerImage:8];
    [mipBlit endEncoding];
    lumProbeFrames++;
    double nowP = CACurrentMediaTime();
    if (lumProbeLastPrint == 0.0) lumProbeLastPrint = nowP;
    if (nowP - lumProbeLastPrint >= 1.0) {
      // Reads last COMPLETED frame's value (one-frame lag, fine for a probe).
      const __fp16 *px = (const __fp16 *)lumProbeBuf.contents;
      printf("[LUMPROBE] avgRGB=(%.3f %.3f %.3f) fps=%.1f phase=%.2f exp=%.3f\n",
             (float)px[0], (float)px[1], (float)px[2],
             lumProbeFrames / (nowP - lumProbeLastPrint), config.envelopePhase,
             config.exposure);
      fflush(stdout);
      lumProbeFrames = 0;
      lumProbeLastPrint = nowP;
    }
  }

  // ── Multi-pass Gaussian blur via ping-pong HDR pool ───────────────
  // Foundation for real blur / future bloom / DOF / feedback. Two reused
  // HDR buffers, flipped H↔V each pass; bypassed entirely (no passes
  // encoded) when blurAmount is 0. Uniforms go via setFragmentBytes so
  // each pass gets its own values inside one command buffer.
  id<MTLTexture> postSource = offscreenTexture;
  if (blurPipeline && config.blurAmount > 0.001f && pingTexture[0] &&
      pingTexture[1]) {
    int iterations = 1 + (int)(config.blurAmount * 3.0f); // 1-4 H+V pairs
    float radius = 1.0f + config.blurAmount * 4.0f;
    struct BlurU {
      float dir[2];
      float radius;
      float pad;
    };
    id<MTLTexture> src = offscreenTexture;
    int dstIdx = 0;
    for (int it = 0; it < iterations; it++) {
      for (int axis = 0; axis < 2; axis++) {
        id<MTLTexture> dst = pingTexture[dstIdx];
        BlurU bu;
        bu.dir[0] = (axis == 0) ? (1.0f / (float)width) : 0.0f;
        bu.dir[1] = (axis == 1) ? (1.0f / (float)height) : 0.0f;
        bu.radius = radius;
        bu.pad = 0.0f;
        MTLRenderPassDescriptor *bp =
            [MTLRenderPassDescriptor renderPassDescriptor];
        bp.colorAttachments[0].texture = dst;
        bp.colorAttachments[0].loadAction = MTLLoadActionDontCare;
        bp.colorAttachments[0].storeAction = MTLStoreActionStore;
        id<MTLRenderCommandEncoder> be =
            [cmdBuf renderCommandEncoderWithDescriptor:bp];
        [be setRenderPipelineState:blurPipeline];
        [be setFragmentTexture:src atIndex:0];
        [be setFragmentBytes:&bu length:sizeof(bu) atIndex:0];
        [be drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [be endEncoding];
        src = dst;
        dstIdx ^= 1;
      }
    }
    postSource = src;
  }

  // ── HDR glow: bright-pass → MIP PYRAMID → composite ────────────────
  // Extract HDR energy above a soft knee into a half-res buffer, then build a
  // pyramid from it: halve down to the 8 px floor, then progressively upsample
  // and ACCUMULATE back up. The finished glow lands in bloomMip[0], which the
  // final post pass adds back additively. Bypassed at intensity 0.
  //
  // Replaced 2026-08-02: the old chain was 3 iterations of a 9-tap Gaussian at
  // radius 2.5 on ONE half-res buffer. Blurring at a single resolution can only
  // produce a single glow radius, which is why it read as cheap. The pyramid is
  // scale-invariant AND cheaper: 6 half-res passes before, now one pass per
  // level over a geometric series that sums to ~1.33x a single half-res pass.
  if (brightPipeline && bloomDownPipeline && bloomUpPipeline &&
      config.bloomIntensity > 0.001f && bloomLevels > 0 && bloomMip[0]) {
    // 1) Bright-pass: extract from the scene about to be shown → bloomTexture
    struct BrightU {
      float threshold;
      float softKnee;
      float pad0;
      float pad1;
    };
    BrightU bru;
    bru.threshold = 1.0f; // glow only past SDR white (HDR cores: disk/particles)
    bru.softKnee = 0.5f;
    bru.pad0 = 0.0f;
    bru.pad1 = 0.0f;
    {
      MTLRenderPassDescriptor *brp =
          [MTLRenderPassDescriptor renderPassDescriptor];
      brp.colorAttachments[0].texture = bloomTexture;
      brp.colorAttachments[0].loadAction = MTLLoadActionDontCare;
      brp.colorAttachments[0].storeAction = MTLStoreActionStore;
      id<MTLRenderCommandEncoder> bre =
          [cmdBuf renderCommandEncoderWithDescriptor:brp];
      [bre setRenderPipelineState:brightPipeline];
      [bre setFragmentTexture:postSource atIndex:0];
      [bre setFragmentBytes:&bru length:sizeof(bru) atIndex:0];
      [bre drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
      [bre endEncoding];
    }

    // 2) DOWNSAMPLE chain: mip[k-1] → mip[k], 13-tap partial box.
    // The kernel's offsets are in SOURCE texels, so the same kernel is correct
    // at every level — that self-similarity is what makes the glow
    // scale-invariant rather than one blur radius applied harder.
    struct BloomDownU {
      float srcTexel[2];
      float pad[2];
    };
    for (int k = 1; k < bloomLevels; k++) {
      id<MTLTexture> src = bloomMip[k - 1];
      id<MTLTexture> dst = bloomMip[k];
      if (!src || !dst)
        break;
      BloomDownU du;
      du.srcTexel[0] = 1.0f / (float)src.width;
      du.srcTexel[1] = 1.0f / (float)src.height;
      du.pad[0] = 0.0f;
      du.pad[1] = 0.0f;
      MTLRenderPassDescriptor *dp =
          [MTLRenderPassDescriptor renderPassDescriptor];
      dp.colorAttachments[0].texture = dst;
      dp.colorAttachments[0].loadAction = MTLLoadActionDontCare; // full write
      dp.colorAttachments[0].storeAction = MTLStoreActionStore;
      id<MTLRenderCommandEncoder> de =
          [cmdBuf renderCommandEncoderWithDescriptor:dp];
      [de setRenderPipelineState:bloomDownPipeline];
      [de setFragmentTexture:src atIndex:0];
      [de setFragmentBytes:&du length:sizeof(du) atIndex:0];
      [de drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
      [de endEncoding];
    }

    // 3) UPSAMPLE chain: mip[k] → mip[k-1], 3x3 tent, ADDITIVELY blended.
    // loadAction MUST be Load here — the destination already holds its own
    // downsampled content, and the sum of the levels IS the finished glow.
    // filterRadius = one SOURCE texel: the tent then spans exactly the
    // destination neighbourhood that source texel covers, so levels tile.
    struct BloomUpU {
      float filterRadius[2];
      float pad[2];
    };
    for (int k = bloomLevels - 1; k >= 1; k--) {
      id<MTLTexture> src = bloomMip[k];
      id<MTLTexture> dst = bloomMip[k - 1];
      if (!src || !dst)
        continue;
      BloomUpU uu;
      uu.filterRadius[0] = 1.0f / (float)src.width;
      uu.filterRadius[1] = 1.0f / (float)src.height;
      uu.pad[0] = 0.0f;
      uu.pad[1] = 0.0f;
      MTLRenderPassDescriptor *up =
          [MTLRenderPassDescriptor renderPassDescriptor];
      up.colorAttachments[0].texture = dst;
      up.colorAttachments[0].loadAction = MTLLoadActionLoad; // accumulate
      up.colorAttachments[0].storeAction = MTLStoreActionStore;
      id<MTLRenderCommandEncoder> ue =
          [cmdBuf renderCommandEncoderWithDescriptor:up];
      [ue setRenderPipelineState:bloomUpPipeline];
      [ue setFragmentTexture:src atIndex:0];
      [ue setFragmentBytes:&uu length:sizeof(uu) atIndex:0];
      [ue drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
      [ue endEncoding];
    }
  }

  // ── Second Pass: Post-FX to drawable ──────────────────────────────
  MTLRenderPassDescriptor *finalPass =
      [MTLRenderPassDescriptor renderPassDescriptor];
  finalPass.colorAttachments[0].texture = drawable.texture;
  finalPass.colorAttachments[0].loadAction = MTLLoadActionClear;
  finalPass.colorAttachments[0].storeAction = MTLStoreActionStore;
  finalPass.colorAttachments[0].clearColor =
      MTLClearColorMake(0.04, 0.04, 0.06, 1.0);

  // Prepare Post-FX Uniforms
  PostFXUniforms post = {};
  post.resolution[0] = (float)width;
  post.resolution[1] = (float)height;
  post.bloomIntensity = config.bloomIntensity;
  post.trailDecay = config.trailDecay;
  post.chromaticAmount = config.chromaticAmount;
  post.time = config.fxTime;
  post.glitchAmount = config.glitchAmount;
  post.neonGrade = config.neonGrade;
  post.vignette = config.vignette;
  post.audioLevel = config.audioLevel;
  post.mirrorMode = config.mirrorMode;
  post.kaleidoSegments = config.kaleidoSegments;
  post.tileCount = config.tileCount;
  post.twirl = config.twirl;
  post.hueShift = config.hueShift;
  post.strobe = config.strobe;
  post.invert = config.invert;
  post.posterize = config.posterize;
  // ── 2026-08-20: this dial is now the SHUTTER on a real motion smear ───────
  // It used to be a spin effect. postfx.metal now smears along the motion the
  // star pass measured, so what should open the shutter is matter being in
  // orbit — bhStrength, the renderer's own smoothed collapse signal (:241),
  // the same one the hole pass gates on. Spin still drives it too, so the
  // no-hole case is unchanged. max() so neither can silently disable the other.
  post.pixelStretch =
      std::min(1.0f, std::max(config.pixelStretch, bhStrength));
  post.exposure = config.exposure; // global iris — scales the HDR scene pre-tonemap
  post.debugBypass = config.debugBypassPostFX ? 1.0f
                     : (config.debugNoBleach ? 2.0f : 0.0f); // mode: B bypass / N no-bleach
  post.gradeAmount = config.gradeAmount; // display grade LUT blend (0 = exact bypass)
  // ── COVERAGE RESOLVE (2026-08-11, board §H9) — his call, path A ──────────
  // Default ON. SS_NO_COVERAGE=1 restores the pure-additive image byte for
  // byte, so the A/B is one relaunch and needs no rebuild.
  static const bool kNoCoverage = (getenv("SS_NO_COVERAGE") != nullptr);
  post.coverageResolve = kNoCoverage ? 0.0f : 1.0f;
  post.smearShutter = config.smearShutter;
  post.smearHold = config.smearHold;
  // EDR headroom: how far above SDR white this display can currently go
  // (1.0 on SDR panels, up to ~16 on XDR depending on brightness/state).
  // Drives how hard the HDR glow punches past white. Queried live because it
  // shifts with display brightness and battery state.
  {
    NSScreen *scr = [NSScreen mainScreen];
    float headroom = 1.0f;
    if (scr) {
      headroom = (float)scr.maximumExtendedDynamicRangeColorComponentValue;
      if (headroom < 1.0f) headroom = 1.0f;
      if (headroom > 4.0f) headroom = 4.0f; // cap: 4× over white is plenty,
                                            // raw XDR (16×) would sear the eyes
    }
    post.edrHeadroom = headroom;
  }

  // Analytic Motion Blur: Inverse current matrix
  CameraUniforms *camStruct = (CameraUniforms *)cameraBuffer[frameIdx].contents;
  invertMatrix4x4(camStruct->viewProj, post.inverseViewProj);
  memcpy(post.prevViewProj, prevViewProj, 16 * sizeof(float));

  memcpy(postUniformBuffer[frameIdx].contents, &post, sizeof(post));

  // Store the current frame's matrix for next frame's Motion Blur calculation
  memcpy(prevViewProj, camStruct->viewProj, 16 * sizeof(float));

  // Prepare ImGui for this pass
  ImGui_ImplMetal_NewFrame(finalPass);

  id<MTLRenderCommandEncoder> postEnc =
      [cmdBuf renderCommandEncoderWithDescriptor:finalPass];
  if (postPipeline) {
    [postEnc setRenderPipelineState:postPipeline];
    [postEnc setFragmentTexture:postSource atIndex:0];
    [postEnc setFragmentTexture:prevFrameTexture atIndex:1];
    [postEnc setFragmentTexture:bloomTexture atIndex:2]; // HDR glow
    [postEnc setFragmentTexture:offscreenTexture atIndex:3]; // auto-exposure avg (top mip)
    [postEnc setFragmentTexture:gradeLutTexture atIndex:4];  // display grade LUT (33^3)
    [postEnc setFragmentTexture:velocityTexture atIndex:5];  // motion vectors → the smear
    [postEnc setFragmentBuffer:postUniformBuffer[frameIdx] offset:0 atIndex:0];
    [postEnc drawPrimitives:MTLPrimitiveTypeTriangle
                vertexStart:0
                vertexCount:3];
  }
  [postEnc endEncoding];   // end BEFORE the UI — keep the render clean

#if HAS_SYPHON
  // ── Dedicated SDR Syphon pass ───────────────────────────────────────────
  // The screen drawable is EDR (values >1.0 → vibrant on the HDR panel), but
  // Resolume/Arena are SDR and clamp >1.0 to flat white. Re-run the SAME
  // hue-preserving tonemap with the headroom forced to 1.0, so it compresses
  // into [0,1] keeping COLOUR at brightness (vibrant SDR, not blown white) and
  // computes the alpha key. Publish THIS, not the EDR drawable. Reads the same
  // last-frame prevFrameTexture as the screen pass → run BEFORE the blit below.
  // Only when someone is actually listening: with no Syphon client connected
  // this whole SDR re-tonemap pass + publish was pure waste every frame
  // (~0.25ms measured 2026-07-07). hasClients flips the moment Resolume/Arena
  // connects, so the feed appears on the next frame — nothing to configure.
  bool syphonLive = (syphonServer != nil) && syphonServer.hasClients;
  if (syphonLive && syphonTexture && postPipeline) {
    PostFXUniforms postSdr = post;
    postSdr.edrHeadroom = 1.0f;            // SDR: no headroom above white
    memcpy(postUniformSyphonBuffer[frameIdx].contents, &postSdr, sizeof(postSdr));
    MTLRenderPassDescriptor *syPass = [MTLRenderPassDescriptor renderPassDescriptor];
    syPass.colorAttachments[0].texture = syphonTexture;
    syPass.colorAttachments[0].loadAction = MTLLoadActionDontCare;
    syPass.colorAttachments[0].storeAction = MTLStoreActionStore;
    id<MTLRenderCommandEncoder> syEnc =
        [cmdBuf renderCommandEncoderWithDescriptor:syPass];
    [syEnc setRenderPipelineState:postPipeline];
    [syEnc setFragmentTexture:postSource atIndex:0];
    [syEnc setFragmentTexture:prevFrameTexture atIndex:1];
    [syEnc setFragmentTexture:bloomTexture atIndex:2];
    [syEnc setFragmentTexture:velocityTexture atIndex:5];  // motion vectors → the smear
    [syEnc setFragmentTexture:gradeLutTexture atIndex:4]; // same grade on the feed as on screen
    [syEnc setFragmentBuffer:postUniformSyphonBuffer[frameIdx] offset:0 atIndex:0];
    [syEnc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [syEnc endEncoding];
  }
#endif

  // ── Copy the CLEAN render (no UI) to prevFrameTexture for trails ───
  id<MTLBlitCommandEncoder> blit = [cmdBuf blitCommandEncoder];
  [blit copyFromTexture:drawable.texture toTexture:prevFrameTexture];
  [blit endEncoding];

#if HAS_SYPHON
  // Publish the dedicated SDR feed (vibrant, alpha-keyed, no UI) to Syphon.
  if (syphonLive && syphonTexture) {
    [syphonServer publishFrameTexture:syphonTexture
                      onCommandBuffer:cmdBuf
                          imageRegion:NSMakeRect(0, 0, width, height)
                              flipped:YES];  // plain render target is top-left origin
  }
#endif

  // ── UI pass ───────────────────────────────────────────────────────────────
  // ImGui::Render() must run EXACTLY ONCE per frame whatever happens below,
  // or ImGui's frame state desyncs and the next NewFrame asserts.
  ImGui::Render();

  // TWO-WINDOW MODE is a Syphon-build feature: `uiLayer` is declared inside
  // `#if HAS_SYPHON` (:46) but was USED here unguarded, so a build without
  // Syphon failed with three `undeclared identifier 'uiLayer'` errors instead of
  // simply losing the feature. That bites every fresh `git worktree add`,
  // because `third_party/syphon/` is GITIGNORED and never comes with the tree
  // (found 2026-08-29 creating SPACE-SYNTH-TRUE-PHYSICS). Behaviour with Syphon
  // present is unchanged: this alias IS `uiLayer`. Without it, nil selects the
  // single-window branch below, which is the correct degrade.
#if HAS_SYPHON
  CAMetalLayer *uiLayerOrNil = uiLayer;
#else
  CAMetalLayer *uiLayerOrNil = nil;
#endif
  id<CAMetalDrawable> uiDrawable = nil;
  if (uiLayerOrNil) {
    // TWO-WINDOW MODE: the panels go to the settings window and the output
    // drawable is left completely clean.
    uiDrawable = [uiLayerOrNil nextDrawable];
    if (uiDrawable) {
      MTLRenderPassDescriptor *uiPass =
          [MTLRenderPassDescriptor renderPassDescriptor];
      uiPass.colorAttachments[0].texture = uiDrawable.texture;
      uiPass.colorAttachments[0].loadAction = MTLLoadActionClear; // own window
      uiPass.colorAttachments[0].clearColor =
          MTLClearColorMake(0.045, 0.05, 0.065, 1.0);
      uiPass.colorAttachments[0].storeAction = MTLStoreActionStore;
      id<MTLRenderCommandEncoder> uiEnc =
          [cmdBuf renderCommandEncoderWithDescriptor:uiPass];
      ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), cmdBuf, uiEnc);
      [uiEnc endEncoding];
    }
    // If nextDrawable returned nil (window hidden/minimised) we simply skip the
    // encode. The frame is still valid — the draw data is just dropped.
  } else {
    // SINGLE WINDOW: unchanged — draw the menu over the clean render.
    MTLRenderPassDescriptor *uiPass =
        [MTLRenderPassDescriptor renderPassDescriptor];
    uiPass.colorAttachments[0].texture = drawable.texture;
    uiPass.colorAttachments[0].loadAction = MTLLoadActionLoad; // keep the render
    uiPass.colorAttachments[0].storeAction = MTLStoreActionStore;
    id<MTLRenderCommandEncoder> uiEnc =
        [cmdBuf renderCommandEncoderWithDescriptor:uiPass];
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), cmdBuf, uiEnc);
    [uiEnc endEncoding];
  }

  if (uiDrawable)
    [cmdBuf presentDrawable:uiDrawable];
  [cmdBuf presentDrawable:drawable];
  [cmdBuf commit];

  currentFrame = (currentFrame + 1) % kMaxInFlightFrames;
}

void Renderer::setUILayer(void *metalLayer) {
#if HAS_SYPHON
  impl_->uiLayer = (__bridge CAMetalLayer *)metalLayer;
#else
  (void)metalLayer;   // two-window mode requires the Syphon build
#endif
}

void Renderer::renderImGui(void *renderEncoder) {
  ImGui::Render();
  ImGui_ImplMetal_RenderDrawData(
      ImGui::GetDrawData(),
      nil, // commandBuffer is not used directly by the current implementation
      (__bridge id<MTLRenderCommandEncoder>)renderEncoder);
}

int Renderer::particleCount() const { return impl_->particleCount; }

void Renderer::setActiveParticleCount(int count) {
  if (!impl_->particleBuffer)
    return;
  int maxCount = (int)(impl_->particleBuffer.length / sizeof(GPUParticle));
  impl_->particleCount = std::max(0, std::min(count, maxCount));
}

void *Renderer::getMetalDevice() const {
  return (__bridge void *)impl_->device;
}

void Renderer::resize(int width, int height) {
  // width/height MUST BE physical (backing) pixels
  if (width <= 0 || height <= 0)
    return;

  impl_->width = width;
  impl_->height = height;

  MTLTextureDescriptor *depthDesc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                   width:width
                                  height:height
                               mipmapped:NO];
  depthDesc.storageMode = MTLStorageModePrivate;
  depthDesc.usage = MTLTextureUsageRenderTarget;
  impl_->depthTexture = [impl_->device newTextureWithDescriptor:depthDesc];

  // ── DEPTH PRE-PASS target (2026-08-11, P1 step 1) ────────────────────────
  // Same format/size, but usage adds ShaderRead: unlike depthTexture (which is
  // RenderTarget-only and thrown away with storeAction=DontCare) this one is
  // STORED so a later stage can sample it. That readability is the entire
  // point — it is what C4a needs to stop faking depth at z=0.99, and what C4b
  // needs to exist at all.
  MTLTextureDescriptor *dpTexDesc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                   width:width
                                  height:height
                               mipmapped:NO];
  dpTexDesc.storageMode = MTLStorageModePrivate;
  dpTexDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
  impl_->depthPrepassTexture =
      [impl_->device newTextureWithDescriptor:dpTexDesc];

  // ── Offscreen texture: HDR (RGBA16Float) for physics-accurate lighting ──
  // MIPMAPPED (2026-07-16, auto-exposure): the top mip = the scene's average
  // colour; the postfx tonemap reads it to adapt the iris (stop-down only) so
  // the queued matter at the hole shows fire structure instead of clipping to
  // white paste (Jamal: "still this blob thing", "hdr peaks limit").
  MTLTextureDescriptor *hdrDesc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                   width:width
                                  height:height
                               mipmapped:YES];
  hdrDesc.storageMode = MTLStorageModePrivate;
  hdrDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
  impl_->offscreenTexture = [impl_->device newTextureWithDescriptor:hdrDesc];

  // ── MOTION VECTORS (2026-08-20) — attachment 1 of the scene pass ──────────
  // RG16Float: a SIGNED UV delta per pixel, so it needs the sign bit and
  // sub-pixel precision. Two channels is all a screen direction has.
  MTLTextureDescriptor *velDesc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatRG16Float
                                   width:width
                                  height:height
                               mipmapped:NO];
  velDesc.storageMode = MTLStorageModePrivate;
  velDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
  impl_->velocityTexture = [impl_->device newTextureWithDescriptor:velDesc];
  // (pool/bloom/feedback textures below stay non-mipmapped — hdrDesc is
  // re-declared for them.)
  hdrDesc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                   width:width
                                  height:height
                               mipmapped:NO];
  hdrDesc.storageMode = MTLStorageModePrivate;
  hdrDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
#if HAS_SYPHON
  // Dedicated SDR-tonemapped texture for the Syphon feed (same format, separate
  // target so the screen stays EDR while the feed is vibrant-SDR).
  impl_->syphonTexture = [impl_->device newTextureWithDescriptor:hdrDesc];
#endif

  // Ping-pong HDR pool (two reused buffers for multi-pass effects)
  impl_->pingTexture[0] = [impl_->device newTextureWithDescriptor:hdrDesc];
  impl_->pingTexture[1] = [impl_->device newTextureWithDescriptor:hdrDesc];
  // HDR glow: a MIP PYRAMID, not one buffer. Level 0 is half-res (bloom is
  // low-frequency, so half-res is invisible and every tap covers twice the
  // screen distance for free); each level halves again.
  //
  // The LEVEL COUNT IS DERIVED FROM THE RESOLUTION, never hardcoded: keep
  // halving while the smaller dimension stays >= 8 px. Below 8 px the 13-tap
  // downsample kernel (±2 texels) is mostly clamped against the edges, so the
  // level stops carrying real information — that 8 is the kernel's own reach,
  // not a taste choice. At 2560x1440 this yields 7 levels, the widest spanning
  // the full frame; the pyramid therefore covers every scale the display has.
  {
    int bw = width / 2 > 0 ? width / 2 : 1;
    int bh = height / 2 > 0 ? height / 2 : 1;
    impl_->bloomLevels = 0;
    for (int k = 0; k < Impl::kBloomMaxLevels; k++) {
      int lw = bw >> k;
      int lh = bh >> k;
      if (k > 0 && (lw < 8 || lh < 8))
        break;
      MTLTextureDescriptor *bloomDesc = [MTLTextureDescriptor
          texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                       width:(NSUInteger)(lw > 0 ? lw : 1)
                                      height:(NSUInteger)(lh > 0 ? lh : 1)
                                   mipmapped:NO];
      bloomDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
      impl_->bloomMip[k] = [impl_->device newTextureWithDescriptor:bloomDesc];
      impl_->bloomLevels = k + 1;
    }
    // Level 0 stays the texture bound at texture(2) by the composite passes.
    impl_->bloomTexture = impl_->bloomMip[0];
    NSLog(@"[BLOOM-PYRAMID] %d levels from %dx%d (floor 8px)",
          impl_->bloomLevels, bw, bh);
  }

  // Feedback texture must match the EDR drawable (RGBA16Float) — it's a
  // blit-copy of the drawable each frame, so trails keep their HDR highlights.
  MTLTextureDescriptor *colorDesc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                   width:width
                                  height:height
                               mipmapped:NO];
  colorDesc.storageMode = MTLStorageModePrivate;
  colorDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
  impl_->prevFrameTexture = [impl_->device newTextureWithDescriptor:colorDesc];
}

void Renderer::setCollisionsEnabled(bool enabled) {
  impl_->collisionsEnabled = enabled;
}

bool Renderer::collisionsEnabled() const { return impl_->collisionsEnabled; }

void Renderer::setBondNetworkEnabled(bool enabled) {
  impl_->bondNetworkEnabled = enabled;
}

bool Renderer::bondNetworkEnabled() const { return impl_->bondNetworkEnabled; }

void Renderer::setEnvelopeState(float phase, float progress, float intensity) {
  impl_->envPhase = phase;
  impl_->envProgress = progress;
  impl_->envIntensity = intensity;
}

void Renderer::setDiskThickness(float t) { impl_->diskThicknessVal = t; }

void Renderer::setSpin(float x, float y) {
  impl_->spinXVal = x;
  impl_->spinYVal = y;
}

PhysicsStats Renderer::getPhysicsStats() const { return impl_->latestStats; }

void Renderer::readbackParticles(GPUParticle *out, int count) {
  if (!impl_->particleBuffer)
    return;
  size_t sz = std::min((size_t)count * sizeof(GPUParticle),
                       (size_t)impl_->particleBuffer.length);
  memcpy(out, impl_->particleBuffer.contents, sz);
}

void Renderer::orthoMatrix(float *m, float l, float r, float b, float t,
                           float n, float f) {
  memset(m, 0, 16 * sizeof(float));
  m[0] = 2.0f / (r - l);
  m[5] = 2.0f / (t - b);
  m[10] = -1.0f / (f - n);
  m[12] = -(r + l) / (r - l);
  m[13] = -(t + b) / (t - b);
  m[14] = -n / (f - n);
  m[15] = 1.0f;
}

void Renderer::perspectiveMatrix(float *m, float fovY, float aspect, float n,
                                 float f) {
  memset(m, 0, 16 * sizeof(float));
  float h = 1.0f / tan(fovY * 0.5f);
  float w = h / aspect;
  m[0] = w;
  m[5] = h;
  m[10] = f / (f - n);
  m[11] = 1.0f;
  m[14] = -n * f / (f - n);
}

bool Renderer::invertMatrix4x4(const float *m, float *invOut) {
  float inv[16], det;

  inv[0] = m[5] * m[10] * m[15] - m[5] * m[11] * m[14] - m[9] * m[6] * m[15] +
           m[9] * m[7] * m[14] + m[13] * m[6] * m[11] - m[13] * m[7] * m[10];
  inv[4] = -m[4] * m[10] * m[15] + m[4] * m[11] * m[14] + m[8] * m[6] * m[15] -
           m[8] * m[7] * m[14] - m[12] * m[6] * m[11] + m[12] * m[7] * m[10];
  inv[8] = m[4] * m[9] * m[15] - m[4] * m[11] * m[13] - m[8] * m[5] * m[15] +
           m[8] * m[7] * m[13] + m[12] * m[5] * m[11] - m[12] * m[7] * m[9];
  inv[12] = -m[4] * m[9] * m[14] + m[4] * m[10] * m[13] + m[8] * m[5] * m[14] -
            m[8] * m[6] * m[13] - m[12] * m[5] * m[10] + m[12] * m[6] * m[9];
  inv[1] = -m[1] * m[10] * m[15] + m[1] * m[11] * m[14] + m[9] * m[2] * m[15] -
           m[9] * m[3] * m[14] - m[13] * m[2] * m[11] + m[13] * m[3] * m[10];
  inv[5] = m[0] * m[10] * m[15] - m[0] * m[11] * m[14] - m[8] * m[2] * m[15] +
           m[8] * m[3] * m[14] + m[12] * m[2] * m[11] - m[12] * m[3] * m[10];
  inv[9] = -m[0] * m[9] * m[15] + m[0] * m[11] * m[13] + m[8] * m[1] * m[15] -
           m[8] * m[3] * m[13] - m[12] * m[1] * m[11] + m[12] * m[3] * m[9];
  inv[13] = m[0] * m[9] * m[14] - m[0] * m[10] * m[13] - m[8] * m[1] * m[14] +
            m[8] * m[2] * m[13] + m[12] * m[1] * m[10] - m[12] * m[2] * m[9];
  inv[2] = m[1] * m[6] * m[15] - m[1] * m[7] * m[14] - m[5] * m[2] * m[15] +
           m[5] * m[3] * m[14] + m[13] * m[2] * m[7] - m[13] * m[3] * m[6];
  inv[6] = -m[0] * m[6] * m[15] + m[0] * m[7] * m[14] + m[4] * m[2] * m[15] -
           m[4] * m[3] * m[14] - m[12] * m[2] * m[7] + m[12] * m[3] * m[6];
  inv[10] = m[0] * m[5] * m[15] - m[0] * m[7] * m[13] - m[4] * m[1] * m[15] +
            m[4] * m[3] * m[13] + m[12] * m[1] * m[7] - m[12] * m[3] * m[5];
  inv[14] = -m[0] * m[5] * m[14] + m[0] * m[6] * m[13] + m[4] * m[1] * m[14] -
            m[4] * m[2] * m[13] - m[12] * m[1] * m[6] + m[12] * m[2] * m[5];
  inv[3] = -m[1] * m[6] * m[11] + m[1] * m[7] * m[10] + m[5] * m[2] * m[11] -
           m[5] * m[3] * m[10] - m[9] * m[2] * m[7] + m[9] * m[3] * m[6];
  inv[7] = m[0] * m[6] * m[11] - m[0] * m[7] * m[10] - m[4] * m[2] * m[11] +
           m[4] * m[3] * m[10] + m[8] * m[2] * m[7] - m[8] * m[3] * m[6];
  inv[11] = -m[0] * m[5] * m[11] + m[0] * m[7] * m[9] + m[4] * m[1] * m[11] -
            m[4] * m[3] * m[9] - m[8] * m[1] * m[7] + m[8] * m[3] * m[5];
  inv[15] = m[0] * m[5] * m[10] - m[0] * m[6] * m[9] - m[4] * m[1] * m[10] +
            m[4] * m[2] * m[9] + m[8] * m[1] * m[6] - m[8] * m[2] * m[5];

  det = m[0] * inv[0] + m[1] * inv[4] + m[2] * inv[8] + m[3] * inv[12];
  if (det == 0)
    return false;

  det = 1.0f / det;
  for (int i = 0; i < 16; i++) {
    invOut[i] = inv[i] * det;
  }
  return true;
}

} // namespace space
