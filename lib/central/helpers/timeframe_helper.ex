defmodule Central.Helpers.TimeframeHelper do
  @moduledoc """
  Provides utility functions for handling timeframes.
  """

  require Logger

  @timeframe_seconds %{
    "1m" => 60,
    "3m" => 3 * 60,
    "5m" => 5 * 60,
    "15m" => 15 * 60,
    "30m" => 30 * 60,
    "1h" => 3600,
    "2h" => 2 * 3600,
    "4h" => 4 * 3600,
    "6h" => 6 * 3600,
    "8h" => 8 * 3600,
    "12h" => 12 * 3600,
    "1d" => 86400,
    "3d" => 3 * 86400,
    "1w" => 7 * 86400
    # Add other relevant timeframes if needed
  }

  @doc """
  Converts a timeframe string (e.g., "1h", "15m") into its duration in seconds.

  Returns 0 and logs an error for unknown timeframes.
  """
  def timeframe_to_seconds(timeframe) when is_binary(timeframe) do
    case Map.get(@timeframe_seconds, timeframe) do
      nil ->
        Logger.error("Unknown timeframe received: #{inspect(timeframe)}")
        # Return 0 for unknown timeframes
        0

      seconds ->
        seconds
    end
  end

  def timeframe_to_seconds(other) do
    Logger.error("Invalid timeframe format received: #{inspect(other)}. Expected a string.")
    0
  end

  @doc """
  Returns a list of commonly supported timeframe strings.
  """
  def supported_timeframes do
    Map.keys(@timeframe_seconds)
  end
end
