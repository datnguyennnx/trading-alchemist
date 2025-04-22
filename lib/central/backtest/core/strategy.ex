defmodule Central.Backtest.Core.Strategy do
  @moduledoc """
  Core module for strategy management in the backtest system.
  Provides the main entry points for working with trading strategies.
  """

  alias Central.Backtest.Contexts.StrategyContext

  @doc """
  Creates a new strategy.

  ## Parameters
    - attrs: Strategy attributes to create

  ## Returns
    - {:ok, strategy} on success
    - {:error, changeset} on validation failure
  """
  def create_strategy(attrs) do
    StrategyContext.create_strategy(attrs)
  end

  @doc """
  Updates an existing strategy.

  ## Parameters
    - strategy: The strategy to update
    - attrs: Attributes to update

  ## Returns
    - {:ok, strategy} on success
    - {:error, changeset} on validation failure
  """
  def update_strategy(strategy, attrs) do
    StrategyContext.update_strategy(strategy, attrs)
  end

  @doc """
  Gets a strategy by ID.

  ## Parameters
    - id: ID of the strategy to get

  ## Returns
    - The strategy if found
    - nil if not found
  """
  def get_strategy(id) do
    StrategyContext.get_strategy!(id)
  end

  @doc """
  Lists all available strategies for a user.

  ## Parameters
    - user_id: ID of the user to list strategies for

  ## Returns
    - List of strategies
  """
  def list_strategies(user_id) do
    StrategyContext.list_strategies(user_id)
  end
end
