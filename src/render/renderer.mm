#include "renderer.h"
#include "core/imf.h"
#include "core/units.h"
#include "spacetime/spacetime.h"  // thermodynamics: kUFloorSim (SPH internal energy floor)
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
#include <cstring>
#include <simd/simd.h>
#include <mach/mach_time.h>
#include <mach/mach.h>

namespace space {

struct Renderer::Impl {
  id<MTLDevice> device;
  id<MTLCommandQueue> commandQueue;        // For rendering
  id<MTLCommandQueue> computeCommandQueue; // For async physics
#if HAS_SYPHON
  SyphonMetalServer *syphonServer = nil;   // live video out (Resolume/Arena etc.)
  id<MTLTexture> syphonTexture = nil;      // dedicated SDR-tonemapped feed (vibrant in SDR)
#endif
  id<MTLEvent> frameEvent;                 // Synchronization fence
  uint64_t frameEventValue;                // Fence ticket

  id<MTLLibrary> library = nil;

  id<MTLComputePipelineState> physicsPipeline = nil;
  id<MTLRenderPipelineState> particlePipeline = nil;
  id<MTLRenderPipelineState> trajectoryPipeline = nil; // scope-line beams
  id<MTLRenderPipelineState> postPipeline = nil;
  // Ping-pong HDR pool for multi-pass effects (blur/echo/feedback)
  id<MTLRenderPipelineState> blurPipeline = nil;
  id<MTLTexture> pingTexture[2] = {nil, nil};
  // HDR glow (bloom): bright-pass extraction → ping-pong blur → composite.
  // Two dedicated half-res HDR buffers so the glow's own blur never collides
  // with the user-facing blur slider's ping-pong pool.
  id<MTLRenderPipelineState> brightPipeline = nil;
  id<MTLTexture> bloomTexture = nil;  // finished glow, bound at texture(2)
  id<MTLTexture> bloomScratch = nil;  // ping-pong partner for the glow blur

  // Spatial hash pipelines
  id<MTLComputePipelineState> assignCellsPipeline = nil;
  id<MTLComputePipelineState> countCellsPipeline = nil;
  id<MTLComputePipelineState> prefixSumLocalPipeline = nil;
  id<MTLComputePipelineState> prefixSumBlocksPipeline = nil;
  id<MTLComputePipelineState> prefixSumAddPipeline = nil;
  id<MTLComputePipelineState> scatterPipeline = nil;
  id<MTLComputePipelineState> centroidPipeline = nil; // per-cell centroid (cohesion)
  id<MTLComputePipelineState> poissonPipeline = nil;  // PM gravity: red-black SOR Poisson sweep
  id<MTLComputePipelineState> sphDensityPipeline = nil; // SPH ρ per particle (reaction engine slice 1)
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
  id<MTLBuffer> cellIndicesBuffer = nil;     // cell ID per particle
  id<MTLBuffer> cellCountsBuffer = nil;      // count per cell
  id<MTLBuffer> cellMassBuffer = nil;        // Σ stellar mass per cell (M_sun ×64, atomic)
  id<MTLBuffer> seedCountBuffer = nil;       // BH-seed registry counter (atomic, per frame)
  id<MTLBuffer> seedIdsBuffer = nil;         // BH-seed particle ids (≤256)
  id<MTLBuffer> cellSeedMapBuffer = nil;     // per-cell seed slot (victim lookup)
  id<MTLBuffer> seedAccumBuffer = nil;       // per-seed meal accumulator (4 uints)
  id<MTLBuffer> accDiagBuffer = nil;         // [0]=max accuracy ratio ×1000 (Step 2 measurement, diagnostic)
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
  float bhMassEnc = 0.0f;     // stars (M_sun) within R_ENC of the peak
  float bhSeedMass = 0.0f;    // mass of the biggest body = the accreted BH (conserved, monotonic)
  float lastHorizonR = 0.0f;  // honest geometric horizon r_h [sim] from the radial profile (1-frame lag)
  float lastDt = 1.0f / 120.0f; // previous frame's dt for time-corrected Verlet (init = spawn kDt → frame-1 correct)
  float lastParticleSize = 2.0f; // Size slider (1-frame lag) → scales the cluster's mass/gravity
  float bhStrength = 0.0f;    // collapse-fraction signal, smoothed+latched
  float bhStrengthEma = 0.0f; // eased raw signal (anti-flicker)
  bool bhFormedLatch = false; // once formed, stays formed (until reset)
  bool bhPosed = false;       // analytic BH pose active → spin the posed disk
  double bhPoseTime = 0.0;    // elapsed seconds since pose (render-clock driven)
  double bhPoseClock = 0.0;   // last render timestamp, for the pose dt
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
#if HAS_SYPHON
  id<MTLBuffer> postUniformSyphonBuffer[kMaxInFlightFrames]; // SDR uniform (headroom=1)
#endif

