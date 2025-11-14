//+------------------------------------------------------------------+
//|                                             SignalGenerator.mqh |
//|                                    BIONICLES Development Team    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "BIONICLES Development Team"
#property link      "https://bionicles.io"
#property version   "1.00"
#property strict

#include "TrendLineDetection.mqh"
#include "ConvergenceAnalysis.mqh"
#include "PricePosition.mqh"
#include "../Utils/Indicators.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Signal Type Enumeration                                           |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_TYPE
{
    SIGNAL_NONE,     // No signal
    SIGNAL_BUY,      // Buy (long) signal
    SIGNAL_SELL      // Sell (short) signal
};

//+------------------------------------------------------------------+
//| Entry Signal Structure                                            |
//+------------------------------------------------------------------+
struct SEntrySignal
{
    ENUM_SIGNAL_TYPE type;         // Signal type
    double entryPrice;             // Calculated entry price
    double stopLoss;               // Calculated stop loss
    double takeProfit;             // Calculated take profit
    double lotSize;                // Calculated position size
    string reason;                 // Human-readable signal explanation
    datetime signalTime;           // Time signal was generated
    bool isValid;                  // Whether signal passed all validations
    double signalStrength;         // Signal quality score (0-100)

    // Confirmation factors (all must be true for valid signal)
    bool conditionA;               // Price at line (± ATR × 0.5)
    bool conditionB;               // Position ratio correct
    bool conditionC;               // Compression intact (> -2%)
    bool conditionD;               // RSI confirmation
    bool conditionE;               // Convergence timing valid
};

//+------------------------------------------------------------------+
//| Signal Generator Class                                            |
//+------------------------------------------------------------------+
class CSignalGenerator
{
public:
    //+------------------------------------------------------------------+
    //| Generate Trading Signal                                          |
    //+------------------------------------------------------------------+
    static ENUM_SIGNAL_TYPE GenerateSignal(
        const double currentPrice,
        const STrendLine &upperLine,
        const STrendLine &lowerLine,
        const SConvergenceData &convergence,
        const SPricePosition &position,
        const double rsi,
        const double atr,
        const int currentBar,
        SEntrySignal &signal,
        string symbol = NULL
    )
    {
        if(symbol == NULL) symbol = _Symbol;

        // Initialize signal
        signal.isValid = false;
        signal.type = SIGNAL_NONE;
        signal.signalTime = TimeCurrent();
        signal.conditionA = false;
        signal.conditionB = false;
        signal.conditionC = false;
        signal.conditionD = false;
        signal.conditionE = false;
        signal.signalStrength = 0.0;

        // Validate wedge pattern
        if(!convergence.isWedgeValid)
        {
            CLogger::Debug("GenerateSignal: Wedge pattern invalid");
            return SIGNAL_NONE;
        }

        // Check BUY conditions
        if(CheckBuyConditions(currentPrice, lowerLine, convergence, position,
                              rsi, atr, currentBar, signal))
        {
            signal.type = SIGNAL_BUY;
            CalculateEntryLevels(signal, currentPrice, lowerLine, upperLine,
                                atr, currentBar, symbol);

            CLogger::LogSignal("BUY", signal.entryPrice, signal.stopLoss,
                              signal.takeProfit, signal.reason);

            return SIGNAL_BUY;
        }

        // Check SELL conditions
        if(CheckSellConditions(currentPrice, upperLine, convergence, position,
                               rsi, atr, currentBar, signal))
        {
            signal.type = SIGNAL_SELL;
            CalculateEntryLevels(signal, currentPrice, upperLine, lowerLine,
                                atr, currentBar, symbol);

            CLogger::LogSignal("SELL", signal.entryPrice, signal.stopLoss,
                              signal.takeProfit, signal.reason);

            return SIGNAL_SELL;
        }

        return SIGNAL_NONE;
    }

