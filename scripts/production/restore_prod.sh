#!/bin/bash
set -euo pipefail

BACKUP_FILE=${1:-}

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file.gpg>"
    echo "Available backups:"
    aws s3 ls s3://bioshield-backups-prod-us-east-1/backups/
    exit 1
fi

echo "⚠️  WARNING: This will restore production database from backup!"
read -p "Type 'RESTORE' to continue: " confirm
if [ "$confirm" != "RESTORE" ]; then
    echo "Restore cancelled."
    exit 0
fi

# Download backup if not local
if [ ! -f "$BACKUP_FILE" ]; then
    echo "📥 Downloading backup from S3..."
    aws s3 cp "s3://bioshield-backups-prod-us-east-1/backups/$(basename $BACKUP_FILE)" "$BACKUP_FILE"
fi

echo "🔄 Starting production restore from $BACKUP_FILE"

# Decrypt backup
echo "  → Decrypting backup..."
gpg --batch --decrypt "$BACKUP_FILE" > /tmp/restore.tar.gz

# Extract
echo "  → Extracting backup..."
tar -xzf /tmp/restore.tar.gz -C /tmp/

# Stop services
echo "  → Stopping services..."
kubectl scale deployment bioshield-api -n bioshield-system --replicas=0
kubectl scale deployment bioshield-engine -n bioshield-system --replicas=0

# Restore database
echo "  → Restoring database..."
kubectl exec -n bioshield-system postgres-0 -- psql -U bioshield -c "DROP DATABASE bioshield;"
kubectl exec -n bioshield-system postgres-0 -- psql -U bioshield -c "CREATE DATABASE bioshield;"
kubectl exec -n bioshield-system postgres-0 -i -- psql -U bioshield bioshield < /tmp/database_*.sql

# Restore Redis
echo "  → Restoring Redis..."
kubectl cp /tmp/redis_*.rdb bioshield-system/redis-0:/data/dump.rdb
kubectl exec -n bioshield-system redis-0 -- redis-cli SHUTDOWN NOSAVE
kubectl wait --for=condition=ready pod -l app=redis -n bioshield-system --timeout=60s

# Restore configurations
echo "  → Restoring configurations..."
tar -xzf /tmp/config_*.tar.gz -C /opt/bioshield/

# Start services
echo "  → Starting services..."
kubectl scale deployment bioshield-engine -n bioshield-system --replicas=3
sleep 10
kubectl scale deployment bioshield-api -n bioshield-system --replicas=5

# Verify
echo "  → Verifying restore..."
./scripts/health_check.sh

# Cleanup
rm -f /tmp/restore.tar.gz /tmp/database_*.sql /tmp/redis_*.rdb /tmp/config_*.tar.gz

echo "✅ Production restore completed successfully!"
