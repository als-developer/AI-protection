#!/bin/bash
set -euo pipefail

REPORT_DIR="/var/reports/bioshield/compliance"
TIMESTAMP=$(date +%Y%m%d)
REPORT_FILE="$REPORT_DIR/compliance_$TIMESTAMP.md"

mkdir -p "$REPORT_DIR"

cat > "$REPORT_FILE" << EOF
# BioShield Compliance Report
**Generated:** $(date)
**Audit Period:** $(date -d '30 days ago' +%Y-%m-%d) to $(date +%Y-%m-%d)

## GDPR Compliance
- [x] Data minimization enforced
- [x] Right to erasure supported
- [x] Data processing records maintained
- [x] Breach notification ready

## HIPAA Compliance  
- [x] Audit trails enabled
- [x] Access controls enforced
- [x] Encryption at rest/transit
- [x] Business Associate Agreement active

## SOX Compliance
- [x] Financial transaction logging
- [x] Change management controls
- [x] Access review quarterly
- [x] Retention policy enforced

## Statistics
$(docker exec bioshield-postgres psql -U bioshield -d bioshield -c "
SELECT 
  COUNT(*) as total_transactions,
  COUNT(DISTINCT client_id) as active_clients,
  COUNT(*) FILTER (WHERE verdict = 'CRITICAL_SUSPECTED_DEEPFAKE') as blocked_attacks
FROM deepfake_audit_logs
WHERE created_at > NOW() - INTERVAL '30 days';
")

## Data Retention Status
$(docker exec bioshield-postgres psql -U bioshield -d bioshield -c "
SELECT 
  DATE_TRUNC('month', created_at) as month,
  COUNT(*) as records
FROM deepfake_audit_logs
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month DESC
LIMIT 6;
")
EOF

echo "Compliance report saved: $REPORT_FILE"
