defmodule Central.Backtest.Schemas.Backtest do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "backtests" do
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :symbol, :string
    field :timeframe, :string
    field :initial_balance, :decimal
    field :final_balance, :decimal
    field :status, Ecto.Enum, values: [:pending, :fetching_data, :running, :completed, :failed]
    field :metadata, :map, default: %{}
    field :error_message, :string

    belongs_to :strategy, Central.Backtest.Schemas.Strategy
    belongs_to :user, Central.Accounts.User, type: :id
    has_many :trades, Central.Backtest.Schemas.Trade
    has_one :performance_summary, Central.Backtest.Schemas.PerformanceSummary

    timestamps()
  end

  @doc false
  def changeset(backtest, attrs) do
    backtest
    |> cast(attrs, [
      :start_time,
      :end_time,
      :symbol,
      :timeframe,
      :initial_balance,
      :final_balance,
      :status,
      :metadata,
      :strategy_id,
      :user_id,
      :error_message
    ])
    |> validate_required([
      :start_time,
      :end_time,
      :symbol,
      :timeframe,
      :initial_balance,
      :status,
      :strategy_id,
      :user_id
    ])
    |> validate_number(:initial_balance, greater_than: 0)
    |> validate_timeframe()
    |> validate_dates()
    |> foreign_key_constraint(:strategy_id)
    |> foreign_key_constraint(:user_id)
  end

  defp validate_timeframe(changeset) do
    # Validate that timeframe is one of the allowed values
    validate_inclusion(changeset, :timeframe, [
      "1m",
      "5m",
      "15m",
      "30m",
      "1h",
      "2h",
      "4h",
      "12h",
      "1d",
      "3d",
      "1w",
      "1M"
    ])
  end

  defp validate_dates(changeset) do
    changeset
    |> validate_change(:start_time, fn :start_time, start_time ->
      now = DateTime.utc_now()

      if DateTime.compare(start_time, now) == :gt do
        [start_time: "cannot be in the future"]
      else
        []
      end
    end)
    |> validate_change(:end_time, fn :end_time, end_time ->
      case get_field(changeset, :start_time) do
        nil ->
          []

        start_time ->
          if DateTime.compare(end_time, start_time) == :lt do
            [end_time: "must be after start time"]
          else
            []
          end
      end
    end)
  end
end
