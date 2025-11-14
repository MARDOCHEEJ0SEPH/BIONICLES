//+------------------------------------------------------------------+
//|                                           TrendLineDetection.mqh |
//|                                    BIONICLES Development Team    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "BIONICLES Development Team"
#property link      "https://bionicles.io"
#property version   "1.00"
#property strict

#include "../Utils/MathUtils.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Trend Line Structure                                              |
//+------------------------------------------------------------------+
struct STrendLine
{
    double slope;              // m (slope of the line)
    double intercept;          // b (y-intercept)
    int touchPoints[];         // Bar indices where price touched the line
    int touchCount;            // Number of valid touches
    datetime startTime;        // Start time of the line
    datetime endTime;          // End time of the line
    double startPrice;         // Price at start
    double endPrice;           // Price at end
    bool isValid;              // Whether the line is valid (min 2 touches)
};

//+------------------------------------------------------------------+
//| Trend Line Detection Class                                        |
//+------------------------------------------------------------------+
class CTrendLineDetection
{
public:
    //+------------------------------------------------------------------+
    //| Calculate Upper Resistance Line                                  |
    //+------------------------------------------------------------------+
    static bool CalculateUpperLine(
        const double &highs[],          // High prices
        const int lookback,             // Number of bars to analyze
        STrendLine &line,               // Output: trend line
        string symbol = NULL,
        ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT
    )
    {
        if(symbol == NULL) symbol = _Symbol;
        if(timeframe == PERIOD_CURRENT) timeframe = _Period;

        // Initialize
        line.isValid = false;
        line.touchCount = 0;
        ArrayResize(line.touchPoints, 0);

        if(ArraySize(highs) < lookback || lookback < 10)
        {
            CLogger::Error("CalculateUpperLine: Insufficient data");
            return false;
        }

        // Find peak points
        int peaks[];
        FindPeaks(highs, lookback, peaks);

        if(ArraySize(peaks) < 2)
        {
            CLogger::Debug("CalculateUpperLine: Less than 2 peaks found");
            return false;
        }

        // Prepare data for linear regression
        double x[], y[];
        int peakCount = ArraySize(peaks);
        ArrayResize(x, peakCount);
        ArrayResize(y, peakCount);

        for(int i = 0; i < peakCount; i++)
        {
            x[i] = (double)peaks[i];        // Bar index
            y[i] = highs[peaks[i]];         // High price at peak
        }

        // Calculate linear regression
        CMathUtils::LinearRegression(x, y, peakCount, line.slope, line.intercept);

        // Validate trend line
        double atr = CalculateATR(symbol, timeframe, 14, 0);
        if(!ValidateTrendLine(line, highs, lookback, atr))
        {
            CLogger::Debug("CalculateUpperLine: Validation failed");
            return false;
        }

        // Set line properties
        line.startTime = iTime(symbol, timeframe, lookback - 1);
        line.endTime = iTime(symbol, timeframe, 0);
        line.startPrice = GetPriceAtBar(line, lookback - 1);
        line.endPrice = GetPriceAtBar(line, 0);
        line.isValid = true;

        CLogger::Debug(StringFormat(
            "Upper line: slope=%.7f, intercept=%.5f, touches=%d",
            line.slope, line.intercept, line.touchCount
        ));

        return true;
    }

