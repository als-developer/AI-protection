from fastapi import APIRouter, HTTPException, Depends, Header, BackgroundTasks
from fastapi.responses import JSONResponse
from typing import Optional, List, Dict, Any
import uuid
import asyncio
import logging

from models.payloads import AudioStreamPayload, MultiChannelPayload, BatchPayload
from models.responses import AuditResponse, BatchAuditResponse
from services.deepfake_service import DeepfakeService
from services.cache_service import CacheService
from services.billing_service import BillingService
from middleware.auth import verify_token, get_client_info

router = APIRouter()
logger = logging.getLogger(__name__)

@router.post("/audit-voice", response_model=AuditResponse)
async def audit_voice_stream(
    payload: AudioStreamPayload,
    background_tasks: BackgroundTasks,
    authorization_token: str = Header(..., alias="X-BioShield-Token"),
    client_info: Dict = Depends(get_client_info)
):
    """
    Analyze a live voice stream for deepfake detection.
    
    This endpoint processes frequency amplitude deltas from an audio stream
    and returns a fraud risk assessment in under 15 milliseconds.
    
    - **bank_cluster_token**: Unique identifier for the banking node
    - **channel_identity**: SIP trunk or channel identifier
    - **frequency_amplitude_deltas**: Array of frequency measurements
    - **metadata**: Optional additional context
    """
    
    # Validate payload
    if not payload.frequency_amplitude_deltas:
        raise HTTPException(status_code=400, detail="Empty frequency data array")
    
    if len(payload.frequency_amplitude_deltas) < 10:
        raise HTTPException(status_code=400, detail="Insufficient samples (minimum 10)")
    
    # Check cache for recent analysis (prevent duplicate processing)
    cache_key = f"voice:{payload.channel_identity}:{hash(tuple(payload.frequency_amplitude_deltas[-10:]))}"
    cached_result = await CacheService.get(cache_key)
    if cached_result:
        logger.info(f"Cache hit for channel {payload.channel_identity}")
        return JSONResponse(content=cached_result)
    
    # Perform deepfake analysis
    result = await DeepfakeService.analyze_stream(
        frequency_deltas=payload.frequency_amplitude_deltas,
        client_id=payload.bank_cluster_token,
        channel_id=payload.channel_identity,
        metadata=payload.metadata
    )
    
    # Deduct billing credit in background
    background_tasks.add_task(
        BillingService.deduct_credit,
        api_key=authorization_token,
        amount=0.10,  # $0.10 per scan
        scan_type="voice_audit"
    )
    
    # Cache result for 60 seconds
    await CacheService.set(cache_key, result, ttl=60)
    
    # Log for audit trail
    background_tasks.add_task(
        DeepfakeService.log_result,
        result=result,
        payload=payload,
        client_info=client_info
    )
    
    return AuditResponse(**result)

@router.post("/audit-multi-channel")
async def audit_multi_channel(
    payload: MultiChannelPayload,
    background_tasks: BackgroundTasks,
    authorization_token: str = Header(..., alias="X-BioShield-Token"),
    client_info: Dict = Depends(get_client_info)
):
    """
    Analyze multi-channel audio stream with ensemble voting.
    
    This endpoint processes multiple audio channels simultaneously and uses
    ensemble voting to determine if a deepfake is present.
    """
    
    if not payload.channels or len(payload.channels) < 2:
        raise HTTPException(status_code=400, detail="At least 2 channels required")
    
    # Analyze each channel in parallel
    tasks = []
    for channel in payload.channels:
        task = DeepfakeService.analyze_stream(
            frequency_deltas=channel.frequency_deltas,
            client_id=payload.bank_cluster_token,
            channel_id=f"{payload.channel_identity}_ch{channel.channel_index}",
            metadata=payload.metadata
        )
        tasks.append(task)
    
    channel_results = await asyncio.gather(*tasks)
    
    # Ensemble voting
    deepfake_count = sum(
        1 for r in channel_results 
        if r["evaluation_verdict"] == "CRITICAL_SUSPECTED_DEEPFAKE"
    )
    suspicious_count = sum(
        1 for r in channel_results 
        if r["evaluation_verdict"] == "SUSPICIOUS_PATTERN"
    )
    
    is_deepfake = deepfake_count > len(payload.channels) / 2
    is_suspicious = suspicious_count > len(payload.channels) / 3
    
    if is_deepfake:
        verdict = "CRITICAL_SUSPECTED_DEEPFAKE"
        action = "TERMINATE_VOICE_CALL_BLOCK_TRANSACTION"
        fraud_risk = sum(float(r["fraud_risk_index"].replace('%','')) for r in channel_results) / len(channel_results)
    elif is_suspicious:
        verdict = "SUSPICIOUS_PATTERN"
        action = "ESCALATE_MANUAL_REVIEW"
        fraud_risk = 45.0
    else:
        verdict = "VERIFIED_HUMAN_AUTHENTIC"
        action = "ALLOW_TRANSACTION_PROCEED"
        fraud_risk = 2.5
    
    # Deduct billing (multi-channel costs more)
    background_tasks.add_task(
        BillingService.deduct_credit,
        api_key=authorization_token,
        amount=0.25,  # $0.25 for multi-channel
        scan_type="multi_channel"
    )
    
    result = {
        "security_token": f"multi_{uuid.uuid4().hex[:12]}",
        "evaluation_verdict": verdict,
        "fraud_risk_index": f"{fraud_risk:.2f}%",
        "firewall_action": action,
        "channel_results": channel_results,
        "ensemble_votes": {
            "total_channels": len(payload.channels),
            "deepfake_votes": deepfake_count,
            "suspicious_votes": suspicious_count,
            "threshold": len(payload.channels) / 2
        }
    }
    
    background_tasks.add_task(
        DeepfakeService.log_result,
        result=result,
        payload=payload,
        client_info=client_info
    )
    
    return result

@router.post("/audit-batch")
async def audit_batch(
    payload: BatchPayload,
    background_tasks: BackgroundTasks,
    authorization_token: str = Header(..., alias="X-BioShield-Token")
):
    """
    Batch process multiple voice streams for high-volume scenarios.
    """
    
    if not payload.streams or len(payload.streams) > 100:
        raise HTTPException(status_code=400, detail="Batch size must be between 1 and 100")
    
    tasks = []
    for stream in payload.streams:
        task = DeepfakeService.analyze_stream(
            frequency_deltas=stream.frequency_deltas,
            client_id=stream.bank_cluster_token,
            channel_id=stream.channel_identity,
            metadata=stream.metadata
        )
        tasks.append(task)
    
    results = await asyncio.gather(*tasks)
    
    # Calculate batch pricing
    total_cost = len(payload.streams) * 0.08  # Bulk discount
    
    background_tasks.add_task(
        BillingService.deduct_credit,
        api_key=authorization_token,
        amount=total_cost,
        scan_type="batch"
    )
    
    return {
        "batch_id": f"batch_{uuid.uuid4().hex[:12]}",
        "total_streams": len(payload.streams),
        "results": results,
        "total_cost": f"${total_cost:.2f}"
    }

@router.get("/stats/{client_id}")
async def get_client_stats(
    client_id: str,
    authorization_token: str = Header(..., alias="X-BioShield-Token")
):
    """
    Get statistics for a specific client.
    """
    stats = await DeepfakeService.get_client_stats(client_id)
    if not stats:
        raise HTTPException(status_code=404, detail="Client not found")
    return stats
