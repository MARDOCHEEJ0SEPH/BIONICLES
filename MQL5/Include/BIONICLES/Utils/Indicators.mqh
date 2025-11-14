//+------------------------------------------------------------------+
//|                                                   Indicators.mqh |
//|                                    BIONICLES Development Team    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "BIONICLES Development Team"
#property link      "https://bionicles.io"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Technical Indicator Wrapper Class                                |
//+------------------------------------------------------------------+
class CIndicators
{
private:
    static int m_atrHandle;
    static int m_rsiHandle;

public:
    //+------------------------------------------------------------------+
    //| Initialize Indicators                                            |
    //+------------------------------------------------------------------+
    static bool Initialize(string symbol, ENUM_TIMEFRAMES timeframe)
    {
        // Create ATR indicator handle
        m_atrHandle = iATR(symbol, timeframe, 14);
        if(m_atrHandle == INVALID_HANDLE)
        {
            Print("Failed to create ATR indicator handle. Error: ", GetLastError());
            return false;
        }

        // Create RSI indicator handle
        m_rsiHandle = iRSI(symbol, timeframe, 14, PRICE_CLOSE);
        if(m_rsiHandle == INVALID_HANDLE)
        {
            Print("Failed to create RSI indicator handle. Error: ", GetLastError());
            IndicatorRelease(m_atrHandle);
            return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Release Indicator Handles                                        |
    //+------------------------------------------------------------------+
    static void Deinitialize()
    {
        if(m_atrHandle != INVALID_HANDLE)
            IndicatorRelease(m_atrHandle);

        if(m_rsiHandle != INVALID_HANDLE)
            IndicatorRelease(m_rsiHandle);

        m_atrHandle = INVALID_HANDLE;
        m_rsiHandle = INVALID_HANDLE;
    }

    //+------------------------------------------------------------------+
    //| Get ATR Value                                                    |
    //+------------------------------------------------------------------+
    static double GetATR(
        string symbol,
        ENUM_TIMEFRAMES timeframe,
        int period,
        int shift = 0
    )
    {
        // Use cached handle if available
        int handle = m_atrHandle;

        // Create temporary handle if not initialized
        if(handle == INVALID_HANDLE)
        {
            handle = iATR(symbol, timeframe, period);
            if(handle == INVALID_HANDLE)
            {
                Print("Failed to create ATR handle. Error: ", GetLastError());
                return 0.0;
            }
        }

        double atrBuffer[];
        ArraySetAsSeries(atrBuffer, true);

        if(CopyBuffer(handle, 0, shift, 1, atrBuffer) <= 0)
        {
            Print("Failed to copy ATR buffer. Error: ", GetLastError());
            if(handle != m_atrHandle)
                IndicatorRelease(handle);
            return 0.0;
        }

        double value = atrBuffer[0];

        // Release temporary handle
        if(handle != m_atrHandle)
            IndicatorRelease(handle);

        return NormalizeDouble(value, _Digits);
    }

    //+------------------------------------------------------------------+
    //| Get RSI Value                                                    |
    //+------------------------------------------------------------------+
    static double GetRSI(
        string symbol,
        ENUM_TIMEFRAMES timeframe,
        int period,
        int shift = 0
    )
    {
        // Use cached handle if available
        int handle = m_rsiHandle;

        // Create temporary handle if not initialized
        if(handle == INVALID_HANDLE)
        {
            handle = iRSI(symbol, timeframe, period, PRICE_CLOSE);
            if(handle == INVALID_HANDLE)
            {
                Print("Failed to create RSI handle. Error: ", GetLastError());
                return 50.0; // Neutral RSI
            }
        }

        double rsiBuffer[];
        ArraySetAsSeries(rsiBuffer, true);

        if(CopyBuffer(handle, 0, shift, 1, rsiBuffer) <= 0)
        {
            Print("Failed to copy RSI buffer. Error: ", GetLastError());
            if(handle != m_rsiHandle)
                IndicatorRelease(handle);
            return 50.0; // Neutral RSI
        }

        double value = rsiBuffer[0];

        // Release temporary handle
        if(handle != m_rsiHandle)
            IndicatorRelease(handle);

        return NormalizeDouble(value, 2);
    }

    //+------------------------------------------------------------------+
    //| Calculate True Range                                             |
    //+------------------------------------------------------------------+
    static double GetTrueRange(
        string symbol,
        ENUM_TIMEFRAMES timeframe,
        int shift = 0
    )
    {
        double high = iHigh(symbol, timeframe, shift);
        double low = iLow(symbol, timeframe, shift);
        double prevClose = iClose(symbol, timeframe, shift + 1);

        double tr1 = high - low;
        double tr2 = MathAbs(high - prevClose);
        double tr3 = MathAbs(low - prevClose);

        double trueRange = MathMax(tr1, MathMax(tr2, tr3));

        return NormalizeDouble(trueRange, _Digits);
    }

    //+------------------------------------------------------------------+
    //| Calculate Manual ATR (without indicator handle)                  |
    //+------------------------------------------------------------------+
    static double CalculateATR(
        string symbol,
        ENUM_TIMEFRAMES timeframe,
        int period,
        int shift = 0
    )
    {
        if(period <= 0) return 0.0;

        double atr = 0.0;
        double alpha = 2.0 / (period + 1.0);

        // Calculate initial ATR (simple average of first period TRs)
        for(int i = shift + period - 1; i >= shift; i--)
        {
            double tr = GetTrueRange(symbol, timeframe, i);

            if(i == shift + period - 1)
            {
                atr = tr; // First value
            }
            else
            {
                // Exponential moving average
                atr = (alpha * tr) + ((1.0 - alpha) * atr);
            }
        }

        return NormalizeDouble(atr, _Digits);
    }

    //+------------------------------------------------------------------+
    //| Calculate Manual RSI                                             |
    //+------------------------------------------------------------------+
    static double CalculateRSI(
        string symbol,
        ENUM_TIMEFRAMES timeframe,
        int period,
        int shift = 0
    )
    {
        if(period <= 0) return 50.0;

        double avgGain = 0.0;
        double avgLoss = 0.0;

        // Calculate initial averages
        for(int i = shift + period; i > shift; i--)
        {
            double change = iClose(symbol, timeframe, i - 1) - iClose(symbol, timeframe, i);

            if(change > 0)
                avgGain += change;
            else
                avgLoss += MathAbs(change);
        }

        avgGain /= period;
        avgLoss /= period;

        // Calculate RSI
        if(avgLoss == 0.0)
            return 100.0;

        double rs = avgGain / avgLoss;
        double rsi = 100.0 - (100.0 / (1.0 + rs));

        return NormalizeDouble(rsi, 2);
    }

    //+------------------------------------------------------------------+
    //| Get Moving Average                                               |
    //+------------------------------------------------------------------+
    static double GetMA(
        string symbol,
        ENUM_TIMEFRAMES timeframe,
        int period,
        int shift = 0,
        ENUM_MA_METHOD method = MODE_SMA,
        ENUM_APPLIED_PRICE price = PRICE_CLOSE
    )
    {
        int handle = iMA(symbol, timeframe, period, 0, method, price);
        if(handle == INVALID_HANDLE)
        {
            Print("Failed to create MA handle. Error: ", GetLastError());
            return 0.0;
        }

        double maBuffer[];
        ArraySetAsSeries(maBuffer, true);

        if(CopyBuffer(handle, 0, shift, 1, maBuffer) <= 0)
        {
            Print("Failed to copy MA buffer. Error: ", GetLastError());
            IndicatorRelease(handle);
            return 0.0;
        }

        double value = maBuffer[0];
        IndicatorRelease(handle);

        return NormalizeDouble(value, _Digits);
    }

    //+------------------------------------------------------------------+
    //| Check if Price is Oversold (RSI < threshold)                     |
    //+------------------------------------------------------------------+
    static bool IsOversold(
        string symbol,
        ENUM_TIMEFRAMES timeframe,
        int period,
        double threshold = 30.0,
        int shift = 0
    )
    {
        double rsi = GetRSI(symbol, timeframe, period, shift);
        return (rsi < threshold);
    }

    //+------------------------------------------------------------------+
    //| Check if Price is Overbought (RSI > threshold)                   |
    //+------------------------------------------------------------------+
    static bool IsOverbought(
        string symbol,
        ENUM_TIMEFRAMES timeframe,
        int period,
        double threshold = 70.0,
        int shift = 0
    )
    {
        double rsi = GetRSI(symbol, timeframe, period, shift);
        return (rsi > threshold);
    }

    //+------------------------------------------------------------------+
    //| Get Bollinger Bands Values                                       |
    //+------------------------------------------------------------------+
    static bool GetBollingerBands(
        string symbol,
        ENUM_TIMEFRAMES timeframe,
        int period,
        double deviation,
        double &upper,
        double &middle,
        double &lower,
        int shift = 0
    )
    {
        int handle = iBands(symbol, timeframe, period, 0, deviation, PRICE_CLOSE);
        if(handle == INVALID_HANDLE)
        {
            Print("Failed to create Bollinger Bands handle. Error: ", GetLastError());
            return false;
        }

        double upperBuffer[], middleBuffer[], lowerBuffer[];
        ArraySetAsSeries(upperBuffer, true);
        ArraySetAsSeries(middleBuffer, true);
        ArraySetAsSeries(lowerBuffer, true);

        if(CopyBuffer(handle, 0, shift, 1, upperBuffer) <= 0 ||
           CopyBuffer(handle, 1, shift, 1, middleBuffer) <= 0 ||
           CopyBuffer(handle, 2, shift, 1, lowerBuffer) <= 0)
        {
            Print("Failed to copy Bollinger Bands buffers. Error: ", GetLastError());
            IndicatorRelease(handle);
            return false;
        }

        upper = NormalizeDouble(upperBuffer[0], _Digits);
        middle = NormalizeDouble(middleBuffer[0], _Digits);
        lower = NormalizeDouble(lowerBuffer[0], _Digits);

        IndicatorRelease(handle);
        return true;
    }
};

// Static member initialization
int CIndicators::m_atrHandle = INVALID_HANDLE;
int CIndicators::m_rsiHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
