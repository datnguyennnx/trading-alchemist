defmodule Central.Repo.Migrations.CreateStrategies do
  use Ecto.Migration

  def change do
    create table(:strategies, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :string, null: false
      add :description, :text
      add :config, :map, null: false
      add :entry_rules, :map, null: false
      add :exit_rules, :map, null: false
      add :is_active, :boolean, default: true
      add :is_public, :boolean, default: false

      # Reference users table with the correct ID type (integer)
      add :user_id, references(:users, on_delete: :restrict), null: false

      timestamps()
    end

    create index(:strategies, [:user_id])
    create index(:strategies, [:name])
    create index(:strategies, [:is_public])
  end
end
