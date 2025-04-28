defmodule Central.Backtest.Indicators.Volume.NviPvi do
  @moduledoc """
  Implements Negative Volume Index (NVI) and Positive Volume Index (PVI).

  NVI and PVI are volume-based indicators designed to identify "smart money" activity.
  - NVI focuses on price changes when volume decreases (supposedly smart money activity)
  - PVI focuses on price changes when volume increases (supposedly public activity)

  The calculation involves:
  1. Compare current volume with previous volume
  2. For NVI: Only add price percentage change when volume decreases
  3. For PVI: Only add price percentage change when volume increases
  4. Cumulate the index values, starting from an initial base value (typically 1000)

  ## Parameters

  - prices: List of price values (typically closing prices)
  - volume: List of volume data
  - initial_value: Starting index value (default: 1000)

  ## Returns

  A tuple containing:
  - {:ok, {nvi, pvi}} on success
  - {:error, reason} on failure

  ## Notes

  - NVI tends to lead market movements and is considered a better signal generator
  - A rising NVI suggests smart money accumulation
  - PVI tends to follow market movements and shows public participation
  - Comparing NVI and PVI can identify market phases (smart money vs. public participation)
  """

  @doc """
  Calculates Negative Volume Index (NVI) and Positive Volume Index (PVI).
  """
  def calculate(prices, volume, initial_value \\ 1000) do
    with true <- validate_inputs(prices, volume) do
      {nvi, pvi} = calculate_indices(prices, volume, initial_value)
      {:ok, {nvi, pvi}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_inputs(prices, volume) do
    cond do
      not (is_list(prices) and is_list(volume)) ->
        {:error, "Prices and volume must be lists"}

      length(prices) != length(volume) ->
        {:error, "Prices and volume must have the same length"}

      length(prices) < 2 ->
        {:error, "At least 2 data points are required"}

      true ->
        true
    end
  end

  defp calculate_indices(prices, volume, initial_value) do
    # Prepare data for comparison (current and previous values)
    volume_pairs = Enum.chunk_every(volume, 2, 1, :discard)
    price_pairs = Enum.chunk_every(prices, 2, 1, :discard)

    # Calculate daily percentage price changes
    price_changes =
      Enum.map(price_pairs, fn [prev, curr] ->
        if prev == 0, do: 0, else: (curr - prev) / prev
      end)

    # Determine volume direction (increase or decrease)
    volume_directions =
      Enum.map(volume_pairs, fn [prev, curr] ->
        cond do
          curr > prev -> :increase
          curr < prev -> :decrease
          true -> :unchanged
        end
      end)

    # Calculate NVI and PVI
    {nvi_values, pvi_values} =
      Enum.zip([price_changes, volume_directions])
      |> Enum.reduce({[initial_value], [initial_value]}, fn {price_change, volume_dir},
                                                            {nvi_acc, pvi_acc} ->
        current_nvi = List.first(nvi_acc)
        current_pvi = List.first(pvi_acc)

        # Update NVI only when volume decreases
        new_nvi =
          case volume_dir do
            :decrease -> current_nvi * (1 + price_change)
            _ -> current_nvi
          end

        # Update PVI only when volume increases
        new_pvi =
          case volume_dir do
            :increase -> current_pvi * (1 + price_change)
            _ -> current_pvi
          end

        {[new_nvi | nvi_acc], [new_pvi | pvi_acc]}
      end)

    # Reverse lists and add initial values for the first data point
    nvi_result = [initial_value | Enum.reverse(nvi_values)]
    pvi_result = [initial_value | Enum.reverse(pvi_values)]

    {nvi_result, pvi_result}
  end

  @doc """
  Applies a signal line (EMA) to NVI and PVI for signal generation.

  Returns:
  - {:ok, {nvi_signal, pvi_signal}} on success
  - {:error, reason} on failure
  """
  def calculate_signal_lines({nvi, pvi}, period \\ 255) do
    with {:ok, nvi_signal} <-
           Central.Backtest.Indicators.Trend.ExponentialMovingAverage.calculate(nvi, period),
         {:ok, pvi_signal} <-
           Central.Backtest.Indicators.Trend.ExponentialMovingAverage.calculate(pvi, period) do
      {:ok, {nvi_signal, pvi_signal}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generates trading signals based on NVI and PVI.

  Returns a list of tuples containing:
  - {1, 0} for NVI buy signal, no PVI signal
  - {0, 1} for PVI buy signal, no NVI signal
  - {1, 1} for both NVI and PVI buy signals
  - {-1, 0} for NVI sell signal, no PVI signal
  - {0, -1} for PVI sell signal, no NVI signal
  - {-1, -1} for both NVI and PVI sell signals
  - {0, 0} for no signals
  """
  def generate_signals({nvi, pvi}, {nvi_signal, pvi_signal}) do
    Enum.zip([nvi, pvi, nvi_signal, pvi_signal])
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [
                     {prev_nvi, prev_pvi, prev_nvi_signal, prev_pvi_signal},
                     {curr_nvi, curr_pvi, curr_nvi_signal, curr_pvi_signal}
                   ] ->
      # Generate NVI signals
      nvi_signal =
        cond do
          # Bullish
          prev_nvi < prev_nvi_signal and curr_nvi > curr_nvi_signal -> 1
          # Bearish
          prev_nvi > prev_nvi_signal and curr_nvi < curr_nvi_signal -> -1
          # No signal
          true -> 0
        end

      # Generate PVI signals
      pvi_signal =
        cond do
          # Bullish
          prev_pvi < prev_pvi_signal and curr_pvi > curr_pvi_signal -> 1
          # Bearish
          prev_pvi > prev_pvi_signal and curr_pvi < curr_pvi_signal -> -1
          # No signal
          true -> 0
        end

      {nvi_signal, pvi_signal}
    end)
    |> pad_with_no_signal(length(nvi))
  end

  @doc """
  Identifies divergences between NVI and PVI to detect market phase changes.

  Returns a list of market phase events:
  - {:smart_money_accumulation, index} when NVI rises but PVI is flat/falling
  - {:smart_money_distribution, index} when NVI falls but PVI is flat/rising
  - {:public_participation, index} when PVI rises strongly while NVI rises moderately
  - {:market_top, index} when PVI rises strongly but NVI is falling
  """
  def identify_market_phases({nvi, pvi}, lookback \\ 20) do
    Enum.zip(nvi, pvi)
    |> Enum.chunk_every(lookback, 1, :discard)
    |> Enum.with_index(lookback - 1)
    |> Enum.flat_map(fn {chunk, index} ->
      {nvi_values, pvi_values} = Enum.unzip(chunk)

      # Calculate percentage changes over the lookback period
      nvi_first = List.first(nvi_values)
      nvi_last = List.last(nvi_values)
      pvi_first = List.first(pvi_values)
      pvi_last = List.last(pvi_values)

      nvi_change = if nvi_first == 0, do: 0, else: (nvi_last - nvi_first) / nvi_first * 100
      pvi_change = if pvi_first == 0, do: 0, else: (pvi_last - pvi_first) / pvi_first * 100

      # Identify market phases
      cond do
        nvi_change > 2.0 and pvi_change < 0.5 ->
          [{:smart_money_accumulation, index}]

        nvi_change < -2.0 and pvi_change > -0.5 ->
          [{:smart_money_distribution, index}]

        pvi_change > 5.0 and nvi_change > 0 and nvi_change < pvi_change / 2 ->
          [{:public_participation, index}]

        pvi_change > 5.0 and nvi_change < 0 ->
          [{:market_top, index}]

        true ->
          []
      end
    end)
  end

  defp pad_with_no_signal(signals, original_length) do
    padding_length = original_length - length(signals) - 1
    padding = List.duplicate({0, 0}, padding_length)
    padding ++ [{0, 0}] ++ signals
  end
end
