#include "avx512_math.h"
#include <immintrin.h>
#include <cmath>

float calculate_variance_avx512(const float* data, size_t length) {
    if (length < 16) {
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
    
    for (; i <= length - 16; i += 16) {
        __m512 chunk = _mm512_loadu_ps(&data[i]);
        sum_vec = _mm512_add_ps(sum_vec, chunk);
    }
    
    float total_sum = _mm512_reduce_add_ps(sum_vec);
    for (; i < length; i++) total_sum += data[i];
    
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

float calculate_mean_avx512(const float* data, size_t length) {
    if (length < 16) {
        float sum = 0.0f;
        for (size_t i = 0; i < length; i++) sum += data[i];
        return sum / length;
    }
    
    __m512 sum_vec = _mm512_setzero_ps();
    size_t i = 0;
    
    for (; i <= length - 16; i += 16) {
        sum_vec = _mm512_add_ps(sum_vec, _mm512_loadu_ps(&data[i]));
    }
    
    float total_sum = _mm512_reduce_add_ps(sum_vec);
    for (; i < length; i++) total_sum += data[i];
    
    return total_sum / length;
}

float dot_product_avx512(const float* a, const float* b, size_t length) {
    if (length < 16) {
        float result = 0.0f;
        for (size_t i = 0; i < length; i++) result += a[i] * b[i];
        return result;
    }
    
    __m512 sum_vec = _mm512_setzero_ps();
    size_t i = 0;
    
    for (; i <= length - 16; i += 16) {
        __m512 a_vec = _mm512_loadu_ps(&a[i]);
        __m512 b_vec = _mm512_loadu_ps(&b[i]);
        sum_vec = _mm512_fmadd_ps(a_vec, b_vec, sum_vec);
    }
    
    float result = _mm512_reduce_add_ps(sum_vec);
    for (; i < length; i++) result += a[i] * b[i];
    
    return result;
}

float calculate_zcr_avx512(const float* data, size_t length) {
    if (length < 16) {
        float crossings = 0.0f;
        for (size_t i = 1; i < length; i++) {
            if ((data[i] >= 0 && data[i-1] < 0) || (data[i] < 0 && data[i-1] >= 0)) {
                crossings += 1.0f;
            }
        }
        return crossings / length;
    }
    
    // Use mask registers for zero-crossing detection
    __mmask16 mask;
    __m512 prev_vec, curr_vec;
    float crossings = 0.0f;
    size_t i = 1;
    
    for (; i <= length - 16; i += 16) {
        prev_vec = _mm512_loadu_ps(&data[i-1]);
        curr_vec = _mm512_loadu_ps(&data[i]);
        
        __m512 prev_sign = _mm512_sign_ps(prev_vec, _mm512_set1_ps(1.0f));
        __m512 curr_sign = _mm512_sign_ps(curr_vec, _mm512_set1_ps(1.0f));
        
        // Detect sign changes
        __mmask16 sign_change = _mm512_cmp_ps_mask(prev_sign, curr_sign, _CMP_NEQ_OQ);
        crossings += __builtin_popcount(sign_change);
    }
    
    for (; i < length; i++) {
        if ((data[i] >= 0 && data[i-1] < 0) || (data[i] < 0 && data[i-1] >= 0)) {
            crossings += 1.0f;
        }
    }
    
    return crossings / length;
}
