#pragma once
#include <vector>

namespace space {

// FFT-based spectral analysis and pitch detection
// Uses vDSP (Accelerate framework) for hardware-optimized FFT
class FFTAnalyzer {
public:
    explicit FFTAnalyzer(int fftSize = 2048, int sampleRate = 48000);
    ~FFTAnalyzer();

    // Feed audio samples, returns true when a new analysis frame is ready
    bool process(const float* samples, int count);

    // Get detected fundamental frequency (Hz), or 0 if no pitch
    float fundamentalFrequency() const { return fundamental_; }

    // Get magnitude spectrum (fftSize/2 + 1 bins)
    const std::vector<float>& magnitudes() const { return magnitudes_; }

    // Get peak frequency bins (for polyphonic detection)
    struct Peak {
        float frequency;
        float magnitude;
    };
    std::vector<Peak> findPeaks(int maxPeaks = 8, float threshold = 0.1f) const;

    void setSampleRate(int sr) { sampleRate_ = sr; }

private:
    struct Impl;
    Impl* impl_;

    int fftSize_;
    int sampleRate_;
    float fundamental_ = 0.0f;
    std::vector<float> magnitudes_;
    std::vector<float> inputBuffer_;
    int bufferPos_ = 0;

    void analyze();
};

} // namespace space
