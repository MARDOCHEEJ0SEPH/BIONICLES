//+------------------------------------------------------------------+
//|                                        PerformanceMetrics.mqh |
//|                                    BIONICLES Development Team    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "BIONICLES Development Team"
#property link      "https://bionicles.io"
#property version   "1.00"
#property strict

#include "../Utils/Logger.mqh"
#include "../Utils/MathUtils.mqh"

//+------------------------------------------------------------------+
//| Trade Record Structure                                            |
//+------------------------------------------------------------------+
struct STradeRecord
{
    ulong ticket;
    datetime entryTime;
    datetime exitTime;
    string symbol;
    int type;                     // 0=buy, 1=sell
    double lots;
    double entryPrice;
    double exitPrice;
    double stopLoss;
    double takeProfit;
    double profitUSD;
    double profitPips;
    bool isWin;
    string exitReason;
};

//+------------------------------------------------------------------+
//| Performance Metrics Structure                                     |
//+------------------------------------------------------------------+
struct SPerformanceMetrics
{
    // Trade counts
    int totalTrades;
    int winningTrades;
    int losingTrades;

    // Win rate
    double winRate;                // %

    // Profit/Loss
    double totalProfitUSD;
    double totalLossUSD;
    double netProfitUSD;
    double totalProfitPips;
    double totalLossPips;
    double netProfitPips;

    // Averages
    double averageWinUSD;
    double averageLossUSD;
    double averageWinPips;
    double averageLossPips;
    double averageTradeUSD;

    // Profit factor
    double profitFactor;

    // Risk-reward
    double averageRiskRewardRatio;
    double expectancy;

    // Consecutive stats
    int maxConsecutiveWins;
    int maxConsecutiveLosses;
    int currentConsecutiveWins;
    int currentConsecutiveLosses;

    // Best/Worst trades
    double bestTradeUSD;
    double worstTradeUSD;
    double bestTradePips;
    double worstTradePips;

    // Time stats
    datetime firstTradeTime;
    datetime lastTradeTime;
    int tradingDays;

    // Sharpe ratio
    double sharpeRatio;
};

//+------------------------------------------------------------------+
//| Performance Metrics Class                                         |
//+------------------------------------------------------------------+
class CPerformanceMetrics
{
private:
    static STradeRecord m_trades[];
    static SPerformanceMetrics m_metrics;
    static bool m_isInitialized;

public:
    //+------------------------------------------------------------------+
    //| Initialize Performance Metrics                                   |
    //+------------------------------------------------------------------+
    static bool Initialize()
    {
        ArrayResize(m_trades, 0);

        // Initialize metrics
        m_metrics.totalTrades = 0;
        m_metrics.winningTrades = 0;
        m_metrics.losingTrades = 0;
        m_metrics.winRate = 0.0;
        m_metrics.totalProfitUSD = 0.0;
        m_metrics.totalLossUSD = 0.0;
        m_metrics.netProfitUSD = 0.0;
        m_metrics.totalProfitPips = 0.0;
        m_metrics.totalLossPips = 0.0;
        m_metrics.netProfitPips = 0.0;
        m_metrics.averageWinUSD = 0.0;
        m_metrics.averageLossUSD = 0.0;
        m_metrics.averageWinPips = 0.0;
        m_metrics.averageLossPips = 0.0;
        m_metrics.averageTradeUSD = 0.0;
        m_metrics.profitFactor = 0.0;
        m_metrics.averageRiskRewardRatio = 0.0;
        m_metrics.expectancy = 0.0;
        m_metrics.maxConsecutiveWins = 0;
        m_metrics.maxConsecutiveLosses = 0;
        m_metrics.currentConsecutiveWins = 0;
        m_metrics.currentConsecutiveLosses = 0;
        m_metrics.bestTradeUSD = 0.0;
        m_metrics.worstTradeUSD = 0.0;
        m_metrics.bestTradePips = 0.0;
        m_metrics.worstTradePips = 0.0;
        m_metrics.firstTradeTime = 0;
        m_metrics.lastTradeTime = 0;
        m_metrics.tradingDays = 0;
        m_metrics.sharpeRatio = 0.0;

        m_isInitialized = true;

        CLogger::Info("Performance metrics initialized");

        return true;
    }

