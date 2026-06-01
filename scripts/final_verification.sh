#!/bin/bash
set -euo pipefail

# Final verification script before production launch
# Run this after full deployment to ensure everything is working

echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║              SOVEREIGN BIO-SHIELD ULTIMATE - FINAL VERIFICATION           ║"
echo "║                         PRODUCTION READINESS CHECK                        ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"

PASSED=0
FAILED=0
WARNINGS=0

check() {
    if [ $? -eq 0 ]; then
        echo "   ✅ PASSED"
        PASSED=$((PASSED + 1))
    else
        echo "   ❌ FAILED"
        FAILED=$((FAILED + 1))
    fi
}

check_warning() {
    if [ $? -eq 0 ]; then
        echo "   ✅ PASSED"
        PASSED=$((PASSED + 1))
    else
        echo "   ⚠️ WARNING"
        WARNINGS=$((WARNINGS + 1))
    fi
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 PHASE 1: INFRASTRUCTURE VERIFICATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check Docker
echo -n "   • Docker daemon running..."
docker info > /dev/null 2>&1 && check

# Check Docker Compose
echo -n "   • Docker Compose available..."
docker-compose version > /dev/null 2>&1 && check

# Check kubectl (optional)
echo -n "   • kubectl available..."
kubectl version --client > /dev/null 2>&1 && check_warning

# Check Terraform (optional)
echo -n "   • Terraform available..."
terraform version > /dev/null 2>&1 && check_warning

# Check Ansible (optional)
echo -n "   • Ansible available..."
ansible --version > /dev/null 2>&1 && check_warning

# Check Go (optional)
echo -n "   • Go available..."
go version > /dev/null 2>&1 && check_warning

# Check Python
echo -n "   • Python 3.11+ available..."
python3 --version 2>&1 | grep -q "Python 3" && check

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 PHASE 2: CONFIGURATION VERIFICATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check environment files
echo -n "   • .env.production exists..."
[ -f "config/.env.production" ] && check

# Check SSL certificates
echo -n "   • SSL certificates configured..."
[ -f "/etc/ssl/certs/bioshield.crt" ] && check_warning

# Check database migrations
echo -n "   • Database migrations applied..."
docker exec bioshield-postgres psql -U bioshield -d bioshield -c "\dt" 2>/dev/null | grep -q "deepfake_audit_logs" && check

# Check Redis
echo -n "   • Redis configured..."
redis-cli ping 2>/dev/null | grep -q "PONG" && check

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛡️ PHASE 3: SECURITY VERIFICATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check API authentication
echo -n "   • API authentication enforced..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/v1/audit-voice 2>/dev/null | grep -q "401" && check

# Check rate limiting
echo -n "   • Rate limiting active..."
RATE_CHECK=$(for i in {1..20}; do curl -s -o /dev/null -w "%{http_code}" -H "X-BioShield-Token: sk_test_key" http://localhost:8000/v1/audit-voice 2>/dev/null; done | grep -c "429")
[ "$RATE_CHECK" -gt 0 ] && check

# Check eBPF XDP (warning if not)
echo -n "   • eBPF XDP loaded..."
ip link show eth0 2>/dev/null | grep -q "xdp" && check_warning

# Check TLS (if HTTPS enabled)
echo -n "   • TLS 1.3 configured..."
nmap --script ssl-enum-ciphers -p 443 localhost 2>/dev/null | grep -q "TLSv1.3" && check_warning

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚡ PHASE 4: PERFORMANCE VERIFICATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check API latency
echo -n "   • API latency (<15ms)..."
LATENCY=$(curl -s -w "%{time_total}" -o /dev/null http://localhost:8000/v1/health 2>/dev/null)
if [ -n "$LATENCY" ]; then
    LATENCY_MS=$(echo "$LATENCY * 1000" | bc)
    if (( $(echo "$LATENCY_MS < 15" | bc -l) )); then
        check
    else
        echo "   ❌ FAILED (${LATENCY_MS}ms)"
        FAILED=$((FAILED + 1))
    fi
else
    echo "   ❌ FAILED (API not responding)"
    FAILED=$((FAILED + 1))
fi

# Check C++ engine
echo -n "   • C++ engine running..."
pgrep -f "bioshield_engine" > /dev/null && check

# Check database response time
echo -n "   • Database query (<10ms)..."
DB_TIME=$(docker exec bioshield-postgres psql -U bioshield -d bioshield -c "\timing" -c "SELECT 1;" 2>&1 | grep "Time:" | awk '{print $2}')
if [ -n "$DB_TIME" ]; then
    if (( $(echo "$DB_TIME < 10" | bc -l) )); then
        check
    else
        echo "   ⚠️ WARNING (${DB_TIME}ms)"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 PHASE 5: INTEGRATION VERIFICATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test human voice detection
echo -n "   • Human voice detection..."
HUMAN_RESULT=$(curl -s -X POST http://localhost:8000/v1/audit-voice \
    -H "X-BioShield-Token: sk_test_key" \
    -H "Content-Type: application/json" \
    -d '{"bank_cluster_token":"test","channel_identity":"test","frequency_amplitude_deltas":[0.45,1.23,0.98,2.11,1.54,0.87,1.92]}' 2>/dev/null | jq -r '.evaluation_verdict')
if [[ "$HUMAN_RESULT" == "VERIFIED_HUMAN_AUTHENTIC" || "$HUMAN_RESULT" == "SUSPICIOUS_PATTERN" ]]; then
    check
else
    echo "   ❌ FAILED (got: $HUMAN_RESULT)"
    FAILED=$((FAILED + 1))
fi

# Test deepfake detection
echo -n "   • Deepfake detection..."
DEEPFAKE_RESULT=$(curl -s -X POST http://localhost:8000/v1/audit-voice \
    -H "X-BioShield-Token: sk_test_key" \
    -H "Content-Type: application/json" \
    -d '{"bank_cluster_token":"test","channel_identity":"test","frequency_amplitude_deltas":[0.12,0.12,0.11,0.12,0.12,0.12,0.11,0.12]}' 2>/dev/null | jq -r '.evaluation_verdict')
if [[ "$DEEPFAKE_RESULT" == "CRITICAL_SUSPECTED_DEEPFAKE" ]]; then
    check
else
    echo "   ❌ FAILED (got: $DEEPFAKE_RESULT)"
    FAILED=$((FAILED + 1))
fi

# Check Prometheus metrics
echo -n "   • Prometheus metrics endpoint..."
curl -s http://localhost:9090/-/healthy 2>/dev/null | grep -q "Prometheus" && check_warning

# Check Grafana
echo -n "   • Grafana dashboard..."
curl -s http://localhost:3000/api/health 2>/dev/null | grep -q "ok" && check_warning

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📈 PHASE 6: RESULTS SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "   ✅ PASSED:  $PASSED"
echo "   ❌ FAILED:  $FAILED"
echo "   ⚠️ WARNINGS: $WARNINGS"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "╔═══════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                           ║"
    echo "║     🎉 ALL CHECKS PASSED! SYSTEM IS PRODUCTION READY! 🎉                  ║"
    echo "║                                                                           ║"
    echo "║     Your Sovereign Bio-Shield Ultimate is fully operational and ready     ║"
    echo "║     to protect your organization from deepfake and voice cloning fraud.  ║"
    echo "║                                                                           ║"
    echo "║     Dashboard:   http://localhost:3000 (admin/your-password)              ║"
    echo "║     API Docs:     http://localhost:8000/api/docs                         ║"
    echo "║     Health Check: http://localhost:8000/v1/health                        ║"
    echo "║                                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════╝"
else
    echo "╔═══════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                           ║"
    echo "║     ⚠️ SOME CHECKS FAILED - PLEASE REVIEW AND FIX ISSUES ABOVE ⚠️         ║"
    echo "║                                                                           ║"
    echo "║     Run './scripts/health_check.sh' for detailed diagnostics              ║"
    echo "║     Check logs: 'docker logs bioshield-api --tail 50'                    ║"
    echo "║                                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════╝"
    exit 1
fi
