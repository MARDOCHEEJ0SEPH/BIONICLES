//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                    BIONICLES Development Team    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "BIONICLES Development Team"
#property link      "https://bionicles.io"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Log Levels                                                        |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
{
    LOG_LEVEL_DEBUG,      // Detailed diagnostic information
    LOG_LEVEL_INFO,       // General informational messages
    LOG_LEVEL_WARNING,    // Warning messages
    LOG_LEVEL_ERROR,      // Error messages
    LOG_LEVEL_CRITICAL    // Critical error messages
};

//+------------------------------------------------------------------+
//| Logging System Class                                              |
//+------------------------------------------------------------------+
class CLogger
{
private:
    static int m_fileHandle;
    static string m_filename;
    static ENUM_LOG_LEVEL m_minLevel;
    static bool m_logToFile;
    static bool m_logToTerminal;
    static bool m_includeTimestamp;

public:
    //+------------------------------------------------------------------+
    //| Initialize Logger                                                |
    //+------------------------------------------------------------------+
    static bool Initialize(
        string filename = "BIONICLES_log.txt",
        ENUM_LOG_LEVEL minLevel = LOG_LEVEL_INFO,
        bool logToFile = true,
        bool logToTerminal = true
    )
    {
        m_filename = filename;
        m_minLevel = minLevel;
        m_logToFile = logToFile;
        m_logToTerminal = logToTerminal;
        m_includeTimestamp = true;

        if(m_logToFile)
        {
            // Create log file in MQL5/Files directory
            m_fileHandle = FileOpen("BIONICLES/" + m_filename,
                                    FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);

            if(m_fileHandle == INVALID_HANDLE)
            {
                Print("Failed to create log file: ", m_filename, ". Error: ", GetLastError());
                m_logToFile = false;
                return false;
            }

            // Write header
            string header = "=".Substring(0, 70) + "\n";
            header += "BIONICLES Trading System Log\n";
            header += "Started: " + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + "\n";
            header += "=".Substring(0, 70) + "\n\n";

            FileWriteString(m_fileHandle, header);
            FileFlush(m_fileHandle);
        }

        Info("Logger initialized successfully");
        return true;
    }

    //+------------------------------------------------------------------+
    //| Deinitialize Logger                                              |
    //+------------------------------------------------------------------+
    static void Deinitialize()
    {
        if(m_fileHandle != INVALID_HANDLE)
        {
            string footer = "\n" + "=".Substring(0, 70) + "\n";
            footer += "Log Ended: " + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + "\n";
            footer += "=".Substring(0, 70) + "\n";

            FileWriteString(m_fileHandle, footer);
            FileClose(m_fileHandle);
            m_fileHandle = INVALID_HANDLE;
        }
    }

    //+------------------------------------------------------------------+
    //| Debug Level Log                                                  |
    //+------------------------------------------------------------------+
    static void Debug(string message)
    {
        Log(LOG_LEVEL_DEBUG, message);
    }

    //+------------------------------------------------------------------+
    //| Info Level Log                                                   |
    //+------------------------------------------------------------------+
    static void Info(string message)
    {
        Log(LOG_LEVEL_INFO, message);
    }

    //+------------------------------------------------------------------+
    //| Warning Level Log                                                |
    //+------------------------------------------------------------------+
    static void Warning(string message)
    {
        Log(LOG_LEVEL_WARNING, message);
    }

    //+------------------------------------------------------------------+
    //| Error Level Log                                                  |
    //+------------------------------------------------------------------+
    static void Error(string message)
    {
        Log(LOG_LEVEL_ERROR, message);
    }

    //+------------------------------------------------------------------+
    //| Critical Level Log                                               |
    //+------------------------------------------------------------------+
    static void Critical(string message)
    {
        Log(LOG_LEVEL_CRITICAL, message);
    }

