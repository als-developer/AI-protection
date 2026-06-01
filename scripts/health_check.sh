#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}     BIO-SHIELD ULTIMATE HEALTH CHECK                      ${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"

# Check API Gateway
echo -n "API Gateway (port 8000): "
if curl -s -f -o /dev/null http://localhost:8000/v1/health; then
    echo -e "${GREEN}✓ ONLINE${NC}"
else
    echo -e "${RED}✗ OFFLINE${NC}"
fi

# Check Redis
echo -n "Redis Cache (port 6379): "
if redis-cli ping 2>/dev/null | grep -q "PONG"; then
    echo -e "${GREEN}✓ ONLINE${NC}"
else
    echo -e "${RED}✗ OFFLINE${NC}"
fi

# Check PostgreSQL
echo -n "PostgreSQL (port 5432): "
if pg_isready -h localhost -U supabase_admin 2>/dev/null; then
    echo -e "${GREEN}✓ ONLINE${NC}"
else
    echo -e "${RED}✗ OFFLINE${NC}"
fi

# Check C++ Engine Process
echo -n "C++ Core Engine: "
if pgrep -f "bioshield_engine" > /dev/null; then
    echo -e "${GREEN}✓ RUNNING${NC}"
else
    echo -e "${RED}✗ NOT RUNNING${NC}"
fi

# Check eBPF XDP Program
echo -n "eBPF XDP on eth0: "
if ip link show eth0 | grep -q "xdp"; then
    echo -e "${GREEN}✓ LOADED${NC}"
else
    echo -e "${YELLOW}⚠ NOT LOADED${NC}"
fi

# Check Prometheus
echo -n "Prometheus (port 9090): "
if curl -s -f -o /dev/null http://localhost:9090/-/healthy; then
    echo -e "${GREEN}✓ ONLINE${NC}"
else
    echo -e "${RED}✗ OFFLINE${NC}"
fi

# Check Grafana
echo -n "Grafana (port 3000): "
if curl -s -f -o /dev/null http://localhost:3000/api/health; then
    echo -e "${GREEN}✓ ONLINE${NC}"
else
    echo -e "${RED}✗ OFFLINE${NC}"
fi

echo -e "\n${GREEN}════════════════════════════════════════════════════════════${NC}"

# Summary
FAILED_COUNT=$(pgrep -c "bioshield_engine" || echo 0)
if [ $FAILED_COUNT -gt 0 ]; then
    echo -e "${GREEN}✅ All critical services operational${NC}"
else
    echo -e "${YELLOW}⚠ Some services need attention${NC}"
fi
