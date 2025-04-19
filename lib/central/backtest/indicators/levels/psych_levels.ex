defmodule Central.Backtest.Indicators.Levels.PsychLevels do
  @moduledoc """
  Implements Psychological Level analysis for price action trading.

  Psychological levels are price points that hold particular psychological importance
  to traders, such as round numbers (e.g., 1000, 1500) or other significant levels.
  These levels often act as support and resistance due to increased attention from market participants.
  """

  @doc """
  Identifies psychological levels based on a given price range.

  ## Parameters
    - start_price: The starting price point
    - end_price: The ending price point
    - increment: The increment between levels (e.g., 10, 100, 1000)
    - include_halves: Whether to include half levels (e.g., 50, 150, 250)
    - include_quarters: Whether to include quarter levels (e.g., 25, 75, 125, 175)

  ## Returns
    - List of psychological levels within the given range
  """
  def identify_levels(start_price, end_price, increment \\ 100, include_halves \\ true, include_quarters \\ false)

  def identify_levels(start_price, end_price, increment, include_halves, include_quarters)
    when is_number(increment) and increment > 0 do

    # Convert to Decimal for consistent handling
    decimal_start = to_decimal(start_price)
    decimal_end = to_decimal(end_price)
    decimal_increment = to_decimal(increment)

    do_identify_levels(decimal_start, decimal_end, decimal_increment, include_halves, include_quarters)
  end

  def identify_levels(start_price, end_price, %Decimal{} = increment, include_halves, include_quarters) do
    # Check if increment is positive
    if Decimal.compare(increment, Decimal.new(0)) != :gt do
      raise ArgumentError, "increment must be greater than 0"
    end

    # Convert to Decimal for consistent handling
    decimal_start = to_decimal(start_price)
    decimal_end = to_decimal(end_price)

    do_identify_levels(decimal_start, decimal_end, increment, include_halves, include_quarters)
  end

  # Internal implementation after guard clauses are handled
  defp do_identify_levels(decimal_start, decimal_end, decimal_increment, include_halves, include_quarters) do
    # Ensure start is smaller than end
    {min_price, max_price} = if Decimal.compare(decimal_start, decimal_end) == :gt do
      {decimal_end, decimal_start}
    else
      {decimal_start, decimal_end}
    end

    # Find the first level at or above the min price
    first_level = find_first_level(min_price, decimal_increment)

    # Generate whole number levels
    levels = generate_levels(first_level, max_price, decimal_increment)

    # Add half levels if requested
    levels_with_halves =
      if include_halves do
        half_increment = Decimal.div(decimal_increment, Decimal.new(2))
        half_first = Decimal.add(first_level, half_increment)

        half_levels = generate_levels(half_first, max_price, decimal_increment)
        Enum.sort_by(levels ++ half_levels, &Decimal.to_float/1)
      else
        levels
      end

    # Add quarter levels if requested
    if include_quarters do
      quarter_increment = Decimal.div(decimal_increment, Decimal.new(4))
      quarter_first = Decimal.add(first_level, quarter_increment)
      three_quarter_first = Decimal.add(first_level, Decimal.mult(quarter_increment, Decimal.new(3)))

      quarter_levels = generate_levels(quarter_first, max_price, decimal_increment)
      three_quarter_levels = generate_levels(three_quarter_first, max_price, decimal_increment)

      Enum.sort_by(levels_with_halves ++ quarter_levels ++ three_quarter_levels, &Decimal.to_float/1)
    else
      levels_with_halves
    end
  end

  @doc """
  Identifies the nearest psychological levels to a given price.

  ## Parameters
    - current_price: The current price
    - levels: List of psychological levels, typically from identify_levels/5
    - count: Number of nearest levels to find (half above, half below)

  ## Returns
    - Map with two lists: %{above: [...], below: [...]}
  """
  def nearest_levels(current_price, levels, count \\ 4) when is_list(levels) and is_integer(count) and count > 0 do
    decimal_price = to_decimal(current_price)

    # Split levels into those above and below the current price
    {levels_below, levels_above} = Enum.split_with(levels, fn level ->
      Decimal.compare(level, decimal_price) == :lt
    end)

    # Sort levels by distance from current price
    sorted_below = Enum.sort_by(levels_below, fn level ->
      Decimal.sub(decimal_price, level) |> Decimal.abs() |> Decimal.to_float()
    end)

    sorted_above = Enum.sort_by(levels_above, fn level ->
      Decimal.sub(level, decimal_price) |> Decimal.abs() |> Decimal.to_float()
    end)

    # Take the nearest levels
    half_count = div(count, 2)
    nearest_below = Enum.take(sorted_below, half_count)
    nearest_above = Enum.take(sorted_above, half_count)

    %{
      below: nearest_below,
      above: nearest_above
    }
  end

  @doc """
  Analyzes the strength of psychological levels based on historical touches.

  ## Parameters
    - candles: List of market data candles
    - levels: List of psychological levels
    - touch_margin: Margin for considering a level touched (e.g., 0.001 for 0.1%)

  ## Returns
    - List of maps with level and strength score
  """
  def analyze_strength(candles, levels, touch_margin \\ 0.001) do
    # Convert margin to Decimal
    decimal_margin = to_decimal(touch_margin)

    # Count touches for each level
    level_touches = Enum.map(levels, fn level ->
      touches = count_touches(candles, level, decimal_margin)

      # Calculate "bounces" (price reversal after approaching the level)
      bounces = count_bounces(candles, level, decimal_margin)

      # Calculate strength score (touches + 2*bounces)
      strength = touches + (2 * bounces)

      %{
        level: level,
        touches: touches,
        bounces: bounces,
        strength: strength
      }
    end)

    # Sort by strength in descending order
    Enum.sort_by(level_touches, fn %{strength: strength} -> -strength end)
  end

  # Helper functions

  # Convert various types to Decimal
  defp to_decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp to_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp to_decimal(%Decimal{} = value), do: value

  # Find the first level at or above a given price
  defp find_first_level(price, increment) do
    # Calculate how many increments fit into the price
    divisions = Decimal.div_int(price, increment)

    # Multiply by increment to get the base level
    base_level = Decimal.mult(divisions, increment)

    # If base_level is less than price, add one increment
    if Decimal.compare(base_level, price) == :lt do
      Decimal.add(base_level, increment)
    else
      base_level
    end
  end

  # Generate levels from start to end with a given increment
  defp generate_levels(start, end_price, increment) do
    # Maximum iterations to prevent infinite loops
    max_iterations = 1000

    Stream.iterate(start, fn level -> Decimal.add(level, increment) end)
    |> Stream.take_while(fn level ->
      Decimal.compare(level, end_price) != :gt
    end)
    |> Enum.take(max_iterations)
  end

  # Count how many times price approached a level
  defp count_touches(candles, level, margin) do
    # Calculate margin bands
    upper_band = Decimal.mult(level, Decimal.add(Decimal.new(1), margin))
    lower_band = Decimal.mult(level, Decimal.sub(Decimal.new(1), margin))

    # Count candles where the price touched the level
    Enum.count(candles, fn candle ->
      # Check if any part of the candle touched the level band
      (Decimal.compare(candle.high, lower_band) == :gt and Decimal.compare(candle.high, upper_band) == :lt) or
      (Decimal.compare(candle.low, lower_band) == :gt and Decimal.compare(candle.low, upper_band) == :lt) or
      (Decimal.compare(candle.close, lower_band) == :gt and Decimal.compare(candle.close, upper_band) == :lt) or
      (Decimal.compare(candle.open, lower_band) == :gt and Decimal.compare(candle.open, upper_band) == :lt)
    end)
  end

  # Count bounces (price reversals after touching a level)
  defp count_bounces(candles, level, margin) do
    # Calculate margin bands
    upper_band = Decimal.mult(level, Decimal.add(Decimal.new(1), margin))
    lower_band = Decimal.mult(level, Decimal.sub(Decimal.new(1), margin))

    # Analyze consecutive candles for reversals
    Enum.chunk_every(candles, 3, 1, :discard)
    |> Enum.count(fn [before_candle, current_candle, next_candle] ->
      # Check if price approached the level
      approached =
        (Decimal.compare(current_candle.high, lower_band) == :gt and Decimal.compare(current_candle.high, upper_band) == :lt) or
        (Decimal.compare(current_candle.low, lower_band) == :gt and Decimal.compare(current_candle.low, upper_band) == :lt)

      if approached do
        # Check if price was moving toward the level and then reversed
        coming_from_above = Decimal.compare(before_candle.close, level) == :gt
        coming_from_below = Decimal.compare(before_candle.close, level) == :lt

        reversed_up = Decimal.compare(next_candle.close, current_candle.close) == :gt
        reversed_down = Decimal.compare(next_candle.close, current_candle.close) == :lt

        (coming_from_above and reversed_down) or (coming_from_below and reversed_up)
      else
        false
      end
    end)
  end
end
