from fastapi import APIRouter, Response, HTTPException, Depends, Header
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST, Counter, Histogram, Gauge
import time
from typing import Dict

router = APIRouter()

# Prometheus metrics
REQUEST_COUNT = Counter(
    'bioshield_requests_total',
    'Total request count',
    ['method', 'endpoint', 'status']
)

REQUEST_LATENCY = Histogram(
    'bioshield_request_latency_seconds',
    'Request latency in seconds',
    ['method', 'endpoint'],
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0]
)

DEEPFAKE_COUNT = Counter(
    'bioshield_deepfake_detections_total',
    'Total deepfake detections',
    ['verdict', 'client_id']
)

ACTIVE_STREAMS = Gauge(
    'bioshield_active_streams',
    'Number of active audio streams'
)

BLOCKED_IPS = Gauge(
    'bioshield_blocked_ips_total',
    'Number of blocked IP addresses'
)

PROCESSING_LATENCY = Histogram(
    'bioshield_processing_latency_seconds',
    'Core engine processing latency',
    buckets=[0.0001, 0.0005, 0.001, 0.005, 0.01, 0.015]
)

@router.get("/metrics")
async def get_metrics():
    """Prometheus metrics endpoint for scraping."""
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )

@router.get("/metrics/streams")
async def get_stream_metrics():
    """Real-time stream metrics."""
    from services.deepfake_service import DeepfakeService
    
    return {
        "active_streams": DeepfakeService.get_active_stream_count(),
        "total_processed_today": await DeepfakeService.get_today_count(),
        "current_queue_depth": await DeepfakeService.get_queue_depth()
    }

@router.get("/metrics/performance")
async def get_performance_metrics():
    """Performance metrics for SLAs."""
    
    # This would query actual metrics from the system
    return {
        "p50_latency_ms": 2.3,
        "p95_latency_ms": 5.1,
        "p99_latency_ms": 8.7,
        "p999_latency_ms": 12.3,
        "throughput_rps": 8750,
        "uptime_percent": 99.999,
        "error_rate_percent": 0.0012
    }
