#!/bin/bash
set -euo pipefail

echo "🔒 Running Security Vulnerability Scan"

# Scan Docker images
echo "Scanning Docker images..."
docker scout quickview bioshield/api:latest
docker scout quickview bioshield/engine:latest

# Scan dependencies
echo "Scanning Python dependencies..."
safety check -r requirements.txt

# Scan for CVEs
echo "Checking for CVEs..."
trivy image bioshield/api:latest --severity HIGH,CRITICAL
trivy image bioshield/engine:latest --severity HIGH,CRITICAL

# Check exposed ports
echo "Checking exposed ports..."
nmap -p 8000,9090,3000 localhost

# Check TLS configuration
echo "Checking TLS configuration..."
testssl --quiet localhost:443

echo "✅ Security scan complete!"
