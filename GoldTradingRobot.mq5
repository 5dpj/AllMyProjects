//+------------------------------------------------------------------+
//|                                           GoldTradingRobot.mq5 |
//|                        Copyright 2025, Professional Gold Trading|
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Professional Gold Trading"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Professional Gold Trading Robot - Multi-Strategy EA"
#property description "Incorporates AI-inspired decision making, multi-timeframe analysis,"
#property description "robust risk management, and multiple confirmation indicators"

//--- Include necessary libraries
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Indicators\Trend.mqh>
#include <Indicators\Oscillators.mqh>

//--- Input parameters
input group "=== TRADING SETTINGS ==="
input string TradeSymbol = "XAUUSD";           // Trading Symbol
input double RiskPercent = 1.0;                // Risk per trade (% of balance)
input double MaxDrawdownPercent = 15.0;        // Maximum allowed drawdown (%)
input int MagicNumber = 12345;                 // Magic number for orders
input bool EnableScalping = true;              // Enable scalping on M1
input bool EnableSwingTrading = true;          // Enable swing trading on H1/H4

input group "=== EMA SETTINGS ==="
input int EMA_Fast_Period = 21;                // Fast EMA period
input int EMA_Slow_Period = 50;                // Slow EMA period
input int EMA_Filter_Period = 200;             // Long-term filter EMA
input ENUM_TIMEFRAMES EMA_Timeframe = PERIOD_H1; // EMA calculation timeframe

input group "=== RSI SETTINGS ==="
input int RSI_Period = 14;                     // RSI period
input double RSI_Oversold = 30.0;              // RSI oversold level
input double RSI_Overbought = 70.0;            // RSI overbought level

input group "=== BOLLINGER BANDS ==="
input int BB_Period = 20;                      // Bollinger Bands period
input double BB_Deviation = 2.0;               // Standard deviation
input ENUM_APPLIED_PRICE BB_AppliedPrice = PRICE_CLOSE; // Applied price

input group "=== ATR SETTINGS ==="
input int ATR_Period = 14;                     // ATR period
input double ATR_StopLoss_Multiplier = 2.0;    // ATR multiplier for stop loss
input double ATR_TakeProfit_Multiplier = 3.0;  // ATR multiplier for take profit

input group "=== VOLUME FILTER ==="
input bool UseVolumeFilter = true;             // Use volume analysis
input double VolumeThreshold = 1.5;            // Volume spike threshold (multiplier)

input group "=== TIME FILTER ==="
input bool UseTimeFilter = true;               // Use time-based filtering
input int StartHour = 7;                       // Trading start hour (GMT)
input int EndHour = 22;                        // Trading end hour (GMT)

input group "=== NEWS FILTER ==="
input bool AvoidNews = true;                   // Avoid trading during news
input int NewsAvoidanceMinutes = 30;           // Minutes before/after news

input group "=== POSITION MANAGEMENT ==="
input int MaxPositions = 3;                    // Maximum concurrent positions
input bool UseTrailingStop = true;             // Use trailing stop
input double TrailingStopPercent = 1.0;        // Trailing stop percentage

//--- Global variables
CTrade trade;
CSymbolInfo symbolInfo;
CPositionInfo positionInfo;

//--- Indicator handles
int handleEMA_Fast, handleEMA_Slow, handleEMA_Filter;
int handleRSI;
int handleBB;
int handleATR;

//--- Indicator buffers
double emaFast[], emaSlow[], emaFilter[];
double rsiBuffer[];
double bbUpper[], bbMiddle[], bbLower[];
double atrBuffer[];

//--- Strategy variables
bool isUptrend = false;
bool isDowntrend = false;
double currentDrawdown = 0.0;
datetime lastTradeTime = 0;
double accountBalance = 0.0;
double peakBalance = 0.0;

