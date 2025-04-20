defmodule CentralWeb.StrategyLive.EditFormLive do
  use CentralWeb, :live_view

  alias Central.Backtest.Contexts.StrategyContext
  alias Central.Backtest.DynamicForm.FormTransformer
  alias Central.Backtest.DynamicForm.FormContext
  alias Central.Backtest.Indicators

  alias CentralWeb.StrategyLive.Components.{
    GeneralForm,
    TradingForm,
    EntryRulesForm,
    ExitRulesForm,
    JsonConfigForm,
    StrategyModeSelector
  }

  import CentralWeb.Components.UI.Button
  import CentralWeb.Components.UI.Card
  import CentralWeb.Components.UI.Tabs

  # Memoize grouped indicators to avoid recalculating on every render
  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Load the strategy
    strategy = StrategyContext.get_strategy!(id)

    # Process strategy data efficiently (do this once in mount)
    {entry_rules, exit_rules, basic_form_data, json_config} = process_strategy_data(strategy)

    # Default to form-based editing
    basic_form_data = Map.put(basic_form_data, "creation_method", "form")

    # Merge all form data
    complete_form_data = Map.merge(
      basic_form_data,
      Map.merge(
        FormTransformer.rules_to_form(entry_rules, "entry"),
        FormTransformer.rules_to_form(exit_rules, "exit")
      )
    )

    # Pre-fetch indicators data once to avoid repeated calls
    grouped_indicators = Indicators.group_indicators_by_type()

    socket =
      socket
      |> assign(:strategy, strategy)
      |> assign(:page_title, "Edit Strategy: #{strategy.name}")
      |> assign(:indicators, Indicators.list_indicators())
      |> assign(:grouped_indicators, grouped_indicators)
      |> assign(:form, to_form(complete_form_data))
      |> assign(:form_data, complete_form_data)
      |> assign(:entry_rules, entry_rules)
      |> assign(:exit_rules, exit_rules)
      |> assign(:json_config_input, json_config)
      |> assign(:json_parse_error, nil)
      |> assign(:creation_method, "form")  # Default creation method

    {:ok, socket}
  end

  # Extract strategy processing logic into a separate function
  defp process_strategy_data(strategy) do
    # Convert database entry_rules and exit_rules to Rule structs
    entry_rules = get_rules_from_strategy(strategy, "entry")
    exit_rules = get_rules_from_strategy(strategy, "exit")

    # Prepare basic form data
    basic_form_data = %{
      "name" => strategy.name,
      "description" => strategy.description,
      "timeframe" => get_in(strategy.config, ["timeframe"]),
      "symbol" => get_in(strategy.config, ["symbol"]),
      "risk_per_trade" => get_in(strategy.config, ["risk_per_trade"]) || "0.02",
      "max_position_size" => get_in(strategy.config, ["max_position_size"]) || "5"
    }

    # Generate JSON representation
    json_config = generate_json_config(strategy)

    {entry_rules, exit_rules, basic_form_data, json_config}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center min-h-screen bg-background">
      <div class="container px-4 py-8">
        <.card class="max-w-2xl mx-auto">
          <.card_header>
            <.card_title>
              Edit Strategy: <%= @strategy.name %>
            </.card_title>
            <.card_description>Update your trading strategy parameters</.card_description>
          </.card_header>

          <.card_content>
            <!-- Mode Selector -->
            <.live_component
              module={StrategyModeSelector}
              id="strategy-mode-selector"
              current_mode={@creation_method}
            />

            <.form :let={_f} for={@form} phx-submit="save" id="strategy-form">
              <%= if @creation_method == "form" do %>
                <!-- Form Mode -->
                <.tabs :let={builder} default="general" id="strategy-tabs" class="w-full">
                  <.tabs_list class="grid w-full grid-cols-4 mb-6">
                    <.tabs_trigger builder={builder} value="general" type="button">
                      General
                    </.tabs_trigger>
                    <.tabs_trigger builder={builder} value="trading" type="button">
                      Trading
                    </.tabs_trigger>
                    <.tabs_trigger builder={builder} value="entry_rules" type="button">
                      Entry Rules
                    </.tabs_trigger>
                    <.tabs_trigger builder={builder} value="exit_rules" type="button">
                      Exit Rules
                    </.tabs_trigger>
                  </.tabs_list>

                  <!-- General Tab -->
                  <.tabs_content value="general" class="space-y-4 mt-6">
                    <.live_component
                      module={GeneralForm}
                      id="general-form"
                      form={@form}
                      parent={self()}
                    />
                  </.tabs_content>

                  <!-- Trading Tab -->
                  <.tabs_content value="trading" class="space-y-4 mt-6">
                    <.live_component
                      module={TradingForm}
                      id="trading-form"
                      form={@form}
                      parent={self()}
                    />
                  </.tabs_content>

                  <!-- Entry Rules Tab -->
                  <.tabs_content value="entry_rules" class="space-y-4 mt-6">
                    <.live_component
                      module={EntryRulesForm}
                      id="entry-rules-form"
                      form={@form}
                      grouped_indicators={@grouped_indicators}
                      entry_rules={@entry_rules}
                      parent={self()}
                    />
                  </.tabs_content>

                  <!-- Exit Rules Tab -->
                  <.tabs_content value="exit_rules" class="space-y-4 mt-6">
                    <.live_component
                      module={ExitRulesForm}
                      id="exit-rules-form"
                      form={@form}
                      grouped_indicators={@grouped_indicators}
                      exit_rules={@exit_rules}
                      parent={self()}
                    />
                  </.tabs_content>
                </.tabs>
              <% else %>
                <!-- JSON Mode -->
                <div class="mt-4">
                  <.live_component
                    module={JsonConfigForm}
                    id="json-config-form"
                    json_config_input={@json_config_input}
                    json_parse_error={@json_parse_error}
                    parent={self()}
                  />
                </div>
              <% end %>

              <!-- Hidden field to track creation method -->
              <input type="hidden" name="creation_method" value={@creation_method} />
            </.form>
          </.card_content>

          <.card_footer class="flex justify-end space-x-4">
            <.button type="button" phx-click="cancel" variant="outline">Cancel</.button>
            <.button
              type="submit"
              form="strategy-form"
              disabled={@creation_method == "json" && @json_parse_error != nil}
            >
              Update Strategy
            </.button>
          </.card_footer>
        </.card>
      </div>
    </div>
    """
  end

  # All handle_event functions grouped together
  @impl true
  def handle_event("save", params, socket) do
    strategy = socket.assigns.strategy

    # Get the user's selected creation method
    creation_method = Map.get(params, "creation_method", socket.assigns.creation_method)

    # Check if name is provided
    name = params["name"]
    if is_nil(name) || String.trim(name) == "" do
      {:noreply,
       socket
       |> put_flash(:error, "Strategy name is required")
       |> assign(:form, to_form(socket.assigns.form_data, errors: [name: {"can't be blank", []}]))}
    else
      # Before proceeding, make sure JSON is synchronized with form if using JSON method
      socket = if creation_method == "json" do
        sync_form_to_json(socket)
      else
        socket
      end

      strategy_params =
        if creation_method == "json" && socket.assigns.json_parse_error == nil do
          # JSON path - use the JSON configuration
          case Jason.decode(socket.assigns.json_config_input) do
            {:ok, json_data} ->
              # Ensure name is set in the JSON if the form has a name
              json_data = ensure_required_fields(json_data, params)

              # Validate the JSON data
              case validate_json_data(json_data) do
                :ok ->
                  # Use JSON data to update strategy
                  %{
                    name: json_data["name"],
                    description: json_data["description"] || "",
                    config: json_data["config"] || %{},
                    entry_rules: json_data["entry_rules"] || %{"conditions" => []},
                    exit_rules: json_data["exit_rules"] || %{"conditions" => []}
                  }

                {:error, message} ->
                  # Show error for invalid JSON structure
                  _socket = socket
                    |> assign(:json_parse_error, message)
                    |> put_flash(:error, "Invalid JSON structure: #{message}")
                  nil
              end

            {:error, error} ->
              # Show error for invalid JSON syntax
              _socket = socket
                |> assign(:json_parse_error, "JSON syntax error: #{inspect(error)}")
                |> put_flash(:error, "Invalid JSON syntax")
              nil
          end
        else
          # Form path - use the form data
          %{
            name: name,
            description: params["description"] || "",
            config: %{
              "timeframe" => params["timeframe"],
              "symbol" => params["symbol"],
              "risk_per_trade" => params["risk_per_trade"] || "0.02",
              "max_position_size" => params["max_position_size"] || "5"
            },
            entry_rules: %{"conditions" => FormTransformer.rules_to_conditions(socket.assigns.entry_rules)},
            exit_rules: %{"conditions" => FormTransformer.rules_to_conditions(socket.assigns.exit_rules)}
          }
        end

      if strategy_params do
        update_strategy(socket, strategy, strategy_params)
      else
        {:noreply, socket}
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
  def handle_event("indicator_changed", params, socket) do
    rule_type = params["rule_type"] || params["phx-value-rule-type"]
    index = extract_index(params)
    indicator_id = extract_indicator_id(params)

    if rule_type && is_integer(index) do
      # Get the list of rules for this type (entry or exit)
      rules_key = String.to_atom("#{rule_type}_rules")
      current_rules = socket.assigns[rules_key]

      # Get the current rule at this index
      current_rule = Enum.at(current_rules, index)

      # Update rule with new indicator and default params
      updated_rule = FormContext.update_rule_indicator(current_rule, indicator_id)

      # Cache frequently calculated values for better performance
      updated_rules = List.replace_at(current_rules, index, updated_rule)
      form_updates = FormTransformer.rule_to_form(updated_rule, rule_type, index)
      updated_form_data = Map.merge(socket.assigns.form_data, form_updates)

      # Update socket
      {:noreply,
       socket
       |> assign(rules_key, updated_rules)
       |> assign(:form_data, updated_form_data)
       |> assign(:form, to_form(updated_form_data))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("condition_changed", params, socket) do
    rule_type = params["rule_type"] || params["phx-value-rule-type"]
    index = extract_index(params)

    # Extract condition value efficiently
    condition = extract_condition_value(params)

    if rule_type && is_integer(index) do
      # Get the list of rules for this type (entry or exit)
      rules_key = String.to_atom("#{rule_type}_rules")
      current_rules = socket.assigns[rules_key]

      # Get the current rule at this index
      current_rule = Enum.at(current_rules, index)

      # Update rule with new condition using FormContext
      updated_rule = FormContext.update_rule_condition(current_rule, condition)

      # Cache calculations for better performance
      updated_rules = List.replace_at(current_rules, index, updated_rule)
      field_key = "#{rule_type}_condition_#{index}"
      updated_form_data = Map.put(socket.assigns.form_data, field_key, condition)

      # Update socket
      {:noreply,
       socket
       |> assign(rules_key, updated_rules)
       |> assign(:form_data, updated_form_data)
       |> assign(:form, to_form(updated_form_data))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_entry_rule", _params, socket) do
    # Use FormContext to add a rule
    {updated_rules, updated_form_data} =
      FormContext.add_rule(socket.assigns.form_data, socket.assigns.entry_rules, "entry")

    # Update socket assigns
    {:noreply,
     socket
     |> assign(:entry_rules, updated_rules)
     |> assign(:form_data, updated_form_data)
     |> assign(:form, to_form(updated_form_data))}
  end

  @impl true
  def handle_event("remove_entry_rule", %{"index" => index_str}, socket) do
    index_to_remove = String.to_integer(index_str)
    current_rules = socket.assigns.entry_rules

    # Prevent removing the last rule
    if length(current_rules) <= 1 do
      {:noreply, put_flash(socket, :error, "Cannot remove the last entry rule.")}
    else
      # Use FormContext to remove a rule
      {updated_rules, updated_form_data} =
        FormContext.remove_rule(socket.assigns.form_data, current_rules, "entry", index_to_remove)

      # Update socket assigns
      {:noreply,
       socket
       |> assign(:entry_rules, updated_rules)
       |> assign(:form_data, updated_form_data)
       |> assign(:form, to_form(updated_form_data))}
    end
  end

  @impl true
  def handle_event("add_exit_rule", _params, socket) do
    # Use FormContext to add a rule
    {updated_rules, updated_form_data} =
      FormContext.add_rule(socket.assigns.form_data, socket.assigns.exit_rules, "exit")

    # Update socket assigns
    {:noreply,
     socket
     |> assign(:exit_rules, updated_rules)
     |> assign(:form_data, updated_form_data)
     |> assign(:form, to_form(updated_form_data))}
  end

  @impl true
  def handle_event("remove_exit_rule", %{"index" => index_str}, socket) do
    index_to_remove = String.to_integer(index_str)
    current_rules = socket.assigns.exit_rules

    # Prevent removing the last rule
    if length(current_rules) <= 1 do
      {:noreply, put_flash(socket, :error, "Cannot remove the last exit rule.")}
    else
      # Use FormContext to remove a rule
      {updated_rules, updated_form_data} =
        FormContext.remove_rule(socket.assigns.form_data, current_rules, "exit", index_to_remove)

      # Update socket assigns
      {:noreply,
       socket
       |> assign(:exit_rules, updated_rules)
       |> assign(:form_data, updated_form_data)
       |> assign(:form, to_form(updated_form_data))}
    end
  end

  @impl true
  def handle_event("update_trading_form", %{"value" => value}, socket) do
    # Update form_data and form assigns
    field_key = case value do
      timeframe when timeframe in ["1m", "5m", "15m", "30m", "1h", "4h", "1d", "1w"] -> "timeframe"
      _ -> "symbol" # Default to symbol or handle other cases
    end

    updated_form_data = Map.put(socket.assigns.form_data, field_key, value)

    {:noreply,
     socket
     |> assign(:form_data, updated_form_data)
     |> assign(:form, to_form(updated_form_data))}
  end

  @impl true
  def handle_event("set_creation_mode", %{"mode" => mode}, socket) when mode in ["form", "json"] do
    socket = case mode do
      "json" ->
        # Generate JSON from current form data before switching to JSON mode
        updated_socket = sync_form_to_json(socket)
        # Also send a notification to the JsonConfigForm component
        send_update(JsonConfigForm, id: "json-config-form", json_config_input: updated_socket.assigns.json_config_input)
        updated_socket

      "form" ->
        # Update form from JSON when switching to form mode
        if socket.assigns.json_parse_error == nil do
          sync_json_to_form(socket)
        else
          # If JSON has errors, keep using current form data
          put_flash(socket, :error, "Cannot switch to form mode: JSON contains errors")
        end
    end

    {:noreply, assign(socket, :creation_method, mode)}
  end

  # Group all handle_info functions together
  @impl true
  def handle_info({:json_config_updated, %{input: json_input, error: json_error}}, socket) do
    {:noreply,
     socket
     |> assign(:json_config_input, json_input)
     |> assign(:json_parse_error, json_error)}
  end

  @impl true
  def handle_info({:set_creation_method, method}, socket) when method in ["form", "json"] do
    socket = if method == "json" do
      # Sync form data to JSON before switching to JSON mode
      sync_form_to_json(socket)
    else
      # When switching to form mode, we'll keep form data as is
      # We could implement JSON-to-form sync here if needed
      socket
    end

    {:noreply, socket |> assign(:creation_method, method)}
  end

  defp get_rules_from_strategy(strategy, rule_type) do
    conditions =
      case rule_type do
        "entry" -> get_in(strategy.entry_rules, ["conditions"]) || []
        "exit" -> get_in(strategy.exit_rules, ["conditions"]) || []
      end

    FormTransformer.conditions_to_rules(conditions, rule_type)
  end

  defp generate_json_config(strategy) do
    data = %{
      name: strategy.name,
      description: strategy.description,
      config: strategy.config,
      entry_rules: strategy.entry_rules,
      exit_rules: strategy.exit_rules
    }

    Jason.encode!(data, pretty: true)
  end

  defp update_strategy(socket, strategy, strategy_params) do
    case StrategyContext.update_strategy(strategy, strategy_params) do
      {:ok, updated_strategy} ->
        {:noreply,
         socket
         |> put_flash(:info, "Strategy updated successfully!")
         |> redirect(to: ~p"/strategies/#{updated_strategy.id}")}

      {:error, changeset} ->
        error_message = format_changeset_errors(changeset)
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update strategy: #{error_message}")
         |> assign(:form, to_form(socket.assigns.form_data, errors: changeset.errors))}
    end
  end

  defp format_changeset_errors(changeset) do
    Enum.map_join(changeset.errors, ", ", fn {field, {msg, _}} -> "#{field} #{msg}" end)
  end

  # Optimized helpers for parameter extraction

  # Extract condition value more efficiently
  defp extract_condition_value(params) do
    case params["value"] do
      nil -> ""
      value when is_map(value) -> Map.get(value, "value", "")
      value when is_binary(value) -> value
      _ -> ""
    end
  end

  defp extract_indicator_id(params) do
    case params["value"] do
      nil -> ""
      value when is_map(value) -> Map.get(value, "value", "")
      value when is_binary(value) -> value
      _ -> ""
    end
  end

  defp extract_index(params) do
    case params["index"] || params["phx-value-index"] do
      idx when is_integer(idx) -> idx
      idx when is_binary(idx) -> String.to_integer(idx)
      _ -> nil
    end
  end

  # Add a function to sync form data to JSON
  defp sync_form_to_json(socket) do
    # Get current form data
    form_data = socket.assigns.form_data
    entry_rules = socket.assigns.entry_rules
    exit_rules = socket.assigns.exit_rules

    # Create JSON structure
    json_data = %{
      "name" => Map.get(form_data, "name", ""),
      "description" => Map.get(form_data, "description", ""),
      "config" => %{
        "timeframe" => Map.get(form_data, "timeframe", "1h"),
        "symbol" => Map.get(form_data, "symbol", "BTCUSDT"),
        "risk_per_trade" => Map.get(form_data, "risk_per_trade", "0.02"),
        "max_position_size" => Map.get(form_data, "max_position_size", "5")
      },
      "entry_rules" => %{
        "conditions" => FormTransformer.rules_to_conditions(entry_rules)
      },
      "exit_rules" => %{
        "conditions" => FormTransformer.rules_to_conditions(exit_rules)
      }
    }

    # Convert to JSON
    json_string = Jason.encode!(json_data, pretty: true)

    # Update socket
    assign(socket, :json_config_input, json_string)
  end

  # Function to convert JSON to form fields
  defp sync_json_to_form(socket) do
    # Parse the JSON data
    case Jason.decode(socket.assigns.json_config_input) do
      {:ok, json_data} ->
        # Extract basic form fields
        basic_form_data = %{
          "name" => json_data["name"] || "",
          "description" => json_data["description"] || "",
          "timeframe" => get_in(json_data, ["config", "timeframe"]) || "1h",
          "symbol" => get_in(json_data, ["config", "symbol"]) || "BTCUSDT",
          "risk_per_trade" => get_in(json_data, ["config", "risk_per_trade"]) || "0.02",
          "max_position_size" => get_in(json_data, ["config", "max_position_size"]) || "5"
        }

        # Extract entry and exit rules
        entry_conditions = get_in(json_data, ["entry_rules", "conditions"]) || []
        exit_conditions = get_in(json_data, ["exit_rules", "conditions"]) || []

        # Convert to Rule structs
        entry_rules = FormTransformer.conditions_to_rules(entry_conditions, "entry")
        exit_rules = FormTransformer.conditions_to_rules(exit_conditions, "exit")

        # Merge all form data
        complete_form_data = Map.merge(
          basic_form_data,
          Map.merge(
            FormTransformer.rules_to_form(entry_rules, "entry"),
            FormTransformer.rules_to_form(exit_rules, "exit")
          )
        )

        # Update socket assigns
        socket
        |> assign(:form_data, complete_form_data)
        |> assign(:form, to_form(complete_form_data))
        |> assign(:entry_rules, entry_rules)
        |> assign(:exit_rules, exit_rules)

      {:error, _error} ->
        # Keep the current form data if JSON parsing fails
        put_flash(socket, :error, "Failed to parse JSON configuration")
    end
  end

  # Ensure required fields are present in JSON data
  defp ensure_required_fields(json_data, params) do
    # Make sure name is present (copy from form if needed)
    json_data = if json_data["name"] == "" && params["name"] && params["name"] != "" do
      Map.put(json_data, "name", params["name"])
    else
      json_data
    end

    # Ensure config section exists
    json_data = if !json_data["config"] do
      Map.put(json_data, "config", %{
        "timeframe" => params["timeframe"] || "1h",
        "symbol" => params["symbol"] || "BTCUSDT",
        "risk_per_trade" => params["risk_per_trade"] || "0.02",
        "max_position_size" => params["max_position_size"] || "5"
      })
    else
      json_data
    end

    # Ensure rules sections exist
    json_data = if !json_data["entry_rules"] do
      Map.put(json_data, "entry_rules", %{"conditions" => []})
    else
      json_data
    end

    json_data = if !json_data["exit_rules"] do
      Map.put(json_data, "exit_rules", %{"conditions" => []})
    else
      json_data
    end

    json_data
  end

  # Validate JSON data structure
  defp validate_json_data(json_data) do
    # Check required top-level keys
    required_keys = ["name", "config"]
    missing_keys = Enum.filter(required_keys, fn key -> not Map.has_key?(json_data, key) end)

    if not Enum.empty?(missing_keys) do
      {:error, "Missing required keys: #{Enum.join(missing_keys, ", ")}"}
    else
      # Check config section
      config = json_data["config"]
      if not is_map(config) do
        {:error, "Config must be an object"}
      else
        config_required = ["timeframe", "symbol"]
        missing_config = Enum.filter(config_required, fn key -> not Map.has_key?(config, key) end)

        if not Enum.empty?(missing_config) do
          {:error, "Missing required config keys: #{Enum.join(missing_config, ", ")}"}
        else
          :ok
        end
      end
    end
  end
end
