use actix_web::{web, HttpResponse};
use sqlx::PgPool;
use uuid::Uuid;
use chrono::Utc;

use crate::{
    config::Config,
    models::{
        AppError, AuthResponse, LoginRequest, RegisterRequest, User, UserResponse,
    },
    utils::{jwt, password, response, validation},
};

/// Configure authentication routes
pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/auth")
            .route("/register", web::post().to(register))
            .route("/login", web::post().to(login))
            .route("/me", web::get().to(get_current_user)),
    );
}

//+------------------------------------------------------------------+
//| Register New User                                                |
//+------------------------------------------------------------------+

async fn register(
    pool: web::Data<PgPool>,
    config: web::Data<Config>,
    req: web::Json<RegisterRequest>,
) -> Result<HttpResponse, AppError> {
    log::info!("Registration attempt: {}", req.email);

    // Validate email format
    if !validation::is_valid_email(&req.email) {
        return Ok(response::bad_request("Invalid email format"));
    }

    // Validate password strength
    if !validation::is_strong_password(&req.password) {
        return Ok(response::bad_request(
            "Password must be at least 8 characters with uppercase, lowercase, and digit",
        ));
    }

    // Check if user already exists
    let existing_user = sqlx::query_as::<_, User>(
        "SELECT * FROM users WHERE email = $1"
    )
    .bind(&req.email)
    .fetch_optional(pool.get_ref())
    .await?;

    if existing_user.is_some() {
        return Ok(response::bad_request("Email already registered"));
    }

    // Hash password
    let password_hash = password::hash_password(&req.password)?;

    // Insert user
    let user = sqlx::query_as::<_, User>(
        r#"
        INSERT INTO users (email, password_hash, full_name, is_admin, is_active)
        VALUES ($1, $2, $3, FALSE, TRUE)
        RETURNING *
        "#,
    )
    .bind(&req.email)
    .bind(&password_hash)
    .bind(&req.full_name)
    .fetch_one(pool.get_ref())
    .await?;

    log::info!("User registered successfully: {} ({})", user.email, user.id);

    // Generate JWT token
    let token = jwt::generate_token(
        user.id,
        &user.email,
        user.is_admin,
        &config.jwt_secret,
        config.jwt_expiration_hours,
    )?;

    let expires_at = Utc::now() + chrono::Duration::hours(config.jwt_expiration_hours);

    let auth_response = AuthResponse {
        token,
        user: user.into(),
        expires_at,
    };

    Ok(response::created(auth_response))
}

//+------------------------------------------------------------------+
//| Login                                                            |
//+------------------------------------------------------------------+

async fn login(
    pool: web::Data<PgPool>,
    config: web::Data<Config>,
    req: web::Json<LoginRequest>,
) -> Result<HttpResponse, AppError> {
    log::info!("Login attempt: {}", req.email);

    // Find user by email
    let user = sqlx::query_as::<_, User>(
        "SELECT * FROM users WHERE email = $1"
    )
    .bind(&req.email)
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or(AppError::InvalidCredentials)?;

    // Check if user is active
    if !user.is_active {
        log::warn!("Login attempt for inactive user: {}", user.email);
        return Err(AppError::InvalidCredentials);
    }

    // Verify password
    let is_valid = password::verify_password(&req.password, &user.password_hash)?;

    if !is_valid {
        log::warn!("Invalid password for user: {}", user.email);
        return Err(AppError::InvalidCredentials);
    }

    log::info!("User logged in successfully: {} ({})", user.email, user.id);

    // Generate JWT token
    let token = jwt::generate_token(
        user.id,
        &user.email,
        user.is_admin,
        &config.jwt_secret,
        config.jwt_expiration_hours,
    )?;

    let expires_at = Utc::now() + chrono::Duration::hours(config.jwt_expiration_hours);

    let auth_response = AuthResponse {
        token,
        user: user.into(),
        expires_at,
    };

    Ok(response::success(auth_response))
}

//+------------------------------------------------------------------+
//| Get Current User (requires authentication)                      |
//+------------------------------------------------------------------+

async fn get_current_user(
    pool: web::Data<PgPool>,
    req: actix_web::HttpRequest,
) -> Result<HttpResponse, AppError> {
    // Extract claims from request extensions (set by auth middleware)
    let claims = req
        .extensions()
        .get::<crate::models::Claims>()
        .cloned()
        .ok_or(AppError::Unauthorized)?;

    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::Unauthorized)?;

    // Fetch user from database
    let user = sqlx::query_as::<_, User>(
        "SELECT * FROM users WHERE id = $1"
    )
    .bind(user_id)
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or(AppError::UserNotFound)?;

    let user_response: UserResponse = user.into();

    Ok(response::success(user_response))
}
