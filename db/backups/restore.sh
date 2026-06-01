#!/bin/bash
# Database restore script

set -euo pipefail

BACKUP_FILE=$1
DB_NAME="bioshield_prod"
DB_USER="supabase_admin"

if [ -z "${BACKUP_FILE}" ]; then
    echo "Usage: $0 <backup_file.gpg>"
    exit 1
fi

echo "[$(date)] Starting database restore from ${BACKUP_FILE}..."

# Decrypt backup
gpg --batch --decrypt "${BACKUP_FILE}" > "${BACKUP_FILE%.gpg}"

# Restore database
pg_restore -U ${DB_USER} -h localhost -d ${DB_NAME} \
    --clean \
    --if-exists \
    --verbose \
    "${BACKUP_FILE%.gpg}"

# Remove decrypted file
rm -f "${BACKUP_FILE%.gpg}"

echo "[$(date)] Restore completed."
