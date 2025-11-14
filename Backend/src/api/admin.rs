use actix_web::{web, HttpResponse, HttpRequest};
use sqlx::PgPool;
use uuid::Uuid;

use crate::{
    models::{AppError, User, Subscription, License, Payment, TradeLog},
    utils::response,
};

/// Configure admin routes (requires admin middleware)
pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/admin")
            .route("/users", web::get().to(get_all_users))
            .route("/users/{user_id}", web::get().to(get_user_details))
            .route("/users/{user_id}/activate", web::post().to(activate_user))
            .route("/users/{user_id}/deactivate", web::post().to(deactivate_user))
            .route("/subscriptions", web::get().to(get_all_subscriptions))
            .route("/subscriptions/{subscription_id}", web::get().to(get_subscription_details))
            .route("/payments", web::get().to(get_all_payments))
            .route("/stats", web::get().to(get_system_stats)),
    );
}

//+------------------------------------------------------------------+
//| Get All Users                                                    |
//+------------------------------------------------------------------+

async fn get_all_users(
    pool: web::Data<PgPool>,
    http_req: HttpRequest,
) -> Result<HttpResponse, AppError> {
    // Check admin permission (middleware should handle this, but double check)
    verify_admin(&http_req)?;

    let users = sqlx::query_as::<_, User>(
        "SELECT * FROM users ORDER BY created_at DESC"
    )
    .fetch_all(pool.get_ref())
    .await?;

    Ok(response::success(users))
}

//+------------------------------------------------------------------+
//| Get User Details                                                 |
//+------------------------------------------------------------------+

async fn get_user_details(
    pool: web::Data<PgPool>,
    http_req: HttpRequest,
    path: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    verify_admin(&http_req)?;

    let user_id = path.into_inner();

    // Get user
    let user = sqlx::query_as::<_, User>(
        "SELECT * FROM users WHERE id = $1"
    )
    .bind(user_id)
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or(AppError::UserNotFound)?;

    // Get subscriptions
    let subscriptions = sqlx::query_as::<_, Subscription>(
        "SELECT * FROM subscriptions WHERE user_id = $1 ORDER BY created_at DESC"
    )
    .bind(user_id)
    .fetch_all(pool.get_ref())
    .await?;

    // Get licenses
    let licenses = sqlx::query_as::<_, License>(
        "SELECT * FROM licenses WHERE user_id = $1 ORDER BY created_at DESC"
    )
    .bind(user_id)
    .fetch_all(pool.get_ref())
    .await?;

    // Get payments
    let payments = sqlx::query_as::<_, Payment>(
        "SELECT * FROM payments WHERE user_id = $1 ORDER BY created_at DESC"
    )
    .bind(user_id)
    .fetch_all(pool.get_ref())
    .await?;

    // Get trade count
    let trade_count = sqlx::query_scalar::<_, i64>(
        "SELECT COUNT(*) FROM trade_logs WHERE user_id = $1"
    )
    .bind(user_id)
    .fetch_one(pool.get_ref())
    .await
    .unwrap_or(0);

    Ok(response::success(serde_json::json!({
        "user": user,
        "subscriptions": subscriptions,
        "licenses": licenses,
        "payments": payments,
        "trade_count": trade_count,
    })))
}

//+------------------------------------------------------------------+
//| Activate User                                                    |
//+------------------------------------------------------------------+

async fn activate_user(
    pool: web::Data<PgPool>,
    http_req: HttpRequest,
    path: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    verify_admin(&http_req)?;

    let user_id = path.into_inner();

    sqlx::query(
        "UPDATE users SET is_active = TRUE, updated_at = NOW() WHERE id = $1"
    )
    .bind(user_id)
    .execute(pool.get_ref())
    .await?;

    log::info!("User activated: {}", user_id);

    Ok(response::success(serde_json::json!({
        "message": "User activated successfully",
        "user_id": user_id,
    })))
}

//+------------------------------------------------------------------+
//| Deactivate User                                                  |
//+------------------------------------------------------------------+

async fn deactivate_user(
    pool: web::Data<PgPool>,
    http_req: HttpRequest,
    path: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    verify_admin(&http_req)?;

    let user_id = path.into_inner();

    sqlx::query(
        "UPDATE users SET is_active = FALSE, updated_at = NOW() WHERE id = $1"
    )
    .bind(user_id)
    .execute(pool.get_ref())
    .await?;

    log::info!("User deactivated: {}", user_id);

    Ok(response::success(serde_json::json!({
        "message": "User deactivated successfully",
        "user_id": user_id,
    })))
}

//+------------------------------------------------------------------+
//| Get All Subscriptions                                           |
//+------------------------------------------------------------------+

async fn get_all_subscriptions(
    pool: web::Data<PgPool>,
    http_req: HttpRequest,
) -> Result<HttpResponse, AppError> {
    verify_admin(&http_req)?;

    let subscriptions = sqlx::query_as::<_, Subscription>(
        "SELECT * FROM subscriptions ORDER BY created_at DESC LIMIT 100"
    )
    .fetch_all(pool.get_ref())
    .await?;

    Ok(response::success(subscriptions))
}

