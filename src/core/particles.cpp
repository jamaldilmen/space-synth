#include "core/particles.h"
#include <cmath>
#include <random>

namespace space {

void ParticleSystem::init(int count, float maxWaveDepth) {
  maxWaveDepth_ = maxWaveDepth;
  particles_.resize(count);

  std::mt19937 rng(42);
  // Thin-disk spawn for emergent accretion disk:
  //   xy: Gaussian σ=1.0  (wide spread in orbital plane)
  //   z:  Gaussian σ=0.10 (tight thickness — particles already on disk)
  // Combined with Keplerian tangential velocity below, orbits stay flat
  // in the xy plane → disk shape is visible from the start instead of
  // having to wait for friction to dissipate off-plane motion.
  std::normal_distribution<float> gaussXY(0.0f, 1.0f);
  std::normal_distribution<float> gaussZ(0.0f, 0.10f);

  // Initial conditions for emergent accretion disk:
  //   position: Gaussian cloud (existing "universe spawn")
  //   velocity: Keplerian tangential velocity in xy plane
  //
  // For circular orbit at radius r under gravity G/(r²+r0²):
  //   centripetal = gravity:  v²/r = G / (r² + r0²)
  //                           v   = sqrt(G·r / (r²+r0²))
  // At small r:  v → sqrt(G·r/r0²) ∝ sqrt(r)  → solid-body rotation
  // At large r:  v → sqrt(G/r)                → Keplerian falloff
  // Particles spawned far out have escape-or-orbit velocity matching
  // the local gravity → no runaway flight, no straight infall.
  //
  // Direction: perpendicular to position in xy plane, same handedness for
  // all particles (counter-clockwise looking down +z). All angular
  // momentum points +z → the disk emerges in the xy plane.
  //
  // Slight randomness on |v| (±15%) prevents perfect orbits and lets
  // friction settle off-plane particles toward the equatorial disk.
  const float G_grav = 1.0f;
  const float r0_soft = 0.5f;
  std::uniform_real_distribution<float> vJitter(0.85f, 1.15f);
  for (auto &p : particles_) {
    p.x = gaussXY(rng);
    p.y = gaussXY(rng);
    p.z = gaussZ(rng);

    float r_xy = std::sqrt(p.x * p.x + p.y * p.y);
    if (r_xy > 1e-4f) {
      float v_orbit = std::sqrt(G_grav * r_xy /
                                (r_xy * r_xy + r0_soft * r0_soft));
      v_orbit *= vJitter(rng);
      p.vx = -p.y / r_xy * v_orbit;
      p.vy =  p.x / r_xy * v_orbit;
    } else {
      p.vx = 0.0f;
      p.vy = 0.0f;
    }
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
    // Wall threshold bumped from 0.93 → 3.0 to match the Gaussian(σ=1.2)
    // spawn distribution. Old threshold (tuned for the pre-Phase-10 uniform
    // [-2,2] box spawn) made ~90% of particles invisible walls after Phase
    // 10's Gaussian rewrite, leaving the rest visual sparse and BH-less.
    // At 3.0 (~2.5σ), only the long Gaussian tail becomes static boundary.
    float invMass = (r3D > 3.0f) ? 0.0f : 1.0f;

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