  id<MTLDepthStencilState> depthState = nil;
  id<MTLDepthStencilState> bgDepthState = nil;
  id<MTLTexture> depthTexture = nil;
  id<MTLTexture> offscreenTexture = nil;
  id<MTLTexture> prevFrameTexture = nil;

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

  // ── Spatial hash compute pipelines ──────────────────────────────────
  const char *spatialKernels[] = {"assign_cells",     "count_cells",
                                  "prefix_sum_local", "prefix_sum_blocks",
                                  "prefix_sum_add",   "scatter_particles",
                                  "compute_cell_centroids"};
  id<MTLComputePipelineState> *spatialPipelines[] = {
      &impl_->assignCellsPipeline,    &impl_->countCellsPipeline,
      &impl_->prefixSumLocalPipeline, &impl_->prefixSumBlocksPipeline,
      &impl_->prefixSumAddPipeline,   &impl_->scatterPipeline,
      &impl_->centroidPipeline};
  for (int i = 0; i < 7; i++) {
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
  } else {
    NSLog(@"Missing shader functions: vertex=%@, fragment=%@", vertexFunc,
          fragmentFunc);
  }

  // ── Trajectory (oscilloscope scope-line) pipeline ───────────────────
  // ISOLATED additive LINE pipeline, drawn AFTER the points so it can never
  // break the particle render. Crisp 1px beams (Metal line primitive), same
  // HDR format + additive blend as the particles.
  {
    id<MTLFunction> trajVertexFunc =
        [impl_->library newFunctionWithName:@"trajectory_vertex"];
    id<MTLFunction> trajFragmentFunc =
        [impl_->library newFunctionWithName:@"trajectory_fragment"];
    if (trajVertexFunc && trajFragmentFunc) {
      MTLRenderPipelineDescriptor *desc =
          [[MTLRenderPipelineDescriptor alloc] init];
      desc.vertexFunction = trajVertexFunc;
      desc.fragmentFunction = trajFragmentFunc;
      desc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float; // HDR
      desc.colorAttachments[0].blendingEnabled = YES;
      desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
      desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
      desc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
      desc.colorAttachments[0].destinationAlphaBlendFactor =
          MTLBlendFactorOneMinusSourceAlpha;
      desc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
      impl_->trajectoryPipeline =
          [impl_->device newRenderPipelineStateWithDescriptor:desc
                                                        error:&error];
      if (error)
        NSLog(@"Trajectory pipeline error: %@", error);
    } else {
      NSLog(@"Missing trajectory shader functions: vertex=%@, fragment=%@",
            trajVertexFunc, trajFragmentFunc);
    }
  }

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
  allocIfNeeded(impl_->densityBuffer, count * sizeof(float));  // SPH ρ per particle (slice 0 plumbing)
  allocIfNeeded(impl_->mergeClaimBuffer, count * sizeof(uint32_t)); // cross-cell merge claims
  allocIfNeeded(impl_->pressureBuffer, count * sizeof(float)); // SPH P per particle (slice 0 plumbing)
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
  allocIfNeeded(impl_->seedIdsBuffer, 256 * sizeof(uint32_t));
  allocIfNeeded(impl_->cellSeedMapBuffer, cellSize);
  allocIfNeeded(impl_->seedAccumBuffer, 256 * 4 * sizeof(uint32_t));
  allocIfNeeded(impl_->accDiagBuffer, 2 * sizeof(uint32_t)); // [0]=max accuracy ratio ×1e6, [1]=over-budget count
  allocIfNeeded(impl_->sphClosureBuffer, 8 * sizeof(int32_t)); // TEMP-CLOSURE window ledger (+poison count)
  allocIfNeeded(impl_->cellStartsBuffer, cellSize);
  size_t blockSumsSize = ((Impl::kTotalCells + 2047) / 2048) * sizeof(uint32_t);
  allocIfNeeded(impl_->blockSumsBuffer, blockSumsSize);
  allocIfNeeded(impl_->cellOffsetsBuffer, cellSize);
  allocIfNeeded(impl_->sortedParticlesBuffer, size);
  allocIfNeeded(impl_->cellCentroidsBuffer, Impl::kTotalCells * 16); // float4/cell
  allocIfNeeded(impl_->cellVelocitiesBuffer, Impl::kTotalCells * 16); // float4/cell
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
  dt = 0.0165f;
  impl_->physicsUniforms.dt = dt;
  impl_->physicsUniforms.dtPrev = 0.0165f; // tcv = dt/dtPrev = 1 exactly (fixed step)
  impl_->lastDt = dt;
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
  accumulatedTime += dt;
  impl_->physicsUniforms.time = accumulatedTime;

