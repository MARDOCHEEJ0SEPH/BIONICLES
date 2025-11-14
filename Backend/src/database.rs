use sqlx::{postgres::PgPoolOptions, PgPool, Error};

pub type DbPool = PgPool;

/// Create PostgreSQL connection pool
pub async fn create_pool(database_url: &str, max_connections: u32) -> Result<DbPool, Error> {
    log::info!("Creating database connection pool...");
    log::info!("Max connections: {}", max_connections);

    PgPoolOptions::new()
        .max_connections(max_connections)
        .connect(database_url)
        .await
}

/// Run database migrations
pub async fn run_migrations(pool: &DbPool) -> Result<(), Error> {
    log::info!("Running database migrations...");

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS users (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            email VARCHAR(255) UNIQUE NOT NULL,
            password_hash VARCHAR(255) NOT NULL,
            full_name VARCHAR(255),
            is_admin BOOLEAN DEFAULT FALSE,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );

        CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
        "#
    )
    .execute(pool)
    .await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS subscriptions (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            tier VARCHAR(50) NOT NULL CHECK (tier IN ('starter', 'professional', 'enterprise')),
            status VARCHAR(50) NOT NULL CHECK (status IN ('active', 'expired', 'cancelled', 'pending')),
            price DECIMAL(10, 2) NOT NULL,
            currency VARCHAR(10) DEFAULT 'USD',
            starts_at TIMESTAMPTZ NOT NULL,
            expires_at TIMESTAMPTZ NOT NULL,
            auto_renew BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );

        CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
        CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
        CREATE INDEX IF NOT EXISTS idx_subscriptions_expires_at ON subscriptions(expires_at);
        "#
    )
    .execute(pool)
    .await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS licenses (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
            license_key VARCHAR(255) UNIQUE NOT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            max_api_calls_per_day INTEGER NOT NULL,
            api_calls_used_today INTEGER DEFAULT 0,
            last_api_call_at TIMESTAMPTZ,
            last_validation_at TIMESTAMPTZ,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );

        CREATE INDEX IF NOT EXISTS idx_licenses_user_id ON licenses(user_id);
        CREATE INDEX IF NOT EXISTS idx_licenses_license_key ON licenses(license_key);
        CREATE INDEX IF NOT EXISTS idx_licenses_subscription_id ON licenses(subscription_id);
        "#
    )
    .execute(pool)
    .await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS payments (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
            amount DECIMAL(18, 6) NOT NULL,
            currency VARCHAR(10) NOT NULL CHECK (currency IN ('USDT', 'USDC')),
            network VARCHAR(20) NOT NULL CHECK (network IN ('ethereum', 'polygon')),
            transaction_hash VARCHAR(66) UNIQUE NOT NULL,
            from_address VARCHAR(42) NOT NULL,
            to_address VARCHAR(42) NOT NULL,
            block_number BIGINT,
            confirmations INTEGER DEFAULT 0,
            status VARCHAR(50) NOT NULL CHECK (status IN ('pending', 'confirmed', 'failed', 'refunded')),
            verified_at TIMESTAMPTZ,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );

        CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
        CREATE INDEX IF NOT EXISTS idx_payments_transaction_hash ON payments(transaction_hash);
        CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
        CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payments(created_at);
        "#
    )
    .execute(pool)
    .await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS api_logs (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID REFERENCES users(id) ON DELETE SET NULL,
            license_id UUID REFERENCES licenses(id) ON DELETE SET NULL,
            endpoint VARCHAR(255) NOT NULL,
            method VARCHAR(10) NOT NULL,
            status_code INTEGER NOT NULL,
            response_time_ms INTEGER,
            ip_address VARCHAR(45),
            user_agent TEXT,
            request_id UUID,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );

        CREATE INDEX IF NOT EXISTS idx_api_logs_user_id ON api_logs(user_id);
        CREATE INDEX IF NOT EXISTS idx_api_logs_created_at ON api_logs(created_at);
        CREATE INDEX IF NOT EXISTS idx_api_logs_endpoint ON api_logs(endpoint);
        "#
    )
    .execute(pool)
    .await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS trade_logs (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            ticket BIGINT NOT NULL,
            symbol VARCHAR(20) NOT NULL,
            trade_type VARCHAR(10) NOT NULL CHECK (trade_type IN ('BUY', 'SELL')),
            lots DECIMAL(10, 2) NOT NULL,
            entry_price DECIMAL(18, 5) NOT NULL,
            stop_loss DECIMAL(18, 5),
            take_profit DECIMAL(18, 5),
            entry_time TIMESTAMPTZ NOT NULL,
            exit_time TIMESTAMPTZ,
            exit_price DECIMAL(18, 5),
            profit_usd DECIMAL(18, 2),
            profit_pips DECIMAL(18, 2),
            is_win BOOLEAN,
            exit_reason VARCHAR(100),
            created_at TIMESTAMPTZ DEFAULT NOW()
        );

        CREATE INDEX IF NOT EXISTS idx_trade_logs_user_id ON trade_logs(user_id);
        CREATE INDEX IF NOT EXISTS idx_trade_logs_entry_time ON trade_logs(entry_time);
        CREATE INDEX IF NOT EXISTS idx_trade_logs_symbol ON trade_logs(symbol);
        "#
    )
    .execute(pool)
    .await?;

    log::info!("Database migrations completed successfully");

    Ok(())
}
