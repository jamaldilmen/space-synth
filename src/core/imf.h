#pragma once
#include <cstdint>
#include <cmath>

// ── Kroupa-IMF stellar mass per particle id ──────────────────────────────────
// EXACT CPU mirror of the star-map draw in render.metal (same hash, same
// inverse-CDF, same float math) so the mass the PHYSICS carries in posW.w is
// the SAME mass the render shows as size/brightness/colour. One star, one
// mass, both worlds. dN/dM ∝ M^-2.3, M ∈ [0.08, 50] M_sun → mean ≈ 0.30 M_sun.
// Deterministic per id: respawns/resets reproduce the identical cluster.

namespace space {
namespace imf {

inline float massOfId(uint32_t id) {
  uint32_t h = id * 2654435761u;
  h ^= h >> 15;
  h *= 0x2c1b3c6du;
  h ^= h >> 12;
  float u01 = (float)(h & 0xFFFFFFu) / (float)0xFFFFFF;
  const float aI = std::pow(0.08f, -1.3f);
  const float bI = std::pow(50.0f, -1.3f);
  return std::pow(aI + u01 * (bI - aI), 1.0f / -1.3f);
}

// Σ mass of the first `count` ids, in M_sun — THE field mass for gravGM and
// the spawn orbits. O(count) once per respawn/count change.
inline double totalMassMsun(int count) {
  double s = 0.0;
  for (int i = 0; i < count; i++) s += (double)massOfId((uint32_t)i);
  return s;
}

} // namespace imf
} // namespace space
