#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     BIO-SHIELD ULTIMATE MANIFEST VALIDATION TOOL          ║"
echo "╚════════════════════════════════════════════════════════════╝"

MISSING=0

check_file() {
    if [ -f "$1" ]; then
        echo "✅ $1"
    else
        echo "❌ $1"
        MISSING=$((MISSING + 1))
    fi
}

check_dir() {
    if [ -d "$1" ]; then
        echo "✅ $1/"
    else
        echo "❌ $1/"
        MISSING=$((MISSING + 1))
    fi
}

echo ""
echo "Core Engine Files:"
check_file "core/main_engine.cpp"
check_file "core/avx512_math.cpp"
check_file "core/lockfree_queue.cpp"
check_file "core/deepfake_detector.cpp"
check_file "core/nic_xdp.c"

echo ""
echo "API Files:"
check_file "api/main.py"
check_file "api/routers/voice_audit.py"
check_file "api/routers/health.py"
check_file "api/middleware/auth.py"
check_file "api/services/deepfake_service.py"

echo ""
echo "Database Files:"
check_dir "db/migrations"
check_file "db/migrations/001_init.sql"
check_file "db/migrations/002_multi_channel.sql"

echo ""
echo "Kubernetes Manifests:"
check_file "infra/kubernetes/deployment.yaml"
check_file "infra/kubernetes/service.yaml"
check_file "infra/kubernetes/network_policy.yaml"

echo ""
echo "Docker Files:"
check_file "docker/Dockerfile.api"
check_file "docker/Dockerfile.engine"
check_file "docker/docker-compose.yml"

echo ""
echo "Documentation:"
check_file "docs/README.md"
check_file "docs/ARCHITECTURE.md"
check_file "docs/RUNBOOK.md"

echo ""
echo "Scripts:"
check_file "scripts/deploy.sh"
check_file "scripts/health_check.sh"
check_file "scripts/watchdog.sh"

echo ""
echo "════════════════════════════════════════════════════════════"
if [ $MISSING -eq 0 ]; then
    echo "✅ ALL FILES PRESENT - System ready for deployment!"
else
    echo "⚠️  $MISSING files missing - Please verify installation"
fi
echo "════════════════════════════════════════════════════════════"
