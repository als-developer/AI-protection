#!/bin/bash
set -euo pipefail

BACKUP_DIR="/var/backups/bioshield"
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
BACKUP_FILE="${BACKUP_DIR}/bioshield_full_${TIMESTAMP}.tar.gz.gpg"

mkdir -p "$BACKUP_DIR"

log_message() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $1"
}

log_message "Starting full system backup..."

# Create temporary backup directory
TEMP_DIR=$(mktemp -d)

# Backup database
log_message "Backing up PostgreSQL database..."
docker exec bioshield-postgres pg_dump -U bioshield -d bioshield \
    --format=custom --compress=9 \
    > "${TEMP_DIR}/database.dump"

# Backup Redis data
log_message "Backing up Redis data..."
docker exec bioshield-redis redis-cli --rdb /tmp/dump.rdb
docker cp bioshield-redis:/tmp/dump.rdb "${TEMP_DIR}/redis.rdb"

# Backup configuration files
log_message "Backing up configuration files..."
cp -r /opt/bioshield/config "${TEMP_DIR}/"

# Backup logs (last 7 days)
log_message "Backing up recent logs..."
find /var/log/bioshield -name "*.log" -mtime -7 -exec cp {} "${TEMP_DIR}/" \;

# Create archive
log_message "Creating archive..."
tar -czf - -C "$TEMP_DIR" . | gpg --batch --yes --encrypt \
    --recipient "backup@bioshield.secure-bank.internal" \
    --output "$BACKUP_FILE"

# Cleanup
rm -rf "$TEMP_DIR"

# Upload to S3 (if configured)
if [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then
    log_message "Uploading to S3..."
    aws s3 cp "$BACKUP_FILE" "s3://${BACKUP_S3_BUCKET}/backups/"
fi

# Delete old backups (keep 30 days)
find "$BACKUP_DIR" -name "bioshield_full_*.tar.gz.gpg" -mtime +30 -delete

log_message "Backup completed: $BACKUP_FILE"
log_message "Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"
