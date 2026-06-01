#!/bin/bash
# Encrypt existing backups for offsite storage

set -euo pipefail

BACKUP_DIR="/var/backups/bioshield_db"
OFFSITE_DIR="/mnt/offsite/bioshield_backups"

mkdir -p "${OFFSITE_DIR}"

for backup in "${BACKUP_DIR}"/*.sql.gz; do
    if [ -f "${backup}" ]; then
        filename=$(basename "${backup}")
        echo "Encrypting ${filename}..."
        
        gpg --batch --yes --encrypt \
            --recipient "offsite@bioshield.secure-bank.internal" \
            --output "${OFFSITE_DIR}/${filename}.gpg" \
            "${backup}"
    fi
done

echo "[$(date)] Offsite encryption completed."
