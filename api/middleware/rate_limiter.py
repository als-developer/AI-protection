from fastapi import Request, HTTPException
from typing import Dict, Tuple
import time
from collections import defaultdict
import asyncio

class RateLimiter:
    """Token bucket rate limiter implementation."""
    
    def __init__(self, capacity: int = 10000, refill_rate: float = 10000.0 / 60.0):
        self.capacity = capacity
        self.refill_rate = refill_rate
        self.tokens = defaultdict(float)
        self.last_refill = defaultdict(float)
    
    def consume(self, key: str, tokens: int = 1) -> Tuple[bool, float]:
        """Consume tokens from the bucket. Returns (allowed, wait_time)."""
        now = time.time()
        
        # Refill tokens
        if key not in self.tokens:
            self.tokens[key] = self.capacity
            self.last_refill[key] = now
        else:
            elapsed = now - self.last_refill[key]
            refill = elapsed * self.refill_rate
            self.tokens[key] = min(self.capacity, self.tokens[key] + refill)
            self.last_refill[key] = now
        
        # Check if enough tokens
        if self.tokens[key] >= tokens:
            self.tokens[key] -= tokens
            return True, 0
        else:
            wait_time = (tokens - self.tokens[key]) / self.refill_rate
            return False, wait_time

class RateLimitMiddleware:
    """Rate limiting middleware using token bucket algorithm."""
    
    def __init__(self, app, default_rate: int = 10000, default_burst: int = 15000):
        self.app = app
        self.default_rate = default_rate
        self.default_burst = default_burst
        self.limiters = {}
    
    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        
        path = scope.get("path", "")
        
        # Skip rate limiting for health endpoints
        if path in ["/v1/health", "/v1/health/liveness", "/v1/health/readiness", "/metrics"]:
            await self.app(scope, receive, send)
            return
        
        # Get client identifier (API key or IP)
        headers = dict(scope.get("headers", []))
        api_key = None
        for key, value in headers.items():
            if key.decode().lower() == "x-bioshield-token":
                api_key = value.decode()
                break
        
        client_key = api_key or scope.get("client", {}).get("host", "unknown")
        
        # Get or create rate limiter for this client
        if client_key not in self.limiters:
            self.limiters[client_key] = RateLimiter(
                capacity=self.default_burst,
                refill_rate=self.default_rate / 60.0
            )
        
        limiter = self.limiters[client_key]
        allowed, wait_time = limiter.consume(client_key, 1)
        
        if not allowed:
            await self.send_rate_limit_response(send, wait_time)
            return
        
        await self.app(scope, receive, send)
    
    async def send_rate_limit_response(self, send, wait_time: float):
        response_body = f'{{"detail":"Rate limit exceeded. Try again in {wait_time:.1f} seconds."}}'.encode()
        await send({
            "type": "http.response.start",
            "status": 429,
            "headers": [
                (b"content-type", b"application/json"),
                (b"retry-after", str(int(wait_time)).encode()),
                (b"content-length", str(len(response_body)).encode())
            ]
        })
        await send({
            "type": "http.response.body",
            "body": response_body
        })
