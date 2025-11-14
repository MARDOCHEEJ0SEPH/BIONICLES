//+------------------------------------------------------------------+
//|                                              OrderManager.mqh |
//|                                    BIONICLES Development Team    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "BIONICLES Development Team"
#property link      "https://bionicles.io"
#property version   "1.00"
#property strict

#include "../Core/SignalGenerator.mqh"
#include "../Core/RiskManagement.mqh"
#include "../Utils/Logger.mqh"
#include "../Utils/Validators.mqh"

//+------------------------------------------------------------------+
//| Order Result Structure                                            |
//+------------------------------------------------------------------+
struct SOrderResult
{
    bool success;                  // Order successful
    ulong ticket;                  // Order ticket
    double executionPrice;         // Execution price
    double lots;                   // Executed volume
    string errorMessage;           // Error message if failed
    int retcode;                   // Return code
};

//+------------------------------------------------------------------+
//| Order Manager Class                                               |
//+------------------------------------------------------------------+
class COrderManager
{
public:
    //+------------------------------------------------------------------+
    //| Execute Market Order from Signal                                 |
    //+------------------------------------------------------------------+
    static bool ExecuteSignal(
        const SEntrySignal &signal,
        const SPositionSize &position,
        const string symbol,
        SOrderResult &result
    )
    {
        // Initialize result
        result.success = false;
        result.ticket = 0;
        result.executionPrice = 0.0;
        result.lots = 0.0;
        result.errorMessage = "";
        result.retcode = 0;

        // Validate signal
        if(!signal.isValid || signal.type == SIGNAL_NONE)
        {
            result.errorMessage = "Invalid signal";
            CLogger::Error("ExecuteSignal: Invalid signal");
            return false;
        }

        // Validate position size
        if(!position.isValid || position.lots <= 0.0)
        {
            result.errorMessage = "Invalid position size";
            CLogger::Error("ExecuteSignal: Invalid position size");
            return false;
        }

        // Validate trading permissions
        if(!CValidators::ValidateTradingAllowed())
        {
            result.errorMessage = "Trading not allowed";
            return false;
        }

        // Validate stop levels
        ENUM_ORDER_TYPE orderType = (signal.type == SIGNAL_BUY) ?
                                     ORDER_TYPE_BUY : ORDER_TYPE_SELL;

        if(!CValidators::ValidateStopLevels(signal.entryPrice, signal.stopLoss,
                                            signal.takeProfit, orderType, symbol))
        {
            result.errorMessage = "Invalid stop levels";
            return false;
        }

        // Check margin
        if(!CRiskManagement::HasSufficientFunds(position.lots, symbol, signal.entryPrice))
        {
            result.errorMessage = "Insufficient margin";
            CLogger::Error("ExecuteSignal: Insufficient margin");
            return false;
        }

        // Prepare order request
        MqlTradeRequest request;
        MqlTradeResult tradeResult;

        ZeroMemory(request);
        ZeroMemory(tradeResult);

        request.action = TRADE_ACTION_DEAL;
        request.symbol = symbol;
        request.volume = position.lots;
        request.type = orderType;
        request.price = (signal.type == SIGNAL_BUY) ?
                       SymbolInfoDouble(symbol, SYMBOL_ASK) :
                       SymbolInfoDouble(symbol, SYMBOL_BID);
        request.sl = signal.stopLoss;
        request.tp = signal.takeProfit;
        request.deviation = 10;
        request.magic = 20241114; // BIONICLES magic number
        request.comment = StringFormat("BIONICLES %s", EnumToString(signal.type));

        // Send order
        if(!OrderSend(request, tradeResult))
        {
            result.errorMessage = StringFormat("OrderSend failed: %d", GetLastError());
            CLogger::LogError("ExecuteSignal", GetLastError());
            return false;
        }

        // Check result
        if(tradeResult.retcode == TRADE_RETCODE_DONE ||
           tradeResult.retcode == TRADE_RETCODE_PLACED ||
           tradeResult.retcode == TRADE_RETCODE_DONE_PARTIAL)
        {
            result.success = true;
            result.ticket = tradeResult.deal;
            result.executionPrice = tradeResult.price;
            result.lots = tradeResult.volume;
            result.retcode = tradeResult.retcode;

            CLogger::LogTrade("ENTRY", (int)result.ticket, symbol,
                             (int)orderType, result.lots, result.executionPrice,
                             signal.stopLoss, signal.takeProfit, signal.reason);

            return true;
        }
        else
        {
            result.errorMessage = StringFormat("Order failed: %d - %s",
                                              tradeResult.retcode, tradeResult.comment);
            result.retcode = tradeResult.retcode;

            CLogger::Error(result.errorMessage);
            return false;
        }
    }

    //+------------------------------------------------------------------+
    //| Close All Positions                                              |
    //+------------------------------------------------------------------+
    static int CloseAllPositions(const string symbol = NULL, const string reason = "Close all")
    {
        int closedCount = 0;

        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);

