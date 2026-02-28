#pragma once
#include <array>
#include <cmath>

namespace space {

// Bessel function of the first kind, order n
// Ported from SOUND ARCHITECT.html — power series with 25 terms
double besselJ(int n, double x);

// Zeros of J_n(x) for n=0..6, first 4 zeros each
// ZEROS[n][k] = k-th zero of J_n
// From the original: drives mode frequencies and nodal patterns
constexpr int MAX_ORDER = 7;   // m = 0..6
constexpr int MAX_ZEROS = 4;   // n = 1..4 (using 0-indexed: 0..3)

extern const std::array<std::array<double, MAX_ZEROS>, MAX_ORDER> ZEROS;

// Z² = (J_m(α·r) · cos(mθ))² — squared displacement field
double Z2(int m, double alpha, double r, double th);

// Potential function with boundary repulsion
// Returns Z² + cubic ramp for r > 0.85, hard wall at r > 0.98
double potential(int m, double alpha, double r, double th);

} // namespace space
