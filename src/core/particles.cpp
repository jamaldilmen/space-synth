#include "core/particles.h"
#include "core/imf.h"
#include "core/units.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <random>
#include <unordered_map>
#include <vector>

namespace space {

void ParticleSystem::init(int count, float maxWaveDepth) {
  maxWaveDepth_ = maxWaveDepth;
  particles_.resize(count);

  // 🔬 TEMP-DIAG SS_SPAWN_SEED (2026-07-15, second-z-seeder hunt): the dead bed
  // carries a deterministic z-comb at fixed centers across runs; a different
  // spawn seed decides realization-noise (centers MOVE) vs grid mechanism
  // (centers STAY). Default 42 = every existing bed byte-identical.
  unsigned spawnSeed = 42u;
  if (const char *ss = getenv("SS_SPAWN_SEED")) spawnSeed = (unsigned)atoi(ss);
  std::mt19937 rng(spawnSeed);
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

  // ── PLUMMER-SPHERE SPAWN (2026-07-10) ──────────────────────────────────
  // Was: uniform-density ball placed by blue-noise dart-throwing. That gave a
  // FLAT profile with a HARD edge at r_outer — a filled sphere, not a cluster —
  // and the min-separation dart-throw made the texture ANTI-clustered
  // (measured sigma/mean 0.37 vs 0.52 for pure random), reading as an even
  // grain rather than a sky. It also cost ~37M dart attempts + a ~400 MB grid
  // per launch.
  //
  // A self-gravitating cluster with NO dominant central point mass (our central
  // SMBH toggle is OFF; the field is bound by its own PM self-gravity) relaxes
  // to the Plummer sphere, rho(r) = rho0 (1 + r^2/a^2)^(-5/2) — THE standard
  // equilibrium (Plummer 1911; Aarseth, Henon & Wielen 1974 sampling). It is
  // centrally concentrated AND has no edge: density falls smoothly to zero, so
  // the r=60 wall disappears on its own.
  //
  // Sampled by EXACT inverse-CDF, no rejection: the enclosed-mass fraction
  // m(r) = r^3/(r^2+a^2)^(3/2) inverts to r = a / sqrt(m^(-2/3) - 1). Drawing m
  // uniform in (0, m(r_outer)) truncates at the domain with zero waste. Angles
  // isotropic. Result is naturally POISSON (no anti-clustering) and O(N).
  // A_PLUMMER sets concentration: half-mass radius = 1.305*a. a=15 -> half-mass
  // ~19.6, ~91% of the untruncated mass inside r_outer=60.
  const float A_PLUMMER = 15.0f;
  std::vector<std::array<float, 3>> latticePts;
  {
    const double ro = (double)r_outer / A_PLUMMER;
    const double mMax = ro * ro * ro / std::pow(1.0 + ro * ro, 1.5); // mass frac within r_outer
    latticePts.reserve((size_t)count);
    for (int i = 0; i < count; i++) {
      double m = (double)u01(rng) * mMax;                    // enclosed-mass fraction, truncated
      double rr = (double)A_PLUMMER / std::sqrt(std::pow(m, -2.0 / 3.0) - 1.0);
      if (!(rr <= (double)r_outer)) rr = (double)r_outer;    // guard the m->mMax float edge
      double cosT = 2.0 * (double)u01(rng) - 1.0;            // isotropic cos(theta)
      double sinT = std::sqrt(std::max(0.0, 1.0 - cosT * cosT));
      double phi = (double)phiDist(rng);
      latticePts.push_back({(float)(rr * sinT * std::cos(phi)),
                            (float)(rr * cosT),
                            (float)(rr * sinT * std::sin(phi))});
    }
    printf("[SPAWN] Plummer: %zu placed, a=%.1f, half-mass=%.1f, %.0f%% mass within r_outer\n",
           latticePts.size(), A_PLUMMER, 1.305f * A_PLUMMER, 100.0 * mMax);
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
