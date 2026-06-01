-- Multi-channel audio analysis schema
-- Version: 2.0

-- Create partitioned table for channel telemetry
CREATE TABLE IF NOT EXISTS channel_telemetry_partitioned (
    LIKE deepfake_channel_telemetry INCLUDING ALL
) PARTITION BY RANGE (logged_at);

-- Create monthly partitions (run monthly)
DO $$
DECLARE
    start_date DATE;
    end_date DATE;
    partition_name TEXT;
BEGIN
    FOR i IN 0..12 LOOP
        start_date := DATE_TRUNC('month', NOW() + (i || ' months')::INTERVAL)::DATE;
        end_date := start_date + INTERVAL '1 month';
        partition_name := 'channel_telemetry_' || TO_CHAR(start_date, 'YYYY_MM');
        
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS %I PARTITION OF channel_telemetry_partitioned
            FOR VALUES FROM (%L) TO (%L)',
            partition_name, start_date, end_date
        );
    END LOOP;
END $$;

-- Function to get multi-channel anomaly detection
CREATE OR REPLACE FUNCTION detect_multi_channel_anomaly(
    p_audit_id VARCHAR
)
RETURNS BOOLEAN AS $$
DECLARE
    total_channels INTEGER;
    anomaly_channels INTEGER;
BEGIN
    SELECT COUNT(*), COUNT(*) FILTER (WHERE is_anomaly = TRUE)
    INTO total_channels, anomaly_channels
    FROM deepfake_channel_telemetry
    WHERE audit_id = p_audit_id;
    
    RETURN anomaly_channels > total_channels / 2;
END;
$$ LANGUAGE plpgsql;

-- View for real-time channel metrics
CREATE OR REPLACE VIEW v_channel_health AS
SELECT 
    DATE_TRUNC('minute', logged_at) AS minute,
    channel_index,
    AVG(calculated_variance) AS avg_variance,
    AVG(anomaly_score) AS avg_anomaly_score,
    COUNT(*) AS sample_count,
    SUM(CASE WHEN is_anomaly THEN 1 ELSE 0 END) AS anomaly_count
FROM deepfake_channel_telemetry
WHERE logged_at >= NOW() - INTERVAL '1 hour'
GROUP BY DATE_TRUNC('minute', logged_at), channel_index;
