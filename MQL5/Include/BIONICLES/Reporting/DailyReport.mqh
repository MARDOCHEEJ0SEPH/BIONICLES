//+------------------------------------------------------------------+
//|                                               DailyReport.mqh |
//|                                    BIONICLES Development Team    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "BIONICLES Development Team"
#property link      "https://bionicles.io"
#property version   "1.00"
#property strict

#include "PerformanceMetrics.mqh"
#include "../Safety/DrawdownMonitor.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Daily Report Class                                                |
//+------------------------------------------------------------------+
class CDailyReport
{
public:
    //+------------------------------------------------------------------+
    //| Generate End-of-Day Report                                       |
    //+------------------------------------------------------------------+
    static void GenerateReport()
    {
        CLogger::Info("=== Generating Daily Report ===");

        // Get performance metrics
        SPerformanceMetrics metrics;
        CPerformanceMetrics::GetMetrics(metrics);

        // Get drawdown data
        SDrawdownData ddData;
        CDrawdownMonitor::GetData(ddData);

        // Build report
        string report = "\n";
        report += "┌─────────────────────────────────────────────────────┐\n";
        report += "│         BIONICLES - Daily Trading Report           │\n";
        report += "│         " + TimeToString(TimeCurrent(), TIME_DATE) + "                              │\n";
        report += "└─────────────────────────────────────────────────────┘\n\n";

        // Account Summary
        report += "ACCOUNT SUMMARY\n";
        report += "───────────────────────────────────────────────────────\n";
        report += StringFormat("Balance:        $%.2f\n", AccountInfoDouble(ACCOUNT_BALANCE));
        report += StringFormat("Equity:         $%.2f\n", AccountInfoDouble(ACCOUNT_EQUITY));
        report += StringFormat("Margin Free:    $%.2f\n", AccountInfoDouble(ACCOUNT_MARGIN_FREE));
        report += StringFormat("Margin Level:   %.2f%%\n\n", AccountInfoDouble(ACCOUNT_MARGIN_LEVEL));

        // Trading Performance
        report += "TRADING PERFORMANCE\n";
        report += "───────────────────────────────────────────────────────\n";
        report += StringFormat("Total Trades:   %d\n", metrics.totalTrades);
        report += StringFormat("Wins:           %d (%.1f%%)\n",
                              metrics.winningTrades, metrics.winRate);
        report += StringFormat("Losses:         %d (%.1f%%)\n",
                              metrics.losingTrades, 100.0 - metrics.winRate);
        report += StringFormat("Profit Factor:  %.2f\n", metrics.profitFactor);
        report += StringFormat("Net P/L:        $%.2f (%.1f pips)\n",
                              metrics.netProfitUSD, metrics.netProfitPips);
        report += StringFormat("Avg Win:        $%.2f (%.1f pips)\n",
                              metrics.averageWinUSD, metrics.averageWinPips);
        report += StringFormat("Avg Loss:       $%.2f (%.1f pips)\n",
                              metrics.averageLossUSD, metrics.averageLossPips);
        report += StringFormat("Best Trade:     $%.2f (%.1f pips)\n",
                              metrics.bestTradeUSD, metrics.bestTradePips);
        report += StringFormat("Worst Trade:    $%.2f (%.1f pips)\n",
                              metrics.worstTradeUSD, metrics.worstTradePips);
        report += StringFormat("Expectancy:     $%.2f per trade\n\n", metrics.expectancy);

        // Risk Metrics
        report += "RISK METRICS\n";
        report += "───────────────────────────────────────────────────────\n";
        report += StringFormat("Current DD:     %.2f%% ($%.2f)\n",
                              ddData.currentDrawdown, ddData.currentDrawdownUSD);
        report += StringFormat("Max DD:         %.2f%% ($%.2f)\n",
                              ddData.maxDrawdown, ddData.maxDrawdownUSD);
        report += StringFormat("Peak Equity:    $%.2f\n", ddData.peakEquity);
        report += StringFormat("Sharpe Ratio:   %.2f\n", metrics.sharpeRatio);
        report += StringFormat("Avg R:R Ratio:  1:%.2f\n\n", metrics.averageRiskRewardRatio);

        // Pattern Quality
        report += "PATTERN QUALITY\n";
        report += "───────────────────────────────────────────────────────\n";
        report += StringFormat("Max Consec Wins:   %d\n", metrics.maxConsecutiveWins);
        report += StringFormat("Max Consec Losses: %d\n", metrics.maxConsecutiveLosses);
        report += StringFormat("Trading Days:      %d\n", metrics.tradingDays);
        report += StringFormat("Trades per Day:    %.1f\n\n",
                              metrics.tradingDays > 0 ?
                              (double)metrics.totalTrades / metrics.tradingDays : 0.0);

        // Current Status
        report += "CURRENT STATUS\n";
        report += "───────────────────────────────────────────────────────\n";
        report += StringFormat("Open Positions: %d\n", PositionsTotal());
        report += StringFormat("In Drawdown:    %s",
                              ddData.isInDrawdown ? "Yes" : "No");

        if(ddData.isInDrawdown)
        {
            report += StringFormat(" (for %d days)", ddData.daysInDrawdown);
        }

        report += "\n\n";

        report += "═══════════════════════════════════════════════════════\n";
        report += "  Generated by BIONICLES Autonomous Trading System\n";
        report += "═══════════════════════════════════════════════════════\n";

        // Log to terminal and file
        Print(report);
        CLogger::Info(report);

        // Save to file
        SaveReportToFile(report);

        CLogger::Info("=== Daily Report Complete ===");
    }

