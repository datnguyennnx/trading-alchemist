defmodule CentralWeb.BacktestLive.Utils.MarketDataLoader do
  require Logger
  import Ecto.Query

  alias Central.Backtest.Contexts.MarketData, as: MarketDataContext
  alias Central.Backtest.Schemas.MarketData, as: MarketDataSchema
  alias Central.Backtest.Workers.MarketSync
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
    # Fetch the latest 200 candles directly
    query =
      from m in MarketDataSchema,
        where: m.symbol == ^symbol,
        where: m.timeframe == ^timeframe,
        order_by: [desc: m.timestamp],
        limit: 200

    # Fetch and reverse to get ascending order for chart
    candles = Repo.all(query) |> Enum.reverse()

    if Enum.empty?(candles) do
      # No data found, trigger a sync for this symbol/timeframe
      Logger.info("No data found for #{symbol}/#{timeframe} - triggering sync")

      try do
        # Trigger market sync for this specific symbol and timeframe
        MarketSync.trigger_sync(symbol, timeframe)
        Logger.info("Sync triggered for #{symbol}/#{timeframe}")

        # Give it a moment to fetch
        :timer.sleep(500)

        # Try one more time
        retried_candles = Repo.all(query)

        if Enum.empty?(retried_candles) do
          Logger.info("Still no data available after sync trigger")
          []
        else
          Logger.info("Found #{length(retried_candles)} candles after sync")
          DataFormatter.format_market_data(retried_candles)
        end
      rescue
        e ->
          Logger.error("Failed to trigger sync: #{inspect(e)}")
          []
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
end
