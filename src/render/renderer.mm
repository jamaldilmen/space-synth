#include "renderer.h"
#include "core/imf.h"
#include "core/units.h"
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
  id<MTLRenderPipelineState> blackHolePipeline = nil;

  // Spatial hash pipelines
  id<MTLComputePipelineState> assignCellsPipeline = nil;
  id<MTLComputePipelineState> countCellsPipeline = nil;
  id<MTLComputePipelineState> prefixSumLocalPipeline = nil;
  id<MTLComputePipelineState> prefixSumBlocksPipeline = nil;
  id<MTLComputePipelineState> prefixSumAddPipeline = nil;
  id<MTLComputePipelineState> scatterPipeline = nil;
  id<MTLComputePipelineState> centroidPipeline = nil; // per-cell centroid (cohesion)

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
  id<MTLBuffer> cellStartsBuffer = nil;      // prefix sum offsets
  id<MTLBuffer> blockSumsBuffer = nil;       // block sums for parallel scan
  id<MTLBuffer> cellOffsetsBuffer = nil;     // atomic write offsets for scatter
  id<MTLBuffer> sortedParticlesBuffer = nil; // particle data in cell order
  id<MTLBuffer> cellCentroidsBuffer = nil;   // float4 per cell: xyz centroid, w count
  id<MTLBuffer> cellVelocitiesBuffer = nil;  // float4 per cell: xyz mean velocity (per-frame)
  id<MTLBuffer> cellMaxPartialsBuffer = nil; // {count,cid} per threadgroup (densest cell)
  id<MTLBuffer> spatialHashUniformBuffer = nil;

  // Stats readback (partial sums from GPU reduction)
  id<MTLBuffer> partialSumsBuffer = nil;
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
  float bhStrength = 0.0f;    // collapse-fraction signal, smoothed+latched
  float bhStrengthEma = 0.0f; // eased raw signal (anti-flicker)
  bool bhFormedLatch = false; // once formed, stays formed (until reset)
  float collapseFrac = 0.25f; // UI dial: core fraction = hole 100%
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
  bool collisionsEnabled = false;
  bool bondNetworkEnabled = false;

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

  // ── Black Hole Pipeline ─────────────────────────────────────────────
  id<MTLFunction> bhVertexFunc =
      [impl_->library newFunctionWithName:@"vertex_black_hole"];
  id<MTLFunction> bhFragmentFunc =
      [impl_->library newFunctionWithName:@"fragment_black_hole"];
  if (bhVertexFunc && bhFragmentFunc) {
    MTLRenderPipelineDescriptor *desc =
        [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = bhVertexFunc;
    desc.fragmentFunction = bhFragmentFunc;
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float; // HDR
    // We want the black hole to "over" the clear color, but we also want to
    // fade it out. Standard premultiplied alpha blending:
    desc.colorAttachments[0].blendingEnabled = YES;
    desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
    desc.colorAttachments[0].destinationRGBBlendFactor =
        MTLBlendFactorOneMinusSourceAlpha;
    desc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    desc.colorAttachments[0].destinationAlphaBlendFactor =
        MTLBlendFactorOneMinusSourceAlpha;
    desc.colorAttachments[0].destinationAlphaBlendFactor =
        MTLBlendFactorOneMinusSourceAlpha;
    desc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    impl_->blackHolePipeline =
        [impl_->device newRenderPipelineStateWithDescriptor:desc error:&error];
    if (error)
      NSLog(@"Black Hole pipeline error: %@", error);
  }

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
  allocIfNeeded(impl_->seedCountBuffer, 8 * sizeof(uint32_t)); // [0]=n [1]=meals [2]=eaten×64 [3]=scan [4..6]=probe
  allocIfNeeded(impl_->seedIdsBuffer, 256 * sizeof(uint32_t));
  allocIfNeeded(impl_->cellSeedMapBuffer, cellSize);
  allocIfNeeded(impl_->seedAccumBuffer, 256 * 4 * sizeof(uint32_t));
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
  impl_->physicsUniforms.dt = dt;
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
  cam.tuneLens = config.lensBend;
  cam.tuneArcWrap = config.arcWrap;
  cam.tuneArcGain = config.arcGain;
  cam.tuneTrailGain = config.trailGain;
  cam.tuneStreakLen = config.streakLen;
  cam.tuneColorK = config.colorTempK;
  cam.tuneHeatK = config.heatGain;
  memcpy(impl_->cameraBuffer[frameIdx].contents, &cam, sizeof(cam));

  impl_->renderWithCamera(drawable, renderCmdBuf, frameIdx, config);
}

void Renderer::render(const RenderConfig &config, const float *viewProj) {
  impl_->renderPhaseSmooth +=
      (config.envelopePhase - impl_->renderPhaseSmooth) * 0.04f;
  impl_->collapseFrac = config.collapseFrac;
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
  cam.tuneLens = config.lensBend;
  cam.tuneArcWrap = config.arcWrap;
  cam.tuneArcGain = config.arcGain;
  cam.tuneTrailGain = config.trailGain;
  cam.tuneStreakLen = config.streakLen;
  cam.tuneColorK = config.colorTempK;
  cam.tuneHeatK = config.heatGain;
  memcpy(impl_->cameraBuffer[frameIdx].contents, &cam, sizeof(cam));

  impl_->renderWithCamera(drawable, renderCmdBuf, frameIdx, config);
}

void Renderer::setScale(float s) { impl_->physicsUniforms.plateRadius = s; }

// Internal helper for compute
void Renderer::triggerReset() { impl_->resetPending = true; }

