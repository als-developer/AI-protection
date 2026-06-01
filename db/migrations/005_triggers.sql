-- Automated triggers for data integrity and auditing

-- Update last_used_at on API key usage
CREATE OR REPLACE FUNCTION update_api_key_last_used()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE developer_api_keys 
    SET last_used_at = CURRENT_TIMESTAMP,
        current_month_usage = current_month_usage + 1
    WHERE api_key_hash = NEW.api_key_hash;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Note: This trigger would be called from application layer

-- Alert on high-risk deepfake detection
CREATE OR REPLACE FUNCTION alert_on_high_risk()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.fraud_risk_score > 95 AND NEW.verdict = 'CRITICAL_SUSPECTED_DEEPFAKE' THEN
        INSERT INTO security_alerts (severity, title, description, client_id, source_ip, verdict, fraud_risk_score)
        VALUES ('critical', 'High-Risk Deepfake Detected', 
                'Deepfake detected with fraud risk score > 95%', 
                NEW.client_id, NEW.source_ip, NEW.verdict, NEW.fraud_risk_score);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_alert_high_risk
    AFTER INSERT ON deepfake_audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION alert_on_high_risk();