  impl_->hasCompute = true;
}

void Renderer::render(const RenderConfig &config) {
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

  // 1. Create a dedicated Async Compute Command Buffer
  id<MTLCommandBuffer> computeCmdBuf =
      [impl_->computeCommandQueue commandBuffer];
  impl_->runComputePass(computeCmdBuf, frameIdx);

  // Signal an event when compute for this frame finishes
  impl_->frameEventValue++;
  uint64_t computeFinishedTicket = impl_->frameEventValue;
  [computeCmdBuf encodeSignalEvent:impl_->frameEvent
                             value:computeFinishedTicket];
  [computeCmdBuf commit];

  // 2. Create the standard Render Command Buffer
  id<MTLCommandBuffer> renderCmdBuf = [impl_->commandQueue commandBuffer];

  __block dispatch_semaphore_t block_sema = impl_->inFlightSemaphore;
  [renderCmdBuf addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
    dispatch_semaphore_signal(block_sema);
  }];

  // Wait for compute to finish BEFORE we rasterize those exact particles
  [renderCmdBuf encodeWaitForEvent:impl_->frameEvent
                             value:computeFinishedTicket];

  // ── Camera ──────────────────────────────────────────────────────────
  float R = config.plateRadius;
  float aspect = (float)impl_->width / (float)impl_->height;
  float halfH = R * 1.3f;
  float halfW = halfH * aspect;

