//+------------------------------------------------------------------+
//|                                          DrawdownMonitor.mqh |
//|                                    BIONICLES Development Team    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "BIONICLES Development Team"
#property link      "https://bionicles.io"
#property version   "1.00"
#property strict

#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Drawdown Data Structure                                           |
//+------------------------------------------------------------------+
struct SDrawdownData
{
    double currentDrawdown;          // Current drawdown %
    double maxDrawdown;              // Maximum drawdown % ever
    double currentDrawdownUSD;       // Current drawdown in USD
    double maxDrawdownUSD;           // Maximum drawdown in USD
    double peakEquity;               // Peak equity achieved
    double currentEquity;            // Current equity
    double startingEquity;           // Starting equity
    datetime peakTime;               // Time of peak equity
    datetime maxDrawdownTime;        // Time of max drawdown
    bool isInDrawdown;               // Currently in drawdown
    double recoveryPercent;          // % recovered from max DD
    int daysInDrawdown;              // Days in current drawdown
};

//+------------------------------------------------------------------+
//| Drawdown Monitor Class                                            |
//+------------------------------------------------------------------+
class CDrawdownMonitor
{
private:
    static SDrawdownData m_data;
    static bool m_isInitialized;
    static double m_warningThreshold;    // % threshold for warning

public:
    //+------------------------------------------------------------------+
    //| Initialize Drawdown Monitor                                      |
    //+------------------------------------------------------------------+
    static bool Initialize(double warningThreshold = 8.0)
    {
        m_warningThreshold = warningThreshold;

        // Initialize data
        m_data.startingEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        m_data.currentEquity = m_data.startingEquity;
        m_data.peakEquity = m_data.startingEquity;
        m_data.currentDrawdown = 0.0;
        m_data.maxDrawdown = 0.0;
        m_data.currentDrawdownUSD = 0.0;
        m_data.maxDrawdownUSD = 0.0;
        m_data.peakTime = TimeCurrent();
        m_data.maxDrawdownTime = 0;
        m_data.isInDrawdown = false;
        m_data.recoveryPercent = 0.0;
        m_data.daysInDrawdown = 0;

        m_isInitialized = true;

        CLogger::Info(StringFormat(
            "Drawdown monitor initialized: Starting equity = $%.2f | Warning threshold = %.1f%%",
            m_data.startingEquity, m_warningThreshold
        ));

        return true;
    }

    //+------------------------------------------------------------------+
    //| Update Drawdown Metrics                                          |
    //+------------------------------------------------------------------+
    static void Update()
    {
        if(!m_isInitialized)
        {
            CLogger::Error("Drawdown monitor not initialized");
            return;
        }

        // Get current equity
        m_data.currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

        // Update peak equity
        if(m_data.currentEquity > m_data.peakEquity)
        {
            m_data.peakEquity = m_data.currentEquity;
            m_data.peakTime = TimeCurrent();

            // If we reached a new peak, we're out of drawdown
            if(m_data.isInDrawdown)
            {
                CLogger::Info(StringFormat(
                    "Drawdown recovered! New peak equity: $%.2f",
                    m_data.peakEquity
                ));

                m_data.isInDrawdown = false;
                m_data.daysInDrawdown = 0;
            }
        }

        // Calculate current drawdown
        if(m_data.peakEquity > 0.0)
        {
            m_data.currentDrawdownUSD = m_data.peakEquity - m_data.currentEquity;
            m_data.currentDrawdown = (m_data.currentDrawdownUSD / m_data.peakEquity) * 100.0;

            // Check if in drawdown
            if(m_data.currentDrawdown > 0.1) // More than 0.1%
            {
                if(!m_data.isInDrawdown)
                {
                    m_data.isInDrawdown = true;

                    CLogger::Warning(StringFormat(
                        "Entered drawdown: %.2f%% ($%.2f)",
                        m_data.currentDrawdown, m_data.currentDrawdownUSD
                    ));
                }

                // Calculate days in drawdown
                m_data.daysInDrawdown = (int)((TimeCurrent() - m_data.peakTime) / 86400);
            }
        }

        // Update maximum drawdown
        if(m_data.currentDrawdown > m_data.maxDrawdown)
        {
            m_data.maxDrawdown = m_data.currentDrawdown;
            m_data.maxDrawdownUSD = m_data.currentDrawdownUSD;
            m_data.maxDrawdownTime = TimeCurrent();

            CLogger::Warning(StringFormat(
                "New maximum drawdown: %.2f%% ($%.2f)",
                m_data.maxDrawdown, m_data.maxDrawdownUSD
            ));

            // Check if warning threshold exceeded
            if(m_data.maxDrawdown >= m_warningThreshold)
            {
                Alert(StringFormat(
                    "[BIONICLES] Drawdown WARNING: %.2f%% (Threshold: %.1f%%)",
                    m_data.maxDrawdown, m_warningThreshold
                ));
            }
        }

        // Calculate recovery percentage
        if(m_data.maxDrawdown > 0.0)
        {
            m_data.recoveryPercent = ((m_data.maxDrawdown - m_data.currentDrawdown) /
                                     m_data.maxDrawdown) * 100.0;
        }
    }

