defmodule CentralWeb.Live.Components.Chart.ChartDataFormatter do
  @moduledoc """
  Provides utility functions for formatting data specifically for chart display.

  Responsibilities:
  - Converting candle data (typically from `MarketDataContext` structs with Decimals)
    into the list of maps format required by the Lightweight Charts library
    (using UNIX timestamps and float values).
  - Extracting specific price points (e.g., latest close) from formatted chart data.
  - Formatting price values, timeframes, and percentages for display elsewhere
    in the UI (like chart stats or tooltips), including applying appropriate
    CSS classes for positive/negative values.

  This module focuses purely on transformation and does not fetch data.
  """

  alias Central.Backtest.Utils.DecimalUtils

  @doc """
  Format market data for chart display.

  ## Parameters
    - candles: List of market data candles

  ## Returns
    List of formatted candles for chart display, matching Lightweight Charts CandlestickData format.
  """
  def format_chart_data(candles) do
    Enum.map(candles, fn candle ->
      # Convert Decimal values to floats and format exactly as needed
      %{
        time: DateTime.to_unix(candle.timestamp),
        open: decimal_to_float(candle.open),
        high: decimal_to_float(candle.high),
        low: decimal_to_float(candle.low),
        close: decimal_to_float(candle.close)
        # Removed volume as it's not in the core CandlestickData type example
      }
    end)
  end

  @doc """
  Gets the price of a specific OHLC field from the latest candle in the chart data.

  ## Parameters
    - chart_data: List of formatted chart candles
    - field: Field to extract (:open, :high, :low, :close)

  ## Returns
    The price value or nil if no data
  """
  def get_latest_price(chart_data, field) when is_list(chart_data) and length(chart_data) > 0 do
    # Find the latest candle (highest timestamp)
    latest_candle =
      Enum.reduce(chart_data, List.first(chart_data), fn candle, latest ->
        if candle.time > latest.time, do: candle, else: latest
      end)

    case field do
      :open -> latest_candle.open
      :high -> latest_candle.high
      :low -> latest_candle.low
      :close -> latest_candle.close
      _ -> nil
    end
  end

  def get_latest_price(_chart_data, _field), do: nil

  @doc """
  Format price value for display.

  ## Parameters
    - price: The price to format
    - precision: Number of decimal places (default: auto)

  ## Returns
    Formatted price string with $ symbol
  """
  def format_price(nil), do: "-"
  def format_price(price, precision \\ nil) do
    precision = precision || auto_precision(price)
    "$#{DecimalUtils.format(price, precision)}"
  end

  @doc """
  Format a timeframe for display.

  ## Parameters
    - timeframe: Timeframe string (e.g. "1h")

  ## Returns
    Human-readable timeframe
  """
  def timeframe_display(timeframe) do
    case timeframe do
      "1m" -> "1 Minute"
      "5m" -> "5 Minutes"
      "15m" -> "15 Minutes"
      "1h" -> "1 Hour"
      "4h" -> "4 Hours"
      "1d" -> "1 Day"
      _ -> timeframe
    end
  end

  @doc """
  Format a value with a CSS color class based on its sign.

  ## Parameters
    - value: The value to evaluate

  ## Returns
    CSS class name for coloring based on sign
  """
  def color_class(value) do
    cond do
      DecimalUtils.positive?(value) -> "text-green-600"
      DecimalUtils.negative?(value) -> "text-red-600"
      true -> ""
    end
  end

  @doc """
  Format a value with a sign prefix and CSS color.

  ## Parameters
    - value: The value to format
    - precision: Number of decimal places

  ## Returns
    Map with formatted value and CSS class
  """
  def format_with_color(value, precision \\ 2) do
    formatted = DecimalUtils.format(value, precision)

    formatted =
      if DecimalUtils.positive?(value) do
        "+#{formatted}"
      else
        formatted
      end

    %{
      value: formatted,
      class: color_class(value)
    }
  end

  @doc """
  Format a percentage with a sign prefix and CSS color.

  ## Parameters
    - value: The percentage value to format (0.1 = 10%)
    - precision: Number of decimal places

  ## Returns
    Map with formatted value and CSS class
  """
  def format_percent_with_color(value, precision \\ 2) do
    formatted = DecimalUtils.format_percent(value, precision)

    formatted =
      if DecimalUtils.positive?(value) and not DecimalUtils.zero?(value) do
        "+#{formatted}"
      else
        formatted
      end

    %{
      value: formatted,
      class: color_class(value)
    }
  end

  # Private Helpers

  defp auto_precision(price) do
    price_float = DecimalUtils.to_float(price)

    cond do
      is_nil(price_float) -> 2
      price_float >= 10000 -> 2
      price_float >= 1000 -> 2
      price_float >= 100 -> 2
      price_float >= 10 -> 3
      price_float >= 1 -> 4
      price_float >= 0.1 -> 5
      price_float >= 0.01 -> 6
      price_float >= 0.001 -> 7
      true -> 8
    end
  end

  # Helper to safely convert Decimal to float
  defp decimal_to_float(%Decimal{} = decimal), do: Decimal.to_float(decimal)
  defp decimal_to_float(value) when is_float(value), do: value
  defp decimal_to_float(value) when is_integer(value), do: value / 1
  defp decimal_to_float(_), do: 0.0
end
