import json
import asyncio
from typing import Optional, Any, Dict
import redis.asyncio as redis
from config import settings

class CacheService:
    _redis: Optional[redis.Redis] = None
    _initialized = False
    
    @classmethod
    async def initialize(cls):
        """Initialize Redis connection."""
        try:
            cls._redis = redis.Redis(
                host=settings.REDIS_HOST,
                port=settings.REDIS_PORT,
                password=settings.REDIS_PASSWORD,
                decode_responses=True,
                socket_connect_timeout=5,
                socket_timeout=5,
                retry_on_timeout=True
            )
            await cls._redis.ping()
            cls._initialized = True
            print("CacheService initialized successfully")
        except Exception as e:
            print(f"Failed to connect to Redis: {e}")
            cls._initialized = False
    
    @classmethod
    async def close(cls):
        """Close Redis connection."""
        if cls._redis:
            await cls._redis.close()
        cls._initialized = False
    
    @classmethod
    async def get(cls, key: str) -> Optional[Any]:
        """Get value from cache."""
        if not cls._initialized:
            return None
        
        try:
            value = await cls._redis.get(key)
            if value:
                return json.loads(value)
        except Exception:
            pass
        return None
    
    @classmethod
    async def set(cls, key: str, value: Any, ttl: int = 60) -> bool:
        """Set value in cache with TTL."""
        if not cls._initialized:
            return False
        
        try:
            await cls._redis.setex(key, ttl, json.dumps(value))
            return True
        except Exception:
            return False
    
    @classmethod
    async def delete(cls, key: str) -> bool:
        """Delete value from cache."""
        if not cls._initialized:
            return False
        
        try:
            await cls._redis.delete(key)
            return True
        except Exception:
            return False
    
    @classmethod
    async def ping(cls) -> bool:
        """Check if Redis is reachable."""
        if not cls._initialized or not cls._redis:
            return False
        
        try:
            return await cls._redis.ping()
        except Exception:
            return False
    
    @classmethod
    async def is_ready(cls) -> bool:
        """Check if cache is ready."""
        return cls._initialized and await cls.ping()
