#pragma once
#include <cmath>

namespace space {

static constexpr int MAX_EMITTERS = 16;

struct Emitter {
  float x = 0.0f;
  float y = 0.0f;
  float z = 0.0f;
  bool active = false;
};

// Manages point source emitter positions
// Each voice can have its own emitter position for wave origin
class EmitterArray {
public:
  Emitter &operator[](int i) { return emitters_[i]; }
  const Emitter &operator[](int i) const { return emitters_[i]; }

  void reset() {
    for (int i = 0; i < MAX_EMITTERS; i++) {
      emitters_[i] = {};
    }
  }

  // Arrange emitters evenly across a 3D sphere using a Fibonacci lattice
  void arrangeSphere(int count, float radius) {
    if (count == 0)
      return;
    if (count == 1) {
      emitters_[0] = {0.0f, 0.0f, 0.0f, true};
      for (int i = 1; i < MAX_EMITTERS; i++)
        emitters_[i] = {};
      return;
    }

    float goldenRatio = (1.0f + sqrtf(5.0f)) / 2.0f;
    float angleIncrement = 2.0f * 3.1415926535f * goldenRatio;

    for (int i = 0; i < MAX_EMITTERS; i++) {
      if (i < count) {
        float t = (float)i / (float)(count - 1);
        float z = 1.0f - (t * 2.0f); // Map t from [0, 1] to [1, -1]
        float r = sqrtf(fmax(0.0f, 1.0f - z * z));
        float theta = angleIncrement * i;

        emitters_[i].x = radius * r * cosf(theta);
        emitters_[i].y = radius * r * sinf(theta);
        emitters_[i].z = radius * z;
        emitters_[i].active = true;
      } else {
        emitters_[i] = {};
      }
    }
  }

private:
  Emitter emitters_[MAX_EMITTERS] = {};
};

} // namespace space
