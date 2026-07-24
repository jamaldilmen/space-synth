#pragma once

// ── SPECTRAL STARMAP — CPU-side band-flux bake ──────────────────────────────
// DESIGN_2026-07-24_spectral_starmap.md. ONE colour law, two consumers (the
// particle vertex path and the BH ray-march), so the spectrum→colour step is a
// pure function of scalars — no Particle, no vid, no position.
//
// GROUND TRUTH: tools/spectral_bands.py → docs/spectral_bands_reference.txt.
// This header is the single implementation of that math; the offline test
// (scratchpad/spectral_check.cpp) and renderer.mm's bake BOTH include it, so
// the shipped LUT and the thing we verified cannot drift apart.
//
// WHY THE CONTINUUM LUT HAS ONLY ONE AXIS. The shift factor g enters exactly
// as a temperature scaling:
//        g³·B_ν(ν/g, T)  ≡  B_ν(ν, g·T)
// A shifted blackbody IS a blackbody at g·T, so the observed flux in a FIXED
// observer band depends on T and g only through their product. The spec's
// 64×32 (T,g) table therefore collapses to a 1-D table in T_eff = g·T with no
// approximation — and the full g⁴ amplitude is already inside it. Nothing
// multiplies by g afterwards. (Verified numerically in both windows to
// ratio 1.00000 across R/G/B for g = 0.4…2.5, 2026-07-24.)
//
// Only the emission LINES genuinely need a g axis: λ_obs = λ_rest/g moves each
// line between bands, and off the end of the set entirely under redshift.

#include <cmath>

namespace space {
namespace spectral {

// SI, exact (CODATA / SI definitions) — same constants as the Python generator.
inline constexpr double kPlanckH = 6.62607015e-34;
inline constexpr double kLightC  = 2.99792458e8;
inline constexpr double kBoltzK  = 1.380649e-23;

// Planck specific intensity, per unit frequency.
inline double planckBnu(double nu, double T) {
  double x = kPlanckH * nu / (kBoltzK * T);
  if (x > 700.0) return 0.0;          // exp overflow guard (matches generator)
  return 2.0 * kPlanckH * nu * nu * nu / (kLightC * kLightC) / std::expm1(x);
}

// Integrate Planck over [l1,l2] micron, IN FREQUENCY SPACE, trapezoid n=800.
// Must match tools/spectral_bands.py bandflux() term for term.
inline double bandFlux(double l1um, double l2um, double T, int n = 800) {
  const double n1 = kLightC / (l2um * 1e-6);
  const double n2 = kLightC / (l1um * 1e-6);
  double s = 0.0;
  for (int i = 0; i <= n; ++i) {
    double nu = n1 + (n2 - n1) * (double)i / (double)n;
    double w  = (i == 0 || i == n) ? 0.5 : 1.0;
    s += w * planckBnu(nu, T);
  }
  return s * (n2 - n1) / (double)n;
}

// Band edges in micron. Index 0 = B (shortest λ), 1 = G, 2 = R — the
// generator's ordering. Do not reorder: the reference table depends on it.
struct BandSet {
  const char *name;
  double lo[3], hi[3];
};

inline constexpr BandSet kBandVisible = {
    "visible", {0.435, 0.500, 0.590}, {0.500, 0.590, 0.700}};
inline constexpr BandSet kBandHubble = {
    "hubble-like", {0.400, 0.550, 0.700}, {0.550, 0.700, 0.950}};
inline constexpr BandSet kBandNircam = {
    "nircam", {0.80, 1.75, 3.10}, {1.65, 3.10, 5.00}};

// ── Continuum LUT axis: T_eff = g·T, log-spaced ─────────────────────────────
// Range covers the spec's T 1000–40000 K crossed with g 0.3–2.0.
inline constexpr int    kContinuumN    = 256;
inline constexpr double kContinuumTMin = 300.0;
inline constexpr double kContinuumTMax = 80000.0;

inline double continuumTempAt(int i) {
  return kContinuumTMin *
         std::pow(kContinuumTMax / kContinuumTMin,
                  (double)i / (double)(kContinuumN - 1));
}

// Absolute band flux (B,G,R) for an effective temperature. out[0]=B,1=G,2=R.
inline void continuumBands(const BandSet &bs, double tEff, double out[3]) {
  for (int b = 0; b < 3; ++b) out[b] = bandFlux(bs.lo[b], bs.hi[b], tEff);
}

// ── Emission lines: the only genuinely g-dependent table ────────────────────
// λ_obs = λ_rest / g. Top-hat band response, matching the generator's
// membership test (blo <= λ_obs < bhi). A line leaving the set entirely under
// redshift is the intended deep-field behaviour, not an edge case to smooth.
inline constexpr int    kLinesN  = 128;
inline constexpr double kLinesGMin = 0.30;
inline constexpr double kLinesGMax = 2.00;
inline constexpr double kLineHalpha = 0.6563; // µm
inline constexpr double kLineOIII   = 0.5007;
inline constexpr double kLineHbeta  = 0.4861;

inline double linesGAt(int i) {
  return kLinesGMin + (kLinesGMax - kLinesGMin) * (double)i /
                          (double)(kLinesN - 1);
}

// Per-band line weight at shift g. out[0]=B,1=G,2=R; each line contributes 1
// to whichever band it lands in, 0 if it has left the set.
inline void lineBands(const BandSet &bs, double g, double out[3]) {
  out[0] = out[1] = out[2] = 0.0;
  const double lines[3] = {kLineHalpha, kLineOIII, kLineHbeta};
  for (int L = 0; L < 3; ++L) {
    double lobs = lines[L] / g;
    for (int b = 0; b < 3; ++b)
      if (lobs >= bs.lo[b] && lobs < bs.hi[b]) out[b] += 1.0;
  }
}

} // namespace spectral
} // namespace space
