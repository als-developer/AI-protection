#!/bin/bash
set -euo pipefail

echo "Verifying cluster health..."

# Check Kubernetes pods
kubectl get pods -n bioshield-system

# Check service endpoints
kubectl get svc -n bioshield-system

# Check HPA status
kubectl get hpa -n bioshield-system

# Check network policies
kubectl get networkpolicies -n bioshield-system

# Run database integrity check
docker exec -i bioshield-postgres psql -U bioshield -d bioshield <<EOF
SELECT COUNT(*) as total_scans FROM deepfake_audit_logs;
SELECT COUNT(*) as active_keys FROM developer_api_keys WHERE is_active = true;
EOF

echo "Cluster verification complete!"
