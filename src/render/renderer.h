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

  // Post-FX
  float bloomIntensity = 0.0f;
  float trailDecay = 0.0f; // Persistence of previous frame
  float chromaticAmount = 0.0f;

  // New Simulation
  float modeP = 1.0f; // Depth Mode multiplier
  float cameraRho = 800.0f;
  bool orthoMode = true;
  bool phaseViz = false;
};

// Matches postfx.metal struct
struct PostFXUniforms {
  float resolution[2];
  float bloomIntensity;
  float trailDecay;
  float chromaticAmount;
  float padding[3];
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
  float padding[1];
};

// Voice data for GPU compute (matches VoiceData in particles.metal)
struct VoiceGPUData {
  int m;
  int n;
  float alpha;
  float amplitude;
  float emitterX;  // Point source position X
  float emitterY;  // Point source position Y
  float emitterZ;  // Point source position Z
  float frequency; // Was pad, now explicitly carries frequency for E=mc2
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
};

// Spatial hash uniforms for collision grid
struct SpatialHashUniforms {
  int gridSize; // 32
  int particleCount;
  float cellSize;    // 2.0 / gridSize
  float invCellSize; // gridSize / 2.0
  int gridSizeZ;     // 32
};

// Stats readback from GPU (conservation laws)
struct PhysicsStats {
  float kineticEnergy;
  float momentumX;
  float momentumY;
  int collisionCount;
};

class Renderer {
public:
  Renderer();
  ~Renderer();

  bool init(void *metalDevice, void *metalLayer, int width, int height);

  void uploadParticles(const GPUParticle *data, int count);
  // Compute physics step (runs async)
  void computeStep(float dt, const VoiceGPUData *voices, int voiceCount,
                   float totalAmplitude, float maxWaveDepth, float jitterFactor,
                   float speedCap, float eFieldStiffness,
                   float bFieldCirculation, float gravityConstant,
                   float stringStiffness, float restLength);

  void render(const RenderConfig &config);
  void render(const RenderConfig &config, const float *viewProj);

  void resize(int width, int height);

  void renderImGui(void *renderEncoder);

  int particleCount() const;
  void setActiveParticleCount(int count);
  void *getMetalDevice() const;

  // Read back particle positions from GPU buffer (for CPU-side access)
  void readbackParticles(GPUParticle *out, int count);

  // Collision system
  void setCollisionsEnabled(bool enabled);
  bool collisionsEnabled() const;

  // Physics stats (1-frame latency)
  PhysicsStats getPhysicsStats() const;

  // Camera helpers
  static void orthoMatrix(float *out, float left, float right, float bottom,
                          float top, float near, float far);
  static void perspectiveMatrix(float *out, float fovY, float aspect,
                                float near, float far);

private:
  struct Impl;
  Impl *impl_;
};

} // namespace space
