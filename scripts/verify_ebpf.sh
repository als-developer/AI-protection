#!/bin/bash
set -euo pipefail

echo "Verifying eBPF XDP configuration..."

# Check if XDP is loaded on interface
INTERFACE=${1:-eth0}
if ip link show "$INTERFACE" | grep -q "xdp"; then
    echo "✅ XDP program loaded on $INTERFACE"
else
    echo "❌ XDP program NOT loaded on $INTERFACE"
    exit 1
fi

# Check BPF maps
MAPS="/sys/fs/bpf/bioshield"
if [ -d "$MAPS" ]; then
    echo "✅ BPF maps directory exists"
    ls -la "$MAPS"
else
    echo "❌ BPF maps directory not found"
fi

# Show map contents
echo ""
echo "Blocked IPs count:"
bpftool map dump name block_map 2>/dev/null | wc -l

echo ""
echo "Packet counters:"
bpftool map dump name packet_count_map 2>/dev/null

echo ""
echo "eBPF verification complete!"
