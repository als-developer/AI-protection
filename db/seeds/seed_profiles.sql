-- Seed rate limit profiles and test data

INSERT INTO rate_limit_profiles (profile_tier, max_requests_per_minute, burst_capacity, price_per_request, concurrent_streams)
VALUES 
('free', 10, 15, 0.00, 1),
('developer', 200, 300, 0.05, 5),
('enterprise', 10000, 15000, 0.03, 50),
('ultra', 100000, 120000, 0.02, 500)
ON CONFLICT (profile_tier) DO NOTHING;

-- Insert test developer key (for development only)
-- DELETE FROM developer_api_keys WHERE developer_id = 'test_developer';
INSERT INTO developer_api_keys (api_key_hash, api_key_prefix, developer_id, developer_name, contact_email, account_balance_usd, rate_limit_tier)
VALUES (
    'test_hash_do_not_use_in_production',
    'sk_test',
    'test_developer',
    'Test Developer',
    'test@example.com',
    100.00,
    'developer'
) ON CONFLICT (developer_id) DO NOTHING;
