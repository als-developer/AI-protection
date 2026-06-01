from pydantic import BaseModel
from typing import Optional, Dict, Any, List
from datetime import datetime

class AuditResponse(BaseModel):
    """Response from voice audit endpoint."""
    
    security_token: str
    evaluation_verdict: str
    fraud_risk_index: str
    firewall_action: str
    metadata: Optional[Dict[str, Any]] = None
    timestamp: Optional[datetime] = None
    
    class Config:
        json_schema_extra = {
            "example": {
                "security_token": "aud_prem_a1b2c3d4e5f6",
                "evaluation_verdict": "VERIFIED_HUMAN_AUTHENTIC",
                "fraud_risk_index": "2.35%",
                "firewall_action": "ALLOW_TRANSACTION_PROCEED"
            }
        }

class ChannelResult(BaseModel):
    """Per-channel analysis result."""
    
    channel_index: int
    evaluation_verdict: str
    fraud_risk_index: str
    variance: float

class MultiChannelResponse(BaseModel):
    """Response from multi-channel audit."""
    
    security_token: str
    evaluation_verdict: str
    fraud_risk_index: str
    firewall_action: str
    channel_results: List[ChannelResult]
    ensemble_votes: Dict[str, int]

class BatchAuditResponse(BaseModel):
    """Response from batch audit."""
    
    batch_id: str
    total_streams: int
    results: List[AuditResponse]
    total_cost: str
