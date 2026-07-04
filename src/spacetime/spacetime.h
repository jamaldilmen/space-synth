#pragma once

// ── SPACETIME — the honest, derived space-AND-time unit system ──────────────
// 2026-06-29 · branch STARS · implements SPACETIME_UNITS.md step 2 (unit core).
//
// Supersedes the units.h TIME HACK (kTimeLapse = 20.58, an arbitrary constant
// with no physical derivation). Here TIME is derived from the same measured SI
// constants that already anchor LENGTH, so c = 1 in sim units BY CONSTRUCTION
// and G is derived — there is no tuned-by-feel number anywhere in this core.
//
// THE ANCHOR (identical length anchor as units.h, now with honest time):
//   Length: 1 sim length = kUnitMeters = 2·r_g(field) = 1.7552e9 m.
//   Mass:   1 mass unit  = 1 M_sun (IMF-sampled, as in units.h).
//   Time:   1 sim time   = (1 sim length)/c = kUnitMeters/c ≈ 5.85 s.
//           ⇒ c_sim = 1 EXACTLY, and the field's r_s = 1.0 sim EXACTLY.
//
// KEYSTONE self-consistency (asserted below): in these units
//   gmSim(M_field) = G·M_field/(c²·L) = r_g(field)/L = 1/2 = 0.5  →  r_s = 1.0.
// No constant tunes this; it falls out of "1 length = 2 r_g of the field."
//
// WHAT IS NOT HERE YET (genuinely open — see SPACETIME_UNITS.md, decisions the
// user owns, NOT to be smuggled in as a constant):
//   - T_lapse  : sim-time per screen-second (the watchability WARP). Separate
//                from the unit definition above. Bounded by integrator stability
//                / adaptive sub-stepping (spec principle 4), not picked by feel.
//   - timeRateFromEnergy(...) : the "playing bends time" energy→local-rate law.
// Both are declared as a clearly-marked TODO interface at the bottom, unwired.

