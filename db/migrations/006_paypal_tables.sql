-- PayPal Integration Tables for BioShield Ultimate

-- Payment orders table
CREATE TABLE IF NOT EXISTS payment_orders (
    id SERIAL PRIMARY KEY,
    order_id VARCHAR(100) UNIQUE NOT NULL,
    client_id VARCHAR(100),
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    status VARCHAR(20) DEFAULT 'PENDING',
    transaction_id VARCHAR(100),
    paypal_order_id VARCHAR(100),
    description TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    failed_at TIMESTAMP,
    refunded_at TIMESTAMP,
    webhook_verified BOOLEAN DEFAULT FALSE
);

-- Indexes for fast lookups
CREATE INDEX idx_payment_orders_client ON payment_orders(client_id);
CREATE INDEX idx_payment_orders_status ON payment_orders(status);
CREATE INDEX idx_payment_orders_created ON payment_orders(created_at DESC);
CREATE INDEX idx_payment_orders_transaction ON payment_orders(transaction_id);

-- Transactions history table
CREATE TABLE IF NOT EXISTS payment_transactions (
    id SERIAL PRIMARY KEY,
    transaction_id VARCHAR(100) UNIQUE NOT NULL,
    order_id VARCHAR(100) REFERENCES payment_orders(order_id),
    client_id VARCHAR(100),
    transaction_type VARCHAR(20), -- 'payment', 'refund', 'chargeback'
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    status VARCHAR(20),
    paypal_response JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_transactions_client ON payment_transactions(client_id);
CREATE INDEX idx_transactions_order ON payment_transactions(order_id);

-- Subscription plans table
CREATE TABLE IF NOT EXISTS subscription_plans (
    id SERIAL PRIMARY KEY,
    plan_id VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    monthly_price DECIMAL(10,2),
    yearly_price DECIMAL(10,2),
    credits_per_month INTEGER,
    features JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    paypal_plan_id VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default plans
INSERT INTO subscription_plans (plan_id, name, description, monthly_price, yearly_price, credits_per_month, features) VALUES
('free', 'Free', 'Basic protection for small businesses', 0, 0, 1000, '{"support": "email", "rate_limit": 1000, "channels": 1}'),
('starter', 'Starter', 'Essential protection for growing businesses', 49, 499, 10000, '{"support": "email+chat", "rate_limit": 5000, "channels": 5}'),
('professional', 'Professional', 'Advanced protection for enterprises', 199, 1999, 50000, '{"support": "24/7", "rate_limit": 25000, "channels": 20}'),
('enterprise', 'Enterprise', 'Complete protection for large organizations', 999, 9999, 250000, '{"support": "dedicated", "rate_limit": 100000, "channels": 100}')
ON CONFLICT (plan_id) DO NOTHING;

-- Client subscriptions table
CREATE TABLE IF NOT EXISTS client_subscriptions (
    id SERIAL PRIMARY KEY,
    client_id VARCHAR(100) NOT NULL,
    plan_id VARCHAR(50) REFERENCES subscription_plans(plan_id),
    status VARCHAR(20) DEFAULT 'active', -- 'active', 'canceled', 'expired'
    paypal_subscription_id VARCHAR(100),
    current_period_start TIMESTAMP,
    current_period_end TIMESTAMP,
    canceled_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_subscriptions_client ON client_subscriptions(client_id);
CREATE INDEX idx_subscriptions_status ON client_subscriptions(status);
