use std::env;

#[derive(Debug, Clone)]
pub struct Config {
    // Server
    pub server_host: String,
    pub server_port: u16,

    // Database
    pub database_url: String,
    pub database_max_connections: u32,

    // Redis
    pub redis_url: String,
    pub redis_cache_ttl: u64,

    // JWT
    pub jwt_secret: String,
    pub jwt_expiration_hours: i64,

    // Ethereum
    pub ethereum_rpc_url: String,
    pub ethereum_chain_id: u64,

    // Polygon
    pub polygon_rpc_url: String,
    pub polygon_chain_id: u64,

    // USDT Contract Addresses
    pub usdt_ethereum_address: String,
    pub usdt_polygon_address: String,

    // USDC Contract Addresses
    pub usdc_ethereum_address: String,
    pub usdc_polygon_address: String,

    // Payment Wallet
    pub payment_wallet_address: String,
    pub payment_wallet_private_key: String,

    // X402 Protocol
    pub x402_realm: String,
    pub x402_payment_uri: String,

    // Subscription Pricing
    pub subscription_starter_price: f64,
    pub subscription_professional_price: f64,

    // API Rate Limits
    pub rate_limit_starter: u32,
    pub rate_limit_professional: u32,

    // Admin
    pub admin_email: String,
    pub admin_password: String,

    // Security
    pub bcrypt_cost: u32,

    // CORS
    pub cors_allowed_origins: String,

    // Test Mode
    pub test_mode: bool,
}

impl Config {
    pub fn from_env() -> Result<Self, env::VarError> {
        Ok(Config {
            // Server
            server_host: env::var("SERVER_HOST")
                .unwrap_or_else(|_| "0.0.0.0".to_string()),
            server_port: env::var("SERVER_PORT")
                .unwrap_or_else(|_| "8080".to_string())
                .parse()
                .unwrap_or(8080),

            // Database
            database_url: env::var("DATABASE_URL")?,
            database_max_connections: env::var("DATABASE_MAX_CONNECTIONS")
                .unwrap_or_else(|_| "10".to_string())
                .parse()
                .unwrap_or(10),

            // Redis
            redis_url: env::var("REDIS_URL")
                .unwrap_or_else(|_| "redis://localhost:6379".to_string()),
            redis_cache_ttl: env::var("REDIS_CACHE_TTL")
                .unwrap_or_else(|_| "300".to_string())
                .parse()
                .unwrap_or(300),

            // JWT
            jwt_secret: env::var("JWT_SECRET")?,
            jwt_expiration_hours: env::var("JWT_EXPIRATION_HOURS")
                .unwrap_or_else(|_| "24".to_string())
                .parse()
                .unwrap_or(24),

            // Ethereum
            ethereum_rpc_url: env::var("ETHEREUM_RPC_URL")?,
            ethereum_chain_id: env::var("ETHEREUM_CHAIN_ID")
                .unwrap_or_else(|_| "1".to_string())
                .parse()
                .unwrap_or(1),

            // Polygon
            polygon_rpc_url: env::var("POLYGON_RPC_URL")?,
            polygon_chain_id: env::var("POLYGON_CHAIN_ID")
                .unwrap_or_else(|_| "137".to_string())
                .parse()
                .unwrap_or(137),

            // USDT Contracts
            usdt_ethereum_address: env::var("USDT_ETHEREUM_ADDRESS")?,
            usdt_polygon_address: env::var("USDT_POLYGON_ADDRESS")?,

            // USDC Contracts
            usdc_ethereum_address: env::var("USDC_ETHEREUM_ADDRESS")?,
            usdc_polygon_address: env::var("USDC_POLYGON_ADDRESS")?,

            // Payment Wallet
            payment_wallet_address: env::var("PAYMENT_WALLET_ADDRESS")?,
            payment_wallet_private_key: env::var("PAYMENT_WALLET_PRIVATE_KEY")?,

            // X402
            x402_realm: env::var("X402_REALM")
                .unwrap_or_else(|_| "BIONICLES Trading API".to_string()),
            x402_payment_uri: env::var("X402_PAYMENT_URI")
                .unwrap_or_else(|_| "https://bionicles.io/subscribe".to_string()),

            // Pricing
            subscription_starter_price: env::var("SUBSCRIPTION_STARTER_PRICE")
                .unwrap_or_else(|_| "9.00".to_string())
                .parse()
                .unwrap_or(9.00),
            subscription_professional_price: env::var("SUBSCRIPTION_PROFESSIONAL_PRICE")
                .unwrap_or_else(|_| "29.00".to_string())
                .parse()
                .unwrap_or(29.00),

            // Rate Limits
            rate_limit_starter: env::var("RATE_LIMIT_STARTER")
                .unwrap_or_else(|_| "1000".to_string())
                .parse()
                .unwrap_or(1000),
            rate_limit_professional: env::var("RATE_LIMIT_PROFESSIONAL")
                .unwrap_or_else(|_| "10000".to_string())
                .parse()
                .unwrap_or(10000),

            // Admin
            admin_email: env::var("ADMIN_EMAIL")
                .unwrap_or_else(|_| "admin@bionicles.io".to_string()),
            admin_password: env::var("ADMIN_PASSWORD")
                .unwrap_or_else(|_| "changeme".to_string()),

            // Security
            bcrypt_cost: env::var("BCRYPT_COST")
                .unwrap_or_else(|_| "12".to_string())
                .parse()
                .unwrap_or(12),

            // CORS
            cors_allowed_origins: env::var("CORS_ALLOWED_ORIGINS")
                .unwrap_or_else(|_| "http://localhost:3000".to_string()),

            // Test Mode
            test_mode: env::var("TEST_MODE")
                .unwrap_or_else(|_| "false".to_string())
                .parse()
                .unwrap_or(false),
        })
    }
}
