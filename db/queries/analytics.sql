-- Analytics queries for reporting and dashboards

-- Daily deepfake detection summary
CREATE OR REPLACE VIEW v_daily_deepfake_summary AS
SELECT 
    DATE(created_at) AS date,
    client_id,
    COUNT(*) AS total_scans,
    COUNT(*) FILTER (WHERE verdict = 'CRITICAL_SUSPECTED_DEEPFAKE') AS deepfake_detections,
    COUNT(*) FILTER (WHERE verdict = 'SUSPICIOUS_PATTERN') AS suspicious_detections,
    AVG(fraud_risk_score) AS avg_risk_score,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY processing_latency_ms) AS p95_latency_ms
FROM deepfake_audit_logs
GROUP BY DATE(created_at), client_id;

-- Hourly trend analysis
CREATE OR REPLACE VIEW v_hourly_trends AS
SELECT 
    DATE_TRUNC('hour', created_at) AS hour,
    COUNT(*) AS scan_count,
    COUNT(*) FILTER (WHERE fraud_risk_score > 90) AS high_risk_count,
    AVG(processing_latency_ms) AS avg_latency_ms
FROM deepfake_audit_logs
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE_TRUNC('hour', created_at)
ORDER BY hour DESC;

-- Top offending IP addresses
CREATE OR REPLACE VIEW v_top_offenders AS
SELECT 
    source_ip,
    COUNT(*) AS total_scans,
    COUNT(*) FILTER (WHERE verdict = 'CRITICAL_SUSPECTED_DEEPFAKE') AS deepfake_count,
    AVG(fraud_risk_score) AS avg_risk_score,
    MAX(created_at) AS last_seen
FROM deepfake_audit_logs
WHERE source_ip IS NOT NULL
AND created_at >= NOW() - INTERVAL '7 days'
GROUP BY source_ip
HAVING COUNT(*) FILTER (WHERE verdict = 'CRITICAL_SUSPECTED_DEEPFAKE') > 0
ORDER BY deepfake_count DESC;
