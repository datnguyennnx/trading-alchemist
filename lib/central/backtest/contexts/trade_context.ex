defmodule Central.Backtest.Contexts.TradeContext do
  @moduledoc """
  Context module for handling trade operations
  """

  import Ecto.Query
  alias Central.Repo
  alias Central.Backtest.Schemas.Trade

  @doc """
  Lists trades for a specific backtest.
  """
  def list_trades_for_backtest(backtest_id, opts \\ []) do
    limit = Keyword.get(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)

    # Build base query
    query =
      from(t in Trade,
        where: t.backtest_id == ^backtest_id,
        order_by: [desc: t.exit_time]
      )

    # Apply limit if specified, otherwise return all trades
    query = if limit, do: limit(query, ^limit), else: query
    query = if offset > 0, do: offset(query, ^offset), else: query

    # Execute the query and log the result for debugging
    trades = Repo.all(query)

    # Return the trades
    trades
  end

  @doc """
  Lists trades for a backtest with pagination.

  ## Parameters
    - backtest_id: The ID of the backtest
    - page: The page number (starting from 1)
    - page_size: Number of trades per page

  ## Returns
    - A list of trades for the specified page
  """
  def list_trades_for_backtest_paginated(backtest_id, page \\ 1, page_size \\ 50) do
    offset = (page - 1) * page_size

    Trade
    |> where(backtest_id: ^backtest_id)
    |> order_by([t], desc: t.entry_time)
    |> limit(^page_size)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Counts trades for a specific backtest.
  """
  def count_trades_for_backtest(backtest_id) do
    Repo.one(from(t in Trade, where: t.backtest_id == ^backtest_id, select: count(t.id)))
  end

  @doc """
  Gets a trade by ID, raises if not found.
  """
  def get_trade!(id) do
    Repo.get!(Trade, id)
  end

  @doc """
  Gets a trade by ID and ensures it belongs to the specified backtest.
  """
  def get_trade_for_backtest!(id, backtest_id) do
    Repo.one!(
      from(t in Trade,
        where: t.id == ^id and t.backtest_id == ^backtest_id
      )
    )
  end
end