    //+------------------------------------------------------------------+
    //| Record Trade                                                      |
    //+------------------------------------------------------------------+
    static void RecordTrade(const STradeRecord &trade)
    {
        if(!m_isInitialized)
        {
            CLogger::Error("Performance metrics not initialized");
            return;
        }

        // Add to array
        int size = ArraySize(m_trades);
        ArrayResize(m_trades, size + 1);
        m_trades[size] = trade;

        // Update metrics
        CalculateMetrics();

        CLogger::Info(StringFormat(
            "Trade recorded: Ticket=%d, P/L=$%.2f (%.1f pips), Win=%s",
            trade.ticket, trade.profitUSD, trade.profitPips,
            trade.isWin ? "Yes" : "No"
        ));
    }

    //+------------------------------------------------------------------+
    //| Get Performance Metrics                                          |
    //+------------------------------------------------------------------+
    static void GetMetrics(SPerformanceMetrics &metrics)
    {
        metrics = m_metrics;
    }

    //+------------------------------------------------------------------+
    //| Log Performance Summary                                          |
    //+------------------------------------------------------------------+
    static void LogSummary()
    {
        CalculateMetrics();

        string summary = "\n=== Performance Summary ===\n";
        summary += StringFormat("Total Trades: %d (Wins: %d, Losses: %d)\n",
                               m_metrics.totalTrades, m_metrics.winningTrades,
                               m_metrics.losingTrades);
        summary += StringFormat("Win Rate: %.2f%%\n", m_metrics.winRate);
        summary += StringFormat("Profit Factor: %.2f\n", m_metrics.profitFactor);
        summary += StringFormat("Net Profit: $%.2f (%.1f pips)\n",
                               m_metrics.netProfitUSD, m_metrics.netProfitPips);
        summary += StringFormat("Average Win: $%.2f (%.1f pips)\n",
                               m_metrics.averageWinUSD, m_metrics.averageWinPips);
        summary += StringFormat("Average Loss: $%.2f (%.1f pips)\n",
                               m_metrics.averageLossUSD, m_metrics.averageLossPips);
        summary += StringFormat("Best Trade: $%.2f (%.1f pips)\n",
                               m_metrics.bestTradeUSD, m_metrics.bestTradePips);
        summary += StringFormat("Worst Trade: $%.2f (%.1f pips)\n",
                               m_metrics.worstTradeUSD, m_metrics.worstTradePips);
        summary += StringFormat("Max Consecutive Wins: %d\n", m_metrics.maxConsecutiveWins);
        summary += StringFormat("Max Consecutive Losses: %d\n", m_metrics.maxConsecutiveLosses);
        summary += StringFormat("Average R:R Ratio: 1:%.2f\n", m_metrics.averageRiskRewardRatio);
        summary += StringFormat("Expectancy: $%.2f per trade\n", m_metrics.expectancy);
        summary += StringFormat("Sharpe Ratio: %.2f\n", m_metrics.sharpeRatio);
        summary += "==========================\n";

        CLogger::LogPerformance(
            m_metrics.totalTrades,
            m_metrics.winningTrades,
            m_metrics.losingTrades,
            m_metrics.profitFactor,
            m_metrics.winRate,
            m_metrics.netProfitUSD,
            0.0  // Max drawdown (get from DrawdownMonitor)
        );

        Print(summary);
    }

