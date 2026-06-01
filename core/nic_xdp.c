#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/udp.h>
#include <bpf/bpf_helpers.h>

#define IP_PROTO_UDP 17
#define DEEPFAKE_BLOCK_THRESHOLD 5

// BPF maps
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 100000);
    __type(key, __u32);
    __type(value, __u8);
} block_map SEC(".maps");

struct {
    __uint(type, BPF_MAP_TYPE_PERCPU_ARRAY);
    __uint(max_entries, 1);
    __type(key, __u32);
    __type(value, __u64);
} packet_count_map SEC(".maps");

struct {
    __uint(type, BPF_MAP_TYPE_PERCPU_ARRAY);
    __uint(max_entries, 1);
    __type(key, __u32);
    __type(value, __u64);
} blocked_count_map SEC(".maps");

SEC("xdp")
int xdp_deepfake_filter(struct xdp_md* ctx) {
    void* data_end = (void*)(long)ctx->data_end;
    void* data = (void*)(long)ctx->data;
    
    struct ethhdr* eth = data;
    if ((void*)(eth + 1) > data_end) return XDP_PASS;
    
    if (eth->h_proto != __constant_htons(ETH_P_IP)) return XDP_PASS;
    
    struct iphdr* ip = (struct iphdr*)(eth + 1);
    if ((void*)(ip + 1) > data_end) return XDP_PASS;
    
    if (ip->protocol != IP_PROTO_UDP) return XDP_PASS;
    
    __u32 src_ip = ip->saddr;
    
    // Check blacklist
    __u8* block_count = bpf_map_lookup_elem(&block_map, &src_ip);
    if (block_count && *block_count >= DEEPFAKE_BLOCK_THRESHOLD) {
        __u32 key = 0;
        __u64* blocked = bpf_map_lookup_elem(&blocked_count_map, &key);
        if (blocked) {
            __sync_fetch_and_add(blocked, 1);
        }
        return XDP_DROP;
    }
    
    struct udphdr* udp = (struct udphdr*)(ip + 1);
    if ((void*)(udp + 1) > data_end) return XDP_PASS;
    
    void* payload = (void*)(udp + 1);
    if (payload > data_end) return XDP_PASS;
    
    // Analyze payload for low variance patterns
    __u8* bytes = (__u8*)payload;
    __u8 low_variance = 1;
    
    for (int i = 1; i < 8 && (bytes + i) < (__u8*)data_end; i++) {
        if (bytes[i] != bytes[0]) {
            low_variance = 0;
            break;
        }
    }
    
    if (low_variance) {
        __u8 new_count = 1;
        if (block_count) {
            new_count = *block_count + 1;
        }
        bpf_map_update_elem(&block_map, &src_ip, &new_count, BPF_ANY);
        return XDP_DROP;
    }
    
    // Count packet
    __u32 key = 0;
    __u64* count = bpf_map_lookup_elem(&packet_count_map, &key);
    if (count) {
        __sync_fetch_and_add(count, 1);
    }
    
    return XDP_PASS;
}

char _license[] SEC("license") = "GPL";
