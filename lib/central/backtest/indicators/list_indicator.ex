defmodule Central.Backtest.Indicators.ListIndicator do
  @moduledoc """
  Provides functions for accessing metadata about available indicators.

  This module contains the comprehensive list of trading indicators with their
  metadata including names, types, default periods, descriptions and parameter specifications.
  """

  # Instead of using module attributes, we'll use memoized functions
  # This avoids compile-time dependencies and issues

  @doc """
  Returns a list of all available indicators with metadata.
  """
  def list_indicators do
    # Using Process.get/put for simple memoization
    case Process.get(:indicators_cache) do
      nil ->
        indicators = init_indicators()
        Process.put(:indicators_cache, indicators)
        indicators
      indicators ->
        indicators
    end
  end

  @doc """
  Returns a specific indicator by ID with O(1) lookup.
  """
  def get_indicator(id) when is_atom(id) do
    Map.get(indicators_map(), id)
  end

  def get_indicator(id) when is_binary(id) do
    # Try to standardize the ID for consistent lookup
    standardized_id = standardize_string_indicator_id(id)
    Map.get(indicators_map(), standardized_id) ||
      (try do
        atom_id = String.to_existing_atom(standardized_id)
        Map.get(indicators_map(), atom_id)
      rescue
        _ -> nil
      end)
  end

  def get_indicator(_), do: nil

  @doc """
  Returns indicators grouped by type.
  """
  def group_indicators_by_type do
    # Using Process.get/put for simple memoization
    case Process.get(:grouped_indicators_cache) do
      nil ->
        grouped = Enum.group_by(list_indicators(), & &1.type)
        Process.put(:grouped_indicators_cache, grouped)
        grouped
      grouped ->
        grouped
    end
  end

  @doc """
  Returns parameter specifications for indicators with optimized lookup.
  """
  def get_params(indicator_id) when is_binary(indicator_id) do
    case indicator_id do
      "" -> []
      id ->
        case get_indicator(id) do
          nil -> []
          indicator -> indicator.params || []
        end
    end
  end

  def get_params(indicator_id) when is_atom(indicator_id) do
    case get_indicator(indicator_id) do
      nil -> []
      indicator -> indicator.params || []
    end
  end

  def get_params(_), do: []

  @doc """
  Returns all available indicators.
  Alias for list_indicators/0 for backward compatibility.
  """
  def all, do: list_indicators()

  # Private helper functions

  # Returns a memoized map of indicators
  defp indicators_map do
    # Using Process.get/put for simple memoization
    case Process.get(:indicators_map_cache) do
      nil ->
        map = build_indicators_map(list_indicators())
        Process.put(:indicators_map_cache, map)
        map
      map ->
        map
    end
  end

  # Standardize string indicator IDs to ensure format consistency
  defp standardize_string_indicator_id(id) do
    # Replace spaces and dashes with underscores, downcase everything
    id
    |> String.downcase()
    |> String.replace(~r/[\s-]+/, "_")
  end

  # Build a map of indicators by ID for fast O(1) lookup
  defp build_indicators_map(indicators) do
    # Build a map with both atom keys and string keys for more flexible lookups
    Enum.reduce(indicators, %{}, fn indicator, acc ->
      id_atom = indicator.id
      id_string = to_string(id_atom)

      acc
      |> Map.put(id_atom, indicator)
      |> Map.put(id_string, indicator)
      |> Map.put(standardize_string_indicator_id(id_string), indicator)
    end)
  end

  # Define the indicators list
  defp init_indicators do
    [
      # Trend Indicators
      %{
        id: :sma,
        name: "Simple Moving Average",
        type: :trend,
        default_period: 20,
        description: "Average price over a specified period.",
        params: [
          %{name: "period", type: :number, default: 20,
            label: "Period", min: 1, max: 200},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :ema,
        name: "Exponential Moving Average",
        type: :trend,
        default_period: 20,
        description: "Weighted average that gives more importance to recent prices.",
        params: [
          %{name: "period", type: :number, default: 20,
            label: "Period", min: 1, max: 200},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :wma,
        name: "Weighted Moving Average",
        type: :trend,
        default_period: 20,
        description: "Weighted average that gives more importance to recent prices using linear weighting.",
        params: [
          %{name: "period", type: :number, default: 20,
            label: "Period", min: 1, max: 200},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :hma,
        name: "Hull Moving Average",
        type: :trend,
        default_period: 20,
        description: "Moving average that reduces lag and improves smoothness.",
        params: [
          %{name: "period", type: :number, default: 20,
            label: "Period", min: 1, max: 200},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :vwma,
        name: "Volume Weighted Moving Average",
        type: :trend,
        default_period: 20,
        description: "Moving average that incorporates volume data.",
        params: [
          %{name: "period", type: :number, default: 20,
            label: "Period", min: 1, max: 200},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :macd,
        name: "Moving Average Convergence Divergence",
        type: :trend,
        default_period: [12, 26, 9],
        description: "Trend-following momentum indicator using moving average relationships.",
        params: [
          %{name: "fast_period", type: :number, default: 12,
            label: "Fast Period", min: 1, max: 100},
          %{name: "slow_period", type: :number, default: 26,
            label: "Slow Period", min: 2, max: 200},
          %{name: "signal_period", type: :number, default: 9,
            label: "Signal Period", min: 1, max: 50},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :ichimoku,
        name: "Ichimoku Cloud",
        type: :trend,
        default_period: [9, 26, 52],
        description: "Multiple component indicator that identifies support/resistance, momentum, and trend direction.",
        params: [
          %{name: "tenkan_period", type: :number, default: 9,
            label: "Tenkan Period", min: 1, max: 100},
          %{name: "kijun_period", type: :number, default: 26,
            label: "Kijun Period", min: 1, max: 200},
          %{name: "senkou_b_period", type: :number, default: 52,
            label: "Senkou B Period", min: 1, max: 300},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :parabolic_sar,
        name: "Parabolic SAR",
        type: :trend,
        default_period: nil,
        description: "Stop and Reverse indicator used to determine trend direction and potential reversal points.",
        params: [
          %{name: "initial_acceleration", type: :number, default: 0.02,
            label: "Initial Acceleration", step: 0.01, min: 0.01, max: 0.5},
          %{name: "acceleration_increment", type: :number, default: 0.02,
            label: "Acceleration Increment", step: 0.01, min: 0.01, max: 0.5},
          %{name: "max_acceleration", type: :number, default: 0.2,
            label: "Maximum Acceleration", step: 0.01, min: 0.1, max: 1.0}
        ]
      },
      %{
        id: :gmma,
        name: "Guppy Multiple Moving Average",
        type: :trend,
        default_period: [[3, 5, 8, 10, 12, 15], [30, 35, 40, 45, 50, 60]],
        description: "Set of multiple EMAs that help identify trend changes and strength.",
        params: [
          %{name: "short_periods", type: :text,
            default: "3, 5, 8, 10, 12, 15",
            label: "Short EMAs (comma-separated)"},
          %{name: "long_periods", type: :text,
            default: "30, 35, 40, 45, 50, 60",
            label: "Long EMAs (comma-separated)"},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :donchian_channel,
        name: "Donchian Channel",
        type: :trend,
        default_period: 20,
        description: "Price channel showing highest high and lowest low over a specified period.",
        params: [
          %{name: "period", type: :number, default: 20,
            label: "Period", min: 1, max: 200}
        ]
      },
      %{
        id: :trix,
        name: "Triple Exponential Average",
        type: :trend,
        default_period: 15,
        description: "Momentum oscillator showing percentage rate of change of triple-smoothed moving average.",
        params: [
          %{name: "period", type: :number, default: 15,
            label: "Period", min: 1, max: 200},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :adx,
        name: "Average Directional Index",
        type: :trend,
        default_period: 14,
        description: "Trend strength indicator measuring the strength of a trend regardless of its direction.",
        params: [
          %{name: "period", type: :number, default: 14,
            label: "Period", min: 1, max: 200},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :fractals,
        name: "Fractals",
        type: :trend,
        default_period: 5,
        description: "Identifies potential reversal points by locating price patterns where high/low is surrounded by lower highs/higher lows.",
        params: [
          %{name: "period", type: :number, default: 5,
            label: "Period", min: 2, max: 20}
        ]
      },
      %{
        id: :regression_line,
        name: "Linear Regression Line",
        type: :trend,
        default_period: 20,
        description: "Statistical trend line showing best fit through price data.",
        params: [
          %{name: "period", type: :number, default: 20,
            label: "Period", min: 1, max: 200},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :regression_slope,
        name: "Linear Regression Slope",
        type: :trend,
        default_period: 20,
        description: "Rate of change of the linear regression line, indicating trend strength and direction.",
        params: [
          %{name: "period", type: :number, default: 20,
            label: "Period", min: 1, max: 200},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :regression_channel,
        name: "Linear Regression Channel",
        type: :trend,
        default_period: 20,
        description: "Channel showing standard deviations around the linear regression line.",
        params: [
          %{name: "period", type: :number, default: 20,
            label: "Period", min: 1, max: 200},
          %{name: "deviations", type: :number, default: 2.0,
            label: "Standard Deviations", step: 0.1, min: 0.1, max: 5.0},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :r_squared,
        name: "R-Squared",
        type: :trend,
        default_period: 20,
        description: "Statistical measure showing how well price movements match a linear trend.",
        params: [
          %{name: "period", type: :number, default: 20,
            label: "Period", min: 1, max: 200},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },

      # Momentum Indicators
      %{
        id: :rsi,
        name: "Relative Strength Index",
        type: :momentum,
        default_period: 14,
        description: "Momentum oscillator that measures the speed and change of price movements.",
        params: [
          %{name: "period", type: :number, default: 14,
            label: "Period", min: 1, max: 200},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :stochastic,
        name: "Stochastic Oscillator",
        type: :momentum,
        default_period: [14, 3, 1],
        description: "Momentum indicator comparing current price to its range over a period.",
        params: [
          %{name: "k_period", type: :number, default: 14,
            label: "%K Period", min: 1, max: 100},
          %{name: "d_period", type: :number, default: 3,
            label: "%D Period", min: 1, max: 50},
          %{name: "smooth_k", type: :number, default: 1,
            label: "Smooth K", min: 1, max: 10},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :roc,
        name: "Rate of Change",
        type: :momentum,
        default_period: 14,
        description: "Momentum oscillator that measures the percentage change in price over time.",
        params: [
          %{name: "period", type: :number, default: 14,
            label: "Period", min: 1, max: 200},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :rvi,
        name: "Relative Vigor Index",
        type: :momentum,
        default_period: [10, 4],
        description: "Momentum oscillator that measures the conviction of a price move based on closing price relative to opening price.",
        params: [
          %{name: "period", type: :number, default: 10,
            label: "Period", min: 1, max: 100},
          %{name: "signal_period", type: :number, default: 4,
            label: "Signal Period", min: 1, max: 50}
        ]
      },
      %{
        id: :elder_ray,
        name: "Elder-Ray Index",
        type: :momentum,
        default_period: 13,
        description: "Bull and bear power indicator measuring buying and selling pressure in the market.",
        params: [
          %{name: "period", type: :number, default: 13,
            label: "Period", min: 1, max: 100},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :tsi,
        name: "True Strength Index",
        type: :momentum,
        default_period: [25, 13, 7],
        description: "Double-smoothed momentum oscillator showing both trend direction and overbought/oversold conditions.",
        params: [
          %{name: "long_period", type: :number, default: 25,
            label: "Long Period", min: 1, max: 200},
          %{name: "short_period", type: :number, default: 13,
            label: "Short Period", min: 1, max: 100},
          %{name: "signal_period", type: :number, default: 7,
            label: "Signal Period", min: 1, max: 50},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :ultimate_oscillator,
        name: "Ultimate Oscillator",
        type: :momentum,
        default_period: [7, 14, 28],
        description: "Momentum oscillator that uses multiple timeframes to reduce false signals and provide a more balanced view.",
        params: [
          %{name: "short_period", type: :number, default: 7,
            label: "Short Period", min: 1, max: 100},
          %{name: "medium_period", type: :number, default: 14,
            label: "Medium Period", min: 1, max: 200},
          %{name: "long_period", type: :number, default: 28,
            label: "Long Period", min: 1, max: 300},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :simple_momentum,
        name: "Simple Momentum",
        type: :momentum,
        default_period: 10,
        description: "Basic momentum indicator measuring the absolute price change over a specified period.",
        params: [
          %{name: "period", type: :number, default: 10,
            label: "Period", min: 1, max: 100},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },

      # Volatility Indicators
      %{
        id: :atr,
        name: "Average True Range",
        type: :volatility,
        default_period: 14,
        description: "Volatility indicator showing the average range of price movement.",
        params: [
          %{name: "period", type: :number, default: 14,
            label: "Period", min: 1, max: 100}
        ]
      },
      %{
        id: :bollinger_bands,
        name: "Bollinger Bands",
        type: :volatility,
        default_period: 20,
        description: "Volatility bands placed above and below a moving average.",
        params: [
          %{name: "period", type: :number, default: 20,
            label: "Period", min: 1, max: 200},
          %{name: "deviations", type: :number, default: 2.0,
            label: "Standard Deviations", step: 0.1, min: 0.1, max: 5.0},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :standard_deviation,
        name: "Standard Deviation",
        type: :volatility,
        default_period: 20,
        description: "Statistical measure of market volatility showing dispersion from the mean.",
        params: [
          %{name: "period", type: :number, default: 20,
            label: "Period", min: 1, max: 200},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :chaikin_volatility,
        name: "Chaikin Volatility",
        type: :volatility,
        default_period: [10, 10],
        description: "Measures the rate of change of the trading range (high - low) to identify potential market reversals.",
        params: [
          %{name: "ema_period", type: :number, default: 10,
            label: "EMA Period", min: 1, max: 100},
          %{name: "roc_period", type: :number, default: 10,
            label: "Rate of Change Period", min: 1, max: 100}
        ]
      },
      %{
        id: :projection_bands,
        name: "Projection Bands",
        type: :volatility,
        default_period: 20,
        description: "Volatility-based bands that help identify potential price targets and reversal zones.",
        params: [
          %{name: "period", type: :number, default: 20,
            label: "Period", min: 1, max: 200},
          %{name: "factor", type: :number, default: 2.0,
            label: "Projection Factor", step: 0.1, min: 0.1, max: 5.0},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },

      # Volume Indicators
      %{
        id: :obv,
        name: "On-Balance Volume",
        type: :volume,
        default_period: nil,
        description: "Cumulative indicator that relates volume to price change.",
        params: []
      },
      %{
        id: :mfi,
        name: "Money Flow Index",
        type: :volume,
        default_period: 14,
        description: "Volume-weighted RSI that identifies overbought/oversold conditions.",
        params: [
          %{name: "period", type: :number, default: 14,
            label: "Period", min: 1, max: 100}
        ]
      },
      %{
        id: :cmf,
        name: "Chaikin Money Flow",
        type: :volume,
        default_period: 20,
        description: "Volume-weighted momentum indicator measuring the money flow into or out of a security.",
        params: [
          %{name: "period", type: :number, default: 20,
            label: "Period", min: 1, max: 100},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :vpt,
        name: "Volume Price Trend",
        type: :volume,
        default_period: nil,
        description: "Volume-based indicator that combines price and volume to confirm price trends.",
        params: [
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :eom,
        name: "Ease of Movement",
        type: :volume,
        default_period: 14,
        description: "Volume-based oscillator that relates price change to volume to show how easily a price moves.",
        params: [
          %{name: "period", type: :number, default: 14,
            label: "Period", min: 1, max: 100},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :force_index,
        name: "Force Index",
        type: :volume,
        default_period: 13,
        description: "Measures the force (or power) behind price movements by combining price change and volume.",
        params: [
          %{name: "period", type: :number, default: 13,
            label: "Period", min: 1, max: 100},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :nvi_pvi,
        name: "Negative/Positive Volume Index",
        type: :volume,
        default_period: nil,
        description: "Volume-based indicators that help identify smart money activity and market phases.",
        params: [
          %{name: "ema_period", type: :number, default: 255,
            label: "EMA Period", min: 1, max: 500},
          %{name: "price_key", type: :select, default: "close",
            options: ["open", "high", "low", "close"], label: "Price Input"}
        ]
      },
      %{
        id: :basic_volume,
        name: "Basic Volume Analysis",
        type: :volume,
        default_period: 20,
        description: "Suite of essential volume analysis tools including relative volume, volume breakouts, and volume-price confirmation.",
        params: [
          %{name: "period", type: :number, default: 20,
            label: "Period", min: 1, max: 100},
          %{name: "threshold", type: :number, default: 1.5,
            label: "Volume Threshold", step: 0.1, min: 1.0, max: 5.0}
        ]
      },

      # Level Indicators
      %{
        id: :standard_pivot_points,
        name: "Standard Pivot Points",
        type: :level,
        default_period: nil,
        description: "Support and resistance levels based on previous periods high, low, and close.",
        params: [
          %{name: "timeframe", type: :select, default: "daily",
            options: ["daily", "weekly", "monthly"],
            label: "Pivot Timeframe"}
        ]
      },
      %{
        id: :fibonacci_pivot_points,
        name: "Fibonacci Pivot Points",
        type: :level,
        default_period: nil,
        description: "Support and resistance levels using Fibonacci ratios.",
        params: [
          %{name: "timeframe", type: :select, default: "daily",
            options: ["daily", "weekly", "monthly"],
            label: "Pivot Timeframe"}
        ]
      },
      %{
        id: :camarilla_pivot_points,
        name: "Camarilla Pivot Points",
        type: :level,
        default_period: nil,
        description: "Multiple support and resistance levels using specific factors.",
        params: [
          %{name: "timeframe", type: :select, default: "daily",
            options: ["daily", "weekly", "monthly"],
            label: "Pivot Timeframe"}
        ]
      },
      %{
        id: :woodie_pivot_points,
        name: "Woodie's Pivot Points",
        type: :level,
        default_period: nil,
        description: "Support and resistance levels putting more weight on the open/close.",
        params: [
          %{name: "timeframe", type: :select, default: "daily",
            options: ["daily", "weekly", "monthly"],
            label: "Pivot Timeframe"}
        ]
      },
      %{
        id: :psych_levels,
        name: "Psychological Levels",
        type: :level,
        default_period: nil,
        description: "Price levels that have psychological significance in the market.",
        params: [
          %{name: "interval", type: :number, default: 100,
            label: "Level Interval", min: 1, max: 1000},
          %{name: "include_decimals", type: :select, default: "true",
            options: ["true", "false"], label: "Include Decimal Levels"}
        ]
      },
      %{
        id: :channels,
        name: "Price Channels",
        type: :level,
        default_period: 20,
        description: "Multiple channel types including linear regression, parallel, and envelope channels to identify price boundaries.",
        params: [
          %{name: "period", type: :number, default: 20,
            label: "Period", min: 1, max: 200},
          %{name: "channel_type", type: :select, default: "regression",
            options: ["regression", "parallel", "envelope"], label: "Channel Type"},
          %{name: "factor", type: :number, default: 2.0,
            label: "Channel Factor", step: 0.1, min: 0.1, max: 5.0}
        ]
      }
    ]
  end
end
