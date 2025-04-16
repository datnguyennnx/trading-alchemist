defmodule Central.Backtest.Services.HistoricalDataFetcher do
  @moduledoc """
  Service for fetching specific historical data ranges on demand.
  Used primarily by the backtest system to ensure all required data is available.
  """

  require Logger
  alias Central.Repo
  alias Central.Backtest.Schemas.MarketData
  alias Central.Backtest.Services.Binance.Client, as: BinanceClient

  # Maximum number of candles per API request (Binance limit)
  @max_candles_per_request 1000

  @doc """
  Fetches and stores historical market data for a specific symbol, timeframe, and date range.
  This is a blocking operation that will not return until the fetch is complete or fails.

  ## Parameters
    - symbol: Trading pair (e.g., "BTCUSDT")
    - timeframe: Timeframe (e.g., "1m", "1h", "1d")
    - start_time: DateTime representing the start of the range to fetch
    - end_time: DateTime representing the end of the range to fetch

  ## Returns
    - {:ok, count} where count is the number of candles successfully inserted
    - {:error, reason} on failure
  """
  def fetch_and_store_range(symbol, timeframe, start_time, end_time) do
    Logger.info("Fetching historical data for #{symbol}/#{timeframe} from #{DateTime.to_iso8601(start_time)} to #{DateTime.to_iso8601(end_time)}")

    # Calculate time chunks to respect API limits
    chunks = calculate_time_chunks(timeframe, start_time, end_time)

    # Fetch data for each chunk
    results =
      Enum.map(chunks, fn {chunk_start, chunk_end} ->
        fetch_chunk_with_retries(symbol, timeframe, chunk_start, chunk_end)
      end)

    # Check for errors in any chunk
    errors = Enum.filter(results, fn {status, _} -> status == :error end)

    if errors != [] do
      # Return the first error
      {_, reason} = List.first(errors)
      {:error, reason}
    else
      # Combine all successful chunks
      all_data =
        results
        |> Enum.filter(fn {status, _} -> status == :ok end)
        |> Enum.flat_map(fn {_, data} -> data end)

      # Prepare and store the data
      prepared_data = prepare_data_for_storage(all_data, symbol, timeframe)

      # Store in database with on_conflict: nothing to avoid duplicates
      {count, _} = Repo.insert_all(MarketData, prepared_data, on_conflict: :nothing)

      Logger.info("Successfully stored #{count} historical candles for #{symbol}/#{timeframe}")
      {:ok, count}
    end
  end

  # Fetches a single chunk of historical data with retries.
  #
  # Parameters:
  #   - symbol: Trading pair
  #   - timeframe: Timeframe
  #   - start_time: Start of the chunk
  #   - end_time: End of the chunk
  #   - retry_count: Current retry attempt
  #
  # Returns:
  #   - {:ok, data} where data is the list of candles
  #   - {:error, reason} on failure after retries
  defp fetch_chunk_with_retries(symbol, timeframe, start_time, end_time, retry_count \\ 0) do
    max_retries = 3

    # Use the existing BinanceClient
    case fetch_from_binance(symbol, timeframe, start_time, end_time) do
      {:ok, data} ->
        {:ok, data}

      {:error, reason} when retry_count < max_retries ->
        # Exponential backoff: 1s, 2s, 4s
        backoff_ms = :math.pow(2, retry_count) * 1000 |> round()
        Logger.warning("Retrying fetch for #{symbol}/#{timeframe} after #{backoff_ms}ms. Error: #{inspect(reason)}")
        :timer.sleep(backoff_ms)
        fetch_chunk_with_retries(symbol, timeframe, start_time, end_time, retry_count + 1)

      {:error, reason} ->
        Logger.error("Failed to fetch data for #{symbol}/#{timeframe} after #{max_retries} retries. Error: #{inspect(reason)}")
        {:error, "Failed to fetch historical data after multiple retries: #{inspect(reason)}"}
    end
  end

  # Fetches data from Binance API using the existing client
  defp fetch_from_binance(symbol, timeframe, start_time, end_time) do
    # Convert timeframes from Phoenix format to Binance format if needed
    binance_timeframe = convert_timeframe(timeframe)

    # Call download_historical_data in BinanceClient
    BinanceClient.download_historical_data(symbol, binance_timeframe, start_time, end_time)
  end

  # Calculates time chunks based on timeframe to respect API limits.
  #
  # Returns:
  #   - List of {start_time, end_time} tuples representing each chunk
  defp calculate_time_chunks(timeframe, start_time, end_time) do
    # Calculate duration of a single candle in seconds
    candle_seconds =
      case timeframe do
        "1m" -> 60
        "5m" -> 5 * 60
        "15m" -> 15 * 60
        "1h" -> 3600
        "4h" -> 4 * 3600
        "1d" -> 86400
        _ -> 3600 # Default to 1h
      end

    # Calculate maximum time range per request (in seconds)
    max_range_seconds = candle_seconds * @max_candles_per_request

    # Split into chunks
    split_into_chunks(start_time, end_time, max_range_seconds, [])
  end

  # Recursively splits a time range into smaller chunks.
  defp split_into_chunks(current_start, end_time, max_range_seconds, chunks) do
    # If we've processed the entire range, return the chunks
    if DateTime.compare(current_start, end_time) != :lt do
      Enum.reverse(chunks)
    else
      # Calculate the end of this chunk
      chunk_end =
        current_start
        |> DateTime.add(max_range_seconds, :second)

      # Ensure chunk_end doesn't exceed the overall end_time
      actual_chunk_end =
        if DateTime.compare(chunk_end, end_time) == :gt do
          end_time
        else
          chunk_end
        end

      # Add this chunk to the list
      updated_chunks = [{current_start, actual_chunk_end} | chunks]

      # Move to the next chunk
      next_start = DateTime.add(actual_chunk_end, 1, :second)
      split_into_chunks(next_start, end_time, max_range_seconds, updated_chunks)
    end
  end

  # Converts a timeframe string from Phoenix format to Binance format if needed
  defp convert_timeframe(timeframe) do
    # Placeholder for any timeframe conversion logic needed
    # For example, if Phoenix uses "1h" but Binance API uses "1H" or "1hour"
    timeframe
  end

  # Prepares data for storage in the database.
  #
  # Parameters:
  #   - data: Raw data from Binance API
  #   - symbol: Trading pair
  #   - timeframe: Timeframe
  #
  # Returns:
  #   - List of maps ready for insert_all
  defp prepare_data_for_storage(data, symbol, timeframe) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    Enum.map(data, fn candle ->
      # The existing BinanceClient returns structs with timestamp, open, high, low, close, volume
      # and other fields, so we need to adapt the code

      %{
        id: Ecto.UUID.generate(),
        symbol: symbol,
        timeframe: timeframe,
        timestamp: candle.timestamp,
        open: parse_decimal(candle.open),
        high: parse_decimal(candle.high),
        low: parse_decimal(candle.low),
        close: parse_decimal(candle.close),
        volume: parse_decimal(candle.volume),
        source: "binance",
        inserted_at: now
      }
    end)
  end

  # Parse a value into a Decimal
  defp parse_decimal(value) when is_binary(value), do: Decimal.new(value)
  defp parse_decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp parse_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp parse_decimal(value), do: value
end
