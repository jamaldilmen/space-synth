#include "core/envelope.h"
#include <algorithm>
#include <cmath>

namespace space {

void Envelope::noteOn(float velocity) {
  phase = EnvPhase::Attack;
  targetAmp = velocity;
  envTime = 0.0f;
  envStart = amplitude; // start from current level (retrigger smoothing)
}

void Envelope::noteOff() {
  if (phase == EnvPhase::Off)
    return;
  phase = EnvPhase::Release;
  envTime = 0.0f;
  envStart = amplitude;
}

float Envelope::update(float dt, const EnvelopeParams &params) {
  envTime += dt;

  switch (phase) {
  case EnvPhase::Attack: {
    // Exponential approach to targetAmp
    // y = target - (target - start) * exp(-k*t) -> simplified for our dt
    float k =
        5.0f /
        std::max(0.001f, params.attack); // reaches 99.3% in 'attack' seconds
    amplitude = targetAmp - (targetAmp - envStart) * std::exp(-k * envTime);
    if (envTime >= params.attack) {
      phase = EnvPhase::Decay;
      envTime = 0.0f;
      envStart = amplitude;
      amplitude = targetAmp; // Force exactly target on transition
    }
    break;
  }
  case EnvPhase::Decay: {
    float sustainLevel = targetAmp * params.sustain;
    float k = 5.0f / std::max(0.001f, params.decay);
    amplitude =
        sustainLevel + (envStart - sustainLevel) * std::exp(-k * envTime);
    if (envTime >= params.decay) {
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
    float k = 5.0f / std::max(0.001f, params.release);
    amplitude = envStart * std::exp(-k * envTime);
    if (envTime >= params.release || amplitude < 0.0001f) {
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
