import pytest
from fastapi.testclient import TestClient
from api.main import app

client = TestClient(app)

class TestAPI:
    """Unit tests for API endpoints."""
    
    def test_health_check(self):
        """Test health check endpoint."""
        response = client.get("/v1/health")
        assert response.status_code == 200
        data = response.json()
        assert "status" in data
        assert "components" in data
    
    def test_liveness(self):
        """Test liveness probe."""
        response = client.get("/v1/health/liveness")
        assert response.status_code == 200
        assert response.json()["alive"] == True
    
    def test_readiness(self):
        """Test readiness probe."""
        response = client.get("/v1/health/readiness")
        assert response.status_code == 200
    
    def test_metrics_endpoint(self):
        """Test Prometheus metrics endpoint."""
        response = client.get("/v1/metrics")
        assert response.status_code == 200
        assert "text/plain" in response.headers["content-type"]
    
    def test_voice_audit_missing_token(self):
        """Test voice audit without authentication."""
        payload = {
            "bank_cluster_token": "test",
            "channel_identity": "test",
            "frequency_amplitude_deltas": [0.1] * 50
        }
        response = client.post("/v1/audit-voice", json=payload)
        assert response.status_code == 401
        assert "Missing API key" in response.json()["detail"]