//+------------------------------------------------------------------+
//| Get Subscription Details                                        |
//+------------------------------------------------------------------+

async fn get_subscription_details(
    pool: web::Data<PgPool>,
    http_req: HttpRequest,
    path: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    verify_admin(&http_req)?;

    let subscription_id = path.into_inner();

    let subscription = sqlx::query_as::<_, Subscription>(
        "SELECT * FROM subscriptions WHERE id = $1"
    )
    .bind(subscription_id)
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or(AppError::Internal("Subscription not found".to_string()))?;

    // Get associated user
    let user = sqlx::query_as::<_, User>(
        "SELECT * FROM users WHERE id = $1"
    )
    .bind(subscription.user_id)
    .fetch_optional(pool.get_ref())
    .await?;

    // Get associated payment
    let payment = sqlx::query_as::<_, Payment>(
        "SELECT * FROM payments WHERE subscription_id = $1"
    )
    .bind(subscription_id)
    .fetch_optional(pool.get_ref())
    .await?;

    // Get associated license
    let license = sqlx::query_as::<_, License>(
        "SELECT * FROM licenses WHERE subscription_id = $1"
    )
    .bind(subscription_id)
    .fetch_optional(pool.get_ref())
    .await?;

    Ok(response::success(serde_json::json!({
        "subscription": subscription,
        "user": user,
        "payment": payment,
        "license": license,
    })))
}

//+------------------------------------------------------------------+
//| Get All Payments                                                 |
//+------------------------------------------------------------------+

async fn get_all_payments(
    pool: web::Data<PgPool>,
    http_req: HttpRequest,
) -> Result<HttpResponse, AppError> {
    verify_admin(&http_req)?;

    let payments = sqlx::query_as::<_, Payment>(
        "SELECT * FROM payments ORDER BY created_at DESC LIMIT 100"
    )
    .fetch_all(pool.get_ref())
    .await?;

    Ok(response::success(payments))
}

//+------------------------------------------------------------------+
//| Get System Statistics                                           |
//+------------------------------------------------------------------+

async fn get_system_stats(
    pool: web::Data<PgPool>,
    http_req: HttpRequest,
) -> Result<HttpResponse, AppError> {
    verify_admin(&http_req)?;

    // User stats
    let total_users = sqlx::query_scalar::<_, i64>(
        "SELECT COUNT(*) FROM users"
    )
    .fetch_one(pool.get_ref())
    .await
    .unwrap_or(0);

    let active_users = sqlx::query_scalar::<_, i64>(
        "SELECT COUNT(*) FROM users WHERE is_active = TRUE"
    )
    .fetch_one(pool.get_ref())
    .await
    .unwrap_or(0);

    // Subscription stats
    let active_subscriptions = sqlx::query_scalar::<_, i64>(
        "SELECT COUNT(*) FROM subscriptions WHERE status = 'active'"
    )
    .fetch_one(pool.get_ref())
    .await
    .unwrap_or(0);

    let total_revenue = sqlx::query_scalar::<_, Option<f64>>(
        "SELECT SUM(amount) FROM payments WHERE status = 'confirmed'"
    )
    .fetch_one(pool.get_ref())
    .await
    .unwrap_or(None)
    .unwrap_or(0.0);

    // Trade stats
    let total_trades = sqlx::query_scalar::<_, i64>(
        "SELECT COUNT(*) FROM trade_logs"
    )
    .fetch_one(pool.get_ref())
    .await
    .unwrap_or(0);

    // Tier breakdown
    let tier_stats = sqlx::query!(
        r#"
        SELECT tier, COUNT(*) as count
        FROM subscriptions
        WHERE status = 'active'
        GROUP BY tier
        "#
    )
    .fetch_all(pool.get_ref())
    .await?;

    Ok(response::success(serde_json::json!({
        "users": {
            "total": total_users,
            "active": active_users,
        },
        "subscriptions": {
            "active": active_subscriptions,
            "tiers": tier_stats.iter().map(|t| {
                serde_json::json!({
                    "tier": &t.tier,
                    "count": t.count,
                })
            }).collect::<Vec<_>>(),
        },
        "revenue": {
            "total": total_revenue,
        },
        "trades": {
            "total": total_trades,
        },
    })))
}

//+------------------------------------------------------------------+
//| Helper: Verify Admin Permission                                 |
//+------------------------------------------------------------------+

fn verify_admin(http_req: &HttpRequest) -> Result<(), AppError> {
    let claims = http_req
        .extensions()
        .get::<crate::models::Claims>()
        .cloned()
        .ok_or(AppError::Unauthorized)?;

    if !claims.is_admin {
        return Err(AppError::Unauthorized);
    }

    Ok(())
}
