defmodule Central.Backtest.Indicators.Volume.Vpt do
  @moduledoc """
  Implementation of the Volume Price Trend (VPT) indicator.

  The VPT is a technical indicator that combines price and volume to help determine
  a security's price direction and strength. It shows the balance between demand and supply.

  The calculation involves:
  1. Calculate the percentage change in price
  2. Multiply the percentage change by volume
  3. Accumulate the results to create a running total

  ## Parameters

  - close: List of closing prices
  - volume: List of volume values

  ## Returns

  A tuple containing:
  - {:ok, vpt_values} on success
  - {:error, reason} on failure
  """

  alias Central.Backtest.Indicators.Calculations.ListOperations

  @doc """
  Calculates the Volume Price Trend indicator using raw price and volume data.
  """
  def calculate_raw(close, volume) do
    with true <- validate_inputs(close, volume),
         vpt <- calculate_vpt(close, volume) do
      {:ok, vpt}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculates the Volume Price Trend indicator using OHLCV candle data.

  ## Parameters
    - candles: List of candle maps with :close and :volume data

  ## Returns
    - {:ok, vpt_values} on success
    - {:error, reason} on failure
  """
  def calculate(candles) when is_list(candles) do
    close = Enum.map(candles, &Map.get(&1, :close))
    volume = Enum.map(candles, &Map.get(&1, :volume))

    calculate_raw(close, volume)
  end

  defp validate_inputs(close, volume) do
    cond do
      not is_list(close) or not is_list(volume) ->
        {:error, "Inputs must be lists"}

      length(close) != length(volume) ->
        {:error, "Input lists must have the same length"}

      true ->
        true
    end
  end

  defp calculate_vpt(close, volume) do
    Enum.zip(close, volume)
    |> Enum.zip(Enum.drop(Enum.zip(close, volume), 1))
    |> Enum.map(fn {{prev_close, _}, {curr_close, curr_volume}} ->
      if prev_close == 0, do: 0, else: (curr_close - prev_close) / prev_close * curr_volume
    end)
    |> Enum.scan(0, &(&1 + &2))
    |> List.insert_at(0, 0)
  end

  @doc """
  Generates trading signals based on VPT values.

  Returns:
  - 1 for buy signal (VPT crosses above its moving average)
  - -1 for sell signal (VPT crosses below its moving average)
  - 0 for no signal
  """
  def generate_signals(vpt, ma_period \\ 20) do
    ma = calculate_moving_average(vpt, ma_period)

    Enum.zip(vpt, ma)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [{prev_vpt, prev_ma}, {curr_vpt, curr_ma}] ->
      cond do
        prev_vpt <= prev_ma and curr_vpt > curr_ma -> 1
        prev_vpt >= prev_ma and curr_vpt < curr_ma -> -1
        true -> 0
      end
    end)
    |> List.insert_at(0, 0)
  end

  defp calculate_moving_average(values, period) do
    values
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(&Enum.sum/1)
    |> Enum.map(&(&1 / period))
    |> List.insert_at(0, 0)
  end

  @doc """
  Identifies divergences between price and VPT.

  Returns a list of divergence events:
  - {:bullish_divergence, index} when price makes lower low but VPT makes higher low
  - {:bearish_divergence, index} when price makes higher high but VPT makes lower high
  """
  def find_divergences(high, low, vpt, lookback \\ 5) do
    Enum.zip([high, low, vpt])
    |> Enum.chunk_every(lookback, 1, :discard)
    |> Enum.with_index()
    |> Enum.flat_map(fn {window, index} ->
      find_divergences_in_window(window, index)
    end)
  end

  defp find_divergences_in_window(window, index) do
    {highs, lows, vpts} = ListOperations.unzip3(window)

    divergences = []

    # Check for bullish divergence
    divergences =
      if Enum.min(lows) == List.last(lows) and
           Enum.min(vpts) != List.last(vpts) do
        [{:bullish_divergence, index} | divergences]
      else
        divergences
      end

    # Check for bearish divergence
    divergences =
      if Enum.max(highs) == List.last(highs) and
           Enum.max(vpts) != List.last(vpts) do
        [{:bearish_divergence, index} | divergences]
      else
        divergences
      end

    divergences
  end

  @doc """
  Calculates the rate of change of VPT.

  Returns the percentage change in VPT over the specified period.
  """
  def calculate_roc(vpt, period \\ 10) do
    vpt
    |> Enum.chunk_every(period + 1, 1, :discard)
    |> Enum.map(fn chunk ->
      [first | _] = chunk
      last = List.last(chunk)
      if first == 0, do: 0, else: (last - first) / first * 100
    end)
    |> List.insert_at(0, 0)
  end
end
