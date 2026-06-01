#include "hardware_affinity.h"
#include <iostream>
#include <fstream>
#include <sched.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/syscall.h>

bool HardwareAffinity::s_frequency_scaling_disabled = false;

bool HardwareAffinity::pin_to_core(int core_id) {
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(core_id, &cpuset);
    
    int result = sched_setaffinity(0, sizeof(cpu_set_t), &cpuset);
    if (result != 0) {
        std::cerr << "[AFFINITY] Failed to pin to core " << core_id << std::endl;
        return false;
    }
    
    std::cout << "[AFFINITY] Pinned to core " << core_id << std::endl;
    return true;
}

bool HardwareAffinity::set_realtime_priority(int priority) {
    struct sched_param param;
    param.sched_priority = priority;
    
    int result = sched_setscheduler(0, SCHED_FIFO, &param);
    if (result != 0) {
        std::cerr << "[AFFINITY] Failed to set real-time priority " << priority << std::endl;
        return false;
    }
    
    std::cout << "[AFFINITY] Set real-time priority to " << priority << std::endl;
    return true;
}

int HardwareAffinity::get_core_count() {
    return sysconf(_SC_NPROCESSORS_ONLN);
}

bool HardwareAffinity::pin_threads_to_cores(int num_threads, int* core_ids) {
    for (int i = 0; i < num_threads; i++) {
        cpu_set_t cpuset;
        CPU_ZERO(&cpuset);
        CPU_SET(core_ids[i], &cpuset);
        
        if (sched_setaffinity(0, sizeof(cpu_set_t), &cpuset) != 0) {
            return false;
        }
    }
    return true;
}

void HardwareAffinity::set_thread_name(const char* name) {
    pthread_setname_np(pthread_self(), name);
}

int HardwareAffinity::get_current_core() {
    return sched_getcpu();
}

bool HardwareAffinity::disable_frequency_scaling() {
    std::ofstream gov("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor");
    if (gov.is_open()) {
        gov << "performance";
        gov.close();
        s_frequency_scaling_disabled = true;
        std::cout << "[AFFINITY] Disabled CPU frequency scaling" << std::endl;
        return true;
    }
    return false;
}
