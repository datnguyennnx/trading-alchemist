defmodule Central.Repo.Migrations.CreateTrades do
  use Ecto.Migration

  def change do
    create table(:trades, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :entry_time, :utc_datetime, null: false
      add :entry_price, :decimal, precision: 18, scale: 8, null: false
      add :exit_time, :utc_datetime
      add :exit_price, :decimal, precision: 18, scale: 8
      add :quantity, :decimal, precision: 18, scale: 8, null: false
      add :side, :string, null: false
      add :pnl, :decimal, precision: 18, scale: 8
      add :pnl_percentage, :decimal, precision: 10, scale: 4
      add :fees, :decimal, precision: 18, scale: 8
      add :tags, {:array, :string}
      add :entry_reason, :string
      add :exit_reason, :string
      add :metadata, :map

      add :backtest_id, references(:backtests, type: :uuid, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:trades, [:backtest_id])
    create index(:trades, [:entry_time])
    create index(:trades, [:side])
  end
end