    //+------------------------------------------------------------------+
    //| Main Log Function                                                |
    //+------------------------------------------------------------------+
    static void Log(ENUM_LOG_LEVEL level, string message)
    {
        // Check if level meets minimum threshold
        if(level < m_minLevel)
            return;

        string levelStr = GetLevelString(level);
        string timestamp = "";

        if(m_includeTimestamp)
            timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + " ";

        string logEntry = timestamp + "[" + levelStr + "] " + message;

        // Log to terminal
        if(m_logToTerminal)
        {
            if(level >= LOG_LEVEL_ERROR)
                Print("ERROR: ", message);
            else if(level == LOG_LEVEL_WARNING)
                Print("WARNING: ", message);
            else
                Print(message);
        }

        // Log to file
        if(m_logToFile && m_fileHandle != INVALID_HANDLE)
        {
            FileWriteString(m_fileHandle, logEntry + "\n");
            FileFlush(m_fileHandle);
        }
    }

    //+------------------------------------------------------------------+
    //| Log Trade Entry                                                  |
    //+------------------------------------------------------------------+
    static void LogTrade(
        string action,      // "ENTRY", "EXIT", "MODIFY"
        int ticket,
        string symbol,
        int type,          // ORDER_TYPE_BUY or ORDER_TYPE_SELL
        double lots,
        double price,
        double sl,
        double tp,
        string comment = ""
    )
    {
        string typeStr = (type == ORDER_TYPE_BUY) ? "BUY" : "SELL";

        string message = StringFormat(
            "%s | Ticket: %d | %s %s %.2f lots @ %.5f | SL: %.5f | TP: %.5f",
            action, ticket, symbol, typeStr, lots, price, sl, tp
        );

        if(comment != "")
            message += " | " + comment;

        Info(message);
    }

    //+------------------------------------------------------------------+
    //| Log Performance Metrics                                          |
    //+------------------------------------------------------------------+
    static void LogPerformance(
        int totalTrades,
        int wins,
        int losses,
        double profitFactor,
        double winRate,
        double totalPL,
        double maxDrawdown
    )
    {
        string message = "\n--- Performance Summary ---\n";
        message += StringFormat("Total Trades: %d | Wins: %d | Losses: %d\n",
                                totalTrades, wins, losses);
        message += StringFormat("Win Rate: %.2f%% | Profit Factor: %.2f\n",
                                winRate, profitFactor);
        message += StringFormat("Total P/L: $%.2f | Max Drawdown: %.2f%%\n",
                                totalPL, maxDrawdown);
        message += "---------------------------\n";

        Info(message);
    }

    //+------------------------------------------------------------------+
    //| Log Signal Detection                                             |
    //+------------------------------------------------------------------+
    static void LogSignal(
        string signalType,      // "BUY" or "SELL"
        double price,
        double sl,
        double tp,
        string reason
    )
    {
        string message = StringFormat(
            "SIGNAL DETECTED | %s @ %.5f | SL: %.5f | TP: %.5f | Reason: %s",
            signalType, price, sl, tp, reason
        );

        Info(message);
    }

    //+------------------------------------------------------------------+
    //| Log Pattern Detection                                            |
    //+------------------------------------------------------------------+
    static void LogPattern(
        string patternType,
        double upperLine,
        double lowerLine,
        int barsToConvergence,
        double compressionRate
    )
    {
        string message = StringFormat(
            "PATTERN | %s | Upper: %.5f | Lower: %.5f | Bars to Conv: %d | Compression: %.2f%%",
            patternType, upperLine, lowerLine, barsToConvergence, compressionRate
        );

        Debug(message);
    }

    //+------------------------------------------------------------------+
    //| Log System Event                                                 |
    //+------------------------------------------------------------------+
    static void LogSystemEvent(string eventType, string details)
    {
        string message = StringFormat("SYSTEM | %s | %s", eventType, details);
        Info(message);
    }

    //+------------------------------------------------------------------+
    //| Log Error with Code                                              |
    //+------------------------------------------------------------------+
    static void LogError(string operation, int errorCode)
    {
        string message = StringFormat(
            "%s failed with error code: %d (%s)",
            operation, errorCode, GetErrorDescription(errorCode)
        );

        Error(message);
    }

