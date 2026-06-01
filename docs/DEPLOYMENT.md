# Deployment Guide

## Prerequisites

- Kubernetes cluster (v1.28+)
- PostgreSQL 15+
- Redis 7+
- Docker 24+
- Ansible 8+
- Terraform 1.5+

## Production Deployment

### 1. Infrastructure Provisioning (Terraform)

```bash
cd infra/terraform
terraform init
terraform plan
terraform apply -auto-approve
