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

  // ── GALAXY-DISK SPAWN (2026-07-15, Jamal: "currently it's a space Dyson —
  // it just sucks in every particle. The orbit should be so violently fast
  // that the light-speed trails of the particles surround the black hole.")
  // MEASURED why the sphere can never deliver that: spherical cold collapse
  // violently relaxes — v_rot/σ came out 0.078 (net L exactly on +y, buried
  // 13:1 under random motion) → a pressure-supported spheroid, radial plunge,
  // no queue at the horizon, no plasma rim, no body. Matter with dominant
  // coherent L physically CANNOT cross r_h without queuing — the queue IS the
  // bright inner disk. So the initial conditions are now disk-dominant (real
  // observed galaxies already are; we skip the 10-Gyr assembly exactly like
  // we choose a spawn seed):
  //   75% THIN DISK  — x–z plane (L about +y, same axis as before), surface
  //                    density ∝ r^0.7 draw (denser inward), Gaussian height
  //                    4% flare; near-circular orbits at 0.95 support + 4%
  //                    random dispersion (v_rot/σ ≈ 20 at spawn — every new
  //                    ordered structure ships WITH its noise, failure-ledger
  //                    rule).
  //   10% NUCLEUS    — Plummer a=1.5 truncated at 6, 0.30 support: collapses
  //                    in minutes, fires the honest horizon, then eats the
  //                    disk's queued inner edge.
  //   15% HALO       — the old Plummer a=15 sphere: the sky backdrop that
  //                    the shadow occludes and the lens bends.
  // v_circ from the COMPOSITE enclosed-mass profile below (not the uniform-
  // ball r³ estimate — that mismatch is what unbound full-support spawns).
  // ── (previous) PLUMMER-SPHERE SPAWN (2026-07-10) ────────────────────────
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
  const float A_PLUMMER = 15.0f;   // halo scale (the sky component)
  const float A_NUC     = 1.0f;    // nucleus Plummer scale (the hole fuel)
  const float R_NUC     = 3.0f;    // nucleus truncation
  const float R_DISK    = 18.0f;   // disk edge — SIZED TO THE CAMERA (2026-07-15:
                                   // the ortho view spans ±4.8 sim at default rho,
                                   // ±24 at max zoom-out; the first cut at 45 was
                                   // 10× wider than the window — the galaxy was
                                   // never on screen. 18 = fully visible zoomed
                                   // out, hub fills the default view; inner disk
                                   // sits inside the AMR fine box + r<5 probes).
  const float F_DISK = 0.75f, F_NUC = 0.10f;   // remainder = halo
  std::normal_distribution<float> gauss(0.0f, 1.0f);

  int nDisk = 0, nNuc = 0, nHalo = 0;
  for (auto &p : particles_) {
    (void)r_inner;
    const float boxL = r_outer;  // cluster scale (kept: Rc reference below)
    // ── COMPONENT DRAW ───────────────────────────────────────────────────
    float sel = u01(rng);
    int component;                    // 0 = disk, 1 = nucleus, 2 = halo
    if (sel < F_DISK) component = 0;
    else if (sel < F_DISK + F_NUC) component = 1;
    else component = 2;
    if (component == 0) {
      // THIN DISK in x–z: r ~ R_DISK·u^{1/1.7} (density ∝ r^-0.3, denser
      // inward; enclosed-mass CDF = (r/R)^1.7 used for v_circ below).
      // ORGANIC CHARACTER (2026-07-15 23:53, Jamal: "too circular, too flat,
      // too slice-of-a-ball"): perfect circles at uniform support read as
      // drawn concentric rings. Real disks are messy —
      //   · lognormal radial jitter (±8%) breaks the ring banding,
      //   · stronger flare + a base thickness kills the razor slice,
      //   · a gentle m=2 warp (5°, radius-dependent phase) tilts the plane
      //     organically instead of a perfect flat cut.
      // (Eccentricity spread lives in the VELOCITY block below.)
      // PLATE-PLANE ALIGNMENT (2026-07-16, Jamal item 4): the default camera
      // sits on +Z (screen plane = x-y) and the Chladni plate lives in x-y —
      // the disk was x-z (about y) = edge-on 90-degrees off the plate at
      // launch. The whole BH world now orbits about Z: disk in the PLATE
      // plane, face-on at launch, aligned with the circle he sees on play.
      float rr = R_DISK * std::pow(u01(rng), 1.0f / 1.7f);
      rr *= std::exp(0.08f * gauss(rng));            // radial clumping
      rr = std::min(rr, R_DISK * 1.15f);
      float ph = phiDist(rng);
      float h  = 0.30f + 0.06f * std::max(rr, 2.0f); // thicker, flared
      // WARP KILLED (2026-07-17, "it still renders as two rings"): the m=1
      // vertical corrugation 0.09·rr·sin(ph+0.15rr) was the ONLY z(φ,r) term.
      // The time-lapse playback spins each radius at Ω∝r^-1.5 (differential),
      // so the corrugation WOUND UP into a helix → two z-separated rings +
      // the connecting strand he sees (present since before the lens existed,
      // so not a lens artifact). Flat plane → differential rotation makes an
      // in-plane spiral (disk-like), not a vertical helix.
      p.x = rr * std::cos(ph);
      p.y = rr * std::sin(ph);
      p.z = h * gauss(rng);
      nDisk++;
    } else if (component == 1) {
      // NUCLEAR DISK (2026-07-16, Jamal: the hole rim was "still just a
      // white-ish circle" from EVERY angle — an isotropic nucleus rains in
      // from all directions, so the matter queuing at r_h forms a spherical
      // SHELL, and a shell limb-brightens into a circle no matter where the
      // camera is — the documented shell-ring artifact. The queue only reads
      // as an accretion structure — band edge-on, ring face-on — if the
      // near-hole matter shares the disk's PLANE.) Plummer radial profile,
      // FLATTENED ×0.30 in y, same rotation axis as the main disk.
      const double ro = (double)R_NUC / A_NUC;
      const double mMax = ro * ro * ro / std::pow(1.0 + ro * ro, 1.5);
      double m = (double)u01(rng) * mMax;
      double rr = (double)A_NUC / std::sqrt(std::pow(m, -2.0 / 3.0) - 1.0);
      if (!(rr <= (double)R_NUC)) rr = (double)R_NUC;
      double cosT = 2.0 * (double)u01(rng) - 1.0;
      double sinT = std::sqrt(std::max(0.0, 1.0 - cosT * cosT));
      double ph = (double)phiDist(rng);
      p.x = (float)(rr * sinT * std::cos(ph));
      p.y = (float)(rr * sinT * std::sin(ph));
      p.z = (float)(rr * cosT) * 0.30f;               // flatten: nuclear disk (plate plane)
      nNuc++;
    } else {
      // HALO: the old Plummer a=15 sky, truncated at r_outer.
      const double ro = (double)r_outer / A_PLUMMER;
      const double mMax = ro * ro * ro / std::pow(1.0 + ro * ro, 1.5);
      double m = (double)u01(rng) * mMax;
      double rr = (double)A_PLUMMER / std::sqrt(std::pow(m, -2.0 / 3.0) - 1.0);
      if (!(rr <= (double)r_outer)) rr = (double)r_outer;
      double cosT = 2.0 * (double)u01(rng) - 1.0;
      double sinT = std::sqrt(std::max(0.0, 1.0 - cosT * cosT));
      double ph = (double)phiDist(rng);
      p.x = (float)(rr * sinT * std::cos(ph));
      p.y = (float)(rr * cosT);
      p.z = (float)(rr * sinT * std::sin(ph));
      nHalo++;
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
    (void)Rc;
    // COMPOSITE ENCLOSED MASS at r3 (matches the three components drawn
    // above — v_circ from the mass the star actually orbits inside):
    //   disk  CDF (r/R_DISK)^1.7, nucleus + halo Plummer m(r) = r³/(r²+a²)^{3/2}
    auto plumEnc = [](float r, float a, float rt) {
      double ro = (double)rt / a;
      double mMax = ro * ro * ro / std::pow(1.0 + ro * ro, 1.5);
      double x = (double)r / a;
      double m = x * x * x / std::pow(1.0 + x * x, 1.5);
      return (float)(std::min(m, mMax) / mMax);   // fraction of the component
    };
    float encFrac =
        F_DISK * std::min(std::pow(r3 / R_DISK, 1.7f), 1.0f) +
        F_NUC  * plumEnc(r3, A_NUC, R_NUC) +
        (1.0f - F_DISK - F_NUC) * plumEnc(r3, A_PLUMMER, r_outer);
    float fieldEncGM = kGM * encFrac;
    // Per-component support (why: v_rot/σ measured 0.078 for the sphere —
    // spheroid, no queue, no rim; see the header note):
    //   disk 0.95 near-circular (+4% dispersion), nucleus 0.30 (collapses →
    //   fires the horizon), halo 0.90 (holds as the sky).
    // Nucleus support raised 0.30 → 0.55 with the flattening: it still sinks
    // and fires the horizon in minutes, but arrives WITH the disk's spin so
    // the queue is planar, not a shell.
    // DISK SUPPORT 0.95 → 0.99 (2026-07-17, "fix the collapse"): at 0.95 the
    // disk was 5% sub-circular → 75% of the mass fell inward, overshot, and
    // BOUNCED (measured: hollow gap r=1–3 empty, inner core vr=+0.015 outward,
    // disk puffed 0.5→3.6 = thick 1.9:1 rings, not the NASA razor disk). Near-
    // circular (0.99) keeps the disk ORBITING in-plane as a thin sheet; the
    // nucleus (0.55) still sinks and fires the hole → thin disk + central hole,
    // the reference structure. Inflow becomes viscous (LTRANS), not a plunge.
    float support = (component == 0) ? 0.99f : (component == 1) ? 0.55f : 0.90f;
    float vc = std::sqrt(fieldEncGM / std::max(r3, 0.5f)) * kDt;
    float vmag = vc * support;
    float lxy = std::sqrt(p.x * p.x + p.y * p.y);
    if (lxy > 1e-4f) {
      // Orbit about +Z (plate plane), sense = the Keplerian playback's
      // counter-clockwise (+z x r): v = omega*(-y, x, 0).
      p.vx = -vmag * p.y / lxy;
      p.vy =  vmag * p.x / lxy;
      p.vz =  0.0f;
    } else {
      p.vx = 0.0f; p.vy = 0.0f; p.vz = 0.0f; // polar axis: radial orbit
    }
    if (component == 0) {                       // disk dispersion: 4% of v_circ,
      float sig = 0.04f * vc;                   // isotropic — ordered structure
      p.vx += sig * gauss(rng);                 // ships WITH its noise
      p.vy += sig * gauss(rng);
      p.vz += sig * gauss(rng);
      // ECCENTRICITY SPREAD (the organic-character other half): per-star
      // support jitter ±8% → a mix of slightly plunging / slightly apo-going
      // ellipses instead of one perfect circular sheet.
      // Review fix 2026-07-17: disk now orbits in the x–y plane (vz=0);
      // jittering vx+vz was azimuth-biased (only the x-component scattered).
      // Scale the full tangential velocity → clean eccentricity at any φ.
      float ecc = 0.08f * gauss(rng);
      p.vx *= (1.0f + ecc);
      p.vy *= (1.0f + ecc);
    }
  }
  printf("[SPAWN] galaxy-disk: %d disk / %d nucleus / %d halo (R_disk=%.0f, "
         "a_nuc=%.1f, a_halo=%.0f)\n",
         nDisk, nNuc, nHalo, R_DISK, A_NUC, A_PLUMMER);
  fflush(stdout);
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
