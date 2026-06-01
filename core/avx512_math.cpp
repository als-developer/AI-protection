#include <immintrin.h>
#include <cmath>
#include "avx512_math.h"

// AVX-512 optimized variance calculation
float calculate_variance_avx512(const float* data, size_t length) {
    if (length < 16) {
        // Fallback to scalar for small arrays
        float sum = 0.0f;
        for (size_t i = 0; i < length; i++) sum += data[i];
        float mean = sum / length;
        float variance = 0.0f;
        for (size_t i = 0; i < length; i++) {
            float diff = data[i] - mean;
            variance += diff * diff;
        }
        return variance / length;
    }
    
    __m512 sum_vec = _mm512_setzero_ps();
    size_t i = 0;
    
    // Summation using AVX-512 registers
    for (; i <= length - 16; i += 16) {
        __m512 chunk = _mm512_loadu_ps(&data[i]);
        sum_vec = _mm512_add_ps(sum_vec, chunk);
    }
    
    float total_sum = _mm512_reduce_add_ps(sum_vec);
    
    // Handle remaining elements
    for (; i < length; i++) {
        total_sum += data[i];
    }
    
    float mean = total_sum / length;
    __m512 mean_vec = _mm512_set1_ps(mean);
    __m512 variance_vec = _mm512_setzero_ps();
    
    i = 0;
    for (; i <= length - 16; i += 16) {
        __m512 chunk = _mm512_loadu_ps(&data[i]);
        __m512 diff = _mm512_sub_ps(chunk, mean_vec);
        variance_vec = _mm512_fmadd_ps(diff, diff, variance_vec);
    }
    
    float total_variance = _mm512_reduce_add_ps(variance_vec);
    
    for (; i < length; i++) {
        float diff = data[i] - mean;
        total_variance += diff * diff;
    }
    
    return total_variance / length;
}

// Detect AI voice patterns using zero-crossing rate and spectral flatness
float calculate_zero_crossing_rate(const float* data, size_t length) {
    float crossings = 0.0f;
    for (size_t i = 1; i < length; i++) {
        if ((data[i] >= 0 && data[i-1] < 0) || (data[i] < 0 && data[i-1] >= 0)) {
            crossings += 1.0f;
        }
    }
    return crossings / length;
}
