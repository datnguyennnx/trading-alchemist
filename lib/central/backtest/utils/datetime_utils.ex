defmodule Central.Backtest.Utils.DatetimeUtils do
  @moduledoc """
  Utility functions for working with datetime values in the backtest system and throughout the application.
  """

  require Logger

  @doc """
  Converts any datetime format to a UTC DateTime for database storage.
  Handles NaiveDateTime, DateTime, and string formats.

  ## Parameters
    - value: The datetime value to convert

  ## Returns
    - DateTime in UTC timezone
    - or nil if conversion fails
  """
  def to_utc_datetime(value) do
    cond do
      # For NaiveDateTime, convert to UTC DateTime
      is_struct(value, NaiveDateTime) ->
        DateTime.from_naive!(value, "Etc/UTC")

      # For DateTime, ensure it's in UTC
      is_struct(value, DateTime) ->
        if value.time_zone == "Etc/UTC" do
          value
        else
          DateTime.shift_zone!(value, "Etc/UTC")
        end

      # Parse ISO8601 strings
      is_binary(value) ->
        case DateTime.from_iso8601(value) do
          {:ok, dt, _} ->
            dt

          {:error, _} ->
            # Try as NaiveDateTime
            case NaiveDateTime.from_iso8601(value) do
              {:ok, ndt} ->
                DateTime.from_naive!(ndt, "Etc/UTC")

              {:error, _} ->
                Logger.warning("Failed to parse datetime string: #{inspect(value)}")
                nil
            end
        end

      # Default/fallback
      is_nil(value) ->
        nil

      true ->
        Logger.warning("Unsupported datetime format: #{inspect(value)}")
        nil
    end
  end

  @doc """
  Alias for to_utc_datetime/1 with a shorter name.

  ## Parameters
    - value: The datetime value to convert

  ## Returns
    - DateTime in UTC timezone or nil if conversion fails
  """
  def to_utc(value) do
    to_utc_datetime(value)
  end

  @doc """
  Creates a current UTC datetime truncated to seconds.
  Useful for database timestamps when using :utc_datetime fields.

  ## Returns
    - Current UTC DateTime with second precision
  """
  def utc_now_sec do
    DateTime.utc_now() |> DateTime.truncate(:second)
  end

  @doc """
  Alias for utc_now_sec/0 with a shorter name.

  ## Returns
    - Current UTC DateTime with second precision
  """
  def utc_now do
    utc_now_sec()
  end

  @doc """
  Creates a current UTC NaiveDateTime truncated to seconds.
  Useful for database timestamps when using :naive_datetime fields
  like inserted_at and updated_at.

  ## Returns
    - Current UTC NaiveDateTime with second precision
  """
  def naive_utc_now_sec do
    NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
  end

  @doc """
  Alias for naive_utc_now_sec/0 with a shorter name.

  ## Returns
    - Current UTC NaiveDateTime with second precision
  """
  def naive_utc_now do
    naive_utc_now_sec()
  end

  @doc """
  Converts a DateTime to a Unix timestamp in seconds.

  ## Parameters
    - datetime: The DateTime to convert

  ## Returns
    - Unix timestamp in seconds
  """
  def to_unix(datetime) do
    DateTime.to_unix(to_utc(datetime))
  end

  @doc """
  Converts a DateTime to a Unix timestamp in milliseconds.

  ## Parameters
    - datetime: The DateTime to convert

  ## Returns
    - Unix timestamp in milliseconds
  """
  def to_unix_ms(datetime) do
    DateTime.to_unix(to_utc(datetime), :millisecond)
  end

  @doc """
  Converts a Unix timestamp to a DateTime.

  ## Parameters
    - timestamp: Unix timestamp (in seconds)
    - unit: The unit of the timestamp (:second, :millisecond) - defaults to :second

  ## Returns
    - DateTime in UTC
  """
  def from_unix(timestamp, unit \\ :second) do
    DateTime.from_unix!(timestamp, unit)
  end

  @doc """
  Formats a datetime for display in the UI.

  ## Parameters
    - datetime: DateTime or NaiveDateTime to format
    - format: Format string (default: "%Y-%m-%d %H:%M:%S")

  ## Returns
    - Formatted datetime string
  """
  def format(datetime, format \\ "%Y-%m-%d %H:%M:%S") do
    datetime = normalize_datetime(datetime)
    Calendar.strftime(datetime, format)
  end

  @doc """
  Parses a datetime string in ISO 8601 format.

  ## Parameters
    - string: ISO 8601 datetime string

  ## Returns
    - {:ok, datetime} on success
    - {:error, reason} on failure
  """
  def parse_iso(string) when is_binary(string) do
    case DateTime.from_iso8601(string) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get the time difference in the specified unit between two datetimes.

  ## Parameters
    - datetime1: The first datetime
    - datetime2: The second datetime (defaults to now)
    - unit: The time unit for the result (:second, :minute, :hour, :day) - defaults to :second

  ## Returns
    - Time difference in the specified unit (positive if datetime1 < datetime2)
  """
  def diff(datetime1, datetime2 \\ utc_now(), unit \\ :second) do
    datetime1 = to_utc(datetime1)
    datetime2 = to_utc(datetime2)

    DateTime.diff(datetime2, datetime1, unit)
  end

  @doc """
  Add a time interval to a datetime.

  ## Parameters
    - datetime: The base datetime
    - value: Number of units to add (can be negative)
    - unit: The time unit (:second, :minute, :hour, :day) - defaults to :second

  ## Returns
    - New DateTime with the added interval
  """
  def add(datetime, value, unit \\ :second) do
    datetime = to_utc(datetime)

    case unit do
      :second ->
        DateTime.add(datetime, value, :second)

      :minute ->
        DateTime.add(datetime, value * 60, :second)

      :hour ->
        DateTime.add(datetime, value * 3600, :second)

      :day ->
        DateTime.add(datetime, value * 86400, :second)

      _ ->
        Logger.warning("Unsupported time unit: #{inspect(unit)}. Using :second")
        DateTime.add(datetime, value, :second)
    end
  end

  @doc """
  Normalize a datetime value into a DateTime struct.

  ## Parameters
    - datetime: DateTime, NaiveDateTime, or ISO string

  ## Returns
    - DateTime in UTC
    - or the original value if it cannot be converted
  """
  def normalize_datetime(datetime) do
    case to_utc(datetime) do
      %DateTime{} = dt -> dt
      nil -> datetime
    end
  end

  @doc """
  Truncate a datetime to a specific precision.

  ## Parameters
    - datetime: The datetime to truncate
    - precision: Precision level (:second, :minute, :hour, :day)

  ## Returns
    - Truncated DateTime
  """
  def truncate(datetime, precision \\ :second) do
    datetime = normalize_datetime(datetime)

    case precision do
      :second ->
        DateTime.truncate(datetime, :second)

      :minute ->
        %{datetime | second: 0, microsecond: {0, 0}}

      :hour ->
        %{datetime | minute: 0, second: 0, microsecond: {0, 0}}

      :day ->
        %{datetime | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}

      _ ->
        Logger.warning("Unsupported precision: #{inspect(precision)}. Using :second")
        DateTime.truncate(datetime, :second)
    end
  end
end
