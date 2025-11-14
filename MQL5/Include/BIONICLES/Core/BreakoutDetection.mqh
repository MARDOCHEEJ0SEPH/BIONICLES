//+------------------------------------------------------------------+
//|                                         BreakoutDetection.mqh |
//|                                    BIONICLES Development Team    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "BIONICLES Development Team"
#property link      "https://bionicles.io"
#property version   "1.00"
#property strict

#include "TrendLineDetection.mqh"
#include "ConvergenceAnalysis.mqh"
#include "TradeManagement.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Breakout Direction Enumeration                                    |
//+------------------------------------------------------------------+
enum ENUM_BREAKOUT_DIRECTION
{
    BREAKOUT_NONE,         // No breakout
    BREAKOUT_UPSIDE,       // Breakout above resistance
    BREAKOUT_DOWNSIDE,     // Breakout below support
    BREAKOUT_AMBIGUOUS     // Unclear direction
};

//+------------------------------------------------------------------+
//| Breakout Data Structure                                           |
//+------------------------------------------------------------------+
struct SBreakoutData
{
    ENUM_BREAKOUT_DIRECTION direction;  // Breakout direction
    double breakoutPrice;               // Price at breakout
    datetime breakoutTime;              // Time of breakout
    double breakoutProbability;         // Probability (0.0 to 1.0)
    bool isConfirmed;                   // 2 consecutive bars confirmation
    int consecutiveBars;                // Number of consecutive bars outside
    bool isPreBreakoutWarning;          // Warning: breakout imminent
    double breakoutVolume;              // Volume at breakout (if available)
};

//+------------------------------------------------------------------+
//| Breakout Detection Class                                          |
//+------------------------------------------------------------------+
class CBreakoutDetection
{
public:
    //+------------------------------------------------------------------+
    //| Detect Breakout Conditions                                       |
    //+------------------------------------------------------------------+
    static bool DetectBreakout(
        const double currentPrice,
        const double previousPrice,
        const STrendLine &upperLine,
        const STrendLine &lowerLine,
        const SConvergenceData &convergence,
        const int currentBar,
        SBreakoutData &breakout
    )
    {
        // Initialize
        breakout.direction = BREAKOUT_NONE;
        breakout.isConfirmed = false;
        breakout.consecutiveBars = 0;
        breakout.breakoutTime = TimeCurrent();

        // Get line prices
        double upperPrice = CTrendLineDetection::GetPriceAtBar(upperLine, currentBar);
        double lowerPrice = CTrendLineDetection::GetPriceAtBar(lowerLine, currentBar);
        double middleLine = (upperPrice + lowerPrice) / 2.0;

        // Check for pre-breakout warning
        breakout.isPreBreakoutWarning = IsPreBreakoutWarning(convergence);

        // Detect breakout direction
        if(currentPrice > upperPrice)
        {
            // Upside breakout
            breakout.direction = BREAKOUT_UPSIDE;
            breakout.breakoutPrice = currentPrice;

            // Check if previous bar was also above
            if(previousPrice > upperPrice)
                breakout.consecutiveBars = 2;
            else
                breakout.consecutiveBars = 1;
        }
        else if(currentPrice < lowerPrice)
        {
            // Downside breakout
            breakout.direction = BREAKOUT_DOWNSIDE;
            breakout.breakoutPrice = currentPrice;

            // Check if previous bar was also below
            if(previousPrice < lowerPrice)
                breakout.consecutiveBars = 2;
            else
                breakout.consecutiveBars = 1;
        }
        else
        {
            // No breakout - price inside wedge
            breakout.direction = GetBreakoutDirection(currentPrice, middleLine, previousPrice);
            breakout.breakoutPrice = 0.0;
        }

        // Confirm breakout (need 2 consecutive bars)
        breakout.isConfirmed = (breakout.consecutiveBars >= 2);

        // Calculate breakout probability
        breakout.breakoutProbability = CalculateBreakoutProbability(
            convergence, convergence.compressionRate
        );

        // Log breakout detection
        if(breakout.direction != BREAKOUT_NONE)
        {
            CLogger::Info(StringFormat(
                "Breakout detected: %s at %.5f | Confirmed: %s | Probability: %.1f%%",
                EnumToString(breakout.direction), breakout.breakoutPrice,
                breakout.isConfirmed ? "Yes" : "No",
                breakout.breakoutProbability * 100.0
            ));
        }

        return (breakout.direction != BREAKOUT_NONE);
    }

