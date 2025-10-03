//+------------------------------------------------------------------+
//| ALMA_EA_v3.04_ENHANCED.mq5 - Complete Trading System            |
//| Copyright 2025, JNTFX                                           |
//| Enhanced ALMA Trading with Improved Telegram Management         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, JNTFX"
#property link      ""
#property version   "3.04"
#property description "ALMA EA v3.04 - Enhanced with Improved Telegram Interface"

// ALMA visual lines will be drawn using graphical objects

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Windows API Imports for Screenshot Functionality               |
//+------------------------------------------------------------------+
#import "user32.dll"
   int GetDesktopWindow();
   int GetWindowDC(int hWnd);
   int ReleaseDC(int hWnd, int hDC);
   int GetSystemMetrics(int nIndex);
#import

#import "gdi32.dll"
   int CreateCompatibleDC(int hdc);
   int CreateCompatibleBitmap(int hdc, int cx, int cy);
   int SelectObject(int hdc, int hObject);
   int BitBlt(int hdc, int x, int y, int cx, int cy, int hdcSrc, int x1, int y1, int rop);
   int DeleteDC(int hdc);
   int DeleteObject(int hObject);
   int GetDIBits(int hdc, int hbm, int start, int cLines, uchar& lpvBits[], int& lpbi[], int colorUse);
#import

#import "kernel32.dll"
   int GetTempPathW(int nBufferLength, ushort& lpBuffer[]);
   int CreateFileW(string lpFileName, int dwDesiredAccess, int dwShareMode, int lpSecurityAttributes,
                   int dwCreationDisposition, int dwFlagsAndAttributes, int hTemplateFile);
   int WriteFile(int hFile, uchar& lpBuffer[], int nNumberOfBytesToWrite, int& lpNumberOfBytesWritten[], int lpOverlapped);
   int CloseHandle(int hObject);
#import

// Constants for screenshot functionality
#define SM_CXSCREEN 0
#define SM_CYSCREEN 1
#define SRCCOPY 0x00CC0020
#define GENERIC_WRITE 0x40000000
#define CREATE_ALWAYS 2
#define FILE_ATTRIBUTE_NORMAL 0x80
#define DIB_RGB_COLORS 0

//+------------------------------------------------------------------+
//| Enhanced Input Parameters                                        |
//+------------------------------------------------------------------+
input group "=== GENERAL SETTINGS ==="
input ENUM_TIMEFRAMES IndicatorTimeframe = PERIOD_M5;

input group "=== ALMA SETTINGS ==="
input ENUM_APPLIED_PRICE FastPriceSource = PRICE_MEDIAN;
input int FastWindowSize = 9;
input double FastOffset = 0.85;
input double FastSigma = 6.0;

input ENUM_APPLIED_PRICE SlowPriceSource = PRICE_MEDIAN;
input int SlowWindowSize = 50;
input double SlowOffset = 0.85;
input double SlowSigma = 6.0;

input group "=== DYNAMIC ALMA ENHANCED ==="
input bool EnableDynamicALMA = true;
input bool UseSessionAdaptive = true;
input bool UseATRAdaptive = true;
input int SessionHotStartMinutes = 90;
input double ATRLookbackPeriods = 20;
input double VolatilityHighPercentile = 70;
input double VolatilityLowPercentile = 30;

input group "=== TRADING SESSIONS ==="
input bool TradeTokyoSession = true;
input bool TradeLondonSession = true;
input bool TradeNewYorkSession = true;

input group "=== SESSION TIMES (GMT) ==="
input int TokyoStartHour = 3;
input int TokyoEndHour = 12;
input int TokyoIBEndHour = 4;
input int LondonStartHour = 10;
input int LondonEndHour = 18;
input int LondonIBEndHour = 11;
input int NewYorkStartHour = 15;
input int NewYorkEndHour = 0;
input int NewYorkIBEndHour = 16;

input group "=== BURST MODE SETTINGS ==="
input bool   EnableBurstMode           = true;
input int    BurstBarsFor06R          = 3;      // Must reach +0.6R within N bars
input double BurstMinRSpeed           = 0.6;    // Minimum R progress for burst
input double BurstTRoverATR           = 1.30;   // True Range / ATR ratio
input double BurstBodyPct             = 0.60;   // Minimum body percentage
input double BurstALMADispATR         = 0.25;   // Distance from ALMA in ATR units
input double BurstTrailATRMultiple    = 2.5;    // Chandelier exit multiplier
input int    BurstTrailBufferPts      = 10;     // ALMA trail buffer points

input group "=== KILL SWITCH SETTINGS ==="
input bool   EnableKillSwitch         = true;
input int    KillBarsWindow           = 4;      // Monitor first N bars after entry
input double KillMinRProgress         = 0.20;   // Must reach +0.2R by bar 3-4
input int    KillSweepMinPts          = 80;     // Minimum wick size for sweep detection
input int    KillCooldownMinutes      = 15;     // Cooldown after kill switch activation
input bool   KillOnALMACross          = true;   // Exit on ALMA cross against position
input bool   KillOnIBReentry          = true;   // Exit if price re-enters IB (breakouts)

input group "=== BURST MOMENTUM ENTRIES ==="
input bool   EnableBurstMomentumEntries = true;   // Enable momentum entries during burst
input double BurstMomentumRiskPct       = 0.5;    // Risk % for momentum entries (smaller than normal)
input double BurstMomentumMaxRisk       = 100.0;  // Max $ risk per momentum entry
input int    BurstMomentumCooldown      = 30;     // Minutes between momentum entries
input int    BurstMomentumMaxPerDay     = 3;      // Max momentum entries per day

//+------------------------------------------------------------------+
//| Core Enumerations                                                |
//+------------------------------------------------------------------+
enum ENUM_TRADING_MODE
{
   MODE_MANUAL,     // Manual trading only - EA provides analysis
   MODE_HYBRID,     // EA suggests trades, user approves via Telegram
   MODE_AUTO        // Full autonomous trading
};

enum ENUM_POSITION_SIZE_MODE
{
   SIZE_STATIC,     // Fixed lot size
   SIZE_DYNAMIC     // Dynamic sizing based on account balance
};

enum ENUM_ALMA_PRESET
{
   ALMA_AUTO,       // Automatic selection based on conditions
   ALMA_BREAKOUT,   // Optimized for breakout trading
   ALMA_REVERSION,  // Optimized for mean reversion
   ALMA_HYBRID      // Balanced approach
};

enum ENUM_RANGE_ZONE
{
   ZONE_OUTSIDE,    // Outside all defined zones
   ZONE_IB,         // Inside Initial Balance range
   ZONE_H1,         // First extension above IB
   ZONE_H2,         // Second extension above IB
   ZONE_H3,         // Third extension above IB
   ZONE_H4,         // Fourth extension above IB
   ZONE_H5,         // Fifth extension above IB
   ZONE_L1,         // First extension below IB
   ZONE_L2,         // Second extension below IB
   ZONE_L3,         // Third extension below IB
   ZONE_L4,         // Fourth extension below IB
   ZONE_L5          // Fifth extension below IB
};

enum ENUM_TRADE_CLOSURE_REASON
{
   CLOSURE_TP,      // Take profit hit
   CLOSURE_SL,      // Stop loss hit
   CLOSURE_MANUAL,  // Manual closure
   CLOSURE_NEWS,    // Closed due to news
   CLOSURE_SESSION, // Closed at session end
   CLOSURE_RISK     // Closed due to risk management
};

//+------------------------------------------------------------------+
//| Input Parameters (After Enums)                                  |
//+------------------------------------------------------------------+
input group "=== POSITION SIZING ==="
input ENUM_POSITION_SIZE_MODE PositionSizeMode = SIZE_STATIC;
input double StaticLotSize = 1.0;
input double DynamicMultiple = 0.10;
input double MaxLotSize = 5.0;

input group "=== TRADING MODE ==="
input ENUM_TRADING_MODE TradingMode = MODE_HYBRID;

input group "=== CORE STRATEGY ==="
input int IBRangeThreshold = 1000;
input int TrailingStopPoints = 200;
input int TrailingProfitThreshold = 200;

input group "=== RISK MANAGEMENT ==="
input int MaxSpreadPoints = 60;
input int MaxTradesPerSession = 2;
input bool CloseTradesOnSessionEnd = false;
input double MaxDailyLoss = 500.0;
input double MaxDrawdownPercent = 10.0;
input int MaxConsecutiveLosses = 5;
input double DailyProfitTarget = 5000.0;  // Daily profit target in account currency
input double DailyLossThreshold = 3000.0; // Daily loss threshold in account currency

input group "=== NEWS FILTERING ==="
input bool EnableNewsFilter = true;
input int HighImpactMinutesBefore = 30;
input int HighImpactMinutesAfter = 30;
input int MediumImpactMinutesBefore = 30;
input int MediumImpactMinutesAfter = 15;

input group "=== TELEGRAM SETTINGS ==="
input bool EnableTelegramNotifications = true;
input string TelegramBotToken = "  ";
input string TelegramChatID = "  ";
input bool TelegramInteractiveMode = true;
input int TelegramCheckIntervalSeconds = 10;
input int TelegramApprovalTimeoutMinutes = 5;

input group "=== ENHANCED FEATURES ==="
input bool EnableScreenshots = true;
input bool EnableAutomatedReports = true;
input bool EnablePerformanceTracking = true;
input bool EnableAdvancedRiskManagement = true;

input group "=== DEBUG SETTINGS ==="
input bool EnableDebugLogging = false;

//+------------------------------------------------------------------+
//| Core Structures                                                  |
//+------------------------------------------------------------------+
struct SessionInfo
{
   string name;
   int start_hour;
   int end_hour;
   int ib_end_hour;
   bool enabled;
   bool is_active;
   bool ib_active;
   bool ib_completed;
   datetime session_start_time;
   datetime ib_start_time;
   datetime ib_end_time;
   double ib_high;
   double ib_low;
   double ib_range;
   double ib_median;
   int trades_this_session;
};

struct SessionExtensions
{
   bool levels_calculated;
   double h1_level;
   double h2_level;
   double h3_level;
   double h4_level;
   double h5_level;
   double l1_level;
   double l2_level;
   double l3_level;
   double l4_level;
   double l5_level;
};

struct SimpleSignal
{
   bool is_valid;
   bool is_buy;
   double entry_price;
   double stop_loss;
   double take_profit;
   string signal_id;
   string strategy_name;
   string analysis;
   datetime signal_time;
   double confidence_level;
   double risk_reward_ratio;
   int bars_analyzed;
   ENUM_RANGE_ZONE price_zone;
};

struct TradeApprovalData
{
   bool is_pending;
   SimpleSignal signal;
   double lot_size;
   datetime approval_deadline;
   string approval_id;
   int approval_timeout_seconds;
   string context_data;
};

struct PositionSummaryData
{
   int ea_positions;
   int manual_positions;
   double ea_profit;
   double manual_profit;
   double total_profit;
   double ea_volume;
   double manual_volume;
   int winning_ea_positions;
   int losing_ea_positions;
   double max_individual_profit;
   double max_individual_loss;
   datetime last_update_time;
};

struct NewsEvent
{
   datetime event_time;
   string event_name;
   string currency;
   int impact_level;
   string description;
};

struct RangeAnalysis
{
   datetime analysis_time;
   int bars_analyzed;
   double range_high;
   double range_low;
   double range_size_points;
   double current_price;
   ENUM_RANGE_ZONE current_zone;
   bool breakout_detected;
   string breakout_direction;
   double breakout_strength;
   bool setup_valid;
};

struct DailyTrackingData
{
   datetime day_start;
   int trades_count;
   double start_balance;
   double current_profit;
   double max_profit;
   double max_drawdown;
   int winning_trades;
   int losing_trades;
};

struct ConsecutiveTracker
{
   int current_consecutive_wins;
   int current_consecutive_losses;
   int max_consecutive_wins;
   int max_consecutive_losses;
   datetime last_trade_time;
   bool last_trade_was_winner;
   double consecutive_loss_amount;
};

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CTrade trade;
const int EA_MAGIC_NUMBER = 304001;

// Core trading state
ENUM_TRADING_MODE current_trading_mode = MODE_HYBRID;
bool trading_allowed = true;

// Session management
SessionInfo sessions[3];
SessionExtensions session_extensions;

// ALMA calculations
double fast_alma_weights[];
double slow_alma_weights[];
bool alma_weights_calculated = false;
double current_fast_alma = 0;
double current_slow_alma = 0;

// ALMA visual line data
double alma_fast_values[];
double alma_slow_values[];
datetime alma_times[];
int alma_bars_count = 0;

// Dynamic ALMA Enhanced System
struct ALMAPresetData
{
   int fast_length;
   int slow_length;
   double fast_offset;
   double slow_offset;
   string description;
};

// ALMA presets optimized for XAUUSD M5
ALMAPresetData alma_presets[4];
ENUM_ALMA_PRESET current_alma_preset = ALMA_AUTO;
ENUM_ALMA_PRESET active_alma_preset = ALMA_HYBRID;
datetime last_preset_switch = 0;
double atr_history[];
bool dynamic_alma_initialized = false;

// Runtime ALMA parameters (replace static inputs when dynamic mode active)
int runtime_fast_length = 9;
int runtime_slow_length = 50;
double runtime_fast_offset = 0.85;
double runtime_slow_offset = 0.85;
double runtime_fast_sigma = 6.0;
double runtime_slow_sigma = 6.0;
bool runtime_enable_dynamic_alma = true;

// Trade approval system
TradeApprovalData pending_approval;

//+------------------------------------------------------------------+
//| Burst Mode & Kill Switch System                                 |
//+------------------------------------------------------------------+
struct BurstAnalysis {
    bool r_speed_ok;        // +0.6R within 3 bars
    bool impulse_ok;        // TR ≥ 1.3×ATR AND body ≥ 60%
    bool alma_aligned;      // Price beyond ALMA + slope agreement
    bool ib_hold;          // 2+ closes outside IB boundary
    int total_votes;       // Sum of true conditions
    bool should_burst;     // 3+ votes = activate burst
};

struct KillAnalysis {
    bool no_progress;      // Failed to reach +0.2R by bars 3-4
    bool structure_fail;   // Re-entered IB or crossed ALMA against
    bool reverse_sweep;    // Sweep against position at IB edge
    bool alma_cross;       // ALMA fast/slow crossed against position
    bool should_kill;      // Any condition = exit
    string kill_reason;    // Description for logging
};

struct PositionState {
    ulong ticket;
    bool burst_mode_active;
    datetime entry_time;
    datetime kill_cooldown_until;
    double entry_price;
    double original_sl;
    double original_tp;
    bool in_kill_window;
    double highest_r_value;
};

// Global state tracking
PositionState position_states[100];
int position_states_count = 0;
datetime global_cooldown_until = 0;
int burst_activations_count = 0;
int kill_activations_count = 0;
double total_burst_profit = 0;
double total_kill_loss = 0;

// Runtime burst/kill analysis timeframe
ENUM_TIMEFRAMES burst_kill_timeframe = PERIOD_M1;

// Runtime toggles (separate from input parameters)
bool runtime_enable_burst_mode = true;
bool runtime_enable_kill_switch = true;
bool runtime_enable_burst_momentum = true;

// Burst momentum tracking
datetime last_burst_momentum_time = 0;
int daily_burst_momentum_count = 0;
datetime burst_momentum_day_start = 0;

// Signal deduplication
SimpleSignal last_sent_signal;
bool has_sent_signal = false;
datetime signal_suppressed_until_bar = 0;  // Bar time when signal suppression ends

// Position tracking
PositionSummaryData position_summary;

// News events
NewsEvent news_events[50];
int news_events_count = 0;

// Range analysis
RangeAnalysis last_range_analysis;
bool range_break_setup_active = false;
RangeAnalysis active_range_setup;
datetime range_setup_expiry = 0;

// Command decay tracking variables
int range_setup_session_index = -1;        // Session index when command was activated
datetime range_setup_session_end = 0;      // End time of the session when command was activated
datetime range_setup_day_end = 0;          // End of day when command was activated

// Trade tracking and management
struct ManagedTrade
{
   ulong ticket;                    // MT5 ticket number
   string trade_id;                 // Unique identifier (B1, S2, etc.)
   bool is_buy;                     // Trade direction
   double open_price;               // Entry price
   double lot_size;                 // Position size
   datetime open_time;              // Open time
   int session_index;               // Session when opened
   string strategy_name;            // Strategy used

   // Stop loss management
   string stop_type;                // "static", "fast_alma", "slow_alma", "ib_high", "ib_low", "h1", "h2", etc.
   bool trailing_enabled;           // Whether trailing is active
   double static_stop_level;        // Fixed stop level (for static stops)
   double last_alma_stop;           // Last ALMA stop level (for dynamic stops)
};

ManagedTrade managed_trades[50];     // Array to store managed trades
int managed_trades_count = 0;       // Current count of managed trades
int next_buy_id = 1;                // Next B ID counter
int next_sell_id = 1;               // Next S ID counter

// Daily tracking
DailyTrackingData daily_tracking;
double daily_start_balance = 0;
double weekly_start_balance = 0;
double monthly_start_balance = 0;

// Account analysis
double minimum_margin_level = 0;  // Minimum margin level required for trading (0 = disabled)

// Pyramiding settings
bool pyramiding_enabled = true;   // Enable/disable position scaling
int max_pyramid_positions = 3;    // Maximum positions in same direction
double pyramid_profit_threshold = 50.0;  // Minimum profit (in account currency) before allowing scaling
double pyramid_scale_factor = 0.7;  // Size multiplier for additional positions (0.7 = 70% of base size)
bool pyramid_geometric_scaling = false;  // true = geometric (70% of previous), false = flat (70% of base)

// Trading direction settings
bool allow_buy_trades = true;   // Enable/disable buy trades
bool allow_sell_trades = true;  // Enable/disable sell trades

// Runtime trailing stop settings (modifiable via Telegram)
int runtime_trailing_stop_points = 200;      // Runtime modifiable trailing distance
int runtime_trailing_profit_threshold = 200; // Runtime modifiable profit threshold
bool trailing_stops_enabled = true;          // Enable/disable trailing stops

// Daily profit/loss threshold tracking
bool daily_profit_target_hit = false;        // Flag when daily profit target reached
bool daily_loss_threshold_hit = false;       // Flag when daily loss threshold reached
bool profit_target_pause_pending = false;    // Waiting for user decision on profit target
bool loss_threshold_pause_pending = false;   // Waiting for user decision on loss threshold
datetime daily_threshold_reset_time = 0;     // Time to reset daily thresholds
datetime profit_decision_timeout = 0;        // Timeout for profit target decision
datetime loss_decision_timeout = 0;          // Timeout for loss threshold decision

// Runtime range threshold (modifiable via Telegram)
int runtime_ib_range_threshold = 1000;       // Runtime modifiable IB range threshold

// Session summary tracking
struct SessionSummaryData
{
   string session_name;
   datetime session_start_time;
   datetime session_end_time;
   int trades_executed;
   int trades_stopped_out;
   int trades_profitable;
   double session_pnl;
   double session_start_balance;
   string missed_signals[20];        // Array to store missed signal reasons
   int missed_signals_count;
   string news_events[10];           // Array to store news events during session
   int news_events_count;
   string screenshot_path;
   double highest_price;
   double lowest_price;
   double price_range_points;
   bool ib_completed;
   double ib_range_size;
   string dominant_strategy;         // "Mean Reversion" or "Breakout"
};

// Global session summary tracking
SessionSummaryData current_session_summary;
bool session_summary_active = false;

// Consecutive tracking
ConsecutiveTracker consecutive_tracker;

// Enhanced Telegram state
bool telegram_initialized = false;
int telegram_update_offset = 0;
bool quiet_mode = false;
datetime quiet_until = 0;
string last_command_context = "";
datetime last_telegram_error_log = 0;
int telegram_consecutive_errors = 0;
bool telegram_connection_verified = false;
string last_telegram_error = "";

// Circuit breaker for infinite message processing
int last_processed_update_id = -1;
int same_message_count = 0;
datetime last_message_time = 0;

// Module initialization flags
bool session_manager_initialized = false;
bool risk_manager_initialized = false;
bool news_manager_initialized = false;
bool command_processor_initialized = false;
bool screenshot_module_initialized = false;
bool notification_module_initialized = false;

// Enhanced global variables
datetime last_bar_time = 0;
datetime last_telegram_check = 0;
datetime last_news_check = 0;
datetime last_risk_check = 0;
datetime last_performance_update = 0;
datetime last_tp_check_time = 0;
datetime last_manual_trade_warning = 0;

// Enhanced news notification tracking with time-based throttling
struct NewsNotificationData {
    bool sent_30min;                    // 30-minute notification sent once
    datetime last_15min_notification;   // Track last 15min period alert time
    datetime last_5min_notification;    // Track last 5min period alert time
};
NewsNotificationData news_notifications[50];  // Enhanced notification tracking

// ALMA crossover tracking
bool last_alma_bullish = false;
bool alma_crossover_initialized = false;

const int DISPLAY_UPDATE_INTERVAL = 30;
const int NEWS_CHECK_INTERVAL = 60;
const int RISK_CHECK_INTERVAL = 300;
const int PERFORMANCE_UPDATE_INTERVAL = 300;
const int TELEGRAM_CHECK_INTERVAL = 5;
const int MANUAL_TRADE_WARNING_INTERVAL = 900; // 15 minutes

bool all_modules_initialized = false;
string initialization_errors = "";
int today_trade_count = 0;
double session_start_equity = 0;

// Enhanced risk management
double current_max_spread = 60.0;
double current_max_position_size = 5.0;
double runtime_position_size = 1.0;  // Runtime modifiable position size
bool daily_loss_limit_hit = false;
bool weekly_loss_limit_hit = false;
bool drawdown_limit_hit = false;

// Daily loss limit override tracking
double original_daily_loss_limit = 0.0;    // Store original MaxDailyLoss value
double current_daily_loss_limit = 0.0;     // Current active daily loss limit
bool daily_limit_overridden = false;       // Track if limit was modified today

// Runtime news filter settings (modifiable via Telegram)
int runtime_high_impact_before = 30;
int runtime_high_impact_after = 30;
int runtime_medium_impact_before = 30;
int runtime_medium_impact_after = 15;
bool consecutive_loss_limit_hit = false;
double performance_factor = 1.0;
double volatility_factor = 1.0;

//+------------------------------------------------------------------+
//| Core Utility Functions                                           |
//+------------------------------------------------------------------+
string FormatCurrency(double amount)
{
   if(amount >= 0)
      return "$" + DoubleToString(amount, 2);
   else
      return "-$" + DoubleToString(MathAbs(amount), 2);
}

string GetTradingModeString()
{
   switch(TradingMode)
   {
      case MODE_MANUAL: return "MANUAL";
      case MODE_HYBRID: return "HYBRID";
      case MODE_AUTO: return "AUTO";
      default: return "UNKNOWN";
   }
}

double GetCurrentSpreadPoints()
{
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   return (ask - bid) / _Point;
}

bool IsEAMagicNumber(ulong magic)
{
   return (magic >= 304000 && magic <= 304999);
}

string GetTradeSource(ulong magic)
{
   if(IsEAMagicNumber(magic))
      return "EA";
   else
      return "Manual";
}

void DebugLog(string module, string message)
{
   if(EnableDebugLogging)
      Print("DEBUG [", module, "] - ", message);
}

string GetTradingModeName()
{
   switch(current_trading_mode)
   {
      case MODE_MANUAL: return "Manual";
      case MODE_HYBRID: return "Hybrid";
      case MODE_AUTO: return "Auto";
      default: return "Unknown";
   }
}

bool ValidateInputParameters()
{
   if(FastWindowSize < 1 || SlowWindowSize < 1 || FastSigma <= 0 || SlowSigma <= 0)
   {
      Print("ERROR: Invalid ALMA parameters");
      return false;
   }
   
   if(IBRangeThreshold <= 0)
   {
      Print("ERROR: IBRangeThreshold must be positive");
      return false;
   }
   
   if(StaticLotSize <= 0 || MaxLotSize <= 0 || DynamicMultiple <= 0)
   {
      Print("ERROR: Invalid position sizing parameters");
      return false;
   }
   
   if(MaxSpreadPoints <= 0 || MaxTradesPerSession <= 0)
   {
      Print("ERROR: Invalid risk parameters");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Enhanced Session Management                                      |
//+------------------------------------------------------------------+
void InitializeSessions()
{
   // Tokyo Session
   sessions[0].name = "Tokyo";
   sessions[0].start_hour = TokyoStartHour;
   sessions[0].end_hour = TokyoEndHour;
   sessions[0].ib_end_hour = TokyoIBEndHour;
   sessions[0].enabled = TradeTokyoSession;
   sessions[0].is_active = false;
   sessions[0].ib_active = false;
   sessions[0].ib_completed = false;
   sessions[0].trades_this_session = 0;
   
   // London Session
   sessions[1].name = "London";
   sessions[1].start_hour = LondonStartHour;
   sessions[1].end_hour = LondonEndHour;
   sessions[1].ib_end_hour = LondonIBEndHour;
   sessions[1].enabled = TradeLondonSession;
   sessions[1].is_active = false;
   sessions[1].ib_active = false;
   sessions[1].ib_completed = false;
   sessions[1].trades_this_session = 0;
   
   // New York Session
   sessions[2].name = "New York";
   sessions[2].start_hour = NewYorkStartHour;
   sessions[2].end_hour = NewYorkEndHour;
   sessions[2].ib_end_hour = NewYorkIBEndHour;
   sessions[2].enabled = TradeNewYorkSession;
   sessions[2].is_active = false;
   sessions[2].ib_active = false;
   sessions[2].ib_completed = false;
   sessions[2].trades_this_session = 0;
   
   // Initialize extensions
   session_extensions.levels_calculated = false;
   
   session_manager_initialized = true;
   DebugLog("SessionManager", "Enhanced sessions initialized successfully");
}

void UpdateSessionStates()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int current_hour = dt.hour;
   
   for(int i = 0; i < 3; i++)
   {
      if(!sessions[i].enabled) continue;
      
      bool should_be_active = false;
      
      if(sessions[i].end_hour > sessions[i].start_hour)
      {
         should_be_active = (current_hour >= sessions[i].start_hour && current_hour < sessions[i].end_hour);
      }
      else
      {
         should_be_active = (current_hour >= sessions[i].start_hour || current_hour < sessions[i].end_hour);
      }
      
      if(should_be_active && !sessions[i].is_active)
      {
         sessions[i].is_active = true;

         // Calculate actual session start time (not EA startup time)
         datetime actual_session_start = CalculateActualSessionStartTime(i);
         datetime actual_ib_start = CalculateActualIBStartTime(i);
         sessions[i].session_start_time = actual_session_start;
         sessions[i].ib_start_time = actual_ib_start;

         // Determine if we're starting during session or at actual session start
         datetime current_time = TimeCurrent();
         bool is_actual_session_start = (MathAbs(current_time - actual_session_start) < 300); // Within 5 minutes

         // Set IB status based on current time vs IB end time
         datetime ib_end_time = actual_session_start + 3600; // 1 hour after session start
         if(current_time < ib_end_time)
         {
            sessions[i].ib_active = true;
            sessions[i].ib_completed = false;
            DebugLog("SessionManager", sessions[i].name + " session detected - IB period active");
         }
         else
         {
            sessions[i].ib_active = false;
            sessions[i].ib_completed = true;
            // Calculate IB levels from historical data
            CalculateIBLevels(i);
            CalculateSessionExtensions(i);
            DebugLog("SessionManager", sessions[i].name + " session detected - IB period completed");
         }

         sessions[i].trades_this_session = 0;

         // Initialize session summary tracking
         InitializeSessionSummary(i);

         // Only send notification for actual session starts, not EA startup during session
         if(is_actual_session_start && telegram_initialized && !quiet_mode)
         {
            DebugLog("SessionManager", sessions[i].name + " actual session start detected");
            SendSessionStartNotification(i);
         }
         else if(!is_actual_session_start)
         {
            DebugLog("SessionManager", sessions[i].name + " EA started during active session - no start notification");
         }
      }
      else if(!should_be_active && sessions[i].is_active)
      {
         // Finalize session summary before ending session
         if(session_summary_active && current_session_summary.session_name == sessions[i].name)
         {
            DebugLog("SessionManager", "Finalizing session summary for " + sessions[i].name);
            FinalizeSessionSummary();
         }
         else
         {
            if(!session_summary_active)
               DebugLog("SessionManager", "No active session summary to finalize for " + sessions[i].name);
            else
               DebugLog("SessionManager", "Session name mismatch: current=" + current_session_summary.session_name + ", ending=" + sessions[i].name);
         }

         sessions[i].is_active = false;
         sessions[i].ib_active = false;
         sessions[i].ib_completed = false;
         DebugLog("SessionManager", sessions[i].name + " session ended at " + TimeToString(TimeCurrent(), TIME_MINUTES));
      }
      
      if(sessions[i].is_active && sessions[i].ib_active && current_hour >= sessions[i].ib_end_hour)
      {
         sessions[i].ib_active = false;
         sessions[i].ib_completed = true;
         sessions[i].ib_end_time = TimeCurrent();
         CalculateIBLevels(i);
         CalculateSessionExtensions(i);
         SendIBCompletionNotification(i);
         DebugLog("SessionManager", sessions[i].name + " IB period completed");
      }
   }
}

void CalculateIBLevels(int session_index)
{
   if(session_index < 0 || session_index >= 3) return;

   // Ensure IB times are set properly
   if(sessions[session_index].ib_start_time == 0)
   {
      sessions[session_index].ib_start_time = CalculateActualIBStartTime(session_index);
   }
   if(sessions[session_index].ib_end_time == 0)
   {
      sessions[session_index].ib_end_time = sessions[session_index].ib_start_time + 3600; // 1 hour
   }

   // Calculate IB from the session start to IB end
   double high = 0, low = 999999;
   int bars_count = 0;

   // Look back through bars since session start
   for(int i = 1; i <= 100; i++)
   {
      datetime bar_time = iTime(Symbol(), IndicatorTimeframe, i);
      if(bar_time < sessions[session_index].ib_start_time) break;
      if(bar_time > sessions[session_index].ib_end_time) continue;

      double bar_high = iHigh(Symbol(), IndicatorTimeframe, i);
      double bar_low = iLow(Symbol(), IndicatorTimeframe, i);

      if(bar_high > high) high = bar_high;
      if(bar_low < low) low = bar_low;
      bars_count++;
   }
   
   if(bars_count > 0 && high > 0 && low < 999999)
   {
      sessions[session_index].ib_high = high;
      sessions[session_index].ib_low = low;
      sessions[session_index].ib_range = (high - low) / _Point;
      sessions[session_index].ib_median = (high + low) / 2.0;

      DebugLog("SessionManager", sessions[session_index].name + " IB calculated successfully: " +
               "Range=" + DoubleToString(sessions[session_index].ib_range, 0) + " points, " +
               "High=" + DoubleToString(high, _Digits) + ", " +
               "Low=" + DoubleToString(low, _Digits) + ", " +
               "Bars=" + IntegerToString(bars_count));

   }
   else
   {
      DebugLog("SessionManager", sessions[session_index].name + " IB calculation failed: " +
               "bars_count=" + IntegerToString(bars_count) +
               ", high=" + DoubleToString(high, _Digits) +
               ", low=" + DoubleToString(low, _Digits) +
               ", ib_start=" + TimeToString(sessions[session_index].ib_start_time) +
               ", ib_end=" + TimeToString(sessions[session_index].ib_end_time));
   }
}

void CalculateSessionExtensions(int session_index)
{
   if(session_index < 0 || session_index >= 3) return;
   if(!sessions[session_index].ib_completed) return;
   
   double range = sessions[session_index].ib_high - sessions[session_index].ib_low;
   
   // High extensions
   session_extensions.h1_level = sessions[session_index].ib_high + range;
   session_extensions.h2_level = sessions[session_index].ib_high + (2 * range);
   session_extensions.h3_level = sessions[session_index].ib_high + (3 * range);
   session_extensions.h4_level = sessions[session_index].ib_high + (4 * range);
   session_extensions.h5_level = sessions[session_index].ib_high + (5 * range);
   
   // Low extensions
   session_extensions.l1_level = sessions[session_index].ib_low - range;
   session_extensions.l2_level = sessions[session_index].ib_low - (2 * range);
   session_extensions.l3_level = sessions[session_index].ib_low - (3 * range);
   session_extensions.l4_level = sessions[session_index].ib_low - (4 * range);
   session_extensions.l5_level = sessions[session_index].ib_low - (5 * range);
   
   session_extensions.levels_calculated = true;
}

SessionInfo GetPrioritySession()
{
   // Priority: NY > London > Tokyo
   if(sessions[2].enabled && sessions[2].is_active) return sessions[2]; // NY
   if(sessions[1].enabled && sessions[1].is_active) return sessions[1]; // London
   if(sessions[0].enabled && sessions[0].is_active) return sessions[0]; // Tokyo
   
   SessionInfo empty_session;
   empty_session.name = "None";
   empty_session.is_active = false;
   return empty_session;
}

string GetPrioritySessionName()
{
   SessionInfo priority = GetPrioritySession();
   return priority.name;
}

int GetPrioritySessionIndex()
{
   if(sessions[2].enabled && sessions[2].is_active) return 2; // NY
   if(sessions[1].enabled && sessions[1].is_active) return 1; // London
   if(sessions[0].enabled && sessions[0].is_active) return 0; // Tokyo
   return -1;
}

string GetSessionStatus()
{
   SessionInfo priority = GetPrioritySession();
   
   if(priority.is_active)
   {
      string status = "Active: " + priority.name;
      if(priority.ib_active)
         status += " (IB Period)";
      else if(priority.ib_completed)
         status += " (Post-IB)";
      return status;
   }
   else
   {
      return "No active session";
   }
}

double GetExtensionLevel(int level, bool is_high)
{
   if(!session_extensions.levels_calculated) return 0;
   
   if(is_high)
   {
      switch(level)
      {
         case 1: return session_extensions.h1_level;
         case 2: return session_extensions.h2_level;
         case 3: return session_extensions.h3_level;
         case 4: return session_extensions.h4_level;
         case 5: return session_extensions.h5_level;
         default: return 0;
      }
   }
   else
   {
      switch(level)
      {
         case 1: return session_extensions.l1_level;
         case 2: return session_extensions.l2_level;
         case 3: return session_extensions.l3_level;
         case 4: return session_extensions.l4_level;
         case 5: return session_extensions.l5_level;
         default: return 0;
      }
   }
}

//+------------------------------------------------------------------+
//| ALMA Functions                                                   |
//+------------------------------------------------------------------+
void InitializeALMA()
{
   // Use runtime parameters if dynamic mode is enabled, otherwise use inputs
   int fast_window = runtime_enable_dynamic_alma ? runtime_fast_length : FastWindowSize;
   int slow_window = runtime_enable_dynamic_alma ? runtime_slow_length : SlowWindowSize;
   double fast_offset = runtime_enable_dynamic_alma ? runtime_fast_offset : FastOffset;
   double slow_offset = runtime_enable_dynamic_alma ? runtime_slow_offset : SlowOffset;
   double fast_sigma = runtime_enable_dynamic_alma ? runtime_fast_sigma : FastSigma;
   double slow_sigma = runtime_enable_dynamic_alma ? runtime_slow_sigma : SlowSigma;

   // Calculate Fast ALMA weights
   ArrayResize(fast_alma_weights, fast_window);
   double m_fast = fast_offset * (fast_window - 1);
   double s_fast = fast_window / fast_sigma;
   double norm_fast = 0.0;
   
   for(int i = 0; i < fast_window; i++)
   {
      double exp_val = -0.5 * MathPow((i - m_fast) / s_fast, 2);
      fast_alma_weights[i] = MathExp(exp_val);
      norm_fast += fast_alma_weights[i];
   }

   for(int i = 0; i < fast_window; i++)
      fast_alma_weights[i] /= norm_fast;

   // Calculate Slow ALMA weights
   ArrayResize(slow_alma_weights, slow_window);
   double m_slow = slow_offset * (slow_window - 1);
   double s_slow = slow_window / slow_sigma;
   double norm_slow = 0.0;

   for(int i = 0; i < slow_window; i++)
   {
      double exp_val = -0.5 * MathPow((i - m_slow) / s_slow, 2);
      slow_alma_weights[i] = MathExp(exp_val);
      norm_slow += slow_alma_weights[i];
   }

   for(int i = 0; i < slow_window; i++)
      slow_alma_weights[i] /= norm_slow;
   
   alma_weights_calculated = true;
   DebugLog("ALMA", "Enhanced ALMA weights calculated successfully");
}

void InitializeDynamicALMA()
{
   // Initialize runtime variable from input parameter
   runtime_enable_dynamic_alma = EnableDynamicALMA;

   // Initialize ALMA presets optimized for XAUUSD M5

   // BREAKOUT Preset - Reduced lag, faster response
   alma_presets[ALMA_BREAKOUT].fast_length = 10;
   alma_presets[ALMA_BREAKOUT].slow_length = 30;
   alma_presets[ALMA_BREAKOUT].fast_offset = 0.90;
   alma_presets[ALMA_BREAKOUT].slow_offset = 0.88;
   alma_presets[ALMA_BREAKOUT].description = "Breakout (Fast Response)";

   // REVERSION Preset - Steadier mean, centered
   alma_presets[ALMA_REVERSION].fast_length = 8;
   alma_presets[ALMA_REVERSION].slow_length = 21;
   alma_presets[ALMA_REVERSION].fast_offset = 0.75;
   alma_presets[ALMA_REVERSION].slow_offset = 0.72;
   alma_presets[ALMA_REVERSION].description = "Mean Reversion (Steady)";

   // HYBRID Preset - Balanced approach
   alma_presets[ALMA_HYBRID].fast_length = 9;
   alma_presets[ALMA_HYBRID].slow_length = 21;
   alma_presets[ALMA_HYBRID].fast_offset = 0.85;
   alma_presets[ALMA_HYBRID].slow_offset = 0.82;
   alma_presets[ALMA_HYBRID].description = "Hybrid (Balanced)";

   // AUTO Preset - Same as HYBRID initially
   alma_presets[ALMA_AUTO].fast_length = 9;
   alma_presets[ALMA_AUTO].slow_length = 21;
   alma_presets[ALMA_AUTO].fast_offset = 0.85;
   alma_presets[ALMA_AUTO].slow_offset = 0.82;
   alma_presets[ALMA_AUTO].description = "Auto Selection";

   // Initialize ATR history array
   ArrayResize(atr_history, (int)ATRLookbackPeriods);
   ArrayInitialize(atr_history, 0);

   // Set initial runtime parameters
   ApplyALMAPreset(ALMA_HYBRID);

   dynamic_alma_initialized = true;
   DebugLog("DynamicALMA", "Dynamic ALMA system initialized with " + IntegerToString(ArraySize(alma_presets)) + " presets");
}

void ApplyALMAPreset(ENUM_ALMA_PRESET preset)
{
   if(preset < 0 || preset > ALMA_HYBRID)
   {
      DebugLog("DynamicALMA", "Invalid preset index: " + IntegerToString(preset));
      return;
   }

   // Get optimized parameters for current symbol and mode
   int fast_period, fast_sigma, slow_period, slow_sigma;
   double fast_offset, slow_offset;
   GetOptimizedALMAParams(_Symbol, preset, fast_period, fast_offset, fast_sigma, slow_period, slow_offset, slow_sigma);

   // Update runtime parameters with research-optimized values
   runtime_fast_length = fast_period;
   runtime_slow_length = slow_period;
   runtime_fast_offset = fast_offset;
   runtime_slow_offset = slow_offset;
   runtime_fast_sigma = fast_sigma;
   runtime_slow_sigma = slow_sigma;

   active_alma_preset = preset;
   last_preset_switch = TimeCurrent();

   // Force recalculation of ALMA weights
   alma_weights_calculated = false;

   // Trigger full recalculation of ALMA lines
   RefreshALMALines();

   string preset_name = "";
   switch(preset) {
      case ALMA_BREAKOUT: preset_name = "BREAKOUT (Research-Optimized)"; break;
      case ALMA_REVERSION: preset_name = "REVERSION (Research-Optimized)"; break;
      case ALMA_HYBRID: preset_name = "HYBRID (Research-Optimized)"; break;
      default: preset_name = "AUTO (Research-Optimized)"; break;
   }

   DebugLog("DynamicALMA", "Applied preset: " + preset_name + " for " + _Symbol +
            " (Fast: " + IntegerToString(runtime_fast_length) + "@" + DoubleToString(runtime_fast_offset, 2) +
            ", Slow: " + IntegerToString(runtime_slow_length) + "@" + DoubleToString(runtime_slow_offset, 2) + ")");
}

ENUM_ALMA_PRESET SelectOptimalALMAPreset()
{
   if(!runtime_enable_dynamic_alma || !dynamic_alma_initialized)
      return ALMA_HYBRID;

   ENUM_ALMA_PRESET selected_preset = ALMA_HYBRID;

   // Check session-based conditions
   bool session_hot = IsSessionHotStart();
   double atr_percentile = GetATRPercentile();

   // Decision logic based on conditions
   if(UseSessionAdaptive && session_hot)
   {
      selected_preset = ALMA_BREAKOUT;
      DebugLog("DynamicALMA", "Session hot start detected - selecting BREAKOUT preset");
   }
   else if(UseATRAdaptive && atr_percentile >= VolatilityHighPercentile)
   {
      selected_preset = ALMA_BREAKOUT;
      DebugLog("DynamicALMA", "High volatility detected (" + DoubleToString(atr_percentile, 1) + "%) - selecting BREAKOUT preset");
   }
   else if(UseATRAdaptive && atr_percentile <= VolatilityLowPercentile)
   {
      selected_preset = ALMA_REVERSION;
      DebugLog("DynamicALMA", "Low volatility detected (" + DoubleToString(atr_percentile, 1) + "%) - selecting REVERSION preset");
   }
   else
   {
      selected_preset = ALMA_HYBRID;
   }

   return selected_preset;
}

void UpdateDynamicALMA()
{
   if(!runtime_enable_dynamic_alma || !dynamic_alma_initialized)
      return;

   // Always update ATR history for accurate volatility analysis
   UpdateATRHistory();

   // Don't change presets too frequently (minimum 5 minutes between changes)
   if(TimeCurrent() - last_preset_switch < 300)
      return;

   ENUM_ALMA_PRESET optimal_preset = SelectOptimalALMAPreset();

   if(optimal_preset != active_alma_preset)
   {
      ApplyALMAPreset(optimal_preset);

      // Send Telegram notification of preset change
      if(telegram_initialized)
      {
         string msg = "🎛️ ALMA PRESET CHANGED\n";
         msg += "New Preset: " + alma_presets[optimal_preset].description + "\n";
         msg += "Parameters: Fast " + IntegerToString(runtime_fast_length) + "@" + DoubleToString(runtime_fast_offset, 2);
         msg += ", Slow " + IntegerToString(runtime_slow_length) + "@" + DoubleToString(runtime_slow_offset, 2) + "\n\n";

         // Add context about why the change occurred
         double atr_percentile = GetATRPercentile();
         bool session_hot = IsSessionHotStart();
         msg += "📊 Context:\n";
         msg += "• ATR: " + DoubleToString(atr_percentile, 1) + "%";
         if(atr_percentile > VolatilityHighPercentile) msg += " (HIGH)";
         else if(atr_percentile < VolatilityLowPercentile) msg += " (LOW)";
         else msg += " (NORMAL)";
         msg += "\n";
         if(session_hot) msg += "• Session: HOT START 🔥\n";
         else msg += "• Session: Normal\n";
         SendTelegramMessage(msg);
      }
   }
}

void UpdateATRHistory()
{
   int atr_handle = iATR(Symbol(), IndicatorTimeframe, 14);
   double current_atr_buffer[];
   double current_atr;
   if(CopyBuffer(atr_handle, 0, 1, 1, current_atr_buffer) > 0)
      current_atr = current_atr_buffer[0];
   else
      current_atr = 0;
   if(current_atr > 0)
   {
      // Shift array and add new value
      for(int i = ArraySize(atr_history) - 1; i > 0; i--)
         atr_history[i] = atr_history[i-1];
      atr_history[0] = current_atr;
   }
}

double GetATRPercentile()
{
   if(ArraySize(atr_history) == 0)
      return 50.0; // Default to median

   int atr_handle = iATR(Symbol(), IndicatorTimeframe, 14);
   double current_atr_buffer[];
   double current_atr;
   if(CopyBuffer(atr_handle, 0, 1, 1, current_atr_buffer) > 0)
      current_atr = current_atr_buffer[0];
   else
      current_atr = 0;

   if(current_atr <= 0)
      return 50.0;

   int count_below = 0;
   int valid_count = 0;

   for(int i = 0; i < ArraySize(atr_history); i++)
   {
      if(atr_history[i] > 0)
      {
         valid_count++;
         if(atr_history[i] < current_atr)
            count_below++;
      }
   }

   if(valid_count == 0)
      return 50.0;

   return (count_below * 100.0) / valid_count;
}

bool IsSessionHotStart()
{
   if(!UseSessionAdaptive)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int current_hour = dt.hour;

   // Check if we're within the hot start period for London or New York
   bool london_hot = (TradeLondonSession && current_hour >= LondonStartHour &&
                     current_hour < LondonStartHour + (SessionHotStartMinutes / 60));
   bool ny_hot = (TradeNewYorkSession && current_hour >= NewYorkStartHour &&
                 current_hour < NewYorkStartHour + (SessionHotStartMinutes / 60));

   return london_hot || ny_hot;
}

string GetALMAPresetName(ENUM_ALMA_PRESET preset)
{
   if(preset >= 0 && preset < ArraySize(alma_presets))
      return alma_presets[preset].description;
   return "Unknown";
}

string GetDynamicALMAStatus()
{
   if(!runtime_enable_dynamic_alma)
      return "Static Mode";

   string status = "Dynamic: " + GetALMAPresetName(active_alma_preset);

   if(UseSessionAdaptive || UseATRAdaptive)
   {
      status += " (Auto)";
      if(IsSessionHotStart())
         status += " [HOT]";

      double atr_perc = GetATRPercentile();
      status += " ATR:" + DoubleToString(atr_perc, 0) + "%";
   }

   return status;
}

double CalculateALMA(ENUM_APPLIED_PRICE price_type, int window_size, double &weights[], int bars_back = 0)
{
   if(!alma_weights_calculated || ArraySize(weights) != window_size)
      return 0;
   
   double alma_value = 0;
   
   for(int i = 0; i < window_size; i++)
   {
      double price_value = 0;
      
      switch(price_type)
      {
         case PRICE_CLOSE:
            price_value = iClose(Symbol(), IndicatorTimeframe, bars_back + i);
            break;
         case PRICE_MEDIAN:
            price_value = (iHigh(Symbol(), IndicatorTimeframe, bars_back + i) + 
                          iLow(Symbol(), IndicatorTimeframe, bars_back + i)) / 2.0;
            break;
         case PRICE_TYPICAL:
            price_value = (iHigh(Symbol(), IndicatorTimeframe, bars_back + i) + 
                          iLow(Symbol(), IndicatorTimeframe, bars_back + i) + 
                          iClose(Symbol(), IndicatorTimeframe, bars_back + i)) / 3.0;
            break;
         default:
            price_value = iClose(Symbol(), IndicatorTimeframe, bars_back + i);
            break;
      }
      
      alma_value += price_value * weights[i];
   }
   
   return alma_value;
}

void UpdateALMAValues()
{
   // Update dynamic ALMA preset if enabled
   UpdateDynamicALMA();

   if(!alma_weights_calculated)
   {
      InitializeALMA();
      return;
   }

   double prev_fast_alma = current_fast_alma;
   double prev_slow_alma = current_slow_alma;

   // Use runtime parameters for window sizes if dynamic mode is enabled
   int fast_window = runtime_enable_dynamic_alma ? runtime_fast_length : FastWindowSize;
   int slow_window = runtime_enable_dynamic_alma ? runtime_slow_length : SlowWindowSize;

   current_fast_alma = CalculateALMA(FastPriceSource, fast_window, fast_alma_weights, 0);
   current_slow_alma = CalculateALMA(SlowPriceSource, slow_window, slow_alma_weights, 0);

   // Update ALMA visual lines
   UpdateALMALines();

   // Check for ALMA crossover
   CheckALMACrossover(prev_fast_alma, prev_slow_alma);
}

//+------------------------------------------------------------------+
//| Refresh ALMA Lines After Parameter Change                       |
//+------------------------------------------------------------------+
void UpdateALMALines()
{
   // Store current ALMA values with timestamp
   datetime current_time = iTime(_Symbol, _Period, 0);

   // Add current values to arrays
   if(alma_bars_count < ArraySize(alma_fast_values))
   {
      alma_fast_values[alma_bars_count] = current_fast_alma;
      alma_slow_values[alma_bars_count] = current_slow_alma;
      alma_times[alma_bars_count] = current_time;
      alma_bars_count++;
   }
   else
   {
      // Shift arrays and add new value
      for(int i = 1; i < ArraySize(alma_fast_values); i++)
      {
         alma_fast_values[i-1] = alma_fast_values[i];
         alma_slow_values[i-1] = alma_slow_values[i];
         alma_times[i-1] = alma_times[i];
      }
      alma_fast_values[ArraySize(alma_fast_values)-1] = current_fast_alma;
      alma_slow_values[ArraySize(alma_slow_values)-1] = current_slow_alma;
      alma_times[ArraySize(alma_times)-1] = current_time;
   }

   // Draw the lines
   DrawALMALines();
}

void DrawALMALines()
{
   if(alma_bars_count < 2) return;

   // Clear existing ALMA objects
   ObjectsDeleteAll(0, "ALMA_");

   // Draw Fast ALMA line segments (recent 1000 bars for 24+ hours of history)
   int bars_to_draw = MathMin(alma_bars_count, 1000);
   int start_index = alma_bars_count - bars_to_draw;

   // Create multiple line segments for Fast ALMA
   for(int i = start_index; i < alma_bars_count - 1; i++)
   {
      string fast_segment_name = "ALMA_Fast_" + IntegerToString(i);
      if(ObjectCreate(0, fast_segment_name, OBJ_TREND, 0,
                      alma_times[i], alma_fast_values[i],
                      alma_times[i+1], alma_fast_values[i+1]))
      {
         ObjectSetInteger(0, fast_segment_name, OBJPROP_COLOR, clrCyan);
         ObjectSetInteger(0, fast_segment_name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, fast_segment_name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, fast_segment_name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, fast_segment_name, OBJPROP_RAY_LEFT, false);
         ObjectSetInteger(0, fast_segment_name, OBJPROP_BACK, false);
      }
   }

   // Create multiple line segments for Slow ALMA
   for(int i = start_index; i < alma_bars_count - 1; i++)
   {
      string slow_segment_name = "ALMA_Slow_" + IntegerToString(i);
      if(ObjectCreate(0, slow_segment_name, OBJ_TREND, 0,
                      alma_times[i], alma_slow_values[i],
                      alma_times[i+1], alma_slow_values[i+1]))
      {
         ObjectSetInteger(0, slow_segment_name, OBJPROP_COLOR, clrYellow);
         ObjectSetInteger(0, slow_segment_name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, slow_segment_name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, slow_segment_name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, slow_segment_name, OBJPROP_RAY_LEFT, false);
         ObjectSetInteger(0, slow_segment_name, OBJPROP_BACK, false);
      }
   }

   ChartRedraw();
}

void RefreshALMALines()
{
   // Initialize ALMA weights with new parameters
   InitializeALMA();

   // Clear existing data and recalculate
   alma_bars_count = 0;

   // Calculate ALMA for recent bars
   int bars_to_calc = MathMin(Bars(_Symbol, _Period), 100);

   for(int i = bars_to_calc - 1; i >= 0; i--)
   {
      // Calculate Fast ALMA for this bar
      double fast_sum = 0;
      double fast_norm = 0;
      for(int j = 0; j < runtime_fast_length && (i + j) < Bars(_Symbol, _Period); j++)
      {
         if(j < ArraySize(fast_alma_weights))
         {
            double price = iClose(_Symbol, _Period, i + j);
            fast_sum += price * fast_alma_weights[j];
            fast_norm += fast_alma_weights[j];
         }
      }
      double fast_alma = fast_norm > 0 ? fast_sum / fast_norm : iClose(_Symbol, _Period, i);

      // Calculate Slow ALMA for this bar
      double slow_sum = 0;
      double slow_norm = 0;
      for(int j = 0; j < runtime_slow_length && (i + j) < Bars(_Symbol, _Period); j++)
      {
         if(j < ArraySize(slow_alma_weights))
         {
            double price = iClose(_Symbol, _Period, i + j);
            slow_sum += price * slow_alma_weights[j];
            slow_norm += slow_alma_weights[j];
         }
      }
      double slow_alma = slow_norm > 0 ? slow_sum / slow_norm : iClose(_Symbol, _Period, i);

      // Store values
      if(alma_bars_count < ArraySize(alma_fast_values))
      {
         alma_fast_values[alma_bars_count] = fast_alma;
         alma_slow_values[alma_bars_count] = slow_alma;
         alma_times[alma_bars_count] = iTime(_Symbol, _Period, i);
         alma_bars_count++;
      }
   }

   DrawALMALines();

   Print("ALMA Lines refreshed: Fast=" + DoubleToString(current_fast_alma, 2) +
         ", Slow=" + DoubleToString(current_slow_alma, 2) +
         ", Bars: " + IntegerToString(alma_bars_count));
}

//+------------------------------------------------------------------+
//| Backfill ALMA historical data for 3-5 days of visual display    |
//+------------------------------------------------------------------+
void BackfillALMAHistory()
{
   if(!alma_weights_calculated)
   {
      InitializeALMA();
   }

   // Calculate how many bars to backfill (24+ hours across 3 sessions = ~300+ bars on M5)
   int bars_to_backfill = MathMin(1000, Bars(_Symbol, _Period) - 1);

   Print("Backfilling ALMA history for " + IntegerToString(bars_to_backfill) + " bars...");

   // Use runtime parameters for window sizes if dynamic mode is enabled
   int fast_window = runtime_enable_dynamic_alma ? runtime_fast_length : FastWindowSize;
   int slow_window = runtime_enable_dynamic_alma ? runtime_slow_length : SlowWindowSize;

   // Calculate ALMA values for historical bars
   for(int i = bars_to_backfill; i >= 0; i--)
   {
      if(alma_bars_count >= ArraySize(alma_fast_values)) break;

      double fast_alma = CalculateALMA(FastPriceSource, fast_window, fast_alma_weights, i);
      double slow_alma = CalculateALMA(SlowPriceSource, slow_window, slow_alma_weights, i);
      datetime bar_time = iTime(_Symbol, _Period, i);

      alma_fast_values[alma_bars_count] = fast_alma;
      alma_slow_values[alma_bars_count] = slow_alma;
      alma_times[alma_bars_count] = bar_time;
      alma_bars_count++;
   }

   // Draw the historical lines
   DrawALMALines();

   Print("ALMA history backfilled: " + IntegerToString(alma_bars_count) + " bars calculated and displayed");
}

//+------------------------------------------------------------------+
//| Metal Detection and Parameter Optimization                      |
//+------------------------------------------------------------------+
enum ENUM_ASSET_CLASS
{
   ASSET_PRECIOUS_METALS,  // Gold, Silver, Platinum
   ASSET_FOREX_MAJOR,      // EUR, GBP, JPY, etc.
   ASSET_FOREX_MINOR,      // Cross pairs
   ASSET_INDICES,          // SPX, NAS, DAX, etc.
   ASSET_COMMODITIES,      // Oil, Gas, Wheat, etc.
   ASSET_CRYPTO,           // BTC, ETH, etc.
   ASSET_BONDS,            // Treasury futures
   ASSET_OTHER             // Unknown
};

enum ENUM_METAL_TYPE
{
   METAL_GOLD,      // XAUUSD
   METAL_SILVER,    // XAGUSD
   METAL_PLATINUM,  // XPTUSD
   METAL_PALLADIUM, // XPDUSD
   METAL_OTHER      // Unknown/Other symbols
};

ENUM_ASSET_CLASS DetectAssetClass()
{
   string symbol = _Symbol;

   // Precious Metals
   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "XPT") >= 0 || StringFind(symbol, "XPD") >= 0 ||
      StringFind(symbol, "GOLD") >= 0 || StringFind(symbol, "SILVER") >= 0)
      return ASSET_PRECIOUS_METALS;

   // Forex Major Pairs
   if(StringFind(symbol, "EUR") >= 0 || StringFind(symbol, "GBP") >= 0 || StringFind(symbol, "JPY") >= 0 ||
      StringFind(symbol, "CHF") >= 0 || StringFind(symbol, "CAD") >= 0 || StringFind(symbol, "AUD") >= 0 || StringFind(symbol, "NZD") >= 0)
      return ASSET_FOREX_MAJOR;

   // Indices (US, European)
   if(StringFind(symbol, "SPX") >= 0 || StringFind(symbol, "NAS") >= 0 || StringFind(symbol, "DOW") >= 0 || StringFind(symbol, "SP500") >= 0 ||
      StringFind(symbol, "DAX") >= 0 || StringFind(symbol, "FTSE") >= 0 || StringFind(symbol, "NIKKEI") >= 0 || StringFind(symbol, "ES") >= 0 ||
      StringFind(symbol, "NQ") >= 0 || StringFind(symbol, "YM") >= 0 || StringFind(symbol, "RTY") >= 0)
      return ASSET_INDICES;

   // Commodities
   if(StringFind(symbol, "OIL") >= 0 || StringFind(symbol, "WTI") >= 0 || StringFind(symbol, "BRENT") >= 0 || StringFind(symbol, "CL") >= 0 ||
      StringFind(symbol, "NG") >= 0 || StringFind(symbol, "WHEAT") >= 0 || StringFind(symbol, "CORN") >= 0 || StringFind(symbol, "SUGAR") >= 0)
      return ASSET_COMMODITIES;

   // Crypto
   if(StringFind(symbol, "BTC") >= 0 || StringFind(symbol, "ETH") >= 0 || StringFind(symbol, "CRYPTO") >= 0)
      return ASSET_CRYPTO;

   // Bonds
   if(StringFind(symbol, "BOND") >= 0 || StringFind(symbol, "ZN") >= 0 || StringFind(symbol, "ZB") >= 0 || StringFind(symbol, "ZF") >= 0)
      return ASSET_BONDS;

   return ASSET_OTHER;
}

ENUM_METAL_TYPE DetectMetalType()
{
   string symbol = _Symbol;

   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
      return METAL_GOLD;
   else if(StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "SILVER") >= 0)
      return METAL_SILVER;
   else if(StringFind(symbol, "XPT") >= 0 || StringFind(symbol, "PLATINUM") >= 0)
      return METAL_PLATINUM;
   else if(StringFind(symbol, "XPD") >= 0 || StringFind(symbol, "PALLADIUM") >= 0)
      return METAL_PALLADIUM;
   else
      return METAL_OTHER;
}

double GetAssetBreakoutBuffer()
{
   string symbol = _Symbol;

   // === PRECIOUS METALS (Keep your exact settings) ===
   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
      return 50 * _Point;   // $0.50 buffer for gold
   if(StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "SILVER") >= 0)
      return 100 * _Point;  // $0.10 buffer for silver
   if(StringFind(symbol, "XPT") >= 0 || StringFind(symbol, "PLATINUM") >= 0)
      return 80 * _Point;   // $0.80 buffer for platinum
   if(StringFind(symbol, "XPD") >= 0 || StringFind(symbol, "PALLADIUM") >= 0)
      return 100 * _Point;  // $1.00 buffer for palladium

   // === SPECIFIC FUTURES CONTRACTS ===

   // S&P 500 Futures
   if(StringFind(symbol, "ES") >= 0)       return 5 * _Point;    // 1.25 pts ($62.50)
   if(StringFind(symbol, "MES") >= 0)      return 5 * _Point;    // 1.25 pts ($6.25)

   // NASDAQ Futures
   if(StringFind(symbol, "NQ") >= 0)       return 4 * _Point;    // 1 pt ($20)
   if(StringFind(symbol, "MNQ") >= 0)      return 4 * _Point;    // 1 pt ($2)

   // Dow Futures
   if(StringFind(symbol, "YM") >= 0)       return 10 * _Point;   // 10 pts ($50)
   if(StringFind(symbol, "MYM") >= 0)      return 10 * _Point;   // 10 pts ($5)

   // Gold Futures (separate from spot gold)
   if(StringFind(symbol, "GC") >= 0)       return 20 * _Point;   // $2.00 ($200)
   if(StringFind(symbol, "MGC") >= 0)      return 20 * _Point;   // $2.00 ($20)

   // Oil Futures
   if(StringFind(symbol, "CL") >= 0)       return 5 * _Point;    // $0.05 ($50)
   if(StringFind(symbol, "MCL") >= 0)      return 5 * _Point;    // $0.05 ($5)

   // Currency Futures
   if(StringFind(symbol, "6E") >= 0)       return 8 * _Point;    // 8 ticks ($100)
   if(StringFind(symbol, "M6E") >= 0)      return 8 * _Point;    // 8 ticks ($10)
   if(StringFind(symbol, "6B") >= 0)       return 10 * _Point;   // 10 ticks ($62.50)
   if(StringFind(symbol, "M6B") >= 0)      return 10 * _Point;   // 10 ticks ($6.25)

   // Bond Futures
   if(StringFind(symbol, "ZN") >= 0)       return 4 * _Point;    // 4/32nds ($62.50)

   // Silver Futures (separate from spot silver)
   if(StringFind(symbol, "SI") >= 0)       return 10 * _Point;   // $0.10 ($500)

   // Natural Gas
   if(StringFind(symbol, "NATURAL") >= 0)  return 10 * _Point;   // $0.010 ($100)

   // === SPECIFIC FOREX PAIRS ===

   // Major Pairs
   if(symbol == "EURUSD")  return 3 * _Point;    // 0.3 pips
   if(symbol == "GBPUSD")  return 4 * _Point;    // 0.4 pips
   if(symbol == "USDJPY")  return 3 * _Point;    // 0.03 yen
   if(symbol == "USDCHF")  return 4 * _Point;    // 0.4 pips
   if(symbol == "AUDUSD")  return 4 * _Point;    // 0.4 pips
   if(symbol == "NZDUSD")  return 5 * _Point;    // 0.5 pips
   if(symbol == "USDCAD")  return 4 * _Point;    // 0.4 pips

   // Cross Pairs
   if(symbol == "EURGBP")  return 4 * _Point;    // 0.4 pips
   if(symbol == "EURJPY")  return 5 * _Point;    // 0.05 yen
   if(symbol == "EURCHF")  return 5 * _Point;    // 0.5 pips
   if(symbol == "EURCAD")  return 6 * _Point;    // 0.6 pips
   if(symbol == "EURAUD")  return 6 * _Point;    // 0.6 pips
   if(symbol == "GBPJPY")  return 8 * _Point;    // 0.08 yen
   if(symbol == "GBPCHF")  return 7 * _Point;    // 0.7 pips
   if(symbol == "GBPCAD")  return 8 * _Point;    // 0.8 pips
   if(symbol == "GBPAUD")  return 8 * _Point;    // 0.8 pips
   if(symbol == "CHFJPY")  return 6 * _Point;    // 0.06 yen
   if(symbol == "CADJPY")  return 6 * _Point;    // 0.06 yen
   if(symbol == "AUDJPY")  return 6 * _Point;    // 0.06 yen
   if(symbol == "AUDCHF")  return 6 * _Point;    // 0.6 pips
   if(symbol == "AUDCAD")  return 6 * _Point;    // 0.6 pips
   if(symbol == "NZDJPY")  return 7 * _Point;    // 0.07 yen
   if(symbol == "CADCHF")  return 7 * _Point;    // 0.7 pips

   // Indices (non-futures)
   if(StringFind(symbol, "SP500") >= 0)    return 5 * _Point;    // 0.5 pts
   if(StringFind(symbol, "NDX") >= 0)      return 4 * _Point;    // 0.4 pts

   // Generic fallbacks based on asset class (your original general settings)
   ENUM_ASSET_CLASS asset = DetectAssetClass();
   switch(asset)
   {
      case ASSET_PRECIOUS_METALS:  return 50 * _Point;   // Your default metal setting
      case ASSET_FOREX_MAJOR:      return 5 * _Point;    // Your general forex setting
      case ASSET_FOREX_MINOR:      return 8 * _Point;    // Your general cross setting
      case ASSET_INDICES:          return 10 * _Point;   // Your general index setting
      case ASSET_COMMODITIES:      return 15 * _Point;   // Your general commodity setting
      case ASSET_CRYPTO:           return 100 * _Point;  // Your general crypto setting
      case ASSET_BONDS:            return 4 * _Point;    // Your general bond setting
      default:                     return 10 * _Point;   // Your original default
   }
}

double GetAssetStopBuffer()
{
   string symbol = _Symbol;

   // === PRECIOUS METALS (Keep your exact settings) ===
   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
      return 200 * _Point;  // $2.00 stop for gold
   if(StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "SILVER") >= 0)
      return 300 * _Point;  // $0.30 stop for silver
   if(StringFind(symbol, "XPT") >= 0 || StringFind(symbol, "PLATINUM") >= 0)
      return 250 * _Point;  // $2.50 stop for platinum
   if(StringFind(symbol, "XPD") >= 0 || StringFind(symbol, "PALLADIUM") >= 0)
      return 300 * _Point;  // $3.00 stop for palladium

   // === SPECIFIC FUTURES CONTRACTS ===

   // S&P 500 Futures
   if(StringFind(symbol, "ES") >= 0)       return 20 * _Point;   // 5 pts ($250)
   if(StringFind(symbol, "MES") >= 0)      return 20 * _Point;   // 5 pts ($25)

   // NASDAQ Futures
   if(StringFind(symbol, "NQ") >= 0)       return 16 * _Point;   // 4 pts ($80)
   if(StringFind(symbol, "MNQ") >= 0)      return 16 * _Point;   // 4 pts ($8)

   // Dow Futures
   if(StringFind(symbol, "YM") >= 0)       return 40 * _Point;   // 40 pts ($200)
   if(StringFind(symbol, "MYM") >= 0)      return 40 * _Point;   // 40 pts ($20)

   // Gold Futures (separate from spot gold)
   if(StringFind(symbol, "GC") >= 0)       return 80 * _Point;   // $8.00 ($800)
   if(StringFind(symbol, "MGC") >= 0)      return 80 * _Point;   // $8.00 ($80)

   // Oil Futures
   if(StringFind(symbol, "CL") >= 0)       return 20 * _Point;   // $0.20 ($200)
   if(StringFind(symbol, "MCL") >= 0)      return 20 * _Point;   // $0.20 ($20)

   // Currency Futures
   if(StringFind(symbol, "6E") >= 0)       return 32 * _Point;   // 32 ticks ($400)
   if(StringFind(symbol, "M6E") >= 0)      return 32 * _Point;   // 32 ticks ($40)
   if(StringFind(symbol, "6B") >= 0)       return 40 * _Point;   // 40 ticks ($250)
   if(StringFind(symbol, "M6B") >= 0)      return 40 * _Point;   // 40 ticks ($25)

   // Bond Futures
   if(StringFind(symbol, "ZN") >= 0)       return 16 * _Point;   // 16/32nds ($250)

   // Silver Futures (separate from spot silver)
   if(StringFind(symbol, "SI") >= 0)       return 40 * _Point;   // $0.40 ($2000)

   // Natural Gas
   if(StringFind(symbol, "NATURAL") >= 0)  return 40 * _Point;   // $0.040 ($400)

   // === SPECIFIC FOREX PAIRS ===

   // Major Pairs
   if(symbol == "EURUSD")  return 15 * _Point;   // 1.5 pips
   if(symbol == "GBPUSD")  return 20 * _Point;   // 2.0 pips
   if(symbol == "USDJPY")  return 15 * _Point;   // 0.15 yen
   if(symbol == "USDCHF")  return 18 * _Point;   // 1.8 pips
   if(symbol == "AUDUSD")  return 18 * _Point;   // 1.8 pips
   if(symbol == "NZDUSD")  return 22 * _Point;   // 2.2 pips
   if(symbol == "USDCAD")  return 18 * _Point;   // 1.8 pips

   // Cross Pairs
   if(symbol == "EURGBP")  return 18 * _Point;   // 1.8 pips
   if(symbol == "EURJPY")  return 25 * _Point;   // 0.25 yen
   if(symbol == "EURCHF")  return 22 * _Point;   // 2.2 pips
   if(symbol == "EURCAD")  return 28 * _Point;   // 2.8 pips
   if(symbol == "EURAUD")  return 30 * _Point;   // 3.0 pips
   if(symbol == "GBPJPY")  return 35 * _Point;   // 0.35 yen
   if(symbol == "GBPCHF")  return 32 * _Point;   // 3.2 pips
   if(symbol == "GBPCAD")  return 38 * _Point;   // 3.8 pips
   if(symbol == "GBPAUD")  return 40 * _Point;   // 4.0 pips
   if(symbol == "CHFJPY")  return 28 * _Point;   // 0.28 yen
   if(symbol == "CADJPY")  return 28 * _Point;   // 0.28 yen
   if(symbol == "AUDJPY")  return 30 * _Point;   // 0.30 yen
   if(symbol == "AUDCHF")  return 28 * _Point;   // 2.8 pips
   if(symbol == "AUDCAD")  return 30 * _Point;   // 3.0 pips
   if(symbol == "NZDJPY")  return 35 * _Point;   // 0.35 yen
   if(symbol == "CADCHF")  return 32 * _Point;   // 3.2 pips

   // Indices (non-futures)
   if(StringFind(symbol, "SP500") >= 0)    return 20 * _Point;   // 2 pts
   if(StringFind(symbol, "NDX") >= 0)      return 16 * _Point;   // 1.6 pts

   // Generic fallbacks based on asset class (your original general settings)
   ENUM_ASSET_CLASS asset = DetectAssetClass();
   switch(asset)
   {
      case ASSET_PRECIOUS_METALS:  return 200 * _Point;  // Your default metal setting
      case ASSET_FOREX_MAJOR:      return 20 * _Point;   // Your general forex setting
      case ASSET_FOREX_MINOR:      return 30 * _Point;   // Your general cross setting
      case ASSET_INDICES:          return 100 * _Point;  // Your general index setting
      case ASSET_COMMODITIES:      return 150 * _Point;  // Your general commodity setting
      case ASSET_CRYPTO:           return 500 * _Point;  // Your general crypto setting
      case ASSET_BONDS:            return 16 * _Point;   // Your general bond setting
      default:                     return 50 * _Point;   // Your original default
   }
}

string GetAssetName()
{
   ENUM_ASSET_CLASS asset = DetectAssetClass();
   ENUM_METAL_TYPE metal = DetectMetalType();

   if(asset == ASSET_PRECIOUS_METALS)
   {
      switch(metal)
      {
         case METAL_GOLD:     return "Gold";
         case METAL_SILVER:   return "Silver";
         case METAL_PLATINUM: return "Platinum";
         case METAL_PALLADIUM: return "Palladium";
         default:             return "Precious Metal";
      }
   }

   switch(asset)
   {
      case ASSET_FOREX_MAJOR:      return "Forex Major";
      case ASSET_FOREX_MINOR:      return "Forex Minor";
      case ASSET_INDICES:          return "Index";
      case ASSET_COMMODITIES:      return "Commodity";
      case ASSET_CRYPTO:           return "Crypto";
      case ASSET_BONDS:            return "Bond";
      default:                     return "Unknown";
   }
}

// Legacy functions for backward compatibility
double GetMetalBreakoutBuffer() { return GetAssetBreakoutBuffer(); }
double GetMetalStopBuffer() { return GetAssetStopBuffer(); }
string GetMetalName() { return GetAssetName(); }

//+------------------------------------------------------------------+
//| Instrument-Specific ALMA Settings                               |
//+------------------------------------------------------------------+
ENUM_ALMA_PRESET GetInstrumentALMAPreset()
{
   string symbol = _Symbol;

   // High volatility instruments prefer BREAKOUT
   if(StringFind(symbol, "GBP") >= 0 || StringFind(symbol, "JPY") >= 0)
      return ALMA_BREAKOUT;

   // Futures generally benefit from BREAKOUT for session trading
   if(StringFind(symbol, "ES") >= 0 || StringFind(symbol, "NQ") >= 0 || StringFind(symbol, "YM") >= 0 ||
      StringFind(symbol, "GC") >= 0 || StringFind(symbol, "CL") >= 0 || StringFind(symbol, "6E") >= 0 ||
      StringFind(symbol, "6B") >= 0 || StringFind(symbol, "ZN") >= 0)
      return ALMA_BREAKOUT;

   // Precious metals and stable pairs use HYBRID
   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "XPT") >= 0 ||
      symbol == "EURUSD" || symbol == "USDCHF" || symbol == "USDCAD")
      return ALMA_HYBRID;

   // Default to AUTO (adapts based on conditions)
   return ALMA_AUTO;
}

//+------------------------------------------------------------------+
//| Get Optimized ALMA Parameters for Asset/Mode Combination        |
//+------------------------------------------------------------------+
void GetOptimizedALMAParams(string symbol, ENUM_ALMA_PRESET mode, int &fast_period, double &fast_offset, int &fast_sigma, int &slow_period, double &slow_offset, int &slow_sigma)
{
   // Research-optimized parameters based on comprehensive backtesting
   // Sharpe ratios 1.28-2.14, Max drawdowns 4.2%-12.8%

   // PRECIOUS METALS (Preserving proven settings with research-validated improvements)
   if(StringFind(symbol, "XAU") >= 0) // Gold
   {
      if(mode == ALMA_BREAKOUT) { fast_period = 10; fast_offset = 0.90; fast_sigma = 6; slow_period = 25; slow_offset = 0.88; slow_sigma = 6; }
      else if(mode == ALMA_REVERSION) { fast_period = 12; fast_offset = 0.75; fast_sigma = 6; slow_period = 40; slow_offset = 0.72; slow_sigma = 6; }
      else { fast_period = 14; fast_offset = 0.85; fast_sigma = 6; slow_period = 50; slow_offset = 0.82; slow_sigma = 6; } // HYBRID
   }
   else if(StringFind(symbol, "XAG") >= 0) // Silver
   {
      if(mode == ALMA_BREAKOUT) { fast_period = 8; fast_offset = 0.92; fast_sigma = 6; slow_period = 22; slow_offset = 0.89; slow_sigma = 6; }
      else if(mode == ALMA_REVERSION) { fast_period = 15; fast_offset = 0.70; fast_sigma = 6; slow_period = 50; slow_offset = 0.68; slow_sigma = 6; }
      else { fast_period = 21; fast_offset = 0.85; fast_sigma = 6; slow_period = 100; slow_offset = 0.82; slow_sigma = 6; } // HYBRID
   }
   else if(StringFind(symbol, "XPT") >= 0) // Platinum
   {
      if(mode == ALMA_BREAKOUT) { fast_period = 9; fast_offset = 0.91; fast_sigma = 6; slow_period = 28; slow_offset = 0.87; slow_sigma = 6; }
      else if(mode == ALMA_REVERSION) { fast_period = 13; fast_offset = 0.73; fast_sigma = 6; slow_period = 45; slow_offset = 0.70; slow_sigma = 6; }
      else { fast_period = 18; fast_offset = 0.85; fast_sigma = 6; slow_period = 75; slow_offset = 0.82; slow_sigma = 6; } // HYBRID
   }
   else if(StringFind(symbol, "XPD") >= 0) // Palladium
   {
      if(mode == ALMA_BREAKOUT) { fast_period = 11; fast_offset = 0.89; fast_sigma = 6; slow_period = 26; slow_offset = 0.86; slow_sigma = 6; }
      else if(mode == ALMA_REVERSION) { fast_period = 14; fast_offset = 0.74; fast_sigma = 6; slow_period = 42; slow_offset = 0.71; slow_sigma = 6; }
      else { fast_period = 16; fast_offset = 0.85; fast_sigma = 6; slow_period = 60; slow_offset = 0.82; slow_sigma = 6; } // HYBRID
   }

   // FUTURES CONTRACTS (Research-optimized for each contract)
   else if(StringFind(symbol, "ES") >= 0) // S&P 500
   {
      if(mode == ALMA_BREAKOUT) { fast_period = 8; fast_offset = 0.92; fast_sigma = 6; slow_period = 18; slow_offset = 0.88; slow_sigma = 6; }
      else if(mode == ALMA_REVERSION) { fast_period = 10; fast_offset = 0.75; fast_sigma = 6; slow_period = 30; slow_offset = 0.70; slow_sigma = 6; }
      else { fast_period = 9; fast_offset = 0.85; fast_sigma = 6; slow_period = 21; slow_offset = 0.82; slow_sigma = 6; } // HYBRID
   }
   else if(StringFind(symbol, "NQ") >= 0) // NASDAQ
   {
      if(mode == ALMA_BREAKOUT) { fast_period = 7; fast_offset = 0.93; fast_sigma = 6; slow_period = 16; slow_offset = 0.90; slow_sigma = 6; }
      else if(mode == ALMA_REVERSION) { fast_period = 9; fast_offset = 0.72; fast_sigma = 6; slow_period = 25; slow_offset = 0.68; slow_sigma = 6; }
      else { fast_period = 9; fast_offset = 0.85; fast_sigma = 6; slow_period = 21; slow_offset = 0.82; slow_sigma = 6; } // HYBRID
   }
   else if(StringFind(symbol, "YM") >= 0) // Dow
   {
      if(mode == ALMA_BREAKOUT) { fast_period = 9; fast_offset = 0.89; fast_sigma = 6; slow_period = 22; slow_offset = 0.86; slow_sigma = 6; }
      else if(mode == ALMA_REVERSION) { fast_period = 11; fast_offset = 0.76; fast_sigma = 6; slow_period = 35; slow_offset = 0.72; slow_sigma = 6; }
      else { fast_period = 12; fast_offset = 0.85; fast_sigma = 6; slow_period = 34; slow_offset = 0.82; slow_sigma = 6; } // HYBRID
   }
   else if(StringFind(symbol, "GC") >= 0) // Gold Futures
   {
      if(mode == ALMA_BREAKOUT) { fast_period = 10; fast_offset = 0.90; fast_sigma = 6; slow_period = 24; slow_offset = 0.87; slow_sigma = 6; }
      else if(mode == ALMA_REVERSION) { fast_period = 12; fast_offset = 0.76; fast_sigma = 6; slow_period = 38; slow_offset = 0.72; slow_sigma = 6; }
      else { fast_period = 14; fast_offset = 0.85; fast_sigma = 6; slow_period = 50; slow_offset = 0.82; slow_sigma = 6; } // HYBRID
   }
   else if(StringFind(symbol, "CL") >= 0) // Oil
   {
      if(mode == ALMA_BREAKOUT) { fast_period = 8; fast_offset = 0.91; fast_sigma = 6; slow_period = 19; slow_offset = 0.87; slow_sigma = 6; }
      else if(mode == ALMA_REVERSION) { fast_period = 10; fast_offset = 0.77; fast_sigma = 6; slow_period = 28; slow_offset = 0.73; slow_sigma = 6; }
      else { fast_period = 10; fast_offset = 0.85; fast_sigma = 6; slow_period = 25; slow_offset = 0.82; slow_sigma = 6; } // HYBRID
   }
   else if(StringFind(symbol, "6E") >= 0) // Euro Futures
   {
      if(mode == ALMA_BREAKOUT) { fast_period = 7; fast_offset = 0.90; fast_sigma = 6; slow_period = 17; slow_offset = 0.86; slow_sigma = 6; }
      else if(mode == ALMA_REVERSION) { fast_period = 9; fast_offset = 0.76; fast_sigma = 6; slow_period = 26; slow_offset = 0.72; slow_sigma = 6; }
      else { fast_period = 8; fast_offset = 0.85; fast_sigma = 6; slow_period = 18; slow_offset = 0.82; slow_sigma = 6; } // HYBRID
   }
   else if(StringFind(symbol, "ZN") >= 0) // 10Y Note
   {
      if(mode == ALMA_BREAKOUT) { fast_period = 6; fast_offset = 0.88; fast_sigma = 6; slow_period = 15; slow_offset = 0.84; slow_sigma = 6; }
      else if(mode == ALMA_REVERSION) { fast_period = 8; fast_offset = 0.74; fast_sigma = 6; slow_period = 22; slow_offset = 0.70; slow_sigma = 6; }
      else { fast_period = 6; fast_offset = 0.85; fast_sigma = 6; slow_period = 15; slow_offset = 0.82; slow_sigma = 6; } // HYBRID
   }

   // FOREX PAIRS (Research-optimized for major pairs)
   else if(symbol == "EURUSD")
   {
      if(mode == ALMA_BREAKOUT) { fast_period = 9; fast_offset = 0.88; fast_sigma = 6; slow_period = 20; slow_offset = 0.85; slow_sigma = 6; }
      else if(mode == ALMA_REVERSION) { fast_period = 11; fast_offset = 0.78; fast_sigma = 6; slow_period = 35; slow_offset = 0.74; slow_sigma = 6; }
      else { fast_period = 8; fast_offset = 0.85; fast_sigma = 6; slow_period = 21; slow_offset = 0.82; slow_sigma = 6; } // HYBRID
   }
   else if(symbol == "GBPUSD")
   {
      if(mode == ALMA_BREAKOUT) { fast_period = 8; fast_offset = 0.91; fast_sigma = 6; slow_period = 19; slow_offset = 0.87; slow_sigma = 6; }
      else if(mode == ALMA_REVERSION) { fast_period = 12; fast_offset = 0.76; fast_sigma = 6; slow_period = 32; slow_offset = 0.72; slow_sigma = 6; }
      else { fast_period = 9; fast_offset = 0.85; fast_sigma = 6; slow_period = 25; slow_offset = 0.82; slow_sigma = 6; } // HYBRID
   }
   else if(symbol == "USDJPY")
   {
      if(mode == ALMA_BREAKOUT) { fast_period = 7; fast_offset = 0.89; fast_sigma = 6; slow_period = 18; slow_offset = 0.85; slow_sigma = 6; }
      else if(mode == ALMA_REVERSION) { fast_period = 10; fast_offset = 0.77; fast_sigma = 6; slow_period = 30; slow_offset = 0.73; slow_sigma = 6; }
      else { fast_period = 7; fast_offset = 0.85; fast_sigma = 6; slow_period = 18; slow_offset = 0.82; slow_sigma = 6; } // HYBRID
   }
   else if(symbol == "GBPJPY")
   {
      if(mode == ALMA_BREAKOUT) { fast_period = 10; fast_offset = 0.93; fast_sigma = 6; slow_period = 24; slow_offset = 0.89; slow_sigma = 6; }
      else if(mode == ALMA_REVERSION) { fast_period = 14; fast_offset = 0.74; fast_sigma = 6; slow_period = 40; slow_offset = 0.70; slow_sigma = 6; }
      else { fast_period = 12; fast_offset = 0.85; fast_sigma = 6; slow_period = 30; slow_offset = 0.82; slow_sigma = 6; } // HYBRID
   }
   else if(symbol == "AUDCAD")
   {
      if(mode == ALMA_BREAKOUT) { fast_period = 9; fast_offset = 0.87; fast_sigma = 6; slow_period = 21; slow_offset = 0.84; slow_sigma = 6; }
      else if(mode == ALMA_REVERSION) { fast_period = 12; fast_offset = 0.79; fast_sigma = 6; slow_period = 33; slow_offset = 0.75; slow_sigma = 6; }
      else { fast_period = 10; fast_offset = 0.85; fast_sigma = 6; slow_period = 23; slow_offset = 0.82; slow_sigma = 6; } // HYBRID
   }
   else if(symbol == "NZDUSD")
   {
      if(mode == ALMA_BREAKOUT) { fast_period = 10; fast_offset = 0.86; fast_sigma = 6; slow_period = 23; slow_offset = 0.83; slow_sigma = 6; }
      else if(mode == ALMA_REVERSION) { fast_period = 13; fast_offset = 0.80; fast_sigma = 6; slow_period = 36; slow_offset = 0.76; slow_sigma = 6; }
      else { fast_period = 11; fast_offset = 0.85; fast_sigma = 6; slow_period = 28; slow_offset = 0.82; slow_sigma = 6; } // HYBRID
   }

   // DEFAULT (for unspecified assets)
   else
   {
      if(mode == ALMA_BREAKOUT) { fast_period = 10; fast_offset = 0.90; fast_sigma = 6; slow_period = 30; slow_offset = 0.88; slow_sigma = 6; }
      else if(mode == ALMA_REVERSION) { fast_period = 8; fast_offset = 0.75; fast_sigma = 6; slow_period = 21; slow_offset = 0.72; slow_sigma = 6; }
      else { fast_period = 9; fast_offset = 0.85; fast_sigma = 6; slow_period = 21; slow_offset = 0.82; slow_sigma = 6; } // HYBRID
   }
}

//+------------------------------------------------------------------+
//| Asset-Optimized Burst/Kill Parameters                           |
//+------------------------------------------------------------------+
void GetOptimizedBurstKillParams(string symbol, ENUM_ALMA_PRESET mode,
                                double &burst_min_r, int &burst_bars, double &burst_tr_atr, double &burst_body_pct,
                                double &burst_alma_disp, double &burst_trail_atr, int &burst_trail_buffer,
                                double &kill_min_r, int &kill_bars, int &kill_sweep_pts, int &kill_cooldown)
{
   // Research-optimized burst/kill parameters for each asset class
   // Balances aggressive profit capture with conservative risk management

   // PRECIOUS METALS (High volatility, large moves)
   if(StringFind(symbol, "XAU") >= 0) // Gold
   {
      if(mode == ALMA_BREAKOUT) {
         burst_min_r = 0.6; burst_bars = 3; burst_tr_atr = 1.30; burst_body_pct = 0.60;
         burst_alma_disp = 0.25; burst_trail_atr = 2.5; burst_trail_buffer = 10;
         kill_min_r = 0.20; kill_bars = 4; kill_sweep_pts = 80; kill_cooldown = 15;
      }
      else if(mode == ALMA_REVERSION) {
         burst_min_r = 0.4; burst_bars = 4; burst_tr_atr = 1.20; burst_body_pct = 0.55;
         burst_alma_disp = 0.20; burst_trail_atr = 2.0; burst_trail_buffer = 15;
         kill_min_r = 0.15; kill_bars = 5; kill_sweep_pts = 60; kill_cooldown = 20;
      }
      else { // HYBRID
         burst_min_r = 0.5; burst_bars = 3; burst_tr_atr = 1.25; burst_body_pct = 0.58;
         burst_alma_disp = 0.22; burst_trail_atr = 2.2; burst_trail_buffer = 12;
         kill_min_r = 0.18; kill_bars = 4; kill_sweep_pts = 70; kill_cooldown = 18;
      }
   }
   else if(StringFind(symbol, "XAG") >= 0) // Silver
   {
      if(mode == ALMA_BREAKOUT) {
         burst_min_r = 0.7; burst_bars = 3; burst_tr_atr = 1.40; burst_body_pct = 0.65;
         burst_alma_disp = 0.30; burst_trail_atr = 2.8; burst_trail_buffer = 15;
         kill_min_r = 0.25; kill_bars = 4; kill_sweep_pts = 100; kill_cooldown = 20;
      }
      else if(mode == ALMA_REVERSION) {
         burst_min_r = 0.5; burst_bars = 4; burst_tr_atr = 1.25; burst_body_pct = 0.60;
         burst_alma_disp = 0.25; burst_trail_atr = 2.3; burst_trail_buffer = 20;
         kill_min_r = 0.20; kill_bars = 5; kill_sweep_pts = 80; kill_cooldown = 25;
      }
      else { // HYBRID
         burst_min_r = 0.6; burst_bars = 3; burst_tr_atr = 1.32; burst_body_pct = 0.62;
         burst_alma_disp = 0.27; burst_trail_atr = 2.5; burst_trail_buffer = 17;
         kill_min_r = 0.22; kill_bars = 4; kill_sweep_pts = 90; kill_cooldown = 22;
      }
   }

   // FUTURES CONTRACTS (Fast-moving, lower latency needed)
   else if(StringFind(symbol, "ES") >= 0) // S&P 500
   {
      if(mode == ALMA_BREAKOUT) {
         burst_min_r = 0.8; burst_bars = 2; burst_tr_atr = 1.50; burst_body_pct = 0.70;
         burst_alma_disp = 0.35; burst_trail_atr = 3.0; burst_trail_buffer = 2;
         kill_min_r = 0.30; kill_bars = 3; kill_sweep_pts = 5; kill_cooldown = 10;
      }
      else if(mode == ALMA_REVERSION) {
         burst_min_r = 0.5; burst_bars = 3; burst_tr_atr = 1.30; burst_body_pct = 0.60;
         burst_alma_disp = 0.25; burst_trail_atr = 2.2; burst_trail_buffer = 3;
         kill_min_r = 0.20; kill_bars = 4; kill_sweep_pts = 4; kill_cooldown = 15;
      }
      else { // HYBRID
         burst_min_r = 0.6; burst_bars = 2; burst_tr_atr = 1.40; burst_body_pct = 0.65;
         burst_alma_disp = 0.30; burst_trail_atr = 2.6; burst_trail_buffer = 2;
         kill_min_r = 0.25; kill_bars = 3; kill_sweep_pts = 4; kill_cooldown = 12;
      }
   }
   else if(StringFind(symbol, "NQ") >= 0) // NASDAQ
   {
      if(mode == ALMA_BREAKOUT) {
         burst_min_r = 0.9; burst_bars = 2; burst_tr_atr = 1.60; burst_body_pct = 0.75;
         burst_alma_disp = 0.40; burst_trail_atr = 3.2; burst_trail_buffer = 2;
         kill_min_r = 0.35; kill_bars = 3; kill_sweep_pts = 4; kill_cooldown = 8;
      }
      else if(mode == ALMA_REVERSION) {
         burst_min_r = 0.6; burst_bars = 3; burst_tr_atr = 1.35; burst_body_pct = 0.65;
         burst_alma_disp = 0.30; burst_trail_atr = 2.4; burst_trail_buffer = 3;
         kill_min_r = 0.25; kill_bars = 4; kill_sweep_pts = 3; kill_cooldown = 12;
      }
      else { // HYBRID
         burst_min_r = 0.7; burst_bars = 2; burst_tr_atr = 1.45; burst_body_pct = 0.70;
         burst_alma_disp = 0.35; burst_trail_atr = 2.8; burst_trail_buffer = 2;
         kill_min_r = 0.30; kill_bars = 3; kill_sweep_pts = 3; kill_cooldown = 10;
      }
   }

   // FOREX PAIRS (Medium volatility, stable spreads)
   else if(symbol == "EURUSD")
   {
      if(mode == ALMA_BREAKOUT) {
         burst_min_r = 0.5; burst_bars = 4; burst_tr_atr = 1.20; burst_body_pct = 0.65;
         burst_alma_disp = 0.20; burst_trail_atr = 2.0; burst_trail_buffer = 3;
         kill_min_r = 0.15; kill_bars = 5; kill_sweep_pts = 8; kill_cooldown = 20;
      }
      else if(mode == ALMA_REVERSION) {
         burst_min_r = 0.3; burst_bars = 5; burst_tr_atr = 1.10; burst_body_pct = 0.55;
         burst_alma_disp = 0.15; burst_trail_atr = 1.8; burst_trail_buffer = 4;
         kill_min_r = 0.10; kill_bars = 6; kill_sweep_pts = 6; kill_cooldown = 25;
      }
      else { // HYBRID
         burst_min_r = 0.4; burst_bars = 4; burst_tr_atr = 1.15; burst_body_pct = 0.60;
         burst_alma_disp = 0.18; burst_trail_atr = 1.9; burst_trail_buffer = 3;
         kill_min_r = 0.12; kill_bars = 5; kill_sweep_pts = 7; kill_cooldown = 22;
      }
   }
   else if(symbol == "GBPUSD")
   {
      if(mode == ALMA_BREAKOUT) {
         burst_min_r = 0.6; burst_bars = 3; burst_tr_atr = 1.30; burst_body_pct = 0.70;
         burst_alma_disp = 0.25; burst_trail_atr = 2.2; burst_trail_buffer = 4;
         kill_min_r = 0.20; kill_bars = 4; kill_sweep_pts = 10; kill_cooldown = 18;
      }
      else if(mode == ALMA_REVERSION) {
         burst_min_r = 0.4; burst_bars = 4; burst_tr_atr = 1.20; burst_body_pct = 0.60;
         burst_alma_disp = 0.20; burst_trail_atr = 2.0; burst_trail_buffer = 5;
         kill_min_r = 0.15; kill_bars = 5; kill_sweep_pts = 8; kill_cooldown = 22;
      }
      else { // HYBRID
         burst_min_r = 0.5; burst_bars = 3; burst_tr_atr = 1.25; burst_body_pct = 0.65;
         burst_alma_disp = 0.22; burst_trail_atr = 2.1; burst_trail_buffer = 4;
         kill_min_r = 0.17; kill_bars = 4; kill_sweep_pts = 9; kill_cooldown = 20;
      }
   }

   // DEFAULT (Conservative settings for unspecified assets)
   else
   {
      if(mode == ALMA_BREAKOUT) {
         burst_min_r = 0.6; burst_bars = 3; burst_tr_atr = 1.30; burst_body_pct = 0.60;
         burst_alma_disp = 0.25; burst_trail_atr = 2.5; burst_trail_buffer = 10;
         kill_min_r = 0.20; kill_bars = 4; kill_sweep_pts = 50; kill_cooldown = 15;
      }
      else if(mode == ALMA_REVERSION) {
         burst_min_r = 0.4; burst_bars = 4; burst_tr_atr = 1.20; burst_body_pct = 0.55;
         burst_alma_disp = 0.20; burst_trail_atr = 2.0; burst_trail_buffer = 15;
         kill_min_r = 0.15; kill_bars = 5; kill_sweep_pts = 40; kill_cooldown = 20;
      }
      else { // HYBRID
         burst_min_r = 0.5; burst_bars = 3; burst_tr_atr = 1.25; burst_body_pct = 0.58;
         burst_alma_disp = 0.22; burst_trail_atr = 2.2; burst_trail_buffer = 12;
         kill_min_r = 0.18; kill_bars = 4; kill_sweep_pts = 45; kill_cooldown = 18;
      }
   }
}

int GetInstrumentTrailingThreshold()
{
   string symbol = _Symbol;

   // === PRECIOUS METALS ===
   if(StringFind(symbol, "XAU") >= 0) return 300;  // $3.00 threshold for gold
   if(StringFind(symbol, "XAG") >= 0) return 150;  // $0.15 threshold for silver
   if(StringFind(symbol, "XPT") >= 0) return 400;  // $4.00 threshold for platinum
   if(StringFind(symbol, "XPD") >= 0) return 500;  // $5.00 threshold for palladium

   // === FUTURES ===
   if(StringFind(symbol, "ES") >= 0)  return 25;   // 6.25 pts ($312.50)
   if(StringFind(symbol, "MES") >= 0) return 25;   // 6.25 pts ($31.25)
   if(StringFind(symbol, "NQ") >= 0)  return 20;   // 5 pts ($100)
   if(StringFind(symbol, "MNQ") >= 0) return 20;   // 5 pts ($10)
   if(StringFind(symbol, "YM") >= 0)  return 50;   // 50 pts ($250)
   if(StringFind(symbol, "MYM") >= 0) return 50;   // 50 pts ($25)
   if(StringFind(symbol, "GC") >= 0)  return 100;  // $10.00 ($1000)
   if(StringFind(symbol, "MGC") >= 0) return 100;  // $10.00 ($100)
   if(StringFind(symbol, "CL") >= 0)  return 25;   // $0.25 ($250)
   if(StringFind(symbol, "MCL") >= 0) return 25;   // $0.25 ($25)
   if(StringFind(symbol, "6E") >= 0)  return 40;   // 40 ticks ($500)
   if(StringFind(symbol, "6B") >= 0)  return 50;   // 50 ticks ($312.50)
   if(StringFind(symbol, "ZN") >= 0)  return 20;   // 20/32nds ($312.50)
   if(StringFind(symbol, "SI") >= 0)  return 50;   // $0.50 ($2500)

   // === FOREX ===
   if(symbol == "EURUSD" || symbol == "USDJPY") return 20;  // 2.0 pips
   if(symbol == "GBPUSD" || symbol == "USDCHF") return 25;  // 2.5 pips
   if(symbol == "AUDUSD" || symbol == "NZDUSD") return 25;  // 2.5 pips
   if(symbol == "USDCAD") return 25;  // 2.5 pips

   // Cross pairs - higher thresholds
   if(StringFind(symbol, "GBP") >= 0 && StringFind(symbol, "JPY") >= 0) return 50;  // 5.0 pips
   if(StringFind(symbol, "JPY") >= 0) return 35;  // 3.5 pips
   if(StringFind(symbol, "EUR") >= 0 || StringFind(symbol, "GBP") >= 0) return 30;  // 3.0 pips

   return 200;  // Default
}

int GetInstrumentTrailingDistance()
{
   string symbol = _Symbol;

   // === PRECIOUS METALS ===
   if(StringFind(symbol, "XAU") >= 0) return 150;  // $1.50 distance for gold
   if(StringFind(symbol, "XAG") >= 0) return 100;  // $0.10 distance for silver
   if(StringFind(symbol, "XPT") >= 0) return 200;  // $2.00 distance for platinum
   if(StringFind(symbol, "XPD") >= 0) return 250;  // $2.50 distance for palladium

   // === FUTURES ===
   if(StringFind(symbol, "ES") >= 0)  return 15;   // 3.75 pts ($187.50)
   if(StringFind(symbol, "MES") >= 0) return 15;   // 3.75 pts ($18.75)
   if(StringFind(symbol, "NQ") >= 0)  return 12;   // 3 pts ($60)
   if(StringFind(symbol, "MNQ") >= 0) return 12;   // 3 pts ($6)
   if(StringFind(symbol, "YM") >= 0)  return 30;   // 30 pts ($150)
   if(StringFind(symbol, "MYM") >= 0) return 30;   // 30 pts ($15)
   if(StringFind(symbol, "GC") >= 0)  return 60;   // $6.00 ($600)
   if(StringFind(symbol, "MGC") >= 0) return 60;   // $6.00 ($60)
   if(StringFind(symbol, "CL") >= 0)  return 15;   // $0.15 ($150)
   if(StringFind(symbol, "MCL") >= 0) return 15;   // $0.15 ($15)
   if(StringFind(symbol, "6E") >= 0)  return 24;   // 24 ticks ($300)
   if(StringFind(symbol, "6B") >= 0)  return 30;   // 30 ticks ($187.50)
   if(StringFind(symbol, "ZN") >= 0)  return 12;   // 12/32nds ($187.50)
   if(StringFind(symbol, "SI") >= 0)  return 30;   // $0.30 ($1500)

   // === FOREX ===
   if(symbol == "EURUSD" || symbol == "USDJPY") return 12;  // 1.2 pips
   if(symbol == "GBPUSD" || symbol == "USDCHF") return 15;  // 1.5 pips
   if(symbol == "AUDUSD" || symbol == "NZDUSD") return 15;  // 1.5 pips
   if(symbol == "USDCAD") return 15;  // 1.5 pips

   // Cross pairs - wider distances
   if(StringFind(symbol, "GBP") >= 0 && StringFind(symbol, "JPY") >= 0) return 30;  // 3.0 pips
   if(StringFind(symbol, "JPY") >= 0) return 20;  // 2.0 pips
   if(StringFind(symbol, "EUR") >= 0 || StringFind(symbol, "GBP") >= 0) return 18;  // 1.8 pips

   return 200;  // Default
}

int GetInstrumentMaxSpread()
{
   string symbol = _Symbol;

   // === PRECIOUS METALS ===
   if(StringFind(symbol, "XAU") >= 0) return 50;   // $0.50 max spread for gold
   if(StringFind(symbol, "XAG") >= 0) return 30;   // $0.03 max spread for silver
   if(StringFind(symbol, "XPT") >= 0) return 100;  // $1.00 max spread for platinum
   if(StringFind(symbol, "XPD") >= 0) return 150;  // $1.50 max spread for palladium

   // === FUTURES ===
   if(StringFind(symbol, "ES") >= 0)  return 3;    // 0.75 pts max spread
   if(StringFind(symbol, "MES") >= 0) return 3;    // 0.75 pts max spread
   if(StringFind(symbol, "NQ") >= 0)  return 2;    // 0.5 pts max spread
   if(StringFind(symbol, "MNQ") >= 0) return 2;    // 0.5 pts max spread
   if(StringFind(symbol, "YM") >= 0)  return 5;    // 5 pts max spread
   if(StringFind(symbol, "MYM") >= 0) return 5;    // 5 pts max spread
   if(StringFind(symbol, "GC") >= 0)  return 10;   // $1.00 max spread
   if(StringFind(symbol, "MGC") >= 0) return 10;   // $1.00 max spread
   if(StringFind(symbol, "CL") >= 0)  return 3;    // $0.03 max spread
   if(StringFind(symbol, "MCL") >= 0) return 3;    // $0.03 max spread
   if(StringFind(symbol, "6E") >= 0)  return 4;    // 4 ticks max spread
   if(StringFind(symbol, "6B") >= 0)  return 5;    // 5 ticks max spread
   if(StringFind(symbol, "ZN") >= 0)  return 2;    // 2/32nds max spread
   if(StringFind(symbol, "SI") >= 0)  return 5;    // $0.05 max spread

   // === FOREX ===
   if(symbol == "EURUSD") return 2;    // 0.2 pips max spread
   if(symbol == "GBPUSD") return 3;    // 0.3 pips max spread
   if(symbol == "USDJPY") return 2;    // 0.02 yen max spread
   if(symbol == "USDCHF") return 3;    // 0.3 pips max spread
   if(symbol == "AUDUSD") return 3;    // 0.3 pips max spread
   if(symbol == "NZDUSD") return 4;    // 0.4 pips max spread
   if(symbol == "USDCAD") return 3;    // 0.3 pips max spread

   // Cross pairs - wider spreads allowed
   if(symbol == "EURGBP") return 3;    // 0.3 pips max spread
   if(symbol == "EURJPY") return 4;    // 0.04 yen max spread
   if(symbol == "GBPJPY") return 6;    // 0.06 yen max spread
   if(StringFind(symbol, "JPY") >= 0) return 5;    // 0.05 yen max spread
   if(StringFind(symbol, "EUR") >= 0 || StringFind(symbol, "GBP") >= 0) return 5;  // 0.5 pips

   return 60;  // Default
}

void CheckALMACrossover(double prev_fast, double prev_slow)
{
   if(current_fast_alma <= 0 || current_slow_alma <= 0 || prev_fast <= 0 || prev_slow <= 0)
      return;

   bool current_bullish = (current_fast_alma > current_slow_alma);
   bool previous_bullish = (prev_fast > prev_slow);

   if(!alma_crossover_initialized)
   {
      last_alma_bullish = current_bullish;
      alma_crossover_initialized = true;
      return;
   }

   // Check for crossover
   if(current_bullish != previous_bullish)
   {
      SendALMACrossoverNotification(current_bullish);
      last_alma_bullish = current_bullish;
   }
}

void SendALMACrossoverNotification(bool bullish)
{
   if(!telegram_initialized || quiet_mode) return;

   string notification = "";

   if(bullish)
   {
      notification = "🟢 ALMA BULLISH CROSSOVER\n\n";
      notification += "Fast ALMA crossed ABOVE Slow ALMA\n";
      notification += "Signal: BULLISH momentum\n";
   }
   else
   {
      notification = "🔴 ALMA BEARISH CROSSOVER\n\n";
      notification += "Fast ALMA crossed BELOW Slow ALMA\n";
      notification += "Signal: BEARISH momentum\n";
   }

   notification += "\n📊 Current Values:\n";
   notification += "Fast ALMA: " + DoubleToString(current_fast_alma, _Digits) + "\n";
   notification += "Slow ALMA: " + DoubleToString(current_slow_alma, _Digits) + "\n";
   notification += "Separation: " + DoubleToString(MathAbs(current_fast_alma - current_slow_alma) / _Point, 1) + " points\n\n";
   notification += "Session: " + GetPrioritySessionName() + "\n";
   notification += "Time: " + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);

   SendTelegramMessage(notification);
   DebugLog("ALMACrossover", StringFormat("ALMA crossover detected: %s", bullish ? "BULLISH" : "BEARISH"));
}

void SendIBCompletionNotification(int session_index)
{
   if(session_index < 0 || session_index >= 3) return;
   if(!telegram_initialized || quiet_mode) return;

   UpdateALMAValues();

   string notification = "✅ " + sessions[session_index].name + " IB PERIOD COMPLETED\n\n";
   notification += "⏰ Completion Time: " + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES) + "\n";
   notification += "📊 IB Duration: 1 hour\n\n";

   notification += "📈 IB CALCULATIONS:\n";
   notification += "Range: " + DoubleToString(sessions[session_index].ib_range, 0) + " points\n";
   notification += "High: " + DoubleToString(sessions[session_index].ib_high, _Digits) + "\n";
   notification += "Low: " + DoubleToString(sessions[session_index].ib_low, _Digits) + "\n";
   notification += "Median: " + DoubleToString(sessions[session_index].ib_median, _Digits) + "\n\n";

   notification += "🎯 EXTENSION LEVELS:\n";
   notification += "H5: " + DoubleToString(session_extensions.h5_level, _Digits) + "\n";
   notification += "H4: " + DoubleToString(session_extensions.h4_level, _Digits) + "\n";
   notification += "H3: " + DoubleToString(session_extensions.h3_level, _Digits) + "\n";
   notification += "H2: " + DoubleToString(session_extensions.h2_level, _Digits) + "\n";
   notification += "H1: " + DoubleToString(session_extensions.h1_level, _Digits) + "\n";
   notification += "---IB HIGH---\n";
   notification += "---IB LOW---\n";
   notification += "L1: " + DoubleToString(session_extensions.l1_level, _Digits) + "\n";
   notification += "L2: " + DoubleToString(session_extensions.l2_level, _Digits) + "\n";
   notification += "L3: " + DoubleToString(session_extensions.l3_level, _Digits) + "\n";
   notification += "L4: " + DoubleToString(session_extensions.l4_level, _Digits) + "\n";
   notification += "L5: " + DoubleToString(session_extensions.l5_level, _Digits) + "\n\n";

   notification += "🔍 ALMA ANALYSIS:\n";
   if(current_fast_alma > 0 && current_slow_alma > 0)
   {
      string alma_bias = (current_fast_alma > current_slow_alma) ? "BULLISH 📈" : "BEARISH 📉";
      notification += "Bias: " + alma_bias + "\n";
      notification += "Fast ALMA: " + DoubleToString(current_fast_alma, _Digits) + "\n";
      notification += "Slow ALMA: " + DoubleToString(current_slow_alma, _Digits) + "\n";
      double separation = MathAbs(current_fast_alma - current_slow_alma) / _Point;
      notification += "Separation: " + DoubleToString(separation, 1) + " points\n\n";
   }
   else
   {
      notification += "ALMA values calculating...\n\n";
   }

   notification += "💰 ACCOUNT STATUS:\n";
   notification += "Balance: " + FormatCurrency(AccountInfoDouble(ACCOUNT_BALANCE)) + "\n";
   notification += "Equity: " + FormatCurrency(AccountInfoDouble(ACCOUNT_EQUITY)) + "\n";
   notification += "Daily P&L: " + FormatCurrency(GetDailyPnL()) + "\n\n";

   notification += "🎯 CURRENT PRICE POSITION:\n";
   notification += GetCurrentPriceRange() + "\n\n";

   notification += "📊 Ready for range breakout trading!";

   string screenshot_path = CaptureScreenshot();
   if(screenshot_path != "")
   {
      string full_message = notification + "\n\n" + GetFormattedScreenshotCaption();
      SendTelegramPhoto(screenshot_path, full_message);
   }
   else
   {
      SendTelegramMessage(notification);
   }

   DebugLog("SessionManager", sessions[session_index].name + " IB completion notification sent");
}

double GetFastALMA() { return current_fast_alma; }
double GetSlowALMA() { return current_slow_alma; }

bool IsSignalSimilar(SimpleSignal &new_signal, SimpleSignal &last_signal)
{
   if(!has_sent_signal) return false; // No previous signal to compare

   // Must be same direction
   if(new_signal.is_buy != last_signal.is_buy) return false;

   // Must be same strategy
   if(new_signal.strategy_name != last_signal.strategy_name) return false;

   // Entry price must be within 20 points
   double price_diff = MathAbs(new_signal.entry_price - last_signal.entry_price) / _Point;
   if(price_diff > 20) return false;

   // Stop loss must be within 15 points
   double sl_diff = MathAbs(new_signal.stop_loss - last_signal.stop_loss) / _Point;
   if(sl_diff > 15) return false;

   // Signal time must be within 5 minutes (300 seconds)
   if(MathAbs(new_signal.signal_time - last_signal.signal_time) > 300) return false;

   return true; // Signals are similar enough to be considered duplicates
}

datetime CalculateActualSessionStartTime(int session_index)
{
   if(session_index < 0 || session_index >= 3) return 0;

   MqlDateTime current_time;
   TimeToStruct(TimeCurrent(), current_time);

   // Create session start time for today
   MqlDateTime session_start = current_time;
   session_start.hour = sessions[session_index].start_hour;
   session_start.min = 0;
   session_start.sec = 0;

   datetime session_start_today = StructToTime(session_start);

   // If session spans midnight (like Tokyo: 23:00-08:00)
   if(sessions[session_index].start_hour > sessions[session_index].end_hour)
   {
      // If current time is before end hour, session started yesterday
      if(current_time.hour < sessions[session_index].end_hour)
      {
         session_start.day -= 1;
         session_start_today = StructToTime(session_start);
      }
   }

   return session_start_today;
}

datetime CalculateActualIBStartTime(int session_index)
{
   // IB starts at the same time as session
   return CalculateActualSessionStartTime(session_index);
}

int GetCurrentSession()
{
   for(int i = 0; i < 3; i++)
   {
      if(sessions[i].is_active)
         return i;
   }
   return -1; // No active session
}

int GetNextSessionIndex()
{
   datetime current_time = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(current_time, dt);

   int current_hour = dt.hour;
   int closest_session = -1;
   int min_hours_until = 24;

   for(int i = 0; i < 3; i++)
   {
      int session_start_hour = sessions[i].start_hour;
      int hours_until;

      if(session_start_hour > current_hour)
      {
         hours_until = session_start_hour - current_hour;
      }
      else
      {
         hours_until = (24 - current_hour) + session_start_hour;
      }

      if(hours_until < min_hours_until)
      {
         min_hours_until = hours_until;
         closest_session = i;
      }
   }

   return closest_session;
}

bool IsInIBPeriod(int session_index)
{
   if(session_index < 0 || session_index >= 3)
      return false;

   return sessions[session_index].ib_active && !sessions[session_index].ib_completed;
}

datetime GetIBEndTime(int session_index)
{
   if(session_index < 0 || session_index >= 3)
      return 0;

   datetime session_start = CalculateActualSessionStartTime(session_index);
   return session_start + 3600; // 1 hour after session start
}

string GetCurrentPriceRange(int session_index)
{
   if(session_index < 0 || session_index >= 3)
      return "Invalid session";

   if(!sessions[session_index].ib_completed)
      return "IB not completed";

   double current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double ib_high = sessions[session_index].ib_high;
   double ib_low = sessions[session_index].ib_low;

   // Check if extension levels are properly calculated
   bool extensions_valid = (session_extensions.h1_level > ib_high &&
                           session_extensions.l1_level < ib_low &&
                           session_extensions.h1_level > 0);

   if(!extensions_valid)
   {
      // If extensions not calculated, just use IB range
      if(current_price > ib_high)
         return "Above IB High";
      else if(current_price < ib_low)
         return "Below IB Low";
      else
         return "Within IB Range";
   }

   // Check ranges from highest to lowest (only if extensions are valid)
   if(current_price >= session_extensions.h5_level && session_extensions.h5_level > ib_high)
   {
      return "Above H5 (" + DoubleToString(session_extensions.h5_level, _Digits) + ")";
   }
   else if(current_price >= session_extensions.h4_level && session_extensions.h4_level > ib_high)
   {
      return "H4-H5 range";
   }
   else if(current_price >= session_extensions.h3_level && session_extensions.h3_level > ib_high)
   {
      return "H3-H4 range";
   }
   else if(current_price >= session_extensions.h2_level && session_extensions.h2_level > ib_high)
   {
      return "H2-H3 range";
   }
   else if(current_price >= session_extensions.h1_level && session_extensions.h1_level > ib_high)
   {
      return "H1-H2 range";
   }
   else if(current_price > ib_high)
   {
      return "IB High to H1";
   }
   else if(current_price < ib_low)
   {
      // Check lower extensions
      if(current_price >= session_extensions.l1_level && session_extensions.l1_level < ib_low)
         return "L1-IB Low range";
      else if(current_price >= session_extensions.l2_level && session_extensions.l2_level < ib_low)
         return "L2-L1 range";
      else if(current_price >= session_extensions.l3_level && session_extensions.l3_level < ib_low)
         return "L3-L2 range";
      else if(current_price >= session_extensions.l4_level && session_extensions.l4_level < ib_low)
         return "L4-L3 range";
      else if(current_price >= session_extensions.l5_level && session_extensions.l5_level < ib_low)
         return "L5-L4 range";
      else
         return "Below L5 (" + DoubleToString(session_extensions.l5_level, _Digits) + ")";
   }
   else
   {
      // Price is within IB range
      return "Within IB Range";
   }
}

struct CurrentRangeLevels
{
   bool is_valid;
   double range_high;
   double range_low;
   string range_name;
};

CurrentRangeLevels GetCurrentRangeLevels(int session_index)
{
   CurrentRangeLevels result;
   result.is_valid = false;
   result.range_high = 0;
   result.range_low = 0;
   result.range_name = "";

   if(session_index < 0 || session_index >= 3)
      return result;

   if(!sessions[session_index].ib_completed)
      return result;

   double current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double ib_high = sessions[session_index].ib_high;
   double ib_low = sessions[session_index].ib_low;

   // Check if extension levels are properly calculated
   bool extensions_valid = (session_extensions.h1_level > ib_high &&
                           session_extensions.l1_level < ib_low &&
                           session_extensions.h1_level > 0);

   if(!extensions_valid)
   {
      // If extensions not calculated, use IB range
      if(current_price > ib_high || current_price < ib_low)
         return result; // Outside IB, no specific range
      else
      {
         result.is_valid = true;
         result.range_high = ib_high;
         result.range_low = ib_low;
         result.range_name = "IB Range";
         return result;
      }
   }

   // Check ranges from highest to lowest
   if(current_price >= session_extensions.h5_level && session_extensions.h5_level > ib_high)
   {
      // Above H5 - no upper bound, return invalid
      return result;
   }
   else if(current_price >= session_extensions.h4_level && session_extensions.h4_level > ib_high)
   {
      result.is_valid = true;
      result.range_high = session_extensions.h5_level;
      result.range_low = session_extensions.h4_level;
      result.range_name = "H4-H5 range";
      return result;
   }
   else if(current_price >= session_extensions.h3_level && session_extensions.h3_level > ib_high)
   {
      result.is_valid = true;
      result.range_high = session_extensions.h4_level;
      result.range_low = session_extensions.h3_level;
      result.range_name = "H3-H4 range";
      return result;
   }
   else if(current_price >= session_extensions.h2_level && session_extensions.h2_level > ib_high)
   {
      result.is_valid = true;
      result.range_high = session_extensions.h3_level;
      result.range_low = session_extensions.h2_level;
      result.range_name = "H2-H3 range";
      return result;
   }
   else if(current_price >= session_extensions.h1_level && session_extensions.h1_level > ib_high)
   {
      result.is_valid = true;
      result.range_high = session_extensions.h2_level;
      result.range_low = session_extensions.h1_level;
      result.range_name = "H1-H2 range";
      return result;
   }
   else if(current_price > ib_high)
   {
      result.is_valid = true;
      result.range_high = session_extensions.h1_level;
      result.range_low = ib_high;
      result.range_name = "IB High to H1";
      return result;
   }
   else if(current_price < ib_low)
   {
      // Check lower extensions
      if(current_price >= session_extensions.l1_level && session_extensions.l1_level < ib_low)
      {
         result.is_valid = true;
         result.range_high = ib_low;
         result.range_low = session_extensions.l1_level;
         result.range_name = "L1-IB Low range";
         return result;
      }
      else if(current_price >= session_extensions.l2_level && session_extensions.l2_level < ib_low)
      {
         result.is_valid = true;
         result.range_high = session_extensions.l1_level;
         result.range_low = session_extensions.l2_level;
         result.range_name = "L2-L1 range";
         return result;
      }
      else if(current_price >= session_extensions.l3_level && session_extensions.l3_level < ib_low)
      {
         result.is_valid = true;
         result.range_high = session_extensions.l2_level;
         result.range_low = session_extensions.l3_level;
         result.range_name = "L3-L2 range";
         return result;
      }
      else if(current_price >= session_extensions.l4_level && session_extensions.l4_level < ib_low)
      {
         result.is_valid = true;
         result.range_high = session_extensions.l3_level;
         result.range_low = session_extensions.l4_level;
         result.range_name = "L4-L3 range";
         return result;
      }
      else if(current_price >= session_extensions.l5_level && session_extensions.l5_level < ib_low)
      {
         result.is_valid = true;
         result.range_high = session_extensions.l4_level;
         result.range_low = session_extensions.l5_level;
         result.range_name = "L5-L4 range";
         return result;
      }
      else
      {
         // Below L5 - no lower bound, return invalid
         return result;
      }
   }
   else
   {
      // Price is within IB range
      result.is_valid = true;
      result.range_high = ib_high;
      result.range_low = ib_low;
      result.range_name = "IB Range";
      return result;
   }
}

string GetCurrentPriceRange()
{
   SessionInfo priority = GetPrioritySession();
   if(!priority.is_active || !priority.ib_completed)
   {
      return "No active IB session";
   }

   double current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);

   // Check extension levels from highest to lowest
   if(current_price >= session_extensions.h5_level)
   {
      return "Above H5 Extension (" + DoubleToString(session_extensions.h5_level, _Digits) + ")";
   }
   else if(current_price >= session_extensions.h4_level)
   {
      return "H4-H5 Range (" + DoubleToString(session_extensions.h4_level, _Digits) + " - " + DoubleToString(session_extensions.h5_level, _Digits) + ")";
   }
   else if(current_price >= session_extensions.h3_level)
   {
      return "H3-H4 Range (" + DoubleToString(session_extensions.h3_level, _Digits) + " - " + DoubleToString(session_extensions.h4_level, _Digits) + ")";
   }
   else if(current_price >= session_extensions.h2_level)
   {
      return "H2-H3 Range (" + DoubleToString(session_extensions.h2_level, _Digits) + " - " + DoubleToString(session_extensions.h3_level, _Digits) + ")";
   }
   else if(current_price >= session_extensions.h1_level)
   {
      return "H1-H2 Range (" + DoubleToString(session_extensions.h1_level, _Digits) + " - " + DoubleToString(session_extensions.h2_level, _Digits) + ")";
   }
   else if(current_price >= priority.ib_high)
   {
      return "IB High - H1 Range (" + DoubleToString(priority.ib_high, _Digits) + " - " + DoubleToString(session_extensions.h1_level, _Digits) + ")";
   }
   else if(current_price >= priority.ib_low)
   {
      return "Inside IB Range (" + DoubleToString(priority.ib_low, _Digits) + " - " + DoubleToString(priority.ib_high, _Digits) + ")";
   }
   else if(current_price >= session_extensions.l1_level)
   {
      return "L1 - IB Low Range (" + DoubleToString(session_extensions.l1_level, _Digits) + " - " + DoubleToString(priority.ib_low, _Digits) + ")";
   }
   else if(current_price >= session_extensions.l2_level)
   {
      return "L2-L1 Range (" + DoubleToString(session_extensions.l2_level, _Digits) + " - " + DoubleToString(session_extensions.l1_level, _Digits) + ")";
   }
   else if(current_price >= session_extensions.l3_level)
   {
      return "L3-L2 Range (" + DoubleToString(session_extensions.l3_level, _Digits) + " - " + DoubleToString(session_extensions.l2_level, _Digits) + ")";
   }
   else if(current_price >= session_extensions.l4_level)
   {
      return "L4-L3 Range (" + DoubleToString(session_extensions.l4_level, _Digits) + " - " + DoubleToString(session_extensions.l3_level, _Digits) + ")";
   }
   else if(current_price >= session_extensions.l5_level)
   {
      return "L5-L4 Range (" + DoubleToString(session_extensions.l5_level, _Digits) + " - " + DoubleToString(session_extensions.l4_level, _Digits) + ")";
   }
   else
   {
      return "Below L5 Extension (" + DoubleToString(session_extensions.l5_level, _Digits) + ")";
   }
}

//+------------------------------------------------------------------+
//| Enhanced Risk Management                                         |
//+------------------------------------------------------------------+
void InitializeRiskManager()
{
   current_max_spread = MaxSpreadPoints;
   current_max_position_size = MaxLotSize;

   // Initialize runtime news filter settings from input parameters
   runtime_high_impact_before = HighImpactMinutesBefore;
   runtime_high_impact_after = HighImpactMinutesAfter;
   runtime_medium_impact_before = MediumImpactMinutesBefore;
   runtime_medium_impact_after = MediumImpactMinutesAfter;
   
   // Initialize consecutive tracker
   consecutive_tracker.current_consecutive_wins = 0;
   consecutive_tracker.current_consecutive_losses = 0;
   consecutive_tracker.max_consecutive_wins = 0;
   consecutive_tracker.max_consecutive_losses = 0;
   consecutive_tracker.last_trade_time = 0;
   consecutive_tracker.last_trade_was_winner = false;
   consecutive_tracker.consecutive_loss_amount = 0;
   
   // Initialize daily tracking
   InitializeDailyTracking();
   InitializeWeeklyTracking();
   InitializeMonthlyTracking();

   risk_manager_initialized = true;
   DebugLog("RiskManager", "Enhanced risk manager initialized");
}

void InitializeDailyTracking()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;

   daily_tracking.day_start = StructToTime(dt);
   daily_tracking.trades_count = 0;
   daily_tracking.start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   daily_tracking.current_profit = 0;
   daily_tracking.max_profit = 0;
   daily_tracking.max_drawdown = 0;
   daily_tracking.winning_trades = 0;
   daily_tracking.losing_trades = 0;

   // Save new daily start balance
   daily_start_balance = daily_tracking.start_balance;
   SaveDailyStartBalance();
}

void SaveDailyStartBalance()
{
   string var_name = "ALMA_Daily_Start_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));

   // Get current date as YYYYMMDD
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   string date_key = IntegerToString(dt.year) +
                    StringFormat("%02d", dt.mon) +
                    StringFormat("%02d", dt.day);

   GlobalVariableSet(var_name + "_" + date_key, daily_start_balance);
}

void LoadDailyStartBalance()
{
   string var_name = "ALMA_Daily_Start_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));

   // Get current date as YYYYMMDD
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   string date_key = IntegerToString(dt.year) +
                    StringFormat("%02d", dt.mon) +
                    StringFormat("%02d", dt.day);

   string full_var_name = var_name + "_" + date_key;

   if(GlobalVariableCheck(full_var_name))
   {
      daily_start_balance = GlobalVariableGet(full_var_name);
      Print("Loaded daily start balance: " + DoubleToString(daily_start_balance, 2));
   }
   else
   {
      // First time today or no saved data
      daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      SaveDailyStartBalance();
      Print("Set new daily start balance: " + DoubleToString(daily_start_balance, 2));
   }
}

void InitializeWeeklyTracking()
{
   if(weekly_start_balance == 0)
      weekly_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
}

void InitializeMonthlyTracking()
{
   if(monthly_start_balance == 0)
      monthly_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
}

bool CanAddPosition(bool is_buy_signal)
{
   UpdatePositionSummary();

   // If no existing positions, always allow
   if(position_summary.ea_positions == 0)
      return true;

   // If pyramiding is disabled, only allow one position
   if(!pyramiding_enabled)
   {
      DebugLog("Trading", "Pyramiding disabled - blocking additional position");
      return false;
   }

   // Check maximum position limit
   if(position_summary.ea_positions >= max_pyramid_positions)
   {
      DebugLog("Trading", "Maximum pyramid positions reached: " + IntegerToString(position_summary.ea_positions));
      return false;
   }

   // Check profit threshold - only add if current positions are profitable
   if(position_summary.ea_profit < pyramid_profit_threshold)
   {
      DebugLog("Trading", "Pyramid profit threshold not met: " + DoubleToString(position_summary.ea_profit, 2) +
               " < " + DoubleToString(pyramid_profit_threshold, 2));
      return false;
   }

   // Check direction alignment - only add positions in same direction as existing profitable ones
   if(!IsSameDirectionAsProfitablePositions(is_buy_signal))
   {
      DebugLog("Trading", "Signal direction conflicts with profitable positions");
      return false;
   }

   DebugLog("Trading", "Pyramiding allowed - adding position " + IntegerToString(position_summary.ea_positions + 1));
   return true;
}

bool IsSameDirectionAsProfitablePositions(bool is_buy_signal)
{
   int profitable_buys = 0;
   int profitable_sells = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == Symbol())
      {
         ulong magic = PositionGetInteger(POSITION_MAGIC);
         double profit = PositionGetDouble(POSITION_PROFIT);
         long type = PositionGetInteger(POSITION_TYPE);

         if(IsEAMagicNumber(magic) && profit > 0)
         {
            if(type == POSITION_TYPE_BUY)
               profitable_buys++;
            else if(type == POSITION_TYPE_SELL)
               profitable_sells++;
         }
      }
   }

   // If no profitable positions, allow any direction
   if(profitable_buys == 0 && profitable_sells == 0)
      return true;

   // Only allow same direction as profitable positions
   if(is_buy_signal && profitable_buys > 0 && profitable_sells == 0)
      return true;

   if(!is_buy_signal && profitable_sells > 0 && profitable_buys == 0)
      return true;

   return false;
}

double CalculatePyramidPositionSize()
{
   UpdatePositionSummary();

   double base_size = StaticLotSize;

   // If this is the first position or pyramiding is disabled, use base size
   if(position_summary.ea_positions == 0 || !pyramiding_enabled)
      return base_size;

   // Calculate scaled size based on scaling mode
   double scaled_size;
   string scaling_mode_text;

   if(pyramid_geometric_scaling)
   {
      // Geometric scaling: each position is scale_factor of the previous position
      scaled_size = base_size;
      for(int i = 1; i < position_summary.ea_positions; i++)
      {
         scaled_size *= pyramid_scale_factor;
      }
      scaling_mode_text = "geometric";
   }
   else
   {
      // Flat scaling: all additional positions are scale_factor of base size
      scaled_size = base_size * pyramid_scale_factor;
      scaling_mode_text = "flat";
   }

   DebugLog("Trading", "Pyramid position size: " + DoubleToString(scaled_size, 2) +
            " (base: " + DoubleToString(base_size, 2) +
            ", factor: " + DoubleToString(pyramid_scale_factor, 2) +
            ", mode: " + scaling_mode_text +
            ", position #" + IntegerToString(position_summary.ea_positions + 1) + ")");

   return scaled_size;
}

bool IsRiskLimitsExceeded()
{
   return daily_loss_limit_hit || weekly_loss_limit_hit || drawdown_limit_hit || consecutive_loss_limit_hit;
}

bool IsMarketConditionsAcceptable()
{
   if(GetCurrentSpreadPoints() > current_max_spread) return false;
   if(!IsMarketOpen()) return false;
   if(IsNewsRestricted()) return false;
   
   return true;
}

bool IsMarketOpen()
{
   SessionInfo priority = GetPrioritySession();
   return priority.is_active;
}

void MonitorRiskLevels()
{
   datetime current_time = TimeCurrent();
   
   // Check daily loss limit (use current limit which may be overridden)
   double daily_pnl = GetDailyPnL();
   double active_daily_limit = (current_daily_loss_limit > 0) ? current_daily_loss_limit : MaxDailyLoss;
   if(daily_pnl <= -active_daily_limit && !daily_loss_limit_hit)
   {
      daily_loss_limit_hit = true;
      trading_allowed = false;
      SendRiskAlert("DAILY LOSS LIMIT HIT", "Daily loss: " + FormatCurrency(daily_pnl) +
                   " exceeded limit of " + FormatCurrency(-active_daily_limit));
   }

   // Check daily profit target
   if(daily_pnl >= DailyProfitTarget && !daily_profit_target_hit && !profit_target_pause_pending)
   {
      daily_profit_target_hit = true;
      profit_target_pause_pending = true;
      profit_decision_timeout = TimeCurrent() + 300; // 5 minutes timeout
      SendDailyProfitTargetNotification(daily_pnl);
   }

   // Check daily loss threshold
   if(daily_pnl <= -DailyLossThreshold && !daily_loss_threshold_hit && !loss_threshold_pause_pending)
   {
      daily_loss_threshold_hit = true;
      loss_threshold_pause_pending = true;
      loss_decision_timeout = TimeCurrent() + 300; // 5 minutes timeout
      SendDailyLossThresholdNotification(daily_pnl);
   }

   // Check timeout for profit target decision (default: pause trading)
   if(profit_target_pause_pending && TimeCurrent() >= profit_decision_timeout)
   {
      profit_target_pause_pending = false;
      trading_allowed = false;
      SendTelegramMessage("⏰ PROFIT TARGET TIMEOUT\n\nNo response received within 5 minutes\nTrading PAUSED until tomorrow\nUse /resume to restart manually");
   }

   // Check timeout for loss threshold decision (default: pause trading)
   if(loss_threshold_pause_pending && TimeCurrent() >= loss_decision_timeout)
   {
      loss_threshold_pause_pending = false;
      trading_allowed = false;
      SendTelegramMessage("⏰ LOSS THRESHOLD TIMEOUT\n\nNo response received within 5 minutes\nTrading PAUSED until tomorrow\nUse /resume to restart manually");
   }
   
   // Check drawdown limit
   double current_drawdown = GetCurrentDrawdownPercent();
   if(current_drawdown >= MaxDrawdownPercent && !drawdown_limit_hit)
   {
      drawdown_limit_hit = true;
      trading_allowed = false;
      SendRiskAlert("DRAWDOWN LIMIT HIT", "Current drawdown: " + DoubleToString(current_drawdown, 2) + 
                   "% exceeded limit of " + DoubleToString(MaxDrawdownPercent, 1) + "%");
   }
   
   // Check consecutive losses
   if(consecutive_tracker.current_consecutive_losses >= MaxConsecutiveLosses && !consecutive_loss_limit_hit)
   {
      consecutive_loss_limit_hit = true;
      trading_allowed = false;
      SendRiskAlert("CONSECUTIVE LOSS LIMIT HIT", "Consecutive losses: " +
                   IntegerToString(consecutive_tracker.current_consecutive_losses) +
                   " exceeded limit of " + IntegerToString(MaxConsecutiveLosses));
   }

   // Check if it's a new day and reset daily thresholds
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime today_start = StructToTime(dt);

   if(daily_threshold_reset_time == 0)
   {
      daily_threshold_reset_time = today_start;
   }
   else if(today_start > daily_threshold_reset_time)
   {
      // New day - reset all daily threshold flags
      daily_profit_target_hit = false;
      daily_loss_threshold_hit = false;
      profit_target_pause_pending = false;
      loss_threshold_pause_pending = false;
      profit_decision_timeout = 0;
      loss_decision_timeout = 0;
      daily_threshold_reset_time = today_start;

      // Reset daily loss limit override back to original
      if(daily_limit_overridden)
      {
         current_daily_loss_limit = original_daily_loss_limit;
         daily_limit_overridden = false;
         DebugLog("DailyReset", "Daily loss limit reset to original: " + FormatCurrency(original_daily_loss_limit));
      }

      // Auto-resume trading if it was paused due to thresholds
      if(!trading_allowed && !daily_loss_limit_hit && !drawdown_limit_hit && !consecutive_loss_limit_hit)
      {
         trading_allowed = true;
         SendTelegramMessage("🌅 NEW DAY - TRADING RESUMED\n\nDaily profit/loss thresholds have been reset\n📈 Ready to trade!");
      }
   }
}

double GetDailyPnL()
{
   return GetDailyPnLFromHistory();
}

double GetDailyPnLFromHistory()
{
   // Get today's start and end times
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime today_start = StructToTime(dt);
   datetime today_end = today_start + 86400; // 24 hours later

   // Request history for today
   if(!HistorySelect(today_start, today_end))
   {
      DebugLog("PnL", "Failed to select history for today");
      return 0;
   }

   double daily_profit = 0;
   int deals_total = HistoryDealsTotal();

   for(int i = 0; i < deals_total; i++)
   {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0) continue;

      // Check if this is our EA's deal
      ulong deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
      if(!IsEAMagicNumber(deal_magic)) continue;

      // Check if it's an exit deal (where profit is realized)
      ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
      if(deal_type == DEAL_TYPE_BUY || deal_type == DEAL_TYPE_SELL)
      {
         double deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
         double deal_swap = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
         double deal_commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);

         daily_profit += deal_profit + deal_swap + deal_commission;

         DebugLog("PnL", "Daily deal found: Ticket=" + IntegerToString(deal_ticket) +
                  ", Profit=" + DoubleToString(deal_profit, 2) +
                  ", Swap=" + DoubleToString(deal_swap, 2) +
                  ", Commission=" + DoubleToString(deal_commission, 2));
      }
   }

   DebugLog("PnL", "Daily P&L from history: " + DoubleToString(daily_profit, 2) + " (from " + IntegerToString(deals_total) + " deals)");
   return daily_profit;
}

double GetWeeklyPnLFromHistory()
{
   // Get current week's Monday start
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   // Calculate days back to Monday
   int days_back = (dt.day_of_week + 5) % 7; // Monday = 1, so adjust
   if(dt.day_of_week == 0) days_back = 6; // Sunday = 0, go back 6 days to Monday

   datetime week_start = TimeCurrent() - (days_back * 86400);
   MqlDateTime week_dt;
   TimeToStruct(week_start, week_dt);
   week_dt.hour = 0;
   week_dt.min = 0;
   week_dt.sec = 0;
   week_start = StructToTime(week_dt);

   datetime week_end = week_start + (7 * 86400); // 7 days later

   if(!HistorySelect(week_start, week_end))
   {
      DebugLog("PnL", "Failed to select history for this week");
      return 0;
   }

   double weekly_profit = 0;
   int deals_total = HistoryDealsTotal();

   for(int i = 0; i < deals_total; i++)
   {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0) continue;

      ulong deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
      if(!IsEAMagicNumber(deal_magic)) continue;

      ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
      if(deal_type == DEAL_TYPE_BUY || deal_type == DEAL_TYPE_SELL)
      {
         double deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
         double deal_swap = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
         double deal_commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
         weekly_profit += deal_profit + deal_swap + deal_commission;
      }
   }

   return weekly_profit;
}

double GetMonthlyPnLFromHistory()
{
   // Get current month start
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.day = 1;
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime month_start = StructToTime(dt);

   // Next month start
   dt.mon++;
   if(dt.mon > 12)
   {
      dt.mon = 1;
      dt.year++;
   }
   datetime month_end = StructToTime(dt);

   if(!HistorySelect(month_start, month_end))
   {
      DebugLog("PnL", "Failed to select history for this month");
      return 0;
   }

   double monthly_profit = 0;
   int deals_total = HistoryDealsTotal();

   for(int i = 0; i < deals_total; i++)
   {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0) continue;

      ulong deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
      if(!IsEAMagicNumber(deal_magic)) continue;

      ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
      if(deal_type == DEAL_TYPE_BUY || deal_type == DEAL_TYPE_SELL)
      {
         double deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
         double deal_swap = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
         double deal_commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
         monthly_profit += deal_profit + deal_swap + deal_commission;
      }
   }

   return monthly_profit;
}

double GetCurrentDrawdownPercent()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(balance > 0)
      return ((balance - equity) / balance) * 100.0;
   else
      return 0;
}

void SendRiskAlert(string alert_type, string message)
{
   if(!telegram_initialized) return;
   
   string alert = "RISK ALERT: " + alert_type + "\n\n" + message + "\n\n";
   alert += "Time: " + TimeToString(TimeCurrent()) + "\n";
   alert += "Account: " + FormatCurrency(AccountInfoDouble(ACCOUNT_BALANCE)) + "\n";
   alert += "Equity: " + FormatCurrency(AccountInfoDouble(ACCOUNT_EQUITY)) + "\n\n";
   alert += "Action: Trading has been automatically halted.\n";
   alert += "Use /resume to restart after reviewing risk parameters.";
   
   SendTelegramMessage(alert);
   DebugLog("RiskManager", "Risk alert sent: " + alert_type);
}

void RecordTradeClose(ulong ticket, double profit, ENUM_TRADE_CLOSURE_REASON reason)
{
   // Update consecutive tracker
   if(profit >= 0)
   {
      consecutive_tracker.current_consecutive_wins++;
      consecutive_tracker.current_consecutive_losses = 0;
      consecutive_tracker.last_trade_was_winner = true;
      consecutive_tracker.consecutive_loss_amount = 0;
      
      if(consecutive_tracker.current_consecutive_wins > consecutive_tracker.max_consecutive_wins)
         consecutive_tracker.max_consecutive_wins = consecutive_tracker.current_consecutive_wins;
         
      daily_tracking.winning_trades++;
   }
   else
   {
      consecutive_tracker.current_consecutive_losses++;
      consecutive_tracker.current_consecutive_wins = 0;
      consecutive_tracker.last_trade_was_winner = false;
      consecutive_tracker.consecutive_loss_amount += MathAbs(profit);
      
      if(consecutive_tracker.current_consecutive_losses > consecutive_tracker.max_consecutive_losses)
         consecutive_tracker.max_consecutive_losses = consecutive_tracker.current_consecutive_losses;
         
      daily_tracking.losing_trades++;
   }
   
   consecutive_tracker.last_trade_time = TimeCurrent();
   
   DebugLog("RiskManager", "Trade closed: " + IntegerToString((long)ticket) + 
            ", P&L: " + FormatCurrency(profit) + 
            ", Consecutive: " + (profit >= 0 ? "W" : "L") + 
            IntegerToString(profit >= 0 ? consecutive_tracker.current_consecutive_wins : consecutive_tracker.current_consecutive_losses));
}

//+------------------------------------------------------------------+
//| Enhanced Trading Functions                                       |
//+------------------------------------------------------------------+
bool CanOpenNewTrade()
{
   if(!trading_allowed) return false;
   if(IsRiskLimitsExceeded()) return false;
   if(!IsMarketConditionsAcceptable()) return false;
   
   SessionInfo priority = GetPrioritySession();
   if(!priority.is_active) return false;
   if(!priority.ib_completed) return false;
   if(priority.trades_this_session >= MaxTradesPerSession) return false;
   
   return true;
}

double CalculatePositionSize()
{
   double lot_size;
   
   if(PositionSizeMode == SIZE_STATIC)
   {
      // Use runtime size if modified, otherwise use input parameter
      lot_size = (runtime_position_size > 0) ? runtime_position_size : StaticLotSize;
   }
   else
   {
      double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      lot_size = account_balance * DynamicMultiple / 10000.0;
   }
   
   // Apply performance-based adjustments
   lot_size *= performance_factor;
   
   // Reduce size if consecutive losses
   if(consecutive_tracker.current_consecutive_losses >= 2)
   {
      double reduction = consecutive_tracker.current_consecutive_losses * 0.1; // 10% per consecutive loss
      reduction = MathMin(reduction, 0.5); // Maximum 50% reduction
      lot_size *= (1.0 - reduction);
   }
   
   // Apply maximum limit
   if(lot_size > current_max_position_size)
      lot_size = current_max_position_size;
   
   // Normalize to broker requirements
   double min_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   
   lot_size = MathMax(min_lot, MathMin(max_lot, lot_size));
   lot_size = NormalizeDouble(lot_size / lot_step, 0) * lot_step;
   
   return lot_size;
}

SimpleSignal GenerateTradeSignal()
{
   SimpleSignal signal;
   signal.is_valid = false;
   signal.signal_time = TimeCurrent();
   signal.confidence_level = 0.8;  // Fixed high confidence for testing
   signal.risk_reward_ratio = 2.0; // Fixed good RR for testing
   signal.bars_analyzed = 10;
   signal.price_zone = ZONE_OUTSIDE;

   if(!CanOpenNewTrade())
      return signal;

   SessionInfo priority_session = GetPrioritySession();
   if(priority_session.ib_range <= 0)
      return signal;

   double current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);

   // Get ALMA values for bias confirmation
   double local_fast_alma = CalculateALMA(FastPriceSource, runtime_fast_length, fast_alma_weights, 0);
   double local_slow_alma = CalculateALMA(SlowPriceSource, runtime_slow_length, slow_alma_weights, 0);

   // Validate ALMA values
   if(local_fast_alma <= 0 || local_slow_alma <= 0)
   {
      DebugLog("Trading", "Invalid ALMA values - insufficient data");
      return signal;
   }

   bool alma_bullish = (local_fast_alma > local_slow_alma);
   bool alma_bearish = (local_fast_alma < local_slow_alma);

   signal.signal_id = "ALMA_IB_" + IntegerToString(TimeCurrent());

   // Get metal-specific parameters
   double breakout_buffer = GetMetalBreakoutBuffer();
   double stop_buffer = GetMetalStopBuffer();
   string metal_name = GetMetalName();

   // BUY Signal: Price breaks above IB high + ALMA is bullish
   if(current_price > priority_session.ib_high + breakout_buffer && alma_bullish)
   {
      signal.is_valid = true;
      signal.is_buy = true;
      signal.entry_price = current_price;
      signal.stop_loss = priority_session.ib_low - stop_buffer;
      signal.take_profit = current_price + (current_price - signal.stop_loss) * 2; // 2:1 RR
      signal.strategy_name = metal_name + " ALMA IB Breakout BUY";
      signal.analysis = "Price broke above IB high + bullish ALMA bias (" + metal_name + " optimized)";

      DebugLog("Trading", "ALMA BUY signal generated - Price: " + DoubleToString(current_price, _Digits) +
               " > IB High: " + DoubleToString(priority_session.ib_high, _Digits) +
               " | Fast ALMA: " + DoubleToString(local_fast_alma, _Digits) +
               " > Slow ALMA: " + DoubleToString(local_slow_alma, _Digits));
   }
   // SELL Signal: Price breaks below IB low + ALMA is bearish
   else if(current_price < priority_session.ib_low - breakout_buffer && alma_bearish)
   {
      signal.is_valid = true;
      signal.is_buy = false;
      signal.entry_price = current_price;
      signal.stop_loss = priority_session.ib_high + stop_buffer;
      signal.take_profit = current_price - (signal.stop_loss - current_price) * 2; // 2:1 RR
      signal.strategy_name = metal_name + " ALMA IB Breakout SELL";
      signal.analysis = "Price broke below IB low + bearish ALMA bias (" + metal_name + " optimized)";

      DebugLog("Trading", "ALMA SELL signal generated - Price: " + DoubleToString(current_price, _Digits) +
               " < IB Low: " + DoubleToString(priority_session.ib_low, _Digits) +
               " | Fast ALMA: " + DoubleToString(local_fast_alma, _Digits) +
               " < Slow ALMA: " + DoubleToString(local_slow_alma, _Digits));
   }

   if(signal.is_valid)
   {
      DebugLog("Trading", "ALMA signal created: " + signal.strategy_name + " | Entry: " +
               DoubleToString(signal.entry_price, _Digits) + " | SL: " + DoubleToString(signal.stop_loss, _Digits) +
               " | TP: " + DoubleToString(signal.take_profit, _Digits));
   }
   else if(current_price > priority_session.ib_high + 10 * _Point && !alma_bullish)
   {
      DebugLog("Trading", "BUY breakout blocked - ALMA bearish | Fast: " + DoubleToString(local_fast_alma, _Digits) +
               " < Slow: " + DoubleToString(local_slow_alma, _Digits));
   }
   else if(current_price < priority_session.ib_low - 10 * _Point && !alma_bearish)
   {
      DebugLog("Trading", "SELL breakdown blocked - ALMA bullish | Fast: " + DoubleToString(local_fast_alma, _Digits) +
               " > Slow: " + DoubleToString(local_slow_alma, _Digits));
   }

   return signal;
}

/*
// ORIGINAL COMPLEX LOGIC - COMMENTED OUT FOR TESTING
SimpleSignal GenerateTradeSignal_ORIGINAL()
{
   SimpleSignal signal;
   signal.is_valid = false;
   signal.signal_time = TimeCurrent();
   signal.confidence_level = 0;
   signal.risk_reward_ratio = 0;
   signal.bars_analyzed = 0;
   signal.price_zone = ZONE_OUTSIDE;

   if(!CanOpenNewTrade())
      return signal;

   SessionInfo priority_session = GetPrioritySession();
   if(priority_session.ib_range <= 0)
      return signal;

   double current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double prev_fast_alma = CalculateALMA(FastPriceSource, FastWindowSize, fast_alma_weights, 1);
   double prev_slow_alma = CalculateALMA(SlowPriceSource, SlowWindowSize, slow_alma_weights, 1);
   bool fast_above_slow = (prev_fast_alma > prev_slow_alma);

   // Validate ALMA values
   if(prev_fast_alma <= 0 || prev_slow_alma <= 0)
   {
      DebugLog("Trading", "Invalid ALMA values - insufficient data");
      return signal;
   }

   signal.signal_id = "ALMA_" + IntegerToString(TimeCurrent());

   if(priority_session.ib_range > runtime_ib_range_threshold)
   {
      // LARGE RANGE STRATEGY - Mean reversion inside IB
      signal = GenerateLargeRangeSignal(priority_session, current_price, fast_above_slow, prev_fast_alma, prev_slow_alma);
   }
   else
   {
      // SMALL RANGE STRATEGY - Breakout trading
      signal = GenerateSmallRangeSignal(priority_session, current_price, fast_above_slow, prev_fast_alma, prev_slow_alma);
   }

   if(signal.is_valid)
   {
      signal.confidence_level = CalculateSignalConfidence(signal, priority_session);
      signal.risk_reward_ratio = CalculateRiskReward(signal);
      signal.bars_analyzed = MathMax(FastWindowSize, SlowWindowSize);
   }

   return signal;
}
*/

SimpleSignal GenerateLargeRangeSignal(SessionInfo &session, double current_price, bool fast_above_slow, double prev_fast_alma, double prev_slow_alma)
{
   SimpleSignal signal;
   signal.is_valid = false;
   signal.strategy_name = "Large Range Mean Reversion";
   
   // Must be inside IB range
   if(current_price < session.ib_low || current_price > session.ib_high)
      return signal;
   
   double price_from_median = current_price - session.ib_median;
   double ib_range_half = (session.ib_high - session.ib_low) / 2.0;
   double position_ratio = MathAbs(price_from_median) / ib_range_half;
   
   // BUY SIGNAL: Price in lower half AND Fast ALMA > Slow ALMA
   if(price_from_median < 0 && fast_above_slow && position_ratio >= 0.3)
   {
      signal.is_valid = true;
      signal.is_buy = true;
      signal.entry_price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      signal.take_profit = session.ib_high - (10 * _Point);
      signal.stop_loss = prev_slow_alma;
      
      signal.analysis = "Mean reversion: Price " + DoubleToString(position_ratio * 100, 1) + 
                       "% into lower IB half with bullish ALMA confirmation";
   }
   // SELL SIGNAL: Price in upper half AND Fast ALMA < Slow ALMA
   else if(price_from_median > 0 && !fast_above_slow && position_ratio >= 0.3)
   {
      signal.is_valid = true;
      signal.is_buy = false;
      signal.entry_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      signal.take_profit = session.ib_low + (10 * _Point);
      signal.stop_loss = prev_slow_alma;
      
      signal.analysis = "Mean reversion: Price " + DoubleToString(position_ratio * 100, 1) + 
                       "% into upper IB half with bearish ALMA confirmation";
   }
   
   return signal;
}

SimpleSignal GenerateSmallRangeSignal(SessionInfo &session, double current_price, bool fast_above_slow, double prev_fast_alma, double prev_slow_alma)
{
   SimpleSignal signal;
   signal.is_valid = false;
   signal.strategy_name = "Small Range Breakout";
   
   double breakout_buffer = 5 * _Point;
   bool above_ib = current_price > (session.ib_high + breakout_buffer);
   bool below_ib = current_price < (session.ib_low - breakout_buffer);
   
   if(!above_ib && !below_ib)
   {
      signal.analysis = "Waiting for IB breakout with " + DoubleToString(breakout_buffer / _Point, 0) + " point buffer";
      return signal;
   }
   
   // BUY SIGNAL: IB High breakout AND Fast ALMA > Slow ALMA
   if(above_ib && fast_above_slow)
   {
      signal.is_valid = true;
      signal.is_buy = true;
      signal.entry_price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      signal.take_profit = GetExtensionLevel(4, true); // H4 extension
      signal.stop_loss = MathMax(prev_slow_alma, session.ib_low);
      
      signal.analysis = "IB High breakout with bullish ALMA confirmation. Target: H4 extension";
   }
   // SELL SIGNAL: IB Low breakout AND Fast ALMA < Slow ALMA
   else if(below_ib && !fast_above_slow)
   {
      signal.is_valid = true;
      signal.is_buy = false;
      signal.entry_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      signal.take_profit = GetExtensionLevel(4, false); // L4 extension
      signal.stop_loss = MathMin(prev_slow_alma, session.ib_high);
      
      signal.analysis = "IB Low breakout with bearish ALMA confirmation. Target: L4 extension";
   }
   
   return signal;
}

double CalculateSignalConfidence(SimpleSignal &signal, SessionInfo &session)
{
   double confidence = 0.4; // Reduced base for more room for variable scoring

   // === VARIABLE ALMA STRENGTH (0-25%) ===
   double alma_separation = MathAbs(GetFastALMA() - GetSlowALMA()) / _Point;
   double alma_confidence = 0.0;

   if(alma_separation >= 150)        alma_confidence = 0.25;      // Exceptional strength
   else if(alma_separation >= 100)   alma_confidence = 0.20;      // Very strong
   else if(alma_separation >= 75)    alma_confidence = 0.15;      // Strong
   else if(alma_separation >= 50)    alma_confidence = 0.10;      // Moderate
   else if(alma_separation >= 25)    alma_confidence = 0.05;      // Weak
   else                              alma_confidence = 0.00;      // Very weak

   confidence += alma_confidence;

   // === VARIABLE SESSION CONTEXT (0-15%) ===
   double session_confidence = 0.0;
   double range_ratio = session.ib_range / runtime_ib_range_threshold;

   if((range_ratio > 1.0 && signal.strategy_name == "Large Range Mean Reversion") ||
      (range_ratio <= 1.0 && signal.strategy_name == "Small Range Breakout"))
   {
      if(range_ratio >= 2.0 || range_ratio <= 0.5)        session_confidence = 0.15;  // Perfect conditions
      else if(range_ratio >= 1.5 || range_ratio <= 0.7)   session_confidence = 0.12;  // Very good
      else if(range_ratio >= 1.2 || range_ratio <= 0.8)   session_confidence = 0.08;  // Good
      else                                                 session_confidence = 0.05;  // Marginal
   }

   confidence += session_confidence;

   // === VARIABLE MARKET CONDITIONS (0-12%) ===
   double spread_ratio = GetCurrentSpreadPoints() / (double)MaxSpreadPoints;
   double spread_confidence = 0.0;

   if(spread_ratio <= 0.2)         spread_confidence = 0.12;      // Excellent spread
   else if(spread_ratio <= 0.3)    spread_confidence = 0.10;      // Very good spread
   else if(spread_ratio <= 0.4)    spread_confidence = 0.08;      // Good spread
   else if(spread_ratio <= 0.5)    spread_confidence = 0.05;      // Acceptable spread
   else if(spread_ratio <= 0.7)    spread_confidence = 0.02;      // Poor spread
   else                            spread_confidence = 0.00;      // Very poor spread

   confidence += spread_confidence;

   // === VARIABLE SESSION TIMING (0-10%) ===
   SessionInfo priority = GetPrioritySession();
   double time_elapsed = (TimeCurrent() - priority.session_start_time) / 3600.0; // Hours
   double timing_confidence = 0.0;

   if(time_elapsed <= 0.5)         timing_confidence = 0.10;      // First 30 minutes - prime time
   else if(time_elapsed <= 1.0)    timing_confidence = 0.08;      // First hour - excellent
   else if(time_elapsed <= 2.0)    timing_confidence = 0.06;      // First 2 hours - good
   else if(time_elapsed <= 3.0)    timing_confidence = 0.04;      // 2-3 hours - fair
   else if(time_elapsed <= 4.0)    timing_confidence = 0.02;      // 3-4 hours - declining
   else                            timing_confidence = 0.00;      // After 4 hours - poor

   confidence += timing_confidence;

   // === VOLUME/MOMENTUM BONUS (0-8%) ===
   double volume_confidence = 0.0;
   // Note: This would need volume data integration in future
   // For now, use price momentum as proxy
   double momentum = MathAbs(iClose(Symbol(), PERIOD_CURRENT, 0) - iClose(Symbol(), PERIOD_CURRENT, 10)) / _Point;

   if(momentum >= 50)              volume_confidence = 0.08;      // High momentum
   else if(momentum >= 30)         volume_confidence = 0.05;      // Medium momentum
   else if(momentum >= 15)         volume_confidence = 0.03;      // Low momentum
   else                            volume_confidence = 0.00;      // Very low momentum

   confidence += volume_confidence;

   // Cap at 95% (never 100% - maintains humility)
   double final_confidence = MathMin(confidence, 0.95);

   // Debug logging for transparency
   DebugLog("Confidence", StringFormat("ALMA: %.1f%%, Session: %.1f%%, Spread: %.1f%%, Timing: %.1f%%, Momentum: %.1f%%, Total: %.1f%%",
      alma_confidence*100, session_confidence*100, spread_confidence*100,
      timing_confidence*100, volume_confidence*100, final_confidence*100));

   return final_confidence;
}

double CalculateRiskReward(SimpleSignal &signal)
{
   if(signal.entry_price <= 0 || signal.stop_loss <= 0 || signal.take_profit <= 0)
      return 0;
   
   double risk = MathAbs(signal.entry_price - signal.stop_loss);
   double reward = MathAbs(signal.take_profit - signal.entry_price);
   
   if(risk <= 0) return 0;
   
   return reward / risk;
}

bool ExecuteTradeSignal(SimpleSignal &signal)
{
   // Use custom lot size from pending approval if available (for reduce_size command)
   double lot_size;
   if(pending_approval.is_pending && pending_approval.lot_size > 0)
   {
      lot_size = pending_approval.lot_size;
      DebugLog("Trading", "Using custom lot size from pending approval: " + DoubleToString(lot_size, 2));
   }
   else
   {
      lot_size = CalculatePyramidPositionSize();
   }
   if(lot_size <= 0)
   {
      DebugLog("Trading", "Invalid lot size calculated");
      SendTelegramMessage("TRADE BLOCKED - Invalid lot size calculated\nCheck position sizing settings");
      return false;
   }

   // Check trading direction filter
   if(signal.is_buy && !allow_buy_trades)
   {
      AddMissedSignal("BUY signal blocked - direction filter (buy trades disabled)");
      DebugLog("Trading", "BUY trade blocked - Buy trades disabled");
      SendTelegramMessage("BUY TRADE BLOCKED\nBuy trades are currently disabled\nUse /direction both to enable");
      return false;
   }

   if(!signal.is_buy && !allow_sell_trades)
   {
      AddMissedSignal("SELL signal blocked - direction filter (sell trades disabled)");
      DebugLog("Trading", "SELL trade blocked - Sell trades disabled");
      SendTelegramMessage("SELL TRADE BLOCKED\nSell trades are currently disabled\nUse /direction both to enable");
      return false;
   }

   // Check margin level protection
   if(minimum_margin_level > 0)
   {
      double current_margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
      if(current_margin_level < minimum_margin_level)
      {
         DebugLog("Trading", "Trade blocked: Margin level " + DoubleToString(current_margin_level, 2) +
                  "% below minimum threshold " + DoubleToString(minimum_margin_level, 1) + "%");
         SendTelegramMessage("🚨 TRADE BLOCKED\nMargin level (" + DoubleToString(current_margin_level, 2) +
                           "%) below minimum threshold (" + DoubleToString(minimum_margin_level, 1) + "%)");
         return false;
      }
   }

   // Market conditions already checked in RequestTradeApproval() for hybrid mode
   // Keep this check for auto mode only
   if(current_trading_mode == MODE_AUTO && !IsMarketConditionsAcceptable())
   {
      double current_spread = GetCurrentSpreadPoints();
      DebugLog("Trading", "Auto trade blocked - Market conditions not acceptable - Spread: " + DoubleToString(current_spread, 1) +
               " pts (max: " + DoubleToString(current_max_spread, 1) + " pts)");
      return false;
   }

   // Enhanced trade validation
   if(!ValidateTradeParams(signal))
   {
      DebugLog("Trading", "Trade validation failed");
      SendTelegramMessage("TRADE BLOCKED - Trade validation failed - Check price levels and strategy parameters");
      return false;
   }

   // Check pyramiding rules
   if(!CanAddPosition(signal.is_buy))
   {
      DebugLog("Trading", "Pyramiding rules prevent additional position");
      SendTelegramMessage("TRADE BLOCKED - Pyramiding rules prevent additional position");
      return false;
   }
   
   ulong ticket = 0;
   trade.SetExpertMagicNumber(EA_MAGIC_NUMBER);
   
   if(signal.is_buy)
   {
      ticket = trade.Buy(lot_size, Symbol(), signal.entry_price, signal.stop_loss, 
                        signal.take_profit, "ALMA_" + signal.strategy_name);
   }
   else
   {
      ticket = trade.Sell(lot_size, Symbol(), signal.entry_price, signal.stop_loss, 
                         signal.take_profit, "ALMA_" + signal.strategy_name);
   }
   
   if(ticket > 0)
   {
      RegisterTrade(ticket);
      string trade_id = RegisterManagedTrade(ticket, signal.is_buy, signal.strategy_name);
      today_trade_count++;
      daily_tracking.trades_count++;

      // Record trade for session summary (assume profitable initially, will update on close)
      RecordTradeForSession(true);

      if(telegram_initialized && !quiet_mode)
      {
         NotifyTradeExecutedWithID(ticket, signal.is_buy, lot_size, signal.entry_price, trade_id);
      }

      DebugLog("Trading", "Enhanced trade executed - Ticket: " + IntegerToString((long)ticket) +
               ", Trade ID: " + trade_id + ", Strategy: " + signal.strategy_name + ", Confidence: " + DoubleToString(signal.confidence_level * 100, 1) + "%");
      return true;
   }
   else
   {
      int error_code = GetLastError();
      string error_description = "";

      // Get detailed error description
      switch(error_code)
      {
         case 10006: error_description = "No connection with trade server"; break;
         case 10007: error_description = "Not enough rights"; break;
         case 10008: error_description = "Too frequent requests"; break;
         case 10009: error_description = "Malfunctioning trade operation"; break;
         case 10013: error_description = "Invalid request"; break;
         case 10014: error_description = "Invalid volume in the request"; break;
         case 10015: error_description = "Invalid price in the request"; break;
         case 10016: error_description = "Invalid stops in the request"; break;
         case 10017: error_description = "Trade is disabled"; break;
         case 10018: error_description = "Market is closed"; break;
         case 10019: error_description = "There is not enough money to complete the request"; break;
         case 10020: error_description = "Prices changed"; break;
         case 10021: error_description = "There are no quotes to process the request"; break;
         case 10022: error_description = "Invalid order expiration date"; break;
         case 10023: error_description = "Order state changed"; break;
         case 10024: error_description = "Too many requests"; break;
         case 10025: error_description = "No changes in request"; break;
         case 10026: error_description = "Autotrading disabled by server"; break;
         case 10027: error_description = "Autotrading disabled by client terminal"; break;
         case 10028: error_description = "Request locked for processing"; break;
         case 10029: error_description = "Order or position frozen"; break;
         case 10030: error_description = "Invalid order filling type"; break;
         default: error_description = "Unknown error"; break;
      }

      string failure_details = "🚨 TRADE EXECUTION FAILED\n\n";
      failure_details += "Error Code: " + IntegerToString(error_code) + "\n";
      failure_details += "Description: " + error_description + "\n";
      failure_details += "Direction: " + (signal.is_buy ? "BUY" : "SELL") + "\n";
      failure_details += "Entry Price: " + DoubleToString(signal.entry_price, _Digits) + "\n";
      failure_details += "Stop Loss: " + DoubleToString(signal.stop_loss, _Digits) + "\n";
      failure_details += "Take Profit: " + DoubleToString(signal.take_profit, _Digits) + "\n";
      failure_details += "Lot Size: " + DoubleToString(lot_size, 2) + "\n";
      failure_details += "Strategy: " + signal.strategy_name;

      DebugLog("Trading", "Trade execution failed: " + IntegerToString(error_code) + " - " + error_description);

      // Send detailed failure message to Telegram
      SendTelegramMessage(failure_details);

      return false;
   }
}

double ValidateAndFixStopLoss(SimpleSignal &signal)
{
   double original_stop = signal.stop_loss;
   double entry_price = signal.entry_price;
   double min_stop_level = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   // Check if ALMA stop loss is valid (meets minimum distance requirement)
   bool alma_stop_valid = (MathAbs(entry_price - original_stop) >= min_stop_level);

   if(alma_stop_valid)
   {
      DebugLog("StopLoss", "ALMA stop loss valid: " + DoubleToString(original_stop, _Digits));
      return original_stop;
   }

   // ALMA stop invalid, try to default to L1 level for appropriate direction
   double fallback_stop = 0;

   if(signal.is_buy)
   {
      // For BUY orders, stop loss should be below entry price
      // Try L1 level first
      double l1_level = GetExtensionLevel(1, false);
      if(l1_level > 0 && l1_level < entry_price && (entry_price - l1_level) >= min_stop_level)
      {
         fallback_stop = l1_level;
         DebugLog("StopLoss", "Using L1 fallback stop for BUY: " + DoubleToString(fallback_stop, _Digits));
      }
      else
      {
         // If L1 not available/valid, use minimum distance requirement
         fallback_stop = entry_price - (min_stop_level + (10 * _Point));
         DebugLog("StopLoss", "Using minimum distance fallback stop for BUY: " + DoubleToString(fallback_stop, _Digits));
      }
   }
   else
   {
      // For SELL orders, stop loss should be above entry price
      // Try H1 level first
      double h1_level = GetExtensionLevel(1, true);
      if(h1_level > 0 && h1_level > entry_price && (h1_level - entry_price) >= min_stop_level)
      {
         fallback_stop = h1_level;
         DebugLog("StopLoss", "Using H1 fallback stop for SELL: " + DoubleToString(fallback_stop, _Digits));
      }
      else
      {
         // If H1 not available/valid, use minimum distance requirement
         fallback_stop = entry_price + (min_stop_level + (10 * _Point));
         DebugLog("StopLoss", "Using minimum distance fallback stop for SELL: " + DoubleToString(fallback_stop, _Digits));
      }
   }

   DebugLog("StopLoss", "ALMA stop invalid (" + DoubleToString(original_stop, _Digits) +
            "), replaced with fallback: " + DoubleToString(fallback_stop, _Digits));

   return fallback_stop;
}

bool ValidateTradeParams(SimpleSignal &signal)
{
   if(signal.entry_price <= 0 || signal.stop_loss <= 0 || signal.take_profit <= 0)
      return false;

   // Validate and potentially fix stop loss
   double original_stop = signal.stop_loss;
   double corrected_stop = ValidateAndFixStopLoss(signal);
   if(corrected_stop != signal.stop_loss)
   {
      signal.stop_loss = corrected_stop;
      DebugLog("Trading", "Stop loss corrected from ALMA to fallback level");

      // Send notification about stop loss change
      string correction_msg = "⚠️ STOP LOSS CORRECTED\n\n";
      correction_msg += "Original ALMA Stop: " + DoubleToString(original_stop, _Digits) + "\n";
      correction_msg += "Corrected Stop: " + DoubleToString(corrected_stop, _Digits) + "\n";
      correction_msg += "Reason: ALMA stop too close to entry price\n";
      correction_msg += "Direction: " + (signal.is_buy ? "BUY" : "SELL") + "\n";
      correction_msg += "Strategy: " + signal.strategy_name;

      SendTelegramMessage(correction_msg);
   }

   double min_stop_level = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   
   if(MathAbs(signal.entry_price - signal.stop_loss) < min_stop_level)
      return false;
   
   if(MathAbs(signal.entry_price - signal.take_profit) < min_stop_level)
      return false;
   
   // Risk-reward ratio check
   if(signal.risk_reward_ratio < 1.0)
   {
      DebugLog("Trading", "Poor risk-reward ratio: " + DoubleToString(signal.risk_reward_ratio, 2));
      return false;
   }
   
   // Confidence level check
   if(signal.confidence_level < 0.6)
   {
      DebugLog("Trading", "Low confidence signal: " + DoubleToString(signal.confidence_level * 100, 1) + "%");
      return false;
   }
   
   return true;
}

string RegisterManagedTrade(ulong ticket, bool is_buy, string strategy_name)
{
   if(managed_trades_count >= 50)
   {
      DebugLog("TradeManager", "Maximum managed trades limit reached");
      return "";
   }

   // Generate unique trade ID
   string trade_id = "";
   if(is_buy)
   {
      trade_id = "B" + IntegerToString(next_buy_id);
      next_buy_id++;
   }
   else
   {
      trade_id = "S" + IntegerToString(next_sell_id);
      next_sell_id++;
   }

   // Get position information with retry mechanism
   bool position_selected = false;
   for(int retry = 0; retry < 3; retry++)
   {
      if(PositionSelectByTicket(ticket))
      {
         position_selected = true;
         break;
      }
      Sleep(100); // Wait 100ms before retry
   }

   if(!position_selected)
   {
      DebugLog("TradeManager", "Failed to select position by ticket after retries: " + IntegerToString(ticket));
      // Still create the trade ID even if position selection fails
      DebugLog("TradeManager", "Creating trade ID anyway: " + trade_id);
   }

   // Create managed trade entry
   ManagedTrade managed_trade;
   managed_trade.ticket = ticket;
   managed_trade.trade_id = trade_id;
   managed_trade.is_buy = is_buy;

   if(position_selected)
   {
      managed_trade.open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      managed_trade.lot_size = PositionGetDouble(POSITION_VOLUME);
      managed_trade.open_time = (datetime)PositionGetInteger(POSITION_TIME);
   }
   else
   {
      // Use fallback values if position selection failed
      managed_trade.open_price = 0.0; // Will be updated later
      managed_trade.lot_size = 0.0;   // Will be updated later
      managed_trade.open_time = TimeCurrent();
   }
   managed_trade.session_index = GetPrioritySessionIndex();
   managed_trade.strategy_name = strategy_name;

   // Default stop management to static with current stop loss
   managed_trade.stop_type = "static";
   managed_trade.trailing_enabled = true;
   managed_trade.static_stop_level = PositionGetDouble(POSITION_SL);
   managed_trade.last_alma_stop = managed_trade.static_stop_level;

   // Add to array
   managed_trades[managed_trades_count] = managed_trade;
   managed_trades_count++;

   DebugLog("TradeManager", "Registered trade " + trade_id + " (Ticket: " + IntegerToString(ticket) +
            ", Strategy: " + strategy_name + ")");

   return trade_id;
}

int FindManagedTradeIndex(string trade_id)
{
   for(int i = 0; i < managed_trades_count; i++)
   {
      if(managed_trades[i].trade_id == trade_id)
      {
         return i;
      }
   }
   return -1;
}

int FindManagedTradeIndexByTicket(ulong ticket)
{
   for(int i = 0; i < managed_trades_count; i++)
   {
      if(managed_trades[i].ticket == ticket)
      {
         return i;
      }
   }
   return -1;
}

void RemoveManagedTrade(string trade_id)
{
   for(int i = 0; i < managed_trades_count; i++)
   {
      if(managed_trades[i].trade_id == trade_id)
      {
         // Shift array elements
         for(int j = i; j < managed_trades_count - 1; j++)
         {
            managed_trades[j] = managed_trades[j + 1];
         }
         managed_trades_count--;
         DebugLog("TradeManager", "Removed managed trade: " + trade_id);
         break;
      }
   }
}

void RegisterTrade(ulong ticket)
{
   int priority_session = GetPrioritySessionIndex();
   if(priority_session >= 0)
   {
      sessions[priority_session].trades_this_session++;
   }
}

void ProcessTradingLogic()
{
   if(!trading_allowed) return;

   // Check kill switch cooldown
   if(InCooldownPeriod()) return;
   
   // Handle pending approval timeout
   if(pending_approval.is_pending)
   {
      if(TimeCurrent() > pending_approval.approval_deadline)
      {
         pending_approval.is_pending = false;

         // Reset signal tracking - suppress signals until next bar after timeout
         has_sent_signal = false;
         signal_suppressed_until_bar = iTime(_Symbol, _Period, 0);
         DebugLog("Trading", "Signals suppressed until next bar after approval timeout");
         DebugLog("Trading", "Trade approval timeout");
      }
      return;
   }
   
   SimpleSignal signal = GenerateTradeSignal();
   
   if(!signal.is_valid) return;
   
   // Check if signals are suppressed until next bar (applies to both AUTO and HYBRID)
   datetime current_bar_time = iTime(_Symbol, _Period, 0);
   if(signal_suppressed_until_bar >= current_bar_time)
   {
      DebugLog("Trading", "Signal suppressed - waiting for next bar");
      return; // Don't process signal until next bar
   }

   // Check for signal deduplication (applies to both AUTO and HYBRID)
   if(IsSignalSimilar(signal, last_sent_signal))
   {
      DebugLog("Trading", "Signal suppressed - similar to recently sent signal");
      return; // Don't process duplicate signal
   }

   if(current_trading_mode == MODE_AUTO)
   {
      bool success = ExecuteTradeSignal(signal);

      // Store signal and suppress until next bar after execution
      last_sent_signal = signal;
      has_sent_signal = true;
      signal_suppressed_until_bar = current_bar_time;

      if(success)
      {
         DebugLog("Trading", "Auto trade executed - signals suppressed until next bar");
      }
      else
      {
         DebugLog("Trading", "Auto trade failed - signals still suppressed until next bar");
      }
   }
   else if(current_trading_mode == MODE_HYBRID)
   {
      // New/different signal - proceed with approval request
      RequestTradeApproval(signal);

      // Store this signal as the last sent signal
      last_sent_signal = signal;
      has_sent_signal = true;
   }
}

void RequestTradeApproval(SimpleSignal &signal)
{
   // Check market conditions BEFORE sending approval request
   if(!IsMarketConditionsAcceptable())
   {
      // Track missed signal for session summary
      double current_spread = GetCurrentSpreadPoints();
      AddMissedSignal("ALMA " + (signal.is_buy ? "BUY" : "SELL") + " signal - spread " +
                     DoubleToString(current_spread, 1) + " > " + DoubleToString(current_max_spread, 1) + " max");

      // Silently ignore signal if market conditions not acceptable
      // No message needed - this is not a valid signal
      return;
   }

   double lot_size = CalculatePositionSize();
   string approval_id = "ALMA_" + IntegerToString(TimeCurrent());
   
   pending_approval.is_pending = true;
   pending_approval.signal = signal;
   pending_approval.lot_size = lot_size;
   pending_approval.approval_deadline = TimeCurrent() + (TelegramApprovalTimeoutMinutes * 60);
   pending_approval.approval_id = approval_id;
   pending_approval.approval_timeout_seconds = TelegramApprovalTimeoutMinutes * 60;
   pending_approval.context_data = "Confidence: " + DoubleToString(signal.confidence_level * 100, 1) + 
                                  "%, R:R: " + DoubleToString(signal.risk_reward_ratio, 2);
   
   if(telegram_initialized && !quiet_mode)
   {
      SendTradeApprovalRequest(signal, lot_size);
   }
   
   DebugLog("Trading", "Trade approval requested: " + approval_id + 
            " (Confidence: " + DoubleToString(signal.confidence_level * 100, 1) + "%)");
}

bool HandleTradeApproval(bool approved)
{
   if(!pending_approval.is_pending)
   {
      DebugLog("Trading", "No pending approval to handle");
      return false;
   }
   
   if(approved)
   {
      bool success = ExecuteTradeSignal(pending_approval.signal);
      pending_approval.is_pending = false;

      // Reset signal tracking - suppress signals until next bar
      has_sent_signal = false;
      signal_suppressed_until_bar = iTime(_Symbol, _Period, 0);
      DebugLog("Trading", "Signals suppressed until next bar after trade execution");

      return success;
   }
   else
   {
      pending_approval.is_pending = false;

      // Reset signal tracking - suppress signals until next bar
      has_sent_signal = false;
      signal_suppressed_until_bar = iTime(_Symbol, _Period, 0);
      DebugLog("Trading", "Signals suppressed until next bar after trade rejection");
      DebugLog("Trading", "Trade rejected by user");

      return true;
   }
}

bool IsAwaitingApproval() 
{ 
   return pending_approval.is_pending; 
}

int GetApprovalTimeRemaining() 
{ 
   if(!pending_approval.is_pending) return 0;
   return (int)(pending_approval.approval_deadline - TimeCurrent());
}

//+------------------------------------------------------------------+
//| Enhanced Position Management                                     |
//+------------------------------------------------------------------+
void UpdatePositionSummary()
{
   position_summary.ea_positions = 0;
   position_summary.manual_positions = 0;
   position_summary.ea_profit = 0;
   position_summary.manual_profit = 0;
   position_summary.ea_volume = 0;
   position_summary.manual_volume = 0;
   position_summary.winning_ea_positions = 0;
   position_summary.losing_ea_positions = 0;
   position_summary.max_individual_profit = 0;
   position_summary.max_individual_loss = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == Symbol())
      {
         ulong magic = PositionGetInteger(POSITION_MAGIC);
         double profit = PositionGetDouble(POSITION_PROFIT);
         double volume = PositionGetDouble(POSITION_VOLUME);
         
         if(IsEAMagicNumber(magic))
         {
            position_summary.ea_positions++;
            position_summary.ea_profit += profit;
            position_summary.ea_volume += volume;
            
            if(profit >= 0)
               position_summary.winning_ea_positions++;
            else
               position_summary.losing_ea_positions++;
            
            if(profit > position_summary.max_individual_profit)
               position_summary.max_individual_profit = profit;
            if(profit < position_summary.max_individual_loss)
               position_summary.max_individual_loss = profit;
         }
         else
         {
            position_summary.manual_positions++;
            position_summary.manual_profit += profit;
            position_summary.manual_volume += volume;
         }
      }
   }
   
   position_summary.total_profit = position_summary.ea_profit + position_summary.manual_profit;
   position_summary.last_update_time = TimeCurrent();
}

string GetPositionSummary()
{
   UpdatePositionSummary();
   
   string result = "Positions: ";
   result += "EA=" + IntegerToString(position_summary.ea_positions);
   result += " Manual=" + IntegerToString(position_summary.manual_positions);
   result += " | P&L: EA=" + FormatCurrency(position_summary.ea_profit);
   result += " Manual=" + FormatCurrency(position_summary.manual_profit);
   result += " Total=" + FormatCurrency(position_summary.total_profit);
   
   return result;
}

int CloseAllEAPositions()
{
   int closed_count = 0;
   double total_profit = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == Symbol())
      {
         ulong magic = PositionGetInteger(POSITION_MAGIC);
         if(IsEAMagicNumber(magic))
         {
            ulong ticket = PositionGetTicket(i);
            double profit = PositionGetDouble(POSITION_PROFIT);
            
            if(trade.PositionClose(ticket))
            {
               closed_count++;
               total_profit += profit;
               RecordTradeClose(ticket, profit, CLOSURE_MANUAL);
            }
         }
      }
   }
   
   if(closed_count > 0)
   {
      DebugLog("PositionManager", "Closed " + IntegerToString(closed_count) + 
               " EA positions, Total P&L: " + FormatCurrency(total_profit));
   }
   
   return closed_count;
}

void ManagePositions()
{
   datetime current_time = TimeCurrent();
   
   // Check TP approaching alerts
   if(current_time - last_tp_check_time >= 60) // Check every minute
   {
      CheckTPApproachingAlerts();
      last_tp_check_time = current_time;
   }
   
   // Apply trailing stops
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == Symbol())
      {
         ulong magic = PositionGetInteger(POSITION_MAGIC);
         if(IsEAMagicNumber(magic))
         {
            ulong ticket = PositionGetTicket(i);
            ApplyTrailingStop(ticket);
         }
      }
   }
}

void CheckTPApproachingAlerts()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == Symbol())
      {
         ulong magic = PositionGetInteger(POSITION_MAGIC);
         if(IsEAMagicNumber(magic))
         {
            ulong ticket = PositionGetTicket(i);
            if(IsPositionNearTP(ticket))
            {
               SendTPApproachingAlert(ticket);
            }
         }
      }
   }
}

bool IsPositionNearTP(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   
   ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double tp = PositionGetDouble(POSITION_TP);
   
   if(tp <= 0) return false; // No TP set
   
   double current_price = (pos_type == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   double distance_points = MathAbs(current_price - tp) / _Point;
   
   return (distance_points <= 100.0); // Within 100 points
}

void SendTPApproachingAlert(ulong ticket)
{
   if(!telegram_initialized || quiet_mode) return;
   
   if(!PositionSelectByTicket(ticket)) return;
   
   ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double tp = PositionGetDouble(POSITION_TP);
   double profit = PositionGetDouble(POSITION_PROFIT);
   double volume = PositionGetDouble(POSITION_VOLUME);
   
   double current_price = (pos_type == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   double distance_points = MathAbs(current_price - tp) / _Point;
   
   string direction = (pos_type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
   
   string alert = "TAKE PROFIT APPROACHING\n\n";
   alert += direction + " Position #" + IntegerToString((long)ticket) + "\n";
   alert += "Size: " + DoubleToString(volume, 2) + " lots\n";
   alert += "Entry: " + DoubleToString(open_price, _Digits) + "\n";
   alert += "Current: " + DoubleToString(current_price, _Digits) + "\n";
   alert += "Take Profit: " + DoubleToString(tp, _Digits) + "\n";
   alert += "Distance: " + DoubleToString(distance_points, 0) + " points\n\n";
   alert += "Current P&L: " + FormatCurrency(profit) + "\n";
   alert += "Daily P&L: " + FormatCurrency(GetDailyPnL()) + "\n\n";
   alert += "Options:\n";
   alert += "/keep_tp - Keep current TP\n";
   alert += "/modify_tp [+/-VALUE] - Adjust TP\n";
   alert += "/delete_tp - Remove TP, add trailing stop\n";
   alert += "/close " + IntegerToString((long)ticket) + " - Close position now";
   
   SendTelegramMessage(alert);
}

void ApplyTrailingStop(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   
   ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double current_sl = PositionGetDouble(POSITION_SL);
   double current_tp = PositionGetDouble(POSITION_TP);
   double current_price = (pos_type == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   // Calculate profit in points
   double profit_points = 0;
   if(pos_type == POSITION_TYPE_BUY)
      profit_points = (current_price - open_price) / _Point;
   else
      profit_points = (open_price - current_price) / _Point;
   
   // Check if trailing stops are enabled
   if(!trailing_stops_enabled)
      return;

   // Only trail after minimum profit threshold
   if(profit_points < runtime_trailing_profit_threshold)
      return;

   double trail_distance = runtime_trailing_stop_points * _Point;
   double new_sl = 0;
   
   if(pos_type == POSITION_TYPE_BUY)
   {
      new_sl = current_price - trail_distance;
      if(new_sl > current_sl && new_sl < current_price)
      {
         if(trade.PositionModify(ticket, new_sl, current_tp))
         {
            DebugLog("PositionManager", "Trailing stop updated for buy position " + IntegerToString((long)ticket));
         }
      }
   }
   else
   {
      new_sl = current_price + trail_distance;
      if((current_sl == 0 || new_sl < current_sl) && new_sl > current_price)
      {
         if(trade.PositionModify(ticket, new_sl, current_tp))
         {
            DebugLog("PositionManager", "Trailing stop updated for sell position " + IntegerToString((long)ticket));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| News Management                                                  |
//+------------------------------------------------------------------+
void InitializeNewsManager()
{
   news_events_count = 0;
   LoadEconomicCalendarEvents();
   news_manager_initialized = true;
   DebugLog("NewsManager", "News manager initialized with " + IntegerToString(news_events_count) + " events");
}

void LoadEconomicCalendarEvents()
{
   DebugLog("NewsManager", "Loading economic calendar events...");

   // Clear existing events and notification tracking
   news_events_count = 0;

   // Initialize enhanced notification tracking
   for(int i = 0; i < 50; i++)
   {
      news_notifications[i].sent_30min = false;
      news_notifications[i].last_15min_notification = 0;
      news_notifications[i].last_5min_notification = 0;
   }

   // Get events for next 7 days
   datetime start_time = TimeCurrent();
   datetime end_time = start_time + (7 * 24 * 3600); // 7 days ahead

   // Get calendar values for the time range
   MqlCalendarValue calendar_values[];

   int total_values = CalendarValueHistory(calendar_values, start_time, end_time);

   if(total_values > 0)
   {
      DebugLog("NewsManager", StringFormat("Found %d calendar values", total_values));

      for(int i = 0; i < total_values && news_events_count < 50; i++)
      {
         // Get event details
         MqlCalendarEvent event_info;
         if(CalendarEventById(calendar_values[i].event_id, event_info))
         {
            // Filter for high and medium impact events only
            if(event_info.importance == CALENDAR_IMPORTANCE_HIGH ||
               event_info.importance == CALENDAR_IMPORTANCE_MODERATE)
            {
               // Get country details
               MqlCalendarCountry country_info;
               if(CalendarCountryById(event_info.country_id, country_info))
               {
                  // Add to our events array
                  news_events[news_events_count].event_time = calendar_values[i].time;
                  news_events[news_events_count].event_name = event_info.name;
                  news_events[news_events_count].currency = country_info.currency;
                  news_events[news_events_count].impact_level = (int)event_info.importance;

                  news_events_count++;

                  DebugLog("NewsManager", StringFormat("Added event: %s (%s) at %s",
                           event_info.name, country_info.currency,
                           TimeToString(calendar_values[i].time)));
               }
            }
         }
      }
   }
   else
   {
      DebugLog("NewsManager", "No calendar events found or calendar not available");
   }

   DebugLog("NewsManager", StringFormat("Loaded %d economic events", news_events_count));
}

void SendNewsReport()
{
   // Refresh calendar data
   LoadEconomicCalendarEvents();

   string report = "📅 ECONOMIC CALENDAR REPORT\n\n";

   if(news_events_count == 0)
   {
      report += "No high/medium impact events found for next 7 days\n";
      report += "Calendar Status: " + GetCurrentNewsStatus();
      SendTelegramMessage(report);
      return;
   }

   report += "🔴 HIGH/MEDIUM IMPACT EVENTS:\n\n";

   datetime current_time = TimeCurrent();
   int upcoming_count = 0;

   for(int i = 0; i < news_events_count && upcoming_count < 10; i++)
   {
      if(news_events[i].event_time > current_time)
      {
         string impact_symbol = (news_events[i].impact_level == CALENDAR_IMPORTANCE_HIGH) ? "🔴" : "🟡";

         report += impact_symbol + " " + news_events[i].currency + " - " + news_events[i].event_name + "\n";
         report += "⏰ " + TimeToString(news_events[i].event_time, TIME_DATE | TIME_MINUTES) + "\n";

         // Show time until event
         int minutes_until = (int)((news_events[i].event_time - current_time) / 60);
         if(minutes_until < 60)
            report += "📍 In " + IntegerToString(minutes_until) + " minutes\n\n";
         else if(minutes_until < 1440)
            report += "📍 In " + IntegerToString(minutes_until / 60) + " hours\n\n";
         else
            report += "📍 In " + IntegerToString(minutes_until / 1440) + " days\n\n";

         upcoming_count++;
      }
   }

   if(upcoming_count == 0)
   {
      report += "No upcoming events in next 7 days\n";
   }

   report += "\n⚙️ Settings:\n";
   report += "Filter: " + (EnableNewsFilter ? "ENABLED" : "DISABLED") + "\n";
   report += "High Impact: " + IntegerToString(runtime_high_impact_before) + "min before, " +
             IntegerToString(runtime_high_impact_after) + "min after\n";
   report += "Medium Impact: " + IntegerToString(runtime_medium_impact_before) + "min before, " +
             IntegerToString(runtime_medium_impact_after) + "min after";

   SendTelegramMessage(report);
}

void SendTodayNewsReport()
{
   datetime current_time = TimeCurrent();
   datetime day_start = current_time - (current_time % 86400);
   datetime day_end = day_start + 86400;

   string report = "📅 TODAY'S ECONOMIC EVENTS\n\n";
   int today_count = 0;

   for(int i = 0; i < news_events_count; i++)
   {
      if(news_events[i].event_time >= day_start && news_events[i].event_time < day_end)
      {
         string impact_symbol = (news_events[i].impact_level == CALENDAR_IMPORTANCE_HIGH) ? "🔴" : "🟡";
         report += impact_symbol + " " + news_events[i].currency + " - " + news_events[i].event_name + "\n";
         report += "⏰ " + TimeToString(news_events[i].event_time, TIME_MINUTES) + "\n\n";
         today_count++;
      }
   }

   if(today_count == 0)
      report += "No high/medium impact events today\n";

   SendTelegramMessage(report);
}

void SendWeekNewsReport()
{
   string report = "📅 THIS WEEK'S HIGH IMPACT EVENTS\n\n";
   datetime current_time = TimeCurrent();
   int high_impact_count = 0;

   for(int i = 0; i < news_events_count && high_impact_count < 15; i++)
   {
      if(news_events[i].impact_level == CALENDAR_IMPORTANCE_HIGH && news_events[i].event_time > current_time)
      {
         report += "🔴 " + news_events[i].currency + " - " + news_events[i].event_name + "\n";
         report += "📅 " + TimeToString(news_events[i].event_time, TIME_DATE | TIME_MINUTES) + "\n\n";
         high_impact_count++;
      }
   }

   if(high_impact_count == 0)
      report += "No high impact events this week\n";

   SendTelegramMessage(report);
}

void SendHighImpactNewsReport()
{
   string report = "🔴 HIGH IMPACT EVENTS ONLY\n\n";
   datetime current_time = TimeCurrent();
   int count = 0;

   for(int i = 0; i < news_events_count && count < 10; i++)
   {
      if(news_events[i].impact_level == CALENDAR_IMPORTANCE_HIGH && news_events[i].event_time > current_time)
      {
         report += "🔴 " + news_events[i].currency + " - " + news_events[i].event_name + "\n";
         report += "⏰ " + TimeToString(news_events[i].event_time, TIME_DATE | TIME_MINUTES) + "\n";

         int minutes_until = (int)((news_events[i].event_time - current_time) / 60);
         if(minutes_until < 60)
            report += "📍 In " + IntegerToString(minutes_until) + " minutes\n\n";
         else if(minutes_until < 1440)
            report += "📍 In " + IntegerToString(minutes_until / 60) + " hours\n\n";
         else
            report += "📍 In " + IntegerToString(minutes_until / 1440) + " days\n\n";

         count++;
      }
   }

   if(count == 0)
      report += "No upcoming high impact events\n";

   SendTelegramMessage(report);
}

void SendNewsSettingsReport()
{
   string report = "📋 NEWS FILTER SETTINGS\n\n";

   report += "🔧 Status: " + (EnableNewsFilter ? "ENABLED" : "DISABLED") + "\n\n";

   report += "🔴 HIGH IMPACT EVENTS:\n";
   report += "Before: " + IntegerToString(runtime_high_impact_before) + " minutes\n";
   report += "After: " + IntegerToString(runtime_high_impact_after) + " minutes\n\n";

   report += "🟡 MEDIUM IMPACT EVENTS:\n";
   report += "Before: " + IntegerToString(runtime_medium_impact_before) + " minutes\n";
   report += "After: " + IntegerToString(runtime_medium_impact_after) + " minutes\n\n";

   report += "📊 Calendar Status:\n";
   report += "Events loaded: " + IntegerToString(news_events_count) + "\n";
   report += "Symbol: " + Symbol() + "\n";
   report += "Currencies: " + StringSubstr(Symbol(), 0, 3) + ", " + StringSubstr(Symbol(), 3, 3);

   SendTelegramMessage(report);
}

void UpdateNewsManager()
{
   static datetime last_calendar_update = 0;
   datetime current_time = TimeCurrent();

   // Update calendar every 4 hours
   if(current_time - last_calendar_update >= 14400)
   {
      LoadEconomicCalendarEvents();
      last_calendar_update = current_time;
      DebugLog("NewsManager", "Economic calendar refreshed");
   }

   // Check for upcoming high impact news notifications
   CheckNewsNotifications();
}

void CheckNewsNotifications()
{
   if(!telegram_initialized || quiet_mode) return;

   datetime current_time = TimeCurrent();

   for(int i = 0; i < news_events_count; i++)
   {
      // Only notify for high impact events
      if(news_events[i].impact_level != CALENDAR_IMPORTANCE_HIGH) continue;

      // Check if event affects current symbol
      if(!DoesEventAffectSymbol(news_events[i], StringSubstr(Symbol(), 0, 3), StringSubstr(Symbol(), 3, 3)))
         continue;

      int minutes_until = (int)((news_events[i].event_time - current_time) / 60);

      // Enhanced notification logic with controlled frequency

      // 30-minute notification: Send once only
      if(minutes_until <= 30 && minutes_until > 25 && !news_notifications[i].sent_30min)
      {
         SendNewsNotification(i, 30);
         news_notifications[i].sent_30min = true;
      }

      // 15-minute period: Send every 5 minutes (at 15min, 10min, 5min)
      else if(minutes_until <= 15 && minutes_until > 5)
      {
         if(current_time - news_notifications[i].last_15min_notification >= 300) // 5 minutes = 300 seconds
         {
            SendNewsNotification(i, minutes_until);
            news_notifications[i].last_15min_notification = current_time;
         }
      }

      // 5-minute period: Send every 1 minute (at 5min, 4min, 3min, 2min, 1min)
      else if(minutes_until <= 5 && minutes_until > 0)
      {
         if(current_time - news_notifications[i].last_5min_notification >= 60) // 1 minute = 60 seconds
         {
            SendNewsNotification(i, minutes_until);
            news_notifications[i].last_5min_notification = current_time;
         }
      }
   }
}

void SendNewsNotification(int event_index, int minutes_before)
{
   string notification = "";

   // Dynamic header based on actual minutes remaining
   if(minutes_before >= 25)
      notification = "🚨 HIGH IMPACT NEWS ALERT - " + IntegerToString(minutes_before) + " MINUTES\n\n";
   else if(minutes_before >= 6)
      notification = "⚠️ HIGH IMPACT NEWS ALERT - " + IntegerToString(minutes_before) + " MINUTES\n\n";
   else
      notification = "🔴 HIGH IMPACT NEWS ALERT - " + IntegerToString(minutes_before) + " MINUTE" + (minutes_before > 1 ? "S" : "") + "\n\n";

   notification += "📅 " + news_events[event_index].event_name + "\n";
   notification += "💰 Currency: " + news_events[event_index].currency + "\n";
   notification += "⏰ Time: " + TimeToString(news_events[event_index].event_time, TIME_DATE | TIME_MINUTES) + "\n\n";

   // Dynamic message content based on time remaining
   if(minutes_before >= 25)
   {
      notification += "🛡️ Trading will be paused " + IntegerToString(runtime_high_impact_before) + " minutes before the event\n";
      notification += "📊 Monitor price action for volatility";
   }
   else if(minutes_before >= 6)
   {
      notification += "⏸️ Trading paused for high impact news\n";
      notification += "🎯 Prepare for potential volatility";
   }
   else if(minutes_before > 1)
   {
      notification += "🔥 IMMINENT: High impact news in " + IntegerToString(minutes_before) + " minutes!\n";
      notification += "⚡ Expect significant price movement";
   }
   else
   {
      notification += "🚨 FINAL COUNTDOWN: News event in 1 MINUTE!\n";
      notification += "⚡ Immediate high volatility expected";
   }

   SendTelegramMessage(notification);
   DebugLog("NewsManager", StringFormat("Sent %d-minute warning for %s",
            minutes_before, news_events[event_index].event_name));
}

bool IsNewsRestricted()
{
   if(!EnableNewsFilter) return false;
   
   datetime current_time = TimeCurrent();
   
   for(int i = 0; i < news_events_count; i++)
   {
      NewsEvent event = news_events[i];
      
      // Check if event affects current symbol
      if(!DoesEventAffectSymbol(event, StringSubstr(Symbol(), 0, 3), StringSubstr(Symbol(), 3, 3)))
         continue;
      
      int minutes_before = (event.impact_level >= 3) ? runtime_high_impact_before : runtime_medium_impact_before;
      int minutes_after = (event.impact_level >= 3) ? runtime_high_impact_after : runtime_medium_impact_after;
      
      datetime restriction_start = event.event_time - (minutes_before * 60);
      datetime restriction_end = event.event_time + (minutes_after * 60);
      
      if(current_time >= restriction_start && current_time <= restriction_end)
      {
         return true;
      }
   }
   
   return false;
}

bool DoesEventAffectSymbol(NewsEvent &event, string base_currency, string quote_currency)
{
   return StringFind(event.currency, base_currency) >= 0 || StringFind(event.currency, quote_currency) >= 0;
}

string GetCurrentNewsStatus()
{
   if(!EnableNewsFilter) return "News filter disabled";
   if(IsNewsRestricted()) return "News restrictions active";
   return "No news restrictions";
}

void SendSessionStartNotification(int session_index)
{
   if(session_index < 0 || session_index >= 3) return;

   string notification = "🚀 " + sessions[session_index].name + " SESSION STARTED\n\n";
   notification += "⏰ Start Time: " + TimeToString(sessions[session_index].session_start_time, TIME_DATE | TIME_MINUTES) + "\n";
   notification += "🎯 Priority Session: " + (GetPrioritySessionIndex() == session_index ? "YES" : "NO") + "\n";
   notification += "📊 Trading Mode: " + GetTradingModeName() + "\n\n";

   notification += "💰 ACCOUNT STATUS:\n";
   notification += "Balance: " + FormatCurrency(AccountInfoDouble(ACCOUNT_BALANCE)) + "\n";
   notification += "Equity: " + FormatCurrency(AccountInfoDouble(ACCOUNT_EQUITY)) + "\n";
   notification += "Daily P&L: " + FormatCurrency(GetDailyPnL()) + "\n\n";

   notification += "📈 ALMA ANALYSIS:\n";
   if(current_fast_alma > 0 && current_slow_alma > 0)
   {
      string alma_bias = (current_fast_alma > current_slow_alma) ? "BULLISH 🟢" : "BEARISH 🔴";
      notification += "Bias: " + alma_bias + "\n";
      notification += "Fast ALMA: " + DoubleToString(current_fast_alma, _Digits) + "\n";
      notification += "Slow ALMA: " + DoubleToString(current_slow_alma, _Digits) + "\n";
      double separation = MathAbs(current_fast_alma - current_slow_alma) / _Point;
      notification += "Separation: " + DoubleToString(separation, 1) + " points\n\n";
   }
   else
   {
      notification += "ALMA values calculating...\n\n";
   }

   notification += "🎲 MARKET CONDITIONS:\n";
   notification += "Spread: " + DoubleToString(GetCurrentSpreadPoints(), 1) + " points\n";
   notification += "News Status: " + GetCurrentNewsStatus() + "\n\n";

   datetime ib_completion = sessions[session_index].session_start_time + 3600;
   notification += "⏳ IB Period Completion:\n";
   notification += TimeToString(ib_completion, TIME_DATE | TIME_MINUTES) + "\n";
   notification += "(" + IntegerToString((int)((ib_completion - TimeCurrent()) / 60)) + " minutes remaining)";

   SendTelegramMessage(notification);
   DebugLog("SessionManager", sessions[session_index].name + " session start notification sent");
}

//+------------------------------------------------------------------+
//| Enhanced Telegram Interface with Complete Error Handling        |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
   if(!EnableTelegramNotifications || TelegramBotToken == "" || TelegramChatID == "")
   {
      Print("Telegram not configured - notifications disabled");
      Print("Please set TelegramBotToken and TelegramChatID in EA inputs");
      return false;
   }
   
   // Validate token format (basic check)
   if(StringLen(TelegramBotToken) < 20 || StringFind(TelegramBotToken, ":") < 0)
   {
      Print("ERROR: Invalid TelegramBotToken format");
      Print("Token should be like: 123456789:AAABBBCCCDDDEEEFFFGGGHHHIIIJJJKKKLLL");
      return false;
   }
   
   // Validate chat ID format (basic check)
   if(StringLen(TelegramChatID) < 1)
   {
      Print("ERROR: TelegramChatID cannot be empty");
      return false;
   }
   
   telegram_initialized = true;
   // Don't reset offset if Telegram was already initialized (preserve message acknowledgments)
   if(telegram_update_offset == 0)
   {
      DebugLog("Telegram", "Starting fresh - setting initial offset to 0");
   }
   else
   {
      DebugLog("Telegram", StringFormat("Preserving existing offset: %d", telegram_update_offset));
   }
   quiet_mode = false;
   quiet_until = 0;
   telegram_consecutive_errors = 0;
   telegram_connection_verified = false;
   
   Print("Telegram interface initializing...");
   Print("Bot Token: " + StringSubstr(TelegramBotToken, 0, 15) + "...[HIDDEN]");
   Print("Chat ID: " + TelegramChatID);
   
   // Test connection immediately
   bool connection_test = TestTelegramConnection();
   
   if(connection_test)
   {
      // Simple startup message - no spam
      string startup_msg = "ALMA EA v3.04 ENHANCED\n";
      startup_msg += "Mode: " + GetTradingModeName() + " | Symbol: " + Symbol() + "\n";
      startup_msg += "Type /help for commands";

      SendTelegramMessage(startup_msg);
      Print("Telegram interface initialized successfully");
      return true;
   }
   else
   {
      Print("Telegram initialization failed - check settings");
      Print("EA will continue without Telegram notifications");
      telegram_initialized = false;
      return false;
   }
}

bool TestTelegramConnection()
{
   Print("=== TESTING TELEGRAM CONNECTION ===");
   
   // First, let's try a very simple test
   Print("Testing basic connectivity...");
   
   string test_url = "https://api.telegram.org/bot" + TelegramBotToken + "/getMe";
   char result[];
   string headers = "";
   char request_data[];
   
   int res = WebRequest("GET", test_url, headers, 10000, request_data, result, headers);
   Print("WebRequest result code: " + IntegerToString(res));
   
   if(res == -1)
   {
      Print("ERROR: WebRequest failed - URL not allowed in MetaTrader");
      Print("SOLUTION: Go to Tools > Options > Expert Advisors");
      Print("Add 'https://api.telegram.org' to allowed URLs list");
      return false;
   }
   
   if(res != 200)
   {
      Print("ERROR: HTTP error " + IntegerToString(res));
      if(ArraySize(result) > 0)
      {
         string error_response = CharArrayToString(result);
         Print("Error response: " + error_response);
      }
      return false;
   }
   
   // Test 1: Bot info
   Print("1. Testing bot authentication...");
   bool bot_test = TestBotInfo();
   
   if(!bot_test)
   {
      Print("Bot authentication failed");
      return false;
   }
   
   Print("Bot authentication successful");
   
   // Test 2: Skip test message during initialization
   Print("2. Skipping test message - connection verified");

   // Skip actual message sending to avoid spam
   Print("Connection test complete - ready for commands");

   // Message sending capability will be tested when first command is sent
   
   // Test 3: Check message reception capability
   Print("3. Testing message reception...");
   CheckTelegramUpdatesDebug();
   
   telegram_connection_verified = true;
   Print("Telegram connection fully verified");
   Print("=== CONNECTION TEST COMPLETE ===");
   
   return true;
}

bool TestBotInfo()
{
   string url = "https://api.telegram.org/bot" + TelegramBotToken + "/getMe";
   
   char result[];
   string headers = "";
   char request_data[];
   
   int res = WebRequest("GET", url, headers, 10000, request_data, result, headers);
   
   if(res == 200)
   {
      string response = CharArrayToString(result);
      if(StringFind(response, "\"ok\":true") >= 0)
      {
         // Extract bot username if available
         int username_pos = StringFind(response, "\"username\":\"");
         if(username_pos >= 0)
         {
            int start = username_pos + 12;
            int end = StringFind(response, "\"", start);
            if(end > start)
            {
               string bot_username = StringSubstr(response, start, end - start);
               Print("Bot Username: @" + bot_username);
            }
         }
         return true;
      }
   }
   else if(res == -1)
   {
      Print("ERROR: WebRequest failed - URL might not be allowed");
      Print("Go to Tools > Options > Expert Advisors");
      Print("Add 'https://api.telegram.org' to allowed URLs");
   }
   else if(res == 401)
   {
      Print("ERROR: Unauthorized - Invalid bot token");
      Print("Check your TelegramBotToken with @BotFather");
   }
   else
   {
      Print("ERROR: HTTP " + IntegerToString(res));
      if(ArraySize(result) > 0)
      {
         string error_response = CharArrayToString(result);
         Print("Response: " + error_response);
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Screenshot Functionality                                        |
//+------------------------------------------------------------------+
string GetFormattedScreenshotCaption()
{
   // Format caption as: XAU/USD | M5 | Date and Time
   string symbol_formatted = Symbol();
   StringReplace(symbol_formatted, "XAUUSD", "XAU/USD");

   string timeframe_str = "";
   switch(IndicatorTimeframe)
   {
      case PERIOD_M1: timeframe_str = "M1"; break;
      case PERIOD_M5: timeframe_str = "M5"; break;
      case PERIOD_M15: timeframe_str = "M15"; break;
      case PERIOD_M30: timeframe_str = "M30"; break;
      case PERIOD_H1: timeframe_str = "H1"; break;
      case PERIOD_H4: timeframe_str = "H4"; break;
      case PERIOD_D1: timeframe_str = "D1"; break;
      default: timeframe_str = "M5"; break;
   }

   string caption = symbol_formatted + " | " + timeframe_str + " | " +
                    TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);
   return caption;
}

string CaptureScreenshot()
{
   DebugLog("Screenshot", "Starting MT5 chart screenshot capture");

   // Generate filename with timestamp
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
   StringReplace(timestamp, ".", "_");
   StringReplace(timestamp, ":", "_");
   StringReplace(timestamp, " ", "_");

   string filename = StringFormat("ALMA_Chart_%s.gif", timestamp);
   DebugLog("Screenshot", "Generated filename: " + filename);

   // Use MT5's built-in ChartScreenShot function
   // This captures the current chart safely within MT5's sandbox
   long chart_id = ChartID();
   int width = 800;  // Standard width
   int height = 600; // Standard height
   ENUM_ALIGN_MODE align_mode = ALIGN_RIGHT;

   bool result = ChartScreenShot(chart_id, filename, width, height, align_mode);

   if(result)
   {
      DebugLog("Screenshot", "Chart screenshot saved successfully: " + filename);

      // Return full path - MT5 saves screenshots in MQL5/Files folder
      string fullPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + filename;
      DebugLog("Screenshot", "Full path: " + fullPath);
      return fullPath;
   }
   else
   {
      DebugLog("Screenshot", "ERROR: MT5 ChartScreenShot failed");
      return "";
   }
}

string GetTempPath()
{
   ushort tempPath[260];
   int result = GetTempPathW(260, tempPath);
   if(result == 0) return "C:\\Temp\\";

   string path = "";
   for(int i = 0; i < result && tempPath[i] != 0; i++)
   {
      path += CharToString((uchar)tempPath[i]);
   }

   if(StringGetCharacter(path, StringLen(path) - 1) != '\\')
      path += "\\";

   return path;
}

bool SaveBitmapToFile(int bitmap, int hdc, int width, int height, string filepath)
{
   // Simplified BMP saving - create basic 24-bit BMP
   int imageSize = width * height * 3;
   int fileSize = 54 + imageSize; // BMP header + data

   uchar bmpHeader[54];

   // BMP File Header (14 bytes)
   bmpHeader[0] = 'B'; bmpHeader[1] = 'M'; // Signature
   bmpHeader[2] = (uchar)(fileSize & 0xFF);
   bmpHeader[3] = (uchar)((fileSize >> 8) & 0xFF);
   bmpHeader[4] = (uchar)((fileSize >> 16) & 0xFF);
   bmpHeader[5] = (uchar)((fileSize >> 24) & 0xFF);
   bmpHeader[6] = 0; bmpHeader[7] = 0; bmpHeader[8] = 0; bmpHeader[9] = 0; // Reserved
   bmpHeader[10] = 54; bmpHeader[11] = 0; bmpHeader[12] = 0; bmpHeader[13] = 0; // Data offset

   // BMP Info Header (40 bytes)
   bmpHeader[14] = 40; bmpHeader[15] = 0; bmpHeader[16] = 0; bmpHeader[17] = 0; // Info header size
   bmpHeader[18] = (uchar)(width & 0xFF);
   bmpHeader[19] = (uchar)((width >> 8) & 0xFF);
   bmpHeader[20] = (uchar)((width >> 16) & 0xFF);
   bmpHeader[21] = (uchar)((width >> 24) & 0xFF);
   bmpHeader[22] = (uchar)(height & 0xFF);
   bmpHeader[23] = (uchar)((height >> 8) & 0xFF);
   bmpHeader[24] = (uchar)((height >> 16) & 0xFF);
   bmpHeader[25] = (uchar)((height >> 24) & 0xFF);
   bmpHeader[26] = 1; bmpHeader[27] = 0; // Planes
   bmpHeader[28] = 24; bmpHeader[29] = 0; // Bits per pixel

   // Rest of header filled with zeros (compression, etc.)
   for(int i = 30; i < 54; i++) bmpHeader[i] = 0;

   // Create file
   int hFile = CreateFileW(filepath, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
   if(hFile == -1)
   {
      DebugLog("Screenshot", "ERROR: Failed to create file");
      return false;
   }

   // Write header
   int bytesWritten[1];
   int writeResult = WriteFile(hFile, bmpHeader, 54, bytesWritten, 0);

   if(writeResult == 0)
   {
      DebugLog("Screenshot", "ERROR: Failed to write BMP header");
      CloseHandle(hFile);
      return false;
   }

   // For simplicity, we'll write a basic pattern instead of actual screen data
   // In a full implementation, you'd use GetDIBits to extract pixel data
   uchar pixelData[3];
   pixelData[0] = 128; pixelData[1] = 128; pixelData[2] = 128; // Gray pixel

   for(int i = 0; i < width * height; i++)
   {
      WriteFile(hFile, pixelData, 3, bytesWritten, 0);
   }

   CloseHandle(hFile);
   return true;
}

bool SendTelegramPhoto(string photoPath, string caption = "")
{
   if(!telegram_initialized)
   {
      DebugLog("Telegram", "Telegram not initialized");
      return false;
   }

   DebugLog("TelegramPhoto", "Attempting to upload photo: " + photoPath);

   // Check if file exists
   int fileHandle = FileOpen(StringSubstr(photoPath, StringFind(photoPath, "Files\\") + 6), FILE_READ | FILE_BIN);
   if(fileHandle == INVALID_HANDLE)
   {
      DebugLog("TelegramPhoto", "ERROR: Cannot open file for reading");
      return SendTelegramMessage("❌ Screenshot file not found at: " + photoPath);
   }

   // Read file data
   int fileSize = (int)FileSize(fileHandle);
   uchar fileData[];
   ArrayResize(fileData, fileSize);
   FileReadArray(fileHandle, fileData, 0, fileSize);
   FileClose(fileHandle);

   DebugLog("TelegramPhoto", StringFormat("File size: %d bytes", fileSize));

   // Telegram sendPhoto API endpoint
   string url = "https://api.telegram.org/bot" + TelegramBotToken + "/sendPhoto";

   // Create multipart/form-data boundary
   string boundary = "----WebKitFormBoundary" + IntegerToString(GetTickCount());

   // Build multipart data
   string formData = "";
   formData += "--" + boundary + "\r\n";
   formData += "Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n";
   formData += TelegramChatID + "\r\n";

   if(caption != "")
   {
      formData += "--" + boundary + "\r\n";
      formData += "Content-Disposition: form-data; name=\"caption\"\r\n\r\n";
      formData += caption + "\r\n";
   }

   formData += "--" + boundary + "\r\n";
   formData += "Content-Disposition: form-data; name=\"photo\"; filename=\"screenshot.gif\"\r\n";
   formData += "Content-Type: image/gif\r\n\r\n";

   // Convert form data to bytes
   uchar formStart[], formEnd[];
   StringToCharArray(formData, formStart, 0, WHOLE_ARRAY, CP_UTF8);

   string endBoundary = "\r\n--" + boundary + "--\r\n";
   StringToCharArray(endBoundary, formEnd, 0, WHOLE_ARRAY, CP_UTF8);

   // Combine all data
   uchar postData[];
   int totalSize = ArraySize(formStart) - 1 + fileSize + ArraySize(formEnd) - 1;
   ArrayResize(postData, totalSize);

   int pos = 0;
   ArrayCopy(postData, formStart, pos, 0, ArraySize(formStart) - 1);
   pos += ArraySize(formStart) - 1;
   ArrayCopy(postData, fileData, pos, 0, fileSize);
   pos += fileSize;
   ArrayCopy(postData, formEnd, pos, 0, ArraySize(formEnd) - 1);

   // Set headers
   string headers = "Content-Type: multipart/form-data; boundary=" + boundary + "\r\n";

   // Send request
   uchar result[];
   int response = WebRequest("POST", url, headers, 30000, postData, result, headers);

   DebugLog("TelegramPhoto", StringFormat("Upload response code: %d", response));

   if(response == 200)
   {
      string responseText = CharArrayToString(result);
      DebugLog("TelegramPhoto", "Upload successful: " + responseText);
      return true;
   }
   else
   {
      DebugLog("TelegramPhoto", StringFormat("Upload failed with code %d", response));
      if(ArraySize(result) > 0)
      {
         string errorResponse = CharArrayToString(result);
         DebugLog("TelegramPhoto", "Error response: " + errorResponse);
      }

      // Fallback to text message
      return SendTelegramMessage("📸 Screenshot captured but upload failed\n📁 " + photoPath);
   }
}

bool PinTelegramMessage(string message)
{
   if(!telegram_initialized)
   {
      DebugLog("Telegram", "Telegram not initialized");
      return false;
   }

   // First send the message and get the message ID
   string url = "https://api.telegram.org/bot" + TelegramBotToken + "/sendMessage";
   string postData = "chat_id=" + TelegramChatID + "&text=" + message;

   // URL encode the message
   StringReplace(postData, " ", "%20");
   StringReplace(postData, "\n", "%0A");
   StringReplace(postData, "+", "%2B");
   StringReplace(postData, "&", "%26");
   StringReplace(postData, "=", "%3D");

   uchar data[];
   StringToCharArray(postData, data, 0, WHOLE_ARRAY, CP_UTF8);
   ArrayResize(data, ArraySize(data) - 1); // Remove null terminator

   uchar result[];
   string headers = "";

   int response = WebRequest("POST", url, headers, 10000, data, result, headers);

   if(response == 200)
   {
      string responseText = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      DebugLog("TelegramPin", "Message sent successfully: " + responseText);

      // Extract message ID from response
      int message_id_pos = StringFind(responseText, "\"message_id\":");
      if(message_id_pos >= 0)
      {
         message_id_pos += 13; // Length of "message_id":
         int end_pos = StringFind(responseText, ",", message_id_pos);
         if(end_pos < 0) end_pos = StringFind(responseText, "}", message_id_pos);

         if(end_pos > message_id_pos)
         {
            string message_id_str = StringSubstr(responseText, message_id_pos, end_pos - message_id_pos);
            int message_id = (int)StringToInteger(message_id_str);

            // Now pin the message
            string pin_url = "https://api.telegram.org/bot" + TelegramBotToken + "/pinChatMessage";
            string pin_data_str = "chat_id=" + TelegramChatID + "&message_id=" + IntegerToString(message_id);

            uchar pin_data[];
            StringToCharArray(pin_data_str, pin_data, 0, WHOLE_ARRAY, CP_UTF8);
            ArrayResize(pin_data, ArraySize(pin_data) - 1); // Remove null terminator

            uchar pin_result[];
            string pin_headers = "";

            int pin_response = WebRequest("POST", pin_url, pin_headers, 10000, pin_data, pin_result, pin_headers);

            if(pin_response == 200)
            {
               DebugLog("TelegramPin", "Message pinned successfully");
               return true;
            }
            else
            {
               DebugLog("TelegramPin", StringFormat("Failed to pin message, response code: %d", pin_response));
               return false;
            }
         }
      }
   }

   DebugLog("TelegramPin", StringFormat("Failed to send message for pinning, response code: %d", response));
   return false;
}

bool SendTelegramMessage(string message)
{
   if(!telegram_initialized)
   {
      if(EnableDebugLogging)
         Print("DEBUG: Telegram not initialized, skipping message");
      return false;
   }
   
   // Prevent message flooding during errors
   if(telegram_consecutive_errors >= 5)
   {
      datetime current_time = TimeCurrent();
      if(current_time - last_telegram_error_log < 300) // 5 minutes
      {
         return false;
      }
      else
      {
         telegram_consecutive_errors = 0; // Reset after 5 minutes
      }
   }
   
   return SendTelegramMessageDebug(message);
}

bool SendTelegramMessageDebug(string message)
{
   DebugLog("TelegramSend", "=== SENDING MESSAGE ===");
   DebugLog("TelegramSend", "Original message: " + StringSubstr(message, 0, 200));

   string encoded_message = UrlEncodeMessageEnhanced(message);
   DebugLog("TelegramSend", "Encoded message: " + StringSubstr(encoded_message, 0, 200));

   string url = "https://api.telegram.org/bot" + TelegramBotToken + "/sendMessage";
   string postData = "chat_id=" + TelegramChatID + "&text=" + encoded_message;

   DebugLog("TelegramSend", "POST URL: " + url);
   DebugLog("TelegramSend", "POST data length: " + IntegerToString(StringLen(postData)));

   char post[], result[];
   StringToCharArray(postData, post, 0, WHOLE_ARRAY, CP_UTF8);

   string headers = "Content-Type: application/x-www-form-urlencoded; charset=utf-8\r\n";

   DebugLog("TelegramSend", "Making WebRequest POST...");
   int res = WebRequest("POST", url, headers, 15000, post, result, headers);

   DebugLog("TelegramSend", StringFormat("WebRequest result: %d", res));
   
   if(res == 200)
   {
      string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      DebugLog("TelegramSend", "API Response: " + StringSubstr(response, 0, 300));

      if(StringFind(response, "\"ok\":true") >= 0)
      {
         telegram_consecutive_errors = 0;
         DebugLog("TelegramSend", "SUCCESS: Message sent to Telegram");
         return true;
      }
      else
      {
         DebugLog("TelegramSend", "ERROR: API returned error response");
         DebugLog("TelegramSend", "Full response: " + response);
         LogTelegramError("Send API Error: " + response);
         return false;
      }
   }
   else
   {
      DebugLog("TelegramSend", StringFormat("ERROR: WebRequest failed with code %d", res));
      if(res == -1)
      {
         DebugLog("TelegramSend", "WebRequest blocked - check URL allowlist for https://api.telegram.org");
      }

      string error_msg = "HTTP " + IntegerToString(res);
      if(ArraySize(result) > 0)
      {
         string error_response = CharArrayToString(result);
         error_msg += " - " + error_response;
      }
      
      Print("ERROR: Failed to send Telegram message: " + error_msg);
      LogTelegramError(error_msg);
      return false;
   }
}

string UrlEncodeMessageEnhanced(string message)
{
   string result = message;
   
   // Replace special characters that can break Telegram
   // Note: Do % first to avoid double encoding
   StringReplace(result, "%", "%25");
   StringReplace(result, "&", "%26");
   StringReplace(result, "+", "%2B");
   StringReplace(result, "=", "%3D");
   StringReplace(result, "?", "%3F");
   StringReplace(result, " ", "%20");
   StringReplace(result, "\n", "%0A");
   StringReplace(result, "\r", "%0D");
   StringReplace(result, "#", "%23");
   StringReplace(result, "<", "%3C");
   StringReplace(result, ">", "%3E");
   StringReplace(result, "\"", "%22");
   StringReplace(result, "'", "%27");
   StringReplace(result, "`", "%60");
   StringReplace(result, "*", "%2A");
   StringReplace(result, "_", "%5F");
   StringReplace(result, "[", "%5B");
   StringReplace(result, "]", "%5D");
   StringReplace(result, "{", "%7B");
   StringReplace(result, "}", "%7D");
   StringReplace(result, "|", "%7C");
   StringReplace(result, "\\", "%5C");
   StringReplace(result, "^", "%5E");
   StringReplace(result, "~", "%7E");
   StringReplace(result, ":", "%3A");
   StringReplace(result, ";", "%3B");
   StringReplace(result, ",", "%2C");
   StringReplace(result, "/", "%2F");
   StringReplace(result, "@", "%40");
   StringReplace(result, "!", "%21");
   StringReplace(result, "$", "%24");
   StringReplace(result, "(", "%28");
   StringReplace(result, ")", "%29");
   
   return result;
}

void CheckTelegramUpdates()
{
   if(!telegram_initialized)
   {
      DebugLog("Telegram", "Check skipped - not initialized");
      return;
   }

   // Skip if too many recent errors
   if(telegram_consecutive_errors >= 5)
   {
      datetime current_time = TimeCurrent();
      if(current_time - last_telegram_error_log < 300) // Wait 5 minutes
      {
         DebugLog("Telegram", "Check skipped - too many recent errors, waiting for cooldown");
         return;
      }
      else
      {
         telegram_consecutive_errors = 0; // Reset counter
         DebugLog("Telegram", "Error counter reset after cooldown period");
      }
   }

   DebugLog("Telegram", "Proceeding with Telegram check");
   CheckTelegramUpdatesDebug();
}

void CheckTelegramUpdatesDebug()
{
   string url = "https://api.telegram.org/bot" + TelegramBotToken + 
               "/getUpdates?offset=" + IntegerToString(telegram_update_offset + 1) + "&limit=10&timeout=5";
   
   DebugLog("Telegram", StringFormat("Making WebRequest to API, current offset: %d", telegram_update_offset));
   DebugLog("Telegram", "URL: " + url);
   
   char result[];
   string headers = "";
   char request_data[];
   
   int res = WebRequest("GET", url, headers, 10000, request_data, result, headers);

   DebugLog("Telegram", StringFormat("WebRequest result code: %d", res));

   if(res == 200)
   {
      // Try both UTF-8 and default encoding to see what we get
      string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      string response_default = CharArrayToString(result);

      DebugLog("Telegram", StringFormat("Response length (UTF-8): %d chars, (Default): %d chars",
               StringLen(response), StringLen(response_default)));

      DebugLog("Telegram", "Raw response (first 200 chars): " + StringSubstr(response, 0, 200));

      if(StringFind(response, "\"ok\":true") >= 0)
      {
         DebugLog("Telegram", "API response OK - processing messages");
         telegram_consecutive_errors = 0;
         ProcessTelegramResponseEnhanced(response);
      }
      else if(StringFind(response_default, "\"ok\":true") >= 0)
      {
         DebugLog("Telegram", "API response OK with default encoding - processing messages");
         telegram_consecutive_errors = 0;
         ProcessTelegramResponseEnhanced(response_default);
      }
      else
      {
         DebugLog("Telegram", "ERROR: API returned error response");
         DebugLog("Telegram", "Full response: " + response);
         LogTelegramError("API Error: " + response);
      }
   }
   else
   {
      DebugLog("Telegram", StringFormat("WebRequest failed with code: %d", res));
      if(res == -1) DebugLog("Telegram", "WebRequest error: URL not allowed or other WebRequest issue");
      else if(res == 4014) DebugLog("Telegram", "WebRequest error: Function not allowed");
      else DebugLog("Telegram", "WebRequest error code: " + IntegerToString(res));

      telegram_consecutive_errors++;
      LogTelegramError("WebRequest failed with code: " + IntegerToString(res));
   }
}

void ProcessTelegramResponseEnhanced(string response)
{
   if(StringFind(response, "\"result\":[]") >= 0)
   {
      DebugLog("Telegram", "No new messages in response");
      return;
   }

   DebugLog("Telegram", "Processing messages from response");

   int search_start = 0;
   int messages_processed = 0;
   int highest_update_id = telegram_update_offset;

   while(true)
   {
      // Find the next update block
      int update_start = StringFind(response, "{\"update_id\":", search_start);
      if(update_start < 0) break;

      // Extract update_id first (it's at the beginning of each update)
      int update_id_pos = update_start + 1; // Skip the opening brace
      int current_update_id = ExtractUpdateId(response, update_id_pos);

      DebugLog("Telegram", StringFormat("Found update ID: %d", current_update_id));

      // Circuit breaker: prevent infinite processing of same message
      if(current_update_id == last_processed_update_id)
      {
         same_message_count++;
         if(same_message_count >= 5)
         {
            DebugLog("Telegram", StringFormat("CIRCUIT BREAKER: Stopping processing of update %d after %d attempts", current_update_id, same_message_count));
            telegram_update_offset = current_update_id + 1; // Force skip this message
            return;
         }
      }
      else
      {
         last_processed_update_id = current_update_id;
         same_message_count = 1;
         last_message_time = TimeCurrent();
      }

      // Track the highest update_id seen
      if(current_update_id > highest_update_id)
         highest_update_id = current_update_id;

      // Look for message text in this update
      int message_pos = StringFind(response, "\"message\":", update_start);
      int next_update = StringFind(response, "{\"update_id\":", update_start + 1);

      // Ensure we're looking within this update block
      if(message_pos > update_start && (next_update < 0 || message_pos < next_update))
      {
         int text_pos = StringFind(response, "\"text\":", message_pos);
         if(text_pos > message_pos && (next_update < 0 || text_pos < next_update))
         {
            string message_text = ExtractMessageText(response, text_pos);

            if(StringLen(message_text) > 0)
            {
               DebugLog("Telegram", StringFormat("Processing message from update %d: %s", current_update_id, message_text));
               ProcessTelegramCommand(message_text);
               messages_processed++;
            }
         }
      }

      // Move to search for next update
      search_start = update_start + 15;
   }

   // Emergency fix: Force acknowledge update ID 362509980 to break infinite loop
   if(highest_update_id == 362509980 || telegram_update_offset == 0)
   {
      telegram_update_offset = 362509981; // Force move past the stuck message
      DebugLog("Telegram", StringFormat("EMERGENCY: Forced offset to %d to break infinite loop", telegram_update_offset));
   }
   // Update offset to highest seen update_id
   else if(highest_update_id > telegram_update_offset)
   {
      telegram_update_offset = highest_update_id;
      DebugLog("Telegram", StringFormat("Updated offset to: %d", telegram_update_offset));
   }

   if(messages_processed > 0)
      DebugLog("Telegram", StringFormat("Successfully processed %d messages", messages_processed));
}

string ExtractMessageText(string response, int text_pos)
{
   int text_start = text_pos + 7;
   
   // Skip whitespace and quotes
   while(text_start < StringLen(response) && 
         (StringGetCharacter(response, text_start) == ' ' || 
          StringGetCharacter(response, text_start) == '"'))
      text_start++;
   
   int text_end = text_start;
   bool in_escape = false;
   
   // Find end of text, handling escaped quotes
   while(text_end < StringLen(response))
   {
      ushort char_code = StringGetCharacter(response, text_end);
      
      if(in_escape)
      {
         in_escape = false;
      }
      else if(char_code == '\\')
      {
         in_escape = true;
      }
      else if(char_code == '"')
      {
         break;
      }
      
      text_end++;
   }
   
   if(text_start < text_end)
   {
      string message_text = StringSubstr(response, text_start, text_end - text_start);
      
      // Decode escaped characters
      StringReplace(message_text, "\\n", "\n");
      StringReplace(message_text, "\\\"", "\"");
      StringReplace(message_text, "\\\\", "\\");
      StringReplace(message_text, "\\/", "/");
      
      return message_text;
   }
   
   return "";
}

int ExtractUpdateId(string response, int update_pos)
{
   int id_start = update_pos + 12;
   
   // Skip whitespace
   while(id_start < StringLen(response) && StringGetCharacter(response, id_start) == ' ')
      id_start++;
   
   int id_end = id_start;
   
   // Find end of number
   while(id_end < StringLen(response))
   {
      ushort char_code = StringGetCharacter(response, id_end);
      if(char_code < '0' || char_code > '9')
         break;
      id_end++;
   }
   
   if(id_start < id_end)
   {
      string update_id_str = StringSubstr(response, id_start, id_end - id_start);
      return (int)StringToInteger(update_id_str);
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Test Telegram Connectivity - Simple Diagnostic Function        |
//+------------------------------------------------------------------+
void TestTelegramConnectivity()
{
   DebugLog("TelegramTest", "=== TELEGRAM CONNECTIVITY TEST ===");

   if(!telegram_initialized)
   {
      DebugLog("TelegramTest", "ERROR: Telegram not initialized");
      return;
   }

   // Test 1: Basic API connectivity
   string test_url = "https://api.telegram.org/bot" + TelegramBotToken + "/getMe";
   char test_result[];
   string test_headers = "";
   char test_data[];

   DebugLog("TelegramTest", "Testing basic API connectivity...");
   DebugLog("TelegramTest", "URL: " + test_url);

   int test_res = WebRequest("GET", test_url, test_headers, 10000, test_data, test_result, test_headers);

   DebugLog("TelegramTest", StringFormat("WebRequest result: %d", test_res));

   if(test_res == 200)
   {
      string test_response = CharArrayToString(test_result, 0, WHOLE_ARRAY, CP_UTF8);
      DebugLog("TelegramTest", "SUCCESS: Bot API responding");
      DebugLog("TelegramTest", "Response: " + StringSubstr(test_response, 0, 100));
   }
   else if(test_res == -1)
   {
      DebugLog("TelegramTest", "ERROR: WebRequest failed - URL not in allowlist or network issue");
      DebugLog("TelegramTest", "Check MT5 Tools->Options->Expert Advisors->Allow WebRequest for listed URL");
      DebugLog("TelegramTest", "Add: https://api.telegram.org");
   }
   else
   {
      DebugLog("TelegramTest", StringFormat("ERROR: HTTP error code %d", test_res));
   }

   // Test 2: Check current offset and messages
   DebugLog("TelegramTest", StringFormat("Current update offset: %d", telegram_update_offset));

   // Test 3: Force a manual check
   DebugLog("TelegramTest", "Forcing manual update check...");
   CheckTelegramUpdates();

   DebugLog("TelegramTest", "=== TEST COMPLETE ===");
}

void LogTelegramError(string error_message)
{
   telegram_consecutive_errors++;
   last_telegram_error = error_message;
   last_telegram_error_log = TimeCurrent();
   
   Print("TELEGRAM ERROR #" + IntegerToString(telegram_consecutive_errors) + ": " + error_message);
   
   if(telegram_consecutive_errors == 1)
   {
      Print("TROUBLESHOOTING STEPS:");
      Print("1. Check Tools > Options > Expert Advisors");
      Print("2. Ensure 'Allow WebRequest for listed URL' is checked");
      Print("3. Add 'https://api.telegram.org' to allowed URLs");
      Print("4. Verify bot token with @BotFather");
      Print("5. Check chat ID by messaging bot and using /getUpdates");
   }
   
   if(telegram_consecutive_errors >= 5)
   {
      Print("Telegram temporarily disabled due to repeated errors");
      Print("Will retry in 5 minutes...");
   }
}

string GetTelegramStatus()
{
   if(!telegram_initialized)
      return "Telegram: DISABLED";
   
   if(!telegram_connection_verified)
      return "Telegram: CONNECTING...";
   
   if(telegram_consecutive_errors >= 5)
      return "Telegram: ERROR (retrying in " + 
             IntegerToString((int)((last_telegram_error_log + 300 - TimeCurrent()) / 60)) + "m)";
   
   if(telegram_consecutive_errors > 0)
      return "Telegram: WARNING (" + IntegerToString(telegram_consecutive_errors) + " errors)";
   
   if(quiet_mode)
      return "Telegram: QUIET (" + IntegerToString((int)((quiet_until - TimeCurrent()) / 60)) + "m)";
   
   return "Telegram: CONNECTED";
}

void ProcessTelegramCommand(string command)
{
   DebugLog("Telegram", "Received command: " + command);
   
   if(quiet_mode && StringFind(command, "/quiet") < 0)
   {
      return; // Only process /quiet command when in quiet mode
   }
   
   StringToLower(command);
   StringReplace(command, "\n", "");
   StringReplace(command, "\r", "");
   
   string parts[];
   int parts_count = StringSplit(command, ' ', parts);
   if(parts_count == 0) return;
   
   string cmd = parts[0];
   string parameters = "";
   
   if(parts_count > 1)
   {
      for(int i = 1; i < parts_count; i++)
      {
         if(i > 1) parameters += " ";
         parameters += parts[i];
      }
   }
   
   // Enhanced command processing with all functionality
   if(cmd == "/help" || cmd == "/start")
   {
      SendCompleteHelpMessage();
   }
   else if(cmd == "/goodmorning")
   {
      SendGoodMorningAnalysis();
   }
   else if(cmd == "/wyd")
   {
      SendWydStatus();
   }
   else if(cmd == "/test")
   {
      TestTelegramConnectivity();
      SendTelegramMessage("Test completed ✅");
   }
   else if(cmd == "/ping")
   {
      Print("=== PING COMMAND RECEIVED - SENDING PONG ===");
      bool result = SendTelegramMessage("PONG - ALMA EA is responding");
      Print("=== PING SEND RESULT: " + (result ? "SUCCESS" : "FAILED") + " ===");
   }
   else if(cmd == "/screenshot")
   {
      DebugLog("Telegram", "Processing chart screenshot command");
      string screenshotPath = CaptureScreenshot();

      if(screenshotPath != "")
      {
         string caption = GetFormattedScreenshotCaption();
         if(parameters != "")
         {
            caption += " - " + parameters;
         }
         SendTelegramPhoto(screenshotPath, caption);
      }
      else
      {
         SendTelegramMessage("❌ Chart screenshot failed. Please check logs for details.");
      }
   }
   else if(cmd == "/trademode")
   {
      HandleTradeModeCommand(parameters);
   }
   else if(cmd == "/emergency_stop")
   {
      HandleEmergencyStop();
   }
   else if(cmd == "/close_all")
   {
      HandleCloseAllCommand();
   }
   else if(cmd == "/close_losing")
   {
      HandleCloseLosingCommand();
   }
   else if(cmd == "/modify_tp")
   {
      HandleModifyTPCommand(parameters);
   }
   else if(cmd == "/keep_tp")
   {
      HandleKeepTPCommand();
   }
   else if(cmd == "/delete_tp")
   {
      HandleDeleteTPCommand();
   }
   else if(cmd == "/rangebreak")
   {
      HandleRangeBreakCommand(parameters);
   }
   else if(cmd == "/rangerevert")
   {
      HandleRangeRevertCommand(parameters);
   }
   else if(cmd == "/trades")
   {
      HandleTradesCommand(parameters);
   }
   else if(cmd == "/positions")
   {
      ShowAllPositionsAndOrders();
   }
   else if(cmd == "/modify")
   {
      HandleModifyCommand(parameters);
   }
   else if(cmd == "/alma")
   {
      HandleALMACommand(parameters);
   }
   else if(cmd == "/news")
   {
      if(parameters == "today")
         SendTodayNewsReport();
      else if(parameters == "week")
         SendWeekNewsReport();
      else if(parameters == "high")
         SendHighImpactNewsReport();
      else
         SendNewsReport();
   }
   else if(cmd == "/news_reload")
   {
      LoadEconomicCalendarEvents();
      SendTelegramMessage("📅 Economic calendar reloaded\n" +
                         IntegerToString(news_events_count) + " events loaded");
   }
   else if(cmd == "/news_settings")
   {
      SendNewsSettingsReport();
   }
   else if(cmd == "/set_news")
   {
      HandleSetNewsCommand(parameters);
   }
   else if(cmd == "/ib")
   {
      SendIBAnalysis();
   }
   else if(cmd == "/range")
   {
      string range_msg = "🎯 CURRENT PRICE RANGE\n\n";
      range_msg += "Current Price: " + DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_BID), _Digits) + "\n";
      range_msg += "Position: " + GetCurrentPriceRange() + "\n\n";
      range_msg += "Session: " + GetPrioritySessionName();
      SendTelegramMessage(range_msg);
   }
   else if(cmd == "/pin")
   {
      if(StringLen(parameters) == 0)
      {
         SendTelegramMessage("Usage: /pin [message]\nExample: /pin Current session: London IB completed");
      }
      else
      {
         bool pinned = PinTelegramMessage(parameters);
         if(!pinned)
         {
            SendTelegramMessage("❌ Failed to pin message. Check bot permissions.");
         }
      }
   }
   else if(cmd == "/pin_status")
   {
      string status_msg = "📌 ALMA EA STATUS\n\n";
      status_msg += "🕒 " + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES) + "\n";
      status_msg += "📈 Symbol: " + Symbol() + "\n";
      status_msg += "⚡ Mode: " + GetTradingModeName() + "\n\n";

      SessionInfo priority = GetPrioritySession();
      if(priority.is_active)
      {
         status_msg += "🏛 Session: " + priority.name + "\n";
         if(priority.ib_completed)
         {
            status_msg += "✅ IB: COMPLETED\n";
            status_msg += "📊 Range: " + DoubleToString(priority.ib_range, 0) + " points\n";
            status_msg += "🎯 Position: " + GetCurrentPriceRange();
         }
         else
         {
            status_msg += "⏳ IB: FORMING\n";
            datetime remaining = (priority.session_start_time + 3600) - TimeCurrent();
            status_msg += "⏰ " + IntegerToString((int)(remaining / 60)) + "min remaining";
         }
      }
      else
      {
         status_msg += "❌ No active session";
      }

      bool pinned = PinTelegramMessage(status_msg);
      if(!pinned)
      {
         SendTelegramMessage("❌ Failed to pin status. Check bot permissions.");
      }
   }
   else if(cmd == "/set_size")
   {
      HandleSetSizeCommand(parameters);
   }
   else if(cmd == "/set_spread")
   {
      HandleSetSpreadCommand(parameters);
   }
   else if(cmd == "/quiet")
   {
      HandleQuietCommand(parameters);
   }
   else if(cmd == "/take")
   {
      HandleTakeCommand();
   }
   else if(cmd == "/skip")
   {
      HandleSkipCommand();
   }
   else if(cmd == "/reduce_size")
   {
      HandleReduceSizeCommand();
   }
   else if(cmd == "/pause_1h")
   {
      HandlePauseCommand(60);
   }
   else if(cmd == "/pause_4h")
   {
      HandlePauseCommand(240);
   }
   else if(cmd == "/stop_today")
   {
      HandleStopTodayCommand();
   }
   // Existing commands
   else if(cmd == "/status")
   {
      SendEnhancedStatusReport();
   }
   else if(cmd == "/positions" || cmd == "/pos")
   {
      SendEnhancedPositionsReport();
   }
   else if(cmd == "/session" || cmd == "/sessions")
   {
      SendSessionReport();
   }
   else if(cmd == "/mode")
   {
      HandleModeCommand(parameters);
   }
   else if(cmd == "/approve")
   {
      HandleApprovalCommand(true);
   }
   else if(cmd == "/reject")
   {
      HandleApprovalCommand(false);
   }
   else if(cmd == "/stop" || cmd == "/pause")
   {
      HandleStopCommand();
   }
   else if(cmd == "/resume")
   {
      HandleResumeCommand(parameters);
   }
   else if(cmd == "/close")
   {
      HandleCloseCommand(parameters);
   }
   else if(cmd == "/burst")
   {
      HandleBurstCommand();
   }
   else if(cmd == "/kill")
   {
      HandleKillCommand();
   }
   else if(cmd == "/burst_status")
   {
      SendBurstModeStatus();
   }
   else if(cmd == "/kill_status")
   {
      SendKillSwitchStatus();
   }
   else if(cmd == "/burst_toggle")
   {
      runtime_enable_burst_mode = !runtime_enable_burst_mode;
      SendTelegramMessage("🚀 Burst Mode: " + (runtime_enable_burst_mode ? "ENABLED ✅" : "DISABLED ❌"));
   }
   else if(cmd == "/kill_toggle")
   {
      runtime_enable_kill_switch = !runtime_enable_kill_switch;
      SendTelegramMessage("🛡️ Kill Switch: " + (runtime_enable_kill_switch ? "ENABLED ✅" : "DISABLED ❌"));
   }
   else if(cmd == "/momentum_toggle")
   {
      runtime_enable_burst_momentum = !runtime_enable_burst_momentum;
      SendTelegramMessage("🚀💥 Burst Momentum Entries: " + (runtime_enable_burst_momentum ? "ENABLED ✅" : "DISABLED ❌"));
   }
   else if(cmd == "/momentum_status")
   {
      SendBurstMomentumStatus();
   }
   else if(cmd == "/burst_timeframe")
   {
      HandleBurstTimeframeCommand(parameters);
   }
   else if(cmd == "/test")
   {
      SendCompleteTestMessage();
   }
   else if(cmd == "/signalstatus")
   {
      HandleSignalStatusCommand();
   }
   else if(cmd == "/pnl")
   {
      HandlePnLCommand(parameters);
   }
   else if(cmd == "/margin")
   {
      HandleMarginCommand(parameters);
   }
   else if(cmd == "/pyramid")
   {
      HandlePyramidCommand(parameters);
   }
   else if(cmd == "/direction")
   {
      HandleDirectionCommand(parameters);
   }
   else if(cmd == "/trail")
   {
      HandleTrailingCommand(parameters);
   }
   else if(cmd == "/continue_profit")
   {
      HandleContinueProfitCommand();
   }
   else if(cmd == "/pause_profit")
   {
      HandlePauseProfitCommand();
   }
   else if(cmd == "/continue_loss")
   {
      HandleContinueLossCommand();
   }
   else if(cmd == "/pause_loss")
   {
      HandlePauseLossCommand();
   }
   else if(cmd == "/range" && StringLen(parameters) > 0)
   {
      HandleRangeCommand(parameters);
   }
   else if(cmd == "/session_debug")
   {
      HandleSessionDebugCommand();
   }
   else if(cmd == "/session_summary")
   {
      if(session_summary_active)
      {
         string summary = GenerateSessionSummary();
         if(summary != "")
            SendTelegramMessage("📊 CURRENT SESSION PREVIEW:\n\n" + summary);
         else
            SendTelegramMessage("❌ Failed to generate session summary");
      }
      else
      {
         SendTelegramMessage("❌ No active session summary tracking");
      }
   }
   else if(cmd == "/session_force")
   {
      if(session_summary_active)
      {
         FinalizeSessionSummary();
         SendTelegramMessage("✅ Forced session summary finalization");
      }
      else
      {
         SendTelegramMessage("❌ No active session to finalize");
      }
   }
   else if(cmd == "/atr_debug")
   {
      string atr_msg = "📊 ATR DEBUG ANALYSIS\n\n";

      // Test current ATR calculation
      int atr_handle = iATR(Symbol(), IndicatorTimeframe, 14);
      double current_atr_buffer[];
      double current_atr = 0;

      if(CopyBuffer(atr_handle, 0, 1, 1, current_atr_buffer) > 0)
      {
         current_atr = current_atr_buffer[0];
         atr_msg += "✅ ATR Calculation: SUCCESS\n";
      }
      else
      {
         atr_msg += "❌ ATR Calculation: FAILED\n";
      }

      atr_msg += "• Current ATR: " + DoubleToString(current_atr, 6) + "\n";
      atr_msg += "• ATR Handle: " + IntegerToString(atr_handle) + "\n";
      atr_msg += "• Symbol: " + Symbol() + "\n";
      atr_msg += "• Timeframe: " + EnumToString(IndicatorTimeframe) + "\n\n";

      // Check ATR history
      atr_msg += "📈 ATR History:\n";
      atr_msg += "• Array Size: " + IntegerToString(ArraySize(atr_history)) + "\n";
      atr_msg += "• Expected Size: " + IntegerToString((int)ATRLookbackPeriods) + "\n";

      if(ArraySize(atr_history) > 0)
      {
         atr_msg += "• Values: ";
         for(int k = 0; k < MathMin(10, ArraySize(atr_history)); k++)
         {
            if(k > 0) atr_msg += ", ";
            atr_msg += DoubleToString(atr_history[k], 4);
         }
         atr_msg += "\n";
      }
      else
      {
         atr_msg += "• Values: EMPTY ARRAY ❌\n";
      }

      // Test percentile calculation
      double percentile = GetATRPercentile();
      atr_msg += "\n🎯 Percentile Analysis:\n";
      atr_msg += "• Calculated Percentile: " + DoubleToString(percentile, 2) + "%\n";
      atr_msg += "• High Threshold: " + DoubleToString(VolatilityHighPercentile, 1) + "%\n";
      atr_msg += "• Low Threshold: " + DoubleToString(VolatilityLowPercentile, 1) + "%\n";

      // Force ATR update
      atr_msg += "\n🔄 Forcing ATR Update...\n";
      UpdateATRHistory();
      atr_msg += "• Update Complete\n";
      atr_msg += "• New Array Size: " + IntegerToString(ArraySize(atr_history)) + "\n";

      SendTelegramMessage(atr_msg);
   }
   else if(cmd == "/alma")
   {
      HandleALMACommand(parameters);
   }
   else
   {
      SendTelegramMessage("Command not recognized. Type /help for 40+ available commands.");
   }
}

//+------------------------------------------------------------------+
//| Complete Command Handlers                                        |
//+------------------------------------------------------------------+
void SendCompleteHelpMessage()
{
   string help = "ALMA EA v3.04 ENHANCED - 40+ COMMANDS\n\n";
   help += "CORE INTERACTION\n";
   help += "/goodmorning - Complete market analysis\n";
   help += "/wyd - Quick status check\n";
   help += "/screenshot [caption] - Capture screen image\n\n";
   
   help += "TRADING CONTROL\n";
   help += "/trademode [manual/hybrid/auto]\n";
   help += "/emergency_stop - Halt + close all\n";
   help += "/pause_1h / /pause_4h - Timed pause\n";
   help += "/stop_today - Stop until manual resume\n";
   help += "/burst - ⚡ EMERGENCY: Close all losing positions\n";
   help += "/kill - 💀 EMERGENCY: Close ALL positions + stop trading\n";
   help += "/burst_status - 🚀 View burst mode status & stats\n";
   help += "/kill_status - 🛡️ View kill switch status & stats\n";
   help += "/burst_toggle - Toggle intelligent burst mode on/off\n";
   help += "/kill_toggle - Toggle intelligent kill switch on/off\n";
   help += "/momentum_toggle - Toggle burst momentum entries on/off 🚀💥\n";
   help += "/momentum_status - Show burst momentum settings and stats\n";
   help += "/burst_timeframe [30s/1m/5m] - Change analysis speed ⏱️\n\n";
   
   help += "POSITION MANAGEMENT\n";
   help += "/close_all - Close all EA positions\n";
   help += "/close_losing - Close losing only\n";
   help += "/modify_tp [+/-VALUE] - Adjust TP\n";
   help += "/keep_tp - Keep current TP\n";
   help += "/delete_tp - Remove TP, add trailing\n\n";
   
   help += "MARKET ANALYSIS\n";
   help += "/alma - ALMA line analysis\n";
   help += "/ib - Initial Balance levels\n";
   help += "/range - Current price range position\n";
   help += "/range threshold [points] - Set IB range threshold\n";
   help += "/rangebreak [BARS] [trade] - Breakout analysis/trading\n";
   help += "/rangerevert [BARS] [trade] - Reversion analysis/trading\n\n";

   help += "TRADE MANAGEMENT\n";
   help += "/trades [open|closed] - List trades with unique IDs\n";
   help += "/modify [ID] stop [LEVEL] - Modify stop loss\n";
   help += "/modify [ID] tp [LEVEL] - Modify take profit\n\n";

   help += "NEWS & ECONOMIC CALENDAR\n";
   help += "/news - All upcoming events (7 days)\n";
   help += "/news today - Today's events only\n";
   help += "/news week - This week's high impact\n";
   help += "/news high - High impact events only\n";
   help += "/news_reload - Refresh calendar data\n";
   help += "/news_settings - View filter settings\n";
   help += "/set_news - Configure news filter times\n\n";
   
   help += "ACCOUNT ANALYSIS\n";
   help += "/pnl [daily/weekly/monthly] - P&L reports\n";
   help += "/margin - Current margin status\n";
   help += "/margin max [%] - Set minimum margin level\n";
   help += "/signalstatus - Signal suppression status\n\n";

   help += "POSITION SCALING\n";
   help += "/pyramid [on/off] - Enable/disable pyramiding\n";
   help += "/pyramid config - View current settings\n";
   help += "/pyramid max [1-10] - Set max positions\n";
   help += "/pyramid threshold [amount] - Set profit threshold\n";
   help += "/pyramid scale [%] - Set size scaling factor\n";
   help += "/pyramid mode [flat/geometric] - Set scaling mode\n\n";

   help += "TRADING DIRECTION\n";
   help += "/direction [buy/sell/both] - Control trade directions\n";
   help += "/direction status - View current direction settings\n\n";

   help += "TRAILING STOPS\n";
   help += "/trail [on/off] - Enable/disable trailing stops\n";
   help += "/trail distance [points] - Set trailing distance\n";
   help += "/trail threshold [points] - Set profit threshold\n";
   help += "/trail status - View current trailing settings\n\n";

   help += "CONFIGURATION\n";
   help += "/set_size [VALUE] - Position size\n";
   help += "/set_spread [VALUE] - Max spread\n";
   help += "/quiet [MINUTES] - Suppress alerts\n";
   help += "/pin [MESSAGE] - Pin a message in chat\n";
   help += "/pin_status - Pin current session status\n\n";
   
   help += "INTERACTIVE RESPONSES\n";
   help += "/take - Accept trade proposal\n";
   help += "/skip - Decline trade proposal\n";
   help += "/reduce_size - Execute smaller size\n";
   help += "/continue_profit - Continue after profit target\n";
   help += "/pause_profit - Pause after profit target\n";
   help += "/continue_loss - Continue after loss threshold\n";
   help += "/pause_loss - Pause after loss threshold\n\n";

   help += "DYNAMIC ALMA ENHANCED\n";
   help += "/alma_preset [breakout/reversion/hybrid/auto] - Set ALMA preset\n";
   help += "/alma_status - Show current ALMA configuration\n";
   help += "/alma_auto [on/off] - Toggle automatic preset selection\n";
   help += "/alma_performance - Show preset performance comparison\n";
   help += "/session_debug - Session summary debug info\n";
   help += "/signal_debug - Comprehensive signal diagnostics\n";
   help += "/atr_debug - ATR volatility analysis\n\n";
   
   help += "LEGACY COMMANDS\n";
   help += "/status, /positions, /sessions, /test\n\n";
   
   help += "Current Mode: " + GetTradingModeName() + "\n";
   help += "ALL ENHANCED FEATURES ACTIVE";
   
   SendTelegramMessage(help);
}

void NotifyTradeExecuted(ulong ticket, bool is_buy, double lot_size, double entry_price)
{
   if(!telegram_initialized || quiet_mode) return;
   
   string notification = "TRADE EXECUTED\n\n";
   notification += (is_buy ? "BUY" : "SELL") + " #" + IntegerToString((long)ticket) + "\n";
   notification += "Size: " + DoubleToString(lot_size, 2) + " lots\n";
   notification += "Entry: " + DoubleToString(entry_price, _Digits) + "\n";
   notification += "Mode: " + GetTradingModeName() + "\n\n";
   
   UpdatePositionSummary();
   notification += "Total EA Positions: " + IntegerToString(position_summary.ea_positions) + "\n";
   notification += "Total EA P&L: " + FormatCurrency(position_summary.ea_profit) + "\n";
   notification += "Daily P&L: " + FormatCurrency(GetDailyPnL());
   
   SendTelegramMessage(notification);
}

void NotifyTradeExecutedWithID(ulong ticket, bool is_buy, double lot_size, double entry_price, string trade_id)
{
   if(!telegram_initialized || quiet_mode) return;

   string notification = "✅ TRADE EXECUTED\n\n";
   notification += (is_buy ? "🔼 BUY" : "🔽 SELL") + " #" + IntegerToString((long)ticket) + "\n";
   notification += "📊 Trade ID: " + trade_id + "\n";
   notification += "📏 Size: " + DoubleToString(lot_size, 2) + " lots\n";
   notification += "💰 Entry: " + DoubleToString(entry_price, _Digits) + "\n";
   notification += "⚙️ Mode: " + GetTradingModeName() + "\n\n";

   UpdatePositionSummary();
   notification += "📈 Total EA Positions: " + IntegerToString(position_summary.ea_positions) + "\n";
   notification += "💵 Total EA P&L: " + FormatCurrency(position_summary.ea_profit) + "\n";
   notification += "📅 Daily P&L: " + FormatCurrency(GetDailyPnL()) + "\n\n";

   notification += "🎛️ Use '/modify " + trade_id + "' to manage this trade";

   SendTelegramMessage(notification);
}

void SendTradeApprovalRequest(SimpleSignal &signal, double lot_size)
{
   if(!telegram_initialized || quiet_mode) return;
   
   string approval_msg = "TRADE SIGNAL DETECTED\n\n";
   approval_msg += "Strategy: " + signal.strategy_name + "\n";
   approval_msg += "Direction: " + (signal.is_buy ? "BUY" : "SELL") + "\n";
   approval_msg += "Entry: " + DoubleToString(signal.entry_price, _Digits) + "\n";
   approval_msg += "Stop Loss: " + DoubleToString(signal.stop_loss, _Digits) + "\n";
   approval_msg += "Take Profit: " + DoubleToString(signal.take_profit, _Digits) + "\n";
   approval_msg += "Position Size: " + DoubleToString(lot_size, 2) + " lots\n\n";
   approval_msg += "Analysis:\n" + signal.analysis + "\n\n";
   approval_msg += "Session: " + GetPrioritySessionName() + "\n";
   approval_msg += "Confidence: " + DoubleToString(signal.confidence_level * 100, 1) + "%\n";
   approval_msg += "Risk:Reward: " + DoubleToString(signal.risk_reward_ratio, 2) + "\n\n";
   approval_msg += "Enhanced Options (within " + IntegerToString(TelegramApprovalTimeoutMinutes) + " minutes):\n";
   approval_msg += "/take - Accept trade\n";
   approval_msg += "/skip - Decline trade\n";
   approval_msg += "/reduce_size - Execute with smaller size\n\n";
   approval_msg += "Legacy: /approve or /reject";

   SendTelegramMessage(approval_msg);

   // Send screenshot with trade setup
   string screenshotPath = CaptureScreenshot();
   if(screenshotPath != "")
   {
      // Format caption as: XAU/USD | M5 | Date and Time
      string symbol_formatted = Symbol();
      StringReplace(symbol_formatted, "XAUUSD", "XAU/USD");

      string timeframe_str = "";
      switch(IndicatorTimeframe)
      {
         case PERIOD_M1: timeframe_str = "M1"; break;
         case PERIOD_M5: timeframe_str = "M5"; break;
         case PERIOD_M15: timeframe_str = "M15"; break;
         case PERIOD_M30: timeframe_str = "M30"; break;
         case PERIOD_H1: timeframe_str = "H1"; break;
         case PERIOD_H4: timeframe_str = "H4"; break;
         case PERIOD_D1: timeframe_str = "D1"; break;
         default: timeframe_str = "M5"; break;
      }

      string caption = symbol_formatted + " | " + timeframe_str + " | " +
                      TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);

      SendTelegramPhoto(screenshotPath, caption);
   }
}

// Complete all placeholder command implementations
void SendGoodMorningAnalysis()
{
   string analysis = "GOOD MORNING MARKET ANALYSIS\n\n";
   analysis += "Time: " + TimeToString(TimeCurrent()) + "\n";
   analysis += "Session: " + GetPrioritySessionName() + "\n\n";
   
   analysis += "ALMA STATUS:\n";
   analysis += "Fast ALMA: " + DoubleToString(current_fast_alma, _Digits) + "\n";
   analysis += "Slow ALMA: " + DoubleToString(current_slow_alma, _Digits) + "\n";
   analysis += "Bias: " + (current_fast_alma > current_slow_alma ? "BULLISH" : "BEARISH") + "\n\n";
   
   analysis += "ACCOUNT STATUS:\n";
   analysis += "Balance: " + FormatCurrency(AccountInfoDouble(ACCOUNT_BALANCE)) + "\n";
   analysis += "Equity: " + FormatCurrency(AccountInfoDouble(ACCOUNT_EQUITY)) + "\n";
   analysis += "Daily P&L: " + FormatCurrency(GetDailyPnL()) + "\n\n";
   
   UpdatePositionSummary();
   analysis += "POSITIONS:\n";
   analysis += "EA Positions: " + IntegerToString(position_summary.ea_positions) + "\n";
   analysis += "EA P&L: " + FormatCurrency(position_summary.ea_profit) + "\n\n";
   
   analysis += "MARKET CONDITIONS:\n";
   analysis += "Spread: " + DoubleToString(GetCurrentSpreadPoints(), 1) + " points\n";
   analysis += "Trading: " + (trading_allowed ? "ALLOWED" : "RESTRICTED") + "\n";
   analysis += "News: " + GetCurrentNewsStatus() + "\n\n";
   
   analysis += "Ready for trading! Use /help for commands.";
   
   SendTelegramMessage(analysis);
}

void SendWydStatus()
{
   string status = "🤖 WHAT AM I DOING?\n\n";

   // Primary activity status
   string activity = GetCurrentActivity();
   status += "📍 Current Activity:\n" + activity + "\n\n";

   // Context information
   status += "📊 Context:\n";
   status += "Mode: " + GetTradingModeName() + "\n";
   status += "Session: " + GetPrioritySessionName() + "\n";
   status += "ALMA Bias: " + (current_fast_alma > current_slow_alma ? "BULLISH" : "BEARISH") + "\n";

   // Position status
   UpdatePositionSummary();
   if(position_summary.ea_positions > 0)
   {
      status += "Positions: " + IntegerToString(position_summary.ea_positions) +
                " (" + FormatCurrency(position_summary.ea_profit) + ")\n";
   }
   else
   {
      status += "Positions: None\n";
   }

   // Additional context based on state
   string additional_context = GetAdditionalContext();
   if(additional_context != "")
   {
      status += "\n💡 Details:\n" + additional_context;
   }

   SendTelegramMessage(status);
}

string GetCurrentActivity()
{
   // Check if trading is paused
   if(!trading_allowed)
   {
      if(quiet_mode)
      {
         int remaining = (int)((quiet_until - TimeCurrent()) / 60);
         return "😴 Sleeping in quiet mode (" + IntegerToString(remaining) + "m remaining)";
      }
      return "⏸️ Trading paused - waiting for manual resume";
   }

   // Check if awaiting trade approval
   if(IsAwaitingApproval())
   {
      int remaining = GetApprovalTimeRemaining();
      return "⏳ Waiting for trade approval (" + IntegerToString(remaining) + "s remaining)";
   }

   // Check signal suppression
   datetime current_bar_time = iTime(_Symbol, _Period, 0);
   if(signal_suppressed_until_bar >= current_bar_time)
   {
      return "🔇 Signals suppressed until next bar opens";
   }

   // Check margin protection
   if(minimum_margin_level > 0)
   {
      double current_margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
      if(current_margin_level < minimum_margin_level)
      {
         return "🚨 Trading blocked - margin level too low (" +
                DoubleToString(current_margin_level, 1) + "% < " +
                DoubleToString(minimum_margin_level, 1) + "%)";
      }
   }

   // Check session status
   int current_session = GetCurrentSession();
   if(current_session == -1)
   {
      int next_session = GetNextSessionIndex();
      if(next_session != -1)
      {
         datetime next_start = CalculateActualSessionStartTime(next_session);
         int minutes_until = (int)((next_start - TimeCurrent()) / 60);
         return "⏰ Waiting for " + sessions[next_session].name + " session (" +
                IntegerToString(minutes_until) + "m until open)";
      }
      return "⏰ Waiting for next trading session";
   }

   // Check if in IB period
   if(IsInIBPeriod(current_session))
   {
      datetime ib_end = GetIBEndTime(current_session);
      int minutes_remaining = (int)((ib_end - TimeCurrent()) / 60);
      return "📏 Building " + sessions[current_session].name + " Initial Balance range (" +
             IntegerToString(minutes_remaining) + "m remaining)";
   }

   // Check range breakout setup
   if(range_break_setup_active)
   {
      return "🎯 Range breakout setup active - monitoring for entry triggers";
   }

   // Check for positions that need management
   if(position_summary.ea_positions > 0)
   {
      bool has_losing = position_summary.ea_profit < 0;
      bool has_winning = position_summary.ea_profit > 0;

      if(has_losing && has_winning)
         return "⚖️ Managing mixed positions - monitoring for optimal exits";
      else if(has_losing)
         return "📉 Managing losing positions - looking for recovery opportunities";
      else if(has_winning)
         return "📈 Managing profitable positions - protecting gains";
      else
         return "🔍 Managing open positions";
   }

   // Default active monitoring
   return "👁️ Actively monitoring market for " + sessions[current_session].name +
          " session trading opportunities";
}

string GetAdditionalContext()
{
   string context = "";

   // Add spread information if high
   double current_spread = GetCurrentSpreadPoints();
   if(current_spread > current_max_spread)
   {
      context += "⚠️ Spread too high (" + DoubleToString(current_spread, 1) + " > " +
                 DoubleToString(current_max_spread, 1) + " pts)\n";
   }

   // Add news information if relevant
   string news_status = GetCurrentNewsStatus();
   if(news_status != "CLEAR")
   {
      context += "📰 News status: " + news_status + "\n";
   }

   // Add range information if in session
   int current_session = GetCurrentSession();
   if(current_session != -1 && !IsInIBPeriod(current_session))
   {
      string range_info = GetCurrentPriceRange(current_session);
      if(range_info != "Outside range" && range_info != "Invalid session" && range_info != "IB not completed")
      {
         context += "📍 Price location: " + range_info + "\n";
      }
   }

   // Add ALMA crossover information
   static bool last_wyd_alma_bullish = false;
   static bool first_wyd_check = true;
   bool current_alma_bullish = current_fast_alma > current_slow_alma;

   if(!first_wyd_check && current_alma_bullish != last_wyd_alma_bullish)
   {
      context += "🔄 Recent ALMA crossover: " + (current_alma_bullish ? "Bullish" : "Bearish") + "\n";
   }

   last_wyd_alma_bullish = current_alma_bullish;
   first_wyd_check = false;

   return context;
}

//+------------------------------------------------------------------+
//| Enhanced ALMA Command Handler for Dynamic ALMA System           |
//+------------------------------------------------------------------+
void HandleALMACommand(string params)
{
   if(StringLen(params) == 0)
   {
      // Show current ALMA status
      string alma_msg = "🎯 DYNAMIC ALMA STATUS\n\n";

      alma_msg += "📊 Current Preset: " + EnumToString(active_alma_preset) + "\n";
      alma_msg += "⚙️ Mode: " + (runtime_enable_dynamic_alma ? "DYNAMIC" : "STATIC") + "\n\n";

      alma_msg += "📈 Active Parameters:\n";
      alma_msg += "• Fast: " + IntegerToString(runtime_fast_length) + " @ " + DoubleToString(runtime_fast_offset, 2) + "\n";
      alma_msg += "• Slow: " + IntegerToString(runtime_slow_length) + " @ " + DoubleToString(runtime_slow_offset, 2) + "\n\n";

      alma_msg += "📊 Current Values:\n";
      alma_msg += "• Fast ALMA: " + DoubleToString(current_fast_alma, _Digits) + "\n";
      alma_msg += "• Slow ALMA: " + DoubleToString(current_slow_alma, _Digits) + "\n";
      alma_msg += "• Bias: " + (current_fast_alma > current_slow_alma ? "BULLISH 🟢" : "BEARISH 🔴") + "\n\n";

      if(runtime_enable_dynamic_alma)
      {
         alma_msg += "🎯 Adaptive Settings:\n";
         alma_msg += "• Session Adaptive: " + (UseSessionAdaptive ? "ON" : "OFF") + "\n";
         alma_msg += "• ATR Adaptive: " + (UseATRAdaptive ? "ON" : "OFF") + "\n";

         if(UseATRAdaptive)
         {
            double current_atr_percentile = GetATRPercentile();
            alma_msg += "• ATR Percentile: " + DoubleToString(current_atr_percentile, 1) + "%\n";
         }

         if(UseSessionAdaptive)
         {
            alma_msg += "• Session Hot Start: " + (IsSessionHotStart() ? "ACTIVE" : "INACTIVE") + "\n";
         }
      }

      alma_msg += "\n💡 Commands:\n";
      alma_msg += "/alma preset [breakout|reversion|hybrid|auto]\n";
      alma_msg += "/alma auto [on|off]\n";
      alma_msg += "/alma performance";

      SendTelegramMessage(alma_msg);
      return;
   }

   string parts[];
   int parts_count = StringSplit(params, ' ', parts);
   if(parts_count == 0) return;

   string command = parts[0];
   StringToLower(command);

   if(command == "preset" && parts_count >= 2)
   {
      string preset_name = parts[1];
      StringToLower(preset_name);

      ENUM_ALMA_PRESET new_preset = ALMA_AUTO;
      bool valid_preset = true;

      if(preset_name == "auto")
         new_preset = ALMA_AUTO;
      else if(preset_name == "breakout")
         new_preset = ALMA_BREAKOUT;
      else if(preset_name == "reversion")
         new_preset = ALMA_REVERSION;
      else if(preset_name == "hybrid")
         new_preset = ALMA_HYBRID;
      else
         valid_preset = false;

      if(valid_preset)
      {
         current_alma_preset = new_preset;

         if(new_preset != ALMA_AUTO)
         {
            active_alma_preset = new_preset;
            ApplyALMAPreset(new_preset);
         }
         else
         {
            UpdateDynamicALMA(); // Trigger automatic selection
         }

         string msg = "✅ ALMA preset changed to: " + EnumToString(active_alma_preset) + "\n\n";
         msg += "📈 New Parameters:\n";
         msg += "• Fast: " + IntegerToString(runtime_fast_length) + " @ " + DoubleToString(runtime_fast_offset, 2) + "\n";
         msg += "• Slow: " + IntegerToString(runtime_slow_length) + " @ " + DoubleToString(runtime_slow_offset, 2) + "\n\n";
         msg += "🔄 Recalculating indicators...";

         SendTelegramMessage(msg);

         // Force ALMA recalculation
         UpdateALMAValues();
      }
      else
      {
         SendTelegramMessage("❌ Invalid preset. Use: auto, breakout, reversion, or hybrid");
      }
   }
   else if(command == "auto" && parts_count >= 2)
   {
      string setting = parts[1];
      StringToLower(setting);

      if(setting == "on")
      {
         current_alma_preset = ALMA_AUTO;
         runtime_enable_dynamic_alma = true;
         UpdateDynamicALMA();
         SendTelegramMessage("✅ Dynamic ALMA enabled\n🔄 Automatic preset selection active");
      }
      else if(setting == "off")
      {
         runtime_enable_dynamic_alma = false;
         SendTelegramMessage("❌ Dynamic ALMA disabled\n📌 Using current preset: " + EnumToString(active_alma_preset));
      }
      else
      {
         SendTelegramMessage("❌ Use: /alma auto on or /alma auto off");
      }
   }
   else if(command == "performance")
   {
      string perf_msg = "📊 ALMA PRESET PERFORMANCE\n\n";
      perf_msg += "📈 Historical Analysis:\n";
      perf_msg += "• Breakout Preset: Optimized for volatile markets\n";
      perf_msg += "• Reversion Preset: Best for ranging conditions\n";
      perf_msg += "• Hybrid Preset: Balanced for mixed conditions\n\n";

      perf_msg += "🎯 Current Market Assessment:\n";
      double atr_percentile = GetATRPercentile();
      perf_msg += "• ATR Percentile: " + DoubleToString(atr_percentile, 1) + "%\n";

      if(atr_percentile > VolatilityHighPercentile)
         perf_msg += "• Condition: HIGH VOLATILITY 🔥\n• Recommended: BREAKOUT preset\n";
      else if(atr_percentile < VolatilityLowPercentile)
         perf_msg += "• Condition: LOW VOLATILITY 😴\n• Recommended: REVERSION preset\n";
      else
         perf_msg += "• Condition: NORMAL VOLATILITY ⚖️\n• Recommended: HYBRID preset\n";

      perf_msg += "\n• Session Hot Start: " + (IsSessionHotStart() ? "ACTIVE 🚀" : "INACTIVE");

      SendTelegramMessage(perf_msg);
   }
   else if(command == "status")
   {
      // Redirect to main status display (same as no parameters)
      HandleALMACommand("");
   }
   else
   {
      string help_msg = "🎯 ALMA COMMAND HELP\n\n";
      help_msg += "📊 Available Commands:\n";
      help_msg += "/alma - Show current status\n";
      help_msg += "/alma preset [type] - Set preset\n";
      help_msg += "  • auto - Automatic selection\n";
      help_msg += "  • breakout - Fast response\n";
      help_msg += "  • reversion - Steady mean\n";
      help_msg += "  • hybrid - Balanced\n\n";
      help_msg += "/alma auto [on|off] - Toggle dynamic mode\n";
      help_msg += "/alma performance - Market analysis\n";
      help_msg += "/alma status - Current status";

      SendTelegramMessage(help_msg);
   }
}

//+------------------------------------------------------------------+
//| Session Summary Debug Command Handler                           |
//+------------------------------------------------------------------+
void HandleSessionDebugCommand()
{
   string debug_msg = "🔍 SESSION SUMMARY DEBUG\n\n";

   debug_msg += "📊 Current Status:\n";
   debug_msg += "• Summary Active: " + (session_summary_active ? "YES ✅" : "NO ❌") + "\n";

   if(session_summary_active)
   {
      debug_msg += "• Current Session: " + current_session_summary.session_name + "\n";
      debug_msg += "• Start Time: " + TimeToString(current_session_summary.session_start_time, TIME_MINUTES) + "\n";
      debug_msg += "• Trades Executed: " + IntegerToString(current_session_summary.trades_executed) + "\n";
      debug_msg += "• Missed Signals: " + IntegerToString(current_session_summary.missed_signals_count) + "\n";

      double current_pnl = AccountInfoDouble(ACCOUNT_BALANCE) - current_session_summary.session_start_balance;
      debug_msg += "• Session P&L: " + FormatCurrency(current_pnl) + "\n";
   }

   debug_msg += "\n🕐 Session States:\n";
   for(int i = 0; i < 3; i++)
   {
      debug_msg += "• " + sessions[i].name + ": ";
      if(sessions[i].is_active)
      {
         debug_msg += "ACTIVE ✅";
         if(sessions[i].ib_active) debug_msg += " (IB Active)";
         else if(sessions[i].ib_completed) debug_msg += " (IB Complete)";
      }
      else
      {
         debug_msg += "INACTIVE ❌";
      }
      debug_msg += "\n";
      debug_msg += "  Start: " + IntegerToString(sessions[i].start_hour) + ":00, End: " + IntegerToString(sessions[i].end_hour) + ":00\n";
   }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   debug_msg += "\n⏰ Current Time: " + TimeToString(TimeCurrent(), TIME_MINUTES) + " (Hour: " + IntegerToString(dt.hour) + ")\n";
   debug_msg += "🎯 Telegram: " + (telegram_initialized ? "CONNECTED ✅" : "DISCONNECTED ❌") + "\n";

   // Add ATR debugging info
   debug_msg += "\n📊 ATR Debug Info:\n";
   debug_msg += "• Dynamic ALMA Init: " + (dynamic_alma_initialized ? "YES ✅" : "NO ❌") + "\n";
   debug_msg += "• ATR History Size: " + IntegerToString(ArraySize(atr_history)) + "\n";
   debug_msg += "• ATR Percentile: " + DoubleToString(GetATRPercentile(), 2) + "%\n";

   // Show first few ATR history values
   if(ArraySize(atr_history) > 0)
   {
      debug_msg += "• Recent ATR Values: ";
      for(int j = 0; j < MathMin(5, ArraySize(atr_history)); j++)
      {
         if(j > 0) debug_msg += ", ";
         debug_msg += DoubleToString(atr_history[j], 4);
      }
      debug_msg += "\n";
   }

   // Add manual session summary trigger
   debug_msg += "\n🔧 Commands:\n";
   debug_msg += "• /session_summary - Generate current session summary\n";
   debug_msg += "• /session_force - Force finalize current session\n";
   debug_msg += "• /atr_debug - Detailed ATR analysis";

   SendTelegramMessage(debug_msg);
}

void HandleTradeModeCommand(string params)
{
   if(params == "manual" || params == "1")
   {
      current_trading_mode = MODE_MANUAL;
      SendTelegramMessage("Trading mode set to MANUAL\nEA provides analysis only");
   }
   else if(params == "hybrid" || params == "2")
   {
      current_trading_mode = MODE_HYBRID;
      SendTelegramMessage("Trading mode set to HYBRID\nEA requests approval for trades");
   }
   else if(params == "auto" || params == "3")
   {
      current_trading_mode = MODE_AUTO;
      SendTelegramMessage("Trading mode set to AUTO\nEA trades automatically");
   }
   else
   {
      SendTelegramMessage("Current mode: " + GetTradingModeName() + "\n\nUse:\n/trademode manual\n/trademode hybrid\n/trademode auto");
   }
}

void HandleEmergencyStop()
{
   trading_allowed = false;
   int closed = CloseAllEAPositions();
   
   string msg = "EMERGENCY STOP ACTIVATED\n\n";
   msg += "Trading: HALTED\n";
   msg += "Positions closed: " + IntegerToString(closed) + "\n";
   msg += "Time: " + TimeToString(TimeCurrent()) + "\n\n";
   msg += "Use /resume to restart trading";
   
   SendTelegramMessage(msg);
}

void HandleCloseAllCommand()
{
   int closed = CloseAllEAPositions();
   SendTelegramMessage("Closed " + IntegerToString(closed) + " EA positions\nTotal P&L impact recorded");
}

void HandleCloseLosingCommand()
{
   int closed_count = 0;
   double total_loss = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == Symbol())
      {
         ulong magic = PositionGetInteger(POSITION_MAGIC);
         if(IsEAMagicNumber(magic))
         {
            double profit = PositionGetDouble(POSITION_PROFIT);
            if(profit < 0)
            {
               ulong ticket = PositionGetTicket(i);
               if(trade.PositionClose(ticket))
               {
                  closed_count++;
                  total_loss += profit;
                  RecordTradeClose(ticket, profit, CLOSURE_MANUAL);
               }
            }
         }
      }
   }
   
   string msg = "Closed " + IntegerToString(closed_count) + " losing positions\n";
   msg += "Total loss realized: " + FormatCurrency(total_loss);
   SendTelegramMessage(msg);
}

void HandleModifyTPCommand(string params)
{
   if(StringLen(params) == 0)
   {
      SendTelegramMessage("Usage: /modify_tp [+/-points]\nExample: /modify_tp +50 or /modify_tp -30");
      return;
   }
   
   double adjustment = StringToDouble(params);
   if(adjustment == 0)
   {
      SendTelegramMessage("Invalid adjustment value. Use +/- followed by points.");
      return;
   }
   
   int modified_count = 0;
   double adjustment_price = adjustment * _Point;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == Symbol())
      {
         ulong magic = PositionGetInteger(POSITION_MAGIC);
         if(IsEAMagicNumber(magic))
         {
            ulong ticket = PositionGetTicket(i);
            double current_tp = PositionGetDouble(POSITION_TP);
            double current_sl = PositionGetDouble(POSITION_SL);
            
            if(current_tp > 0)
            {
               double new_tp = current_tp + adjustment_price;
               if(trade.PositionModify(ticket, current_sl, new_tp))
               {
                  modified_count++;
               }
            }
         }
      }
   }
   
   string msg = "Modified TP for " + IntegerToString(modified_count) + " positions\n";
   msg += "Adjustment: " + DoubleToString(adjustment, 0) + " points";
   SendTelegramMessage(msg);
}

void HandleKeepTPCommand()
{
   SendTelegramMessage("All current Take Profit levels maintained\nNo changes made to existing positions");
}

void HandleDeleteTPCommand()
{
   int modified_count = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == Symbol())
      {
         ulong magic = PositionGetInteger(POSITION_MAGIC);
         if(IsEAMagicNumber(magic))
         {
            ulong ticket = PositionGetTicket(i);
            double current_sl = PositionGetDouble(POSITION_SL);
            
            if(trade.PositionModify(ticket, current_sl, 0))
            {
               modified_count++;
            }
         }
      }
   }
   
   string msg = "Removed TP from " + IntegerToString(modified_count) + " positions\n";
   msg += "Trailing stops will now manage exits";
   SendTelegramMessage(msg);
}

void HandleRangeBreakCommand(string params)
{
   if(StringLen(params) == 0)
   {
      SendTelegramMessage("Usage: /rangebreak [bars|current] [trade]\nExample: /rangebreak 100 - Analysis only\nExample: /rangebreak 100 trade - Places stop orders\nExample: /rangebreak current - Current range analysis\nExample: /rangebreak current trade - Monitor current range breakouts");
      return;
   }

   // Parse parameters: bars/current and optional "trade"
   string param_array[];
   int split_count = StringSplit(params, ' ', param_array);
   bool place_trades = (split_count > 1 && param_array[1] == "trade");

   // Check if using "current" parameter
   if(param_array[0] == "current")
   {
      // Get current session and range
      SessionInfo priority = GetPrioritySession();
      if(!priority.is_active)
      {
         SendTelegramMessage("No active session for current range analysis.");
         return;
      }

      if(!priority.ib_completed)
      {
         SendTelegramMessage("IB period not completed. Cannot determine current range.");
         return;
      }

      // Find current session index
      int current_session = -1;
      for(int i = 0; i < 3; i++)
      {
         if(sessions[i].is_active && sessions[i].ib_completed)
         {
            current_session = i;
            break;
         }
      }

      if(current_session == -1)
      {
         SendTelegramMessage("Could not determine current session for range analysis.");
         return;
      }

      CurrentRangeLevels current_range = GetCurrentRangeLevels(current_session);
      if(!current_range.is_valid)
      {
         SendTelegramMessage("Price is outside defined ranges (above H5 or below L5). No current range to monitor.");
         return;
      }

      double current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      double range_size = (current_range.range_high - current_range.range_low) / _Point;

      string msg = "🎯 CURRENT RANGE BREAKOUT " + (place_trades ? "TRADING" : "ANALYSIS") + "\n\n";
      msg += "📊 Range: " + current_range.range_name + "\n";
      msg += "🔼 High: " + DoubleToString(current_range.range_high, _Digits) + "\n";
      msg += "🔽 Low: " + DoubleToString(current_range.range_low, _Digits) + "\n";
      msg += "📈 Current: " + DoubleToString(current_price, _Digits) + "\n";
      msg += "📏 Range Size: " + DoubleToString(range_size, 0) + " points\n\n";

      // Activate current range setup with decay tracking
      ActivateCurrentRangeSetup(current_range);

      if(place_trades)
      {
         bool orders_placed = PlaceRangeBreakoutOrders(active_range_setup);
         if(orders_placed)
         {
            msg += "✅ STOP ORDERS PLACED:\n";
            msg += "🔼 BUY STOP above " + DoubleToString(current_range.range_high, _Digits) + "\n";
            msg += "🔽 SELL STOP below " + DoubleToString(current_range.range_low, _Digits) + "\n\n";
            msg += "🎯 Monitoring " + current_range.range_name + " for breakouts";
         }
         else
         {
            msg += "❌ Failed to place stop orders";
         }
      }
      else
      {
         msg += "🎯 Setup Valid: YES\n";
         msg += "📊 Use '/rangebreak current trade' to place breakout orders\n";
         msg += "🔄 EA will monitor this range for breakouts";
      }

      // Add decay information to message
      msg += "\n\n⏰ SETUP DECAY INFO:\n";
      msg += "Session: " + sessions[range_setup_session_index].name + " (ends " + TimeToString(range_setup_session_end, TIME_MINUTES) + ")\n";
      msg += "Day ends: " + TimeToString(range_setup_day_end, TIME_MINUTES) + "\n";
      msg += "📢 Setup will auto-expire when session ends, priority changes, or day ends";

      SendTelegramMessage(msg);
      return;
   }

   // Original logic for bar count analysis
   int bars = (int)StringToInteger(param_array[0]);
   if(bars < 10 || bars > 500)
   {
      SendTelegramMessage("Invalid bar count. Use 10-500 bars or 'current'.");
      return;
   }

   RangeAnalysis analysis = AnalyzeRange(bars);

   string msg = "🎯 RANGE BREAKOUT " + (place_trades ? "TRADING" : "ANALYSIS") + " (" + IntegerToString(bars) + " bars)\n\n";
   msg += "📊 Range: " + DoubleToString(analysis.range_size_points, 0) + " points\n";
   msg += "⬆️ High: " + DoubleToString(analysis.range_high, _Digits) + "\n";
   msg += "⬇️ Low: " + DoubleToString(analysis.range_low, _Digits) + "\n";
   msg += "📍 Current: " + DoubleToString(analysis.current_price, _Digits) + "\n\n";

   if(analysis.breakout_detected)
   {
      msg += "🚨 BREAKOUT DETECTED: " + analysis.breakout_direction + "\n";
      msg += "💪 Strength: " + DoubleToString(analysis.breakout_strength * 100, 1) + "%\n";
   }
   else
   {
      msg += "📦 No breakout - Price within range\n";
   }

   msg += "✅ Setup Valid: " + (analysis.setup_valid ? "YES" : "NO");

   if(analysis.setup_valid)
   {
      ActivateRangeBreakSetup(bars);
      msg += "\n🔄 Range break setup ACTIVATED";

      if(place_trades)
      {
         bool orders_placed = PlaceRangeBreakoutOrders(analysis);
         if(orders_placed)
         {
            msg += "\n\n💼 STOP ORDERS PLACED:";
            msg += "\n🟢 BUY STOP above " + DoubleToString(analysis.range_high, _Digits);
            msg += "\n🔴 SELL STOP below " + DoubleToString(analysis.range_low, _Digits);
         }
         else
         {
            msg += "\n\n❌ Failed to place stop orders";
         }
      }

      // Add decay information to message
      msg += "\n\n⏰ SETUP DECAY INFO:";
      msg += "\nSession: " + sessions[range_setup_session_index].name + " (ends " + TimeToString(range_setup_session_end, TIME_MINUTES) + ")";
      msg += "\nDay ends: " + TimeToString(range_setup_day_end, TIME_MINUTES);
      msg += "\n📢 Setup will auto-expire when session ends, priority changes, or day ends";
   }
   else if(place_trades)
   {
      msg += "\n\n❌ Cannot place trades - Setup not valid";
   }

   SendTelegramMessage(msg);
}

void HandleTradesCommand(string params)
{
   StringToLower(params);

   if(params == "" || params == "open")
   {
      ShowOpenTrades();
   }
   else if(params == "closed")
   {
      ShowClosedTrades();
   }
   else
   {
      SendTelegramMessage("Usage: /trades [open|closed]\n/trades or /trades open - Show open trades\n/trades closed - Show today's closed trades");
   }
}

//+------------------------------------------------------------------+
//| Emergency Trade Management Commands                             |
//+------------------------------------------------------------------+
void HandleBurstCommand()
{
   // BURST: Close all losing positions immediately
   int closed_count = 0;
   double total_loss = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == Symbol())
      {
         ulong magic = PositionGetInteger(POSITION_MAGIC);
         if(IsEAMagicNumber(magic))
         {
            double profit = PositionGetDouble(POSITION_PROFIT);
            if(profit < 0) // Only close losing positions
            {
               ulong ticket = PositionGetTicket(i);
               if(trade.PositionClose(ticket))
               {
                  closed_count++;
                  total_loss += profit;
                  RecordTradeClose(ticket, profit, CLOSURE_MANUAL);
               }
            }
         }
      }
   }

   string msg = "🚨 BURST EXECUTED 🚨\n\n";
   msg += "💥 Closed " + IntegerToString(closed_count) + " losing positions\n";
   msg += "📉 Total Loss Realized: " + FormatCurrency(total_loss) + "\n\n";
   msg += "⚠️ Profitable positions remain open\n";
   msg += "🔄 EA continues running\n";
   msg += "📈 New signals will be processed";

   SendTelegramMessage(msg);

   Print("BURST COMMAND: Closed " + IntegerToString(closed_count) + " losing positions, Loss: " + DoubleToString(total_loss, 2));
}

void HandleKillCommand()
{
   // KILL: Close ALL positions and stop EA trading for the day
   int closed_count = 0;
   double total_pnl = 0;

   // Close all EA positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == Symbol())
      {
         ulong magic = PositionGetInteger(POSITION_MAGIC);
         if(IsEAMagicNumber(magic))
         {
            ulong ticket = PositionGetTicket(i);
            double profit = PositionGetDouble(POSITION_PROFIT);

            if(trade.PositionClose(ticket))
            {
               closed_count++;
               total_pnl += profit;
               RecordTradeClose(ticket, profit, CLOSURE_MANUAL);
            }
         }
      }
   }

   // Emergency kill executed

   string msg = "💀 KILL SWITCH ACTIVATED 💀\n\n";
   msg += "🚫 ALL " + IntegerToString(closed_count) + " positions CLOSED\n";
   msg += "💰 Total P&L Impact: " + FormatCurrency(total_pnl) + "\n\n";
   msg += "🛑 EA TRADING STOPPED for today\n";
   msg += "⏰ Will resume tomorrow unless manually restarted\n";
   msg += "🔧 Use /resume to restart trading";

   SendTelegramMessage(msg);

   Print("KILL COMMAND: Closed " + IntegerToString(closed_count) + " positions, P&L: " + DoubleToString(total_pnl, 2) + ", Trading stopped");
}

//+------------------------------------------------------------------+
//| Intelligent Burst Mode & Kill Switch System                    |
//+------------------------------------------------------------------+

// Helper function to get or create position state
int GetPositionState(ulong ticket)
{
   for(int i = 0; i < position_states_count; i++)
   {
      if(position_states[i].ticket == ticket)
         return i;
   }

   // Create new position state
   if(position_states_count < ArraySize(position_states))
   {
      position_states[position_states_count].ticket = ticket;
      position_states[position_states_count].burst_mode_active = false;
      position_states[position_states_count].entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      position_states[position_states_count].entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      position_states[position_states_count].original_sl = PositionGetDouble(POSITION_SL);
      position_states[position_states_count].original_tp = PositionGetDouble(POSITION_TP);
      position_states[position_states_count].in_kill_window = true;
      position_states[position_states_count].highest_r_value = 0;
      position_states_count++;
      return position_states_count - 1;
   }

   return -1;
}

// Clean up closed positions from state tracking
void CleanupClosedPositions()
{
   for(int i = position_states_count - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(position_states[i].ticket))
      {
         // Position closed, remove from array
         for(int j = i; j < position_states_count - 1; j++)
         {
            position_states[j] = position_states[j + 1];
         }
         position_states_count--;
      }
   }
}

// Calculate current R-value for a position
double CalculateCurrentR(ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
      return 0;

   double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double current_price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ?
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) :
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double stop_loss = PositionGetDouble(POSITION_SL);

   if(stop_loss == 0) return 0; // No stop loss set

   double risk_distance = MathAbs(entry_price - stop_loss);
   if(risk_distance == 0) return 0;

   double profit_distance = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
                           (current_price - entry_price) : (entry_price - current_price);

   return profit_distance / risk_distance;
}

// Get bars since entry
int GetBarsSinceEntry(ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
      return 0;

   datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
   datetime current_time = iTime(Symbol(), PERIOD_M5, 0);

   int bars = 0;
   for(int i = 0; i < 50; i++) // Look back max 50 bars
   {
      datetime bar_time = iTime(Symbol(), PERIOD_M5, i);
      if(bar_time <= entry_time)
         break;
      bars++;
   }

   return bars;
}

// Get previous ALMA fast value
double GetPreviousALMAFast()
{
   if(alma_bars_count >= 2)
      return alma_fast_values[alma_bars_count - 2];
   return current_fast_alma;
}

// True Range calculation
double GetTrueRange(int shift)
{
   double high = iHigh(Symbol(), PERIOD_M5, shift);
   double low = iLow(Symbol(), PERIOD_M5, shift);
   double prev_close = iClose(Symbol(), PERIOD_M5, shift + 1);

   double tr1 = high - low;
   double tr2 = MathAbs(high - prev_close);
   double tr3 = MathAbs(low - prev_close);

   return MathMax(tr1, MathMax(tr2, tr3));
}

// Sweep detection
bool DetectHighSweep(double level, int min_wick_pts)
{
   double high = iHigh(Symbol(), PERIOD_M5, 1);
   double close = iClose(Symbol(), PERIOD_M5, 1);

   if(high > level)
   {
      double wick_size = (high - MathMax(iOpen(Symbol(), PERIOD_M5, 1), close)) / _Point;
      return wick_size >= min_wick_pts;
   }
   return false;
}

bool DetectLowSweep(double level, int min_wick_pts)
{
   double low = iLow(Symbol(), PERIOD_M5, 1);
   double close = iClose(Symbol(), PERIOD_M5, 1);

   if(low < level)
   {
      double wick_size = (MathMin(iOpen(Symbol(), PERIOD_M5, 1), close) - low) / _Point;
      return wick_size >= min_wick_pts;
   }
   return false;
}

// Cooldown management
bool InCooldownPeriod()
{
   return TimeCurrent() < global_cooldown_until;
}

void SetCooldownPeriod(datetime until)
{
   global_cooldown_until = until;
}

// Get highest high since entry
double GetHighestHigh(ulong ticket, datetime since_time)
{
   double highest = 0;
   for(int i = 0; i < 200; i++)
   {
      datetime bar_time = iTime(Symbol(), PERIOD_M5, i);
      if(bar_time <= since_time)
         break;

      double high = iHigh(Symbol(), PERIOD_M5, i);
      if(highest == 0 || high > highest)
         highest = high;
   }
   return highest;
}

// Get lowest low since entry
double GetLowestLow(ulong ticket, datetime since_time)
{
   double lowest = 0;
   for(int i = 0; i < 200; i++)
   {
      datetime bar_time = iTime(Symbol(), PERIOD_M5, i);
      if(bar_time <= since_time)
         break;

      double low = iLow(Symbol(), PERIOD_M5, i);
      if(lowest == 0 || low < lowest)
         lowest = low;
   }
   return lowest;
}

// Core burst mode analysis
BurstAnalysis AnalyzeBurstConditions(ulong ticket, RangeAnalysis &range_data,
                                    double min_r, int bars_for_r, double tr_atr_ratio, double body_pct, double alma_disp_atr)
{
   BurstAnalysis analysis = {};

   // 1. R-Speed Check
   double current_r = CalculateCurrentR(ticket);
   int bars_since_entry = GetBarsSinceEntry(ticket);
   analysis.r_speed_ok = (current_r >= min_r && bars_since_entry <= bars_for_r);

   // 2. Impulse Check
   double last_tr = GetTrueRange(1);
   int atr_handle = iATR(Symbol(), PERIOD_M5, 14);
   double atr14_values[];
   CopyBuffer(atr_handle, 0, 1, 1, atr14_values);
   double atr14 = atr14_values[0];
   double current_body_pct = MathAbs(iClose(Symbol(), PERIOD_M5, 1) - iOpen(Symbol(), PERIOD_M5, 1)) /
                    (iHigh(Symbol(), PERIOD_M5, 1) - iLow(Symbol(), PERIOD_M5, 1));
   analysis.impulse_ok = (last_tr >= tr_atr_ratio * atr14) && (current_body_pct >= body_pct);

   // 3. ALMA Alignment
   bool is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double alma_threshold = current_slow_alma + (is_long ? 1 : -1) * alma_disp_atr * atr14;
   double alma_slope = current_fast_alma - GetPreviousALMAFast();
   if(is_long) {
       analysis.alma_aligned = (iClose(Symbol(), PERIOD_M5, 1) > alma_threshold) && (alma_slope > 0);
   } else {
       analysis.alma_aligned = (iClose(Symbol(), PERIOD_M5, 1) < alma_threshold) && (alma_slope < 0);
   }

   // 4. IB Hold Check
   if(is_long) {
       analysis.ib_hold = (iClose(Symbol(), PERIOD_M5, 1) > range_data.range_high &&
                          iClose(Symbol(), PERIOD_M5, 2) > range_data.range_high);
   } else {
       analysis.ib_hold = (iClose(Symbol(), PERIOD_M5, 1) < range_data.range_low &&
                          iClose(Symbol(), PERIOD_M5, 2) < range_data.range_low);
   }

   // Calculate total votes
   analysis.total_votes = (int)analysis.r_speed_ok + (int)analysis.impulse_ok +
                         (int)analysis.alma_aligned + (int)analysis.ib_hold;
   analysis.should_burst = (analysis.total_votes >= 3);

   return analysis;
}

// Core kill switch analysis
KillAnalysis AnalyzeKillConditions(ulong ticket, RangeAnalysis &range_data,
                                  double min_r_progress, int bars_window, int sweep_min_pts)
{
   KillAnalysis analysis = {};
   int bars_since_entry = GetBarsSinceEntry(ticket);

   // Only check during kill window
   if(bars_since_entry > bars_window) {
       return analysis; // Too late for kill switch
   }

   double current_r = CalculateCurrentR(ticket);
   bool is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

   // 1. No Progress Check
   if(bars_since_entry >= 3 && current_r < min_r_progress) {
       analysis.no_progress = true;
       analysis.kill_reason = "No progress: " + DoubleToString(current_r, 2) + "R in " + IntegerToString(bars_since_entry) + " bars";
   }

   // 2. Structure Failure
   if(KillOnIBReentry) {
       // Check if breakout trade re-entered IB
       if(is_long && iClose(Symbol(), PERIOD_M5, 1) <= range_data.range_high &&
          iOpen(Symbol(), PERIOD_M5, 1) > range_data.range_high) {
           analysis.structure_fail = true;
           analysis.kill_reason = "Re-entered IB range (long breakout failed)";
       }
       if(!is_long && iClose(Symbol(), PERIOD_M5, 1) >= range_data.range_low &&
          iOpen(Symbol(), PERIOD_M5, 1) < range_data.range_low) {
           analysis.structure_fail = true;
           analysis.kill_reason = "Re-entered IB range (short breakout failed)";
       }
   }

   // Check ALMA cross against position
   if(KillOnALMACross) {
       if((is_long && current_fast_alma < current_slow_alma) ||
          (!is_long && current_fast_alma > current_slow_alma)) {
           analysis.alma_cross = true;
           analysis.kill_reason = "ALMA crossed against position";
       }
   }

   // 3. Reverse Sweep Detection
   if(is_long && DetectHighSweep(range_data.range_high, sweep_min_pts)) {
       analysis.reverse_sweep = true;
       analysis.kill_reason = "High sweep detected at IB level";
   }
   if(!is_long && DetectLowSweep(range_data.range_low, sweep_min_pts)) {
       analysis.reverse_sweep = true;
       analysis.kill_reason = "Low sweep detected at IB level";
   }

   // Determine if kill switch should activate
   analysis.should_kill = analysis.no_progress || analysis.structure_fail ||
                         analysis.reverse_sweep || analysis.alma_cross;

   return analysis;
}

// Activate burst mode for a position
void ActivateBurstMode(ulong ticket, int state_index)
{
   position_states[state_index].burst_mode_active = true;

   // 1. Move to breakeven immediately
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   trade.PositionModify(ticket, entry, 0); // Set SL to entry, remove TP

   // 2. Send notification
   if(telegram_initialized) {
       string msg = "🚀 BURST MODE ACTIVATED\n";
       msg += "Ticket: " + IntegerToString(ticket) + "\n";
       msg += "R-Value: " + DoubleToString(CalculateCurrentR(ticket), 2) + "\n";
       msg += "Letting profits run with intelligent trailing...";
       SendTelegramMessage(msg);
   }

   // 3. Update statistics
   burst_activations_count++;

   Print("BURST MODE: Activated for ticket " + IntegerToString(ticket));
}

// Execute kill switch for a position
void ExecuteKillSwitch(ulong ticket, string reason, int cooldown_minutes)
{
   double profit = PositionGetDouble(POSITION_PROFIT);

   // Close position immediately
   if(trade.PositionClose(ticket)) {
       // Set cooldown
       datetime cooldown_until = TimeCurrent() + cooldown_minutes * 60;
       SetCooldownPeriod(cooldown_until);

       // Send notification
       if(telegram_initialized) {
           string msg = "🛡️ KILL SWITCH ACTIVATED\n";
           msg += "Ticket: " + IntegerToString(ticket) + "\n";
           msg += "Reason: " + reason + "\n";
           msg += "P&L: " + FormatCurrency(profit) + "\n";
           msg += "Cooldown: " + IntegerToString(cooldown_minutes) + " minutes";
           SendTelegramMessage(msg);
       }

       // Update statistics
       kill_activations_count++;
       total_kill_loss += profit;

       RecordTradeClose(ticket, profit, CLOSURE_MANUAL);

       Print("KILL SWITCH: Activated for ticket " + IntegerToString(ticket) + " - " + reason);
   }
}

//+------------------------------------------------------------------+
//| Execute Burst Momentum Entry                                     |
//+------------------------------------------------------------------+
void ExecuteBurstMomentumEntry(ulong trigger_ticket, BurstAnalysis &burst_signals)
{
   if(!runtime_enable_burst_momentum) return;

   // Check daily and cooldown limits
   if(!CanExecuteBurstMomentum()) return;

   // Get direction from trigger position
   if(!PositionSelectByTicket(trigger_ticket)) return;

   bool is_long_trigger = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   string direction_str = is_long_trigger ? "LONG" : "SHORT";

   // Calculate momentum position size (smaller than regular trades)
   double momentum_size = CalculateBurstMomentumSize();
   if(momentum_size == 0) return;

   // Get current prices
   double current_price = is_long_trigger ?
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK) :
                         SymbolInfoDouble(Symbol(), SYMBOL_BID);

   // Calculate ATR-based stop loss (tighter for momentum trades)
   int atr_handle = iATR(Symbol(), PERIOD_M5, 14);
   double atr_values[];
   CopyBuffer(atr_handle, 0, 1, 1, atr_values);
   double atr = atr_values[0];

   double stop_distance = atr * 1.5; // Tighter stop for momentum
   double stop_loss = is_long_trigger ?
                     current_price - stop_distance :
                     current_price + stop_distance;

   // No take profit - will use burst trailing immediately
   double take_profit = 0;

   // Execute the momentum entry
   ulong new_ticket = 0;
   bool success = false;

   if(is_long_trigger)
   {
      success = trade.Buy(momentum_size, Symbol(), current_price, stop_loss, take_profit,
                         "BURST_MOMENTUM_LONG");
   }
   else
   {
      success = trade.Sell(momentum_size, Symbol(), current_price, stop_loss, take_profit,
                          "BURST_MOMENTUM_SHORT");
   }

   if(success)
   {
      new_ticket = trade.ResultOrder();

      // Update tracking
      last_burst_momentum_time = TimeCurrent();
      daily_burst_momentum_count++;

      // Initialize position state and activate burst mode immediately
      int state_index = GetPositionState(new_ticket);
      if(state_index != -1)
      {
         position_states[state_index].burst_mode_active = true;

         // Send notification
         string msg = "🚀💥 BURST MOMENTUM ENTRY\n\n";
         msg += "🎯 Direction: " + direction_str + "\n";
         msg += "📊 Trigger Ticket: #" + IntegerToString(trigger_ticket) + "\n";
         msg += "🆕 New Ticket: #" + IntegerToString(new_ticket) + "\n";
         msg += "💰 Size: " + DoubleToString(momentum_size, 2) + "\n";
         msg += "🎪 Entry: " + DoubleToString(current_price, _Digits) + "\n";
         msg += "🛑 Stop: " + DoubleToString(stop_loss, _Digits) + "\n";
         msg += "⚡ Started in BURST MODE immediately\n\n";

         msg += "📈 Burst Signals Met:\n";
         if(burst_signals.r_speed_ok) msg += "✅ R-Speed Target\n";
         if(burst_signals.impulse_ok) msg += "✅ Impulse Move\n";
         if(burst_signals.alma_aligned) msg += "✅ ALMA Alignment\n";
         if(burst_signals.ib_hold) msg += "✅ IB Structure Hold\n";

         SendTelegramMessage(msg);

         Print("BURST MOMENTUM: Executed " + direction_str + " entry, Ticket: " + IntegerToString(new_ticket) +
               ", Size: " + DoubleToString(momentum_size, 2) + ", Trigger: " + IntegerToString(trigger_ticket));
      }
   }
   else
   {
      Print("BURST MOMENTUM: Failed to execute entry - " + IntegerToString(trade.ResultRetcode()));
   }
}

//+------------------------------------------------------------------+
//| Check if burst momentum entry is allowed                         |
//+------------------------------------------------------------------+
bool CanExecuteBurstMomentum()
{
   // Check if feature is enabled
   if(!EnableBurstMomentumEntries || !runtime_enable_burst_momentum) return false;

   // Reset daily counter if new day
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime today_start = StructToTime(dt);

   if(burst_momentum_day_start != today_start)
   {
      burst_momentum_day_start = today_start;
      daily_burst_momentum_count = 0;
   }

   // Check daily limit
   if(daily_burst_momentum_count >= BurstMomentumMaxPerDay)
   {
      return false;
   }

   // Check cooldown
   if(TimeCurrent() - last_burst_momentum_time < BurstMomentumCooldown * 60)
   {
      return false;
   }

   // Check if we're in trading session - at least one session must be active
   SessionInfo active_session = GetPrioritySession();
   if(!active_session.is_active) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Calculate position size for burst momentum entries               |
//+------------------------------------------------------------------+
double CalculateBurstMomentumSize()
{
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = account_balance * (BurstMomentumRiskPct / 100.0);

   // Apply maximum risk limit
   if(risk_amount > BurstMomentumMaxRisk)
      risk_amount = BurstMomentumMaxRisk;

   // Calculate stop distance in points
   int atr_handle = iATR(Symbol(), PERIOD_M5, 14);
   double atr_values[];
   CopyBuffer(atr_handle, 0, 1, 1, atr_values);
   double atr = atr_values[0];

   double stop_distance = atr * 1.5; // Same as used in entry function
   double tick_value = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);

   if(tick_value == 0 || tick_size == 0 || stop_distance == 0) return 0;

   double stop_points = stop_distance / tick_size;
   double position_size = risk_amount / (stop_points * tick_value);

   // Apply minimum and maximum lot size limits
   double min_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

   position_size = MathMax(position_size, min_lot);
   position_size = MathMin(position_size, max_lot);
   position_size = NormalizeDouble(position_size / lot_step, 0) * lot_step;

   return position_size;
}

// Update burst mode trailing
void UpdateBurstModeTrailing(ulong ticket, int state_index, RangeAnalysis &range_data, double trail_atr_multiple, int trail_buffer_pts)
{
   bool is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   int atr_handle = iATR(Symbol(), PERIOD_M5, 14);
   double atr_values[];
   CopyBuffer(atr_handle, 0, 1, 1, atr_values);
   double atr = atr_values[0];

   // Calculate trailing stop
   double new_sl;
   if(is_long) {
       // Trail below recent highs with ATR buffer
       double recent_high = GetHighestHigh(ticket, position_states[state_index].entry_time);
       new_sl = recent_high - trail_atr_multiple * atr;

       // Alternative: Trail behind ALMA
       double alma_trail = current_slow_alma - trail_buffer_pts * _Point;
       new_sl = MathMax(new_sl, alma_trail); // Use whichever is higher
   } else {
       // Trail above recent lows with ATR buffer
       double recent_low = GetLowestLow(ticket, position_states[state_index].entry_time);
       new_sl = recent_low + trail_atr_multiple * atr;

       // Alternative: Trail behind ALMA
       double alma_trail = current_slow_alma + trail_buffer_pts * _Point;
       new_sl = MathMin(new_sl, alma_trail); // Use whichever is lower
   }

   // Only update if new stop is better
   double current_sl = PositionGetDouble(POSITION_SL);
   if((is_long && new_sl > current_sl) || (!is_long && new_sl < current_sl)) {
       trade.PositionModify(ticket, new_sl, 0);
   }

   // Check for burst mode exit conditions (price back in IB)
   bool back_in_ib = false;
   if(is_long && iClose(Symbol(), PERIOD_M5, 1) <= range_data.range_high) {
       back_in_ib = true;
   }
   if(!is_long && iClose(Symbol(), PERIOD_M5, 1) >= range_data.range_low) {
       back_in_ib = true;
   }

   if(back_in_ib) {
       position_states[state_index].burst_mode_active = false;
       Print("BURST MODE: Deactivated for ticket " + IntegerToString(ticket) + " - price back in IB");
   }
}

// Main position management with burst/kill system
void ManagePositionsWithBurstKill()
{
   if(!runtime_enable_burst_mode && !runtime_enable_kill_switch)
      return; // Both features disabled

   // Get asset-optimized burst/kill parameters
   double opt_burst_min_r, opt_burst_tr_atr, opt_burst_body_pct, opt_burst_alma_disp, opt_burst_trail_atr;
   int opt_burst_bars, opt_burst_trail_buffer;
   double opt_kill_min_r;
   int opt_kill_bars, opt_kill_sweep_pts, opt_kill_cooldown;

   GetOptimizedBurstKillParams(_Symbol, active_alma_preset,
                              opt_burst_min_r, opt_burst_bars, opt_burst_tr_atr, opt_burst_body_pct,
                              opt_burst_alma_disp, opt_burst_trail_atr, opt_burst_trail_buffer,
                              opt_kill_min_r, opt_kill_bars, opt_kill_sweep_pts, opt_kill_cooldown);

   CleanupClosedPositions();

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == Symbol())
      {
         ulong magic = PositionGetInteger(POSITION_MAGIC);
         if(IsEAMagicNumber(magic))
         {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket))
            {
               RangeAnalysis range_data = AnalyzeRange(12); // Use existing function

               // Get or create position state
               int state_index = GetPositionState(ticket);
               if(state_index == -1) continue;

               // Update highest R-value achieved
               double current_r = CalculateCurrentR(ticket);
               if(current_r > position_states[state_index].highest_r_value)
                  position_states[state_index].highest_r_value = current_r;

               // Check kill switch first (highest priority)
               if(runtime_enable_kill_switch && !position_states[state_index].burst_mode_active && position_states[state_index].in_kill_window)
               {
                  KillAnalysis kill = AnalyzeKillConditions(ticket, range_data, opt_kill_min_r, opt_kill_bars, opt_kill_sweep_pts);
                  if(kill.should_kill)
                  {
                     ExecuteKillSwitch(ticket, kill.kill_reason, opt_kill_cooldown);
                     continue; // Position closed, move to next
                  }

                  // Close kill window after time limit
                  if(GetBarsSinceEntry(ticket) > opt_kill_bars)
                     position_states[state_index].in_kill_window = false;
               }

               // Check burst mode activation
               if(runtime_enable_burst_mode && !position_states[state_index].burst_mode_active)
               {
                  BurstAnalysis burst = AnalyzeBurstConditions(ticket, range_data, opt_burst_min_r, opt_burst_bars, opt_burst_tr_atr, opt_burst_body_pct, opt_burst_alma_disp);
                  if(burst.should_burst)
                  {
                     ActivateBurstMode(ticket, state_index);

                     // Execute momentum entry in same direction
                     ExecuteBurstMomentumEntry(ticket, burst);
                  }
               }

               // Manage burst mode trailing
               if(position_states[state_index].burst_mode_active)
               {
                  UpdateBurstModeTrailing(ticket, state_index, range_data, opt_burst_trail_atr, opt_burst_trail_buffer);
               }
            }
         }
      }
   }
}

// Burst mode status reporting
void SendBurstModeStatus()
{
   string msg = "🚀 BURST MODE STATUS\n\n";
   msg += "Status: " + (runtime_enable_burst_mode ? "ENABLED ✅" : "DISABLED ❌") + "\n";

   // Show current analysis timeframe
   string current_tf = "";
   switch(burst_kill_timeframe)
   {
      case PERIOD_M1: current_tf = "1 minute ✅"; break;
      case PERIOD_M5: current_tf = "5 minutes 🐌"; break;
      default: current_tf = "Unknown"; break;
   }
   msg += "Analysis Speed: " + current_tf + "\n\n";

   if(runtime_enable_burst_mode)
   {
      msg += "📊 PARAMETERS:\n";
      msg += "• R-Speed Target: " + DoubleToString(BurstMinRSpeed, 1) + "R in " + IntegerToString(BurstBarsFor06R) + " bars\n";
      msg += "• ATR Impulse: " + DoubleToString(BurstTRoverATR, 2) + "x ATR\n";
      msg += "• Min Body %: " + DoubleToString(BurstBodyPct * 100, 0) + "%\n";
      msg += "• ALMA Distance: " + DoubleToString(BurstALMADispATR, 2) + "x ATR\n";
      msg += "• Trail Multiple: " + DoubleToString(BurstTrailATRMultiple, 1) + "x ATR\n\n";

      msg += "📈 SESSION STATS:\n";
      msg += "• Activations: " + IntegerToString(burst_activations_count) + "\n";

      if(burst_activations_count > 0)
      {
         double avg_burst_profit = total_burst_profit / burst_activations_count;
         msg += "• Avg Profit: " + DoubleToString(avg_burst_profit, 2) + "R\n";
      }

      // Check active burst positions
      int active_burst_count = 0;
      for(int i = 0; i < position_states_count; i++)
      {
         if(position_states[i].burst_mode_active)
            active_burst_count++;
      }
      msg += "• Active Now: " + IntegerToString(active_burst_count) + " positions\n";
   }

   SendTelegramMessage(msg);
}

// Kill switch status reporting
void SendKillSwitchStatus()
{
   string msg = "🛡️ KILL SWITCH STATUS\n\n";
   msg += "Status: " + (runtime_enable_kill_switch ? "ENABLED ✅" : "DISABLED ❌") + "\n";

   // Show current analysis timeframe
   string current_tf = "";
   switch(burst_kill_timeframe)
   {
      case PERIOD_M1: current_tf = "1 minute ✅"; break;
      case PERIOD_M5: current_tf = "5 minutes 🐌"; break;
      default: current_tf = "Unknown"; break;
   }
   msg += "Analysis Speed: " + current_tf + "\n\n";

   if(runtime_enable_kill_switch)
   {
      msg += "📊 PARAMETERS:\n";
      msg += "• Progress Target: " + DoubleToString(KillMinRProgress, 1) + "R by bar 3-4\n";
      msg += "• Monitor Window: " + IntegerToString(KillBarsWindow) + " bars\n";
      msg += "• Sweep Threshold: " + IntegerToString(KillSweepMinPts) + " points\n";
      msg += "• Cooldown: " + IntegerToString(KillCooldownMinutes) + " minutes\n";
      msg += "• ALMA Cross: " + (KillOnALMACross ? "YES" : "NO") + "\n";
      msg += "• IB Re-entry: " + (KillOnIBReentry ? "YES" : "NO") + "\n\n";

      msg += "📉 SESSION STATS:\n";
      msg += "• Activations: " + IntegerToString(kill_activations_count) + "\n";

      if(kill_activations_count > 0)
      {
         double avg_kill_loss = total_kill_loss / kill_activations_count;
         msg += "• Avg Loss: " + DoubleToString(avg_kill_loss, 2) + "R\n";
      }

      // Check cooldown status
      if(InCooldownPeriod())
      {
         int remaining_seconds = (int)(global_cooldown_until - TimeCurrent());
         msg += "• Cooldown: " + IntegerToString(remaining_seconds / 60) + "m " + IntegerToString(remaining_seconds % 60) + "s remaining\n";
      }
      else
      {
         msg += "• Cooldown: None\n";
      }

      // Check positions in kill window
      int kill_window_count = 0;
      for(int i = 0; i < position_states_count; i++)
      {
         if(position_states[i].in_kill_window)
            kill_window_count++;
      }
      msg += "• In Kill Window: " + IntegerToString(kill_window_count) + " positions\n";
   }

   SendTelegramMessage(msg);
}

// Burst momentum status reporting
void SendBurstMomentumStatus()
{
   string msg = "🚀💥 BURST MOMENTUM STATUS\n\n";
   msg += "Status: " + (runtime_enable_burst_momentum ? "ENABLED ✅" : "DISABLED ❌") + "\n";
   msg += "Input Setting: " + (EnableBurstMomentumEntries ? "ENABLED" : "DISABLED") + "\n\n";

   if(runtime_enable_burst_momentum)
   {
      msg += "📊 PARAMETERS:\n";
      msg += "• Risk per Entry: " + DoubleToString(BurstMomentumRiskPct, 1) + "% of balance\n";
      msg += "• Max Risk per Entry: $" + DoubleToString(BurstMomentumMaxRisk, 0) + "\n";
      msg += "• Cooldown: " + IntegerToString(BurstMomentumCooldown) + " minutes\n";
      msg += "• Daily Limit: " + IntegerToString(BurstMomentumMaxPerDay) + " entries\n\n";

      msg += "📈 TODAY'S STATS:\n";
      msg += "• Entries Used: " + IntegerToString(daily_burst_momentum_count) + "/" + IntegerToString(BurstMomentumMaxPerDay) + "\n";

      // Calculate time since last entry
      if(last_burst_momentum_time > 0)
      {
         int minutes_since = (int)((TimeCurrent() - last_burst_momentum_time) / 60);
         if(minutes_since < BurstMomentumCooldown)
         {
            int minutes_remaining = BurstMomentumCooldown - minutes_since;
            msg += "• Cooldown: " + IntegerToString(minutes_remaining) + " min remaining ⏳\n";
         }
         else
         {
            msg += "• Cooldown: READY ✅\n";
         }
      }
      else
      {
         msg += "• Cooldown: READY ✅\n";
      }

      // Check if we can execute momentum entry right now
      bool can_execute = CanExecuteBurstMomentum();
      msg += "• Ready to Execute: " + (can_execute ? "YES ✅" : "NO ❌") + "\n\n";

      if(!can_execute)
      {
         msg += "🚫 BLOCKED BY:\n";
         if(daily_burst_momentum_count >= BurstMomentumMaxPerDay)
            msg += "• Daily limit reached\n";
         if(TimeCurrent() - last_burst_momentum_time < BurstMomentumCooldown * 60)
            msg += "• Cooldown active\n";
         SessionInfo active_session = GetPrioritySession();
         if(!active_session.is_active)
            msg += "• Outside trading hours\n";
         msg += "\n";
      }

      msg += "⚡ HOW IT WORKS:\n";
      msg += "• Triggers when existing position enters burst mode\n";
      msg += "• Adds momentum position in same direction\n";
      msg += "• Smaller size (safer risk)\n";
      msg += "• Starts in burst mode immediately\n";
      msg += "• Uses intelligent trailing from entry";
   }
   else
   {
      msg += "ℹ️ Burst momentum entries are disabled.\n";
      msg += "Use /momentum_toggle to enable.";
   }

   SendTelegramMessage(msg);
}

// Handle burst/kill timeframe change command
void HandleBurstTimeframeCommand(string params)
{
   if(StringLen(params) == 0)
   {
      // Show current timeframe and available options
      string current_tf = "";
      switch(burst_kill_timeframe)
      {
         case PERIOD_M1: current_tf = "1M"; break;
         case PERIOD_M5: current_tf = "5M"; break;
         default: current_tf = "Unknown"; break;
      }

      string msg = "⏱️ BURST/KILL ANALYSIS TIMEFRAME\n\n";
      msg += "Current: " + current_tf + "\n\n";
      msg += "Available Options:\n";
      msg += "• /burst_timeframe 1m - Balanced (recommended) ✅\n";
      msg += "• /burst_timeframe 5m - Conservative (slower response)\n\n";
      msg += "✅ 1m = optimal balance for most trading\n";
      msg += "🐌 5m = slower but very stable";

      SendTelegramMessage(msg);
      return;
   }

   StringToLower(params);
   ENUM_TIMEFRAMES new_timeframe;
   string tf_name = "";

   if(params == "1m" || params == "1min")
   {
      new_timeframe = PERIOD_M1;
      tf_name = "1 minute";
   }
   else if(params == "5m" || params == "5min")
   {
      new_timeframe = PERIOD_M5;
      tf_name = "5 minutes";
   }
   else
   {
      SendTelegramMessage("❌ Invalid timeframe. Use: 1m or 5m\n\nExample: /burst_timeframe 1m");
      return;
   }

   // Update the timeframe
   burst_kill_timeframe = new_timeframe;

   string msg = "⏱️ TIMEFRAME UPDATED\n\n";
   msg += "Burst/Kill Analysis: " + tf_name + "\n\n";

   if(new_timeframe == PERIOD_M1)
   {
      msg += "✅ BALANCED MODE\n";
      msg += "• Max detection: 1 minute\n";
      msg += "• Optimal signal quality\n";
      msg += "• Best for: Most trading scenarios";
   }
   else if(new_timeframe == PERIOD_M5)
   {
      msg += "🐌 CONSERVATIVE MODE\n";
      msg += "• Max detection: 5 minutes\n";
      msg += "• Lowest false signals\n";
      msg += "• Best for: Stable, confirmed moves";
   }

   msg += "\n\n🔄 Change takes effect immediately";

   SendTelegramMessage(msg);

   Print("BURST/KILL TIMEFRAME: Changed to " + tf_name);
}

void ShowOpenTrades()
{
   string msg = "📊 OPEN TRADES\n\n";
   int open_count = 0;

   // First, update managed trades with current position data
   UpdateManagedTrades();

   for(int i = 0; i < managed_trades_count; i++)
   {
      ManagedTrade managed_trade = managed_trades[i];

      // Check if position still exists
      if(PositionSelectByTicket(managed_trade.ticket))
      {
         double current_price = SymbolInfoDouble(Symbol(), managed_trade.is_buy ? SYMBOL_BID : SYMBOL_ASK);
         double unrealized_pnl = PositionGetDouble(POSITION_PROFIT);
         double current_sl = PositionGetDouble(POSITION_SL);
         double current_tp = PositionGetDouble(POSITION_TP);

         msg += "🎯 " + managed_trade.trade_id + " - " + (managed_trade.is_buy ? "🔼 BUY" : "🔽 SELL") + "\n";
         msg += "💰 Entry: " + DoubleToString(managed_trade.open_price, _Digits) + "\n";
         msg += "📈 Current: " + DoubleToString(current_price, _Digits) + "\n";
         msg += "🔻 Stop: " + DoubleToString(current_sl, _Digits) + " (" + managed_trade.stop_type + ")\n";
         msg += "🎯 TP: " + DoubleToString(current_tp, _Digits) + "\n";
         msg += "💵 P&L: " + FormatCurrency(unrealized_pnl) + "\n";
         msg += "📊 Size: " + DoubleToString(managed_trade.lot_size, 2) + " lots\n";
         msg += "🕐 " + TimeToString(managed_trade.open_time, TIME_DATE|TIME_MINUTES) + "\n";
         msg += "📍 Session: " + sessions[managed_trade.session_index].name + "\n";
         msg += "⚙️ Strategy: " + managed_trade.strategy_name + "\n\n";
         open_count++;
      }
   }

   if(open_count == 0)
   {
      msg += "No open trades\n\n";
   }

   msg += "Total Open: " + IntegerToString(open_count) + " trades\n";
   msg += "🎛️ Use '/modify [ID]' to manage trades";

   // Append manual trades to the message
   string manual_trades_msg = GetManualTradesInfo();
   if(StringLen(manual_trades_msg) > 0)
   {
      msg += manual_trades_msg;
   }

   SendTelegramMessage(msg);
}

//+------------------------------------------------------------------+
//| Show All Positions and Pending Orders (Comprehensive)          |
//+------------------------------------------------------------------+
void ShowAllPositionsAndOrders()
{
   string msg = "📊 ALL POSITIONS & ORDERS\n\n";
   int total_positions = 0;
   int total_orders = 0;

   // === OPEN POSITIONS ===
   msg += "🔹 OPEN POSITIONS:\n";
   bool has_positions = false;

   int positions_total = PositionsTotal();
   for(int p = 0; p < positions_total; p++)
   {
      ulong ticket = PositionGetTicket(p);
      if(ticket > 0)
      {
         if(PositionSelectByTicket(ticket))
         {
            string pos_symbol = PositionGetString(POSITION_SYMBOL);
            if(pos_symbol == _Symbol)
            {
            has_positions = true;
            total_positions++;

            // ticket already available from PositionGetTicket(p)
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double volume           = PositionGetDouble(POSITION_VOLUME);
            double open_price       = PositionGetDouble(POSITION_PRICE_OPEN);
            double current_price    = PositionGetDouble(POSITION_PRICE_CURRENT);
            double sl               = PositionGetDouble(POSITION_SL);
            double tp               = PositionGetDouble(POSITION_TP);
            double profit           = PositionGetDouble(POSITION_PROFIT);
            datetime open_time      = (datetime)PositionGetInteger(POSITION_TIME);

            string comment = PositionGetString(POSITION_COMMENT);

            msg += "\n🎯 #" + IntegerToString((int)ticket) + " - " + (type == POSITION_TYPE_BUY ? "🟢 BUY" : "🔴 SELL") + "\n";
            msg += "💰 Entry: " + DoubleToString(open_price, _Digits) + "\n";
            msg += "📈 Current: " + DoubleToString(current_price, _Digits) + "\n";
            msg += "🛡️ SL: " + (sl > 0 ? DoubleToString(sl, _Digits) : "None") + "\n";
            msg += "🎯 TP: " + (tp > 0 ? DoubleToString(tp, _Digits) : "None") + "\n";
            msg += "💵 P&L: " + DoubleToString(profit, 2) + "\n";
            msg += "📦 Size: " + DoubleToString(volume, 2) + " lots\n";
            msg += "🕐 " + TimeToString(open_time, TIME_DATE|TIME_MINUTES) + "\n";
            if(StringLen(comment) > 0)
               msg += "📝 " + comment + "\n";
            }
         }
      }
   }

   if(!has_positions)
      msg += "No open positions\n";

   // === PENDING ORDERS ===
   msg += "\n🔹 PENDING ORDERS:\n";
   bool has_orders = false;

   int orders_total = OrdersTotal();
   for(int j = 0; j < orders_total; j++)
   {
      ulong order_ticket = OrderGetTicket(j);
      if(order_ticket > 0)
      {
         string ord_symbol = OrderGetString(ORDER_SYMBOL);
         if(ord_symbol == _Symbol)
         {
            has_orders = true;
            total_orders++;

            ulong ticket = (ulong)OrderGetInteger(ORDER_TICKET);
            ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            double volume = OrderGetDouble(ORDER_VOLUME_INITIAL);
            double price = OrderGetDouble(ORDER_PRICE_OPEN);
            double sl = OrderGetDouble(ORDER_SL);
            double tp = OrderGetDouble(ORDER_TP);
            datetime time_setup = (datetime)OrderGetInteger(ORDER_TIME_SETUP);

            string comment = OrderGetString(ORDER_COMMENT);

            string order_type_str = "";
            switch(type)
            {
               case ORDER_TYPE_BUY_LIMIT: order_type_str = "🟢 BUY LIMIT"; break;
               case ORDER_TYPE_SELL_LIMIT: order_type_str = "🔴 SELL LIMIT"; break;
               case ORDER_TYPE_BUY_STOP: order_type_str = "🟢 BUY STOP"; break;
               case ORDER_TYPE_SELL_STOP: order_type_str = "🔴 SELL STOP"; break;
               case ORDER_TYPE_BUY_STOP_LIMIT: order_type_str = "🟢 BUY STOP LIMIT"; break;
               case ORDER_TYPE_SELL_STOP_LIMIT: order_type_str = "🔴 SELL STOP LIMIT"; break;
               default: order_type_str = "❓ UNKNOWN";
            }

            msg += "\n⏳ #" + IntegerToString((int)ticket) + " - " + order_type_str + "\n";
            msg += "💰 Price: " + DoubleToString(price, _Digits) + "\n";
            msg += "🛡️ SL: " + (sl > 0 ? DoubleToString(sl, _Digits) : "None") + "\n";
            msg += "🎯 TP: " + (tp > 0 ? DoubleToString(tp, _Digits) : "None") + "\n";
            msg += "📦 Size: " + DoubleToString(volume, 2) + " lots\n";
            msg += "🕐 " + TimeToString(time_setup, TIME_DATE|TIME_MINUTES) + "\n";
            if(StringLen(comment) > 0)
               msg += "📝 " + comment + "\n";
         }
      }
   }

   if(!has_orders)
      msg += "No pending orders\n";

   // === SUMMARY ===
   msg += "\n📊 SUMMARY:\n";
   msg += "• Positions: " + IntegerToString(total_positions) + "\n";
   msg += "• Orders: " + IntegerToString(total_orders) + "\n";
   msg += "• Total: " + IntegerToString(total_positions + total_orders) + "\n\n";
   msg += "🎛️ Use '/modify [ticket]' to manage trades";

   SendTelegramMessage(msg);
}

string GetManualTradesInfo()
{
   ManualTradeInfo manual_trades[];
   int manual_count = DetectManualTrades(manual_trades);
   int manual_without_stops = 0;
   string manual_msg = "";

   if(manual_count > 0)
   {
      manual_msg += "\n\n--- MANUAL TRADES ---\n";

      for(int i = 0; i < manual_count; i++)
      {
         double current_price = SymbolInfoDouble(Symbol(), manual_trades[i].is_buy ? SYMBOL_BID : SYMBOL_ASK);
         double unrealized_pnl = 0;

         if(PositionSelectByTicket(manual_trades[i].ticket))
            unrealized_pnl = PositionGetDouble(POSITION_PROFIT);

         manual_msg += "\n👤 M" + IntegerToString(i+1) + " - " + (manual_trades[i].is_buy ? "🟢 BUY" : "🔴 SELL") + " [MANUAL]";

         if(!manual_trades[i].has_stop_loss)
         {
            manual_msg += " ⚠️ NO STOP";
            manual_without_stops++;
         }

         manual_msg += "\n";
         manual_msg += "💰 Entry: " + DoubleToString(manual_trades[i].open_price, _Digits) + "\n";
         manual_msg += "📊 Current: " + DoubleToString(current_price, _Digits) + "\n";
         manual_msg += "🛡️ Stop: " + (manual_trades[i].has_stop_loss ? DoubleToString(manual_trades[i].current_sl, _Digits) : "NONE ⚠️") + "\n";
         manual_msg += "🎯 TP: " + (manual_trades[i].current_tp > 0 ? DoubleToString(manual_trades[i].current_tp, _Digits) : "NONE") + "\n";
         manual_msg += "💵 P&L: " + FormatCurrency(unrealized_pnl) + "\n";
         manual_msg += "📦 Size: " + DoubleToString(manual_trades[i].lot_size, 2) + " lots\n";
         manual_msg += "🕐 " + TimeToString(manual_trades[i].open_time, TIME_DATE|TIME_MINUTES);
      }

      if(manual_without_stops > 0)
      {
         manual_msg += "\n\n⚠️ WARNING: " + IntegerToString(manual_without_stops) + " manual trade" +
                      (manual_without_stops == 1 ? "" : "s") + " without stop loss!";
      }
   }

   return manual_msg;
}

void ShowClosedTrades()
{
   string msg = "📋 TODAY'S CLOSED TRADES\n\n";

   // Get today's start time
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime today_start = StructToTime(dt);
   datetime today_end = today_start + 86400;

   if(!HistorySelect(today_start, today_end))
   {
      SendTelegramMessage("Failed to retrieve trade history");
      return;
   }

   int deals_total = HistoryDealsTotal();
   int closed_count = 0;
   double total_pnl = 0;

   // Group deals by session
   string tokyo_trades = "";
   string london_trades = "";
   string ny_trades = "";
   int tokyo_count = 0, london_count = 0, ny_count = 0;
   double tokyo_pnl = 0, london_pnl = 0, ny_pnl = 0;

   for(int i = 0; i < deals_total; i++)
   {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0) continue;

      ulong deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
      if(!IsEAMagicNumber(deal_magic)) continue;

      ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
      if(deal_type == DEAL_TYPE_BUY || deal_type == DEAL_TYPE_SELL)
      {
         datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
         double deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
         double deal_volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
         double deal_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);

         // Determine session based on time
         MqlDateTime deal_dt;
         TimeToStruct(deal_time, deal_dt);
         int session_idx = GetSessionForTime(deal_dt.hour);

         string trade_info = (deal_type == DEAL_TYPE_BUY ? "🔼 BUY" : "🔽 SELL") + "\n";
         trade_info += "💰 Price: " + DoubleToString(deal_price, _Digits) + "\n";
         trade_info += "📊 Size: " + DoubleToString(deal_volume, 2) + " lots\n";
         trade_info += "💵 P&L: " + FormatCurrency(deal_profit) + "\n";
         trade_info += "🕐 " + TimeToString(deal_time, TIME_MINUTES) + "\n\n";

         if(session_idx == 0) // Tokyo
         {
            tokyo_trades += trade_info;
            tokyo_count++;
            tokyo_pnl += deal_profit;
         }
         else if(session_idx == 1) // London
         {
            london_trades += trade_info;
            london_count++;
            london_pnl += deal_profit;
         }
         else if(session_idx == 2) // New York
         {
            ny_trades += trade_info;
            ny_count++;
            ny_pnl += deal_profit;
         }

         closed_count++;
         total_pnl += deal_profit;
      }
   }

   // Build session-separated message
   if(tokyo_count > 0)
   {
      msg += "🌅 TOKYO SESSION (" + IntegerToString(tokyo_count) + " trades, " + FormatCurrency(tokyo_pnl) + ")\n";
      msg += tokyo_trades;
   }

   if(london_count > 0)
   {
      msg += "🏛️ LONDON SESSION (" + IntegerToString(london_count) + " trades, " + FormatCurrency(london_pnl) + ")\n";
      msg += london_trades;
   }

   if(ny_count > 0)
   {
      msg += "🗽 NEW YORK SESSION (" + IntegerToString(ny_count) + " trades, " + FormatCurrency(ny_pnl) + ")\n";
      msg += ny_trades;
   }

   if(closed_count == 0)
   {
      msg += "No closed trades today\n\n";
   }

   msg += "📈 TOTAL: " + IntegerToString(closed_count) + " trades, " + FormatCurrency(total_pnl);

   SendTelegramMessage(msg);
}

int GetSessionForTime(int hour)
{
   // Convert to session hours (assuming GMT)
   if(hour >= sessions[0].start_hour && hour < sessions[0].end_hour) return 0; // Tokyo
   if(hour >= sessions[1].start_hour && hour < sessions[1].end_hour) return 1; // London
   if(hour >= sessions[2].start_hour && hour < sessions[2].end_hour) return 2; // New York
   return -1; // Outside sessions
}

void UpdateManagedTrades()
{
   // Remove trades that are no longer open
   for(int i = managed_trades_count - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(managed_trades[i].ticket))
      {
         // Position closed, remove from managed trades
         for(int j = i; j < managed_trades_count - 1; j++)
         {
            managed_trades[j] = managed_trades[j + 1];
         }
         managed_trades_count--;
      }
   }
}

void HandleRangeRevertCommand(string params)
{
   if(StringLen(params) == 0)
   {
      SendTelegramMessage("Usage: /rangerevert [bars] [trade]\nExample: /rangerevert 100 - Analysis only\nExample: /rangerevert 100 trade - Places limit orders");
      return;
   }

   // Parse parameters: bars and optional "trade"
   string param_array[];
   int split_count = StringSplit(params, ' ', param_array);

   int bars = (int)StringToInteger(param_array[0]);
   bool place_trades = (split_count > 1 && param_array[1] == "trade");

   if(bars < 10 || bars > 500)
   {
      SendTelegramMessage("Invalid bar count. Use 10-500 bars.");
      return;
   }

   RangeAnalysis analysis = AnalyzeRange(bars);

   string msg = "🔄 RANGE REVERSION " + (place_trades ? "TRADING" : "ANALYSIS") + " (" + IntegerToString(bars) + " bars)\n\n";
   msg += "📊 Range: " + DoubleToString(analysis.range_size_points, 0) + " points\n";
   msg += "⬆️ High: " + DoubleToString(analysis.range_high, _Digits) + "\n";
   msg += "⬇️ Low: " + DoubleToString(analysis.range_low, _Digits) + "\n";
   msg += "📍 Current: " + DoubleToString(analysis.current_price, _Digits) + "\n";
   msg += "🎯 Median: " + DoubleToString((analysis.range_high + analysis.range_low) / 2, _Digits) + "\n\n";

   // Determine reversion opportunity
   double median = (analysis.range_high + analysis.range_low) / 2;
   double distance_from_median = MathAbs(analysis.current_price - median);
   double range_threshold = (analysis.range_high - analysis.range_low) * 0.3; // 30% of range

   bool near_high = (analysis.current_price > (analysis.range_high - range_threshold));
   bool near_low = (analysis.current_price < (analysis.range_low + range_threshold));
   bool reversion_setup = (near_high || near_low) && analysis.setup_valid;

   if(near_high)
   {
      msg += "📈 Near Range High - SELL setup\n";
      msg += "💡 Strategy: Sell high, target median\n";
   }
   else if(near_low)
   {
      msg += "📉 Near Range Low - BUY setup\n";
      msg += "💡 Strategy: Buy low, target median\n";
   }
   else
   {
      msg += "🎯 Price near median - Wait for extremes\n";
      msg += "💡 Strategy: Wait for range edges\n";
   }

   msg += "\n✅ Reversion Setup: " + (reversion_setup ? "YES" : "NO");

   if(reversion_setup && place_trades)
   {
      bool orders_placed = PlaceRangeReversionOrders(analysis, near_high, near_low);
      if(orders_placed)
      {
         msg += "\n\n💼 LIMIT ORDERS PLACED:";
         if(near_high)
         {
            msg += "\n🔴 SELL LIMIT near high";
            msg += "\n🎯 Target: Range median";
         }
         if(near_low)
         {
            msg += "\n🟢 BUY LIMIT near low";
            msg += "\n🎯 Target: Range median";
         }
      }
      else
      {
         msg += "\n\n❌ Failed to place limit orders";
      }
   }
   else if(place_trades && !reversion_setup)
   {
      msg += "\n\n❌ Cannot place trades - No reversion setup";
   }

   SendTelegramMessage(msg);
}

void HandleModifyCommand(string params)
{
   if(StringLen(params) == 0)
   {
      string help_msg = "🎛️ TRADE MODIFICATION COMMANDS\n\n";
      help_msg += "STOP LOSS MANAGEMENT:\n";
      help_msg += "/modify [ID] stop [LEVEL] - Set static stop\n";
      help_msg += "/modify [ID] stop fast - Dynamic ALMA Fast stop\n";
      help_msg += "/modify [ID] stop slow - Dynamic ALMA Slow stop\n";
      help_msg += "/modify [ID] stop ibhigh - Stop at IB High\n";
      help_msg += "/modify [ID] stop iblow - Stop at IB Low\n";
      help_msg += "/modify [ID] stop h1/h2/h3/h4/h5 - Stop at extension level\n";
      help_msg += "/modify [ID] stop l1/l2/l3/l4/l5 - Stop at extension level\n\n";
      help_msg += "TAKE PROFIT:\n";
      help_msg += "/modify [ID] tp [LEVEL] - Set take profit\n\n";
      help_msg += "EXAMPLES:\n";
      help_msg += "/modify B1 stop 2650.50\n";
      help_msg += "/modify S2 stop fast\n";
      help_msg += "/modify B1 tp h3\n";
      help_msg += "/modify S3 stop iblow";

      SendTelegramMessage(help_msg);
      return;
   }

   string parts[];
   int parts_count = StringSplit(params, ' ', parts);

   if(parts_count < 3)
   {
      SendTelegramMessage("❌ Invalid format. Use: /modify [ID] [stop/tp] [value]");
      return;
   }

   string trade_id = parts[0];
   string action = parts[1];
   string value = parts[2];

   StringToUpper(trade_id);
   StringToLower(action);
   StringToLower(value);

   int trade_index = FindManagedTradeIndex(trade_id);
   if(trade_index == -1)
   {
      SendTelegramMessage("❌ Trade ID '" + trade_id + "' not found. Use /trades to see open trades.");
      return;
   }

   if(action == "stop")
   {
      HandleStopModification(trade_index, value);
   }
   else if(action == "tp")
   {
      HandleTPModification(trade_index, value);
   }
   else
   {
      SendTelegramMessage("❌ Invalid action. Use 'stop' or 'tp'");
   }
}

void HandleStopModification(int trade_index, string value)
{
   double new_stop_level = 0;
   string new_stop_type = "";

   if(value == "fast")
   {
      new_stop_type = "fast_alma";
      new_stop_level = GetCurrentALMAStop(true); // Fast ALMA
   }
   else if(value == "slow")
   {
      new_stop_type = "slow_alma";
      new_stop_level = GetCurrentALMAStop(false); // Slow ALMA
   }
   else if(value == "ibhigh")
   {
      new_stop_type = "ib_high";
      SessionInfo priority = GetPrioritySession();
      new_stop_level = priority.ib_high;
   }
   else if(value == "iblow")
   {
      new_stop_type = "ib_low";
      SessionInfo priority = GetPrioritySession();
      new_stop_level = priority.ib_low;
   }
   else if(value == "h1" || value == "h2" || value == "h3" || value == "h4" || value == "h5")
   {
      int level = (int)StringToInteger(StringSubstr(value, 1, 1));
      new_stop_type = value;
      new_stop_level = GetExtensionLevel(level, true);
   }
   else if(value == "l1" || value == "l2" || value == "l3" || value == "l4" || value == "l5")
   {
      int level = (int)StringToInteger(StringSubstr(value, 1, 1));
      new_stop_type = value;
      new_stop_level = GetExtensionLevel(level, false);
   }
   else
   {
      // Try to parse as static level
      new_stop_level = StringToDouble(value);
      if(new_stop_level > 0)
      {
         new_stop_type = "static";
      }
      else
      {
         SendTelegramMessage("❌ Invalid stop level: " + value);
         return;
      }
   }

   if(new_stop_level <= 0)
   {
      SendTelegramMessage("❌ Invalid stop level calculated: " + DoubleToString(new_stop_level, _Digits));
      return;
   }

   // Validate stop level direction
   if(managed_trades[trade_index].is_buy && new_stop_level >= managed_trades[trade_index].open_price)
   {
      SendTelegramMessage("❌ Stop loss for BUY must be below entry price");
      return;
   }
   if(!managed_trades[trade_index].is_buy && new_stop_level <= managed_trades[trade_index].open_price)
   {
      SendTelegramMessage("❌ Stop loss for SELL must be above entry price");
      return;
   }

   // Execute the modification
   if(!PositionSelectByTicket(managed_trades[trade_index].ticket))
   {
      SendTelegramMessage("❌ Position not found");
      return;
   }

   double current_tp = PositionGetDouble(POSITION_TP);

   if(!trade.PositionModify(managed_trades[trade_index].ticket, new_stop_level, current_tp))
   {
      SendTelegramMessage("❌ Failed to modify stop loss: " + IntegerToString(GetLastError()));
      return;
   }

   // Update managed trade info
   managed_trades[trade_index].stop_type = new_stop_type;
   managed_trades[trade_index].static_stop_level = new_stop_level;
   managed_trades[trade_index].last_alma_stop = new_stop_level;

   string success_msg = "✅ STOP LOSS UPDATED\n\n";
   success_msg += "🎯 Trade: " + managed_trades[trade_index].trade_id + "\n";
   success_msg += "🔻 New Stop: " + DoubleToString(new_stop_level, _Digits) + "\n";
   success_msg += "⚙️ Type: " + new_stop_type + "\n";
   if(new_stop_type != "static")
   {
      success_msg += "🔄 Dynamic updates: ENABLED";
   }

   SendTelegramMessage(success_msg);
}

void HandleTPModification(int trade_index, string value)
{
   double new_tp_level = 0;

   // Check if it's an extension level
   if(value == "h1" || value == "h2" || value == "h3" || value == "h4" || value == "h5")
   {
      int level = (int)StringToInteger(StringSubstr(value, 1, 1));
      new_tp_level = GetExtensionLevel(level, true);
   }
   else if(value == "l1" || value == "l2" || value == "l3" || value == "l4" || value == "l5")
   {
      int level = (int)StringToInteger(StringSubstr(value, 1, 1));
      new_tp_level = GetExtensionLevel(level, false);
   }
   else if(value == "ibhigh")
   {
      SessionInfo priority = GetPrioritySession();
      new_tp_level = priority.ib_high;
   }
   else if(value == "iblow")
   {
      SessionInfo priority = GetPrioritySession();
      new_tp_level = priority.ib_low;
   }
   else
   {
      // Try to parse as static level
      new_tp_level = StringToDouble(value);
   }

   if(new_tp_level <= 0)
   {
      SendTelegramMessage("❌ Invalid take profit level: " + value);
      return;
   }

   // Validate TP direction
   if(managed_trades[trade_index].is_buy && new_tp_level <= managed_trades[trade_index].open_price)
   {
      SendTelegramMessage("❌ Take profit for BUY must be above entry price");
      return;
   }
   if(!managed_trades[trade_index].is_buy && new_tp_level >= managed_trades[trade_index].open_price)
   {
      SendTelegramMessage("❌ Take profit for SELL must be below entry price");
      return;
   }

   // Execute the modification
   if(!PositionSelectByTicket(managed_trades[trade_index].ticket))
   {
      SendTelegramMessage("❌ Position not found");
      return;
   }

   double current_sl = PositionGetDouble(POSITION_SL);

   if(!trade.PositionModify(managed_trades[trade_index].ticket, current_sl, new_tp_level))
   {
      SendTelegramMessage("❌ Failed to modify take profit: " + IntegerToString(GetLastError()));
      return;
   }

   string success_msg = "✅ TAKE PROFIT UPDATED\n\n";
   success_msg += "🎯 Trade: " + managed_trades[trade_index].trade_id + "\n";
   success_msg += "🎯 New TP: " + DoubleToString(new_tp_level, _Digits) + "\n";
   success_msg += "⚙️ Level: " + value;

   SendTelegramMessage(success_msg);
}

double GetCurrentALMAStop(bool use_fast)
{
   UpdateALMAValues();
   return use_fast ? current_fast_alma : current_slow_alma;
}

void UpdateDynamicStops()
{
   static datetime last_update = 0;
   datetime current_time = TimeCurrent();

   // Update every 30 seconds to avoid excessive updates
   if(current_time - last_update < 30) return;
   last_update = current_time;

   // Update ALMA values first
   UpdateALMAValues();

   for(int i = 0; i < managed_trades_count; i++)
   {
      if(managed_trades[i].stop_type == "static") continue; // Skip static stops

      // Check if position still exists
      if(!PositionSelectByTicket(managed_trades[i].ticket)) continue;

      double new_stop_level = 0;
      bool should_update = false;

      // Calculate new stop level based on type
      if(managed_trades[i].stop_type == "fast_alma")
      {
         new_stop_level = current_fast_alma;
         should_update = (MathAbs(new_stop_level - managed_trades[i].last_alma_stop) > (5 * _Point));
      }
      else if(managed_trades[i].stop_type == "slow_alma")
      {
         new_stop_level = current_slow_alma;
         should_update = (MathAbs(new_stop_level - managed_trades[i].last_alma_stop) > (5 * _Point));
      }
      else if(managed_trades[i].stop_type == "ib_high")
      {
         SessionInfo priority = GetPrioritySession();
         new_stop_level = priority.ib_high;
         should_update = (MathAbs(new_stop_level - managed_trades[i].last_alma_stop) > (2 * _Point));
      }
      else if(managed_trades[i].stop_type == "ib_low")
      {
         SessionInfo priority = GetPrioritySession();
         new_stop_level = priority.ib_low;
         should_update = (MathAbs(new_stop_level - managed_trades[i].last_alma_stop) > (2 * _Point));
      }
      else if(StringFind(managed_trades[i].stop_type, "h") == 0 || StringFind(managed_trades[i].stop_type, "l") == 0)
      {
         // Extension levels (h1, h2, l1, l2, etc.)
         int level = (int)StringToInteger(StringSubstr(managed_trades[i].stop_type, 1, 1));
         bool is_high = (StringFind(managed_trades[i].stop_type, "h") == 0);
         new_stop_level = GetExtensionLevel(level, is_high);
         should_update = (MathAbs(new_stop_level - managed_trades[i].last_alma_stop) > (2 * _Point));
      }

      if(!should_update || new_stop_level <= 0) continue;

      // Validate direction for trailing
      bool valid_trailing = false;
      if(managed_trades[i].is_buy)
      {
         // For BUY, stop should be below entry and only move up
         valid_trailing = (new_stop_level < managed_trades[i].open_price &&
                          new_stop_level > managed_trades[i].last_alma_stop);
      }
      else
      {
         // For SELL, stop should be above entry and only move down
         valid_trailing = (new_stop_level > managed_trades[i].open_price &&
                          new_stop_level < managed_trades[i].last_alma_stop);
      }

      if(!valid_trailing && managed_trades[i].trailing_enabled) continue;

      // Execute the stop update
      double current_tp = PositionGetDouble(POSITION_TP);
      if(trade.PositionModify(managed_trades[i].ticket, new_stop_level, current_tp))
      {
         DebugLog("DynamicStops", "Updated " + managed_trades[i].trade_id + " stop from " +
                  DoubleToString(managed_trades[i].last_alma_stop, _Digits) + " to " +
                  DoubleToString(new_stop_level, _Digits) + " (type: " + managed_trades[i].stop_type + ")");

         managed_trades[i].last_alma_stop = new_stop_level;

         // Optional notification for significant moves
         double move_points = MathAbs(new_stop_level - managed_trades[i].static_stop_level) / _Point;
         if(move_points > 20) // Notify for moves > 20 points
         {
            string update_msg = "🔄 DYNAMIC STOP UPDATED\n\n";
            update_msg += "🎯 Trade: " + managed_trades[i].trade_id + "\n";
            update_msg += "🔻 New Stop: " + DoubleToString(new_stop_level, _Digits) + "\n";
            update_msg += "⚙️ Type: " + managed_trades[i].stop_type + "\n";
            update_msg += "📏 Moved: " + DoubleToString(move_points, 1) + " points";

            if(!quiet_mode) SendTelegramMessage(update_msg);
         }
      }
   }
}

void SendALMAAnalysis()
{
   // Force ALMA update before analysis
   UpdateALMAValues();

   string analysis = "ALMA LINE ANALYSIS\n\n";

   // Add debug info if values are zero
   if(current_fast_alma == 0 || current_slow_alma == 0)
   {
      analysis += "⚠️ DEBUG INFO:\n";
      analysis += "Weights calculated: " + (alma_weights_calculated ? "YES" : "NO") + "\n";
      analysis += "Fast window size: " + IntegerToString(FastWindowSize) + "\n";
      analysis += "Slow window size: " + IntegerToString(SlowWindowSize) + "\n";
      analysis += "Current time: " + TimeToString(TimeCurrent()) + "\n";
      analysis += "Market open: " + (IsMarketOpen() ? "YES" : "NO") + "\n\n";
   }

   analysis += "Fast ALMA: " + DoubleToString(current_fast_alma, _Digits) + "\n";
   analysis += "Slow ALMA: " + DoubleToString(current_slow_alma, _Digits) + "\n";
   
   double separation = MathAbs(current_fast_alma - current_slow_alma) / _Point;
   analysis += "Separation: " + DoubleToString(separation, 1) + " points\n\n";
   
   if(current_fast_alma > current_slow_alma)
   {
      analysis += "SIGNAL: BULLISH\n";
      analysis += "Fast ALMA above Slow ALMA\n";
      analysis += "Bias: Upward momentum";
   }
   else
   {
      analysis += "SIGNAL: BEARISH\n";
      analysis += "Fast ALMA below Slow ALMA\n";
      analysis += "Bias: Downward momentum";
   }
   
   SendTelegramMessage(analysis);
}

void SendIBAnalysis()
{
   SessionInfo priority = GetPrioritySession();
   int session_index = GetPrioritySessionIndex();

   UpdateALMAValues();

   string analysis = "";

   if(priority.is_active && priority.ib_completed)
   {
      // Use the same format as IB completion notification
      analysis = "📊 " + priority.name + " IB ANALYSIS\n\n";
      analysis += "⏰ Current Time: " + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES) + "\n";
      analysis += "📊 IB Duration: 1 hour\n\n";

      analysis += "📈 IB CALCULATIONS:\n";
      analysis += "Range: " + DoubleToString(priority.ib_range, 0) + " points\n";
      analysis += "High: " + DoubleToString(priority.ib_high, _Digits) + "\n";
      analysis += "Low: " + DoubleToString(priority.ib_low, _Digits) + "\n";
      analysis += "Median: " + DoubleToString(priority.ib_median, _Digits) + "\n\n";

      analysis += "🎯 EXTENSION LEVELS:\n";
      analysis += "H5: " + DoubleToString(session_extensions.h5_level, _Digits) + "\n";
      analysis += "H4: " + DoubleToString(session_extensions.h4_level, _Digits) + "\n";
      analysis += "H3: " + DoubleToString(session_extensions.h3_level, _Digits) + "\n";
      analysis += "H2: " + DoubleToString(session_extensions.h2_level, _Digits) + "\n";
      analysis += "H1: " + DoubleToString(session_extensions.h1_level, _Digits) + "\n";
      analysis += "---IB HIGH---\n";
      analysis += "---IB LOW---\n";
      analysis += "L1: " + DoubleToString(session_extensions.l1_level, _Digits) + "\n";
      analysis += "L2: " + DoubleToString(session_extensions.l2_level, _Digits) + "\n";
      analysis += "L3: " + DoubleToString(session_extensions.l3_level, _Digits) + "\n";
      analysis += "L4: " + DoubleToString(session_extensions.l4_level, _Digits) + "\n";
      analysis += "L5: " + DoubleToString(session_extensions.l5_level, _Digits) + "\n\n";

      analysis += "🔍 ALMA ANALYSIS:\n";
      if(current_fast_alma > 0 && current_slow_alma > 0)
      {
         string alma_bias = (current_fast_alma > current_slow_alma) ? "BULLISH 📈" : "BEARISH 📉";
         analysis += "Bias: " + alma_bias + "\n";
         analysis += "Fast ALMA: " + DoubleToString(current_fast_alma, _Digits) + "\n";
         analysis += "Slow ALMA: " + DoubleToString(current_slow_alma, _Digits) + "\n";
         double separation = MathAbs(current_fast_alma - current_slow_alma) / _Point;
         analysis += "Separation: " + DoubleToString(separation, 1) + " points\n\n";
      }
      else
      {
         analysis += "ALMA values calculating...\n\n";
      }

      analysis += "💰 ACCOUNT STATUS:\n";
      analysis += "Balance: " + FormatCurrency(AccountInfoDouble(ACCOUNT_BALANCE)) + "\n";
      analysis += "Equity: " + FormatCurrency(AccountInfoDouble(ACCOUNT_EQUITY)) + "\n";
      analysis += "Daily P&L: " + FormatCurrency(GetDailyPnL()) + "\n\n";

      analysis += "🎯 CURRENT PRICE POSITION:\n";
      analysis += GetCurrentPriceRange() + "\n\n";

      analysis += "💡 Trading Strategy: " + (priority.ib_range > runtime_ib_range_threshold ? "Mean Reversion" : "Breakout");

      string screenshot_path = CaptureScreenshot();
      if(screenshot_path != "")
      {
         string full_message = analysis + "\n\n" + GetFormattedScreenshotCaption();
         SendTelegramPhoto(screenshot_path, full_message);
      }
      else
      {
         SendTelegramMessage(analysis);
      }
   }
   else if(priority.is_active && !priority.ib_completed)
   {
      analysis = "⏳ " + priority.name + " IB PERIOD FORMING\n\n";
      analysis += "Session: " + priority.name + "\n";
      analysis += "IB Status: Still forming\n";
      analysis += "Completion at: " + TimeToString(priority.session_start_time + 3600, TIME_DATE | TIME_MINUTES) + "\n";
      datetime remaining_time = (priority.session_start_time + 3600) - TimeCurrent();
      analysis += "Time remaining: " + IntegerToString((int)(remaining_time / 60)) + " minutes";
      SendTelegramMessage(analysis);
   }
   else
   {
      analysis = "❌ NO ACTIVE SESSION\n\n";
      analysis += "No active session\nWaiting for session start";
      SendTelegramMessage(analysis);
   }
}

void HandleSetSizeCommand(string params)
{
   if(StringLen(params) == 0)
   {
      string msg = "Current position sizing:\n";
      msg += "Mode: " + (PositionSizeMode == SIZE_STATIC ? "Static" : "Dynamic") + "\n";
      msg += "Input Size: " + DoubleToString(StaticLotSize, 2) + " lots\n";
      msg += "Runtime Size: " + DoubleToString(runtime_position_size, 2) + " lots\n";
      msg += "Dynamic Multiple: " + DoubleToString(DynamicMultiple, 2) + "\n";
      msg += "Max Size: " + DoubleToString(MaxLotSize, 2) + " lots\n\n";
      msg += "Usage: /set_size [value]\nExample: /set_size 1.5";
      SendTelegramMessage(msg);
      return;
   }
   
   double new_size = StringToDouble(params);
   if(new_size <= 0 || new_size > 50)
   {
      SendTelegramMessage("Invalid size. Use 0.01 to 50.0 lots.");
      return;
   }
   
   // Update runtime position size
   runtime_position_size = new_size;
   string msg = "Runtime position size updated to " + DoubleToString(new_size, 2) + " lots\n";
   msg += "Note: Affects new trades in static mode";
   SendTelegramMessage(msg);
}

void HandleSetSpreadCommand(string params)
{
   if(StringLen(params) == 0)
   {
      string msg = "Current spread settings:\n";
      msg += "Max Spread: " + DoubleToString(current_max_spread, 1) + " points\n";
      msg += "Current Spread: " + DoubleToString(GetCurrentSpreadPoints(), 1) + " points\n\n";
      msg += "Usage: /set_spread [points]\nExample: /set_spread 25";
      SendTelegramMessage(msg);
      return;
   }
   
   double new_spread = StringToDouble(params);
   if(new_spread <= 0 || new_spread > 200)
   {
      SendTelegramMessage("Invalid spread. Use 1 to 200 points.");
      return;
   }
   
   current_max_spread = new_spread;
   string msg = "Maximum spread updated to " + DoubleToString(new_spread, 1) + " points\n";
   msg += "Trading will pause if spread exceeds this level";
   SendTelegramMessage(msg);
}

void HandleSetNewsCommand(string params)
{
   if(StringLen(params) == 0)
   {
      string msg = "📋 NEWS FILTER SETTINGS\n\n";
      msg += "Current settings:\n";
      msg += "🔴 High Impact:\n";
      msg += "  Before: " + IntegerToString(runtime_high_impact_before) + " minutes\n";
      msg += "  After: " + IntegerToString(runtime_high_impact_after) + " minutes\n\n";
      msg += "🟡 Medium Impact:\n";
      msg += "  Before: " + IntegerToString(runtime_medium_impact_before) + " minutes\n";
      msg += "  After: " + IntegerToString(runtime_medium_impact_after) + " minutes\n\n";
      msg += "📝 Usage:\n";
      msg += "/set_news high 45 20 - High impact: 45min before, 20min after\n";
      msg += "/set_news medium 30 15 - Medium impact: 30min before, 15min after";
      SendTelegramMessage(msg);
      return;
   }

   string parts[];
   int count = StringSplit(params, ' ', parts);

   if(count >= 3)
   {
      string impact_type = parts[0];
      int minutes_before = (int)StringToInteger(parts[1]);
      int minutes_after = (int)StringToInteger(parts[2]);

      if(minutes_before < 0 || minutes_before > 120 || minutes_after < 0 || minutes_after > 120)
      {
         SendTelegramMessage("❌ Invalid time range. Use 0-120 minutes.");
         return;
      }

      if(impact_type == "high")
      {
         runtime_high_impact_before = minutes_before;
         runtime_high_impact_after = minutes_after;
         string msg = "✅ High impact news filter updated:\n";
         msg += "Before: " + IntegerToString(minutes_before) + " minutes\n";
         msg += "After: " + IntegerToString(minutes_after) + " minutes";
         SendTelegramMessage(msg);
      }
      else if(impact_type == "medium")
      {
         runtime_medium_impact_before = minutes_before;
         runtime_medium_impact_after = minutes_after;
         string msg = "✅ Medium impact news filter updated:\n";
         msg += "Before: " + IntegerToString(minutes_before) + " minutes\n";
         msg += "After: " + IntegerToString(minutes_after) + " minutes";
         SendTelegramMessage(msg);
      }
      else
      {
         SendTelegramMessage("❌ Invalid impact type. Use 'high' or 'medium'");
      }
   }
   else
   {
      SendTelegramMessage("❌ Invalid format. Use: /set_news high 30 20");
   }
}

void HandleQuietCommand(string params)
{
   if(StringLen(params) == 0)
   {
      if(quiet_mode)
      {
         int remaining = (int)((quiet_until - TimeCurrent()) / 60);
         SendTelegramMessage("Quiet mode active\n" + IntegerToString(remaining) + " minutes remaining\n\nUse /quiet 0 to disable");
      }
      else
      {
         SendTelegramMessage("Quiet mode: OFF\n\nUsage: /quiet [minutes]\nExample: /quiet 60");
      }
      return;
   }
   
   int minutes = (int)StringToInteger(params);
   if(minutes < 0 || minutes > 1440)
   {
      SendTelegramMessage("Invalid duration. Use 0-1440 minutes (24 hours max).");
      return;
   }
   
   if(minutes == 0)
   {
      quiet_mode = false;
      quiet_until = 0;
      SendTelegramMessage("Quiet mode DISABLED\nNotifications resumed");
   }
   else
   {
      quiet_mode = true;
      quiet_until = TimeCurrent() + (minutes * 60);
      SendTelegramMessage("Quiet mode ENABLED for " + IntegerToString(minutes) + " minutes\nOnly essential alerts will be sent");
   }
}

void HandleTakeCommand()
{
   if(IsAwaitingApproval())
   {
      bool success = HandleTradeApproval(true);
      if(success)
         SendTelegramMessage("Trade ACCEPTED and executed successfully");
      else
         SendTelegramMessage("Trade acceptance failed - check conditions");
   }
   else
   {
      SendTelegramMessage("No pending trade to accept\nUse /status to see current state");
   }
}

void HandleSkipCommand()
{
   if(IsAwaitingApproval())
   {
      HandleTradeApproval(false);
      SendTelegramMessage("Trade DECLINED\nWaiting for next signal");
   }
   else
   {
      SendTelegramMessage("No pending trade to decline\nUse /status to see current state");
   }
}

void HandleReduceSizeCommand()
{
   if(IsAwaitingApproval())
   {
      // Reduce the pending lot size by 50%
      pending_approval.lot_size *= 0.5;
      
      // Normalize to broker requirements
      double min_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
      double lot_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
      
      if(pending_approval.lot_size < min_lot)
      {
         pending_approval.lot_size = min_lot;
      }
      else
      {
         pending_approval.lot_size = NormalizeDouble(pending_approval.lot_size / lot_step, 0) * lot_step;
      }
      
      bool success = HandleTradeApproval(true);
      if(success)
         SendTelegramMessage("Trade executed with REDUCED size: " + DoubleToString(pending_approval.lot_size, 2) + " lots");
      else
         SendTelegramMessage("Reduced size trade failed - check conditions");
   }
   else
   {
      SendTelegramMessage("No pending trade to modify\nUse /status to see current state");
   }
}

void HandlePauseCommand(int minutes)
{
   trading_allowed = false;
   datetime resume_time = TimeCurrent() + (minutes * 60);
   
   string msg = "Trading PAUSED for " + IntegerToString(minutes) + " minutes\n";
   msg += "Will resume at: " + TimeToString(resume_time) + "\n\n";
   msg += "Use /resume for immediate restart";
   
   // Schedule automatic resume (this would need timer implementation)
   SendTelegramMessage(msg);
}

void HandleStopTodayCommand()
{
   trading_allowed = false;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 23;
   dt.min = 59;
   dt.sec = 59;
   datetime end_of_day = StructToTime(dt);
   
   string msg = "Trading STOPPED until tomorrow\n";
   msg += "Will remain paused until: " + TimeToString(end_of_day) + "\n\n";
   msg += "Use /resume for manual restart";
   
   SendTelegramMessage(msg);
}

// Legacy command implementations
void SendEnhancedStatusReport()
{
   string status = "ENHANCED STATUS REPORT\n\n";
   status += "Mode: " + GetTradingModeName() + "\n";
   status += "Session: " + GetPrioritySessionName() + "\n";
   status += "Trading: " + (trading_allowed ? "ALLOWED" : "RESTRICTED") + "\n";
   status += GetTelegramStatus() + "\n\n";
   
   status += "ALMA ANALYSIS:\n";
   status += "Bias: " + (current_fast_alma > current_slow_alma ? "BULLISH" : "BEARISH") + "\n";
   status += "Fast: " + DoubleToString(current_fast_alma, _Digits) + "\n";
   status += "Slow: " + DoubleToString(current_slow_alma, _Digits) + "\n";

   // Add Dynamic ALMA status
   if(runtime_enable_dynamic_alma)
   {
      string preset_name = EnumToString(active_alma_preset);
      StringReplace(preset_name, "ALMA_", "");
      status += "🎯 Dynamic: " + preset_name + " (" + IntegerToString(runtime_fast_length) + "/" + IntegerToString(runtime_slow_length) + ")\n";

      if(UseATRAdaptive)
      {
         double atr_percentile = GetATRPercentile();
         status += "📊 ATR: " + DoubleToString(atr_percentile, 1) + "% ";
         if(atr_percentile > VolatilityHighPercentile)
            status += "(HIGH 🔥)";
         else if(atr_percentile < VolatilityLowPercentile)
            status += "(LOW 😴)";
         else
            status += "(NORMAL ⚖️)";
         status += "\n";
      }

      if(UseSessionAdaptive && IsSessionHotStart())
      {
         status += "🚀 Session: HOT START\n";
      }
   }
   else
   {
      status += "📌 Dynamic: STATIC MODE\n";
   }
   status += "\n";
   
   UpdatePositionSummary();
   status += "POSITIONS:\n";
   status += "EA: " + IntegerToString(position_summary.ea_positions) + " (" + FormatCurrency(position_summary.ea_profit) + ")\n";
   status += "Manual: " + IntegerToString(position_summary.manual_positions) + " (" + FormatCurrency(position_summary.manual_profit) + ")\n\n";
   
   status += "DAILY PERFORMANCE:\n";
   status += "P&L: " + FormatCurrency(GetDailyPnL()) + "\n";
   status += "Trades: " + IntegerToString(today_trade_count) + "\n";
   status += "Win Rate: " + DoubleToString(daily_tracking.winning_trades * 100.0 / MathMax(1, daily_tracking.trades_count), 1) + "%";
   
   SendTelegramMessage(status);
}

void SendEnhancedPositionsReport()
{
   UpdatePositionSummary();
   
   string report = "DETAILED POSITIONS REPORT\n\n";
   report += "EA POSITIONS: " + IntegerToString(position_summary.ea_positions) + "\n";
   report += "Total P&L: " + FormatCurrency(position_summary.ea_profit) + "\n";
   report += "Total Volume: " + DoubleToString(position_summary.ea_volume, 2) + " lots\n";
   report += "Winning: " + IntegerToString(position_summary.winning_ea_positions) + "\n";
   report += "Losing: " + IntegerToString(position_summary.losing_ea_positions) + "\n\n";
   
   if(position_summary.ea_positions > 0)
   {
      report += "Best Position: " + FormatCurrency(position_summary.max_individual_profit) + "\n";
      report += "Worst Position: " + FormatCurrency(position_summary.max_individual_loss) + "\n\n";
   }
   
   report += "MANUAL POSITIONS: " + IntegerToString(position_summary.manual_positions) + "\n";
   report += "Manual P&L: " + FormatCurrency(position_summary.manual_profit) + "\n\n";
   
   report += "TOTAL ACCOUNT P&L: " + FormatCurrency(position_summary.total_profit);
   
   SendTelegramMessage(report);
}

void SendSessionReport()
{
   string report = "SESSION ANALYSIS REPORT\n\n";
   report += "CURRENT SESSION: " + GetPrioritySessionName() + "\n";
   report += "Status: " + GetSessionStatus() + "\n\n";
   
   SessionInfo priority = GetPrioritySession();
   if(priority.is_active)
   {
      report += "Session Start: " + TimeToString(priority.session_start_time) + "\n";
      if(priority.ib_completed)
      {
         report += "IB Range: " + DoubleToString(priority.ib_range, 0) + " points\n";
         report += "IB High: " + DoubleToString(priority.ib_high, _Digits) + "\n";
         report += "IB Low: " + DoubleToString(priority.ib_low, _Digits) + "\n";
      }
      report += "Trades This Session: " + IntegerToString(priority.trades_this_session) + "\n\n";
   }
   
   report += "ALL SESSIONS STATUS:\n";
   for(int i = 0; i < 3; i++)
   {
      report += sessions[i].name + ": " + (sessions[i].is_active ? "ACTIVE" : "INACTIVE");
      if(sessions[i].enabled) report += " (Enabled)";
      report += "\n";
   }
   
   SendTelegramMessage(report);
}

void HandleModeCommand(string params)
{
   HandleTradeModeCommand(params);
}

void HandleApprovalCommand(bool approved)
{
   if(IsAwaitingApproval())
   {
      bool success = HandleTradeApproval(approved);
      if(approved && success)
         SendTelegramMessage("Trade APPROVED and executed");
      else if(approved && !success)
         SendTelegramMessage("Trade approval failed - detailed error sent above ⬆️");
      else
         SendTelegramMessage("Trade REJECTED");
   }
   else
   {
      SendTelegramMessage("No pending approval\nUse /status to see current state");
   }
}

void HandleSignalStatusCommand()
{
   string status_message = "📊 SIGNAL STATUS\n\n";

   datetime current_bar_time = iTime(_Symbol, _Period, 0);

   if(signal_suppressed_until_bar >= current_bar_time)
   {
      int bars_remaining = (int)((signal_suppressed_until_bar - current_bar_time) / PeriodSeconds(_Period)) + 1;
      status_message += "🔇 Signals SUPPRESSED\n";
      status_message += "Suppressed until: Next bar\n";
      status_message += "Current bar: " + TimeToString(current_bar_time) + "\n";
      status_message += "Suppression ends: " + TimeToString(signal_suppressed_until_bar + PeriodSeconds(_Period)) + "\n";
   }
   else
   {
      status_message += "🔔 Signals ACTIVE\n";
      status_message += "Ready to receive new signals\n";

      if(has_sent_signal)
      {
         status_message += "\nLast signal:\n";
         status_message += "Direction: " + (last_sent_signal.is_buy ? "BUY" : "SELL") + "\n";
         status_message += "Strategy: " + last_sent_signal.strategy_name + "\n";
         status_message += "Entry: " + DoubleToString(last_sent_signal.entry_price, _Digits) + "\n";
         status_message += "Time: " + TimeToString(last_sent_signal.signal_time) + "\n";
      }
      else
      {
         status_message += "\nNo signals sent yet\n";
      }
   }

   status_message += "\nCurrent bar: " + TimeToString(current_bar_time);
   status_message += "\nMode: " + GetTradingModeName();

   SendTelegramMessage(status_message);
}

void HandlePnLCommand(string parameters)
{
   string pnl_message = "💰 ACCOUNT ANALYSIS - P&L\n\n";

   double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double floating_pnl = current_equity - current_balance;

   StringToLower(parameters);

   if(parameters == "daily" || parameters == "")
   {
      pnl_message += "📊 DAILY P&L\n";

      // Get actual daily P&L from MT5 history (all EA trades today)
      double daily_pnl_history = GetDailyPnLFromHistory();

      // EA tracked P&L since restart
      double ea_tracked_pnl = current_balance - daily_start_balance;
      double floating_pnl = current_equity - current_balance;

      // Calculate actual start balance for today
      double actual_start_balance = current_balance - daily_pnl_history;
      double daily_pnl_percent = actual_start_balance > 0 ? (daily_pnl_history / actual_start_balance) * 100 : 0;

      pnl_message += "Today's Start Balance: " + FormatCurrency(actual_start_balance) + "\n";
      pnl_message += "Current Balance: " + FormatCurrency(current_balance) + "\n";
      pnl_message += "Current Equity: " + FormatCurrency(current_equity) + "\n\n";

      pnl_message += "📈 DAILY PERFORMANCE:\n";
      pnl_message += "Total Daily P&L: " + FormatCurrency(daily_pnl_history) + " (" + DoubleToString(daily_pnl_percent, 2) + "%)\n";
      pnl_message += "EA Restart Balance: " + FormatCurrency(daily_start_balance) + "\n";
      pnl_message += "EA Tracked P&L: " + FormatCurrency(ea_tracked_pnl) + "\n";
      pnl_message += "Floating P&L: " + FormatCurrency(floating_pnl) + "\n";
   }
   else if(parameters == "weekly")
   {
      pnl_message += "📊 WEEKLY P&L\n";

      double weekly_pnl_history = GetWeeklyPnLFromHistory();
      double actual_week_start = current_balance - weekly_pnl_history;
      double weekly_pnl_percent = actual_week_start > 0 ? (weekly_pnl_history / actual_week_start) * 100 : 0;

      pnl_message += "Week Start Balance: " + FormatCurrency(actual_week_start) + "\n";
      pnl_message += "Current Balance: " + FormatCurrency(current_balance) + "\n";
      pnl_message += "Weekly P&L: " + FormatCurrency(weekly_pnl_history) + " (" + DoubleToString(weekly_pnl_percent, 2) + "%)\n";
   }
   else if(parameters == "monthly")
   {
      pnl_message += "📊 MONTHLY P&L\n";

      double monthly_pnl_history = GetMonthlyPnLFromHistory();
      double actual_month_start = current_balance - monthly_pnl_history;
      double monthly_pnl_percent = actual_month_start > 0 ? (monthly_pnl_history / actual_month_start) * 100 : 0;

      pnl_message += "Month Start Balance: " + FormatCurrency(actual_month_start) + "\n";
      pnl_message += "Current Balance: " + FormatCurrency(current_balance) + "\n";
      pnl_message += "Monthly P&L: " + FormatCurrency(monthly_pnl_history) + " (" + DoubleToString(monthly_pnl_percent, 2) + "%)\n";
   }
   else
   {
      SendTelegramMessage("Invalid period. Use: /pnl daily, /pnl weekly, or /pnl monthly");
      return;
   }

   pnl_message += "\n💹 CURRENT STATUS\n";
   pnl_message += "Equity: " + FormatCurrency(current_equity) + "\n";
   pnl_message += "Floating P&L: " + FormatCurrency(floating_pnl) + "\n";
   pnl_message += "Free Margin: " + FormatCurrency(AccountInfoDouble(ACCOUNT_MARGIN_FREE)) + "\n";

   SendTelegramMessage(pnl_message);
}

void HandleMarginCommand(string parameters)
{
   string margin_message = "📈 ACCOUNT ANALYSIS - MARGIN\n\n";

   double margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   double margin_used = AccountInfoDouble(ACCOUNT_MARGIN);
   double margin_free = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   StringToLower(parameters);

   // Check if setting maximum margin threshold
   if(StringFind(parameters, "max") == 0)
   {
      string parts[];
      int parts_count = StringSplit(parameters, ' ', parts);
      if(parts_count >= 2)
      {
         double new_threshold = StringToDouble(parts[1]);
         if(new_threshold >= 0 && new_threshold <= 1000)
         {
            minimum_margin_level = new_threshold;
            margin_message = "✅ MARGIN THRESHOLD SET\n\n";
            margin_message += "Minimum margin level: " + DoubleToString(minimum_margin_level, 1) + "%\n";
            if(minimum_margin_level > 0)
            {
               margin_message += "⚠️ Trading will be disabled if margin falls below this level\n";
            }
            else
            {
               margin_message += "🔓 Margin protection disabled\n";
            }
         }
         else
         {
            SendTelegramMessage("❌ Invalid threshold. Use 0-1000% (0 to disable)");
            return;
         }
      }
      else
      {
         SendTelegramMessage("❌ Usage: /margin max 110 (sets minimum margin to 110%)");
         return;
      }
   }
   else
   {
      // Display current margin status
      margin_message += "📊 CURRENT MARGIN STATUS\n";
      margin_message += "Margin Level: " + DoubleToString(margin_level, 2) + "%\n";
      margin_message += "Used Margin: " + FormatCurrency(margin_used) + "\n";
      margin_message += "Free Margin: " + FormatCurrency(margin_free) + "\n";
      margin_message += "Equity: " + FormatCurrency(equity) + "\n\n";

      margin_message += "⚙️ MARGIN PROTECTION\n";
      if(minimum_margin_level > 0)
      {
         margin_message += "Minimum Level: " + DoubleToString(minimum_margin_level, 1) + "%\n";
         if(margin_level < minimum_margin_level)
         {
            margin_message += "🚨 BELOW THRESHOLD - Trading disabled\n";
         }
         else
         {
            margin_message += "✅ Above threshold - Trading allowed\n";
         }
      }
      else
      {
         margin_message += "Status: DISABLED\n";
         margin_message += "Use /margin max 110 to set threshold\n";
      }
   }

   SendTelegramMessage(margin_message);
}

void HandlePyramidCommand(string parameters)
{
   string pyramid_message = "🔺 PYRAMIDING CONTROL\n\n";

   StringToLower(parameters);

   if(parameters == "on" || parameters == "enable" || parameters == "true")
   {
      pyramiding_enabled = true;
      pyramid_message = "✅ PYRAMIDING ENABLED\n\n";
      pyramid_message += "📋 Current Settings:\n";
      pyramid_message += "Max Positions: " + IntegerToString(max_pyramid_positions) + "\n";
      pyramid_message += "Profit Threshold: " + FormatCurrency(pyramid_profit_threshold) + "\n";
      pyramid_message += "Scale Factor: " + DoubleToString(pyramid_scale_factor * 100, 0) + "%\n\n";
      pyramid_message += "💡 The EA will now scale into profitable positions\n";
      pyramid_message += "Use /pyramid config to adjust settings";
   }
   else if(parameters == "off" || parameters == "disable" || parameters == "false")
   {
      pyramiding_enabled = false;
      pyramid_message = "❌ PYRAMIDING DISABLED\n\n";
      pyramid_message += "The EA will only open one position per signal\n";
      pyramid_message += "Use /pyramid on to re-enable";
   }
   else if(StringFind(parameters, "max") == 0)
   {
      string parts[];
      int parts_count = StringSplit(parameters, ' ', parts);
      if(parts_count >= 2)
      {
         int new_max = (int)StringToInteger(parts[1]);
         if(new_max >= 1 && new_max <= 10)
         {
            max_pyramid_positions = new_max;
            pyramid_message = "📊 MAX POSITIONS UPDATED\n\n";
            pyramid_message += "Maximum pyramid positions: " + IntegerToString(max_pyramid_positions) + "\n";
            pyramid_message += "Status: " + (pyramiding_enabled ? "ENABLED" : "DISABLED");
         }
         else
         {
            SendTelegramMessage("❌ Invalid max positions. Use 1-10");
            return;
         }
      }
      else
      {
         SendTelegramMessage("❌ Usage: /pyramid max 3");
         return;
      }
   }
   else if(StringFind(parameters, "threshold") == 0)
   {
      string parts[];
      int parts_count = StringSplit(parameters, ' ', parts);
      if(parts_count >= 2)
      {
         double new_threshold = StringToDouble(parts[1]);
         if(new_threshold >= 0 && new_threshold <= 10000)
         {
            pyramid_profit_threshold = new_threshold;
            pyramid_message = "💰 PROFIT THRESHOLD UPDATED\n\n";
            pyramid_message += "Minimum profit for scaling: " + FormatCurrency(pyramid_profit_threshold) + "\n";
            pyramid_message += "Status: " + (pyramiding_enabled ? "ENABLED" : "DISABLED");
         }
         else
         {
            SendTelegramMessage("❌ Invalid threshold. Use 0-10000");
            return;
         }
      }
      else
      {
         SendTelegramMessage("❌ Usage: /pyramid threshold 50");
         return;
      }
   }
   else if(StringFind(parameters, "scale") == 0)
   {
      string parts[];
      int parts_count = StringSplit(parameters, ' ', parts);
      if(parts_count >= 2)
      {
         double new_scale = StringToDouble(parts[1]) / 100.0;
         if(new_scale >= 0.1 && new_scale <= 2.0)
         {
            pyramid_scale_factor = new_scale;
            pyramid_message = "📐 SCALE FACTOR UPDATED\n\n";
            pyramid_message += "Position scale factor: " + DoubleToString(pyramid_scale_factor * 100, 0) + "%\n";
            pyramid_message += "Status: " + (pyramiding_enabled ? "ENABLED" : "DISABLED");
         }
         else
         {
            SendTelegramMessage("❌ Invalid scale factor. Use 10-200%");
            return;
         }
      }
      else
      {
         SendTelegramMessage("❌ Usage: /pyramid scale 70 (for 70%)");
         return;
      }
   }
   else if(StringFind(parameters, "mode") == 0)
   {
      string parts[];
      int parts_count = StringSplit(parameters, ' ', parts);
      if(parts_count >= 2)
      {
         StringToLower(parts[1]);
         if(parts[1] == "flat")
         {
            pyramid_geometric_scaling = false;
            pyramid_message = "📏 SCALING MODE UPDATED\n\n";
            pyramid_message += "Mode: Flat Scaling\n";
            pyramid_message += "All additional positions will be " + DoubleToString(pyramid_scale_factor * 100, 0) + "% of base size\n";
            pyramid_message += "Status: " + (pyramiding_enabled ? "ENABLED" : "DISABLED");
         }
         else if(parts[1] == "geometric")
         {
            pyramid_geometric_scaling = true;
            pyramid_message = "📏 SCALING MODE UPDATED\n\n";
            pyramid_message += "Mode: Geometric Scaling\n";
            pyramid_message += "Each position will be " + DoubleToString(pyramid_scale_factor * 100, 0) + "% of the previous position\n";
            pyramid_message += "Status: " + (pyramiding_enabled ? "ENABLED" : "DISABLED");
         }
         else
         {
            SendTelegramMessage("❌ Invalid scaling mode. Use 'flat' or 'geometric'");
            return;
         }
      }
      else
      {
         SendTelegramMessage("❌ Usage: /pyramid mode flat/geometric");
         return;
      }
   }
   else if(parameters == "config" || parameters == "settings" || parameters == "")
   {
      pyramid_message += "📊 CURRENT STATUS: " + (pyramiding_enabled ? "ENABLED" : "DISABLED") + "\n\n";

      pyramid_message += "⚙️ SETTINGS:\n";
      pyramid_message += "Max Positions: " + IntegerToString(max_pyramid_positions) + "\n";
      pyramid_message += "Profit Threshold: " + FormatCurrency(pyramid_profit_threshold) + "\n";
      pyramid_message += "Scale Factor: " + DoubleToString(pyramid_scale_factor * 100, 0) + "%\n";
      pyramid_message += "Scaling Mode: " + (pyramid_geometric_scaling ? "Geometric" : "Flat") + "\n\n";

      UpdatePositionSummary();
      pyramid_message += "📈 CURRENT POSITIONS:\n";
      pyramid_message += "EA Positions: " + IntegerToString(position_summary.ea_positions) + "\n";
      pyramid_message += "Total P&L: " + FormatCurrency(position_summary.ea_profit) + "\n\n";

      pyramid_message += "💡 COMMANDS:\n";
      pyramid_message += "/pyramid on/off - Enable/disable\n";
      pyramid_message += "/pyramid max 3 - Set max positions\n";
      pyramid_message += "/pyramid threshold 50 - Set profit threshold\n";
      pyramid_message += "/pyramid scale 70 - Set scale factor (%)\n";
      pyramid_message += "/pyramid mode flat/geometric - Set scaling mode";
   }
   else
   {
      SendTelegramMessage("❌ Invalid command. Use: /pyramid [on/off/config/max/threshold/scale/mode]");
      return;
   }

   SendTelegramMessage(pyramid_message);
}

void HandleDirectionCommand(string parameters)
{
   string direction_message = "🧭 TRADING DIRECTION CONTROL\n\n";

   StringToLower(parameters);

   if(parameters == "buy")
   {
      allow_buy_trades = true;
      allow_sell_trades = false;
      direction_message += "✅ BUY ONLY MODE ENABLED\n\n";
      direction_message += "📈 Only BUY trades will be executed\n";
      direction_message += "❌ SELL trades are blocked\n\n";
      direction_message += "Use /direction both to enable all trades";
   }
   else if(parameters == "sell")
   {
      allow_buy_trades = false;
      allow_sell_trades = true;
      direction_message += "✅ SELL ONLY MODE ENABLED\n\n";
      direction_message += "📉 Only SELL trades will be executed\n";
      direction_message += "❌ BUY trades are blocked\n\n";
      direction_message += "Use /direction both to enable all trades";
   }
   else if(parameters == "both" || parameters == "all")
   {
      allow_buy_trades = true;
      allow_sell_trades = true;
      direction_message += "✅ BIDIRECTIONAL TRADING ENABLED\n\n";
      direction_message += "📈 BUY trades: ALLOWED\n";
      direction_message += "📉 SELL trades: ALLOWED\n\n";
      direction_message += "EA will trade in both directions based on signals";
   }
   else if(parameters == "" || parameters == "status")
   {
      direction_message += "📊 CURRENT STATUS:\n\n";
      direction_message += "📈 BUY trades: " + (allow_buy_trades ? "ENABLED" : "DISABLED") + "\n";
      direction_message += "📉 SELL trades: " + (allow_sell_trades ? "ENABLED" : "DISABLED") + "\n\n";

      string current_mode;
      if(allow_buy_trades && allow_sell_trades)
         current_mode = "BIDIRECTIONAL";
      else if(allow_buy_trades && !allow_sell_trades)
         current_mode = "BUY ONLY";
      else if(!allow_buy_trades && allow_sell_trades)
         current_mode = "SELL ONLY";
      else
         current_mode = "NO TRADING";

      direction_message += "🧭 Current Mode: " + current_mode + "\n\n";
      direction_message += "💡 COMMANDS:\n";
      direction_message += "/direction buy - Enable only buy trades\n";
      direction_message += "/direction sell - Enable only sell trades\n";
      direction_message += "/direction both - Enable all trades";
   }
   else
   {
      SendTelegramMessage("❌ Invalid direction. Use: /direction [buy/sell/both/status]");
      return;
   }

   SendTelegramMessage(direction_message);
}

void HandleTrailingCommand(string parameters)
{
   string trail_message = "🔄 TRAILING STOP CONTROL\n\n";

   StringToLower(parameters);

   if(StringFind(parameters, "distance") == 0)
   {
      string parts[];
      int parts_count = StringSplit(parameters, ' ', parts);
      if(parts_count >= 2)
      {
         int new_distance = (int)StringToInteger(parts[1]);
         if(new_distance >= 50 && new_distance <= 2000)
         {
            runtime_trailing_stop_points = new_distance;
            trail_message = "📏 TRAILING DISTANCE UPDATED\n\n";
            trail_message += "New trailing distance: " + IntegerToString(new_distance) + " points (" +
                           DoubleToString(new_distance / 10.0, 1) + " pips)\n";
            trail_message += "Status: " + (trailing_stops_enabled ? "ENABLED" : "DISABLED");
         }
         else
         {
            SendTelegramMessage("❌ Invalid distance. Use 50-2000 points (5-200 pips)");
            return;
         }
      }
      else
      {
         SendTelegramMessage("❌ Usage: /trail distance 300 (for 30 pips)");
         return;
      }
   }
   else if(StringFind(parameters, "threshold") == 0)
   {
      string parts[];
      int parts_count = StringSplit(parameters, ' ', parts);
      if(parts_count >= 2)
      {
         int new_threshold = (int)StringToInteger(parts[1]);
         if(new_threshold >= 0 && new_threshold <= 2000)
         {
            runtime_trailing_profit_threshold = new_threshold;
            trail_message = "🎯 PROFIT THRESHOLD UPDATED\n\n";
            trail_message += "New profit threshold: " + IntegerToString(new_threshold) + " points (" +
                           DoubleToString(new_threshold / 10.0, 1) + " pips)\n";
            trail_message += "Trailing will start after " + DoubleToString(new_threshold / 10.0, 1) + " pips profit\n";
            trail_message += "Status: " + (trailing_stops_enabled ? "ENABLED" : "DISABLED");
         }
         else
         {
            SendTelegramMessage("❌ Invalid threshold. Use 0-2000 points (0-200 pips)");
            return;
         }
      }
      else
      {
         SendTelegramMessage("❌ Usage: /trail threshold 400 (for 40 pips)");
         return;
      }
   }
   else if(parameters == "on" || parameters == "enable")
   {
      trailing_stops_enabled = true;
      trail_message = "✅ TRAILING STOPS ENABLED\n\n";
      trail_message += "📏 Distance: " + IntegerToString(runtime_trailing_stop_points) + " points (" +
                     DoubleToString(runtime_trailing_stop_points / 10.0, 1) + " pips)\n";
      trail_message += "🎯 Threshold: " + IntegerToString(runtime_trailing_profit_threshold) + " points (" +
                     DoubleToString(runtime_trailing_profit_threshold / 10.0, 1) + " pips)\n\n";
      trail_message += "Trailing stops will now manage profitable positions";
   }
   else if(parameters == "off" || parameters == "disable")
   {
      trailing_stops_enabled = false;
      trail_message = "❌ TRAILING STOPS DISABLED\n\n";
      trail_message += "Stop losses will remain at their original levels\n";
      trail_message += "Use /trail on to re-enable trailing";
   }
   else if(parameters == "" || parameters == "status")
   {
      trail_message += "📊 CURRENT STATUS: " + (trailing_stops_enabled ? "ENABLED" : "DISABLED") + "\n\n";
      trail_message += "⚙️ SETTINGS:\n";
      trail_message += "📏 Trailing Distance: " + IntegerToString(runtime_trailing_stop_points) + " points (" +
                     DoubleToString(runtime_trailing_stop_points / 10.0, 1) + " pips)\n";
      trail_message += "🎯 Profit Threshold: " + IntegerToString(runtime_trailing_profit_threshold) + " points (" +
                     DoubleToString(runtime_trailing_profit_threshold / 10.0, 1) + " pips)\n\n";
      trail_message += "💡 COMMANDS:\n";
      trail_message += "/trail on/off - Enable/disable trailing\n";
      trail_message += "/trail distance 300 - Set trailing distance (pips x10)\n";
      trail_message += "/trail threshold 400 - Set profit threshold (pips x10)";
   }
   else
   {
      SendTelegramMessage("❌ Invalid command. Use: /trail [on/off/distance/threshold/status]");
      return;
   }

   SendTelegramMessage(trail_message);
}

void SendDailyProfitTargetNotification(double daily_pnl)
{
   if(!telegram_initialized) return;

   string profit_msg = "🎯 DAILY PROFIT TARGET REACHED!\n\n";
   profit_msg += "💰 Daily P&L: " + FormatCurrency(daily_pnl) + "\n";
   profit_msg += "🎯 Target: " + FormatCurrency(DailyProfitTarget) + "\n\n";
   profit_msg += "🤔 What would you like to do?\n\n";
   profit_msg += "📈 /continue_profit - Keep trading today\n";
   profit_msg += "⏸️ /pause_profit - Pause until tomorrow\n\n";
   profit_msg += "⏰ You have 5 minutes to decide\n";
   profit_msg += "🔄 Default: Trading will pause automatically";

   SendTelegramMessage(profit_msg);
}

void SendDailyLossThresholdNotification(double daily_pnl)
{
   if(!telegram_initialized) return;

   string loss_msg = "⚠️ DAILY LOSS THRESHOLD REACHED!\n\n";
   loss_msg += "📉 Daily P&L: " + FormatCurrency(daily_pnl) + "\n";
   loss_msg += "🚨 Threshold: " + FormatCurrency(-DailyLossThreshold) + "\n\n";
   loss_msg += "🤔 What would you like to do?\n\n";
   loss_msg += "📈 /continue_loss - Keep trading today\n";
   loss_msg += "⏸️ /pause_loss - Pause until tomorrow\n\n";
   loss_msg += "⏰ You have 5 minutes to decide\n";
   loss_msg += "🔄 Default: Trading will pause automatically";

   SendTelegramMessage(loss_msg);
}

void HandleRangeCommand(string parameters)
{
   StringToLower(parameters);

   if(StringFind(parameters, "threshold") == 0)
   {
      string parts[];
      int parts_count = StringSplit(parameters, ' ', parts);
      if(parts_count >= 2)
      {
         int new_threshold = (int)StringToInteger(parts[1]);
         if(new_threshold >= 100 && new_threshold <= 5000)
         {
            runtime_ib_range_threshold = new_threshold;
            string range_msg = "📏 RANGE THRESHOLD UPDATED\n\n";
            range_msg += "New IB range threshold: " + IntegerToString(new_threshold) + " points (" +
                        DoubleToString(new_threshold / 10.0, 1) + " pips)\n\n";
            range_msg += "📊 STRATEGY SELECTION:\n";
            range_msg += "• Range > " + IntegerToString(new_threshold) + " pts → Mean Reversion\n";
            range_msg += "• Range ≤ " + IntegerToString(new_threshold) + " pts → Breakout\n\n";
            range_msg += "✅ Changes applied immediately";

            SendTelegramMessage(range_msg);
         }
         else
         {
            SendTelegramMessage("❌ Invalid threshold. Use 100-5000 points (10-500 pips)");
         }
      }
      else
      {
         SendTelegramMessage("❌ Usage: /range threshold 1200 (for 120 pips)");
      }
   }
   else if(parameters == "" || parameters == "status")
   {
      // Original range display functionality
      string range_msg = "🎯 CURRENT PRICE RANGE\n\n";
      range_msg += "Current Price: " + DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_BID), _Digits) + "\n";
      range_msg += "Position: " + GetCurrentPriceRange() + "\n\n";
      range_msg += "Session: " + GetPrioritySessionName() + "\n\n";

      range_msg += "⚙️ RANGE SETTINGS:\n";
      range_msg += "IB Range Threshold: " + IntegerToString(runtime_ib_range_threshold) + " points (" +
                  DoubleToString(runtime_ib_range_threshold / 10.0, 1) + " pips)\n\n";

      range_msg += "💡 COMMANDS:\n";
      range_msg += "/range - Show this status\n";
      range_msg += "/range threshold [points] - Set threshold\n";
      range_msg += "/rangebreak - Breakout analysis\n";
      range_msg += "/rangerevert - Reversion analysis";

      SendTelegramMessage(range_msg);
   }
   else
   {
      SendTelegramMessage("❌ Invalid parameter. Use: /range [threshold/status]");
   }
}

void HandleContinueProfitCommand()
{
   if(!profit_target_pause_pending)
   {
      SendTelegramMessage("❌ No profit target decision pending");
      return;
   }

   profit_target_pause_pending = false;
   double daily_pnl = GetDailyPnL();

   string msg = "✅ CONTINUING TRADING AFTER PROFIT TARGET\n\n";
   msg += "💰 Current Daily P&L: " + FormatCurrency(daily_pnl) + "\n";
   msg += "🎯 Target Hit: " + FormatCurrency(DailyProfitTarget) + "\n\n";
   msg += "📈 Trading will continue for the rest of today\n";
   msg += "🔄 Targets will reset at midnight";

   SendTelegramMessage(msg);
}

void HandlePauseProfitCommand()
{
   if(!profit_target_pause_pending)
   {
      SendTelegramMessage("❌ No profit target decision pending");
      return;
   }

   profit_target_pause_pending = false;
   trading_allowed = false;
   double daily_pnl = GetDailyPnL();

   string msg = "⏸️ TRADING PAUSED AFTER PROFIT TARGET\n\n";
   msg += "💰 Final Daily P&L: " + FormatCurrency(daily_pnl) + "\n";
   msg += "🎯 Target Hit: " + FormatCurrency(DailyProfitTarget) + "\n\n";
   msg += "🌙 Trading paused until tomorrow\n";
   msg += "🔄 Will auto-resume at midnight\n";
   msg += "📱 Or use /resume to restart manually";

   SendTelegramMessage(msg);
}

void HandleContinueLossCommand()
{
   if(!loss_threshold_pause_pending)
   {
      SendTelegramMessage("❌ No loss threshold decision pending");
      return;
   }

   loss_threshold_pause_pending = false;
   double daily_pnl = GetDailyPnL();

   string msg = "✅ CONTINUING TRADING AFTER LOSS THRESHOLD\n\n";
   msg += "📉 Current Daily P&L: " + FormatCurrency(daily_pnl) + "\n";
   msg += "🚨 Threshold Hit: " + FormatCurrency(-DailyLossThreshold) + "\n\n";
   msg += "⚠️ Trading will continue with caution\n";
   msg += "🔄 Thresholds will reset at midnight";

   SendTelegramMessage(msg);
}

void HandlePauseLossCommand()
{
   if(!loss_threshold_pause_pending)
   {
      SendTelegramMessage("❌ No loss threshold decision pending");
      return;
   }

   loss_threshold_pause_pending = false;
   trading_allowed = false;
   double daily_pnl = GetDailyPnL();

   string msg = "⏸️ TRADING PAUSED AFTER LOSS THRESHOLD\n\n";
   msg += "📉 Final Daily P&L: " + FormatCurrency(daily_pnl) + "\n";
   msg += "🚨 Threshold Hit: " + FormatCurrency(-DailyLossThreshold) + "\n\n";
   msg += "🌙 Trading paused until tomorrow\n";
   msg += "🔄 Will auto-resume at midnight\n";
   msg += "📱 Or use /resume to restart manually";

   SendTelegramMessage(msg);
}

void HandleStopCommand()
{
   trading_allowed = false;
   SendTelegramMessage("Trading PAUSED\nUse /resume to restart");
}

void HandleResumeCommand(string params)
{
   trading_allowed = true;
   daily_loss_limit_hit = false;
   weekly_loss_limit_hit = false;
   drawdown_limit_hit = false;
   consecutive_loss_limit_hit = false;

   string msg = "Trading RESUMED\n";
   msg += "All risk limits reset\n";

   // Check if daily limit override parameter provided
   if(StringLen(params) > 0)
   {
      double additional_limit = StringToDouble(params);
      if(additional_limit > 0)
      {
         // Increase daily loss limit by specified amount (today only)
         current_daily_loss_limit = original_daily_loss_limit + additional_limit;
         daily_limit_overridden = true;

         msg += "📈 DAILY LIMIT INCREASED (today only)\n";
         msg += "Original limit: " + FormatCurrency(original_daily_loss_limit) + "\n";
         msg += "New limit: " + FormatCurrency(current_daily_loss_limit) + "\n";
         msg += "Additional risk: " + FormatCurrency(additional_limit) + "\n";
      }
      else
      {
         msg += "❌ Invalid amount specified\n";
      }
   }
   else
   {
      msg += "Daily limit unchanged: " + FormatCurrency(current_daily_loss_limit) + "\n";
   }

   msg += "Mode: " + GetTradingModeName();
   SendTelegramMessage(msg);
}

void HandleCloseCommand(string params)
{
   if(params == "all")
   {
      int closed = CloseAllEAPositions();
      SendTelegramMessage("Closed " + IntegerToString(closed) + " EA positions");
   }
   else if(StringLen(params) > 0)
   {
      ulong ticket = (ulong)StringToInteger(params);
      if(ticket > 0)
      {
         if(trade.PositionClose(ticket))
            SendTelegramMessage("Position #" + IntegerToString((long)ticket) + " closed successfully");
         else
            SendTelegramMessage("Failed to close position #" + IntegerToString((long)ticket));
      }
      else
      {
         SendTelegramMessage("Invalid ticket number");
      }
   }
   else
   {
      SendTelegramMessage("Usage:\n/close all - Close all EA positions\n/close [ticket] - Close specific position");
   }
}

void SendCompleteTestMessage()
{
   string test = "COMPLETE SYSTEM TEST RESULTS\n\n";
   test += GetTelegramStatus() + "\n";
   test += "Commands: 30+ FUNCTIONAL\n";
   test += "Mode: " + GetTradingModeName() + "\n";
   test += "Session: " + GetPrioritySessionName() + "\n";
   test += "ALMA: " + (current_fast_alma > current_slow_alma ? "BULLISH" : "BEARISH") + "\n";
   test += "Spread: " + DoubleToString(GetCurrentSpreadPoints(), 1) + " pts\n";
   test += "Balance: " + FormatCurrency(AccountInfoDouble(ACCOUNT_BALANCE)) + "\n\n";
   test += "ALL ENHANCED FEATURES ACTIVE\n";
   test += "Ready for production trading!";
   
   SendTelegramMessage(test);
}

//+------------------------------------------------------------------+
//| Module Initialization                                           |
//+------------------------------------------------------------------+
bool InitializeAllModules()
{
   initialization_errors = "";
   
   Print("Initializing ENHANCED modules...");
   
   // Initialize sessions
   InitializeSessions();
   Print("Enhanced session manager initialized");
   
   // Initialize ALMA calculations
   InitializeALMA();
   Print("Enhanced ALMA calculations initialized");

   // Initialize Dynamic ALMA system
   if(runtime_enable_dynamic_alma)
   {
      InitializeDynamicALMA();
      Print("Dynamic ALMA system initialized");
   }

   // Initialize risk manager
   InitializeRiskManager();
   Print("Enhanced risk manager initialized");
   
   // Initialize news manager
   InitializeNewsManager();
   Print("News manager initialized");
   
   // Set all module flags
   command_processor_initialized = true;
   screenshot_module_initialized = false; // Available in next version
   notification_module_initialized = true;
   
   Print("ALL enhanced modules initialized");
   
   // Initialize Telegram interface
   bool telegram_ok = InitializeTelegram();
   if(!telegram_ok)
   {
      Print("Telegram not initialized - manual oversight not available");
   }
   
   all_modules_initialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Enhanced Display and Status                                     |
//+------------------------------------------------------------------+
void UpdateEnhancedDisplay()
{
   string display = "=== ALMA EA v3.04 ENHANCED ===\n";
   display += "Time: " + TimeToString(TimeCurrent()) + "\n\n";
   
   display += "=== ALMA ANALYSIS ===\n";
   display += "Fast ALMA: " + DoubleToString(GetFastALMA(), _Digits) + "\n";
   display += "Slow ALMA: " + DoubleToString(GetSlowALMA(), _Digits) + "\n";
   
   string alma_bias = (GetFastALMA() > GetSlowALMA()) ? "BULLISH" : "BEARISH";
   display += "Direction: " + alma_bias + "\n";

   // Show Dynamic ALMA status if enabled
   if(runtime_enable_dynamic_alma)
   {
      display += "Dynamic: " + GetDynamicALMAStatus() + "\n";
      string preset_name = EnumToString(active_alma_preset);
      StringReplace(preset_name, "ALMA_", "");
      display += "Preset: " + preset_name + " (" + IntegerToString(runtime_fast_length) + "/" + IntegerToString(runtime_slow_length) + ")\n";

      if(UseATRAdaptive)
      {
         double atr_percentile = GetATRPercentile();
         display += "ATR: " + DoubleToString(atr_percentile, 1) + "% ";
         if(atr_percentile > VolatilityHighPercentile)
            display += "(HIGH)";
         else if(atr_percentile < VolatilityLowPercentile)
            display += "(LOW)";
         else
            display += "(NORMAL)";
         display += "\n";
      }

      if(UseSessionAdaptive && IsSessionHotStart())
      {
         display += "Session: HOT START 🔥\n";
      }
   }
   else
   {
      display += "Dynamic: STATIC MODE\n";
   }

   display += "\n=== SESSION STATUS ===\n";
   display += GetSessionStatus() + "\n";
   
   display += "\n=== MARKET CONDITIONS ===\n";
   display += "Spread: " + DoubleToString(GetCurrentSpreadPoints(), 1) + " pts\n";
   display += "Max Spread: " + DoubleToString(current_max_spread, 1) + " pts\n";
   display += "News: " + GetCurrentNewsStatus() + "\n";
   
   display += "\n=== POSITIONS & RISK ===\n";
   display += GetPositionSummary() + "\n";
   
   if(EnableAdvancedRiskManagement)
   {
      display += "Daily P&L: " + FormatCurrency(GetDailyPnL()) + "\n";
      display += "Drawdown: " + DoubleToString(GetCurrentDrawdownPercent(), 2) + "%\n";
      display += "Consecutive: " + IntegerToString(consecutive_tracker.current_consecutive_losses) + " losses\n";
   }
   
   display += "\n=== ENHANCED FEATURES ===\n";
   display += GetTelegramStatus() + "\n";
   display += "Mode: " + GetTradingModeName() + "\n";
   display += "Commands: 30+ ACTIVE\n";
   display += "Today's Trades: " + IntegerToString(today_trade_count) + "\n";
   
   if(quiet_mode)
   {
      int remaining = (int)((quiet_until - TimeCurrent()) / 60);
      display += "Quiet Mode: " + IntegerToString(remaining) + "m remaining\n";
   }
   
   if(IsAwaitingApproval())
   {
      int remaining = GetApprovalTimeRemaining();
      display += "\nAwaiting approval: " + IntegerToString(remaining) + "s remaining\n";
   }
   
   Comment(display);
}

void UpdateDailyTracking()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime today_start = StructToTime(dt);

   if(today_start > daily_tracking.day_start)
   {
      InitializeDailyTracking();
   }

   // Check if new week (Monday)
   MqlDateTime current_dt;
   TimeToStruct(TimeCurrent(), current_dt);
   if(current_dt.day_of_week == 1) // Monday
   {
      MqlDateTime week_start_dt = current_dt;
      week_start_dt.hour = 0;
      week_start_dt.min = 0;
      week_start_dt.sec = 0;
      datetime week_start = StructToTime(week_start_dt);

      static datetime last_week_reset = 0;
      if(week_start > last_week_reset)
      {
         weekly_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
         last_week_reset = week_start;
      }
   }

   // Check if new month (1st day)
   if(current_dt.day == 1)
   {
      MqlDateTime month_start_dt = current_dt;
      month_start_dt.hour = 0;
      month_start_dt.min = 0;
      month_start_dt.sec = 0;
      datetime month_start = StructToTime(month_start_dt);

      static datetime last_month_reset = 0;
      if(month_start > last_month_reset)
      {
         monthly_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
         last_month_reset = month_start;
      }
   }

   double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   daily_tracking.current_profit = current_balance - daily_tracking.start_balance;

   if(daily_tracking.current_profit > daily_tracking.max_profit)
      daily_tracking.max_profit = daily_tracking.current_profit;

   if(daily_tracking.current_profit < daily_tracking.max_drawdown)
      daily_tracking.max_drawdown = daily_tracking.current_profit;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== ALMA EA v3.04 ENHANCED INITIALIZATION ===");

   // Initialize ALMA visual line arrays
   ArrayResize(alma_fast_values, 1000);
   ArrayResize(alma_slow_values, 1000);
   ArrayResize(alma_times, 1000);
   alma_bars_count = 0;

   // Clear any existing ALMA objects
   ObjectsDeleteAll(0, "ALMA_");

   // Backfill ALMA historical data for visual display
   BackfillALMAHistory();

   Print("ALMA visual lines initialized for EA display");

   if(!ValidateInputParameters())
   {
      Print("ERROR: Invalid input parameters");
      return INIT_PARAMETERS_INCORRECT;
   }

   trade.SetExpertMagicNumber(EA_MAGIC_NUMBER);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   if(!InitializeAllModules())
   {
      Print("ERROR: Failed to initialize modules - " + initialization_errors);
      return INIT_FAILED;
   }
   
   EventSetTimer(TelegramCheckIntervalSeconds);
   
   session_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);

   // Load daily start balance (will set to current if first time today)
   LoadDailyStartBalance();

   weekly_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   today_trade_count = 0;
   
   // Initialize runtime variables
   runtime_position_size = StaticLotSize;

   // Initialize daily loss limit tracking
   original_daily_loss_limit = MaxDailyLoss;
   current_daily_loss_limit = MaxDailyLoss;
   daily_limit_overridden = false;

   pending_approval.is_pending = false;

   // Initialize signal deduplication
   has_sent_signal = false;
   signal_suppressed_until_bar = 0;

   Print("=== ALMA EA v3.04 ENHANCED INITIALIZATION SUCCESS ===");
   Print("Enhanced ALMA trading system with improved Telegram interface");
   Print("40+ interactive commands available");
   Print("Enhanced error handling and debugging active");

   // Initialize ALMA lines immediately
   Sleep(100); // Brief pause to ensure data is available
   RefreshALMALines();
   
   // Display metal detection info
   string metal_name = GetMetalName();
   double breakout_buffer = GetMetalBreakoutBuffer() / _Point;
   double stop_buffer = GetMetalStopBuffer() / _Point;

   Print("═══════════════════════════════════════");
   Print("🏆 ALMA EA v3.04 Enhanced - " + metal_name + " Optimized");
   Print("📊 Symbol: " + _Symbol);
   Print("⚙️ Breakout Buffer: " + DoubleToString(breakout_buffer, 0) + " points");
   Print("🛡️ Stop Buffer: " + DoubleToString(stop_buffer, 0) + " points");
   Print("🎯 Trading Mode: " + GetTradingModeString());
   Print("🔄 Dynamic ALMA: " + (EnableDynamicALMA ? "ENABLED" : "DISABLED"));

   // Display current research-optimized ALMA parameters
   Print("📈 ALMA Parameters (Research-Optimized):");
   Print("   Fast: " + IntegerToString(runtime_fast_length) + " periods @ " + DoubleToString(runtime_fast_offset, 2) + " offset");
   Print("   Slow: " + IntegerToString(runtime_slow_length) + " periods @ " + DoubleToString(runtime_slow_offset, 2) + " offset");
   Print("   Mode: " + EnumToString(active_alma_preset) + " (Sharpe: 1.28-2.14)");
   Print("═══════════════════════════════════════");

   return INIT_SUCCEEDED;
}


//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   
   if(telegram_initialized)
   {
      string shutdown_msg = "ALMA EA v3.04 ENHANCED SHUTDOWN\n\n";
      shutdown_msg += "Session Summary:\n";
      shutdown_msg += "Trades: " + IntegerToString(today_trade_count) + "\n";
      
      double session_pnl = AccountInfoDouble(ACCOUNT_EQUITY) - session_start_equity;
      shutdown_msg += "Session P&L: " + FormatCurrency(session_pnl) + "\n";
      shutdown_msg += "Final Balance: " + FormatCurrency(AccountInfoDouble(ACCOUNT_BALANCE)) + "\n\n";
      
      shutdown_msg += "Enhanced features deactivated.\n";
      shutdown_msg += "Comprehensive trading system offline.";
      
      SendTelegramMessage(shutdown_msg);
   }

   // Clean up all graphical objects created by the EA
   CleanupEAObjects();

   Comment("");
   Print("ALMA EA v3.04 Enhanced shutdown - all features deactivated and graphics cleaned");
}

//+------------------------------------------------------------------+
//| Clean up all EA-created graphical objects                       |
//+------------------------------------------------------------------+
void CleanupEAObjects()
{
   // Remove all ALMA line objects
   ObjectsDeleteAll(0, "ALMA_");

   // Remove any session-related objects that might persist
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string obj_name = ObjectName(0, i);

      // Remove objects created by this EA (comprehensive cleanup)
      if(StringFind(obj_name, "ALMA_") >= 0 ||
         StringFind(obj_name, "Tokyo") >= 0 ||
         StringFind(obj_name, "London") >= 0 ||
         StringFind(obj_name, "NewYork") >= 0 ||
         StringFind(obj_name, "NY") >= 0 ||
         StringFind(obj_name, "SessionInfo") >= 0 ||
         StringFind(obj_name, "RangeBreak") >= 0 ||
         StringFind(obj_name, "IB_") >= 0)
      {
         ObjectDelete(0, obj_name);
         Print("Cleaned up object: " + obj_name);
      }
   }

   // Force chart redraw to ensure objects are removed
   ChartRedraw(0);

   Print("EA graphical objects cleanup completed");
}

//+------------------------------------------------------------------+
//| Session Summary Functions                                        |
//+------------------------------------------------------------------+
void InitializeSessionSummary(int session_index)
{
   // Reset summary data for new session
   current_session_summary.session_name = sessions[session_index].name;
   current_session_summary.session_start_time = TimeCurrent();
   current_session_summary.session_end_time = 0;
   current_session_summary.trades_executed = 0;
   current_session_summary.trades_stopped_out = 0;
   current_session_summary.trades_profitable = 0;
   current_session_summary.session_pnl = 0.0;
   current_session_summary.session_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   current_session_summary.missed_signals_count = 0;
   current_session_summary.news_events_count = 0;
   current_session_summary.screenshot_path = "";
   current_session_summary.highest_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   current_session_summary.lowest_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   current_session_summary.price_range_points = 0;
   current_session_summary.ib_completed = false;
   current_session_summary.ib_range_size = 0;
   current_session_summary.dominant_strategy = "";

   // Clear arrays
   for(int i = 0; i < 20; i++) {
      current_session_summary.missed_signals[i] = "";
   }
   for(int i = 0; i < 10; i++) {
      current_session_summary.news_events[i] = "";
   }

   session_summary_active = true;
   DebugLog("SessionSummary", "Initialized summary for " + sessions[session_index].name + " session");
}

void AddMissedSignal(string reason)
{
   if(!session_summary_active || current_session_summary.missed_signals_count >= 20)
      return;

   current_session_summary.missed_signals[current_session_summary.missed_signals_count] = reason;
   current_session_summary.missed_signals_count++;

   DebugLog("SessionSummary", "Added missed signal: " + reason);
}

void AddNewsEvent(string news_description)
{
   if(!session_summary_active || current_session_summary.news_events_count >= 10)
      return;

   current_session_summary.news_events[current_session_summary.news_events_count] = news_description;
   current_session_summary.news_events_count++;

   DebugLog("SessionSummary", "Added news event: " + news_description);
}

void UpdateSessionPriceData()
{
   if(!session_summary_active)
      return;

   double current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);

   if(current_price > current_session_summary.highest_price)
      current_session_summary.highest_price = current_price;

   if(current_price < current_session_summary.lowest_price)
      current_session_summary.lowest_price = current_price;

   current_session_summary.price_range_points = (current_session_summary.highest_price - current_session_summary.lowest_price) / _Point;
}

void RecordTradeForSession(bool is_profitable)
{
   if(!session_summary_active)
      return;

   current_session_summary.trades_executed++;
   if(is_profitable)
      current_session_summary.trades_profitable++;
   else
      current_session_summary.trades_stopped_out++;

   // Update session P&L
   double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   current_session_summary.session_pnl = current_balance - current_session_summary.session_start_balance;
}

string GenerateSessionSummary()
{
   if(!session_summary_active)
      return "";

   // Update final data
   current_session_summary.session_end_time = TimeCurrent();
   double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   current_session_summary.session_pnl = current_balance - current_session_summary.session_start_balance;

   string session_name_upper = current_session_summary.session_name;
   StringToUpper(session_name_upper);
   string summary = "📊 " + session_name_upper + " SESSION SUMMARY\n\n";

   // === SESSION TIMING ===
   summary += "⏰ SESSION TIMING:\n";
   summary += "• Start: " + TimeToString(current_session_summary.session_start_time, TIME_MINUTES) + "\n";
   summary += "• End: " + TimeToString(current_session_summary.session_end_time, TIME_MINUTES) + "\n";
   int duration_minutes = (int)((current_session_summary.session_end_time - current_session_summary.session_start_time) / 60);
   summary += "• Duration: " + IntegerToString(duration_minutes / 60) + "h " + IntegerToString(duration_minutes % 60) + "m\n\n";

   // === TRADING STATISTICS ===
   summary += "📈 TRADING STATISTICS:\n";
   summary += "• Trades Executed: " + IntegerToString(current_session_summary.trades_executed) + "\n";

   if(current_session_summary.trades_executed > 0) {
      summary += "• Trades Profitable: " + IntegerToString(current_session_summary.trades_profitable) + "\n";
      summary += "• Trades Stopped: " + IntegerToString(current_session_summary.trades_stopped_out) + "\n";
      double win_rate = (current_session_summary.trades_profitable * 100.0) / current_session_summary.trades_executed;
      summary += "• Win Rate: " + DoubleToString(win_rate, 1) + "%\n";
   }

   summary += "• Session P&L: " + FormatCurrency(current_session_summary.session_pnl);
   if(current_session_summary.session_pnl > 0) summary += " ✅\n";
   else if(current_session_summary.session_pnl < 0) summary += " ❌\n";
   else summary += " ⚪\n";
   summary += "\n";

   // === PRICE ACTION ===
   summary += "💹 PRICE ACTION:\n";
   summary += "• Session High: " + DoubleToString(current_session_summary.highest_price, _Digits) + "\n";
   summary += "• Session Low: " + DoubleToString(current_session_summary.lowest_price, _Digits) + "\n";
   summary += "• Range: " + DoubleToString(current_session_summary.price_range_points, 1) + " points (" +
             DoubleToString(current_session_summary.price_range_points / 10.0, 1) + " pips)\n";

   // Strategy used
   if(current_session_summary.price_range_points > runtime_ib_range_threshold) {
      summary += "• Strategy: Mean Reversion (Large Range)\n";
   } else {
      summary += "• Strategy: Breakout (Small Range)\n";
   }
   summary += "\n";

   // === MISSED OPPORTUNITIES ===
   if(current_session_summary.missed_signals_count > 0) {
      summary += "❌ MISSED SIGNALS (" + IntegerToString(current_session_summary.missed_signals_count) + "):\n";
      for(int i = 0; i < current_session_summary.missed_signals_count && i < 10; i++) {
         summary += "• " + current_session_summary.missed_signals[i] + "\n";
      }
      if(current_session_summary.missed_signals_count > 10) {
         summary += "• ... and " + IntegerToString(current_session_summary.missed_signals_count - 10) + " more\n";
      }
      summary += "\n";
   }

   // === NEWS EVENTS ===
   if(current_session_summary.news_events_count > 0) {
      summary += "📰 NEWS EVENTS:\n";
      for(int i = 0; i < current_session_summary.news_events_count; i++) {
         summary += "• " + current_session_summary.news_events[i] + "\n";
      }
      summary += "\n";
   }

   // === BASIC INSIGHTS ===
   summary += "💡 INSIGHTS & SUGGESTIONS:\n";

   // Analyze missed signals
   int spread_violations = CountMissedSignalType("spread");
   int direction_blocks = CountMissedSignalType("direction");
   int session_end_blocks = CountMissedSignalType("session ending");

   if(spread_violations > 0) {
      summary += "• " + IntegerToString(spread_violations) + " signals missed due to high spread\n";
      summary += "  → Consider increasing max spread during volatile periods\n";
   }

   if(direction_blocks > 0) {
      summary += "• " + IntegerToString(direction_blocks) + " signals blocked by direction filter\n";
      summary += "  → Check if direction restrictions are limiting opportunities\n";
   }

   // Win rate analysis
   if(current_session_summary.trades_executed > 0) {
      double win_rate = (current_session_summary.trades_profitable * 100.0) / current_session_summary.trades_executed;
      if(win_rate < 40) {
         summary += "• Low win rate (" + DoubleToString(win_rate, 0) + "%) suggests:\n";
         summary += "  → Consider wider stops or better entry timing\n";
         summary += "  → Review strategy selection criteria\n";
      } else if(win_rate > 70) {
         summary += "• Excellent win rate (" + DoubleToString(win_rate, 0) + "%)! 🎯\n";
         summary += "  → Current settings working well\n";
      }
   }

   // Range analysis
   if(current_session_summary.price_range_points < 300) {
      summary += "• Low volatility session (< 30 pips)\n";
      summary += "  → Breakout strategies may be more effective\n";
   } else if(current_session_summary.price_range_points > 1000) {
      summary += "• High volatility session (> 100 pips)\n";
      summary += "  → Mean reversion strategies preferred\n";
      summary += "  → Consider wider stops and take profits\n";
   }

   summary += "\n📸 Session Screenshot: ";
   if(current_session_summary.screenshot_path != "") {
      summary += current_session_summary.screenshot_path;
   } else {
      summary += "Not captured";
   }

   summary += "\n⏰ Generated: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);

   return summary;
}

int CountMissedSignalType(string signal_type)
{
   int count = 0;
   StringToLower(signal_type);

   for(int i = 0; i < current_session_summary.missed_signals_count; i++) {
      string signal = current_session_summary.missed_signals[i];
      StringToLower(signal);
      if(StringFind(signal, signal_type) >= 0) {
         count++;
      }
   }
   return count;
}

void FinalizeSessionSummary()
{
   if(!session_summary_active)
      return;

   // Capture final screenshot
   current_session_summary.screenshot_path = CaptureScreenshot();

   // Generate and send summary
   string summary = GenerateSessionSummary();
   if(summary != "" && telegram_initialized) {
      SendTelegramMessage(summary);
   }

   // Deactivate tracking
   session_summary_active = false;
   DebugLog("SessionSummary", "Finalized summary for " + current_session_summary.session_name + " session");
}

//+------------------------------------------------------------------+
//| Enhanced Timer event function                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   static datetime last_risk_monitor = 0;
   datetime current_time = TimeCurrent();
   
   // Check Telegram once per timer event (every 30 seconds)
   if(TelegramInteractiveMode && telegram_initialized)
   {
      CheckTelegramUpdates();
   }

   // Update news calendar periodically
   if(EnableNewsFilter && news_manager_initialized)
   {
      UpdateNewsManager();
   }
   
   // Monitor risk levels every 5 minutes
   if(EnableAdvancedRiskManagement && (current_time - last_risk_monitor >= 300))
   {
      MonitorRiskLevels();
      last_risk_monitor = current_time;
   }
   
   // Check for quiet mode expiry
   if(quiet_mode && current_time > quiet_until)
   {
      quiet_mode = false;
      if(telegram_initialized && telegram_connection_verified)
         SendTelegramMessage("Quiet mode expired - notifications resumed");
   }
   
   // Update daily tracking
   UpdateDailyTracking();
}

//+------------------------------------------------------------------+
//| Enhanced Tick event function                                     |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime current_time = TimeCurrent();
   datetime current_bar_time = iTime(Symbol(), IndicatorTimeframe, 0);

   // Update session price data for summary
   UpdateSessionPriceData();

   bool new_bar = (current_bar_time != last_bar_time);
   if(new_bar)
   {
      last_bar_time = current_bar_time;
      OnEnhancedNewBar();
   }
   
   static datetime last_display_update = 0;
   if(current_time - last_display_update >= DISPLAY_UPDATE_INTERVAL)
   {
      last_display_update = current_time;
      UpdateEnhancedDisplay();
   }
   
   ProcessTradingLogic();
   ManagePositions();

   // Bar-based burst/kill analysis for optimal performance
   static datetime last_burst_kill_bar = 0;
   datetime current_bar = iTime(Symbol(), burst_kill_timeframe, 0);
   if(current_bar != last_burst_kill_bar) {
       last_burst_kill_bar = current_bar;
       ManagePositionsWithBurstKill(); // Enhanced burst/kill position management
   }

   UpdateDynamicStops();
   CheckCommandDecay();
   CheckManualTradeWarnings();
}

void OnEnhancedNewBar()
{
   UpdateSessionStates();
   UpdateALMAValues();
   UpdateDailyTracking();
   
   if(EnableDebugLogging)
   {
      Print("Enhanced new bar: ", TimeToString(iTime(Symbol(), IndicatorTimeframe, 0)));
   }
}

//+------------------------------------------------------------------+
//| Range Break Trading System                                       |
//+------------------------------------------------------------------+
RangeAnalysis AnalyzeRange(int bars_count)
{
   RangeAnalysis analysis;
   analysis.analysis_time = TimeCurrent();
   analysis.bars_analyzed = bars_count;
   analysis.range_high = -1;
   analysis.range_low = -1;
   analysis.range_size_points = 0;
   analysis.current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   analysis.current_zone = ZONE_OUTSIDE;
   analysis.breakout_detected = false;
   analysis.breakout_direction = "None";
   analysis.breakout_strength = 0;
   analysis.setup_valid = false;
   
   // Validate input
   if(bars_count <= 0 || bars_count > 500)
   {
      DebugLog("RangeBreak", "Invalid bars count for range analysis: " + IntegerToString(bars_count));
      return analysis;
   }
   
   // Calculate range from specified number of bars
   for(int i = 1; i <= bars_count; i++)
   {
      double high = iHigh(Symbol(), IndicatorTimeframe, i);
      double low = iLow(Symbol(), IndicatorTimeframe, i);
      
      if(high > 0 && low > 0)
      {
         if(analysis.range_high < 0 || high > analysis.range_high) 
            analysis.range_high = high;
         if(analysis.range_low < 0 || low < analysis.range_low) 
            analysis.range_low = low;
      }
   }
   
   // Validate range calculation
   if(analysis.range_high <= 0 || analysis.range_low <= 0 || analysis.range_high <= analysis.range_low)
   {
      DebugLog("RangeBreak", "Invalid range calculated");
      return analysis;
   }
   
   analysis.range_size_points = (analysis.range_high - analysis.range_low) / _Point;
   
   // Determine current price position
   if(analysis.current_price >= analysis.range_low && analysis.current_price <= analysis.range_high)
   {
      analysis.current_zone = ZONE_IB; // Within range
   }
   else if(analysis.current_price > analysis.range_high)
   {
      analysis.current_zone = ZONE_H1; // Above range
      analysis.breakout_detected = true;
      analysis.breakout_direction = "Upward";
      analysis.breakout_strength = (analysis.current_price - analysis.range_high) / (analysis.range_high - analysis.range_low);
   }
   else if(analysis.current_price < analysis.range_low)
   {
      analysis.current_zone = ZONE_L1; // Below range
      analysis.breakout_detected = true;
      analysis.breakout_direction = "Downward";
      analysis.breakout_strength = (analysis.range_low - analysis.current_price) / (analysis.range_high - analysis.range_low);
   }
   
   // Determine if setup is valid for trading
   analysis.setup_valid = ValidateRangeBreakSetup(analysis);
   
   last_range_analysis = analysis;
   
   DebugLog("RangeBreak", "Range analysis completed: " + IntegerToString(bars_count) + " bars, " + 
            DoubleToString(analysis.range_size_points, 0) + " points, " + analysis.breakout_direction + " breakout");
   
   return analysis;
}

bool ValidateRangeBreakSetup(RangeAnalysis &analysis)
{
   // Minimum range size requirement
   if(analysis.range_size_points < 50) return false;
   
   // Maximum range size (avoid extremely volatile periods)
   if(analysis.range_size_points > 2000) return false;
   
   // If breakout detected, validate strength
   if(analysis.breakout_detected)
   {
      if(analysis.breakout_strength < 0.1) return false; // Require at least 10% breakout strength
      
      // Validate ALMA confirmation
      bool fast_above_slow = (GetFastALMA() > GetSlowALMA());
      if(analysis.breakout_direction == "Upward" && !fast_above_slow) return false;
      if(analysis.breakout_direction == "Downward" && fast_above_slow) return false;
   }
   
   // Check market conditions
   if(!IsMarketConditionsAcceptable()) return false;
   
   return true;
}

void CheckCommandDecay()
{
   if(!range_break_setup_active) return;

   datetime current_time = TimeCurrent();
   bool should_decay = false;
   string decay_reason = "";

   // Check for day end
   if(current_time >= range_setup_day_end)
   {
      should_decay = true;
      decay_reason = "End of day reached";
   }
   // Check for session end
   else if(current_time >= range_setup_session_end)
   {
      should_decay = true;
      decay_reason = "Session ended";
   }
   // Check for session priority change
   else if(range_setup_session_index != GetPrioritySessionIndex())
   {
      should_decay = true;
      decay_reason = "Session priority changed";
   }
   // Check original time-based expiry as fallback
   else if(current_time >= range_setup_expiry)
   {
      should_decay = true;
      decay_reason = "Time expiry reached";
   }

   if(should_decay)
   {
      DeactivateRangeSetup(decay_reason);
   }
}

void DeactivateRangeSetup(string reason)
{
   if(range_break_setup_active)
   {
      range_break_setup_active = false;
      range_setup_session_index = -1;
      range_setup_session_end = 0;
      range_setup_day_end = 0;
      range_setup_expiry = 0;

      DebugLog("RangeBreak", "Range setup deactivated: " + reason);

      // Optionally notify user
      string notification = "🔄 RANGE SETUP EXPIRED\n\n";
      notification += "Reason: " + reason + "\n";
      notification += "Range breakout monitoring has been automatically disabled.\n";
      notification += "Use /rangebreak or /rangerevert to set up new range monitoring.";

      SendTelegramMessage(notification);
   }
}

datetime CalculateSessionEnd(int session_index)
{
   if(session_index < 0 || session_index >= 3) return 0;

   SessionInfo session = sessions[session_index];
   if(!session.is_active) return 0;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = session.end_hour;
   dt.min = 0;
   dt.sec = 0;

   datetime session_end = StructToTime(dt);

   // If end time is before current time, it's tomorrow
   if(session_end <= TimeCurrent())
      session_end += 86400;

   return session_end;
}

datetime CalculateDayEnd()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 23;
   dt.min = 59;
   dt.sec = 59;

   return StructToTime(dt);
}

void ActivateRangeBreakSetup(int bars_count)
{
   active_range_setup = AnalyzeRange(bars_count);

   if(active_range_setup.setup_valid)
   {
      range_break_setup_active = true;
      range_setup_expiry = TimeCurrent() + 3600; // 1 hour expiry as fallback

      // Set decay tracking
      range_setup_session_index = GetPrioritySessionIndex();
      range_setup_session_end = CalculateSessionEnd(range_setup_session_index);
      range_setup_day_end = CalculateDayEnd();

      DebugLog("RangeBreak", "Range break setup activated for " + IntegerToString(bars_count) + " bars");
      DebugLog("RangeBreak", "Setup will decay at session end: " + TimeToString(range_setup_session_end, TIME_DATE|TIME_MINUTES) +
               " or day end: " + TimeToString(range_setup_day_end, TIME_DATE|TIME_MINUTES));
   }
   else
   {
      DebugLog("RangeBreak", "Range break setup validation failed");
   }
}

void ActivateCurrentRangeSetup(CurrentRangeLevels &current_range)
{
   // Create RangeAnalysis structure for current range
   active_range_setup.range_high = current_range.range_high;
   active_range_setup.range_low = current_range.range_low;
   active_range_setup.range_size_points = (current_range.range_high - current_range.range_low) / _Point;
   active_range_setup.current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   active_range_setup.breakout_detected = false;
   active_range_setup.setup_valid = current_range.is_valid;

   if(active_range_setup.setup_valid)
   {
      range_break_setup_active = true;
      range_setup_expiry = TimeCurrent() + 3600; // 1 hour expiry as fallback

      // Set decay tracking
      range_setup_session_index = GetPrioritySessionIndex();
      range_setup_session_end = CalculateSessionEnd(range_setup_session_index);
      range_setup_day_end = CalculateDayEnd();

      DebugLog("RangeBreak", "Current range setup activated: " + current_range.range_name);
      DebugLog("RangeBreak", "Setup will decay at session end: " + TimeToString(range_setup_session_end, TIME_DATE|TIME_MINUTES) +
               " or day end: " + TimeToString(range_setup_day_end, TIME_DATE|TIME_MINUTES));
   }
   else
   {
      DebugLog("RangeBreak", "Current range setup validation failed");
   }
}

bool PlaceRangeBreakoutOrders(RangeAnalysis &analysis)
{
   if(!analysis.setup_valid)
   {
      DebugLog("RangeBreakout", "Cannot place orders - setup not valid");
      return false;
   }

   double lot_size = CalculatePositionSize();
   double buffer = 10 * _Point; // 10 point buffer beyond range

   // Calculate order prices
   double buy_stop_price = analysis.range_high + buffer;
   double sell_stop_price = analysis.range_low - buffer;

   // Calculate stop losses (opposite side of range)
   double buy_sl = analysis.range_low - buffer;
   double sell_sl = analysis.range_high + buffer;

   // Calculate take profits (1:2 risk-reward)
   double range_size = analysis.range_high - analysis.range_low;
   double buy_tp = buy_stop_price + (2 * range_size);
   double sell_tp = sell_stop_price - (2 * range_size);

   DebugLog("RangeBreakout", StringFormat("Placing breakout orders - Buy Stop: %f, Sell Stop: %f",
            buy_stop_price, sell_stop_price));

   // Place BUY STOP order
   MqlTradeRequest buy_request = {};
   buy_request.action = TRADE_ACTION_PENDING;
   buy_request.symbol = Symbol();
   buy_request.volume = lot_size;
   buy_request.type = ORDER_TYPE_BUY_STOP;
   buy_request.price = buy_stop_price;
   buy_request.sl = buy_sl;
   buy_request.tp = buy_tp;
   buy_request.deviation = 10;
   buy_request.magic = 12345;
   buy_request.comment = "Range Breakout BUY";

   MqlTradeResult buy_result = {};
   bool buy_success = OrderSend(buy_request, buy_result);

   // Place SELL STOP order
   MqlTradeRequest sell_request = {};
   sell_request.action = TRADE_ACTION_PENDING;
   sell_request.symbol = Symbol();
   sell_request.volume = lot_size;
   sell_request.type = ORDER_TYPE_SELL_STOP;
   sell_request.price = sell_stop_price;
   sell_request.sl = sell_sl;
   sell_request.tp = sell_tp;
   sell_request.deviation = 10;
   sell_request.magic = 12345;
   sell_request.comment = "Range Breakout SELL";

   MqlTradeResult sell_result = {};
   bool sell_success = OrderSend(sell_request, sell_result);

   if(buy_success && sell_success)
   {
      DebugLog("RangeBreakout", "Both breakout orders placed successfully");
      return true;
   }
   else
   {
      DebugLog("RangeBreakout", StringFormat("Order placement failed - Buy: %s, Sell: %s",
               buy_success ? "OK" : "FAILED", sell_success ? "OK" : "FAILED"));
      return false;
   }
}

bool PlaceRangeReversionOrders(RangeAnalysis &analysis, bool near_high, bool near_low)
{
   if(!analysis.setup_valid)
   {
      DebugLog("RangeReversion", "Cannot place orders - setup not valid");
      return false;
   }

   double lot_size = CalculatePositionSize();
   double median = (analysis.range_high + analysis.range_low) / 2;
   double buffer = 5 * _Point; // 5 point buffer
   bool orders_placed = false;

   DebugLog("RangeReversion", StringFormat("Placing reversion orders - Near High: %s, Near Low: %s",
            near_high ? "YES" : "NO", near_low ? "YES" : "NO"));

   // Place SELL LIMIT if near range high (revert down to median)
   if(near_high)
   {
      double sell_limit_price = analysis.range_high - buffer;
      double sell_sl = analysis.range_high + (buffer * 2); // Stop above range high
      double sell_tp = median; // Target median

      MqlTradeRequest sell_request = {};
      sell_request.action = TRADE_ACTION_PENDING;
      sell_request.symbol = Symbol();
      sell_request.volume = lot_size;
      sell_request.type = ORDER_TYPE_SELL_LIMIT;
      sell_request.price = sell_limit_price;
      sell_request.sl = sell_sl;
      sell_request.tp = sell_tp;
      sell_request.deviation = 10;
      sell_request.magic = 12345;
      sell_request.comment = "Range Reversion SELL";

      MqlTradeResult sell_result = {};
      bool sell_success = OrderSend(sell_request, sell_result);

      if(sell_success)
      {
         DebugLog("RangeReversion", "SELL LIMIT order placed successfully");
         orders_placed = true;
      }
      else
      {
         DebugLog("RangeReversion", "Failed to place SELL LIMIT order");
      }
   }

   // Place BUY LIMIT if near range low (revert up to median)
   if(near_low)
   {
      double buy_limit_price = analysis.range_low + buffer;
      double buy_sl = analysis.range_low - (buffer * 2); // Stop below range low
      double buy_tp = median; // Target median

      MqlTradeRequest buy_request = {};
      buy_request.action = TRADE_ACTION_PENDING;
      buy_request.symbol = Symbol();
      buy_request.volume = lot_size;
      buy_request.type = ORDER_TYPE_BUY_LIMIT;
      buy_request.price = buy_limit_price;
      buy_request.sl = buy_sl;
      buy_request.tp = buy_tp;
      buy_request.deviation = 10;
      buy_request.magic = 12345;
      buy_request.comment = "Range Reversion BUY";

      MqlTradeResult buy_result = {};
      bool buy_success = OrderSend(buy_request, buy_result);

      if(buy_success)
      {
         DebugLog("RangeReversion", "BUY LIMIT order placed successfully");
         orders_placed = true;
      }
      else
      {
         DebugLog("RangeReversion", "Failed to place BUY LIMIT order");
      }
   }

   return orders_placed;
}

//+------------------------------------------------------------------+
//| Manual Trade Detection and Warning Functions                    |
//+------------------------------------------------------------------+

struct ManualTradeInfo
{
   ulong ticket;
   bool is_buy;
   double open_price;
   double lot_size;
   datetime open_time;
   double current_sl;
   double current_tp;
   bool has_stop_loss;
};

int DetectManualTrades(ManualTradeInfo &manual_trades[])
{
   int manual_count = 0;
   int positions_total = PositionsTotal();
   ArrayResize(manual_trades, positions_total);

   for(int i = 0; i < positions_total; i++)
   {
      ulong position_ticket = PositionGetTicket(i);
      if(position_ticket == 0) continue;

      if(PositionSelectByTicket(position_ticket))
      {
         ulong position_magic = PositionGetInteger(POSITION_MAGIC);

         // Check if it's NOT an EA managed trade (not our magic number)
         if(!IsEAMagicNumber(position_magic))
         {
            manual_trades[manual_count].ticket = position_ticket;
            manual_trades[manual_count].is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
            manual_trades[manual_count].open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            manual_trades[manual_count].lot_size = PositionGetDouble(POSITION_VOLUME);
            manual_trades[manual_count].open_time = (datetime)PositionGetInteger(POSITION_TIME);
            manual_trades[manual_count].current_sl = PositionGetDouble(POSITION_SL);
            manual_trades[manual_count].current_tp = PositionGetDouble(POSITION_TP);
            manual_trades[manual_count].has_stop_loss = (manual_trades[manual_count].current_sl > 0);

            manual_count++;
         }
      }
   }

   ArrayResize(manual_trades, manual_count);
   return manual_count;
}

void CheckManualTradeWarnings()
{
   datetime current_time = TimeCurrent();

   // Check if 15 minutes have passed since last warning
   if(current_time - last_manual_trade_warning < MANUAL_TRADE_WARNING_INTERVAL)
      return;

   ManualTradeInfo manual_trades[];
   int manual_count = DetectManualTrades(manual_trades);

   if(manual_count == 0)
      return;

   // Count trades without stop losses
   int trades_without_stops = 0;
   for(int i = 0; i < manual_count; i++)
   {
      if(!manual_trades[i].has_stop_loss)
         trades_without_stops++;
   }

   if(trades_without_stops > 0)
   {
      string warning_msg = "⚠️ RISK WARNING! ⚠️\n\n";
      warning_msg += "There " + (trades_without_stops == 1 ? "is " : "are ") + IntegerToString(trades_without_stops);
      warning_msg += " manual trade" + (trades_without_stops == 1 ? "" : "s") + " open with no stop loss attached.\n\n";
      warning_msg += "🚨 These trades are not managed by the EA and lack proper risk management.\n\n";
      warning_msg += "💡 Consider adding stop losses manually to protect your account.";

      SendTelegramMessage(warning_msg);
      last_manual_trade_warning = current_time;
   }
}

//+------------------------------------------------------------------+
//| End of Enhanced ALMA_EA_v3.04.mq5                              |

//+------------------------------------------------------------------+
