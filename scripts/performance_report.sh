#!/bin/bash
set -euo pipefail

REPORT_DIR="/var/reports/bioshield"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORT_DIR/performance_$TIMESTAMP.md"

mkdir -p "$REPORT_DIR"

cat > "$REPORT_FILE" << EOF
# BioShield Performance Report
**Generated:** $(date)

## System Metrics
$(curl -s http://localhost:8000/v1/metrics/performance | jq .)

## Request Statistics
$(curl -s http://localhost:8000/v1/metrics/streams | jq .)

## Health Status
$(curl -s http://localhost:8000/v1/health | jq .)

## Resource Usage
\`\`\`
$(top -b -n 1 | head -20)
\`\`\`

## Database Stats
\`\`\`
$(docker exec bioshield-postgres psql -U bioshield -d bioshield -c "SELECT COUNT(*) as total_scans FROM deepfake_audit_logs;")
\`\`\`
EOF

echo "Performance report saved: $REPORT_FILE"