//--- AI-inspired variables
double trendStrength = 0.0;
double volatilityIndex = 0.0;
double marketSentiment = 0.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Initialize trade object
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(30);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    //--- Initialize symbol info
    if(!symbolInfo.Name(TradeSymbol))
    {
        Print("Error: Invalid symbol ", TradeSymbol);
        return INIT_FAILED;
    }
    
    //--- Initialize indicators
    if(!InitializeIndicators())
    {
        Print("Error: Failed to initialize indicators");
        return INIT_FAILED;
    }
    
    //--- Initialize account variables
    accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    peakBalance = accountBalance;
    
    Print("Gold Trading Robot initialized successfully");
    Print("Symbol: ", TradeSymbol);
    Print("Risk per trade: ", RiskPercent, "%");
    Print("Max drawdown: ", MaxDrawdownPercent, "%");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Release indicator handles
    IndicatorRelease(handleEMA_Fast);
    IndicatorRelease(handleEMA_Slow);
    IndicatorRelease(handleEMA_Filter);
    IndicatorRelease(handleRSI);
    IndicatorRelease(handleBB);
    IndicatorRelease(handleATR);
    
    Print("Gold Trading Robot deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Update market data
    if(!UpdateMarketData())
        return;
    
    //--- Check drawdown protection
    if(!CheckDrawdownProtection())
        return;
    
    //--- Update AI-inspired indicators
    UpdateAIIndicators();
    
    //--- Check trading filters
    if(!CheckTradingFilters())
        return;
    
    //--- Manage existing positions
    ManagePositions();
    
    //--- Look for new trading opportunities
    if(EnableScalping && Period() == PERIOD_M1)
        CheckScalpingSignals();
    
    if(EnableSwingTrading && (Period() == PERIOD_H1 || Period() == PERIOD_H4))
        CheckSwingTradingSignals();
}

