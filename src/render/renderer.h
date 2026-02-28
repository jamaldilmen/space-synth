#pragma once
#include "core/particles.h"
#include <cstdint>

namespace space {

struct RenderConfig {
    int width = 1920;
    int height = 1080;
    float particleSize = 0.8f;
    float bloomIntensity = 0.0f;
    float trailDecay = 0.0f;
    float chromaticAberration = 0.0f;
};

// Metal renderer: compute pipeline for physics, instanced draw for particles
class Renderer {
public:
    Renderer();
    ~Renderer();

    // Initialize Metal device, command queue, pipelines, shaders
    // metalLayer = CAMetalLayer from the window
    bool init(void* metalLayer, int width, int height);

    // Upload particle data to GPU buffer
    void uploadParticles(const GPUParticle* data, int count);

    // Execute compute pass: particle physics step on GPU
    // voiceData = per-voice mode/amplitude info for the compute shader
    struct VoiceGPUData {
        int m;
        int n;
        float alpha;
        float amplitude;
    };
    void computeStep(float dt, const VoiceGPUData* voices, int voiceCount,
                     float totalAmplitude);

    // Execute render pass: instanced particle draw + post-fx
    void render(const RenderConfig& config);

    // Resize swap chain
    void resize(int width, int height);

    // Get the Metal texture for Syphon output
    void* currentTexture() const;

private:
    struct Impl;
    Impl* impl_;
};

} // namespace space
