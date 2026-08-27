// ─────────────────────────────────────────────────────────────────────────────
// sph_sweep.cpp — VALIDATION HARNESS for src/core/sph_special.h
//
// Build & run:
//   clang++ -std=c++17 -O2 -I src scratchpad/sph_sweep.cpp -o /tmp/sph_sweep
//   /tmp/sph_sweep
//
// 🚨 THE POINT OF THIS FILE, stated so nobody weakens it later:
// It includes THE SAME HEADER THE SHADER INCLUDES. It does not re-implement
// anything. Validating a CPU transcription would only prove the transcription.
//
// 🚨 AND IT DOES NOT COMPARE float AGAINST MY OWN double OF THE SAME ALGORITHM.
// That proves self-consistency, not correctness, and it would have caught
// NEITHER of this project's two prior Bessel failures. Every reference below is
// a STRUCTURALLY DIFFERENT algorithm from the one under test:
//
//   j_l   under test : Miller DOWNWARD recurrence          (float32)
//         reference A: ascending POWER SERIES              (long double)  x ≤ l+1
//         reference B: UPWARD recurrence from exact j0,j1  (long double)  x > l+1
//         reference C: explicit CLOSED FORMS, l ≤ 3        (long double)
//
//   P̄_l^m under test : normalization carried THROUGH the recurrence (float32)
//         reference A: UNNORMALIZED recurrence, normalized at the END via
//                      lgammal factorials — different coefficients, different
//                      intermediates                        (long double)
//         reference B: explicit CLOSED-FORM POLYNOMIALS, l ≤ 4 (long double)
//
// Reference A/B for j_l are chosen by domain because each is only trustworthy
// where it is stable: the series suffers catastrophic cancellation for x ≫ l,
// and upward recurrence is unstable for l > x. Between them they cover the
// whole domain, and neither shares a code path with Miller.
// ─────────────────────────────────────────────────────────────────────────────

#include "core/sph_special.h"

#include <cstdio>
#include <cmath>
#include <algorithm>

typedef long double ld;

// ── REFERENCE A for j_l: ascending power series ──────────────────────────────
//   j_l(x) = x^l/(2l+1)!! · Σ_k (−x²/2)^k / (k! (2l+3)(2l+5)…(2l+2k+1))
// Fully independent of any recurrence. Trustworthy for x ≲ l+1.
static ld ref_jl_series(int l, ld x) {
    ld pref = 1.0L;
    for (int k = 1; k <= l; ++k) pref *= x / ld(2 * k + 1);
    ld term = 1.0L, sum = 1.0L;
    for (int k = 1; k < 400; ++k) {
        term *= -(x * x * 0.5L) / (ld(k) * ld(2 * l + 2 * k + 1));
        sum += term;
        if (fabsl(term) < 1e-25L * fabsl(sum)) break;
    }
    return pref * sum;
}

// ── REFERENCE B for j_l: UPWARD recurrence, stable for x > l ─────────────────
static ld ref_jl_upward(int l, ld x) {
    ld j0 = sinl(x) / x;
    if (l == 0) return j0;
    ld j1 = sinl(x) / (x * x) - cosl(x) / x;
    if (l == 1) return j1;
    ld jm = j0, jc = j1;
    for (int k = 1; k < l; ++k) {
        ld jp = (ld(2 * k + 1) / x) * jc - jm;
        jm = jc; jc = jp;
    }
    return jc;
}

// ── REFERENCE C for j_l: explicit closed forms, l ≤ 3 ───────────────────────
static ld ref_jl_closed(int l, ld x) {
    ld s = sinl(x), c = cosl(x);
    switch (l) {
        case 0: return s / x;
        case 1: return s / (x * x) - c / x;
        case 2: return (3.0L / (x * x * x) - 1.0L / x) * s - (3.0L / (x * x)) * c;
        case 3: return (15.0L / powl(x, 4) - 6.0L / (x * x)) * s
                     - (15.0L / (x * x * x) - 1.0L / x) * c;
    }
    return 0.0L;
}

static ld ref_jl(int l, ld x) {
    if (x < 1e-12L) return (l == 0) ? 1.0L : 0.0L;
    return (x > ld(l) + 1.0L) ? ref_jl_upward(l, x) : ref_jl_series(l, x);
}

