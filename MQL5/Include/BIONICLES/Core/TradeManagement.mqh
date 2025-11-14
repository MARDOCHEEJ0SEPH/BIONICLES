//+------------------------------------------------------------------+
//|                                            TradeManagement.mqh |
//|                                    BIONICLES Development Team    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "BIONICLES Development Team"
#property link      "https://bionicles.io"
#property version   "1.00"
#property strict

#include "TrendLineDetection.mqh"
#include "SignalGenerator.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Trade Status Structure                                            |
//+------------------------------------------------------------------+
struct STradeStatus
{
    ulong ticket;                  // Position ticket
    ENUM_SIGNAL_TYPE type;         // BUY or SELL
    double entryPrice;             // Entry price
    double currentPrice;           // Current price
    double stopLoss;               // Current stop loss
    double takeProfit;             // Take profit
    double currentPL;              // Current P/L in USD
    double currentPLPips;          // Current P/L in pips
    double currentPLPercent;       // Current P/L as % of risk
    bool isBreakevenActive;        // Breakeven protection activated
    bool isTrailingActive;         // Trailing stop activated
    bool isScaledOut;              // Partial profit taken
    datetime entryTime;            // Entry time
    datetime lastUpdate;           // Last update time
    double lots;                   // Position size
    string symbol;                 // Symbol
};

//+------------------------------------------------------------------+
//| Trade Management Class                                            |
//+------------------------------------------------------------------+
class CTradeManagement
{
public:
    //+------------------------------------------------------------------+
    //| Update All Active Trades                                         |
    //+------------------------------------------------------------------+
    static void ManageActiveTrades(
        STrendLine &upperLine,
        STrendLine &lowerLine,
        const double atr,
        const int currentBar
    )
    {
        // Loop through all open positions
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);

