#include "core/particles.h"
#include <cmath>
#include <cstring>
#include <random>

namespace space {

void ParticleSystem::init(int count, float maxWaveDepth) {
  maxWaveDepth_ = maxWaveDepth;
  particles_.resize(count);

  std::mt19937 rng(42);
  // ── STAR-MAP REST SPAWN: a FILLED 3D star cluster (not a flat disk) ──────
  // The rest/silence state is a STAR MAP — an isotropic, centre-filled sphere
  // of stars — NOT the old thin accretion-disk ring with an empty hole (that
  // read as a black hole at rest). Each particle gets:
  //   radius r ~ volumetric in [r_inner, r_outer]  (uniform density in the ball)
  //   direction ~ isotropic on the unit sphere (theta, phi)
  // The 3D home (r, theta, phi) is stored per-particle (see packForGPU) so the
  // compute shader can hold each star at its fixed home + slowly rotate the
  // whole map as a rigid body — calm star-cluster motion. The BH only forms
  // later, on the release/collapse phase. Was: ring (r_inner 0.75, z σ=0.05).
  const float r_inner   = 0.15f;  // small core so the CENTRE is filled
  const float r_outer   = 42.0f;  // box larger than the camera POV incl. the
                                  // diagonal corners. Play squeezes it inward to
                                  // the Chladni cap; release collapses.
  std::uniform_real_distribution<float> u01(0.0f, 1.0f);
  std::uniform_real_distribution<float> phiDist(0.0f, 2.0f * (float)M_PI);
  for (auto &p : particles_) {
    // Uniform BOX, not a sphere → the field fills the frame CORNER-TO-CORNER
    // (no circular edge, no "tube"/radius limitation at rest). That tube only
    // belongs to the PLAY state (the Chladni cap reintroduces the disk when a
    // note is held); the open star map has no such limit.
    (void)r_inner;
    const float boxL = r_outer;  // half-extent of the star-field box
    p.x = (2.0f * u01(rng) - 1.0f) * boxL;
    p.y = (2.0f * u01(rng) - 1.0f) * boxL;
    p.z = (2.0f * u01(rng) - 1.0f) * boxL;

    // Gentle rigid-rotation velocity about +Y (matches the slow whole-map
    // spin the shader applies at rest), so play perturbations start coherent.
    const float omega_slow = 0.08f; // rad/s, matches particles.metal rest spin
    const float kDt = 1.0f / 120.0f;
    // v = ω × r,  ω = (0, omega_slow, 0)  ⇒  v = omega·(z, 0, −x)
    p.vx =  omega_slow * p.z * kDt;
    p.vy =  0.0f;
    p.vz = -omega_slow * p.x * kDt;
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
    float invMass = (r3D > 80.0f) ? 0.0f : 1.0f; // star map has no wall (box reaches r≈73)

    // STAR-MAP home, stored per-particle: the fixed 3D point each star holds
    // at rest. The compute shader reconstructs home = r·(sinθcosφ, sinθsinφ,
    // cosθ) and applies a slow rigid rotation of the whole map. Stored as:
    //   spinW.x   = r_home   (radius)
    //   pad2/pad3 = theta, phi  (isotropic direction angles, float bits)
    // pad2/pad3 (entanglement.z/.w) are free — hardness uses .y, partner .x.
    float r_home = r3D;
    float cosTh  = (r3D > 1e-6f) ? (p.z / r3D) : 1.0f;
    cosTh        = cosTh < -1.0f ? -1.0f : (cosTh > 1.0f ? 1.0f : cosTh);
    float theta  = std::acos(cosTh);
    float aphi   = std::atan2(p.y, p.x);
    auto f2u = [](float f) { uint32_t u; std::memcpy(&u, &f, sizeof(u)); return u; };

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
        r_home,
        0.0f,
        0.0f,
        1.0f,                                // spinW = (r_home, 0, 0, charge=1)
        (uint32_t)(rand() % system.count()), // entanglementID
        0,            // pad1 (hardness at runtime)
        f2u(theta),   // pad2 = star-map home theta
        f2u(aphi)     // pad3 = star-map home phi
    };
  }
  return gpu;
}

} // namespace space
