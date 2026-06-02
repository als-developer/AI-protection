#!/bin/bash
set -euo pipefail

# BioShield Ultimate Production Deployment Script
# Run this from CI/CD pipeline or manually

ENVIRONMENT=${1:-production}
NAMESPACE="bioshield-system"
REGION=${2:-us-east-1}

echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║              SOVEREIGN BIO-SHIELD - PRODUCTION DEPLOYMENT                 ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"

# Pre-deployment checks
echo ""
echo "📋 Pre-deployment checks..."
./scripts/health_check.sh || { echo "❌ Pre-deployment health check failed"; exit 1; }

# Backup current state
echo ""
echo "💾 Creating pre-deployment backup..."
./scripts/backup_all.sh

# Pull latest images
echo ""
echo "🐳 Pulling latest Docker images..."
docker pull bioshield/api:3.0.0-prod
docker pull bioshield/engine:3.0.0-prod

# Apply Kubernetes manifests
echo ""
echo "☸️ Deploying to Kubernetes..."
kubectl apply -f enterprise/kubernetes/production/

# Wait for rollout
echo ""
echo "⏳ Waiting for rollout to complete..."
kubectl rollout status deployment/bioshield-api -n $NAMESPACE --timeout=10m
kubectl rollout status deployment/bioshield-engine -n $NAMESPACE --timeout=10m

# Verify deployment
echo ""
echo "✅ Verifying deployment..."
./scripts/final_verification.sh

# Update DNS if needed (Blue-Green)
echo ""
echo "🌐 Updating DNS records..."
if [ "$ENVIRONMENT" == "production" ]; then
    # Switch traffic to new cluster
    kubectl patch service bioshield-api -n $NAMESPACE -p '{"spec":{"selector":{"version":"green"}}}'
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                    ✅ PRODUCTION DEPLOYMENT COMPLETE                       ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
