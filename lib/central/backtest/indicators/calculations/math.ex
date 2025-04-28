defmodule Central.Backtest.Indicators.Calculations.Math do
  @moduledoc """
  Common mathematical functions used across various indicators.
  """

  @doc """
  Safe division that handles division by zero.
  Returns 0 when divisor is 0.
  """
  def safe_div(_numerator, 0), do: Decimal.new(0)

  def safe_div(numerator, %Decimal{} = divisor) do
    if Decimal.equal?(divisor, Decimal.new(0)),
      do: Decimal.new(0),
      else: Decimal.div(numerator, divisor)
  end

  def safe_div(numerator, divisor) when is_number(numerator) and is_number(divisor),
    do: numerator / divisor

  @doc """
  Calculates the square root of a Decimal value.
  """
  def decimal_sqrt(%Decimal{} = decimal) do
    # Convert to float for sqrt calculation
    {float, _} = Decimal.to_string(decimal) |> Float.parse()
    sqrt = :math.sqrt(float)
    Decimal.from_float(sqrt)
  end

  @doc """
  Calculates the average of a list of Decimal values.
  """
  def average(values) when is_list(values) and length(values) > 0 do
    sum = Enum.reduce(values, Decimal.new(0), &Decimal.add/2)
    Decimal.div(sum, Decimal.new(Enum.count(values)))
  end

  def average([]), do: Decimal.new(0)
end
