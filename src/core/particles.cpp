#include "core/particles.h"
#include <cmath>
#include <random>

namespace space {

void ParticleSystem::init(int count, float maxWaveDepth) {
  maxWaveDepth_ = maxWaveDepth;
  particles_.resize(count);

  std::mt19937 rng(42);
  // Explicit ring spawn for the accretion disk:
  //   radius r ~ uniform[r_inner, r_outer]  with r_inner > BH_HORIZON
  //   angle  φ ~ uniform[0, 2π)
  //   z      ~ Gaussian σ=0.05 (thin disk)
  // Previously used Cartesian Gaussian σ=1, which put ~85% of particles
  // INSIDE the horizon (r<1.14) — those got culled and the visible ones
  // were a scattered halo. Explicit ring puts every particle OUTSIDE the
  // horizon and tangentially-velocitied for stable orbit at that radius.
  //
  // Must match `G` and `BH_HORIZON` in particles.metal — gravity, orbital
  // velocity, and spawn radius all need to agree or particles spawn
  // off-balance and either fall in or fly out.
  const float G_grav    = 100.0f;  // matches particles.metal G
  const float r0_soft   = 0.1f;    // matches particles.metal r0
  const float r_inner   = 0.75f;  // just outside BH_HORIZON = 0.57
  const float r_outer   = 3.0f;   // disk extent — inner edge hugs the BH,
                                  // outer keeps shapes ≤ ~5× the horizon
  const float z_sigma   = 0.05f;  // thin disk
  // CRITICAL: the integrator stores velocity as per-FRAME displacement and
  // gravity adds gMag·dt per frame. With gravity gMag = G/(r+r0) (flat
  // rotation curve, matches particles.metal), a stable circular orbit needs
  //   v_frame² / r = gMag · dt   ⇒   v_frame = sqrt(G·r·dt/(r+r0))
  // The dt factor is essential — omitting it spawns velocity ~11× too fast.
  const float kDt = 1.0f / 120.0f; // assume ~120 fps; matches Renderer dt
  std::uniform_real_distribution<float> rDist(r_inner, r_outer);
  std::uniform_real_distribution<float> phiDist(0.0f, 2.0f * (float)M_PI);
  std::normal_distribution<float> zDist(0.0f, z_sigma);
  std::uniform_real_distribution<float> vJitter(0.95f, 1.05f);
  for (auto &p : particles_) {
    float r   = rDist(rng);
    float phi = phiDist(rng);
    float cf  = std::cos(phi);
    float sf  = std::sin(phi);
    p.x = r * cf;
    p.y = r * sf;
    p.z = zDist(rng);

    // Per-frame tangential velocity for a stable circular orbit
    // under 1/(r+r0) gravity: v_frame = sqrt(G·r·dt/(r+r0)).
    float v_orbit = std::sqrt(G_grav * r * kDt / (r + r0_soft));
    v_orbit *= vJitter(rng);   // ±5% jitter — slight eccentricity
    // Counter-clockwise around +z: tangent = (-sin φ, cos φ, 0)
    p.vx = -sf * v_orbit;
    p.vy =  cf * v_orbit;
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

    // Bruneton-style analytic orbit parameters, stored per-particle.
    // r_home: orbital radius set at spawn (sim coords)
    // phi_offset: angle at t=0, so particle is at angle (phi_offset + ω·t)
    // These are used by the compute shader to compute an analytic target
    // position each frame; particles smoothly lerp toward this target
    // (recovery from voice perturbations is automatic — no integration drift).
    // Stored in spinW.x, spinW.y (spinW is only used by collisions which
    // default OFF).
    float r_home    = std::sqrt(p.x * p.x + p.y * p.y);
    float phi_offset = std::atan2(p.y, p.x);

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
        phi_offset,
        0.0f,
        1.0f,                                // spinW = (r_home, phi_offset, 0, charge=1)
        (uint32_t)(rand() % system.count()), // entanglementID
        0,
        0,
        0 // padding
    };
  }
  return gpu;
}

} // namespace space
