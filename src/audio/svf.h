#pragma once
#include <cmath>

namespace space {

// A standard digital State Variable Filter (SVF)
// Capable of Lowpass, Highpass, Bandpass outputs
class SVF {
public:
  void setSampleRate(float sr) { sampleRate_ = sr; }

  // Set parameters
  // cutoff: frequency in Hz
  // resonance: 0.0 to 1.0 (higher = sharper peak)
  void set(float cutoff, float resonance) {
    float f = cutoff / sampleRate_;
    // Prewarp the cutoff frequency
    f = 2.0f * std::sin(M_PI * std::fmin(0.49f, f));

    // Calculate filter coefficients
    q_ = 1.0f - resonance;
    f_ = f;
  }

  // Process a single sample through the filter
  // Returns the Lowpass output (can be modified to return HP/BP)
  float process(float input) {
    // 2x oversampling to improve stability at high frequencies
    for (int i = 0; i < 2; ++i) {
      low_ = low_ + f_ * band_;
      float high = input - low_ - q_ * band_;
      band_ = band_ + f_ * high;
    }
    return low_;
  }

  void reset() {
    low_ = 0.0f;
    band_ = 0.0f;
  }

private:
  float sampleRate_ = 48000.0f;
  float f_ = 0.0f;
  float q_ = 0.0f;

  // State variables
  float low_ = 0.0f;
  float band_ = 0.0f;
};

} // namespace space
