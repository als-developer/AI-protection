#!/bin/bash
set -euo pipefail

echo "Monitoring CPU core usage for BioShield engine..."

while true; do
    clear
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           BIO-SHIELD CORE ENGINE MONITOR                   ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    
    # CPU usage per core
    mpstat -P ALL 1 1 | grep -E "CPU|all|[0-9]" | tail -n +3
    
    echo "╠════════════════════════════════════════════════════════════╣"
    
    # Engine process info
    ENGINE_PID=$(pgrep -f "bioshield_engine" || echo "Not running")
    if [ "$ENGINE_PID" != "Not running" ]; then
        CPU=$(ps -p $ENGINE_PID -o %cpu= | tr -d ' ')
        MEM=$(ps -p $ENGINE_PID -o %mem= | tr -d ' ')
        echo "Engine PID: $ENGINE_PID | CPU: ${CPU}% | MEM: ${MEM}%"
        
        # Thread info
        echo "Threads: $(ps -T -p $ENGINE_PID | wc -l)"
    else
        echo "Engine: NOT RUNNING!"
    fi
    
    echo "╠════════════════════════════════════════════════════════════╣"
    
    # eBPF stats
    if [ -f /sys/fs/bpf/bioshield/packet_count_map ]; then
        bpftool map dump name packet_count_map 2>/dev/null | head -5
    fi
    
    echo "╚════════════════════════════════════════════════════════════╝"
    echo "Press Ctrl+C to exit"
    sleep 2
done
