#!/bin/bash
set -euo pipefail

BACKUP_FILE=${1:-}

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file.gpg>"
    echo "Available backups:"
    ls -la /var/backups/bioshield/*.gpg 2>/dev/null || echo "No backups found"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Backup file not found: $BACKUP_FILE"
    exit 1
fi

log_message() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $1"
}

log_message "Starting restore from $BACKUP_FILE..."

# Stop services
log_message "Stopping services..."
systemctl stop bioshield-api bioshield-engine

# Create restore directory
RESTORE_DIR=$(mktemp -d)

# Decrypt and extract
log_message "Decrypting backup..."
gpg --batch --decrypt "$BACKUP_FILE" | tar -xzf - -C "$RESTORE_DIR"

# Restore database
log_message "Restoring database..."
docker exec -i bioshield-postgres pg_restore -U bioshield -d bioshield \
    --clean --if-exists < "${RESTORE_DIR}/database.dump"

# Restore Redis
log_message "Restoring Redis..."
docker cp "${RESTORE_DIR}/redis.rdb" bioshield-redis:/data/dump.rdb
docker exec bioshield-redis redis-cli SHUTDOWN NOSAVE
docker start bioshield-redis

# Restore configuration
log_message "Restoring configuration..."
cp -r "${RESTORE_DIR}/config"/* /opt/bioshield/config/

# Cleanup
rm -rf "$RESTORE_DIR"

# Restart services
log_message "Restarting services..."
systemctl start bioshield-engine
sleep 5
systemctl start bioshield-api

log_message "Restore completed successfully!"
