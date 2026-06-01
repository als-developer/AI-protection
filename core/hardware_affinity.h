#ifndef HARDWARE_AFFINITY_H
#define HARDWARE_AFFINITY_H

#include <cstdint>

class HardwareAffinity {
public:
    // Pin current thread to specific CPU core
    static bool pin_to_core(int core_id);
    
    // Set real-time scheduling priority
    static bool set_realtime_priority(int priority);
    
    // Get number of available CPU cores
    static int get_core_count();
    
    // Pin multiple threads to different cores
    static bool pin_threads_to_cores(int num_threads, int* core_ids);
    
    // Set thread name for debugging
    static void set_thread_name(const char* name);
    
    // Get current CPU core
    static int get_current_core();
    
    // Disable CPU frequency scaling for consistent performance
    static bool disable_frequency_scaling();
    
private:
    static bool s_frequency_scaling_disabled;
};

#endif // HARDWARE_AFFINITY_H
