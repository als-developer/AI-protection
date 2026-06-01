#!/bin/bash
set -euo pipefail

VERSION=${1:-previous}
echo "Rolling back BioShield Ultimate to version: $VERSION"

# Stop services
systemctl stop bioshield-api bioshield-engine

# Rollback database if needed
if [ -f "/var/backups/bioshield/database_rollback.dump" ]; then
    docker exec -i bioshield-postgres pg_restore -U bioshield -d bioshield \
        --clean --if-exists < /var/backups/bioshield/database_rollback.dump
fi

# Start previous versions
docker pull bioshield/api:$VERSION
docker pull bioshield/engine:$VERSION

systemctl start bioshield-engine
sleep 5
systemctl start bioshield-api

# Verify rollback
./scripts/health_check.sh

echo "✅ Rollback to $VERSION completed successfully!"
