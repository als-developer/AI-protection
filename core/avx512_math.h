#ifndef AVX512_MATH_H
#define AVX512_MATH_H

#include <cstddef>

// AVX-512 optimized variance calculation
float calculate_variance_avx512(const float* data, size_t length);

// AVX-512 optimized mean calculation
float calculate_mean_avx512(const float* data, size_t length);

// AVX-512 optimized dot product
float dot_product_avx512(const float* a, const float* b, size_t length);

// AVX-512 optimized zero-crossing rate
float calculate_zcr_avx512(const float* data, size_t length);

// AVX-512 optimized spectral flatness
float calculate_spectral_flatness_avx512(const float* data, size_t length);

// Batch process multiple channels
void batch_process_channels_avx512(const float* channels, size_t num_channels, 
                                    size_t samples_per_channel, float* results);

#endif // AVX512_MATH_H
