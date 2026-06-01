-- Generate test data for development and testing

-- Generate 10,000 test audit logs
INSERT INTO deepfake_audit_logs (audit_id, client_id, media_type, fraud_risk_score, verdict, frequency_delta, created_at)
SELECT 
    'test_' || generate_series,
    'crdb_hq_main',
    'audio_stream',
    random() * 100,
    CASE WHEN random() > 0.95 THEN 'CRITICAL_SUSPECTED_DEEPFAKE' ELSE 'VERIFIED_HUMAN_AUTHENTIC' END,
    random() * 0.5,
    NOW() - (random() * interval '30 days')
FROM generate_series(1, 10000);

-- Generate test channel telemetry
INSERT INTO deepfake_channel_telemetry (audit_id, channel_index, calculated_variance, is_anomaly)
SELECT 
    'test_' || (random() * 10000)::INT,
    (random() * 7)::INT,
    random() * 0.2,
    random() > 0.9
FROM generate_series(1, 50000);
