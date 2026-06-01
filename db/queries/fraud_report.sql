-- Fraud detection reports for compliance

-- Generate fraud report for a specific date range
CREATE OR REPLACE FUNCTION generate_fraud_report(
    start_date DATE,
    end_date DATE
)
RETURNS TABLE(
    report_date DATE,
    total_scans BIGINT,
    confirmed_deepfakes BIGINT,
    suspicious_count BIGINT,
    avg_risk_score NUMERIC,
    top_channel VARCHAR,
    affected_clients BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        DATE(created_at) AS report_date,
        COUNT(*)::BIGINT,
        COUNT(*) FILTER (WHERE verdict = 'CRITICAL_SUSPECTED_DEEPFAKE')::BIGINT,
        COUNT(*) FILTER (WHERE verdict = 'SUSPICIOUS_PATTERN')::BIGINT,
        AVG(fraud_risk_score),
        MODE() WITHIN GROUP (ORDER BY channel_identity) AS top_channel,
        COUNT(DISTINCT client_id)::BIGINT
    FROM deepfake_audit_logs
    WHERE DATE(created_at) BETWEEN start_date AND end_date
    GROUP BY DATE(created_at)
    ORDER BY report_date;
END;
$$ LANGUAGE plpgsql;

-- Weekly fraud summary
CREATE OR REPLACE VIEW v_weekly_fraud_summary AS
SELECT 
    DATE_TRUNC('week', created_at) AS week_start,
    COUNT(*) AS total_scans,
    COUNT(*) FILTER (WHERE verdict = 'CRITICAL_SUSPECTED_DEEPFAKE') AS deepfakes_blocked,
    ROUND(100.0 * COUNT(*) FILTER (WHERE verdict = 'CRITICAL_SUSPECTED_DEEPFAKE') / NULLIF(COUNT(*), 0), 2) AS deepfake_percentage,
    AVG(processing_latency_ms) AS avg_latency
FROM deepfake_audit_logs
GROUP BY DATE_TRUNC('week', created_at)
ORDER BY week_start DESC;
