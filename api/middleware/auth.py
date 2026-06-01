from fastapi import Request, HTTPException, Depends
from fastapi.security import APIKeyHeader
from typing import Optional, Dict
import hashlib
import hmac
import time
from functools import wraps

from services.billing_service import BillingService

api_key_header = APIKeyHeader(name="X-BioShield-Token", auto_error=False)

async def verify_token(api_key: str = Depends(api_key_header)) -> str:
    """Verify API token and return client ID."""
    if not api_key:
        raise HTTPException(status_code=401, detail="Missing API key")
    
    # Check if key is valid and get client
    client_id = await BillingService.validate_api_key(api_key)
    if not client_id:
        raise HTTPException(status_code=401, detail="Invalid API key")
    
    return client_id

async def get_client_info(request: Request) -> Dict:
    """Extract client information from request."""
    return {
        "ip": request.client.host,
        "user_agent": request.headers.get("user-agent", "unknown"),
        "timestamp": time.time(),
        "method": request.method,
        "path": request.url.path
    }

class AuthMiddleware:
    """Authentication middleware for all routes."""
    
    def __init__(self, app):
        self.app = app
    
    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        
        # Skip auth for health endpoints
        path = scope.get("path", "")
        if path in ["/v1/health", "/v1/health/liveness", "/v1/health/readiness", "/metrics"]:
            await self.app(scope, receive, send)
            return
        
        # Extract headers
        headers = dict(scope.get("headers", []))
        api_key = None
        for key, value in headers.items():
            if key.decode().lower() == "x-bioshield-token":
                api_key = value.decode()
                break
        
        if not api_key:
            await self.send_error_response(send, 401, "Missing API key")
            return
        
        # Validate key
        client_id = await BillingService.validate_api_key(api_key)
        if not client_id:
            await self.send_error_response(send, 401, "Invalid API key")
            return
        
        # Add client_id to scope for downstream use
        scope["client_id"] = client_id
        await self.app(scope, receive, send)
    
    async def send_error_response(self, send, status_code: int, detail: str):
        response_body = f'{{"detail":"{detail}"}}'.encode()
        await send({
            "type": "http.response.start",
            "status": status_code,
            "headers": [
                (b"content-type", b"application/json"),
                (b"content-length", str(len(response_body)).encode())
            ]
        })
        await send({
            "type": "http.response.body",
            "body": response_body
        })
