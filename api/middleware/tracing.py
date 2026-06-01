from fastapi import Request
import uuid
import time

class RequestTracingMiddleware:
    """Middleware for request tracing and correlation IDs."""
    
    def __init__(self, app):
        self.app = app
    
    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        
        # Generate request ID
        request_id = str(uuid.uuid4())
        
        # Record start time
        start_time = time.time()
        
        # Store in scope for downstream use
        scope["request_id"] = request_id
        
        async def send_wrapper(message):
            if message["type"] == "http.response.start":
                message["headers"].append(
                    (b"x-request-id", request_id.encode())
                )
            await send(message)
        
        await self.app(scope, receive, send_wrapper)
        
        # Log request completion
        duration = (time.time() - start_time) * 1000
        print(f"Request {request_id} completed in {duration:.2f}ms")
