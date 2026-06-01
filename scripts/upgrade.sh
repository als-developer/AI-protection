#!/bin/bash
set -euo pipefail

VERSION=${1:-latest}
echo "Upgrading BioShield Ultimate to version: $VERSION"

# Pull latest images
docker pull bioshield/api:$VERSION
docker pull bioshield/engine:$VERSION

# Backup current configuration
./scripts/backup_all.sh

# Stop services
systemctl stop bioshield-api bioshield-engine

# Update database schema
./scripts/data_migration.sh

# Start new versions
systemctl start bioshield-engine
sleep 5
systemctl start bioshield-api

# Verify upgrade
./scripts/health_check.sh

echo "✅ Upgrade to $VERSION completed successfully!"
