//+------------------------------------------------------------------+
//|                                           CircuitBreakers.mqh |
//|                                    BIONICLES Development Team    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "BIONICLES Development Team"
#property link      "https://bionicles.io"
#property version   "1.00"
#property strict

#include "../Execution/OrderManager.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Circuit Breaker Status                                            |
//+------------------------------------------------------------------+
enum ENUM_BREAKER_STATUS
{
    BREAKER_NORMAL,           // Trading allowed
    BREAKER_TRIGGERED,        // Circuit breaker triggered
    BREAKER_HALTED            // Trading halted
};

//+------------------------------------------------------------------+
//| Circuit Breaker Data                                              |
//+------------------------------------------------------------------+
struct SCircuitBreakerData
{
    ENUM_BREAKER_STATUS status;       // Current status
    datetime haltStartTime;            // When halt started
    datetime haltEndTime;              // When halt ends
    double startingBalance;            // Balance at EA start
    double currentBalance;             // Current balance
    double peakBalance;                // Peak balance achieved
    double currentDrawdown;            // Current drawdown %
    double dailyDrawdown;              // Daily drawdown %
    int consecutiveLosses;             // Current consecutive losses
    int totalLosses;                   // Total losses today
    datetime lastResetTime;            // Last daily reset time
    string triggerReason;              // Reason for circuit breaker
};

//+------------------------------------------------------------------+
//| Circuit Breaker Class                                             |
//+------------------------------------------------------------------+
class CCircuitBreakers
{
private:
    static SCircuitBreakerData m_data;
    static double m_dailyStartBalance;
    static double m_maxDailyDrawdown;
    static double m_maxEquityDrop;
    static int m_maxConsecutiveLosses;
    static int m_haltDurationHours;
    static bool m_isInitialized;

public:
    //+------------------------------------------------------------------+
    //| Initialize Circuit Breakers                                      |
    //+------------------------------------------------------------------+
    static bool Initialize(
        double maxDailyDrawdown = 10.0,      // % daily max loss
        double maxEquityDrop = 20.0,         // % equity drop from peak
        int maxConsecutiveLosses = 5,        // Max consecutive losses
        int haltDurationHours = 24           // Hours to halt trading
    )
    {
        m_maxDailyDrawdown = maxDailyDrawdown;
        m_maxEquityDrop = maxEquityDrop;
        m_maxConsecutiveLosses = maxConsecutiveLosses;
        m_haltDurationHours = haltDurationHours;

        // Initialize data
        m_data.status = BREAKER_NORMAL;
        m_data.startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        m_data.currentBalance = m_data.startingBalance;
        m_data.peakBalance = m_data.startingBalance;
        m_data.currentDrawdown = 0.0;
        m_data.dailyDrawdown = 0.0;
        m_data.consecutiveLosses = 0;
        m_data.totalLosses = 0;
        m_data.lastResetTime = TimeCurrent();
        m_data.triggerReason = "";

        m_dailyStartBalance = m_data.startingBalance;

        m_isInitialized = true;

        CLogger::Info(StringFormat(
            "Circuit breakers initialized: MaxDailyDD=%.1f%%, MaxEquityDrop=%.1f%%, MaxConsecLosses=%d",
            m_maxDailyDrawdown, m_maxEquityDrop, m_maxConsecutiveLosses
        ));

        return true;
    }

    //+------------------------------------------------------------------+
    //| Check All Circuit Breakers                                       |
    //+------------------------------------------------------------------+
    static bool CheckBreakers()
    {
        if(!m_isInitialized)
        {
            CLogger::Error("Circuit breakers not initialized");
            return false;
        }

        // Update current state
        UpdateState();

        // If already halted, check if halt period is over
        if(m_data.status == BREAKER_HALTED)
        {
            if(TimeCurrent() >= m_data.haltEndTime)
            {
                ResumeTrading();
            }
            else
            {
                return false; // Still halted
            }
        }

        // Check daily reset
        CheckDailyReset();

        // Check all breaker conditions
        if(CheckDailyDrawdown())
            return false;

        if(CheckEquityDrop())
            return false;

        if(CheckConsecutiveLosses())
            return false;

        return true; // All checks passed
    }

