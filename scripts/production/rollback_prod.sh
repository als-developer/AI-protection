#!/bin/bash
set -euo pipefail

VERSION=${1:-previous}
NAMESPACE="bioshield-system"

echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║              SOVEREIGN BIO-SHIELD - PRODUCTION ROLLBACK                   ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"

# Confirm rollback
read -p "⚠️  Confirm rollback to $VERSION? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Rollback cancelled."
    exit 0
fi

# Stop traffic
echo "🛑 Stopping incoming traffic..."
kubectl scale deployment bioshield-api -n $NAMESPACE --replicas=0

# Rollback database
echo "🗄️ Rolling back database..."
./scripts/restore.sh /var/backups/bioshield/pre_rollback_$VERSION.gpg

# Rollback images
echo "🐳 Rolling back Docker images..."
kubectl set image deployment/bioshield-api api=bioshield/api:$VERSION -n $NAMESPACE
kubectl set image deployment/bioshield-engine engine=bioshield/engine:$VERSION -n $NAMESPACE

# Restore traffic
echo "🔄 Restoring traffic..."
kubectl scale deployment bioshield-api -n $NAMESPACE --replicas=5

# Verify
echo "✅ Verifying rollback..."
./scripts/health_check.sh

echo "✅ Rollback to $VERSION completed successfully!"
