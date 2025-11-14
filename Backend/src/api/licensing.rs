use actix_web::{web, HttpResponse, HttpRequest};
use sqlx::PgPool;
use uuid::Uuid;
use chrono::Utc;

use crate::{
    config::Config,
    models::{AppError, License, LicenseValidationResponse, Subscription},
    utils::{response, datetime},
    cache::{Cache, helpers},
};

/// Configure licensing routes
pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/license")
            .route("/validate", web::get().to(validate_license))
            .route("/status", web::get().to(get_license_status)),
    );
}

//+------------------------------------------------------------------+
//| Validate License (X402 Protocol Core)                           |
//+------------------------------------------------------------------+

async fn validate_license(
    pool: web::Data<PgPool>,
    redis_client: web::Data<redis::Client>,
    config: web::Data<Config>,
    req: HttpRequest,
) -> Result<HttpResponse, AppError> {
    // Extract claims from JWT (set by auth middleware)
    let claims = req
        .extensions()
        .get::<crate::models::Claims>()
        .cloned()
        .ok_or(AppError::Unauthorized)?;

    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::Unauthorized)?;

    log::info!("License validation request for user: {}", user_id);

    // Try to get from cache first
    let cache_key = helpers::license_key(&user_id.to_string());
    let mut cache = Cache::new(&redis_client).await
        .map_err(|e| AppError::Internal(format!("Cache error: {}", e)))?;

    // Check cache
    if let Ok(Some(cached_response)) = cache.get::<LicenseValidationResponse>(&cache_key).await {
        log::debug!("License found in cache for user: {}", user_id);

        // Return cached response if not expired
        if !datetime::is_expired(cached_response.expires_at) {
            return Ok(response::success(cached_response));
        }
    }

    // Cache miss or expired - check database

    // Get active license
    let license = sqlx::query_as::<_, License>(
        r#"
        SELECT l.*
        FROM licenses l
        INNER JOIN subscriptions s ON l.subscription_id = s.id
        WHERE l.user_id = $1
        AND l.is_active = TRUE
        AND s.status = 'active'
        ORDER BY l.created_at DESC
        LIMIT 1
        "#,
    )
    .bind(user_id)
    .fetch_optional(pool.get_ref())
    .await?;

    let license = match license {
        Some(l) => l,
        None => {
            log::warn!("No active license found for user: {}", user_id);

            // Return X402 Payment Required response
            return Ok(response::payment_required(
                &config.x402_payment_uri,
                &config.x402_realm,
                config.subscription_starter_price,
            ));
        }
    };

    // Get subscription details
    let subscription = sqlx::query_as::<_, Subscription>(
        "SELECT * FROM subscriptions WHERE id = $1"
    )
    .bind(license.subscription_id)
    .fetch_one(pool.get_ref())
    .await?;

    // Check if subscription is expired
    if datetime::is_expired(subscription.expires_at) {
        log::warn!("License expired for user: {} (expired at: {})", user_id, subscription.expires_at);

        // Update subscription status
        sqlx::query(
            "UPDATE subscriptions SET status = 'expired' WHERE id = $1"
        )
        .bind(subscription.id)
        .execute(pool.get_ref())
        .await?;

        // Return X402 Payment Required with renewal URI
        let renewal_uri = format!("{}/renew?license={}", config.x402_payment_uri, license.id);
        return Ok(response::payment_required(
            &renewal_uri,
            &config.x402_realm,
            subscription.price,
        ));
    }

    // Check API rate limit
    let daily_calls_remaining = license.max_api_calls_per_day - license.api_calls_used_today;

    if daily_calls_remaining <= 0 {
        log::warn!("API rate limit exceeded for user: {}", user_id);

        let upgrade_uri = format!("{}/upgrade?user={}", config.x402_payment_uri, user_id);
        return Ok(response::payment_required(
            &upgrade_uri,
            &format!("{} - Rate Limit", config.x402_realm),
            0.01, // Micropayment for additional calls
        ));
    }

    // Increment API call counter
    sqlx::query(
        r#"
        UPDATE licenses
        SET api_calls_used_today = api_calls_used_today + 1,
            last_api_call_at = NOW(),
            last_validation_at = NOW()
        WHERE id = $1
        "#
    )
    .bind(license.id)
    .execute(pool.get_ref())
    .await?;

    // Build response
    let validation_response = LicenseValidationResponse {
        is_valid: true,
        user_id: license.user_id,
        tier: subscription.tier,
        credits_remaining: daily_calls_remaining - 1,
        expires_at: subscription.expires_at,
    };

    // Cache the response for 5 minutes
    cache.set(&cache_key, &validation_response, config.redis_cache_ttl as usize).await
        .map_err(|e| AppError::Internal(format!("Failed to cache license: {}", e)))?;

    log::info!("License validated successfully for user: {} (credits remaining: {})",
              user_id, daily_calls_remaining - 1);

    // Add custom headers
    Ok(HttpResponse::Ok()
        .insert_header(("X-Credits-Remaining", (daily_calls_remaining - 1).to_string()))
        .insert_header(("X-License-Tier", subscription.tier.clone()))
        .insert_header(("X-Expires-At", subscription.expires_at.to_rfc3339()))
        .json(crate::models::ApiResponse::success(validation_response)))
}

//+------------------------------------------------------------------+
//| Get License Status (detailed information)                       |
//+------------------------------------------------------------------+

async fn get_license_status(
    pool: web::Data<PgPool>,
    req: HttpRequest,
) -> Result<HttpResponse, AppError> {
    // Extract claims from JWT
    let claims = req
        .extensions()
        .get::<crate::models::Claims>()
        .cloned()
        .ok_or(AppError::Unauthorized)?;

    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::Unauthorized)?;

    // Get all licenses for user
    let licenses = sqlx::query_as::<_, License>(
        r#"
        SELECT l.*
        FROM licenses l
        WHERE l.user_id = $1
        ORDER BY l.created_at DESC
        "#,
    )
    .bind(user_id)
    .fetch_all(pool.get_ref())
    .await?;

    // Get all subscriptions
    let subscriptions = sqlx::query_as::<_, Subscription>(
        r#"
        SELECT *
        FROM subscriptions
        WHERE user_id = $1
        ORDER BY created_at DESC
        "#,
    )
    .bind(user_id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(response::success(serde_json::json!({
        "licenses": licenses,
        "subscriptions": subscriptions,
    })))
}
