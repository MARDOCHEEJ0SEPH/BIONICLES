//+------------------------------------------------------------------+
//|                                                   Validators.mqh |
//|                                    BIONICLES Development Team    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "BIONICLES Development Team"
#property link      "https://bionicles.io"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Input Validation Class                                            |
//+------------------------------------------------------------------+
class CValidators
{
public:
    //+------------------------------------------------------------------+
    //| Validate Symbol Exists and is Tradable                           |
    //+------------------------------------------------------------------+
    static bool ValidateSymbol(string symbol)
    {
        if(symbol == "" || symbol == NULL)
        {
            Print("Invalid symbol: empty or NULL");
            return false;
        }

        if(!SymbolSelect(symbol, true))
        {
            Print("Symbol not found or cannot be selected: ", symbol);
            return false;
        }

        // Check if trading is allowed
        if(!SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE))
        {
            Print("Trading is not allowed for symbol: ", symbol);
            return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Validate Lot Size                                                |
    //+------------------------------------------------------------------+
    static bool ValidateLotSize(double lots, string symbol = NULL)
    {
        if(symbol == NULL) symbol = _Symbol;

        double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

        if(lots < minLot)
        {
            Print("Lot size ", lots, " is below minimum ", minLot);
            return false;
        }

        if(lots > maxLot)
        {
            Print("Lot size ", lots, " exceeds maximum ", maxLot);
            return false;
        }

        // Check if lots is a valid multiple of lot step
        double remainder = MathMod(lots, lotStep);
        if(MathAbs(remainder) > 0.000001)
        {
            Print("Lot size ", lots, " is not a valid multiple of lot step ", lotStep);
            return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Validate Stop Loss and Take Profit Levels                        |
    //+------------------------------------------------------------------+
    static bool ValidateStopLevels(
        double entryPrice,
        double stopLoss,
        double takeProfit,
        ENUM_ORDER_TYPE orderType,
        string symbol = NULL
    )
    {
        if(symbol == NULL) symbol = _Symbol;

        // Get minimum stop level in points
        int stopLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double minDistance = stopLevel * point;

        if(orderType == ORDER_TYPE_BUY)
        {
            // For buy orders
            if(stopLoss >= entryPrice)
            {
                Print("Buy order: Stop loss must be below entry price");
                return false;
            }

            if(takeProfit <= entryPrice)
            {
                Print("Buy order: Take profit must be above entry price");
                return false;
            }

            // Check minimum distance
            if((entryPrice - stopLoss) < minDistance)
            {
                Print("Buy order: Stop loss too close to entry. Minimum: ", minDistance);
                return false;
            }

            if((takeProfit - entryPrice) < minDistance)
            {
                Print("Buy order: Take profit too close to entry. Minimum: ", minDistance);
                return false;
            }
        }
        else if(orderType == ORDER_TYPE_SELL)
        {
            // For sell orders
            if(stopLoss <= entryPrice)
            {
                Print("Sell order: Stop loss must be above entry price");
                return false;
            }

            if(takeProfit >= entryPrice)
            {
                Print("Sell order: Take profit must be below entry price");
                return false;
            }

            // Check minimum distance
            if((stopLoss - entryPrice) < minDistance)
            {
                Print("Sell order: Stop loss too close to entry. Minimum: ", minDistance);
                return false;
            }

            if((entryPrice - takeProfit) < minDistance)
            {
                Print("Sell order: Take profit too close to entry. Minimum: ", minDistance);
                return false;
            }
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Validate Account Balance                                         |
    //+------------------------------------------------------------------+
    static bool ValidateBalance(double requiredBalance)
    {
        double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);

        if(currentBalance < requiredBalance)
        {
            Print("Insufficient balance. Required: ", requiredBalance, ", Available: ", currentBalance);
            return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Validate Free Margin                                             |
    //+------------------------------------------------------------------+
    static bool ValidateFreeMargin(double requiredMargin)
    {
        double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

        if(freeMargin < requiredMargin)
        {
            Print("Insufficient free margin. Required: ", requiredMargin, ", Available: ", freeMargin);
            return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Validate Risk Percentage                                         |
    //+------------------------------------------------------------------+
    static bool ValidateRiskPercent(double riskPercent, double maxRisk = 5.0)
    {
        if(riskPercent <= 0.0)
        {
            Print("Risk percent must be greater than 0");
            return false;
        }

        if(riskPercent > maxRisk)
        {
            Print("Risk percent ", riskPercent, " exceeds maximum allowed ", maxRisk);
            return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Validate Risk-Reward Ratio                                       |
    //+------------------------------------------------------------------+
    static bool ValidateRiskRewardRatio(
        double entry,
        double stopLoss,
        double takeProfit,
        ENUM_ORDER_TYPE orderType,
        double expectedRatio = 3.0,
        double tolerance = 0.1
    )
    {
        double risk, reward, actualRatio;

        if(orderType == ORDER_TYPE_BUY)
        {
            risk = entry - stopLoss;
            reward = takeProfit - entry;
        }
        else
        {
            risk = stopLoss - entry;
            reward = entry - takeProfit;
        }

        if(risk <= 0.0)
        {
            Print("Invalid risk calculation: risk must be positive");
            return false;
        }

        actualRatio = reward / risk;

        double diff = MathAbs(actualRatio - expectedRatio);

        if(diff > tolerance)
        {
            Print("Risk-reward ratio ", actualRatio, " deviates from expected ", expectedRatio, " by more than tolerance ", tolerance);
            return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Validate Time Range                                              |
    //+------------------------------------------------------------------+
    static bool ValidateTimeRange(datetime startTime, datetime endTime)
    {
        if(startTime >= endTime)
        {
            Print("Start time must be before end time");
            return false;
        }

        if(startTime > TimeCurrent())
        {
            Print("Start time cannot be in the future");
            return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Validate Bar Count                                               |
    //+------------------------------------------------------------------+
    static bool ValidateBarCount(int bars, int minBars = 1, int maxBars = 1000)
    {
        if(bars < minBars)
        {
            Print("Bar count ", bars, " is below minimum ", minBars);
            return false;
        }

        if(bars > maxBars)
        {
            Print("Bar count ", bars, " exceeds maximum ", maxBars);
            return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Validate Array Size                                              |
    //+------------------------------------------------------------------+
    static bool ValidateArraySize(int size, int minSize = 1)
    {
        if(size < minSize)
        {
            Print("Array size ", size, " is below minimum ", minSize);
            return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Validate Indicator Value                                         |
    //+------------------------------------------------------------------+
    static bool ValidateIndicatorValue(double value, double min = -DBL_MAX, double max = DBL_MAX)
    {
        if(value < min || value > max)
        {
            Print("Indicator value ", value, " is outside valid range [", min, ", ", max, "]");
            return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Validate Trading Allowed                                         |
    //+------------------------------------------------------------------+
    static bool ValidateTradingAllowed()
    {
        if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
        {
            Print("Automated trading is disabled in the terminal");
            return false;
        }

        if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
        {
            Print("Trading is not allowed in the terminal");
            return false;
        }

        if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
        {
            Print("Trading is not allowed for this account");
            return false;
        }

        if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
        {
            Print("Expert Advisor trading is not allowed");
            return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Normalize Lot Size to Broker Requirements                        |
    //+------------------------------------------------------------------+
    static double NormalizeLots(double lots, string symbol = NULL)
    {
        if(symbol == NULL) symbol = _Symbol;

        double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

        // Round to lot step
        double normalized = MathRound(lots / lotStep) * lotStep;

        // Clamp to min/max
        if(normalized < minLot) normalized = minLot;
        if(normalized > maxLot) normalized = maxLot;

        return NormalizeDouble(normalized, 2);
    }

    //+------------------------------------------------------------------+
    //| Normalize Price to Tick Size                                     |
    //+------------------------------------------------------------------+
    static double NormalizePrice(double price, string symbol = NULL)
    {
        if(symbol == NULL) symbol = _Symbol;

        double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

        if(tickSize > 0)
        {
            price = MathRound(price / tickSize) * tickSize;
        }

        return NormalizeDouble(price, digits);
    }
};

//+------------------------------------------------------------------+
