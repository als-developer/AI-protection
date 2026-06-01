#include <iostream>
#include <memory>
#include <thread>
#include <signal.h>
#include "deepfake_detector.h"
#include "hardware_affinity.h"
#include "lockfree_queue.h"
#include "memory_pool.h"
#include "ebpf_loader.h"

static volatile bool g_running = true;

void signal_handler(int sig) {
    std::cout << "[ENGINE] Received signal " << sig << ", shutting down..." << std::endl;
    g_running = false;
}

int main(int argc, char** argv) {
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    std::cout << "╔══════════════════════════════════════════════════════════════╗" << std::endl;
    std::cout << "║     SOVEREIGN BIO-SHIELD ULTIMATE CORE ENGINE v1.0          ║" << std::endl;
    std::cout << "║     AVX-512 Optimized | Lock-Free | eBPF XDP Enabled        ║" << std::endl;
    std::cout << "╚══════════════════════════════════════════════════════════════╝" << std::endl;
    
    // Pin to CPU core 0 for real-time processing
    HardwareAffinity::pin_to_core(0);
    HardwareAffinity::set_realtime_priority(99);
    
    // Initialize lock-free queue
    LockFreeQueue queue(65536);
    
    // Initialize memory pool
    MemoryPool memory_pool(1024 * 1024 * 100); // 100MB
    
    // Load eBPF XDP program
    if (!EBPFLoader::load_xdp_program("nic_xdp.o", "eth0")) {
        std::cerr << "[ERROR] Failed to load eBPF XDP program" << std::endl;
        return 1;
    }
    
    // Initialize deepfake detector
    DeepfakeDetector detector;
    detector.initialize();
    
    std::cout << "[ENGINE] All systems operational. Waiting for audio streams..." << std::endl;
    
    uint64_t total_packets = 0;
    uint64_t blocked_packets = 0;
    auto last_report = std::chrono::steady_clock::now();
    
    while (g_running) {
        TelemetryPacket packet;
        if (queue.pop(packet)) {
            total_packets++;
            
            bool is_deepfake = detector.analyze_voice_channel(
                packet.frequency_data,
                packet.num_samples
            );
            
            if (is_deepfake) {
                blocked_packets++;
                // Instruct eBPF to block source IP
                EBPFLoader::block_ip(packet.source_ip);
            }
        }
        
        auto now = std::chrono::steady_clock::now();
        if (now - last_report >= std::chrono::seconds(5)) {
            std::cout << "[STATS] Packets: " << total_packets 
                      << " | Blocked: " << blocked_packets
                      << " | Queue Depth: " << queue.size() << std::endl;
            last_report = now;
        }
        
        std::this_thread::sleep_for(std::chrono::microseconds(10));
    }
    
    // Cleanup
    EBPFLoader::unload_xdp_program("eth0");
    std::cout << "[ENGINE] Shutdown complete." << std::endl;
    return 0;
}