  CameraUniforms cam = {};
  orthoMatrix(cam.viewProj, -halfW, halfW, -halfH, halfH, -R * 3.0f, R * 3.0f);
  cam.cameraPos[0] = 0;
  cam.cameraPos[1] = R;
  cam.cameraPos[2] = 0;
  cam.cameraPad = config.cameraRho;
  cam.particleSize = config.particleSize;
  cam.plateRadius = R;
  cam.phaseViz = config.phaseViz ? 1.0f : 0.0f;
  cam.waveDepth = config.modeP * 20.0f; // Using modeP to scale depth
  cam.envelopePhase = impl_->renderPhaseSmooth; // smoothed (render-only)
  cam.envelopeProgress = config.envelopeProgress;
  cam.orthoMode = config.orthoMode ? 1.0f : 0.0f;
  {
    float frustum = config.cameraRho * 1.2f;
    // PHYSICAL Einstein radius: the lens ring derives from the HOLE'S REAL
    // MASS (photon capture b = 2.6·r_s(M_core)), not an arbitrary UI size —
    // that mismatch made the lens sphere and the physical disk read as two
    // layered bodies. "BH Size" is now a ×multiplier (default 1 = physics):
    // the lens grows as the hole eats, always matching the disk it carved.
    float bSim = 2.6f * (float)space::units::kRsSimPerMsun *
                 std::max(impl_->bhSeedMass, 0.0f) *   // accreted BH mass (stable, monotonic)
                 config.shadowRadius;
    // LENS OFF DURING PLAY: the BH gravitational lens warps the whole field
    // toward screen-center (the "squeeze to the middle / eckig, not fluid"
    // distortion + bright center dot). No hole while a note sounds → no lens.
    // Returns at rest. The center pull was a RENDER lens, not a physics force
    // (the log showed 99.9% of mass is OUT of the core during play). Jamal 2026-06-14.
    bool bhLensActive = (impl_->physicsUniforms.totalAmplitude < 0.02f);
    cam.bhShadowNdcRadius =
        (config.orthoMode && frustum > 1e-4f && bhLensActive)
            ? bSim * config.plateRadius / frustum
            : 0.0f;
    cam.aspect = aspect;
  }
  cam.sharpness = config.sharpness;
  cam.grainAlpha = config.grainAlpha;
  cam.oscAmount = config.oscAmount;
  cam.spinX = config.spinX;
  cam.spinY = config.spinY;
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
    impl_->bhPoseTime += dtP;
    cam.bhDiskGM   = (float)space::units::gmSim((double)impl_->bhSeedMass);
    cam.bhPoseTime = (float)impl_->bhPoseTime;
    cam.bhPoseDt   = (float)dtP;
  } else {
    cam.bhDiskGM = 0.0f; cam.bhPoseTime = 0.0f; cam.bhPoseDt = 0.0f;
  }
  cam.tuneLens = config.lensBend;
  cam.tuneArcWrap = config.arcWrap;
  cam.tuneArcGain = config.arcGain;
  cam.tuneTrailGain = config.trailGain;
  cam.tuneStreakLen = config.streakLen;
  cam.tuneColorK = config.colorTempK;
  cam.tuneHeatK = config.heatGain;
  cam.bhToggles = config.bhToggles;
  impl_->bhToggles = config.bhToggles; // → physics gates in runComputePass
  memcpy(impl_->cameraBuffer[frameIdx].contents, &cam, sizeof(cam));

  impl_->renderWithCamera(drawable, renderCmdBuf, frameIdx, config);
}

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
  cam.cameraPad = config.cameraRho;
  cam.particleSize = config.particleSize;
  cam.plateRadius = config.plateRadius;
  cam.phaseViz = config.phaseViz ? 1.0f : 0.0f;
  cam.envelopePhase = impl_->renderPhaseSmooth; // smoothed (render-only)
  cam.envelopeProgress = config.envelopeProgress;
  cam.orthoMode = config.orthoMode ? 1.0f : 0.0f;
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
    float bSim = 2.6f * (float)space::units::kRsSimPerMsun *
                 std::max(impl_->bhSeedMass, 0.0f) *   // accreted BH mass (stable, monotonic)
                 config.shadowRadius;
    bool bhLensActive = (impl_->physicsUniforms.totalAmplitude < 0.02f); // lens OFF during play
    cam.bhShadowNdcRadius =
        (config.orthoMode && frustum > 1e-4f && bhLensActive)
            ? bSim * config.plateRadius / frustum
            : 0.0f;
    cam.aspect = (float)impl_->width / (float)impl_->height;
  }
  cam.sharpness = config.sharpness;
  cam.grainAlpha = config.grainAlpha;
  cam.oscAmount = config.oscAmount;
  cam.spinX = config.spinX;
  cam.spinY = config.spinY;
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
    impl_->bhPoseTime += dtP;
    cam.bhDiskGM   = (float)space::units::gmSim((double)impl_->bhSeedMass);
    cam.bhPoseTime = (float)impl_->bhPoseTime;
    cam.bhPoseDt   = (float)dtP;
  } else {
    cam.bhDiskGM = 0.0f; cam.bhPoseTime = 0.0f; cam.bhPoseDt = 0.0f;
  }
  cam.tuneLens = config.lensBend;
  cam.tuneArcWrap = config.arcWrap;
  cam.tuneArcGain = config.arcGain;
  cam.tuneTrailGain = config.trailGain;
  cam.tuneStreakLen = config.streakLen;
  cam.tuneColorK = config.colorTempK;
  cam.tuneHeatK = config.heatGain;
  cam.bhToggles = config.bhToggles;
  impl_->bhToggles = config.bhToggles; // → physics gates in runComputePass
  memcpy(impl_->cameraBuffer[frameIdx].contents, &cam, sizeof(cam));

  impl_->renderWithCamera(drawable, renderCmdBuf, frameIdx, config);
}

void Renderer::setScale(float s) { impl_->physicsUniforms.plateRadius = s; }

// Internal helper for compute
void Renderer::triggerReset() { impl_->resetPending = true; }

