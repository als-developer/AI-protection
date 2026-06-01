#include "multi_channel_core.h"
#include "avx512_math.h"
#include <cmath>
#include <algorithm>
#include <cstring>

MultiChannelProcessor::MultiChannelProcessor()
    : m_initialized(false)
    , m_max_channels(0)
    , m_samples_per_channel(0)
{}

MultiChannelProcessor::~MultiChannelProcessor() {
    shutdown();
}

bool MultiChannelProcessor::initialize(size_t max_channels, size_t samples_per_channel) {
    if (m_initialized) return true;
    
    m_max_channels = max_channels;
    m_samples_per_channel = samples_per_channel;
    
    m_channels.resize(max_channels);
    for (auto& channel : m_channels) {
        channel.buffer.reserve(samples_per_channel);
        channel.running_variance = 0.0f;
        channel.sample_count = 0;
        channel.is_anomaly = false;
    }
    
    m_initialized = true;
    return true;
}

void MultiChannelProcessor::shutdown() {
    if (!m_initialized) return;
    m_channels.clear();
    m_initialized = false;
}

bool MultiChannelProcessor::process_channels(const float* const* channel_data,
                                              size_t num_channels,
                                              size_t samples_per_channel,
                                              float* results) {
    if (!m_initialized) return false;
    if (num_channels > m_max_channels) return false;
    
    // Process all channels using AVX-512 where possible
    #pragma omp parallel for
    for (size_t i = 0; i < num_channels; i++) {
        results[i] = calculate_variance_avx512(channel_data[i], samples_per_channel);
    }
    
    return true;
}

void MultiChannelProcessor::calculate_channel_variances(const float* const* channel_data,
                                                         size_t num_channels,
                                                         size_t samples_per_channel,
                                                         float* variances) {
    process_channels(channel_data, num_channels, samples_per_channel, variances);
}

float MultiChannelProcessor::detect_cross_correlation(const float* channel_a,
                                                       const float* channel_b,
                                                       size_t num_samples) {
    float mean_a = calculate_mean_avx512(channel_a, num_samples);
    float mean_b = calculate_mean_avx512(channel_b, num_samples);
    
    float numerator = 0.0f;
    float denom_a = 0.0f;
    float denom_b = 0.0f;
    
    for (size_t i = 0; i < num_samples; i++) {
        float diff_a = channel_a[i] - mean_a;
        float diff_b = channel_b[i] - mean_b;
        numerator += diff_a * diff_b;
        denom_a += diff_a * diff_a;
        denom_b += diff_b * diff_b;
    }
    
    float denominator = std::sqrt(denom_a * denom_b);
    if (denominator < 1e-6f) return 0.0f;
    
    return numerator / denominator;
}

bool MultiChannelProcessor::ensemble_vote(const float* variances, 
                                           size_t num_channels, 
                                           float threshold) {
    size_t anomaly_count = 0;
    for (size_t i = 0; i < num_channels; i++) {
        if (variances[i] < threshold) {
            anomaly_count++;
        }
    }
    
    // Deepfake detected if > 50% of channels show low variance
    return anomaly_count > (num_channels / 2);
}