    //+------------------------------------------------------------------+
    //| Calculate Lower Support Line                                     |
    //+------------------------------------------------------------------+
    static bool CalculateLowerLine(
        const double &lows[],           // Low prices
        const int lookback,             // Number of bars to analyze
        STrendLine &line,               // Output: trend line
        string symbol = NULL,
        ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT
    )
    {
        if(symbol == NULL) symbol = _Symbol;
        if(timeframe == PERIOD_CURRENT) timeframe = _Period;

        // Initialize
        line.isValid = false;
        line.touchCount = 0;
        ArrayResize(line.touchPoints, 0);

        if(ArraySize(lows) < lookback || lookback < 10)
        {
            CLogger::Error("CalculateLowerLine: Insufficient data");
            return false;
        }

        // Find valley points
        int valleys[];
        FindValleys(lows, lookback, valleys);

        if(ArraySize(valleys) < 2)
        {
            CLogger::Debug("CalculateLowerLine: Less than 2 valleys found");
            return false;
        }

        // Prepare data for linear regression
        double x[], y[];
        int valleyCount = ArraySize(valleys);
        ArrayResize(x, valleyCount);
        ArrayResize(y, valleyCount);

        for(int i = 0; i < valleyCount; i++)
        {
            x[i] = (double)valleys[i];      // Bar index
            y[i] = lows[valleys[i]];        // Low price at valley
        }

        // Calculate linear regression
        CMathUtils::LinearRegression(x, y, valleyCount, line.slope, line.intercept);

        // Validate trend line
        double atr = CalculateATR(symbol, timeframe, 14, 0);
        if(!ValidateTrendLine(line, lows, lookback, atr))
        {
            CLogger::Debug("CalculateLowerLine: Validation failed");
            return false;
        }

        // Set line properties
        line.startTime = iTime(symbol, timeframe, lookback - 1);
        line.endTime = iTime(symbol, timeframe, 0);
        line.startPrice = GetPriceAtBar(line, lookback - 1);
        line.endPrice = GetPriceAtBar(line, 0);
        line.isValid = true;

        CLogger::Debug(StringFormat(
            "Lower line: slope=%.7f, intercept=%.5f, touches=%d",
            line.slope, line.intercept, line.touchCount
        ));

        return true;
    }

    //+------------------------------------------------------------------+
    //| Get Price at Specific Bar (using line equation)                  |
    //+------------------------------------------------------------------+
    static double GetPriceAtBar(const STrendLine &line, const int bar)
    {
        // y = mx + b
        return line.slope * bar + line.intercept;
    }

    //+------------------------------------------------------------------+
    //| Validate Trend Line (minimum 2 touch points)                     |
    //+------------------------------------------------------------------+
    static bool ValidateTrendLine(
        STrendLine &line,
        const double &prices[],
        const int lookback,
        const double atr,
        const double threshold = 0.3
    )
    {
        ArrayResize(line.touchPoints, 0);
        line.touchCount = 0;

        double touchThreshold = atr * threshold;

        // Check how many prices touch the line
        for(int i = lookback - 1; i >= 0; i--)
        {
            double linePrice = GetPriceAtBar(line, i);
            double distance = MathAbs(prices[i] - linePrice);

            if(distance <= touchThreshold)
            {
                ArrayResize(line.touchPoints, line.touchCount + 1);
                line.touchPoints[line.touchCount] = i;
                line.touchCount++;
            }
        }

        // Minimum 2 touch points required
        return (line.touchCount >= 2);
    }

private:
    //+------------------------------------------------------------------+
    //| Find Peak Points (local maxima) in Price Data                    |
    //+------------------------------------------------------------------+
    static void FindPeaks(
        const double &highs[],
        const int lookback,
        int &peaks[]
    )
    {
        ArrayResize(peaks, 0);
        int peakCount = 0;

        // Scan for local maxima (peak is higher than neighbors)
        for(int i = lookback - 2; i >= 1; i--)
        {
            // Check if current bar is higher than both neighbors
            if(highs[i] > highs[i - 1] && highs[i] > highs[i + 1])
            {
                // Check if it's a significant peak (higher than 2 bars on each side)
                bool isSignificant = true;
                int lookAhead = MathMin(3, i);
                int lookBehind = MathMin(3, lookback - 1 - i);

                for(int j = 1; j <= lookAhead; j++)
                {
                    if(highs[i] <= highs[i - j])
                    {
                        isSignificant = false;
                        break;
                    }
                }

                if(isSignificant)
                {
                    for(int j = 1; j <= lookBehind; j++)
                    {
                        if(highs[i] <= highs[i + j])
                        {
                            isSignificant = false;
                            break;
                        }
                    }
                }

                if(isSignificant)
                {
                    ArrayResize(peaks, peakCount + 1);
                    peaks[peakCount] = i;
                    peakCount++;
                }
            }
        }

        // If less than 2 peaks found, use the 3 highest bars
        if(peakCount < 2)
        {
            ArrayResize(peaks, 0);
            peakCount = 0;

            // Find indices of highest values
            double sortedHighs[];
            ArrayResize(sortedHighs, lookback);
            ArrayCopy(sortedHighs, highs, 0, 0, lookback);

            // Find top 3 peaks
            for(int n = 0; n < MathMin(3, lookback); n++)
            {
                int maxIdx = CMathUtils::MaxIndex(sortedHighs, lookback);

                if(maxIdx >= 0)
                {
                    ArrayResize(peaks, peakCount + 1);
                    peaks[peakCount] = maxIdx;
                    peakCount++;

                    // Mark this value as used
                    sortedHighs[maxIdx] = -DBL_MAX;
                }
            }
        }
    }

