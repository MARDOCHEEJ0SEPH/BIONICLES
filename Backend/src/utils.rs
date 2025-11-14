use crate::models::{Claims, AppError};
use chrono::{Utc, Duration};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use uuid::Uuid;

//+------------------------------------------------------------------+
//| JWT Token Management                                             |
//+------------------------------------------------------------------+

pub mod jwt {
    use super::*;

    /// Generate JWT token
    pub fn generate_token(
        user_id: Uuid,
        email: &str,
        is_admin: bool,
        secret: &str,
        expiration_hours: i64,
    ) -> Result<String, AppError> {
        let now = Utc::now();
        let exp = (now + Duration::hours(expiration_hours)).timestamp();

        let claims = Claims {
            sub: user_id.to_string(),
            email: email.to_string(),
            is_admin,
            exp,
            iat: now.timestamp(),
        };

        encode(
            &Header::default(),
            &claims,
            &EncodingKey::from_secret(secret.as_bytes()),
        )
        .map_err(|e| AppError::Internal(format!("Failed to generate token: {}", e)))
    }

    /// Validate JWT token
    pub fn validate_token(token: &str, secret: &str) -> Result<Claims, AppError> {
        decode::<Claims>(
            token,
            &DecodingKey::from_secret(secret.as_bytes()),
            &Validation::default(),
        )
        .map(|data| data.claims)
        .map_err(|_| AppError::Unauthorized)
    }

    /// Extract bearer token from Authorization header
    pub fn extract_bearer_token(auth_header: Option<&str>) -> Result<String, AppError> {
        auth_header
            .and_then(|h| h.strip_prefix("Bearer "))
            .map(|t| t.to_string())
            .ok_or(AppError::Unauthorized)
    }
}

//+------------------------------------------------------------------+
//| Password Hashing                                                 |
//+------------------------------------------------------------------+

pub mod password {
    use super::*;
    use bcrypt::{hash, verify, DEFAULT_COST};

    /// Hash password using bcrypt
    pub fn hash_password(password: &str) -> Result<String, AppError> {
        hash(password, DEFAULT_COST)
            .map_err(|e| AppError::Internal(format!("Failed to hash password: {}", e)))
    }

    /// Verify password against hash
    pub fn verify_password(password: &str, hash: &str) -> Result<bool, AppError> {
        verify(password, hash)
            .map_err(|e| AppError::Internal(format!("Failed to verify password: {}", e)))
    }
}

//+------------------------------------------------------------------+
//| License Key Generation                                           |
//+------------------------------------------------------------------+

pub mod license {
    use super::*;
    use rand::Rng;

    /// Generate license key in format: XXXX-XXXX-XXXX-XXXX
    pub fn generate_license_key() -> String {
        let mut rng = rand::thread_rng();
        let chars: Vec<char> = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".chars().collect();

        let parts: Vec<String> = (0..4)
            .map(|_| {
                (0..4)
                    .map(|_| chars[rng.gen_range(0..chars.len())])
                    .collect()
            })
            .collect();

        parts.join("-")
    }
}

//+------------------------------------------------------------------+
//| Validation Helpers                                               |
//+------------------------------------------------------------------+

pub mod validation {
    use regex::Regex;

    /// Validate email format
    pub fn is_valid_email(email: &str) -> bool {
        let email_regex = Regex::new(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").unwrap();
        email_regex.is_match(email)
    }

    /// Validate password strength (min 8 chars, 1 uppercase, 1 lowercase, 1 number)
    pub fn is_strong_password(password: &str) -> bool {
        if password.len() < 8 {
            return false;
        }

        let has_uppercase = password.chars().any(|c| c.is_uppercase());
        let has_lowercase = password.chars().any(|c| c.is_lowercase());
        let has_digit = password.chars().any(|c| c.is_numeric());

        has_uppercase && has_lowercase && has_digit
    }

    /// Validate Ethereum address format (0x + 40 hex chars)
    pub fn is_valid_eth_address(address: &str) -> bool {
        if !address.starts_with("0x") {
            return false;
        }

        if address.len() != 42 {
            return false;
        }

        address[2..].chars().all(|c| c.is_ascii_hexdigit())
    }

    /// Validate transaction hash format (0x + 64 hex chars)
    pub fn is_valid_tx_hash(tx_hash: &str) -> bool {
        if !tx_hash.starts_with("0x") {
            return false;
        }

        if tx_hash.len() != 66 {
            return false;
        }

        tx_hash[2..].chars().all(|c| c.is_ascii_hexdigit())
    }
}

//+------------------------------------------------------------------+
//| Date/Time Helpers                                                |
//+------------------------------------------------------------------+

pub mod datetime {
    use chrono::{DateTime, Utc, Duration};

    /// Get current UTC timestamp
    pub fn now() -> DateTime<Utc> {
        Utc::now()
    }

    /// Add 3 months (quarterly subscription)
    pub fn add_quarterly_period(from: DateTime<Utc>) -> DateTime<Utc> {
        from + Duration::days(90)
    }

    /// Check if date is in the past
    pub fn is_expired(date: DateTime<Utc>) -> bool {
        date < Utc::now()
    }

    /// Days until expiration
    pub fn days_until_expiration(date: DateTime<Utc>) -> i64 {
        (date - Utc::now()).num_days()
    }
}

//+------------------------------------------------------------------+
//| Response Builders                                                |
//+------------------------------------------------------------------+

pub mod response {
    use actix_web::HttpResponse;
    use crate::models::ApiResponse;

    pub fn success<T: serde::Serialize>(data: T) -> HttpResponse {
        HttpResponse::Ok().json(ApiResponse::success(data))
    }

    pub fn created<T: serde::Serialize>(data: T) -> HttpResponse {
        HttpResponse::Created().json(ApiResponse::success(data))
    }

    pub fn bad_request(message: &str) -> HttpResponse {
        HttpResponse::BadRequest().json(ApiResponse::<()>::error(message.to_string()))
    }

    pub fn unauthorized(message: &str) -> HttpResponse {
        HttpResponse::Unauthorized().json(ApiResponse::<()>::error(message.to_string()))
    }

    pub fn payment_required(payment_uri: &str, realm: &str, amount: f64) -> HttpResponse {
        HttpResponse::PaymentRequired()
            .insert_header((
                "WWW-Authenticate",
                format!(
                    "Bearer realm=\"{}\", payment_uri=\"{}\", amount=\"{} USD\"",
                    realm, payment_uri, amount
                ),
            ))
            .insert_header(("Payment-URI", payment_uri))
            .json(serde_json::json!({
                "error": "payment_required",
                "message": "Active subscription required to access this resource",
                "payment_uri": payment_uri,
                "amount": amount,
                "currency": "USD",
                "accepted_methods": ["USDT", "USDC"],
                "accepted_networks": ["ethereum", "polygon"]
            }))
    }

    pub fn internal_error(message: &str) -> HttpResponse {
        HttpResponse::InternalServerError().json(ApiResponse::<()>::error(message.to_string()))
    }
}
