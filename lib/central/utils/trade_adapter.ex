defmodule Central.Utils.TradeAdapter do
  @moduledoc """
  Utility module for adapting trade records to make them compatible with all systems.
  Specifically, it ensures backward compatibility with code that uses both 'profit_loss' and 'pnl' field names.
  """

  require Logger
  alias Central.Backtest.Services.MarketDataHandler

  @doc """
  Adds backward compatibility to trade records to ensure both field names work.

  ## Parameters
    - trades: A list of trade records or a single trade record

  ## Returns
    - The same trades with field name compatibility added
  """
  def adapt_trades(trades) when is_list(trades) do
    Enum.map(trades, &adapt_fields/1)
  end

  def adapt_trades(trade) do
    adapt_fields(trade)
  end

  # Add missing fields to ensure code can use either pnl or profit_loss
  defp adapt_fields(trade) do
    cond do
      # If it's a struct, use Map.from_struct first to allow adding virtual fields
      is_struct(trade) ->
        trade
        |> Map.from_struct()
        |> add_compatibility_fields()
        |> restore_struct(trade.__struct__)

      # For a regular map, just add the fields
      is_map(trade) ->
        add_compatibility_fields(trade)

      # For anything else, return as is
      true ->
        trade
    end
  end

  # Add missing field(s) based on what's available
  defp add_compatibility_fields(trade_map) do
    pnl_value = get_pnl_value(trade_map)

    # Always normalize the values to ensure consistency
    trade_map
    |> Map.put(:pnl, pnl_value)
    |> Map.put(:profit_loss, pnl_value)
  end

  # Get the PnL value from either field, prioritizing the :pnl field
  defp get_pnl_value(trade_map) do
    cond do
      # If pnl exists, use it (might be Decimal or float)
      Map.has_key?(trade_map, :pnl) ->
        ensure_decimal(trade_map.pnl)

      # If profit_loss exists, use it
      Map.has_key?(trade_map, :profit_loss) ->
        ensure_decimal(trade_map.profit_loss)

      # If neither exists, use 0
      true ->
        Decimal.new(0)
    end
  end

  # Ensure the value is a Decimal type for consistent calculations
  defp ensure_decimal(value) do
    cond do
      is_nil(value) ->
        Decimal.new(0)
      is_struct(value, Decimal) ->
        value
      is_float(value) ->
        # Convert float to Decimal with reasonable precision
        Decimal.from_float(value)
      is_integer(value) ->
        Decimal.new(value)
      is_binary(value) ->
        case Decimal.parse(value) do
          {:ok, decimal} -> decimal
          _ -> Decimal.new(0)
        end
      true ->
        Logger.warn("Unexpected PnL value type: #{inspect(value)}")
        Decimal.new(0)
    end
  end

  # Restore struct if needed
  defp restore_struct(map, struct_type) do
    struct(struct_type, map)
  end
end
