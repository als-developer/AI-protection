-- Anomaly detection function using statistical methods

CREATE OR REPLACE FUNCTION detect_statistical_anomaly(
    values NUMERIC[],
    threshold NUMERIC DEFAULT 2.5
)
RETURNS BOOLEAN[] AS $$
DECLARE
    mean_val NUMERIC;
    std_dev NUMERIC;
    result BOOLEAN[];
    val NUMERIC;
    z_score NUMERIC;
BEGIN
    -- Calculate mean and standard deviation
    SELECT AVG(v), STDDEV(v) INTO mean_val, std_dev
    FROM unnest(values) AS v;
    
    IF std_dev IS NULL OR std_dev = 0 THEN
        -- If all values are identical, it's an anomaly
        RETURN ARRAY(SELECT TRUE FROM unnest(values));
    END IF;
    
    -- Detect anomalies using Z-score
    FOREACH val IN ARRAY values
    LOOP
        z_score := ABS(val - mean_val) / std_dev;
        result := result || (z_score > threshold);
    END LOOP;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Rolling window anomaly detection for time series
CREATE OR REPLACE FUNCTION rolling_window_anomaly(
    p_client_id VARCHAR,
    p_hours INTEGER DEFAULT 24
)
RETURNS TABLE(
    anomaly_hour TIMESTAMP,
    anomaly_count BIGINT,
    avg_variance NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        DATE_TRUNC('hour', created_at) AS hour,
        COUNT(*) FILTER (WHERE frequency_delta < 0.045) AS anomaly_count,
        AVG(frequency_delta) AS avg_variance
    FROM deepfake_audit_logs
    WHERE client_id = p_client_id
    AND created_at >= NOW() - (p_hours || ' hours')::INTERVAL
    GROUP BY DATE_TRUNC('hour', created_at)
    ORDER BY hour;
END;
$$ LANGUAGE plpgsql;
