defmodule Central.Backtest.Indicators do
  @moduledoc """
  Public facade for accessing various trading indicators.

  This module delegates to specialized indicator modules for calculating
  different types of trading indicators including:
  - Trend indicators (moving averages, MACD, etc.)
  - Momentum indicators (RSI, stochastic, etc.)
  - Volatility indicators (Bollinger Bands, ATR, etc.)
  - Volume indicators (OBV, etc.)
  - Level indicators (pivot points, etc.)

  It provides a unified API for accessing these indicators and metadata
  about them.
  """

  require Logger
  alias Central.Backtest.Indicators.ListIndicator

  # ----------------------------------------------------------------------
  # LiveView Optimization Functions
  # ----------------------------------------------------------------------

  @doc """
  Returns a paginated list of indicators for LiveView.
  This optimized function is designed for efficient loading in LiveView
  when dealing with large datasets.

  ## Parameters
    - page: The page number to return (default: 1)
    - per_page: The number of items per page (default: 20)
    - type_filter: Optional filter for indicator type

  ## Returns
    - A map containing paginated indicators and metadata
  """
  def paginated_indicators(page \\ 1, per_page \\ 20, type_filter \\ nil) do
    indicators = ListIndicator.list_indicators()

    # Apply type filter if provided
    filtered_indicators =
      if type_filter do
        Enum.filter(indicators, fn indicator -> indicator.type == type_filter end)
      else
        indicators
      end

    # Calculate pagination
    total_count = length(filtered_indicators)
    total_pages = ceil(total_count / per_page)

    # Enforce page boundaries
    page = max(1, min(page, max(1, total_pages)))

    # Get the subset of indicators for this page
    start_index = (page - 1) * per_page
    page_indicators = Enum.slice(filtered_indicators, start_index, per_page)

    # Return formatted result with pagination metadata
    %{
      indicators: page_indicators,
      pagination: %{
        page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: total_pages
      }
    }
  end

  @doc """
  Returns a lightweight version of indicators for dropdown selectors.
  Only includes essential fields for UI rendering to reduce JSON payload size.
  """
  def indicators_for_select(grouped \\ true) do
    indicators = ListIndicator.list_indicators()

    lightweight_indicators =
      Enum.map(indicators, fn indicator ->
        %{
          id: indicator.id,
          name: indicator.name,
          type: indicator.type
        }
      end)

    if grouped do
      Enum.group_by(lightweight_indicators, fn indicator -> indicator.type end)
    else
      lightweight_indicators
    end
  end

  @doc """
  Gets detailed indicator data with parameters suitable for form generation.
  Optimized for the DynamicForm modules.
  """
  def get_indicator_for_form(indicator_id) do
    indicator = ListIndicator.get_indicator(indicator_id)

    case indicator do
      nil ->
        nil

      _ ->
        # Prepare parameters in the format expected by FormContext and FormGenerator
        params =
          Enum.map(indicator.params || [], fn param ->
            # Ensure params have consistent keys and format for the form modules
            Map.put(param, :id, param.name)
          end)

        # Return a format compatible with DynamicForm modules
        Map.put(indicator, :params, params)
    end
  end

  @doc """
  Returns default parameters for an indicator in a format compatible with DynamicForm.
  """
  def get_default_params(indicator_id) do
    params = ListIndicator.get_params(indicator_id)

    Enum.reduce(params, %{}, fn param, acc ->
      param_name = Map.get(param, :name)
      param_default = Map.get(param, :default)

      key = if is_atom(param_name), do: param_name, else: String.to_atom(param_name)
      if key, do: Map.put(acc, key, param_default), else: acc
    end)
  end

  # ------------------------------------------------------------------------------
  # Trend Indicators
  # ------------------------------------------------------------------------------

  @doc """
  Calculates Simple Moving Average (SMA).
  """
  defdelegate sma(candles, period \\ 20, price_key \\ :close),
    to: Central.Backtest.Indicators.Trend.MA

  @doc """
  Calculates Exponential Moving Average (EMA).
  """
  defdelegate ema(candles, period \\ 20, price_key \\ :close),
    to: Central.Backtest.Indicators.Trend.MA

  @doc """
  Calculates Weighted Moving Average (WMA).
  """
  defdelegate wma(candles, period \\ 20, price_key \\ :close),
    to: Central.Backtest.Indicators.Trend.MA

  @doc """
  Calculates Hull Moving Average (HMA).
  """
  defdelegate hma(candles, period \\ 20, price_key \\ :close),
    to: Central.Backtest.Indicators.Trend.MA

  @doc """
  Calculates Volume Weighted Moving Average (VWMA).
  """
  defdelegate vwma(candles, period \\ 20, price_key \\ :close),
    to: Central.Backtest.Indicators.Trend.MA

  @doc """
  Calculates Moving Average Convergence Divergence (MACD).
  """
  defdelegate macd(
                candles,
                fast_period \\ 12,
                slow_period \\ 26,
                signal_period \\ 9,
                price_key \\ :close
              ),
              to: Central.Backtest.Indicators.Trend.Macd

  @doc """
  Calculates Ichimoku Cloud.
  """
  defdelegate ichimoku(candles, tenkan_period \\ 9, kijun_period \\ 26, senkou_b_period \\ 52),
    to: Central.Backtest.Indicators.Trend.Ichimoku

  @doc """
  Calculates Parabolic SAR.
  """
  defdelegate parabolic_sar(
                candles,
                initial_acceleration \\ 0.02,
                acceleration_increment \\ 0.02,
                max_acceleration \\ 0.2
              ),
              to: Central.Backtest.Indicators.Trend.ParabolicSar

  @doc """
  Calculates Guppy Multiple Moving Average (GMMA).
  """
  defdelegate gmma(
                candles,
                short_periods \\ [3, 5, 8, 10, 12, 15],
                long_periods \\ [30, 35, 40, 45, 50, 60],
                price_key \\ :close
              ),
              to: Central.Backtest.Indicators.Trend.Gmma

  @doc """
  Analyzes GMMA for trend signals.
  """
  defdelegate analyze_gmma(gmma_result, options \\ [price_key: :close]),
    to: Central.Backtest.Indicators.Trend.Gmma,
    as: :analyze

  @doc """
  Calculates Donchian Channel.
  """
  defdelegate donchian_channel(candles, period \\ 20),
    to: Central.Backtest.Indicators.Trend.DonchianChannel

  @doc """
  Calculates Triple Exponential Average (TRIX).
  """
  defdelegate trix(candles, period \\ 15, signal_period \\ 9, price_key \\ :close),
    to: Central.Backtest.Indicators.Trend.Trix

  @doc """
  Generates trading signals based on TRIX.
  """
  defdelegate trix_signals(trix_result, zero_line_crossover \\ true),
    to: Central.Backtest.Indicators.Trend.Trix,
    as: :generate_signals

  @doc """
  Calculates Average Directional Index (ADX).
  """
  defdelegate adx(candles, period \\ 14),
    to: Central.Backtest.Indicators.Trend.Adx,
    as: :calculate

  @doc """
  Calculates Linear Regression Line.
  """
  defdelegate regression_line(candles, period \\ 20, price_key \\ :close),
    to: Central.Backtest.Indicators.Trend.LinearRegression

  @doc """
  Calculates Linear Regression Slope.
  """
  defdelegate regression_slope(candles, period \\ 20, price_key \\ :close, normalized \\ true),
    to: Central.Backtest.Indicators.Trend.LinearRegression

  @doc """
  Calculates Linear Regression Channel.
  """
  defdelegate regression_channel(candles, period \\ 20, deviations \\ 2, price_key \\ :close),
    to: Central.Backtest.Indicators.Trend.LinearRegression

  @doc """
  Calculates R-squared (coefficient of determination).
  """
  defdelegate r_squared(candles, period \\ 20, price_key \\ :close),
    to: Central.Backtest.Indicators.Trend.LinearRegression

  @doc """
  Finds potential support and resistance levels using linear regression.
  """
  defdelegate linear_regression_support_resistance(
                candles,
                threshold \\ 0.7,
                min_length \\ 5,
                lookback \\ 100
              ),
              to: Central.Backtest.Indicators.Trend.LinearRegression,
              as: :find_support_resistance

  @doc """
  Calculates Fractals indicator.
  """
  defdelegate fractals(candles, window_size \\ 5),
    to: Central.Backtest.Indicators.Trend.Fractals,
    as: :calculate

  @doc """
  Extracts price values of fractals.
  """
  defdelegate fractal_values(fractals_result, high, low),
    to: Central.Backtest.Indicators.Trend.Fractals,
    as: :extract_fractal_values

  @doc """
  Identifies trend structure based on fractal patterns.
  """
  defdelegate identify_fractal_trend(fractals_result, lookback \\ 3),
    to: Central.Backtest.Indicators.Trend.Fractals,
    as: :identify_trend

  @doc """
  Finds support and resistance levels from fractals.
  """
  defdelegate fractal_support_resistance(fractals_result, high, low, count \\ 3),
    to: Central.Backtest.Indicators.Trend.Fractals,
    as: :find_support_resistance

  # ------------------------------------------------------------------------------
  # Momentum Indicators
  # ------------------------------------------------------------------------------

  @doc """
  Calculates Relative Strength Index (RSI).
  """
  defdelegate rsi(candles, period \\ 14, price_key \\ :close),
    to: Central.Backtest.Indicators.Momentum.Rsi

  @doc """
  Calculates Stochastic Oscillator.
  """
  defdelegate stochastic(candles, k_period \\ 14, d_period \\ 3, smooth_k \\ 1),
    to: Central.Backtest.Indicators.Momentum.Stochastic

  @doc """
  Calculates Rate of Change (ROC).
  """
  defdelegate roc(candles, period \\ 14, price_key \\ :close),
    to: Central.Backtest.Indicators.Momentum.Roc

  @doc """
  Calculates Rate of Change (ROC) with timestamp.
  """
  defdelegate roc_with_timestamp(candles, period \\ 14, price_key \\ :close),
    to: Central.Backtest.Indicators.Momentum.Roc

  @doc """
  Analyzes ROC data for trading signals.
  """
  defdelegate analyze_roc(roc_data), to: Central.Backtest.Indicators.Momentum.Roc, as: :analyze

  @doc """
  Calculates Relative Vigor Index (RVI).
  """
  defdelegate rvi(candles, period \\ 10, signal_period \\ 4),
    to: Central.Backtest.Indicators.Momentum.Rvi

  @doc """
  Generates trading signals based on RVI.
  """
  defdelegate rvi_signals(rvi_data, use_histogram \\ true),
    to: Central.Backtest.Indicators.Momentum.Rvi,
    as: :generate_signals

  @doc """
  Detects divergences between price and RVI.
  """
  defdelegate rvi_divergences(candles, rvi_data, lookback \\ 10),
    to: Central.Backtest.Indicators.Momentum.Rvi,
    as: :detect_divergences

  @doc """
  Calculates Elder-Ray Index (Bull and Bear Power).
  """
  defdelegate elder_ray(candles, period \\ 13),
    to: Central.Backtest.Indicators.Momentum.ElderRay,
    as: :calculate

  @doc """
  Generates trading signals based on Elder-Ray.
  """
  defdelegate elder_ray_signals(elder_ray_result),
    to: Central.Backtest.Indicators.Momentum.ElderRay,
    as: :generate_signals

  @doc """
  Finds divergences between price and Elder-Ray components.
  """
  defdelegate elder_ray_divergences(candles, lookback \\ 5, elder_ray_result),
    to: Central.Backtest.Indicators.Momentum.ElderRay,
    as: :find_divergences

  @doc """
  Calculates the True Strength Index (TSI).
  """
  defdelegate tsi(
                candles,
                long_period \\ 25,
                short_period \\ 13,
                signal_period \\ 7,
                price_key \\ :close
              ),
              to: Central.Backtest.Indicators.Momentum.Tsi,
              as: :calculate

  @doc """
  Generates trading signals based on TSI.
  """
  defdelegate tsi_signals(tsi_result),
    to: Central.Backtest.Indicators.Momentum.Tsi,
    as: :generate_signals

  @doc """
  Finds divergences between price and TSI.
  """
  defdelegate tsi_divergences(candles, tsi_result, lookback \\ 5),
    to: Central.Backtest.Indicators.Momentum.Tsi,
    as: :find_divergences

  @doc """
  Calculates Ultimate Oscillator.
  """
  defdelegate ultimate_oscillator(
                candles,
                short_period \\ 7,
                medium_period \\ 14,
                long_period \\ 28,
                weights \\ [4, 2, 1]
              ),
              to: Central.Backtest.Indicators.Momentum.UltimateOscillator,
              as: :calculate

  @doc """
  Generates trading signals based on Ultimate Oscillator.
  """
  defdelegate ultimate_oscillator_signals(uo_result, overbought \\ 70, oversold \\ 30),
    to: Central.Backtest.Indicators.Momentum.UltimateOscillator,
    as: :generate_signals

  @doc """
  Finds divergences between price and Ultimate Oscillator.
  """
  defdelegate ultimate_oscillator_divergences(high, low, uo_result, lookback \\ 5),
    to: Central.Backtest.Indicators.Momentum.UltimateOscillator,
    as: :find_divergences

  @doc """
  Calculates Simple Momentum.
  """
  defdelegate simple_momentum(
                candles,
                period \\ 10,
                return_percentage \\ false,
                price_key \\ :close
              ),
              to: Central.Backtest.Indicators.Momentum.SimpleMomentum,
              as: :calculate

  @doc """
  Generates trading signals based on Simple Momentum.
  """
  defdelegate simple_momentum_signals(momentum_result),
    to: Central.Backtest.Indicators.Momentum.SimpleMomentum,
    as: :generate_signals

  @doc """
  Analyzes momentum strength by classifying values.
  """
  defdelegate classify_momentum_strength(momentum_result, strong_threshold \\ 5.0),
    to: Central.Backtest.Indicators.Momentum.SimpleMomentum,
    as: :classify_strength

  @doc """
  Calculates acceleration of momentum.
  """
  defdelegate momentum_acceleration(momentum_result, period \\ 3),
    to: Central.Backtest.Indicators.Momentum.SimpleMomentum,
    as: :calculate_acceleration

  # ------------------------------------------------------------------------------
  # Volatility Indicators
  # ------------------------------------------------------------------------------

  @doc """
  Calculates Average True Range (ATR).
  """
  defdelegate atr(candles, period \\ 14), to: Central.Backtest.Indicators.Volatility.Atr

  @doc """
  Calculates Bollinger Bands.
  """
  defdelegate bollinger_bands(candles, period \\ 20, deviations \\ 2, price_key \\ :close),
    to: Central.Backtest.Indicators.Volatility.BollingerBands

  @doc """
  Calculates Standard Deviation.
  """
  defdelegate standard_deviation(candles, period \\ 20, price_key \\ :close),
    to: Central.Backtest.Indicators.Volatility.StandardDeviation

  @doc """
  Calculates normalized standard deviation (as percentage of price).
  """
  defdelegate normalized_standard_deviation(candles, period \\ 20, price_key \\ :close),
    to: Central.Backtest.Indicators.Volatility.StandardDeviation

  @doc """
  Analyzes volatility patterns in standard deviation data.
  """
  defdelegate analyze_volatility(std_dev_data, trend_periods \\ 5),
    to: Central.Backtest.Indicators.Volatility.StandardDeviation,
    as: :analyze_volatility

  @doc """
  Calculates Chaikin Volatility.
  """
  defdelegate chaikin_volatility(candles, ema_period \\ 10, roc_period \\ 10),
    to: Central.Backtest.Indicators.Volatility.ChaikinVolatility,
    as: :calculate

  @doc """
  Detects potential market reversals based on Chaikin Volatility.
  """
  defdelegate chaikin_volatility_reversals(chaikin_volatility, threshold \\ 10, lookback \\ 5),
    to: Central.Backtest.Indicators.Volatility.ChaikinVolatility,
    as: :detect_reversals

  @doc """
  Calculates volatility bands around price based on Chaikin Volatility.
  """
  defdelegate chaikin_volatility_bands(close, chaikin_volatility, multiplier \\ 1.0),
    to: Central.Backtest.Indicators.Volatility.ChaikinVolatility,
    as: :calculate_bands

  @doc """
  Calculates Projection Bands.
  """
  defdelegate projection_bands(
                candles,
                period \\ 20,
                multiplier \\ 2.0,
                ma_type \\ :ema,
                adaptive \\ false,
                price_key \\ :close
              ),
              to: Central.Backtest.Indicators.Volatility.ProjectionBands,
              as: :calculate

  @doc """
  Generates trading signals based on Projection Bands.
  """
  defdelegate projection_bands_signals(prices, projection_bands_result),
    to: Central.Backtest.Indicators.Volatility.ProjectionBands,
    as: :generate_signals

  @doc """
  Identifies contraction and expansion patterns in Projection Bands.
  """
  defdelegate projection_bands_patterns(projection_bands_result, threshold \\ 0.1),
    to: Central.Backtest.Indicators.Volatility.ProjectionBands,
    as: :identify_band_patterns

  # ------------------------------------------------------------------------------
  # Volume Indicators
  # ------------------------------------------------------------------------------

  @doc """
  Calculates On-Balance Volume (OBV).
  """
  defdelegate obv(candles), to: Central.Backtest.Indicators.Volume.Obv

  @doc """
  Calculates Money Flow Index (MFI).
  """
  defdelegate mfi(candles, period \\ 14),
    to: Central.Backtest.Indicators.Volume.Mfi

  @doc """
  Generates signals based on Money Flow Index (MFI).
  """
  defdelegate mfi_signals(mfi_result, overbought \\ 80, oversold \\ 20),
    to: Central.Backtest.Indicators.Volume.Mfi,
    as: :generate_signals

  @doc """
  Detects divergences between price and MFI.
  """
  defdelegate mfi_divergences(candles, mfi_result, lookback \\ 5),
    to: Central.Backtest.Indicators.Volume.Mfi,
    as: :detect_divergences

  @doc """
  Calculates Chaikin Money Flow (CMF).
  """
  defdelegate cmf(candles, period \\ 20),
    to: Central.Backtest.Indicators.Volume.Cmf,
    as: :calculate

  @doc """
  Generates signals based on Chaikin Money Flow (CMF).
  """
  defdelegate cmf_signals(cmf_result, threshold \\ 0.05),
    to: Central.Backtest.Indicators.Volume.Cmf,
    as: :generate_signals

  @doc """
  Detects divergences between price and CMF.
  """
  defdelegate cmf_divergences(candles, cmf_result, lookback \\ 5),
    to: Central.Backtest.Indicators.Volume.Cmf,
    as: :find_divergences

  @doc """
  Calculates Volume Price Trend (VPT).
  """
  defdelegate vpt(candles), to: Central.Backtest.Indicators.Volume.Vpt, as: :calculate

  @doc """
  Generates signals based on Volume Price Trend (VPT).
  """
  defdelegate vpt_signals(vpt_result, ma_period \\ 20),
    to: Central.Backtest.Indicators.Volume.Vpt,
    as: :generate_signals

  @doc """
  Calculates rate of change for VPT.
  """
  defdelegate vpt_roc(vpt_result, period \\ 10),
    to: Central.Backtest.Indicators.Volume.Vpt,
    as: :calculate_roc

  @doc """
  Calculates Ease of Movement (EOM).
  """
  defdelegate eom(candles, period \\ 14, divisor \\ 10000),
    to: Central.Backtest.Indicators.Volume.Eom,
    as: :calculate

  @doc """
  Calculates Ease of Movement with separate components.
  """
  defdelegate eom_with_components(candles, period \\ 14, divisor \\ 10000),
    to: Central.Backtest.Indicators.Volume.Eom,
    as: :calculate_with_components

  @doc """
  Generates signals based on Ease of Movement.
  """
  defdelegate eom_signals(eom_result),
    to: Central.Backtest.Indicators.Volume.Eom,
    as: :generate_signals

  @doc """
  Calculates Force Index.
  """
  defdelegate force_index(candles, period \\ 13),
    to: Central.Backtest.Indicators.Volume.ForceIndex,
    as: :calculate

  @doc """
  Calculates Force Index for multiple timeframes.
  """
  defdelegate force_index_multi_timeframe(candles, long_period \\ 50),
    to: Central.Backtest.Indicators.Volume.ForceIndex,
    as: :calculate_multi_timeframe

  @doc """
  Generates signals based on Force Index.
  """
  defdelegate force_index_signals(force_index),
    to: Central.Backtest.Indicators.Volume.ForceIndex,
    as: :generate_signals

  @doc """
  Analyzes trend strength based on Force Index.
  """
  defdelegate force_index_trend_analysis(force_index, lookback \\ 10),
    to: Central.Backtest.Indicators.Volume.ForceIndex,
    as: :analyze_trend_strength

  @doc """
  Calculates Negative and Positive Volume Indices (NVI & PVI).
  """
  defdelegate nvi_pvi(candles, initial_value \\ 1000, price_key \\ :close),
    to: Central.Backtest.Indicators.Volume.NviPvi,
    as: :calculate

  @doc """
  Calculates signal lines for NVI and PVI.
  """
  defdelegate nvi_pvi_signal_lines(nvi_pvi_result, period \\ 255),
    to: Central.Backtest.Indicators.Volume.NviPvi,
    as: :calculate_signal_lines

  @doc """
  Generates signals based on NVI and PVI.
  """
  defdelegate nvi_pvi_signals(nvi_pvi_result, signal_lines_result),
    to: Central.Backtest.Indicators.Volume.NviPvi,
    as: :generate_signals

  @doc """
  Identifies market phases using NVI and PVI.
  """
  defdelegate identify_market_phases(nvi_pvi_result, lookback \\ 20),
    to: Central.Backtest.Indicators.Volume.NviPvi,
    as: :identify_market_phases

  @doc """
  Calculates volume moving average.
  """
  defdelegate volume_ma(candles, period \\ 20, ma_type \\ :sma, volume_key \\ :volume),
    to: Central.Backtest.Indicators.Volume.BasicVolume

  @doc """
  Calculates volume rate of change.
  """
  defdelegate volume_roc(candles, period \\ 14, volume_key \\ :volume),
    to: Central.Backtest.Indicators.Volume.BasicVolume

  @doc """
  Calculates relative volume.
  """
  defdelegate relative_volume(candles, period \\ 20, volume_key \\ :volume),
    to: Central.Backtest.Indicators.Volume.BasicVolume

  @doc """
  Calculates up/down volume.
  """
  defdelegate up_down_volume(candles, price_key \\ :close, volume_key \\ :volume),
    to: Central.Backtest.Indicators.Volume.BasicVolume

  @doc """
  Identifies volume breakouts.
  """
  defdelegate volume_breakouts(candles, period \\ 20, threshold \\ 2.0, volume_key \\ :volume),
    to: Central.Backtest.Indicators.Volume.BasicVolume

  @doc """
  Calculates volume-price confirmation.
  """
  defdelegate volume_price_confirmation(
                candles,
                period \\ 20,
                rel_vol_threshold \\ 1.5,
                price_key \\ :close,
                volume_key \\ :volume
              ),
              to: Central.Backtest.Indicators.Volume.BasicVolume

  @doc """
  Detects volume climax.
  """
  defdelegate volume_climax(
                candles,
                period \\ 20,
                volume_threshold \\ 3.0,
                trend_lookback \\ 5,
                price_key \\ :close,
                volume_key \\ :volume
              ),
              to: Central.Backtest.Indicators.Volume.BasicVolume

  @doc """
  Calculates volume force.
  """
  defdelegate volume_force(candles, price_key \\ :close, volume_key \\ :volume),
    to: Central.Backtest.Indicators.Volume.BasicVolume

  # ------------------------------------------------------------------------------
  # Level Indicators
  # ------------------------------------------------------------------------------

  @doc """
  Calculates Standard Pivot Points.
  """
  defdelegate standard_pivot_points(candle),
    to: Central.Backtest.Indicators.Levels.PivotPoints,
    as: :standard

  @doc """
  Calculates Fibonacci Pivot Points.
  """
  defdelegate fibonacci_pivot_points(candle),
    to: Central.Backtest.Indicators.Levels.PivotPoints,
    as: :fibonacci

  @doc """
  Calculates Camarilla Pivot Points.
  """
  defdelegate camarilla_pivot_points(candle),
    to: Central.Backtest.Indicators.Levels.PivotPoints,
    as: :camarilla

  @doc """
  Calculates Woodie's Pivot Points.
  """
  defdelegate woodie_pivot_points(candle),
    to: Central.Backtest.Indicators.Levels.PivotPoints,
    as: :woodie

  @doc """
  Identifies Psychological Price Levels.
  """
  defdelegate psych_levels(
                start_price,
                end_price,
                increment \\ 1,
                include_halves \\ false,
                include_quarters \\ false
              ),
              to: Central.Backtest.Indicators.Levels.PsychLevels,
              as: :identify_levels

  @doc """
  Finds the nearest psychological levels to the current price.
  """
  defdelegate nearest_psych_levels(levels, current_price, limit \\ 3),
    to: Central.Backtest.Indicators.Levels.PsychLevels,
    as: :nearest_levels

  @doc """
  Analyzes the strength of psychological levels based on historical data.
  """
  defdelegate analyze_psych_levels(levels, candles, lookback \\ 100),
    to: Central.Backtest.Indicators.Levels.PsychLevels,
    as: :analyze_strength

  @doc """
  Calculates Linear Regression Channel.
  """
  defdelegate linear_regression_channel(prices, period \\ 20, deviation_multiplier \\ 2.0),
    to: Central.Backtest.Indicators.Levels.Channels

  @doc """
  Calculates Linear Regression Channel with OHLC candles.
  """
  defdelegate linear_regression_channel_candles(candles, period),
    to: Central.Backtest.Indicators.Levels.Channels

  @doc """
  Calculates Raff Regression Channel.
  """
  defdelegate raff_regression_channel(candles, period \\ 20, price_key \\ :close),
    to: Central.Backtest.Indicators.Levels.Channels

  @doc """
  Calculates Parallel Channel (a.k.a. Andrews' Pitchfork).
  """
  defdelegate parallel_channel(candles, period \\ 20),
    to: Central.Backtest.Indicators.Levels.Channels

  @doc """
  Calculates Trend Channel.
  """
  defdelegate trend_channel(candles, period \\ 20),
    to: Central.Backtest.Indicators.Levels.Channels

  @doc """
  Calculates Envelope Channel.
  """
  defdelegate envelope_channel(prices, period \\ 20, percentage \\ 2.5, ma_type \\ :sma),
    to: Central.Backtest.Indicators.Levels.Channels

  @doc """
  Calculates Envelope Channel with OHLC candles.
  """
  defdelegate envelope_channel_candles(candles, period),
    to: Central.Backtest.Indicators.Levels.Channels

  @doc """
  Generates trading signals based on channel breakouts.
  """
  defdelegate channel_signals(candles, channel_result, price_key \\ :close),
    to: Central.Backtest.Indicators.Levels.Channels,
    as: :generate_signals

  @doc """
  Identifies channel contraction and expansion patterns.
  """
  defdelegate identify_channel_patterns(channel_result, threshold \\ 0.1),
    to: Central.Backtest.Indicators.Levels.Channels,
    as: :identify_channel_patterns

  # ------------------------------------------------------------------------------
  # Indicator Metadata
  # ------------------------------------------------------------------------------

  @doc """
  Returns a list of all available indicators with metadata.
  """
  defdelegate list_indicators(), to: ListIndicator

  @doc """
  Returns a specific indicator by ID.
  """
  defdelegate get_indicator(id), to: ListIndicator

  @doc """
  Returns indicators grouped by type.
  """
  defdelegate group_indicators_by_type(), to: ListIndicator
end
