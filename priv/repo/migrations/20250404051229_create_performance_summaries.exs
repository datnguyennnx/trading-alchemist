defmodule Central.Repo.Migrations.CreatePerformanceSummaries do
  use Ecto.Migration

  def change do
    create table(:performance_summaries, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :total_trades, :integer
      add :winning_trades, :integer
      add :losing_trades, :integer
      add :win_rate, :decimal, precision: 10, scale: 4
      add :profit_factor, :decimal, precision: 10, scale: 4
      add :max_drawdown, :decimal, precision: 18, scale: 8
      add :max_drawdown_percentage, :decimal, precision: 10, scale: 4
      add :sharpe_ratio, :decimal, precision: 10, scale: 4
      add :sortino_ratio, :decimal, precision: 10, scale: 4
      add :total_pnl, :decimal, precision: 18, scale: 8
      add :total_pnl_percentage, :decimal, precision: 10, scale: 4
      add :average_win, :decimal, precision: 18, scale: 8
      add :average_loss, :decimal, precision: 18, scale: 8
      add :largest_win, :decimal, precision: 18, scale: 8
      add :largest_loss, :decimal, precision: 18, scale: 8
      add :metrics, :map

      add :backtest_id, references(:backtests, type: :uuid, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:performance_summaries, [:backtest_id])
  end
end