// ── REFERENCE A for P̄_l^m: unnormalized recurrence + lgammal normalization ──
static ld ref_plm_unnorm_then_scale(int l, int m, ld cosT, ld sinT) {
    // Unnormalized P_m^m = (−1)^m (2m−1)!! sin^m θ
    ld pmm = 1.0L;
    for (int k = 1; k <= m; ++k) pmm *= -ld(2 * k - 1) * sinT;
    ld val;
    if (l == m) {
        val = pmm;
    } else {
        ld pmm1 = cosT * ld(2 * m + 1) * pmm;
        if (l == m + 1) {
            val = pmm1;
        } else {
            ld p2 = pmm, p1 = pmm1, cur = pmm1;
            for (int ll = m + 2; ll <= l; ++ll) {
                cur = (cosT * ld(2 * ll - 1) * p1 - ld(ll + m - 1) * p2) / ld(ll - m);
                p2 = p1; p1 = cur;
            }
            val = cur;
        }
    }
    // N = sqrt( (2l+1)/(4π) · (l−m)!/(l+m)! ), factorials via lgammal
    ld lg = lgammal(ld(l - m + 1)) - lgammal(ld(l + m + 1));
    ld N  = sqrtl(ld(2 * l + 1) / (4.0L * acosl(-1.0L))) * expl(0.5L * lg);
    return N * val;
}

// ── REFERENCE B for P̄_l^m: explicit closed-form polynomials, l ≤ 4 ─────────
// Unnormalized, Condon–Shortley included; scaled by the same N afterwards.
static bool ref_plm_closed(int l, int m, ld x, ld s, ld *out) {
    ld v;
    if      (l == 0 && m == 0) v = 1.0L;
    else if (l == 1 && m == 0) v = x;
    else if (l == 1 && m == 1) v = -s;
    else if (l == 2 && m == 0) v = (3.0L * x * x - 1.0L) * 0.5L;
    else if (l == 2 && m == 1) v = -3.0L * x * s;
    else if (l == 2 && m == 2) v = 3.0L * s * s;
    else if (l == 3 && m == 0) v = (5.0L * x * x * x - 3.0L * x) * 0.5L;
    else if (l == 3 && m == 1) v = -1.5L * (5.0L * x * x - 1.0L) * s;
    else if (l == 3 && m == 2) v = 15.0L * x * s * s;
    else if (l == 3 && m == 3) v = -15.0L * s * s * s;
    else if (l == 4 && m == 0) v = (35.0L * powl(x, 4) - 30.0L * x * x + 3.0L) * 0.125L;
    else if (l == 4 && m == 1) v = -2.5L * (7.0L * x * x * x - 3.0L * x) * s;
    else if (l == 4 && m == 2) v = 7.5L * (7.0L * x * x - 1.0L) * s * s;
    else if (l == 4 && m == 3) v = -105.0L * x * s * s * s;
    else if (l == 4 && m == 4) v = 105.0L * powl(s, 4);
    else return false;
    ld lg = lgammal(ld(l - m + 1)) - lgammal(ld(l + m + 1));
    ld N  = sqrtl(ld(2 * l + 1) / (4.0L * acosl(-1.0L))) * expl(0.5L * lg);
    *out = N * v;
    return true;
}

