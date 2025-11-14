//+------------------------------------------------------------------+
//|                                              PricePosition.mqh |
//|                                    BIONICLES Development Team    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "BIONICLES Development Team"
#property link      "https://bionicles.io"
#property version   "1.00"
#property strict

#include "TrendLineDetection.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Price Zone Enumeration                                            |
//+------------------------------------------------------------------+
enum ENUM_PRICE_ZONE
{
    ZONE_SUPPORT,          // Position ratio < 0.20 (near lower line)
    ZONE_RESISTANCE,       // Position ratio > 0.80 (near upper line)
    ZONE_NEUTRAL,          // In between (0.20 to 0.80)
    ZONE_OUTSIDE_ABOVE,    // Price broke above upper line
    ZONE_OUTSIDE_BELOW     // Price broke below lower line
};

//+------------------------------------------------------------------+
//| Price Position Structure                                          |
//+------------------------------------------------------------------+
struct SPricePosition
{
    double positionRatio;          // 0.0 to 1.0 (0=lower line, 1=upper line)
    ENUM_PRICE_ZONE zone;          // Current zone
    double distanceToSupport;      // Pips to lower line
    double distanceToResistance;   // Pips to upper line
    double distanceToMiddle;       // Pips to middle line
    bool isTouchingSupport;        // Within ATR×0.3 of lower line
    bool isTouchingResistance;     // Within ATR×0.3 of upper line
    bool isOutsideWedge;           // Price outside channel
    double currentPrice;           // Current price
    double upperLinePrice;         // Upper line price at current bar
    double lowerLinePrice;         // Lower line price at current bar
    double middleLinePrice;        // Middle line price at current bar
};

//+------------------------------------------------------------------+
//| Price Position Detection Class                                    |
//+------------------------------------------------------------------+
class CPricePosition
{
public:
    //+------------------------------------------------------------------+
    //| Calculate Current Price Position                                 |
    //+------------------------------------------------------------------+
    static bool CalculatePosition(
        const double currentPrice,
        const STrendLine &upperLine,
        const STrendLine &lowerLine,
        const int currentBar,
        const double atr,
        SPricePosition &position,
        string symbol = NULL
    )
    {
        if(symbol == NULL) symbol = _Symbol;

        // Validate input
        if(!upperLine.isValid || !lowerLine.isValid)
        {
            CLogger::Warning("CalculatePosition: Invalid trend lines");
            return false;
        }

        // Store current price
        position.currentPrice = currentPrice;

        // Get line prices at current bar
        position.upperLinePrice = CTrendLineDetection::GetPriceAtBar(upperLine, currentBar);
        position.lowerLinePrice = CTrendLineDetection::GetPriceAtBar(lowerLine, currentBar);
        position.middleLinePrice = (position.upperLinePrice + position.lowerLinePrice) / 2.0;

        // Calculate distances in pips
        position.distanceToSupport = CMathUtils::DistanceInPips(
            currentPrice, position.lowerLinePrice, symbol
        );
        position.distanceToResistance = CMathUtils::DistanceInPips(
            currentPrice, position.upperLinePrice, symbol
        );
        position.distanceToMiddle = CMathUtils::DistanceInPips(
            currentPrice, position.middleLinePrice, symbol
        );

        // Calculate position ratio (0.0 to 1.0)
        double channelWidth = position.upperLinePrice - position.lowerLinePrice;

        if(channelWidth <= 0.0)
        {
            CLogger::Error("CalculatePosition: Invalid channel width");
            return false;
        }

        position.positionRatio = (currentPrice - position.lowerLinePrice) / channelWidth;

        // Determine zone
        position.zone = DetermineZone(position.positionRatio, currentPrice,
                                      position.upperLinePrice, position.lowerLinePrice);

        // Check if price is outside wedge
        position.isOutsideWedge = (position.zone == ZONE_OUTSIDE_ABOVE ||
                                   position.zone == ZONE_OUTSIDE_BELOW);

        // Check touch points (within ATR × 0.3)
        double touchThreshold = atr * 0.3;

        position.isTouchingSupport = IsTouchingSupport(
            currentPrice, lowerLine, currentBar, atr, 0.3
        );

        position.isTouchingResistance = IsTouchingResistance(
            currentPrice, upperLine, currentBar, atr, 0.3
        );

        CLogger::Debug(StringFormat(
            "Position: Ratio=%.2f, Zone=%s, DistSupport=%.1f pips, DistResist=%.1f pips",
            position.positionRatio, EnumToString(position.zone),
            position.distanceToSupport, position.distanceToResistance
        ));

        return true;
    }

    //+------------------------------------------------------------------+
    //| Check if Price is Touching Support                               |
    //+------------------------------------------------------------------+
    static bool IsTouchingSupport(
        const double price,
        const STrendLine &lowerLine,
        const int bar,
        const double atr,
        const double threshold = 0.3
    )
    {
        double lowerPrice = CTrendLineDetection::GetPriceAtBar(lowerLine, bar);
        double distance = MathAbs(price - lowerPrice);
        double touchThreshold = atr * threshold;

        return (distance <= touchThreshold && price >= lowerPrice);
    }

