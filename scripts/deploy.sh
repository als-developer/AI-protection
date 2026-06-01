#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     SOVEREIGN BIO-SHIELD ULTIMATE DEPLOYMENT SCRIPT       ║"
echo "╚════════════════════════════════════════════════════════════╝"

ENV=${1:-production}
echo "Target environment: ${ENV}"

# Load environment variables
source config/.env.${ENV}

# Build Docker images
echo "Building Docker images..."
docker build -t bioshield/api:latest -f docker/Dockerfile.api .
docker build -t bioshield/engine:latest -f docker/Dockerfile.engine .

# Deploy with docker-compose
echo "Starting services..."
docker-compose -f docker/docker-compose.${ENV}.yml up -d

# Wait for services to be ready
echo "Waiting for services..."
sleep 10

# Verify deployment
./scripts/health_check.sh

echo "✅ Deployment complete!"
echo "API endpoint: http://localhost:8000"
echo "Health check: http://localhost:8000/v1/health"
