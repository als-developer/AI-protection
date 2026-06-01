#ifndef FREQUENCY_ANALYZER_H
#define FREQUENCY_ANALYZER_H

#include <cstddef>
#include <vector>
#include <complex>

class FrequencyAnalyzer {
public:
    FrequencyAnalyzer();
    ~FrequencyAnalyzer();
    
    void initialize(size_t fft_size);
    void shutdown();
    
    // FFT analysis
    void perform_fft(const float* samples, size_t num_samples, std::complex<float>* output);
    void perform_ifft(const std::complex<float>* input, size_t num_samples, float* output);
    
    // Frequency domain features
    float get_dominant_frequency(const float* samples, size_t num_samples);
    float get_spectral_centroid(const float* samples, size_t num_samples);
    float get_spectral_rolloff(const float* samples, size_t num_samples);
    float get_spectral_flux(const float* samples, size_t num_samples);
    
    // Mel-frequency cepstral coefficients (MFCC)
    void compute_mfcc(const float* samples, size_t num_samples, float* mfcc_output, int num_coeffs);
    
    // Harmonic analysis
    float get_harmonic_ratio(const float* samples, size_t num_samples);
    
private:
    void* m_fft_plan;
    size_t m_fft_size;
    bool m_initialized;
    
    void init_fftw_plan();
    void destroy_fftw_plan();
};

#endif // FREQUENCY_ANALYZER_H
