#pragma once
#include <array>
#include <unordered_map>
#include <vector>
#include <string>

namespace space {

// Gradient Look-Up Table for a single Chladni mode
// Stores pre-computed gradient of the potential field on a 2D grid
// Each cell holds (dP/dx, dP/dy) — the force direction for particles
constexpr int LUT_GRID = 128;

struct GradientLUT {
    // Interleaved (gx, gy) pairs — LUT_GRID × LUT_GRID × 2
    std::vector<float> data;

    GradientLUT() : data(LUT_GRID * LUT_GRID * 2, 0.0f) {}
};

// Build a gradient LUT for mode (m, n) with Bessel zero alpha
// Uses central differencing of the potential function, then normalizes
GradientLUT makeLUT(int m, int n, double alpha);

// Bilinear sample from a LUT at position (px, py) in [-1, 1]
// Returns (gx, gy) gradient
std::pair<float, float> sampleLUT(const GradientLUT& lut, float px, float py);

// Global LUT cache — keyed by "m_n"
class LUTCache {
public:
    const GradientLUT& get(int m, int n, double alpha);
    void clear();

private:
    std::unordered_map<std::string, GradientLUT> cache_;
};

} // namespace space