    //+------------------------------------------------------------------+
    //| Save Report to File                                              |
    //+------------------------------------------------------------------+
    static bool SaveReportToFile(string report)
    {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);

        string filename = StringFormat("daily_report_%04d%02d%02d.txt",
                                      dt.year, dt.mon, dt.day);

        int handle = FileOpen("BIONICLES/Reports/" + filename,
                             FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);

        if(handle == INVALID_HANDLE)
        {
            CLogger::Error("Failed to create report file: " + filename);
            return false;
        }

        FileWriteString(handle, report);
        FileClose(handle);

        CLogger::Info("Report saved to: " + filename);

        return true;
    }

    //+------------------------------------------------------------------+
    //| Generate Weekly Summary                                          |
    //+------------------------------------------------------------------+
    static void GenerateWeeklySummary()
    {
        CLogger::Info("=== Generating Weekly Summary ===");

        SPerformanceMetrics metrics;
        CPerformanceMetrics::GetMetrics(metrics);

        string summary = "\n";
        summary += "╔═══════════════════════════════════════════════════════╗\n";
        summary += "║         BIONICLES - Weekly Summary                    ║\n";
        summary += "║         Week of " + TimeToString(TimeCurrent(), TIME_DATE) + "                       ║\n";
        summary += "╚═══════════════════════════════════════════════════════╝\n\n";

        summary += "WEEKLY HIGHLIGHTS\n";
        summary += "─────────────────────────────────────────────────────────\n";
        summary += StringFormat("Total Trades:       %d\n", metrics.totalTrades);
        summary += StringFormat("Win Rate:           %.1f%%\n", metrics.winRate);
        summary += StringFormat("Net Profit:         $%.2f\n", metrics.netProfitUSD);
        summary += StringFormat("Profit Factor:      %.2f\n", metrics.profitFactor);
        summary += StringFormat("Sharpe Ratio:       %.2f\n", metrics.sharpeRatio);
        summary += StringFormat("Best Trade:         $%.2f\n", metrics.bestTradeUSD);
        summary += StringFormat("Worst Trade:        $%.2f\n", metrics.worstTradeUSD);
        summary += StringFormat("Max Consec Wins:    %d\n", metrics.maxConsecutiveWins);
        summary += StringFormat("Max Consec Losses:  %d\n\n", metrics.maxConsecutiveLosses);

        summary += "RECOMMENDATIONS\n";
        summary += "─────────────────────────────────────────────────────────\n";

        // Analysis and recommendations
        if(metrics.winRate < 40.0)
        {
            summary += "⚠ Win rate below target (40%). Review signal quality.\n";
        }
        else if(metrics.winRate >= 45.0)
        {
            summary += "✓ Excellent win rate achieved!\n";
        }

        if(metrics.profitFactor < 1.5)
        {
            summary += "⚠ Profit factor below target (1.5). Review risk management.\n";
        }
        else if(metrics.profitFactor >= 2.0)
        {
            summary += "✓ Outstanding profit factor!\n";
        }

        if(metrics.averageRiskRewardRatio < 2.8)
        {
            summary += "⚠ Average R:R below 1:3 target. Check TP placement.\n";
        }

        summary += "\n";
        summary += "═════════════════════════════════════════════════════════\n";

        Print(summary);
        CLogger::Info(summary);
    }
};

//+------------------------------------------------------------------+
