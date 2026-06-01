#!/bin/bash
set -euo pipefail

echo "🛠️ Running system maintenance..."

# Clean up old logs
find /var/log/bioshield -name "*.log" -mtime +30 -delete

# Rotate logs
logrotate -f /etc/logrotate.d/bioshield.conf

# Clean Docker
docker system prune -f
docker volume prune -f

# Vacuum database
docker exec bioshield-postgres psql -U bioshield -d bioshield -c "VACUUM ANALYZE;"

# Reindex database
docker exec bioshield-postgres psql -U bioshield -d bioshield -c "REINDEX DATABASE CONCURRENTLY bioshield;"

# Check for updates
docker pull bioshield/api:latest
docker pull bioshield/engine:latest

echo "✅ Maintenance complete!"
