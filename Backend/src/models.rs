use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

//+------------------------------------------------------------------+
//| User Models                                                       |
//+------------------------------------------------------------------+

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct User {
    pub id: Uuid,
    pub email: String,
    #[serde(skip_serializing)]
    pub password_hash: String,
    pub full_name: Option<String>,
    pub is_admin: bool,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct RegisterRequest {
    pub email: String,
    pub password: String,
    pub full_name: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
}

#[derive(Debug, Serialize)]
pub struct AuthResponse {
    pub token: String,
    pub user: UserResponse,
    pub expires_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct UserResponse {
    pub id: Uuid,
    pub email: String,
    pub full_name: Option<String>,
    pub is_admin: bool,
    pub created_at: DateTime<Utc>,
}

impl From<User> for UserResponse {
    fn from(user: User) -> Self {
        UserResponse {
            id: user.id,
            email: user.email,
            full_name: user.full_name,
            is_admin: user.is_admin,
            created_at: user.created_at,
        }
    }
}

//+------------------------------------------------------------------+
//| Subscription Models                                              |
//+------------------------------------------------------------------+

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Subscription {
    pub id: Uuid,
    pub user_id: Uuid,
    pub tier: String,
    pub status: String,
    pub price: f64,
    pub currency: String,
    pub starts_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
    pub auto_renew: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct CreateSubscriptionRequest {
    pub tier: SubscriptionTier,
    pub payment_tx_hash: String,
    pub network: PaymentNetwork,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum SubscriptionTier {
    Starter,
    Professional,
    Enterprise,
}

impl SubscriptionTier {
    pub fn as_str(&self) -> &str {
        match self {
            SubscriptionTier::Starter => "starter",
            SubscriptionTier::Professional => "professional",
            SubscriptionTier::Enterprise => "enterprise",
        }
    }

    pub fn max_api_calls(&self) -> i32 {
        match self {
            SubscriptionTier::Starter => 1000,
            SubscriptionTier::Professional => 10000,
            SubscriptionTier::Enterprise => 999999,
        }
    }

    pub fn price(&self) -> f64 {
        match self {
            SubscriptionTier::Starter => 9.0,
            SubscriptionTier::Professional => 29.0,
            SubscriptionTier::Enterprise => 0.0, // Custom pricing
        }
    }
}

//+------------------------------------------------------------------+
//| License Models                                                   |
//+------------------------------------------------------------------+

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct License {
    pub id: Uuid,
    pub user_id: Uuid,
    pub subscription_id: Uuid,
    pub license_key: String,
    pub is_active: bool,
    pub max_api_calls_per_day: i32,
    pub api_calls_used_today: i32,
    pub last_api_call_at: Option<DateTime<Utc>>,
    pub last_validation_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct LicenseValidationResponse {
    pub is_valid: bool,
    pub user_id: Uuid,
    pub tier: String,
    pub credits_remaining: i32,
    pub expires_at: DateTime<Utc>,
}

//+------------------------------------------------------------------+
//| Payment Models                                                   |
//+------------------------------------------------------------------+

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Payment {
    pub id: Uuid,
    pub user_id: Uuid,
    pub subscription_id: Option<Uuid>,
    pub amount: f64,
    pub currency: String,
    pub network: String,
    pub transaction_hash: String,
    pub from_address: String,
    pub to_address: String,
    pub block_number: Option<i64>,
    pub confirmations: i32,
    pub status: String,
    pub verified_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum PaymentCurrency {
    USDT,
    USDC,
}

impl PaymentCurrency {
    pub fn as_str(&self) -> &str {
        match self {
            PaymentCurrency::USDT => "USDT",
            PaymentCurrency::USDC => "USDC",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum PaymentNetwork {
    Ethereum,
    Polygon,
}

impl PaymentNetwork {
    pub fn as_str(&self) -> &str {
        match self {
            PaymentNetwork::Ethereum => "ethereum",
            PaymentNetwork::Polygon => "polygon",
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct VerifyPaymentRequest {
    pub transaction_hash: String,
    pub network: PaymentNetwork,
}

//+------------------------------------------------------------------+
//| Trade Log Models                                                 |
//+------------------------------------------------------------------+

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct TradeLog {
    pub id: Uuid,
    pub user_id: Uuid,
    pub ticket: i64,
    pub symbol: String,
    pub trade_type: String,
    pub lots: f64,
    pub entry_price: f64,
    pub stop_loss: Option<f64>,
    pub take_profit: Option<f64>,
    pub entry_time: DateTime<Utc>,
    pub exit_time: Option<DateTime<Utc>>,
    pub exit_price: Option<f64>,
    pub profit_usd: Option<f64>,
    pub profit_pips: Option<f64>,
    pub is_win: Option<bool>,
    pub exit_reason: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct LogTradeRequest {
    pub ticket: i64,
    pub symbol: String,
    pub trade_type: String,
    pub lots: f64,
    pub entry_price: f64,
    pub stop_loss: Option<f64>,
    pub take_profit: Option<f64>,
}

//+------------------------------------------------------------------+
//| JWT Claims                                                       |
//+------------------------------------------------------------------+

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,      // User ID
    pub email: String,
    pub is_admin: bool,
    pub exp: i64,         // Expiration timestamp
    pub iat: i64,         // Issued at timestamp
}

//+------------------------------------------------------------------+
//| API Response Models                                              |
//+------------------------------------------------------------------+

#[derive(Debug, Serialize)]
pub struct ApiResponse<T> {
    pub success: bool,
    pub data: Option<T>,
    pub error: Option<String>,
    pub timestamp: DateTime<Utc>,
}

impl<T> ApiResponse<T> {
    pub fn success(data: T) -> Self {
        ApiResponse {
            success: true,
            data: Some(data),
            error: None,
            timestamp: Utc::now(),
        }
    }

    pub fn error(message: String) -> ApiResponse<()> {
        ApiResponse {
            success: false,
            data: None,
            error: Some(message),
            timestamp: Utc::now(),
        }
    }
}

//+------------------------------------------------------------------+
//| Error Types                                                      |
//+------------------------------------------------------------------+

#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("Database error: {0}")]
    Database(#[from] sqlx::Error),

    #[error("Redis error: {0}")]
    Redis(#[from] redis::RedisError),

    #[error("Unauthorized")]
    Unauthorized,

    #[error("Payment required")]
    PaymentRequired,

    #[error("Invalid credentials")]
    InvalidCredentials,

    #[error("User not found")]
    UserNotFound,

    #[error("License not found")]
    LicenseNotFound,

    #[error("Invalid license")]
    InvalidLicense,

    #[error("License expired")]
    LicenseExpired,

    #[error("Rate limit exceeded")]
    RateLimitExceeded,

    #[error("Payment verification failed: {0}")]
    PaymentVerificationFailed(String),

    #[error("Internal server error: {0}")]
    Internal(String),
}

impl actix_web::ResponseError for AppError {
    fn error_response(&self) -> actix_web::HttpResponse {
        use actix_web::http::StatusCode;

        let status = match self {
            AppError::Unauthorized => StatusCode::UNAUTHORIZED,
            AppError::PaymentRequired => StatusCode::PAYMENT_REQUIRED,
            AppError::InvalidCredentials => StatusCode::UNAUTHORIZED,
            AppError::UserNotFound => StatusCode::NOT_FOUND,
            AppError::LicenseNotFound => StatusCode::NOT_FOUND,
            AppError::InvalidLicense => StatusCode::FORBIDDEN,
            AppError::LicenseExpired => StatusCode::PAYMENT_REQUIRED,
            AppError::RateLimitExceeded => StatusCode::TOO_MANY_REQUESTS,
            AppError::PaymentVerificationFailed(_) => StatusCode::BAD_REQUEST,
            _ => StatusCode::INTERNAL_SERVER_ERROR,
        };

        actix_web::HttpResponse::build(status).json(ApiResponse::<()>::error(self.to_string()))
    }
}
