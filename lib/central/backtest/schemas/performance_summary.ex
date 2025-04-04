defmodule Central.Backtest.Schemas.PerformanceSummary do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "performance_summaries" do
    field :total_trades, :integer
    field :winning_trades, :integer
    field :losing_trades, :integer
    field :win_rate, :decimal
    field :profit_factor, :decimal
    field :max_drawdown, :decimal
    field :max_drawdown_percentage, :decimal
    field :sharpe_ratio, :decimal
    field :sortino_ratio, :decimal
    field :total_pnl, :decimal
    field :total_pnl_percentage, :decimal
    field :average_win, :decimal
    field :average_loss, :decimal
    field :largest_win, :decimal
    field :largest_loss, :decimal
    field :metrics, :map, default: %{}

    belongs_to :backtest, Central.Backtest.Schemas.Backtest

    timestamps()
  end

  @doc false
  def changeset(performance_summary, attrs) do
    performance_summary
    |> cast(attrs, [:total_trades, :winning_trades, :losing_trades, :win_rate, :profit_factor,
                    :max_drawdown, :max_drawdown_percentage, :sharpe_ratio, :sortino_ratio,
                    :total_pnl, :total_pnl_percentage, :average_win, :average_loss,
                    :largest_win, :largest_loss, :metrics, :backtest_id])
    |> validate_required([:total_trades, :winning_trades, :losing_trades, :backtest_id])
    |> validate_number(:total_trades, greater_than_or_equal_to: 0)
    |> validate_number(:winning_trades, greater_than_or_equal_to: 0)
    |> validate_number(:losing_trades, greater_than_or_equal_to: 0)
    |> validate_consistency()
    |> foreign_key_constraint(:backtest_id)
    |> unique_constraint(:backtest_id)
  end

  defp validate_consistency(changeset) do
    total = get_field(changeset, :total_trades) || 0
    winning = get_field(changeset, :winning_trades) || 0
    losing = get_field(changeset, :losing_trades) || 0

    if total != winning + losing && total > 0 do
      add_error(changeset, :total_trades, "must equal the sum of winning and losing trades")
    else
      changeset
    end
  end
end