    //+------------------------------------------------------------------+
    //| Record Trade Result                                              |
    //+------------------------------------------------------------------+
    static void RecordTradeResult(bool isWin, double profitLoss)
    {
        if(isWin)
        {
            // Reset consecutive losses on win
            m_data.consecutiveLosses = 0;

            CLogger::Debug(StringFormat(
                "Win recorded: $%.2f | Consecutive losses reset to 0",
                profitLoss
            ));
        }
        else
        {
            // Increment consecutive losses
            m_data.consecutiveLosses++;
            m_data.totalLosses++;

            CLogger::Warning(StringFormat(
                "Loss recorded: $%.2f | Consecutive losses: %d",
                profitLoss, m_data.consecutiveLosses
            ));
        }

        UpdateState();
    }

    //+------------------------------------------------------------------+
    //| Trigger Emergency Stop                                           |
    //+------------------------------------------------------------------+
    static void TriggerEmergencyStop(string reason)
    {
        m_data.status = BREAKER_TRIGGERED;
        m_data.triggerReason = reason;

        CLogger::Critical(StringFormat(
            "EMERGENCY STOP TRIGGERED: %s", reason
        ));

        // Close all positions immediately
        int closedCount = COrderManager::CloseAllPositions(NULL, "Emergency stop: " + reason);

        CLogger::Critical(StringFormat(
            "Emergency stop closed %d positions", closedCount
        ));

        // Halt trading
        HaltTrading(reason);

        // Send alerts
        SendAlert("EMERGENCY STOP", reason);
    }

    //+------------------------------------------------------------------+
    //| Get Current Status                                               |
    //+------------------------------------------------------------------+
    static ENUM_BREAKER_STATUS GetStatus()
    {
        return m_data.status;
    }

    //+------------------------------------------------------------------+
    //| Is Trading Allowed                                               |
    //+------------------------------------------------------------------+
    static bool IsTradingAllowed()
    {
        return (m_data.status == BREAKER_NORMAL);
    }

    //+------------------------------------------------------------------+
    //| Get Circuit Breaker Data                                         |
    //+------------------------------------------------------------------+
    static void GetData(SCircuitBreakerData &data)
    {
        data = m_data;
    }

    //+------------------------------------------------------------------+
    //| Reset Circuit Breakers (Admin Override)                          |
    //+------------------------------------------------------------------+
    static void ResetBreakers()
    {
        m_data.status = BREAKER_NORMAL;
        m_data.consecutiveLosses = 0;
        m_data.triggerReason = "";

        CLogger::Warning("Circuit breakers manually reset");
    }

private:
    //+------------------------------------------------------------------+
    //| Update Current State                                             |
    //+------------------------------------------------------------------+
    static void UpdateState()
    {
        m_data.currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);

        // Update peak balance
        if(m_data.currentBalance > m_data.peakBalance)
            m_data.peakBalance = m_data.currentBalance;

        // Calculate current drawdown from peak
        if(m_data.peakBalance > 0.0)
        {
            m_data.currentDrawdown = ((m_data.peakBalance - m_data.currentBalance) /
                                     m_data.peakBalance) * 100.0;
        }

