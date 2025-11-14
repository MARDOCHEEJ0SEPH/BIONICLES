use actix_web::{web, HttpResponse, HttpRequest};
use sqlx::PgPool;
use uuid::Uuid;
use chrono::Utc;

use crate::{
    models::{AppError, LogTradeRequest, TradeLog},
    utils::response,
};

/// Configure trading routes
pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/trading")
            .route("/log", web::post().to(log_trade))
            .route("/history", web::get().to(get_trade_history))
            .route("/stats", web::get().to(get_trade_stats)),
    );
}

//+------------------------------------------------------------------+
//| Log Trade Execution                                              |
//+------------------------------------------------------------------+

async fn log_trade(
    pool: web::Data<PgPool>,
    http_req: HttpRequest,
    req: web::Json<LogTradeRequest>,
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
        "Trade log for user {}: Ticket {} | {} {} @ {}",
        user_id,
        req.ticket,
        req.trade_type,
        req.lots,
        req.entry_price
    );

    // Insert trade log
    let trade_log = sqlx::query_as::<_, TradeLog>(
        r#"
        INSERT INTO trade_logs (
            user_id, ticket, symbol, trade_type, lots, entry_price,
            stop_loss, take_profit, entry_time
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
        RETURNING *
        "#,
    )
    .bind(user_id)
    .bind(req.ticket)
    .bind(&req.symbol)
    .bind(&req.trade_type)
    .bind(req.lots)
    .bind(req.entry_price)
    .bind(req.stop_loss)
    .bind(req.take_profit)
    .fetch_one(pool.get_ref())
    .await?;

    Ok(response::created(trade_log))
}

//+------------------------------------------------------------------+
//| Get Trade History                                                |
//+------------------------------------------------------------------+

async fn get_trade_history(
    pool: web::Data<PgPool>,
    http_req: HttpRequest,
    query: web::Query<std::collections::HashMap<String, String>>,
) -> Result<HttpResponse, AppError> {
    // Extract claims from JWT
    let claims = http_req
        .extensions()
        .get::<crate::models::Claims>()
        .cloned()
        .ok_or(AppError::Unauthorized)?;

    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::Unauthorized)?;

    // Get limit parameter (default 100, max 1000)
    let limit: i64 = query
        .get("limit")
        .and_then(|l| l.parse().ok())
        .unwrap_or(100)
        .min(1000);

    // Get trades
    let trades = sqlx::query_as::<_, TradeLog>(
        r#"
        SELECT *
        FROM trade_logs
        WHERE user_id = $1
        ORDER BY entry_time DESC
        LIMIT $2
        "#,
    )
    .bind(user_id)
    .bind(limit)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(response::success(trades))
}

//+------------------------------------------------------------------+
//| Get Trade Statistics                                             |
//+------------------------------------------------------------------+

async fn get_trade_stats(
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

    // Get statistics
    let stats = sqlx::query!(
        r#"
        SELECT
            COUNT(*) as total_trades,
            COUNT(*) FILTER (WHERE is_win = TRUE) as winning_trades,
            COUNT(*) FILTER (WHERE is_win = FALSE) as losing_trades,
            COALESCE(SUM(profit_usd) FILTER (WHERE is_win = TRUE), 0) as total_profit,
            COALESCE(SUM(profit_usd) FILTER (WHERE is_win = FALSE), 0) as total_loss,
            COALESCE(SUM(profit_usd), 0) as net_profit,
            COALESCE(AVG(profit_usd) FILTER (WHERE is_win = TRUE), 0) as avg_win,
            COALESCE(AVG(profit_usd) FILTER (WHERE is_win = FALSE), 0) as avg_loss,
            COALESCE(MAX(profit_usd), 0) as best_trade,
            COALESCE(MIN(profit_usd), 0) as worst_trade
        FROM trade_logs
        WHERE user_id = $1
        AND exit_time IS NOT NULL
        "#,
        user_id
    )
    .fetch_one(pool.get_ref())
    .await?;

    let total_trades = stats.total_trades.unwrap_or(0);
    let winning_trades = stats.winning_trades.unwrap_or(0);
    let total_profit = stats.total_profit.unwrap_or(0.0);
    let total_loss = stats.total_loss.unwrap_or(0.0);

    let win_rate = if total_trades > 0 {
        (winning_trades as f64 / total_trades as f64) * 100.0
    } else {
        0.0
    };

    let profit_factor = if total_loss.abs() > 0.0 {
        total_profit.abs() / total_loss.abs()
    } else {
        0.0
    };

    Ok(response::success(serde_json::json!({
        "total_trades": total_trades,
        "winning_trades": winning_trades,
        "losing_trades": stats.losing_trades.unwrap_or(0),
        "win_rate": win_rate,
        "total_profit": total_profit,
        "total_loss": total_loss,
        "net_profit": stats.net_profit.unwrap_or(0.0),
        "avg_win": stats.avg_win.unwrap_or(0.0),
        "avg_loss": stats.avg_loss.unwrap_or(0.0),
        "best_trade": stats.best_trade.unwrap_or(0.0),
        "worst_trade": stats.worst_trade.unwrap_or(0.0),
        "profit_factor": profit_factor,
    })))
}
