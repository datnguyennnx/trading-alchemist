defmodule Central.Backtest.Indicators.Momentum.ElderRay do
  @moduledoc """
  Implements the Elder-Ray Index indicator.

  The Elder-Ray Index is a technical analysis indicator that measures buying and selling pressure
  in the market. It consists of two components:
  1. Bull Power: The difference between the high price and a 13-period EMA
  2. Bear Power: The difference between the low price and a 13-period EMA

  The indicator helps identify:
  - Bullish divergence (price makes lower low, Bull Power makes higher low)
  - Bearish divergence (price makes higher high, Bear Power makes lower high)
  - Trend strength and direction

  ## Parameters

  - high: List of high prices
  - low: List of low prices
  - period: Number of periods for EMA calculation (default: 13)

  ## Returns

  A tuple containing:
  - {:ok, %{bull_power: bull_power_values, bear_power: bear_power_values}} on success
  - {:error, reason} on failure
  """

  alias Central.Backtest.Indicators.Trend.MovingAverage

  @doc """
  Calculates the Elder-Ray Index.
  """
  def calculate(high, low, period \\ 13) do
    with true <- validate_inputs(high, low, period),
         ema <- MovingAverage.ema(high, period),
         bull_power <- calculate_bull_power(high, ema),
         bear_power <- calculate_bear_power(low, ema) do
      {:ok, %{bull_power: bull_power, bear_power: bear_power}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_inputs(high, low, period) do
    cond do
      not is_list(high) or not is_list(low) ->
        {:error, "Inputs must be lists"}
      length(high) != length(low) ->
        {:error, "Input lists must have the same length"}
      period <= 0 ->
        {:error, "Period must be greater than 0"}
      true ->
        true
    end
  end

  defp calculate_bull_power(high, ema) do
    Enum.zip(high, ema)
    |> Enum.map(fn {h, e} -> h - e end)
  end

  defp calculate_bear_power(low, ema) do
    Enum.zip(low, ema)
    |> Enum.map(fn {l, e} -> l - e end)
  end

  @doc """
  Generates trading signals based on Elder-Ray values.

  Returns:
  - 1 for buy signal (Bull Power crosses above 0)
  - -1 for sell signal (Bear Power crosses below 0)
  - 0 for no signal
  """
  def generate_signals(%{bull_power: bull_power, bear_power: bear_power}) do
    Enum.zip(bull_power, bear_power)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [{prev_bull, _}, {curr_bull, curr_bear}] ->
      cond do
        prev_bull <= 0 and curr_bull > 0 -> 1
        curr_bear < 0 -> -1
        true -> 0
      end
    end)
    |> List.insert_at(0, 0)
  end

  @doc """
  Identifies divergences between price and Elder-Ray components.

  Returns a list of divergence events:
  - {:bullish_divergence, index} when price makes lower low but Bull Power makes higher low
  - {:bearish_divergence, index} when price makes higher high but Bear Power makes lower high
  """
  def find_divergences(high, low, %{bull_power: bull_power, bear_power: bear_power}, lookback \\ 5) do
    Enum.zip([high, low, bull_power, bear_power])
    |> Enum.chunk_every(lookback, 1, :discard)
    |> Enum.with_index()
    |> Enum.flat_map(fn {window, index} ->
      find_divergences_in_window(window, index)
    end)
  end

  defp find_divergences_in_window(window, index) do
    {highs, lows, bull_powers, bear_powers} = Enum.unzip(window)

    all_divergences = []

    # Check for bullish divergence
    all_divergences = if Enum.min(lows) == List.last(lows) and
       Enum.min(bull_powers) != List.last(bull_powers) do
      [{:bullish_divergence, index} | all_divergences]
    else
      all_divergences
    end

    # Check for bearish divergence
    all_divergences = if Enum.max(highs) == List.last(highs) and
       Enum.max(bear_powers) != List.last(bear_powers) do
      [{:bearish_divergence, index} | all_divergences]
    else
      all_divergences
    end

    all_divergences
  end
end
