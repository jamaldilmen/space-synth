#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/CAMetalLayer.h>
#include "render/renderer.h"

namespace space {

struct Renderer::Impl {
    id<MTLDevice> device = nil;
    id<MTLCommandQueue> commandQueue = nil;
    id<MTLLibrary> library = nil;

    // Compute pipelines
    id<MTLComputePipelineState> physicsPipeline = nil;

    // Render pipelines
    id<MTLRenderPipelineState> particlePipeline = nil;
    id<MTLRenderPipelineState> postfxPipeline = nil;

    // Buffers
    id<MTLBuffer> particleBuffer = nil;
    id<MTLBuffer> voiceBuffer = nil;
    id<MTLBuffer> uniformBuffer = nil;

    // Depth
    id<MTLDepthStencilState> depthState = nil;
    id<MTLTexture> depthTexture = nil;

    // Off-screen render targets for post-fx
    id<MTLTexture> colorTargetA = nil;
    id<MTLTexture> colorTargetB = nil;

    CAMetalLayer* metalLayer = nil;
    int particleCount = 0;
    int width = 0;
    int height = 0;
};

Renderer::Renderer() : impl_(new Impl()) {}

Renderer::~Renderer() {
    delete impl_;
}

bool Renderer::init(void* metalLayer, int width, int height) {
    impl_->metalLayer = (__bridge CAMetalLayer*)metalLayer;
    impl_->device = MTLCreateSystemDefaultDevice();
    if (!impl_->device) return false;

    impl_->metalLayer.device = impl_->device;
    impl_->metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    impl_->metalLayer.framebufferOnly = NO;  // Need for Syphon

    impl_->commandQueue = [impl_->device newCommandQueue];

    // Load compiled shader library
    NSString* libPath = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"metallib"];
    if (!libPath) {
        // Fallback: look next to executable
        NSString* execPath = [[NSBundle mainBundle] executablePath];
        NSString* execDir = [execPath stringByDeletingLastPathComponent];
        libPath = [execDir stringByAppendingPathComponent:@"default.metallib"];
    }

    NSError* error = nil;
    if (libPath) {
        NSURL* libURL = [NSURL fileURLWithPath:libPath];
        impl_->library = [impl_->device newLibraryWithURL:libURL error:&error];
    }

    if (!impl_->library) {
        NSLog(@"Failed to load Metal library: %@", error);
        return false;
    }

    // ── Compute pipeline: particle physics ──────────────────────────────
    id<MTLFunction> physicsFunc = [impl_->library newFunctionWithName:@"particle_physics"];
    if (physicsFunc) {
        impl_->physicsPipeline = [impl_->device newComputePipelineStateWithFunction:physicsFunc error:&error];
    }

    // ── Render pipeline: instanced particles ────────────────────────────
    id<MTLFunction> vertexFunc = [impl_->library newFunctionWithName:@"particle_vertex"];
    id<MTLFunction> fragmentFunc = [impl_->library newFunctionWithName:@"particle_fragment"];

    if (vertexFunc && fragmentFunc) {
        MTLRenderPipelineDescriptor* desc = [[MTLRenderPipelineDescriptor alloc] init];
        desc.vertexFunction = vertexFunc;
        desc.fragmentFunction = fragmentFunc;
        desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        desc.colorAttachments[0].blendingEnabled = YES;
        desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        desc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
        impl_->particlePipeline = [impl_->device newRenderPipelineStateWithDescriptor:desc error:&error];
    }

    // ── Post-FX pipeline ────────────────────────────────────────────────
    id<MTLFunction> postVert = [impl_->library newFunctionWithName:@"postfx_vertex"];
    id<MTLFunction> postFrag = [impl_->library newFunctionWithName:@"postfx_fragment"];

    if (postVert && postFrag) {
        MTLRenderPipelineDescriptor* desc = [[MTLRenderPipelineDescriptor alloc] init];
        desc.vertexFunction = postVert;
        desc.fragmentFunction = postFrag;
        desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        impl_->postfxPipeline = [impl_->device newRenderPipelineStateWithDescriptor:desc error:&error];
    }

    // ── Depth state ─────────────────────────────────────────────────────
    MTLDepthStencilDescriptor* depthDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthDesc.depthWriteEnabled = YES;
    impl_->depthState = [impl_->device newDepthStencilStateWithDescriptor:depthDesc];

    resize(width, height);
    return true;
}

void Renderer::uploadParticles(const GPUParticle* data, int count) {
    size_t size = count * sizeof(GPUParticle);
    impl_->particleCount = count;

    if (!impl_->particleBuffer || impl_->particleBuffer.length < size) {
        impl_->particleBuffer = [impl_->device newBufferWithLength:size
                                    options:MTLResourceStorageModeShared];
    }
    memcpy(impl_->particleBuffer.contents, data, size);
}

