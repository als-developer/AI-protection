#include "frequency_analyzer.h"
#include <cmath>
#include <complex>
#include <vector>

// Simplified FFT implementation (would use FFTW in production)
static void simple_fft(std::vector<std::complex<float>>& data, bool invert) {
    size_t n = data.size();
    if (n <= 1) return;
    
    // Split into even and odd
    std::vector<std::complex<float>> even(n / 2);
    std::vector<std::complex<float>> odd(n / 2);
    
    for (size_t i = 0; i < n / 2; i++) {
        even[i] = data[i * 2];
        odd[i] = data[i * 2 + 1];
    }
    
    simple_fft(even, invert);
    simple_fft(odd, invert);
    
    float angle = 2.0f * M_PI / n * (invert ? -1 : 1);
    std::complex<float> w(1);
    std::complex<float> wn(std::cos(angle), std::sin(angle));
    
    for (size_t i = 0; i < n / 2; i++) {
        data[i] = even[i] + w * odd[i];
        data[i + n / 2] = even[i] - w * odd[i];
        w *= wn;
    }
    
    if (invert) {
        for (size_t i = 0; i < n; i++) {
            data[i] /= n;
        }
    }
}

float FrequencyAnalyzer::get_dominant_frequency(const float* samples, size_t num_samples) {
    std::vector<std::complex<float>> data(num_samples);
    for (size_t i = 0; i < num_samples; i++) {
        data[i] = std::complex<float>(samples[i], 0);
    }
    
    simple_fft(data, false);
    
    float max_magnitude = 0.0f;
    size_t max_index = 0;
    
    for (size_t i = 1; i < num_samples / 2; i++) {
        float magnitude = std::abs(data[i]);
        if (magnitude > max_magnitude) {
            max_magnitude = magnitude;
            max_index = i;
        }
    }
    
    // Return normalized frequency (0 to 0.5)
    return static_cast<float>(max_index) / num_samples;
}

float FrequencyAnalyzer::get_spectral_centroid(const float* samples, size_t num_samples) {
    std::vector<std::complex<float>> data(num_samples);
    for (size_t i = 0; i < num_samples; i++) {
        data[i] = std::complex<float>(samples[i], 0);
    }
    
    simple_fft(data, false);
    
    float numerator = 0.0f;
    float denominator = 0.0f;
    
    for (size_t i = 0; i < num_samples / 2; i++) {
        float magnitude = std::abs(data[i]);
        float freq = static_cast<float>(i) / num_samples;
        numerator += freq * magnitude;
        denominator += magnitude;
    }
    
    if (denominator < 1e-6f) return 0.0f;
    return numerator / denominator;
}
