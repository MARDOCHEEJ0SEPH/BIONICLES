mod config;
mod database;
mod cache;
mod models;
mod api;
mod x402;
mod payments;
mod middleware;
mod utils;

use actix_web::{web, App, HttpServer, HttpResponse};
use actix_cors::Cors;
use std::sync::Arc;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Initialize environment variables
    dotenv::dotenv().ok();

    // Initialize logger
    env_logger::init();

    log::info!("═══════════════════════════════════════════════════════");
    log::info!("  BIONICLES Backend Server v1.0");
    log::info!("  X402 Protocol + USDT/USDC Payments");
    log::info!("═══════════════════════════════════════════════════════");

    // Load configuration
    let config = config::Config::from_env()
        .expect("Failed to load configuration");

    log::info!("Configuration loaded");

    // Initialize database connection pool
    let db_pool = database::create_pool(&config.database_url, config.database_max_connections)
        .await
        .expect("Failed to create database pool");

    log::info!("Database connection pool created");

    // Run migrations
    database::run_migrations(&db_pool)
        .await
        .expect("Failed to run database migrations");

    log::info!("Database migrations completed");

    // Initialize Redis cache
    let redis_client = cache::create_client(&config.redis_url)
        .expect("Failed to create Redis client");

    log::info!("Redis cache initialized");

    // Initialize payment processors
    let payment_processor = payments::PaymentProcessor::new(
        config.ethereum_rpc_url.clone(),
        config.polygon_rpc_url.clone(),
        config.payment_wallet_address.clone(),
    ).await.expect("Failed to initialize payment processor");

    log::info!("Payment processor initialized");

    // Wrap shared state
    let db_pool = Arc::new(db_pool);
    let redis_client = Arc::new(redis_client);
    let payment_processor = Arc::new(payment_processor);
    let app_config = Arc::new(config.clone());

    let server_host = config.server_host.clone();
    let server_port = config.server_port;

    log::info!("Starting server on {}:{}", server_host, server_port);

    // Start HTTP server
    HttpServer::new(move || {
        // Configure CORS
        let cors = Cors::default()
            .allowed_origin(&app_config.cors_allowed_origins)
            .allowed_methods(vec!["GET", "POST", "PUT", "DELETE", "PATCH"])
            .allowed_headers(vec![
                actix_web::http::header::AUTHORIZATION,
                actix_web::http::header::ACCEPT,
                actix_web::http::header::CONTENT_TYPE,
            ])
            .max_age(3600);

        App::new()
            .wrap(cors)
            .wrap(actix_web::middleware::Logger::default())
            .app_data(web::Data::new(db_pool.clone()))
            .app_data(web::Data::new(redis_client.clone()))
            .app_data(web::Data::new(payment_processor.clone()))
            .app_data(web::Data::new(app_config.clone()))
            // Health check
            .route("/health", web::get().to(health_check))
            // API routes
            .service(
                web::scope("/api")
                    .configure(api::auth::configure)
                    .configure(api::licensing::configure)
                    .configure(api::trading::configure)
                    .configure(api::admin::configure)
                    .configure(api::payments::configure)
            )
    })
    .bind((server_host.as_str(), server_port))?
    .run()
    .await
}

/// Health check endpoint
async fn health_check() -> HttpResponse {
    HttpResponse::Ok().json(serde_json::json!({
        "status": "healthy",
        "service": "BIONICLES Backend",
        "version": "1.0.0",
        "timestamp": chrono::Utc::now().to_rfc3339()
    }))
}