void Renderer::computeStep(float dt, const VoiceGPUData* voices, int voiceCount,
                           float totalAmplitude) {
    if (!impl_->physicsPipeline || impl_->particleCount == 0) return;

    // Upload voice data
    size_t voiceSize = voiceCount * sizeof(VoiceGPUData);
    if (!impl_->voiceBuffer || impl_->voiceBuffer.length < voiceSize) {
        impl_->voiceBuffer = [impl_->device newBufferWithLength:std::max(voiceSize, (size_t)64)
                                 options:MTLResourceStorageModeShared];
    }
    if (voiceCount > 0) {
        memcpy(impl_->voiceBuffer.contents, voices, voiceSize);
    }

    // Uniforms
    struct PhysicsUniforms {
        float dt;
        float totalAmplitude;
        int voiceCount;
        int particleCount;
        float maxWaveDepth;
        float plateRadius;
        float padding[2];
    } uniforms = {dt, totalAmplitude, voiceCount, impl_->particleCount, 100.0f, 1.0f, {0, 0}};

    if (!impl_->uniformBuffer) {
        impl_->uniformBuffer = [impl_->device newBufferWithLength:256
                                   options:MTLResourceStorageModeShared];
    }
    memcpy(impl_->uniformBuffer.contents, &uniforms, sizeof(uniforms));

    id<MTLCommandBuffer> cmdBuf = [impl_->commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [cmdBuf computeCommandEncoder];

    [encoder setComputePipelineState:impl_->physicsPipeline];
    [encoder setBuffer:impl_->particleBuffer offset:0 atIndex:0];
    [encoder setBuffer:impl_->voiceBuffer offset:0 atIndex:1];
    [encoder setBuffer:impl_->uniformBuffer offset:0 atIndex:2];

    NSUInteger threadGroupSize = impl_->physicsPipeline.maxTotalThreadsPerThreadgroup;
    if (threadGroupSize > 256) threadGroupSize = 256;
    MTLSize threads = MTLSizeMake(impl_->particleCount, 1, 1);
    MTLSize groups = MTLSizeMake(threadGroupSize, 1, 1);

    [encoder dispatchThreads:threads threadsPerThreadgroup:groups];
    [encoder endEncoding];
    [cmdBuf commit];
}

void Renderer::render(const RenderConfig& config) {
    if (impl_->particleCount == 0) return;

    id<CAMetalDrawable> drawable = [impl_->metalLayer nextDrawable];
    if (!drawable) return;

    id<MTLCommandBuffer> cmdBuf = [impl_->commandQueue commandBuffer];

    // ── Main render pass ────────────────────────────────────────────────
    MTLRenderPassDescriptor* passDesc = [MTLRenderPassDescriptor renderPassDescriptor];
    passDesc.colorAttachments[0].texture = drawable.texture;
    passDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
    passDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
    passDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.04, 0.04, 0.06, 1.0);

    if (impl_->depthTexture) {
        passDesc.depthAttachment.texture = impl_->depthTexture;
        passDesc.depthAttachment.loadAction = MTLLoadActionClear;
        passDesc.depthAttachment.storeAction = MTLStoreActionDontCare;
        passDesc.depthAttachment.clearDepth = 1.0;
    }

    id<MTLRenderCommandEncoder> encoder = [cmdBuf renderCommandEncoderWithDescriptor:passDesc];

    if (impl_->particlePipeline) {
        [encoder setRenderPipelineState:impl_->particlePipeline];
        [encoder setDepthStencilState:impl_->depthState];
        [encoder setVertexBuffer:impl_->particleBuffer offset:0 atIndex:0];

        // TODO: Set camera uniforms at index 1
        // TODO: Draw instanced spheres
        // [encoder drawPrimitives:MTLPrimitiveTypeTriangle
        //            vertexStart:0 vertexCount:sphereVertexCount
        //          instanceCount:impl_->particleCount];
    }

    [encoder endEncoding];
    [cmdBuf presentDrawable:drawable];
    [cmdBuf commit];
}

void Renderer::resize(int width, int height) {
    impl_->width = width;
    impl_->height = height;

    // Recreate depth texture
    MTLTextureDescriptor* depthDesc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
        width:width height:height mipmapped:NO];
    depthDesc.storageMode = MTLStorageModePrivate;
    depthDesc.usage = MTLTextureUsageRenderTarget;
    impl_->depthTexture = [impl_->device newTextureWithDescriptor:depthDesc];

    // Recreate post-fx targets
    MTLTextureDescriptor* colorDesc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
        width:width height:height mipmapped:NO];
    colorDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    impl_->colorTargetA = [impl_->device newTextureWithDescriptor:colorDesc];
    impl_->colorTargetB = [impl_->device newTextureWithDescriptor:colorDesc];
}

void* Renderer::currentTexture() const {
    return (__bridge void*)impl_->colorTargetA;
}

} // namespace space
