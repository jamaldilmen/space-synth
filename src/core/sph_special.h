#pragma once
// ─────────────────────────────────────────────────────────────────────────────
// SPHERICAL SPECIAL FUNCTIONS — j_l(x) and the fully-normalized P̄_l^m(cos θ)
//
// WHY THIS FILE COMPILES IN BOTH METAL AND C++ (2026-08-26):
// The shader and the CPU validation harness must run THE SAME SOURCE. Writing a
// separate CPU transcription and validating that would only prove the
// transcription is correct — it would say nothing about the code that actually
// runs on the GPU. There is no dual-target precedent in this repo; this
// establishes it, and the only cost is the four macros below.
//
// 🚨 THIS PROJECT HAS BEEN BURNED TWICE BY BESSEL EVALUATORS. The rules that
// came out of those two failures are structural here, not tested-for:
//   1. NO DATA-DEPENDENT LOOP BREAK ANYWHERE. A data-dependent break once HUNG
//      PSO creation. Every loop below has a compile-time-constant trip count.
//      The rescale guard inside the Miller loop is a rescale, NOT an exit — the
//      trip count is identical on every call.
//   2. NO ASYMPTOTIC FORMS. An asymptotic form gave 8.9e-1 garbage at m ≤ 11.
//      j_l uses Miller DOWNWARD recurrence, which is stable for l > x by
//      construction; upward recurrence (unstable exactly there) is never used.
//   3. Accuracy is MEASURED against independent references, never assumed.
//      See scratchpad/sph_sweep.cpp.
//
// Mirrors the proven template already in particles.metal:487 (besselJm), which
// uses the same fixed-trip-count Miller scheme and measured 2.6e-7.
// ─────────────────────────────────────────────────────────────────────────────

#if defined(__METAL_VERSION__)
  #define SPH_SIN(x)  metal::sin(x)
  #define SPH_COS(x)  metal::cos(x)
  #define SPH_SQRT(x) metal::sqrt(x)
  #define SPH_ABS(x)  metal::fabs(x)
#else
  #include <cmath>
  #define SPH_SIN(x)  std::sin(x)
  #define SPH_COS(x)  std::cos(x)
  #define SPH_SQRT(x) std::sqrt(x)
  #define SPH_ABS(x)  std::fabs(x)
#endif

// Highest harmonic degree the field will use. Every loop below is bounded by
// this, so the trip counts are compile-time constants.
#define SPH_L_MAX 16

// Miller downward-recurrence start order. Must sit well above both l and x for
// the downward pass to have converged onto j_l by the time it reaches l.
//
// 🚨 MEASURED, AND THE KNEE IS BRUTAL. Sweep over the full domain (l ≤ 16,
// |x| ≤ 64), worst full-scale relative error vs the independent references.
//
// ⚠️ READ THE RIGHT NUMBER. The harness prints FOUR sweep sections. Only the
// two j_l ones respond to M at all; both P̄ sections are M-INDEPENDENT (sph_plm
// never references SPH_MILLER_M) and sit at a flat 5.337e-06 / 5.793e-07. The
// overall GATE is the max of all four, so it is P̄-driven and SATURATES at
// 5.337e-06 above the knee — by the gate, 76/80/96/128/192 are
// indistinguishable and the knee is invisible. CHOOSE M ON A j_l SECTION;
// SHIP ON THE GATE.
// Both j_l sections agree on where the knee is (measured 2026-08-27 10:47:52):
//     M = 68 → 4.540e-03 / 1.543e-03      M = 76 → 1.317e-06 / 1.128e-06
//     M = 72 → 1.044e-04 / 3.550e-05      (vs-series / vs-closed-forms)
// so the knee at 72→76 does not rest on one instrument. Above 76 the
// vs-closed-forms section hits its own float32 floor at 1.128e-06 and stops
// resolving too; vs-series keeps a little resolution, and its drift from 76 to
// 192 is under 40% — noise, not a second knee.
// Figures below are the vs-series j_l section. Re-measured 2026-08-27 10:34:00:
//     M = 40 → 3.244e+03     M = 76  → 1.317e-06
//     M = 48 → 3.153e+03     M = 80  → 1.010e-06
//     M = 56 → 1.205e+03     M = 96  → 9.530e-07
//     M = 64 → 8.226e-02     M = 128 → 1.001e-06
//     M = 72 → 1.044e-04     M = 192 → 9.454e-07
// The transition from garbage to converged happens between 72 and 76 — four
// orders of magnitude across a step of 4.
//
// ⚠️ DO NOT COPY THE 64 FROM particles.metal:485 (that is the constant itself;
// besselJm begins at :487). It is correct for the CYLINDRICAL J_m over ITS
// argument range; here it yields 8.2e-02 — the same order as the 8.9e-1
// asymptotic garbage that burned this project once already. The start order has
// to clear the ARGUMENT, and x reaches 64 in this domain where the cylindrical
// use did not.
//
// 96 = comfortably past the knee (72→76), and half the loop cost of the 192
// this started at. If the used x range ever grows past 64, RE-RUN THE SWEEP —
// this number is a measurement of a domain, not a universal constant.
#ifndef SPH_MILLER_M
#define SPH_MILLER_M 96
#endif

