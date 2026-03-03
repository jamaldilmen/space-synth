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
    Emitter& operator[](int i) { return emitters_[i]; }
    const Emitter& operator[](int i) const { return emitters_[i]; }

    void reset() {
        for (int i = 0; i < MAX_EMITTERS; i++) {
            emitters_[i] = {};
        }
    }

    // Arrange emitters in a circle of given radius
    void arrangeCircle(int count, float radius) {
        for (int i = 0; i < MAX_EMITTERS; i++) {
            if (i < count) {
                float angle = (float)i / (float)count * 6.28318530718f;
                emitters_[i].x = radius * cosf(angle);
                emitters_[i].y = radius * sinf(angle);
                emitters_[i].z = 0.0f;
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
