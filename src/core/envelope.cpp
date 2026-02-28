#include "core/envelope.h"
#include <algorithm>
#include <cmath>

namespace space {

void Envelope::noteOn(float velocity) {
    phase = EnvPhase::Attack;
    targetAmp = velocity;
    envTime = 0.0f;
    envStart = amplitude;  // start from current level (retrigger smoothing)
}

void Envelope::noteOff() {
    if (phase == EnvPhase::Off) return;
    phase = EnvPhase::Release;
    envTime = 0.0f;
    envStart = amplitude;
}

float Envelope::update(float dt, const EnvelopeParams& params) {
    envTime += dt;

    switch (phase) {
        case EnvPhase::Attack: {
            float t = std::min(1.0f, envTime / std::max(0.001f, params.attack));
            amplitude = envStart + (targetAmp - envStart) * t;
            if (t >= 1.0f) {
                phase = EnvPhase::Decay;
                envTime = 0.0f;
                envStart = amplitude;
            }
            break;
        }
        case EnvPhase::Decay: {
            float t = std::min(1.0f, envTime / std::max(0.001f, params.decay));
            float sustainLevel = targetAmp * params.sustain;
            amplitude = envStart + (sustainLevel - envStart) * t;
            if (t >= 1.0f) {
                phase = EnvPhase::Sustain;
                amplitude = sustainLevel;
            }
            break;
        }
        case EnvPhase::Sustain: {
            amplitude = targetAmp * params.sustain;
            break;
        }
        case EnvPhase::Release: {
            float t = std::min(1.0f, envTime / std::max(0.001f, params.release));
            amplitude = envStart * (1.0f - t);
            if (t >= 1.0f) {
                phase = EnvPhase::Off;
                amplitude = 0.0f;
            }
            break;
        }
        case EnvPhase::Off: {
            amplitude = 0.0f;
            break;
        }
    }

    return amplitude;
}

} // namespace space