    //+------------------------------------------------------------------+
    //| Check if Pre-Breakout Warning Should Be Triggered                |
    //+------------------------------------------------------------------+
    static bool IsPreBreakoutWarning(
        const SConvergenceData &convergence,
        const int warningBars = 5
    )
    {
        // Warning if convergence is within 5 bars
        if(convergence.barsToConvergence < warningBars &&
           convergence.barsToConvergence > 0)
        {
            return true;
        }

        return false;
    }

    //+------------------------------------------------------------------+
    //| Calculate Breakout Probability                                   |
    //+------------------------------------------------------------------+
    static double CalculateBreakoutProbability(
        const SConvergenceData &convergence,
        const double compressionRate
    )
    {
        if(convergence.barsToConvergence <= 0)
            return 1.0; // Already converged

        if(convergence.barsToConvergence > 30)
            return 0.0; // Too far away

        // Exponential increase as convergence approaches
        // P = 1 - e^(-rate × compression_factor)
        double barsRemaining = (double)convergence.barsToConvergence;
        double compressionFactor = MathAbs(compressionRate) * 100.0;

        // Normalize to range [0, 1]
        double exponent = -compressionFactor * (30.0 - barsRemaining) / 300.0;
        double probability = 1.0 - MathExp(exponent);

        return MathMax(0.0, MathMin(probability, 1.0));
    }

    //+------------------------------------------------------------------+
    //| Determine Breakout Direction (even if not broken yet)            |
    //+------------------------------------------------------------------+
    static ENUM_BREAKOUT_DIRECTION GetBreakoutDirection(
        const double price,
        const double middleLine,
        const double previousClose
    )
    {
        // Determine likely breakout direction based on price position

        // If price above middle and moving up
        if(price > middleLine && price > previousClose)
            return BREAKOUT_UPSIDE;

        // If price below middle and moving down
        if(price < middleLine && price < previousClose)
            return BREAKOUT_DOWNSIDE;

        // If near middle or unclear
        if(MathAbs(price - middleLine) < (middleLine * 0.001)) // Within 0.1%
            return BREAKOUT_AMBIGUOUS;

        return BREAKOUT_NONE;
    }

    //+------------------------------------------------------------------+
    //| Handle Active Trades During Breakout                             |
    //+------------------------------------------------------------------+
    static void HandleBreakoutTrades(const SBreakoutData &breakout)
    {
        if(!breakout.isConfirmed)
            return; // Only handle confirmed breakouts

        // Loop through all open positions
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);

            if(ticket > 0)
            {
                // Get position type
                ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);

                // Move all stop losses to breakeven immediately
                double stopLoss = PositionGetDouble(POSITION_SL);

