#!/bin/bash
set -euo pipefail

echo "🚨 EMERGENCY STOP - Blocking all traffic"

# Block all IPs at eBPF level
kubectl exec -n bioshield-system deployment/bioshield-engine -- \
  /app/bioshield_engine --block-all

# Scale down API
kubectl scale deployment bioshield-api --replicas=0 -n bioshield-system

# Disable ingress
kubectl delete ingress bioshield-ingress -n bioshield-system

echo "✅ All traffic blocked. System in emergency mode."

# Wait for admin
read -p "Press Enter to restore normal operation..."

# Restore
kubectl scale deployment bioshield-api --replicas=3 -n bioshield-system
kubectl apply -f infra/kubernetes/ingress.yaml
kubectl exec -n bioshield-system deployment/bioshield-engine -- \
  /app/bioshield_engine --unblock-all

echo "✅ System restored."
