from pydantic_settings import BaseSettings
from typing import List, Optional

class Settings(BaseSettings):
    """Application configuration."""
    
    # API Settings
    APP_NAME: str = "Sovereign Bio-Shield Ultimate"
    APP_VERSION: str = "3.0.0"
    DEBUG: bool = False
    WORKERS_COUNT: int = 8
    
    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    
    # Security
    ALLOWED_HOSTS: List[str] = ["*"]
    ALLOWED_ORIGINS: List[str] = []
    
    # Database
    DATABASE_URL: str = "postgresql://user:pass@localhost/bioshield"
    
    # Redis
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379
    REDIS_PASSWORD: Optional[str] = None
    
    # Core Engine
    CORE_ENGINE_LIB: str = "/usr/local/lib/libbioshield.so"
    
    # Billing
    STRIPE_API_KEY: Optional[str] = None
    BILLING_RATE_PER_SCAN: float = 0.10
    
    # Rate Limiting
    RATE_LIMIT_DEFAULT: int = 10000
    RATE_LIMIT_BURST: int = 15000
    
    class Config:
        env_file = ".env"
        case_sensitive = False

settings = Settings()
