#pragma once
#include "core/particles.h"
#include <cmath>
#include <cstdint>

namespace space {

struct RenderConfig {
  int width = 1920;
  int height = 1080;
  float particleSize = 2.0f;
  float bloomIntensity = 0.0f;
  float trailDecay = 0.0f;
  float chromaticAberration = 0.0f;
  float plateRadius = 400.0f;
};

// Camera uniforms — matches the struct in render.metal
struct CameraUniforms {
  float viewProj[16]; // 4x4 column-major
  float cameraPos[3];
  float particleSize;
  float plateRadius;
  float padding[3];
};

// Voice data for GPU compute
struct VoiceGPUData {
  int m;
  int n;
  float alpha;
  float amplitude;
};

// Physics uniforms for compute shader
struct PhysicsUniforms {
  float dt;
  float totalAmplitude;
  int voiceCount;
  int particleCount;
  float maxWaveDepth;
  float plateRadius;
  float padding[2];
};

class Renderer {
public:
  Renderer();
  ~Renderer();

  bool init(void *metalDevice, void *metalLayer, int width, int height);

  void uploadParticles(const GPUParticle *data, int count);

  void computeStep(float dt, const VoiceGPUData *voices, int voiceCount,
                   float totalAmplitude, float maxWaveDepth);

  void render(const RenderConfig &config);

  void resize(int width, int height);

  int particleCount() const;

  // Read back particle positions from GPU buffer (for CPU-side access)
  void readbackParticles(GPUParticle *out, int count);

private:
  struct Impl;
  Impl *impl_;

  // Build orthographic projection matrix
  static void orthoMatrix(float *out, float left, float right, float bottom,
                          float top, float near, float far);
};

} // namespace space