// Below this |x| the ASCENDING POWER SERIES is used instead of the closed
// forms / Miller. This is not about 0/0 at the origin — it is about CATASTROPHIC
// CANCELLATION, and it was MEASURED, not guessed (first sweep, 2026-08-26):
// j_1 = sin x/x² − cos x/x subtracts two quantities of size ~1/x² to leave a
// result of size ~x/3, so the relative error goes as ~3ε/x³. At x = 0.001 that
// is 8.5e-2 — the first sweep returned 3.05e-4 for a true 3.34e-4. A threshold
// of 1e-4 (the original guess) was three orders of magnitude too low.
// At x = 2 the same estimate gives ~2e-8, and the series itself is still
// cancellation-free there (its largest term is O(1)), so 2.0 is where the two
// methods cross while both are accurate. Above ~8 the series would cancel badly
// in its own right; Miller owns everything above 2.
#define SPH_SERIES_X 2.0f
// Fixed term count. At x < 2 the terms decay past k≈2; 24 is far beyond
// convergence and keeps the trip count constant.
#define SPH_SERIES_TERMS 24

// 1/sqrt(4π) — the l=0,m=0 value of the normalized associated Legendre.
#define SPH_INV_SQRT_4PI 0.28209479177387814f

// ─────────────────────────────────────────────────────────────────────────────
// j_l(x) — spherical Bessel function of the first kind.
//
// Recurrence (downward):  j_{k-1}(x) = ((2k+1)/x)·j_k(x) − j_{k+1}(x)
// Seeded at SPH_MILLER_M with (j_{M+1}, j_M) = (0, tiny), run down to l=0, then
// normalized against whichever of j_0 = sin x/x or j_1 = sin x/x² − cos x/x is
// LARGER IN MAGNITUDE. Both have exact closed forms and they never vanish
// together (where sin x → 0, j_1 → −cos x/x, which is at its largest), so the
// normalization is always well-conditioned. Normalizing on j_0 alone would be
// ill-conditioned at every x ≈ nπ.
// ─────────────────────────────────────────────────────────────────────────────
inline float sph_jl(int l, float x) {
    if (l < 0 || l > SPH_L_MAX) return 0.0f;

    float ax = SPH_ABS(x);
    // Parity: j_l(−x) = (−1)^l · j_l(x)
    float sgn = (x < 0.0f && (l & 1)) ? -1.0f : 1.0f;

    // ── ASCENDING POWER SERIES, x < 2 ───────────────────────────────────────
    //   j_l(x) = x^l/(2l+1)!! · Σ_k (−x²/2)^k / (k!·(2l+3)(2l+5)…(2l+2k+1))
    // Every term is formed by multiplication only — no subtraction of large
    // near-equal quantities — so this branch has no cancellation. It also
    // carries the x → 0 limit correctly: the prefactor IS x^l/(2l+1)!!, so
    // small-x values stay right in RELATIVE terms, not merely in absolute ones.
    if (ax < SPH_SERIES_X) {
        float pref = 1.0f;
        for (int k = 1; k <= SPH_L_MAX; ++k) {      // fixed trip count
            if (k <= l) pref *= ax / float(2 * k + 1);
        }
        float h = -0.5f * ax * ax;
        float term = 1.0f, sum = 1.0f;
        for (int k = 1; k <= SPH_SERIES_TERMS; ++k) {   // fixed trip count
            term *= h / (float(k) * float(2 * l + 2 * k + 1));
            sum  += term;
        }
        return sgn * pref * sum;
    }

    float s = SPH_SIN(ax), c = SPH_COS(ax);
    float j0 = s / ax;
    if (l == 0) return sgn * j0;
    float j1 = s / (ax * ax) - c / ax;
    if (l == 1) return sgn * j1;

    // Miller downward pass. FIXED trip count — no early exit, ever.
    float jp1 = 0.0f;        // j_{k+1}, unnormalized
    float jc  = 1.0e-30f;    // j_k,     unnormalized seed
    float target = 0.0f;     // unnormalized j_l
    float r0 = 0.0f, r1 = 0.0f;   // unnormalized j_0, j_1

    for (int k = SPH_MILLER_M; k >= 1; --k) {
        float jm1 = (float(2 * k + 1) / ax) * jc - jp1;
        jp1 = jc;
        jc  = jm1;                       // jc now holds j_{k-1}
        if (k - 1 == l) target = jc;
        if (k - 1 == 1) r1 = jc;
        if (k - 1 == 0) r0 = jc;
        // Overflow guard. This RESCALES; it does not break. Values captured
        // earlier are rescaled with it so every quantity stays in one common
        // (arbitrary) normalization until the final scale is applied.
        if (SPH_ABS(jc) > 1.0e20f) {
            const float rs = 1.0e-20f;
            jc *= rs; jp1 *= rs; target *= rs; r1 *= rs; r0 *= rs;
        }
    }

    // Normalize on the better-conditioned of the two exact closed forms.
    float scale = (SPH_ABS(j0) >= SPH_ABS(j1)) ? (j0 / r0) : (j1 / r1);
    return sgn * target * scale;
}

