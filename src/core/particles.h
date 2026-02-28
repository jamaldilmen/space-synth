#pragma once
#include <vector>
#include <cstdint>

namespace space {

// CPU-side particle state
// Position in normalized plate coords: x,y in [-1,1], z = wave depth
struct Particle {
    float x, y, z;
    float vx, vy, vz;
};

// Manages the particle buffer on CPU side
// GPU-side state is a mirror of this (uploaded each frame or computed on GPU)
class ParticleSystem {
public:
    void init(int count, float maxWaveDepth);
    void clear();

    int count() const { return static_cast<int>(particles_.size()); }
    Particle* data() { return particles_.data(); }
    const Particle* data() const { return particles_.data(); }
    Particle& operator[](int i) { return particles_[i]; }

    float maxWaveDepth() const { return maxWaveDepth_; }
    void setMaxWaveDepth(float d) { maxWaveDepth_ = d; }

private:
    std::vector<Particle> particles_;
    float maxWaveDepth_ = 100.0f;
};

// Packed struct for GPU upload — position + velocity as float4 pairs
struct alignas(16) GPUParticle {
    float x, y, z, pad0;
    float vx, vy, vz, pad1;
};

// Convert CPU particles to GPU buffer format
std::vector<GPUParticle> packForGPU(const ParticleSystem& system);

} // namespace space
