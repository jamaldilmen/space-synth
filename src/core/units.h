#pragma once

#include "../spacetime/spacetime.h"

// ── REAL UNITS — now a thin DERIVATION over the honest spacetime base ───────
// 2026-06-29 15:38:00 HONEST-TIME RE-BASE (Step 1, behavior-neutral).
// Previously this file carried `kTimeLapse = 20.58` — an arbitrary constant
// with no physical derivation, the system's last time fudge. It is GONE.
//
// The unit SYSTEM (length, mass, time, c, G, r_s) now lives in spacetime.h and
// is fully derived from measured SI constants: 1 sim length = 2·r_g(field),
// 1 sim time = (1 sim length)/c ≈ 5.854 s, so c ≡ 1 and G is derived. This file
// just re-exports the public API the engine already calls (gmSim, kCSimPerSec,
// kRsSimPerMsun, kTimeLapse, kMbhMsun, kREnc) on top of that honest base.
//
// THE ONLY REMAINING KNOB is kTLapse — the warp: how many honest sim-time units
// advance per wall-clock second. It is a deliberate, LABELED time-lapse choice
// (you cannot watch a Myr collapse in real time), NOT a unit definition. Its
// value 3.515 reproduces the pre-re-base dynamics EXACTLY; Step 2 replaces this
// fixed value with an accuracy-governed cap (Universe-Sandbox model: spend
// accuracy via adaptive sub-steps to go faster; cap the warp when accuracy runs
// out). For now it is fixed so this re-base is verifiably behavior-neutral.
//
// Behavior delta vs the old file: the only numerical change is that kUnitMeters
// is now DERIVED (2·G·M_field/c² = 1.75504e9 m) instead of the rounded literal
// 1.7552e9 — a ~0.015% shift in gmSim/r_s, below visual perception, and the
// more-correct value. The sim must look identical.

namespace space {
namespace units {

namespace st = ::space::spacetime;

// ── Re-exported honest SI anchor + derived base (single source: spacetime.h) ─
inline constexpr double kGMsunSI    = st::kGMsunSI;     // G·M_sun, m³/s² (IAU)
inline constexpr double kCSI        = st::kCSI;         // c, m/s (exact)
inline constexpr double kCsqSI      = st::kCsqSI;       // c², m²/s²
inline constexpr double kMbhMsun    = st::kMfieldMsun;  // FIELD mass — conservation anchor
inline constexpr double kUnitMeters = st::kUnitMeters;  // 1 sim length = 2·r_g(field), DERIVED
inline constexpr double kSimSeconds = st::kSimSeconds;  // 1 sim time, in real seconds (≈ 5.854)

// ── THE WARP KNOB (replaces the magic kTimeLapse=20.58) ─────────────────────
// sim-time units advanced per wall-clock second. 3.51513 reproduces the
// pre-2026-06-29 dynamics exactly (it equalled the old kCSimPerSec). Step 2
// makes this accuracy-governed instead of a fixed constant.
inline constexpr double kTLapse = 3.51513;

// ── Gravitational coupling the integrator sees ──────────────────────────────
// The integrator steps by simDt in WALL seconds, so the coupling must be
// per-wall-second²: honest per-sim-time² gmSim × (sim-time/wall-sec)² = ×kTLapse².
inline constexpr double gmSim(double mSun) {
  return st::gmSim(mSun) * kTLapse * kTLapse;
}

// ── THE SPEED OF LIGHT, in sim-length per wall-second ───────────────────────
// c ≡ 1 sim-length/sim-time (honest); per wall-second that is × kTLapse.
// The integrator caps each particle's |v| (sim/wall-s) at this.
inline constexpr double kCSimPerSec = st::kCSim * kTLapse; // ≈ 3.515 sim/(wall s)

// ── DISPLAY: real physics seconds advanced per wall-clock second ────────────
// = warp (sim-time/wall-s) × real-seconds-per-sim-time. Now DERIVED, was 20.58.
inline constexpr double kTimeLapse = kTLapse * kSimSeconds; // ≈ 20.58 (display only)

// ── ISCO ORBITAL PERIOD, in WALL seconds, for the WARPED coupling ───────────
// 2026-07-25 22:0x:00 — THE c³ FIX. spacetime::kIscoPeriodPerGM gives
// T = 2π·6^1.5·GM only in a system where c = 1. gmSim() above is the warped
// coupling, per wall-second², where c = kCSimPerSec ≈ 3.515 — NOT 1. Redo it:
//     r_isco = 6GM/c²,  T = 2π·r_isco^1.5/√(GM) = 2π·6^1.5·GM/c³
// so the c=1 form is too large by c³ = 43.4334. The render time-lapse clock
// (renderer.mm) used the c=1 form against the warped GM, making the declared
// "screen-seconds per ISCO orbit" 43.43× too fast — measured live at
// poseDt = 2.3969 wall-s per frame vs a 0.0165 physics step (×145 net).
// The [BALANCE] probe's Texact (main.cpp) always used the correct law; the two
// disagreed by exactly this factor.
inline constexpr double iscoPeriodWallSec(double gmWarped) {
  return st::kIscoPeriodPerGM * gmWarped /
         (kCSimPerSec * kCSimPerSec * kCSimPerSec);
}

// ── Geometric black-hole criterion (time-independent — pure geometry) ───────
// r_s(M) = 2GM/c² in sim units. A region of enclosed mass M inside radius R IS
// a black hole when r_s(M) ≥ R. The whole field crushed into kREnc gives
// r_s(M_field)/kREnc = 1.0/0.5 = 2 (clear horizon); a partial core grows the
// hole honestly as collapse gathers mass.
inline constexpr double kRsSimPerMsun = st::rsSim(1.0);  // ≈ 1.6827e-6 (derived)
inline constexpr double kREnc         = 0.5;             // enclosure radius, sim units

} // namespace units
} // namespace space
