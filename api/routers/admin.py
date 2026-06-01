from fastapi import APIRouter, HTTPException, Depends, Header, Body
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
import asyncio
import logging

from services.admin_service import AdminService
from services.billing_service import BillingService
from models.admin import ClientConfig, BlockListEntry, RateLimitOverride

router = APIRouter()
logger = logging.getLogger(__name__)

# Admin API key validation (separate from user keys)
ADMIN_KEYS = {"sk_admin_master_2026", "sk_admin_emergency_backup"}

async def verify_admin_key(authorization_token: str = Header(..., alias="X-Admin-Token")):
    if authorization_token not in ADMIN_KEYS:
        raise HTTPException(status_code=403, detail="Invalid admin token")
    return authorization_token

@router.get("/clients")
async def list_clients(
    admin_token: str = Depends(verify_admin_key),
    limit: int = 100,
    offset: int = 0
):
    """List all registered clients."""
    clients = await AdminService.list_clients(limit, offset)
    return {"clients": clients, "total": len(clients)}

@router.get("/clients/{client_id}")
async def get_client(
    client_id: str,
    admin_token: str = Depends(verify_admin_key)
):
    """Get detailed client information."""
    client = await AdminService.get_client(client_id)
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    return client

@router.post("/clients")
async def create_client(
    config: ClientConfig,
    admin_token: str = Depends(verify_admin_key)
):
    """Create a new client account."""
    result = await AdminService.create_client(config)
    return result

@router.put("/clients/{client_id}")
async def update_client(
    client_id: str,
    config: ClientConfig,
    admin_token: str = Depends(verify_admin_key)
):
    """Update client configuration."""
    result = await AdminService.update_client(client_id, config)
    return result

@router.delete("/clients/{client_id}")
async def delete_client(
    client_id: str,
    admin_token: str = Depends(verify_admin_key)
):
    """Delete a client account."""
    await AdminService.delete_client(client_id)
    return {"status": "deleted"}

@router.get("/blocklist")
async def get_blocklist(
    admin_token: str = Depends(verify_admin_key)
):
    """Get all blocked IP addresses."""
    blocked = await AdminService.get_blocklist()
    return {"blocked_ips": blocked, "count": len(blocked)}

@router.post("/blocklist")
async def add_to_blocklist(
    entry: BlockListEntry,
    admin_token: str = Depends(verify_admin_key)
):
    """Add an IP address to the blocklist."""
    await AdminService.block_ip(entry.ip_address, entry.reason, entry.duration_hours)
    return {"status": "blocked", "ip": entry.ip_address}

@router.delete("/blocklist/{ip_address}")
async def remove_from_blocklist(
    ip_address: str,
    admin_token: str = Depends(verify_admin_key)
):
    """Remove an IP address from the blocklist."""
    await AdminService.unblock_ip(ip_address)
    return {"status": "unblocked", "ip": ip_address}

@router.post("/rate-limit/{client_id}")
async def set_rate_limit_override(
    client_id: str,
    override: RateLimitOverride,
    admin_token: str = Depends(verify_admin_key)
):
    """Override rate limits for a specific client."""
    await AdminService.set_rate_limit_override(client_id, override)
    return {"status": "updated"}

@router.get("/stats/global")
async def get_global_stats(
    admin_token: str = Depends(verify_admin_key),
    days: int = 7
):
    """Get global system statistics."""
    stats = await AdminService.get_global_stats(days)
    return stats

@router.post("/emergency-stop")
async def emergency_stop(
    admin_token: str = Depends(verify_admin_key),
    reason: str = Body(...)
):
    """Emergency shutdown of the system."""
    logger.warning(f"EMERGENCY STOP initiated by admin. Reason: {reason}")
    await AdminService.emergency_stop(reason)
    return {"status": "stopped", "reason": reason}

@router.post("/emergency-start")
async def emergency_start(
    admin_token: str = Depends(verify_admin_key)
):
    """Restart the system after emergency stop."""
    logger.info("Emergency start initiated")
    await AdminService.emergency_start()
    return {"status": "started"}
