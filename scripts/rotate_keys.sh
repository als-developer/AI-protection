#!/bin/bash
set -euo pipefail

echo "Rotating API keys..."

# Generate new API key
NEW_KEY=$(openssl rand -hex 32)
KEY_HASH=$(echo -n "$NEW_KEY" | sha256sum | cut -d' ' -f1)

# Insert into database
docker exec -i bioshield-postgres psql -U bioshield -d bioshield <<EOF
INSERT INTO developer_api_keys (api_key_hash, api_key_prefix, developer_id, account_balance_usd)
VALUES ('$KEY_HASH', 'sk_new', 'new_developer', 100.00);
EOF

echo "New API key generated: $NEW_KEY"
echo "Store this key securely - it will not be shown again!"