        // Calculate daily drawdown
        if(m_dailyStartBalance > 0.0)
        {
            m_data.dailyDrawdown = ((m_dailyStartBalance - m_data.currentBalance) /
                                   m_dailyStartBalance) * 100.0;
        }
    }

    //+------------------------------------------------------------------+
    //| Check Daily Drawdown Limit                                       |
    //+------------------------------------------------------------------+
    static bool CheckDailyDrawdown()
    {
        if(m_data.dailyDrawdown >= m_maxDailyDrawdown)
        {
            string reason = StringFormat(
                "Daily drawdown limit exceeded: %.2f%% (max: %.2f%%)",
                m_data.dailyDrawdown, m_maxDailyDrawdown
            );

            TriggerEmergencyStop(reason);
            return true;
        }

        return false;
    }

    //+------------------------------------------------------------------+
    //| Check Equity Drop from Starting Balance                          |
    //+------------------------------------------------------------------+
    static bool CheckEquityDrop()
    {
        if(m_data.startingBalance <= 0.0)
            return false;

        double equityDropPercent = ((m_data.startingBalance - m_data.currentBalance) /
                                   m_data.startingBalance) * 100.0;

        if(equityDropPercent >= m_maxEquityDrop)
        {
            string reason = StringFormat(
                "Equity drop exceeded: %.2f%% (max: %.2f%%)",
                equityDropPercent, m_maxEquityDrop
            );

            TriggerEmergencyStop(reason);
            return true;
        }

        return false;
    }

    //+------------------------------------------------------------------+
    //| Check Consecutive Losses                                         |
    //+------------------------------------------------------------------+
    static bool CheckConsecutiveLosses()
    {
        if(m_data.consecutiveLosses >= m_maxConsecutiveLosses)
        {
            string reason = StringFormat(
                "Maximum consecutive losses reached: %d (max: %d)",
                m_data.consecutiveLosses, m_maxConsecutiveLosses
            );

            TriggerEmergencyStop(reason);
            return true;
        }

        return false;
    }

    //+------------------------------------------------------------------+
    //| Halt Trading for Specified Duration                              |
    //+------------------------------------------------------------------+
    static void HaltTrading(string reason)
    {
        m_data.status = BREAKER_HALTED;
        m_data.haltStartTime = TimeCurrent();
        m_data.haltEndTime = m_data.haltStartTime + (m_haltDurationHours * 3600);

        CLogger::Critical(StringFormat(
            "Trading HALTED for %d hours: %s | Resume at: %s",
            m_haltDurationHours, reason,
            TimeToString(m_data.haltEndTime, TIME_DATE | TIME_SECONDS)
        ));

        SendAlert("TRADING HALTED", reason);
    }

    //+------------------------------------------------------------------+
    //| Resume Trading After Halt                                        |
    //+------------------------------------------------------------------+
    static void ResumeTrading()
    {
        m_data.status = BREAKER_NORMAL;
        m_data.consecutiveLosses = 0; // Reset consecutive losses after halt

        CLogger::Info("Trading RESUMED after halt period");

        SendAlert("TRADING RESUMED", "Halt period ended");
    }

    //+------------------------------------------------------------------+
    //| Check if Daily Reset is Needed                                   |
    //+------------------------------------------------------------------+
    static void CheckDailyReset()
    {
        MqlDateTime now, last;

        TimeToStruct(TimeCurrent(), now);
        TimeToStruct(m_data.lastResetTime, last);

        // Reset at midnight
        if(now.day != last.day)
        {
            m_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
            m_data.totalLosses = 0;
            m_data.lastResetTime = TimeCurrent();

            CLogger::Info(StringFormat(
                "Daily reset: Start balance = $%.2f",
                m_dailyStartBalance
            ));
        }
    }

    //+------------------------------------------------------------------+
    //| Send Alert (Email/SMS/Terminal)                                  |
    //+------------------------------------------------------------------+
    static void SendAlert(string subject, string message)
    {
        // Terminal alert
        Alert(StringFormat("[BIONICLES] %s: %s", subject, message));

        // Log
        CLogger::Critical(StringFormat("%s: %s", subject, message));

        // Email (if configured)
        // SendMail(subject, message);

        // Push notification (if available)
        // SendNotification(subject + ": " + message);
    }
};

// Static member initialization
SCircuitBreakerData CCircuitBreakers::m_data;
double CCircuitBreakers::m_dailyStartBalance = 0.0;
double CCircuitBreakers::m_maxDailyDrawdown = 10.0;
double CCircuitBreakers::m_maxEquityDrop = 20.0;
int CCircuitBreakers::m_maxConsecutiveLosses = 5;
int CCircuitBreakers::m_haltDurationHours = 24;
bool CCircuitBreakers::m_isInitialized = false;

//+------------------------------------------------------------------+
