defmodule Central.Backtest.Contexts.MarketData do
  @moduledoc """
  Context for working with market data.
  Provides functions for querying and caching market data.
  """

  import Ecto.Query
  alias Central.Backtest.Schemas.MarketData
  alias Central.Repo

  # In-memory cache using ETS
  @ets_table :market_data_cache

  @doc """
  Returns the name of the ETS cache table.
  """
  def cache_name, do: @ets_table

  # Initialize the ETS table for caching
  def init_cache do
    :ets.new(@ets_table, [:set, :public, :named_table, read_concurrency: true])
    :ok
  end

  @doc """
  Returns a list of all available symbols in the database.

  ## Examples

      iex> list_symbols()
      ["BTCUSDT"]
  """
  def list_symbols do
    symbols_query = from m in MarketData, select: m.symbol, distinct: true

    # Try to get from cache first
    try do
      case :ets.lookup(@ets_table, :symbols) do
        [{:symbols, symbols}] ->
          symbols

        [] ->
          symbols = Repo.all(symbols_query)
          # Add default symbols if none are found
          symbols = if Enum.empty?(symbols), do: ["BTCUSDT", "ETHUSDT"], else: symbols
          :ets.insert(@ets_table, {:symbols, symbols})
          symbols
      end
    rescue
      # Handle case when ETS table doesn't exist
      ArgumentError ->
        symbols = Repo.all(symbols_query)
        # Add default symbols if none are found
        symbols = if Enum.empty?(symbols), do: ["BTCUSDT", "ETHUSDT"], else: symbols

        # Try to create the table if it doesn't exist
        try do
          :ets.new(@ets_table, [:set, :public, :named_table, read_concurrency: true])
          :ets.insert(@ets_table, {:symbols, symbols})
        rescue
          _ -> :ok # Table might already exist in another process
        end

        symbols
    end
  end

  @doc """
  Returns a list of all available timeframes in the database.

  ## Examples

      iex> list_timeframes()
      ["1m", "5m", "15m", "1h", "4h", "1d"]
  """
  def list_timeframes do
    timeframes_query = from m in MarketData, select: m.timeframe, distinct: true

    # Try to get from cache first
    try do
      case :ets.lookup(@ets_table, :timeframes) do
        [{:timeframes, timeframes}] ->
          timeframes

        [] ->
          timeframes = Repo.all(timeframes_query)
          # Add default timeframes if none are found
          timeframes = if Enum.empty?(timeframes), do: ["1m", "5m", "15m", "1h", "4h", "1d"], else: timeframes
          :ets.insert(@ets_table, {:timeframes, timeframes})
          timeframes
      end
    rescue
      # Handle case when ETS table doesn't exist
      ArgumentError ->
        timeframes = Repo.all(timeframes_query)
        # Add default timeframes if none are found
        timeframes = if Enum.empty?(timeframes), do: ["1m", "5m", "15m", "1h", "4h", "1d"], else: timeframes

        # Try to create the table if it doesn't exist
        try do
          :ets.new(@ets_table, [:set, :public, :named_table, read_concurrency: true])
          :ets.insert(@ets_table, {:timeframes, timeframes})
        rescue
          _ -> :ok # Table might already exist in another process
        end

        timeframes
    end
  end

  @doc """
  Gets candles for a symbol and timeframe within a date range.

  ## Examples

      iex> get_candles("BTCUSDT", "1h", ~U[2025-01-01 00:00:00Z], ~U[2025-01-02 00:00:00Z])
      [%MarketData{}, ...]
  """
  def get_candles(symbol, timeframe, start_time, end_time) do
    MarketData
    |> where([m], m.symbol == ^symbol)
    |> where([m], m.timeframe == ^timeframe)
    |> where([m], m.timestamp >= ^start_time)
    |> where([m], m.timestamp <= ^end_time)
    |> order_by([m], asc: m.timestamp)
    |> Repo.all()
  end

  @doc """
  Gets the latest candle for a symbol and timeframe.

  ## Examples

      iex> get_latest_candle("BTCUSDT", "1h")
      %MarketData{}

      iex> get_latest_candle("NONEXISTENT", "1h")
      nil
  """
  def get_latest_candle(symbol, timeframe) do
    MarketData
    |> where([m], m.symbol == ^symbol)
    |> where([m], m.timeframe == ^timeframe)
    |> order_by([m], desc: m.timestamp)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Gets the oldest candle for a symbol and timeframe.

  ## Examples

      iex> get_oldest_candle("BTCUSDT", "1h")
      %MarketData{}

      iex> get_oldest_candle("NONEXISTENT", "1h")
      nil
  """
  def get_oldest_candle(symbol, timeframe) do
    MarketData
    |> where([m], m.symbol == ^symbol)
    |> where([m], m.timeframe == ^timeframe)
    |> order_by([m], asc: m.timestamp)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Gets the date range (min and max timestamp) for a symbol and timeframe.

  ## Examples

      iex> get_date_range("BTCUSDT", "1h")
      {~U[2025-01-01 00:00:00Z], ~U[2025-01-31 23:00:00Z]}

      iex> get_date_range("NONEXISTENT", "1h")
      {nil, nil}
  """
  def get_date_range(symbol, timeframe) do
    query = from m in MarketData,
      where: m.symbol == ^symbol and m.timeframe == ^timeframe,
      select: {min(m.timestamp), max(m.timestamp)}

    case Repo.one(query) do
      {nil, nil} -> {nil, nil}
      result -> result
    end
  end

  @doc """
  Gets a count of candles for a symbol and timeframe within a date range.

  ## Examples

      iex> get_candle_count("BTCUSDT", "1h", ~U[2025-01-01 00:00:00Z], ~U[2025-01-02 00:00:00Z])
      24
  """
  def get_candle_count(symbol, timeframe, start_time, end_time) do
    MarketData
    |> where([m], m.symbol == ^symbol)
    |> where([m], m.timeframe == ^timeframe)
    |> where([m], m.timestamp >= ^start_time)
    |> where([m], m.timestamp <= ^end_time)
    |> select([m], count(m.id))
    |> Repo.one()
  end

  @doc """
  Gets the last candle for a symbol and timeframe.

  ## Parameters
    - symbol: Trading pair (e.g., "BTCUSDT")
    - timeframe: Timeframe (e.g., "1m", "1h", "1d")

  ## Examples

      iex> get_last_candle("BTCUSDT", "1h")
      %{symbol: "BTCUSDT", timeframe: "1h", timestamp: ~U[2025-01-01 00:00:00Z], ...}
  """
  def get_last_candle(symbol, timeframe) do
    cache_key = {:last_candle, symbol, timeframe}

    # Try to get from cache first
    case :ets.lookup(@ets_table, cache_key) do
      [{^cache_key, candle, cached_at}] ->
        # Check if cache is fresh (less than 10 seconds old)
        if DateTime.diff(DateTime.utc_now(), cached_at, :second) < 10 do
          candle
        else
          fetch_and_cache_last_candle(symbol, timeframe, cache_key)
        end

      [] ->
        fetch_and_cache_last_candle(symbol, timeframe, cache_key)
    end
  end

  @doc """
  Gets a statistical summary of market data availability.

  ## Examples

      iex> get_data_summary()
      %{
        total_candles: 10000,
        symbols: 2,
        timeframes: 6,
        date_range: %{min: ~U[2025-01-01 00:00:00Z], max: ~U[2025-02-01 00:00:00Z]}
      }
  """
  def get_data_summary do
    # Query for summary statistics
    total_candles = Repo.one(from m in MarketData, select: count(m.id))

    symbol_count_query = from m in MarketData, select: count(fragment("DISTINCT ?", m.symbol))
    symbol_count = Repo.one(symbol_count_query)

    timeframe_count_query = from m in MarketData, select: count(fragment("DISTINCT ?", m.timeframe))
    timeframe_count = Repo.one(timeframe_count_query)

    min_date_query = from m in MarketData, select: min(m.timestamp)
    min_date = Repo.one(min_date_query)

    max_date_query = from m in MarketData, select: max(m.timestamp)
    max_date = Repo.one(max_date_query)

    %{
      total_candles: total_candles,
      symbols: symbol_count,
      timeframes: timeframe_count,
      date_range: %{min: min_date, max: max_date}
    }
  end

  @doc """
  Invalidates cache for a specific symbol and timeframe.
  Used by the sync worker when new data is added.

  ## Parameters
    - symbol: Trading pair (e.g., "BTCUSDT"), or nil to invalidate all symbols
    - timeframe: Timeframe (e.g., "1m", "1h", "1d"), or nil to invalidate all timeframes
  """
  def invalidate_cache(symbol \\ nil, timeframe \\ nil) do
    # Always invalidate the symbols and timeframes lists
    :ets.delete(@ets_table, :symbols)
    :ets.delete(@ets_table, :timeframes)

    # If no symbol or timeframe specified, flush the entire cache
    if is_nil(symbol) and is_nil(timeframe) do
      :ets.delete_all_objects(@ets_table)
    else
      # Pattern match to find entries to invalidate
      pattern =
        case {symbol, timeframe} do
          {nil, nil} ->
            :_ # Match everything (should not happen due to above check)
          {nil, tf} ->
            {:_, tf, :_, :_, :_, :_} # Match any symbol with specific timeframe
          {sym, nil} ->
            {sym, :_, :_, :_, :_, :_} # Match specific symbol with any timeframe
          {sym, tf} ->
            {sym, tf, :_, :_, :_, :_} # Match specific symbol and timeframe
        end

      # Find matching cache keys and delete them
      :ets.match(@ets_table, {pattern, :_, :_})
      |> Enum.each(fn [key, _, _] ->
        case :ets.lookup(@ets_table, key) do
          [] -> :ok
          objects -> Enum.each(objects, &:ets.delete_object(@ets_table, &1))
        end
      end)

      # Also invalidate last candle cache if applicable
      if symbol do
        last_candle_key =
          if timeframe do
            {:last_candle, symbol, timeframe}
          else
            # Use match pattern for all timeframes of this symbol
            :ets.match(@ets_table, {{:last_candle, symbol, :_}, :_, :_})
            |> Enum.each(fn [[_, _, tf], _, _] ->
              key = {:last_candle, symbol, tf}
              case :ets.lookup(@ets_table, key) do
                [] -> :ok
                objects -> Enum.each(objects, &:ets.delete_object(@ets_table, &1))
              end
            end)
          end

        if is_tuple(last_candle_key) do
          case :ets.lookup(@ets_table, last_candle_key) do
            [] -> :ok
            objects -> Enum.each(objects, &:ets.delete_object(@ets_table, &1))
          end
        end
      end
    end

    :ok
  end

  # PRIVATE FUNCTIONS

  @doc false
  defp fetch_and_cache_last_candle(symbol, timeframe, cache_key) do
    # Query for the last candle
    candle =
      Repo.one(
        from m in MarketData,
          where: m.symbol == ^symbol and m.timeframe == ^timeframe,
          order_by: [desc: m.timestamp],
          limit: 1
      )

    # Cache the result
    :ets.insert(@ets_table, {cache_key, candle, DateTime.utc_now()})

    candle
  end
end
