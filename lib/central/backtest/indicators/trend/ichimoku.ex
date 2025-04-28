defmodule Central.Backtest.Indicators.Trend.Ichimoku do
  @moduledoc """
  Implements the Ichimoku Cloud (Ichimoku Kinko Hyo) indicator.

  The Ichimoku Cloud is a comprehensive indicator that defines support and resistance,
  identifies trend direction, measures momentum and provides trading signals.
  """

  alias Central.Backtest.Indicators.Calculations.ListOperations

  @doc """
  Calculates the Ichimoku Cloud components.

  ## Parameters
    - candles: List of market data candles
    - tenkan_period: Period for Tenkan-sen (Conversion Line) (typically 9)
    - kijun_period: Period for Kijun-sen (Base Line) (typically 26)
    - senkou_span_b_period: Period for Senkou Span B (typically 52)
    - displacement: Displacement for Senkou Span A and B (typically 26)

  ## Returns
    - List of maps containing Ichimoku values aligned with input candles:
      %{
        tenkan_sen: value,
        kijun_sen: value,
        senkou_span_a: value,
        senkou_span_b: value,
        chikou_span: value
      }
  """
  def ichimoku(
        candles,
        tenkan_period \\ 9,
        kijun_period \\ 26,
        senkou_span_b_period \\ 52,
        displacement \\ 26
      )
      when is_list(candles) and length(candles) > senkou_span_b_period do
    # Extract high and low prices
    highs = ListOperations.extract_key(candles, :high)
    lows = ListOperations.extract_key(candles, :low)
    closes = ListOperations.extract_key(candles, :close)

    # Calculate each component
    tenkan_sen = calculate_ichimoku_line(highs, lows, tenkan_period)
    kijun_sen = calculate_ichimoku_line(highs, lows, kijun_period)

    # Calculate Senkou Span A (avg of Tenkan and Kijun)
    senkou_span_a =
      Enum.zip(tenkan_sen, kijun_sen)
      |> Enum.map(fn
        {nil, _} ->
          nil

        {_, nil} ->
          nil

        {tenkan, kijun} ->
          Decimal.div(Decimal.add(tenkan, kijun), Decimal.new(2))
      end)
      |> displace_forward(displacement)

    # Calculate Senkou Span B
    senkou_span_b =
      calculate_ichimoku_line(highs, lows, senkou_span_b_period)
      |> displace_forward(displacement)

    # Calculate Chikou Span (close displaced backwards)
    chikou_span = displace_backward(closes, displacement)

    # Zip all components and create result maps
    max_length = length(candles)

    components = [
      pad_to_length(tenkan_sen, max_length),
      pad_to_length(kijun_sen, max_length),
      pad_to_length(senkou_span_a, max_length),
      pad_to_length(senkou_span_b, max_length),
      pad_to_length(chikou_span, max_length)
    ]

    Enum.zip(components)
    |> Enum.map(fn
      {nil, _, _, _, _} ->
        nil

      {_, nil, _, _, _} ->
        nil

      {_, _, nil, _, _} ->
        nil

      {_, _, _, nil, _} ->
        nil

      {_, _, _, _, nil} ->
        nil

      {tenkan, kijun, span_a, span_b, chikou} ->
        %{
          tenkan_sen: tenkan,
          kijun_sen: kijun,
          senkou_span_a: span_a,
          senkou_span_b: span_b,
          chikou_span: chikou
        }
    end)
  end

  # Calculates a single Ichimoku line (Tenkan, Kijun, or Senkou Span B)
  defp calculate_ichimoku_line(highs, lows, period) when length(highs) >= period do
    highs_chunks = Enum.chunk_every(highs, period, 1, :discard)
    lows_chunks = Enum.chunk_every(lows, period, 1, :discard)

    Enum.zip(highs_chunks, lows_chunks)
    |> Enum.map(fn {high_chunk, low_chunk} ->
      highest_high = Enum.max_by(high_chunk, &Decimal.to_float/1)
      lowest_low = Enum.min_by(low_chunk, &Decimal.to_float/1)

      # (highest_high + lowest_low) / 2
      Decimal.div(
        Decimal.add(highest_high, lowest_low),
        Decimal.new(2)
      )
    end)
  end

  # Displace a list forward by the specified periods (adds nils at the beginning, drops from end)
  defp displace_forward(values, periods) when length(values) > periods do
    displaced = List.duplicate(nil, periods) ++ Enum.take(values, length(values) - periods)
    displaced
  end

  # Displace a list backward by the specified periods (adds nils at the end, drops from beginning)
  defp displace_backward(values, periods) when length(values) > periods do
    displaced = Enum.drop(values, periods) ++ List.duplicate(nil, periods)
    displaced
  end

  # Pad a list to a specific length with nils
  defp pad_to_length(list, length) when length(list) < length do
    list ++ List.duplicate(nil, length - length(list))
  end

  defp pad_to_length(list, length) when length(list) > length do
    Enum.take(list, length)
  end

  defp pad_to_length(list, _length), do: list
end
