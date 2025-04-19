defmodule Central.Backtest.Indicators.Volume.Cmf do
  @moduledoc """
  Implements the Chaikin Money Flow (CMF) indicator.

  CMF is a volume-weighted momentum indicator that measures buying and selling pressure
  over a specified period. It combines price and volume to measure the flow of money
  into or out of a security.

  The calculation involves:
  1. Money Flow Multiplier = [(Close - Low) - (High - Close)] / (High - Low)
  2. Money Flow Volume = Money Flow Multiplier * Volume
  3. CMF = Sum of Money Flow Volume / Sum of Volume over the period

  ## Parameters

  - high: List of high prices
  - low: List of low prices
  - close: List of closing prices
  - volume: List of volume values
  - period: Number of periods to use for calculation (default: 20)

  ## Returns

  A tuple containing:
  - {:ok, cmf_values} on success
  - {:error, reason} on failure
  """

  @doc """
  Calculates the Chaikin Money Flow indicator.
  """
  def calculate(high, low, close, volume, period \\ 20) do
    with true <- validate_inputs(high, low, close, volume, period),
         money_flow_multiplier <- calculate_money_flow_multiplier(high, low, close),
         money_flow_volume <- calculate_money_flow_volume(money_flow_multiplier, volume),
         cmf <- calculate_cmf(money_flow_volume, volume, period) do
      {:ok, cmf}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculates the Chaikin Money Flow indicator using OHLCV candle data.

  ## Parameters
    - candles: List of candle maps with :high, :low, :close, and :volume data
    - period: Number of periods to use for calculation (default: 20)

  ## Returns
    - {:ok, cmf_values} on success
    - {:error, reason} on failure
  """
  def calculate(candles, period \\ 20) when is_list(candles) do
    high = Enum.map(candles, &Map.get(&1, :high))
    low = Enum.map(candles, &Map.get(&1, :low))
    close = Enum.map(candles, &Map.get(&1, :close))
    volume = Enum.map(candles, &Map.get(&1, :volume))

    calculate(high, low, close, volume, period)
  end

  defp validate_inputs(high, low, close, volume, period) do
    cond do
      not is_list(high) or not is_list(low) or not is_list(close) or not is_list(volume) ->
        {:error, "Inputs must be lists"}
      length(high) != length(low) or length(low) != length(close) or length(close) != length(volume) ->
        {:error, "Input lists must have the same length"}
      period <= 0 ->
        {:error, "Period must be greater than 0"}
      true ->
        true
    end
  end

  defp calculate_money_flow_multiplier(high, low, close) do
    Enum.zip([high, low, close])
    |> Enum.map(fn {h, l, c} ->
      if h == l, do: 0, else: ((c - l) - (h - c)) / (h - l)
    end)
  end

  defp calculate_money_flow_volume(money_flow_multiplier, volume) do
    Enum.zip(money_flow_multiplier, volume)
    |> Enum.map(fn {mfm, v} -> mfm * v end)
  end

  defp calculate_cmf(money_flow_volume, volume, period) do
    money_flow_volume
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.zip(Enum.chunk_every(volume, period, 1, :discard))
    |> Enum.map(fn {mfv_chunk, vol_chunk} ->
      sum_mfv = Enum.sum(mfv_chunk)
      sum_vol = Enum.sum(vol_chunk)
      if sum_vol == 0, do: 0, else: sum_mfv / sum_vol
    end)
    |> List.insert_at(0, 0)
  end

  @doc """
  Generates trading signals based on CMF values.

  Returns:
  - 1 for buy signal (CMF crosses above 0.05)
  - -1 for sell signal (CMF crosses below -0.05)
  - 0 for no signal
  """
  def generate_signals(cmf, threshold \\ 0.05) do
    cmf
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, curr] ->
      cond do
        prev <= threshold and curr > threshold -> 1
        prev >= -threshold and curr < -threshold -> -1
        true -> 0
      end
    end)
    |> List.insert_at(0, 0)
  end

  @doc """
  Identifies divergences between price and CMF.

  Returns a list of divergence events:
  - {:bullish_divergence, index} when price makes lower low but CMF makes higher low
  - {:bearish_divergence, index} when price makes higher high but CMF makes lower high
  """
  def find_divergences(high, low, cmf, lookback \\ 5) do
    Enum.zip([high, low, cmf])
    |> Enum.chunk_every(lookback, 1, :discard)
    |> Enum.with_index()
    |> Enum.flat_map(fn {window, index} ->
      find_divergences_in_window(window, index)
    end)
  end

  defp find_divergences_in_window(window, index) do
    {prices, cmf_values} = Enum.unzip(window)

    divergences = []

    # Check for bullish divergence (price makes lower low but CMF doesn't)
    divergences = if Enum.min(prices) == List.last(prices) and
       Enum.min(cmf_values) != List.last(cmf_values) do
      [{:bullish_divergence, index} | divergences]
    else
      divergences
    end

    # Check for bearish divergence (price makes higher high but CMF doesn't)
    divergences = if Enum.max(prices) == List.last(prices) and
       Enum.max(cmf_values) != List.last(cmf_values) do
      [{:bearish_divergence, index} | divergences]
    else
      divergences
    end

    divergences
  end
end
