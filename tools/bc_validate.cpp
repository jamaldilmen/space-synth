// bc_validate.cpp — independent re-derivation of the Schwarzschild critical
// impact parameter b_c by ACTUALLY INTEGRATING NULL GEODESICS.
//
// Board row BH8 / BH board L9: render.metal:3086 and app_state.h:53 both cite a
// "scratchpad bc_validate.cpp" that has never existed in this tree. This file
// re-derives the number from scratch so the claim stops being unverifiable.
//
// NOTHING HERE PRINTS A CLOSED FORM AS ITS ANSWER. Each method bisects on the
// impact parameter b between "the ray fell in" and "the ray came back out to
// infinity". The analytic 3*sqrt(3)*M is printed ONLY at the end, as the thing
// being checked against.
//
// PROJECT UNIT CONVENTION (established from source, not assumed):
//   src/spacetime/spacetime.h:64   rsSim(m) = 2*gmSim(m)/(kCSim*kCSim)
//   src/spacetime/spacetime.h:52   kCSim  ==  1  (static_assert :97)
//   src/spacetime/spacetime.h:98   static_assert rsSim(M_field) == 1.0
//   => geometrized c = G = 1, r_s = 2M, therefore  M = r_s/2.
//   The shader marches in units of r_s (render.metal:3271-3274), so in ITS
//   units M = 0.5 and the answer to expect is 3*sqrt(3)*M = 3*sqrt(3)/2 r_s.
//
// Build (no part of the app build):
//   clang++ -std=c++17 -O2 -o /tmp/bc_validate tools/bc_validate.cpp

#include <cstdio>
#include <cmath>
#include <algorithm>

// ═════════════════════════════════════════════════════════════════════════════
// METHOD A — exact Schwarzschild orbit equation, units M = 1.
//
// Derivation used (no weak field anywhere):
//   Killing vectors give  E = (1-2M/r) dt/dl,  L = r^2 dphi/dl.
//   Null norm g_ab u^a u^b = 0 gives
//       (dr/dl)^2 = E^2 - (L^2/r^2)(1 - 2M/r).
//   With u = 1/r and b = L/E, changing variable to phi gives the first integral
//       (du/dphi)^2 = 1/b^2 - u^2 (1 - 2 M u)
//   and differentiating,
//       d^2u/dphi^2 = 3 M u^2 - u.
//   We integrate THAT second-order system in phi; the first integral is used
//   only to set the initial du/dphi and is monitored as a conservation check.
// ═════════════════════════════════════════════════════════════════════════════

struct FateA { bool captured; double rmin; double driftMax; };

static FateA integrateA(double b, double M, double r0, double dphi, int maxSteps)
{
    const double uH = 1.0 / (2.0 * M);      // horizon u = 1/(2M)
    double u = 1.0 / r0;
    double inv = 1.0 / (b * b) - u * u * (1.0 - 2.0 * M * u);
    if (inv <= 0.0) return {false, r0, 0.0};   // cannot even be at r0 with this b
    // INCOMING means r DECREASING, i.e. u = 1/r INCREASING as phi advances,
    // so this branch is +sqrt, not -sqrt. (Getting this backwards makes every
    // ray "escape" immediately and the bisection reports the bracket edge.)
    double w = +std::sqrt(inv);
    const double C0 = 1.0 / (b * b);            // the conserved combination

    double umax = u, driftMax = 0.0;
    auto acc = [&](double uu) { return 3.0 * M * uu * uu - uu; };

    for (int i = 0; i < maxSteps; ++i) {
        // adaptive: fine steps where u is large (near the hole), coarse far out
        double h = dphi;

        double k1u = w,               k1w = acc(u);
        double k2u = w + 0.5*h*k1w,   k2w = acc(u + 0.5*h*k1u);
        double k3u = w + 0.5*h*k2w,   k3w = acc(u + 0.5*h*k2u);
        double k4u = w + h*k3w,       k4w = acc(u + h*k3u);
        u += (h/6.0)*(k1u + 2*k2u + 2*k3u + k4u);
        w += (h/6.0)*(k1w + 2*k2w + 2*k3w + k4w);

        if (u > umax) umax = u;

        // conservation monitor: w^2 + u^2(1-2Mu) should stay at 1/b^2
        double C = w*w + u*u*(1.0 - 2.0*M*u);
        driftMax = std::max(driftMax, std::fabs(C - C0) / C0);

        if (u >= uH)  return {true,  1.0/umax, driftMax};   // crossed the horizon
        if (u <= 0.0) return {false, 1.0/umax, driftMax};   // out past r0, escaped
        // turned around (w < 0 = u falling = r growing) and made it back to r0
        if (w < 0.0 && u <= 1.0/r0) return {false, 1.0/umax, driftMax};
    }
    // ran out of phi without deciding: near-critical winding -> treat as captured
    return {true, 1.0/umax, driftMax};
}

