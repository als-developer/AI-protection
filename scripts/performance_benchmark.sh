#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     BIO-SHIELD PERFORMANCE BENCHMARK SUITE                 ║"
echo "╚════════════════════════════════════════════════════════════╝"

BENCHMARK_DIR="/tmp/bioshield_benchmark"
mkdir -p "$BENCHMARK_DIR"

# Test 1: API Latency
echo ""
echo "📊 Test 1: API Latency (1000 requests)"
ab -n 1000 -c 10 -H "X-BioShield-Token: sk_load_test_key" \
   -p /dev/null -T application/json \
   http://localhost:8000/v1/health > "$BENCHMARK_DIR/api_latency.txt"

# Extract p99 latency
P99=$(grep "99%" "$BENCHMARK_DIR/api_latency.txt" | awk '{print $2}')
echo "   p99 Latency: ${P99}ms"

# Test 2: Voice Audit Throughput
echo ""
echo "📊 Test 2: Voice Audit Throughput (10000 requests)"
cat > "$BENCHMARK_DIR/payload.json" << EOF
{
  "bank_cluster_token": "benchmark_bank",
  "channel_identity": "benchmark_channel",
  "frequency_amplitude_deltas": [0.12, 0.12, 0.11, 0.12, 0.12, 0.12, 0.11, 0.12, 0.12, 0.12]
}
EOF

wrk -t4 -c100 -d30s \
   -H "X-BioShield-Token: sk_load_test_key" \
   -s <(echo '
request = function()
   return wrk.format("POST", "/v1/audit-voice", nil, [=[
{
  "bank_cluster_token": "benchmark_bank",
  "channel_identity": "benchmark_channel", 
  "frequency_amplitude_deltas": [0.12, 0.12, 0.11, 0.12]
}=])
end
') http://localhost:8000 > "$BENCHMARK_DIR/throughput.txt"

# Extract requests per second
RPS=$(grep "Requests/sec" "$BENCHMARK_DIR/throughput.txt" | awk '{print $2}')
echo "   Throughput: ${RPS} req/sec"

# Test 3: C++ Engine Speed
echo ""
echo "📊 Test 3: C++ Engine Processing Speed"
cd core && make benchmark 2>/dev/null || g++ -O3 -march=native -std=c++23 bench_core.cpp -o bench_core
./bench_core 2>/dev/null | grep "Million Calls/sec"

echo ""
echo "✅ Benchmark complete! Results saved to: $BENCHMARK_DIR"
