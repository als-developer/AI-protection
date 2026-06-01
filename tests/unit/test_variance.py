import pytest
import numpy as np
from api.services.deepfake_service import DeepfakeService

class TestVarianceCalculation:
    """Unit tests for variance calculation and deepfake detection."""
    
    @pytest.mark.asyncio
    async def test_human_voice_detection(self):
        """Test that human voice patterns are correctly identified."""
        # Generate random human-like voice pattern (high variance)
        human_voice = list(np.random.uniform(0.1, 2.5, 100))
        
        result = await DeepfakeService.analyze_stream(
            frequency_deltas=human_voice,
            client_id="test_client",
            channel_id="test_channel"
        )
        
        assert result["evaluation_verdict"] in ["VERIFIED_HUMAN_AUTHENTIC", "SUSPICIOUS_PATTERN"]
        assert float(result["fraud_risk_index"].replace('%', '')) < 50
    
    @pytest.mark.asyncio
    async def test_deepfake_detection(self):
        """Test that AI deepfake patterns are detected."""
        # Generate AI clone pattern (low variance)
        ai_voice = [0.12, 0.12, 0.11, 0.12, 0.12] * 20
        
        result = await DeepfakeService.analyze_stream(
            frequency_deltas=ai_voice,
            client_id="test_client",
            channel_id="test_channel"
        )
        
        assert result["evaluation_verdict"] == "CRITICAL_SUSPECTED_DEEPFAKE"
        assert float(result["fraud_risk_index"].replace('%', '')) > 90
    
    def test_variance_calculation(self):
        """Test mathematical variance calculation."""
        data = [1.0, 2.0, 3.0, 4.0, 5.0]
        variance = np.var(data)
        assert variance == 2.0
