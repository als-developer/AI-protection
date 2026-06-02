"""
PayPal Payment Routes for BioShield Ultimate
Handles payment creation, webhooks, and credit management
"""

from fastapi import APIRouter, HTTPException, Request, Depends, Header
from fastapi.responses import JSONResponse, RedirectResponse
from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime
import json
import logging

from services.paypal_service import paypal_service
from services.billing_service import BillingService
from services.database_service import DatabaseService

router = APIRouter(prefix="/paypal", tags=["PayPal Payments"])
logger = logging.getLogger(__name__)


class CreatePaymentRequest(BaseModel):
    amount: float
    currency: str = "USD"
    package_name: Optional[str] = None
    return_url: Optional[str] = None
    cancel_url: Optional[str] = None


class CreateSubscriptionRequest(BaseModel):
    plan_id: str
    return_url: Optional[str] = None


@router.post("/create-order")
async def create_payment_order(
    request: CreatePaymentRequest,
    authorization_token: str = Header(None, alias="X-BioShield-Token")
):
    """
    Create a PayPal payment order for purchasing API credits
    """
    try:
        # Validate amount
        if request.amount <= 0:
            raise HTTPException(status_code=400, detail="Amount must be greater than 0")
        
        # Get client ID from token
        client_id = None
        if authorization_token:
            client_id = await BillingService.validate_api_key(authorization_token)
        
        # Determine package description
        description = request.package_name or f"BioShield API Credits - ${request.amount}"
        
        # Create PayPal order
        order = await paypal_service.create_order(
            amount=request.amount,
            currency=request.currency,
            description=description,
            client_id=client_id,
            return_url=request.return_url,
            cancel_url=request.cancel_url
        )
        
        # Store order in database (pending)
        await DatabaseService.create_payment_order({
            "order_id": order['order_id'],
            "client_id": client_id,
            "amount": request.amount,
            "currency": request.currency,
            "status": "PENDING",
            "created_at": datetime.utcnow().isoformat()
        })
        
        return {
            "success": True,
            "order_id": order['order_id'],
            "approval_url": order['approval_url'],
            "amount": order['amount'],
            "currency": order['currency']
        }
        
    except Exception as e:
        logger.error(f"Payment creation failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Payment creation failed: {str(e)}")


@router.get("/capture-order/{order_id}")
async def capture_payment_order(
    order_id: str,
    token: Optional[str] = None
):
    """
    Capture a PayPal order after customer approval
    Redirects to success/failure page
    """
    try:
        # Capture the order
        capture_result = await paypal_service.capture_order(order_id)
        
        if capture_result['status'] == 'COMPLETED':
            # Get order details from database
            order = await DatabaseService.get_payment_order(order_id)
            
            if order:
                # Update order status
                await DatabaseService.update_payment_order(order_id, {
                    "status": "COMPLETED",
                    "transaction_id": capture_result['transaction_id'],
                    "completed_at": datetime.utcnow().isoformat()
                })
                
                # Add credits to client account
                if order.get('client_id'):
                    await BillingService.add_credits(
                        order['client_id'],
                        order['amount'],
                        f"PayPal payment - Order: {order_id}"
                    )
            
            # Redirect to success page
            return RedirectResponse(
                url=f"/payment/success?order_id={order_id}&amount={order['amount'] if order else 0}"
            )
        else:
            # Update failed status
            await DatabaseService.update_payment_order(order_id, {
                "status": "FAILED",
                "failed_at": datetime.utcnow().isoformat()
            })
            
            return RedirectResponse(url=f"/payment/failed?order_id={order_id}")
            
    except Exception as e:
        logger.error(f"Capture failed: {str(e)}")
        return RedirectResponse(url=f"/payment/error?message={str(e)}")


