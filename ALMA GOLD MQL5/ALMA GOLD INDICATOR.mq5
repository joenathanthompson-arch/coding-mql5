//+------------------------------------------------------------------+
//|                                           IB ALMA Combined.mq5 |
//|                                    Copyright 2025, JNTFX TRADER |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, JNTFX TRADER"
#property link      ""
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

//--- Plot Fast ALMA (matches EA)
#property indicator_label1  "Fast ALMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrWhite
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot Slow ALMA (matches EA)
#property indicator_label2  "Slow ALMA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Plot Buy Signals
#property indicator_label3  "Buy Signals"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrLimeGreen
#property indicator_width3  3

//--- Plot Sell Signals
#property indicator_label4  "Sell Signals"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_width4  3

//+------------------------------------------------------------------+
//| Input Parameters - MATCH EA EXACTLY                            |
//+------------------------------------------------------------------+

//--- General Settings
input group "=== GENERAL SETTINGS ==="
input ENUM_TIMEFRAMES IndicatorTimeframe = PERIOD_M5; // Indicator Timeframe
input int TerminalTimezoneOffset = 0; // Terminal Timezone Offset from GMT (hours)
input int BarsToShow = 2000; // Historical bars to show

//--- ALMA Settings (EXACTLY MATCH EA)
input group "=== ALMA SETTINGS (MATCH EA) ==="
input ENUM_APPLIED_PRICE FastPriceSource = PRICE_MEDIAN; // Fast Price Source (EA: PRICE_MEDIAN)
input int FastWindowSize = 9; // Fast Window Size (EA: 9)
input double FastOffset = 0.85; // Fast Offset (EA: 0.85)
input double FastSigma = 6.0; // Fast Sigma (EA: 6.0)

input ENUM_APPLIED_PRICE SlowPriceSource = PRICE_MEDIAN; // Slow Price Source (EA: PRICE_MEDIAN)
input int SlowWindowSize = 50; // Slow Window Size (EA: 50)
input double SlowOffset = 0.85; // Slow Offset (EA: 0.85)
input double SlowSigma = 6.0; // Slow Sigma (EA: 6.0)

input bool ShowALMALines = false; // Show ALMA Lines on Chart (Default: OFF)

//--- Trading Logic Settings (MATCH EA)
input group "=== TRADING LOGIC (MATCH EA) ==="
input int IBRangeThreshold = 1000; // IB Range threshold in points (EA: 1000)
input double MaxSpreadPoints = 100.0; // Maximum spread allowed (EA uses this)

//--- IB Session Settings (MATCH EA)
input group "=== IB SESSION SETTINGS (MATCH EA) ==="
input bool ShowTokyo = true; // Show Tokyo Session
input color TokyoColor = clrYellow; // Tokyo Color
input bool ShowLondon = true; // Show London Session
input color LondonColor = clrOrange; // London Color
input bool ShowNewYork = true; // Show New York Session
input color NewYorkColor = clrMediumOrchid; // New York Color

//--- IB Session Times (MATCH EA EXACTLY)
input group "=== SESSION TIMES (GMT - MATCH EA) ==="
input int TokyoStartHour = 3; // Tokyo Start Hour (EA: 3)
input int TokyoEndHour = 12; // Tokyo End Hour (EA: 12)
input int TokyoIBEndHour = 4; // Tokyo IB End Hour (EA: 4)
input int LondonStartHour = 10; // London Start Hour (EA: 10)
input int LondonEndHour = 18; // London End Hour (EA: 18)
input int LondonIBEndHour = 11; // London IB End Hour (EA: 11)
input int NewYorkStartHour = 15; // New York Start Hour (EA: 15)
input int NewYorkEndHour = 0; // New York End Hour (EA: 0 = midnight)
input int NewYorkIBEndHour = 16; // New York IB End Hour (EA: 16)

//--- IB Display Settings
input group "=== IB DISPLAY SETTINGS ==="
input bool ShowIBBoxes = true; // Show IB Boxes
input bool ShowIBLines = true; // Show IB Lines
input bool ShowExtensions = true; // Show Extension Lines
input bool ShowLabels = true; // Show Info Labels
input bool ShowTradeSignals = true; // Show Trade Arrows
input int IBBoxOpacity = 70; // IB Box Opacity (0-100)
input int PastSessionOpacity = 40; // Past Session Opacity (0-100)
input double RoundTripThreshold = 60.0; // Round Trip Threshold %
input int MaxSessionsToShow = 5; // Maximum sessions to display (increased for more history)
input double DollarPerPoint = 10.0; // Dollar value per point for range calculation

//--- Extension Levels
input group "=== EXTENSION LEVELS ==="
input double Extension1x = 1.0; // Extension 1x Multiplier
input double Extension2x = 2.0; // Extension 2x Multiplier
input double Extension3x = 3.0; // Extension 3x Multiplier
input double Extension4x = 4.0; // Extension 4x Multiplier

//+------------------------------------------------------------------+
//| Session Data Structure                                           |
//+------------------------------------------------------------------+
struct SessionInfo
{
    bool enabled;
    color session_color;
    string name;
    int start_hour, end_hour, ib_end_hour;

    double ib_high, ib_low, ib_range;
    datetime ib_start_time, ib_end_time;
    bool ib_active;

    datetime session_starts[];
    double session_highs[], session_lows[];
    double session_ranges[];

    int total_sessions, round_trips;
    double total_ib_range;
    bool high_broken, low_broken, rt_counted;

