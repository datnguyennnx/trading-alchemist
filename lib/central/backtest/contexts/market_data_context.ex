defmodule Central.Backtest.Contexts.MarketDataContext do
  @moduledoc """
  Context for working with market data.
  Provides functions for querying and caching market data.
  """

  import Ecto.Query
  alias Central.Backtest.Schemas.MarketData
  alias Central.Repo
  require Logger

  # In-memory cache using ETS
  @ets_table :market_data_cache

  @doc """
  Returns the name of the ETS cache table.
  """
  def cache_name, do: @ets_table

  # Initialize the ETS table for caching
  def init_cache do
    try do
      :ets.new(@ets_table, [:set, :public, :named_table, read_concurrency: true])
      :ok
    rescue
      # Table might already exist
      ArgumentError -> :ok
    end
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
          # Table might already exist in another process
          _ -> :ok
        end

        symbols
    end
  end

  @doc """
  Alias for list_symbols. Returns available symbols for backtesting.
  """
  def get_available_symbols do
    list_symbols()
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
          timeframes =
            if Enum.empty?(timeframes),
              do: ["1m", "5m", "15m", "1h", "4h", "1d"],
              else: timeframes

          :ets.insert(@ets_table, {:timeframes, timeframes})
          timeframes
      end
    rescue
      # Handle case when ETS table doesn't exist
      ArgumentError ->
        timeframes = Repo.all(timeframes_query)
        # Add default timeframes if none are found
        timeframes =
          if Enum.empty?(timeframes), do: ["1m", "5m", "15m", "1h", "4h", "1d"], else: timeframes

        # Try to create the table if it doesn't exist
        try do
          :ets.new(@ets_table, [:set, :public, :named_table, read_concurrency: true])
          :ets.insert(@ets_table, {:timeframes, timeframes})
        rescue
          # Table might already exist in another process
          _ -> :ok
        end

        timeframes
    end
  end

  @doc """
  Alias for list_timeframes. Returns available timeframes for backtesting.
  """
  def get_available_timeframes do
    list_timeframes()
  end

  @doc """
  Gets candles for a symbol and timeframe within a date range, with limit and optional sorting.
  This is an optimized version of get_candles that supports limiting results and custom sort order.

  ## Parameters
    - symbol: Trading pair symbol (e.g., "BTCUSDT")
    - timeframe: Candle timeframe (e.g., "1h")
    - start_time: The required start DateTime (UTC)
    - end_time: The required end DateTime (UTC)
    - opts: Additional options
      - limit: Maximum number of candles to return
      - order_by: Sort order (:asc or :desc for timestamp, default: :asc)
      - use_cache: Whether to check/use cache (default: true)

  ## Examples

      iex> get_candles_with_limit("BTCUSDT", "1h", ~U[2025-01-01 00:00:00Z], ~U[2025-01-02 00:00:00Z], limit: 10)
      [%MarketData{}, ...]

      iex> get_candles_with_limit("BTCUSDT", "1h", ~U[2025-01-01 00:00:00Z], ~U[2025-01-02 00:00:00Z], limit: 20, order_by: :desc)
      [%MarketData{}, ...]
  """
  def get_candles_with_limit(symbol, timeframe, start_time, end_time, opts \\ []) do
    limit = Keyword.get(opts, :limit)
    order_by = Keyword.get(opts, :order_by, :asc)
    use_cache = Keyword.get(opts, :use_cache, true)

    # Generate a cache key if caching is enabled
    cache_key =
      if use_cache do
        {:candles, symbol, timeframe, DateTime.to_unix(start_time), DateTime.to_unix(end_time),
         limit, order_by}
      else
        nil
      end

    # Try to get from cache first if enabled
    if use_cache && cache_key do
      case :ets.lookup(@ets_table, cache_key) do
        [{^cache_key, candles, cached_at}] ->
          # Check if cache is fresh (less than 10 seconds old)
          if DateTime.diff(DateTime.utc_now(), cached_at, :second) < 10 do
            IO.puts(
              "[MarketDataContext] get_candles_with_limit cache hit for #{symbol}/#{timeframe}"
            )

            candles
          else
            fetch_and_cache_candles(
              symbol,
              timeframe,
              start_time,
              end_time,
              limit,
              order_by,
              cache_key
            )
          end

        [] ->
          fetch_and_cache_candles(
            symbol,
            timeframe,
            start_time,
            end_time,
            limit,
            order_by,
            cache_key
          )
      end
    else
      # Skip cache if disabled
      fetch_candles(symbol, timeframe, start_time, end_time, limit, order_by)
    end
  end

  # Private helper for fetching and caching candles
  defp fetch_and_cache_candles(
         symbol,
         timeframe,
         start_time,
         end_time,
         limit,
         order_by,
         cache_key
       ) do
    candles = fetch_candles(symbol, timeframe, start_time, end_time, limit, order_by)

    # Cache the result if we have a cache key
    if cache_key do
      :ets.insert(@ets_table, {cache_key, candles, DateTime.utc_now()})
    end

    candles
  end

  # Actual database query for fetching candles
  defp fetch_candles(symbol, timeframe, start_time, end_time, limit, order_by) do
    IO.puts(
      "[MarketDataContext] fetch_candles: symbol=#{symbol}, timeframe=#{timeframe}, limit=#{limit || "none"}, order=#{order_by}"
    )

    # Build base query
    query =
      MarketData
      |> where([m], m.symbol == ^symbol)
      |> where([m], m.timeframe == ^timeframe)
      |> where([m], m.timestamp >= ^start_time)
      |> where([m], m.timestamp <= ^end_time)

    # Add ordering
    query =
      case order_by do
        :desc -> query |> order_by([m], desc: m.timestamp)
        _ -> query |> order_by([m], asc: m.timestamp)
      end

    # Add limit if provided
    query = if limit, do: query |> limit(^limit), else: query

    # Execute query
    result = Repo.all(query)
    IO.puts("[MarketDataContext] fetch_candles found #{length(result)} records")

    result
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
    query =
      from m in MarketData,
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

    timeframe_count_query =
      from m in MarketData, select: count(fragment("DISTINCT ?", m.timeframe))

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
            # Match everything (should not happen due to above check)
            :_

          {nil, tf} ->
            # Match any symbol with specific timeframe
            {:_, tf, :_, :_, :_, :_}

          {sym, nil} ->
            # Match specific symbol with any timeframe
            {sym, :_, :_, :_, :_, :_}

          {sym, tf} ->
            # Match specific symbol and timeframe
            {sym, tf, :_, :_, :_, :_}
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

  @doc """
  Inserts a list of MarketData attribute maps in bulk.

  Uses `Repo.insert_all` for efficiency and handles conflicts based on the
  unique index (symbol, timeframe, timestamp, source).

  ## Parameters
    - data_to_insert: A list of maps, where each map represents a MarketData record.
                      Example: `[%{symbol: "BTCUSDT", timestamp: ~U[...], open: Decimal.new(...), ...}, ...]`

  ## Returns
    - `{:ok, count}` where `count` is the number of rows inserted.
    - `{:error, term}` if insertion fails.
  """
  def bulk_insert_candles(data_to_insert) when is_list(data_to_insert) do
    if Enum.empty?(data_to_insert) do
      IO.puts(
        "[MarketDataContext] bulk_insert_candles called with empty list. Nothing to insert."
      )

      {:ok, 0}
    else
      # Validate the structure of the first map (basic check)
      first_item = List.first(data_to_insert)

      required_keys = [
        :symbol,
        :timeframe,
        :timestamp,
        :open,
        :high,
        :low,
        :close,
        :volume,
        :source,
        :inserted_at
      ]

      if is_map(first_item) and Enum.all?(required_keys, &Map.has_key?(first_item, &1)) do
        # Log attempt
        IO.puts(
          "[MarketDataContext] Attempting Repo.insert_all with #{length(data_to_insert)} records."
        )

        # IO.inspect(data_to_insert, label: "[MarketDataContext] Data for insert_all") # Keep inspect for now?
        # Use insert_all with on_conflict: :nothing to ignore duplicates
        # based on the unique constraint [symbol, timeframe, timestamp, source]
        case Repo.insert_all(MarketData, data_to_insert, on_conflict: :nothing, returning: false) do
          {count, nil} ->
            # Invalidate cache after successful insertion
            # Invalidate broadly for now, could be more specific if needed
            invalidate_cache()
            # Log success
            IO.puts(
              "[MarketDataContext] Repo.insert_all successful, inserted/ignored #{count} records."
            )

            {:ok, count}

          {_count, error_info} ->
            # This part might not be reached with :nothing strategy, but good to have
            Logger.error("Bulk candle insert failed: #{inspect(error_info)}")
            # Log error
            IO.puts("[MarketDataContext] Repo.insert_all failed: #{inspect(error_info)}")
            # Return error info
            {:error, error_info}
        end
      else
        Logger.error(
          "[MarketDataContext] bulk_insert_candles received list with invalid map structure. First item: #{inspect(first_item)}"
        )

        {:error, :invalid_data_structure}
      end
    end
  end

  @doc """
  Gets a chunk of historical candles for a symbol and timeframe *before* a given end timestamp.
  Results are ordered newest-first (descending timestamp) within the chunk.

  ## Parameters
    - symbol: Trading pair (e.g., "BTCUSDT")
    - timeframe: Timeframe (e.g., "1m", "1h", "1d")
    - end_time_exclusive: Fetch candles strictly *before* this timestamp.
    - limit: Maximum number of candles to fetch.

  ## Examples

      iex> get_historical_candles("BTCUSDT", "1h", ~U[2025-01-10 00:00:00Z], 100)
      [%MarketData{timestamp: ~U[2025-01-09 23:00:00Z]}, ..., %MarketData{timestamp: ~U[2025-01-09 19:00:00Z]}]
  """
  def get_historical_candles(symbol, timeframe, end_time_exclusive, limit) do
    # Log call
    IO.puts(
      "[MarketDataContext] get_historical_candles called: symbol=#{symbol}, timeframe=#{timeframe}, before=#{inspect(end_time_exclusive)}, limit=#{limit}"
    )

    query =
      MarketData
      |> where([m], m.symbol == ^symbol)
      |> where([m], m.timeframe == ^timeframe)
      # Use '<' for exclusive end time
      |> where([m], m.timestamp < ^end_time_exclusive)
      # Order newest first within the chunk
      |> order_by([m], desc: m.timestamp)
      |> limit(^limit)

    # Note: The result here is newest-first. The frontend will need to reverse this
    # list before prepending it to its existing data to maintain ascending order.
    result = Repo.all(query)
    # Log result count
    IO.puts("[MarketDataContext] get_historical_candles found #{length(result)} records.")
    result
  end

  @doc """
  Gets candles for a symbol and timeframe within a date range.
  This is a convenience wrapper around get_candles_with_limit without a limit.

  ## Examples
      iex> get_candles("BTCUSDT", "1h", ~U[2025-01-01 00:00:00Z], ~U[2025-01-02 00:00:00Z])
      [%MarketData{}, ...]
  """
  def get_candles(symbol, timeframe, start_time, end_time) do
    IO.puts(
      "[MarketDataContext] get_candles called: symbol=#{symbol}, timeframe=#{timeframe}, start=#{inspect(start_time)}, end=#{inspect(end_time)}"
    )

    get_candles_with_limit(symbol, timeframe, start_time, end_time)
  end

  # PRIVATE FUNCTIONS

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
