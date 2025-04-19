defmodule Central.Backtest.Indicators.Volume.Obv do
  @moduledoc """
  Implementation of the On-Balance Volume (OBV) indicator.

  On-Balance Volume is a momentum indicator that uses volume flow to predict changes in price.
  OBV is calculated by adding volume on up days and subtracting volume on down days.

  The theory behind OBV is that volume precedes price. Smart money (institutional investors)
  accumulates or distributes before the general public, which later causes price to move.
  """

  @doc """
  Calculates On-Balance Volume (OBV) for a list of candles.

  ## Parameters
    - candles: List of candle maps with price and volume data

  ## Returns
    - List of OBV values, aligned with the input candles
  """
  def obv(candles) do
    # Need at least 2 candles to calculate OBV
    if length(candles) < 2 do
      List.duplicate(nil, length(candles))
    else
      # Initialize OBV with the first candle's volume
      first_candle = hd(candles)
      initial_obv = first_candle.volume

      # Calculate OBV for each candle after the first
      {_, obv_values} =
        candles
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.reduce({initial_obv, [initial_obv]}, fn [prev_candle, curr_candle], {current_obv, results} ->
          new_obv = calculate_new_obv(prev_candle, curr_candle, current_obv)
          {new_obv, [new_obv | results]}
        end)

      # Return OBV values in the same order as input candles
      Enum.reverse(obv_values)
    end
  end

  defp calculate_new_obv(prev_candle, curr_candle, current_obv) do
    cond do
      # Close price increased - add volume
      curr_candle.close > prev_candle.close ->
        current_obv + curr_candle.volume

      # Close price decreased - subtract volume
      curr_candle.close < prev_candle.close ->
        current_obv - curr_candle.volume

      # Close price unchanged - OBV remains the same
      true ->
        current_obv
    end
  end

  @doc """
  Calculates OBV and returns with additional analysis.

  ## Parameters
    - candles: List of candle maps with price and volume data
    - ma_period: Period for OBV moving average (default: 20)

  ## Returns
    - List of maps containing:
      - :obv - OBV value
      - :obv_ma - OBV moving average
      - :signal - Signal based on OBV and its MA (:buy, :sell, or :neutral)
  """
  def analyze(candles, ma_period \\ 20) do
    obv_values = obv(candles)

    # Calculate simple moving average for OBV
    obv_ma = calculate_obv_ma(obv_values, ma_period)

    # Generate signals
    Enum.zip(obv_values, obv_ma)
    |> Enum.with_index()
    |> Enum.map(fn {{obv_value, ma_value}, index} ->
      prev_obv = if index > 0, do: Enum.at(obv_values, index - 1), else: nil
      prev_ma = if index > 0, do: Enum.at(obv_ma, index - 1), else: nil

      signal = generate_signal(obv_value, ma_value, prev_obv, prev_ma)

      %{
        obv: obv_value,
        obv_ma: ma_value,
        signal: signal
      }
    end)
  end

  defp calculate_obv_ma(obv_values, period) do
    # Calculate moving average of OBV
    obv_values
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn window -> Enum.sum(window) / period end)
    |> then(fn ma_values ->
      # Add nil for first period-1 values to align with obv_values
      List.duplicate(nil, min(length(obv_values), period - 1)) ++ ma_values
    end)
  end

  defp generate_signal(obv_value, ma_value, prev_obv, prev_ma) do
    # Not enough data for signals
    if is_nil(obv_value) or is_nil(ma_value) or is_nil(prev_obv) or is_nil(prev_ma) do
      :neutral
    else
      cond do
        # OBV crosses above its MA
        prev_obv < prev_ma and obv_value > ma_value ->
          :buy

        # OBV crosses below its MA
        prev_obv > prev_ma and obv_value < ma_value ->
          :sell

        # OBV and price diverge (bullish)
        obv_value > prev_obv and ma_value > prev_ma ->
          :bullish

        # OBV and price diverge (bearish)
        obv_value < prev_obv and ma_value < prev_ma ->
          :bearish

        # No clear signal
        true ->
          :neutral
      end
    end
  end
end
