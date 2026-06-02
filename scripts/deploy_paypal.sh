#!/bin/bash
set -euo pipefail

echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                 DEPLOYING PAYPAL INTEGRATION                              ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"

# Set PayPal environment variables
export PAYPAL_ENV="sandbox"
export PAYPAL_CLIENT_ID="AdYZjwcxNYqpWCglcoqt4cv0ESkJ-G3RChAAuuET"
export PAYPAL_SECRET_KEY="EAecZX7x2XtI61BA-b72HxH0A4xInOX6rnolchtua"

# Run database migrations
echo "📦 Running database migrations..."
docker exec -i bioshield-postgres psql -U supabase_admin -d postgres < db/migrations/006_paypal_tables.sql

# Deploy PayPal routes
echo "🌐 Deploying PayPal API routes..."
kubectl rollout restart deployment/bioshield-api -n bioshield-system

# Deploy web pages
echo "📄 Deploying billing pages..."
cp web/billing/*.html /var/www/html/bioshield/billing/

echo ""
echo "✅ PayPal integration deployed successfully!"
echo ""
echo "📋 Configuration Summary:"
echo "   - Environment: $PAYPAL_ENV"
echo "   - Client ID: ${PAYPAL_CLIENT_ID:0:20}..."
echo "   - Pricing Page: https://bioshield/billing/pricing.html"
echo "   - Checkout: https://bioshield/billing/checkout.html"
