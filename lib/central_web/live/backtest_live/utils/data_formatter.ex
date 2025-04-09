defmodule CentralWeb.BacktestLive.Utils.DataFormatter do
  require Logger

  @doc """
  Format market data for chart display.
  Converts database records to the format expected by TradingView chart.
  """
  def format_market_data(candles) do
    # Order by timestamp ascending to ensure proper chart display
    sorted_candles = Enum.sort_by(candles, & &1.timestamp, {:asc, DateTime})

    # Log sample data to debug
    if length(sorted_candles) > 0 do
      first = List.first(sorted_candles)
      last = List.last(sorted_candles)
      Logger.debug("First candle timestamp: #{inspect(first.timestamp)}")
      Logger.debug("Last candle timestamp: #{inspect(last.timestamp)}")
    end

    formatted =
      Enum.map(sorted_candles, fn candle ->
        time = DateTime.to_unix(candle.timestamp)

        %{
          # Ensure this is a Unix timestamp in seconds
          time: time,
          open: to_float(candle.open),
          high: to_float(candle.high),
          low: to_float(candle.low),
          close: to_float(candle.close),
          volume: (candle.volume && to_float(candle.volume)) || 0.0
        }
      end)

    # Log the formatted data structure
    if length(formatted) > 0 do
      first_formatted = List.first(formatted)
      last_formatted = List.last(formatted)
      Logger.debug("First formatted candle: #{inspect(first_formatted)}")
      Logger.debug("Last formatted candle: #{inspect(last_formatted)}")
      Logger.debug("Total formatted candles: #{length(formatted)}")
    end

    formatted
  end

  @doc """
  Another name for format_market_data, for consistent API.
  """
  def format_chart_data(candles), do: format_market_data(candles)

  @doc """
  Helper to safely convert Decimal to float
  """
  def to_float(nil), do: 0.0
  def to_float(%Decimal{} = decimal), do: Decimal.to_float(decimal)
  def to_float(number) when is_number(number), do: number
  def to_float(_), do: 0.0

  @doc """
  Format price for display in UI
  """
  def format_price(nil), do: "--"

  def format_price(price) when price >= 1000,
    do: "$#{:erlang.float_to_binary(price, decimals: 2)}"

  def format_price(price) when price >= 1, do: "$#{:erlang.float_to_binary(price, decimals: 2)}"
  def format_price(price), do: "$#{:erlang.float_to_binary(price, decimals: 4)}"

  @doc """
  Get formatted timeframe display name
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
  Get the latest price from the chart data for the specified key
  """
  def get_latest_price(chart_data, key) do
    case List.last(chart_data) do
      nil -> nil
      data -> Map.get(data, key)
    end
  end
end
