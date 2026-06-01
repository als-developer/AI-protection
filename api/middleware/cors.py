from fastapi.middleware.cors import CORSMiddleware as FastAPICORSMiddleware

class CORSConfig:
    """CORS configuration for the API."""
    
    @staticmethod
    def get_config():
        """Get CORS configuration for the application."""
        return {
            "allow_origins": [
                "https://dashboard.bioshield.secure-bank.internal",
                "https://admin.bioshield.secure-bank.internal",
            ],
            "allow_origin_regex": r"https://.*\.bioshield\.secure-bank\.internal",
            "allow_credentials": True,
            "allow_methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
            "allow_headers": [
                "X-BioShield-Token",
                "Content-Type",
                "Authorization",
                "Accept",
            ],
            "expose_headers": ["X-Request-ID", "X-RateLimit-Limit", "X-RateLimit-Remaining"],
            "max_age": 3600,
        }

def add_cors_middleware(app):
    """Add CORS middleware to the FastAPI application."""
    app.add_middleware(FastAPICORSMiddleware, **CORSConfig.get_config())
