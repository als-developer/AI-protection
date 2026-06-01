#!/bin/bash
set -euo pipefail

API_URL="http://localhost:8000/v1/health"
ENGINE_PID_FILE="/var/run/bioshield-engine.pid"
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
LOG_FILE="/var/log/bioshield/watchdog.log"

log_message() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $1" | tee -a "$LOG_FILE"
}

send_alert() {
    local message="$1"
    log_message "ALERT: $message"
    
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -s -X POST -H "Content-Type: application/json" \
            -d "{\"text\":\"🚨 BioShield Watchdog: $message\"}" \
            "$SLACK_WEBHOOK" || true
    fi
}

while true; do
    # Check API health
    if ! curl -s -f -o /dev/null "$API_URL"; then
        send_alert "API gateway is down! Attempting restart..."
        systemctl restart bioshield-api
        sleep 10
    fi
    
    # Check engine process
    if ! pgrep -f "bioshield_engine" > /dev/null; then
        send_alert "Core engine is not running! Attempting restart..."
        systemctl restart bioshield-engine
        sleep 10
    fi
    
    # Check eBPF XDP
    if ! ip link show eth0 | grep -q "xdp"; then
        send_alert "eBPF XDP program not loaded! Reloading..."
        /opt/bioshield/scripts/setup_ebpf.sh
    fi
    
    # Check disk space
    DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -gt 85 ]; then
        send_alert "Disk usage is at ${DISK_USAGE}% - cleaning up old logs"
        journalctl --vacuum-time=7d
        docker system prune -f
    fi
    
    # Check memory usage
    MEM_USAGE=$(free | grep Mem | awk '{print ($3/$2) * 100}' | cut -d. -f1)
    if [ "$MEM_USAGE" -gt 90 ]; then
        send_alert "Memory usage is at ${MEM_USAGE}% - consider scaling up"
    fi
    
    sleep 30
done
