#include "core/envelope.h"
#include <algorithm>
#include <cmath>

namespace space {

void Envelope::noteOn(float velocity) {
  phase = EnvPhase::Attack;
  targetAmp = velocity;
  envTime = 0.0f;
  noteAge = 0.0f; // the note-length clock starts HERE and is never reset again
  envStart = amplitude; // start from current level (retrigger smoothing)
}

void Envelope::noteOff() {
  if (phase == EnvPhase::Off)
    return;
  sustainHeld = noteAge; // TRUE note length (envTime resets on Attack->Decay)
  phase = EnvPhase::Release;
  envTime = 0.0f;
  envStart = amplitude;
}

float Envelope::update(float dt, const EnvelopeParams &params) {
  envTime += dt;
  noteAge += dt;

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
    // ── MIDI LENGTH DICTATES THE TAIL (2026-08-23, his order) ──────────────
    // WAS: clamp(sustainHeld, params.release, 1.5f) — with params.release as
    // the LOWER bound. That gave EVERY note a tail of at least the Release knob
    // (400 ms by default) no matter how short it was, so a 10 ms arp note
    // produced ~400 ms of visual — 40x the note. At a 10 ms arp ~40 voices
    // overlapped, getDominantEnvelope() ranks Attack highest, so the phase the
    // GPU sees pinned to Attack and never resolved. That was "the sim gets
    // stuck", and it is why note length did not read on screen.
    //
    // NOW: the Release knob is the CEILING, not the floor. The tail is the note
    // itself, capped by the knob. A 10 ms note tails for 10 ms; a note held
    // past the knob tails for exactly the knob. The knob still does its whole
    // job (1 ms .. 2 s in the UI) — it now sets the LONGEST tail, not the
    // shortest. kMinTail only exists to keep the collapse from clicking.
    // ⚠️ ONE BEHAVIOUR CHANGE: a long hold used to always reach up to 1.5 s
    // regardless of the knob. It now honours the knob. Turn Release up for the
    // old feel.
    constexpr float kMinTail = 0.012f; // ~one buffer; anti-click floor only
    const float maxTail = std::min(params.release, 1.5f);
    float relDur = std::clamp(sustainHeld, kMinTail, std::max(kMinTail, maxTail));
    float k = 5.0f / std::max(0.001f, relDur);
    amplitude = envStart * std::exp(-k * envTime);
    if (envTime >= relDur || amplitude < 0.0001f) {
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
