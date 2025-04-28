defmodule Central.MarketData.Exchange.Binance.Client do
  @moduledoc """
  Binance API Client for fetching market data.
  Handles rate limiting, error handling, and retry logic.
  """

  use Tesla
  require Logger

  alias Central.Config.DateTime, as: DateTimeConfig
  alias Central.Config.HTTP, as: HTTPConfig
  # Assuming MarketData schema might live under MarketData now - Removed unused
  # alias Central.MarketData.Schemas.MarketData
  # Or keep Central.Backtest.Schemas.MarketData if it's staying there

  import HTTPConfig,
    only: [
      extract_error_message: 1
    ]

  # Import HTTP status code ranges for use in guard clauses
  @success_status_range HTTPConfig.success_status_range()
  @client_error_range HTTPConfig.client_error_range()
  @server_error_range HTTPConfig.server_error_range()

  @base_url "https://api.binance.com"

  plug Tesla.Middleware.BaseUrl, @base_url
  plug Tesla.Middleware.JSON

  plug Tesla.Middleware.Retry,
    delay: 500,
    max_retries: 5,
    max_delay: 5000,
    timeout: 30_000,
    should_retry: fn
      {:ok, %{status: status}} when status >= 500 -> true
      {:error, _} -> true
      _ -> false
    end,
    max_backoff_ms: 5000

  @doc """
  Get kline/candlestick data for a symbol and interval

  Returns a list of market data structures suitable for processing/storage.

  ## Parameters
    - symbol: String - The trading pair symbol (e.g., "BTCUSDT")
    - interval: String - The interval (e.g., "1m", "1h", "1d")
    - start_time: DateTime - Optional start time
    - end_time: DateTime - Optional end time
    - limit: Integer - Optional limit (default: 500, max: 1000)

  ## Returns
    - {:ok, list_of_candle_maps} - List of maps with :timestamp, :open, :high, :low, :close, :volume
    - {:error, reason} - Error reason
  """
  def get_klines(symbol, interval, opts \\ []) do
    # Extract and validate options
    start_time = Keyword.get(opts, :start_time)
    end_time = Keyword.get(opts, :end_time)
    limit = Keyword.get(opts, :limit, 500)

    # Build query params
    query = [
      symbol: symbol,
      interval: interval,
      limit: limit
    ]

    # Add optional params if provided
    query =
      if start_time,
        do: [{:startTime, DateTime.to_unix(start_time, :millisecond)} | query],
        else: query

    query =
      if end_time, do: [{:endTime, DateTime.to_unix(end_time, :millisecond)} | query], else: query

    # Make the request
    "/api/v3/klines"
    |> get(query: query)
    |> handle_response(fn data ->
      Enum.map(data, &parse_kline(&1, symbol, interval))
    end)
  end

  @doc false
  # Parse a single kline/candlestick data point from the raw API list format
  def parse_kline(kline, symbol, interval) do
    # Extract data from the kline
    [
      open_time,
      open,
      high,
      low,
      close,
      volume,
      _close_time,
      _quote_volume,
      _trades,
      _taker_buy_base_volume,
      _taker_buy_quote_volume,
      _ignore
    ] = kline

    # Convert timestamp to DateTime
    timestamp =
      open_time
      |> div(1000)
      |> DateTime.from_unix!()
      |> DateTimeConfig.truncate() # Use centralized config

    # Return a map, not a MarketData struct directly
    # Let the caller (e.g., HistoricalDataFetcher) handle struct creation/DB mapping
    %{
      symbol: symbol,
      timeframe: interval,
      timestamp: timestamp,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
      source: "binance" # Hardcoded for now
    }
  end

  @doc """
  Fetch exchange information including trading rules and symbol info.

  ## Returns
    - {:ok, exchange_info} on success
    - {:error, reason} on failure
  """
  def get_exchange_info do
    get("/api/v3/exchangeInfo")
    |> handle_response(fn body -> body end)
  end

  @doc """
  Fetch available trading pairs matching the optional symbol parameter.
  If no symbol is provided, all trading pairs are returned.

  ## Parameters
    - symbol: Optional symbol prefix (e.g., "BTC" would match all BTC pairs)

  ## Returns
    - {:ok, symbols} on success
    - {:error, reason} on failure
  """
  def get_symbols(symbol \\ nil) do
    with {:ok, exchange_info} <- get_exchange_info() do
      symbols =
        exchange_info["symbols"]
        |> Enum.filter(fn info ->
          info["status"] == "TRADING" &&
            (is_nil(symbol) || String.contains?(info["symbol"], String.upcase(symbol)))
        end)
        |> Enum.map(& &1["symbol"])

      {:ok, symbols}
    end
  end

  @doc """
  Fetch current price for a single symbol or all symbols.

  ## Parameters
    - symbol: Optional symbol to fetch price for

  ## Returns
    - {:ok, price} on success with symbol specified
    - {:ok, prices} on success with no symbol specified
    - {:error, reason} on failure
  """
  def get_price(symbol \\ nil) do
    query = if symbol, do: [symbol: String.upcase(symbol)], else: []

    get("/api/v3/ticker/price", query: query)
    |> handle_response(fn body -> body end)
  end

  # Handle HTTP response and transform data if successful
  defp handle_response({:ok, %{status: status, body: body}}, transform_fn)
       when status in @success_status_range do
    {:ok, transform_fn.(body)}
  end

  # Handle client errors (4xx)
  defp handle_response({:ok, %{status: status, body: body}}, _transform_fn)
       when status in @client_error_range do
    log_error_response(status, body, :client_error)
    {:error, "Client error: #{status} - #{extract_error_message(body)}"}
  end

  # Handle server errors (5xx)
  defp handle_response({:ok, %{status: status, body: body}}, _transform_fn)
       when status in @server_error_range do
    log_error_response(status, body, :server_error)
    {:error, "Server error: #{status} - #{extract_error_message(body)}"}
  end

  # Handle unexpected status codes
  defp handle_response({:ok, %{status: status, body: body}}, _transform_fn) do
    log_error_response(status, body, :unexpected_status)
    {:error, "Unexpected status: #{status} - #{extract_error_message(body)}"}
  end

  # Handle network errors
  defp handle_response({:error, reason}, _transform_fn) do
    Logger.error("Binance API request failed: #{inspect(reason)}")
    {:error, "Request failed: #{inspect(reason)}"}
  end

  # Log error responses with appropriate level
  defp log_error_response(status, body, error_type) do
    message = "Binance API #{error_type}: status=#{status}, body=#{inspect(body)}"

    case error_type do
      :client_error -> Logger.warning(message)
      _ -> Logger.error(message)
    end
  end

  @doc """
  Download historical market data for a symbol and interval.
  This function directly calls `get_klines` and assumes the caller
  (e.g., HistoricalDataFetcher, MarketSyncWorker) handles chunking if needed.

  ## Parameters
    - symbol: Trading pair (e.g., "BTCUSDT")
    - interval: Timeframe (e.g., "1m", "5m", "1h", "1d")
    - start_time: Starting time (DateTime)
    - end_time: Ending time (DateTime)
    - limit: Optional limit (default: 1000)

  ## Returns
    - {:ok, list_of_candle_maps} on success
    - {:error, reason} on failure
  """
  def download_historical_data(symbol, interval, start_time, end_time, limit \\ 1000) do
    # Use get_klines to fetch data for the specified range
    # The caller is responsible for handling potential chunking for larger ranges
    opts = [
      start_time: start_time,
      end_time: end_time,
      limit: limit
    ]

    get_klines(symbol, interval, opts)
  end
end
