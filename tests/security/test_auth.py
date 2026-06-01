import pytest
from fastapi.testclient import TestClient
from api.main import app

client = TestClient(app)

class TestAuthentication:
    """Security tests for authentication."""
    
    def test_missing_api_key(self):
        """Test request without API key."""
        response = client.post("/v1/audit-voice", json={
            "bank_cluster_token": "test",
            "channel_identity": "test",
            "frequency_amplitude_deltas": [0.1] * 50
        })
        assert response.status_code == 401
        assert "Missing API key" in response.json()["detail"]
    
    def test_invalid_api_key(self):
        """Test request with invalid API key."""
        response = client.post(
            "/v1/audit-voice",
            headers={"X-BioShield-Token": "invalid_key"},
            json={
                "bank_cluster_token": "test",
                "channel_identity": "test",
                "frequency_amplitude_deltas": [0.1] * 50
            }
        )
        assert response.status_code == 401
        assert "Invalid API key" in response.json()["detail"]
    
    def test_valid_api_key(self):
        """Test request with valid API key."""
        response = client.post(
            "/v1/audit-voice",
            headers={"X-BioShield-Token": "sk_test_valid_key"},
            json={
                "bank_cluster_token": "test",
                "channel_identity": "test",
                "frequency_amplitude_deltas": [0.1] * 50
            }
        )
        # Should be 200 or 400 (if payload invalid), not 401
        assert response.status_code != 401
