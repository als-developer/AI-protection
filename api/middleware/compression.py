from fastapi import Request, Response
from fastapi.responses import JSONResponse
import gzip
import json

class CompressionMiddleware:
    """Automatic response compression middleware."""
    
    def __init__(self, app, minimum_size=1000):
        self.app = app
        self.minimum_size = minimum_size
    
    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        
        # Check if client accepts gzip
        headers = dict(scope.get("headers", []))
        accept_encoding = None
        for key, value in headers.items():
            if key.decode().lower() == "accept-encoding":
                accept_encoding = value.decode()
                break
        
        if not accept_encoding or "gzip" not in accept_encoding:
            await self.app(scope, receive, send)
            return
        
        # Capture response
        response_body = []
        
        async def send_wrapper(message):
            if message["type"] == "http.response.body":
                if len(message.get("body", b"")) >= self.minimum_size:
                    # Compress response
                    compressed = gzip.compress(message["body"])
                    message["body"] = compressed
                    message["headers"].append(
                        (b"content-encoding", b"gzip")
                    )
            await send(message)
        
        await self.app(scope, receive, send_wrapper)
