//+------------------------------------------------------------------+
//|                                         ConvergenceAnalysis.mqh |
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
//| Convergence Data Structure                                        |
//+------------------------------------------------------------------+
struct SConvergenceData
{
    double currentWidth;           // Current channel width (pips)
    double initialWidth;           // Initial channel width (pips)
    double compressionRate;        // Rate of narrowing per bar
    int barsToConvergence;         // Bars until lines converge
    double convergencePrice;       // Price at convergence point
    double compressionPercent;     // % change in width per bar
    bool isWedgeValid;             // Pattern integrity check
    bool isCompressing;            // Is wedge compressing (not expanding)
    bool isBreakoutImminent;       // Breakout warning (< 5 bars)
    double middleLinePrice;        // Price at middle of channel
};

//+------------------------------------------------------------------+
//| Convergence Analysis Class                                        |
//+------------------------------------------------------------------+
class CConvergenceAnalysis
{
public:
    //+------------------------------------------------------------------+
    //| Calculate Convergence Metrics                                    |
    //+------------------------------------------------------------------+
    static bool CalculateConvergence(
        const STrendLine &upperLine,
        const STrendLine &lowerLine,
        const int currentBar,
        SConvergenceData &data,
        string symbol = NULL
    )
    {
        if(symbol == NULL) symbol = _Symbol;

        // Validate input
        if(!upperLine.isValid || !lowerLine.isValid)
        {
            CLogger::Warning("CalculateConvergence: Invalid trend lines");
            data.isWedgeValid = false;
            return false;
        }

        // Calculate current width
        double upperPrice = CTrendLineDetection::GetPriceAtBar(upperLine, currentBar);
        double lowerPrice = CTrendLineDetection::GetPriceAtBar(lowerLine, currentBar);

        data.currentWidth = CMathUtils::DistanceInPips(upperPrice, lowerPrice, symbol);

        // Calculate initial width (at start of lookback period)
        int lookbackBar = currentBar + 60; // Assuming 60 bar lookback
        double upperPriceInitial = CTrendLineDetection::GetPriceAtBar(upperLine, lookbackBar);
        double lowerPriceInitial = CTrendLineDetection::GetPriceAtBar(lowerLine, lookbackBar);

        data.initialWidth = CMathUtils::DistanceInPips(upperPriceInitial, lowerPriceInitial, symbol);

        // Calculate compression rate (slope difference)
        data.compressionRate = MathAbs(upperLine.slope - lowerLine.slope);

        // Calculate compression percentage per bar
        if(data.initialWidth > 0)
        {
            double widthChange = data.currentWidth - data.initialWidth;
            data.compressionPercent = (widthChange / data.initialWidth) * 100.0 / 60.0; // Per bar
        }
        else
        {
            data.compressionPercent = 0.0;
        }

        // Calculate convergence point
        // When y_upper = y_lower:
        // m1*x + b1 = m2*x + b2
        // x = (b2 - b1) / (m1 - m2)
        double slopeDiff = upperLine.slope - lowerLine.slope;

        if(MathAbs(slopeDiff) < 0.00000001)
        {
            // Lines are parallel - no convergence
            data.barsToConvergence = 999999;
            data.convergencePrice = 0.0;
            data.isWedgeValid = false;
            CLogger::Debug("CalculateConvergence: Lines are parallel");
            return false;
        }

        double convergenceBar = (lowerLine.intercept - upperLine.intercept) / slopeDiff;
        data.barsToConvergence = (int)(convergenceBar - currentBar);

        // Calculate price at convergence
        data.convergencePrice = CTrendLineDetection::GetPriceAtBar(upperLine, (int)convergenceBar);

        // Calculate middle line price
        data.middleLinePrice = (upperPrice + lowerPrice) / 2.0;

        // Validate wedge pattern
        data.isWedgeValid = ValidateWedge(data);
        data.isCompressing = IsCompressing(data);
        data.isBreakoutImminent = IsBreakoutImminent(data);

        CLogger::Debug(StringFormat(
            "Convergence: Width=%.1f pips, Compression=%.2f%%, Bars=%d, Valid=%s",
            data.currentWidth, data.compressionPercent, data.barsToConvergence,
            data.isWedgeValid ? "Yes" : "No"
        ));

        return data.isWedgeValid;
    }

    //+------------------------------------------------------------------+
    //| Check if Wedge is Compressing (not expanding)                    |
    //+------------------------------------------------------------------+
    static bool IsCompressing(
        const SConvergenceData &data,
        const double threshold = -2.0  // -2% per bar
    )
    {
        // Compression percentage should be negative (width decreasing)
        // and greater than threshold
        return (data.compressionPercent < 0.0 && data.compressionPercent > threshold);
    }

    //+------------------------------------------------------------------+
    //| Check if Breakout is Imminent                                    |
    //+------------------------------------------------------------------+
    static bool IsBreakoutImminent(
        const SConvergenceData &data,
        const int minBars = 3,
        const int maxBars = 30
    )
    {
        // Breakout warning if convergence is close
        return (data.barsToConvergence >= minBars &&
                data.barsToConvergence < 5);
    }

