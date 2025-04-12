defmodule CentralWeb.StrategyLive.EditFormLive do
  use CentralWeb, :live_view
  alias Central.Backtest.Contexts.StrategyContext
  alias Jason # Alias Jason for parsing

  import SaladUI.Card
  import SaladUI.Form
  import SaladUI.Input
  import SaladUI.Button
  import SaladUI.Textarea
  import SaladUI.Select
  import SaladUI.Icon
  import SaladUI.Tabs

  @impl true
  def mount(params, _session, socket) do
    strategy = StrategyContext.get_strategy!(params["id"])

    socket =
      socket
      |> assign(:strategy, strategy)
      |> assign(:page_title, "Edit Strategy: \#{strategy.name}")
      |> assign_form(init_edit_form(strategy))

    # Add state for JSON input
    {:ok,
      socket
      |> assign(json_config_input: default_json_input(socket.assigns.strategy)) # Always pass the strategy
      |> assign(json_parse_error: nil)
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
      |> Enum.filter(fn {k, _} -> String.starts_with?(k, "entry_indicator_") end) # Check for indicator instead of strategy
      |> length()

    exit_rules_count =
      form_data
      |> Enum.filter(fn {k, _} -> String.starts_with?(k, "exit_indicator_") end) # Check for indicator instead of strategy
      |> length()

    socket
    |> assign(:initial_form_data, form_data) # <-- Store the original map
    |> assign(:form, to_form(form_data))
    |> assign(:entry_rules_count, max(1, entry_rules_count))
    |> assign(:exit_rules_count, max(1, exit_rules_count))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center min-h-screen bg-background">
      <div class="container px-4 py-8">
        <.card class="max-w-2xl mx-auto">
          <.card_header>
            <.card_title>
              Edit Strategy
            </.card_title>
            <.card_description>Define your trading strategy parameters</.card_description>
          </.card_header>

          <.card_content>
            <.form :let={f} for={@form} phx-submit="save" id="strategy-form">

              <.tabs default="general" id="strategy-tabs" :let={builder} class="w-full">
                <.tabs_list class="grid w-full grid-cols-5 mb-6">
                  <.tabs_trigger builder={builder} value="general" type="button">General</.tabs_trigger>
                  <.tabs_trigger builder={builder} value="trading" type="button">Trading</.tabs_trigger>
                  <.tabs_trigger builder={builder} value="entry_rules" type="button">Entry Rules</.tabs_trigger>
                  <.tabs_trigger builder={builder} value="exit_rules" type="button">Exit Rules</.tabs_trigger>
                  <.tabs_trigger builder={builder} value="json_config" type="button">JSON Config</.tabs_trigger>
                </.tabs_list>

                <!-- General Tab -->
                <.tabs_content value="general" class="space-y-4 mt-6">
                   <.form_item>
                     <.form_label>Strategy Name</.form_label>
                     <.input field={f[:name]} placeholder="e.g. RSI + SMA Crossover Strategy" />
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
                </.tabs_content>

                <!-- Trading Tab -->
                <.tabs_content value="trading" class="space-y-4 mt-6">
                   <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                     <.form_item>
                       <.form_label>Timeframe</.form_label>
                       <.select :let={select} field={f[:timeframe]} id="timeframe-select" placeholder="Select timeframe" >
                         <.select_trigger builder={select} class="w-full" />
                         <.select_content class="w-full" builder={select}>
                           <.select_group>
                             <.select_item builder={select} value="1m" label="1 Minute"></.select_item>
                             <.select_item builder={select} value="5m" label="5 Minutes"></.select_item>
                             <.select_item builder={select} value="15m" label="15 Minutes"></.select_item>
                             <.select_item builder={select} value="1h" label="1 Hour"></.select_item>
                             <.select_item builder={select} value="4h" label="4 Hours"></.select_item>
                             <.select_item builder={select} value="1d" label="1 Day"></.select_item>
                           </.select_group>
                         </.select_content>
                       </.select>
                       <.form_message field={f[:timeframe]} />
                     </.form_item>

                     <.form_item>
                        <.form_label>Symbol</.form_label>
                        <.select :let={select} field={f[:symbol]} id="symbol-select" placeholder="Select trading pair" >
                           <.select_trigger builder={select} class="w-full" />
                           <.select_content class="w-full" builder={select}>
                             <.select_group>
                               <.select_item builder={select} value="BTCUSDT" label="BTC/USDT"></.select_item>
                             </.select_group>
                           </.select_content>
                         </.select>
                         <.form_message field={f[:symbol]} />
                      </.form_item>
                   </div>
                   <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                     <.form_item>
                        <.form_label>Risk per Trade (%)</.form_label>
                        <.input field={f[:risk_per_trade]} type="number" step="0.01" min="0" max="100" placeholder="e.g. 2.0" />
                        <.form_message field={f[:risk_per_trade]} />
                      </.form_item>
                      <.form_item>
                        <.form_label>Max Position Size (%)</.form_label>
                        <.input field={f[:max_position_size]} type="number" step="0.01" min="0" max="100" placeholder="e.g. 5.0" />
                        <.form_message field={f[:max_position_size]} />
                      </.form_item>
                   </div>
                </.tabs_content>

                <!-- Entry Rules Tab -->
                <.tabs_content value="entry_rules" class="space-y-4 mt-6">
                   <div class="flex justify-end mb-4">
                     <.button type="button" phx-click="add_entry_rule" variant="outline" size="sm"> Add Entry Rule </.button>
                   </div>
                   <%= for i <- 0..(@entry_rules_count - 1) do %>
                     <.card class="p-4 relative space-y-4">
                        <%!-- Add index to phx-value-index for remove button --%>
                       <%= if @entry_rules_count > 1 do %>
                         <.button type="button" phx-click="remove_entry_rule" phx-value-index={i} variant="ghost" size="icon" class="absolute top-2 right-2 text-destructive hover:text-destructive/80">
                           <.icon name="hero-x-mark" class="h-4 w-4" />
                           <span class="sr-only">Remove Rule</span>
                         </.button>
                       <% end %>
                        <.form_item>
                           <.form_label>Indicator</.form_label>
                           <%!-- Manually set name/value/id, remove field --%>
                           <%!-- Access value from @initial_form_data --%>
                           <.select :let={select} name="entry_indicator[]" id={"entry-indicator-#{i}"} value={Map.get(@initial_form_data, "entry_indicator_#{i}")} placeholder="Select indicator">
                             <.select_trigger builder={select} class="w-full" />
                             <.select_content class="w-full" builder={select}>
                               <.select_group>
                                  <.select_item builder={select} value="price" label="Price"></.select_item>
                                  <.select_item builder={select} value="sma" label="SMA"></.select_item>
                                  <.select_item builder={select} value="ema" label="EMA"></.select_item>
                                  <.select_item builder={select} value="rsi" label="RSI"></.select_item>
                                  <.select_item builder={select} value="macd" label="MACD"></.select_item>
                               </.select_group>
                             </.select_content>
                           </.select>
                           <%!-- Re-add form_message, referencing the base field name for potential errors --%>
                           <.form_message field={@form[:entry_indicator]} />
                         </.form_item>
                         <.form_item>
                           <.form_label>Condition</.form_label>
                           <%!-- Manually set name/value/id, remove field --%>
                           <%!-- Access value from @initial_form_data --%>
                           <.select :let={select} name="entry_condition[]" id={"entry-condition-#{i}"} value={Map.get(@initial_form_data, "entry_condition_#{i}")} placeholder="Select condition">
                             <.select_trigger builder={select} class="w-full" />
                             <.select_content class="w-full" builder={select}>
                               <.select_group>
                                  <.select_item builder={select} value="above" label="Above"></.select_item>
                                  <.select_item builder={select} value="below" label="Below"></.select_item>
                                  <.select_item builder={select} value="crosses_above" label="Crosses Above"></.select_item>
                                  <.select_item builder={select} value="crosses_below" label="Crosses Below"></.select_item>
                               </.select_group>
                             </.select_content>
                           </.select>
                           <%!-- Re-add form_message --%>
                           <.form_message field={@form[:entry_condition]} />
                         </.form_item>
                         <.form_item>
                           <.form_label>Value</.form_label>
                           <%!-- Manually set name/value/id, remove field --%>
                           <%!-- Access value from @initial_form_data --%>
                           <.input name="entry_value[]" type="number" step="any" placeholder="e.g. 30 or 200" id={"entry-value-#{i}"} value={Map.get(@initial_form_data, "entry_value_#{i}")}/>
                           <%!-- Re-add form_message --%>
                           <.form_message field={@form[:entry_value]} />
                         </.form_item>
                     </.card>
                   <% end %>
                </.tabs_content>

                <!-- Exit Rules Tab -->
                <.tabs_content value="exit_rules" class="space-y-4 mt-6">
                   <div class="flex justify-end mb-4">
                      <.button type="button" phx-click="add_exit_rule" variant="outline" size="sm"> Add Exit Rule </.button>
                   </div>
                   <%= for i <- 0..(@exit_rules_count - 1) do %>
                     <.card class="p-4 relative space-y-4">
                        <%= if @exit_rules_count > 1 do %>
                           <.button type="button" phx-click="remove_exit_rule" phx-value-index={i} variant="ghost" size="icon" class="absolute top-2 right-2 text-destructive hover:text-destructive/80">
                             <.icon name="hero-x-mark" class="h-4 w-4" />
                             <span class="sr-only">Remove Rule</span>
                           </.button>
                         <% end %>
                        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                          <.form_item>
                            <.form_label>Stop Loss (%)</.form_label>
                            <%!-- Manually set name/value/id, remove field --%>
                            <%!-- Access value from @initial_form_data --%>
                            <.input name="stop_loss[]" type="number" step="0.01" min="0" max="100" placeholder="e.g. 2.0" id={"stop-loss-#{i}"} value={Map.get(@initial_form_data, "stop_loss_#{i}")}/>
                            <%!-- Re-add form_message --%>
                            <.form_message field={@form[:stop_loss]} />
                          </.form_item>
                          <.form_item>
                            <.form_label>Take Profit (%)</.form_label>
                             <%!-- Manually set name/value/id, remove field --%>
                             <%!-- Access value from @initial_form_data --%>
                            <.input name="take_profit[]" type="number" step="0.01" min="0" max="100" placeholder="e.g. 4.0" id={"take-profit-#{i}"} value={Map.get(@initial_form_data, "take_profit_#{i}")}/>
                            <%!-- Re-add form_message --%>
                            <.form_message field={@form[:take_profit]} />
                          </.form_item>
                        </div>
                         <.form_item>
                           <.form_label>Indicator</.form_label>
                           <%!-- Manually set name/value/id, remove field --%>
                           <%!-- Access value from @initial_form_data --%>
                           <.select :let={select} name="exit_indicator[]" id={"exit-indicator-#{i}"} value={Map.get(@initial_form_data, "exit_indicator_#{i}")} placeholder="Select indicator">
                             <.select_trigger builder={select} class="w-full" />
                             <.select_content class="w-full" builder={select}>
                               <.select_group>
                                  <.select_item builder={select} value="price" label="Price"></.select_item>
                                  <.select_item builder={select} value="sma" label="SMA"></.select_item>
                                  <.select_item builder={select} value="ema" label="EMA"></.select_item>
                                  <.select_item builder={select} value="rsi" label="RSI"></.select_item>
                                  <.select_item builder={select} value="macd" label="MACD"></.select_item>
                               </.select_group>
                             </.select_content>
                           </.select>
                            <%!-- Re-add form_message --%>
                           <.form_message field={@form[:exit_indicator]} />
                         </.form_item>
                         <.form_item>
                           <.form_label>Condition</.form_label>
                           <%!-- Manually set name/value/id, remove field --%>
                           <%!-- Access value from @initial_form_data --%>
                           <.select :let={select} name="exit_condition[]" id={"exit-condition-#{i}"} value={Map.get(@initial_form_data, "exit_condition_#{i}")} placeholder="Select condition">
                             <.select_trigger builder={select} class="w-full" />
                             <.select_content class="w-full" builder={select}>
                               <.select_group>
                                  <.select_item builder={select} value="above" label="Above"></.select_item>
                                  <.select_item builder={select} value="below" label="Below"></.select_item>
                                  <.select_item builder={select} value="crosses_above" label="Crosses Above"></.select_item>
                                  <.select_item builder={select} value="crosses_below" label="Crosses Below"></.select_item>
                               </.select_group>
                             </.select_content>
                           </.select>
                           <%!-- Re-add form_message --%>
                           <.form_message field={@form[:exit_condition]} />
                         </.form_item>
                         <.form_item>
                           <.form_label>Value</.form_label>
                            <%!-- Manually set name/value/id, remove field --%>
                            <%!-- Access value from @initial_form_data --%>
                           <.input name="exit_value[]" type="number" step="any" placeholder="e.g. 70 or 50" id={"exit-value-#{i}"} value={Map.get(@initial_form_data, "exit_value_#{i}")}/>
                           <%!-- Re-add form_message --%>
                           <.form_message field={@form[:exit_value]} />
                         </.form_item>
                     </.card>
                   <% end %>
                </.tabs_content>

                <!-- JSON Config Tab -->
                <.tabs_content value="json_config" class="space-y-4 mt-6">
                   <.form_item>
                    <.form_label>Strategy JSON</.form_label>
                     <.textarea
                       id="json-config-input"
                       value={@json_config_input}
                       phx-change="update_json_input"
                       phx-debounce="500"
                       class="h-96 font-mono text-sm"
                     />
                     <.form_message :if={@json_parse_error} class="text-destructive">
                      {@json_parse_error}
                     </.form_message>
                     <.form_description>
                      Define or edit the full strategy configuration using JSON.
                      <span class="font-semibold">Changes here will override other tabs when saving if the JSON is valid.</span>
                     </.form_description>
                   </.form_item>
                </.tabs_content>

              </.tabs>

            </.form> <!-- End of form -->
          </.card_content>

          <.card_footer class="flex justify-end space-x-4">
             <.button type="button" phx-click="cancel" variant="outline"> Cancel </.button>
             <%!-- Use form="strategy-form" to trigger submit from outside the form tag --%>
             <.button type="submit" form="strategy-form">
               Update Strategy
             </.button>
           </.card_footer>

        </.card>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("add_entry_rule", _params, socket) do
    # This needs to add to @initial_form_data as well for consistency
    updated_socket = update(socket, :entry_rules_count, &(&1 + 1))
    count = updated_socket.assigns.entry_rules_count - 1

    new_rule_data = %{"entry_indicator_#{count}" => "", "entry_condition_#{count}" => "", "entry_value_#{count}" => ""}

    updated_initial_data = Map.merge(socket.assigns.initial_form_data, new_rule_data)

    {:noreply,
      updated_socket
      |> assign(:initial_form_data, updated_initial_data)
      |> assign(:form, to_form(updated_initial_data))
    }
  end

  @impl true
  def handle_event("remove_entry_rule", %{"index" => index_str}, socket) do
    index_to_remove = String.to_integer(index_str)
    current_count = socket.assigns.entry_rules_count

    # Prevent removing the last rule
    if current_count <= 1 do
      {:noreply, put_flash(socket, :error, "Cannot remove the last entry rule.")}
    else
      # Need to update @initial_form_data as well
      new_initial_data =
        socket.assigns.initial_form_data
        |> Enum.reduce(%{}, fn {key, value}, acc ->
          case Regex.run(~r/^entry_(indicator|condition|value)_(\\d+)$/, key) do
            [_, _field_type, index_str] ->
              index = String.to_integer(index_str)
              cond do
                index < index_to_remove -> Map.put(acc, key, value)
                index == index_to_remove -> acc
                index > index_to_remove ->
                  new_key = String.replace(key, "_\#{index}", "_\#{index - 1}")
                  Map.put(acc, new_key, value)
                true -> Map.put(acc, key, value)
              end
            _ -> Map.put(acc, key, value)
          end
        end)

      {:noreply,
       socket
       |> assign(:entry_rules_count, current_count - 1)
       |> assign(:initial_form_data, new_initial_data)
       |> assign(:form, to_form(new_initial_data))
      }
    end
  end

  @impl true
  def handle_event("add_exit_rule", _params, socket) do
    # Needs to update @initial_form_data
    updated_socket = update(socket, :exit_rules_count, &(&1 + 1))
    count = updated_socket.assigns.exit_rules_count - 1

    new_rule_data = %{"exit_indicator_#{count}" => "", "exit_condition_#{count}" => "", "exit_value_#{count}" => "", "stop_loss_#{count}" => "0.02", "take_profit_#{count}" => "0.04"}

    updated_initial_data = Map.merge(socket.assigns.initial_form_data, new_rule_data)

    {:noreply,
      updated_socket
      |> assign(:initial_form_data, updated_initial_data)
      |> assign(:form, to_form(updated_initial_data))
    }
  end

  @impl true
  def handle_event("remove_exit_rule", %{"index" => index_str}, socket) do
    index_to_remove = String.to_integer(index_str)
    current_count = socket.assigns.exit_rules_count

     # Prevent removing the last rule
    if current_count <= 1 do
      {:noreply, put_flash(socket, :error, "Cannot remove the last exit rule.")}
    else
      # Need to update @initial_form_data as well
      new_initial_data =
        socket.assigns.initial_form_data
        |> Enum.reduce(%{}, fn {key, value}, acc ->
          case Regex.run(~r/^exit_(indicator|condition|value|stop_loss|take_profit)_(\\d+)$/, key) do
            [_, _field_type, index_str] ->
              index = String.to_integer(index_str)
              cond do
                index < index_to_remove -> Map.put(acc, key, value)
                index == index_to_remove -> acc
                index > index_to_remove ->
                  new_key = String.replace(key, "_\#{index}", "_\#{index - 1}")
                  Map.put(acc, new_key, value)
                 true -> Map.put(acc, key, value)
              end
            _ -> Map.put(acc, key, value)
          end
        end)

      {:noreply,
       socket
       |> assign(:exit_rules_count, current_count - 1)
       |> assign(:initial_form_data, new_initial_data)
       |> assign(:form, to_form(new_initial_data))
      }
    end
  end

  @impl true
  def handle_event("save", params, socket) do
    current_user_id = socket.assigns.current_user.id
    json_string = socket.assigns.json_config_input

    # Attempt to decode and validate JSON first
    case Jason.decode(json_string) do
      {:ok, json_params} ->
        # JSON is valid, check for required keys
        required_keys = ["name", "description", "config", "entry_rules", "exit_rules"]
        missing_keys = Enum.reject(required_keys, &Map.has_key?(json_params, &1))

        if Enum.empty?(missing_keys) do
           # JSON is valid and complete, use it directly
           strategy_params = %{
            name: Map.get(json_params, "name"),
            description: Map.get(json_params, "description"),
            config: Map.get(json_params, "config", %{}),
            entry_rules: Map.get(json_params, "entry_rules", %{"conditions" => []}),
            exit_rules: Map.get(json_params, "exit_rules", %{"conditions" => []}),
            user_id: current_user_id,
            is_active: true,
            is_public: false
          }
          # Clear any previous JSON parse error
          socket = assign(socket, :json_parse_error, nil)
          save_strategy(socket, strategy_params)
        else
          # JSON is valid but incomplete
          error_msg = "JSON is missing required keys: #{Enum.join(missing_keys, ", ")}"
          {:noreply,
            socket
            |> assign(:json_parse_error, error_msg)
            |> put_flash(:error, "Cannot save: #{error_msg}. Please fix the JSON or use the form tabs.")
          }
        end

      {:error, _reason} ->
        # JSON is invalid, proceed with saving from form tabs *unless* user intended to save JSON
        # Check if the JSON input is significantly different from the default (heuristic)
        default_json = default_json_input(socket.assigns.strategy) # Compare against current strategy json
        json_likely_edited = json_string != default_json && json_string != ""

        if json_likely_edited do
           # User likely edited JSON and it's invalid, block save and show error
           error_msg = "JSON is invalid and could not be parsed. Please fix the JSON before saving."
           {:noreply,
             socket
             |> assign(:json_parse_error, error_msg)
             |> put_flash(:error, error_msg)
            }
        else
           # JSON is invalid but likely wasn't edited by user, proceed with form data
           # Clear JSON error just in case
           socket = assign(socket, :json_parse_error, nil)
           # Process form data as before (using params from the form event)
           entry_indicators = Map.get(params, "entry_indicator", [])
           entry_conditions = Map.get(params, "entry_condition", [])
           entry_values = Map.get(params, "entry_value", [])

           exit_indicators = Map.get(params, "exit_indicator", [])
           exit_conditions = Map.get(params, "exit_condition", [])
           exit_values = Map.get(params, "exit_value", [])
           stop_losses = Map.get(params, "stop_loss", [])
           take_profits = Map.get(params, "take_profit", [])

           entry_conditions_list =
             [entry_indicators, entry_conditions, entry_values]
             |> Enum.zip()
             |> Enum.map(fn
                  {nil, _, _} -> nil
                  {_, nil, _} -> nil
                  {_, _, nil} -> nil
                  {indicator, comparison, value} -> %{"indicator" => indicator, "comparison" => comparison, "value" => value}
                end)
             |> Enum.reject(&is_nil/1)
             |> Enum.filter(fn rule -> rule["indicator"] != "" && rule["comparison"] != "" && rule["value"] != "" end)

           exit_conditions_list =
             [exit_indicators, exit_conditions, exit_values, stop_losses, take_profits]
             |> Enum.zip()
             |> Enum.map(fn
                  {nil, _, _, _, _} -> nil
                  {_, nil, _, _, _} -> nil
                  {_, _, nil, _, _} -> nil
                  {_, _, _, nil, _} -> nil
                  {_, _, _, _, nil} -> nil
                  {indicator, comparison, value, stop_loss, take_profit} ->
                     %{"indicator" => indicator, "comparison" => comparison, "value" => value, "stop_loss" => stop_loss, "take_profit" => take_profit}
                  end)
              |> Enum.reject(&is_nil/1)
              |> Enum.filter(fn rule ->
                   rule["indicator"] != "" && rule["comparison"] != "" && rule["value"] != "" &&
                   rule["stop_loss"] != "" && rule["take_profit"] != ""
                 end)

           config = %{
             "timeframe" => Map.get(params, "timeframe"),
             "symbol" => Map.get(params, "symbol"),
             "risk_per_trade" => Map.get(params, "risk_per_trade"),
             "max_position_size" => Map.get(params, "max_position_size")
           }

           entry_rules = %{"conditions" => entry_conditions_list}
           exit_rules = %{"conditions" => exit_conditions_list}

           strategy_params = %{
             name: Map.get(params, "name"),
             description: Map.get(params, "description"),
             config: config,
             entry_rules: entry_rules,
             exit_rules: exit_rules,
             user_id: current_user_id,
             is_active: true,
             is_public: false
           }
           save_strategy(socket, strategy_params)
         end
    end
  end

  @impl true
  def handle_event("cancel", _, socket) do
    # Redirect to show page for edit cancel
    strategy_id = socket.assigns.strategy.id
    {:noreply, redirect(socket, to: ~p"/strategies/#{strategy_id}")}
  end

  @impl true
  def handle_event("update_json_input", %{"value" => json_string}, socket) do
    {:noreply,
      socket
      |> assign(:json_config_input, json_string)
      |> assign(:json_parse_error, nil) # Clear error on input change
    }
  end

  defp save_strategy(%{assigns: %{strategy: strategy}} = socket, strategy_params) do
    case StrategyContext.update_strategy(strategy, strategy_params) do
      {:ok, %{id: strategy_id}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Strategy updated successfully!")
         |> redirect(to: ~p"/strategies/#{strategy_id}")}

      {:error, changeset} ->
         error_message = Enum.map_join(changeset.errors, ", ", fn {field, {msg, _}} -> "#{field} #{msg}" end)
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update strategy: #{error_message}")
         # Need to re-assign initial_form_data here as well on error?
         |> assign(:initial_form_data, changeset.params)
         |> assign(:form, to_form(changeset.params, errors: changeset.errors))
        }
    end
  end

  defp default_json_input(strategy) do
    data = %{
      name: strategy.name,
      description: strategy.description,
      config: strategy.config,
      entry_rules: strategy.entry_rules,
      exit_rules: strategy.exit_rules
    }
    Jason.encode!(data, pretty: true)
  end
end
