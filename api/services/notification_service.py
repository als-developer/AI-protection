import asyncio
import aiohttp
import json
from typing import Dict, Any, Optional
from config import settings

class NotificationService:
    _session: Optional[aiohttp.ClientSession] = None
    
    @classmethod
    async def initialize(cls):
        cls._session = aiohttp.ClientSession()
    
    @classmethod
    async def close(cls):
        if cls._session:
            await cls._session.close()
    
    @classmethod
    async def send_slack_alert(cls, message: str, severity: str = "warning"):
        """Send alert to Slack channel."""
        if not settings.SLACK_WEBHOOK_URL:
            return
        
        colors = {
            "critical": "danger",
            "warning": "warning",
            "info": "good"
        }
        
        payload = {
            "attachments": [{
                "color": colors.get(severity, "warning"),
                "text": message,
                "footer": "BioShield Security System",
                "ts": int(asyncio.get_event_loop().time())
            }]
        }
        
        try:
            async with cls._session.post(
                settings.SLACK_WEBHOOK_URL,
                json=payload
            ) as resp:
                return resp.status == 200
        except Exception:
            return False
    
    @classmethod
    async def send_pagerduty_alert(cls, summary: str, severity: str = "critical"):
        """Send critical alert to PagerDuty."""
        if not settings.PAGERDUTY_INTEGRATION_KEY:
            return
        
        payload = {
            "routing_key": settings.PAGERDUTY_INTEGRATION_KEY,
            "event_action": "trigger",
            "payload": {
                "summary": summary,
                "severity": severity,
                "source": "bioshield-api"
            }
        }
        
        try:
            async with cls._session.post(
                "https://events.pagerduty.com/v2/enqueue",
                json=payload
            ) as resp:
                return resp.status == 202
        except Exception:
            return False
