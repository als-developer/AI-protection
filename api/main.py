import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
import logging
from routers import voice_audit, health, metrics, admin, billing
from middleware.rate_limiter import RateLimitMiddleware
from middleware.auth import AuthMiddleware
from middleware.logging import LoggingMiddleware
from services.cache_service import CacheService
from services.notification_service import NotificationService

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Starting Sovereign Bio-Shield API Gateway...")
    await CacheService.initialize()
    await NotificationService.initialize()
    yield
    # Shutdown
    logger.info("Shutting down API Gateway...")
    await CacheService.close()
    await NotificationService.close()

app = FastAPI(
    title="Sovereign Bio-Shield Ultimate API",
    description="Enterprise-grade deepfake detection and voice cloning prevention",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json"
)

# Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=[],
    allow_credentials=True,
    allow_methods=["POST", "GET"],
    allow_headers=["X-BioShield-Token", "Content-Type"],
)
app.add_middleware(TrustedHostMiddleware, allowed_hosts=["*"])
app.add_middleware(RateLimitMiddleware)
app.add_middleware(AuthMiddleware)
app.add_middleware(LoggingMiddleware)

# Routers
app.include_router(voice_audit.router, prefix="/v1", tags=["Voice Audit"])
app.include_router(health.router, prefix="/v1", tags=["Health"])
app.include_router(metrics.router, prefix="/v1", tags=["Metrics"])
app.include_router(admin.router, prefix="/v1/admin", tags=["Admin"])
app.include_router(billing.router, prefix="/v1/billing", tags=["Billing"])

@app.get("/")
async def root():
    return {
        "service": "Sovereign Bio-Shield Ultimate",
        "version": "1.0.0",
        "status": "operational"
    }
