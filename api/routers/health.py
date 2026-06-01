from fastapi import APIRouter, Depends
from typing import Dict, Any
import psutil
import asyncio
from services.cache_service import CacheService
from services.deepfake_service import DeepfakeService

router = APIRouter()

@router.get("/health")
async def health_check() -> Dict[str, Any]:
    """Comprehensive health check endpoint"""
    
    # Check Redis
    redis_healthy = await CacheService.ping()
    
    # Check C++ engine
    engine_healthy = DeepfakeService.check_engine()
    
    # System metrics
    cpu_percent = psutil.cpu_percent(interval=0.1)
    memory_percent = psutil.virtual_memory().percent
    
    status = "healthy" if (redis_healthy and engine_healthy) else "degraded"
    
    return {
        "status": status,
        "timestamp": asyncio.get_event_loop().time(),
        "components": {
            "redis": "up" if redis_healthy else "down",
            "engine": "up" if engine_healthy else "down",
        },
        "system": {
            "cpu_usage_percent": cpu_percent,
            "memory_usage_percent": memory_percent
        }
    }

@router.get("/readiness")
async def readiness_check():
    """Kubernetes readiness probe"""
    engine_ready = DeepfakeService.is_ready()
    return {"ready": engine_ready}

@router.get("/liveness")
async def liveness_check():
    """Kubernetes liveness probe"""
    return {"alive": True}
