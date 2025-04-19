defmodule Central.Backtest.Indicators.Trend.Adx do
  @moduledoc """
  Implements the Average Directional Index (ADX) indicator.

  ADX is a technical analysis indicator used to quantify trend strength.
  It is a non-directional indicator, meaning it measures trend strength whether price is trending up or down.

  The ADX is derived from the Directional Movement Index (DMI) and is calculated as follows:
  1. Calculate +DM and -DM (Directional Movement)
  2. Calculate True Range (TR)
  3. Calculate +DI and -DI (Directional Indicators)
  4. Calculate ADX as a smoothed average of the absolute difference between +DI and -DI

  ## Parameters

  - high: List of high prices
  - low: List of low prices
  - close: List of closing prices
  - period: Number of periods to use for smoothing (default: 14)

  ## Returns

  A map containing:
  - adx: List of ADX values
  - plus_di: List of +DI values
  - minus_di: List of -DI values
  """

  alias Central.Backtest.Indicators.Calculations.Math

  @doc """
  Calculates the ADX indicator from raw price arrays.
  """
  def calculate_raw(high, low, close, period \\ 14) do
    with true <- validate_inputs(high, low, close, period),
         {plus_dm, minus_dm} <- calculate_directional_movement(high, low),
         tr <- calculate_true_range(high, low, close),
         {plus_di, minus_di} <- calculate_directional_indicators(plus_dm, minus_dm, tr, period),
         adx <- calculate_adx(plus_di, minus_di, period) do
      {:ok, %{adx: adx, plus_di: plus_di, minus_di: minus_di}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculates the ADX indicator from OHLC candles.

  ## Parameters
    - candles: List of candle maps with :high, :low, and :close data
    - period: Number of periods for calculation (default: 14)

  ## Returns
    - {:ok, result} where result is a map with :adx, :plus_di, and :minus_di values
  """
  def calculate(candles, period \\ 14) when is_list(candles) do
    # Extract high, low, and close prices from candles
    high = Enum.map(candles, & &1.high)
    low = Enum.map(candles, & &1.low)
    close = Enum.map(candles, & &1.close)

    # Call the main calculation function
    calculate_raw(high, low, close, period)
  end

  defp validate_inputs(high, low, close, period) do
    cond do
      not is_list(high) or not is_list(low) or not is_list(close) ->
        {:error, "Inputs must be lists"}
      length(high) != length(low) or length(low) != length(close) ->
        {:error, "Input lists must have the same length"}
      period <= 0 ->
        {:error, "Period must be greater than 0"}
      true ->
        true
    end
  end

  defp calculate_directional_movement(high, low) do
    {plus_dm, minus_dm} = Enum.zip(high, low)
    |> Enum.zip(Enum.drop(Enum.zip(high, low), 1))
    |> Enum.map(fn {{prev_high, prev_low}, {curr_high, curr_low}} ->
      up_move = curr_high - prev_high
      down_move = prev_low - curr_low

      plus_dm = if up_move > down_move and up_move > 0, do: up_move, else: 0
      minus_dm = if down_move > up_move and down_move > 0, do: down_move, else: 0

      {plus_dm, minus_dm}
    end)
    |> Enum.unzip()

    {[0 | plus_dm], [0 | minus_dm]}
  end

  defp calculate_true_range(high, low, close) do
    Enum.zip([high, low, close])
    |> Enum.zip(Enum.drop(Enum.zip([high, low, close]), 1))
    |> Enum.map(fn {{_prev_high, _prev_low, prev_close}, {curr_high, curr_low, _curr_close}} ->
      [
        curr_high - curr_low,
        abs(curr_high - prev_close),
        abs(curr_low - prev_close)
      ]
      |> Enum.max()
    end)
    |> List.insert_at(0, 0)
  end

  defp calculate_directional_indicators(plus_dm, minus_dm, tr, period) do
    plus_di = smooth_series(plus_dm, tr, period)
    |> Enum.map(fn {dm, tr} ->
      if tr == 0, do: 0, else: 100 * dm / tr
    end)

    minus_di = smooth_series(minus_dm, tr, period)
    |> Enum.map(fn {dm, tr} ->
      if tr == 0, do: 0, else: 100 * dm / tr
    end)

    {plus_di, minus_di}
  end

  defp calculate_adx(plus_di, minus_di, period) do
    Enum.zip(plus_di, minus_di)
    |> Enum.map(fn {plus, minus} -> abs(plus - minus) / (plus + minus) * 100 end)
    |> smooth_series(period)
  end

  defp smooth_series(values, period) do
    values
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(&Math.average/1)
  end

  defp smooth_series(values1, values2, period) do
    Enum.zip(values1, values2)
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn chunk ->
      {sum1, sum2} = Enum.reduce(chunk, {0, 0}, fn {v1, v2}, {acc1, acc2} ->
        {acc1 + v1, acc2 + v2}
      end)
      {sum1 / period, sum2 / period}
    end)
  end
end
