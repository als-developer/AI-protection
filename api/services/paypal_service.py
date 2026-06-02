"""
PayPal Integration Service for BioShield Ultimate
Handles payment processing, webhooks, and subscription management
"""

import os
import json
import hashlib
import hmac
from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta
import httpx
from dataclasses import dataclass
from enum import Enum

# PayPal API Configuration
PAYPAL_CLIENT_ID = "AdYZjwcxNYqpWCglcoqt4cv0ESkJ-G3RChAAuuET"
PAYPAL_SECRET_KEY = "EAecZX7x2XtI61BA-b72HxH0A4xInOX6rnolchtua"
PAYPAL_API_KEY = "8coHKYs478Md3iPe6WTBR9GOeBn1N97T2SoQJzNS"

# Environment: sandbox for testing, production for live
PAYPAL_ENV = os.getenv("PAYPAL_ENV", "sandbox")
PAYPAL_BASE_URL = "https://api-m.sandbox.paypal.com" if PAYPAL_ENV == "sandbox" else "https://api-m.paypal.com"

class PaymentIntent(str, Enum):
    CAPTURE = "CAPTURE"
    AUTHORIZE = "AUTHORIZE"

class PaymentStatus(str, Enum):
    CREATED = "CREATED"
    APPROVED = "APPROVED"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"
    REFUNDED = "REFUNDED"

@dataclass
class PaymentOrder:
    order_id: str
    amount: float
    currency: str
    status: PaymentStatus
    paypal_order_id: Optional[str] = None
    transaction_id: Optional[str] = None
    created_at: datetime = None

class PayPalService:
    """Main PayPal integration service"""
    
    def __init__(self):
        self.client_id = PAYPAL_CLIENT_ID
        self.secret_key = PAYPAL_SECRET_KEY
        self.base_url = PAYPAL_BASE_URL
        self._access_token = None
        self._token_expiry = None
    
    async def get_access_token(self) -> str:
        """Get PayPal OAuth2 access token"""
        if self._access_token and self._token_expiry and datetime.now() < self._token_expiry:
            return self._access_token
        
        auth_string = f"{self.client_id}:{self.secret_key}"
        auth_bytes = auth_string.encode('ascii')
        auth_b64 = __import__('base64').b64encode(auth_bytes).decode('ascii')
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/v1/oauth2/token",
                headers={
                    "Authorization": f"Basic {auth_b64}",
                    "Content-Type": "application/x-www-form-urlencoded"
                },
                data="grant_type=client_credentials"
            )
            
            if response.status_code != 200:
                raise Exception(f"PayPal auth failed: {response.text}")
            
            data = response.json()
            self._access_token = data['access_token']
            expires_in = data.get('expires_in', 32400)
            self._token_expiry = datetime.now() + timedelta(seconds=expires_in - 60)
            
            return self._access_token
    
    async def create_order(
        self, 
        amount: float, 
        currency: str = "USD",
        description: str = "BioShield API Credits",
        client_id: str = None,
        return_url: str = None,
        cancel_url: str = None
    ) -> Dict[str, Any]:
        """Create a PayPal order for payment"""
        
        token = await self.get_access_token()
        
        order_data = {
            "intent": "CAPTURE",
            "purchase_units": [
                {
                    "amount": {
                        "currency_code": currency,
                        "value": f"{amount:.2f}"
                    },
                    "description": description,
                    "custom_id": client_id or "anonymous"
                }
            ],
            "application_context": {
                "brand_name": "BioShield Ultimate",
                "landing_page": "LOGIN",
                "user_action": "PAY_NOW",
                "return_url": return_url or "https://api.bioshield/v1/paypal/success",
                "cancel_url": cancel_url or "https://api.bioshield/v1/paypal/cancel"
            }
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/v2/checkout/orders",
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json"
                },
                json=order_data
            )
            
            if response.status_code != 201:
                raise Exception(f"Failed to create order: {response.text}")
            
            order = response.json()
            
            # Extract approval URL
            approval_url = None
            for link in order.get('links', []):
                if link.get('rel') == 'approve':
                    approval_url = link.get('href')
                    break
            
            return {
                "order_id": order['id'],
                "status": order['status'],
                "approval_url": approval_url,
                "amount": amount,
                "currency": currency
            }
    
    async def capture_order(self, order_id: str) -> Dict[str, Any]:
        """Capture a PayPal order after customer approval"""
        
        token = await self.get_access_token()
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/v2/checkout/orders/{order_id}/capture",
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json"
                }
            )
            
            if response.status_code != 201:
                raise Exception(f"Failed to capture order: {response.text}")
            
            capture = response.json()
            
            # Extract transaction details
            transaction_id = None
            if capture.get('purchase_units'):
                for unit in capture['purchase_units']:
                    if unit.get('payments', {}).get('captures'):
                        for cap in unit['payments']['captures']:
                            transaction_id = cap.get('id')
                            break
            
            return {
                "status": capture['status'],
                "transaction_id": transaction_id,
                "order_id": order_id,
                "capture_data": capture
            }
    
    async def refund_payment(self, capture_id: str, amount: float = None) -> Dict[str, Any]:
        """Refund a captured payment"""
        
        token = await self.get_access_token()
        
        refund_data = {}
        if amount:
            refund_data = {
                "amount": {
                    "value": f"{amount:.2f}",
                    "currency_code": "USD"
                }
            }
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/v2/payments/captures/{capture_id}/refund",
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json"
                },
                json=refund_data if refund_data else {}
            )
            
            if response.status_code not in [201, 200]:
                raise Exception(f"Failed to refund: {response.text}")
            
            return response.json()
    
    async def get_order_details(self, order_id: str) -> Dict[str, Any]:
        """Get details of a PayPal order"""
        
        token = await self.get_access_token()
        
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/v2/checkout/orders/{order_id}",
                headers={"Authorization": f"Bearer {token}"}
            )
            
            if response.status_code != 200:
                raise Exception(f"Failed to get order: {response.text}")
            
            return response.json()
    
    async def verify_webhook_signature(
        self, 
        webhook_id: str, 
        headers: Dict, 
        body: str
    ) -> bool:
        """Verify PayPal webhook signature for security"""
        
        token = await self.get_access_token()
        
        verification_data = {
            "auth_algo": headers.get('paypal-auth-algo'),
            "cert_url": headers.get('paypal-cert-url'),
            "transmission_id": headers.get('paypal-transmission-id'),
            "transmission_sig": headers.get('paypal-transmission-sig'),
            "transmission_time": headers.get('paypal-transmission-time'),
            "webhook_id": webhook_id,
            "webhook_event": json.loads(body) if isinstance(body, str) else body
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/v1/notifications/verify-webhook-signature",
                headers={"Authorization": f"Bearer {token}"},
                json=verification_data
            )
            
            if response.status_code != 200:
                return False
            
            result = response.json()
            return result.get('verification_status') == 'SUCCESS'


# Singleton instance
paypal_service = PayPalService()
