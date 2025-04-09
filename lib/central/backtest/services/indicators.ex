defmodule Central.Backtest.Services.Indicators do
  @moduledoc """
  Service for calculating technical indicators.
  Implements common indicators used in trading strategies.
  """

  @doc """
  Calculates a Simple Moving Average (SMA) for a list of candles.

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods to average
    - price_key: Key to use for price (:close, :open, :high, :low)

  ## Returns
    - List of SMA values aligned with the input candles (first period-1 values are nil)
  """
  def sma(candles, period, price_key \\ :close) do
    candles
    |> Enum.map(&Map.get(&1, price_key))
    |> calculate_sma(period, [])
  end

  defp calculate_sma(prices, period, results) when length(prices) < period do
    # Pad with nil for periods with insufficient data
    Enum.reverse(results) ++ List.duplicate(nil, length(prices))
  end

  defp calculate_sma(prices, period, results) do
    {window, _rest} = Enum.split(prices, period)

    # Calculate average for current window
    sum = Enum.reduce(window, Decimal.new(0), &Decimal.add/2)
    avg = Decimal.div(sum, Decimal.new(period))

    # Recurse with remaining prices
    calculate_sma(tl(prices), period, [avg | results])
  end

  @doc """
  Calculates an Exponential Moving Average (EMA) for a list of candles.

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods for the EMA
    - price_key: Key to use for price (:close, :open, :high, :low)

  ## Returns
    - List of EMA values aligned with the input candles (first period-1 values are nil)
  """
  def ema(candles, period, price_key \\ :close) do
    prices = Enum.map(candles, &Map.get(&1, price_key))

    # Calculate multiplier: 2 / (period + 1)
    multiplier = Decimal.div(Decimal.new(2), Decimal.add(Decimal.new(period), Decimal.new(1)))

    # Use SMA as first value
    {sma_values, _} =
      prices
      |> Enum.take(period)
      |> calculate_sma(period, [])
      |> List.pop_at(0)

    # Calculate EMA starting with SMA as seed
    prices
    |> Enum.drop(period - 1)
    |> calculate_ema(multiplier, sma_values, [])
    |> then(fn ema_values ->
      # Add nil values at the beginning to align with input
      List.duplicate(nil, period - 1) ++ Enum.reverse(ema_values)
    end)
  end

  defp calculate_ema([], _multiplier, _prev_ema, results), do: results

  defp calculate_ema([price | rest], multiplier, prev_ema, results) do
    # EMA = Price * multiplier + Previous EMA * (1 - multiplier)
    new_ema =
      Decimal.add(
        Decimal.mult(price, multiplier),
        Decimal.mult(prev_ema, Decimal.sub(Decimal.new(1), multiplier))
      )

    calculate_ema(rest, multiplier, new_ema, [new_ema | results])
  end

  @doc """
  Calculates the Relative Strength Index (RSI) for a list of candles.

  ## Parameters
    - candles: List of market data candles
    - period: Number of periods for the RSI (typically 14)
    - price_key: Key to use for price (:close, :open, :high, :low)

  ## Returns
    - List of RSI values aligned with the input candles (first period values are nil)
  """
  def rsi(candles, period \\ 14, price_key \\ :close) do
    # Extract prices
    prices = Enum.map(candles, &Map.get(&1, price_key))

    # Calculate price changes
    changes = calculate_changes(prices)

    # Separate gains and losses
    {gains, losses} =
      Enum.map(changes, fn change ->
        cond do
          Decimal.compare(change, Decimal.new(0)) == :gt -> {change, Decimal.new(0)}
          Decimal.compare(change, Decimal.new(0)) == :lt -> {Decimal.new(0), Decimal.abs(change)}
          true -> {Decimal.new(0), Decimal.new(0)}
        end
      end)
      |> Enum.unzip()

    # Calculate initial averages (simple averages for the first period)
    initial_avg_gain = Enum.take(gains, period) |> average()
    initial_avg_loss = Enum.take(losses, period) |> average()

    # Calculate RSI for each point using smoothed averages
    calculate_rsi(
      Enum.drop(gains, period),
      Enum.drop(losses, period),
      initial_avg_gain,
      initial_avg_loss,
      period,
      []
    )
    |> then(fn rsi_values ->
      # Add nil values at the beginning to align with input
      List.duplicate(nil, period) ++ Enum.reverse(rsi_values)
    end)
  end

  defp calculate_changes(prices) do
    Enum.zip(Enum.drop(prices, 1), prices)
    |> Enum.map(fn {current, previous} -> Decimal.sub(current, previous) end)
  end

  defp average(values) do
    sum = Enum.reduce(values, Decimal.new(0), &Decimal.add/2)
    Decimal.div(sum, Decimal.new(Enum.count(values)))
  end

  defp calculate_rsi([], [], _avg_gain, _avg_loss, _period, results), do: results

  defp calculate_rsi(
         [gain | rest_gains],
         [loss | rest_losses],
         avg_gain,
         avg_loss,
         period,
         results
       ) do
    # Calculate smoothed averages:
    # avgGain = ((previous avgGain) * (period - 1) + currentGain) / period
    # avgLoss = ((previous avgLoss) * (period - 1) + currentLoss) / period
    new_avg_gain =
      Decimal.div(
        Decimal.add(
          Decimal.mult(avg_gain, Decimal.new(period - 1)),
          gain
        ),
        Decimal.new(period)
      )

    new_avg_loss =
      Decimal.div(
        Decimal.add(
          Decimal.mult(avg_loss, Decimal.new(period - 1)),
          loss
        ),
        Decimal.new(period)
      )

    # Calculate RS = avgGain / avgLoss
    rs =
      if Decimal.compare(new_avg_loss, Decimal.new(0)) == :gt do
        Decimal.div(new_avg_gain, new_avg_loss)
      else
        # If no losses, RS is maximal
        Decimal.new(100)
      end

    # Calculate RSI = 100 - (100 / (1 + RS))
    rsi_value =
      Decimal.sub(
        Decimal.new(100),
        Decimal.div(
          Decimal.new(100),
          Decimal.add(Decimal.new(1), rs)
        )
      )

    calculate_rsi(rest_gains, rest_losses, new_avg_gain, new_avg_loss, period, [
      rsi_value | results
    ])
  end

  @doc """
  Calculates the Moving Average Convergence Divergence (MACD) for a list of candles.

  ## Parameters
    - candles: List of market data candles
    - fast_period: Period for the fast EMA (typically 12)
    - slow_period: Period for the slow EMA (typically 26)
    - signal_period: Period for the signal line EMA (typically 9)
    - price_key: Key to use for price (:close, :open, :high, :low)

  ## Returns
    - List of maps containing MACD values aligned with the input candles:
      %{macd: value, signal: value, histogram: value}
      (first slow_period + signal_period - 2 values are nil)
  """
  def macd(candles, fast_period \\ 12, slow_period \\ 26, signal_period \\ 9, price_key \\ :close) do
    # Calculate fast and slow EMAs
    fast_ema = ema(candles, fast_period, price_key)
    slow_ema = ema(candles, slow_period, price_key)

    # Calculate MACD line: fast_ema - slow_ema
    macd_line =
      Enum.zip(fast_ema, slow_ema)
      |> Enum.map(fn
        {nil, _} -> nil
        {_, nil} -> nil
        {fast, slow} -> Decimal.sub(fast, slow)
      end)

    # Get the valid MACD values (non-nil)
    # Index where MACD values start
    valid_macd_start = slow_period - 1
    valid_macd = Enum.drop(macd_line, valid_macd_start)

    # Calculate signal line: EMA of MACD line
    valid_signal = calculate_ema_from_values(valid_macd, signal_period)

    # Align signal with original MACD by adding nils at beginning
    signal_line = List.duplicate(nil, valid_macd_start + signal_period - 1) ++ valid_signal

    # Calculate histogram: MACD line - signal line
    Enum.zip(macd_line, signal_line)
    |> Enum.map(fn
      {nil, _} ->
        nil

      {_, nil} ->
        nil

      {macd, signal} ->
        histogram = Decimal.sub(macd, signal)
        %{macd: macd, signal: signal, histogram: histogram}
    end)
  end

  defp calculate_ema_from_values(values, period) do
    # Use SMA as first value
    first_sma = Enum.take(values, period) |> average()

    # Calculate multiplier
    multiplier = Decimal.div(Decimal.new(2), Decimal.add(Decimal.new(period), Decimal.new(1)))

    # Calculate EMA
    values
    |> Enum.drop(period)
    |> calculate_ema(multiplier, first_sma, [])
    |> Enum.reverse()
  end

  @doc """
  Calculates Bollinger Bands for a list of candles.

  ## Parameters
    - candles: List of market data candles
    - period: Period for the SMA (typically 20)
    - deviations: Number of standard deviations (typically 2)
    - price_key: Key to use for price (:close, :open, :high, :low)

  ## Returns
    - List of maps containing Bollinger Bands values aligned with the input candles:
      %{middle: value, upper: value, lower: value}
      (first period-1 values are nil)
  """
  def bollinger_bands(candles, period \\ 20, deviations \\ 2, price_key \\ :close) do
    prices = Enum.map(candles, &Map.get(&1, price_key))

    # Middle band is SMA
    sma_values = calculate_sma(prices, period, []) |> Enum.reverse()

    # Calculate standard deviation at each point
    std_devs = calculate_rolling_std_dev(prices, period, sma_values)

    # Calculate upper and lower bands
    Enum.zip([sma_values, std_devs])
    |> Enum.map(fn
      {nil, _} ->
        nil

      {sma, std_dev} ->
        upper = Decimal.add(sma, Decimal.mult(std_dev, Decimal.new(deviations)))
        lower = Decimal.sub(sma, Decimal.mult(std_dev, Decimal.new(deviations)))
        %{middle: sma, upper: upper, lower: lower}
    end)
  end

  defp calculate_rolling_std_dev(prices, period, sma_values) do
    prices
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.zip(sma_values)
    |> Enum.map(fn {window, sma} ->
      if is_nil(sma) do
        nil
      else
        # Calculate variance: sum of squared differences from mean, divided by period
        variance =
          Enum.reduce(window, Decimal.new(0), fn price, acc ->
            diff = Decimal.sub(price, sma)
            squared_diff = Decimal.mult(diff, diff)
            Decimal.add(acc, squared_diff)
          end)
          |> Decimal.div(Decimal.new(period))

        # Standard deviation is square root of variance
        decimal_sqrt(variance)
      end
    end)
    |> then(fn std_devs ->
      # Add nil values at the beginning to align with input
      List.duplicate(nil, period - 1) ++ std_devs
    end)
  end

  # Helper function for square root of Decimal
  defp decimal_sqrt(decimal) do
    # Convert to float for sqrt calculation
    {float, _} = Decimal.to_string(decimal) |> Float.parse()
    sqrt = :math.sqrt(float)
    Decimal.from_float(sqrt)
  end
end
