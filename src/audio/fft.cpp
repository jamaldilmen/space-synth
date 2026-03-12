#include "audio/fft.h"
#include <Accelerate/Accelerate.h>
#include <cmath>
#include <algorithm>

namespace space {

struct FFTAnalyzer::Impl {
    FFTSetup fftSetup = nullptr;
    DSPSplitComplex splitComplex;
    std::vector<float> realp;
    std::vector<float> imagp;
    std::vector<float> window;  // Hann window
};

FFTAnalyzer::FFTAnalyzer(int fftSize, int sampleRate)
    : impl_(new Impl()), fftSize_(fftSize), sampleRate_(sampleRate)
{
    int log2n = static_cast<int>(std::log2(fftSize));
    impl_->fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX2);

    int halfN = fftSize / 2;
    impl_->realp.resize(halfN);
    impl_->imagp.resize(halfN);
    impl_->splitComplex.realp = impl_->realp.data();
    impl_->splitComplex.imagp = impl_->imagp.data();

    // Hann window
    impl_->window.resize(fftSize);
    vDSP_hann_window(impl_->window.data(), fftSize, vDSP_HANN_NORM);

    magnitudes_.resize(halfN + 1, 0.0f);
    inputBuffer_.resize(fftSize, 0.0f);
}

FFTAnalyzer::~FFTAnalyzer() {
    if (impl_->fftSetup) vDSP_destroy_fftsetup(impl_->fftSetup);
    delete impl_;
}

bool FFTAnalyzer::process(const float* samples, int count) {
    bool analyzed = false;
    for (int i = 0; i < count; i++) {
        inputBuffer_[bufferPos_++] = samples[i];
        if (bufferPos_ >= fftSize_) {
            analyze();
            bufferPos_ = 0;
            analyzed = true;
        }
    }
    return analyzed;
}

void FFTAnalyzer::analyze() {
    int halfN = fftSize_ / 2;
    int log2n = static_cast<int>(std::log2(fftSize_));

    // Apply Hann window
    std::vector<float> windowed(fftSize_);
    vDSP_vmul(inputBuffer_.data(), 1, impl_->window.data(), 1, windowed.data(), 1, fftSize_);

    // Pack for FFT
    vDSP_ctoz(reinterpret_cast<const DSPComplex*>(windowed.data()), 2,
              &impl_->splitComplex, 1, halfN);

    // Forward FFT
    vDSP_fft_zrip(impl_->fftSetup, &impl_->splitComplex, 1, log2n, FFT_FORWARD);

    // Compute magnitudes
    float scale = 1.0f / (2.0f * fftSize_);
    vDSP_zvmags(&impl_->splitComplex, 1, magnitudes_.data(), 1, halfN);
    vDSP_vsmul(magnitudes_.data(), 1, &scale, magnitudes_.data(), 1, halfN);

    // Convert to dB-like scale
    for (int i = 0; i < halfN; i++) {
        magnitudes_[i] = std::sqrt(magnitudes_[i]);
    }

    // Find fundamental via peak detection with parabolic interpolation
    float maxMag = 0.0f;
    int maxBin = 0;
    for (int i = 2; i < halfN; i++) {
        if (magnitudes_[i] > maxMag) {
            maxMag = magnitudes_[i];
            maxBin = i;
        }
    }

    if (maxMag > 0.01f && maxBin > 0 && maxBin < halfN - 1) {
        // Parabolic interpolation for sub-bin accuracy
        float alpha = magnitudes_[maxBin - 1];
        float beta  = magnitudes_[maxBin];
        float gamma = magnitudes_[maxBin + 1];
        float denom = alpha - 2.0f * beta + gamma;
        float p = (std::abs(denom) > 1e-12f) ? 0.5f * (alpha - gamma) / denom : 0.0f;
        float binFreq = static_cast<float>(sampleRate_) / fftSize_;
        fundamental_ = (maxBin + p) * binFreq;
    } else {
        fundamental_ = 0.0f;
    }
}

std::vector<FFTAnalyzer::Peak> FFTAnalyzer::findPeaks(int maxPeaks, float threshold) const {
    std::vector<Peak> peaks;
    int halfN = fftSize_ / 2;
    float binFreq = static_cast<float>(sampleRate_) / fftSize_;

    for (int i = 2; i < halfN - 1; i++) {
        if (magnitudes_[i] > threshold &&
            magnitudes_[i] > magnitudes_[i - 1] &&
            magnitudes_[i] > magnitudes_[i + 1]) {
            peaks.push_back({i * binFreq, magnitudes_[i]});
        }
    }

    // Sort by magnitude descending
    std::sort(peaks.begin(), peaks.end(),
        [](const Peak& a, const Peak& b) { return a.magnitude > b.magnitude; });

    if (static_cast<int>(peaks.size()) > maxPeaks) {
        peaks.resize(maxPeaks);
    }

    return peaks;
}

} // namespace space
