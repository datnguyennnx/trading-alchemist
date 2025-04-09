defmodule Central.Backtest.Schemas.Strategy do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  # Don't use binary_id for foreign keys as User uses default integer IDs
  schema "strategies" do
    field :name, :string
    field :description, :string
    field :config, :map
    field :entry_rules, :map
    field :exit_rules, :map
    field :is_active, :boolean, default: true
    field :is_public, :boolean, default: false

    belongs_to :user, Central.Accounts.User, foreign_key: :user_id, type: :id
    has_many :backtests, Central.Backtest.Schemas.Backtest

    timestamps()
  end

  @doc false
  def changeset(strategy, attrs) do
    strategy
    |> cast(attrs, [
      :name,
      :description,
      :config,
      :entry_rules,
      :exit_rules,
      :is_active,
      :is_public,
      :user_id
    ])
    |> validate_required([:name, :config, :entry_rules, :exit_rules, :user_id])
    |> validate_length(:name, min: 3, max: 100)
    |> validate_config()
    |> validate_rules()
    |> foreign_key_constraint(:user_id)
  end

  defp validate_config(changeset) do
    # Validate config map structure - actual implementation would vary based on your specific needs
    validate_change(changeset, :config, fn :config, config ->
      cond do
        not is_map(config) ->
          [config: "is invalid"]

        # Add more specific validation based on your config structure
        # For example, checking for required keys, value types, etc.

        true ->
          []
      end
    end)
  end

  defp validate_rules(changeset) do
    # Validate entry and exit rules - actual implementation would vary based on your specific needs
    changeset
    |> validate_change(:entry_rules, fn :entry_rules, rules ->
      cond do
        not is_map(rules) ->
          [entry_rules: "is invalid"]

        # Add more specific validation based on your rules structure

        true ->
          []
      end
    end)
    |> validate_change(:exit_rules, fn :exit_rules, rules ->
      cond do
        not is_map(rules) ->
          [exit_rules: "is invalid"]

        # Add more specific validation based on your rules structure

        true ->
          []
      end
    end)
  end
end