// ─────────────────────────────────────────────────────────────────────────────
// P̄_l^m(cos θ) — associated Legendre, FULLY NORMALIZED:
//     P̄_l^m = sqrt( (2l+1)/(4π) · (l−m)!/(l+m)! ) · P_l^m
// so that Y_lm = P̄_l^m · e^{imφ}. Condon–Shortley phase (−1)^m is included.
//
// The normalization is carried THROUGH the recurrence rather than applied at
// the end, so no factorial is ever formed and nothing overflows — the naive
// route computes (l+m)! and dies well before l=16.
//
//   P̄_0^0     = 1/sqrt(4π)
//   P̄_m^m     = −sqrt((2m+1)/(2m))·sinθ·P̄_{m−1}^{m−1}
//   P̄_{m+1}^m =  sqrt(2m+3)·cosθ·P̄_m^m
//   P̄_l^m     =  a·cosθ·P̄_{l−1}^m − b·P̄_{l−2}^m
//     a = sqrt( (2l−1)(2l+1) / ((l−m)(l+m)) )
//     b = sqrt( (2l+1)(l+m−1)(l−m−1) / ((2l−3)(l−m)(l+m)) )
//
// POLES ARE SAFE BY CONSTRUCTION: at sinθ = 0 the P̄_m^m climb yields exactly 0
// for every m ≥ 1, which is the true value. There is no division by sinθ
// anywhere — that division is the classic way these blow up at θ = 0, π.
// ─────────────────────────────────────────────────────────────────────────────
inline float sph_plm(int l, int m, float cosT, float sinT) {
    if (m < 0 || l < 0 || m > l || l > SPH_L_MAX) return 0.0f;

    // Climb the diagonal to P̄_m^m. Fixed trip count.
    float pmm = SPH_INV_SQRT_4PI;
    for (int k = 1; k <= SPH_L_MAX; ++k) {
        if (k <= m) pmm *= -SPH_SQRT(float(2 * k + 1) / float(2 * k)) * sinT;
    }
    if (l == m) return pmm;

    float pmm1 = SPH_SQRT(float(2 * m + 3)) * cosT * pmm;
    if (l == m + 1) return pmm1;

    // Climb in l. Fixed trip count.
    float prev2 = pmm, prev1 = pmm1, cur = pmm1;
    for (int k = 2; k <= SPH_L_MAX; ++k) {
        int ll = m + k;
        if (ll <= l) {
            float a = SPH_SQRT(float((2 * ll - 1) * (2 * ll + 1)) /
                               float((ll - m) * (ll + m)));
            float b = SPH_SQRT(float((2 * ll + 1) * (ll + m - 1) * (ll - m - 1)) /
                               float((2 * ll - 3) * (ll - m) * (ll + m)));
            cur   = a * cosT * prev1 - b * prev2;
            prev2 = prev1;
            prev1 = cur;
        }
    }
    return cur;
}
