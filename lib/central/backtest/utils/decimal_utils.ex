defmodule Central.Backtest.Utils.DecimalUtils do
  @moduledoc """
  Utility functions for working with Decimal values in the backtest system.
  Provides helper functions for parsing, comparing, and converting decimal values.
  """

  require Logger

  @doc """
  Parse a value into a Decimal type, handling various input formats.

  ## Parameters
    - value: The value to convert (binary string, number, or nil)

  ## Returns
    - Decimal value or Decimal.new(0) if conversion fails
  """
  def parse(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} -> decimal
      {decimal, _} -> decimal
      :error -> Decimal.new(0)
    end
  end

  def parse(value) when is_number(value) do
    Decimal.new(value)
  end

  def parse(nil), do: Decimal.new(0)
  def parse(_), do: Decimal.new(0)

  @doc """
  Parse a value that might be a string, decimal, or number into a float.
  Useful for numeric calculations where float precision is acceptable.

  ## Parameters
    - value: The value to be converted to float

  ## Returns
    - float value or 0.0 if conversion fails
  """
  def to_float(value) do
    cond do
      is_nil(value) ->
        0.0

      is_binary(value) ->
        case Float.parse(value) do
          {num, _} -> num
          :error -> 0.0
        end

      is_number(value) ->
        value * 1.0

      # Handle Decimal type explicitly
      match?(%Decimal{}, value) ->
        Decimal.to_float(value)

      # Generic struct check as fallback
      is_struct(value) && function_exported?(value.__struct__, :to_float, 1) ->
        value.__struct__.to_float(value)

      true ->
        Logger.warning("Unknown value type for conversion: #{inspect(value)}")
        0.0
    end
  end

  @doc """
  Safely compare two values that may be Decimal or convertible to Decimal.
  Returns :gt, :eq, or :lt similar to Decimal.compare.

  ## Parameters
    - a: First value to compare
    - b: Second value to compare

  ## Returns
    - :gt if a > b
    - :eq if a == b
    - :lt if a < b
  """
  def compare(a, b) do
    a_decimal = parse(a)
    b_decimal = parse(b)
    Decimal.compare(a_decimal, b_decimal)
  end

  @doc """
  Checks if a value is positive (greater than zero).

  ## Parameters
    - value: Value to check

  ## Returns
    - true if value > 0
    - false otherwise
  """
  def positive?(value) do
    compare(value, 0) == :gt
  end

  @doc """
  Checks if a value is negative (less than zero).

  ## Parameters
    - value: Value to check

  ## Returns
    - true if value < 0
    - false otherwise
  """
  def negative?(value) do
    compare(value, 0) == :lt
  end

  @doc """
  Checks if a value is zero.

  ## Parameters
    - value: Value to check

  ## Returns
    - true if value == 0
    - false otherwise
  """
  def zero?(value) do
    compare(value, 0) == :eq
  end

  @doc """
  Format a decimal value with specified precision.

  ## Parameters
    - value: Value to format
    - precision: Number of decimal places (default: 2)

  ## Returns
    - Formatted string with specified precision
  """
  def format(value, precision \\ 2) do
    value
    |> parse()
    |> Decimal.round(precision)
    |> Decimal.to_string()
  end

  @doc """
  Format a decimal as percentage with specified precision.

  ## Parameters
    - value: Decimal value to format (0.1 = 10%)
    - precision: Number of decimal places (default: 2)

  ## Returns
    - Formatted percentage string (e.g., "10.00%")
  """
  def format_percent(value, precision \\ 2) do
    value
    |> parse()
    |> Decimal.mult(Decimal.new(100))
    |> Decimal.round(precision)
    |> Decimal.to_string()
    |> Kernel.<>("%")
  end
end
