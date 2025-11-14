# BIONICLES Backend API

**Rust + Actix-Web + PostgreSQL + Redis**
**X402 Payment Protocol + USDT/USDC Cryptocurrency Payments**

---

## 🎯 Overview

The BIONICLES backend is a high-performance Rust API server that provides:

- **X402 Payment Protocol**: HTTP 402-based subscription management
- **Cryptocurrency Payments**: USDT/USDC on Ethereum and Polygon networks
- **License Validation**: Quarterly subscription-based API access
- **JWT Authentication**: Secure user authentication
- **Trade Logging**: Track MQL5 EA trade execution
- **Admin Dashboard API**: User and subscription management

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Actix-Web Server                        │
│                         (Rust)                              │
└────────────┬────────────────────────────────────────────────┘
             │
    ┌────────┼────────────┬──────────────┬──────────────┐
    │        │            │              │              │
    ▼        ▼            ▼              ▼              ▼
┌─────────┐┌──────────┐┌──────────┐┌────────────┐┌──────────┐
│  Auth   ││ Licensing││ Payments ││   Trading  ││  Admin   │
│  API    ││   API    ││   API    ││    API     ││   API    │
└─────────┘└──────────┘└──────────┘└────────────┘└──────────┘
    │        │            │              │              │
    └────────┼────────────┴──────────────┴──────────────┘
             │
    ┌────────┼────────────┬──────────────┐
    │        │            │              │
    ▼        ▼            ▼              ▼
┌─────────┐┌──────────┐┌──────────┐┌────────────┐
│PostgreSQL││  Redis   ││ Ethereum ││  Polygon   │
│ Database ││  Cache   ││   RPC    ││    RPC     │
└─────────┘└──────────┘└──────────┘└────────────┘
```

---

## 📦 Dependencies

### Core
- **actix-web**: Web framework
- **sqlx**: PostgreSQL async driver
- **redis**: Redis cache client
- **tokio**: Async runtime

### Authentication
- **jsonwebtoken**: JWT token generation/validation
- **bcrypt**: Password hashing
- **uuid**: Unique identifiers

### Blockchain
- **ethers**: Ethereum/Polygon interaction
- **web3**: Alternative Web3 client

### Serialization
- **serde**: JSON serialization
- **serde_json**: JSON handling

---

## 🚀 Quick Start

### Prerequisites

- Rust 1.75+
- PostgreSQL 16+
- Redis 7+
- Docker (optional)

### Option 1: Docker Compose (Recommended)

```bash
# 1. Clone repository
git clone https://github.com/MARDOCHEEJ0SEPH/BIONICLES.git
cd BIONICLES/Backend

# 2. Create .env file
cp .env.example .env
# Edit .env with your configuration

# 3. Start services
docker-compose up -d

# 4. Check logs
docker-compose logs -f backend

# 5. Health check
curl http://localhost:8080/health
```

### Option 2: Local Development

```bash
# 1. Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 2. Start PostgreSQL
docker run -d \
  --name bionicles-postgres \
  -e POSTGRES_DB=bionicles \
  -e POSTGRES_USER=bionicles \
  -e POSTGRES_PASSWORD=changeme \
  -p 5432:5432 \
  postgres:16-alpine

# 3. Start Redis
docker run -d \
  --name bionicles-redis \
  -p 6379:6379 \
  redis:7-alpine

# 4. Set environment variables
export DATABASE_URL="postgresql://bionicles:changeme@localhost:5432/bionicles"
export REDIS_URL="redis://localhost:6379"
export JWT_SECRET="your-secret-key"
# ... (see .env.example for all variables)

# 5. Build and run
cargo build --release
cargo run --release
```

---

## 🔧 Configuration

Create a `.env` file with the following variables:

```env
# Server
SERVER_HOST=0.0.0.0
SERVER_PORT=8080

# Database
DATABASE_URL=postgresql://bionicles:password@localhost:5432/bionicles

# Redis
REDIS_URL=redis://localhost:6379