    //+------------------------------------------------------------------+
    //| Set Minimum Log Level                                            |
    //+------------------------------------------------------------------+
    static void SetMinLevel(ENUM_LOG_LEVEL level)
    {
        m_minLevel = level;
    }

    //+------------------------------------------------------------------+
    //| Enable/Disable Terminal Logging                                  |
    //+------------------------------------------------------------------+
    static void SetTerminalLogging(bool enable)
    {
        m_logToTerminal = enable;
    }

    //+------------------------------------------------------------------+
    //| Enable/Disable File Logging                                      |
    //+------------------------------------------------------------------+
    static void SetFileLogging(bool enable)
    {
        m_logToFile = enable;
    }

private:
    //+------------------------------------------------------------------+
    //| Get String Representation of Log Level                           |
    //+------------------------------------------------------------------+
    static string GetLevelString(ENUM_LOG_LEVEL level)
    {
        switch(level)
        {
            case LOG_LEVEL_DEBUG:    return "DEBUG";
            case LOG_LEVEL_INFO:     return "INFO";
            case LOG_LEVEL_WARNING:  return "WARN";
            case LOG_LEVEL_ERROR:    return "ERROR";
            case LOG_LEVEL_CRITICAL: return "CRITICAL";
            default:                 return "UNKNOWN";
        }
    }

    //+------------------------------------------------------------------+
    //| Get Error Description                                            |
    //+------------------------------------------------------------------+
    static string GetErrorDescription(int errorCode)
    {
        // Common MQL5 error codes
        switch(errorCode)
        {
            case 0:     return "No error";
            case 4001:  return "Wrong function pointer";
            case 4002:  return "Array index out of range";
            case 4003:  return "No memory for function call stack";
            case 4004:  return "Recursive stack overflow";
            case 4005:  return "Not enough stack for parameter";
            case 4006:  return "No memory for parameter string";
            case 4007:  return "No memory for temp string";
            case 4008:  return "Not initialized string";
            case 4009:  return "Not initialized string in array";
            case 4010:  return "No memory for array";
            case 4011:  return "Too long string";
            case 4012:  return "Remainder from zero divide";
            case 4013:  return "Zero divide";
            case 4014:  return "Unknown command";
            case 4015:  return "Wrong jump";
            case 4016:  return "Not initialized array";
            case 4017:  return "DLL calls are not allowed";
            case 4018:  return "Cannot load library";
            case 4019:  return "Cannot call function";
            case 4020:  return "Expert function calls are not allowed";
            case 10004: return "No error returned, but result is unknown";
            case 10006: return "Invalid request";
            case 10007: return "Invalid parameters";
            case 10008: return "Invalid operation";
            case 10009: return "Invalid price";
            case 10010: return "Invalid stop loss or take profit";
            case 10011: return "Invalid volume";
            case 10012: return "Invalid price";
            case 10013: return "Trade is disabled";
            case 10014: return "Market is closed";
            case 10015: return "Not enough money";
            case 10016: return "Price changed";
            case 10017: return "Off quotes";
            case 10018: return "Requote";
            case 10019: return "Order is locked";
            case 10020: return "Long positions only allowed";
            case 10021: return "Short positions only allowed";
            case 10022: return "Order locked";
            case 10023: return "Pending order accepted";
            case 10024: return "Order accepted";
            case 10025: return "Order cancelled";
            default:    return StringFormat("Unknown error code %d", errorCode);
        }
    }
};

// Static member initialization
int CLogger::m_fileHandle = INVALID_HANDLE;
string CLogger::m_filename = "BIONICLES_log.txt";
ENUM_LOG_LEVEL CLogger::m_minLevel = LOG_LEVEL_INFO;
bool CLogger::m_logToFile = true;
bool CLogger::m_logToTerminal = true;
bool CLogger::m_includeTimestamp = true;

//+------------------------------------------------------------------+