            if(ticket > 0)
            {
                // Get trade status
                STradeStatus trade;
                if(GetTradeStatus(ticket, trade))
                {
                    // Update trade management
                    ManageSingleTrade(trade, upperLine, lowerLine, atr, currentBar);
                }
            }
        }
    }

    //+------------------------------------------------------------------+
    //| Manage Single Trade                                              |
    //+------------------------------------------------------------------+
    static void ManageSingleTrade(
        STradeStatus &trade,
        const STrendLine &upperLine,
        const STrendLine &lowerLine,
        const double atr,
        const int currentBar
    )
    {
        // Calculate current P/L
        CalculateCurrentPL(trade);

        // 1. Check for breakeven trigger
        if(!trade.isBreakevenActive)
        {
            if(ShouldMoveToBreakeven(trade, atr))
            {
                MoveToBreakeven(trade);
            }
        }

        // 2. Check for trailing stop
        if(!trade.isTrailingActive && trade.isBreakevenActive)
        {
            if(ShouldActivateTrailing(trade, atr))
            {
                trade.isTrailingActive = true;
                CLogger::Info(StringFormat(
                    "Trailing stop activated for ticket %d",
                    trade.ticket
                ));
            }
        }

        if(trade.isTrailingActive)
        {
            ApplyTrailingStop(trade, atr);
        }

        // 3. Check for partial profit
        if(!trade.isScaledOut)
        {
            if(ShouldScaleOut(trade))
            {
                ScaleOutPosition(trade);
            }
        }

        // 4. Check if trade should be closed early (wedge invalidation)
        if(ShouldCloseTradeEarly(trade, upperLine, lowerLine, currentBar))
        {
            CloseTrade(trade.ticket, "Wedge pattern invalidated");
        }
    }

    //+------------------------------------------------------------------+
    //| Move Stop Loss to Breakeven                                      |
    //+------------------------------------------------------------------+
    static bool MoveToBreakeven(STradeStatus &trade)
    {
        double newSL;

        if(trade.type == SIGNAL_BUY)
        {
            newSL = trade.entryPrice + CMathUtils::PipsToPrice(5.0, trade.symbol);
        }
        else // SIGNAL_SELL
        {
            newSL = trade.entryPrice - CMathUtils::PipsToPrice(5.0, trade.symbol);
        }

        if(ModifyStopLoss(trade.ticket, newSL))
        {
            trade.stopLoss = newSL;
            trade.isBreakevenActive = true;

            CLogger::Info(StringFormat(
                "Breakeven activated for ticket %d at %.5f (Entry: %.5f)",
                trade.ticket, newSL, trade.entryPrice
            ));

            return true;
        }

        return false;
    }

    //+------------------------------------------------------------------+
    //| Apply Trailing Stop                                              |
    //+------------------------------------------------------------------+
    static bool ApplyTrailingStop(STradeStatus &trade, const double atr)
    {
        double newSL;

        if(trade.type == SIGNAL_BUY)
        {
            // Trail stop at Current Price - ATR
            newSL = trade.currentPrice - atr;

            // Only move SL up, never down
            if(newSL <= trade.stopLoss)
                return false;
        }
        else // SIGNAL_SELL
        {
            // Trail stop at Current Price + ATR
            newSL = trade.currentPrice + atr;

            // Only move SL down, never up
            if(newSL >= trade.stopLoss)
                return false;
        }

        if(ModifyStopLoss(trade.ticket, newSL))
        {
            CLogger::Debug(StringFormat(
                "Trailing stop updated for ticket %d: %.5f -> %.5f",
                trade.ticket, trade.stopLoss, newSL
            ));

            trade.stopLoss = newSL;
            return true;
        }

        return false;
    }

    //+------------------------------------------------------------------+
    //| Scale Out Position (Take Partial Profit)                         |
    //+------------------------------------------------------------------+
    static bool ScaleOutPosition(STradeStatus &trade, const double percent = 50.0)
    {
        double closeVolume = trade.lots * (percent / 100.0);
        closeVolume = CValidators::NormalizeLots(closeVolume, trade.symbol);

        if(closeVolume <= 0.0)
        {
            CLogger::Warning("ScaleOutPosition: Close volume too small");
            return false;
        }

        // Close partial position
        MqlTradeRequest request;
        MqlTradeResult result;

        ZeroMemory(request);
        ZeroMemory(result);

        request.action = TRADE_ACTION_DEAL;
        request.position = trade.ticket;
        request.symbol = trade.symbol;
        request.volume = closeVolume;
        request.type = (trade.type == SIGNAL_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        request.deviation = 10;

        if(OrderSend(request, result))
        {
            if(result.retcode == TRADE_RETCODE_DONE)
            {
                trade.isScaledOut = true;
                trade.lots -= closeVolume;

                CLogger::Info(StringFormat(
                    "Scaled out %.2f lots from ticket %d at %.5f",
                    closeVolume, trade.ticket, trade.currentPrice
                ));

                return true;
            }
        }

        CLogger::Error(StringFormat(
            "Failed to scale out position: %d - %s",
            result.retcode, result.comment
        ));

        return false;
    }

    //+------------------------------------------------------------------+
    //| Close Trade Manually                                             |
    //+------------------------------------------------------------------+
    static bool CloseTrade(const ulong ticket, const string reason)
    {
        if(!PositionSelectByTicket(ticket))
        {
            CLogger::Warning(StringFormat("Position %d not found", ticket));
            return false;
        }

        MqlTradeRequest request;
        MqlTradeResult result;

        ZeroMemory(request);
        ZeroMemory(result);

        request.action = TRADE_ACTION_DEAL;
        request.position = ticket;
        request.symbol = PositionGetString(POSITION_SYMBOL);
        request.volume = PositionGetDouble(POSITION_VOLUME);
        request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
                       ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        request.deviation = 10;

        if(OrderSend(request, result))
        {
            if(result.retcode == TRADE_RETCODE_DONE)
            {
                CLogger::Info(StringFormat(
                    "Position %d closed: %s",
                    ticket, reason
                ));

                return true;
            }
        }

        CLogger::Error(StringFormat(
            "Failed to close position %d: %d - %s",
            ticket, result.retcode, result.comment
        ));

        return false;
    }

private:
    //+------------------------------------------------------------------+
    //| Get Trade Status from Position                                   |
    //+------------------------------------------------------------------+
    static bool GetTradeStatus(const ulong ticket, STradeStatus &trade)
    {
        if(!PositionSelectByTicket(ticket))
            return false;

        trade.ticket = ticket;
        trade.symbol = PositionGetString(POSITION_SYMBOL);
        trade.entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        trade.currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        trade.stopLoss = PositionGetDouble(POSITION_SL);
        trade.takeProfit = PositionGetDouble(POSITION_TP);
        trade.lots = PositionGetDouble(POSITION_VOLUME);
        trade.entryTime = (datetime)PositionGetInteger(POSITION_TIME);
        trade.lastUpdate = TimeCurrent();

        // Determine type
        trade.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
                     SIGNAL_BUY : SIGNAL_SELL;

        // Initialize flags (would need to track these separately in production)
        trade.isBreakevenActive = false;
        trade.isTrailingActive = false;
        trade.isScaledOut = false;

        // Check if breakeven is active (SL is at or above entry for long)
        if(trade.type == SIGNAL_BUY && trade.stopLoss >= trade.entryPrice)
            trade.isBreakevenActive = true;
        else if(trade.type == SIGNAL_SELL && trade.stopLoss <= trade.entryPrice)
            trade.isBreakevenActive = true;

        return true;
    }

    //+------------------------------------------------------------------+
    //| Calculate Current P/L                                            |
    //+------------------------------------------------------------------+
    static void CalculateCurrentPL(STradeStatus &trade)
    {
        trade.currentPL = PositionGetDouble(POSITION_PROFIT);

        // Calculate P/L in pips
        if(trade.type == SIGNAL_BUY)
        {
            trade.currentPLPips = CMathUtils::DistanceInPips(
                trade.currentPrice, trade.entryPrice, trade.symbol
            );
        }
        else
        {
            trade.currentPLPips = CMathUtils::DistanceInPips(
                trade.entryPrice, trade.currentPrice, trade.symbol
            );
        }

        // Calculate P/L as percentage of risk
        double risk = CMathUtils::DistanceInPips(
            trade.entryPrice, trade.stopLoss, trade.symbol
        );

        if(risk > 0.0)
        {
            trade.currentPLPercent = (trade.currentPLPips / risk) * 100.0;
        }
        else
        {
            trade.currentPLPercent = 0.0;
        }
    }

    //+------------------------------------------------------------------+
    //| Check if Should Move to Breakeven                                |
    //+------------------------------------------------------------------+
    static bool ShouldMoveToBreakeven(const STradeStatus &trade, const double atr)
    {
        // Move to breakeven when profit > 1× ATR
        if(trade.type == SIGNAL_BUY)
        {
            return (trade.currentPrice >= trade.entryPrice + atr);
        }
        else
        {
            return (trade.currentPrice <= trade.entryPrice - atr);
        }
    }

    //+------------------------------------------------------------------+
    //| Check if Should Activate Trailing Stop                           |
    //+------------------------------------------------------------------+
    static bool ShouldActivateTrailing(const STradeStatus &trade, const double atr)
    {
        // Activate trailing when profit > 1× ATR and breakeven is active
        return ShouldMoveToBreakeven(trade, atr);
    }

    //+------------------------------------------------------------------+
    //| Check if Should Scale Out                                        |
    //+------------------------------------------------------------------+
    static bool ShouldScaleOut(const STradeStatus &trade)
    {
        // Scale out at 50% of TP target (or when profit is 1.5× risk)
        return (trade.currentPLPercent >= 150.0);
    }

    //+------------------------------------------------------------------+
    //| Check if Trade Should Be Closed Early                            |
    //+------------------------------------------------------------------+
    static bool ShouldCloseTradeEarly(
        const STradeStatus &trade,
        const STrendLine &upperLine,
        const STrendLine &lowerLine,
        const int currentBar
    )
    {
        // Check if price broke both lines (wedge invalidation)
        double upperPrice = CTrendLineDetection::GetPriceAtBar(upperLine, currentBar);
        double lowerPrice = CTrendLineDetection::GetPriceAtBar(lowerLine, currentBar);

        if(trade.currentPrice > upperPrice && trade.type == SIGNAL_BUY)
        {
            // Price broke above resistance - potential breakout, let it run
            return false;
        }

        if(trade.currentPrice < lowerPrice && trade.type == SIGNAL_SELL)
        {
            // Price broke below support - potential breakout, let it run
            return false;
        }

        // Close if price moved against the wedge pattern
        if(trade.type == SIGNAL_BUY && trade.currentPrice > upperPrice)
            return true;

        if(trade.type == SIGNAL_SELL && trade.currentPrice < lowerPrice)
            return true;

        return false;
    }

    //+------------------------------------------------------------------+
    //| Modify Stop Loss                                                 |
    //+------------------------------------------------------------------+
    static bool ModifyStopLoss(const ulong ticket, const double newSL)
    {
        if(!PositionSelectByTicket(ticket))
            return false;

        MqlTradeRequest request;
        MqlTradeResult result;

        ZeroMemory(request);
        ZeroMemory(result);

        request.action = TRADE_ACTION_SLTP;
        request.position = ticket;
        request.symbol = PositionGetString(POSITION_SYMBOL);
        request.sl = CValidators::NormalizePrice(newSL, request.symbol);
        request.tp = PositionGetDouble(POSITION_TP);

        if(OrderSend(request, result))
        {
            if(result.retcode == TRADE_RETCODE_DONE)
                return true;
        }

        CLogger::Error(StringFormat(
            "Failed to modify SL for ticket %d: %d - %s",
            ticket, result.retcode, result.comment
        ));

        return false;
    }
};

//+------------------------------------------------------------------+
