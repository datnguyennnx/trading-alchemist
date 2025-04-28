defmodule Central.Backtest.Contexts.BacktestContext do
  @moduledoc """
  Context module for handling backtesting operations
  """

  import Ecto.Query
  alias Central.Repo
  alias Central.Backtest.Schemas.Backtest
  alias Central.Backtest.Utils.BacktestUtils, as: Utils

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
  Lists all backtests for a specific strategy.
  """
  def list_backtests_for_strategy(strategy_id) do
    from(b in Backtest,
      where: b.strategy_id == ^strategy_id,
      order_by: [desc: b.inserted_at],
      preload: [:strategy]
    )
    |> Repo.all()
    |> Enum.sort_by(
      fn backtest ->
        case backtest.inserted_at do
          %DateTime{} = dt ->
            Utils.DateTime.to_unix(dt)

          %NaiveDateTime{} = ndt ->
            Utils.DateTime.to_unix(ndt)

          _ ->
            0
        end
      end,
      :desc
    )
  end
end
