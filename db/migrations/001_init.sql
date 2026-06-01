-- Sovereign Bio-Shield Ultimate Database Schema
-- Version: 3.0.0
-- Description: Core database schema for deepfake detection platform

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "timescaledb";

-- =====================================================
-- CORE TABLES
-- =====================================================

-- Audit logs table (main telemetry storage)
CREATE TABLE IF NOT EXISTS deepfake_audit_logs (
    audit_id VARCHAR(50) PRIMARY KEY,
    client_id VARCHAR(100) NOT NULL,
    client_name VARCHAR(200),
    media_type VARCHAR(30) NOT NULL,
    fraud_risk_score NUMERIC(5,2) NOT NULL,
    verdict VARCHAR(50) NOT NULL,
    frequency_delta NUMERIC(10,6) NOT NULL,
    variance_calculated NUMERIC(10,6),
    mean_value NUMERIC(10,6),
    std_deviation NUMERIC(10,6),
    zero_crossing_rate NUMERIC(10,6),
    spectral_flatness NUMERIC(10,6),
    processing_latency_ms NUMERIC(8,3),
    metadata JSONB DEFAULT '{}',
    source_ip INET,
    channel_identity VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMPTZ,
    region VARCHAR(50)
);

-- Create partitioned table for time-series data
SELECT create_hypertable('deepfake_audit_logs', 'created_at', chunk_time_interval => INTERVAL '1 day');