// ═════════════════════════════════════════════════════════════════════════════
// METHOD B — the SHIPPED shader ODE, verbatim.
//
//   render.metal:3593-3605:  accel = -(3/2) * h^2 * x / r^5,   r_s = 1
//   render.metal:3277:       dl = stepScale * r * sqrt(r)
//   render.metal:3335:       captured when r < 1.0 (= r_s)
//   render.metal:3336:       escaped   when r > rMarchStart*1.02 and dot(x,v) > 0
//   render.metal:3266-3275:  ray back-extended to r = rMarchStart (60) r_s
//
// Templated on the scalar type so we can run it in the shader's own float
// precision as well as in double.
// ═════════════════════════════════════════════════════════════════════════════

template <typename T>
struct V3 { T x, y, z; };

template <typename T>
static V3<T> add(V3<T> a, V3<T> b_) { return {a.x+b_.x, a.y+b_.y, a.z+b_.z}; }
template <typename T>
static V3<T> mul(V3<T> a, T s)      { return {a.x*s, a.y*s, a.z*s}; }
template <typename T>
static T len(V3<T> a) { return (T)std::sqrt((double)(a.x*a.x + a.y*a.y + a.z*a.z)); }
template <typename T>
static V3<T> crossv(V3<T> a, V3<T> b_) {
    return { a.y*b_.z - a.z*b_.y, a.z*b_.x - a.x*b_.z, a.x*b_.y - a.y*b_.x };
}

struct FateB { bool captured; double rmin; double h2drift; int steps; };

// coef is the (3/2) in front: 1.5 = correct (r_s=1 => 3M with M=0.5).
// The banner claims 0.5 (the "half-strength" coefficient) gives b_c = sqrt(2).
template <typename T>
static FateB integrateB(double bIn, double coefIn, double stepScaleIn,
                        double rStartIn, int maxSteps)
{
    const T coef      = (T)coefIn;
    const T stepScale = (T)stepScaleIn;
    const T rStart    = (T)rStartIn;
    const T b         = (T)bIn;

    // Back-extend to r = rStart along +x with perpendicular offset b (this is
    // exactly what the shader's tStart root does for a ray of impact param b).
    T sx = -(T)std::sqrt(std::max(0.0, (double)(rStart*rStart - b*b)));
    V3<T> x { sx, b, (T)0 };
    V3<T> v { (T)1, (T)0, (T)0 };

    V3<T> hv = crossv(x, v);
    T h2 = hv.x*hv.x + hv.y*hv.y + hv.z*hv.z;
    const double h2_0 = (double)h2;
    const T rEsc = rStart * (T)1.02;

    double rmin = (double)len(x), drift = 0.0;

    auto accel = [&](V3<T> p) -> V3<T> {
        T q = len(p);
        T q5 = q*q*q*q*q;
        return mul(p, (T)(-coef * h2 / q5));
    };

    for (int i = 0; i < maxSteps; ++i) {
        T r = len(x);
        rmin = std::min(rmin, (double)r);
        if (r < (T)1.0) return {true, rmin, drift, i};                  // captured
        if (r > rEsc && (x.x*v.x + x.y*v.y + x.z*v.z) > (T)0)
            return {false, rmin, drift, i};                             // escaped

        T dl = stepScale * r * (T)std::sqrt((double)r);

        V3<T> a1 = accel(x);
        V3<T> x2 = add(x, mul(v,  dl*(T)0.5)), v2 = add(v, mul(a1, dl*(T)0.5));
        V3<T> a2 = accel(x2);
        V3<T> x3 = add(x, mul(v2, dl*(T)0.5)), v3 = add(v, mul(a2, dl*(T)0.5));
        V3<T> a3 = accel(x3);
        V3<T> x4 = add(x, mul(v3, dl)),        v4 = add(v, mul(a3, dl));
        V3<T> a4 = accel(x4);

        V3<T> dx = add(add(v, mul(v2,(T)2)), add(mul(v3,(T)2), v4));
        V3<T> dv = add(add(a1, mul(a2,(T)2)), add(mul(a3,(T)2), a4));
        x = add(x, mul(dx, dl/(T)6));
        v = add(v, mul(dv, dl/(T)6));

        V3<T> hn = crossv(x, v);
        double h2n = (double)(hn.x*hn.x + hn.y*hn.y + hn.z*hn.z);
        drift = std::max(drift, std::fabs(h2n - h2_0) / h2_0);
    }
    return {true, rmin, drift, maxSteps};
}

