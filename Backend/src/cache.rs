use redis::{Client, RedisError, AsyncCommands, aio::ConnectionManager};
use serde::{Serialize, Deserialize};

pub type RedisClient = Client;
pub type RedisConnection = ConnectionManager;

/// Create Redis client
pub fn create_client(redis_url: &str) -> Result<RedisClient, RedisError> {
    log::info!("Creating Redis client...");
    Client::open(redis_url)
}

/// Get connection manager
pub async fn get_connection(client: &RedisClient) -> Result<RedisConnection, RedisError> {
    ConnectionManager::new(client.clone()).await
}

/// Cache operations
pub struct Cache {
    conn: RedisConnection,
}

impl Cache {
    pub async fn new(client: &RedisClient) -> Result<Self, RedisError> {
        let conn = get_connection(client).await?;
        Ok(Cache { conn })
    }

    /// Set key-value with TTL (seconds)
    pub async fn set<T: Serialize>(
        &mut self,
        key: &str,
        value: &T,
        ttl: usize,
    ) -> Result<(), RedisError> {
        let serialized = serde_json::to_string(value)
            .map_err(|e| RedisError::from((redis::ErrorKind::Serialize, "Serialization failed", e.to_string())))?;

        self.conn.set_ex(key, serialized, ttl).await
    }

    /// Get value by key
    pub async fn get<T: for<'de> Deserialize<'de>>(
        &mut self,
        key: &str,
    ) -> Result<Option<T>, RedisError> {
        let value: Option<String> = self.conn.get(key).await?;

        match value {
            Some(v) => {
                let deserialized = serde_json::from_str(&v)
                    .map_err(|e| RedisError::from((redis::ErrorKind::Serialize, "Deserialization failed", e.to_string())))?;
                Ok(Some(deserialized))
            }
            None => Ok(None),
        }
    }

    /// Delete key
    pub async fn delete(&mut self, key: &str) -> Result<(), RedisError> {
        self.conn.del(key).await
    }

    /// Check if key exists
    pub async fn exists(&mut self, key: &str) -> Result<bool, RedisError> {
        self.conn.exists(key).await
    }

    /// Increment counter
    pub async fn increment(&mut self, key: &str) -> Result<i64, RedisError> {
        self.conn.incr(key, 1).await
    }

    /// Set expiration on existing key
    pub async fn expire(&mut self, key: &str, ttl: usize) -> Result<(), RedisError> {
        self.conn.expire(key, ttl).await
    }
}

/// Helper functions for common cache patterns
pub mod helpers {
    use super::*;

    /// License cache key
    pub fn license_key(user_id: &str) -> String {
        format!("license:{}", user_id)
    }

    /// Session cache key
    pub fn session_key(token: &str) -> String {
        format!("session:{}", token)
    }

    /// API rate limit key
    pub fn rate_limit_key(user_id: &str, endpoint: &str) -> String {
        format!("ratelimit:{}:{}", user_id, endpoint)
    }

    /// Payment verification key
    pub fn payment_key(tx_hash: &str) -> String {
        format!("payment:{}", tx_hash)
    }

    /// Daily API call counter key
    pub fn daily_api_calls_key(user_id: &str) -> String {
        use chrono::Utc;
        let today = Utc::now().format("%Y-%m-%d");
        format!("api_calls:{}:{}", user_id, today)
    }
}
