#include "deepfake_detector.h"
#include "avx512_math.h"
#include <cmath>
#include <cstring>
#include <fstream>
#include <random>
#include <algorithm>

DeepfakeDetector::DeepfakeDetector()
    : m_threshold_variance(0.045f)
    , m_threshold_zcr(0.35f)
    , m_threshold_spectral(0.82f)
    , m_weight_variance(0.35f)
    , m_weight_zcr(0.30f)
    , m_weight_spectral(0.20f)
    , m_weight_nn(0.15f)
    , m_weights_loaded(false)
{
    for (auto& stream : m_streams) {
        stream.buffer.reserve(256);
    }
}

DeepfakeDetector::~DeepfakeDetector() {}

void DeepfakeDetector::initialize() {
    // Initialize random number generator for testing
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<> dis(0.0, 1.0);
    
    // Default weights for ensemble
    m_weight_variance = 0.40f;
    m_weight_zcr = 0.35f;
    m_weight_spectral = 0.25f;
    
    std::cout << "[DETECTOR] Initialized with ensemble weights: "
              << "Variance=" << m_weight_variance
              << ", ZCR=" << m_weight_zcr
              << ", Spectral=" << m_weight_spectral << std::endl;
}

bool DeepfakeDetector::analyze_voice_channel(const float* samples, size_t num_samples) {
    if (num_samples < 32) return false;
    
    // Calculate features using AVX-512
    float variance = calculate_variance_avx512(samples, num_samples);
    float zcr = calculate_zcr_avx512(samples, num_samples);
    float spectral_flatness = calculate_spectral_flatness(samples, num_samples);
    
    // Score each feature (lower values indicate AI/deepfake)
    float score_variance = (variance < m_threshold_variance) ? 1.0f : 0.0f;
    float score_zcr = (zcr < m_threshold_zcr) ? 1.0f : 0.0f;
    float score_spectral = (spectral_flatness < m_threshold_spectral) ? 1.0f : 0.0f;
    
    // Weighted ensemble score
    float ensemble_score = (score_variance * m_weight_variance) +
                           (score_zcr * m_weight_zcr) +
                           (score_spectral * m_weight_spectral);
    
    // Neural network prediction if available
    if (m_weights_loaded) {
        float nn_score = predict_neural_network(samples, num_samples);
        ensemble_score = (ensemble_score * (1.0f - m_weight_nn)) + (nn_score * m_weight_nn);
    }
    
    // Deepfake detected if ensemble score > threshold
    return ensemble_score > 0.65f;
}

float DeepfakeDetector::calculate_spectral_flatness(const float* samples, size_t num_samples) {
    float geometric_mean = 1.0f;
    float arithmetic_mean = 0.0f;
    
    for (size_t i = 0; i < num_samples; i++) {
        float abs_val = std::abs(samples[i]);
        geometric_mean *= std::pow(abs_val + 1e-10f, 1.0f / num_samples);
        arithmetic_mean += abs_val / num_samples;
    }
    
    if (arithmetic_mean < 1e-6f) return 1.0f;
    return geometric_mean / arithmetic_mean;
}

float DeepfakeDetector::predict_neural_network(const float* samples, size_t num_samples) {
    // Simplified NN prediction (would be replaced with actual model inference)
    float sum = 0.0f;
    for (size_t i = 0; i < num_samples && i < 64; i++) {
        sum += samples[i];
    }
    float mean = sum / std::min(num_samples, size_t(64));
    
    // Simple threshold-based prediction
    return (mean < 0.2f) ? 0.8f : 0.2f;
}

void DeepfakeDetector::load_weights(const char* model_path) {
    std::ifstream file(model_path, std::ios::binary);
    if (file.is_open()) {
        file.seekg(0, std::ios::end);
        size_t size = file.tellg();
        file.seekg(0, std::ios::beg);
        
        m_nn_weights.resize(size / sizeof(float));
        file.read(reinterpret_cast<char*>(m_nn_weights.data()), size);
        file.close();
        
        m_weights_loaded = true;
        std::cout << "[DETECTOR] Loaded weights from " << model_path << std::endl;
    } else {
        std::cout << "[DETECTOR] No weights found at " << model_path << std::endl;
    }
}
