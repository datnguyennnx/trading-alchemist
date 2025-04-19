defmodule Central.Backtest.Indicators.Trend.Fractals do
  @moduledoc """
  Implements the Fractals indicator developed by Bill Williams.

  Fractals are indicators that identify potential reversal points in the market.
  A bullish fractal forms when a high is surrounded by lower highs on both sides.
  A bearish fractal forms when a low is surrounded by higher lows on both sides.

  Fractals help identify market structure and potential support/resistance levels.
  They are often used in conjunction with other indicators like Alligator or Awesome Oscillator.

  ## Parameters

  - high: List of high prices
  - low: List of low prices
  - window_size: Number of periods to use for fractal detection (default: 5)

  ## Returns

  A tuple containing:
  - {:ok, %{bullish: bullish_fractals, bearish: bearish_fractals}} on success
  - {:error, reason} on failure

  where bullish_fractals and bearish_fractals are lists of boolean values
  indicating the presence of fractals at each index.
  """

  @doc """
  Calculates Bullish and Bearish Fractals.

  A bullish fractal occurs when a high is higher than 2 highs before it and 2 highs after it.
  A bearish fractal occurs when a low is lower than 2 lows before it and 2 lows after it.

  Returns a map with bullish and bearish fractal indicators.
  """
  def calculate(high, low, window_size \\ 5) do
    with true <- validate_inputs(high, low, window_size),
         bullish <- detect_bullish_fractals(high, window_size),
         bearish <- detect_bearish_fractals(low, window_size) do
      {:ok, %{bullish: bullish, bearish: bearish}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_inputs(high, low, window_size) do
    cond do
      not is_list(high) or not is_list(low) ->
        {:error, "Inputs must be lists"}
      length(high) != length(low) ->
        {:error, "Input lists must have the same length"}
      window_size <= 2 or rem(window_size, 2) == 0 ->
        {:error, "Window size must be an odd number greater than 2"}
      length(high) < window_size ->
        {:error, "Not enough data points for the given window size"}
      true ->
        true
    end
  end

  defp detect_bullish_fractals(high, window_size) do
    radius = div(window_size, 2)

    # Initialize with false values for the first 'radius' elements
    initial_padding = List.duplicate(false, radius)

    # Process all possible windows
    mid_results = high
    |> Enum.chunk_every(window_size, 1, :discard)
    |> Enum.map(fn window ->
      mid_index = div(window_size, 2)
      mid_value = Enum.at(window, mid_index)

      # Check if middle value is higher than all others in the window
      Enum.with_index(window)
      |> Enum.all?(fn {value, index} ->
        index == mid_index or value < mid_value
      end)
    end)

    # Add padding to the end to match original length
    end_padding = List.duplicate(false, radius)

    initial_padding ++ mid_results ++ end_padding
  end

  defp detect_bearish_fractals(low, window_size) do
    radius = div(window_size, 2)

    # Initialize with false values for the first 'radius' elements
    initial_padding = List.duplicate(false, radius)

    # Process all possible windows
    mid_results = low
    |> Enum.chunk_every(window_size, 1, :discard)
    |> Enum.map(fn window ->
      mid_index = div(window_size, 2)
      mid_value = Enum.at(window, mid_index)

      # Check if middle value is lower than all others in the window
      Enum.with_index(window)
      |> Enum.all?(fn {value, index} ->
        index == mid_index or value > mid_value
      end)
    end)

    # Add padding to the end to match original length
    end_padding = List.duplicate(false, radius)

    initial_padding ++ mid_results ++ end_padding
  end

  @doc """
  Extracts the actual price values of fractals.

  Returns a map with:
  - :bullish - List of {index, price} tuples for bullish fractals
  - :bearish - List of {index, price} tuples for bearish fractals
  """
  def extract_fractal_values(%{bullish: bullish, bearish: bearish}, high, low) do
    bullish_values = bullish
    |> Enum.with_index()
    |> Enum.filter(fn {is_fractal, _} -> is_fractal end)
    |> Enum.map(fn {_, index} -> {index, Enum.at(high, index)} end)

    bearish_values = bearish
    |> Enum.with_index()
    |> Enum.filter(fn {is_fractal, _} -> is_fractal end)
    |> Enum.map(fn {_, index} -> {index, Enum.at(low, index)} end)

    %{bullish: bullish_values, bearish: bearish_values}
  end

  @doc """
  Identifies trend structure based on fractal patterns.

  Returns:
  - :uptrend if recent bullish fractals are higher and bearish fractals are higher
  - :downtrend if recent bullish fractals are lower and bearish fractals are lower
  - :sideways if fractal pattern doesn't show a clear trend
  """
  def identify_trend(%{bullish: bullish, bearish: bearish}, lookback \\ 3) do
    # Extract the most recent fractal values
    recent_bullish = Enum.take(bullish, -lookback * 2)
                    |> Enum.filter(fn x -> x end)
                    |> Enum.take(-lookback)

    recent_bearish = Enum.take(bearish, -lookback * 2)
                    |> Enum.filter(fn x -> x end)
                    |> Enum.take(-lookback)

    bullish_increasing = length(recent_bullish) >= 2 and
                        is_list_increasing(recent_bullish)

    bearish_increasing = length(recent_bearish) >= 2 and
                        is_list_increasing(recent_bearish)

    cond do
      bullish_increasing and bearish_increasing ->
        :uptrend
      not bullish_increasing and not bearish_increasing ->
        :downtrend
      true ->
        :sideways
    end
  end

  defp is_list_increasing(list) do
    list
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [a, b] -> b > a end)
  end

  @doc """
  Finds the most recent support and resistance levels based on fractals.

  Returns a map with:
  - :support - List of the most recent support levels from bearish fractals
  - :resistance - List of the most recent resistance levels from bullish fractals
  """
  def find_support_resistance(%{bullish: bullish, bearish: bearish}, high, low, count \\ 3) do
    fractal_values = extract_fractal_values(%{bullish: bullish, bearish: bearish}, high, low)

    support_levels = fractal_values.bearish
                    |> Enum.map(fn {_, price} -> price end)
                    |> Enum.sort(&(&1 > &2))
                    |> Enum.take(count)

    resistance_levels = fractal_values.bullish
                        |> Enum.map(fn {_, price} -> price end)
                        |> Enum.sort(&(&1 < &2))
                        |> Enum.take(count)

    %{support: support_levels, resistance: resistance_levels}
  end
end
