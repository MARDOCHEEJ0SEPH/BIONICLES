//+------------------------------------------------------------------+
//|                                                    MathUtils.mqh |
//|                                    BIONICLES Development Team    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "BIONICLES Development Team"
#property link      "https://bionicles.io"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Mathematical Utility Functions                                    |
//+------------------------------------------------------------------+
class CMathUtils
{
public:
    //+------------------------------------------------------------------+
    //| Linear Regression Calculation                                    |
    //| Calculates slope (m) and intercept (b) for y = mx + b           |
    //+------------------------------------------------------------------+
    static void LinearRegression(
        const double &x[],          // X values (bar indices)
        const double &y[],          // Y values (prices)
        const int count,            // Number of points
        double &slope,              // Output: slope
        double &intercept           // Output: y-intercept
    )
    {
        if(count < 2)
        {
            slope = 0.0;
            intercept = 0.0;
            return;
        }

        double sumX = 0.0, sumY = 0.0;
        double sumXY = 0.0, sumX2 = 0.0;

        // Calculate sums
        for(int i = 0; i < count; i++)
        {
            sumX += x[i];
            sumY += y[i];
            sumXY += x[i] * y[i];
            sumX2 += x[i] * x[i];
        }

        double n = (double)count;
        double denominator = (n * sumX2) - (sumX * sumX);

        if(MathAbs(denominator) > 0.000001)
        {
            slope = ((n * sumXY) - (sumX * sumY)) / denominator;
            intercept = (sumY - (slope * sumX)) / n;
        }
        else
        {
            slope = 0.0;
            intercept = sumY / n; // Average Y value
        }
    }

    //+------------------------------------------------------------------+
    //| Calculate Mean (Average)                                         |
    //+------------------------------------------------------------------+
    static double Mean(const double &data[], const int count = WHOLE_ARRAY)
    {
        int size = (count == WHOLE_ARRAY) ? ArraySize(data) : count;
        if(size == 0) return 0.0;

        double sum = 0.0;
        for(int i = 0; i < size; i++)
            sum += data[i];

        return sum / size;
    }

    //+------------------------------------------------------------------+
    //| Calculate Standard Deviation                                     |
    //+------------------------------------------------------------------+
    static double StandardDeviation(const double &data[], const int count = WHOLE_ARRAY)
    {
        int size = (count == WHOLE_ARRAY) ? ArraySize(data) : count;
        if(size < 2) return 0.0;

        double mean = Mean(data, size);
        double sumSquaredDiff = 0.0;

        for(int i = 0; i < size; i++)
        {
            double diff = data[i] - mean;
            sumSquaredDiff += diff * diff;
        }

        return MathSqrt(sumSquaredDiff / (size - 1));
    }

    //+------------------------------------------------------------------+
    //| Find Maximum Value in Array                                      |
    //+------------------------------------------------------------------+
    static double Max(const double &data[], const int count = WHOLE_ARRAY)
    {
        int size = (count == WHOLE_ARRAY) ? ArraySize(data) : count;
        if(size == 0) return 0.0;

        double maxVal = data[0];
        for(int i = 1; i < size; i++)
        {
            if(data[i] > maxVal)
                maxVal = data[i];
        }
        return maxVal;
    }

    //+------------------------------------------------------------------+
    //| Find Minimum Value in Array                                      |
    //+------------------------------------------------------------------+
    static double Min(const double &data[], const int count = WHOLE_ARRAY)
    {
        int size = (count == WHOLE_ARRAY) ? ArraySize(data) : count;
        if(size == 0) return 0.0;

        double minVal = data[0];
        for(int i = 1; i < size; i++)
        {
            if(data[i] < minVal)
                minVal = data[i];
        }
        return minVal;
    }

    //+------------------------------------------------------------------+
    //| Find Index of Maximum Value                                      |
    //+------------------------------------------------------------------+
    static int MaxIndex(const double &data[], const int count = WHOLE_ARRAY)
    {
        int size = (count == WHOLE_ARRAY) ? ArraySize(data) : count;
        if(size == 0) return -1;

        int maxIdx = 0;
        double maxVal = data[0];

        for(int i = 1; i < size; i++)
        {
            if(data[i] > maxVal)
            {
                maxVal = data[i];
                maxIdx = i;
            }
        }
        return maxIdx;
    }

