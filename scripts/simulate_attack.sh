#!/bin/bash
set -euo pipefail

API_URL="http://localhost:8000/v1/audit-voice"
API_KEY="sk_load_test_key"
THREADS=${1:-10}
DURATION=${2:-30}

echo "Simulating deepfake attack with $THREADS threads for $DURATION seconds..."

# Function to send deepfake payload
send_deepfake() {
    local id=$1
    local end_time=$((SECONDS + DURATION))
    
    while [ $SECONDS -lt $end_time ]; do
        # Generate AI clone pattern (low variance)
        payload=$(printf '{"bank_cluster_token":"attack_bank_%d","channel_identity":"trunk_%d","frequency_amplitude_deltas":[' "$id" "$id")
        for i in {1..50}; do
            payload+="0.12,"
        done
        payload="${payload%,}]}"
        
        curl -s -X POST "$API_URL" \
            -H "X-BioShield-Token: $API_KEY" \
            -H "Content-Type: application/json" \
            -d "$payload" > /dev/null &
        
        sleep 0.01
    done
}

# Launch attack threads
for i in $(seq 1 $THREADS); do
    send_deepfake $i &
done

# Wait for completion
wait

echo "Attack simulation completed!"
echo "Check dashboard for detection results: http://localhost:3000"
