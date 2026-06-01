-- Daily statistics for dashboard

-- Current day statistics
CREATE OR REPLACE FUNCTION get_today_stats()
RETURNS TABLE(
    stat_name TEXT,
    stat_value NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'total_scans'::TEXT, COUNT(*)::NUMERIC
    FROM deepfake_audit_logs
    WHERE DATE(created_at) = CURRENT_DATE
    
    UNION ALL
    
    SELECT 'deepfake_detections'::TEXT, COUNT(*)::NUMERIC
    FROM deepfake_audit_logs
    WHERE DATE(created_at) = CURRENT_DATE
    AND verdict = 'CRITICAL_SUSPECTED_DEEPFAKE'
    
    UNION ALL
    
    SELECT 'avg_latency_ms'::TEXT, COALESCE(AVG(processing_latency_ms), 0)
    FROM deepfake_audit_logs
    WHERE DATE(created_at) = CURRENT_DATE
    
    UNION ALL
    
    SELECT 'active_clients'::TEXT, COUNT(DISTINCT client_id)::NUMERIC
    FROM deepfake_audit_logs
    WHERE DATE(created_at) = CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

-- Client-specific daily stats
CREATE OR REPLACE FUNCTION get_client_daily_stats(p_client_id VARCHAR)
RETURNS TABLE(
    stat_date DATE,
    scans BIGINT,
    deepfakes BIGINT,
    avg_risk NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        DATE(created_at),
        COUNT(*)::BIGINT,
        COUNT(*) FILTER (WHERE verdict = 'CRITICAL_SUSPECTED_DEEPFAKE')::BIGINT,
        AVG(fraud_risk_score)
    FROM deepfake_audit_logs
    WHERE client_id = p_client_id
    AND created_at >= NOW() - INTERVAL '30 days'
    GROUP BY DATE(created_at)
    ORDER BY DATE(created_at) DESC;
END;
$$ LANGUAGE plpgsql;
