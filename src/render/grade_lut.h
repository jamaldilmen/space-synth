#pragma once

// ── DISPLAY GRADE LUT — CPU-side bake ───────────────────────────────────────
// The grade stage the pipeline never had. §9 item 2 of
// docs/HANDOFF_2026-08-02_cinematic_visual_overhaul.md.
//
// WHAT THIS IS NOT: it is NOT a replacement for the tonemap. The live display
// transform (postfx.metal:296-325 — hue-preserving max-channel asinh + sensor
// bleach) was built over several sessions directly from Jamal's verdicts and
// stays exactly as it is. This is the CREATIVE stage that composites after it,
// which simply did not exist: the only grade in the whole chain was the
// hardcoded `neonGrade` synth-palette remap.
//
// Follows the spectral_lut.h contract: ONE implementation of the math in a
// header that both the shipped bake (renderer.mm) and any offline verifier
// include, so the thing we ship and the thing we check cannot drift apart.
// Pure function of scalars — no Metal types, no engine types.

#include <algorithm>
#include <cmath>

namespace space {
namespace grade {

// ── N = 33 ──────────────────────────────────────────────────────────────────
// The cinema .cube standard, and it is standard for a reason that matters here:
// 33 = 2^5 + 1, so the grid has 32 intervals and therefore lands EXACTLY on
// 0.0, 0.5 and 1.0 — and on every dyadic value between them. An even node
// count (32, 64) puts no sample at mid-grey, which is precisely where a grade
// is judged. 17 is the "fast" tier and shows its interpolation on smooth
// gradients; 65 is beyond what hardware trilinear can distinguish on a grade
// this smooth. Not a taste number.
inline constexpr int kGradeLutN = 33;

// ── THE TINT DIRECTION IS DERIVED FROM OUR OWN TWO COLOUR LAWS ──────────────
// This render has exactly two colour sources, and between them they occupy
// most of the hue circle:
//   1. REST/disk — the Planck blackbody locus, `unifiedKelvin()` clamped to
//      1000-40000 K (render.metal:406-418). That locus runs deep red-orange →
//      white → pale blue. It never reaches saturated green, and never reaches
//      magenta at all (no blackbody is magenta — the locus is a smooth curve
//      that misses the purple line entirely).
//   2. PLAY/supernova — the shock-ionization EMISSION LINES (render.metal:1382+):
//      Hα/[SII] red, [OIII] GREEN, Hβ cyan, X-ray/synchrotron blue.
//
// ⚠️ So the "green is unoccupied" result from the NASA UI research is true ONLY
// of the blackbody law. [OIII] green is the physical tell of the play state and
// must never be competed with. Checking BOTH laws together, the one arc neither
// occupies is MAGENTA/VIOLET.
//
// Hue 280 deg = the centre of that unoccupied arc: far enough from the
// synchrotron blue line (~240) to read as a distinct colour, and short of
// magenta (~300) where it would start to read as a broken red channel.
inline constexpr float kTintR = 0.50f; // hue 280 deg in sRGB, unit max channel
inline constexpr float kTintG = 0.00f; // ZERO — green belongs to [OIII], never to the grade
inline constexpr float kTintB = 1.00f;

// ── LIFT MAGNITUDE = 0.03, BOUNDED BY THE sRGB LINEAR SEGMENT ───────────────
// sRGB's transfer function is linear below an encoded value of 0.04045 and a
// power law above it. Keeping the maximum lift under that threshold keeps the
// ENTIRE tint inside the display's defined linear toe — the region that carries
// no image detail by construction — so the grade can never reach into the
// power-law range where the actual picture lives.
inline constexpr float kLift = 0.03f;

// ── THE CHROMA GUARD — why this grade cannot corrupt a star ─────────────────
// A faint star is DIM but not neutral: its hue sits on the Planck locus (or on
// an emission line) regardless of how little light reaches us, because
// brightness comes from mass and distance while hue comes from temperature.
// Luminance alone is therefore NOT a test for "is this matter" — a toe grade
// gated on darkness alone would tint every faint star off its true colour.
//
// The honest test is CHROMA: everything the physics emits has a chromaticity on
// one of the two laws; only the void is neutral. So the lift is weighted by
// (1 - saturation) and touches solely the colourless background.
inline float gradeWeight(float r, float g, float b) {
  const float mx = std::max(r, std::max(g, b));
  const float mn = std::min(r, std::min(g, b));
  const float sat = (mx > 1e-5f) ? (mx - mn) / mx : 0.0f;

  // Toe weight: full at black, gone by the sRGB linear-segment threshold
  // scaled to the grade's working range. Rec.709 luma — the display-referred
  // weighting, correct here because this stage runs AFTER the tonemap.
  const float luma = 0.2126f * r + 0.7152f * g + 0.0722f * b;
  const float t = std::min(1.0f, std::max(0.0f, luma / 0.25f));
  const float toe = 1.0f - (t * t * (3.0f - 2.0f * t)); // smoothstep(0, 0.25, luma)

  return toe * (1.0f - sat);
}

// Evaluate the grade for one display-referred RGB triple in [0,1].
inline void gradeSample(float r, float g, float b, float *outR, float *outG,
                        float *outB) {
  const float w = gradeWeight(r, g, b) * kLift;
  *outR = std::min(1.0f, r + kTintR * w);
  *outG = std::min(1.0f, g + kTintG * w);
  *outB = std::min(1.0f, b + kTintB * w);
}

// Bake the full N^3 grid into RGBA float storage (A = 1). Index order is
// x = R (fastest), y = G, z = B — the layout MTLTexture3D expects when the
// shader samples with float3(r, g, b).
inline void bakeGradeLut(float *rgba, int n = kGradeLutN) {
  const float inv = 1.0f / (float)(n - 1);
  for (int bz = 0; bz < n; ++bz) {
    for (int gy = 0; gy < n; ++gy) {
      for (int rx = 0; rx < n; ++rx) {
        const float r = (float)rx * inv;
        const float g = (float)gy * inv;
        const float b = (float)bz * inv;
        float orr, og, ob;
        gradeSample(r, g, b, &orr, &og, &ob);
        const size_t i = ((size_t)bz * n * n + (size_t)gy * n + (size_t)rx) * 4;
        rgba[i + 0] = orr;
        rgba[i + 1] = og;
        rgba[i + 2] = ob;
        rgba[i + 3] = 1.0f;
      }
    }
  }
}

} // namespace grade
} // namespace space