void Renderer::Impl::runComputePass(id<MTLCommandBuffer> cmdBuf, int frameIdx) {
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
    physicsUniforms.massTotal = (float)sMassTotal;
    physicsUniforms.gravGM = (float)space::units::gmSim(sMassTotal);
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
      su.halfExtent = tubePhase ? 3.0f : 64.0f;
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
      [clearBlit fillBuffer:cellOffsetsBuffer
                      range:NSMakeRange(0, kTotalCells * sizeof(uint32_t))
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
      if (centroidPipeline && cellCentroidsBuffer &&
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

      // Phase 6: densest-cell reduce (the emergent-BH signal, Step 2)
      if (reduceCellMaxPipeline && cellMaxPartialsBuffer) {
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
      if (mergeStarsPipeline && countStable && notPlaying) {
        id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
        [comp setComputePipelineState:mergeStarsPipeline];
        [comp setBuffer:particleBuffer offset:0 atIndex:0];
        [comp setBuffer:sortedParticlesBuffer offset:0 atIndex:1];
        [comp setBuffer:cellStartsBuffer offset:0 atIndex:2];
        [comp setBuffer:cellCountsBuffer offset:0 atIndex:3];
        [comp setBuffer:spatialHashUniformBuffer offset:0 atIndex:4];
        [comp setBuffer:uniformBuffer[frameIdx] offset:0 atIndex:5];
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
    {
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
    if (reduceStatsPipeline && partialSumsBuffer) {
      id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
      [comp setComputePipelineState:reduceStatsPipeline];
      [comp setBuffer:particleBuffer offset:0 atIndex:0];
      [comp setBuffer:partialSumsBuffer offset:0 atIndex:1];
      [comp setBuffer:uniformBuffer[frameIdx] offset:0 atIndex:2];

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
        float target = (float)(kRsSimPerMsun * bhSeedMass / kREnc);
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

  // 1. Draw Black Hole Background (raymarching)
  // Re-enabled. The raytracer renders pure BLACK inside the Kerr geodesic
  // event horizon — that's the dark central void the lensed accretion-disk
  // lobes wrap around (Interstellar/Gargantua look). Without it the
  // particle lensing arches around nothing visible.
  // Run during silence, sustain, release. Attack + decay skip (shader-side
  // opacity is 0 there anyway).
  PhysicsUniforms *phys_gate = (PhysicsUniforms *)uniformBuffer[frameIdx].contents;
  // EMERGENT-BH render gate (Step 3): the shadow renders because the core
  // approaches the geometric hole criterion — mass decides, not the phase.
  bool needRaytracer = (bhStrength > 0.5f);
  (void)phys_gate;
  // (Black-hole shadow pass MOVED below — it must composite OVER the
  // particle disk and the arcs: drawing it first let matter paint over the
  // round shadow, leaving only the elliptical cull-gap = the '2D eye'.)

  // 2. Draw Particles
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
  if (trajectoryPipeline &&
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

  // 3. Black-hole shadow + lens — LAST: the hole occludes the matter.
  // BILLBOARD DELETED (Jamal): the raytraced shadow disc was a 2D layer
  // composited over the particle world — it could never be one entity with
  // it. The hole is the LENS now: the original particle lensing bends the
  // light, and the darkness is wherever no light ends up. No overlay.
  if (false && blackHolePipeline && needRaytracer) {
    struct BlackHoleUniforms {
      float resolution[2]; // 8
      float cameraPos[3];  // 12
      float time;          // 4
      float envelopePhase; // 4
      float rotationX;     // 4
      float simScale;      // 4 — particle scale (plateRadius)
      float orthoFrustum;  // 4 — ortho half-extent in world units (0 = persp)
      float shadowRadius;  // 4 — black shadow radius in sim coords (user-tunable)
      float bhStrength;    // 4 — emergent-hole signal (Step 3)
    }; // 48 bytes

    PhysicsUniforms *phys = (PhysicsUniforms *)uniformBuffer[frameIdx].contents;
    BlackHoleUniforms bhUniforms;
    bhUniforms.resolution[0] = (float)width;
    bhUniforms.resolution[1] = (float)height;

    CameraUniforms *camStruct =
        (CameraUniforms *)cameraBuffer[frameIdx].contents;
    bhUniforms.cameraPos[0] = camStruct->cameraPos[0];
    bhUniforms.cameraPos[1] = camStruct->cameraPos[1];
    bhUniforms.cameraPos[2] = camStruct->cameraPos[2];

    bhUniforms.time = phys->time;
    bhUniforms.envelopePhase = renderPhaseSmooth; // smoothed (render-only)
    bhUniforms.rotationX = config.rotationX;
    bhUniforms.simScale = std::max(0.01f, config.plateRadius);
    // Ortho frustum half-extent = cameraRho * 1.2 (matches main.cpp:534).
    // Was using plateRadius (constant 100) which made the raytracer ignore
    // zoom entirely. cameraRho varies 50-2000 with the user's zoom.
    bhUniforms.orthoFrustum = config.orthoMode ? (config.cameraRho * 1.2f) : 0.0f;
    bhUniforms.shadowRadius = config.shadowRadius;
    bhUniforms.bhStrength = bhStrength;

    [enc setRenderPipelineState:blackHolePipeline];
    [enc setFragmentBytes:&bhUniforms
                   length:sizeof(BlackHoleUniforms)
                  atIndex:0];

    // Bind Spatial Hash Buffers for volumetric particle sampling
    [enc setFragmentBuffer:spatialHashUniformBuffer offset:0 atIndex:1];
    [enc setFragmentBuffer:cellStartsBuffer offset:0 atIndex:2];
    [enc setFragmentBuffer:sortedParticlesBuffer offset:0 atIndex:3];

    [enc setDepthStencilState:bgDepthState];
    [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
  }

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
