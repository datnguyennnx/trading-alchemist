defmodule Central.Repo.Migrations.EnableTimescaledb do
  use Ecto.Migration

  def up do
    # Enable the TimescaleDB extension
    execute "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;"
  end

  def down do
    # Optionally disable the extension if no longer needed
    # Note: This would drop all hypertables, so use with caution
    # execute "DROP EXTENSION IF EXISTS timescaledb CASCADE;"

    # In practice, it's often safer to leave the extension installed
    :ok
  end
end
