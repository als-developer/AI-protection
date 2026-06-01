#!/bin/bash
# Automated database backup script

set -euo pipefail

BACKUP_DIR="/var/backups/bioshield_db"
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
DB_NAME="bioshield_prod"
DB_USER="supabase_admin"
BACKUP_FILE="${BACKUP_DIR}/bioshield_full_${TIMESTAMP}.sql.gz"

mkdir -p "${BACKUP_DIR}"

echo "[$(date)] Starting database backup..."

# Dump database with compression
pg_dump -U ${DB_USER} -h localhost -d ${DB_NAME} \
    --format=custom \
    --compress=9 \
    --file="${BACKUP_FILE%.gz}" \
    --verbose

# Encrypt backup
gpg --batch --yes --encrypt \
    --recipient "backup@bioshield.secure-bank.internal" \
    "${BACKUP_FILE%.gz}"

# Remove unencrypted file
rm -f "${BACKUP_FILE%.gz}"

# Keep only last 7 days of backups
find "${BACKUP_DIR}" -name "bioshield_full_*.sql.gz.gpg" -mtime +7 -delete

echo "[$(date)] Backup completed: ${BACKUP_FILE}.gpg"
