defmodule CentralWeb.BacktestLive.Components.BacktestConfig do
  use CentralWeb, :live_component
  require Logger
  alias Central.Backtest.Contexts.BacktestContext

  import SaladUI.Card
  import SaladUI.Form
  import SaladUI.Input
  import SaladUI.Button

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.card>
        <.card_header>
          <.card_title>Backtest Configuration</.card_title>
          <.card_description>
            Configure and run your backtest with the strategy parameters
          </.card_description>
        </.card_header>

        <.card_content>
          <.form
            :let={f}
            for={@form}
            phx-submit="start_backtest"
            phx-target={@myself}
            class="space-y-4"
          >
            <div class="grid grid-cols-1 gap-4">
              <.form_item>
                <.form_label>Symbol</.form_label>
                <.input id="backtest-symbol" value={@strategy.config["symbol"]} disabled />
              </.form_item>

              <.form_item>
                <.form_label>Timeframe</.form_label>
                <.input id="backtest-timeframe" value={@strategy.config["timeframe"]} disabled />
              </.form_item>

              <.form_item>
                <.form_label>Start Time</.form_label>
                <.input field={f[:start_time]} name="start_time" type="datetime-local" required />
                <.form_message field={f[:start_time]} />
              </.form_item>

              <.form_item>
                <.form_label>End Time</.form_label>
                <.input field={f[:end_time]} name="end_time" type="datetime-local" required />
                <.form_message field={f[:end_time]} />
              </.form_item>

              <.form_item>
                <.form_label>Initial Balance</.form_label>
                <.input
                  field={f[:initial_balance]}
                  name="initial_balance"
                  type="number"
                  step="0.01"
                  min="0"
                  required
                />
                <.form_message field={f[:initial_balance]} />
              </.form_item>

              <.form_item>
                <.form_label>Position Size (%)</.form_label>
                <.input
                  field={f[:position_size]}
                  name="position_size"
                  type="number"
                  step="0.01"
                  min="0"
                  max="100"
                  required
                />
                <.form_message field={f[:position_size]} />
              </.form_item>
            </div>

            <.card_footer class="flex justify-end p-0">
              <.button type="submit" phx-disable-with="Starting...">
                Start Backtest
              </.button>
            </.card_footer>
          </.form>
        </.card_content>
      </.card>

      <%= if @backtest do %>
        <.card>
          <.card_header>
            <.card_title>Backtest Status</.card_title>
            <.card_description>Current status and results of your backtest</.card_description>
          </.card_header>

          <.card_content>
            <div class="space-y-2">
              <div class="flex justify-between">
                <span class="text-gray-600">Status:</span>
                <span class={status_class(@backtest.status)}>
                  {String.capitalize(to_string(@backtest.status))}
                </span>
              </div>

              <%= if @backtest.status == :completed do %>
                <div class="flex justify-between">
                  <span class="text-gray-600">Total Trades:</span>
                  <span>{length(@backtest.trades)}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-600">Final Balance:</span>
                  <span>{format_balance(@backtest.final_balance)}</span>
                </div>
              <% end %>
            </div>
          </.card_content>
        </.card>
      <% end %>
    </div>
    """
  end

  def update(assigns, socket) do
    # Initialize form with default values
    default_values = %{
      "start_time" => default_start_time(),
      "end_time" => default_end_time(),
      "initial_balance" => "10000.0",
      "position_size" => "2.0"
    }

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(default_values))}
  end

  def handle_event("start_backtest", params, socket) do
    # Extract the correct form values from the params
    start_time = get_form_value(params, "start_time")
    end_time = get_form_value(params, "end_time")
    initial_balance = get_form_value(params, "initial_balance")
    position_size = get_form_value(params, "position_size")

    # Debug info to verify what values we're receiving
    Logger.debug(
      "Form values received - start_time: #{start_time}, end_time: #{end_time}, initial_balance: #{initial_balance}, position_size: #{position_size}"
    )

    # Use the strategy's values for symbol and timeframe
    symbol = socket.assigns.strategy.config["symbol"]
    timeframe = socket.assigns.strategy.config["timeframe"]

    # Ensure initial_balance is a valid decimal
    parsed_initial_balance =
      case initial_balance do
        # Default if missing
        nil ->
          Decimal.new("10000.0")

        # Default if empty string
        "" ->
          Decimal.new("10000.0")

        val when is_binary(val) ->
          case Decimal.parse(val) do
            # Successfully parsed with no remainder
            {decimal, ""} -> decimal
            # Default on parse error
            _ -> Decimal.new("10000.0")
          end

        val when is_number(val) ->
          Decimal.new(val)

        # Default for other cases
        _ ->
          Decimal.new("10000.0")
      end

    # Ensure position_size is a valid decimal
    parsed_position_size =
      case position_size do
        # Default if missing
        nil ->
          Decimal.new("2.0")

        # Default if empty string
        "" ->
          Decimal.new("2.0")

        val when is_binary(val) ->
          case Decimal.parse(val) do
            # Successfully parsed with no remainder
            {decimal, ""} -> decimal
            # Default on parse error
            _ -> Decimal.new("2.0")
          end

        val when is_number(val) ->
          Decimal.new(val)

        # Default for other cases
        _ ->
          Decimal.new("2.0")
      end

    # Create the backtest params
    backtest_params = %{
      strategy_id: socket.assigns.strategy.id,
      symbol: symbol,
      timeframe: timeframe,
      start_time: parse_datetime(start_time),
      end_time: parse_datetime(end_time),
      initial_balance: parsed_initial_balance,
      position_size: parsed_position_size,
      status: :pending,
      user_id: socket.assigns.strategy.user_id,
      metadata: %{
        "position_size" => Decimal.to_string(parsed_position_size),
        "progress" => 0
      }
    }

    Logger.debug("Backtest params: #{inspect(backtest_params)}")

    case BacktestContext.create_backtest(backtest_params) do
      {:ok, backtest} ->
        # Start backtest in background worker
        Central.Backtest.Workers.BacktestRunner.perform_async(%{
          "backtest_id" => backtest.id
        })

        # Subscribe to backtest updates
        Phoenix.PubSub.subscribe(Central.PubSub, "backtest:#{backtest.id}")

        {:noreply,
         socket
         |> assign(:backtest, backtest)
         |> put_flash(:info, "Backtest started successfully!")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to start backtest: #{error_messages(changeset)}")
         |> assign(:form, to_form(changeset))}
    end
  end

  # Helper to extract form values from different form structures
  defp get_form_value(params, field) do
    cond do
      # Direct field access
      Map.has_key?(params, field) ->
        Map.get(params, field)

      # Nested under "backtest" key (common LiveView form structure)
      Map.has_key?(params, "backtest") && is_map(params["backtest"]) ->
        Map.get(params["backtest"], field)

      # Other form structures
      true ->
        nil
    end
  end

  # Format changeset errors for display
  defp error_messages(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
    |> Enum.join("; ")
  end

  def handle_info({:backtest_update, backtest}, socket) do
    {:noreply, assign(socket, :backtest, backtest)}
  end

  defp status_class(:pending), do: "text-yellow-600"
  defp status_class(:running), do: "text-blue-600"
  defp status_class(:completed), do: "text-green-600"
  defp status_class(:failed), do: "text-red-600"
  defp status_class(_), do: "text-gray-600"

  defp format_balance(balance) when is_number(balance) do
    :erlang.float_to_binary(balance, decimals: 2)
  end

  defp format_balance(balance), do: balance

  defp parse_datetime(nil), do: nil
  defp parse_datetime(""), do: nil

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    # First try parsing as ISO 8601
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} ->
        datetime

      _ ->
        # Then try parsing as datetime-local format
        try do
          [date_str, time_str] = String.split(datetime_string, "T")
          [year, month, day] = String.split(date_str, "-") |> Enum.map(&String.to_integer/1)
          [hour, minute] = String.split(time_str, ":") |> Enum.map(&String.to_integer/1)

          {:ok, datetime} = NaiveDateTime.new(year, month, day, hour, minute, 0)
          DateTime.from_naive!(datetime, "Etc/UTC")
        rescue
          _ -> nil
        end
    end
  end

  defp parse_datetime(_), do: nil

  # Helper functions to set reasonable default times
  defp default_start_time do
    # Default to 30 days ago
    DateTime.utc_now()
    |> DateTime.add(-30, :day)
    |> DateTime.to_iso8601()
    |> String.replace("Z", "")
  end

  defp default_end_time do
    # Default to now
    DateTime.utc_now()
    |> DateTime.to_iso8601()
    |> String.replace("Z", "")
  end
end
