#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/udp.h>
#include <bpf/bpf_helpers.h>

#define IP_PROTO_UDP 17
#define DEEPFAKE_BLOCK_THRESHOLD 5

// BPF map for blocked IP addresses
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 100000);
    __type(key, __u32);   // IPv4 address
    __type(value, __u8);   // Block counter
} block_map SEC(".maps");

// BPF map for packet counters
struct {
    __uint(type, BPF_MAP_TYPE_PERCPU_ARRAY);
    __uint(max_entries, 1);
    __type(key, __u32);
    __type(value, __u64);
} packet_count_map SEC(".maps");

// Helper function to extract UDP payload
static __always_inline void* get_udp_payload(void* data, void* data_end, struct udphdr* udp) {
    if ((void*)(udp + 1) > data_end) return NULL;
    return (void*)(udp + 1);
}

SEC("xdp")
int xdp_deepfake_filter(struct xdp_md* ctx) {
    void* data_end = (void*)(long)ctx->data_end;
    void* data = (void*)(long)ctx->data;
    
    struct ethhdr* eth = data;
    if ((void*)(eth + 1) > data_end) return XDP_PASS;
    
    // Only process IPv4 packets
    if (eth->h_proto != __constant_htons(ETH_P_IP)) return XDP_PASS;
    
    struct iphdr* ip = (struct iphdr*)(eth + 1);
    if ((void*)(ip + 1) > data_end) return XDP_PASS;
    
    // Only process UDP packets (voice/RTP traffic)
    if (ip->protocol != IP_PROTO_UDP) return XDP_PASS;
    
    __u32 src_ip = ip->saddr;
    
    // Check if source IP is blacklisted
    __u8* block_count = bpf_map_lookup_elem(&block_map, &src_ip);
    if (block_count && *block_count >= DEEPFAKE_BLOCK_THRESHOLD) {
        return XDP_DROP;  // Block suspicious source
    }
    
    struct udphdr* udp = (struct udphdr*)(ip + 1);
    void* payload = get_udp_payload(data, data_end, udp);
    
    if (payload) {
        // Analyze first few bytes of payload for deepfake signatures
        __u8* bytes = (__u8*)payload;
        
        // Check for low-variance patterns (AI voice characteristic)
        __u8 low_variance_detected = 1;
        for (int i = 1; i < 8 && (void*)(bytes + i) < data_end; i++) {
            if (bytes[i] != bytes[0]) {
                low_variance_detected = 0;
                break;
            }
        }
        
        if (low_variance_detected) {
            __u8 new_count = 1;
            if (block_count) {
                new_count = *block_count + 1;
            }
            bpf_map_update_elem(&block_map, &src_ip, &new_count, BPF_ANY);
            return XDP_DROP;
        }
    }
    
    // Count packet for telemetry
    __u32 key = 0;
    __u64* count = bpf_map_lookup_elem(&packet_count_map, &key);
    if (count) {
        __sync_fetch_and_add(count, 1);
    }
    
    return XDP_PASS;
}

char _license[] SEC("license") = "GPL";
