defmodule Central.Backtest.Utils.BacktestUtils do
  @moduledoc """
  Main utility module for the backtest system.
  Provides a convenient entry point for accessing all backtest utility functions.

  Usage:
  ```
  alias Central.Backtest.Utils.BacktestUtils, as: Utils

  # Use datetime utilities
  start_time = Utils.DateTime.utc_now()

  # Use decimal utilities
  formatted_profit = Utils.Decimal.format_percent(0.1543)
  ```
  """

  defmodule DateTime do
    @moduledoc """
    Convenience module for accessing datetime utility functions.
    All functions are delegated to Central.Backtest.Utils.DatetimeUtils.
    """

    alias Central.Backtest.Utils.DatetimeUtils

    defdelegate to_utc(value), to: DatetimeUtils
    defdelegate utc_now(), to: DatetimeUtils
    defdelegate naive_utc_now(), to: DatetimeUtils
    defdelegate to_unix(datetime), to: DatetimeUtils
    defdelegate to_unix_ms(datetime), to: DatetimeUtils
    defdelegate from_unix(timestamp, unit \\ :second), to: DatetimeUtils
    defdelegate format(datetime, format \\ "%Y-%m-%d %H:%M:%S"), to: DatetimeUtils
    defdelegate parse_iso(string), to: DatetimeUtils
    defdelegate diff(datetime1, datetime2 \\ nil, unit \\ :second), to: DatetimeUtils
    defdelegate add(datetime, value, unit \\ :second), to: DatetimeUtils
    defdelegate normalize_datetime(datetime), to: DatetimeUtils
    defdelegate truncate(datetime, precision \\ :second), to: DatetimeUtils
  end

  defmodule Decimal do
    @moduledoc """
    Convenience module for accessing decimal utility functions.
    All functions are delegated to Central.Backtest.Utils.DecimalUtils.
    """

    alias Central.Backtest.Utils.DecimalUtils

    defdelegate parse(value), to: DecimalUtils
    defdelegate to_float(value), to: DecimalUtils
    defdelegate compare(a, b), to: DecimalUtils
    defdelegate positive?(value), to: DecimalUtils
    defdelegate negative?(value), to: DecimalUtils
    defdelegate zero?(value), to: DecimalUtils
    defdelegate format(value, precision \\ 2), to: DecimalUtils
    defdelegate format_percent(value, precision \\ 2), to: DecimalUtils
  end

  @doc """
  Generate a unique identifier for backtest-related entities.
  Uses UUID v4 format.

  ## Returns
    - A string containing a unique identifier
  """
  def generate_id do
    Ecto.UUID.generate()
  end

  @doc """
  Get the current environment name (:dev, :test, :prod).

  ## Returns
    - Atom representing the current environment
  """
  def environment do
    Application.get_env(:central, :environment, :dev)
  end

  @doc """
  Check if the current environment is development.

  ## Returns
    - true if in development environment, false otherwise
  """
  def dev_env? do
    environment() == :dev
  end

  @doc """
  Check if the current environment is test.

  ## Returns
    - true if in test environment, false otherwise
  """
  def test_env? do
    environment() == :test
  end

  @doc """
  Check if the current environment is production.

  ## Returns
    - true if in production environment, false otherwise
  """
  def prod_env? do
    environment() == :prod
  end
end
