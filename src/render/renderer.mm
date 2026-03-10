#include "renderer.h"
#include "backends/imgui_impl_metal.h"
#include "imgui.h"
#include <Metal/Metal.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/CAMetalLayer.h>
#include <algorithm>
#include <cstring>
#include <simd/simd.h>

namespace space {

struct Renderer::Impl {
  id<MTLDevice> device;
  id<MTLCommandQueue> commandQueue;        // For rendering
  id<MTLCommandQueue> computeCommandQueue; // For async physics
  id<MTLEvent> frameEvent;                 // Synchronization fence
  uint64_t frameEventValue;                // Fence ticket

  id<MTLLibrary> library = nil;

  id<MTLComputePipelineState> physicsPipeline = nil;
  id<MTLRenderPipelineState> particlePipeline = nil;
  id<MTLRenderPipelineState> postPipeline = nil;
  id<MTLRenderPipelineState> blackHolePipeline = nil;

  // Spatial hash pipelines
  id<MTLComputePipelineState> assignCellsPipeline = nil;
  id<MTLComputePipelineState> countCellsPipeline = nil;
  id<MTLComputePipelineState> prefixSumLocalPipeline = nil;
  id<MTLComputePipelineState> prefixSumBlocksPipeline = nil;
  id<MTLComputePipelineState> prefixSumAddPipeline = nil;
  id<MTLComputePipelineState> scatterPipeline = nil;

  // Conservation law reduction
  id<MTLComputePipelineState> reduceStatsPipeline = nil;

  id<MTLBuffer> particleBuffer = nil;
  id<MTLBuffer> particleBufferRead = nil; // Double-buffer for collision reads

  // Spatial hash buffers
  static constexpr int kGridSize = 32; // 32x32x32 (64^3 too expensive for 1M)
  static constexpr int kTotalCells =
      kGridSize * kGridSize * kGridSize;     // 32,768
  id<MTLBuffer> cellIndicesBuffer = nil;     // cell ID per particle
  id<MTLBuffer> cellCountsBuffer = nil;      // count per cell
  id<MTLBuffer> cellStartsBuffer = nil;      // prefix sum offsets
  id<MTLBuffer> blockSumsBuffer = nil;       // block sums for parallel scan
  id<MTLBuffer> cellOffsetsBuffer = nil;     // atomic write offsets for scatter
  id<MTLBuffer> sortedParticlesBuffer = nil; // particle data in cell order
  id<MTLBuffer> spatialHashUniformBuffer = nil;

  // Stats readback (partial sums from GPU reduction)
  id<MTLBuffer> partialSumsBuffer = nil;
  int numThreadgroups = 0;
  PhysicsStats latestStats = {};
  bool collisionsEnabled = false;

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

  float prevViewProj[16];

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
  impl_->frameEvent = [impl_->device newEvent];
  impl_->frameEventValue = 0;

  impl_->inFlightSemaphore =
      dispatch_semaphore_create(Impl::kMaxInFlightFrames);
  impl_->currentFrame = 0;

