defmodule Central.Backtest.Schemas.MarketData do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @foreign_key_type :binary_id
  schema "market_data" do
    field :id, :binary_id, primary_key: true, autogenerate: true
    field :timestamp, :utc_datetime, primary_key: true
    field :symbol, :string
    field :timeframe, :string
    field :open, :decimal
    field :high, :decimal
    field :low, :decimal
    field :close, :decimal
    field :volume, :decimal
    field :source, :string, default: "binance"

    timestamps(updated_at: false)
  end

  @required_fields [:symbol, :timeframe, :timestamp, :open, :high, :low, :close, :volume]
  @optional_fields [:source]

  @doc false
  def changeset(market_data, attrs) do
    market_data
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:open, greater_than_or_equal_to: 0)
    |> validate_number(:high, greater_than_or_equal_to: 0)
    |> validate_number(:low, greater_than_or_equal_to: 0)
    |> validate_number(:close, greater_than_or_equal_to: 0)
    |> validate_number(:volume, greater_than_or_equal_to: 0)
    |> prepare_datetime_fields()
    |> unique_constraint([:symbol, :timeframe, :timestamp, :source])
  end

  # Ensure datetime fields are properly truncated to seconds
  defp prepare_datetime_fields(changeset) do
    case get_change(changeset, :timestamp) do
      nil ->
        changeset

      timestamp when is_struct(timestamp, DateTime) ->
        # Ensure timestamp has no microseconds
        put_change(changeset, :timestamp, DateTime.truncate(timestamp, :second))

      _ ->
        changeset
    end
  end

  # Format a DateTime for display (dd/mm/yyyy HH:MM:SS)
  def format_datetime(nil), do: "N/A"

  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y %H:%M:%S")
  end
end
