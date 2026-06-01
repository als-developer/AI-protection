-- Performance indexes for high-velocity queries

-- Composite indexes for common query patterns
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_composite_1 
ON deepfake_audit_logs(client_id, verdict, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_composite_2 
ON deepfake_audit_logs(created_at, fraud_risk_score) 
WHERE fraud_risk_score > 90;

-- Partial indexes for active data
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_active_api_keys 
ON developer_api_keys(developer_id) 
WHERE is_active = TRUE;

-- Expression indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_date_trunc 
ON deepfake_audit_logs(DATE_TRUNC('hour', created_at));

-- GIN index for full-text search on metadata
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_metadata_gin 
ON deepfake_audit_logs USING GIN(metadata);

-- BRIN index for time-series (space-efficient)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_created_brin 
ON deepfake_audit_logs USING BRIN(created_at);

-- Analyze tables to update statistics
ANALYZE deepfake_audit_logs;
ANALYZE deepfake_channel_telemetry;
ANALYZE developer_api_keys;
