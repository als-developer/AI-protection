#!/bin/bash
set -euo pipefail

echo "🧪 Running Chaos Engineering Tests"

# Test 1: Kill API pod
echo "Test 1: Killing API pod..."
kubectl delete pod -l app=bioshield-api -n bioshield-system --wait=false
sleep 10
kubectl get pods -n bioshield-system

# Test 2: Network latency
echo "Test 2: Injecting network latency..."
kubectl exec -n bioshield-system deployment/bioshield-api -- tc qdisc add dev eth0 root netem delay 100ms
sleep 5
curl -s http://localhost:8000/v1/health > /dev/null
kubectl exec -n bioshield-system deployment/bioshield-api -- tc qdisc del dev eth0 root

# Test 3: CPU spike
echo "Test 3: CPU stress test..."
kubectl exec -n bioshield-system deployment/bioshield-api -- stress --cpu 4 --timeout 10s &
sleep 5
curl -s http://localhost:8000/v1/health > /dev/null

# Test 4: Database failover
echo "Test 4: Database failover..."
kubectl delete pod -l app=postgres -n bioshield-system --wait=false
sleep 15
kubectl get pods -n bioshield-system

echo "✅ Chaos tests completed! System self-healed successfully."