            if(ticket > 0)
            {
                string posSymbol = PositionGetString(POSITION_SYMBOL);

                // Filter by symbol if specified
                if(symbol != NULL && posSymbol != symbol)
                    continue;

                if(ClosePosition(ticket, reason))
                    closedCount++;
            }
        }

        CLogger::Info(StringFormat("Closed %d positions: %s", closedCount, reason));

        return closedCount;
    }

    //+------------------------------------------------------------------+
    //| Close Single Position                                            |
    //+------------------------------------------------------------------+
    static bool ClosePosition(const ulong ticket, const string reason = "Manual close")
    {
        if(!PositionSelectByTicket(ticket))
        {
            CLogger::Warning(StringFormat("Position %d not found", ticket));
            return false;
        }

        string symbol = PositionGetString(POSITION_SYMBOL);
        double volume = PositionGetDouble(POSITION_VOLUME);
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

        MqlTradeRequest request;
        MqlTradeResult result;

        ZeroMemory(request);
        ZeroMemory(result);

        request.action = TRADE_ACTION_DEAL;
        request.position = ticket;
        request.symbol = symbol;
        request.volume = volume;
        request.type = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        request.price = (posType == POSITION_TYPE_BUY) ?
                       SymbolInfoDouble(symbol, SYMBOL_BID) :
                       SymbolInfoDouble(symbol, SYMBOL_ASK);
        request.deviation = 10;
        request.magic = 20241114;
        request.comment = reason;

        if(OrderSend(request, result))
        {
            if(result.retcode == TRADE_RETCODE_DONE)
            {
                CLogger::LogTrade("EXIT", (int)ticket, symbol, (int)posType,
                                 volume, result.price, 0.0, 0.0, reason);
                return true;
            }
        }

        CLogger::Error(StringFormat("Failed to close position %d: %d - %s",
                                   ticket, result.retcode, result.comment));

        return false;
    }

    //+------------------------------------------------------------------+
    //| Get Open Position Count                                          |
    //+------------------------------------------------------------------+
    static int GetOpenPositionCount(const string symbol = NULL)
    {
        int count = 0;

        for(int i = 0; i < PositionsTotal(); i++)
        {
            ulong ticket = PositionGetTicket(i);

            if(ticket > 0)
            {
                if(symbol == NULL)
                {
                    count++;
                }
                else
                {
                    string posSymbol = PositionGetString(POSITION_SYMBOL);
                    if(posSymbol == symbol)
                        count++;
                }
            }
        }

        return count;
    }

    //+------------------------------------------------------------------+
    //| Get Position Count by Direction                                  |
    //+------------------------------------------------------------------+
    static void GetPositionCountByDirection(
        int &longCount,
        int &shortCount,
        const string symbol = NULL
    )
    {
        longCount = 0;
        shortCount = 0;

        for(int i = 0; i < PositionsTotal(); i++)
        {
            ulong ticket = PositionGetTicket(i);

            if(ticket > 0)
            {
                string posSymbol = PositionGetString(POSITION_SYMBOL);

                // Filter by symbol if specified
                if(symbol != NULL && posSymbol != symbol)
                    continue;

                ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

                if(type == POSITION_TYPE_BUY)
                    longCount++;
                else
                    shortCount++;
            }
        }
    }

    //+------------------------------------------------------------------+
    //| Check if Max Concurrent Trades Reached                           |
    //+------------------------------------------------------------------+
    static bool IsMaxConcurrentTradesReached(
        const int maxTrades,
        const string symbol = NULL
    )
    {
        return (GetOpenPositionCount(symbol) >= maxTrades);
    }

    //+------------------------------------------------------------------+
    //| Check if Max Same Direction Trades Reached                       |
    //+------------------------------------------------------------------+
    static bool IsMaxSameDirectionReached(
        const ENUM_SIGNAL_TYPE direction,
        const int maxSameDirection,
        const string symbol = NULL
    )
    {
        int longCount, shortCount;
        GetPositionCountByDirection(longCount, shortCount, symbol);

        if(direction == SIGNAL_BUY)
            return (longCount >= maxSameDirection);
        else
            return (shortCount >= maxSameDirection);
    }

    //+------------------------------------------------------------------+
    //| Get Total Exposure (USD)                                         |
    //+------------------------------------------------------------------+
    static double GetTotalExposure(const string symbol = NULL)
    {
        double totalExposure = 0.0;

        for(int i = 0; i < PositionsTotal(); i++)
        {
            ulong ticket = PositionGetTicket(i);

            if(ticket > 0)
            {
                string posSymbol = PositionGetString(POSITION_SYMBOL);

                // Filter by symbol if specified
                if(symbol != NULL && posSymbol != symbol)
                    continue;

                double volume = PositionGetDouble(POSITION_VOLUME);
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double contractSize = SymbolInfoDouble(posSymbol, SYMBOL_TRADE_CONTRACT_SIZE);

                totalExposure += (volume * contractSize * openPrice);
            }
        }

        return totalExposure;
    }
};

//+------------------------------------------------------------------+
