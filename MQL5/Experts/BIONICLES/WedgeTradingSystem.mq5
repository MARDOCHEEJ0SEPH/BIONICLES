//+------------------------------------------------------------------+
//|                                        WedgeTradingSystem.mq5 |
//|                                    BIONICLES Development Team    |
//|                       Advanced Autonomous Wedge Trading System    |
//+------------------------------------------------------------------+
#property copyright "BIONICLES Development Team"
#property link      "https://bionicles.io"
#property version   "1.00"
#property description "Autonomous wedge pattern trading system with 1:3 R:R ratio"
#property description "4-Hour timeframe EURUSD specialist"

#define EA_MAGIC 20241114

// Include all modules
#include <BIONICLES/Utils/MathUtils.mqh>
#include <BIONICLES/Utils/Indicators.mqh>
#include <BIONICLES/Utils/Logger.mqh>
#include <BIONICLES/Utils/Validators.mqh>
#include <BIONICLES/Core/TrendLineDetection.mqh>
#include <BIONICLES/Core/ConvergenceAnalysis.mqh>
#include <BIONICLES/Core/PricePosition.mqh>
#include <BIONICLES/Core/SignalGenerator.mqh>
#include <BIONICLES/Core/RiskManagement.mqh>
#include <BIONICLES/Core/TradeManagement.mqh>
#include <BIONICLES/Core/BreakoutDetection.mqh>
#include <BIONICLES/Execution/OrderManager.mqh>
#include <BIONICLES/Safety/CircuitBreakers.mqh>
#include <BIONICLES/Safety/DrawdownMonitor.mqh>
#include <BIONICLES/Reporting/PerformanceMetrics.mqh>
#include <BIONICLES/Reporting/DailyReport.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

//=== WEDGE PATTERN PARAMETERS ===
input group "Wedge Pattern Settings"
input int InpLookbackBars = 60;                   // Bars to analyze for trend lines
input double InpCompressionThreshold = -2.0;      // Compression threshold %
input int InpMinConvergenceBars = 3;              // Min bars before convergence
input int InpMaxConvergenceBars = 30;             // Max bars before convergence

//=== ENTRY PARAMETERS ===
input group "Entry Signal Settings"
input int InpATRPeriod = 14;                      // ATR period
input int InpRSIPeriod = 14;                      // RSI period
input int InpRSIOversold = 40;                    // RSI oversold level (BUY)
input int InpRSIOverbought = 60;                  // RSI overbought level (SELL)
input double InpSupportOffset = 0.5;              // Entry offset from support (ATR multiple)
input double InpResistanceOffset = 0.5;           // Entry offset from resistance (ATR multiple)

//=== POSITION SIZING ===
input group "Risk Management"
input double InpMaxRiskPercent = 2.0;             // Max % risk per trade
input double InpMaxPortfolioRisk = 5.0;           // Max % portfolio risk
input double InpRiskRewardRatio = 3.0;            // Risk-reward ratio (1:3)
input double InpStopLossATRMultiple = 1.5;        // Stop loss ATR multiple

//=== TRADE MANAGEMENT ===
input group "Trade Management"
input int InpMaxConcurrentTrades = 3;             // Max concurrent positions
input int InpMaxSameDirectionTrades = 2;          // Max same direction positions
input double InpBreakevenTrigger = 1.0;           // Breakeven trigger (ATR multiple)
input double InpTrailingStopATR = 1.0;            // Trailing stop (ATR multiple)

//=== SAFETY PARAMETERS ===
input group "Safety Settings"
input double InpDailyDrawdownLimit = 10.0;        // Daily drawdown limit %
input double InpMaxEquityDrop = 20.0;             // Max equity drop %
input int InpMaxConsecutiveLosses = 5;            // Max consecutive losses
input int InpHaltDurationHours = 24;              // Trading halt duration (hours)

//=== REPORTING ===
input group "Reporting"
input bool InpEnableAlerts = true;                // Enable alerts
input bool InpEnablePerformanceLog = true;        // Enable performance logging
input bool InpGenerateDailyReport = true;         // Generate daily reports

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
datetime g_lastBarTime = 0;
STrendLine g_upperLine;
STrendLine g_lowerLine;
bool g_isInitialized = false;
int g_tradesThisSession = 0;

