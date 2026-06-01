from pydantic import BaseModel, Field, validator
from typing import List, Optional, Dict, Any
from datetime import datetime

class AudioStreamPayload(BaseModel):
    """Payload for single audio stream analysis."""
    
    bank_cluster_token: str = Field(..., description="Banking node identifier", max_length=100)
    channel_identity: str = Field(..., description="SIP trunk or channel ID", max_length=100)
    frequency_amplitude_deltas: List[float] = Field(
        ..., 
        description="Array of frequency measurements",
        min_items=10,
        max_items=1000
    )
    metadata: Optional[Dict[str, Any]] = Field(default={}, description="Additional context")
    
    @validator('frequency_amplitude_deltas')
    def validate_deltas(cls, v):
        if any(x < 0 or x > 10 for x in v):
            raise ValueError('Frequency deltas must be between 0 and 10')
        return v

class ChannelData(BaseModel):
    """Individual channel data for multi-channel analysis."""
    
    channel_index: int = Field(..., ge=0, le=31, description="Channel number")
    frequency_deltas: List[float] = Field(..., min_items=10, max_items=1000)

class MultiChannelPayload(BaseModel):
    """Payload for multi-channel audio analysis."""
    
    bank_cluster_token: str = Field(..., max_length=100)
    channel_identity: str = Field(..., max_length=100)
    channels: List[ChannelData] = Field(..., min_items=2, max_items=32)
    metadata: Optional[Dict[str, Any]] = {}

class BatchStreamPayload(BaseModel):
    """Single stream in batch request."""
    
    bank_cluster_token: str
    channel_identity: str
    frequency_deltas: List[float]
    metadata: Optional[Dict[str, Any]] = {}

class BatchPayload(BaseModel):
    """Batch processing payload."""
    
    streams: List[BatchStreamPayload] = Field(..., min_items=1, max_items=100)
    
    @validator('streams')
    def validate_batch_size(cls, v):
        if len(v) > 100:
            raise ValueError('Maximum batch size is 100')
        return v

class HealthCheckResponse(BaseModel):
    status: str
    timestamp: datetime
    components: Dict[str, str]
