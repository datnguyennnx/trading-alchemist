defmodule Central.Backtest.Contexts.StrategyContext do
  import Ecto.Query
  alias Central.Backtest.Schemas.Strategy
  alias Central.Repo

  def create_strategy(attrs) do
    %Strategy{}
    |> Strategy.changeset(attrs)
    |> Repo.insert()
  end

  def get_strategy!(id), do: Repo.get!(Strategy, id) |> Repo.preload(:backtests)

  def update_strategy(%Strategy{} = strategy, attrs) do
    strategy
    |> Strategy.changeset(attrs)
    |> Repo.update()
  end

  def delete_strategy(%Strategy{} = strategy) do
    Repo.delete(strategy)
  end

  def list_strategies(opts \\ []) do
    user_id = Keyword.get(opts, :user_id)

    query = from(s in Strategy,
      order_by: [desc: s.inserted_at],
      preload: [:backtests])

    query = if user_id, do: where(query, [s], s.user_id == ^user_id), else: query

    Repo.all(query)
  end

  def list_active_strategies(opts \\ []) do
    from(s in Strategy,
      where: s.is_active == true,
      order_by: [desc: s.inserted_at],
      preload: [:backtests]
    )
    |> maybe_filter_by_user(opts)
    |> Repo.all()
  end

  def list_public_strategies do
    from(s in Strategy,
      where: s.is_public == true and s.is_active == true,
      order_by: [desc: s.inserted_at],
      preload: [:backtests]
    )
    |> Repo.all()
  end

  defp maybe_filter_by_user(query, opts) do
    case Keyword.get(opts, :user_id) do
      nil -> query
      user_id -> where(query, [s], s.user_id == ^user_id)
    end
  end
end
