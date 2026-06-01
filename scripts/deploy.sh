#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     SOVEREIGN BIO-SHIELD ULTIMATE DEPLOYMENT SCRIPT       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo -e "${RED}Docker not installed${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${YELLOW}kubectl not found, skipping K8s deployment${NC}"; }
command -v ansible >/dev/null 2>&1 || { echo -e "${YELLOW}Ansible not found, skipping playbook execution${NC}"; }

# Load environment
ENV=${1:-production}
echo -e "${GREEN}Target environment: ${ENV}${NC}"
source config/.env.${ENV}

# Phase 1: Build Docker images
echo -e "\n${GREEN}[Phase 1] Building Docker images...${NC}"
docker build -t bioshield/api:latest -f docker/Dockerfile.api .
docker build -t bioshield/engine:latest -f docker/Dockerfile.engine .
docker build -t bioshield/ebpf:latest -f docker/Dockerfile.ebpf .

# Phase 2: Deploy infrastructure
echo -e "\n${GREEN}[Phase 2] Deploying infrastructure...${NC}"
if command -v terraform >/dev/null 2>&1; then
    cd infra/terraform
    terraform init
    terraform apply -auto-approve -var="environment=${ENV}"
    cd ../..
fi

# Phase 3: Deploy Kubernetes resources
echo -e "\n${GREEN}[Phase 3] Deploying Kubernetes resources...${NC}"
if command -v kubectl >/dev/null 2>&1; then
    kubectl create namespace bioshield-system --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f infra/kubernetes/configmap.yaml
    kubectl apply -f infra/kubernetes/secret.yaml
    kubectl apply -f infra/kubernetes/deployment.yaml
    kubectl apply -f infra/kubernetes/service.yaml
    kubectl apply -f infra/kubernetes/network_policy.yaml
    kubectl rollout status deployment/bioshield-core -n bioshield-system --timeout=300s
fi

# Phase 4: Run Ansible playbooks
echo -e "\n${GREEN}[Phase 4] Running Ansible playbooks...${NC}"
if command -v ansible-playbook >/dev/null 2>&1; then
    ansible-playbook -i infra/ansible/inventory.${ENV} infra/ansible/deploy.yml
fi

# Phase 5: Load eBPF program
echo -e "\n${GREEN}[Phase 5] Loading eBPF XDP program...${NC}"
./scripts/setup_ebpf.sh

# Phase 6: Verify deployment
echo -e "\n${GREEN}[Phase 6] Verifying deployment...${NC}"
sleep 10
./scripts/health_check.sh

echo -e "\n${GREEN}✅ Deployment complete!${NC}"
echo -e "API endpoint: https://api.bioshield.secure-bank.internal"
echo -e "Dashboard: https://monitoring.bioshield.secure-bank.internal"