    //+------------------------------------------------------------------+
    //| Check if Convergence Timing is Valid for Trading                 |
    //+------------------------------------------------------------------+
    static bool IsConvergenceValid(
        const SConvergenceData &data,
        const int minBars = 3,
        const int maxBars = 30
    )
    {
        // Convergence should be:
        // - Not too close (min 3 bars away)
        // - Not too far (max 30 bars away)
        return (data.barsToConvergence >= minBars &&
                data.barsToConvergence <= maxBars);
    }

    //+------------------------------------------------------------------+
    //| Calculate Middle Line Price                                      |
    //+------------------------------------------------------------------+
    static double GetMiddleLine(
        const STrendLine &upperLine,
        const STrendLine &lowerLine,
        const int bar
    )
    {
        double upperPrice = CTrendLineDetection::GetPriceAtBar(upperLine, bar);
        double lowerPrice = CTrendLineDetection::GetPriceAtBar(lowerLine, bar);

        return (upperPrice + lowerPrice) / 2.0;
    }

    //+------------------------------------------------------------------+
    //| Calculate Wedge Quality Score (0-100)                            |
    //+------------------------------------------------------------------+
    static double CalculateWedgeQuality(
        const STrendLine &upperLine,
        const STrendLine &lowerLine,
        const SConvergenceData &data
    )
    {
        double score = 0.0;

        // Factor 1: Touch point count (max 30 points)
        int totalTouches = upperLine.touchCount + lowerLine.touchCount;
        score += MathMin(totalTouches * 5.0, 30.0);

        // Factor 2: Compression rate (max 25 points)
        if(data.compressionPercent < 0.0 && data.compressionPercent > -5.0)
            score += 25.0;
        else if(data.compressionPercent < 0.0)
            score += 15.0;

        // Factor 3: Convergence timing (max 25 points)
        if(data.barsToConvergence >= 5 && data.barsToConvergence <= 20)
            score += 25.0;
        else if(data.barsToConvergence > 20 && data.barsToConvergence <= 30)
            score += 15.0;

        // Factor 4: Channel width (max 20 points)
        if(data.currentWidth >= 20.0 && data.currentWidth <= 100.0)
            score += 20.0;
        else if(data.currentWidth > 100.0 && data.currentWidth <= 200.0)
            score += 10.0;

        return MathMin(score, 100.0);
    }

    //+------------------------------------------------------------------+
    //| Calculate Breakout Probability (0.0 to 1.0)                      |
    //+------------------------------------------------------------------+
    static double CalculateBreakoutProbability(
        const SConvergenceData &data,
        const double compressionRate
    )
    {
        // Probability increases as convergence approaches
        if(data.barsToConvergence <= 0)
            return 1.0;

        if(data.barsToConvergence > 30)
            return 0.0;

        // Exponential increase in probability
        // P = 1 - e^(-rate * bars_remaining)
        double barsRemaining = (double)data.barsToConvergence;
        double rate = compressionRate * 10.0; // Amplify for better scaling

        double probability = 1.0 - MathExp(-rate * (30.0 - barsRemaining) / 30.0);

        return MathMax(0.0, MathMin(probability, 1.0));
    }

    //+------------------------------------------------------------------+
    //| Check if Price is Inside Wedge                                   |
    //+------------------------------------------------------------------+
    static bool IsPriceInsideWedge(
        const double price,
        const STrendLine &upperLine,
        const STrendLine &lowerLine,
        const int bar
    )
    {
        double upperPrice = CTrendLineDetection::GetPriceAtBar(upperLine, bar);
        double lowerPrice = CTrendLineDetection::GetPriceAtBar(lowerLine, bar);

        return (price > lowerPrice && price < upperPrice);
    }

    //+------------------------------------------------------------------+
    //| Calculate Width Change Rate (pips per bar)                       |
    //+------------------------------------------------------------------+
    static double CalculateWidthChangeRate(
        const STrendLine &upperLine,
        const STrendLine &lowerLine,
        string symbol = NULL
    )
    {
        if(symbol == NULL) symbol = _Symbol;

        // Width change rate is the difference in slopes
        double slopeDiff = upperLine.slope - lowerLine.slope;

        // Convert to pips per bar
        return CMathUtils::PriceToPips(MathAbs(slopeDiff), symbol);
    }

private:
    //+------------------------------------------------------------------+
    //| Validate Wedge Pattern Integrity                                 |
    //+------------------------------------------------------------------+
    static bool ValidateWedge(const SConvergenceData &data)
    {
        // Wedge is valid if:
        // 1. Width is positive
        if(data.currentWidth <= 0.0)
        {
            CLogger::Debug("Wedge validation failed: negative width");
            return false;
        }

        // 2. Compressing (not expanding)
        if(data.compressionPercent >= 0.0)
        {
            CLogger::Debug("Wedge validation failed: expanding instead of compressing");
            return false;
        }

        // 3. Compression rate is reasonable (not too fast or too slow)
        if(data.compressionPercent < -10.0)
        {
            CLogger::Debug("Wedge validation failed: compression too fast");
            return false;
        }

        // 4. Convergence is in reasonable timeframe
        if(data.barsToConvergence < 0 || data.barsToConvergence > 100)
        {
            CLogger::Debug("Wedge validation failed: convergence out of range");
            return false;
        }

        // 5. Channel width is reasonable (not too narrow or too wide)
        if(data.currentWidth < 10.0 || data.currentWidth > 500.0)
        {
            CLogger::Debug("Wedge validation failed: width out of range");
            return false;
        }

        return true;
    }
};

//+------------------------------------------------------------------+
