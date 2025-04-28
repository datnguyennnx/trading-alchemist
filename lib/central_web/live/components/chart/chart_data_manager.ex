defmodule CentralWeb.Live.Components.Chart.ChartDataManager do
  @moduledoc """
  Manages chart data loading and processing, primarily for generic (non-backtest) charts.

  This module acts as a facade between chart components/LiveViews and the underlying
  data context (`MarketDataContext`) and formatter (`ChartDataFormatter`).

  Responsibilities:
  - `load_chart_data/3`: Fetches an initial batch of candle data for a given symbol/timeframe,
    typically used when a generic chart first loads. It calculates the appropriate
    time range based on limits or provided start/end times.
  - `load_historical_data/4`: Fetches older batches of candle data for infinite scrolling,
    calculating the time range based on the oldest visible candle and batch size.
  - Interacts with `MarketDataContext` to retrieve candle data from the database.
  - Uses `ChartDataFormatter` to format the retrieved candles into the format required
    by the chart's JavaScript hook.
  - Determines if more historical data is likely available (`has_more`).

  It is generally used by LiveViews that display standard market charts, whereas
  `BacktestChartComponent` handles its own data loading tailored to the backtest context.
  """

  require Logger

  alias Central.Backtest.Contexts.MarketDataContext
  alias CentralWeb.Live.Components.Chart.ChartDataFormatter
  alias Central.Helpers.TimeframeHelper

  @doc """
  Load generic chart data for a given symbol and timeframe.

  ## Parameters
    - symbol: Trading pair symbol (e.g., "BTCUSDT")
    - timeframe: Candle timeframe (e.g., "1h")
    - opts: Optional parameters
      - limit: Maximum number of candles to fetch (default: 500)
      - end_time: End time for fetching data (defaults to now)
      - start_time: Explicitly set start time (overrides limit calculation)

  ## Returns
    List of formatted candles for chart display
  """
  def load_chart_data(symbol, timeframe, opts \\ []) do
    Logger.debug("[ChartDataManager] load_chart_data called with: symbol=#{inspect symbol}, timeframe=#{inspect timeframe}, opts=#{inspect opts}")

    limit = Keyword.get(opts, :limit, 500)
    # Default end_time to now, truncated to the second
    end_time = Keyword.get(opts, :end_time, DateTime.utc_now()) |> DateTime.truncate(:second)

    # Use explicit start_time if provided, otherwise calculate based on limit and timeframe
    start_time = case Keyword.get(opts, :start_time) do
      nil ->
        case TimeframeHelper.timeframe_to_seconds(timeframe) do
          seconds when seconds > 0 -> DateTime.add(end_time, -seconds * limit, :second)
          _ ->
            Logger.warning("Invalid timeframe '#{timeframe}' used in load_chart_data. Defaulting start_time to end_time - 30 days.")
            DateTime.add(end_time, -30 * 24 * 60 * 60, :second) # Default to 30 days
        end
      explicit_start_time -> explicit_start_time
    end

    Logger.debug("[ChartDataManager] Query Range: start=#{inspect start_time}, end=#{inspect end_time}, limit=#{limit}")

    # Get candles from database
    candles = MarketDataContext.get_candles_with_limit(
      symbol,
      timeframe,
      start_time,
      end_time,
      limit: limit,
      order_by: :asc
    )

    Logger.debug("[ChartDataManager] Fetched #{length(candles)} candles from DB.")

    # Format candles for chart display
    formatted = ChartDataFormatter.format_chart_data(candles)
    Logger.debug("[ChartDataManager] Returning #{length(formatted)} formatted candles.")

    formatted
  end

  @doc """
  Load historical data for infinite scrolling.

  ## Parameters
    - symbol: Trading pair symbol
    - timeframe: Candle timeframe
    - oldest_time: DateTime representing the oldest visible candle
    - opts: Optional parameters
      - batch_size: Number of candles to fetch (default: 200)
      - start_time_limit: Optional DateTime representing the earliest possible time to fetch

  ## Returns
    %{data: [...], has_more: boolean, recommended_batch_size: integer}
  """
  def load_historical_data(symbol, timeframe, oldest_time, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 200)
    start_time_limit = Keyword.get(opts, :start_time_limit)

    Logger.debug("[ChartDataManager] load_historical_data called: symbol=#{symbol}, timeframe=#{timeframe}, oldest_time=#{inspect oldest_time}, opts=#{inspect opts}")

    # Convert DateTime to ensure it's properly typed
    oldest_time = case oldest_time do
      %DateTime{} -> oldest_time
      timestamp when is_integer(timestamp) -> DateTime.from_unix!(timestamp)
      iso8601 when is_binary(iso8601) ->
        case DateTime.from_iso8601(iso8601) do
          {:ok, dt, _} -> dt
          _ ->
            Logger.error("[ChartDataManager] Invalid oldest_time format: #{inspect iso8601}")
            DateTime.utc_now()
        end
      _ -> DateTime.utc_now()
    end

    # Calculate time range for the query
    timeframe_seconds = TimeframeHelper.timeframe_to_seconds(timeframe)
    calculated_start_time = DateTime.add(oldest_time, -timeframe_seconds * batch_size, :second)

    # Apply the start_time_limit if provided
    start_time =
      if start_time_limit do
        max_datetime(calculated_start_time, start_time_limit)
      else
        calculated_start_time
      end

    # Ensure the end_time is just before the oldest visible candle
    end_time = DateTime.add(oldest_time, -1, :second)

    # Ensure valid time range
    if DateTime.compare(end_time, start_time) != :gt do
      Logger.debug("[ChartDataManager] Historical data load - invalid time range: end_time <= start_time")
      %{data: [], has_more: false, recommended_batch_size: batch_size}
    else
      # Fetch candles for the range
      candles = MarketDataContext.get_candles_with_limit(
        symbol,
        timeframe,
        start_time,
        end_time,
        limit: batch_size,
        order_by: :desc # Newest first for historical loading
      )

      Logger.debug("[ChartDataManager] Fetched #{length(candles)} historical candles from DB.")
      formatted_data = ChartDataFormatter.format_chart_data(candles)

      # Determine if there might be more data
      has_more =
        if start_time_limit do
          # If limited by start_time_limit, there's more if start_time is still after the limit
          DateTime.compare(start_time, start_time_limit) == :gt
        else
          # If no limit, assume more data exists if we received a reasonable amount
          length(formatted_data) >= batch_size * 0.7
        end

      # Build result
      result = %{
        data: formatted_data,
        has_more: has_more,
        recommended_batch_size: calculate_recommended_batch_size(formatted_data, batch_size)
      }

      Logger.debug("[ChartDataManager] Returning #{length(formatted_data)} formatted historical candles, has_more=#{has_more}")
      result
    end
  end

  # Helper Functions

  defp calculate_recommended_batch_size(data, current_batch_size) do
    cond do
      length(data) >= current_batch_size * 0.9 -> current_batch_size
      length(data) >= current_batch_size * 0.5 -> current_batch_size
      length(data) > 0 -> max(50, trunc(current_batch_size * 0.7))
      true -> 100
    end
  end

  defp max_datetime(dt1, dt2) do
    case DateTime.compare(dt1, dt2) do
      :gt -> dt1
      _ -> dt2
    end
  end
end
