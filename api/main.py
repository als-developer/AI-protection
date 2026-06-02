import asyncio
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.middleware.gzip import GZipMiddleware
import uvicorn

from routers import voice_audit, health, metrics, admin, billing, dashboard
from middleware.rate_limiter import RateLimitMiddleware
from middleware.auth import AuthMiddleware
from middleware.logging import LoggingMiddleware
from middleware.compression import CompressionMiddleware
from services.cache_service import CacheService
from services.deepfake_service import DeepfakeService
from services.billing_service import BillingService
from services.notification_service import NotificationService
from config import settings

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/bioshield/api.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("🚀 Starting Sovereign Bio-Shield API Gateway v1.0...")
    
    # Initialize services
    await CacheService.initialize()
    await DeepfakeService.initialize()
    await BillingService.initialize()
    await NotificationService.initialize()
    
    logger.info("✅ All services initialized successfully")
    yield
    
    # Shutdown
    logger.info("🛑 Shutting down API Gateway...")
    await CacheService.close()
    await DeepfakeService.close()
    await BillingService.close()
    await NotificationService.close()
    logger.info("✅ Shutdown complete")

# Create FastAPI app
app = FastAPI(
    title="Sovereign Bio-Shield Ultimate API",
    description="""
    ## Enterprise Deepfake Detection & Voice Cloning Prevention Platform
    
    This API provides real-time deepfake detection for audio streams, multi-channel voice analysis,
    and integration with banking security systems.
    
    ### Features
    - Sub-millisecond voice stream analysis
    - Multi-channel audio processing
    - Enterprise-grade rate limiting
    - Real-time fraud detection
    - Comprehensive audit logging
    """,
    version="3.0.0",
    lifespan=lifespan,
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json",
    servers=[
        {"url": "https://api.bioshield.secure-bank.internal", "description": "Production"},
        {"url": "https://staging-api.bioshield.secure-bank.internal", "description": "Staging"},
        {"url": "http://localhost:8000", "description": "Local Development"}
    ]
)

# Add middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["X-BioShield-Token", "Content-Type", "Authorization"],
    max_age=3600,
)
app.add_middleware(TrustedHostMiddleware, allowed_hosts=settings.ALLOWED_HOSTS)
app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(RateLimitMiddleware)
app.add_middleware(AuthMiddleware)
app.add_middleware(LoggingMiddleware)
app.add_middleware(CompressionMiddleware)

# Include routers
app.include_router(voice_audit.router, prefix="/v1", tags=["Voice Audit"])
app.include_router(health.router, prefix="/v1", tags=["Health"])
app.include_router(metrics.router, prefix="/v1", tags=["Metrics"])
app.include_router(admin.router, prefix="/v1/admin", tags=["Admin"])
app.include_router(billing.router, prefix="/v1/billing", tags=["Billing"])
app.include_router(dashboard.router, prefix="/v1/dashboard", tags=["Dashboard"])

@app.get("/")
async def root():
    return {
        "service": "Sovereign Bio-Shield Ultimate",
        "version": "3.0.0",
        "status": "operational",
        "documentation": "/api/docs",
        "health": "/v1/health"
    }

@app.get("/api/health")
async def api_health():
    return {"status": "alive", "timestamp": asyncio.get_event_loop().time()}

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG,
        workers=settings.WORKERS_COUNT,
        log_level="info"
    )


# Add this line to include PayPal router
from routers import voice_audit, health, metrics, admin, billing, dashboard, paypal

# Add this after other router inclusions
app.include_router(paypal.router, prefix="/v1", tags=["PayPal Payments"])
