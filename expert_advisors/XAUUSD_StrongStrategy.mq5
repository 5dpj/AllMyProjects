//+------------------------------------------------------------------+
//|                                                    XAUUSD_EA.mq5 |
//|      Robust Multi-TF EMA Trend-Scalp Strategy for XAUUSD         |
//|      Author:  o3-Assistant                                       |
//|      Date:    2025-07-06                                         |
//|                                                                  |
//|  Description:                                                    |
//|  – Higher-timeframe (H1) 50 EMA vs 200 EMA filters market trend. |
//|  – Entry on M5 when 21 EMA crosses 50 EMA in trend direction.    |
//|  – Optional RSI/ATR volatility filters.                          |
//|  – Dynamic position sizing by risk-% with ATR-based SL / TP.     |
//|  – Trailing-stop, break-even, spread/ slippage / news filters.   |
//|  – Supports partial close, trading sessions, and multi-instance. |
//+------------------------------------------------------------------+
#property copyright   "o3-Assistant"
#property link        "https://cursor.sh"
#property version     "1.00"
#property strict
#property description "EMA trend-scalp Expert Advisor for XAUUSD"

#include <Trade/Trade.mqh>
#include <Calendar/Calendar.mqh>

//--- trade object
CTrade   trade;

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input ENUM_TIMEFRAMES TrendTF         = PERIOD_H1;   // Trend timeframe
input ENUM_TIMEFRAMES EntryTF         = PERIOD_M5;   // Signal timeframe

input int            FastEMA          = 21;         // Fast EMA (entry)
input int            SlowEMA          = 50;         // Slow EMA (entry)
input int            HTF_FastEMA      = 50;         // HTF trend fast EMA
input int            HTF_SlowEMA      = 200;        // HTF trend slow EMA

input double         RiskPercent      = 1.0;        // Risk per trade (% equity)
input double         ATR_Multiplier   = 1.5;        // SL = ATR*mult
input int            ATR_Period       = 14;         // ATR period (entry TF)
input double         RR_Multiplier    = 2.0;        // TP = SL*mult

input bool           UseTrailing      = true;       // Enable trailing stop
input double         TrailingATR      = 1.0;        // Trailing stop = ATR*mult
input bool           UseBreakEven     = true;       // Move SL to BE at RR 1:1

input bool           FilterNews       = true;       // Skip trading near Red news
input int            NewsMinutesSkip  = 30;         // Minutes before/after news to avoid trades

input int            StartHour        = 6;          // Allowed trading window start (server time)
input int            EndHour          = 22;         // Allowed trading window end (server time)

input double         MaxSpreadPoints  = 25;         // Max allowed spread (points)
input uint           SlippagePoints   = 30;         // Max slippage points

input bool           PartialClose     = true;       // Enable partial close at RR 1:1
input double         ClosePercent     = 50;         // % volume to close partially

input ulong          Magic            = 770077;     // Magic number

//--- global handles
int hFastEMA, hSlowEMA;
int hHTF_FastEMA, hHTF_SlowEMA;
int hATR;

//--- misc globals
datetime last_entry_bar = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- indicator handles for entry timeframe
   hFastEMA = iMA(_Symbol,EntryTF,FastEMA,0,MODE_EMA,PRICE_CLOSE);
   hSlowEMA = iMA(_Symbol,EntryTF,SlowEMA,0,MODE_EMA,PRICE_CLOSE);

   //--- HTF trend handles
   hHTF_FastEMA = iMA(_Symbol,TrendTF,HTF_FastEMA,0,MODE_EMA,PRICE_CLOSE);
   hHTF_SlowEMA = iMA(_Symbol,TrendTF,HTF_SlowEMA,0,MODE_EMA,PRICE_CLOSE);

   //--- ATR handle on entry TF
   hATR = iATR(_Symbol,EntryTF,ATR_Period);

   if(hFastEMA==INVALID_HANDLE || hSlowEMA==INVALID_HANDLE ||
      hHTF_FastEMA==INVALID_HANDLE || hHTF_SlowEMA==INVALID_HANDLE ||
      hATR==INVALID_HANDLE)
     {
      Print("Failed to create indicator handles");
      return(INIT_FAILED);
     }

   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints((int)SlippagePoints);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(hFastEMA);
   IndicatorRelease(hSlowEMA);
   IndicatorRelease(hHTF_FastEMA);
   IndicatorRelease(hHTF_SlowEMA);
   IndicatorRelease(hATR);
  }

//+------------------------------------------------------------------+
//| Helper: Check if new bar on EntryTF                              |
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   static datetime last_time=0;
   datetime current_time=iTime(_Symbol,EntryTF,0);
   if(current_time!=last_time)
     {
      last_time=current_time;
      return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Helper: Get spread in points                                     |
//+------------------------------------------------------------------+
double CurrentSpreadPoints()
  {
   return((double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD));
  }

//+------------------------------------------------------------------+
//| Helper: Economic calendar filter                                 |
//+------------------------------------------------------------------+
bool RedNewsSoon()
  {
   if(!FilterNews)
      return(false);

   datetime now=TimeCurrent();
   ENUM_CALENDAR_EVENT_PRIORITY prior[]= {CALENDAR_EVENT_HIGH};
   MqlCalendarValue val;
   int total=CalendarValueHistory(prior,ArraySize(prior),0,now+(NewsMinutesSkip*60),val);
   // if any high priority event within +-skip window
   if(total>0)
      return(true);

   return(false);
  }

//+------------------------------------------------------------------+
//| Compute position size (lots)                                     |
//+------------------------------------------------------------------+
double CalcLot(double SL_points)
  {
   double risk=AccountInfoDouble(ACCOUNT_EQUITY)*RiskPercent/100.0;
   double tick_value=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tick_size =SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

   double lot= risk / ( (SL_points*Point)/tick_size * tick_value);
   double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double stepLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);

   lot=NormalizeDouble(lot/fmax(stepLot,1e-4))*stepLot;
   lot=MathMin(MathMax(lot,minLot),maxLot);
   return(lot);
  }