//+------------------------------------------------------------------+
//| Initialize all indicators                                        |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
    //--- EMA indicators
    handleEMA_Fast = iMA(TradeSymbol, EMA_Timeframe, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
    handleEMA_Slow = iMA(TradeSymbol, EMA_Timeframe, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
    handleEMA_Filter = iMA(TradeSymbol, EMA_Timeframe, EMA_Filter_Period, 0, MODE_EMA, PRICE_CLOSE);
    
    //--- RSI indicator
    handleRSI = iRSI(TradeSymbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
    
    //--- Bollinger Bands
    handleBB = iBands(TradeSymbol, PERIOD_CURRENT, BB_Period, 0, BB_Deviation, BB_AppliedPrice);
    
    //--- ATR indicator
    handleATR = iATR(TradeSymbol, PERIOD_CURRENT, ATR_Period);
    
    //--- Check if all indicators are valid
    if(handleEMA_Fast == INVALID_HANDLE || handleEMA_Slow == INVALID_HANDLE || 
       handleEMA_Filter == INVALID_HANDLE || handleRSI == INVALID_HANDLE ||
       handleBB == INVALID_HANDLE || handleATR == INVALID_HANDLE)
    {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Update market data and indicator buffers                        |
//+------------------------------------------------------------------+
bool UpdateMarketData()
{
    //--- Refresh symbol quotes
    if(!symbolInfo.RefreshRates())
        return false;
    
    //--- Copy indicator data
    if(CopyBuffer(handleEMA_Fast, 0, 0, 3, emaFast) <= 0) return false;
    if(CopyBuffer(handleEMA_Slow, 0, 0, 3, emaSlow) <= 0) return false;
    if(CopyBuffer(handleEMA_Filter, 0, 0, 3, emaFilter) <= 0) return false;
    if(CopyBuffer(handleRSI, 0, 0, 3, rsiBuffer) <= 0) return false;
    if(CopyBuffer(handleBB, 0, 0, 3, bbUpper) <= 0) return false;
    if(CopyBuffer(handleBB, 1, 0, 3, bbMiddle) <= 0) return false;
    if(CopyBuffer(handleBB, 2, 0, 3, bbLower) <= 0) return false;
    if(CopyBuffer(handleATR, 0, 0, 3, atrBuffer) <= 0) return false;
    
    //--- Set array directions
    ArraySetAsSeries(emaFast, true);
    ArraySetAsSeries(emaSlow, true);
    ArraySetAsSeries(emaFilter, true);
    ArraySetAsSeries(rsiBuffer, true);
    ArraySetAsSeries(bbUpper, true);
    ArraySetAsSeries(bbMiddle, true);
    ArraySetAsSeries(bbLower, true);
    ArraySetAsSeries(atrBuffer, true);
    
    return true;
}

//+------------------------------------------------------------------+
//| Update AI-inspired indicators                                   |
//+------------------------------------------------------------------+
void UpdateAIIndicators()
{
    //--- Calculate trend strength (AI-inspired)
    double emaSpread = MathAbs(emaFast[0] - emaSlow[0]);
    double normalizedSpread = emaSpread / symbolInfo.Point();
    trendStrength = MathMin(normalizedSpread / 100.0, 1.0); // Normalize to 0-1
    
    //--- Calculate volatility index
    volatilityIndex = atrBuffer[0] / symbolInfo.Point() / 100.0; // Normalize ATR
    
    //--- Calculate market sentiment (AI-inspired combination)
    double rsiNorm = (rsiBuffer[0] - 50.0) / 50.0; // Normalize RSI to -1 to 1
    double pricePosition = (symbolInfo.Last() - bbLower[0]) / (bbUpper[0] - bbLower[0]); // Position in BB
    marketSentiment = (rsiNorm * 0.6) + ((pricePosition - 0.5) * 2.0 * 0.4); // Weighted combination
    
    //--- Determine trend direction
    isUptrend = (emaFast[0] > emaSlow[0]) && (emaFast[0] > emaFilter[0]) && (trendStrength > 0.3);
    isDowntrend = (emaFast[0] < emaSlow[0]) && (emaFast[0] < emaFilter[0]) && (trendStrength > 0.3);
}

//+------------------------------------------------------------------+
//| Check drawdown protection                                       |
//+------------------------------------------------------------------+
bool CheckDrawdownProtection()
{
    accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    if(accountBalance > peakBalance)
        peakBalance = accountBalance;
    
    currentDrawdown = (peakBalance - accountBalance) / peakBalance * 100.0;
    
    if(currentDrawdown > MaxDrawdownPercent)
    {
        CloseAllPositions();
        Print("DRAWDOWN PROTECTION: Maximum drawdown exceeded (", currentDrawdown, "%)");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check trading filters                                           |
//+------------------------------------------------------------------+
bool CheckTradingFilters()
{
    //--- Time filter
    if(UseTimeFilter)
    {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        if(dt.hour < StartHour || dt.hour > EndHour)
            return false;
    }
    
    //--- Volume filter
    if(UseVolumeFilter)
    {
        long currentVolume = iVolume(TradeSymbol, PERIOD_M1, 0);
        long avgVolume = 0;
        for(int i = 1; i <= 20; i++)
            avgVolume += iVolume(TradeSymbol, PERIOD_M1, i);
        avgVolume /= 20;
        
        if(currentVolume < avgVolume * VolumeThreshold)
            return false;
    }
    
    //--- News filter (simplified - avoid trading on round hours)
    if(AvoidNews)
    {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        if(dt.min < NewsAvoidanceMinutes || dt.min > (60 - NewsAvoidanceMinutes))
            return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check scalping signals (M1 timeframe)                          |
//+------------------------------------------------------------------+
void CheckScalpingSignals()
{
    //--- Check if we can open new positions
    if(GetOpenPositionsCount() >= MaxPositions)
        return;
    
    //--- EMA crossover scalping signal
    bool buySignal = false;
    bool sellSignal = false;
    
    //--- Bullish signal: Fast EMA crosses above Slow EMA + RSI not overbought + price above BB middle
    if(emaFast[1] <= emaSlow[1] && emaFast[0] > emaSlow[0] && // EMA crossover
       rsiBuffer[0] < RSI_Overbought && // RSI filter
       symbolInfo.Last() > bbMiddle[0] && // Price above BB middle
       isUptrend && trendStrength > 0.4) // AI trend confirmation
    {
        buySignal = true;
    }
    
    //--- Bearish signal: Fast EMA crosses below Slow EMA + RSI not oversold + price below BB middle
    if(emaFast[1] >= emaSlow[1] && emaFast[0] < emaSlow[0] && // EMA crossover
       rsiBuffer[0] > RSI_Oversold && // RSI filter
       symbolInfo.Last() < bbMiddle[0] && // Price below BB middle
       isDowntrend && trendStrength > 0.4) // AI trend confirmation
    {
        sellSignal = true;
    }
    
    //--- Execute trades
    if(buySignal)
        OpenPosition(ORDER_TYPE_BUY, "Scalp Buy");
    
    if(sellSignal)
        OpenPosition(ORDER_TYPE_SELL, "Scalp Sell");
}

//+------------------------------------------------------------------+
//| Check swing trading signals (H1/H4 timeframes)                 |
//+------------------------------------------------------------------+
void CheckSwingTradingSignals()
{
    //--- Check if we can open new positions
    if(GetOpenPositionsCount() >= MaxPositions)
        return;
    
    //--- Swing trading signals based on stronger confirmation
    bool buySignal = false;
    bool sellSignal = false;
    
    //--- Bullish signal: Multiple confirmations required
    if(isUptrend && // Trend confirmation
       rsiBuffer[0] > RSI_Oversold && rsiBuffer[0] < 60 && // RSI in favorable zone
       symbolInfo.Last() > emaFilter[0] && // Above long-term EMA
       symbolInfo.Last() < bbUpper[0] && // Not overbought on BB
       marketSentiment > -0.3 && // AI sentiment filter
       volatilityIndex > 0.5) // Sufficient volatility
    {
        buySignal = true;
    }
    
    //--- Bearish signal: Multiple confirmations required
    if(isDowntrend && // Trend confirmation
       rsiBuffer[0] < RSI_Overbought && rsiBuffer[0] > 40 && // RSI in favorable zone
       symbolInfo.Last() < emaFilter[0] && // Below long-term EMA
       symbolInfo.Last() > bbLower[0] && // Not oversold on BB
       marketSentiment < 0.3 && // AI sentiment filter
       volatilityIndex > 0.5) // Sufficient volatility
    {
        sellSignal = true;
    }
    
    //--- Execute trades
    if(buySignal)
        OpenPosition(ORDER_TYPE_BUY, "Swing Buy");
    
    if(sellSignal)
        OpenPosition(ORDER_TYPE_SELL, "Swing Sell");
}

//+------------------------------------------------------------------+
//| Open a new position                                             |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType, string comment)
{
    //--- Calculate position size based on risk
    double lotSize = CalculatePositionSize();
    if(lotSize <= 0)
        return;
    
    //--- Calculate stop loss and take profit
    double stopLoss = 0, takeProfit = 0;
    CalculateStopLossAndTakeProfit(orderType, stopLoss, takeProfit);
    
    //--- Open position
    bool result = false;
    if(orderType == ORDER_TYPE_BUY)
    {
        result = trade.Buy(lotSize, TradeSymbol, 0, stopLoss, takeProfit, comment);
    }
    else if(orderType == ORDER_TYPE_SELL)
    {
        result = trade.Sell(lotSize, TradeSymbol, 0, stopLoss, takeProfit, comment);
    }
    
    if(result)
    {
        lastTradeTime = TimeCurrent();
        Print("Position opened: ", comment, " | Lots: ", lotSize, " | SL: ", stopLoss, " | TP: ", takeProfit);
    }
    else
    {
        Print("Failed to open position: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                          |
//+------------------------------------------------------------------+
double CalculatePositionSize()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * RiskPercent / 100.0;
    
    double stopLossPoints = atrBuffer[0] * ATR_StopLoss_Multiplier / symbolInfo.Point();
    double tickValue = symbolInfo.TickValue();
    double tickSize = symbolInfo.TickSize();
    
    double lotSize = riskAmount / (stopLossPoints * tickValue / tickSize);
    
    //--- Normalize lot size
    double minLot = symbolInfo.LotsMin();
    double maxLot = symbolInfo.LotsMax();
    double lotStep = symbolInfo.LotsStep();
    
    lotSize = MathMax(minLot, MathMin(maxLot, MathRound(lotSize / lotStep) * lotStep));
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Calculate stop loss and take profit levels                     |
//+------------------------------------------------------------------+
void CalculateStopLossAndTakeProfit(ENUM_ORDER_TYPE orderType, double &stopLoss, double &takeProfit)
{
    double atr = atrBuffer[0];
    double currentPrice = (orderType == ORDER_TYPE_BUY) ? symbolInfo.Ask() : symbolInfo.Bid();
    
    if(orderType == ORDER_TYPE_BUY)
    {
        stopLoss = currentPrice - (atr * ATR_StopLoss_Multiplier);
        takeProfit = currentPrice + (atr * ATR_TakeProfit_Multiplier);
    }
    else
    {
        stopLoss = currentPrice + (atr * ATR_StopLoss_Multiplier);
        takeProfit = currentPrice - (atr * ATR_TakeProfit_Multiplier);
    }
    
    //--- Normalize prices
    stopLoss = NormalizeDouble(stopLoss, symbolInfo.Digits());
    takeProfit = NormalizeDouble(takeProfit, symbolInfo.Digits());
}

//+------------------------------------------------------------------+
//| Manage existing positions                                       |
//+------------------------------------------------------------------+
void ManagePositions()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(positionInfo.SelectByIndex(i))
        {
            if(positionInfo.Symbol() == TradeSymbol && positionInfo.Magic() == MagicNumber)
            {
                //--- Trailing stop implementation
                if(UseTrailingStop)
                    UpdateTrailingStop(positionInfo.Ticket());
                
                //--- Check for early exit conditions
                CheckEarlyExit(positionInfo.Ticket());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update trailing stop for a position                            |
//+------------------------------------------------------------------+
void UpdateTrailingStop(ulong ticket)
{
    if(!positionInfo.SelectByTicket(ticket))
        return;
    
    double currentPrice = (positionInfo.PositionType() == POSITION_TYPE_BUY) ? 
                         symbolInfo.Bid() : symbolInfo.Ask();
    double currentSL = positionInfo.StopLoss();
    double trailDistance = atrBuffer[0] * TrailingStopPercent;
    
    double newSL = 0;
    bool updateSL = false;
    
    if(positionInfo.PositionType() == POSITION_TYPE_BUY)
    {
        newSL = currentPrice - trailDistance;
        if(newSL > currentSL && (currentSL == 0 || newSL > currentSL))
            updateSL = true;
    }
    else
    {
        newSL = currentPrice + trailDistance;
        if(newSL < currentSL && (currentSL == 0 || newSL < currentSL))
            updateSL = true;
    }
    
    if(updateSL)
    {
        newSL = NormalizeDouble(newSL, symbolInfo.Digits());
        trade.PositionModify(ticket, newSL, positionInfo.TakeProfit());
    }
}

//+------------------------------------------------------------------+
//| Check early exit conditions                                    |
//+------------------------------------------------------------------+
void CheckEarlyExit(ulong ticket)
{
    if(!positionInfo.SelectByTicket(ticket))
        return;
    
    //--- Exit if trend reverses strongly
    bool exitCondition = false;
    
    if(positionInfo.PositionType() == POSITION_TYPE_BUY)
    {
        if(isDowntrend && trendStrength > 0.6 && marketSentiment < -0.5)
            exitCondition = true;
    }
    else
    {
        if(isUptrend && trendStrength > 0.6 && marketSentiment > 0.5)
            exitCondition = true;
    }
    
    if(exitCondition)
    {
        trade.PositionClose(ticket);
        Print("Position closed early due to trend reversal: ", ticket);
    }
}

//+------------------------------------------------------------------+
//| Get count of open positions                                    |
//+------------------------------------------------------------------+
int GetOpenPositionsCount()
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(positionInfo.SelectByIndex(i))
        {
            if(positionInfo.Symbol() == TradeSymbol && positionInfo.Magic() == MagicNumber)
                count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Close all positions                                            |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(positionInfo.SelectByIndex(i))
        {
            if(positionInfo.Symbol() == TradeSymbol && positionInfo.Magic() == MagicNumber)
            {
                trade.PositionClose(positionInfo.Ticket());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| OnTrade function - called when trade events occur              |
//+------------------------------------------------------------------+
void OnTrade()
{
    //--- Update account statistics
    accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    //--- Log trade events
    Print("Trade event occurred. New balance: ", accountBalance);
}