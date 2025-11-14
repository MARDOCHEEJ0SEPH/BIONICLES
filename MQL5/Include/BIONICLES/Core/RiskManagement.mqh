//+------------------------------------------------------------------+
//|                                            RiskManagement.mqh |
//|                                    BIONICLES Development Team    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "BIONICLES Development Team"
#property link      "https://bionicles.io"
#property version   "1.00"
#property strict

#include "SignalGenerator.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/Validators.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Position Size Structure                                           |
//+------------------------------------------------------------------+
struct SPositionSize
{
    double lots;                   // Position size in lots
    double riskAmount;             // USD risk amount
    double stopDistancePips;       // Stop distance in pips
    double takeProfitPips;         // TP distance in pips
    double riskRewardRatio;        // Should always be 3.0
    bool isValid;                  // Whether calculation succeeded
    double requiredMargin;         // Margin required for position
    double pipValue;               // Value of 1 pip for this position
};

//+------------------------------------------------------------------+
//| Risk Management Class                                             |
//+------------------------------------------------------------------+
class CRiskManagement
{
public:
    //+------------------------------------------------------------------+
    //| Calculate Position Size                                          |
    //+------------------------------------------------------------------+
    static bool CalculatePositionSize(
        const double accountBalance,
        const double maxRiskPercent,
        const SEntrySignal &signal,
        const string symbol,
        SPositionSize &position
    )
    {
        // Initialize
        position.isValid = false;

        // Validate signal
        if(!signal.isValid || signal.type == SIGNAL_NONE)
        {
            CLogger::Error("CalculatePositionSize: Invalid signal");
            return false;
        }

        // Validate account balance
        if(accountBalance <= 0.0)
        {
            CLogger::Error("CalculatePositionSize: Invalid account balance");
            return false;
        }

        // Calculate risk amount (max 2% of account)
        position.riskAmount = accountBalance * (maxRiskPercent / 100.0);

        // Calculate stop distance in pips
        if(signal.type == SIGNAL_BUY)
        {
            position.stopDistancePips = CMathUtils::DistanceInPips(
                signal.entryPrice, signal.stopLoss, symbol
            );
            position.takeProfitPips = CMathUtils::DistanceInPips(
                signal.takeProfit, signal.entryPrice, symbol
            );
        }
        else // SIGNAL_SELL
        {
            position.stopDistancePips = CMathUtils::DistanceInPips(
                signal.stopLoss, signal.entryPrice, symbol
            );
            position.takeProfitPips = CMathUtils::DistanceInPips(
                signal.entryPrice, signal.takeProfit, symbol
            );
        }

        // Validate stop distance
        if(position.stopDistancePips <= 0.0)
        {
            CLogger::Error("CalculatePositionSize: Invalid stop distance");
            return false;
        }

        // Calculate pip value
        position.pipValue = GetPipValue(symbol, 1.0);

        if(position.pipValue <= 0.0)
        {
            CLogger::Error("CalculatePositionSize: Invalid pip value");
            return false;
        }

        // Calculate position size
        // Lots = Risk Amount / (Stop Distance in Pips × Pip Value)
        position.lots = position.riskAmount / (position.stopDistancePips * position.pipValue);

        // Normalize lot size to broker requirements
        position.lots = CValidators::NormalizeLots(position.lots, symbol);

        // Validate lot size
        if(!CValidators::ValidateLotSize(position.lots, symbol))
        {
            CLogger::Error("CalculatePositionSize: Invalid lot size after normalization");
            return false;
        }

        // Calculate required margin
        double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
        double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);

        position.requiredMargin = position.lots * contractSize *
                                 signal.entryPrice / AccountInfoInteger(ACCOUNT_LEVERAGE);

        // Verify risk-reward ratio (should be 3.0)
        position.riskRewardRatio = position.takeProfitPips / position.stopDistancePips;

