#include <iostream>
#include <memory>
#include <thread>
#include <vector>
#include <atomic>
#include <signal.h>
#include <chrono>
#include "deepfake_detector.h"
#include "hardware_affinity.h"
#include "lockfree_queue.h"
#include "memory_pool.h"
#include "ebpf_loader.h"
#include "avx512_math.h"
#include "frequency_analyzer.h"
#include "multi_channel_core.h"

static volatile bool g_running = true;
static std::unique_ptr<LockFreeQueue> g_queue;
static std::unique_ptr<DeepfakeDetector> g_detector;
static std::atomic<uint64_t> g_total_packets{0};
static std::atomic<uint64_t> g_blocked_packets{0};

void signal_handler(int sig) {
    std::cout << "[ENGINE] Signal " << sig << ", shutting down..." << std::endl;
    g_running = false;
}

void telemetry_thread() {
    auto last_report = std::chrono::steady_clock::now();
    while (g_running) {
        auto now = std::chrono::steady_clock::now();
        if (now - last_report >= std::chrono::seconds(5)) {
            std::cout << "[STATS] Total: " << g_total_packets.load()
                      << " | Blocked: " << g_blocked_packets.load()
                      << " | Queue: " << g_queue->size() << std::endl;
            last_report = now;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
}

int main(int argc, char** argv) {
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    std::cout << "╔══════════════════════════════════════════════════════════════╗" << std::endl;
    std::cout << "║     SOVEREIGN BIO-SHIELD ULTIMATE CORE ENGINE v3.0          ║" << std::endl;
    std::cout << "║     AVX-512 Optimized | Lock-Free | eBPF XDP Enabled        ║" << std::endl;
    std::cout << "╚══════════════════════════════════════════════════════════════╝" << std::endl;
    
    // Pin to CPU core 0
    if (!HardwareAffinity::pin_to_core(0)) {
        std::cerr << "[WARN] Failed to pin to core 0" << std::endl;
    }
    
    // Set real-time priority
    if (!HardwareAffinity::set_realtime_priority(99)) {
        std::cerr << "[WARN] Failed to set real-time priority" << std::endl;
    }
    
    // Initialize components
    g_queue = std::make_unique<LockFreeQueue>(131072);
    g_detector = std::make_unique<DeepfakeDetector>();
    g_detector->initialize();
    
    MemoryPool::initialize(1024 * 1024 * 512); // 512MB pool
    
    // Load eBPF XDP
    if (!EBPFLoader::load_xdp_program("nic_xdp.o", "eth0")) {
        std::cerr << "[ERROR] Failed to load eBPF XDP" << std::endl;
        return 1;
    }
    
    // Start telemetry thread
    std::thread telemetry(telemetry_thread);
    
    std::cout << "[ENGINE] Ready. Processing audio streams..." << std::endl;
    
    // Main processing loop
    TelemetryPacket packet;
    while (g_running) {
        if (g_queue->pop(packet)) {
            g_total_packets++;
            
            bool is_deepfake = g_detector->analyze_voice_channel(
                packet.frequency_data,
                packet.num_samples
            );
            
            if (is_deepfake) {
                g_blocked_packets++;
                EBPFLoader::block_ip(packet.source_ip);
            }
        }
        std::this_thread::sleep_for(std::chrono::microseconds(1));
    }
    
    telemetry.join();
    
    // Cleanup
    EBPFLoader::unload_xdp_program("eth0");
    MemoryPool::shutdown();
    
    std::cout << "[ENGINE] Shutdown complete." << std::endl;
    return 0;
}