    //+------------------------------------------------------------------+
    //| Check BUY Conditions                                             |
    //+------------------------------------------------------------------+
    static bool CheckBuyConditions(
        const double price,
        const STrendLine &lowerLine,
        const SConvergenceData &convergence,
        const SPricePosition &position,
        const double rsi,
        const double atr,
        const int bar,
        SEntrySignal &signal
    )
    {
        double lowerPrice = CTrendLineDetection::GetPriceAtBar(lowerLine, bar);

        // Condition A: Price at or near support (within ATR × 0.5)
        signal.conditionA = (price <= lowerPrice + (atr * 0.5));

        // Condition B: Position ratio < 0.20 (in support zone)
        signal.conditionB = (position.positionRatio < 0.20);

        // Condition C: Compression rate > -2% (wedge still intact)
        signal.conditionC = (convergence.compressionPercent > -2.0 &&
                            convergence.compressionPercent < 0.0);

        // Condition D: RSI < 40 (oversold)
        signal.conditionD = (rsi < 40.0);

        // Condition E: Bars to convergence > 3 (not too close to breakout)
        signal.conditionE = (convergence.barsToConvergence > 3 &&
                            convergence.barsToConvergence < 30);

        // All conditions must be true
        bool allConditionsMet = (signal.conditionA && signal.conditionB &&
                                signal.conditionC && signal.conditionD &&
                                signal.conditionE);

        if(allConditionsMet)
        {
            // Calculate signal strength
            signal.signalStrength = CalculateSignalStrength(signal, position, convergence, rsi);
            signal.isValid = true;

            // Generate reason string
            signal.reason = StringFormat(
                "BUY: Price %.5f near support %.5f | RSI %.1f | Ratio %.2f | Conv %d bars | Strength %.0f%%",
                price, lowerPrice, rsi, position.positionRatio,
                convergence.barsToConvergence, signal.signalStrength
            );

            return true;
        }

        return false;
    }

    //+------------------------------------------------------------------+
    //| Check SELL Conditions                                            |
    //+------------------------------------------------------------------+
    static bool CheckSellConditions(
        const double price,
        const STrendLine &upperLine,
        const SConvergenceData &convergence,
        const SPricePosition &position,
        const double rsi,
        const double atr,
        const int bar,
        SEntrySignal &signal
    )
    {
        double upperPrice = CTrendLineDetection::GetPriceAtBar(upperLine, bar);

        // Condition A: Price at or near resistance (within ATR × 0.5)
        signal.conditionA = (price >= upperPrice - (atr * 0.5));

        // Condition B: Position ratio > 0.80 (in resistance zone)
        signal.conditionB = (position.positionRatio > 0.80);

        // Condition C: Compression rate > -2% (wedge still intact)
        signal.conditionC = (convergence.compressionPercent > -2.0 &&
                            convergence.compressionPercent < 0.0);

        // Condition D: RSI > 60 (overbought)
        signal.conditionD = (rsi > 60.0);

        // Condition E: Bars to convergence > 3 (not too close to breakout)
        signal.conditionE = (convergence.barsToConvergence > 3 &&
                            convergence.barsToConvergence < 30);

        // All conditions must be true
        bool allConditionsMet = (signal.conditionA && signal.conditionB &&
                                signal.conditionC && signal.conditionD &&
                                signal.conditionE);

        if(allConditionsMet)
        {
            // Calculate signal strength
            signal.signalStrength = CalculateSignalStrength(signal, position, convergence, rsi);
            signal.isValid = true;

            // Generate reason string
            signal.reason = StringFormat(
                "SELL: Price %.5f near resistance %.5f | RSI %.1f | Ratio %.2f | Conv %d bars | Strength %.0f%%",
                price, upperPrice, rsi, position.positionRatio,
                convergence.barsToConvergence, signal.signalStrength
            );

            return true;
        }

        return false;
    }

