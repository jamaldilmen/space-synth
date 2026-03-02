#include "chorus.h"
#include <cmath>

#ifndef M_PI_F
#define M_PI_F 3.14159265358979323846f
#endif

namespace space {

Chorus::Chorus() {}

void Chorus::init(float sampleRate) {
  sampleRate_ = sampleRate;
  // Initialize with enough buffer for max delay (e.g., 50ms)
  int maxDelaySamples = static_cast<int>(0.05f * sampleRate_) + 2;
  bufferL_.assign(maxDelaySamples, 0.0f);
  bufferR_.assign(maxDelaySamples, 0.0f);
  writePos_ = 0;
  lfoPhase_ = 0.0f;
}

float Chorus::getDelayedSample(const std::vector<float> &buffer,
                               float delaySamples) const {
  int size = static_cast<int>(buffer.size());
  if (size == 0)
    return 0.0f;

  float rp = static_cast<float>(writePos_) - delaySamples;
  while (rp < 0)
    rp += size;

  int i = static_cast<int>(rp);
  float frac = rp - i;
  int iNext = (i + 1) % size;

  // Linear interpolation
  return buffer[i] * (1.0f - frac) + buffer[iNext] * frac;
}

void Chorus::process(float inL, float inR, float &outL, float &outR) {
  if (!enabled_) {
    outL = inL;
    outR = inR;
    return;
  }

  // Base delay (15ms + 4ms oscillation gives a lush chorus without flanging)
  float baseDelayMs = 15.0f;

  // Modulate 90 degrees out of phase (quadrature) for wide stereo
  float lfoL = std::sin(lfoPhase_);
  float lfoR = std::cos(lfoPhase_);

  lfoPhase_ += 2.0f * M_PI_F * rate_ / sampleRate_;
  if (lfoPhase_ >= 2.0f * M_PI_F)
    lfoPhase_ -= 2.0f * M_PI_F;

  float delayLMs = baseDelayMs + lfoL * 4.0f;
  float delayRMs = baseDelayMs + lfoR * 4.0f;

  float delayLSamples = (delayLMs * 0.001f) * sampleRate_;
  float delayRSamples = (delayRMs * 0.001f) * sampleRate_;

  // Write new samples into the delay lines
  bufferL_[writePos_] = inL;
  bufferR_[writePos_] = inR;

  // Read the delayed samples
  float dryL = inL;
  float dryR = inR;
  float wetL = getDelayedSample(bufferL_, delayLSamples);
  float wetR = getDelayedSample(bufferR_, delayRSamples);

  // Mix: Preserve 100% dry signal for bass integrity, add wet on top, then
  // attenuate to prevent clipping
  outL = (dryL + mix_ * wetL) * 0.8f;
  outR = (dryR + mix_ * wetR) * 0.8f;

  // Advance
  writePos_ = (writePos_ + 1) % bufferL_.size();
}

} // namespace space
