use actix_web::{web, HttpResponse, HttpRequest};
use sqlx::PgPool;
use uuid::Uuid;
use chrono::Utc;

use crate::{
    config::Config,
    models::{
        AppError, CreateSubscriptionRequest, Payment, Subscription, VerifyPaymentRequest,
        PaymentCurrency,
    },
    payments::PaymentProcessor,
    utils::{response, datetime, license, validation},
};

/// Configure payment routes
pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/payments")
            .route("/verify", web::post().to(verify_payment))
            .route("/subscribe", web::post().to(create_subscription))
            .route("/history", web::get().to(get_payment_history)),
    );
}

//+------------------------------------------------------------------+
//| Verify Payment Transaction                                       |
//+------------------------------------------------------------------+

async fn verify_payment(
    payment_processor: web::Data<PaymentProcessor>,
    req: web::Json<VerifyPaymentRequest>,
) -> Result<HttpResponse, AppError> {
    log::info!("Payment verification request: {}", req.transaction_hash);

    // Validate transaction hash format
    if !validation::is_valid_tx_hash(&req.transaction_hash) {
        return Ok(response::bad_request("Invalid transaction hash format"));
    }

    // Verify payment (check both USDT and USDC)
    // Try USDT first
    let verification = payment_processor
        .verify_payment(
            &req.transaction_hash,
            &req.network,
            &PaymentCurrency::USDT,
            9.0, // Minimum amount for starter tier
        )
        .await;

    let verification = match verification {
        Ok(v) => v,
        Err(_) => {
            // Try USDC if USDT verification failed
            payment_processor
                .verify_payment(
                    &req.transaction_hash,
                    &req.network,
                    &PaymentCurrency::USDC,
                    9.0,
                )
                .await?
        }
    };

    Ok(response::success(verification))
}

//+------------------------------------------------------------------+
//| Create Subscription with Payment                                |
//+------------------------------------------------------------------+

async fn create_subscription(
    pool: web::Data<PgPool>,
    payment_processor: web::Data<PaymentProcessor>,
    config: web::Data<Config>,
    http_req: HttpRequest,
    req: web::Json<CreateSubscriptionRequest>,
) -> Result<HttpResponse, AppError> {
    // Extract claims from JWT
    let claims = http_req
        .extensions()
        .get::<crate::models::Claims>()
        .cloned()
        .ok_or(AppError::Unauthorized)?;

    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::Unauthorized)?;

    log::info!(
        "Subscription creation request for user: {} (tier: {:?})",
        user_id,
        req.tier
    );

    // Validate transaction hash
    if !validation::is_valid_tx_hash(&req.payment_tx_hash) {
        return Ok(response::bad_request("Invalid transaction hash format"));
    }

    // Check if payment already processed
    let existing_payment = sqlx::query_as::<_, Payment>(
        "SELECT * FROM payments WHERE transaction_hash = $1"
    )
    .bind(&req.payment_tx_hash)
    .fetch_optional(pool.get_ref())
    .await?;

    if existing_payment.is_some() {
        return Ok(response::bad_request(
            "Payment already processed for this transaction",
        ));
    }

    // Determine expected amount based on tier
    let expected_amount = req.tier.price();
    let currency = PaymentCurrency::USDT; // Try USDT first

    // Verify payment
    let verification = payment_processor
        .verify_payment(
            &req.payment_tx_hash,
            &req.network,
            &currency,
            expected_amount,
        )
        .await
        .or_else(|_| {
            // Try USDC if USDT failed
            payment_processor.verify_payment(
                &req.payment_tx_hash,
                &req.network,
                &PaymentCurrency::USDC,
                expected_amount,
            )
        })?;

    log::info!(
        "Payment verified: {} {} from {}",
        verification.amount,
        verification.currency,
        verification.from_address
    );

    // Begin transaction
    let mut tx = pool.begin().await?;

    // Record payment
    let payment = sqlx::query_as::<_, Payment>(
        r#"
        INSERT INTO payments (
            user_id, amount, currency, network, transaction_hash,
            from_address, to_address, block_number, confirmations, status, verified_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'confirmed', NOW())
        RETURNING *
        "#,
    )
    .bind(user_id)
    .bind(verification.amount)
    .bind(&verification.currency)
    .bind(&verification.network)
    .bind(&verification.tx_hash)
    .bind(&verification.from_address)
    .bind(&verification.to_address)
    .bind(verification.block_number)
    .bind(verification.confirmations)
    .fetch_one(&mut *tx)
    .await?;

    // Create subscription (3 months = 90 days)
    let starts_at = Utc::now();
    let expires_at = datetime::add_quarterly_period(starts_at);

    let subscription = sqlx::query_as::<_, Subscription>(
        r#"
        INSERT INTO subscriptions (
            user_id, tier, status, price, currency, starts_at, expires_at, auto_renew
        )
        VALUES ($1, $2, 'active', $3, 'USD', $4, $5, TRUE)
        RETURNING *
        "#,
    )
    .bind(user_id)
    .bind(req.tier.as_str())
    .bind(expected_amount)
    .bind(starts_at)
    .bind(expires_at)
    .fetch_one(&mut *tx)
    .await?;

    // Update payment with subscription_id
    sqlx::query(
        "UPDATE payments SET subscription_id = $1 WHERE id = $2"
    )
    .bind(subscription.id)
    .bind(payment.id)
    .execute(&mut *tx)
    .await?;

    // Create license
    let license_key = license::generate_license_key();
    let max_api_calls = req.tier.max_api_calls();

    let license_record = sqlx::query(
        r#"
        INSERT INTO licenses (
            user_id, subscription_id, license_key, is_active, max_api_calls_per_day, api_calls_used_today
        )
        VALUES ($1, $2, $3, TRUE, $4, 0)
        "#,
    )
    .bind(user_id)
    .bind(subscription.id)
    .bind(&license_key)
    .bind(max_api_calls)
    .execute(&mut *tx)
    .await?;

    // Commit transaction
    tx.commit().await?;

    log::info!(
        "Subscription created successfully for user: {} (subscription_id: {}, license_key: {})",
        user_id,
        subscription.id,
        license_key
    );

    Ok(response::created(serde_json::json!({
        "subscription": subscription,
        "payment": payment,
        "license_key": license_key,
        "message": "Subscription activated successfully"
    })))
}

//+------------------------------------------------------------------+
//| Get Payment History                                              |
//+------------------------------------------------------------------+

async fn get_payment_history(
    pool: web::Data<PgPool>,
    http_req: HttpRequest,
) -> Result<HttpResponse, AppError> {
    // Extract claims from JWT
    let claims = http_req
        .extensions()
        .get::<crate::models::Claims>()
        .cloned()
        .ok_or(AppError::Unauthorized)?;

    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::Unauthorized)?;

    // Get all payments for user
    let payments = sqlx::query_as::<_, Payment>(
        r#"
        SELECT *
        FROM payments
        WHERE user_id = $1
        ORDER BY created_at DESC
        "#,
    )
    .bind(user_id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(response::success(payments))
}
