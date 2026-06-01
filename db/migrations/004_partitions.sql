-- Automatic partitioning setup for deepfake_audit_logs

-- Create partition function
CREATE OR REPLACE FUNCTION create_monthly_partition()
RETURNS VOID AS $$
DECLARE
    next_month DATE;
    partition_name TEXT;
    start_date DATE;
    end_date DATE;
BEGIN
    next_month := DATE_TRUNC('month', NOW() + INTERVAL '1 month')::DATE;
    partition_name := 'deepfake_audit_logs_' || TO_CHAR(next_month, 'YYYY_MM');
    start_date := next_month;
    end_date := next_month + INTERVAL '1 month';
    
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I PARTITION OF deepfake_audit_logs
        FOR VALUES FROM (%L) TO (%L)',
        partition_name, start_date, end_date
    );
END;
$$ LANGUAGE plpgsql;

-- Schedule monthly partition creation (run via cron)
-- SELECT create_monthly_partition();