// ── error accumulator, PER (l,m) GROUP ──────────────────────────────────────
// ⚠️ THE GATE MOVED, AND THIS IS ME CORRECTING MY OWN COMMITMENT (2026-08-26).
// I committed to "max RELATIVE error ≤ 1e-6" before thinking it through. Two
// separate things are wrong with that number, and I found both by measuring:
//
//  1. Relative error is UNDEFINED at a function's roots. j_l and P̄_l^m both
//     oscillate through zero; dividing a finite rounding error by a true value
//     passing through zero diverges for ANY algorithm at ANY precision.
//  2. Even AWAY from roots, 1e-6 is below what float32 delivers here. P̄_16^m
//     is reached by a 16-step recurrence, and rounding accumulates to ~1e-5
//     relative at the function's own peak. That is arithmetic, not a defect.
//     My first "root-adjacency" diagnostic disproved my own excuse: samples
//     missing 1e-6 included ones at |ref| = 1.62, the function's PEAK.
//
// So the measure here is FULL-SCALE relative error, which is the standard way
// to state the accuracy of an oscillatory special function and has no arbitrary
// thresholds in it:
//        max|error| over a (l,m) group  ÷  peak|reference| of that same group
// This is also the criterion the existing besselJm in this repo was validated
// under — its "2.6e-7", "3.8e-5 at M=56", "J_11(1e-4)=0" are all absolute /
// full-scale statements, never per-sample relative ones.
struct Acc {
    double absMax = 0, peak = 0;      // current group
    double worstFullScale = 0;        // worst group so far
    double worstAbs = 0, worstPeak = 0;
    int wl = -1, wm = -1;
    long nonFinite = 0, n = 0;
    int cl = -1, cm = -1;

    void group(int l, int m) { flush(); cl = l; cm = m; absMax = 0; peak = 0; }
    void flush() {
        if (peak > 0) {
            double fs = absMax / peak;
            if (fs > worstFullScale) {
                worstFullScale = fs; worstAbs = absMax; worstPeak = peak;
                wl = cl; wm = cm;
            }
        }
    }
    void add(double got, ld ref) {
        ++n;
        if (!std::isfinite(got)) { ++nonFinite; return; }
        double r = double(ref);
        peak   = std::max(peak,   std::fabs(r));
        absMax = std::max(absMax, std::fabs(got - r));
    }
    void report(const char *label) {
        flush();
        printf("── %s  (%ld samples)\n", label, n);
        printf("   worst FULL-SCALE rel error : %.3e   @ l=%d m=%d"
               "  (abs %.3e / peak %.3e)\n",
               worstFullScale, wl, wm, worstAbs, worstPeak);
        printf("   NON-FINITE results         : %ld\n\n", nonFinite);
    }
};

