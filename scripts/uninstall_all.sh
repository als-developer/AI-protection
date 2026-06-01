#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     BIO-SHIELD ULTIMATE COMPLETE UNINSTALL                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  This will REMOVE ALL BioShield components!"
read -p "Type 'DELETE ALL' to confirm: " confirm

if [ "$confirm" != "DELETE ALL" ]; then
    echo "Aborted."
    exit 0
fi

# Stop all services
echo "Stopping services..."
systemctl stop bioshield-* 2>/dev/null || true
systemctl disable bioshield-* 2>/dev/null || true

# Remove Docker containers
echo "Removing Docker containers..."
docker stop $(docker ps -a -q --filter name=bioshield) 2>/dev/null || true
docker rm $(docker ps -a -q --filter name=bioshield) 2>/dev/null || true

# Remove Docker images
echo "Removing Docker images..."
docker rmi bioshield/api bioshield/engine bioshield/ebpf 2>/dev/null || true

# Remove eBPF programs
echo "Removing eBPF programs..."
ip link set dev eth0 xdp off 2>/dev/null || true
rm -rf /sys/fs/bpf/bioshield 2>/dev/null || true

# Remove configuration files
echo "Removing configuration files..."
rm -rf /opt/bioshield 2>/dev/null || true
rm -f /etc/systemd/system/bioshield-*.service 2>/dev/null || true
rm -f /etc/sysctl.d/99-bioshield.conf 2>/dev/null || true
rm -f /etc/logrotate.d/bioshield.conf 2>/dev/null || true

# Remove data directories
echo "Removing data directories..."
rm -rf /var/lib/bioshield 2>/dev/null || true
rm -rf /var/log/bioshield 2>/dev/null || true
rm -rf /var/backups/bioshield 2>/dev/null || true
rm -rf /var/reports/bioshield 2>/dev/null || true

# Remove Docker volumes
echo "Removing Docker volumes..."
docker volume rm $(docker volume ls -q -f name=bioshield) 2>/dev/null || true

echo ""
echo "✅ BioShield Ultimate has been completely removed from this system."