namespace space {
namespace spacetime {

// ── Measured SI anchor constants (same source as units.h) ───────────────────
inline constexpr double kCSI      = 2.99792458e8;     // c, m/s (exact)
inline constexpr double kCsqSI    = kCSI * kCSI;       // c², m²/s²
inline constexpr double kGMsunSI  = 1.32712440018e20; // G·M_sun, m³/s² (IAU)
inline constexpr double kMfieldMsun = 5.94276e5;      // FIELD mass — conservation anchor

// 1 sim length = 2·r_g(field) = 2·G·M_field/c², DERIVED (not the rounded
// 1.7552e9 literal in units.h, which differs by ~0.01% — that rounding is why
// gmSim(field) read 0.49995 instead of 0.5). Deriving it makes r_s(field)=1.0
// and gmSim(field)=0.5 EXACT by construction — the last hand-rounded number gone.
inline constexpr double kUnitMeters =
    2.0 * kGMsunSI * kMfieldMsun / kCsqSI;            // ≈ 1.75504e9 m

// ── Derived honest units (NO free parameters) ───────────────────────────────
// 1 sim time = (1 sim length)/c. This is the whole trick: it makes c_sim = 1.
inline constexpr double kSimSeconds = kUnitMeters / kCSI; // ≈ 5.8547 s per sim time unit

// Speed of light in sim units: length per time = kUnitMeters/kSimSeconds / sim
//   = c / (kUnitMeters/kSimSeconds) ... by construction this is exactly 1.
inline constexpr double kCSim = (kUnitMeters / kSimSeconds) / kCSI; // ≡ 1

// G·M per solar mass in sim units [sim³ / sim_time²].
//   GM_SI [m³/s²] → sim: × T²/L³ = × (kSimSeconds²)/(kUnitMeters³).
//   With T = L/c this simplifies to GM_SI/(c²·L)  (= r_g per M_sun, in sim).
inline constexpr double kGMsunSim =
    kGMsunSI * (kSimSeconds * kSimSeconds) /
    (kUnitMeters * kUnitMeters * kUnitMeters);

// G·M in sim units for a mass of mSun solar masses — what the integrator sees.
inline constexpr double gmSim(double mSun) { return mSun * kGMsunSim; }

// Schwarzschild radius in sim units: r_s = 2GM/c² = 2·gmSim(M)/c_sim².
inline constexpr double rsSim(double mSun) {
  return 2.0 * gmSim(mSun) / (kCSim * kCSim);
}

// Gravitational tick t_g = GM/c³, in REAL seconds (the system's natural clock).
inline constexpr double tgSeconds(double mSun) {
  return mSun * kGMsunSI / (kCsqSI * kCSI);
}

// ── Self-verification (compile-time; numbers come from the derivation only) ──
namespace detail {
inline constexpr double cabs(double x) { return x < 0.0 ? -x : x; }
inline constexpr bool approx(double a, double b, double rel) {
  return cabs(a - b) <= rel * (cabs(b) > 1.0 ? cabs(b) : 1.0);
}
} // namespace detail

// c is exactly 1 in sim units, by construction.
static_assert(detail::approx(kCSim, 1.0, 1e-12),
              "c_sim must be exactly 1 in honest units");
// The whole field, crushed, is a 1-unit black hole: r_s(M_field) = 1.0 sim.
static_assert(detail::approx(rsSim(kMfieldMsun), 1.0, 1e-9),
              "r_s(field) must be 1.0 sim — the length anchor's defining property");
// gmSim(M_field) = r_g/L = 0.5 exactly.
static_assert(detail::approx(gmSim(kMfieldMsun), 0.5, 1e-9),
              "gmSim(field) must be 0.5 (r_g/L) — keystone consistency");
// 1 sim time ≈ 5.85 s (horizon light-crossing of the field).
static_assert(detail::approx(kSimSeconds, 5.8547, 1e-3),
              "1 sim time must be kUnitMeters/c ≈ 5.85 s");
// field gravitational tick ≈ 2.93 s.
static_assert(detail::approx(tgSeconds(kMfieldMsun), 2.927, 1e-3),
              "t_g(field) must be GM/c³ ≈ 2.93 s");

// ── THERMODYNAMICS (EOS anchor — physical, NOT feel-tuned) ───────────────────
// Specific internal energy u is carried in SIM units (velocity = c, so u is in
// units of c²). Temperature in Kelvin is DERIVED, never stored:
//   ideal gas:  u = (1/(γ−1))·k_B·T / (μ·m_H)
//   →  T[K] = (γ−1)·μ·m_H·c² / k_B · u_sim = kKelvinPerUSim · u_sim
// All constants are physical (SI); μ = ionized solar H/He. No arbitrary scale.
inline constexpr double kBoltzSI      = 1.380649e-23;       // k_B, J/K (exact)
inline constexpr double kProtonMassSI = 1.67262192369e-27;  // m_H, kg
inline constexpr double kMuIonized    = 0.62;               // mean molecular weight (ionized solar)
inline constexpr double kGammaAdiab   = 5.0 / 3.0;          // monatomic ideal gas
inline constexpr double kKelvinPerUSim =
    (kGammaAdiab - 1.0) * kMuIonized * kProtonMassSI * kCsqSI / kBoltzSI; // ≈ 4.500e12 K
inline constexpr double kUSimPerKelvin = 1.0 / kKelvinPerUSim;
// Cold thermal floor so rest stays ≈ collisionless (u≈0 → pressure≈0).
inline constexpr double kTFloorKelvin = 10.0;               // cold ISM-ish
inline constexpr double kUFloorSim    = kTFloorKelvin * kUSimPerKelvin; // ≈ 2.2e-12
static_assert(detail::approx(kKelvinPerUSim, 4.500e12, 2e-3),
              "T[K] = kKelvinPerUSim·u_sim must be ≈ 4.5e12 (γ=5/3, μ=0.62)");

// ── OPEN INTERFACE (UNWIRED — decisions the user owns; see SPACETIME_UNITS.md) ─
// T_lapse: sim-time units advanced per screen-second (the watchability warp).
//   It is NOT part of the unit definition above and must NOT be a feel-tuned
//   constant. Bounded by integrator stability + adaptive sub-stepping
//   (spec principle 4: math correct to ~6× local dynamical time per step).
//   Left undefined here on purpose until that decision is made.
//
// inline constexpr double kTLapse = /* TBD — gated decision */;
//
// timeRateFromEnergy: "playing bends time." Injected mass-energy density curves
//   spacetime → faster local dynamical rate (why play-supernova forms faster).
//   Physics basis still TBD from research; declared, not implemented.
//
// inline double timeRateFromEnergy(double injectedEnergyDensity) { /* TBD */ }

} // namespace spacetime
} // namespace space