# JWT
JWT_SECRET=your-secret-key-here
JWT_EXPIRATION_HOURS=24

# Ethereum
ETHEREUM_RPC_URL=https://mainnet.infura.io/v3/YOUR_INFURA_KEY

# Polygon
POLYGON_RPC_URL=https://polygon-rpc.com

# Payment Wallet
PAYMENT_WALLET_ADDRESS=0xYourWalletAddress
PAYMENT_WALLET_PRIVATE_KEY=0xYourPrivateKey

# X402
X402_REALM=BIONICLES Trading API
X402_PAYMENT_URI=https://bionicles.io/subscribe

# Pricing
SUBSCRIPTION_STARTER_PRICE=9.00
SUBSCRIPTION_PROFESSIONAL_PRICE=29.00
```

---

## 📡 API Endpoints

### Health Check

```bash
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "service": "BIONICLES Backend",
  "version": "1.0.0",
  "timestamp": "2024-11-14T12:00:00Z"
}
```

---

### Authentication

#### Register

```bash
POST /api/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePass123",
  "full_name": "John Doe"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGc....",
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "full_name": "John Doe",
      "is_admin": false,
      "created_at": "2024-11-14T12:00:00Z"
    },
    "expires_at": "2024-11-15T12:00:00Z"
  }
}
```

#### Login

```bash
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePass123"
}
```

#### Get Current User

```bash
GET /api/auth/me
Authorization: Bearer <token>
```

---

### License Validation (X402 Core)

```bash
GET /api/license/validate
Authorization: Bearer <token>
```

**Response (Valid License):**
```json
{
  "success": true,
  "data": {
    "is_valid": true,
    "user_id": "uuid",
    "tier": "professional",
    "credits_remaining": 9999,
    "expires_at": "2025-02-14T00:00:00Z"
  }
}
```

**Response (No License - X402):**
```http
HTTP/1.1 402 Payment Required
WWW-Authenticate: Bearer realm="BIONICLES Trading API", payment_uri="https://bionicles.io/subscribe", amount="9.00 USD"
Payment-URI: https://bionicles.io/subscribe

{
  "error": "payment_required",
  "message": "Active subscription required to access this resource",
  "payment_uri": "https://bionicles.io/subscribe",
  "amount": 9.0,
  "currency": "USD",
  "accepted_methods": ["USDT", "USDC"],
  "accepted_networks": ["ethereum", "polygon"]
}
```

---

### Payments

#### Verify Payment

```bash
POST /api/payments/verify
Authorization: Bearer <token>
Content-Type: application/json

{
  "transaction_hash": "0x123...abc",
  "network": "ethereum"
}
```

#### Create Subscription

```bash
POST /api/payments/subscribe
Authorization: Bearer <token>
Content-Type: application/json

{
  "tier": "professional",
  "payment_tx_hash": "0x123...abc",
  "network": "polygon"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "subscription": { ... },
    "payment": { ... },
    "license_key": "ABCD-1234-EFGH-5678",
    "message": "Subscription activated successfully"
  }
}
```

---

### Trading

#### Log Trade

```bash
POST /api/trading/log
Authorization: Bearer <token>
Content-Type: application/json

