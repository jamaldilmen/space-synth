#pragma once

// ── REAL UNITS — the CONSERVATION anchor (single source of truth) ───────────
// 2026-06-13 RE-ANCHOR (Jamal: "science executed masterfully, no cheats").
// The old anchor was Sgr A* (4.297e6 M_sun) — but we are NOT simulating Sgr A*;
// we simulate a fixed mass BUDGET (the IMF field, ≈594k M_sun at 2M particles)
// that shape-shifts between a star map and a black hole. The established
// conservation model IS: field mass = the black hole's mass. So the natural
// length unit is set by THAT mass, not an unrelated SMBH:
//   Geometry: 1 sim unit = 2 gravitational radii of the FIELD's own mass.
//     M_field ≈ 5.94e5 M_sun  →  2·r_g = 2·G·M_field/c² = 1.7552e9 m.
//     ⇒ r_s(M_field) = 1.0 sim unit exactly: the whole budget, fully crushed,
//       IS a one-unit black hole. A collapsed CORE of mass m has the honest
//       r_s = (m/M_field) units — a real, resolvable, viewable horizon, NOT a
//       0.003-of-the-field speck (the Sgr A* anchor's artifact, which made the
//       physically-inevitable pressureless collapse read as "not a hole").
//   No magnification: the shadow is still the REAL 2.6·r_s of the REAL mass —
//   we only chose the unit scale to match the system we actually simulate.
// Mass: 1 particle = 1 M_sun (IMF-sampled). Time: TIME-LAPSE (below).
//   The DYNAMICS are deliberately UNCHANGED by this re-anchor: gmSim (the only
//   thing the integrator sees) is held constant by re-deriving kTimeLapse, so
//   the collapse/orbits behave exactly as before — only the r_s INTERPRETATION
//   (and thus the criterion + shadow size) moves to the honest scale.
// Everything dynamical derives from these four numbers — no tuned-by-feel GM.

namespace space {
namespace units {

inline constexpr double kGMsunSI    = 1.32712440018e20; // G·M_sun, m³/s² (IAU)
inline constexpr double kMbhMsun    = 5.94276e5;        // FIELD mass (≈2M particles × IMF mean 0.30) — the conservation anchor
inline constexpr double kUnitMeters = 1.7552e9;         // 2 r_g of the field mass, in m
inline constexpr double kTimeLapse  = 20.58;            // chosen so gmSim is UNCHANGED vs the old anchor (dynamics invariant)
// Re-anchor arithmetic (2026-06-13): kUnitMeters shrank ×7.23 (1.269e10→1.7552e9),
// so kGMsunSim = kGMsunSI/kUnitMeters³ grew ×378. To keep gmSim = kGMsunSim·K²
// IDENTICAL (so the integrator behaves exactly as before), K drops 400→20.58
// (20.58² ≈ 423 ≈ 400²/378). Net: same gravity, same collapse, same orbits;
// only r_s/length INTERPRETATION re-anchored. kRsSimPerMsun grows 2.327e-7→
// 1.6825e-6 (×7.23) → the gathered core mass now reads as a real horizon.

// G·M_sun in sim units (sim³/s², REAL time): ≈ 6.49e-11
inline constexpr double kGMsunSim =
    kGMsunSI / (kUnitMeters * kUnitMeters * kUnitMeters);

// G·M in sim units under the time-lapse, for a mass of mSun solar masses.
// Use this for every gravitational coupling in the simulation.
inline constexpr double gmSim(double mSun) {
  return mSun * kGMsunSim * kTimeLapse * kTimeLapse;
}

// ── Geometric black-hole criterion ──
// Schwarzschild radius per solar mass, in sim units:
//   r_s(M) = 2GM/c² → 2953 m per M_sun → / kUnitMeters
// A region of enclosed mass M inside radius R IS a black hole when r_s(M) ≥ R
// (the real geometric criterion, no fraction cheat). bhStrength = r_s(M_enc)/
// kREnc is the 0..1 "how close is the core to a horizon" signal; lensing scales
// with it, the shadow appears at 1. Under the conservation anchor the WHOLE
// field crushed into kREnc gives r_s(M_field)/kREnc = 1.0/0.5 = 2 (a clear
// horizon); a partial core of mass m gives r_s/kREnc = (m/M_field)/0.5, so the
// hole grows honestly as the collapse gathers mass — and is order-unity in
// sim coords (resolvable + viewable), which the Sgr A* anchor never allowed.
inline constexpr double kCsqSI       = 8.987551787e16;  // c², m²/s²
inline constexpr double kRsSimPerMsun = 2.0 * kGMsunSI / kCsqSI / kUnitMeters; // ≈ 1.6825e-6 (conservation anchor)
inline constexpr double kREnc        = 0.5;             // enclosure radius, sim units

// ── THE SPEED OF LIGHT in sim units (Phase A1 — fully physical, 2026-06-13) ──
// Nothing may move faster than c. On screen, 1 s of wall-clock advances the
// physics by kTimeLapse real seconds, so light travels kTimeLapse·c_SI real
// metres = that many / kUnitMeters sim units, per on-screen second:
//   c [sim / on-screen s] = kTimeLapse · c_SI / kUnitMeters.
// The integrator caps each particle's |v| (sim/s) at this. The HUD's v/c is
// |v_sim_per_s| / kCSimPerSec (= |velW|·120 / kCSimPerSec at 120 fps).
inline constexpr double kCSI         = 2.99792458e8;    // c, m/s (exact)
inline constexpr double kCSimPerSec  = kTimeLapse * kCSI / kUnitMeters; // ≈ 3.515 sim/(screen s)

} // namespace units
} // namespace space
