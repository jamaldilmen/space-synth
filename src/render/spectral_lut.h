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

// ── STELLAR B/V/R — the line-straddling set, 2026-08-24 ─────────────────────
// Neither shipped set could do both jobs at once:
//   visible  lines land one per band, but the CONTINUUM collapses hot
//            (10000 K spread 0.173 — a blue giant renders nearly grey)
//   hubble   continuum separates well (30000 K spread 0.765), but its edges
//            put Hbeta 0.4861 AND [OIII] 0.5007 both in B and Halpha 0.6563
//            in G, so R gets NO line at all and the gas loses its red.
// The line positions FIX two edges: B|G must fall between [OIII] 0.5007 and
// Hbeta 0.4861 (-> 0.495) and G|R between [OIII] and Halpha 0.6563 (-> 0.600).
// That leaves only the outer edges free. Swept 2026-08-24 against: Sun near
// white, hot end separated, cool end deep red. Best was B_lo 0.360, R_hi 0.720:
//
//              2000 K   5772 K  10000 K  30000 K   lines
//   visible     0.955    0.332    0.173    0.447   one per band
//   hubble      0.980    0.126    0.548    0.765   COLLAPSED (R empty)
//   stellar     0.962    0.175    0.636    0.810   one per band
//
// It beats hubble at BOTH hot temperatures and keeps the emission lines
// separated. The edges land close to the Johnson B / V / R photometric bands,
// which is the standard system for stellar photometry — so this is a defensible
// choice, not a tuned one. (Real Johnson filters OVERLAP and are not top-hat;
// these are non-overlapping top-hats, same as every other set here.)
inline constexpr BandSet kBandStellar = {
    "stellar-bvr", {0.360, 0.495, 0.600}, {0.495, 0.600, 0.720}};

// ── WHICH BAND SET IS LIVE — SS_BANDS, added 2026-08-23 20:12:26 ────────────
// Until today renderer.mm held `const BandSet &bs = kBandVisible;` with the
// comment "switching rebakes". Nothing switched it: no UI, no env var, no
// caller. kBandHubble and kBandNircam had never been selected by anything
// since they were written on 2026-07-24. A comment is not a mechanism.
//
// MEASURED 2026-08-23 20:12:26 with this header's own math, normalised to the
// brightest channel, spread = max-min across B/G/R (higher = more colour):
//
//              2000 K        5772 K        10000 K       30000 K
//   visible    0.955         0.332         0.173         0.447
//   hubble     0.980         0.126         0.548         0.765
//   nircam     0.569         0.956         0.973         0.982
//
// Read those numbers before choosing:
//  • visible (the old default) COLLAPSES THE HOT END. At 10000 K the three
//    channels are within 0.17 of each other — a blue giant renders nearly
//    grey. That is the "hot stars go white" defect, and it is the band set,
//    not the tonemap.
//  • hubble separates both ends: deep red at 2000 K, strong blue at 30000 K
//    (0.765, 1.7x the visible set), and a near-white Sun at 5772 K — which is
//    correct, the Sun IS white above the atmosphere.
//  • nircam is NOT a drop-in. In 0.8-5 um everything hotter than ~3000 K sits
//    on the Rayleigh-Jeans tail, so the shortest band always wins: B=1.000,
//    G=0.10-0.20, R=0.02-0.04 for EVERY star from 5772 K up. A pure NIRCam
//    continuum makes the whole starfield one shade of blue. Real JWST images
//    are colourful because of EMISSION LINES and dust, not stellar continuum,
//    which is what the lines LUT below carries. Use nircam for the gas story,
//    not to colour stars.
inline const BandSet &bandSetByName(const char *name) {
  if (!name) return kBandStellar;          // default since 2026-08-24
  if (name[0] == 'v') return kBandVisible;
  if (name[0] == 'n') return kBandNircam;
  if (name[0] == 'h') return kBandHubble;
  return kBandStellar;
}

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

// ── PER-LINE STRENGTHS — 2026-07-30 02:3x ───────────────────────────────────
// Was `out[b] += 1.0` for every line: all three weighted EQUALLY. At g=1 the
// three lines land one per band (Hα→R, [OIII]→G, Hβ→B), so an equal-weight
// line component is spectrally FLAT — it adds grey. Added over the continuum it
// DESATURATES rather than colours, and the more ionised the gas the greyer it
// got. That is the "everything goes purple" Jamal reported, and the defect was
// already measured and written down as a known limitation when bit16 landed
// (commit 0f6a091, 2026-07-24) rather than fixed.
//
// Real ratios, Case B recombination, T_e = 10⁴ K, n_e = 100 cm⁻³
// (Osterbrock & Ferland, *Astrophysics of Gaseous Nebulae and AGN*, 2nd ed.,
// the standard Case B table). Normalised to Hβ = 1:
//   Hα  6563 Å : 2.86   ← the Balmer decrement. Fixed atomic physics.
//   Hβ  4861 Å : 1.00   ← reference
//   [OIII] 5007 Å : 3.0 ← see caveat
//
// ⚠ [OIII]/Hβ IS NOT A CONSTANT. It is an ionisation diagnostic and physically
// ranges ~1–5 in HII regions (Orion ≈ 3–4) and higher in planetary nebulae.
// 3.0 is a representative HII value, and it is the ONE number here that should
// become a function of the ionisation the caller already computes
// (`lineStrength`/`exc`). That needs a signature change to lineBands, which
// this header shares with the offline verifier, so it is deliberately left as a
// stated constant rather than smuggled in. THIS IS THE DIAL for a
// "too green"/"not green enough" verdict.
//
// Because Hα dominates at 2.86 and lands in R, ionised gas now reads WARM
// (red/orange) with an [OIII] green lift — which is what emission nebulae
// actually look like — instead of neutral grey over the continuum.
//
// ⚠ REGENERATE `docs/spectral_bands_reference.txt`: the [SPEC-LUT] probe
// compares the baked table against it, and the LINE rows will now differ by
// design. The continuum rows are untouched.
inline constexpr double kLineWHalpha = 2.86; // Case B, Hα/Hβ
inline constexpr double kLineWOIII   = 3.00; // representative HII; the dial
inline constexpr double kLineWHbeta  = 1.00; // reference

// Per-band line weight at shift g. out[0]=B,1=G,2=R; each line contributes its
// Case B strength to whichever band it lands in, 0 if it has left the set.
inline void lineBands(const BandSet &bs, double g, double out[3]) {
  out[0] = out[1] = out[2] = 0.0;
  const double lines[3]   = {kLineHalpha,  kLineOIII,   kLineHbeta};
  const double weight[3]  = {kLineWHalpha, kLineWOIII,  kLineWHbeta};
  for (int L = 0; L < 3; ++L) {
    double lobs = lines[L] / g;
    for (int b = 0; b < 3; ++b)
      if (lobs >= bs.lo[b] && lobs < bs.hi[b]) out[b] += weight[L];
  }
}

// The three strong lines, so a caller can state the CORRECT expectation for
// whichever set is live instead of hardcoding one set's answer.
inline void expectedLineBands(const BandSet &bs, double out[3]) {
  const double lam[3] = {kLineHbeta, kLineOIII, kLineHalpha};
  const double amp[3] = {1.00, 3.00, 2.86};   // Case B, normalised to Hbeta
  out[0] = out[1] = out[2] = 0.0;
  for (int i = 0; i < 3; ++i)
    for (int b = 0; b < 3; ++b)
      if (lam[i] >= bs.lo[b] && lam[i] < bs.hi[b]) out[b] += amp[i];
}

} // namespace spectral
} // namespace space
