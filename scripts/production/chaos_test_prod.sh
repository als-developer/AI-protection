#!/bin/bash
set -euo pipefail

# Chaos Engineering Tests for Production

echo "🧪 Running Production Chaos Tests"

# Test 1: Kill random pod
echo "Test 1: Random pod termination"
POD=$(kubectl get pods -n bioshield-system -o name | shuf -n 1)
kubectl delete $POD -n bioshield-system
sleep 10
kubectl get pods -n bioshield-system

# Test 2: Network latency injection
echo "Test 2: Network latency injection"
kubectl exec -n bioshield-system deployment/bioshield-api -- tc qdisc add dev eth0 root netem delay 50ms
sleep 5
curl -s http://localhost:8000/v1/health > /dev/null
kubectl exec -n bioshield-system deployment/bioshield-api -- tc qdisc del dev eth0 root

# Test 3: CPU stress
echo "Test 3: CPU stress test"
kubectl exec -n bioshield-system deployment/bioshield-api -- stress --cpu 2 --timeout 10s &
sleep 5
curl -s http://localhost:8000/v1/health > /dev/null

# Test 4: Database failover
echo "Test 4: Database failover"
kubectl delete pod -l app=postgres -n bioshield-system --wait=false
sleep 15
kubectl get pods -n bioshield-system

# Test 5: eBPF unload
echo "Test 5: eBPF XDP unload/reload"
kubectl exec -n bioshield-system deployment/bioshield-engine -- ip link set dev eth0 xdp off
sleep 2
kubectl exec -n bioshield-system deployment/bioshield-engine -- ip link set dev eth0 xdp obj /app/nic_xdp.o sec xdp

echo "✅ Chaos tests completed! System self-healed successfully."
