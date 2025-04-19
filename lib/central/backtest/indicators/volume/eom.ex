defmodule Central.Backtest.Indicators.Volume.Eom do
  @moduledoc """
  Implements the Ease of Movement (EOM) indicator.

  EOM is a volume-based oscillator that relates price change to volume.
  It aims to quantify the "ease" with which price moves, showing how
  much volume is required to move the price.

  The calculation involves:
  1. Calculate the midpoint move (current midpoint - previous midpoint)
  2. Calculate the box ratio (volume / price range)
  3. Calculate EOM = midpoint move / box ratio
  4. Apply smoothing with a moving average

  ## Parameters

  - high: List of high prices
  - low: List of low prices
  - volume: List of volume values
  - period: Number of periods for smoothing (default: 14)
  - divisor: Volume divisor for scaling (default: 10000)

  ## Returns

  A tuple containing:
  - {:ok, eom_values} on success
  - {:error, reason} on failure
  """

  alias Central.Backtest.Indicators.Trend.MovingAverage

  @doc """
  Calculates the Ease of Movement indicator.
  """
  def calculate(high, low, volume, period \\ 14, divisor \\ 10000) do
    with true <- validate_inputs(high, low, volume, period),
         raw_eom <- calculate_raw_eom(high, low, volume, divisor),
         smoothed_eom <- MovingAverage.sma(raw_eom, period) do
      {:ok, smoothed_eom}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_inputs(high, low, volume, period) do
    cond do
      not is_list(high) or not is_list(low) or not is_list(volume) ->
        {:error, "Inputs must be lists"}
      length(high) != length(low) or length(low) != length(volume) ->
        {:error, "Input lists must have the same length"}
      period <= 0 ->
        {:error, "Period must be greater than 0"}
      true ->
        true
    end
  end

  defp calculate_raw_eom(high, low, volume, divisor) do
    calculate_midpoints(high, low)
    |> calculate_midpoint_moves()
    |> Enum.zip(calculate_box_ratios(high, low, volume, divisor))
    |> Enum.map(fn {midpoint_move, box_ratio} ->
      if box_ratio == 0, do: 0, else: midpoint_move / box_ratio
    end)
  end

  defp calculate_midpoints(high, low) do
    Enum.zip(high, low)
    |> Enum.map(fn {h, l} -> (h + l) / 2 end)
  end

  defp calculate_midpoint_moves(midpoints) do
    midpoints
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, curr] -> curr - prev end)
    |> List.insert_at(0, 0)
  end

  defp calculate_box_ratios(high, low, volume, divisor) do
    Enum.zip([high, low, volume])
    |> Enum.map(fn {h, l, v} ->
      case h - l do
        0 -> 0
        range -> (v / divisor) / range
      end
    end)
  end

  @doc """
  Generates trading signals based on EOM values.

  Returns:
  - 1 for buy signal (EOM crosses above zero)
  - -1 for sell signal (EOM crosses below zero)
  - 0 for no signal
  """
  def generate_signals(eom) do
    eom
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, curr] ->
      cond do
        prev <= 0 and curr > 0 -> 1
        prev >= 0 and curr < 0 -> -1
        true -> 0
      end
    end)
    |> List.insert_at(0, 0)
  end

  @doc """
  Calculates EOM with velocity components separated.

  Returns a map with keys:
  - :eom - The standard EOM values
  - :distance - The midpoint move component
  - :volume_factor - The volume/range component

  This is useful for more detailed analysis of price movement vs volume.
  """
  def calculate_with_components(high, low, volume, period \\ 14, divisor \\ 10000) do
    midpoints = calculate_midpoints(high, low)
    midpoint_moves = calculate_midpoint_moves(midpoints)

    box_ratios = calculate_box_ratios(high, low, volume, divisor)

    raw_eom = Enum.zip(midpoint_moves, box_ratios)
    |> Enum.map(fn {midpoint_move, box_ratio} ->
      if box_ratio == 0, do: 0, else: midpoint_move / box_ratio
    end)

    smoothed_eom = MovingAverage.sma(raw_eom, period)
    smoothed_distance = MovingAverage.sma(midpoint_moves, period)
    smoothed_volume_factor = MovingAverage.sma(box_ratios, period)

    {:ok, %{
      eom: smoothed_eom,
      distance: smoothed_distance,
      volume_factor: smoothed_volume_factor
    }}
  end

  @doc """
  Analyzes EOM values to identify high-probability price moves.

  Returns a list of potential trading opportunities with their index.
  """
  def analyze_trends(eom, lookback \\ 5, threshold \\ 0.5) do
    eom
    |> Enum.chunk_every(lookback, 1, :discard)
    |> Enum.with_index()
    |> Enum.filter(fn {window, _} ->
      avg = Enum.sum(window) / length(window)
      if abs(avg) > threshold do
        avg > 0 and Enum.all?(window, fn x -> x > 0 end) or
        avg < 0 and Enum.all?(window, fn x -> x < 0 end)
      else
        false
      end
    end)
    |> Enum.map(fn {window, index} ->
      avg = Enum.sum(window) / length(window)
      type = if avg > 0, do: :bullish, else: :bearish
      {type, index, abs(avg)}
    end)
  end
end