  NSError *error = nil;
  NSString *execPath = [[[NSProcessInfo processInfo] arguments][0]
      stringByDeletingLastPathComponent];
  NSString *libPath =
      [execPath stringByAppendingPathComponent:@"default.metallib"];
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
                                  "prefix_sum_add",   "scatter_particles"};
  id<MTLComputePipelineState> *spatialPipelines[] = {
      &impl_->assignCellsPipeline,    &impl_->countCellsPipeline,
      &impl_->prefixSumLocalPipeline, &impl_->prefixSumBlocksPipeline,
      &impl_->prefixSumAddPipeline,   &impl_->scatterPipeline};
  for (int i = 0; i < 6; i++) {
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
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    impl_->postPipeline =
        [impl_->device newRenderPipelineStateWithDescriptor:desc error:&error];
    if (error)
      NSLog(@"Post-FX pipeline error: %@", error);
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
  allocIfNeeded(impl_->cellStartsBuffer, cellSize);
  size_t blockSumsSize = ((Impl::kTotalCells + 2047) / 2048) * sizeof(uint32_t);
  allocIfNeeded(impl_->blockSumsBuffer, blockSumsSize);
  allocIfNeeded(impl_->cellOffsetsBuffer, cellSize);
  allocIfNeeded(impl_->sortedParticlesBuffer, size);
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

  // Partial sums buffer for reduction: 1 per threadgroup (800k/256 = 3125)
  impl_->numThreadgroups = (count + 255) / 256;
  // Each partial sum: 4 floats (KE, MX, MY, pad) = 16 bytes
  allocIfNeeded(impl_->partialSumsBuffer, impl_->numThreadgroups * 16);
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
    gpuData[i].pad1 = gpuData[i].pad2 = gpuData[i].pad3 = 0;
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
  impl_->physicsUniforms.speedCap = speedCap;
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

  static float accumulatedTime = 0.0f;
  accumulatedTime += dt;
  impl_->physicsUniforms.time = accumulatedTime;

  impl_->hasCompute = true;
}

void Renderer::render(const RenderConfig &config) {
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
  cam.padding[0] = config.orthoMode ? 1.0f : 0.0f;
  memcpy(impl_->cameraBuffer[frameIdx].contents, &cam, sizeof(cam));

  impl_->renderWithCamera(drawable, renderCmdBuf, frameIdx, config);
}

void Renderer::render(const RenderConfig &config, const float *viewProj) {
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
  [computeCmdBuf commit];

  // 2. Render Pass
  id<MTLCommandBuffer> renderCmdBuf = [impl_->commandQueue commandBuffer];

  __block dispatch_semaphore_t block_sema = impl_->inFlightSemaphore;
  [renderCmdBuf addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
    dispatch_semaphore_signal(block_sema);
  }];

  // Wait for compute
  [renderCmdBuf encodeWaitForEvent:impl_->frameEvent
                             value:computeFinishedTicket];

  // ── Camera ──────────────────────────────────────────────────────────
  CameraUniforms cam = {};
  memcpy(cam.viewProj, viewProj, 16 * sizeof(float));
  cam.cameraPad = config.cameraRho;
  cam.particleSize = config.particleSize;
  cam.plateRadius = config.plateRadius;
  cam.phaseViz = config.phaseViz ? 1.0f : 0.0f;
  cam.padding[0] = config.orthoMode ? 1.0f : 0.0f;
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

    memcpy(uniformBuffer[frameIdx].contents, &physicsUniforms,
           sizeof(physicsUniforms));

    NSUInteger tgSize = 256;

    // ── Double-buffer: copy particles for collision reads ──────────
    if (collisionsEnabled && particleBufferRead) {
      id<MTLBlitCommandEncoder> blit = [cmdBuf blitCommandEncoder];
      [blit copyFromBuffer:particleBuffer
               sourceOffset:0
                   toBuffer:particleBufferRead
          destinationOffset:0
                       size:particleCount * sizeof(GPUParticle)];
      [blit endEncoding];
    }

    // ── Spatial hash build (4 phases) ──────────────────────────────
    if (collisionsEnabled && assignCellsPipeline && countCellsPipeline &&
        prefixSumLocalPipeline && prefixSumBlocksPipeline &&
        prefixSumAddPipeline && scatterPipeline) {
      // Upload spatial hash uniforms
      SpatialHashUniforms su = {};
      su.gridSize = kGridSize;
      su.particleCount = particleCount;
      su.cellSize = 2.0f / (float)kGridSize;
      su.invCellSize = (float)kGridSize / 2.0f;
      su.gridSizeZ = kGridSize;
      memcpy(spatialHashUniformBuffer.contents, &su,
             sizeof(SpatialHashUniforms));

      // Clear cell counts and offsets
      id<MTLBlitCommandEncoder> clearBlit = [cmdBuf blitCommandEncoder];
      [clearBlit fillBuffer:cellCountsBuffer
                      range:NSMakeRange(0, kTotalCells * sizeof(uint32_t))
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
      }

      NSUInteger tg =
          std::min(tgSize, physicsPipeline.maxTotalThreadsPerThreadgroup);
      [comp dispatchThreads:MTLSizeMake(particleCount, 1, 1)
          threadsPerThreadgroup:MTLSizeMake(tg, 1, 1)];
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
          float ke, mx, my, pad;
        };
        const PartialStats *sums =
            (const PartialStats *)partialSumsBuffer.contents;
        float totalKE = 0, totalMX = 0, totalMY = 0;
        for (int i = 0; i < numThreadgroups; i++) {
          totalKE += sums[i].ke;
          totalMX += sums[i].mx;
          totalMY += sums[i].my;
        }
        latestStats.kineticEnergy = totalKE;
        latestStats.momentumX = totalMX;
        latestStats.momentumY = totalMY;
        latestStats.collisionCount = 0;

