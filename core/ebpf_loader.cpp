#include "ebpf_loader.h"
#include <iostream>
#include <fstream>
#include <cstring>
#include <unistd.h>
#include <sys/socket.h>
#include <linux/if_link.h>
#include <bpf/libbpf.h>

int EBPFLoader::s_xdp_fd = -1;
uint64_t EBPFLoader::s_blocked_count = 0;

bool EBPFLoader::load_xdp_program(const std::string& program_path, const std::string& interface) {
    struct bpf_object* obj = nullptr;
    struct bpf_program* prog = nullptr;
    int ifindex = 0;
    
    // Load BPF object file
    obj = bpf_object__open(program_path.c_str());
    if (libbpf_get_error(obj)) {
        std::cerr << "[EBPF] Failed to open " << program_path << std::endl;
        return false;
    }
    
    // Find XDP program
    prog = bpf_object__find_program_by_name(obj, "xdp_deepfake_filter");
    if (!prog) {
        std::cerr << "[EBPF] Failed to find XDP program" << std::endl;
        bpf_object__close(obj);
        return false;
    }
    
    // Load BPF program into kernel
    if (bpf_object__load(obj)) {
        std::cerr << "[EBPF] Failed to load BPF object" << std::endl;
        bpf_object__close(obj);
        return false;
    }
    
    // Get interface index
    ifindex = if_nametoindex(interface.c_str());
    if (ifindex == 0) {
        std::cerr << "[EBPF] Invalid interface: " << interface << std::endl;
        bpf_object__close(obj);
        return false;
    }
    
    // Get program FD
    s_xdp_fd = bpf_program__fd(prog);
    if (s_xdp_fd < 0) {
        std::cerr << "[EBPF] Invalid program FD" << std::endl;
        bpf_object__close(obj);
        return false;
    }
    
    // Attach XDP program
    if (bpf_set_link_xdp_fd(ifindex, s_xdp_fd, XDP_FLAGS_SKB_MODE) < 0) {
        std::cerr << "[EBPF] Failed to attach XDP program to " << interface << std::endl;
        bpf_object__close(obj);
        return false;
    }
    
    std::cout << "[EBPF] Loaded XDP program on " << interface << std::endl;
    return true;
}

bool EBPFLoader::unload_xdp_program(const std::string& interface) {
    int ifindex = if_nametoindex(interface.c_str());
    if (ifindex == 0) {
        return false;
    }
    
    if (bpf_set_link_xdp_fd(ifindex, -1, XDP_FLAGS_SKB_MODE) < 0) {
        std::cerr << "[EBPF] Failed to unload XDP program from " << interface << std::endl;
        return false;
    }
    
    if (s_xdp_fd >= 0) {
        close(s_xdp_fd);
        s_xdp_fd = -1;
    }
    
    std::cout << "[EBPF] Unloaded XDP program from " << interface << std::endl;
    return true;
}

bool EBPFLoader::block_ip(uint32_t ip_address) {
    // Would interact with BPF map to block IP
    s_blocked_count++;
    return true;
}

bool EBPFLoader::unblock_ip(uint32_t ip_address) {
    return true;
}

uint64_t EBPFLoader::get_blocked_count() {
    return s_blocked_count;
}

void EBPFLoader::clear_blocked_ips() {
    s_blocked_count = 0;
}

bool EBPFLoader::is_xdp_loaded(const std::string& interface) {
    std::ifstream proc("/proc/net/xt_statistics");
    return proc.good();
}

std::string EBPFLoader::get_xdp_version() {
    return "1.0.0";
}
