#ifndef DEEPFAKE_DETECTOR_H
#define DEEPFAKE_DETECTOR_H

#include <cstddef>
#include <cstdint>
#include <vector>
#include <array>

class DeepfakeDetector {
public:
    DeepfakeDetector();
    ~DeepfakeDetector();
    
    void initialize();
    bool analyze_voice_channel(const float* samples, size_t num_samples);
    void load_weights(const char* model_path);
    
    // Multi-channel analysis
    bool analyze_multi_channel(const float* channels, size_t num_channels, 
                                size_t samples_per_channel);
    
    // Real-time streaming analysis
    void start_stream_analysis(uint32_t stream_id);
    void feed_stream_sample(uint32_t stream_id, float sample);
    bool get_stream_verdict(uint32_t stream_id);
    
    // Configuration
    void set_threshold_variance(float threshold) { m_threshold_variance = threshold; }
    void set_threshold_zcr(float threshold) { m_threshold_zcr = threshold; }
    void set_ensemble_weights(float w1, float w2, float w3);
    
private:
    float calculate_spectral_flatness(const float* samples, size_t num_samples);
    float predict_neural_network(const float* samples, size_t num_samples);
    
    float m_threshold_variance;
    float m_threshold_zcr;
    float m_threshold_spectral;
    float m_weight_variance;
    float m_weight_zcr;
    float m_weight_spectral;
    float m_weight_nn;
    
    bool m_weights_loaded;
    std::vector<float> m_nn_weights;
    
    struct StreamState {
        std::vector<float> buffer;
        float running_variance;
        uint32_t sample_count;
        bool verdict_ready;
    };
    
    std::array<StreamState, 1024> m_streams;
};

#endif // DEEPFAKE_DETECTOR_H
