from fastapi import APIRouter, HTTPException, Depends, Header
from fastapi.responses import JSONResponse
from typing import Optional, List
import asyncio
import uuid
import random
from models.payloads import AudioStreamPayload, MultiChannelPayload
from models.responses import AuditResponse
from services.deepfake_service import DeepfakeService
from services.cache_service import CacheService
from services.billing_service import BillingService
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

@router.post("/audit-voice", response_model=AuditResponse)
async def audit_voice_stream(
    payload: AudioStreamPayload,
    authorization_token: str = Header(..., alias="X-BioShield-Token")
):
    """Analyze live voice stream for deepfake detection"""
    
    # Validate payload
    if not payload.frequency_amplitude_deltas or len(payload.frequency_amplitude_deltas) < 10:
        raise HTTPException(status_code=400, detail="Invalid frequency data")
    
    # Check cache for recent analysis
    cache_key = f"voice:{payload.channel_identity}"
    cached_result = await CacheService.get(cache_key)
    if cached_result:
        return JSONResponse(content=cached_result)
    
    # Perform deepfake analysis
    result = await DeepfakeService.analyze_stream(
        payload.frequency_amplitude_deltas,
        payload.bank_cluster_token
    )
    
    # Deduct billing credit
    await BillingService.deduct_credit(authorization_token, 0.10)  # $0.10 per scan
    
    # Cache result for 60 seconds
    await CacheService.set(cache_key, result, ttl=60)
    
    # Log to database
    await DeepfakeService.log_result(result, payload)
    
    return AuditResponse(**result)

@router.post("/audit-multi-channel")
async def audit_multi_channel(
    payload: MultiChannelPayload,
    authorization_token: str = Header(..., alias="X-BioShield-Token")
):
    """Analyze multi-channel audio stream (enhanced detection)"""
    
    if not payload.channels or len(payload.channels) < 2:
        raise HTTPException(status_code=400, detail="At least 2 channels required")
    
    results = []
    for channel in payload.channels:
        result = await DeepfakeService.analyze_stream(
            channel.frequency_deltas,
            payload.bank_cluster_token
        )
        results.append(result)
    
    # Ensemble voting
    deepfake_count = sum(1 for r in results if r["evaluation_verdict"] == "CRITICAL_SUSPECTED_DEEPFAKE")
    is_deepfake = deepfake_count > len(results) / 2
    
    return {
        "security_token": f"multi_{uuid.uuid4().hex[:12]}",
        "evaluation_verdict": "CRITICAL_SUSPECTED_DEEPFAKE" if is_deepfake else "VERIFIED_HUMAN_AUTHENTIC",
        "fraud_risk_index": f"{sum(float(r['fraud_risk_index'].replace('%','')) for r in results) / len(results):.2f}%",
        "firewall_action": "TERMINATE_VOICE_CALL_BLOCK_TRANSACTION" if is_deepfake else "ALLOW_TRANSACTION_PROCEED",
        "channel_results": results
    }