    //+------------------------------------------------------------------+
    //| Find Index of Minimum Value                                      |
    //+------------------------------------------------------------------+
    static int MinIndex(const double &data[], const int count = WHOLE_ARRAY)
    {
        int size = (count == WHOLE_ARRAY) ? ArraySize(data) : count;
        if(size == 0) return -1;

        int minIdx = 0;
        double minVal = data[0];

        for(int i = 1; i < size; i++)
        {
            if(data[i] < minVal)
            {
                minVal = data[i];
                minIdx = i;
            }
        }
        return minIdx;
    }

    //+------------------------------------------------------------------+
    //| Normalize Value to Range [0, 1]                                  |
    //+------------------------------------------------------------------+
    static double Normalize(double value, double min, double max)
    {
        if(max - min == 0.0) return 0.0;
        return (value - min) / (max - min);
    }

    //+------------------------------------------------------------------+
    //| Convert Pips to Price (account for 3/5 digit brokers)           |
    //+------------------------------------------------------------------+
    static double PipsToPrice(double pips, string symbol = NULL)
    {
        if(symbol == NULL) symbol = _Symbol;

        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

        // Account for 3/5 digit brokers
        double pipSize = (digits == 3 || digits == 5) ? point * 10 : point;

        return pips * pipSize;
    }

    //+------------------------------------------------------------------+
    //| Convert Price to Pips                                            |
    //+------------------------------------------------------------------+
    static double PriceToPips(double price, string symbol = NULL)
    {
        if(symbol == NULL) symbol = _Symbol;

        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

        // Account for 3/5 digit brokers
        double pipSize = (digits == 3 || digits == 5) ? point * 10 : point;

        return price / pipSize;
    }

    //+------------------------------------------------------------------+
    //| Calculate Distance Between Two Prices in Pips                    |
    //+------------------------------------------------------------------+
    static double DistanceInPips(double price1, double price2, string symbol = NULL)
    {
        return PriceToPips(MathAbs(price1 - price2), symbol);
    }

    //+------------------------------------------------------------------+
    //| Clamp Value Between Min and Max                                  |
    //+------------------------------------------------------------------+
    static double Clamp(double value, double min, double max)
    {
        if(value < min) return min;
        if(value > max) return max;
        return value;
    }

    //+------------------------------------------------------------------+
    //| Check if Value is Between Min and Max (inclusive)                |
    //+------------------------------------------------------------------+
    static bool IsBetween(double value, double min, double max)
    {
        return (value >= min && value <= max);
    }

    //+------------------------------------------------------------------+
    //| Round to Nearest Step Size                                       |
    //+------------------------------------------------------------------+
    static double RoundToStep(double value, double step)
    {
        if(step <= 0.0) return value;
        return MathRound(value / step) * step;
    }

    //+------------------------------------------------------------------+
    //| Calculate Percentage Change                                      |
    //+------------------------------------------------------------------+
    static double PercentChange(double oldValue, double newValue)
    {
        if(oldValue == 0.0) return 0.0;
        return ((newValue - oldValue) / oldValue) * 100.0;
    }

    //+------------------------------------------------------------------+
    //| Safe Division (returns 0 if denominator is 0)                    |
    //+------------------------------------------------------------------+
    static double SafeDivide(double numerator, double denominator, double defaultValue = 0.0)
    {
        if(MathAbs(denominator) < 0.000001)
            return defaultValue;
        return numerator / denominator;
    }

    //+------------------------------------------------------------------+
    //| Exponential Moving Average                                        |
    //+------------------------------------------------------------------+
    static double EMA(double currentValue, double previousEMA, int period)
    {
        if(period <= 0) return currentValue;

        double alpha = 2.0 / (period + 1.0);
        return (alpha * currentValue) + ((1.0 - alpha) * previousEMA);
    }
};

//+------------------------------------------------------------------+
