//+------------------------------------------------------------------+
//|                        X402 Payment Protocol                      |
//|                                                                  |
//| HTTP 402 Payment Required - Protocol Implementation             |
//+------------------------------------------------------------------+

/*!
# X402 Payment Protocol

The X402 protocol uses HTTP status code 402 (Payment Required) to implement
a subscription-based API access model with cryptocurrency payments.

## Protocol Flow

1. **Client Request**: Client makes API request with Bearer token
2. **Token Validation**: Server validates JWT token
3. **License Check**: Server checks if user has active subscription
4. **Payment Required**: If no valid license, return 402 with payment URI
5. **Payment Processing**: User pays with USDT/USDC on Ethereum/Polygon
6. **License Activation**: Server verifies payment and activates license
7. **Access Granted**: Client can now access API with valid license

## Response Format

### 200 OK - Valid License
```json
{
  "success": true,
  "data": {
    "is_valid": true,
    "user_id": "uuid",
    "tier": "professional",
    "credits_remaining": 9999,
    "expires_at": "2024-12-31T23:59:59Z"
  }
}
```

### 402 Payment Required - No License
```http
HTTP/1.1 402 Payment Required
WWW-Authenticate: Bearer realm="BIONICLES Trading API", payment_uri="https://bionicles.io/subscribe", amount="9.00 USD"
Payment-URI: https://bionicles.io/subscribe

{
  "error": "payment_required",
  "message": "Active subscription required to access this resource",
  "payment_uri": "https://bionicles.io/subscribe",
  "amount": 9.00,
  "currency": "USD",
  "accepted_methods": ["USDT", "USDC"],
  "accepted_networks": ["ethereum", "polygon"]
}
```

### 402 Payment Required - Expired License
```http
HTTP/1.1 402 Payment Required
WWW-Authenticate: Bearer realm="BIONICLES Trading API", payment_uri="https://bionicles.io/renew?license=uuid", amount="9.00 USD"
Payment-URI: https://bionicles.io/renew?license=uuid

{
  "error": "payment_required",
  "message": "Subscription expired. Please renew to continue access.",
  "payment_uri": "https://bionicles.io/renew?license=uuid",
  "amount": 9.00,
  "currency": "USD"
}
```

### 402 Payment Required - Rate Limit
```http
HTTP/1.1 402 Payment Required
WWW-Authenticate: Bearer realm="BIONICLES Trading API - Rate Limit", payment_uri="https://bionicles.io/upgrade?user=uuid", amount="0.01 USD"

{
  "error": "payment_required",
  "message": "Daily API limit exceeded. Upgrade for more calls.",
  "payment_uri": "https://bionicles.io/upgrade?user=uuid",
  "amount": 0.01,
  "currency": "USD"
}
```

## Payment Methods

- **USDT** (Tether) on Ethereum mainnet
- **USDT** (Tether) on Polygon mainnet
- **USDC** (USD Coin) on Ethereum mainnet
- **USDC** (USD Coin) on Polygon mainnet

## Subscription Tiers

| Tier | Price | API Calls/Day | Features |
|------|-------|---------------|----------|
| Starter | $9/quarter | 1,000 | Basic analytics, Live trading |
| Professional | $29/quarter | 10,000 | Advanced analytics, API access, Alerts |
| Enterprise | Custom | Unlimited | White-label, Dedicated support |

## Implementation Notes

- All subscriptions are **quarterly** (3 months = 90 days)
- Payments verified on-chain before activation
- License keys generated automatically after payment
- Rate limits reset daily at 00:00 UTC
- JWT tokens expire after 24 hours
- License validation cached for 5 minutes

*/

use actix_web::HttpResponse;
use serde_json::json;

/// Build X402 Payment Required response
pub fn payment_required_response(
    payment_uri: &str,
    realm: &str,
    amount: f64,
    currency: &str,
) -> HttpResponse {
    HttpResponse::PaymentRequired()
        .insert_header((
            "WWW-Authenticate",
            format!(
                "Bearer realm=\"{}\", payment_uri=\"{}\", amount=\"{} {}\"",
                realm, payment_uri, amount, currency
            ),
        ))
        .insert_header(("Payment-URI", payment_uri))
        .insert_header(("X-Payment-Amount", amount.to_string()))
        .insert_header(("X-Payment-Currency", currency))
        .json(json!({
            "error": "payment_required",
            "message": "Active subscription required to access this resource",
            "payment_uri": payment_uri,
            "amount": amount,
            "currency": currency,
            "accepted_methods": ["USDT", "USDC"],
            "accepted_networks": ["ethereum", "polygon"],
            "subscription_info": {
                "starter": {
                    "price": 9.0,
                    "period": "quarterly",
                    "api_calls_per_day": 1000,
                    "features": ["Basic analytics", "Live trading"]
                },
                "professional": {
                    "price": 29.0,
                    "period": "quarterly",
                    "api_calls_per_day": 10000,
                    "features": ["Advanced analytics", "API access", "Alerts"]
                }
            }
        }))
}

/// Build success response with license details
pub fn license_valid_response(
    user_id: uuid::Uuid,
    tier: &str,
    credits_remaining: i32,
    expires_at: chrono::DateTime<chrono::Utc>,
) -> HttpResponse {
    HttpResponse::Ok()
        .insert_header(("X-License-Valid", "true"))
        .insert_header(("X-License-Tier", tier))
        .insert_header(("X-Credits-Remaining", credits_remaining.to_string()))
        .insert_header(("X-Expires-At", expires_at.to_rfc3339()))
        .json(crate::models::ApiResponse::success(json!({
            "is_valid": true,
            "user_id": user_id,
            "tier": tier,
            "credits_remaining": credits_remaining,
            "expires_at": expires_at,
        })))
}

/// Check if error should return 402
pub fn should_return_402(error_type: &str) -> bool {
    matches!(
        error_type,
        "no_license" | "expired_license" | "rate_limit_exceeded"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_payment_required_response() {
        let response = payment_required_response(
            "https://bionicles.io/subscribe",
            "BIONICLES API",
            9.0,
            "USD",
        );

        assert_eq!(response.status(), actix_web::http::StatusCode::PAYMENT_REQUIRED);
    }

    #[test]
    fn test_should_return_402() {
        assert!(should_return_402("no_license"));
        assert!(should_return_402("expired_license"));
        assert!(should_return_402("rate_limit_exceeded"));
        assert!(!should_return_402("invalid_token"));
    }
}
