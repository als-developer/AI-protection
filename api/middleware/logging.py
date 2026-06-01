from fastapi import Request
import time
import logging
import json
from datetime import datetime

logger = logging.getLogger("bioshield.api")

class LoggingMiddleware:
    """Request/response logging middleware."""
    
    def __init__(self, app):
        self.app = app
    
    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        
        start_time = time.time()
        
        # Get request details
        method = scope.get("method", "UNKNOWN")
        path = scope.get("path", "/")
        
        # Get client IP
        headers = dict(scope.get("headers", []))
        client_ip = None
        for key, value in headers.items():
            if key.decode().lower() == "x-forwarded-for":
                client_ip = value.decode().split(",")[0].strip()
                break
            elif key.decode().lower() == "x-real-ip":
                client_ip = value.decode()
                break
        
        if not client_ip:
            client_ip = scope.get("client", (None, 0))[0]
        
        # Log request start
        logger.info(f"REQUEST: {method} {path} from {client_ip}")
        
        # Capture response status
        response_status = [200]
        
        async def send_wrapper(message):
            if message["type"] == "http.response.start":
                response_status[0] = message["status"]
            await send(message)
        
        try:
            await self.app(scope, receive, send_wrapper)
        except Exception as e:
            logger.error(f"ERROR: {method} {path} - {str(e)}")
            raise
        finally:
            duration_ms = (time.time() - start_time) * 1000
            logger.info(
                f"RESPONSE: {method} {path} -> {response_status[0]} "
                f"in {duration_ms:.2f}ms from {client_ip}"
            )
