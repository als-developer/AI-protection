#!/bin/bash
set -euo pipefail

DAYS=${1:-7}
OUTPUT_DIR="/var/reports/bioshield/audit"
TIMESTAMP=$(date +%Y%m%d)

mkdir -p "$OUTPUT_DIR"

echo "Exporting audit logs for last $DAYS days..."

docker exec bioshield-postgres psql -U bioshield -d bioshield -c "
COPY (
  SELECT * FROM deepfake_audit_logs 
  WHERE created_at > NOW() - INTERVAL '$DAYS days'
  ORDER BY created_at DESC
) TO '/tmp/audit_export_$TIMESTAMP.csv' WITH CSV HEADER;
"

docker cp bioshield-postgres:/tmp/audit_export_$TIMESTAMP.csv "$OUTPUT_DIR/"

echo "Audit logs exported to: $OUTPUT_DIR/audit_export_$TIMESTAMP.csv"
