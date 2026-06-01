#!/bin/bash
set -euo pipefail

CLUSTER_NAME=${1:-bioshield-prod}
echo "Syncing cluster: $CLUSTER_NAME"

# Sync configuration across nodes
ansible-playbook -i infra/ansible/inventory.yml infra/ansible/sync_config.yml

# Sync database schema
for node in $(kubectl get nodes -l node-role.kubernetes.io/worker -o name); do
    kubectl exec -n bioshield-system $node -- /opt/bioshield/scripts/data_migration.sh
done

# Sync eBPF programs
for node in $(kubectl get nodes -l node-role.kubernetes.io/worker -o name); do
    kubectl exec -n bioshield-system $node -- /opt/bioshield/scripts/setup_ebpf.sh
done

# Verify all nodes are in sync
kubectl get pods -n bioshield-system -o wide
kubectl get nodes

echo "✅ Cluster sync completed!"
