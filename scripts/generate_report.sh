#!/bin/bash
set -euo pipefail

REPORT_DIR="/var/reports/bioshield"
TIMESTAMP=$(date +'%Y-%m-%d')
REPORT_FILE="${REPORT_DIR}/daily_report_${TIMESTAMP}.md"

mkdir -p "$REPORT_DIR"

# Generate daily report
cat > "$REPORT_FILE" << EOF
# BioShield Ultimate Daily Operations Report
**Date:** $(date -u +'%Y-%m-%d')
**Generated:** $(date -u +'%Y-%m-%d %H:%M:%S UTC')

## System Health

| Component | Status | Details |
|-----------|--------|---------|
| API Gateway | $(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/v1/health) | HTTP status |
| Core Engine | $(pgrep -f "bioshield_engine" > /dev/null && echo "Running" || echo "Stopped") | Process status |
| eBPF XDP | $(ip link show eth0 2>/dev/null | grep -q "xdp" && echo "Loaded" || echo "Not loaded") | Kernel filter |
| PostgreSQL | $(docker exec bioshield-postgres pg_isready -U bioshield > /dev/null 2>&1 && echo "Online" || echo "Offline") | Database |
| Redis | $(redis-cli ping 2>/dev/null | grep -q "PONG" && echo "Online" || echo "Offline") | Cache |

## Usage Statistics

EOF

# Add database stats
docker exec bioshield-postgres psql -U bioshield -d bioshield -t -c "
SELECT 'Total Scans Today: ' || COUNT(*) FROM deepfake_audit_logs WHERE DATE(created_at) = CURRENT_DATE;
" >> "$REPORT_FILE"

docker exec bioshield-postgres psql -U bioshield -d bioshield -t -c "
SELECT 'Deepfakes Blocked: ' || COUNT(*) FROM deepfake_audit_logs WHERE verdict = 'CRITICAL_SUSPECTED_DEEPFAKE' AND DATE(created_at) = CURRENT_DATE;
" >> "$REPORT_FILE"

docker exec bioshield-postgres psql -U bioshield -d bioshield -t -c "
SELECT 'Active Clients: ' || COUNT(DISTINCT client_id) FROM deepfake_audit_logs WHERE DATE(created_at) = CURRENT_DATE;
" >> "$REPORT_FILE"

cat >> "$REPORT_FILE" << EOF

## Performance Metrics

| Metric | Value |
|--------|-------|
| Avg Latency (p99) | $(curl -s http://localhost:8000/v1/metrics/performance 2>/dev/null | jq -r '.p99_latency_ms // "N/A"') ms |
| Throughput | $(curl -s http://localhost:8000/v1/metrics/performance 2>/dev/null | jq -r '.throughput_rps // "N/A"') req/sec |
| Uptime | $(ps -p 1 -o etime= | tr -d ' ') |

## Alerts

$(cat /var/log/bioshield/watchdog.log 2>/dev/null | tail -10 || echo "No recent alerts")

---
*This report is auto-generated. For issues, contact Security Operations.*
EOF

echo "Daily report generated: $REPORT_FILE"
cat "$REPORT_FILE"
