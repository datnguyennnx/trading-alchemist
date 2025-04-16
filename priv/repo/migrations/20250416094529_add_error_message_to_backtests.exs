defmodule Central.Repo.Migrations.AddErrorMessageToBacktests do
  use Ecto.Migration

  def change do
    # Add error_message field to store specific error information
    alter table(:backtests) do
      add :error_message, :text
    end

    # First drop the existing constraint if it exists
    execute(
      "ALTER TABLE backtests DROP CONSTRAINT IF EXISTS backtests_status_check",
      "-- Down migration handled in next statement"
    )

    # Then add the new constraint with updated values
    execute(
      "ALTER TABLE backtests ADD CONSTRAINT backtests_status_check CHECK (status::text = ANY (ARRAY['pending'::text, 'fetching_data'::text, 'running'::text, 'completed'::text, 'failed'::text]))",
      "ALTER TABLE backtests ADD CONSTRAINT backtests_status_check CHECK (status::text = ANY (ARRAY['pending'::text, 'running'::text, 'completed'::text, 'failed'::text]))"
    )
  end
end