void Renderer::Impl::runComputePass(id<MTLCommandBuffer> cmdBuf, int frameIdx) {
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
    physicsUniforms.gravGM = (float)(space::units::gmSim(sMassTotal) * massScale);
    // Hard-coded CENTRAL mass at the origin — the dominant anchor the cluster
    // orbits. Sized so its ISCO (3·r_s = 3·M·kRsSimPerMsun) is SMALLER than the
    // cluster radius (~1–3 sim), so stars orbit OUTSIDE the ISCO (stable, ~0.4c)
    // instead of plunging from inside it. 1e5 M☉ → ISCO ≈ 0.5 sim. TUNABLE knob:
    // bigger = faster/tighter orbits (ISCO grows), smaller = wider/slower.
    physicsUniforms.centerGM = (float)space::units::gmSim(4297000.0);
    physicsUniforms.bhToggles = bhToggles;    // UI on/off bitmask → physics gates
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
      float ph = physicsUniforms.envelopePhase;
      bool tubePhase = (ph >= 1.5f && ph < 3.5f);
      su.halfExtent = tubePhase ? 3.0f : 64.0f; // reverted from 8: fine cells made
                                   // softening (cellSize²) tiny → sharp kicks hit
                                   // the c-cap → ejection. The resolution↔stability
                                   // trilemma needs adaptive sub-stepping, not a
                                   // smaller domain. Back to the bound star-map base.
      lastHashExtent = su.halfExtent;
      su.particleCount = particleCount;
      su.cellSize = 2.0f * su.halfExtent / (float)kGridSize;
      su.invCellSize = (float)kGridSize / (2.0f * su.halfExtent);
      su.gridSizeZ = kGridSize;
      memcpy(spatialHashUniformBuffer.contents, &su,
             sizeof(SpatialHashUniforms));

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
                      range:NSMakeRange(0, 256 * 4 * sizeof(uint32_t))
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
      [clearBlit fillBuffer:radialMassBuffer   // 256-shell horizon profile, re-accumulated each frame
                      range:NSMakeRange(0, 256 * sizeof(uint32_t))
                      value:0];
      [clearBlit endEncoding];

      // Phase 1: assign_cells
      {
        id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
        [comp setComputePipelineState:assignCellsPipeline];
        [comp setBuffer:particleBufferRead offset:0 atIndex:0];
        [comp setBuffer:cellIndicesBuffer offset:0 atIndex:1];
        [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:2];
        NSUInteger tg =
            std::min(tgSize, assignCellsPipeline.maxTotalThreadsPerThreadgroup);
        [comp dispatchThreads:MTLSizeMake(particleCount, 1, 1)
            threadsPerThreadgroup:MTLSizeMake(tg, 1, 1)];
        [comp endEncoding];
      }

      // Phase 2: count_cells (atomic)
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
      bool sphFrame = (physicsUniforms.frameCounter % kSphCadence) == 0u;

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
                 coolOn, coolTau; } sphParams = {
            physicsUniforms.dt,
            physicsUniforms.dt * (float)kSphCadence,  // du + brake cover skipped frames
            sphAlpha,
            sphBeta,
            (float)space::spacetime::kUFloorSim,
            uMax,
            sphViscosityOn ? 1.0f : 0.0f,
            muMax,
            sphCoolingOn ? 1.0f : 0.0f,
            lastSphCoolTau};  // τ₀ [simt] from the mod-menu slider (~1 simt ≈ 1 s wall)
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
      bool sorFrame = (physicsUniforms.frameCounter % 2u) == 1u;
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
        [comp dispatchThreads:MTLSizeMake(256, 1, 1)
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
      }

      NSUInteger tg =
          std::min(tgSize, physicsPipeline.maxTotalThreadsPerThreadgroup);
      [comp dispatchThreads:MTLSizeMake(particleCount, 1, 1)
          threadsPerThreadgroup:MTLSizeMake(tg, 1, 1)];
      [comp endEncoding];
    }

    // ── Seed apply: credit each black hole its meals (after physics) ──
    if (seedApplyPipeline && seedAccumBuffer &&
        physicsUniforms.totalAmplitude < 0.02f) {  // no meal-crediting while playing
      id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
      [comp setComputePipelineState:seedApplyPipeline];
      [comp setBuffer:particleBuffer offset:0 atIndex:0];
      [comp setBuffer:seedCountBuffer offset:0 atIndex:1];
      [comp setBuffer:seedIdsBuffer offset:0 atIndex:2];
      [comp setBuffer:seedAccumBuffer offset:0 atIndex:3];
      [comp setBuffer:uniformBuffer[frameIdx] offset:0 atIndex:4];
      [comp dispatchThreads:MTLSizeMake(256, 1, 1)
          threadsPerThreadgroup:MTLSizeMake(64, 1, 1)];
      [comp endEncoding];
    }

    // ── Stats reduction ────────────────────────────────────────────
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

      // CPU-side final sum (from partial sums) — 1-frame latency is fine
      // Schedule readback after commit completes
      // For now, read previous frame's data synchronously
      if (numThreadgroups > 0) {
        struct PartialStats {
          float ke, mx, my, sumMass;
          float sumTemp, maxTemp, sumSpeed, maxSpeed;
          float sumPx, sumPy, sumPz, sumCount;
          float sumR, maxR, maxMass, pad3;
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
          totalEX += sums[i].sumEncX;
          totalEY += sums[i].sumEncY;
          totalEZ += sums[i].sumEncZ;
          totalEC += sums[i].sumEncMass;
          if (sums[i].maxTemp > gMaxTemp) gMaxTemp = sums[i].maxTemp;
          if (sums[i].maxSpeed > gMaxSpeed) gMaxSpeed = sums[i].maxSpeed;
        }
        // HONEST GEOMETRIC HORIZON (observe-only — full_physics_todo B2). From the
        // radial mass profile (mass binned by distance from the BH candidate), find
        // the largest r where r_s(M(<r)) ≥ r. This resolves r_s far below the coarse
        // 1.0-sim cell, so a small dense core can show a REAL horizon. NOT yet wired
        // to formation — just logged, so we can SEE r_h appear when a core crushes.
        if (radialMassBuffer) {
          const uint32_t *radial = (const uint32_t *)radialMassBuffer.contents;
          const double dr = 5.0 / 256.0;           // RADIAL_MAX_R / RADIAL_SHELLS
          const double kRsSimPerMsun = 1.6825e-6;  // units.h
          double cum = 0.0, r_h = 0.0, mEncRh = 0.0;
          for (int s = 0; s < 256; s++) {
            cum += radial[s] / 256.0;              // un-scale fixed-point → M_sun
            double r = (s + 1) * dr;
            if (kRsSimPerMsun * cum >= r) { r_h = r; mEncRh = cum; } // horizon here
          }
          lastHorizonR = (float)r_h;   // → uniform next frame: pressure yields inside r_h
          if ((physicsUniforms.frameCounter % 120u) == 0u) {
            fprintf(stderr,
                    "[HORIZON] r_h=%.4f sim  M(<r_h)=%.3e Msun  (honest geometric, observe-only)\n",
                    r_h, mEncRh);
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
        float encFrac = bhMassEnc / std::max(physicsUniforms.massTotal, 1.0f);
        float dt01 = (encFrac - 0.40f) / 0.30f;          // ramp 40%→70% gathered
        dt01 = dt01 < 0.0f ? 0.0f : (dt01 > 1.0f ? 1.0f : dt01);
        float densTarget = dt01 * dt01 * (3.0f - 2.0f * dt01); // smoothstep
        float target = std::max(seedTarget, densTarget);
        (void)collapseFrac;                      // UI dial now unused by formation
        // SMOOTH + LATCH: the raw enclosure signal wobbles with disk slosh
        // and made the raytracer flicker on/off ("seconds of black hole
        // greatness"). Ease toward it; once FORMED, a black hole stays a
        // black hole — mass inside doesn't leave. The latch clears only on
        // true dissolution (field reset: Menc < 1% of total).
        bhStrengthEma += (target - bhStrengthEma) * 0.04f;
        if (target >= 1.0f) bhFormedLatch = true;
        // Once a hole, ALWAYS a hole (agreed): the enclosure dips whenever
        // the seed wanders >0.5 off origin or a chord yanks the disk — that
        // must NOT un-form it ('exists then ceases to exist'). The latch
        // clears only when the biggest BODY is gone too, i.e. a true field
        // reset — no merger product survives a respawn.
        if (bhMassEnc < 0.01f * physicsUniforms.massTotal && gMaxMass < 50.0f)
          bhFormedLatch = false;
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
                  "[BH-POP] encFrac=%.2f densTarget=%.2f seedTarget=%.3f -> bhStrength=%.2f%s\n",
                  encFrac, densTarget, seedTarget, bhStrength,
                  bhFormedLatch ? " LATCH" : "");
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
                  "phase=%.1f amp=%.3f gm=%.3f bh=(%.2f %.2f %.2f) Menc=%.0f peak=%u\n",
                  liveCount, totalSM, physicsUniforms.massTotal, gMaxMass,
                  bhStrength, bhFormedLatch ? "L" : "",

                  seedCountBuffer ? ((const uint32_t *)seedCountBuffer.contents)[4] : 0u,
                  [&]() -> uint32_t {
                    if (!seedAccumBuffer) return 0;
                    const uint32_t *a = (const uint32_t *)seedAccumBuffer.contents;
                    uint32_t meals = 0;
                    for (int i = 0; i < 256; i++) meals += a[i * 4 + 1];
                    return meals;
                  }(),
                  [&]() -> float {
                    if (!seedAccumBuffer) return 0.0f;
                    const uint32_t *a = (const uint32_t *)seedAccumBuffer.contents;
                    uint64_t fp = 0;
                    for (int i = 0; i < 256; i++) fp += a[i * 4 + 0];
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
                  bhPosX, bhPosY, bhPosZ, bhMassEnc, bhPeakCount);
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
            double W = cl[0] * 1e-2, dyn = cl[1] * 1e-2, cool = cl[2] * 1e-2,
                   clmp = cl[3] * 1e-2;
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
        latestStats.fieldMassMsun = physicsUniforms.massTotal;
        latestStats.maxBodyMsun = gMaxMass;
        latestStats.bhStrength = bhStrength;
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
  // ── First Pass: Render particles to offscreen texture ──────────────
  MTLRenderPassDescriptor *offscreenPass =
      [MTLRenderPassDescriptor renderPassDescriptor];
  offscreenPass.colorAttachments[0].texture = offscreenTexture;
  offscreenPass.colorAttachments[0].loadAction = MTLLoadActionClear;
  offscreenPass.colorAttachments[0].storeAction = MTLStoreActionStore;
  offscreenPass.colorAttachments[0].clearColor =
      MTLClearColorMake(0, 0, 0, 0); // Transparent black

  offscreenPass.depthAttachment.texture = depthTexture;
  offscreenPass.depthAttachment.loadAction = MTLLoadActionClear;
  offscreenPass.depthAttachment.storeAction = MTLStoreActionDontCare;
  offscreenPass.depthAttachment.clearDepth = 1.0;

  id<MTLRenderCommandEncoder> enc =
      [cmdBuf renderCommandEncoderWithDescriptor:offscreenPass];

  // Geodesic fullscreen BH render DELETED (2026-06-28) — it was a shader painting
  // a disk, NOT the particles. The black hole must be the actual particle cloud,
  // gravitationally lensed. Particles always render.

  // Draw Particles — ALWAYS (the particles ARE the black hole)
  [enc setRenderPipelineState:particlePipeline];
  [enc setDepthStencilState:depthState];
  [enc setVertexBuffer:particleBuffer offset:0 atIndex:0];
  [enc setVertexBuffer:cameraBuffer[frameIdx] offset:0 atIndex:1];
  [enc setVertexBuffer:particleBuffer
                offset:0
               atIndex:2]; // Random-access for Webbing
  // instanceCount — instance 0 = primary image, instance 1 = the SECONDARY
  // lensed image (the Gargantua fold-over). The secondary only EXISTS when a
  // hole is lensing; with no hole it was culled in-shader to pointSize 0 — but
  // the heavy vertex shader (lensing + Doppler + blackbody + streak + webbing
  // partner read) STILL RAN for all 2×N particles, doubling the most expensive
  // pass in the app every frame for nothing. Only instance the secondary when a
  // hole is actually present → no-hole (play/rest) runs 1×, halving the pass.
  NSUInteger particleInstances = (bhStrength > 0.5f) ? 2u : 1u;
  [enc drawPrimitives:MTLPrimitiveTypePoint
          vertexStart:0
          vertexCount:particleCount
        instanceCount:particleInstances];

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
  if (false && trajectoryPipeline &&
      (bhStrength > 0.5f || config.oscAmount > 0.01f)) {
    [enc setRenderPipelineState:trajectoryPipeline];
    [enc setDepthStencilState:depthState];
    [enc setVertexBuffer:particleBuffer offset:0 atIndex:0];
    [enc setVertexBuffer:cameraBuffer[frameIdx] offset:0 atIndex:1];
    // ARC LOD BUDGET: every particle drawing a 22-vertex ribbon makes this pass
    // cost 22×particleCount line-vertices — unbounded with count (the 5M-easy →
    // 2M-fighting regression). Cap the arc-drawing particles to a fixed budget;
    // the field is dense enough that this many arcs still read as continuous
    // spacetime flow, but the cost stops scaling. (2026-06-18)
    int arcParticles = std::min(particleCount, 1500000);
    [enc drawPrimitives:MTLPrimitiveTypeLine
            vertexStart:0
            vertexCount:(NSUInteger)arcParticles * 22];
  }

  // Black-hole raytracer shadow pass DELETED (2026-06-28). It was a screen-space
  // 2D circle that sampled no useful disk. Real gravitational lensing is applied
  // to the particles in the vertex shader (render.metal).

  [enc endEncoding];

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

  // ── HDR glow: bright-pass → wide ping-pong blur (half-res) ─────────
  // Modern bloom split: extract HDR energy above a soft knee into a half-res
  // buffer, then blur it wide and cheap. The finished glow lands in
  // bloomTexture, which the final post pass adds back additively. Decoupled
  // from the user blur slider via its own two buffers. Bypassed at intensity 0.
  if (brightPipeline && blurPipeline && config.bloomIntensity > 0.001f &&
      bloomTexture && bloomScratch) {
    int bw = width / 2 > 0 ? width / 2 : 1;
    int bh = height / 2 > 0 ? height / 2 : 1;

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

    // 2) Wide separable blur, ping-ponging bloomTexture ↔ bloomScratch.
    // Each iteration is H then V, so the result lands back in bloomTexture.
    struct BlurU {
      float dir[2];
      float radius;
      float pad;
    };
    int iterations = 3;          // wide, soft halo
    float radius = 2.5f;         // half-res texels → covers a lot of screen
    for (int it = 0; it < iterations; it++) {
      for (int axis = 0; axis < 2; axis++) {
        id<MTLTexture> src = (axis == 0) ? bloomTexture : bloomScratch;
        id<MTLTexture> dst = (axis == 0) ? bloomScratch : bloomTexture;
        BlurU bu;
        bu.dir[0] = (axis == 0) ? (1.0f / (float)bw) : 0.0f;
        bu.dir[1] = (axis == 1) ? (1.0f / (float)bh) : 0.0f;
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
      }
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
  post.scanlineAmount = config.scanlineAmount;
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
  post.pixelStretch = config.pixelStretch; // "5D look" radial pixel-stretch (spin)
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
  if (syphonTexture && postPipeline) {
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
  if (syphonServer && syphonTexture) {
    [syphonServer publishFrameTexture:syphonTexture
                      onCommandBuffer:cmdBuf
                          imageRegion:NSMakeRect(0, 0, width, height)
                              flipped:YES];  // plain render target is top-left origin
  }
#endif

  // ── UI pass: draw the ImGui menu OVER the clean render (on-screen only) ──
  MTLRenderPassDescriptor *uiPass = [MTLRenderPassDescriptor renderPassDescriptor];
  uiPass.colorAttachments[0].texture = drawable.texture;
  uiPass.colorAttachments[0].loadAction = MTLLoadActionLoad;   // keep the render
  uiPass.colorAttachments[0].storeAction = MTLStoreActionStore;
  id<MTLRenderCommandEncoder> uiEnc =
      [cmdBuf renderCommandEncoderWithDescriptor:uiPass];
  ImGui::Render();
  ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), cmdBuf, uiEnc);
  [uiEnc endEncoding];

  [cmdBuf presentDrawable:drawable];
  [cmdBuf commit];

  currentFrame = (currentFrame + 1) % kMaxInFlightFrames;
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

  // ── Offscreen texture: HDR (RGBA16Float) for physics-accurate lighting ──
  MTLTextureDescriptor *hdrDesc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                   width:width
                                  height:height
                               mipmapped:NO];
  hdrDesc.storageMode = MTLStorageModePrivate;
  hdrDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
  impl_->offscreenTexture = [impl_->device newTextureWithDescriptor:hdrDesc];
#if HAS_SYPHON
  // Dedicated SDR-tonemapped texture for the Syphon feed (same format, separate
  // target so the screen stays EDR while the feed is vibrant-SDR).
  impl_->syphonTexture = [impl_->device newTextureWithDescriptor:hdrDesc];
#endif

  // Ping-pong HDR pool (two reused buffers for multi-pass effects)
  impl_->pingTexture[0] = [impl_->device newTextureWithDescriptor:hdrDesc];
  impl_->pingTexture[1] = [impl_->device newTextureWithDescriptor:hdrDesc];
  // HDR glow buffers at half-res — bloom is low-frequency, so half-res is
  // invisible and the blur taps cover twice the screen distance for free.
  MTLTextureDescriptor *bloomDesc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                   width:(NSUInteger)(width / 2 > 0 ? width / 2 : 1)
                                  height:(NSUInteger)(height / 2 > 0 ? height / 2 : 1)
                               mipmapped:NO];
  bloomDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
  impl_->bloomTexture = [impl_->device newTextureWithDescriptor:bloomDesc];
  impl_->bloomScratch = [impl_->device newTextureWithDescriptor:bloomDesc];

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
