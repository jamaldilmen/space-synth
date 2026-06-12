#pragma once

// ── REAL UNITS — the Sgr A* anchor (single source of truth) ─────────────────
// Geometry: 1 sim unit = 2 gravitational radii of Sgr A*.
//   M_BH = 4.297e6 M_sun (GRAVITY collaboration)
//   r_g  = G·M_BH/c² = 6.345e9 m = 0.0424 AU  →  1 sim unit = 1.269e10 m
// Mass: 1 particle = 1 M_sun (a nuclear-star-cluster star).
// Time: TIME-LAPSE — 1 on-screen second = kTimeLapse real seconds.
//   Accelerating time by K is exact (a·t² invariance): every GM is multiplied
//   by K². K = 130 chosen so:
//     · ISCO (6 r_g = 3 sim units) orbital period: 32.6 real min → ~15 s on screen
//     · untouched 2M-star cluster free-fall from r≈40 → ~3 min on screen
// Everything dynamical derives from these four numbers — no tuned-by-feel GM.

namespace space {
namespace units {

inline constexpr double kGMsunSI    = 1.32712440018e20; // G·M_sun, m³/s² (IAU)
inline constexpr double kMbhMsun    = 4.297e6;          // Sgr A*, solar masses
inline constexpr double kUnitMeters = 1.269e10;         // 2 r_g of Sgr A*, in m
inline constexpr double kTimeLapse  = 400.0;            // real seconds per on-screen second
// 130 → 400 (2026-06-12): the 2-MINUTE ARC. Gravity ∝ K², so the global
// infall compresses ~9.5× — free-fall from the spawn radius lands near the
// spec (star map → hole ≤ 2 min at rest). Spawn orbits derive from the same
// constant, so they stay circular; ISCO period on screen drops to ~1.6 s
// (fast inner spin — the disk look wants this anyway).

// G·M_sun in sim units (sim³/s², REAL time): ≈ 6.49e-11
inline constexpr double kGMsunSim =
    kGMsunSI / (kUnitMeters * kUnitMeters * kUnitMeters);

// G·M in sim units under the time-lapse, for a mass of mSun solar masses.
// Use this for every gravitational coupling in the simulation.
inline constexpr double gmSim(double mSun) {
  return mSun * kGMsunSim * kTimeLapse * kTimeLapse;
}

// ── Geometric black-hole criterion (Step 2/3) ──
// Schwarzschild radius per solar mass, in sim units:
//   r_s(M) = 2GM/c² → 2953 m per M_sun → / kUnitMeters
// A region of enclosed mass M inside radius R IS a black hole when
// r_s(M) ≥ R. bhStrength = r_s(M_enc)/kREnc is the 0..1 "how close is the
// core to being a hole" signal; lensing scales with it, the shadow appears
// near 1. Full collapse of a 2e6-star field gives ≈ 0.93 — physically, our
// 6.7%-of-the-cluster field is *just* shy of forming a Sgr A*; the strength
// gate at 0.9 honours the enclosure-resolution limit.
inline constexpr double kCsqSI       = 8.987551787e16;  // c², m²/s²
inline constexpr double kRsSimPerMsun = 2.0 * kGMsunSI / kCsqSI / kUnitMeters; // ≈ 2.327e-7
inline constexpr double kREnc        = 0.5;             // enclosure radius, sim units

} // namespace units
} // namespace space
