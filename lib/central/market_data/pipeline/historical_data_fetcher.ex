defmodule Central.MarketData.Pipeline.HistoricalDataFetcher do
  @moduledoc """
  Service for fetching specific historical data ranges on demand from external sources (e.g., Binance).
  Stores the fetched data into the database.
  """

  require Logger
  alias Central.Repo
  # Assuming MarketData schema stays for now
  alias Central.Backtest.Schemas.MarketData
  # Added alias
  alias Central.Helpers.TimeframeHelper
  # Updated alias from Central.Backtest.Services.Fetching.DataProcessor
  alias Central.MarketData.DataProcessor
  # Updated path
  alias Central.MarketData.Exchange.Binance.Client, as: BinanceClient

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
    Logger.info(
      "Fetching historical data for #{symbol}/#{timeframe} from #{DateTime.to_iso8601(start_time)} to #{DateTime.to_iso8601(end_time)}"
    )

    # Calculate time chunks to respect API limits
    chunks = calculate_time_chunks(timeframe, start_time, end_time)

    # Fetch data for each chunk concurrently
    results =
      chunks
      |> Task.async_stream(&fetch_chunk_with_retries(symbol, timeframe, elem(&1, 0), elem(&1, 1)),
        max_concurrency: 5,
        ordered: false,
        timeout: 60000
      )
      |> Enum.to_list()

    # Check for errors, considering both handled errors ({:ok, {:error, _}}) and crashes ({:exit, _})
    errors =
      Enum.filter(results, fn
        # Handled error within the task
        {:ok, {:error, _}} -> true
        # Task crashed
        {:exit, _} -> true
        _ -> false
      end)

    if errors != [] do
      # Extract reasons more robustly
      reasons =
        Enum.map(errors, fn
          {:ok, {:error, reason}} -> to_string(reason)
          {:exit, reason} -> "Task crashed: #{inspect(reason)}"
          # Should not happen with the filter
          _ -> "Unknown error structure"
        end)

      Logger.error(
        "Errors encountered during historical data fetch for #{symbol}/#{timeframe}: #{inspect(reasons)}"
      )

      {:error, "Failed to fetch some historical data ranges: #{Enum.join(reasons, "; ")}"}
    else
      # Combine successful data, extracting from {:ok, {:ok, data}}
      all_raw_data =
        results
        # Filter only successful results
        |> Enum.filter(fn
          {:ok, {:ok, _}} -> true
          _ -> false
        end)
        # Extract data
        |> Enum.flat_map(fn {:ok, {:ok, data}} -> data end)

      if Enum.empty?(all_raw_data) do
        Logger.info(
          "No new raw historical data found to process for #{symbol}/#{timeframe} in the specified range."
        )

        {:ok, 0}
      else
        # Prepare and store the data
        prepared_data = DataProcessor.prepare_for_storage(all_raw_data, symbol, timeframe)

        if Enum.empty?(prepared_data) do
          Logger.warning(
            "No valid candles remained after processing for #{symbol}/#{timeframe}. Raw count: #{length(all_raw_data)}"
          )

          {:ok, 0}
        else
          # Store in database with on_conflict: nothing to avoid duplicates
          try do
            case Repo.insert_all(MarketData, prepared_data,
                   on_conflict: :nothing,
                   returning: false
                 ) do
              {count, _} ->
                Logger.info(
                  "Successfully stored #{count} historical candles for #{symbol}/#{timeframe}"
                )

                {:ok, count}
            end
          rescue
            e in [Ecto.QueryError, DBConnection.ConnectionError] ->
              Logger.error(
                "Database error storing historical data for #{symbol}/#{timeframe}: #{inspect(e)}"
              )

              {:error, "Database error storing historical data"}
          end
        end
      end
    end
  end

  # Fetches a single chunk of historical data with retries.
  defp fetch_chunk_with_retries(symbol, timeframe, start_time, end_time, retry_count \\ 0) do
    max_retries = 3
    # Ensure start_time is not after end_time which can happen with chunking logic
    if DateTime.compare(start_time, end_time) == :gt do
      # Return empty list if range is invalid
      {:ok, []}
    else
      case fetch_from_binance(symbol, timeframe, start_time, end_time) do
        {:ok, data} ->
          {:ok, data}

        {:error, reason} when retry_count < max_retries ->
          # Exponential backoff: 1s, 2s, 4s
          backoff_ms = (:math.pow(2, retry_count) * 1000) |> round()

          Logger.warning(
            "Retrying fetch for #{symbol}/#{timeframe} [#{retry_count + 1}/#{max_retries}] after #{backoff_ms}ms. Error: #{inspect(reason)}"
          )

          :timer.sleep(backoff_ms)
          fetch_chunk_with_retries(symbol, timeframe, start_time, end_time, retry_count + 1)

        {:error, reason} ->
          Logger.error(
            "Failed to fetch data chunk for #{symbol}/#{timeframe} after #{max_retries} retries. Range: #{DateTime.to_iso8601(start_time)} to #{DateTime.to_iso8601(end_time)}. Error: #{inspect(reason)}"
          )

          {:error, "Failed to fetch historical data chunk: #{inspect(reason)}"}
      end
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
  defp calculate_time_chunks(timeframe, start_time, end_time) do
    # Use helper
    candle_seconds = TimeframeHelper.timeframe_to_seconds(timeframe)

    if candle_seconds == 0 do
      Logger.error("Invalid timeframe '#{timeframe}' provided for chunk calculation.")
      # Return a single chunk to avoid errors, maybe fetch fails later
      [{start_time, end_time}]
    else
      # Calculate maximum time range per request (in seconds)
      # Subtract 1 candle duration to avoid edge cases with inclusive start/end times in API
      max_range_seconds = candle_seconds * (@max_candles_per_request - 1)

      # Split into chunks
      split_into_chunks(start_time, end_time, max_range_seconds, [])
    end
  end

  # Recursively splits a time range into smaller chunks.
  defp split_into_chunks(current_start, end_time, max_range_seconds, chunks) do
    # If current_start is already past end_time, return the chunks
    if DateTime.compare(current_start, end_time) != :lt do
      Enum.reverse(chunks)
    else
      # Calculate the end of this chunk
      chunk_end_ideal = DateTime.add(current_start, max_range_seconds, :second)

      # Ensure chunk_end doesn't exceed the overall end_time
      actual_chunk_end =
        if DateTime.compare(chunk_end_ideal, end_time) == :gt do
          end_time
        else
          chunk_end_ideal
        end

      # Add this chunk to the list
      updated_chunks = [{current_start, actual_chunk_end} | chunks]

      # Calculate the start for the next chunk. Add 1 second to avoid overlap.
      next_start = DateTime.add(actual_chunk_end, 1, :second)

      # Continue splitting if the next start is still before or at the end time
      if DateTime.compare(next_start, end_time) != :gt do
        split_into_chunks(next_start, end_time, max_range_seconds, updated_chunks)
      else
        # We've covered the whole range
        Enum.reverse(updated_chunks)
      end
    end
  end

  # Converts a timeframe string from Phoenix format to Binance format if needed
  defp convert_timeframe(timeframe) do
    # Placeholder for any timeframe conversion logic needed
    # Example: If Binance uses "1H" instead of "1h"
    # case timeframe do
    #   "1h" -> "1H"
    #   "4h" -> "4H"
    #   "1d" -> "1D"
    #   _ -> timeframe
    # end
    # Assuming format is currently compatible
    timeframe
  end
end
