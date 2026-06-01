#!/bin/bash
set -euo pipefail

echo "Applying kernel performance tuning for BioShield Ultimate..."

# Apply sysctl settings
sysctl -p /etc/sysctl.d/99-bioshield.conf

# Disable CPU frequency scaling for performance
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    if [ -f "$cpu" ]; then
        echo performance > "$cpu" 2>/dev/null || true
    fi
done

# Set IRQ affinity for network interfaces
INTERFACE=${1:-eth0}
IRQS=$(grep "$INTERFACE" /proc/interrupts | cut -d: -f1 | tr -d ' ')
for irq in $IRQS; do
    echo "1" > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true
done

# Increase network buffer sizes
echo 134217728 > /proc/sys/net/core/rmem_max
echo 134217728 > /proc/sys/net/core/wmem_max

# Enable jumbo frames if supported
if ip link show "$INTERFACE" | grep -q "mtu 1500"; then
    ip link set dev "$INTERFACE" mtu 9000 2>/dev/null || true
fi

echo "Kernel tuning complete!"