-- Indexes for deepfake_audit_logs
CREATE INDEX IF NOT EXISTS idx_audit_client_time ON deepfake_audit_logs(client_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_verdict_time ON deepfake_audit_logs(verdict, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_risk_score ON deepfake_audit_logs(fraud_risk_score) WHERE fraud_risk_score > 90;
CREATE INDEX IF NOT EXISTS idx_audit_metadata ON deepfake_audit_logs USING GIN(metadata);
CREATE INDEX IF NOT EXISTS idx_audit_source_ip ON deepfake_audit_logs(source_ip);
CREATE INDEX IF NOT EXISTS idx_audit_region ON deepfake_audit_logs(region);

-- =====================================================
-- MULTI-CHANNEL TELEMETRY
-- =====================================================

CREATE TABLE IF NOT EXISTS deepfake_channel_telemetry (
    channel_telemetry_id BIGSERIAL PRIMARY KEY,
    audit_id VARCHAR(50) NOT NULL REFERENCES deepfake_audit_logs(audit_id) ON DELETE CASCADE,
    channel_index INTEGER NOT NULL,
    calculated_variance NUMERIC(10,6) NOT NULL,
    calculated_mean NUMERIC(10,6),
    zero_crossing_rate NUMERIC(10,6),
    peak_frequency NUMERIC(10,2),
    is_anomaly BOOLEAN DEFAULT FALSE,
    anomaly_score NUMERIC(5,2),
    logged_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_channel_audit ON deepfake_channel_telemetry(audit_id);
CREATE INDEX idx_channel_anomaly ON deepfake_channel_telemetry(is_anomaly) WHERE is_anomaly = TRUE;
CREATE INDEX idx_channel_index ON deepfake_channel_telemetry(channel_index);

-- =====================================================
-- DEVELOPER & API KEYS
-- =====================================================

CREATE TABLE IF NOT EXISTS developer_api_keys (
    id BIGSERIAL PRIMARY KEY,
    api_key_hash VARCHAR(128) UNIQUE NOT NULL,
    api_key_prefix VARCHAR(20),
    developer_id VARCHAR(50) UNIQUE NOT NULL,
    developer_name VARCHAR(200),
    contact_email VARCHAR(200),
    account_balance_usd NUMERIC(12,2) DEFAULT 0.00,
    rate_limit_tier VARCHAR(20) DEFAULT 'standard',
    monthly_quota INTEGER DEFAULT 100000,
    current_month_usage INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ,
    last_ip INET,
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX idx_api_keys_hash ON developer_api_keys(api_key_hash);
CREATE INDEX idx_api_keys_active ON developer_api_keys(is_active);
CREATE INDEX idx_api_keys_developer ON developer_api_keys(developer_id);

-- =====================================================
-- RATE LIMITING PROFILES
-- =====================================================

CREATE TABLE IF NOT EXISTS rate_limit_profiles (
    profile_tier VARCHAR(20) PRIMARY KEY,
    max_requests_per_minute INTEGER NOT NULL,
    burst_capacity INTEGER NOT NULL,
    price_per_request NUMERIC(8,4) DEFAULT 0.10,
    concurrent_streams INTEGER DEFAULT 10,
    description TEXT
);

INSERT INTO rate_limit_profiles (profile_tier, max_requests_per_minute, burst_capacity, price_per_request, concurrent_streams, description) VALUES
('free', 10, 15, 0.00, 1, 'Free tier for testing'),
('developer', 200, 300, 0.05, 5, 'Developer tier for integration'),
('enterprise', 10000, 15000, 0.03, 50, 'Enterprise tier for production'),
('ultra', 100000, 120000, 0.02, 500, 'Ultra tier for high-volume banks')
ON CONFLICT (profile_tier) DO NOTHING;

-- =====================================================
-- BILLING & INVOICES
-- =====================================================

CREATE TABLE IF NOT EXISTS billing_transactions (
    transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    developer_id VARCHAR(50) NOT NULL REFERENCES developer_api_keys(developer_id),
    amount_usd NUMERIC(10,4) NOT NULL,
    transaction_type VARCHAR(20) NOT NULL, -- 'credit_purchase', 'scan_charge', 'refund'
    scan_count INTEGER,
    scan_type VARCHAR(30),
    stripe_payment_intent_id VARCHAR(100),
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ
);

CREATE INDEX idx_billing_developer ON billing_transactions(developer_id);
CREATE INDEX idx_billing_created ON billing_transactions(created_at DESC);
CREATE INDEX idx_billing_status ON billing_transactions(status);

CREATE TABLE IF NOT EXISTS invoices (
    invoice_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    developer_id VARCHAR(50) NOT NULL,
    invoice_number VARCHAR(50) UNIQUE NOT NULL,
    amount_usd NUMERIC(12,2) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    pdf_url TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMPTZ
);

CREATE INDEX idx_invoices_developer ON invoices(developer_id);
CREATE INDEX idx_invoices_period ON invoices(period_start, period_end);

-- =====================================================
-- BLOCKLIST
-- =====================================================

CREATE TABLE IF NOT EXISTS ip_blocklist (
    id BIGSERIAL PRIMARY KEY,
    ip_address INET NOT NULL UNIQUE,
    reason TEXT,
    blocked_by VARCHAR(100),
    blocked_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ,
    is_permanent BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_blocklist_ip ON ip_blocklist(ip_address);
CREATE INDEX idx_blocklist_expires ON ip_blocklist(expires_at) WHERE expires_at IS NOT NULL;

-- =====================================================
-- ALERTS & NOTIFICATIONS
-- =====================================================

CREATE TABLE IF NOT EXISTS security_alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    severity VARCHAR(20) NOT NULL, -- 'critical', 'high', 'medium', 'low'
    title VARCHAR(200) NOT NULL,
    description TEXT,
    client_id VARCHAR(100),
    source_ip INET,
    verdict VARCHAR(50),
    fraud_risk_score NUMERIC(5,2),
    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_by VARCHAR(100),
    acknowledged_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_alerts_severity ON security_alerts(severity, created_at DESC);
CREATE INDEX idx_alerts_unacknowledged ON security_alerts(acknowledged) WHERE acknowledged = FALSE;

-- =====================================================
-- AUDIT TRAIL (for compliance)
-- =====================================================

CREATE TABLE IF NOT EXISTS audit_trail (
    audit_id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(100),
    action VARCHAR(50) NOT NULL,
    resource_type VARCHAR(50),
    resource_id VARCHAR(100),
    old_value JSONB,
    new_value JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_trail_user ON audit_trail(user_id, created_at DESC);
CREATE INDEX idx_audit_trail_action ON audit_trail(action);

-- =====================================================
-- STORED PROCEDURES & FUNCTIONS
-- =====================================================

-- Function to calculate risk score from variance
CREATE OR REPLACE FUNCTION calculate_risk_score(variance NUMERIC, mean_val NUMERIC)
RETURNS NUMERIC AS $$
BEGIN
    RETURN CASE
        WHEN variance < 0.045 THEN 95 + (random() * 4)::NUMERIC
        WHEN variance < 0.08 THEN 50 + (random() * 20)::NUMERIC
        ELSE (random() * 10)::NUMERIC
    END;
END;
$$ LANGUAGE plpgsql;

-- Function to get client statistics
CREATE OR REPLACE FUNCTION get_client_statistics(
    p_client_id VARCHAR,
    p_days INTEGER DEFAULT 7
)
RETURNS TABLE(
    total_scans BIGINT,
    deepfake_detections BIGINT,
    avg_risk_score NUMERIC,
    avg_latency_ms NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT,
        COUNT(*) FILTER (WHERE verdict = 'CRITICAL_SUSPECTED_DEEPFAKE')::BIGINT,
        AVG(fraud_risk_score),
        AVG(processing_latency_ms)
    FROM deepfake_audit_logs
    WHERE client_id = p_client_id
    AND created_at >= NOW() - (p_days || ' days')::INTERVAL;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Trigger to auto-calculate fraud risk score
CREATE OR REPLACE FUNCTION auto_calculate_fraud_risk()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.fraud_risk_score IS NULL THEN
        NEW.fraud_risk_score := calculate_risk_score(NEW.frequency_delta, 0);
    END IF;
    NEW.processed_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auto_risk_score
    BEFORE INSERT ON deepfake_audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION auto_calculate_fraud_risk();

-- Trigger for audit trail
CREATE OR REPLACE FUNCTION audit_rate_limit_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.rate_limit_tier IS DISTINCT FROM NEW.rate_limit_tier THEN
        INSERT INTO audit_trail (user_id, action, resource_type, resource_id, old_value, new_value)
        VALUES (current_user, 'RATE_LIMIT_CHANGE', 'developer_api_keys', NEW.developer_id, 
                jsonb_build_object('rate_limit_tier', OLD.rate_limit_tier),
                jsonb_build_object('rate_limit_tier', NEW.rate_limit_tier));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_rate_limit
    AFTER UPDATE OF rate_limit_tier ON developer_api_keys
    FOR EACH ROW
    EXECUTE FUNCTION audit_rate_limit_change();
