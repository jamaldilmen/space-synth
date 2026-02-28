#include "core/lut.h"
#include "core/bessel.h"
#include <cmath>
#include <algorithm>

namespace space {

GradientLUT makeLUT(int m, int n, double alpha) {
    GradientLUT lut;
    const float eps = 2.0f / LUT_GRID;

    for (int iy = 0; iy < LUT_GRID; iy++) {
        for (int ix = 0; ix < LUT_GRID; ix++) {
            float px = static_cast<float>(ix) / (LUT_GRID - 1) * 2.0f - 1.0f;
            float py = static_cast<float>(iy) / (LUT_GRID - 1) * 2.0f - 1.0f;
            float rr = std::sqrt(px * px + py * py);
            int base = (iy * LUT_GRID + ix) * 2;

            if (rr > 0.96f || rr < 0.001f) continue;

            // Central difference for dP/dx
            float pxp = px + eps, pxm = px - eps;
            double r1 = std::sqrt(pxp * pxp + py * py);
            double r2 = std::sqrt(pxm * pxm + py * py);
            lut.data[base] = static_cast<float>(
                (potential(m, alpha, r1, std::atan2(py, pxp)) -
                 potential(m, alpha, r2, std::atan2(py, pxm))) / (2.0 * eps));

            // Central difference for dP/dy
            float pyp = py + eps, pym = py - eps;
            double r3 = std::sqrt(px * px + pyp * pyp);
            double r4 = std::sqrt(px * px + pym * pym);
            lut.data[base + 1] = static_cast<float>(
                (potential(m, alpha, r3, std::atan2(pyp, px)) -
                 potential(m, alpha, r4, std::atan2(pym, px))) / (2.0 * eps));
        }
    }

    // Normalize: find max gradient magnitude, scale to [-1, 1]
    float maxMag = 0.0f;
    for (int i = 0; i < LUT_GRID * LUT_GRID; i++) {
        float gx = lut.data[i * 2];
        float gy = lut.data[i * 2 + 1];
        float mag = std::sqrt(gx * gx + gy * gy);
        maxMag = std::max(maxMag, mag);
    }

    if (maxMag > 0.0f) {
        for (auto& v : lut.data) v /= maxMag;
    }

    return lut;
}

std::pair<float, float> sampleLUT(const GradientLUT& lut, float px, float py) {
    float fx = (px + 1.0f) / 2.0f * (LUT_GRID - 1);
    float fy = (py + 1.0f) / 2.0f * (LUT_GRID - 1);

    int ix = std::clamp(static_cast<int>(fx), 0, LUT_GRID - 2);
    int iy = std::clamp(static_cast<int>(fy), 0, LUT_GRID - 2);

    float tx = fx - ix;
    float ty = fy - iy;

    int a = (iy * LUT_GRID + ix) * 2;
    int b = a + 2;
    int c = ((iy + 1) * LUT_GRID + ix) * 2;
    int d = c + 2;

    float gx = (1 - ty) * ((1 - tx) * lut.data[a]     + tx * lut.data[b]) +
                    ty  * ((1 - tx) * lut.data[c]     + tx * lut.data[d]);
    float gy = (1 - ty) * ((1 - tx) * lut.data[a + 1] + tx * lut.data[b + 1]) +
                    ty  * ((1 - tx) * lut.data[c + 1] + tx * lut.data[d + 1]);

    return {gx, gy};
}

const GradientLUT& LUTCache::get(int m, int n, double alpha) {
    std::string key = std::to_string(m) + "_" + std::to_string(n);
    auto it = cache_.find(key);
    if (it != cache_.end()) return it->second;
    cache_[key] = makeLUT(m, n, alpha);
    return cache_[key];
}

void LUTCache::clear() {
    cache_.clear();
}

} // namespace space