                // For BUY positions
                if(posType == POSITION_TYPE_BUY)
                {
                    if(breakout.direction == BREAKOUT_UPSIDE)
                    {
                        // Breakout in our favor - let it run
                        if(stopLoss < entryPrice)
                        {
                            // Move to breakeven
                            ModifyStopLoss(ticket, entryPrice);

                            CLogger::Info(StringFormat(
                                "Breakout upside - Moving SL to breakeven for ticket %d",
                                ticket
                            ));
                        }
                    }
                    else if(breakout.direction == BREAKOUT_DOWNSIDE)
                    {
                        // Breakout against us - close position
                        CLogger::Warning(StringFormat(
                            "Breakout downside - Closing BUY position ticket %d",
                            ticket
                        ));

                        CTradeManagement::CloseTrade(ticket, "Breakout against position");
                    }
                }
                // For SELL positions
                else if(posType == POSITION_TYPE_SELL)
                {
                    if(breakout.direction == BREAKOUT_DOWNSIDE)
                    {
                        // Breakout in our favor - let it run
                        if(stopLoss > entryPrice)
                        {
                            // Move to breakeven
                            ModifyStopLoss(ticket, entryPrice);

                            CLogger::Info(StringFormat(
                                "Breakout downside - Moving SL to breakeven for ticket %d",
                                ticket
                            ));
                        }
                    }
                    else if(breakout.direction == BREAKOUT_UPSIDE)
                    {
                        // Breakout against us - close position
                        CLogger::Warning(StringFormat(
                            "Breakout upside - Closing SELL position ticket %d",
                            ticket
                        ));

                        CTradeManagement::CloseTrade(ticket, "Breakout against position");
                    }
                }
            }
        }
    }

    //+------------------------------------------------------------------+
    //| Check if Breakout Has Failed (False Breakout)                    |
    //+------------------------------------------------------------------+
    static bool IsFailedBreakout(
        const double currentPrice,
        const SBreakoutData &previousBreakout,
        const STrendLine &upperLine,
        const STrendLine &lowerLine,
        const int currentBar
    )
    {
        if(previousBreakout.direction == BREAKOUT_NONE)
            return false; // No previous breakout to fail

        double upperPrice = CTrendLineDetection::GetPriceAtBar(upperLine, currentBar);
        double lowerPrice = CTrendLineDetection::GetPriceAtBar(lowerLine, currentBar);

        // Check if price returned inside wedge after breakout
        if(previousBreakout.direction == BREAKOUT_UPSIDE)
        {
            // Failed if price came back below resistance
            if(currentPrice < upperPrice)
            {
                CLogger::Warning("Failed breakout detected: Price returned below resistance");
                return true;
            }
        }
        else if(previousBreakout.direction == BREAKOUT_DOWNSIDE)
        {
            // Failed if price came back above support
            if(currentPrice > lowerPrice)
            {
                CLogger::Warning("Failed breakout detected: Price returned above support");
                return true;
            }
        }

        return false;
    }

    //+------------------------------------------------------------------+
    //| Get Breakout Quality Score (0-100)                               |
    //+------------------------------------------------------------------+
    static double CalculateBreakoutQuality(const SBreakoutData &breakout)
    {
        double quality = 0.0;

        // Factor 1: Confirmation (max 40 points)
        if(breakout.isConfirmed)
            quality += 40.0;
        else if(breakout.consecutiveBars > 0)
            quality += 20.0;

        // Factor 2: Probability (max 30 points)
        quality += breakout.breakoutProbability * 30.0;

        // Factor 3: Clear direction (max 30 points)
        if(breakout.direction == BREAKOUT_UPSIDE || breakout.direction == BREAKOUT_DOWNSIDE)
            quality += 30.0;
        else if(breakout.direction != BREAKOUT_NONE)
            quality += 15.0;

        return MathMin(quality, 100.0);
    }

private:
    //+------------------------------------------------------------------+
    //| Modify Stop Loss (Internal Helper)                               |
    //+------------------------------------------------------------------+
    static bool ModifyStopLoss(const ulong ticket, const double newSL)
    {
        if(!PositionSelectByTicket(ticket))
            return false;

        string symbol = PositionGetString(POSITION_SYMBOL);
        double tp = PositionGetDouble(POSITION_TP);

        MqlTradeRequest request;
        MqlTradeResult result;

        ZeroMemory(request);
        ZeroMemory(result);

        request.action = TRADE_ACTION_SLTP;
        request.position = ticket;
        request.symbol = symbol;
        request.sl = CValidators::NormalizePrice(newSL, symbol);
        request.tp = tp;

        if(OrderSend(request, result))
        {
            return (result.retcode == TRADE_RETCODE_DONE);
        }

        return false;
    }
};

//+------------------------------------------------------------------+
