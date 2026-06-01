#ifndef EBPF_LOADER_H
#define EBPF_LOADER_H

#include <cstdint>
#include <string>

class EBPFLoader {
public:
    static bool load_xdp_program(const std::string& program_path, const std::string& interface);
    static bool unload_xdp_program(const std::string& interface);
    
    static bool block_ip(uint32_t ip_address);
    static bool unblock_ip(uint32_t ip_address);
    
    static uint64_t get_blocked_count();
    static void clear_blocked_ips();
    
    static bool is_xdp_loaded(const std::string& interface);
    static std::string get_xdp_version();
    
private:
    static int s_xdp_fd;
    static uint64_t s_blocked_count;
};

#endif // EBPF_LOADER_H