    //+------------------------------------------------------------------+
    //| Check if Price is Touching Resistance                            |
    //+------------------------------------------------------------------+
    static bool IsTouchingResistance(
        const double price,
        const STrendLine &upperLine,
        const int bar,
        const double atr,
        const double threshold = 0.3
    )
    {
        double upperPrice = CTrendLineDetection::GetPriceAtBar(upperLine, bar);
        double distance = MathAbs(price - upperPrice);
        double touchThreshold = atr * threshold;

        return (distance <= touchThreshold && price <= upperPrice);
    }

    //+------------------------------------------------------------------+
    //| Check if Price is in Buy Zone (near support)                     |
    //+------------------------------------------------------------------+
    static bool IsInBuyZone(const SPricePosition &position)
    {
        return (position.zone == ZONE_SUPPORT ||
                (position.positionRatio < 0.20 && !position.isOutsideWedge));
    }

    //+------------------------------------------------------------------+
    //| Check if Price is in Sell Zone (near resistance)                 |
    //+------------------------------------------------------------------+
    static bool IsInSellZone(const SPricePosition &position)
    {
        return (position.zone == ZONE_RESISTANCE ||
                (position.positionRatio > 0.80 && !position.isOutsideWedge));
    }

    //+------------------------------------------------------------------+
    //| Check if Price is in Neutral Zone                                |
    //+------------------------------------------------------------------+
    static bool IsInNeutralZone(const SPricePosition &position)
    {
        return (position.zone == ZONE_NEUTRAL);
    }

    //+------------------------------------------------------------------+
    //| Get Distance to Nearest Line                                     |
    //+------------------------------------------------------------------+
    static double GetDistanceToNearestLine(const SPricePosition &position)
    {
        return MathMin(position.distanceToSupport, position.distanceToResistance);
    }

    //+------------------------------------------------------------------+
    //| Check if Price Crossed Middle Line                               |
    //+------------------------------------------------------------------+
    static bool CrossedMiddleLine(
        const double currentPrice,
        const double previousPrice,
        const double middleLinePrice
    )
    {
        // Check if price crossed from below to above
        bool crossedUp = (previousPrice < middleLinePrice && currentPrice >= middleLinePrice);

        // Check if price crossed from above to below
        bool crossedDown = (previousPrice > middleLinePrice && currentPrice <= middleLinePrice);

        return (crossedUp || crossedDown);
    }

    //+------------------------------------------------------------------+
    //| Get Position Strength (0-100)                                    |
    //| Higher score = better position for entry                          |
    //+------------------------------------------------------------------+
    static double CalculatePositionStrength(const SPricePosition &position)
    {
        double strength = 0.0;

        // Factor 1: Distance from entry zone (max 40 points)
        if(position.zone == ZONE_SUPPORT)
            strength += 40.0;
        else if(position.zone == ZONE_RESISTANCE)
            strength += 40.0;
        else if(position.positionRatio < 0.25 || position.positionRatio > 0.75)
            strength += 25.0;
        else if(position.positionRatio < 0.35 || position.positionRatio > 0.65)
            strength += 15.0;

        // Factor 2: Touch confirmation (max 30 points)
        if(position.isTouchingSupport || position.isTouchingResistance)
            strength += 30.0;

        // Factor 3: Distance from middle (max 30 points)
        if(position.distanceToMiddle > 20.0)
            strength += 30.0;
        else if(position.distanceToMiddle > 10.0)
            strength += 20.0;
        else if(position.distanceToMiddle > 5.0)
            strength += 10.0;

        // Penalty for being outside wedge
        if(position.isOutsideWedge)
            strength = 0.0;

        return MathMin(strength, 100.0);
    }

    //+------------------------------------------------------------------+
    //| Check if Multiple Consecutive Bars Near Line                     |
    //+------------------------------------------------------------------+
    static bool HasConsecutiveTouches(
        const double &prices[],
        const STrendLine &line,
        const double atr,
        const int consecutiveBars = 2,
        const double threshold = 0.3
    )
    {
        int touchCount = 0;
        double touchThreshold = atr * threshold;

        for(int i = 0; i < MathMin(consecutiveBars, ArraySize(prices)); i++)
        {
            double linePrice = CTrendLineDetection::GetPriceAtBar(line, i);
            double distance = MathAbs(prices[i] - linePrice);

            if(distance <= touchThreshold)
                touchCount++;
            else
                break; // Not consecutive anymore
        }

        return (touchCount >= consecutiveBars);
    }

private:
    //+------------------------------------------------------------------+
    //| Determine Price Zone                                             |
    //+------------------------------------------------------------------+
    static ENUM_PRICE_ZONE DetermineZone(
        const double ratio,
        const double price,
        const double upperPrice,
        const double lowerPrice
    )
    {
        // Check if outside wedge first
        if(price > upperPrice)
            return ZONE_OUTSIDE_ABOVE;

        if(price < lowerPrice)
            return ZONE_OUTSIDE_BELOW;

        // Inside wedge - determine zone by ratio
        if(ratio < 0.20)
            return ZONE_SUPPORT;

        if(ratio > 0.80)
            return ZONE_RESISTANCE;

        return ZONE_NEUTRAL;
    }
};

//+------------------------------------------------------------------+