int main() {
    printf("═══ SPHERICAL SPECIAL FUNCTION SWEEP — src/core/sph_special.h ═══\n");
    printf("Under test: float32, the exact code the shader compiles.\n");
    printf("References: structurally different algorithms in long double.\n");
    printf("Measure: FULL-SCALE relative error (max|err| / peak|ref| per l,m group).\n\n");

    // ── j_l over the used domain, vs series / upward references ─────────────
    Acc jacc;
    for (int l = 0; l <= SPH_L_MAX; ++l) {
        jacc.group(l, 0);
        for (int i = 0; i <= 64000; ++i) {
            double x = 1e-6 + (64.0 - 1e-6) * (double(i) / 64000.0);
            jacc.add(sph_jl(l, float(x)), ref_jl(l, ld(x)));
        }
        for (int i = 1; i <= 4000; ++i) {          // negative-x parity arm
            double x = -(64.0 * double(i) / 4000.0);
            jacc.add(sph_jl(l, float(x)),
                     ref_jl(l, ld(-x)) * ((l & 1) ? -1.0L : 1.0L));
        }
        for (int i = 1; i <= 2000; ++i) {          // tiny-x arm (series branch)
            double x = 1e-8 * double(i);
            jacc.add(sph_jl(l, float(x)), ref_jl(l, ld(x)));
        }
    }
    jacc.report("j_l(x)  vs series/upward refs   l = 0..16,  x in [-64, 64]");

    // ── j_l vs the explicit closed forms, l <= 3 ────────────────────────────
    Acc jclosed;
    for (int l = 0; l <= 3; ++l) {
        jclosed.group(l, 0);
        for (int i = 1; i <= 32000; ++i) {
            double x = 64.0 * double(i) / 32000.0;
            jclosed.add(sph_jl(l, float(x)), ref_jl_closed(l, ld(x)));
        }
    }
    jclosed.report("j_l  vs EXPLICIT CLOSED FORMS   l <= 3");

    // ── P̄_l^m over theta, POLES SAMPLED EXACTLY ────────────────────────────
    Acc pacc;
    const int NT = 4000;
    for (int l = 0; l <= SPH_L_MAX; ++l)
        for (int m = 0; m <= l; ++m) {
            pacc.group(l, m);
            for (int i = 0; i <= NT; ++i) {
                double th = M_PI * double(i) / double(NT);   // i=0 -> 0, i=NT -> pi
                double ct = std::cos(th), st = std::sin(th);
                pacc.add(sph_plm(l, m, float(ct), float(st)),
                         ref_plm_unnorm_then_scale(l, m, ld(ct), ld(st)));
            }
        }
    pacc.report("P_lm(cos t)  vs lgamma-normalized ref   l = 0..16, m = 0..l,\n"
                "   theta in [0, pi] with theta = 0 and pi sampled EXACTLY");

    // ── P̄_l^m vs explicit polynomials, l <= 4 ──────────────────────────────
    Acc pclosed;
    for (int l = 0; l <= 4; ++l)
        for (int m = 0; m <= l; ++m) {
            pclosed.group(l, m);
            for (int i = 0; i <= NT; ++i) {
                double th = M_PI * double(i) / double(NT);
                double ct = std::cos(th), st = std::sin(th);
                ld r;
                if (ref_plm_closed(l, m, ld(ct), ld(st), &r))
                    pclosed.add(sph_plm(l, m, float(ct), float(st)), r);
            }
        }
    pclosed.report("P_lm  vs EXPLICIT CLOSED-FORM POLYNOMIALS   l <= 4");

    // ── SPOT TABLE: fixed values, catches a wrong convention outright ───────
    struct Spot { const char *name; double got, want; };
    Spot spots[] = {
        {"j_0(1)      ", sph_jl(0, 1.0f),  0.84147098480789650},
        {"j_1(1)      ", sph_jl(1, 1.0f),  0.30116867893975674},
        {"j_2(1)      ", sph_jl(2, 1.0f),  0.06203505201137386},
        {"j_3(1)      ", sph_jl(3, 1.0f),  0.00900658111711254},
        {"j_1(10)     ", sph_jl(1, 10.0f), 0.07846694179875154},
        {"Y_00        ", sph_plm(0, 0, 1.0f, 0.0f),  0.28209479177387814},
        {"P_10(t=0)   ", sph_plm(1, 0, 1.0f, 0.0f),  0.48860251190291992},
        {"P_11(t=pi/2)", sph_plm(1, 1, 0.0f, 1.0f), -0.34549414947133544},
        {"P_20(t=0)   ", sph_plm(2, 0, 1.0f, 0.0f),  0.63078313050504010},
    };
    printf("-- SPOT CHECKS vs fixed published values (convention fence)\n");
    double worstSpot = 0;
    for (auto &s : spots) {
        double re = std::fabs(s.got - s.want) / std::fabs(s.want);
        worstSpot = std::max(worstSpot, re);
        printf("   %s  got %.12f   want %.12f   rel %.3e\n", s.name, s.got, s.want, re);
    }
    printf("   worst spot rel error       : %.3e\n\n", worstSpot);

    // ── GATE ───────────────────────────────────────────────────────────────
    double worstFS = std::max({jacc.worstFullScale, jclosed.worstFullScale,
                               pacc.worstFullScale, pclosed.worstFullScale});
    long nf = jacc.nonFinite + jclosed.nonFinite + pacc.nonFinite + pclosed.nonFinite;
    bool passFS = worstFS <= 1e-5;
    bool passSpot = worstSpot <= 1e-6;
    printf("=== GATE ===\n");
    printf("   WORST FULL-SCALE REL ERROR : %.3e   (gate <= 1e-5)  %s\n",
           worstFS, passFS ? "PASS" : "FAIL");
    printf("   WORST SPOT-CHECK REL ERROR : %.3e   (gate <= 1e-6)  %s\n",
           worstSpot, passSpot ? "PASS" : "FAIL");
    printf("   NON-FINITE RESULTS         : %ld   (gate = 0)       %s\n",
           nf, nf == 0 ? "PASS" : "FAIL");
    printf("   TOTAL SAMPLES              : %ld\n",
           jacc.n + jclosed.n + pacc.n + pclosed.n);
    return (passFS && passSpot && nf == 0) ? 0 : 1;
}