    //+------------------------------------------------------------------+
    //| Get Drawdown Data                                                |
    //+------------------------------------------------------------------+
    static void GetData(SDrawdownData &data)
    {
        data = m_data;
    }

    //+------------------------------------------------------------------+
    //| Get Current Drawdown Percentage                                  |
    //+------------------------------------------------------------------+
    static double GetCurrentDrawdown()
    {
        return m_data.currentDrawdown;
    }

    //+------------------------------------------------------------------+
    //| Get Maximum Drawdown Percentage                                  |
    //+------------------------------------------------------------------+
    static double GetMaxDrawdown()
    {
        return m_data.maxDrawdown;
    }

    //+------------------------------------------------------------------+
    //| Is Currently in Drawdown                                         |
    //+------------------------------------------------------------------+
    static bool IsInDrawdown()
    {
        return m_data.isInDrawdown;
    }

    //+------------------------------------------------------------------+
    //| Get Days in Current Drawdown                                     |
    //+------------------------------------------------------------------+
    static int GetDaysInDrawdown()
    {
        return m_data.daysInDrawdown;
    }

    //+------------------------------------------------------------------+
    //| Calculate Recovery Factor                                         |
    //| Recovery Factor = Net Profit / Max Drawdown                      |
    //+------------------------------------------------------------------+
    static double CalculateRecoveryFactor()
    {
        double netProfit = m_data.currentEquity - m_data.startingEquity;

        if(m_data.maxDrawdownUSD > 0.0)
        {
            return netProfit / m_data.maxDrawdownUSD;
        }

        return 0.0;
    }

    //+------------------------------------------------------------------+
    //| Log Drawdown Summary                                             |
    //+------------------------------------------------------------------+
    static void LogSummary()
    {
        string summary = "\n=== Drawdown Summary ===\n";
        summary += StringFormat("Current Equity: $%.2f\n", m_data.currentEquity);
        summary += StringFormat("Peak Equity: $%.2f (on %s)\n",
                               m_data.peakEquity,
                               TimeToString(m_data.peakTime, TIME_DATE));
        summary += StringFormat("Current Drawdown: %.2f%% ($%.2f)\n",
                               m_data.currentDrawdown, m_data.currentDrawdownUSD);
        summary += StringFormat("Maximum Drawdown: %.2f%% ($%.2f) (on %s)\n",
                               m_data.maxDrawdown, m_data.maxDrawdownUSD,
                               m_data.maxDrawdownTime > 0 ?
                               TimeToString(m_data.maxDrawdownTime, TIME_DATE) : "N/A");
        summary += StringFormat("In Drawdown: %s", m_data.isInDrawdown ? "Yes" : "No");

        if(m_data.isInDrawdown)
        {
            summary += StringFormat(" (for %d days)", m_data.daysInDrawdown);
        }

        summary += "\n";
        summary += StringFormat("Recovery Factor: %.2f\n", CalculateRecoveryFactor());
        summary += "=======================\n";

        CLogger::Info(summary);
    }

    //+------------------------------------------------------------------+
    //| Reset Peak Equity (Admin Override)                               |
    //+------------------------------------------------------------------+
    static void ResetPeak()
    {
        m_data.peakEquity = m_data.currentEquity;
        m_data.peakTime = TimeCurrent();
        m_data.isInDrawdown = false;
        m_data.daysInDrawdown = 0;

        CLogger::Warning("Peak equity manually reset");
    }
};

// Static member initialization
SDrawdownData CDrawdownMonitor::m_data;
bool CDrawdownMonitor::m_isInitialized = false;
double CDrawdownMonitor::m_warningThreshold = 8.0;

//+------------------------------------------------------------------+