//+------------------------------------------------------------------+
//| Expert Initialization Function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("═══════════════════════════════════════════════════════");
    Print("  BIONICLES Wedge Trading System v1.00");
    Print("  Initializing...");
    Print("═══════════════════════════════════════════════════════");

    // Validate symbol and timeframe
    if(_Symbol != "EURUSD" && _Symbol != "EURUSDm")
    {
        Alert("WARNING: This EA is optimized for EURUSD. Current symbol: ", _Symbol);
    }

    if(_Period != PERIOD_H4)
    {
        Alert("ERROR: This EA requires 4-Hour (H4) timeframe!");
        return INIT_FAILED;
    }

    // Validate trading permissions
    if(!CValidators::ValidateTradingAllowed())
    {
        Alert("ERROR: Trading not allowed. Enable Auto Trading!");
        return INIT_FAILED;
    }

    // Initialize logger
    if(!CLogger::Initialize("BIONICLES_log.txt", LOG_LEVEL_INFO, true, true))
    {
        Print("ERROR: Failed to initialize logger");
        return INIT_FAILED;
    }

    CLogger::Info("═══════════════════════════════════════════════════════");
    CLogger::Info("BIONICLES Wedge Trading System v1.00");
    CLogger::Info("═══════════════════════════════════════════════════════");
    CLogger::Info(StringFormat("Symbol: %s | Timeframe: %s", _Symbol, EnumToString(_Period)));
    CLogger::Info(StringFormat("Account: %d | Balance: $%.2f",
                              AccountInfoInteger(ACCOUNT_LOGIN),
                              AccountInfoDouble(ACCOUNT_BALANCE)));

    // Initialize indicators
    if(!CIndicators::Initialize(_Symbol, _Period))
    {
        CLogger::Error("Failed to initialize indicators");
        return INIT_FAILED;
    }

    // Initialize circuit breakers
    if(!CCircuitBreakers::Initialize(InpDailyDrawdownLimit, InpMaxEquityDrop,
                                     InpMaxConsecutiveLosses, InpHaltDurationHours))
    {
        CLogger::Error("Failed to initialize circuit breakers");
        return INIT_FAILED;
    }

    // Initialize drawdown monitor
    if(!CDrawdownMonitor::Initialize(8.0))
    {
        CLogger::Error("Failed to initialize drawdown monitor");
        return INIT_FAILED;
    }

    // Initialize performance metrics
    if(!CPerformanceMetrics::Initialize())
    {
        CLogger::Error("Failed to initialize performance metrics");
        return INIT_FAILED;
    }

    // Set timer for periodic checks (every 5 minutes)
    EventSetTimer(300);

    // Log configuration
    CLogger::Info("Configuration:");
    CLogger::Info(StringFormat("  Lookback Bars: %d", InpLookbackBars));
    CLogger::Info(StringFormat("  Max Risk Per Trade: %.1f%%", InpMaxRiskPercent));
    CLogger::Info(StringFormat("  Risk-Reward Ratio: 1:%.0f", InpRiskRewardRatio));
    CLogger::Info(StringFormat("  Max Concurrent Trades: %d", InpMaxConcurrentTrades));
    CLogger::Info(StringFormat("  Daily Drawdown Limit: %.1f%%", InpDailyDrawdownLimit));

    g_isInitialized = true;
    g_lastBarTime = iTime(_Symbol, _Period, 0);

    CLogger::Info("═══════════════════════════════════════════════════════");
    CLogger::Info("Initialization COMPLETE - Trading enabled");
    CLogger::Info("═══════════════════════════════════════════════════════");

    Print("Initialization successful!");

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert Deinitialization Function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    CLogger::Info("═══════════════════════════════════════════════════════");
    CLogger::Info("BIONICLES EA Shutting Down");
    CLogger::Info(StringFormat("Reason: %s", GetDeinitReasonText(reason)));
    CLogger::Info("═══════════════════════════════════════════════════════");

    // Kill timer
    EventKillTimer();

    // Generate final report
    if(InpEnablePerformanceLog)
    {
        CLogger::Info("Generating final performance report...");
        CPerformanceMetrics::LogSummary();
        CDrawdownMonitor::LogSummary();

        // Export trades to CSV
        CPerformanceMetrics::ExportToCSV("trades_final.csv");
    }

    // Release indicator handles
    CIndicators::Deinitialize();

    // Close logger
    CLogger::Deinitialize();

    Print("Shutdown complete.");
}