{
  "ticket": 123456789,
  "symbol": "EURUSD",
  "trade_type": "BUY",
  "lots": 0.10,
  "entry_price": 1.10500,
  "stop_loss": 1.10200,
  "take_profit": 1.11400
}
```

#### Get Trade History

```bash
GET /api/trading/history?limit=100
Authorization: Bearer <token>
```

#### Get Trade Statistics

```bash
GET /api/trading/stats
Authorization: Bearer <token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "total_trades": 50,
    "winning_trades": 25,
    "losing_trades": 25,
    "win_rate": 50.0,
    "profit_factor": 1.8,
    "net_profit": 2500.00
  }
}
```

---

### Admin (Requires Admin Permission)

#### Get All Users

```bash
GET /api/admin/users
Authorization: Bearer <admin-token>
```

#### Get User Details

```bash
GET /api/admin/users/{user_id}
Authorization: Bearer <admin-token>
```

#### System Statistics

```bash
GET /api/admin/stats
Authorization: Bearer <admin-token>
```

---

## 💰 Payment Flow

1. **User Registers** → Receives JWT token
2. **User Sends USDT/USDC** → To payment wallet address
3. **User Submits TX Hash** → `POST /api/payments/subscribe`
4. **Backend Verifies Payment** → Checks blockchain transaction
5. **Subscription Created** → 90-day subscription activated
6. **License Generated** → License key returned
7. **MQL5 EA Validates** → `GET /api/license/validate` every 5 minutes

---

## 🔐 Security

### Authentication
- JWT tokens with 24-hour expiration
- Bcrypt password hashing (cost 12)
- Bearer token authentication

### Rate Limiting
- Daily API call limits based on tier
- Redis-based rate limiting
- 402 response when limit exceeded

### Payment Security
- On-chain transaction verification
- Multi-confirmation checks
- Amount validation (±1% tolerance)

---

## 📊 Database Schema

### Users
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    is_admin BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Subscriptions
```sql
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    tier VARCHAR(50) CHECK (tier IN ('starter', 'professional', 'enterprise')),
    status VARCHAR(50) CHECK (status IN ('active', 'expired', 'cancelled')),
    price DECIMAL(10, 2),
    starts_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Licenses
```sql
CREATE TABLE licenses (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    subscription_id UUID REFERENCES subscriptions(id),
    license_key VARCHAR(255) UNIQUE,
    is_active BOOLEAN DEFAULT TRUE,
    max_api_calls_per_day INTEGER,
    api_calls_used_today INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Payments
```sql
CREATE TABLE payments (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    transaction_hash VARCHAR(66) UNIQUE,
    amount DECIMAL(18, 6),
    currency VARCHAR(10) CHECK (currency IN ('USDT', 'USDC')),
    network VARCHAR(20) CHECK (network IN ('ethereum', 'polygon')),
    status VARCHAR(50) CHECK (status IN ('pending', 'confirmed', 'failed')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 🧪 Testing

```bash
# Run all tests
cargo test

# Run specific test
cargo test test_payment_required_response

# Run with output
cargo test -- --nocapture
```

---

## 📈 Monitoring

### Logs

```bash
# Docker logs
docker-compose logs -f backend

# Local logs
RUST_LOG=debug cargo run
```

### Metrics

- Request count: Log every API call
- Response time: Tracked in `api_logs` table
- Payment confirmations: Monitored in `payments` table
- Active subscriptions: Query `subscriptions` table

---

## 🚢 Deployment

### Production Checklist

- [ ] Set strong `JWT_SECRET`
- [ ] Configure production RPC URLs (Infura/Alchemy)
- [ ] Set up secure payment wallet
- [ ] Enable HTTPS/SSL
- [ ] Configure firewall (allow 8080, 5432, 6379)
- [ ] Set up database backups
- [ ] Configure log rotation
- [ ] Enable monitoring (Prometheus/Grafana)
- [ ] Test payment flow end-to-end

### VPS Deployment

```bash
# 1. SSH into VPS
ssh root@your-vps-ip

# 2. Install Docker
curl -fsSL https://get.docker.com | sh

# 3. Clone repository
git clone https://github.com/MARDOCHEEJ0SEPH/BIONICLES.git
cd BIONICLES/Backend

# 4. Create .env
nano .env
# (paste production configuration)

# 5. Start services
docker-compose up -d

# 6. Verify
curl http://localhost:8080/health

# 7. Set up Nginx reverse proxy (optional)
# (see deployment guide for details)
```

---

## 📝 License

Proprietary - BIONICLES Development Team

---

## 📧 Support

- **Email**: support@bionicles.io
- **GitHub**: [MARDOCHEEJ0SEPH/BIONICLES](https://github.com/MARDOCHEEJ0SEPH/BIONICLES)

---

**Built with ❤️ in Rust**