        if(!CValidators::ValidateRiskRewardRatio(
            signal.entryPrice, signal.stopLoss, signal.takeProfit,
            (signal.type == SIGNAL_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL),
            3.0, 0.1))
        {
            CLogger::Warning(StringFormat(
                "Risk-reward ratio %.2f deviates from expected 3.0",
                position.riskRewardRatio
            ));
        }

        position.isValid = true;

        CLogger::Info(StringFormat(
            "Position size calculated: %.2f lots | Risk: $%.2f | Stop: %.1f pips | R:R: 1:%.1f",
            position.lots, position.riskAmount, position.stopDistancePips,
            position.riskRewardRatio
        ));

        return true;
    }

    //+------------------------------------------------------------------+
    //| Calculate Stop Loss Level                                        |
    //+------------------------------------------------------------------+
    static double CalculateStopLoss(
        const ENUM_SIGNAL_TYPE signalType,
        const STrendLine &trendLine,
        const int currentBar,
        const double atr,
        const double multiplier = 1.5,
        string symbol = NULL
    )
    {
        if(symbol == NULL) symbol = _Symbol;

        double linePrice = CTrendLineDetection::GetPriceAtBar(trendLine, currentBar);
        double stopLoss;

        if(signalType == SIGNAL_BUY)
        {
            // Stop below support line
            stopLoss = linePrice - (atr * multiplier);
        }
        else // SIGNAL_SELL
        {
            // Stop above resistance line
            stopLoss = linePrice + (atr * multiplier);
        }

        return CValidators::NormalizePrice(stopLoss, symbol);
    }

    //+------------------------------------------------------------------+
    //| Calculate Take Profit Level (1:3 ratio)                          |
    //+------------------------------------------------------------------+
    static double CalculateTakeProfit(
        const ENUM_SIGNAL_TYPE signalType,
        const double entryPrice,
        const double stopLoss,
        const double ratio = 3.0,
        string symbol = NULL
    )
    {
        if(symbol == NULL) symbol = _Symbol;

        double takeProfit;
        double risk;

        if(signalType == SIGNAL_BUY)
        {
            risk = entryPrice - stopLoss;
            takeProfit = entryPrice + (risk * ratio);
        }
        else // SIGNAL_SELL
        {
            risk = stopLoss - entryPrice;
            takeProfit = entryPrice - (risk * ratio);
        }

        return CValidators::NormalizePrice(takeProfit, symbol);
    }

    //+------------------------------------------------------------------+
    //| Validate Risk-Reward Ratio                                       |
    //+------------------------------------------------------------------+
    static bool ValidateRiskReward(
        const double entry,
        const double stopLoss,
        const double takeProfit,
        const ENUM_SIGNAL_TYPE type,
        const double expectedRatio = 3.0,
        string symbol = NULL
    )
    {
        if(symbol == NULL) symbol = _Symbol;

        double risk, reward, actualRatio;

        if(type == SIGNAL_BUY)
        {
            risk = CMathUtils::DistanceInPips(entry, stopLoss, symbol);
            reward = CMathUtils::DistanceInPips(takeProfit, entry, symbol);
        }
        else
        {
            risk = CMathUtils::DistanceInPips(stopLoss, entry, symbol);
            reward = CMathUtils::DistanceInPips(entry, takeProfit, symbol);
        }

        if(risk <= 0.0)
        {
            CLogger::Error("ValidateRiskReward: Risk is zero or negative");
            return false;
        }

        actualRatio = reward / risk;

        double deviation = MathAbs(actualRatio - expectedRatio);

        if(deviation > 0.1) // 10% tolerance
        {
            CLogger::Warning(StringFormat(
                "R:R ratio %.2f deviates from expected %.2f by %.2f",
                actualRatio, expectedRatio, deviation
            ));
            return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Check Portfolio Risk Limits                                      |
    //+------------------------------------------------------------------+
    static bool CheckPortfolioRisk(
        const double newTradeRisk,
        const double maxPortfolioRisk,
        const double currentPortfolioRisk
    )
    {
        double totalRisk = currentPortfolioRisk + newTradeRisk;

        if(totalRisk > maxPortfolioRisk)
        {
            CLogger::Warning(StringFormat(
                "Portfolio risk limit exceeded: %.2f%% (max: %.2f%%)",
                totalRisk, maxPortfolioRisk
            ));
            return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Calculate Current Portfolio Risk                                 |
    //+------------------------------------------------------------------+
    static double GetCurrentPortfolioRisk()
    {
        double totalRisk = 0.0;
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);

        if(accountBalance <= 0.0)
            return 0.0;

        // Loop through all open positions
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);

            if(ticket > 0)
            {
                double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double stopLoss = PositionGetDouble(POSITION_SL);
                double lots = PositionGetDouble(POSITION_VOLUME);
                string symbol = PositionGetString(POSITION_SYMBOL);

                if(stopLoss > 0.0)
                {
                    // Calculate risk for this position
                    double stopDistance = CMathUtils::DistanceInPips(entryPrice, stopLoss, symbol);
                    double pipValue = GetPipValue(symbol, lots);
                    double positionRisk = stopDistance * pipValue;

                    totalRisk += positionRisk;
                }
            }
        }

        // Convert to percentage
        return (totalRisk / accountBalance) * 100.0;
    }

    //+------------------------------------------------------------------+
    //| Get Pip Value for Symbol                                         |
    //+------------------------------------------------------------------+
    static double GetPipValue(const string symbol, const double lots)
    {
        // Get symbol properties
        double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
        double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

        if(tickSize == 0.0 || tickValue == 0.0)
        {
            CLogger::Error("GetPipValue: Invalid tick size or tick value");
            return 0.0;
        }

        // Calculate pip size (account for 3/5 digit brokers)
        double pipSize = (digits == 3 || digits == 5) ? tickSize * 10 : tickSize;

        // Calculate pip value
        double pipValue = (tickValue / tickSize) * pipSize * lots;

        return pipValue;
    }

    //+------------------------------------------------------------------+
    //| Calculate Maximum Lot Size Based on Available Margin             |
    //+------------------------------------------------------------------+
    static double GetMaxLotsByMargin(const string symbol, const double price)
    {
        double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
        double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
        int leverage = (int)AccountInfoInteger(ACCOUNT_LEVERAGE);

        if(leverage == 0 || contractSize == 0.0 || price == 0.0)
            return 0.0;

        double marginPerLot = (contractSize * price) / leverage;

        if(marginPerLot <= 0.0)
            return 0.0;

        // Use 80% of free margin for safety
        double maxLots = (freeMargin * 0.8) / marginPerLot;

        return CValidators::NormalizeLots(maxLots, symbol);
    }

    //+------------------------------------------------------------------+
    //| Check if Account Has Sufficient Funds                            |
    //+------------------------------------------------------------------+
    static bool HasSufficientFunds(
        const double lots,
        const string symbol,
        const double price
    )
    {
        double requiredMargin = CalculateRequiredMargin(lots, symbol, price);

        if(requiredMargin <= 0.0)
            return false;

        double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

        if(freeMargin < requiredMargin)
        {
            CLogger::Warning(StringFormat(
                "Insufficient margin: Required $%.2f, Available $%.2f",
                requiredMargin, freeMargin
            ));
            return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Calculate Required Margin for Position                           |
    //+------------------------------------------------------------------+
    static double CalculateRequiredMargin(
        const double lots,
        const string symbol,
        const double price
    )
    {
        double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
        int leverage = (int)AccountInfoInteger(ACCOUNT_LEVERAGE);

        if(leverage == 0 || contractSize == 0.0)
            return 0.0;

        return (lots * contractSize * price) / leverage;
    }
};

//+------------------------------------------------------------------+
