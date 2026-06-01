from fastapi import APIRouter, Depends
from typing import Dict, Any
import asyncio
import psutil
import platform
import time
from datetime import datetime

from services.cache_service import CacheService
from services.deepfake_service import DeepfakeService
from services.billing_service import BillingService

router = APIRouter()

@router.get("/health")
async def health_check() -> Dict[str, Any]:
    """Comprehensive health check for all system components."""
    
    start_time = time.perf_counter()
    
    # Check all components in parallel
    redis_task = CacheService.ping()
    engine_task = asyncio.to_thread(DeepfakeService.check_engine)
    billing_task = asyncio.to_thread(BillingService.check_health)
    
    redis_healthy, engine_healthy, billing_healthy = await asyncio.gather(
        redis_task, engine_task, billing_task, return_exceptions=True
    )
    
    redis_healthy = redis_healthy is True
    engine_healthy = engine_healthy is True
    billing_healthy = billing_healthy is True
    
    # System metrics
    cpu_percent = psutil.cpu_percent(interval=0.1)
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage('/')
    
    # Determine overall status
    all_healthy = redis_healthy and engine_healthy and billing_healthy
    status = "healthy" if all_healthy else "degraded"
    
    elapsed_ms = (time.perf_counter() - start_time) * 1000
    
    return {
        "status": status,
        "timestamp": datetime.utcnow().isoformat(),
        "latency_ms": round(elapsed_ms, 2),
        "components": {
            "redis": "up" if redis_healthy else "down",
            "cpp_engine": "up" if engine_healthy else "down",
            "billing": "up" if billing_healthy else "down",
        },
        "system": {
            "hostname": platform.node(),
            "platform": platform.platform(),
            "cpu_cores": psutil.cpu_count(),
            "cpu_usage_percent": cpu_percent,
            "memory_total_gb": round(memory.total / (1024**3), 2),
            "memory_used_percent": memory.percent,
            "memory_available_gb": round(memory.available / (1024**3), 2),
            "disk_total_gb": round(disk.total / (1024**3), 2),
            "disk_used_percent": disk.percent,
            "disk_free_gb": round(disk.free / (1024**3), 2),
            "uptime_seconds": time.time() - psutil.boot_time()
        }
    }

@router.get("/health/readiness")
async def readiness_check():
    """Kubernetes readiness probe."""
    engine_ready = DeepfakeService.is_ready()
    cache_ready = await CacheService.is_ready()
    
    return {
        "ready": engine_ready and cache_ready,
        "components": {
            "engine": engine_ready,
            "cache": cache_ready
        }
    }

@router.get("/health/liveness")
async def liveness_check():
    """Kubernetes liveness probe."""
    return {
        "alive": True,
        "timestamp": datetime.utcnow().isoformat()
    }

@router.get("/health/metrics")
async def detailed_metrics():
    """Detailed system metrics for monitoring."""
    
    # Get Prometheus-style metrics
    process = psutil.Process()
    
    return {
        "process": {
            "pid": process.pid,
            "cpu_percent": process.cpu_percent(),
            "memory_rss_mb": round(process.memory_info().rss / (1024**2), 2),
            "memory_vms_mb": round(process.memory_info().vms / (1024**2), 2),
            "threads": process.num_threads(),
            "open_files": len(process.open_files()),
            "connections": len(process.connections()),
        },
        "system": {
            "load_avg_1m": psutil.getloadavg()[0],
            "load_avg_5m": psutil.getloadavg()[1],
            "load_avg_15m": psutil.getloadavg()[2],
            "network_bytes_sent": psutil.net_io_counters().bytes_sent,
            "network_bytes_recv": psutil.net_io_counters().bytes_recv,
        }
    }
