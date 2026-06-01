# Integration Guide for Financial Institutions

## Overview

This guide helps banking and telecommunications partners integrate Sovereign Bio-Shield Ultimate into their existing infrastructure.

## Architecture Options

### Option 1: On-Premise (Recommended)
Deploy within your private cloud/firewall:
- **Pros:** Zero data exposure, full control
- **Cons:** Requires hardware setup

### Option 2: Hybrid
Cloud API + local caching:
- **Pros:** Faster deployment
- **Cons:** Some data leaves premises

## Integration Steps

### Step 1: Obtain API Credentials
```bash
# Contact support to get your API key
curl -X POST https://api.bioshield/v1/admin/clients \
  -H "X-Admin-Token: YOUR_ADMIN_KEY" \
  -d '{
    "client_name": "National Bank of Tanzania",
    "contact_email": "security@nbt.go.tz",
    "tier": "enterprise"
  }'
