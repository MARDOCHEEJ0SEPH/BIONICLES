# BIONICLES - Advanced Autonomous Wedge Trading System

![License](https://img.shields.io/badge/license-Proprietary-red)
![Platform](https://img.shields.io/badge/platform-MetaTrader%205-blue)
![Language](https://img.shields.io/badge/language-MQL5-green)
![Timeframe](https://img.shields.io/badge/timeframe-4H-orange)
![Risk:Reward](https://img.shields.io/badge/R:R-1:3-purple)

## Overview

BIONICLES is a fully autonomous wedge pattern trading system for MetaTrader 5 (MQL5) designed to trade EURUSD on the 4-hour timeframe with a strict 1:3 risk-reward ratio. The system uses advanced mathematical algorithms including linear regression for trend line detection, multi-factor signal confirmation, and comprehensive risk management.

### Key Features

- **Autonomous Trading**: 24/7 market surveillance and pattern detection
- **Mathematical Precision**: Linear regression-based trend line calculations
- **Strict Risk Management**: 2% maximum risk per trade, 1:3 reward ratio
- **Safety Protocols**: Circuit breakers, drawdown limits, emergency stops
- **Multi-Factor Confirmation**: RSI, ATR, price position, convergence analysis
- **Flexible Deployment**: Standalone EA or SaaS with X402 payment protocol
- **Performance Tracking**: Real-time P&L, win rate, profit factor monitoring

## Quick Start

### Prerequisites

- MetaTrader 5 terminal (build 3640+)
- EURUSD symbol access
- Minimum $1,000 account balance recommended
- Stable internet connection

### Installation (Standalone Mode)

1. **Copy Files**:
   ```bash
   # Copy EA to Experts folder
   cp MQL5/Experts/BIONICLES/WedgeTradingSystem.mq5 <MT5_DATA>/MQL5/Experts/BIONICLES/

   # Copy include files
   cp -r MQL5/Include/BIONICLES/ <MT5_DATA>/MQL5/Include/

   # Copy license file (if using offline license)
   cp MQL5/Files/BIONICLES/license.key <MT5_DATA>/MQL5/Files/BIONICLES/
   ```

2. **Restart MT5 Terminal**

3. **Attach EA to Chart**:
   - Open EURUSD chart
   - Set timeframe to H4 (4-hour)
   - Drag `WedgeTradingSystem` EA onto chart
   - Configure parameters (see Configuration section)
   - Enable Auto Trading

4. **Verify Operation**:
   - Check Experts log for initialization messages
   - Verify license validation success
   - Monitor for pattern detection

### Configuration

#### Basic Parameters

```ini
// === WEDGE PATTERN PARAMETERS ===
LookbackBars = 60              # Bars to analyze for trend lines
CompressionThreshold = -2.0    # % compression per bar alert
MinConvergenceBars = 3         # Min bars before convergence to trade
MaxConvergenceBars = 30        # Max bars allowed before trade disabled

// === ENTRY PARAMETERS ===
ATR_Period = 14                # ATR period for volatility
RSI_Period = 14                # RSI period
RSI_Oversold = 40              # RSI threshold for buy signals
RSI_Overbought = 60            # RSI threshold for sell signals

// === POSITION SIZING ===
MaxRiskPercent = 2.0           # % account risk per trade (max 2%)
MaxPortfolioRisk = 5.0         # % total portfolio risk (max 5%)
RiskRewardRatio = 3.0          # Fixed 1:3 ratio

// === SAFETY PARAMETERS ===
DailyDrawdownLimit = 10.0      # % daily max loss before halt
MaxConsecutiveLosses = 5       # Halt after this many losses
```

#### License Configuration

**Standalone Mode**:
```ini
LicenseMode = OFFLINE
LicenseKeyFile = license.key
```

**SaaS Mode (X402 Protocol)**:
```ini
LicenseMode = X402
APIUrl = https://api.bionicles.io
Username = your-email@example.com
APIKey = your-api-key-here
```

## Architecture

### System Components

```
WedgeTradingSystem.mq5 (Main EA)
├── Core Modules
│   ├── TrendLineDetection.mqh      - Linear regression, trend lines
│   ├── ConvergenceAnalysis.mqh     - Wedge compression, breakout timing
│   ├── PricePosition.mqh           - Price position relative to channels
│   ├── SignalGenerator.mqh         - Buy/sell signal generation
│   ├── RiskManagement.mqh          - Position sizing, R:R calculations
│   ├── TradeManagement.mqh         - Breakeven, trailing stops
│   └── BreakoutDetection.mqh       - Breakout detection and handling
│
├── Utilities
│   ├── MathUtils.mqh               - Mathematical functions
│   ├── Indicators.mqh              - ATR, RSI wrappers
│   ├── Logger.mqh                  - Logging system
│   └── Validators.mqh              - Input validation
│
├── Execution
│   ├── OrderManager.mqh            - Order execution
│   ├── PositionTracker.mqh         - Position tracking
│   └── BrokerInterface.mqh         - Broker API wrapper
│
├── Safety
│   ├── CircuitBreakers.mqh         - Emergency stops
│   ├── DrawdownMonitor.mqh         - Drawdown tracking
│   └── RiskLimits.mqh              - Risk validation
│
├── Reporting
│   ├── PerformanceMetrics.mqh      - P&L, win rate, profit factor
│   ├── DailyReport.mqh             - Daily summaries
│   └── WeeklyAnalysis.mqh          - Weekly performance
│
└── Licensing
    ├── LicenseValidator.mqh        - License validation
    ├── X402Client.mqh              - HTTP 402 protocol client
    └── OfflineLicense.mqh          - File-based licensing
```

### Mathematical Foundation

#### Trend Line Calculation

```
Upper Line: y_upper = m₁ × x + b₁
Lower Line: y_lower = m₂ × x + b₂

Linear Regression:
m = (n×Σ(xy) - Σx×Σy) / (n×Σ(x²) - (Σx)²)
b = (Σy - m×Σx) / n
```

#### Convergence Analysis

```
Channel Width: Width(bar) = y_upper(bar) - y_lower(bar)
Convergence Point: x_convergence = (b₂ - b₁) / (m₁ - m₂)
Bars to Convergence = x_convergence - current_bar
```

#### Position Sizing

```
Max Risk = Account Balance × 2%
Stop Distance = Entry - Stop Loss (pips)
Position Size = Max Risk / (Stop Distance × Pip Value)
Take Profit = Entry + (Stop Distance × 3)  [1:3 R:R]
```

## Trading Logic

### Signal Generation

**BUY Signal Conditions** (all must be true):
1. Price ≤ Lower Line + (ATR × 0.5)
2. Position Ratio < 0.20
3. Compression Rate > -2%
4. RSI < 40
5. Bars to Convergence > 3

**SELL Signal Conditions** (all must be true):
1. Price ≥ Upper Line - (ATR × 0.5)
2. Position Ratio > 0.80
3. Compression Rate > -2%
4. RSI > 60
5. Bars to Convergence > 3

### Trade Management

- **Entry**: Market order at calculated entry price
- **Stop Loss**: Lower/Upper line - (ATR × 1.5)
- **Take Profit**: Entry + (Stop Distance × 3)
- **Breakeven**: Move SL to entry when profit > 1×ATR
- **Trailing Stop**: Trail SL at Price - ATR when in profit
- **Partial Profit**: Scale out 50% at 50% of TP target

### Safety Protocols

| Condition | Action |
|-----------|--------|
| Daily Drawdown > 10% | Stop all trading, close positions |
| Account Equity < 80% of start | Emergency stop |
| 5 Consecutive Losses | Halt trading for 24 hours |
| Wedge Breaks Outside | Close affected trades immediately |
| Data Feed Disconnected | Close all positions, send alert |

## X402 Payment Protocol (SaaS Mode)

### Subscription Tiers

| Tier | Price/Quarter | Accounts | API Calls/Day | Features |
|------|---------------|----------|---------------|----------|
| Starter | $9 | 1 | 1,000 | Basic analytics, live trading |
| Professional | $29 | 3 | 10,000 | Advanced analytics, API access, alerts |
| Enterprise | Custom | Unlimited | Unlimited | White-label, dedicated support |

### How X402 Works

1. **Authentication**: EA authenticates with backend using credentials
2. **License Validation**: System validates license via HTTP 402 protocol
3. **Trading**: If valid, EA operates normally
4. **Payment Required**: If expired, EA receives HTTP 402 response with payment URI
5. **Renewal**: User renews subscription, license updates automatically

### Setup for SaaS Mode

1. **Register Account**:
   ```
   https://bionicles.io/register
   ```

2. **Subscribe to Tier**:
   - Choose subscription level
   - Pay via credit card or Bitcoin/Ethereum
   - Receive API credentials

3. **Configure EA**:
   ```ini
   LicenseMode = X402
   APIUrl = https://api.bionicles.io
   APIKey = your-api-key
   ```

4. **Start Trading**:
   - EA validates license every 5 minutes
   - Logs trades to backend for analytics
   - Access web dashboard for performance metrics

## Performance Targets

### 90-Day Goals

- **Win Rate**: ≥ 40%
- **Profit Factor**: ≥ 1.5
- **Max Drawdown**: < 12%
- **Risk:Reward**: 1:3 (all trades)
- **Account Growth**: ≥ 10%
- **Trades**: 20-30 total

### Yearly Goals

- **Win Rate**: ≥ 45%
- **Profit Factor**: ≥ 2.0
- **Annual Return**: 25-40%
- **Max Drawdown**: < 15%
- **Sharpe Ratio**: > 1.5
- **Trades**: 60-100 total

## Testing & Validation

### Backtesting Checklist

- [ ] Run Strategy Tester on 1 year of EURUSD H4 data
- [ ] Verify win rate > 40%
- [ ] Confirm profit factor > 1.5
- [ ] Validate all trades have 1:3 R:R ratio
- [ ] Check max drawdown < 15%
- [ ] Ensure no more than 5 consecutive losses
- [ ] Verify position sizing (max 2% risk per trade)

### Forward Testing

1. **Demo Account** (2 weeks):
   - Test with live market data
   - Verify signal accuracy
   - Monitor system stability

2. **Small Live Account** (1 month):
   - $1,000-$2,000 account
   - Validate real-world performance
   - Test broker execution

3. **Full Deployment**:
   - Scale to target account size
   - Continue monitoring
   - Adjust parameters if needed

## Documentation

- **[CLAUDE.md](CLAUDE.md)**: Comprehensive technical documentation
- **[Docs/USER_MANUAL.md](Docs/USER_MANUAL.md)**: User guide (coming soon)
- **[Docs/API_REFERENCE.md](Docs/API_REFERENCE.md)**: API documentation (coming soon)
- **[Docs/X402_PROTOCOL.md](Docs/X402_PROTOCOL.md)**: X402 protocol spec (coming soon)
- **[Docs/DEPLOYMENT_GUIDE.md](Docs/DEPLOYMENT_GUIDE.md)**: Deployment instructions (coming soon)

## Development

### Building from Source

```bash
# Clone repository
git clone https://github.com/BIONICLES/trading-system.git
cd trading-system

# Copy to MT5 directory
cp -r MQL5/* ~/AppData/Roaming/MetaQuotes/Terminal/<TERMINAL_ID>/MQL5/

# Compile in MetaEditor
# Or use MT5 terminal's compile function
```

### Running Tests

```bash
# Open MetaEditor
# Navigate to Tests/unit/
# Run each test script individually

# Or use Strategy Tester for integration tests
# Select Tests/integration/test_full_system.mq5
```

### Contributing

This is a proprietary project. For collaboration inquiries, contact: dev@bionicles.io

## Support

### Common Issues

**EA Not Loading**:
- Ensure all include files are in correct directories
- Check MT5 terminal logs for errors
- Verify license file exists (standalone mode)

**No Signals Generated**:
- Confirm EURUSD H4 chart is active
- Check if wedge pattern exists in current market
- Review lookback period (default 60 bars = 10 days)

**Trades Not Executing**:
- Enable Auto Trading in MT5
- Check account balance (minimum $1,000 recommended)
- Verify broker allows EA trading

**License Validation Failed**:
- Check internet connection
- Verify license file path (standalone)
- Confirm API credentials (SaaS mode)
- Check subscription status

### Contact

- **Email**: support@bionicles.io
- **Website**: https://bionicles.io
- **Documentation**: https://docs.bionicles.io
- **Discord**: https://discord.gg/bionicles

## License

Copyright (c) 2025 BIONICLES Development Team

This software is proprietary and confidential. Unauthorized copying, distribution, or use is strictly prohibited.

## Disclaimer

Trading forex involves substantial risk of loss and is not suitable for all investors. Past performance is not indicative of future results. This software is provided for educational and research purposes. The developers and distributors of this software are not liable for any losses incurred through its use. Always trade responsibly and within your risk tolerance.

---

**Version**: 1.0.0
**Last Updated**: 2025-11-14
**Build**: Alpha

