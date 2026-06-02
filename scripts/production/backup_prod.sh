#!/bin/bash
set -euo strict

# Production Backup Script with Multi-Region Replication

BACKUP_DIR="/var/backups/bioshield"
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
BACKUP_FILE="${BACKUP_DIR}/bioshield_full_${TIMESTAMP}.tar.gz"
ENCRYPTED_FILE="${BACKUP_FILE}.gpg"

mkdir -p "$BACKUP_DIR"

echo "🔄 Starting production backup at $(date)"

# Backup database
echo "  → Backing up PostgreSQL..."
kubectl exec -n bioshield-system postgres-0 -- pg_dump -U bioshield bioshield > "${BACKUP_DIR}/database_${TIMESTAMP}.sql"

# Backup Redis
echo "  → Backing up Redis..."
kubectl exec -n bioshield-system redis-0 -- redis-cli SAVE
kubectl cp bioshield-system/redis-0:/data/dump.rdb "${BACKUP_DIR}/redis_${TIMESTAMP}.rdb"

# Backup configurations
echo "  → Backing up configurations..."
tar -czf "${BACKUP_DIR}/config_${TIMESTAMP}.tar.gz" -C /opt/bioshield config/

# Create full archive
echo "  → Creating full archive..."
tar -czf "$BACKUP_FILE" -C "$BACKUP_DIR" database_${TIMESTAMP}.sql redis_${TIMESTAMP}.rdb config_${TIMESTAMP}.tar.gz

# Encrypt backup
echo "  → Encrypting backup..."
gpg --batch --yes --encrypt --recipient backup@bioshield.secure-bank.internal --output "$ENCRYPTED_FILE" "$BACKUP_FILE"

# Upload to S3 (Primary)
echo "  → Uploading to S3 (Primary)..."
aws s3 cp "$ENCRYPTED_FILE" s3://bioshield-backups-prod-us-east-1/backups/

# Upload to S3 (Secondary - DR)
echo "  → Uploading to S3 (Secondary)..."
aws s3 cp "$ENCRYPTED_FILE" s3://bioshield-backups-prod-eu-west-1/backups/ --region eu-west-1

# Cleanup old backups (keep 30 days)
echo "  → Cleaning up old backups..."
find "$BACKUP_DIR" -name "bioshield_full_*.tar.gz.gpg" -mtime +30 -delete
find "$BACKUP_DIR" -name "*.sql" -mtime +7 -delete
find "$BACKUP_DIR" -name "*.rdb" -mtime +7 -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete

echo "✅ Production backup completed: $ENCRYPTED_FILE"
echo "   Size: $(du -h "$ENCRYPTED_FILE" | cut -f1)"
