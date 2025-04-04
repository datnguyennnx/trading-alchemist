defmodule Central.Repo.Migrations.CreateBacktests do
  use Ecto.Migration

  def change do
    create table(:backtests, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :start_time, :utc_datetime, null: false
      add :end_time, :utc_datetime, null: false
      add :symbol, :string, null: false
      add :timeframe, :string, null: false
      add :initial_balance, :decimal, precision: 18, scale: 8, null: false
      add :final_balance, :decimal, precision: 18, scale: 8
      add :status, :string, null: false, default: "pending"
      add :metadata, :map

      add :strategy_id, references(:strategies, type: :uuid, on_delete: :restrict), null: false
      add :user_id, references(:users, on_delete: :restrict), null: false

      timestamps()
    end

    create index(:backtests, [:strategy_id])
    create index(:backtests, [:user_id])
    create index(:backtests, [:symbol, :timeframe])
    create index(:backtests, [:status])
  end
end
