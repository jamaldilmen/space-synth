#pragma once
#include <string>

namespace space {

// ADSR envelope — per-voice amplitude tracker
// Ported from SOUND ARCHITECT.html envelope system
enum class EnvPhase {
    Attack,
    Decay,
    Sustain,
    Release,
    Off
};

struct EnvelopeParams {
    float attack  = 0.020f;  // seconds
    float decay   = 0.100f;  // seconds
    float sustain = 0.700f;  // level (0-1)
    float release = 0.400f;  // seconds
};

struct Envelope {
    EnvPhase phase = EnvPhase::Off;
    float amplitude = 0.0f;
    float targetAmp = 0.0f;
    float envTime = 0.0f;
    float envStart = 0.0f;

    // Trigger attack phase
    void noteOn(float velocity = 1.0f);

    // Trigger release phase
    void noteOff();

    // Advance envelope by dt seconds, returns current amplitude
    float update(float dt, const EnvelopeParams& params);

    bool isActive() const { return phase != EnvPhase::Off; }
};

} // namespace space
