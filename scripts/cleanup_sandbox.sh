#!/bin/bash
set -euo pipefail

echo "⚠️  WARNING: This will remove all BioShield containers, volumes, and eBPF programs!"
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo "Cleaning up BioShield sandbox environment..."

# Stop and remove containers
docker-compose -f docker/docker-compose.yml down -v 2>/dev/null || true
docker-compose -f docker/docker-compose.prod.yml down -v 2>/dev/null || true

# Remove eBPF programs
ip link set dev eth0 xdp off 2>/dev/null || true
rm -rf /sys/fs/bpf/bioshield 2>/dev/null || true

# Remove systemd services
systemctl stop bioshield-api bioshield-engine bioshield-ebpf 2>/dev/null || true
systemctl disable bioshield-api bioshield-engine bioshield-ebpf 2>/dev/null || true
rm -f /etc/systemd/system/bioshield-*.service

# Remove directories
rm -rf /opt/bioshield 2>/dev/null || true
rm -rf /var/lib/bioshield 2>/dev/null || true
rm -rf /var/log/bioshield 2>/dev/null || true
rm -rf /var/backups/bioshield 2>/dev/null || true

# Remove Docker images
docker rmi bioshield/api:latest bioshield/engine:latest 2>/dev/null || true

echo "✅ Cleanup complete!"
