"""
Database service for managing payment orders and transactions
"""

import json
from typing import Dict, Any, Optional, List
from datetime import datetime
import asyncpg
from supabase import create_client, Client
import os

SUPABASE_URL = os.getenv("SUPABASE_URL", "https://your-project.supabase.co")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "your-anon-key")

class DatabaseService:
    _supabase: Client = None
    
    @classmethod
    def get_client(cls) -> Client:
        if not cls._supabase:
            cls._supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        return cls._supabase
    
    @classmethod
    async def create_payment_order(cls, order_data: Dict[str, Any]) -> Dict:
        """Create a new payment order record"""
        client = cls.get_client()
        
        result = client.table("payment_orders").insert(order_data).execute()
        
        if result.data:
            return result.data[0]
        return None
    
    @classmethod
    async def get_payment_order(cls, order_id: str) -> Optional[Dict]:
        """Get payment order by ID"""
        client = cls.get_client()
        
        result = client.table("payment_orders").select("*").eq("order_id", order_id).execute()
        
        if result.data:
            return result.data[0]
        return None
    
    @classmethod
    async def get_payment_order_by_transaction(cls, transaction_id: str) -> Optional[Dict]:
        """Get payment order by transaction ID"""
        client = cls.get_client()
        
        result = client.table("payment_orders").select("*").eq("transaction_id", transaction_id).execute()
        
        if result.data:
            return result.data[0]
        return None
    
    @classmethod
    async def update_payment_order(cls, order_id: str, updates: Dict[str, Any]) -> Dict:
        """Update payment order status"""
        client = cls.get_client()
        
        result = client.table("payment_orders").update(updates).eq("order_id", order_id).execute()
        
        if result.data:
            return result.data[0]
        return None
    
    @classmethod
    async def get_client_orders(cls, client_id: str, limit: int = 50) -> List[Dict]:
        """Get all orders for a specific client"""
        client = cls.get_client()
        
        result = client.table("payment_orders").select("*").eq("client_id", client_id).order("created_at", desc=True).limit(limit).execute()
        
        return result.data or []
    
    @classmethod
    async def get_transaction_stats(cls, days: int = 30) -> Dict:
        """Get transaction statistics for reporting"""
        client = cls.get_client()
        
        # Get completed payments
        payments = client.table("payment_orders").select("*").eq("status", "COMPLETED").execute()
        
        total_amount = 0
        total_transactions = len(payments.data or [])
        
        for payment in (payments.data or []):
            total_amount += float(payment.get('amount', 0))
        
        return {
            "total_transactions": total_transactions,
            "total_amount_usd": total_amount,
            "average_transaction": total_amount / total_transactions if total_transactions > 0 else 0,
            "period_days": days
        }
