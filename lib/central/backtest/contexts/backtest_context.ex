defmodule Central.Backtest.Contexts.BacktestContext do
  @moduledoc """
  Context module for handling backtesting operations
  """

  import Ecto.Query
  alias Central.Repo
  alias Central.Backtest.Schemas.Backtest

  @doc """
  Creates a new backtest with the given attributes.
  """
  def create_backtest(attrs) do
    %Backtest{}
    |> Backtest.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a backtest by ID, raises if not found.
  """
  def get_backtest!(id) do
    Repo.get!(Backtest, id) |> Repo.preload(:strategy)
  end

  @doc """
  Updates a backtest with the given attributes.
  """
  def update_backtest(backtest, attrs) do
    backtest
    |> Backtest.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Lists recent backtests with their associated strategies.
  """
  def list_recent_backtests(limit \\ 5) do
    from(b in Backtest,
      order_by: [desc: b.inserted_at],
      limit: ^limit,
      preload: [:strategy, :trades]
    )
    |> Repo.all()
  end

  @doc """
  Lists all backtests for a specific strategy, supporting pagination.
  Options:
    * :limit - The maximum number of backtests to return.
    * :offset - The number of backtests to skip.
  """
  def list_backtests_for_strategy(strategy_id, opts \\ []) do
    limit = Keyword.get(opts, :limit)
    offset = Keyword.get(opts, :offset)

    query =
      from(b in Backtest,
        where: b.strategy_id == ^strategy_id,
        order_by: [desc: b.inserted_at],
        preload: [:strategy]
      )

    query =
      if limit, do: from(q in query, limit: ^limit), else: query

    query =
      if offset, do: from(q in query, offset: ^offset), else: query

    Repo.all(query)
    # Note: Sorting in Elixir after Repo.all is inefficient for pagination.
    # The order_by in the query should handle the sorting correctly.
    # If specific complex sorting is needed that can't be done in SQL,
    # consider if pagination is still the right approach or if the calculation
    # needs pre-computation.
    # |> Enum.sort_by(...)
  end

  @doc """
  Counts the total number of backtests for a specific strategy.
  """
  def count_backtests_for_strategy(strategy_id) do
    from(b in Backtest, where: b.strategy_id == ^strategy_id, select: count(b.id))
    |> Repo.one()
  end

  @doc """
  Gets the most recent completed backtest for a strategy.
  """
  def get_most_recent_completed_backtest(strategy_id) do
    from(b in Backtest,
      where: b.strategy_id == ^strategy_id and b.status == :completed,
      order_by: [desc: b.inserted_at],
      limit: 1,
      preload: [:strategy]
    )
    |> Repo.one()
  end
end