    //+------------------------------------------------------------------+
    //| Find Valley Points (local minima) in Price Data                  |
    //+------------------------------------------------------------------+
    static void FindValleys(
        const double &lows[],
        const int lookback,
        int &valleys[]
    )
    {
        ArrayResize(valleys, 0);
        int valleyCount = 0;

        // Scan for local minima (valley is lower than neighbors)
        for(int i = lookback - 2; i >= 1; i--)
        {
            // Check if current bar is lower than both neighbors
            if(lows[i] < lows[i - 1] && lows[i] < lows[i + 1])
            {
                // Check if it's a significant valley (lower than 2 bars on each side)
                bool isSignificant = true;
                int lookAhead = MathMin(3, i);
                int lookBehind = MathMin(3, lookback - 1 - i);

                for(int j = 1; j <= lookAhead; j++)
                {
                    if(lows[i] >= lows[i - j])
                    {
                        isSignificant = false;
                        break;
                    }
                }

                if(isSignificant)
                {
                    for(int j = 1; j <= lookBehind; j++)
                    {
                        if(lows[i] >= lows[i + j])
                        {
                            isSignificant = false;
                            break;
                        }
                    }
                }

                if(isSignificant)
                {
                    ArrayResize(valleys, valleyCount + 1);
                    valleys[valleyCount] = i;
                    valleyCount++;
                }
            }
        }

        // If less than 2 valleys found, use the 3 lowest bars
        if(valleyCount < 2)
        {
            ArrayResize(valleys, 0);
            valleyCount = 0;

            // Find indices of lowest values
            double sortedLows[];
            ArrayResize(sortedLows, lookback);
            ArrayCopy(sortedLows, lows, 0, 0, lookback);

            // Find bottom 3 valleys
            for(int n = 0; n < MathMin(3, lookback); n++)
            {
                int minIdx = CMathUtils::MinIndex(sortedLows, lookback);

                if(minIdx >= 0)
                {
                    ArrayResize(valleys, valleyCount + 1);
                    valleys[valleyCount] = minIdx;
                    valleyCount++;

                    // Mark this value as used
                    sortedLows[minIdx] = DBL_MAX;
                }
            }
        }
    }

    //+------------------------------------------------------------------+
    //| Calculate ATR for Touch Validation                               |
    //+------------------------------------------------------------------+
    static double CalculateATR(
        string symbol,
        ENUM_TIMEFRAMES timeframe,
        int period,
        int shift
    )
    {
        // Simple ATR calculation without creating indicator handle
        double atr = 0.0;
        double alpha = 2.0 / (period + 1.0);

        for(int i = shift + period; i > shift; i--)
        {
            double high = iHigh(symbol, timeframe, i);
            double low = iLow(symbol, timeframe, i);
            double prevClose = iClose(symbol, timeframe, i + 1);

            double tr1 = high - low;
            double tr2 = MathAbs(high - prevClose);
            double tr3 = MathAbs(low - prevClose);
            double tr = MathMax(tr1, MathMax(tr2, tr3));

            if(i == shift + period)
                atr = tr;
            else
                atr = (alpha * tr) + ((1.0 - alpha) * atr);
        }

        return atr;
    }
};

//+------------------------------------------------------------------+
