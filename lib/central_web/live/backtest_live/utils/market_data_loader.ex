defmodule CentralWeb.BacktestLive.Utils.MarketDataLoader do
  require Logger
  import Ecto.Query

  alias Central.Backtest.Contexts.MarketDataContext
  alias Central.Backtest.Schemas.MarketData, as: MarketDataSchema
  alias Central.Backtest.Workers.MarketSyncWorker
  alias Central.Backtest.Services.MarketData.HistoricalDataFetcher
  alias Central.Repo
  alias CentralWeb.BacktestLive.Utils.DataFormatter

  @doc """
  Get available symbols from the market data
  """
  def get_symbols do
    # Try to use the MarketDataContext
    try do
      symbols = MarketDataContext.list_symbols()
      if Enum.empty?(symbols), do: ["BTCUSDT"], else: symbols
    rescue
      # Fall back to query if the context call fails (might be ETS table issues)
      _ ->
        query =
          from m in MarketDataSchema,
            select: m.symbol,
            distinct: true

        symbols = Repo.all(query) |> Enum.sort()
        if Enum.empty?(symbols), do: ["BTCUSDT"], else: symbols
    end
  end

  @doc """
  Fetch market data using direct query for reliability
  """
  def fetch_market_data(symbol, timeframe) do
    # Get current time for recent data
    end_time = DateTime.utc_now()
    # For chart view, get about 200 candles by default
    start_time = calculate_start_time(end_time, timeframe, 200)

    # Check if we have the data for this time range
    {db_start, db_end} = MarketDataContext.get_date_range(symbol, timeframe)

    # Check if we need to fetch historical data
    missing_data =
      cond do
        # No data at all
        is_nil(db_start) or is_nil(db_end) ->
          true

        # Start time earlier than available data
        DateTime.compare(start_time, db_start) == :lt ->
          true

        # End time later than available data (less common)
        DateTime.compare(end_time, db_end) == :gt ->
          true

        # Data seems to be available
        true ->
          false
      end

    if missing_data do
      Logger.info("Missing data detected for chart view #{symbol}/#{timeframe}. Fetching historical data...")

      # Determine the missing ranges
      missing_ranges = determine_missing_ranges(symbol, timeframe, start_time, end_time, db_start, db_end)

      # Fetch each missing range
      Enum.each(missing_ranges, fn {range_start, range_end} ->
        Logger.info("Fetching range #{DateTime.to_iso8601(range_start)} to #{DateTime.to_iso8601(range_end)}")
        case HistoricalDataFetcher.fetch_and_store_range(symbol, timeframe, range_start, range_end) do
          {:ok, count} ->
            Logger.info("Successfully fetched #{count} candles for chart view")

          {:error, reason} ->
            Logger.error("Failed to fetch historical data for chart view: #{reason}")
            # Fall back to standard sync as a contingency
            try_standard_sync(symbol, timeframe)
        end
      end)
    end

    # Fetch the latest 200 candles directly
    query =
      from m in MarketDataSchema,
        where: m.symbol == ^symbol,
        where: m.timeframe == ^timeframe,
        where: m.timestamp >= ^start_time,
        where: m.timestamp <= ^end_time,
        order_by: [asc: m.timestamp]

    # Fetch candles
    candles = Repo.all(query)

    if Enum.empty?(candles) do
      # No data found, trigger a sync for this symbol/timeframe
      Logger.info("No data found for #{symbol}/#{timeframe} - triggering sync")
      try_standard_sync(symbol, timeframe)

      # Try one more time
      retried_candles = Repo.all(query)

      if Enum.empty?(retried_candles) do
        Logger.info("Still no data available after sync trigger")
        []
      else
        Logger.info("Found #{length(retried_candles)} candles after sync")
        DataFormatter.format_market_data(retried_candles)
      end
    else
      # We have data, format it for the chart
      Logger.info("Fetched #{length(candles)} candles for #{symbol}/#{timeframe}")

      if length(candles) > 0 do
        sample = List.first(candles)
        Logger.debug("Sample candle: #{inspect(sample, pretty: true)}")
      end

      DataFormatter.format_market_data(candles)
    end
  rescue
    error ->
      Logger.error("Error fetching market data: #{inspect(error, pretty: true)}")
      # Return empty list on error
      []
  end

  # Determine the missing data ranges that need to be fetched.
  #
  # Returns:
  #   A list of {start_time, end_time} tuples representing missing ranges
  defp determine_missing_ranges(_symbol, _timeframe, start_time, end_time, db_start, db_end) do
    cond do
      # No data at all
      is_nil(db_start) or is_nil(db_end) ->
        [{start_time, end_time}]

      # Data exists but doesn't cover the entire requested range
      true ->
        ranges = []

        # Check if we need earlier data
        ranges =
          if DateTime.compare(start_time, db_start) == :lt do
            [{start_time, DateTime.add(db_start, -1, :second)} | ranges]
          else
            ranges
          end

        # Check if we need more recent data
        ranges =
          if DateTime.compare(end_time, db_end) == :gt do
            ranges ++ [{DateTime.add(db_end, 1, :second), end_time}]
          else
            ranges
          end

        ranges
    end
  end

  # Fallback to standard sync mechanism if historical fetch fails
  defp try_standard_sync(symbol, timeframe) do
    try do
      # Trigger market sync for this specific symbol and timeframe
      MarketSyncWorker.trigger_sync(symbol, timeframe)
      Logger.info("Standard sync triggered for #{symbol}/#{timeframe}")

      # Give it a moment to fetch
      :timer.sleep(500)
    rescue
      e ->
        Logger.error("Failed to trigger sync: #{inspect(e)}")
    end
  end

  @doc """
  Calculate start time based on timeframe and candle count
  """
  def calculate_start_time(end_time, timeframe, count) do
    seconds =
      case timeframe do
        "1m" -> count * 60
        "5m" -> count * 5 * 60
        "15m" -> count * 15 * 60
        "1h" -> count * 3600
        "4h" -> count * 4 * 3600
        "1d" -> count * 86400
        # Default to 1h
        _ -> count * 3600
      end

    DateTime.add(end_time, -seconds, :second)
  end

  @doc """
  Fetch historical market data for a specific time range
  """
  def fetch_historical_data(symbol, timeframe, start_time, end_time) do
    # Check if we have all the data we need
    {db_start, db_end} = MarketDataContext.get_date_range(symbol, timeframe)

    # Check if we need to fetch historical data
    missing_data =
      cond do
        # No data at all
        is_nil(db_start) or is_nil(db_end) ->
          true

        # Start time earlier than available data
        DateTime.compare(start_time, db_start) == :lt ->
          true

        # End time later than available data
        DateTime.compare(end_time, db_end) == :gt ->
          true

        # Data seems to be available
        true ->
          false
      end

    if missing_data do
      Logger.info("Missing historical data detected for #{symbol}/#{timeframe}. Fetching data...")

      # Determine the missing ranges
      missing_ranges = determine_missing_ranges(symbol, timeframe, start_time, end_time, db_start, db_end)

      # Fetch each missing range
      Enum.each(missing_ranges, fn {range_start, range_end} ->
        Logger.info("Fetching range #{DateTime.to_iso8601(range_start)} to #{DateTime.to_iso8601(range_end)}")
        case HistoricalDataFetcher.fetch_and_store_range(symbol, timeframe, range_start, range_end) do
          {:ok, count} ->
            Logger.info("Successfully fetched #{count} historical candles")

          {:error, reason} ->
            Logger.error("Failed to fetch historical data: #{reason}")
        end
      end)
    end

    # Skip the context and use direct query for reliability
    query =
      from m in MarketDataSchema,
        where: m.symbol == ^symbol,
        where: m.timeframe == ^timeframe,
        where: m.timestamp >= ^start_time,
        where: m.timestamp <= ^end_time,
        order_by: [asc: m.timestamp]

    candles = Repo.all(query)

    Logger.info(
      "Fetched #{length(candles)} historical candles for #{symbol}/#{timeframe} from #{DateTime.to_iso8601(start_time)} to #{DateTime.to_iso8601(end_time)}"
    )

    if length(candles) > 0 do
      DataFormatter.format_market_data(candles)
    else
      []
    end
  rescue
    error ->
      Logger.error("Error fetching historical market data: #{inspect(error, pretty: true)}")
      # Return empty list on error
      []
  end

  def load_market_data(symbol, timeframe, candle_count \\ 200) do
    Logger.info("Loading market data for #{symbol}/#{timeframe} (#{candle_count} candles)")

    # Calculate time range based on candle count
    end_time = DateTime.utc_now()
    start_time = calculate_start_time(end_time, timeframe, candle_count)

    # Check if we need to fetch historical data for this range
    {db_start, db_end} = MarketDataContext.get_date_range(symbol, timeframe)

    # Determine if we need to fetch data
    missing_data =
      cond do
        # No data exists at all
        is_nil(db_start) or is_nil(db_end) ->
          true

        # Requested start is before available data
        DateTime.compare(start_time, db_start) == :lt ->
          true

        # End time is after available data
        DateTime.compare(end_time, db_end) == :gt ->
          true

        # Data is available
        true ->
          false
      end

    # If we need historical data, try to fetch it first
    if missing_data do
      Logger.info("Missing market data detected for chart view - fetching historical data...")

      # Determine which ranges are missing
      missing_ranges = determine_missing_ranges(symbol, timeframe, start_time, end_time, db_start, db_end)

      # Fetch each missing range
      Task.start(fn ->
        Enum.each(missing_ranges, fn {range_start, range_end} ->
          Logger.info(
            "Fetching historical data for chart from #{DateTime.to_iso8601(range_start)} to #{DateTime.to_iso8601(range_end)}"
          )

          case HistoricalDataFetcher.fetch_and_store_range(symbol, timeframe, range_start, range_end) do
            {:ok, count} ->
              Logger.info("Successfully fetched #{count} historical candles for chart view")

            {:error, reason} ->
              Logger.error("Failed to fetch historical data for chart view: #{reason}")
              # Fall back to standard sync as a contingency
              try_standard_sync(symbol, timeframe)
          end
        end)
      end)
    end

    # Fetch the latest 200 candles directly
    query =
      from m in MarketDataSchema,
        where: m.symbol == ^symbol,
        where: m.timeframe == ^timeframe,
        where: m.timestamp >= ^start_time,
        where: m.timestamp <= ^end_time,
        order_by: [asc: m.timestamp]

    # Fetch candles
    candles = Repo.all(query)

    if Enum.empty?(candles) do
      # No data found, trigger a sync for this symbol/timeframe
      Logger.info("No data found for #{symbol}/#{timeframe} - triggering sync")
      try_standard_sync(symbol, timeframe)

      # Try one more time
      retried_candles = Repo.all(query)

      if Enum.empty?(retried_candles) do
        Logger.info("Still no data available after sync trigger")
        []
      else
        Logger.info("Found #{length(retried_candles)} candles after sync")
        DataFormatter.format_market_data(retried_candles)
      end
    else
      # We have data, format it for the chart
      Logger.info("Fetched #{length(candles)} candles for #{symbol}/#{timeframe}")

      if length(candles) > 0 do
        sample = List.first(candles)
        Logger.debug("Sample candle: #{inspect(sample, pretty: true)}")
      end

      DataFormatter.format_market_data(candles)
    end
  rescue
    error ->
      Logger.error("Error fetching market data: #{inspect(error, pretty: true)}")
      # Return empty list on error
      []
  end
end