    //+------------------------------------------------------------------+
    //| Export Trades to CSV                                             |
    //+------------------------------------------------------------------+
    static bool ExportToCSV(string filename = "trades.csv")
    {
        int handle = FileOpen("BIONICLES/" + filename,
                             FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_SHARE_READ);

        if(handle == INVALID_HANDLE)
        {
            CLogger::Error("Failed to create CSV file: " + filename);
            return false;
        }

        // Write header
        FileWrite(handle,
                 "Ticket", "EntryTime", "ExitTime", "Symbol", "Type",
                 "Lots", "EntryPrice", "ExitPrice", "StopLoss", "TakeProfit",
                 "ProfitUSD", "ProfitPips", "Result", "ExitReason");

        // Write trades
        for(int i = 0; i < ArraySize(m_trades); i++)
        {
            FileWrite(handle,
                     m_trades[i].ticket,
                     TimeToString(m_trades[i].entryTime, TIME_DATE | TIME_SECONDS),
                     TimeToString(m_trades[i].exitTime, TIME_DATE | TIME_SECONDS),
                     m_trades[i].symbol,
                     m_trades[i].type == 0 ? "BUY" : "SELL",
                     m_trades[i].lots,
                     m_trades[i].entryPrice,
                     m_trades[i].exitPrice,
                     m_trades[i].stopLoss,
                     m_trades[i].takeProfit,
                     m_trades[i].profitUSD,
                     m_trades[i].profitPips,
                     m_trades[i].isWin ? "WIN" : "LOSS",
                     m_trades[i].exitReason);
        }

        FileClose(handle);

        CLogger::Info(StringFormat(
            "Exported %d trades to CSV: %s",
            ArraySize(m_trades), filename
        ));

        return true;
    }

private:
    //+------------------------------------------------------------------+
    //| Calculate All Metrics                                            |
    //+------------------------------------------------------------------+
    static void CalculateMetrics()
    {
        int tradeCount = ArraySize(m_trades);

        if(tradeCount == 0)
            return;

        // Reset counters
        m_metrics.totalTrades = tradeCount;
        m_metrics.winningTrades = 0;
        m_metrics.losingTrades = 0;
        m_metrics.totalProfitUSD = 0.0;
        m_metrics.totalLossUSD = 0.0;
        m_metrics.totalProfitPips = 0.0;
        m_metrics.totalLossPips = 0.0;
        m_metrics.currentConsecutiveWins = 0;
        m_metrics.currentConsecutiveLosses = 0;
        m_metrics.maxConsecutiveWins = 0;
        m_metrics.maxConsecutiveLosses = 0;
        m_metrics.bestTradeUSD = -DBL_MAX;
        m_metrics.worstTradeUSD = DBL_MAX;
        m_metrics.bestTradePips = -DBL_MAX;
        m_metrics.worstTradePips = DBL_MAX;

        double returns[];
        ArrayResize(returns, tradeCount);

        // Calculate totals
        for(int i = 0; i < tradeCount; i++)
        {
            STradeRecord trade = m_trades[i];

            if(trade.isWin)
            {
                m_metrics.winningTrades++;
                m_metrics.totalProfitUSD += trade.profitUSD;
                m_metrics.totalProfitPips += trade.profitPips;

                m_metrics.currentConsecutiveWins++;
                m_metrics.currentConsecutiveLosses = 0;

                if(m_metrics.currentConsecutiveWins > m_metrics.maxConsecutiveWins)
                    m_metrics.maxConsecutiveWins = m_metrics.currentConsecutiveWins;
            }
            else
            {
                m_metrics.losingTrades++;
                m_metrics.totalLossUSD += MathAbs(trade.profitUSD);
                m_metrics.totalLossPips += MathAbs(trade.profitPips);

                m_metrics.currentConsecutiveLosses++;
                m_metrics.currentConsecutiveWins = 0;

                if(m_metrics.currentConsecutiveLosses > m_metrics.maxConsecutiveLosses)
                    m_metrics.maxConsecutiveLosses = m_metrics.currentConsecutiveLosses;
            }

            // Best/worst trades
            if(trade.profitUSD > m_metrics.bestTradeUSD)
                m_metrics.bestTradeUSD = trade.profitUSD;

            if(trade.profitUSD < m_metrics.worstTradeUSD)
                m_metrics.worstTradeUSD = trade.profitUSD;

            if(trade.profitPips > m_metrics.bestTradePips)
                m_metrics.bestTradePips = trade.profitPips;

            if(trade.profitPips < m_metrics.worstTradePips)
                m_metrics.worstTradePips = trade.profitPips;

            // Store returns for Sharpe ratio
            returns[i] = trade.profitUSD;

            // Time tracking
            if(m_metrics.firstTradeTime == 0 || trade.entryTime < m_metrics.firstTradeTime)
                m_metrics.firstTradeTime = trade.entryTime;

            if(trade.exitTime > m_metrics.lastTradeTime)
                m_metrics.lastTradeTime = trade.exitTime;
        }

        // Calculate derived metrics
        m_metrics.netProfitUSD = m_metrics.totalProfitUSD - m_metrics.totalLossUSD;
        m_metrics.netProfitPips = m_metrics.totalProfitPips - m_metrics.totalLossPips;

        m_metrics.winRate = (m_metrics.winningTrades * 100.0) / tradeCount;

        m_metrics.averageWinUSD = m_metrics.winningTrades > 0 ?
                                  m_metrics.totalProfitUSD / m_metrics.winningTrades : 0.0;

        m_metrics.averageLossUSD = m_metrics.losingTrades > 0 ?
                                   m_metrics.totalLossUSD / m_metrics.losingTrades : 0.0;

        m_metrics.averageWinPips = m_metrics.winningTrades > 0 ?
                                   m_metrics.totalProfitPips / m_metrics.winningTrades : 0.0;

        m_metrics.averageLossPips = m_metrics.losingTrades > 0 ?
                                    m_metrics.totalLossPips / m_metrics.losingTrades : 0.0;

        m_metrics.averageTradeUSD = m_metrics.netProfitUSD / tradeCount;

        m_metrics.profitFactor = m_metrics.totalLossUSD > 0.0 ?
                                m_metrics.totalProfitUSD / m_metrics.totalLossUSD : 0.0;

        // Expectancy = (Win% × AvgWin) - (Loss% × AvgLoss)
        m_metrics.expectancy = (m_metrics.winRate / 100.0) * m_metrics.averageWinUSD -
                              ((100.0 - m_metrics.winRate) / 100.0) * m_metrics.averageLossUSD;

        // Average R:R ratio
        m_metrics.averageRiskRewardRatio = m_metrics.averageLossUSD > 0.0 ?
                                          m_metrics.averageWinUSD / m_metrics.averageLossUSD : 0.0;

        // Trading days
        if(m_metrics.lastTradeTime > m_metrics.firstTradeTime)
            m_metrics.tradingDays = (int)((m_metrics.lastTradeTime - m_metrics.firstTradeTime) / 86400);

        // Sharpe ratio
        m_metrics.sharpeRatio = CalculateSharpeRatio(returns);
    }

    //+------------------------------------------------------------------+
    //| Calculate Sharpe Ratio                                           |
    //+------------------------------------------------------------------+
    static double CalculateSharpeRatio(const double &returns[])
    {
        int count = ArraySize(returns);

        if(count < 2)
            return 0.0;

        double mean = CMathUtils::Mean(returns);
        double stdDev = CMathUtils::StandardDeviation(returns);

        if(stdDev == 0.0)
            return 0.0;

        // Annualized Sharpe ratio (assuming ~60 trades per year)
        double sharpe = (mean / stdDev) * MathSqrt(60);

        return sharpe;
    }
};

// Static member initialization
STradeRecord CPerformanceMetrics::m_trades[];
SPerformanceMetrics CPerformanceMetrics::m_metrics;
bool CPerformanceMetrics::m_isInitialized = false;

//+------------------------------------------------------------------+
