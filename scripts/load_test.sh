#!/bin/bash
set -euo pipefail

DURATION=${1:-60}
THREADS=${2:-10}

echo "Starting load test: $DURATION seconds, $THREADS threads"

# Install dependencies if needed
pip3 install locust -q

# Run load test
locust -f tests/load/locustfile.py \
  --headless \
  --host http://localhost:8000 \
  --users $THREADS \
  --spawn-rate 1 \
  --run-time ${DURATION}s \
  --html /tmp/load_test_report.html

echo "Load test complete! Report: /tmp/load_test_report.html"
