# Advanced Autonomous Wedge Trading System
## MQL5 Expert Advisor with X402 Payment Protocol Integration

---

## TABLE OF CONTENTS

1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [MQL5 Implementation Structure](#mql5-implementation-structure)
4. [X402 Payment Protocol Integration](#x402-payment-protocol-integration)
5. [Module Specifications](#module-specifications)
6. [Mathematical Foundation](#mathematical-foundation)
7. [Implementation Plan](#implementation-plan)
8. [Deployment Strategy](#deployment-strategy)
9. [Testing & Validation](#testing--validation)
10. [Performance Targets](#performance-targets)

---

## PROJECT OVERVIEW

### Vision
Create an autonomous, intelligent wedge pattern trading system for MQL5 (MetaTrader 5) that:
- Operates on 4-hour EURUSD timeframe
- Maintains strict 1:3 risk-reward ratio
- Provides 24/7 autonomous market surveillance
- Integrates with X402 payment protocol for licensing
- Offers optional SaaS backend for multi-user deployment

### Core Objectives
1. **Autonomous Trading**: 24/7 pattern detection and execution without human intervention
2. **Risk Management**: Strict position sizing with 2% max risk per trade
3. **Mathematical Precision**: Linear regression-based trend line detection
4. **Scalability**: Support for both standalone and SaaS deployment
5. **Monetization**: X402 payment protocol for subscription management

### Key Features
- **Pattern Recognition**: Automated wedge pattern detection using linear regression
- **Signal Generation**: Multi-factor confirmation (RSI, ATR, price position)
- **Position Management**: Trailing stops, breakeven protection, profit scaling
- **Safety Protocols**: Circuit breakers, drawdown limits, emergency stops
- **Performance Tracking**: Real-time P&L, win rate, profit factor monitoring
- **Licensing**: HTTP 402 payment protocol for subscription validation

---

## SYSTEM ARCHITECTURE

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                      MQL5 EXPERT ADVISOR                            │
│                   WedgeTradingSystem.mq5                           │
└────────────┬────────────────────────────────────────────────────────┘
             │
    ┌────────┼────────────┬──────────────┬──────────────┬────────────┐
    │        │            │              │              │            │
    ▼        ▼            ▼              ▼              ▼            ▼
┌─────────┐┌──────────┐┌──────────┐┌────────────┐┌──────────┐┌──────┐
│ Trend   ││Convergence││ Signal   ││ Risk      ││ Trade    ││Safety│
│ Lines   ││ Analysis  ││Generator ││ Mgmt      ││ Mgmt     ││Checks│
│ .mqh    ││  .mqh     ││  .mqh    ││  .mqh     ││  .mqh    ││ .mqh │
└─────────┘└──────────┘└──────────┘└────────────┘└──────────┘└──────┘
    │        │            │              │              │            │
    └────────┼────────────┴──────────────┴──────────────┴────────────┘
             │
    ┌────────┴────────────────────────────────────────────────────────┐
    │                                                                  │
    ▼                                                                  ▼
┌─────────────────────────┐                    ┌────────────────────────┐
│  STANDALONE MODE        │                    │  SAAS MODE (OPTIONAL)  │
│  - Local execution      │                    │  - Backend connectivity│
│  - File-based license   │                    │  - X402 validation     │
│  - Manual configuration │                    │  - Multi-user support  │
└─────────────────────────┘                    └────────────┬───────────┘
                                                             │
                                                             ▼
                                               ┌──────────────────────────┐
                                               │  BACKEND SERVER (Rust)   │
                                               │  - X402 Protocol Handler │
                                               │  - License Management    │
                                               │  - User Authentication   │
                                               │  - Analytics Dashboard   │
                                               └──────────────────────────┘
```

### Deployment Modes

#### Mode 1: Standalone Expert Advisor
- **Target Users**: Individual traders
- **License**: File-based license key
- **Configuration**: Manual parameter input
- **Reporting**: Local files and terminal output
- **Cost**: One-time purchase or annual license

#### Mode 2: SaaS with X402 Protocol
- **Target Users**: Trading firms, multiple accounts
- **License**: HTTP 402 payment protocol
- **Configuration**: Cloud-based, API-driven
- **Reporting**: Web dashboard with analytics
- **Cost**: Quarterly subscription ($9-$29/quarter)

---

## MQL5 IMPLEMENTATION STRUCTURE

### File Structure

```
BIONICLES/
├── CLAUDE.md                                    # This file
├── README.md                                    # Project readme
├── LICENSE                                      # License information
│
├── MQL5/
│   ├── Experts/
│   │   └── BIONICLES/
│   │       └── WedgeTradingSystem.mq5          # Main EA
│   │
│   ├── Include/
│   │   └── BIONICLES/
│   │       ├── Core/
│   │       │   ├── TrendLineDetection.mqh      # Module 1
│   │       │   ├── ConvergenceAnalysis.mqh     # Module 2
│   │       │   ├── PricePosition.mqh           # Module 3
│   │       │   ├── SignalGenerator.mqh         # Module 4
│   │       │   ├── RiskManagement.mqh          # Module 5
│   │       │   ├── TradeManagement.mqh         # Module 6
│   │       │   └── BreakoutDetection.mqh       # Module 7
│   │       │
│   │       ├── Utils/
│   │       │   ├── MathUtils.mqh               # Mathematical helpers
│   │       │   ├── Indicators.mqh              # ATR, RSI calculations
│   │       │   ├── Logger.mqh                  # Logging system
│   │       │   └── Validators.mqh              # Input validation
│   │       │
│   │       ├── Execution/
│   │       │   ├── OrderManager.mqh            # Order execution
│   │       │   ├── PositionTracker.mqh         # Position tracking
│   │       │   └── BrokerInterface.mqh         # Broker API
│   │       │
│   │       ├── Safety/
│   │       │   ├── CircuitBreakers.mqh         # Emergency stops
│   │       │   ├── DrawdownMonitor.mqh         # Drawdown tracking
│   │       │   └── RiskLimits.mqh              # Risk validation
│   │       │
│   │       ├── Reporting/
│   │       │   ├── PerformanceMetrics.mqh      # P&L tracking
│   │       │   ├── DailyReport.mqh             # Daily summary
│   │       │   └── WeeklyAnalysis.mqh          # Weekly analysis
│   │       │
│   │       └── Licensing/
│   │           ├── LicenseValidator.mqh        # License validation
│   │           ├── X402Client.mqh              # X402 HTTP client
│   │           └── OfflineLicense.mqh          # Standalone license
│   │
│   └── Files/
│       └── BIONICLES/
│           ├── config.txt                       # Configuration
│           ├── license.key                      # License file
│           └── trades.csv                       # Trade log
│
├── Backend/                                     # Optional Rust backend
│   ├── Cargo.toml
│   ├── src/
│   │   ├── main.rs
│   │   ├── api/
│   │   │   ├── auth.rs
│   │   │   ├── trading.rs
│   │   │   └── licensing.rs
│   │   ├── x402/
│   │   │   ├── protocol.rs                     # X402 implementation
│   │   │   ├── validation.rs
│   │   │   └── middleware.rs
│   │   └── payments/
│   │       ├── subscription.rs
│   │       ├── webhook.rs
│   │       └── crypto_payment.rs               # Bitcoin/crypto support
│   │
│   └── migrations/
│       ├── 001_users.sql
│       ├── 002_subscriptions.sql
│       └── 003_licenses.sql
│
├── Docs/
│   ├── API_REFERENCE.md
│   ├── USER_MANUAL.md
│   ├── X402_PROTOCOL.md
│   ├── MATHEMATICAL_PROOFS.md
│   ├── BACKTESTING_RESULTS.md
│   └── DEPLOYMENT_GUIDE.md
│
└── Tests/
    ├── unit/
    │   ├── test_trend_lines.mq5
    │   ├── test_signals.mq5
    │   └── test_risk_mgmt.mq5
    └── integration/
        └── test_full_system.mq5
```

---

## X402 PAYMENT PROTOCOL INTEGRATION

### What is X402?

X402 (HTTP 402 Payment Required) is a payment protocol that enables pay-per-use and subscription models for API access. Unlike Stripe which requires account creation and payment processing, X402 is a protocol-level approach that can work with:
- Cryptocurrency payments (Bitcoin Lightning, Ethereum)
- Traditional payment processors
- Micropayment channels
- Token-based systems

### X402 vs Traditional Licensing

| Feature | Traditional License | X402 Protocol |
|---------|-------------------|---------------|
| Payment Method | One-time/Stripe | Flexible (crypto, fiat, tokens) |
| Validation | Local file/key | HTTP request to server |
| Offline Support | Yes | Limited (cached validation) |
| Multi-device | Single install | Any device with credentials |
| Updates | Manual | Automatic |
| Analytics | None | Full usage tracking |

### X402 Implementation in MQL5

#### Architecture

```
MQL5 EA (Client)                    Backend Server (Rust)
     │                                      │
     │  1. Request Trading Signal           │
     ├──────────────────────────────────────>│
     │                                      │
     │  2. HTTP 402 Payment Required        │
     │<────────────────────────────────────┤
     │    WWW-Authenticate: Bearer realm   │
     │    Payment-URI: /api/pay?amount=0.01│
     │                                      │
     │  3. Submit Payment Proof/Token       │
     ├──────────────────────────────────────>│
     │    Authorization: Bearer <token>     │
     │                                      │
     │  4. Validate Payment & License       │
     │                                      ├─> Database
     │                                      │   Check subscription
     │                                      │   Verify payment
     │                                      │   Log API call
     │                                      │
     │  5. Return Trading Data + Receipt    │
     │<────────────────────────────────────┤
     │    200 OK + Market Analysis          │
     │    X-Payment-Receipt: tx_12345       │
     │    X-Credits-Remaining: 9999         │
     │                                      │
     │  6. Execute Trade Locally            │
     ├─> MT5 Broker                         │
```

#### MQL5 X402 Client Implementation

```mql5
// Include/BIONICLES/Licensing/X402Client.mqh

class CX402Client {
private:
    string m_apiUrl;
    string m_apiKey;
    string m_userToken;
    datetime m_tokenExpiry;
    int m_creditsRemaining;
    bool m_isLicenseValid;

public:
    CX402Client(string apiUrl) {
        m_apiUrl = apiUrl;
        m_isLicenseValid = false;
        m_creditsRemaining = 0;
    }

    // Authenticate user and get JWT token
    bool Authenticate(string username, string password) {
        string url = m_apiUrl + "/auth/login";
        string payload = StringFormat("{\"username\":\"%s\",\"password\":\"%s\"}",
                                      username, password);

        char post[], result[];
        string headers = "Content-Type: application/json\r\n";

        StringToCharArray(payload, post, 0, WHOLE_ARRAY);

        int res = WebRequest("POST", url, headers, 5000, post, result, headers);

        if(res == 200) {
            // Parse JSON response
            string response = CharArrayToString(result);
            // Extract token (simplified - use JSON parser in production)
            if(StringFind(response, "\"token\":") >= 0) {
                // Extract token value
                m_userToken = ExtractToken(response);
                m_tokenExpiry = TimeCurrent() + 3600; // 1 hour
                return true;
            }
        }
        return false;
    }

    // Validate license with X402 protocol
    bool ValidateLicense() {
        if(TimeCurrent() < m_tokenExpiry && m_isLicenseValid) {
            return true; // Use cached validation
        }

        string url = m_apiUrl + "/api/license/validate";
        char post[], result[];
        string headers = StringFormat("Authorization: Bearer %s\r\nContent-Type: application/json\r\n",
                                      m_userToken);

        int res = WebRequest("GET", url, headers, 5000, post, result, headers);

        if(res == 200) {
            // License valid
            string response = CharArrayToString(result);
            m_creditsRemaining = ExtractCredits(response);
            m_isLicenseValid = true;
            m_tokenExpiry = TimeCurrent() + 300; // Cache for 5 minutes
            return true;
        }
        else if(res == 402) {
            // Payment Required
            string paymentUri = ExtractPaymentUri(headers);
            Print("License expired. Please renew at: ", paymentUri);
            m_isLicenseValid = false;
            return false;
        }
        else if(res == 401) {
            // Token expired - re-authenticate
            Print("Session expired. Please re-authenticate.");
            m_isLicenseValid = false;
            return false;
        }

        return false;
    }

    // Request trading signal with payment
    bool RequestTradingSignal(double &signalData[]) {
        if(!ValidateLicense()) {
            return false;
        }

        string url = m_apiUrl + "/api/trading/signal";
        char post[], result[];
        string headers = StringFormat("Authorization: Bearer %s\r\nContent-Type: application/json\r\n",
                                      m_userToken);

        int res = WebRequest("GET", url, headers, 5000, post, result, headers);

        if(res == 200) {
            // Parse signal data
            string response = CharArrayToString(result);
            ParseSignalData(response, signalData);

            // Update credits
            m_creditsRemaining = ExtractCreditsFromHeaders(headers);

            return true;
        }
        else if(res == 402) {
            // Payment required - show payment URI
            string paymentUri = ExtractPaymentUri(headers);
            Alert("Credits exhausted. Please add credits at: ", paymentUri);
            return false;
        }

        return false;
    }

    // Log trade execution (for analytics)
    void LogTrade(int ticket, int type, double lots, double price) {
        string url = m_apiUrl + "/api/trading/log";
        string payload = StringFormat("{\"ticket\":%d,\"type\":%d,\"lots\":%.2f,\"price\":%.5f}",
                                      ticket, type, lots, price);

        char post[], result[];
        string headers = StringFormat("Authorization: Bearer %s\r\nContent-Type: application/json\r\n",
                                      m_userToken);

        StringToCharArray(payload, post, 0, WHOLE_ARRAY);
        WebRequest("POST", url, headers, 5000, post, result, headers);
    }

    bool IsLicenseValid() { return m_isLicenseValid; }
    int GetCreditsRemaining() { return m_creditsRemaining; }

private:
    string ExtractToken(string json) {
        // Simplified token extraction
        int start = StringFind(json, "\"token\":\"") + 9;
        int end = StringFind(json, "\"", start);
        return StringSubstr(json, start, end - start);
    }

    int ExtractCredits(string json) {
        int start = StringFind(json, "\"credits_remaining\":") + 20;
        int end = StringFind(json, ",", start);
        if(end < 0) end = StringFind(json, "}", start);
        return (int)StringToInteger(StringSubstr(json, start, end - start));
    }

    string ExtractPaymentUri(string headers) {
        int start = StringFind(headers, "Payment-URI: ") + 13;
        int end = StringFind(headers, "\r\n", start);
        return StringSubstr(headers, start, end - start);
    }

    int ExtractCreditsFromHeaders(string headers) {
        int start = StringFind(headers, "X-Credits-Remaining: ") + 21;
        int end = StringFind(headers, "\r\n", start);
        return (int)StringToInteger(StringSubstr(headers, start, end - start));
    }

    void ParseSignalData(string json, double &data[]) {
        // Parse JSON signal data into array
        // Implementation depends on signal structure
    }
};
```

### X402 Backend Server (Rust)

```rust
// Backend/src/x402/protocol.rs

use actix_web::{HttpRequest, HttpResponse, web};
use chrono::Utc;

/// X402 Payment Required Response
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
        .json(serde_json::json!({
            "error": "payment_required",
            "message": "Active subscription required to access this resource",
            "payment_uri": payment_uri,
            "amount": amount,
            "currency": currency,
            "accepted_methods": ["bitcoin_lightning", "ethereum", "credit_card"]
        }))
}

/// Middleware to validate X402 payment/license
pub async fn validate_license_middleware(
    req: HttpRequest,
    db: web::Data<Database>,
    cache: web::Data<Cache>,
) -> Result<UserContext, HttpResponse> {
    // Extract JWT token
    let token = match extract_bearer_token(&req) {
        Some(t) => t,
        None => return Err(HttpResponse::Unauthorized().json(serde_json::json!({
            "error": "unauthorized",
            "message": "Bearer token required"
        }))),
    };

    // Validate JWT
    let claims = match jwt::validate_token(&token) {
        Ok(c) => c,
        Err(_) => return Err(HttpResponse::Unauthorized().json(serde_json::json!({
            "error": "invalid_token",
            "message": "Invalid or expired token"
        }))),
    };

    // Check license validity
    let license = match cache.get_license(&claims.sub).await {
        Ok(l) => l,
        Err(_) => {
            // Cache miss - check database
            match db.get_active_license(&claims.sub).await {
                Ok(l) => {
                    cache.set_license(&claims.sub, &l, 300).await.ok();
                    l
                }
                Err(_) => {
                    return Err(payment_required_response(
                        "https://bionicles.io/subscribe",
                        "BIONICLES Trading API",
                        9.0,
                        "USD"
                    ));
                }
            }
        }
    };

    // Check expiration
    if license.expires_at < Utc::now() {
        return Err(payment_required_response(
            &format!("https://bionicles.io/renew?license={}", license.id),
            "BIONICLES Trading API",
            9.0,
            "USD"
        ));
    }

    // Check API rate limit
    if license.api_calls_used_today >= license.max_api_calls_per_day {
        return Err(payment_required_response(
            &format!("https://bionicles.io/upgrade?user={}", claims.sub),
            "BIONICLES Trading API - Rate Limit",
            0.01, // Micr payment for additional calls
            "USD"
        ));
    }

    // Increment API counter
    db.increment_api_call(&license.id).await.ok();

    // Return user context
    Ok(UserContext {
        user_id: claims.sub,
        email: claims.email,
        tier: license.tier,
        license,
        request_id: uuid::Uuid::new_v4().to_string(),
    })
}

fn extract_bearer_token(req: &HttpRequest) -> Option<String> {
    req.headers()
        .get("Authorization")?
        .to_str()
        .ok()?
        .strip_prefix("Bearer ")?
        .to_string()
        .into()
}
```

### Subscription Tiers with X402

| Tier | Price | Features | API Calls/Day | Payment Method |
|------|-------|----------|---------------|----------------|
| **Starter** | $9/quarter | 1 account, basic analytics | 1,000 | Card/Crypto |
| **Professional** | $29/quarter | 3 accounts, advanced analytics, API access | 10,000 | Card/Crypto |
| **Enterprise** | Custom | Unlimited accounts, white-label, dedicated support | Unlimited | Invoice/Crypto |

### Payment Flow

```
User Registration
       │
       ▼
Choose Subscription Tier
       │
       ▼
Payment (Card/Bitcoin/Ethereum)
       │
       ▼
Backend Creates:
  - Subscription record
  - License with expiry
  - API credentials
       │
       ▼
User receives:
  - API key
  - Login credentials
  - License details
       │
       ▼
Configure MQL5 EA:
  - Enter API credentials
  - Enable X402 mode
  - Test connection
       │
       ▼
EA validates license every 5 minutes
       │
       ├─> Valid: Continue trading
       │
       └─> Invalid/Expired: Show payment URI
                            │
                            ▼
                     User renews subscription
                            │
                            ▼
                     Backend updates license
                            │
                            ▼
                     EA resumes automatically
```

---

## MODULE SPECIFICATIONS

### Module 1: Trend Line Detection (TrendLineDetection.mqh)

**Purpose**: Calculate upper and lower trend lines using linear regression

**Mathematical Foundation**:
```
Upper Line: y_upper = m₁ × x + b₁
Lower Line: y_lower = m₂ × x + b₂

Where:
m = (n×Σ(xy) - Σx×Σy) / (n×Σ(x²) - (Σx)²)
b = (Σy - m×Σx) / n
```

**Key Functions**:
```mql5
struct STrendLine {
    double slope;           // m (slope)
    double intercept;       // b (y-intercept)
    double touchPoints[];   // Bar indices where price touched line
    int touchCount;         // Number of valid touches
    datetime startTime;
    datetime endTime;
};

class CTrendLineDetection {
public:
    // Calculate upper resistance line
    static bool CalculateUpperLine(
        const double &highs[],
        const int lookback,
        STrendLine &line
    );

    // Calculate lower support line
    static bool CalculateLowerLine(
        const double &lows[],
        const int lookback,
        STrendLine &line
    );

    // Validate trend line (minimum 2 touch points)
    static bool ValidateTrendLine(
        const STrendLine &line,
        const double &prices[],
        const double atr
    );

    // Get price at specific bar
    static double GetPriceAtBar(
        const STrendLine &line,
        const int bar
    );

private:
    // Linear regression calculation
    static void LinearRegression(
        const double &x[],
        const double &y[],
        const int count,
        double &slope,
        double &intercept
    );

    // Find peak points for upper line
    static void FindPeaks(
        const double &highs[],
        const int lookback,
        int &peaks[]
    );

    // Find valley points for lower line
    static void FindValleys(
        const double &lows[],
        const int lookback,
        int &valleys[]
    );
};
```

**Implementation Details**:
- Use last 60 bars (4H timeframe = 10 days)
- Touch validation: Distance < ATR × 0.3
- Minimum 2 touch points required
- Update lines every new bar

---

### Module 2: Convergence Analysis (ConvergenceAnalysis.mqh)

**Purpose**: Calculate wedge compression and predict breakout timing

**Mathematical Foundation**:
```
Width(bar) = y_upper(bar) - y_lower(bar)
Width(bar) = (m₁ - m₂) × bar + (b₁ - b₂)

Convergence Point:
x_convergence = (b₂ - b₁) / (m₁ - m₂)

Bars to Convergence = x_convergence - current_bar
Days to Convergence = Bars_to_Convergence / 6
```

**Key Functions**:
```mql5
struct SConvergenceData {
    double currentWidth;          // Current channel width (pips)
    double compressionRate;       // Rate of narrowing per bar
    int barsToConvergence;       // Bars until convergence
    double convergencePrice;      // Price at convergence point
    double compressionPercent;    // % change in width
    bool isWedgeValid;           // Pattern integrity check
};

class CConvergenceAnalysis {
public:
    // Calculate convergence metrics
    static bool CalculateConvergence(
        const STrendLine &upperLine,
        const STrendLine &lowerLine,
        const int currentBar,
        SConvergenceData &data
    );

    // Check if wedge is compressing (not expanding)
    static bool IsCompressing(
        const SConvergenceData &data,
        const double threshold = -2.0  // -2% per bar
    );

    // Check if breakout is imminent
    static bool IsBreakoutImminent(
        const SConvergenceData &data,
        const int minBars = 3,
        const int maxBars = 30
    );

    // Calculate middle line (50% between upper/lower)
    static double GetMiddleLine(
        const STrendLine &upperLine,
        const STrendLine &lowerLine,
        const int bar
    );
};
```

---

### Module 3: Price Position Detection (PricePosition.mqh)

**Purpose**: Determine where current price is relative to wedge channels

**Mathematical Foundation**:
```
Position_Ratio = (Close - y_lower) / (y_upper - y_lower)

Interpretation:
< 0.15: At support (buy zone)
> 0.85: At resistance (sell zone)
0.4-0.6: Neutral zone (no signal)
```

**Key Functions**:
```mql5
enum ENUM_PRICE_ZONE {
    ZONE_SUPPORT,      // Position ratio < 0.20
    ZONE_RESISTANCE,   // Position ratio > 0.80
    ZONE_NEUTRAL,      // In between
    ZONE_OUTSIDE       // Price broke channel
};

struct SPricePosition {
    double positionRatio;     // 0.0 to 1.0 (0 = at lower line, 1 = at upper)
    ENUM_PRICE_ZONE zone;     // Current zone
    double distanceToSupport; // Pips to lower line
    double distanceToResistance; // Pips to upper line
    bool isTouchingSupport;   // Within ATR×0.3 of lower line
    bool isTouchingResistance; // Within ATR×0.3 of upper line
};

class CPricePosition {
public:
    // Calculate current price position
    static bool CalculatePosition(
        const double currentPrice,
        const STrendLine &upperLine,
        const STrendLine &lowerLine,
        const int currentBar,
        const double atr,
        SPricePosition &position
    );

    // Check if price is touching support
    static bool IsTouchingSupport(
        const double price,
        const STrendLine &lowerLine,
        const int bar,
        const double atr,
        const double threshold = 0.3
    );

    // Check if price is touching resistance
    static bool IsTouchingResistance(
        const double price,
        const STrendLine &upperLine,
        const int bar,
        const double atr,
        const double threshold = 0.3
    );
};
```

---

### Module 4: Signal Generator (SignalGenerator.mqh)

**Purpose**: Generate buy/sell signals based on multi-factor confirmation

**Signal Conditions**:

**BUY Signal**:
1. Close ≤ y_lower + (ATR × 0.5)
2. Position_Ratio < 0.20
3. Compression_Percentage > -2%
4. RSI(14) < 40
5. Bars_to_Convergence > 3

**SELL Signal**:
1. Close ≥ y_upper - (ATR × 0.5)
2. Position_Ratio > 0.80
3. Compression_Percentage > -2%
4. RSI(14) > 60
5. Bars_to_Convergence > 3

**Key Functions**:
```mql5
enum ENUM_SIGNAL_TYPE {
    SIGNAL_NONE,
    SIGNAL_BUY,
    SIGNAL_SELL
};

struct SEntrySignal {
    ENUM_SIGNAL_TYPE type;
    double entryPrice;
    double stopLoss;
    double takeProfit;
    double lotSize;
    string reason;              // Human-readable signal explanation
    datetime signalTime;
    bool isValid;

    // Confirmation factors
    bool conditionA;            // Price at line
    bool conditionB;            // Position ratio
    bool conditionC;            // Compression intact
    bool conditionD;            // RSI confirmation
    bool conditionE;            // Convergence timing
};

class CSignalGenerator {
public:
    // Generate trading signal
    static ENUM_SIGNAL_TYPE GenerateSignal(
        const double currentPrice,
        const STrendLine &upperLine,
        const STrendLine &lowerLine,
        const SConvergenceData &convergence,
        const SPricePosition &position,
        const double rsi,
        const double atr,
        const int currentBar,
        SEntrySignal &signal
    );

    // Check BUY conditions
    static bool CheckBuyConditions(
        const double price,
        const STrendLine &lowerLine,
        const SConvergenceData &convergence,
        const SPricePosition &position,
        const double rsi,
        const double atr,
        const int bar,
        SEntrySignal &signal
    );

    // Check SELL conditions
    static bool CheckSellConditions(
        const double price,
        const STrendLine &upperLine,
        const SConvergenceData &convergence,
        const SPricePosition &position,
        const double rsi,
        const double atr,
        const int bar,
        SEntrySignal &signal
    );

    // Validate all 5 conditions
    static bool ValidateSignal(const SEntrySignal &signal);
};
```

---

### Module 5: Risk Management (RiskManagement.mqh)

**Purpose**: Calculate position size, stop loss, and take profit (1:3 R:R)

**Mathematical Foundation**:
```
Max Risk Per Trade = Account Balance × 2%

FOR LONG:
Entry = y_lower + (ATR × 0.25)
Stop Loss = y_lower - (ATR × 1.5)
Stop Distance = Entry - Stop Loss
Take Profit = Entry + (Stop Distance × 3)

FOR SHORT:
Entry = y_upper - (ATR × 0.25)
Stop Loss = y_upper + (ATR × 1.5)
Stop Distance = Stop Loss - Entry
Take Profit = Entry - (Stop Distance × 3)

Position Size = Max Risk / (Stop Distance in pips × Pip Value)
```

**Key Functions**:
```mql5
struct SPositionSize {
    double lots;                  // Position size in lots
    double riskAmount;            // USD risk amount
    double stopDistancePips;      // Stop distance in pips
    double takeProfitPips;        // TP distance in pips
    double riskRewardRatio;       // Should always be 3.0
    bool isValid;
};

class CRiskManagement {
public:
    // Calculate position size
    static bool CalculatePositionSize(
        const double accountBalance,
        const double maxRiskPercent,
        const SEntrySignal &signal,
        const string symbol,
        SPositionSize &position
    );

    // Calculate stop loss level
    static double CalculateStopLoss(
        const ENUM_SIGNAL_TYPE signalType,
        const STrendLine &trendLine,
        const int currentBar,
        const double atr,
        const double multiplier = 1.5
    );

    // Calculate take profit level (1:3 ratio)
    static double CalculateTakeProfit(
        const ENUM_SIGNAL_TYPE signalType,
        const double entryPrice,
        const double stopLoss,
        const double ratio = 3.0
    );

    // Validate risk-reward ratio
    static bool ValidateRiskReward(
        const double entry,
        const double stopLoss,
        const double takeProfit,
        const ENUM_SIGNAL_TYPE type,
        const double expectedRatio = 3.0
    );

    // Check portfolio risk limits
    static bool CheckPortfolioRisk(
        const double newTradeRisk,
        const double maxPortfolioRisk,
        const double currentPortfolioRisk
    );

    // Get pip value for symbol
    static double GetPipValue(
        const string symbol,
        const double lots
    );
};
```

---

### Module 6: Trade Management (TradeManagement.mqh)

**Purpose**: Monitor and manage active trades (trailing stops, breakeven, scaling)

**Management Rules**:
1. **Breakeven Protection**: When profit > 1×ATR, move SL to entry + 5 pips
2. **Trailing Stop**: When profit > 1×ATR, trail SL at Price - ATR (for longs)
3. **Partial Profit**: At 50% of TP, scale out 50% of position
4. **Invalidation**: If wedge breaks, close trade immediately

**Key Functions**:
```mql5
struct STradeStatus {
    int ticket;
    ENUM_SIGNAL_TYPE type;
    double entryPrice;
    double currentPrice;
    double stopLoss;
    double takeProfit;
    double currentPL;
    double currentPLPercent;
    bool isBreakevenActive;
    bool isTrailingActive;
    datetime entryTime;
    datetime lastUpdate;
};

class CTradeManagement {
public:
    // Update all active trades
    static void ManageActiveTrades(
        STradeStatus &trades[],
        const STrendLine &upperLine,
        const STrendLine &lowerLine,
        const double atr,
        const int currentBar
    );

    // Move stop loss to breakeven
    static bool MoveToBreakeven(
        const int ticket,
        const double entryPrice,
        const ENUM_SIGNAL_TYPE type,
        const double minProfit
    );

    // Apply trailing stop
    static bool ApplyTrailingStop(
        const int ticket,
        const ENUM_SIGNAL_TYPE type,
        const double currentPrice,
        const double atr,
        const double atrMultiplier = 1.0
    );

    // Scale out position (take partial profit)
    static bool ScaleOutPosition(
        const int ticket,
        const double percent = 50.0
    );

    // Check if trade should be closed (wedge invalidation)
    static bool ShouldCloseTradeEarly(
        const STradeStatus &trade,
        const STrendLine &upperLine,
        const STrendLine &lowerLine,
        const int currentBar
    );

    // Close trade manually
    static bool CloseTrade(
        const int ticket,
        const string reason
    );
};
```

---

### Module 7: Breakout Detection (BreakoutDetection.mqh)

**Purpose**: Detect when wedge is about to break and manage exits

**Breakout Criteria**:
```
Pre-Breakout Warning:
- Bars_to_Convergence < 5
- Compression > 70% from initial width

Breakout Confirmation:
- Close price outside both lines
- 2 consecutive 4H bars hold outside
- Price > Middle_Line (for upside) or < Middle_Line (for downside)
```

**Key Functions**:
```mql5
enum ENUM_BREAKOUT_DIRECTION {
    BREAKOUT_NONE,
    BREAKOUT_UPSIDE,
    BREAKOUT_DOWNSIDE,
    BREAKOUT_AMBIGUOUS
};

struct SBreakoutData {
    ENUM_BREAKOUT_DIRECTION direction;
    double breakoutPrice;
    datetime breakoutTime;
    double breakoutProbability;    // 0.0 to 1.0
    bool isConfirmed;              // 2 consecutive bars
    int consecutiveBars;
};

class CBreakoutDetection {
public:
    // Detect breakout conditions
    static bool DetectBreakout(
        const double currentPrice,
        const double previousPrice,
        const STrendLine &upperLine,
        const STrendLine &lowerLine,
        const SConvergenceData &convergence,
        const int currentBar,
        SBreakoutData &breakout
    );

    // Check if pre-breakout warning should be triggered
    static bool IsPreBreakoutWarning(
        const SConvergenceData &convergence,
        const int warningBars = 5
    );

    // Calculate breakout probability
    static double CalculateBreakoutProbability(
        const SConvergenceData &convergence,
        const double compressionRate
    );

    // Determine breakout direction
    static ENUM_BREAKOUT_DIRECTION GetBreakoutDirection(
        const double price,
        const double middleLine,
        const double previousClose
    );

    // Handle active trades during breakout
    static void HandleBreakoutTrades(
        STradeStatus &trades[],
        const SBreakoutData &breakout
    );
};
```

---

## MATHEMATICAL FOUNDATION

### Linear Regression Details

**Formula**:
```
Given n points (x₁, y₁), (x₂, y₂), ..., (xₙ, yₙ)

Slope: m = (n×Σ(xᵢ×yᵢ) - Σxᵢ×Σyᵢ) / (n×Σ(xᵢ²) - (Σxᵢ)²)

Intercept: b = (Σyᵢ - m×Σxᵢ) / n

Line equation: y = m×x + b
```

**MQL5 Implementation**:
```mql5
void CTrendLineDetection::LinearRegression(
    const double &x[],
    const double &y[],
    const int count,
    double &slope,
    double &intercept
) {
    double sumX = 0.0, sumY = 0.0;
    double sumXY = 0.0, sumX2 = 0.0;

    for(int i = 0; i < count; i++) {
        sumX += x[i];
        sumY += y[i];
        sumXY += x[i] * y[i];
        sumX2 += x[i] * x[i];
    }

    double n = (double)count;
    double denominator = (n * sumX2) - (sumX * sumX);

    if(denominator != 0) {
        slope = ((n * sumXY) - (sumX * sumY)) / denominator;
        intercept = (sumY - (slope * sumX)) / n;
    } else {
        slope = 0.0;
        intercept = 0.0;
    }
}
```

### ATR (Average True Range) Calculation

**Purpose**: Measure market volatility for stop loss placement

**Formula**:
```
True Range = Max(
    High - Low,
    |High - Previous Close|,
    |Low - Previous Close|
)

ATR(n) = EMA of True Range over n periods

For n=14 (standard):
α = 2 / (n + 1) = 0.1333

ATR_current = α × TR_current + (1 - α) × ATR_previous
```

**MQL5 Implementation**:
```mql5
double CalculateATR(const string symbol, const int period, const int shift = 0) {
    double atr = iATR(symbol, PERIOD_H4, period);
    return NormalizeDouble(atr, _Digits);
}
```

### RSI (Relative Strength Index) Calculation

**Purpose**: Identify overbought/oversold conditions

**Formula**:
```
RS = Average Gain / Average Loss (over n periods)

RSI = 100 - (100 / (1 + RS))

For n=14 (standard):
Average Gain = EMA of gains
Average Loss = EMA of losses
```

**Interpretation**:
- RSI < 30: Oversold (potential buy)
- RSI > 70: Overbought (potential sell)
- **Our thresholds**: RSI < 40 (buy), RSI > 60 (sell)

**MQL5 Implementation**:
```mql5
double CalculateRSI(const string symbol, const int period, const int shift = 0) {
    double rsi = iRSI(symbol, PERIOD_H4, period, PRICE_CLOSE);
    return NormalizeDouble(rsi, 2);
}
```

### Risk-Reward Ratio Calculation

**Formula**:
```
Risk = Entry Price - Stop Loss (for long)
Reward = Take Profit - Entry Price (for long)

Risk-Reward Ratio = Reward / Risk

For 1:3 ratio:
Reward = Risk × 3
Take Profit = Entry + (Entry - Stop Loss) × 3
```

**Validation**:
```mql5
bool CRiskManagement::ValidateRiskReward(
    const double entry,
    const double stopLoss,
    const double takeProfit,
    const ENUM_SIGNAL_TYPE type,
    const double expectedRatio = 3.0
) {
    double risk, reward, actualRatio;

    if(type == SIGNAL_BUY) {
        risk = entry - stopLoss;
        reward = takeProfit - entry;
    } else {
        risk = stopLoss - entry;
        reward = entry - takeProfit;
    }

    if(risk <= 0) return false;

    actualRatio = reward / risk;

    // Allow 1% tolerance
    return (MathAbs(actualRatio - expectedRatio) < 0.03);
}
```

---

## IMPLEMENTATION PLAN

### Phase 1: Core Infrastructure (Days 1-3)

#### Day 1: Project Setup & Utilities
- [ ] Create project folder structure
- [ ] Set up Git repository
- [ ] Create `MathUtils.mqh` (linear regression, statistics)
- [ ] Create `Indicators.mqh` (ATR, RSI wrappers)
- [ ] Create `Logger.mqh` (file logging system)
- [ ] Create `Validators.mqh` (input validation)
- [ ] Write unit tests for utilities

#### Day 2: Data Structures & Types
- [ ] Define all structs in main EA file
- [ ] Create `OrderManager.mqh` (order execution wrapper)
- [ ] Create `PositionTracker.mqh` (position management)
- [ ] Create `BrokerInterface.mqh` (broker-specific functions)
- [ ] Test order execution on demo account

#### Day 3: Licensing System
- [ ] Create `OfflineLicense.mqh` (file-based licensing)
- [ ] Create `X402Client.mqh` (HTTP 402 protocol client)
- [ ] Create `LicenseValidator.mqh` (validation logic)
- [ ] Test license validation (both modes)

### Phase 2: Core Trading Modules (Days 4-7)

#### Day 4: Module 1 & 2
- [ ] Implement `TrendLineDetection.mqh`
  - Linear regression functions
  - Peak/valley detection
  - Touch point validation
- [ ] Implement `ConvergenceAnalysis.mqh`
  - Width calculation
  - Compression rate
  - Breakout timing
- [ ] Unit tests for trend line accuracy

#### Day 5: Module 3 & 4
- [ ] Implement `PricePosition.mqh`
  - Position ratio calculation
  - Zone detection
  - Touch validation
- [ ] Implement `SignalGenerator.mqh`
  - Buy signal logic
  - Sell signal logic
  - Multi-factor validation
- [ ] Test signal generation on historical data

#### Day 6: Module 5
- [ ] Implement `RiskManagement.mqh`
  - Position sizing
  - Stop loss calculation
  - Take profit calculation (1:3 ratio)
  - Portfolio risk tracking
- [ ] Test risk calculations with various account sizes

#### Day 7: Module 6 & 7
- [ ] Implement `TradeManagement.mqh`
  - Breakeven logic
  - Trailing stops
  - Position scaling
- [ ] Implement `BreakoutDetection.mqh`
  - Breakout detection
  - Direction analysis
  - Trade invalidation
- [ ] Test trade management scenarios

### Phase 3: Safety & Reporting (Days 8-9)

#### Day 8: Safety Systems
- [ ] Implement `CircuitBreakers.mqh`
  - Daily drawdown monitor
  - Consecutive loss counter
  - Emergency stop logic
- [ ] Implement `DrawdownMonitor.mqh`
  - Equity tracking
  - Drawdown calculation
  - Alert system
- [ ] Implement `RiskLimits.mqh`
  - Portfolio risk validation
  - Concurrent trade limits
  - Same-direction limits

#### Day 9: Reporting & Analytics
- [ ] Implement `PerformanceMetrics.mqh`
  - P&L tracking
  - Win rate calculation
  - Profit factor
  - Sharpe ratio
- [ ] Implement `DailyReport.mqh`
  - Daily summary generation
  - CSV export
- [ ] Implement `WeeklyAnalysis.mqh`
  - Weekly performance review
  - Pattern analysis

### Phase 4: Main EA Integration (Days 10-11)

#### Day 10: Main EA Logic
- [ ] Create `WedgeTradingSystem.mq5`
- [ ] Implement `OnInit()` function
  - Load configuration
  - Validate license
  - Initialize modules
  - Set up logging
- [ ] Implement `OnTick()` function
  - Check for new bar
  - Update trend lines
  - Generate signals
  - Execute trades
  - Manage positions
- [ ] Implement `OnDeinit()` function
  - Close all positions (optional)
  - Save final report
  - Clean up resources

#### Day 11: Event Handlers
- [ ] Implement `OnTimer()` function
  - Periodic license validation
  - Heartbeat logging
  - Status updates
- [ ] Implement `OnTrade()` function
  - Trade execution logging
  - Performance tracking
- [ ] Error handling and recovery

### Phase 5: Testing & Optimization (Days 12-14)

#### Day 12: Unit Testing
- [ ] Test each module independently
- [ ] Verify mathematical accuracy
- [ ] Test edge cases (zero convergence, invalid data)
- [ ] Validate license system

#### Day 13: Integration Testing
- [ ] Run full system on demo account
- [ ] Test with live market data (no real trades)
- [ ] Verify signal generation accuracy
- [ ] Test safety protocols (manually trigger drawdown)
- [ ] Validate reporting

#### Day 14: Backtesting
- [ ] Run backtest on 1 year EURUSD data
- [ ] Verify results:
  - Win rate > 40%
  - Profit factor > 1.5
  - Max drawdown < 15%
  - All trades 1:3 R:R
- [ ] Optimize parameters if needed
- [ ] Document results

### Phase 6: Documentation & Deployment (Days 15-16)

#### Day 15: Documentation
- [ ] Write `USER_MANUAL.md`
- [ ] Write `API_REFERENCE.md`
- [ ] Write `X402_PROTOCOL.md`
- [ ] Write `DEPLOYMENT_GUIDE.md`
- [ ] Create configuration templates
- [ ] Record video tutorial

#### Day 16: Deployment
- [ ] Create installer package
- [ ] Set up licensing server (if using X402)
- [ ] Deploy to MT5 market (optional)
- [ ] Create support documentation
- [ ] Launch!

### Phase 7: Backend (Optional - Days 17-21)

If implementing SaaS mode with Rust backend:

#### Days 17-19: Rust Backend
- [ ] Set up Rust project
- [ ] Implement X402 protocol handlers
- [ ] Create authentication system
- [ ] Implement license management
- [ ] Set up PostgreSQL database
- [ ] Create payment integration (Bitcoin/Ethereum)

#### Days 20-21: Web Dashboard
- [ ] Create user registration/login
- [ ] Build dashboard (trades, performance, analytics)
- [ ] Implement payment portal
- [ ] Set up webhooks for renewals
- [ ] Deploy to cloud (AWS/DigitalOcean)

---

## DEPLOYMENT STRATEGY

### Standalone Deployment

**Requirements**:
- MetaTrader 5 terminal
- Windows/Linux/Mac OS
- Minimum 2GB RAM
- Stable internet connection

**Installation Steps**:
1. Copy EA file to `MT5/MQL5/Experts/BIONICLES/`
2. Copy include files to `MT5/MQL5/Include/BIONICLES/`
3. Copy license file to `MT5/MQL5/Files/BIONICLES/license.key`
4. Restart MT5 terminal
5. Attach EA to EURUSD 4H chart
6. Configure parameters
7. Enable auto-trading
8. Monitor logs

**Configuration**:
```ini
// config.txt
[General]
LicenseMode=OFFLINE
LicenseKey=XXXX-XXXX-XXXX-XXXX

[Trading]
LookbackBars=60
MaxRiskPercent=2.0
MaxPortfolioRisk=5.0
RiskRewardRatio=3.0

[Safety]
DailyDrawdownLimit=10.0
MaxConsecutiveLosses=5
```

### SaaS Deployment

**Architecture**:
```
User → MT5 EA → API Gateway → Backend → Database
                    ↓
                Payment Processor (Bitcoin/Stripe)
```

**Requirements**:
- VPS/Cloud server (2GB RAM minimum)
- PostgreSQL database
- Redis cache
- SSL certificate
- Domain name

**Backend Deployment**:
```bash
# Clone repository
git clone https://github.com/BIONICLES/trading-system.git
cd trading-system/Backend

# Set up environment
cp .env.example .env
# Edit .env with database credentials, API keys, etc.

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Build and run
cargo build --release
cargo run --release

# Or use Docker
docker-compose up -d
```

**Environment Variables**:
```env
DATABASE_URL=postgresql://user:pass@localhost/bionicles
REDIS_URL=redis://localhost:6379
JWT_SECRET=your-secret-key
BITCOIN_RPC_URL=http://localhost:8332
STRIPE_SECRET_KEY=sk_live_...
SERVER_HOST=0.0.0.0
SERVER_PORT=8080
```

**Database Setup**:
```bash
# Run migrations
diesel migration run

# Or use included SQL scripts
psql -U postgres -d bionicles -f migrations/001_users.sql
psql -U postgres -d bionicles -f migrations/002_subscriptions.sql
psql -U postgres -d bionicles -f migrations/003_licenses.sql
```

**EA Configuration for SaaS**:
```ini
[General]
LicenseMode=X402
APIUrl=https://api.bionicles.io

[Auth]
Username=your-email@example.com
Password=your-password
# Or use API key
APIKey=your-api-key
```

### Scaling Considerations

**Single Server** (up to 100 users):
- 2 CPU cores
- 4GB RAM
- PostgreSQL + Redis on same server
- Handles ~10,000 API requests/day

**Multi-Server** (100-1000 users):
- Load balancer (Nginx)
- 2+ API servers (horizontal scaling)
- Separate database server
- Redis cluster for caching
- Handles ~100,000 API requests/day

**Enterprise** (1000+ users):
- Kubernetes cluster
- Auto-scaling based on load
- Multi-region deployment
- Database replication
- CDN for static assets
- Handles millions of API requests/day

---

## TESTING & VALIDATION

### Unit Testing Framework

Create test files in `Tests/unit/`:

**test_trend_lines.mq5**:
```mql5
#include <BIONICLES/Core/TrendLineDetection.mqh>

void OnStart() {
    // Test 1: Linear Regression
    double x[] = {0, 1, 2, 3, 4};
    double y[] = {1.0, 2.0, 3.0, 4.0, 5.0};
    double slope, intercept;

    CTrendLineDetection::LinearRegression(x, y, 5, slope, intercept);

    if(MathAbs(slope - 1.0) < 0.001 && MathAbs(intercept - 1.0) < 0.001) {
        Print("✓ Linear regression test passed");
    } else {
        Print("✗ Linear regression test FAILED");
    }

    // Test 2: Peak Detection
    double highs[] = {1.1000, 1.1010, 1.1005, 1.1020, 1.1015, 1.1025};
    int peaks[];
    CTrendLineDetection::FindPeaks(highs, 6, peaks);

    Print("✓ Peak detection test completed. Found ", ArraySize(peaks), " peaks");
}
```

**test_signals.mq5**:
```mql5
#include <BIONICLES/Core/SignalGenerator.mqh>

void OnStart() {
    // Test BUY signal generation
    STrendLine upperLine, lowerLine;
    upperLine.slope = -0.0001;
    upperLine.intercept = 1.1050;
    lowerLine.slope = -0.00005;
    lowerLine.intercept = 1.1000;

    SConvergenceData convergence;
    convergence.barsToConvergence = 10;
    convergence.compressionPercent = -1.5;

    SPricePosition position;
    position.positionRatio = 0.15;

    SEntrySignal signal;
    ENUM_SIGNAL_TYPE result = CSignalGenerator::GenerateSignal(
        1.1005,      // Current price (near support)
        upperLine,
        lowerLine,
        convergence,
        position,
        35.0,        // RSI = 35 (oversold)
        0.0010,      // ATR
        50,          // Current bar
        signal
    );

    if(result == SIGNAL_BUY) {
        Print("✓ BUY signal test passed");
    } else {
        Print("✗ BUY signal test FAILED. Got: ", EnumToString(result));
    }
}
```

**test_risk_mgmt.mq5**:
```mql5
#include <BIONICLES/Core/RiskManagement.mqh>

void OnStart() {
    // Test position sizing
    SEntrySignal signal;
    signal.type = SIGNAL_BUY;
    signal.entryPrice = 1.1010;
    signal.stopLoss = 1.0980;  // 30 pips stop
    signal.takeProfit = 1.1100; // 90 pips TP (1:3 ratio)

    SPositionSize position;
    bool result = CRiskManagement::CalculatePositionSize(
        10000.0,      // $10,000 account
        2.0,          // 2% risk
        signal,
        "EURUSD",
        position
    );

    Print("Position size: ", position.lots, " lots");
    Print("Risk amount: $", position.riskAmount);
    Print("Stop distance: ", position.stopDistancePips, " pips");
    Print("R:R ratio: 1:", position.riskRewardRatio);

    if(result && position.riskRewardRatio >= 2.9 && position.riskRewardRatio <= 3.1) {
        Print("✓ Risk management test passed");
    } else {
        Print("✗ Risk management test FAILED");
    }
}
```

### Integration Testing

**Full System Test**:
```mql5
// Tests/integration/test_full_system.mq5

#property script_show_inputs
input int TestBars = 100;  // Number of bars to simulate

#include <BIONICLES/Core/TrendLineDetection.mqh>
#include <BIONICLES/Core/ConvergenceAnalysis.mqh>
#include <BIONICLES/Core/SignalGenerator.mqh>
#include <BIONICLES/Core/RiskManagement.mqh>

void OnStart() {
    Print("Starting full system integration test...");

    int signals = 0;
    int validSignals = 0;
    int trades = 0;

    for(int i = TestBars; i >= 0; i--) {
        // 1. Calculate trend lines
        STrendLine upperLine, lowerLine;
        double highs[], lows[];
        ArrayResize(highs, 60);
        ArrayResize(lows, 60);

        for(int j = 0; j < 60; j++) {
            highs[j] = iHigh(_Symbol, PERIOD_H4, i + j);
            lows[j] = iLow(_Symbol, PERIOD_H4, i + j);
        }

        CTrendLineDetection::CalculateUpperLine(highs, 60, upperLine);
        CTrendLineDetection::CalculateLowerLine(lows, 60, lowerLine);

        // 2. Calculate convergence
        SConvergenceData convergence;
        CConvergenceAnalysis::CalculateConvergence(upperLine, lowerLine, i, convergence);

        // 3. Get price position
        SPricePosition position;
        double currentPrice = iClose(_Symbol, PERIOD_H4, i);
        double atr = iATR(_Symbol, PERIOD_H4, 14, i);

        CPricePosition::CalculatePosition(currentPrice, upperLine, lowerLine, i, atr, position);

        // 4. Generate signal
        double rsi = iRSI(_Symbol, PERIOD_H4, 14, PRICE_CLOSE, i);
        SEntrySignal signal;

        ENUM_SIGNAL_TYPE signalType = CSignalGenerator::GenerateSignal(
            currentPrice, upperLine, lowerLine, convergence, position, rsi, atr, i, signal
        );

        if(signalType != SIGNAL_NONE) {
            signals++;

            // 5. Calculate position size
            SPositionSize posSize;
            if(CRiskManagement::CalculatePositionSize(10000.0, 2.0, signal, _Symbol, posSize)) {
                validSignals++;

                Print(StringFormat("Bar %d: %s signal at %.5f, SL: %.5f, TP: %.5f, Size: %.2f lots",
                                   i, EnumToString(signalType), signal.entryPrice,
                                   signal.stopLoss, signal.takeProfit, posSize.lots));

                trades++;
            }
        }
    }

    Print("=== Integration Test Results ===");
    Print("Total signals detected: ", signals);
    Print("Valid signals: ", validSignals);
    Print("Trades that would execute: ", trades);
    Print("Signal quality: ", (validSignals * 100.0 / MathMax(signals, 1)), "%");
}
```

### Backtesting Checklist

**Strategy Tester Settings**:
- Symbol: EURUSD
- Period: H4
- Date range: 1 year (e.g., 2023-01-01 to 2024-01-01)
- Model: Every tick based on real ticks
- Initial deposit: $10,000
- Leverage: 1:100

**Expected Results**:
- [ ] Total trades: 30-60 per year
- [ ] Win rate: > 40%
- [ ] Profit factor: > 1.5
- [ ] Max drawdown: < 15%
- [ ] All trades: 1:3 R:R ratio verified
- [ ] Average win: ~60 pips
- [ ] Average loss: ~20 pips
- [ ] Net profit: > $2,000 (20% annual return)

**Validation Steps**:
1. Run backtest with default parameters
2. Review trade log - verify all trades have 1:3 R:R
3. Check max consecutive losses < 5
4. Verify no trades during breakouts
5. Confirm stop loss never wider than 50 pips
6. Validate position sizing (max risk 2% per trade)
7. Review daily drawdown (should never exceed 10%)

---

## PERFORMANCE TARGETS

### 90-Day Goals

**Trading Performance**:
- Minimum 20 trades executed
- Win rate: ≥ 40%
- Profit factor: ≥ 1.5
- Average R:R: 1:3 (exactly)
- Maximum drawdown: < 12%
- Net profit: ≥ +10% account growth

**System Reliability**:
- Uptime: > 99.5%
- Signal accuracy: > 80% (signals that meet criteria)
- Zero missed wedge patterns
- Emergency stop triggers: 0
- License validation success: 100%

**Risk Management**:
- No single trade risk > 2%
- Portfolio risk never > 5%
- No more than 3 concurrent trades
- Trailing stop hit rate: > 30% of winning trades
- Breakeven protection activated: > 50% of trades

### Yearly Goals

**Trading Performance**:
- 60-100 trades per year
- Win rate: ≥ 45%
- Profit factor: ≥ 2.0
- Annual return: 25-40%
- Max drawdown: < 15%
- Sharpe ratio: > 1.5

**Business Metrics** (SaaS Mode):
- Active users: 100+
- Monthly recurring revenue: $1,000+
- Churn rate: < 5%
- Customer satisfaction: > 4.5/5
- System uptime: 99.9%

---

## CONCLUSION

This comprehensive plan provides a complete roadmap for building the Advanced Autonomous Wedge Trading System. The architecture is designed to be:

1. **Modular**: Each component is independent and testable
2. **Scalable**: Supports both standalone and SaaS deployment
3. **Robust**: Multiple safety layers and validation checks
4. **Profitable**: Strict risk management with 1:3 R:R ratio
5. **Flexible**: X402 payment protocol for modern monetization

The mathematical foundation is sound, the implementation is structured, and the testing framework ensures reliability. By following this plan, you'll create a professional-grade trading system that can operate autonomously while maintaining strict risk controls.

**Next Steps**:
1. Review this document thoroughly
2. Set up development environment
3. Begin Phase 1 implementation
4. Test each module rigorously
5. Deploy and monitor

Good luck with your trading system! May your wedges converge profitably. 📈

---

**Document Version**: 1.0
**Last Updated**: 2025-11-14
**Author**: BIONICLES Development Team
**License**: Proprietary
