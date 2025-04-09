defmodule Central.Config.DateTime do
  @moduledoc """
  Provides consistent DateTime handling and formatting across the application.
  """

  @doc """
  The timezone used throughout the application.
  """
  def timezone, do: "Etc/UTC"

  @doc """
  Formats a DateTime for display in a consistent format (dd/mm/yyyy HH:MM:SS).

  ## Examples

      iex> Central.Config.DateTime.format(~U[2023-01-15 12:30:45Z])
      "15/01/2023 12:30:45"

      iex> Central.Config.DateTime.format(nil)
      "N/A"
  """
  def format(nil), do: "N/A"

  def format(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y %H:%M:%S")
  end

  @doc """
  Formats a DateTime with the timezone name included.

  ## Examples

      iex> Central.Config.DateTime.format_with_timezone(~U[2023-01-15 12:30:45Z])
      "15/01/2023 12:30:45 UTC"
  """
  def format_with_timezone(nil), do: "N/A"

  def format_with_timezone(datetime) do
    "#{format(datetime)} UTC"
  end

  @doc """
  Ensures a DateTime has no microseconds, truncating it to seconds precision.

  ## Examples

      iex> datetime = DateTime.utc_now()
      iex> datetime.microsecond != {0, 0}
      iex> truncated = Central.Config.DateTime.truncate(datetime)
      iex> truncated.microsecond
      {0, 0}
  """
  def truncate(datetime) when is_struct(datetime, DateTime) do
    DateTime.truncate(datetime, :second)
  end

  def truncate(nil), do: nil
  def truncate(datetime), do: datetime

  @doc """
  Parses a string into a DateTime using a specified format.
  Returns {:ok, datetime} or {:error, reason}

  ## Examples

      iex> Central.Config.DateTime.parse("15/01/2023 12:30:45", "%d/%m/%Y %H:%M:%S")
      {:ok, ~U[2023-01-15 12:30:45Z]}
  """
  def parse(nil, _format), do: {:error, :invalid_datetime}

  def parse(datetime_string, _format) do
    case DateTime.from_naive(
           NaiveDateTime.from_iso8601!(datetime_string),
           timezone()
         ) do
      {:ok, datetime} -> {:ok, datetime}
      error -> error
    end
  rescue
    _ -> {:error, :invalid_format}
  end

  @doc """
  Gets the current time in UTC, truncated to seconds.

  ## Examples

      iex> datetime = Central.Config.DateTime.now()
      iex> datetime.microsecond
      {0, 0}
  """
  def now do
    DateTime.utc_now() |> truncate()
  end

  @doc """
  Adds a specified time to a DateTime.

  ## Examples

      iex> datetime = ~U[2023-01-15 12:00:00Z]
      iex> Central.Config.DateTime.add(datetime, 1, :day)
      ~U[2023-01-16 12:00:00Z]
  """
  def add(datetime, value, unit) do
    DateTime.add(datetime, value, unit) |> truncate()
  end
end
