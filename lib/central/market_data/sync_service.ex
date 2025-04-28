defmodule Central.MarketData.SyncService do
  @moduledoc """
  Ensures that historical market data for a specific range is available in the database.

  This service checks the existing data range and triggers fetching for any missing
  periods using the HistoricalDataFetcher. It's designed primarily for ensuring
  data completeness before running backtests or analyses.
  """

  require Logger

  alias Central.Backtest.Contexts.MarketDataContext
  alias Central.MarketData.Pipeline.HistoricalDataFetcher

  @doc """
  Ensures data for the given symbol, timeframe, and date range exists in the database.

  Checks the current range and fetches missing data segments if necessary.

  ## Parameters
    - symbol: Trading pair symbol (e.g., "BTCUSDT")
    - timeframe: Candle timeframe (e.g., "1h")
    - start_time: The required start DateTime (UTC)
    - end_time: The required end DateTime (UTC)

  ## Returns
    - `{:ok, :available}`: If the full range already exists.
    - `{:ok, :synced}`: If data was successfully fetched to cover the range.
    - `{:error, reason}`: If checking or fetching failed.
  """
  def ensure_data_range(symbol, timeframe, start_time, end_time) do
    unless DateTime.compare(start_time, end_time) != :gt do
      Logger.warning(
        "ensure_data_range called with start_time >= end_time. Start: #{inspect(start_time)}, End: #{inspect(end_time)}. Assuming data is available."
      )

      {:ok, :available}
    else
      case MarketDataContext.get_date_range(symbol, timeframe) do
        {nil, nil} ->
          # No data exists, fetch the entire requested range
          Logger.info(
            "No existing data for #{symbol}/#{timeframe}. Fetching full range: #{inspect(start_time)} to #{inspect(end_time)}"
          )

          fetch_and_report(symbol, timeframe, start_time, end_time)

        {db_start, db_end} ->
          # Data exists, check for gaps
          missing_periods = calculate_missing_periods(start_time, end_time, db_start, db_end)

          if Enum.empty?(missing_periods) do
            {:ok, :available}
          else
            Logger.info(
              "Found #{length(missing_periods)} missing period(s) for #{symbol}/#{timeframe}. Fetching..."
            )

            # Fetch each missing period
            fetch_results =
              missing_periods
              |> Task.async_stream(&fetch_and_report(symbol, timeframe, elem(&1, 0), elem(&1, 1)),
                max_concurrency: 3,
                ordered: false,
                # Use HistoricalDataFetcher's internal timeouts
                timeout: :infinity
              )
              |> Enum.to_list()

            # Check results - succeed if all fetches were :ok
            if Enum.all?(fetch_results, fn {:ok, res} -> Keyword.get(res, :status) == :ok end) do
              {:ok, :synced}
            else
              errors =
                fetch_results
                |> Enum.filter(fn {:ok, res} -> Keyword.get(res, :status) != :ok end)
                |> Enum.map(fn {:ok, res} -> Keyword.get(res, :reason, "Unknown fetch error") end)

              Logger.error(
                "Failed to fetch some missing periods for #{symbol}/#{timeframe}: #{inspect(errors)}"
              )

              {:error, "Failed to sync missing data periods: #{Enum.join(errors, "; ")}"}
            end
          end
      end
    end
  end

  # --- Private Helpers ---

  @doc false
  # Fetches a range and returns a consistent status map for Task.async_stream
  def fetch_and_report(symbol, timeframe, start_time, end_time) do
    case HistoricalDataFetcher.fetch_and_store_range(symbol, timeframe, start_time, end_time) do
      {:ok, count} ->
        Logger.info(
          "Successfully fetched #{count} candles for #{symbol}/#{timeframe} from #{inspect(start_time)} to #{inspect(end_time)}"
        )

        %{status: :ok, count: count}

      {:error, reason} ->
        Logger.error(
          "Failed to fetch range for #{symbol}/#{timeframe} from #{inspect(start_time)} to #{inspect(end_time)}: #{inspect(reason)}"
        )

        %{status: :error, reason: reason}
    end
  end

  @doc false
  # Calculates the time periods within the required range [req_start, req_end]
  # that are *not* covered by the existing database range [db_start, db_end].
  # Assumes db_start and db_end are not nil.
  def calculate_missing_periods(req_start, req_end, db_start, db_end) do
    # Add a small buffer (1 timeframe duration) to db times to avoid fetching single overlaps
    # timeframe_seconds = TimeframeHelper.timeframe_to_seconds(timeframe) # Need timeframe here...
    # For simplicity now, let's not buffer, rely on on_conflict: :nothing

    periods = []

    # 1. Check period before existing data
    # If req_start is before db_start
    if DateTime.compare(req_start, db_start) == :lt do
      # The missing period is [req_start, db_start - 1 second]
      missing_end = DateTime.add(db_start, -1, :second)
      # Ensure the period is valid (start < end)
      if DateTime.compare(req_start, missing_end) == :lt do
        _periods = [{req_start, missing_end} | periods]
      end
    end

    # 2. Check period after existing data
    # If req_end is after db_end
    if DateTime.compare(req_end, db_end) == :gt do
      # The missing period is [db_end + 1 second, req_end]
      missing_start = DateTime.add(db_end, 1, :second)
      # Ensure the period is valid (start < end)
      if DateTime.compare(missing_start, req_end) == :lt do
        _periods = [{missing_start, req_end} | periods]
      end
    end

    # Reverse because we prepended
    Enum.reverse(periods)
  end
end
