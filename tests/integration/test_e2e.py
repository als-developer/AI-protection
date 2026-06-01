import pytest
import httpx
import asyncio

API_URL = "http://localhost:8000"
API_KEY = "sk_test_integration_key"

class TestEndToEnd:
    """End-to-end integration tests."""
    
    @pytest.mark.asyncio
    async def test_full_audit_flow(self):
        """Test complete audit flow from request to response."""
        async with httpx.AsyncClient() as client:
            payload = {
                "bank_cluster_token": "integration_test_bank",
                "channel_identity": "sip_trunk_01",
                "frequency_amplitude_deltas": [0.12, 0.12, 0.11, 0.12] * 25
            }
            
            response = await client.post(
                f"{API_URL}/v1/audit-voice",
                json=payload,
                headers={"X-BioShield-Token": API_KEY}
            )
            
            assert response.status_code == 200
            data = response.json()
            assert "security_token" in data
            assert "evaluation_verdict" in data
            assert "fraud_risk_index" in data
    
    @pytest.mark.asyncio
    async def test_multi_channel_audit(self):
        """Test multi-channel audio analysis."""
        async with httpx.AsyncClient() as client:
            payload = {
                "bank_cluster_token": "integration_test_bank",
                "channel_identity": "multi_channel_test",
                "channels": [
                    {"channel_index": 0, "frequency_deltas": [0.12] * 50},
                    {"channel_index": 1, "frequency_deltas": [0.13] * 50},
                    {"channel_index": 2, "frequency_deltas": [0.45, 1.23, 0.98] * 20}
                ]
            }
            
            response = await client.post(
                f"{API_URL}/v1/audit-multi-channel",
                json=payload,
                headers={"X-BioShield-Token": API_KEY}
            )
            
            assert response.status_code == 200
            data = response.json()
            assert "channel_results" in data
            assert "ensemble_votes" in data