    int recent_session_count;
};

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
double FastALMABuffer[];
double SlowALMABuffer[];
double BuySignalBuffer[];
double SellSignalBuffer[];

SessionInfo TokyoSession, LondonSession, NewYorkSession;
double fast_alma_weights[], slow_alma_weights[];

//+------------------------------------------------------------------+
//| Function prototypes                                              |
//+------------------------------------------------------------------+
void InitSession(SessionInfo &session, bool enabled, color clr, string name, int start_h, int end_h, int ib_end_h);
void ResetCurrentSession(SessionInfo &session);
int FindTimeframeBar(datetime current_time, const datetime &tf_time[], int tf_size);
double CalculateALMA(ENUM_APPLIED_PRICE priceType, int period, const double &weights[], int shift, const double &open[], const double &high[], const double &low[], const double &close[]);
double GetAppliedPrice(ENUM_APPLIED_PRICE price_type, int pos, const double &open[], const double &high[], const double &low[], const double &close[]);
void ProcessBar(datetime bar_time, double bar_high, double bar_low);
void ProcessSessionBar(SessionInfo &session, int terminal_hour, datetime bar_time, double bar_high, double bar_low);
int ConvertGMTToTerminalHour(int gmt_hour);
bool IsInTimeRange(int terminal_hour, int gmt_start_hour, int gmt_end_hour);
void StartIBPeriod(SessionInfo &session, datetime bar_time, double bar_high, double bar_low);
void UpdateIBPeriod(SessionInfo &session, datetime bar_time, double bar_high, double bar_low);
void EndIBPeriod(SessionInfo &session, datetime bar_time);
void AddToSessionHistory(SessionInfo &session);
void LimitSessionDisplay(SessionInfo &session);
void TrackRoundTrips(SessionInfo &session, double bar_high, double bar_low);
bool IsCurrentSession(SessionInfo &session);
void CreateIBBox(SessionInfo &session, datetime start_time);
void UpdateIBBox(SessionInfo &session, datetime current_time);
void DrawIBLines(SessionInfo &session);
void DrawExtensions(SessionInfo &session);
void CreateInfoLabel(SessionInfo &session);
double GetRoundTripPercentage(SessionInfo &session);
void RemoveSessionVisuals(SessionInfo &session, datetime session_time);
void CleanupObjects();
void PrintSettings();
void InitializeALMAWeights();
SessionInfo GetPrioritySession(datetime bar_time);
bool ShouldGenerateBuySignal(int pos, SessionInfo &priority_session, const double &high[], const double &low[], const double &close[]);
bool ShouldGenerateSellSignal(int pos, SessionInfo &priority_session, const double &high[], const double &low[], const double &close[]);
bool IsLargeRangeMeanReversion(SessionInfo &session, double current_price);
bool IsSmallRangeBreakout(SessionInfo &session, double current_price);
bool ShouldGenerateSignalBasedOnStrategy(SessionInfo &session, double current_price, bool is_buy);

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Validate inputs
    if(FastWindowSize < 1 || SlowWindowSize < 1)
    {
        Print("Error: Window sizes must be greater than 0");
        return(INIT_PARAMETERS_INCORRECT);
    }

    if(FastSigma <= 0 || SlowSigma <= 0)
    {
        Print("Error: Sigma values must be greater than 0");
        return(INIT_PARAMETERS_INCORRECT);
    }

    //--- Set array as series
    ArraySetAsSeries(FastALMABuffer, true);
    ArraySetAsSeries(SlowALMABuffer, true);
    ArraySetAsSeries(BuySignalBuffer, true);
    ArraySetAsSeries(SellSignalBuffer, true);

    //--- Set indicator buffers
    SetIndexBuffer(0, FastALMABuffer, INDICATOR_DATA);
    SetIndexBuffer(1, SlowALMABuffer, INDICATOR_DATA);
    SetIndexBuffer(2, BuySignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, SellSignalBuffer, INDICATOR_DATA);

    //--- Set arrow codes
    PlotIndexSetInteger(2, PLOT_ARROW, 233); // Up arrow for buy
    PlotIndexSetInteger(3, PLOT_ARROW, 234); // Down arrow for sell

    //--- Initialize ALMA weights (EXACTLY like EA)
    InitializeALMAWeights();

    //--- Initialize sessions (EXACTLY like EA)
    InitSession(TokyoSession, ShowTokyo, TokyoColor, "Tokyo",
                TokyoStartHour, TokyoEndHour, TokyoIBEndHour);
    InitSession(LondonSession, ShowLondon, LondonColor, "London",
                LondonStartHour, LondonEndHour, LondonIBEndHour);
    InitSession(NewYorkSession, ShowNewYork, NewYorkColor, "NewYork",
                NewYorkStartHour, NewYorkEndHour, NewYorkIBEndHour);

    //--- Clean up objects and set indicator properties
    CleanupObjects();
    IndicatorSetString(INDICATOR_SHORTNAME, "IB ALMA EA Signals");
    IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

    //--- Set empty values
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);

    PrintSettings();
    Print("IB ALMA EA Signals Indicator initialized - Matches EA exactly");

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Initialize ALMA weights exactly like EA                         |
//+------------------------------------------------------------------+
void InitializeALMAWeights()
{
    // Fast ALMA weights (exactly like EA)
    ArrayResize(fast_alma_weights, FastWindowSize);
    double m_fast = FastOffset * (FastWindowSize - 1);
    double s_fast = FastWindowSize / FastSigma;
    double norm_fast = 0.0;

    for(int i = 0; i < FastWindowSize; i++)
    {
        fast_alma_weights[i] = MathExp(-1 * MathPow(i - m_fast, 2) / (2 * MathPow(s_fast, 2)));
        norm_fast += fast_alma_weights[i];
    }

    for(int i = 0; i < FastWindowSize; i++)
    {
        fast_alma_weights[i] /= norm_fast;
    }

    // Slow ALMA weights (exactly like EA)
    ArrayResize(slow_alma_weights, SlowWindowSize);
    double m_slow = SlowOffset * (SlowWindowSize - 1);
    double s_slow = SlowWindowSize / SlowSigma;
    double norm_slow = 0.0;

    for(int i = 0; i < SlowWindowSize; i++)
    {
        slow_alma_weights[i] = MathExp(-1 * MathPow(i - m_slow, 2) / (2 * MathPow(s_slow, 2)));
        norm_slow += slow_alma_weights[i];
    }

    for(int i = 0; i < SlowWindowSize; i++)
    {
        slow_alma_weights[i] /= norm_slow;
    }
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    CleanupObjects();
    Print("IB ALMA EA Signals Indicator removed");
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    //--- Check if we have enough data
    int minBars = MathMax(FastWindowSize, SlowWindowSize);
    if(rates_total < minBars)
        return(0);

    //--- Limit to BarsToShow for performance
    int bars_to_calculate = MathMin(rates_total, BarsToShow);

    //--- Set arrays as series for price data access
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(time, true);

    //--- Calculate start position
    int start = prev_calculated;
    if(start < minBars)
        start = minBars;

    //--- Main calculation loop
    for(int i = start; i < rates_total; i++)
    {
        int pos = rates_total - 1 - i;

        //--- Calculate ALMA values for signals and conditionally for display
        double current_fast_alma = EMPTY_VALUE;
        double current_slow_alma = EMPTY_VALUE;

        if(pos + MathMax(FastWindowSize, SlowWindowSize) >= rates_total)
        {
            FastALMABuffer[pos] = EMPTY_VALUE;
            SlowALMABuffer[pos] = EMPTY_VALUE;
        }
        else
        {
            // Always calculate ALMA values for signal generation
            current_fast_alma = CalculateALMA(FastPriceSource, FastWindowSize, fast_alma_weights, pos, open, high, low, close);
            current_slow_alma = CalculateALMA(SlowPriceSource, SlowWindowSize, slow_alma_weights, pos, open, high, low, close);

            // Set buffer values based on ShowALMALines parameter
            if(ShowALMALines)
            {
                FastALMABuffer[pos] = current_fast_alma;
                SlowALMABuffer[pos] = current_slow_alma;
            }
            else
            {
                FastALMABuffer[pos] = EMPTY_VALUE;
                SlowALMABuffer[pos] = EMPTY_VALUE;
            }
        }

        //--- Initialize signal buffers
        BuySignalBuffer[pos] = EMPTY_VALUE;
        SellSignalBuffer[pos] = EMPTY_VALUE;

        //--- Process IB sessions for graphics
        ProcessBar(time[pos], high[pos], low[pos]);

        //--- Generate trading signals (use calculated values, not buffer display values)
        if(ShowTradeSignals && pos > 0 && current_fast_alma != EMPTY_VALUE && current_slow_alma != EMPTY_VALUE)
        {
            SessionInfo priority_session = GetPrioritySession(time[pos]);

            // Check for crossover signals using calculated values
            bool fast_above_slow = current_fast_alma > current_slow_alma;

            // Get previous values (handle both display modes)
            double prev_fast = EMPTY_VALUE;
            double prev_slow = EMPTY_VALUE;
            if(pos < rates_total - 1)
            {
                if(ShowALMALines)
                {
                    prev_fast = FastALMABuffer[pos + 1];
                    prev_slow = SlowALMABuffer[pos + 1];
                }
                else
                {
                    // Calculate previous values when lines are hidden
                    prev_fast = CalculateALMA(FastPriceSource, FastWindowSize, fast_alma_weights, pos + 1, open, high, low, close);
                    prev_slow = CalculateALMA(SlowPriceSource, SlowWindowSize, slow_alma_weights, pos + 1, open, high, low, close);
                }
            }
            bool prev_fast_above_slow = (prev_fast != EMPTY_VALUE && prev_slow != EMPTY_VALUE) ? prev_fast > prev_slow : fast_above_slow;

            // Buy signal: Fast crosses above Slow
            if(fast_above_slow && !prev_fast_above_slow)
            {
                if(priority_session.ib_range > 0) // Only if we have session data
                {
                    if(ShouldGenerateSignalBasedOnStrategy(priority_session, close[pos], true))
                    {
                        BuySignalBuffer[pos] = low[pos] - 10 * _Point;
                        Print("BUY signal at ", TimeToString(time[pos]), " Price: ", close[pos],
                              " Session: ", priority_session.name, " Range: ", priority_session.ib_range/_Point, " pts");
                    }
                    else
                    {
                        Print("BUY crossover but strategy filtered at ", TimeToString(time[pos]));
                    }
                }
                else
                {
                    Print("BUY crossover but no session data at ", TimeToString(time[pos]));
                }
            }

            // Sell signal: Fast crosses below Slow
            if(!fast_above_slow && prev_fast_above_slow)
            {
                if(priority_session.ib_range > 0) // Only if we have session data
                {
                    if(ShouldGenerateSignalBasedOnStrategy(priority_session, close[pos], false))
                    {
                        SellSignalBuffer[pos] = high[pos] + 10 * _Point;
                        Print("SELL signal at ", TimeToString(time[pos]), " Price: ", close[pos],
                              " Session: ", priority_session.name, " Range: ", priority_session.ib_range/_Point, " pts");
                    }
                    else
                    {
                        Print("SELL crossover but strategy filtered at ", TimeToString(time[pos]));
                    }
                }
                else
                {
                    Print("SELL crossover but no session data at ", TimeToString(time[pos]));
                }
            }
        }
    }

    return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate ALMA exactly like EA                                  |
//+------------------------------------------------------------------+
double CalculateALMA(ENUM_APPLIED_PRICE priceType, int period, const double &weights[], int shift,
                   const double &open[], const double &high[], const double &low[], const double &close[])
{
    if(shift + period > ArraySize(close))
        return(EMPTY_VALUE);

    double sum = 0.0;

    for(int i = 0; i < period; i++)
    {
        if(shift + i >= ArraySize(close))
            break;

        double price = GetAppliedPrice(priceType, shift + i, open, high, low, close);
        sum += weights[i] * price;
    }

    return(sum);
}

//+------------------------------------------------------------------+
//| Get Priority Session (copy EA logic)                           |
//+------------------------------------------------------------------+
SessionInfo GetPrioritySession(datetime bar_time)
{
    MqlDateTime time_struct;
    TimeToStruct(bar_time, time_struct);

    // Check which session is active and has range data (EA priority logic)
    if(NewYorkSession.enabled && IsInTimeRange(time_struct.hour, NewYorkSession.start_hour, NewYorkSession.end_hour))
    {
        if(NewYorkSession.ib_range > 0 || ArraySize(NewYorkSession.session_ranges) > 0)
            return NewYorkSession;
    }

    if(LondonSession.enabled && IsInTimeRange(time_struct.hour, LondonSession.start_hour, LondonSession.end_hour))
    {
        if(LondonSession.ib_range > 0 || ArraySize(LondonSession.session_ranges) > 0)
            return LondonSession;
    }

    if(TokyoSession.enabled && IsInTimeRange(time_struct.hour, TokyoSession.start_hour, TokyoSession.end_hour))
    {
        if(TokyoSession.ib_range > 0 || ArraySize(TokyoSession.session_ranges) > 0)
            return TokyoSession;
    }

    // Return most recent session with data
    if(ArraySize(NewYorkSession.session_ranges) > 0)
        return NewYorkSession;
    else if(ArraySize(LondonSession.session_ranges) > 0)
        return LondonSession;
    else if(ArraySize(TokyoSession.session_ranges) > 0)
        return TokyoSession;

    // Default to NewYork
    return NewYorkSession;
}

//+------------------------------------------------------------------+
//| Should Generate Buy Signal (copy EA logic exactly)             |
//+------------------------------------------------------------------+
bool ShouldGenerateBuySignal(int pos, SessionInfo &priority_session, const double &high[], const double &low[], const double &close[])
{
    if(pos >= ArraySize(FastALMABuffer) - 1 || pos >= ArraySize(SlowALMABuffer) - 1)
        return false;

    // Check ALMA crossover (Fast above Slow)
    if(FastALMABuffer[pos] <= SlowALMABuffer[pos])
        return false;

    // Check if this is a new crossover
    if(pos > 0 && FastALMABuffer[pos + 1] > SlowALMABuffer[pos + 1])
        return false; // Already crossed

    double current_price = close[pos];

    // Apply EA trading logic
    if(priority_session.ib_range > IBRangeThreshold)
    {
        // Large Range Mean Reversion
        return IsLargeRangeMeanReversion(priority_session, current_price);
    }
    else
    {
        // Small Range Breakout
        return IsSmallRangeBreakout(priority_session, current_price);
    }
}

//+------------------------------------------------------------------+
//| Should Generate Sell Signal (copy EA logic exactly)            |
//+------------------------------------------------------------------+
bool ShouldGenerateSellSignal(int pos, SessionInfo &priority_session, const double &high[], const double &low[], const double &close[])
{
    if(pos >= ArraySize(FastALMABuffer) - 1 || pos >= ArraySize(SlowALMABuffer) - 1)
        return false;

    // Check ALMA crossunder (Fast below Slow)
    if(FastALMABuffer[pos] >= SlowALMABuffer[pos])
        return false;

    // Check if this is a new crossunder
    if(pos > 0 && FastALMABuffer[pos + 1] < SlowALMABuffer[pos + 1])
        return false; // Already crossed

    double current_price = close[pos];

    // Apply EA trading logic
    if(priority_session.ib_range > IBRangeThreshold)
    {
        // Large Range Mean Reversion
        return IsLargeRangeMeanReversion(priority_session, current_price);
    }
    else
    {
        // Small Range Breakout
        return IsSmallRangeBreakout(priority_session, current_price);
    }
}

//+------------------------------------------------------------------+
//| Large Range Mean Reversion Logic (copy from EA)                |
//+------------------------------------------------------------------+
bool IsLargeRangeMeanReversion(SessionInfo &session, double current_price)
{
    if(session.ib_range <= 0) return false;

    double ib_mid = (session.ib_high + session.ib_low) / 2.0;
    double upper_threshold = ib_mid + (session.ib_range * 0.3); // 30% into upper half
    double lower_threshold = ib_mid - (session.ib_range * 0.3); // 30% into lower half

    // Mean reversion when price is in extreme areas
    return (current_price >= upper_threshold || current_price <= lower_threshold);
}

//+------------------------------------------------------------------+
//| Small Range Breakout Logic (copy from EA)                      |
//+------------------------------------------------------------------+
bool IsSmallRangeBreakout(SessionInfo &session, double current_price)
{
    if(session.ib_range <= 0) return false;

    // Breakout when price is near IB levels
    double breakout_buffer = session.ib_range * 0.1; // 10% buffer

    return (current_price >= (session.ib_high - breakout_buffer) ||
            current_price <= (session.ib_low + breakout_buffer));
}

//+------------------------------------------------------------------+
//| Simplified signal generation based on strategy                  |
//+------------------------------------------------------------------+
bool ShouldGenerateSignalBasedOnStrategy(SessionInfo &session, double current_price, bool is_buy)
{
    if(session.ib_range <= 0) return false;

    double range_points = session.ib_range / _Point;

    if(range_points >= IBRangeThreshold)
    {
        // Large Range Mean Reversion
        return IsLargeRangeMeanReversion(session, current_price);
    }
    else
    {
        // Small Range Breakout
        return IsSmallRangeBreakout(session, current_price);
    }
}

//+------------------------------------------------------------------+
//| Initialize session structure                                     |
//+------------------------------------------------------------------+
void InitSession(SessionInfo &session, bool enabled, color clr, string name,
                int start_h, int end_h, int ib_end_h)
{
    session.enabled = enabled;
    session.session_color = clr;
    session.name = name;
    session.start_hour = start_h;
    session.end_hour = end_h;
    session.ib_end_hour = ib_end_h;

    ArrayResize(session.session_starts, 0);
    ArrayResize(session.session_highs, 0);
    ArrayResize(session.session_lows, 0);
    ArrayResize(session.session_ranges, 0);

    ResetCurrentSession(session);
    session.recent_session_count = 0;
}

//+------------------------------------------------------------------+
//| Reset current session variables                                 |
//+------------------------------------------------------------------+
void ResetCurrentSession(SessionInfo &session)
{
    session.ib_high = 0;
    session.ib_low = 0;
    session.ib_range = 0;
    session.ib_active = false;
    session.high_broken = false;
    session.low_broken = false;
    session.rt_counted = false;
}

//+------------------------------------------------------------------+
//| Find corresponding timeframe bar                                |
//+------------------------------------------------------------------+
int FindTimeframeBar(datetime current_time, const datetime &tf_time[], int tf_size)
{
    for(int i = 0; i < tf_size; i++)
    {
        if(tf_time[i] <= current_time)
            return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Get applied price value                                         |
//+------------------------------------------------------------------+
double GetAppliedPrice(ENUM_APPLIED_PRICE price_type, int pos,
                     const double &open[], const double &high[],
                     const double &low[], const double &close[])
{
    switch(price_type)
    {
        case PRICE_OPEN: return(open[pos]);
        case PRICE_HIGH: return(high[pos]);
        case PRICE_LOW: return(low[pos]);
        case PRICE_CLOSE: return(close[pos]);
        case PRICE_MEDIAN: return((high[pos] + low[pos]) / 2.0);
        case PRICE_TYPICAL: return((high[pos] + low[pos] + close[pos]) / 3.0);
        case PRICE_WEIGHTED: return((high[pos] + low[pos] + close[pos] + close[pos]) / 4.0);
        default: return(close[pos]);
    }
}

//+------------------------------------------------------------------+
//| Process individual bar for all sessions                         |
//+------------------------------------------------------------------+
void ProcessBar(datetime bar_time, double bar_high, double bar_low)
{
    MqlDateTime time_struct;
    TimeToStruct(bar_time, time_struct);

    if(TokyoSession.enabled)
        ProcessSessionBar(TokyoSession, time_struct.hour, bar_time, bar_high, bar_low);

    if(LondonSession.enabled)
        ProcessSessionBar(LondonSession, time_struct.hour, bar_time, bar_high, bar_low);

    if(NewYorkSession.enabled)
        ProcessSessionBar(NewYorkSession, time_struct.hour, bar_time, bar_high, bar_low);
}

//+------------------------------------------------------------------+
//| Process bar for specific session                                |
//+------------------------------------------------------------------+
void ProcessSessionBar(SessionInfo &session, int terminal_hour, datetime bar_time,
                     double bar_high, double bar_low)
{
    bool is_in_ib = IsInTimeRange(terminal_hour, session.start_hour, session.ib_end_hour);
    bool is_in_session = IsInTimeRange(terminal_hour, session.start_hour, session.end_hour);

    if(is_in_ib && !session.ib_active)
    {
        StartIBPeriod(session, bar_time, bar_high, bar_low);
    }

    if(is_in_ib && session.ib_active)
    {
        UpdateIBPeriod(session, bar_time, bar_high, bar_low);
    }

    if(!is_in_ib && session.ib_active)
    {
        EndIBPeriod(session, bar_time);
    }

    if(is_in_session && !is_in_ib && session.ib_range > 0)
    {
        TrackRoundTrips(session, bar_high, bar_low);
    }

    if(!is_in_session && ArraySize(session.session_starts) > 0)
    {
        ResetCurrentSession(session);
    }
}

//+------------------------------------------------------------------+
//| Convert GMT hour to terminal timezone hour                      |
//+------------------------------------------------------------------+
int ConvertGMTToTerminalHour(int gmt_hour)
{
    int terminal_hour = gmt_hour + TerminalTimezoneOffset;
    if(terminal_hour >= 24) terminal_hour -= 24;
    if(terminal_hour < 0) terminal_hour += 24;
    return terminal_hour;
}

//+------------------------------------------------------------------+
//| Check if hour is in time range                                  |
//+------------------------------------------------------------------+
bool IsInTimeRange(int terminal_hour, int gmt_start_hour, int gmt_end_hour)
{
    int start_hour = ConvertGMTToTerminalHour(gmt_start_hour);
    int end_hour = ConvertGMTToTerminalHour(gmt_end_hour);

    if(start_hour <= end_hour)
    {
        return (terminal_hour >= start_hour && terminal_hour < end_hour);
    }
    else
    {
        return (terminal_hour >= start_hour || terminal_hour < end_hour);
    }
}

//+------------------------------------------------------------------+
//| Start IB period tracking                                        |
//+------------------------------------------------------------------+
void StartIBPeriod(SessionInfo &session, datetime bar_time, double bar_high, double bar_low)
{
    session.ib_high = bar_high;
    session.ib_low = bar_low;
    session.ib_start_time = bar_time;
    session.ib_active = true;

    if(ShowIBBoxes)
    {
        CreateIBBox(session, bar_time);
    }
}

//+------------------------------------------------------------------+
//| Update IB period with current bar                               |
//+------------------------------------------------------------------+
void UpdateIBPeriod(SessionInfo &session, datetime bar_time, double bar_high, double bar_low)
{
    bool updated = false;

    if(bar_high > session.ib_high)
    {
        session.ib_high = bar_high;
        updated = true;
    }

    if(bar_low < session.ib_low)
    {
        session.ib_low = bar_low;
        updated = true;
    }

    session.ib_range = session.ib_high - session.ib_low;

    if(updated && ShowIBBoxes)
    {
        UpdateIBBox(session, bar_time);
    }
}

//+------------------------------------------------------------------+
//| End IB period and finalize calculations                         |
//+------------------------------------------------------------------+
void EndIBPeriod(SessionInfo &session, datetime bar_time)
{
    session.ib_range = session.ib_high - session.ib_low;
    session.ib_end_time = bar_time;
    session.ib_active = false;

    AddToSessionHistory(session);

    session.total_sessions++;
    session.total_ib_range += session.ib_range;

    session.recent_session_count++;

    if(ShowIBLines)
        DrawIBLines(session);

    if(ShowExtensions)
        DrawExtensions(session);

    if(ShowLabels)
        CreateInfoLabel(session);
}

//+------------------------------------------------------------------+
//| Add session to history arrays                                   |
//+------------------------------------------------------------------+
void AddToSessionHistory(SessionInfo &session)
{
    int size = ArraySize(session.session_starts);

    ArrayResize(session.session_starts, size + 1);
    ArrayResize(session.session_highs, size + 1);
    ArrayResize(session.session_lows, size + 1);
    ArrayResize(session.session_ranges, size + 1);

    session.session_starts[size] = session.ib_start_time;
    session.session_highs[size] = session.ib_high;
    session.session_lows[size] = session.ib_low;
    session.session_ranges[size] = session.ib_range;

    if(size >= MaxSessionsToShow)
    {
        LimitSessionDisplay(session);
    }
}

//+------------------------------------------------------------------+
//| Limit displayed sessions to maximum                             |
//+------------------------------------------------------------------+
void LimitSessionDisplay(SessionInfo &session)
{
    int current_size = ArraySize(session.session_starts);

    if(current_size > MaxSessionsToShow)
    {
        int excess = current_size - MaxSessionsToShow;

        for(int i = 0; i < excess; i++)
        {
            RemoveSessionVisuals(session, session.session_starts[i]);
        }

        for(int i = 0; i < MaxSessionsToShow; i++)
        {
            session.session_starts[i] = session.session_starts[i + excess];
            session.session_highs[i] = session.session_highs[i + excess];
            session.session_lows[i] = session.session_lows[i + excess];
            session.session_ranges[i] = session.session_ranges[i + excess];
        }

        ArrayResize(session.session_starts, MaxSessionsToShow);
        ArrayResize(session.session_highs, MaxSessionsToShow);
        ArrayResize(session.session_lows, MaxSessionsToShow);
        ArrayResize(session.session_ranges, MaxSessionsToShow);
    }
}

//+------------------------------------------------------------------+
//| Track round trips during session                                |
//+------------------------------------------------------------------+
void TrackRoundTrips(SessionInfo &session, double bar_high, double bar_low)
{
    if(ArraySize(session.session_starts) == 0) return;

    int last_idx = ArraySize(session.session_starts) - 1;
    double ib_high = session.session_highs[last_idx];
    double ib_low = session.session_lows[last_idx];

    if(bar_high > ib_high)
        session.high_broken = true;
    if(bar_low < ib_low)
        session.low_broken = true;

    if(session.high_broken && session.low_broken && !session.rt_counted)
    {
        session.round_trips++;
        session.rt_counted = true;
    }
}

//+------------------------------------------------------------------+
//| Check if session is currently active                            |
//+------------------------------------------------------------------+
bool IsCurrentSession(SessionInfo &session)
{
    MqlDateTime current_time;
    TimeToStruct(TimeCurrent(), current_time);

    return IsInTimeRange(current_time.hour, session.start_hour, session.end_hour);
}

//+------------------------------------------------------------------+
//| Create IB box covering entire IB period                         |
//+------------------------------------------------------------------+
void CreateIBBox(SessionInfo &session, datetime start_time)
{
    MqlDateTime start_struct;
    TimeToStruct(start_time, start_struct);

    MqlDateTime end_struct = start_struct;
    int terminal_ib_end_hour = ConvertGMTToTerminalHour(session.ib_end_hour);
    end_struct.hour = terminal_ib_end_hour;
    end_struct.min = 0;
    end_struct.sec = 0;

    if(terminal_ib_end_hour < start_struct.hour)
    {
        end_struct.day++;
    }

    datetime ib_end_time = StructToTime(end_struct);

    string box_name = session.name + "_Box_" + IntegerToString(start_time);

    ObjectDelete(0, box_name);

    if(!ObjectCreate(0, box_name, OBJ_RECTANGLE, 0, start_time, session.ib_high,
                    ib_end_time, session.ib_low))
    {
        return;
    }

    bool is_current = IsCurrentSession(session);

    ObjectSetInteger(0, box_name, OBJPROP_COLOR, session.session_color);
    ObjectSetInteger(0, box_name, OBJPROP_BGCOLOR, session.session_color);
    ObjectSetInteger(0, box_name, OBJPROP_FILL, true);
    ObjectSetInteger(0, box_name, OBJPROP_BACK, true);
    ObjectSetInteger(0, box_name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, box_name, OBJPROP_HIDDEN, false);

    if(is_current)
    {
        ObjectSetInteger(0, box_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, box_name, OBJPROP_WIDTH, 2);
    }
    else
    {
        ObjectSetInteger(0, box_name, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, box_name, OBJPROP_WIDTH, 1);
    }
}

//+------------------------------------------------------------------+
//| Update IB box maintaining full period coverage                  |
//+------------------------------------------------------------------+
void UpdateIBBox(SessionInfo &session, datetime current_time)
{
    string box_name = session.name + "_Box_" + IntegerToString(session.ib_start_time);

    if(ObjectFind(0, box_name) >= 0)
    {
        MqlDateTime start_struct;
        TimeToStruct(session.ib_start_time, start_struct);

        MqlDateTime end_struct = start_struct;
        int terminal_ib_end_hour = ConvertGMTToTerminalHour(session.ib_end_hour);
        end_struct.hour = terminal_ib_end_hour;
        end_struct.min = 0;
        end_struct.sec = 0;

        if(terminal_ib_end_hour < start_struct.hour)
        {
            end_struct.day++;
        }

        datetime ib_end_time = StructToTime(end_struct);

        ObjectSetDouble(0, box_name, OBJPROP_PRICE, 0, session.ib_high);
        ObjectSetDouble(0, box_name, OBJPROP_PRICE, 1, session.ib_low);
        ObjectSetInteger(0, box_name, OBJPROP_TIME, 0, session.ib_start_time);
        ObjectSetInteger(0, box_name, OBJPROP_TIME, 1, ib_end_time);
    }
}

//+------------------------------------------------------------------+
//| Draw IB high/low lines                                          |
//+------------------------------------------------------------------+
void DrawIBLines(SessionInfo &session)
{
    string prefix = session.name + "_Line_" + IntegerToString(session.ib_start_time);
    datetime end_time = session.ib_end_time + 8 * 3600;

    bool is_current = IsCurrentSession(session);
    int line_width = is_current ? 2 : 1;
    ENUM_LINE_STYLE line_style = is_current ? STYLE_SOLID : STYLE_DOT;

    string high_line = prefix + "_High";
    if(ObjectCreate(0, high_line, OBJ_TREND, 0, session.ib_end_time, session.ib_high, end_time, session.ib_high))
    {
        ObjectSetInteger(0, high_line, OBJPROP_COLOR, session.session_color);
        ObjectSetInteger(0, high_line, OBJPROP_WIDTH, line_width);
        ObjectSetInteger(0, high_line, OBJPROP_STYLE, line_style);
        ObjectSetInteger(0, high_line, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, high_line, OBJPROP_RAY_LEFT, false);
        ObjectSetInteger(0, high_line, OBJPROP_SELECTABLE, false);
    }

    string low_line = prefix + "_Low";
    if(ObjectCreate(0, low_line, OBJ_TREND, 0, session.ib_end_time, session.ib_low, end_time, session.ib_low))
    {
        ObjectSetInteger(0, low_line, OBJPROP_COLOR, session.session_color);
        ObjectSetInteger(0, low_line, OBJPROP_WIDTH, line_width);
        ObjectSetInteger(0, low_line, OBJPROP_STYLE, line_style);
        ObjectSetInteger(0, low_line, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, low_line, OBJPROP_RAY_LEFT, false);
        ObjectSetInteger(0, low_line, OBJPROP_SELECTABLE, false);
    }
}

//+------------------------------------------------------------------+
//| Draw extension levels                                           |
//+------------------------------------------------------------------+
void DrawExtensions(SessionInfo &session)
{
    string prefix = session.name + "_Ext_" + IntegerToString(session.ib_start_time);
    datetime end_time = session.ib_end_time + 8 * 3600;
    double ib_range = session.ib_range;

    double extensions[4] = {Extension1x, Extension2x, Extension3x, Extension4x};
    string ext_names[4] = {"1x", "2x", "3x", "4x"};

    for(int i = 0; i < 4; i++)
    {
        string upper_name = prefix + "_" + ext_names[i] + "_Up";
        double upper_price = session.ib_high + ib_range * extensions[i];
        if(ObjectCreate(0, upper_name, OBJ_TREND, 0, session.ib_end_time, upper_price, end_time, upper_price))
        {
            ObjectSetInteger(0, upper_name, OBJPROP_COLOR, session.session_color);
            ObjectSetInteger(0, upper_name, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, upper_name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, upper_name, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, upper_name, OBJPROP_RAY_LEFT, false);
            ObjectSetInteger(0, upper_name, OBJPROP_SELECTABLE, false);
        }

        string lower_name = prefix + "_" + ext_names[i] + "_Down";
        double lower_price = session.ib_low - ib_range * extensions[i];
        if(ObjectCreate(0, lower_name, OBJ_TREND, 0, session.ib_end_time, lower_price, end_time, lower_price))
        {
            ObjectSetInteger(0, lower_name, OBJPROP_COLOR, session.session_color);
            ObjectSetInteger(0, lower_name, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, lower_name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, lower_name, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, lower_name, OBJPROP_RAY_LEFT, false);
            ObjectSetInteger(0, lower_name, OBJPROP_SELECTABLE, false);
        }
    }
}

//+------------------------------------------------------------------+
//| Create information label                                        |
//+------------------------------------------------------------------+
void CreateInfoLabel(SessionInfo &session)
{
    string label_name = session.name + "_Info_" + IntegerToString(session.ib_start_time);

    double rt_percentage = GetRoundTripPercentage(session);

    // Calculate range in points and determine trading mode based on range size
    double range_points = session.ib_range / _Point;
    string mode = (range_points >= IBRangeThreshold) ? "RT" : "BO";
    double range_dollars = range_points * DollarPerPoint;

    // Format: Session | Percent | RT/BO | Range Points | Range Dollars
    string info_text = session.name + " | " +
                      DoubleToString(rt_percentage, 1) + "% | " +
                      mode + " | " +
                      DoubleToString(range_points, 0) + " pts | $" +
                      DoubleToString(range_dollars, 2);

    double label_price = session.ib_high + session.ib_range * 0.1;

    if(ObjectCreate(0, label_name, OBJ_TEXT, 0, session.ib_end_time, label_price))
    {
        ObjectSetString(0, label_name, OBJPROP_TEXT, info_text);
        ObjectSetInteger(0, label_name, OBJPROP_COLOR, session.session_color);
        ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 10);
        ObjectSetString(0, label_name, OBJPROP_FONT, "Arial Bold");
        ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
        ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false);
    }
}

//+------------------------------------------------------------------+
//| Calculate round trip percentage                                 |
//+------------------------------------------------------------------+
double GetRoundTripPercentage(SessionInfo &session)
{
    if(session.total_sessions > 0)
        return (double)session.round_trips / session.total_sessions * 100.0;
    return 0.0;
}

//+------------------------------------------------------------------+
//| Remove visual objects for specific session                     |
//+------------------------------------------------------------------+
void RemoveSessionVisuals(SessionInfo &session, datetime session_time)
{
    string time_str = IntegerToString(session_time);

    for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string obj_name = ObjectName(0, i);
        if(StringFind(obj_name, session.name) >= 0 && StringFind(obj_name, time_str) >= 0)
        {
            ObjectDelete(0, obj_name);
        }
    }
}

