defmodule Central.Backtest.Indicators.Calculations.ListOperations do
  @moduledoc """
  List processing utilities for technical indicators.
  """

  @doc """
  Extracts a specific key from each map in a list.

  ## Parameters
    - candles: List of maps/candles
    - key: The key to extract from each map

  ## Returns
    - List of values
  """
  def extract_key(candles, key) when is_list(candles) do
    Enum.map(candles, &Map.get(&1, key))
  end

  @doc """
  Calculates price changes between consecutive values.

  ## Returns
    - List of changes (length is one less than input)
  """
  def calculate_changes(prices) when is_list(prices) do
    Enum.zip(Enum.drop(prices, 1), prices)
    |> Enum.map(fn {current, previous} -> Decimal.sub(current, previous) end)
  end

  @doc """
  Separates a list of price changes into gains and losses.

  ## Returns
    - Tuple of {gains, losses} lists
  """
  def separate_gains_losses(changes) when is_list(changes) do
    Enum.map(changes, fn change ->
      cond do
        Decimal.compare(change, Decimal.new(0)) == :gt ->
          {change, Decimal.new(0)}
        Decimal.compare(change, Decimal.new(0)) == :lt ->
          {Decimal.new(0), Decimal.abs(change)}
        true ->
          {Decimal.new(0), Decimal.new(0)}
      end
    end)
    |> Enum.unzip()
  end

  @doc """
  Unzips a list of 3-element tuples into 3 separate lists.

  ## Parameters
    - list: List of 3-element tuples {a, b, c}

  ## Returns
    - Tuple with 3 lists {[a1, a2, ...], [b1, b2, ...], [c1, c2, ...]}
  """
  def unzip3(list) when is_list(list) do
    {first_elements, second_elements, third_elements} =
      Enum.reduce(list, {[], [], []}, fn {a, b, c}, {as, bs, cs} ->
        {[a | as], [b | bs], [c | cs]}
      end)

    {Enum.reverse(first_elements), Enum.reverse(second_elements), Enum.reverse(third_elements)}
  end
end
