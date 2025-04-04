defmodule Central.Repo.Migrations.CreateMarketDataHypertable do
  use Ecto.Migration

  def up do
    create table(:market_data, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()")
      add :symbol, :string, null: false
      add :timeframe, :string, null: false
      add :timestamp, :utc_datetime, null: false
      add :open, :decimal, precision: 18, scale: 8, null: false
      add :high, :decimal, precision: 18, scale: 8, null: false
      add :low, :decimal, precision: 18, scale: 8, null: false
      add :close, :decimal, precision: 18, scale: 8, null: false
      add :volume, :decimal, precision: 24, scale: 8
      add :source, :string, default: "binance"

      timestamps(updated_at: false)
    end

    # Add a primary key that includes the timestamp column
    execute "ALTER TABLE market_data ADD PRIMARY KEY (id, timestamp);"

    # Convert the table to a hypertable, partitioned by the timestamp column
    # Choose an appropriate chunk_time_interval based on expected data volume
    execute "SELECT create_hypertable('market_data', 'timestamp', chunk_time_interval => INTERVAL '1 day');"

    # Create indices AFTER converting to hypertable for better performance
    create index(:market_data, [:symbol, :timeframe, :timestamp])
    create index(:market_data, [:symbol, :timeframe, :source])
    create unique_index(:market_data, [:symbol, :timeframe, :timestamp, :source])
  end

  def down do
    # Drop indices first
    drop_if_exists unique_index(:market_data, [:symbol, :timeframe, :timestamp, :source])
    drop_if_exists index(:market_data, [:symbol, :timeframe, :source])
    drop_if_exists index(:market_data, [:symbol, :timeframe, :timestamp])

    # Drop the table (this automatically handles hypertables)
    drop_if_exists table(:market_data)
  end
end
