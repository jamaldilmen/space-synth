#include "core/bessel.h"

namespace space {

// Bessel zeros table — J_m zeros for m=0..6, first 4 zeros each
// Sourced from Abramowitz & Stegun / validated against SOUND ARCHITECT.html
const std::array<std::array<double, MAX_ZEROS>, MAX_ORDER> ZEROS = {{
    {{ 2.4048,  5.5201,  8.6537, 11.7915 }},  // J_0
    {{ 3.8317,  7.0156, 10.1735, 13.3237 }},  // J_1
    {{ 5.1356,  8.4172, 11.6198, 14.7960 }},  // J_2
    {{ 6.3802,  9.7610, 13.0152, 16.2235 }},  // J_3
    {{ 7.5883, 11.0647, 14.3725, 17.6160 }},  // J_4
    {{ 8.7715, 12.3386, 15.7002, 18.9801 }},  // J_5
    {{ 9.9361, 13.5893, 17.0038, 20.3208 }},  // J_6
}};

double besselJ(int n, double x) {
    if (std::abs(x) < 1e-10) return n == 0 ? 1.0 : 0.0;

    double sum = 0.0;
    double hx = x / 2.0;

    for (int k = 0; k < 25; k++) {
        double sign = (k % 2 == 0) ? 1.0 : -1.0;
        double num = std::pow(hx, 2 * k + n);

        // k! * (k+n)!
        double den = 1.0;
        for (int i = 1; i <= k; i++) den *= i;
        for (int i = 1; i <= k + n; i++) den *= i;

        double term = sign * num / den;
        sum += term;

        if (std::abs(term) < 1e-15) break;
    }

    return sum;
}

double Z2(int m, double alpha, double r, double th) {
    double j = besselJ(m, alpha * r);
    double a = (m == 0) ? 1.0 : std::cos(m * th);
    return j * a * j * a;
}

double potential(int m, double alpha, double r, double th) {
    if (r > 0.98) return 10.0;
    double p = Z2(m, alpha, r, th);
    if (r > 0.85) {
        double t = (r - 0.85) / 0.13;
        p += 0.5 * t * t * t;
    }
    return p;
}

} // namespace space
