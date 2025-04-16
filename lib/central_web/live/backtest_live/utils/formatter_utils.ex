defmodule CentralWeb.BacktestLive.Utils.FormatterUtils do
  @moduledoc """
  Utility functions for formatting values for display in the backtest LiveView UI.
  """

  alias Central.Backtest.Utils.{DecimalUtils, DatetimeUtils}

  @doc """
  Format a datetime for display in the UI.

  ## Parameters
    - datetime: The datetime to format
    - format: Format string (optional)

  ## Returns
    - Formatted datetime string
    - "N/A" if datetime is nil
  """
  def format_datetime(datetime, format \\ "%Y-%m-%d %H:%M:%S")
  def format_datetime(nil, _format), do: "N/A"
  def format_datetime(%NaiveDateTime{} = naive_datetime, format) do
    naive_datetime
    |> NaiveDateTime.truncate(:second)
    |> Calendar.strftime(format)
  end
  def format_datetime(%DateTime{} = datetime, format) do
    datetime
    |> DateTime.truncate(:second)
    |> Calendar.strftime(format)
  end
  def format_datetime(datetime, format) when is_binary(datetime) do
    case DatetimeUtils.to_utc(datetime) do
      %DateTime{} = dt -> format_datetime(dt, format)
      _ -> datetime
    end
  end
  def format_datetime(_, _), do: "N/A"

  @doc """
  Format a date for display in the UI.

  ## Parameters
    - datetime: The datetime to format

  ## Returns
    - Formatted date string (YYYY-MM-DD)
    - "N/A" if datetime is nil
  """
  def format_date(datetime) do
    format_datetime(datetime, "%Y-%m-%d")
  end

  @doc """
  Format a time for display in the UI.

  ## Parameters
    - datetime: The datetime to format

  ## Returns
    - Formatted time string (HH:MM:SS)
    - "N/A" if datetime is nil
  """
  def format_time(datetime) do
    format_datetime(datetime, "%H:%M:%S")
  end

  @doc """
  Format a numeric value with specified precision.

  ## Parameters
    - value: The value to format
    - precision: Number of decimal places

  ## Returns
    - Formatted string with the specified precision
    - "N/A" if value is nil
  """
  def format_number(value, precision \\ 2)
  def format_number(nil, _precision), do: "N/A"
  def format_number(value, precision) do
    DecimalUtils.format(value, precision)
  end

  @doc """
  Format a value as a percentage with specified precision.

  ## Parameters
    - value: The value to format (0.1 = 10%)
    - precision: Number of decimal places

  ## Returns
    - Formatted percentage string
    - "N/A" if value is nil
  """
  def format_percent(value, precision \\ 2)
  def format_percent(nil, _precision), do: "N/A"
  def format_percent(value, precision) do
    DecimalUtils.format_percent(value, precision)
  end

  @doc """
  Format a price value with appropriate decimal places.

  ## Parameters
    - price: The price to format
    - precision: Number of decimal places (default: auto)

  ## Returns
    - Formatted price string with appropriate precision
    - "N/A" if price is nil
  """
  def format_price(price, precision \\ nil)
  def format_price(nil, _precision), do: "N/A"
  def format_price(price, precision) do
    precision = precision || auto_precision(price)
    DecimalUtils.format(price, precision)
  end

  @doc """
  Determine appropriate precision for a price based on its magnitude.

  ## Parameters
    - price: The price value

  ## Returns
    - Recommended precision (number of decimal places)
  """
  def auto_precision(price) do
    price_float = DecimalUtils.to_float(price)

    cond do
      is_nil(price_float) -> 2
      price_float >= 10000 -> 2
      price_float >= 1000 -> 2
      price_float >= 100 -> 2
      price_float >= 10 -> 3
      price_float >= 1 -> 4
      price_float >= 0.1 -> 5
      price_float >= 0.01 -> 6
      price_float >= 0.001 -> 7
      true -> 8
    end
  end

  @doc """
  Format a value with a CSS color class based on its sign.

  ## Parameters
    - value: The value to evaluate

  ## Returns
    - CSS class name for coloring based on sign (green for positive, red for negative)
  """
  def color_class(value) do
    cond do
      DecimalUtils.positive?(value) -> "text-green-600"
      DecimalUtils.negative?(value) -> "text-red-600"
      true -> ""
    end
  end

  @doc """
  Format a value with a sign prefix and CSS color.

  ## Parameters
    - value: The value to format
    - precision: Number of decimal places

  ## Returns
    - Map with formatted value and CSS class
  """
  def format_with_color(value, precision \\ 2) do
    formatted = format_number(value, precision)

    formatted =
      if DecimalUtils.positive?(value) do
        "+#{formatted}"
      else
        formatted
      end

    %{
      value: formatted,
      class: color_class(value)
    }
  end

  @doc """
  Format a percentage with a sign prefix and CSS color.

  ## Parameters
    - value: The percentage value to format
    - precision: Number of decimal places

  ## Returns
    - Map with formatted value and CSS class
  """
  def format_percent_with_color(value, precision \\ 2) do
    formatted = format_percent(value, precision)

    formatted =
      if DecimalUtils.positive?(value) and not DecimalUtils.zero?(value) do
        "+#{formatted}"
      else
        formatted
      end

    %{
      value: formatted,
      class: color_class(value)
    }
  end
end
