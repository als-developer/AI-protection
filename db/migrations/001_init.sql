-- Initial database schema for Sovereign Bio-Shield

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Audit logs table
CREATE TABLE IF NOT EXISTS deepfake_audit_logs (
    audit_id VARCHAR(50) PRIMARY KEY,
    client_id VARCHAR(100) NOT NULL,
    media_type VARCHAR(30) NOT NULL,
    fraud_risk_score NUMERIC(5,2) NOT NULL,
    verdict VARCHAR(50) NOT NULL,
    frequency_delta NUMERIC(7,4) NOT NULL,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_audit_client ON deepfake_audit_logs(client_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON deepfake_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_verdict ON deepfake_audit_logs(verdict);

-- Developer API keys table
CREATE TABLE IF NOT EXISTS developer_api_keys (
    id SERIAL PRIMARY KEY,
    api_key_hash VARCHAR(64) UNIQUE NOT NULL,
    developer_id VARCHAR(50) UNIQUE NOT NULL,
    account_balance_usd NUMERIC(12,2) DEFAULT 0.00,
    rate_limit_tier VARCHAR(20) DEFAULT 'standard',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    last_used_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_api_keys_hash ON developer_api_keys(api_key_hash);
CREATE INDEX IF NOT EXISTS idx_api_keys_active ON developer_api_keys(is_active);

-- Rate limiting profiles
CREATE TABLE IF NOT EXISTS rate_limit_profiles (
    profile_tier VARCHAR(20) PRIMARY KEY,
    max_requests_per_minute INTEGER NOT NULL,
    burst_capacity INTEGER NOT NULL,
    price_per_request NUMERIC(8,4) DEFAULT 0.10
);

INSERT INTO rate_limit_profiles (profile_tier, max_requests_per_minute, burst_capacity, price_per_request) VALUES
('free', 10, 15, 0.00),
('developer', 200, 300, 0.05),
('enterprise', 10000, 15000, 0.03),
('ultra', 100000, 120000, 0.02)
ON CONFLICT (profile_tier) DO NOTHING;

-- Create partitioned table for archive (monthly)
CREATE TABLE IF NOT EXISTS deepfake_audit_archive (LIKE deepfake_audit_logs INCLUDING ALL);
