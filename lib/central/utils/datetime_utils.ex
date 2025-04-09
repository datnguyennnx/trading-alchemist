defmodule Central.Utils.DatetimeUtils do
  @moduledoc """
  Utility functions for working with datetime values.
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
  Creates a current UTC datetime truncated to seconds.
  Useful for database timestamps when using :utc_datetime fields.

  ## Returns
    - Current UTC DateTime with second precision
  """
  def utc_now_sec do
    DateTime.utc_now() |> DateTime.truncate(:second)
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
end
