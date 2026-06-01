#!/bin/bash
set -euo pipefail

echo "Installing BioShield Ultimate dependencies..."

# Update system
apt-get update && apt-get upgrade -y

# Install base packages
apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    cmake \
    python3 \
    python3-pip \
    python3-venv \
    docker.io \
    docker-compose \
    postgresql-client \
    redis-tools \
    nginx \
    haproxy \
    prometheus \
    grafana

# Install eBPF tools
apt-get install -y \
    clang \
    llvm \
    libbpf-dev \
    linux-tools-common \
    linux-tools-generic \
    bpftool

# Install Go
wget https://golang.org/dl/go1.22.0.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc

# Install Python packages
pip3 install --upgrade pip
pip3 install -r requirements.txt

# Install Rust (for eBPF development)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update && apt-get install terraform

# Install Ansible
apt-get install -y ansible

echo "✅ All dependencies installed successfully!"
