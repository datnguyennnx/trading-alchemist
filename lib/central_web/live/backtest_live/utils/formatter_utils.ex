defmodule CentralWeb.BacktestLive.Utils.FormatterUtils do
  @moduledoc """
  Utility functions for formatting data in the backtest components.
  """

  @doc """
  Formats a datetime for display in the UI.
  Supports both DateTime and NaiveDateTime.
  """
  def format_datetime(nil), do: "N/A"

  def format_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%b %d, %Y %H:%M")
  end

  def format_datetime(%NaiveDateTime{} = datetime) do
    datetime
    |> NaiveDateTime.truncate(:second)
    |> Calendar.strftime("%b %d, %Y %H:%M")
  end

  def format_datetime(_), do: "Invalid Date"

  @doc """
  Formats a percentage value for display.
  """
  def format_percent(nil), do: "N/A"

  def format_percent(decimal) when is_number(decimal) do
    "#{:erlang.float_to_binary(decimal * 100, decimals: 2)}%"
  end

  def format_percent(decimal) do
    case Decimal.to_float(decimal) do
      value when is_number(value) ->
        "#{:erlang.float_to_binary(value * 100, decimals: 2)}%"
        # The _ case is unreachable as Decimal.to_float returns a float or raises.
    end
  rescue
    _ -> "N/A"
  end

  @doc """
  Returns a CSS class based on whether a value is positive, negative, or zero.
  """
  def color_class(nil), do: "text-muted-foreground"

  def color_class(%Decimal{} = value) do
    case Decimal.compare(value, Decimal.new(0)) do
      :gt -> "text-green-600 dark:text-green-400"
      :lt -> "text-red-600 dark:text-red-400"
      :eq -> "text-muted-foreground"
    end
  end

  def color_class(value) when is_number(value) do
    cond do
      value > 0 -> "text-green-600 dark:text-green-400"
      value < 0 -> "text-red-600 dark:text-red-400"
      true -> "text-muted-foreground"
    end
  end

  def color_class(_), do: "text-muted-foreground"

  @doc """
  Formats a balance value with a currency symbol and 2 decimal places.
  """
  def format_balance(balance) when is_number(balance) do
    "$#{:erlang.float_to_binary(balance, decimals: 2)}"
  end

  def format_balance(_), do: "$0.00"

  @doc """
  Formats a number or Decimal into a currency string (e.g., $1,234.56).
  Handles nil by returning 'N/A'.
  """
  def format_currency(nil), do: "N/A"

  def format_currency(%Decimal{} = value) do
    # Fix for the Decimal.to_string/2 error - use Decimal.round first
    rounded = Decimal.round(value, 2)
    "$#{Decimal.to_string(rounded)}"
  end

  def format_currency(value) when is_number(value) do
    # Consider adding number formatting (commas) for larger values if needed
    "$#{:erlang.float_to_binary(value, decimals: 2)}"
  end

  # Catch-all for unexpected types
  def format_currency(_), do: "N/A"
end