//+------------------------------------------------------------------+
//| Expert Tick Function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!g_isInitialized)
        return;

    // Check for new bar (4H)
    datetime currentBarTime = iTime(_Symbol, _Period, 0);

    if(currentBarTime == g_lastBarTime)
        return; // Wait for new bar

    g_lastBarTime = currentBarTime;

    CLogger::Debug("═══════════════════════════════════════════════════════");
    CLogger::Debug(StringFormat("New 4H bar: %s", TimeToString(currentBarTime)));

    // Update safety monitors
    CDrawdownMonitor::Update();

    // Check circuit breakers
    if(!CCircuitBreakers::CheckBreakers())
    {
        CLogger::Warning("Trading halted by circuit breakers");
        return;
    }

    // Main trading logic
    ProcessTradingLogic();

    // Manage active trades
    CTradeManagement::ManageActiveTrades(g_upperLine, g_lowerLine,
                                        CIndicators::GetATR(_Symbol, _Period, InpATRPeriod, 0),
                                        0);

    CLogger::Debug("═══════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Main Trading Logic                                                |
//+------------------------------------------------------------------+
void ProcessTradingLogic()
{
    // Step 1: Get market data
    double highs[], lows[], closes[];
    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows, true);
    ArraySetAsSeries(closes, true);

    if(CopyHigh(_Symbol, _Period, 0, InpLookbackBars, highs) <= 0 ||
       CopyLow(_Symbol, _Period, 0, InpLookbackBars, lows) <= 0 ||
       CopyClose(_Symbol, _Period, 0, InpLookbackBars, closes) <= 0)
    {
        CLogger::Error("Failed to copy price data");
        return;
    }

    // Step 2: Calculate trend lines
    if(!CTrendLineDetection::CalculateUpperLine(highs, InpLookbackBars, g_upperLine, _Symbol, _Period))
    {
        CLogger::Debug("No valid upper trend line detected");
        return;
    }

    if(!CTrendLineDetection::CalculateLowerLine(lows, InpLookbackBars, g_lowerLine, _Symbol, _Period))
    {
        CLogger::Debug("No valid lower trend line detected");
        return;
    }

    // Step 3: Calculate convergence
    SConvergenceData convergence;
    if(!CConvergenceAnalysis::CalculateConvergence(g_upperLine, g_lowerLine, 0, convergence, _Symbol))
    {
        CLogger::Debug("Wedge pattern invalid");
        return;
    }

    CLogger::LogPattern("WEDGE",
                       CTrendLineDetection::GetPriceAtBar(g_upperLine, 0),
                       CTrendLineDetection::GetPriceAtBar(g_lowerLine, 0),
                       convergence.barsToConvergence,
                       convergence.compressionPercent);

    // Step 4: Get indicators
    double currentPrice = closes[0];
    double atr = CIndicators::GetATR(_Symbol, _Period, InpATRPeriod, 0);
    double rsi = CIndicators::GetRSI(_Symbol, _Period, InpRSIPeriod, 0);

    // Step 5: Calculate price position
    SPricePosition position;
    if(!CPricePosition::CalculatePosition(currentPrice, g_upperLine, g_lowerLine,
                                          0, atr, position, _Symbol))
    {
        CLogger::Error("Failed to calculate price position");
        return;
    }

    // Step 6: Check for breakout
    SBreakoutData breakout;
    if(CBreakoutDetection::DetectBreakout(currentPrice, closes[1], g_upperLine,
                                         g_lowerLine, convergence, 0, breakout))
    {
        if(breakout.isConfirmed)
        {
            CLogger::Warning("Confirmed breakout detected!");
            CBreakoutDetection::HandleBreakoutTrades(breakout);
        }
    }

    // Step 7: Check if can enter new trade
    if(COrderManager::IsMaxConcurrentTradesReached(InpMaxConcurrentTrades, _Symbol))
    {
        CLogger::Debug("Max concurrent trades reached");
        return;
    }

    // Step 8: Generate signal
    SEntrySignal signal;
    ENUM_SIGNAL_TYPE signalType = CSignalGenerator::GenerateSignal(
        currentPrice, g_upperLine, g_lowerLine, convergence, position,
        rsi, atr, 0, signal, _Symbol
    );

    if(signalType == SIGNAL_NONE)
    {
        CLogger::Debug("No valid signal generated");
        return;
    }

    // Step 9: Check same direction limit
    if(COrderManager::IsMaxSameDirectionReached(signalType, InpMaxSameDirectionTrades, _Symbol))
    {
        CLogger::Warning(StringFormat("Max %s positions reached",
                                     signalType == SIGNAL_BUY ? "BUY" : "SELL"));
        return;
    }

    // Step 10: Calculate position size
    SPositionSize posSize;
    if(!CRiskManagement::CalculatePositionSize(AccountInfoDouble(ACCOUNT_BALANCE),
                                               InpMaxRiskPercent, signal, _Symbol, posSize))
    {
        CLogger::Error("Failed to calculate position size");
        return;
    }

    // Step 11: Check portfolio risk
    double currentPortfolioRisk = CRiskManagement::GetCurrentPortfolioRisk();
    if(!CRiskManagement::CheckPortfolioRisk(InpMaxRiskPercent, InpMaxPortfolioRisk, currentPortfolioRisk))
    {
        CLogger::Warning("Portfolio risk limit exceeded");
        return;
    }

    // Step 12: Execute trade
    SOrderResult result;
    if(COrderManager::ExecuteSignal(signal, posSize, _Symbol, result))
    {
        CLogger::Info(StringFormat(
            "✓ Trade executed successfully! Ticket: %d | Entry: %.5f | SL: %.5f | TP: %.5f",
            result.ticket, result.executionPrice, signal.stopLoss, signal.takeProfit
        ));

        g_tradesThisSession++;

        if(InpEnableAlerts)
        {
            Alert(StringFormat("[BIONICLES] New %s trade @ %.5f",
                              EnumToString(signalType), result.executionPrice));
        }
    }
    else
    {
        CLogger::Error(StringFormat("Trade execution failed: %s", result.errorMessage));
    }
}

