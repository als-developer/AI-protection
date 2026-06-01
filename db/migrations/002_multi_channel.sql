-- Multi-channel telemetry table
CREATE TABLE IF NOT EXISTS deepfake_channel_telemetry (
    channel_telemetry_id BIGSERIAL PRIMARY KEY,
    audit_id VARCHAR(50) NOT NULL REFERENCES deepfake_audit_logs(audit_id) ON DELETE CASCADE,
    channel_index INTEGER NOT NULL,
    calculated_variance NUMERIC(7,4) NOT NULL,
    calculated_mean NUMERIC(10,6) NOT NULL,
    zero_crossing_rate NUMERIC(7,4),
    is_anomaly BOOLEAN DEFAULT FALSE,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for fast lookups
CREATE INDEX idx_channel_audit ON deepfake_channel_telemetry(audit_id);
CREATE INDEX idx_channel_anomaly ON deepfake_channel_telemetry(is_anomaly) WHERE is_anomaly = TRUE;

-- Stored procedure for variance calculation
CREATE OR REPLACE FUNCTION calculate_risk_score(variance NUMERIC, mean NUMERIC)
RETURNS NUMERIC AS $$
BEGIN
    RETURN CASE
        WHEN variance < 0.045 THEN 95 + (random() * 4)::NUMERIC
        WHEN variance < 0.08 THEN 50 + (random() * 20)::NUMERIC
        ELSE (random() * 10)::NUMERIC
    END;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-calculate risk score
CREATE OR REPLACE FUNCTION auto_calculate_fraud_risk()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fraud_risk_score := calculate_risk_score(NEW.frequency_delta, 0);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auto_risk_score
    BEFORE INSERT ON deepfake_audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION auto_calculate_fraud_risk();
