#include "core/particles.h"
#include <cmath>
#include <random>

namespace space {

void ParticleSystem::init(int count, float maxWaveDepth) {
  maxWaveDepth_ = maxWaveDepth;
  particles_.resize(count);

  std::mt19937 rng(42);
  std::uniform_real_distribution<float> angle(0.0f, 2.0f * M_PI);
  std::uniform_real_distribution<float> radius(0.0f, 1.0f);
  std::uniform_real_distribution<float> depth(-1.0f, 1.0f);

  for (auto &p : particles_) {
    // True Universe Distribution: Particles exist uniformly in the void.
    // They are no longer forced into a pre-existing "planet" ball.
    // The physics engine (Gravity + Harmonic Waves) will collect them
    // organically.
    p.x = depth(rng) * 2.0f; // Scale to fill the visible universe bounds
    p.y = depth(rng) * 2.0f;
    p.z = depth(rng) * 2.0f;

    p.vx = 0.0f;
    p.vy = 0.0f;
    p.vz = 0.0f;
  }
}

void ParticleSystem::clear() { particles_.clear(); }

std::vector<GPUParticle> packForGPU(const ParticleSystem &system) {
  std::vector<GPUParticle> gpu(system.count());
  for (int i = 0; i < system.count(); i++) {
    const auto &p = system.data()[i];

    // Phase 5 LIDAR prep / Heavy Walls:
    // If a particle is at the very outer edge of the initialized cylinder (r >
    // 0.93), it becomes an infinite-mass unmoving boundary (invMass = 0.0f).
    float r3D = std::sqrt(p.x * p.x + p.y * p.y + p.z * p.z);
    float invMass = (r3D > 0.93f) ? 0.0f : 1.0f;

    gpu[i] = {
        p.x,
        p.y,
        p.z,
        invMass, // posW.w = invMass (0.0 = static wall)
        p.vx,
        p.vy,
        p.vz,
        0.0f, // vel + phase
        p.x,
        p.y,
        p.z,
        0.0f, // prevPos + temperature
        0.0f,
        0.0f,
        1.0f,
        1.0f,                                // spinZ = 1.0, charge = 1.0
        (uint32_t)(rand() % system.count()), // entanglementID
        0,
        0,
        0 // padding
    };
  }
  return gpu;
}

} // namespace space