//+------------------------------------------------------------------+
//| Timer Function                                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Periodic checks every 5 minutes

    // Update monitors
    CDrawdownMonitor::Update();

    // Check circuit breakers
    CCircuitBreakers::CheckBreakers();

    // Log status
    CLogger::Debug(StringFormat(
        "Status: Open=%d | Balance=$%.2f | DD=%.2f%%",
        PositionsTotal(),
        AccountInfoDouble(ACCOUNT_BALANCE),
        CDrawdownMonitor::GetCurrentDrawdown()
    ));
}

//+------------------------------------------------------------------+
//| Trade Event Handler                                               |
//+------------------------------------------------------------------+
void OnTrade()
{
    // This is called when a trade is executed or modified

    // Check if any positions were closed
    static int lastPositionCount = 0;
    int currentPositionCount = PositionsTotal();

    if(currentPositionCount < lastPositionCount)
    {
        // Position was closed - record result
        // (In production, track closed trades via history)

        CLogger::Info("Position closed - updating metrics");

        // You would need to fetch the closed position from history here
        // and record it in PerformanceMetrics

        // For now, just update monitors
        CDrawdownMonitor::Update();
    }

    lastPositionCount = currentPositionCount;
}

//+------------------------------------------------------------------+
//| Get Deinitialization Reason Text                                 |
//+------------------------------------------------------------------+
string GetDeinitReasonText(int reason)
{
    switch(reason)
    {
        case REASON_PROGRAM:     return "EA stopped by user";
        case REASON_REMOVE:      return "EA removed from chart";
        case REASON_RECOMPILE:   return "EA recompiled";
        case REASON_CHARTCHANGE: return "Chart symbol/timeframe changed";
        case REASON_CHARTCLOSE:  return "Chart closed";
        case REASON_PARAMETERS:  return "Input parameters changed";
        case REASON_ACCOUNT:     return "Account changed";
        case REASON_TEMPLATE:    return "Template changed";
        case REASON_INITFAILED:  return "Initialization failed";
        case REASON_CLOSE:       return "Terminal closing";
        default:                 return "Unknown reason";
    }
}

//+------------------------------------------------------------------+
