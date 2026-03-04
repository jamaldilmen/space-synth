#include "core/particles.h"
#include <cmath>
#include <random>

namespace space {

void ParticleSystem::init(int count, float maxWaveDepth) {
  maxWaveDepth_ = maxWaveDepth;
  particles_.resize(count);

  std::mt19937 rng(42);
  // Phase 10: Gaussian Universe Spawn
  // Replacing a hard uniform box [-2.0, 2.0] with a soft Gaussian cloud
  // centered on 0. This eradicates the visual "quadrat" and creates a true
  // majestic void.
  std::normal_distribution<float> gaussian(0.0f, 1.2f); // Mean 0.0, StdDev 1.2

  for (auto &p : particles_) {
    // True Universe Distribution: Particles exist uniformly in the void.
    // They are no longer forced into a pre-existing "planet" ball.
    // The physics engine (Gravity + Harmonic Waves) will collect them
    // organically.
    p.x = gaussian(rng);
    p.y = gaussian(rng);
    p.z = gaussian(rng);

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