@router.post("/webhook")
async def paypal_webhook(request: Request):
    """
    PayPal webhook endpoint for asynchronous payment notifications
    """
    try:
        # Get raw body and headers
        body = await request.body()
        headers = dict(request.headers)
        
        # Verify webhook signature
        webhook_id = "YOUR_WEBHOOK_ID"  # Set this from PayPal Developer Dashboard
        is_valid = await paypal_service.verify_webhook_signature(
            webhook_id, 
            headers, 
            body.decode('utf-8')
        )
        
        if not is_valid:
            logger.warning("Invalid webhook signature")
            return JSONResponse(status_code=401, content={"error": "Invalid signature"})
        
        # Parse webhook event
        event = await request.json()
        event_type = event.get('event_type')
        
        logger.info(f"Received webhook: {event_type}")
        
        # Handle different event types
        if event_type == 'PAYMENT.CAPTURE.COMPLETED':
            # Payment completed successfully
            resource = event.get('resource', {})
            order_id = resource.get('supplementary_data', {}).get('related_ids', {}).get('order_id')
            capture_id = resource.get('id')
            
            if order_id:
                await DatabaseService.update_payment_order(order_id, {
                    "status": "COMPLETED",
                    "transaction_id": capture_id,
                    "webhook_verified": True,
                    "completed_at": datetime.utcnow().isoformat()
                })
                
                # Add credits (if not already added)
                order = await DatabaseService.get_payment_order(order_id)
                if order and order.get('status') != 'COMPLETED':
                    if order.get('client_id'):
                        await BillingService.add_credits(
                            order['client_id'],
                            order['amount'],
                            f"PayPal payment (webhook) - Order: {order_id}"
                        )
        
        elif event_type == 'PAYMENT.CAPTURE.DENIED':
            # Payment was denied
            resource = event.get('resource', {})
            order_id = resource.get('supplementary_data', {}).get('related_ids', {}).get('order_id')
            
            if order_id:
                await DatabaseService.update_payment_order(order_id, {
                    "status": "DENIED",
                    "failed_at": datetime.utcnow().isoformat()
                })
        
        elif event_type == 'PAYMENT.CAPTURE.REFUNDED':
            # Payment was refunded
            resource = event.get('resource', {})
            capture_id = resource.get('id')
            
            # Find order by transaction_id
            order = await DatabaseService.get_payment_order_by_transaction(capture_id)
            if order:
                await DatabaseService.update_payment_order(order['order_id'], {
                    "status": "REFUNDED",
                    "refunded_at": datetime.utcnow().isoformat()
                })
                
                # Deduct credits if needed
                if order.get('client_id'):
                    await BillingService.deduct_credits(
                        order['client_id'],
                        order['amount'],
                        f"PayPal refund - Order: {order['order_id']}"
                    )
        
        return JSONResponse(content={"status": "received"})
        
    except Exception as e:
        logger.error(f"Webhook processing error: {str(e)}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/order/{order_id}")
async def get_order_status(order_id: str):
    """Get status of a PayPal order"""
    try:
        # Get from database first
        order = await DatabaseService.get_payment_order(order_id)
        
        if order:
            return {
                "order_id": order_id,
                "status": order.get('status'),
                "amount": order.get('amount'),
                "currency": order.get('currency'),
                "transaction_id": order.get('transaction_id'),
                "created_at": order.get('created_at'),
                "completed_at": order.get('completed_at')
            }
        
        # Fall back to PayPal API
        paypal_order = await paypal_service.get_order_details(order_id)
        
        return {
            "order_id": order_id,
            "status": paypal_order.get('status'),
            "amount": paypal_order.get('purchase_units', [{}])[0].get('amount', {}).get('value'),
            "currency": paypal_order.get('purchase_units', [{}])[0].get('amount', {}).get('currency_code')
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/refund/{transaction_id}")
async def refund_payment(
    transaction_id: str,
    amount: Optional[float] = None,
    authorization_token: str = Header(..., alias="X-Admin-Token")
):
    """
    Refund a previous payment (Admin only)
    """
    try:
        # Verify admin token
        if authorization_token != "sk_admin_master_2026":
            raise HTTPException(status_code=403, detail="Admin access required")
        
        result = await paypal_service.refund_payment(transaction_id, amount)
        
        return {
            "success": True,
            "refund_id": result.get('id'),
            "status": result.get('status'),
            "amount": result.get('amount', {}).get('value')
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/packages")
async def get_pricing_packages():
    """Get available credit packages for purchase"""
    packages = [
        {
            "id": "starter",
            "name": "Starter Package",
            "credits": 1000,
            "price_usd": 50.00,
            "price_tzs": 125000,
            "savings": 0,
            "popular": False
        },
        {
            "id": "professional",
            "name": "Professional Package",
            "credits": 5000,
            "price_usd": 200.00,
            "price_tzs": 500000,
            "savings": 20,
            "popular": True
        },
        {
            "id": "business",
            "name": "Business Package",
            "credits": 12000,
            "price_usd": 450.00,
            "price_tzs": 1125000,
            "savings": 25,
            "popular": False
        },
        {
            "id": "enterprise",
            "name": "Enterprise Package",
            "credits": 30000,
            "price_usd": 1000.00,
            "price_tzs": 2500000,
            "savings": 30,
            "popular": False
        }
    ]
    return {"packages": packages}
