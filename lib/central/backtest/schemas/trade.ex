defmodule Central.Backtest.Schemas.Trade do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "trades" do
    field :entry_time, :utc_datetime
    field :entry_price, :decimal
    field :exit_time, :utc_datetime
    field :exit_price, :decimal
    field :quantity, :decimal
    field :side, Ecto.Enum, values: [:long, :short]
    field :pnl, :decimal
    field :pnl_percentage, :decimal
    field :fees, :decimal
    field :tags, {:array, :string}, default: []
    field :entry_reason, :string
    field :exit_reason, :string
    field :metadata, :map, default: %{}

    belongs_to :backtest, Central.Backtest.Schemas.Backtest

    timestamps()
  end

  @doc false
  def changeset(trade, attrs) do
    trade
    |> cast(attrs, [
      :entry_time,
      :entry_price,
      :exit_time,
      :exit_price,
      :quantity,
      :side,
      :pnl,
      :pnl_percentage,
      :fees,
      :tags,
      :entry_reason,
      :exit_reason,
      :metadata,
      :backtest_id
    ])
    |> validate_required([:entry_time, :entry_price, :quantity, :side, :backtest_id])
    |> validate_number(:entry_price, greater_than: 0)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_exit_data()
    |> foreign_key_constraint(:backtest_id)
  end

  defp validate_exit_data(changeset) do
    exit_time = get_field(changeset, :exit_time)
    exit_price = get_field(changeset, :exit_price)

    # If exit_time is present, exit_price must also be present and vice versa
    case {exit_time, exit_price} do
      {nil, nil} ->
        changeset

      {nil, _} ->
        add_error(changeset, :exit_time, "must be provided if exit price is set")

      {_, nil} ->
        add_error(changeset, :exit_price, "must be provided if exit time is set")

      {_exit_time, _exit_price} ->
        entry_time = get_field(changeset, :entry_time)

        changeset
        |> validate_number(:exit_price, greater_than: 0)
        |> validate_change(:exit_time, fn :exit_time, exit_time ->
          if DateTime.compare(exit_time, entry_time) == :lt do
            [exit_time: "must be after entry time"]
          else
            []
          end
        end)
    end
  end

  @doc """
  Creates a new trade changeset for an entry position (without exit details).
  """
  def entry_changeset(trade, attrs) do
    trade
    |> cast(attrs, [
      :entry_time,
      :entry_price,
      :quantity,
      :side,
      :entry_reason,
      :tags,
      :metadata,
      :backtest_id
    ])
    |> validate_required([:entry_time, :entry_price, :quantity, :side, :backtest_id])
    |> validate_number(:entry_price, greater_than: 0)
    |> validate_number(:quantity, greater_than: 0)
    |> foreign_key_constraint(:backtest_id)
  end

  @doc """
  Creates a changeset to update an existing trade with exit details.
  """
  def exit_changeset(trade, attrs) do
    trade
    |> cast(attrs, [:exit_time, :exit_price, :pnl, :pnl_percentage, :fees, :exit_reason])
    |> validate_required([:exit_time, :exit_price])
    |> validate_number(:exit_price, greater_than: 0)
    |> validate_change(:exit_time, fn :exit_time, exit_time ->
      if DateTime.compare(exit_time, trade.entry_time) == :lt do
        [exit_time: "must be after entry time"]
      else
        []
      end
    end)
  end
end
