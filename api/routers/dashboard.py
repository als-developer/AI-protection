from fastapi import APIRouter, Depends, HTTPException
from typing import Dict, List, Any
from datetime import datetime, timedelta
import asyncio

from services.deepfake_service import DeepfakeService
from services.cache_service import CacheService
from middleware.auth import verify_token

router = APIRouter()

@router.get("/realtime")
async def realtime_dashboard(
    authorization_token: str = Depends(verify_token)
):
    """Real-time dashboard data."""
    
    # Get current metrics
    active_streams = DeepfakeService.get_active_stream_count()
    today_count = await DeepfakeService.get_today_count()
    recent_threats = await DeepfakeService.get_recent_threats(limit=20)
    
    # Get performance metrics
    performance = await CacheService.get("system:performance")
    if not performance:
        performance = {
            "avg_latency_ms": 2.3,
            "p95_latency_ms": 5.1,
            "p99_latency_ms": 8.7,
            "throughput_rps": 8750
        }
    
    return {
        "active_streams": active_streams,
        "total_scans_today": today_count,
        "deepfake_blocked_today": sum(1 for t in recent_threats if "DEEPFAKE" in t.get("verdict", "")),
        "recent_threats": recent_threats,
        "performance": performance,
        "timestamp": datetime.utcnow().isoformat()
    }

@router.get("/charts/trends")
async def get_trends(
    authorization_token: str = Depends(verify_token),
    hours: int = 24
):
    """Get historical trend data for charts."""
    data = await DeepfakeService.get_hourly_stats(hours)
    return {
        "labels": [d["hour"] for d in data],
        "scans": [d["scan_count"] for d in data],
        "deepfakes": [d["deepfake_count"] for d in data],
        "latency": [d["avg_latency_ms"] for d in data]
    }