    //+------------------------------------------------------------------+
    //| Validate All Signal Conditions                                   |
    //+------------------------------------------------------------------+
    static bool ValidateSignal(const SEntrySignal &signal)
    {
        if(!signal.isValid)
            return false;

        // All 5 conditions must be true
        if(!(signal.conditionA && signal.conditionB && signal.conditionC &&
             signal.conditionD && signal.conditionE))
        {
            CLogger::Warning("ValidateSignal: Not all conditions met");
            return false;
        }

        // Signal strength should be reasonable
        if(signal.signalStrength < 50.0)
        {
            CLogger::Warning("ValidateSignal: Signal strength too low");
            return false;
        }

        // Entry, SL, TP must be valid
        if(signal.entryPrice <= 0.0 || signal.stopLoss <= 0.0 || signal.takeProfit <= 0.0)
        {
            CLogger::Error("ValidateSignal: Invalid price levels");
            return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Check for Confirmation (2 consecutive bars)                      |
    //+------------------------------------------------------------------+
    static bool HasConfirmation(
        const double &closes[],
        const double middleLine,
        const ENUM_SIGNAL_TYPE signalType,
        const int barsRequired = 2
    )
    {
        if(ArraySize(closes) < barsRequired)
            return false;

        if(signalType == SIGNAL_BUY)
        {
            // For BUY: Check if last N bars closed below middle line
            for(int i = 0; i < barsRequired; i++)
            {
                if(closes[i] >= middleLine)
                    return false;
            }
            return true;
        }
        else if(signalType == SIGNAL_SELL)
        {
            // For SELL: Check if last N bars closed above middle line
            for(int i = 0; i < barsRequired; i++)
            {
                if(closes[i] <= middleLine)
                    return false;
            }
            return true;
        }

        return false;
    }

private:
    //+------------------------------------------------------------------+
    //| Calculate Entry, Stop Loss, and Take Profit Levels               |
    //+------------------------------------------------------------------+
    static void CalculateEntryLevels(
        SEntrySignal &signal,
        const double currentPrice,
        const STrendLine &entryLine,     // Lower for BUY, Upper for SELL
        const STrendLine &oppositeeLine, // Upper for BUY, Lower for SELL
        const double atr,
        const int bar,
        string symbol
    )
    {
        double linePrice = CTrendLineDetection::GetPriceAtBar(entryLine, bar);

        if(signal.type == SIGNAL_BUY)
        {
            // Entry: Slightly above support
            signal.entryPrice = linePrice + (atr * 0.25);

            // Stop Loss: Below support
            signal.stopLoss = linePrice - (atr * 1.5);

            // Take Profit: 3× risk distance
            double risk = signal.entryPrice - signal.stopLoss;
            signal.takeProfit = signal.entryPrice + (risk * 3.0);
        }
        else if(signal.type == SIGNAL_SELL)
        {
            // Entry: Slightly below resistance
            signal.entryPrice = linePrice - (atr * 0.25);

            // Stop Loss: Above resistance
            signal.stopLoss = linePrice + (atr * 1.5);

            // Take Profit: 3× risk distance
            double risk = signal.stopLoss - signal.entryPrice;
            signal.takeProfit = signal.entryPrice - (risk * 3.0);
        }

        // Normalize prices
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        signal.entryPrice = NormalizeDouble(signal.entryPrice, digits);
        signal.stopLoss = NormalizeDouble(signal.stopLoss, digits);
        signal.takeProfit = NormalizeDouble(signal.takeProfit, digits);
    }

    //+------------------------------------------------------------------+
    //| Calculate Signal Strength (0-100)                                |
    //+------------------------------------------------------------------+
    static double CalculateSignalStrength(
        const SEntrySignal &signal,
        const SPricePosition &position,
        const SConvergenceData &convergence,
        const double rsi
    )
    {
        double strength = 0.0;

        // Factor 1: All conditions met (base 40 points)
        if(signal.conditionA && signal.conditionB && signal.conditionC &&
           signal.conditionD && signal.conditionE)
            strength += 40.0;

        // Factor 2: Position quality (max 20 points)
        strength += CPricePosition::CalculatePositionStrength(position) * 0.20;

        // Factor 3: RSI extremity (max 20 points)
        if(signal.type == SIGNAL_BUY)
        {
            if(rsi < 30.0)
                strength += 20.0;
            else if(rsi < 35.0)
                strength += 15.0;
            else if(rsi < 40.0)
                strength += 10.0;
        }
        else if(signal.type == SIGNAL_SELL)
        {
            if(rsi > 70.0)
                strength += 20.0;
            else if(rsi > 65.0)
                strength += 15.0;
            else if(rsi > 60.0)
                strength += 10.0;
        }

        // Factor 4: Convergence timing (max 20 points)
        if(convergence.barsToConvergence >= 10 && convergence.barsToConvergence <= 20)
            strength += 20.0;
        else if(convergence.barsToConvergence > 5 && convergence.barsToConvergence < 25)
            strength += 15.0;
        else if(convergence.barsToConvergence > 3 && convergence.barsToConvergence < 30)
            strength += 10.0;

        return MathMin(strength, 100.0);
    }
};

//+------------------------------------------------------------------+
