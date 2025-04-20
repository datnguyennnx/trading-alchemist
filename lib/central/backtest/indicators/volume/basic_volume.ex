defmodule Central.Backtest.Indicators.Volume.BasicVolume do
  @moduledoc """
  Implements Basic Volume Analysis techniques.

  Volume is one of the most fundamental aspects of market analysis, providing
  insights into the strength and sustainability of price movements. This module
  provides essential volume analysis functions.

  Basic volume analysis includes:
  1. Volume moving averages (to identify normal vs abnormal volume)
  2. Volume rate of change (to identify volume surges/drops)
  3. Relative volume (comparing current volume to historical average)
  4. Up/down volume (analyzing volume on up days vs down days)
  5. Volume breakouts (identifying significant volume spikes)

  ## Parameters

  - volume: List of volume data
  - prices: List of price values (typically closing prices)
  - period: Number of periods for calculations (default varies by function)

  ## Returns

  Varies by function, typically:
  - {:ok, result} on success
  - {:error, reason} on failure
  """

  @doc """
  Calculates Volume Moving Average for candles.
  This is the main public interface function that matches the facade in indicators.ex.
  """
  def volume_ma(candles, period \\ 20, ma_type \\ :sma, volume_key \\ :volume)

  def volume_ma(candles, period, ma_type, volume_key)
      when is_list(candles) and is_map(hd(candles)) do
    volume = Enum.map(candles, &Map.get(&1, volume_key))
    calculate_ma(volume, period, ma_type)
  end

  def volume_ma(volume, period, ma_type, _volume_key)
      when is_list(volume) and is_number(hd(volume)) do
    calculate_ma(volume, period, ma_type)
  end

  # Private helper function to calculate the actual MA
  defp calculate_ma(volume, period, ma_type) do
    case ma_type do
      :sma ->
        case Central.Backtest.Indicators.Trend.MovingAverage.calculate(volume, period, :simple) do
          {:ok, result} -> {:ok, result}
          error -> error
        end
      :ema ->
        case Central.Backtest.Indicators.Trend.ExponentialMovingAverage.calculate(volume, period) do
          {:ok, result} -> {:ok, result}
          error -> error
        end
      :wma ->
        case Central.Backtest.Indicators.Trend.MovingAverage.calculate(volume, period, :weighted) do
          {:ok, result} -> {:ok, result}
          error -> error
        end
      _ -> {:error, "Unsupported moving average type"}
    end
  end

  @doc """
  Calculates Volume Rate of Change with OHLCV candle data.

  ## Parameters
    - candles: List of candle maps with :volume data
    - period: Number of periods for ROC calculation (default: 14)
    - volume_key: Key to use for volume data (default: :volume)

  ## Returns
    - {:ok, volume_roc} on success
    - {:error, reason} on failure
  """
  def volume_roc(candles, period \\ 14, volume_key \\ :volume)

  def volume_roc(candles, period, volume_key)
      when is_list(candles) and is_map(hd(candles)) and is_atom(volume_key) do
    volume = Enum.map(candles, &Map.get(&1, volume_key))
    volume_roc_raw(volume, period)
  end

  @doc """
  Calculates Volume Rate of Change for raw volume data.

  ## Parameters
    - volume: List of volume values
    - period: Number of periods for calculation

  ## Returns
    - {:ok, roc_values} on success
    - {:error, reason} on failure
  """
  def volume_roc_raw(volume, period)
      when is_list(volume) and is_number(hd(volume)) do
    with :ok <- validate_inputs(volume, period) do
      roc = volume
        |> Enum.chunk_every(period + 1, 1, :discard)
        |> Enum.map(fn chunk ->
          current = List.last(chunk)
          previous = List.first(chunk)
          if previous == 0, do: 0, else: (current - previous) / previous * 100
        end)
        |> pad_with_zeros(length(volume), period)

      {:ok, roc}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculates Relative Volume with OHLCV candle data.

  ## Parameters
    - candles: List of candle maps with :volume data
    - period: Number of periods for calculation (default: 20)
    - volume_key: Key to use for volume data (default: :volume)

  ## Returns
    - {:ok, relative_volume} on success
    - {:error, reason} on failure
  """
  def relative_volume(candles, period \\ 20, volume_key \\ :volume)

  def relative_volume(candles, period, volume_key)
      when is_list(candles) and is_map(hd(candles)) and is_atom(volume_key) do
    volume = Enum.map(candles, &Map.get(&1, volume_key))
    relative_volume_raw(volume, period)
  end

  @doc """
  Calculates Relative Volume for raw volume data.

  ## Parameters
    - volume: List of volume values
    - period: Number of periods for calculation

  ## Returns
    - {:ok, relative_volume} on success
    - {:error, reason} on failure
  """
  def relative_volume_raw(volume, period)
      when is_list(volume) and is_number(hd(volume)) do
    with :ok <- validate_inputs(volume, period),
         {:ok, volume_avg} <- calculate_ma(volume, period, :sma) do

      rel_volume = Enum.zip(volume, volume_avg)
        |> Enum.map(fn {vol, avg} ->
          if avg == 0, do: 0, else: vol / avg
        end)

      {:ok, rel_volume}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculates Up/Down Volume with OHLCV candle data.

  ## Parameters
    - candles: List of candle maps with :close and :volume data
    - price_key: Key to use for price data (default: :close)
    - volume_key: Key to use for volume data (default: :volume)

  ## Returns
    - {:ok, {up_volume, down_volume}} on success
    - {:error, reason} on failure
  """
  def up_down_volume(candles, price_key \\ :close, volume_key \\ :volume)

  def up_down_volume(candles, price_key, volume_key)
      when is_list(candles) and is_map(hd(candles)) and is_atom(price_key) and is_atom(volume_key) do
    volume = Enum.map(candles, &Map.get(&1, volume_key))
    prices = Enum.map(candles, &Map.get(&1, price_key))
    up_down_volume_raw(volume, prices)
  end

  @doc """
  Calculates Up/Down Volume for raw volume and price data.

  ## Parameters
    - volume: List of volume values
    - prices: List of price values

  ## Returns
    - {:ok, {up_volume, down_volume}} on success
    - {:error, reason} on failure
  """
  def up_down_volume_raw(volume, prices)
      when is_list(volume) and is_list(prices) do
    with :ok <- validate_volume_prices(volume, prices) do
      {up_vol, down_vol} = prices
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.zip(Enum.drop(volume, 1))
        |> Enum.map(fn {[prev_price, curr_price], vol} ->
          cond do
            curr_price > prev_price -> {vol, 0}  # Up day
            curr_price < prev_price -> {0, vol}  # Down day
            true -> {0, 0}  # Unchanged
          end
        end)
        |> Enum.unzip()

      # Pad first values
      up_volume = [0 | up_vol]
      down_volume = [0 | down_vol]

      {:ok, {up_volume, down_volume}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Identifies Volume Breakouts with OHLCV candle data.

  ## Parameters
    - candles: List of candle maps with :volume data
    - period: Number of periods for moving average (default: 20)
    - threshold: Threshold for breakout detection (default: 2.0)
    - volume_key: Key to use for volume data (default: :volume)

  ## Returns
    - {:ok, breakout_signals} on success where 1 = breakout, 0 = no breakout
    - {:error, reason} on failure
  """
  def volume_breakouts(candles, period \\ 20, threshold \\ 2.0, volume_key \\ :volume)

  def volume_breakouts(candles, period, threshold, volume_key)
      when is_list(candles) and is_map(hd(candles)) and is_atom(volume_key) do
    volume = Enum.map(candles, &Map.get(&1, volume_key))
    volume_breakouts_raw(volume, period, threshold)
  end

  @doc """
  Identifies Volume Breakouts for raw volume data.

  ## Parameters
    - volume: List of volume values
    - period: Number of periods for moving average
    - threshold: Threshold for breakout detection

  ## Returns
    - {:ok, breakout_signals} on success where 1 = breakout, 0 = no breakout
    - {:error, reason} on failure
  """
  def volume_breakouts_raw(volume, period, threshold)
      when is_list(volume) and is_number(hd(volume)) do
    with :ok <- validate_inputs(volume, period),
         {:ok, volume_avg} <- calculate_ma(volume, period, :sma) do

      breakouts = Enum.zip(volume, volume_avg)
        |> Enum.map(fn {vol, avg} ->
          if avg > 0 and vol / avg >= threshold, do: 1, else: 0
        end)

      {:ok, breakouts}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculates Volume Price Confirmation with OHLCV candle data.

  ## Parameters
    - candles: List of candle maps with :close and :volume data
    - period: Number of periods for calculation (default: 20)
    - rel_vol_threshold: Threshold for relative volume (default: 1.5)
    - price_key: Key to use for price data (default: :close)
    - volume_key: Key to use for volume data (default: :volume)

  ## Returns
    - {:ok, confirmation_values} on success
    - {:error, reason} on failure
  """
  def volume_price_confirmation(candles, period \\ 20, rel_vol_threshold \\ 1.5, price_key \\ :close, volume_key \\ :volume)

  def volume_price_confirmation(candles, period, rel_vol_threshold, price_key, volume_key)
      when is_list(candles) and is_map(hd(candles)) and is_atom(price_key) and is_atom(volume_key) do
    volume = Enum.map(candles, &Map.get(&1, volume_key))
    prices = Enum.map(candles, &Map.get(&1, price_key))
    volume_price_confirmation_raw(volume, prices, period, rel_vol_threshold)
  end

  @doc """
  Calculates Volume Price Confirmation for raw volume and price data.

  ## Parameters
    - volume: List of volume values
    - prices: List of price values
    - period: Number of periods for calculation
    - rel_vol_threshold: Threshold for relative volume

  ## Returns
    - {:ok, confirmation_values} on success
    - {:error, reason} on failure
  """
  def volume_price_confirmation_raw(volume, prices, period, rel_vol_threshold)
      when is_list(volume) and is_list(prices) do
    with :ok <- validate_volume_prices(volume, prices),
         {:ok, rel_volume} <- relative_volume_raw(volume, period) do

      # Get price changes
      price_changes = prices
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [prev, curr] -> curr - prev end)
        |> pad_with_zeros(length(prices), 1)

      # Combine price direction with relative volume
      Enum.zip([price_changes, rel_volume])
        |> Enum.map(fn {price_change, rel_vol} ->
          cond do
            price_change > 0 and rel_vol >= rel_vol_threshold -> 1      # Strong bullish
            price_change < 0 and rel_vol >= rel_vol_threshold -> -1     # Strong bearish
            price_change > 0 and rel_vol < rel_vol_threshold -> 0.5     # Weak bullish
            price_change < 0 and rel_vol < rel_vol_threshold -> -0.5    # Weak bearish
            true -> 0  # No confirmation
          end
        end)
        |> then(fn result -> {:ok, result} end)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Detects Volume Climax with OHLCV candle data.

  ## Parameters
    - candles: List of candle maps with :close and :volume data
    - period: Number of periods for calculation (default: 20)
    - volume_threshold: Threshold for volume spike detection (default: 3.0)
    - trend_lookback: Number of periods to determine trend (default: 5)
    - price_key: Key to use for price data (default: :close)
    - volume_key: Key to use for volume data (default: :volume)

  ## Returns
    - {:ok, climax_signals} on success
    - {:error, reason} on failure
  """
  def volume_climax(candles, period \\ 20, volume_threshold \\ 3.0, trend_lookback \\ 5, price_key \\ :close, volume_key \\ :volume)

  def volume_climax(candles, period, volume_threshold, trend_lookback, price_key, volume_key)
      when is_list(candles) and is_map(hd(candles)) and is_atom(price_key) and is_atom(volume_key) do
    volume = Enum.map(candles, &Map.get(&1, volume_key))
    prices = Enum.map(candles, &Map.get(&1, price_key))
    volume_climax_raw(volume, prices, period, volume_threshold, trend_lookback)
  end

  @doc """
  Detects Volume Climax for raw volume and price data.

  ## Parameters
    - volume: List of volume values
    - prices: List of price values
    - period: Number of periods for calculation
    - volume_threshold: Threshold for volume spike detection
    - trend_lookback: Number of periods to determine trend

  ## Returns
    - {:ok, climax_signals} on success
    - {:error, reason} on failure
  """
  def volume_climax_raw(volume, prices, period, volume_threshold, trend_lookback)
      when is_list(volume) and is_list(prices) do
    with :ok <- validate_volume_prices(volume, prices),
         {:ok, rel_volume} <- relative_volume_raw(volume, period) do

      # Determine price trends
      price_trends = prices
        |> Enum.chunk_every(trend_lookback, 1, :discard)
        |> Enum.map(fn chunk ->
          first = List.first(chunk)
          last = List.last(chunk)
          if last > first, do: :uptrend, else: :downtrend
        end)
        |> pad_with_first_value(length(prices), trend_lookback - 1)

      # Get price changes
      price_changes = prices
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [prev, curr] ->
          if prev == 0, do: 0, else: (curr - prev) / prev * 100
        end)
        |> pad_with_zeros(length(prices), 1)

      # Combine trend, price change and volume for climax detection
      Enum.zip([price_trends, price_changes, rel_volume])
        |> Enum.map(fn {trend, price_change, rel_vol} ->
          cond do
            trend == :downtrend and price_change > 1 and rel_vol >= volume_threshold -> 1  # Bullish climax
            trend == :uptrend and price_change < -1 and rel_vol >= volume_threshold -> -1  # Bearish climax
            true -> 0  # No climax
          end
        end)
        |> then(fn result -> {:ok, result} end)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculates Volume Force with OHLCV candle data.

  ## Parameters
    - candles: List of candle maps with :close and :volume data
    - price_key: Key to use for price data (default: :close)
    - volume_key: Key to use for volume data (default: :volume)

  ## Returns
    - {:ok, volume_force} on success
    - {:error, reason} on failure
  """
  def volume_force(candles, price_key \\ :close, volume_key \\ :volume)

  def volume_force(candles, price_key, volume_key)
      when is_list(candles) and is_map(hd(candles)) and is_atom(price_key) and is_atom(volume_key) do
    volume = Enum.map(candles, &Map.get(&1, volume_key))
    prices = Enum.map(candles, &Map.get(&1, price_key))
    volume_force_raw(volume, prices)
  end

  @doc """
  Calculates Volume Force for raw volume and price data.

  ## Parameters
    - volume: List of volume values
    - prices: List of price values

  ## Returns
    - {:ok, volume_force} on success
    - {:error, reason} on failure
  """
  def volume_force_raw(volume, prices)
      when is_list(volume) and is_list(prices) and is_number(hd(volume)) do
    with :ok <- validate_volume_prices(volume, prices) do
      # Calculate percentage price changes
      price_changes = prices
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [prev, curr] ->
          if prev == 0, do: 0, else: (curr - prev) / prev * 100
        end)
        |> pad_with_zeros(length(prices), 1)

      # Multiply volume by price change
      force = Enum.zip([volume, price_changes])
        |> Enum.map(fn {vol, change} -> vol * change end)

      {:ok, force}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculates Volume Moving Average with OHLCV candle data.

  ## Parameters
    - candles: List of candle maps with :volume data
    - period: Number of periods for the moving average (default: 20)
    - ma_type: Type of moving average (:sma, :ema, :wma) (default: :sma)
    - volume_key: Key to use for volume data (default: :volume)

  ## Returns
    - {:ok, volume_ma} on success
    - {:error, reason} on failure
  """
  def volume_ma_candles(candles, period \\ 20, ma_type \\ :sma, volume_key \\ :volume)

  def volume_ma_candles(candles, period, ma_type, volume_key)
      when is_list(candles) and is_map(hd(candles)) and is_atom(volume_key) do
    volume = Enum.map(candles, &Map.get(&1, volume_key))
    volume_ma(volume, period, ma_type)
  end

  # Helper Functions

  defp validate_inputs(volume, period) do
    cond do
      not is_list(volume) ->
        {:error, "Volume must be a list"}
      period <= 0 ->
        {:error, "Period must be greater than 0"}
      length(volume) < period ->
        {:error, "Not enough data points for the given period"}
      true ->
        :ok
    end
  end

  defp validate_volume_prices(volume, prices) do
    cond do
      not (is_list(volume) and is_list(prices)) ->
        {:error, "Volume and prices must be lists"}
      length(volume) != length(prices) ->
        {:error, "Volume and prices must have the same length"}
      length(volume) < 2 ->
        {:error, "At least 2 data points are required"}
      true ->
        :ok
    end
  end

  defp pad_with_zeros(values, original_length, padding_size) do
    padding = List.duplicate(0, padding_size)
    padding ++ values ++ List.duplicate(0, original_length - padding_size - length(values))
  end

  defp pad_with_first_value(values, original_length, padding_size) do
    first_value = List.first(values) || :neutral
    padding = List.duplicate(first_value, padding_size)
    padding ++ values ++ List.duplicate(first_value, original_length - padding_size - length(values))
  end
end
