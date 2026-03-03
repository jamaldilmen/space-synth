#include "core/particles.h"
#include <cmath>
#include <random>

namespace space {

void ParticleSystem::init(int count, float maxWaveDepth) {
    maxWaveDepth_ = maxWaveDepth;
    particles_.resize(count);

    std::mt19937 rng(42);
    std::uniform_real_distribution<float> angle(0.0f, 2.0f * M_PI);
    std::uniform_real_distribution<float> radius(0.0f, 1.0f);
    std::uniform_real_distribution<float> depth(-1.0f, 1.0f);

    for (auto& p : particles_) {
        float a = angle(rng);
        float r = std::sqrt(radius(rng)) * 0.95f;
        p.x = r * std::cos(a);
        p.y = r * std::sin(a);
        p.z = depth(rng) * maxWaveDepth;
        p.vx = 0.0f;
        p.vy = 0.0f;
        p.vz = 0.0f;
    }
}

void ParticleSystem::clear() {
    particles_.clear();
}

std::vector<GPUParticle> packForGPU(const ParticleSystem& system) {
    std::vector<GPUParticle> gpu(system.count());
    for (int i = 0; i < system.count(); i++) {
        const auto& p = system.data()[i];
        gpu[i] = {
            p.x, p.y, p.z, 1.0f,       // pos + mass
            p.vx, p.vy, p.vz, 0.0f,     // vel + phase
            p.x, p.y, p.z, 0.0f         // prevPos = pos (zero initial velocity for Verlet)
        };
    }
    return gpu;
}

} // namespace space