        // Physical Assert: Check for NaNs or Infinity (Energy Explosion)
        if (std::isnan(totalKE) || std::isinf(totalKE) || totalKE > 1e12f) {
          latestStats.errorState = (std::isnan(totalKE)) ? 1 : 2;
        } else {
          latestStats.errorState = 0;
        }
      }
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
  if (blackHolePipeline && config.envelopePhase <= 0.5f) {
    struct BlackHoleUniforms {
      float resolution[2]; // 8 bytes
      float cameraPos[3];  // 12 bytes
      float time;          // 4 bytes
      float envelopePhase; // 4 bytes
      float rotationX;     // 4 bytes
    }; // 32 bytes total

    PhysicsUniforms *phys = (PhysicsUniforms *)uniformBuffer[frameIdx].contents;
    BlackHoleUniforms bhUniforms;
    bhUniforms.resolution[0] = (float)width;
    bhUniforms.resolution[1] = (float)height;

    // Note: cameraPos comes from the CameraUniforms bound to cameraBuffer
    CameraUniforms *camStruct =
        (CameraUniforms *)cameraBuffer[frameIdx].contents;
    bhUniforms.cameraPos[0] = camStruct->cameraPos[0];
    bhUniforms.cameraPos[1] = camStruct->cameraPos[1];
    bhUniforms.cameraPos[2] = camStruct->cameraPos[2];

    bhUniforms.time = phys->time;
    bhUniforms.envelopePhase = config.envelopePhase;
    bhUniforms.rotationX = config.blackHoleRotationX;

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

  // 2. Draw Particles
  [enc setRenderPipelineState:particlePipeline];
  [enc setDepthStencilState:depthState];
  [enc setVertexBuffer:particleBuffer offset:0 atIndex:0];
  [enc setVertexBuffer:cameraBuffer[frameIdx] offset:0 atIndex:1];
  [enc setVertexBuffer:particleBuffer
                offset:0
               atIndex:2]; // Random-access for Webbing
  [enc drawPrimitives:MTLPrimitiveTypePoint
          vertexStart:0
          vertexCount:particleCount];
  [enc endEncoding];

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
    [postEnc setFragmentTexture:offscreenTexture atIndex:0];
    [postEnc setFragmentTexture:prevFrameTexture atIndex:1];
    [postEnc setFragmentBuffer:postUniformBuffer[frameIdx] offset:0 atIndex:0];
    [postEnc drawPrimitives:MTLPrimitiveTypeTriangle
                vertexStart:0
                vertexCount:3];
  }

  // Render ImGui on top
  ImGui::Render();
  ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), cmdBuf, postEnc);

  [postEnc endEncoding];

  // ── Copy result to prevFrameTexture for trails ────────────────────
  id<MTLBlitCommandEncoder> blit = [cmdBuf blitCommandEncoder];
  [blit copyFromTexture:drawable.texture toTexture:prevFrameTexture];
  [blit endEncoding];

  [cmdBuf presentDrawable:drawable];
  [cmdBuf commit];

  currentFrame = (currentFrame + 1) % kMaxInFlightFrames;
}

void Renderer::renderImGui(void *renderEncoder) {
  ImGui::Render();
  ImGui_ImplMetal_RenderDrawData(
      ImGui::GetDrawData(),
      (__bridge id<MTLCommandBuffer>)[(
          __bridge id<MTLRenderCommandEncoder>)renderEncoder commandBuffer],
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

  // Feedback texture stays BGRA8 (post-tonemapped)
  MTLTextureDescriptor *colorDesc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
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

void Renderer::setEnvelopeState(float phase, float progress, float intensity) {
  impl_->envPhase = phase;
  impl_->envProgress = progress;
  impl_->envIntensity = intensity;
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
