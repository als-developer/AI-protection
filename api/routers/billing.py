from fastapi import APIRouter, HTTPException, Depends, Header
from typing import Dict, Optional
from datetime import datetime, timedelta
import stripe

from models.billing import CreditPackage, Invoice, PaymentMethod
from services.billing_service import BillingService
from middleware.auth import verify_token

router = APIRouter()

# Initialize Stripe (production)
stripe.api_key = "sk_live_your_stripe_secret_key"

@router.get("/balance")
async def get_balance(
    authorization_token: str = Header(..., alias="X-BioShield-Token")
):
    """Get current account balance."""
    client_id = await verify_token(authorization_token)
    balance = await BillingService.get_balance(client_id)
    return {
        "balance_usd": balance,
        "currency": "USD",
        "estimated_scans": int(balance / 0.10)
    }

@router.post("/credits/purchase")
async def purchase_credits(
    package: CreditPackage,
    authorization_token: str = Header(..., alias="X-BioShield-Token")
):
    """Purchase additional credits."""
    client_id = await verify_token(authorization_token)
    
    # Create Stripe payment intent
    intent = stripe.PaymentIntent.create(
        amount=int(package.amount_usd * 100),
        currency='usd',
        metadata={'client_id': client_id, 'package': package.package_name}
    )
    
    return {
        "client_secret": intent.client_secret,
        "payment_intent_id": intent.id,
        "amount_usd": package.amount_usd,
        "credits_added": int(package.amount_usd / 0.10)
    }

@router.get("/invoices")
async def get_invoices(
    authorization_token: str = Header(..., alias="X-BioShield-Token"),
    limit: int = 10,
    offset: int = 0
):
    """Get billing history."""
    client_id = await verify_token(authorization_token)
    invoices = await BillingService.get_invoices(client_id, limit, offset)
    return {"invoices": invoices, "total": len(invoices)}

@router.get("/usage")
async def get_usage(
    authorization_token: str = Header(..., alias="X-BioShield-Token"),
    days: int = 30
):
    """Get API usage statistics."""
    client_id = await verify_token(authorization_token)
    usage = await BillingService.get_usage(client_id, days)
    return usage

@router.post("/payment-method")
async def add_payment_method(
    payment_method_id: str,
    authorization_token: str = Header(..., alias="X-BioShield-Token")
):
    """Add a payment method."""
    client_id = await verify_token(authorization_token)
    result = await BillingService.add_payment_method(client_id, payment_method_id)
    return result
