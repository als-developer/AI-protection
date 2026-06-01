#!/bin/bash
set -euo pipefail

INTERFACE=${CORE_EBPF_INTERFACE:-eth0}
XDP_PROGRAM="/opt/bioshield/nic_xdp.o"

echo "Setting up eBPF XDP program on ${INTERFACE}..."

# Check if interface exists
if ! ip link show "${INTERFACE}" > /dev/null 2>&1; then
    echo "Interface ${INTERFACE} not found"
    exit 1
fi

# Unload existing XDP program if present
ip link set dev "${INTERFACE}" xdp off 2>/dev/null || true

# Load new XDP program
ip link set dev "${INTERFACE}" xdp obj "${XDP_PROGRAM}" sec xdp

# Verify loading
if ip link show "${INTERFACE}" | grep -q "xdp"; then
    echo "✅ eBPF XDP program loaded successfully on ${INTERFACE}"
else
    echo "❌ Failed to load eBPF XDP program"
    exit 1
fi

# Pin BPF maps for user-space access
mkdir -p /sys/fs/bpf/bioshield
bpftool map pin name block_map /sys/fs/bpf/bioshield/block_map
bpftool map pin name packet_count_map /sys/fs/bpf/bioshield/packet_count_map
bpftool map pin name blocked_count_map /sys/fs/bpf/bioshield/blocked_count_map

echo "✅ BPF maps pinned to /sys/fs/bpf/bioshield/"

# Show statistics
bpftool map list | grep -A5 bioshield

echo "eBPF XDP setup complete!"
