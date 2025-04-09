defmodule CentralWeb.StrategyLive.FormLive do
  use CentralWeb, :live_view
  alias Central.Backtest.Contexts.StrategyContext

  import SaladUI.Card
  import SaladUI.Form
  import SaladUI.Input
  import SaladUI.Button
  import SaladUI.Textarea
  import SaladUI.Select

  @impl true
  def mount(params, _session, socket) do
    socket =
      case socket.assigns.live_action do
        :new ->
          socket
          |> assign(:strategy, nil)
          |> assign(:page_title, "Create Strategy")
          |> assign_form(init_new_form())

        :edit ->
          strategy = StrategyContext.get_strategy!(params["id"])

          socket
          |> assign(:strategy, strategy)
          |> assign(:page_title, "Edit Strategy: #{strategy.name}")
          |> assign_form(init_edit_form(strategy))
      end

    {:ok, socket}
  end

  defp init_new_form do
    %{
      "name" => "",
      "description" => "",
      "timeframe" => "",
      "symbol" => "",
      "risk_per_trade" => "0.02",
      "max_position_size" => "5",
      "entry_strategy_0" => "",
      "entry_indicator_0" => "",
      "entry_condition_0" => "",
      "entry_value_0" => "0",
      "exit_strategy_0" => "",
      "exit_indicator_0" => "",
      "exit_condition_0" => "",
      "exit_value_0" => "0",
      "stop_loss_0" => "0.02",
      "take_profit_0" => "0.04"
    }
  end

  defp init_edit_form(strategy) do
    form_data = %{
      "name" => strategy.name,
      "description" => strategy.description,
      "timeframe" => strategy.config["timeframe"],
      "symbol" => strategy.config["symbol"],
      "risk_per_trade" => strategy.config["risk_per_trade"] || "0.02",
      "max_position_size" => strategy.config["max_position_size"] || "5"
    }

    # Add entry rules
    entry_rules = strategy.entry_rules["conditions"] || []

    form_data =
      Enum.with_index(entry_rules)
      |> Enum.reduce(form_data, fn {rule, i}, acc ->
        Map.merge(acc, %{
          "entry_strategy_#{i}" => rule["strategy"] || "",
          "entry_indicator_#{i}" => rule["indicator"] || "",
          "entry_condition_#{i}" => rule["comparison"] || "",
          "entry_value_#{i}" => rule["value"] || "0"
        })
      end)

    # Add exit rules
    exit_rules = strategy.exit_rules["conditions"] || []

    Enum.with_index(exit_rules)
    |> Enum.reduce(form_data, fn {rule, i}, acc ->
      Map.merge(acc, %{
        "exit_strategy_#{i}" => rule["strategy"] || "",
        "exit_indicator_#{i}" => rule["indicator"] || "",
        "exit_condition_#{i}" => rule["comparison"] || "",
        "exit_value_#{i}" => rule["value"] || "0",
        "stop_loss_#{i}" => rule["stop_loss"] || "0.02",
        "take_profit_#{i}" => rule["take_profit"] || "0.04"
      })
    end)
  end

  defp assign_form(socket, form_data) do
    entry_rules_count =
      form_data
      |> Enum.filter(fn {k, _} -> String.starts_with?(k, "entry_strategy_") end)
      |> length()

    exit_rules_count =
      form_data
      |> Enum.filter(fn {k, _} -> String.starts_with?(k, "exit_strategy_") end)
      |> length()

    socket
    |> assign(:form, to_form(form_data))
    |> assign(:entry_rules_count, max(1, entry_rules_count))
    |> assign(:exit_rules_count, max(1, exit_rules_count))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <.card class="max-w-2xl mx-auto">
        <.card_header>
          <.card_title>
            {if @live_action == :new, do: "Create New Strategy", else: "Edit Strategy"}
          </.card_title>
          <.card_description>Define your trading strategy parameters</.card_description>
        </.card_header>

        <.card_content>
          <.form :let={f} for={@form} phx-submit="save" class="space-y-6">
            <div class="space-y-4">
              <.form_item>
                <.form_label>Strategy Name</.form_label>
                <.input field={f[:name]} placeholder="e.g. RSI + SMA Crossover Strategy" required />
                <.form_message field={f[:name]} />
              </.form_item>

              <.form_item>
                <.form_label>Description</.form_label>
                <.textarea
                  id="strategy-description"
                  name={f[:description].name}
                  value={f[:description].value}
                  placeholder="Describe your strategy's logic and conditions. Example: Enter long when RSI is below 30 and price crosses above 20-period SMA. Exit when RSI reaches 70 or price drops below SMA."
                />
                <.form_message field={f[:description]} />
              </.form_item>

              <div class="space-y-4">
                <h3 class="text-lg font-medium">Trading Configuration</h3>

                <div class="grid grid-cols-2 gap-4">
                  <.form_item>
                    <.form_label>Timeframe</.form_label>
                    <.select
                      :let={select}
                      field={f[:timeframe]}
                      id="timeframe-select"
                      placeholder="Select timeframe"
                    >
                      <.select_trigger builder={select} class="w-full" />
                      <.select_content class="w-full" builder={select}>
                        <.select_group>
                          <.select_item builder={select} value="1m">1 Minute</.select_item>
                          <.select_item builder={select} value="5m">5 Minutes</.select_item>
                          <.select_item builder={select} value="15m">15 Minutes</.select_item>
                          <.select_item builder={select} value="1h">1 Hour</.select_item>
                          <.select_item builder={select} value="4h">4 Hours</.select_item>
                          <.select_item builder={select} value="1d">1 Day</.select_item>
                        </.select_group>
                      </.select_content>
                    </.select>
                    <.form_message field={f[:timeframe]} />
                  </.form_item>

                  <.form_item>
                    <.form_label>Symbol</.form_label>
                    <.select
                      :let={select}
                      field={f[:symbol]}
                      id="symbol-select"
                      placeholder="Select trading pair"
                    >
                      <.select_trigger builder={select} class="w-full" />
                      <.select_content class="w-full" builder={select}>
                        <.select_group>
                          <.select_item builder={select} value="BTCUSDT">BTC/USDT</.select_item>
                          <.select_item builder={select} value="ETHUSDT">ETH/USDT</.select_item>
                          <.select_item builder={select} value="BNBUSDT">BNB/USDT</.select_item>
                          <.select_item builder={select} value="SOLUSDT">SOL/USDT</.select_item>
                          <.select_item builder={select} value="XRPUSDT">XRP/USDT</.select_item>
                          <.select_item builder={select} value="ADAUSDT">ADA/USDT</.select_item>
                          <.select_item builder={select} value="DOGEUSDT">DOGE/USDT</.select_item>
                          <.select_item builder={select} value="DOTUSDT">DOT/USDT</.select_item>
                          <.select_item builder={select} value="LINKUSDT">LINK/USDT</.select_item>
                          <.select_item builder={select} value="MATICUSDT">MATIC/USDT</.select_item>
                        </.select_group>
                      </.select_content>
                    </.select>
                    <.form_message field={f[:symbol]} />
                  </.form_item>
                </div>

                <div class="grid grid-cols-2 gap-4">
                  <.form_item>
                    <.form_label>Risk per Trade (%)</.form_label>
                    <.input
                      field={f[:risk_per_trade]}
                      type="number"
                      step="0.01"
                      min="0"
                      max="100"
                      placeholder="e.g. 2.0 (2% of account balance per trade)"
                      required
                    />
                    <.form_message field={f[:risk_per_trade]} />
                  </.form_item>

                  <.form_item>
                    <.form_label>Max Position Size (%)</.form_label>
                    <.input
                      field={f[:max_position_size]}
                      type="number"
                      step="0.01"
                      min="0"
                      max="100"
                      placeholder="e.g. 5.0 (5% max position size)"
                      required
                    />
                    <.form_message field={f[:max_position_size]} />
                  </.form_item>
                </div>
              </div>

              <div class="space-y-4">
                <div class="flex justify-between items-center">
                  <h4 class="text-md font-medium">Entry Rules</h4>
                  <.button type="button" phx-click="add_entry_rule" variant="outline" size="sm">
                    Add Rule
                  </.button>
                </div>

                <%= for i <- 0..(@entry_rules_count - 1) do %>
                  <div class="space-y-4 p-4 border rounded-lg">
                    <.form_item>
                      <.form_label>Indicator</.form_label>
                      <.select
                        :let={select}
                        field={f[:"entry_indicator_#{i}"]}
                        id={"entry-indicator-#{i}"}
                        placeholder="Select indicator"
                      >
                        <.select_trigger builder={select} class="w-full" />
                        <.select_content class="w-full" builder={select}>
                          <.select_group>
                            <.select_item builder={select} value="price">Price</.select_item>
                            <.select_item builder={select} value="sma">SMA</.select_item>
                            <.select_item builder={select} value="ema">EMA</.select_item>
                            <.select_item builder={select} value="rsi">RSI</.select_item>
                            <.select_item builder={select} value="macd">MACD</.select_item>
                          </.select_group>
                        </.select_content>
                      </.select>
                      <.form_message field={f[:"entry_indicator_#{i}"]} />
                    </.form_item>

                    <.form_item>
                      <.form_label>Condition</.form_label>
                      <.select
                        :let={select}
                        field={f[:"entry_condition_#{i}"]}
                        id={"entry-condition-#{i}"}
                        placeholder="Select condition"
                      >
                        <.select_trigger builder={select} class="w-full" />
                        <.select_content class="w-full" builder={select}>
                          <.select_group>
                            <.select_item builder={select} value="above">Above</.select_item>
                            <.select_item builder={select} value="below">Below</.select_item>
                            <.select_item builder={select} value="crosses_above">
                              Crosses Above
                            </.select_item>
                            <.select_item builder={select} value="crosses_below">
                              Crosses Below
                            </.select_item>
                          </.select_group>
                        </.select_content>
                      </.select>
                      <.form_message field={f[:"entry_condition_#{i}"]} />
                    </.form_item>

                    <.form_item>
                      <.form_label>Value</.form_label>
                      <.input
                        field={f[:"entry_value_#{i}"]}
                        type="number"
                        step="0.01"
                        placeholder="e.g. 30 (for RSI oversold) or 200 (for SMA period)"
                        required
                      />
                      <.form_message field={f[:"entry_value_#{i}"]} />
                    </.form_item>
                  </div>
                <% end %>
              </div>

              <div class="space-y-4">
                <div class="flex justify-between items-center">
                  <h4 class="text-md font-medium">Exit Rules</h4>
                  <.button type="button" phx-click="add_exit_rule" variant="outline" size="sm">
                    Add Rule
                  </.button>
                </div>

                <%= for i <- 0..(@exit_rules_count - 1) do %>
                  <div class="space-y-4 p-4 border rounded-lg">
                    <div class="grid grid-cols-2 gap-4">
                      <.form_item>
                        <.form_label>Stop Loss (%)</.form_label>
                        <.input
                          field={f[:"stop_loss_#{i}"]}
                          type="number"
                          step="0.01"
                          min="0"
                          max="100"
                          placeholder="e.g. 2.0 (2% stop loss)"
                          required
                        />
                        <.form_message field={f[:"stop_loss_#{i}"]} />
                      </.form_item>

                      <.form_item>
                        <.form_label>Take Profit (%)</.form_label>
                        <.input
                          field={f[:"take_profit_#{i}"]}
                          type="number"
                          step="0.01"
                          min="0"
                          max="100"
                          placeholder="e.g. 4.0 (4% take profit)"
                          required
                        />
                        <.form_message field={f[:"take_profit_#{i}"]} />
                      </.form_item>
                    </div>

                    <.form_item>
                      <.form_label>Indicator</.form_label>
                      <.select
                        :let={select}
                        field={f[:"exit_indicator_#{i}"]}
                        id={"exit-indicator-#{i}"}
                        placeholder="Select indicator"
                      >
                        <.select_trigger builder={select} class="w-full" />
                        <.select_content class="w-full" builder={select}>
                          <.select_group>
                            <.select_item builder={select} value="price">Price</.select_item>
                            <.select_item builder={select} value="sma">SMA</.select_item>
                            <.select_item builder={select} value="ema">EMA</.select_item>
                            <.select_item builder={select} value="rsi">RSI</.select_item>
                            <.select_item builder={select} value="macd">MACD</.select_item>
                          </.select_group>
                        </.select_content>
                      </.select>
                      <.form_message field={f[:"exit_indicator_#{i}"]} />
                    </.form_item>

                    <.form_item>
                      <.form_label>Condition</.form_label>
                      <.select
                        :let={select}
                        field={f[:"exit_condition_#{i}"]}
                        id={"exit-condition-#{i}"}
                        placeholder="Select condition"
                      >
                        <.select_trigger builder={select} class="w-full" />
                        <.select_content class="w-full" builder={select}>
                          <.select_group>
                            <.select_item builder={select} value="above">Above</.select_item>
                            <.select_item builder={select} value="below">Below</.select_item>
                            <.select_item builder={select} value="crosses_above">
                              Crosses Above
                            </.select_item>
                            <.select_item builder={select} value="crosses_below">
                              Crosses Below
                            </.select_item>
                          </.select_group>
                        </.select_content>
                      </.select>
                      <.form_message field={f[:"exit_condition_#{i}"]} />
                    </.form_item>

                    <.form_item>
                      <.form_label>Value</.form_label>
                      <.input
                        field={f[:"exit_value_#{i}"]}
                        type="number"
                        step="0.01"
                        placeholder="e.g. 70 (for RSI overbought) or 50 (for SMA period)"
                        required
                      />
                      <.form_message field={f[:"exit_value_#{i}"]} />
                    </.form_item>
                  </div>
                <% end %>
              </div>
            </div>

            <.card_footer class="flex justify-end space-x-4">
              <.button type="button" phx-click="cancel" variant="outline">
                Cancel
              </.button>
              <.button type="submit">
                {if @live_action == :new, do: "Create Strategy", else: "Update Strategy"}
              </.button>
            </.card_footer>
          </.form>
        </.card_content>
      </.card>
    </div>
    """
  end

  @impl true
  def handle_event("add_entry_rule", _params, socket) do
    updated_socket = update(socket, :entry_rules_count, &(&1 + 1))
    count = updated_socket.assigns.entry_rules_count - 1

    form_data =
      Map.merge(updated_socket.assigns.form.data, %{
        "entry_indicator_#{count}" => "",
        "entry_condition_#{count}" => "",
        "entry_value_#{count}" => "0"
      })

    {:noreply, assign(updated_socket, :form, to_form(form_data))}
  end

  @impl true
  def handle_event("add_exit_rule", _params, socket) do
    updated_socket = update(socket, :exit_rules_count, &(&1 + 1))
    count = updated_socket.assigns.exit_rules_count - 1

    form_data =
      Map.merge(updated_socket.assigns.form.data, %{
        "exit_indicator_#{count}" => "",
        "exit_condition_#{count}" => "",
        "exit_value_#{count}" => "0",
        "stop_loss_#{count}" => "0.02",
        "take_profit_#{count}" => "0.04"
      })

    {:noreply, assign(updated_socket, :form, to_form(form_data))}
  end

  @impl true
  def handle_event("save", params, socket) do
    current_user_id = socket.assigns.current_user.id

    # Collect entry rules
    entry_conditions =
      Enum.map(0..(socket.assigns.entry_rules_count - 1), fn i ->
        %{
          "indicator" => params["entry_indicator_#{i}"],
          "comparison" => params["entry_condition_#{i}"],
          "value" => params["entry_value_#{i}"]
        }
      end)
      |> Enum.filter(fn rule ->
        rule["indicator"] != "" && rule["comparison"] != "" && rule["value"] != ""
      end)

    # Collect exit rules
    exit_conditions =
      Enum.map(0..(socket.assigns.exit_rules_count - 1), fn i ->
        %{
          "indicator" => params["exit_indicator_#{i}"],
          "comparison" => params["exit_condition_#{i}"],
          "value" => params["exit_value_#{i}"],
          "stop_loss" => params["stop_loss_#{i}"],
          "take_profit" => params["take_profit_#{i}"]
        }
      end)
      |> Enum.filter(fn rule ->
        rule["indicator"] != "" && rule["comparison"] != "" && rule["value"] != ""
      end)

    # Create the config map
    config = %{
      "timeframe" => params["timeframe"],
      "symbol" => params["symbol"],
      "risk_per_trade" => params["risk_per_trade"],
      "max_position_size" => params["max_position_size"]
    }

    # Create entry and exit rules maps
    entry_rules = %{
      "conditions" => entry_conditions
    }

    exit_rules = %{
      "conditions" => exit_conditions
    }

    # Prepare the strategy params
    strategy_params = %{
      name: params["name"],
      description: params["description"],
      config: config,
      entry_rules: entry_rules,
      exit_rules: exit_rules,
      user_id: current_user_id,
      is_active: true,
      is_public: false
    }

    save_strategy(socket, strategy_params)
  end

  @impl true
  def handle_event("cancel", _, socket) do
    destination =
      case socket.assigns do
        %{live_action: :new} -> ~p"/strategies"
        %{live_action: :edit, strategy: strategy} -> ~p"/strategies/#{strategy.id}"
      end

    {:noreply, redirect(socket, to: destination)}
  end

  defp save_strategy(%{assigns: %{live_action: :new}} = socket, strategy_params) do
    case StrategyContext.create_strategy(strategy_params) do
      {:ok, strategy} ->
        {:noreply,
         socket
         |> put_flash(:info, "Strategy created successfully!")
         |> redirect(to: ~p"/strategies/#{strategy.id}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create strategy: #{inspect(changeset.errors)}")
         |> assign(
           :form,
           to_form(Map.merge(socket.assigns.form.data, %{"_errors" => changeset.errors}))
         )}
    end
  end

  defp save_strategy(
         %{assigns: %{live_action: :edit, strategy: strategy}} = socket,
         strategy_params
       ) do
    case StrategyContext.update_strategy(strategy, strategy_params) do
      {:ok, strategy} ->
        {:noreply,
         socket
         |> put_flash(:info, "Strategy updated successfully!")
         |> redirect(to: ~p"/strategies/#{strategy.id}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update strategy: #{inspect(changeset.errors)}")
         |> assign(
           :form,
           to_form(Map.merge(socket.assigns.form.data, %{"_errors" => changeset.errors}))
         )}
    end
  end
end
