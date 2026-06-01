from locust import HttpUser, task, between
import random

class BioShieldUser(HttpUser):
    wait_time = between(0.01, 0.1)
    
    def on_start(self):
        """Set up authentication."""
        self.headers = {
            "X-BioShield-Token": "sk_load_test_key",
            "Content-Type": "application/json"
        }
    
    @task(3)
    def audit_human_voice(self):
        """Simulate human voice audit."""
        payload = {
            "bank_cluster_token": f"bank_{random.randint(1, 100)}",
            "channel_identity": f"trunk_{random.randint(1, 1000)}",
            "frequency_amplitude_deltas": [random.uniform(0.1, 3.0) for _ in range(50)]
        }
        self.client.post("/v1/audit-voice", json=payload, headers=self.headers)
    
    @task(1)
    def audit_deepfake(self):
        """Simulate deepfake detection."""
        payload = {
            "bank_cluster_token": f"bank_{random.randint(1, 100)}",
            "channel_identity": f"trunk_{random.randint(1, 1000)}",
            "frequency_amplitude_deltas": [0.12] * 50
        }
        self.client.post("/v1/audit-voice", json=payload, headers=self.headers)
    
    @task(1)
    def health_check(self):
        """Check health endpoint."""
        self.client.get("/v1/health")