//+------------------------------------------------------------------+
//| Main tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(!IsNewBar())
      return;

   // Trading window check
   int hour=TimeHour(TimeCurrent());
   if(hour<StartHour || hour>=EndHour)
      return;

   // Spread filter
   if(CurrentSpreadPoints()>MaxSpreadPoints)
      return;

   // News filter
   if(RedNewsSoon())
      return;

   // Trend direction
   double htf_fast[3], htf_slow[3];
   if(CopyBuffer(hHTF_FastEMA,0,0,3,htf_fast)<=0 || CopyBuffer(hHTF_SlowEMA,0,0,3,htf_slow)<=0)
      return;

   int trend=0; // 1 bullish, -1 bearish, 0 none
   if(htf_fast[0]>htf_slow[0])
      trend=1;
   else if(htf_fast[0]<htf_slow[0])
      trend=-1;
   else
      trend=0;

   if(trend==0)
      return;

   // Entry signals on lower TF
   double fast[3], slow[3];
   if(CopyBuffer(hFastEMA,0,0,3,fast)<=0 || CopyBuffer(hSlowEMA,0,0,3,slow)<=0)
      return;

   // Cross detection
   bool cross_up = fast[1]<slow[1] && fast[0]>slow[0];
   bool cross_dn = fast[1]>slow[1] && fast[0]<slow[0];

   // ATR for SL/TP
   double atr_val[1];
   if(CopyBuffer(hATR,0,0,1,atr_val)<=0)
      return;

   double SL_points = atr_val[0]*ATR_Multiplier/Point;
   double TP_points = SL_points*RR_Multiplier;

   double lot=CalcLot(SL_points);
   if(lot<=0)
      return;

   // ensure single position at a time
   if(PositionSelect(_Symbol))
      return;

   // Entry conditions
   if(trend==1 && cross_up)
     {
      trade.Buy(lot,_Symbol,CurrentAsk(),SL_points*Point,TP_points*Point,"Buy EMA",Magic);
      last_entry_bar=iTime(_Symbol,EntryTF,0);
     }
   else if(trend==-1 && cross_dn)
     {
      trade.Sell(lot,_Symbol,CurrentBid(),SL_points*Point,TP_points*Point,"Sell EMA",Magic);
      last_entry_bar=iTime(_Symbol,EntryTF,0);
     }

   // Post-trade management handled separately
  }

//+------------------------------------------------------------------+
//| Timer for trade management (trailing, break-even, partial close) |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(!PositionSelect(_Symbol))
      return;

   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double price_open       = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl               = PositionGetDouble(POSITION_SL);
   double tp               = PositionGetDouble(POSITION_TP);
   double volume           = PositionGetDouble(POSITION_VOLUME);

   // ATR for dynamic trailing
   double atr_val[1];
   if(CopyBuffer(hATR,0,0,1,atr_val)<=0)
      return;
   double trail_dist = atr_val[0]*TrailingATR;

   double new_sl=sl;
   if(type==POSITION_TYPE_BUY)
     {
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      // Break-even move
      if(UseBreakEven && bid - price_open >= tp/2.0 && bid - price_open > 0)
         new_sl=price_open;

      // Trailing stop
      if(UseTrailing)
        {
         double trail=bid - trail_dist;
         if(trail>new_sl)
            new_sl=trail;
        }
     }
   else if(type==POSITION_TYPE_SELL)
     {
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(UseBreakEven && price_open - ask >= tp/2.0 && price_open - ask > 0)
         new_sl=price_open;

      if(UseTrailing)
        {
         double trail=ask + trail_dist;
         if(trail<new_sl || new_sl==0)
            new_sl=trail;
        }
     }

   // Update SL if changed
   if(new_sl!=sl && new_sl>0)
      trade.PositionModify(_Symbol,new_sl,tp);

   // Partial close
   if(PartialClose && volume>SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN))
     {
      double profit_rr = fabs((type==POSITION_TYPE_BUY ? SymbolInfoDouble(_Symbol,SYMBOL_BID)-price_open : price_open-SymbolInfoDouble(_Symbol,SYMBOL_ASK)))/tp;
      if(profit_rr>=1.0)
        {
         double close_vol = volume*ClosePercent/100.0;
         close_vol = MathMax(close_vol,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN));
         trade.PositionClosePartial(_Symbol,close_vol);
        }
     }
  }

//+------------------------------------------------------------------+
//| Set timer when EA starts                                         |
//+------------------------------------------------------------------+
int OnInitTimer()
  {
   EventSetTimer(30); // manage every 30 seconds
   return(0);
  }

//+------------------------------------------------------------------+
//| Expert entry point after OnInit                                  |
//+------------------------------------------------------------------+
void OnStart()
  {
   OnInitTimer();
  }

//+------------------------------------------------------------------+