// ═════════════════════════════════════════════════════════════════════════════
// Bisection driver — shared. lo must be a CAPTURED b, hi an ESCAPING b.
// ═════════════════════════════════════════════════════════════════════════════
template <typename F>
static double bisect(F captured, double lo, double hi, int iters)
{
    for (int i = 0; i < iters; ++i) {
        double mid = 0.5 * (lo + hi);
        if (captured(mid)) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}

int main()
{
    const double analyticOverM  = 3.0 * std::sqrt(3.0);          // b_c / M
    const double analyticOverRs = 3.0 * std::sqrt(3.0) / 2.0;    // b_c / r_s  (M = r_s/2)

    printf("=====================================================================\n");
    printf(" bc_validate  —  independent numerical b_c for Schwarzschild\n");
    printf(" convention from src/spacetime/spacetime.h:64  r_s = 2M  =>  M = r_s/2\n");
    printf("=====================================================================\n\n");

    // ---- METHOD A: exact orbit equation, units M = 1 -------------------------
    {
        // r0 only has to sit outside the photon sphere: the first integral is
        // exact, so the capture separatrix does not depend on where we start.
        const double M = 1.0, r0 = 1.0e3, dphi = 1.0e-4;
        const int steps = 2000000;   // phi_max = 200 rad, enough for the winding
        double lastDrift = 0.0, rminEsc = 0.0;

        auto cap = [&](double b) {
            FateA f = integrateA(b, M, r0, dphi, steps);
            lastDrift = std::max(lastDrift, f.driftMax);
            return f.captured;
        };
        // sanity: bracket must be genuinely capture / escape
        FateA lo = integrateA(4.0, M, r0, dphi, steps);
        FateA hi = integrateA(7.0, M, r0, dphi, steps);
        printf("METHOD A  — exact null-geodesic orbit equation  d2u/dphi2 = 3Mu^2 - u\n");
        printf("            units M = 1, start r0 = %.0f M, dphi = %.0e, phi_max = %.0f rad\n", r0, dphi, dphi*steps);
        printf("            bracket check: b=4.0 -> %s   b=7.0 -> %s\n",
               lo.captured ? "CAPTURED" : "escaped",
               hi.captured ? "captured" : "ESCAPES");

        double bcA = bisect(cap, 4.0, 7.0, 50);
        FateA just = integrateA(bcA * 1.000001, M, r0, dphi, steps);
        rminEsc = just.rmin;

        printf("            b_c (bisected, 50 iters)   = %.12f  M\n", bcA);
        printf("            analytic 3*sqrt(3)*M       = %.12f  M\n", analyticOverM);
        printf("            abs err = %.3e   rel err = %.3e\n",
               std::fabs(bcA - analyticOverM),
               std::fabs(bcA - analyticOverM) / analyticOverM);
        printf("            ray just OUTSIDE b_c skims rmin = %.6f M  (photon sphere = 3M)\n",
               rminEsc);
        printf("            first-integral drift max   = %.3e\n\n", lastDrift);
        printf("            same number expressed in r_s: %.12f r_s  (analytic %.12f)\n\n",
               bcA / 2.0, analyticOverRs);
    }

    // ---- METHOD B: the shipped shader ODE, units r_s = 1 ---------------------
    struct Cfg { const char* name; double coef; double stepScale; double rStart; int maxSteps; bool dbl; };
    Cfg cfgs[] = {
        { "shader as shipped  (coef 1.5, step 0.03, R=60, float)", 1.5, 0.03, 60.0, 20000, false },
        { "shader ODE in double (coef 1.5, step 0.03, R=60)      ", 1.5, 0.03, 60.0, 20000, true  },
        { "tightened          (coef 1.5, step 0.002, R=2000)     ", 1.5, 0.002, 2000.0, 4000000, true },
        { "shader step 0.10   (coef 1.5, step 0.10, R=60, float) ", 1.5, 0.10, 60.0, 20000, false },
        { "HALF coefficient   (coef 0.5, step 0.002, R=2000)     ", 0.5, 0.002, 2000.0, 4000000, true },
    };

    printf("METHOD B  — the SHIPPED shader integrator, verbatim (render.metal:3593)\n");
    printf("            accel = -coef * h^2 * x / r^5 ,  r_s = 1 ,  capture at r < 1\n");
    printf("            (coef 1.5 == 3M with M = r_s/2 = 0.5)\n\n");
    printf("  %-56s %-16s %-12s %-10s\n", "configuration", "b_c [r_s]", "rmin(esc)", "h^2 drift");
    printf("  %s\n", "-----------------------------------------------------------------------------------------------");

    double bcShipped = 0.0;
    for (const Cfg& c : cfgs) {
        double maxDrift = 0.0;
        auto cap = [&](double b) {
            FateB f = c.dbl ? integrateB<double>(b, c.coef, c.stepScale, c.rStart, c.maxSteps)
                            : integrateB<float> (b, c.coef, c.stepScale, c.rStart, c.maxSteps);
            maxDrift = std::max(maxDrift, f.h2drift);
            return f.captured;
        };
        double bc = bisect(cap, 0.2, 6.0, 60);
        FateB just = c.dbl ? integrateB<double>(bc*1.00001, c.coef, c.stepScale, c.rStart, c.maxSteps)
                           : integrateB<float> (bc*1.00001, c.coef, c.stepScale, c.rStart, c.maxSteps);
        printf("  %-56s %-16.8f %-12.6f %.2e\n", c.name, bc, just.rmin, maxDrift);
        if (bcShipped == 0.0) bcShipped = bc;
    }

    printf("\n=====================================================================\n");
    printf(" VERDICT\n");
    printf("=====================================================================\n");
    printf("  analytic  3*sqrt(3)*M          = %.10f M\n", analyticOverM);
    printf("  analytic  = 3*sqrt(3)/2 * r_s  = %.10f r_s\n", analyticOverRs);
    printf("  shader constant in source      = 2.5980762   (render.metal:3177, :937, :1104)\n");
    printf("  |shader const - analytic|      = %.3e r_s   (rel %.2e)\n",
           std::fabs(2.5980762 - analyticOverRs),
           std::fabs(2.5980762 - analyticOverRs) / analyticOverRs);
    printf("  Method B shipped-config b_c    = %.8f r_s  (rel err vs analytic %.2e)\n",
           bcShipped, std::fabs(bcShipped - analyticOverRs) / analyticOverRs);
    return 0;
}
