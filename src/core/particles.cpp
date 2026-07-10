#include "core/particles.h"
#include "core/imf.h"
#include "core/units.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <cstring>
#include <random>
#include <unordered_map>
#include <vector>

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
  // VOLUMETRIC 3D star map (NOT a thin disk — Jamal 2026-06-22): a filled rotating
  // cluster of ~2M stars orbiting the centre, like a real galaxy seen in 3D. Small
  // central hole (> r_inner) for the central mass / forming BH.
  // Cluster orbits the dominant central SMBH (Sgr A* 4.297e6 M☉, r_g≈3.6 sim,
  // ISCO≈22 sim). Inner edge OUTSIDE the ISCO so orbits are stable + sub-c
  // (v/c=√(r_g/r): 0.38c at r=25 → 0.20c at r=60). Volumetric, not a disk.
  // FILLED CENTRE (2026-07-10). r_inner was 25 → an empty ball of radius 25.
  // A uniform shell is LIMB-BRIGHTENED at its inner edge when projected: the
  // measured column density ran 167/area at screen centre up to 254 at rho=27
  // — a bright ring, which is what read as the "weird formation". It also
  // contradicted this function's own header ("centre-filled sphere, NOT the
  // old ring with an empty hole"). A filled ball projects brightest at the
  // middle. Still UNIFORM density — a real cluster is centrally concentrated
  // (King/Plummer); that is the next, separate change.
  const float r_inner   = 0.0f;   // diffuse star-map scale. NOTE (2026-06-30): too diffuse
  const float r_outer   = 60.0f;  // for collapse (gravity ~1e-6 of a light-step here); but a
                                  // dense spawn (r=3-10) just makes the cold-radial infall
                                  // slam through the centre WITHOUT gathering mass (seed stalls
                                  // ~50 M☉). The missing piece is dissipative ACCRETION, not a
                                  // smaller domain. See docs handoff 2026-06-30.
  std::uniform_real_distribution<float> u01(0.0f, 1.0f);
  std::uniform_real_distribution<float> phiDist(0.0f, 2.0f * (float)M_PI);

  // ── MIN-SEPARATION SPAWN (2026-07-08, Jamal: "open it. star map. period.
  // slow progression on mergers — not a blinking orange blob"). Random
  // placement at our density gives a mean neighbour gap (~0.42 sim) BELOW the
  // stellar contact radius (0.3 dwarf–dwarf, ~0.7 sun-pair): thousands of
  // stars spawned already touching → guaranteed merge storm + nova flashes in
  // the first seconds. Real clusters have no overlapping stars. Jittered
  // lattice: same ball, same mean density, but a HARD separation floor
  // (0.7·a ≈ 0.52 sim) so launch mergers are zero by construction and pair
  // contact only develops from real dynamics.
  // BLUE-NOISE dart throwing, not a lattice (2026-07-08: the jittered lattice
  // kept its crystal PLANES — visible as sliced-ball stripes on screen, Jamal's
  // pic. Dart throwing has no periodic structure by construction). Hash-grid
  // acceleration: cell = rMin, check 27 neighbours; points come out in random
  // order so no shuffle is needed. ~8% packing → acceptance stays high.
  std::vector<std::array<float, 3>> latticePts;
  {
    const float rIn = 0.0f, rOut = 60.0f; // must match r_inner/r_outer below
    // Min gap scaled to the REQUESTED density: this bakes the FULL buffer
    // (count = 10M, not the 2M live), and a fixed 0.4 gap at 10M is past
    // random-packing saturation — the spawn stalled for minutes (measured
    // 2026-07-08). 0.6× the mean spacing keeps acceptance high (~seconds)
    // and the resulting gap (0.26 @10M / 0.45 @2M) stays ≥4× every stellar
    // contact radius (max ~0.067 sim for a 10 M☉ star at MERGE_RSUN 0.01).
    const double shellVol =
        4.0 / 3.0 * M_PI * ((double)rOut * rOut * rOut - (double)rIn * rIn * rIn);
    const float rMin =
        std::min(0.4f, 0.6f * (float)cbrt(shellVol / std::max(count, 1)));
    const float cell = rMin;
    const int G = (int)std::ceil(2.0f * rOut / cell) + 2; // ~302 cells/axis
    auto cellIx = [&](float v) {
      return std::min(G - 1, std::max(0, (int)((v + rOut) / cell) + 1));
    };
    // Flat chained grid (no hashing, no per-cell heap): head[cell] → first
    // point index, next[i] → chain. 302³ ints ≈ 110 MB, freed after spawn.
    std::vector<int32_t> head((size_t)G * G * G, -1);
    std::vector<int32_t> next; next.reserve((size_t)count);
    latticePts.reserve((size_t)count);
    const uint64_t maxAttempts = (uint64_t)count * 60ull;
    uint64_t attempts = 0;
    while (latticePts.size() < (size_t)count && attempts < maxAttempts) {
      attempts++;
      float px = (2.0f * u01(rng) - 1.0f) * rOut;
      float py = (2.0f * u01(rng) - 1.0f) * rOut;
      float pz = (2.0f * u01(rng) - 1.0f) * rOut;
      float r2 = px * px + py * py + pz * pz;
      if (r2 < rIn * rIn || r2 > rOut * rOut) continue;
      int cx = cellIx(px), cy = cellIx(py), cz = cellIx(pz);
      bool ok = true;
      for (int dx = -1; dx <= 1 && ok; dx++)
        for (int dy = -1; dy <= 1 && ok; dy++)
          for (int dz = -1; dz <= 1 && ok; dz++) {
            size_t c = ((size_t)(cx + dx) * G + (size_t)(cy + dy)) * G + (size_t)(cz + dz);
            for (int32_t idx = head[c]; idx >= 0; idx = next[idx]) {
              float ddx = latticePts[idx][0] - px, ddy = latticePts[idx][1] - py,
                    ddz = latticePts[idx][2] - pz;
              if (ddx * ddx + ddy * ddy + ddz * ddz < rMin * rMin) { ok = false; break; }
            }
          }
      if (!ok) continue;
      size_t c = ((size_t)cx * G + (size_t)cy) * G + (size_t)cz;
      next.push_back(head[c]);
      head[c] = (int32_t)latticePts.size();
      latticePts.push_back({px, py, pz});
    }
    printf("[SPAWN] blue-noise: %zu/%d placed, %llu attempts (min gap %.2f)\n",
           latticePts.size(), count, (unsigned long long)attempts, rMin);
    fflush(stdout);
  }
  size_t latticeIdx = 0;

  for (auto &p : particles_) {
    // Uniform BOX, not a sphere → the field fills the frame CORNER-TO-CORNER
    // (no circular edge, no "tube"/radius limitation at rest). That tube only
    // belongs to the PLAY state (the Chladni cap reintroduces the disk when a
    // note is held); the open star map has no such limit.
    (void)r_inner;
    const float boxL = r_outer;  // half-extent of the star-field box
    // VOLUMETRIC 3D BALL (not a box), minus a small central hole. Rejection-
    // sample the box and KEEP only points with r_inner ≤ r ≤ r_outer. The old
    // code sampled the box but only rejected the inner hole, so the box CORNERS
    // reached r = √(boxL²·3) ≈ 104 — far beyond halfExtent (64). Those corner
    // stars spawned already outside the domain and "vanished into nothingness"
    // (2026-06-25, Jamal). A true ball of radius r_outer=60 < 64 keeps every
    // star inside the domain; the circular spawn velocity (v⊥r, |v|=√(GM/r))
    // then holds them on bound orbits that never exceed their spawn radius.
    // This matches the stated intent at the top of this function ("uniform
    // density in the ball").
    float rr2;
    if (latticeIdx < latticePts.size()) {
      // Jittered-lattice site: hard min-separation, no spawn contacts.
      p.x = latticePts[latticeIdx][0];
      p.y = latticePts[latticeIdx][1];
      p.z = latticePts[latticeIdx][2];
      latticeIdx++;
      rr2 = p.x * p.x + p.y * p.y + p.z * p.z;
    } else {
      // Lattice exhausted (discretization shortfall, few thousand at most):
      // fall back to the old rejection sample for the remainder.
      do {
        p.x = (2.0f * u01(rng) - 1.0f) * boxL;
        p.y = (2.0f * u01(rng) - 1.0f) * boxL;
        p.z = (2.0f * u01(rng) - 1.0f) * boxL;
        rr2 = p.x * p.x + p.y * p.y + p.z * p.z;
      } while (rr2 < r_inner * r_inner || rr2 > r_outer * r_outer);
    }

    // KEPLERIAN rest velocity: each star starts on a circular orbit about +Y
    // around the cluster's mass centre (≈ origin at spawn), v_circ = √(GM/r).
    // This is what makes rest = ORBITS instead of radial plunge: without
    // tangential velocity every star falls straight through the centre.
    // Same sense as the old rigid rotation (v ∝ (z, 0, −x)) and the home-pin
    // spin. Stored in per-FRAME displacement units (×kDt) — the shader's
    // Verlet velocity proxy is displacement-per-frame.
    // GM of the whole field, DERIVED from the Sgr A* anchor + time-lapse
    // (units.h) — same expression the renderer uploads as gravGM, so spawn
    // orbits exactly match the gravity they live in. Field mass = Σ of the
    // real per-star IMF masses (mean ≈ 0.30 M_sun), not N×1.
    static double sTotalMass = 0.0;
    static int sTotalMassCount = -1;
    if (sTotalMassCount != count) {
      sTotalMass = imf::totalMassMsun(count);
      sTotalMassCount = count;
    }
    const float kGM = (float)units::gmSim(sTotalMass);
    const float kDt = 1.0f / 120.0f;
    float r3 = std::sqrt(p.x * p.x + p.y * p.y + p.z * p.z);
    float lxz = std::sqrt(p.x * p.x + p.z * p.z);
    // ENCLOSED-MASS circular velocity (2026-06-13 audit, step 3). The old
    // v=√(GM_total/r) treated ALL the field mass as interior to every star —
    // true only for a point mass. The spawn is a uniform BOX, so the mass
    // actually inside radius r is ≈ M_total·(r/R)³. Using the full mass made
    // the inner stars (where enclosed mass ≈ 0) hugely over-sped → they flew
    // outward and the whole map slowly drifted/heated outward at rest (the
    // leak the rest friction was masking; measured: meanR climbing with
    // amp=0). Correct law: v ∝ r inside the cluster (solid-body rotation of a
    // bound cluster), Keplerian only in the sparse tail outside it. Continuous
    // at r=R (both give √(GM/R) there).
    const float Rc = boxL;                       // cluster scale (box half-extent)
    // HARD-CODED CENTRAL SMBH (Sgr A* = 4.297e6 M☉) at the origin — the dominant
    // mass the cluster orbits (must MATCH the shader's u.centerGM). v_circ is the
    // Keplerian speed around (central SMBH + the field mass interior to r), so
    // spawn orbits exactly balance the gravity the stars live in → clean fast
    // circular orbits instead of radial plunge.
    // SELF-BOUND spawn (2026-06-26): velocity from the FIELD's OWN gravity only.
    // The old `kCenterGM + fieldEncGM` sized the orbit for the 4.3e6 M☉ central
    // SMBH; with that crutch toggled OFF (the real-physics base), only the weak
    // field self-gravity remains, so the over-sped cluster flew apart (meanR
    // 60→660, unbound, never collapses). Using fieldEncGM alone (enclosed mass
    // ∝ r³ inside the uniform ball → solid-body v∝r) makes the cluster bound by
    // its OWN mass — the scale is now self-consistent, so gravity can hold and
    // collapse it toward a real geometric horizon. Jamal: "scale must be correct".
    float fieldEncGM = (r3 < Rc) ? kGM * (r3 * r3 * r3) / (Rc * Rc * Rc) : kGM;
    // COLD / SUB-VIRIAL spawn (2026-06-26): 0.3× the circular speed. At full
    // v_circ the cluster still EXPANDED (the real grid+softening force is weaker
    // than this smooth-r³ estimate → effectively super-virial → unbound). A
    // sub-virial cloud lets self-gravity WIN: it collapses inward, density
    // climbs, and at the anchored scale a crushed core reaches r_s ≥ radius = a
    // real geometric horizon. This is the honest "gravity does its thing →
    // core collapse → black hole" (Jamal). Factor tunable; lower = colder/faster.
    const float kColdFactor = 0.05f; // near-radial: kill rotation so it collapses
                                     // to the centre (no centrifugal ring) → the
                                     // whole field crushes to ~1 sim where
                                     // r_s(field)=1 ≥ radius = a real horizon.
    float vmag = std::sqrt(fieldEncGM / std::max(r3, 0.5f)) * kDt * kColdFactor;
    if (lxz > 1e-4f) {
      p.vx =  vmag * p.z / lxz;
      p.vy =  0.0f;
      p.vz = -vmag * p.x / lxz;
    } else {
      p.vx = 0.0f; p.vy = 0.0f; p.vz = 0.0f; // polar axis: radial orbit
    }
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
    // posW.w = the star's REAL stellar mass in M_sun (Kroupa IMF, the same
    // per-id draw the render uses for size/brightness/colour — see imf.h).
    // 0.0 still marks a static wall. This is the mass the self-gravity
    // weighs and the mass mergers will transfer: the US2 "eating" currency.
    float starMass = (r3D > 150.0f) ? 0.0f : imf::massOfId((uint32_t)i);

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
        starMass, // posW.w = stellar mass in M_sun (0.0 = static wall)
        p.vx,
        p.vy,
        p.vz,
        0.0f, // vel + phase
        // prevPos seeded one step BEHIND the Keplerian orbit velocity: the
        // shader's Störmer-Verlet derives velocity from (pos − prev), so this
        // is how spawn velocity actually enters the physics (velW above is
        // never read by compute_physics). vx/vy/vz are per-frame units.
        p.x - p.vx,
        p.y - p.vy,
        p.z - p.vz,
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