//+------------------------------------------------------------------+
//| Clean up all indicator objects                                  |
//+------------------------------------------------------------------+
void CleanupObjects()
{
    for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string obj_name = ObjectName(0, i);
        if(StringFind(obj_name, "Tokyo") >= 0 ||
           StringFind(obj_name, "London") >= 0 ||
           StringFind(obj_name, "NewYork") >= 0)
        {
            ObjectDelete(0, obj_name);
        }
    }
}

//+------------------------------------------------------------------+
//| Print indicator settings at startup                            |
//+------------------------------------------------------------------+
void PrintSettings()
{
    Print("=== IB ALMA EA Signals Indicator Settings ===");
    Print("Indicator Timeframe: ", EnumToString(IndicatorTimeframe));
    Print("Terminal Timezone: GMT", TerminalTimezoneOffset >= 0 ? "+" : "", TerminalTimezoneOffset);
    Print("Fast ALMA: Window=", FastWindowSize, ", Offset=", FastOffset, ", Sigma=", FastSigma);
    Print("Slow ALMA: Window=", SlowWindowSize, ", Offset=", SlowOffset, ", Sigma=", SlowSigma);
    Print("ALMA Lines Display: ", ShowALMALines ? "ENABLED" : "DISABLED (Default)");
    Print("IBRangeThreshold: ", IBRangeThreshold, " points (MATCHES EA)");
    Print("Sessions: Tokyo=", TokyoSession.enabled, " London=", LondonSession.enabled, " NY=", NewYorkSession.enabled);
    Print("Max Sessions Display: ", MaxSessionsToShow);
    Print("Bars to Show: ", BarsToShow);
    Print("Trade Signals: ", ShowTradeSignals ? "ENABLED" : "DISABLED");
    Print("================================================");
}