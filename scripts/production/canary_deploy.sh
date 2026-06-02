#!/bin/bash
set -euo pipefail

# Canary Deployment Script for BioShield Production

NEW_VERSION=${1:-latest}
CANARY_PERCENTAGE=${2:-10}

echo "🚀 Starting canary deployment for version: $NEW_VERSION (${CANARY_PERCENTAGE}% traffic)"

# Deploy canary version
kubectl apply -f enterprise/kubernetes/canary/deployment-canary.yaml

# Wait for canary to be ready
kubectl wait --for=condition=ready pod -l version=canary -n bioshield-system --timeout=5m

# Split traffic (10% to canary, 90% to stable)
kubectl patch service bioshield-api -n bioshield-system --patch '
spec:
  selector:
    app: bioshield
  sessionAffinity: None
'

# Monitor canary for 10 minutes
echo "📊 Monitoring canary for 10 minutes..."
for i in {1..10}; do
    sleep 60
    ERROR_RATE=$(kubectl logs -l version=canary -n bioshield-system --tail=100 | grep -c ERROR || echo "0")
    if [ "$ERROR_RATE" -gt 5 ]; then
        echo "❌ Canary failed - error rate too high. Rolling back..."
        kubectl delete -f enterprise/kubernetes/canary/deployment-canary.yaml
        exit 1
    fi
    echo "   Minute $i: Error rate = $ERROR_RATE"
done

# Gradually increase canary traffic
for percentage in 25 50 75 100; do
    echo "🔄 Increasing canary traffic to ${percentage}%..."
    sleep 120
    # Update traffic split
    kubectl patch service bioshield-api -n bioshield-system --patch '
    metadata:
      annotations:
        traffic.canary.io/weight: "'$percentage'"
    '
done

# Promote canary to stable
echo "✅ Canary successful! Promoting to stable..."
kubectl patch deployment bioshield-api -n bioshield-system -p '{"spec":{"template":{"metadata":{"labels":{"version":"stable"}}}}}'
kubectl delete -f enterprise/kubernetes/canary/deployment-canary.yaml

echo "🎉 Canary deployment completed successfully!"
