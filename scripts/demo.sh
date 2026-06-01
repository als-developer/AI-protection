#!/bin/bash
set -euo pipefail

# BioShield Ultimate Demo Script
# Run this for live demonstrations

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     BIO-SHIELD ULTIMATE LIVE DEMO                          ║"
echo "╚════════════════════════════════════════════════════════════╝"

# Check if system is running
./scripts/health_check.sh

# Demo 1: Human Voice (Should pass)
echo ""
echo "📞 Demo 1: Human Voice Authentication"
echo "--------------------------------------"
curl -s -X POST http://localhost:8000/v1/audit-voice \
  -H "X-BioShield-Token: sk_demo_key" \
  -H "Content-Type: application/json" \
  -d '{
    "bank_cluster_token": "demo_bank",
    "channel_identity": "human_caller",
    "frequency_amplitude_deltas": [0.45, 1.23, 0.98, 2.11, 1.54, 0.87, 1.92, 0.34, 1.67, 0.78]
  }' | jq '.'

sleep 2

# Demo 2: AI Clone (Should block)
echo ""
echo "🤖 Demo 2: AI Voice Clone Detection"
echo "------------------------------------"
curl -s -X POST http://localhost:8000/v1/audit-voice \
  -H "X-BioShield-Token: sk_demo_key" \
  -H "Content-Type: application/json" \
  -d '{
    "bank_cluster_token": "demo_bank",
    "channel_identity": "ai_clone",
    "frequency_amplitude_deltas": [0.12, 0.12, 0.11, 0.12, 0.12, 0.12, 0.11, 0.12, 0.12, 0.12]
  }' | jq '.'

# Show metrics
echo ""
echo "📊 Live Metrics"
echo "---------------"
curl -s http://localhost:8000/v1/metrics/streams | jq '.'

echo ""
echo "✅ Demo complete!"
echo "Dashboard: http://localhost:3000 (admin/admin)"
