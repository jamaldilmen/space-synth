#pragma once
#include <cmath>
#include <vector>

namespace space {

// A simple dual-delay line Bucket-Brigade Chorus (Juno style)
class Chorus {
public:
  Chorus();
  void init(float sampleRate);

  // Process a stereo sample
  void process(float inL, float inR, float &outL, float &outR);

  // Parameters
  void setRate(float hz) { rate_ = hz; }
  float rate() const { return rate_; }

  void setDepth(float ms) { depth_ = ms; }
  float depth() const { return depth_; }

  void setMix(float mix) { mix_ = mix; }
  float mix() const { return mix_; }

  void setEnabled(bool e) { enabled_ = e; }
  bool enabled() const { return enabled_; }

private:
  float sampleRate_ = 48000.0f;
  std::vector<float> bufferL_;
  std::vector<float> bufferR_;
  int writePos_ = 0;
  float lfoPhase_ = 0.0f;

  bool enabled_ = true;
  float rate_ = 0.5f;  // Hz
  float depth_ = 2.0f; // ms
  float mix_ = 0.5f;   // 0 = dry, 1 = wet

  float getDelayedSample(const std::vector<float> &buffer,
                         float delaySamples) const;
};

} // namespace space
