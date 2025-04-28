defmodule CentralWeb.StrategyLive.NewFormLive do
  use CentralWeb, :live_view

  alias Central.Backtest.Contexts.StrategyContext
  alias Central.Backtest.DynamicForm.FormTransformer
  alias Central.Backtest.DynamicForm.FormContext
  alias Central.Backtest.DynamicForm.FormProcessor
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

  @impl true
  def mount(_params, _session, socket) do
    # Initialize default values for new strategy
    basic_form_data = FormContext.init_new_form()

    # Default to form-based creation method
    basic_form_data = Map.put(basic_form_data, "creation_method", "form")

    # Initialize default rules
    entry_rule = FormContext.new_rule("entry", 0)
    exit_rule = FormContext.new_rule("exit", 0)

    # Convert rules to form data
    entry_form_data = FormTransformer.rules_to_form([entry_rule], "entry")
    exit_form_data = FormTransformer.rules_to_form([exit_rule], "exit")

    # Merge all form data
    form_data =
      Map.merge(
        basic_form_data,
        Map.merge(entry_form_data, exit_form_data)
      )

    # Pre-fetch indicators data once to avoid repeated calls
    grouped_indicators = Indicators.group_indicators_by_type()

    # Generate initial JSON config
    initial_json_config =
      Jason.encode!(
        %{
          name: "",
          description: "",
          config: %{
            timeframe: "1h",
            symbol: "BTCUSDT",
            risk_per_trade: "0.02",
            max_position_size: "5"
          },
          entry_rules: %{
            conditions: []
          },
          exit_rules: %{
            conditions: []
          }
        },
        pretty: true
      )

    socket =
      socket
      |> assign(:page_title, "Create New Trading Strategy")
      |> assign(:indicators, Indicators.list_indicators())
      |> assign(:grouped_indicators, grouped_indicators)
      |> assign(:form, to_form(form_data))
      |> assign(:form_data, form_data)
      |> assign(:entry_rules, [entry_rule])
      |> assign(:exit_rules, [exit_rule])
      |> assign(:json_config_input, initial_json_config)
      |> assign(:json_parse_error, nil)
      # Default creation method
      |> assign(:creation_method, "form")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center min-h-screen bg-background">
      <div class="container px-4 py-8">
        <.card class="max-w-2xl mx-auto">
          <.card_header>
            <.card_title>Create New Trading Strategy</.card_title>
            <.card_description>
              Configure your strategy parameters, entry and exit rules
            </.card_description>
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
              Create Strategy
            </.button>
          </.card_footer>
        </.card>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("save", params, socket) do
    # Get the creation method
    creation_method = Map.get(params, "creation_method", "form")

    # Check if name is provided
    name = params["name"]

    if is_nil(name) || String.trim(name) == "" do
      {:noreply,
       socket
       |> put_flash(:error, "Strategy name is required")
       |> assign(:form, to_form(socket.assigns.form_data, errors: [name: {"can't be blank", []}]))}
    else
      if creation_method == "json" do
        # Handle JSON submission
        case Jason.decode(socket.assigns.json_config_input) do
          {:ok, _json_data} ->
            # Process the strategy creation with the JSON string
            json_params = %{
              "creation_method" => "json",
              "json_config" => socket.assigns.json_config_input
            }

            case FormProcessor.process_strategy(json_params, socket.assigns.current_user.id) do
              {:ok, strategy_params} ->
                case StrategyContext.create_strategy(strategy_params) do
                  {:ok, strategy} ->
                    {:noreply,
                     socket
                     |> put_flash(:info, "Strategy created successfully!")
                     |> redirect(to: ~p"/strategies/#{strategy.id}")}

                  {:error, _changeset} ->
                    {:noreply,
                     socket
                     |> put_flash(:error, "Failed to save strategy. Please check your data.")}
                end

              {:error, error_message} ->
                {:noreply,
                 socket
                 |> put_flash(:error, "Invalid strategy data: #{error_message}")}
            end

          {:error, error} ->
            {:noreply,
             socket
             |> put_flash(:error, "Invalid JSON: #{inspect(error)}")
             |> assign(:json_parse_error, "JSON syntax error")}
        end
      else
        # Form-based strategy creation
        case FormProcessor.process_strategy(params, socket.assigns.current_user.id) do
          {:ok, strategy_params} ->
            case StrategyContext.create_strategy(strategy_params) do
              {:ok, strategy} ->
                {:noreply,
                 socket
                 |> put_flash(:info, "Strategy created successfully!")
                 |> redirect(to: ~p"/strategies/#{strategy.id}")}

              {:error, changeset} ->
                error_message =
                  Enum.map_join(changeset.errors, ", ", fn {field, {msg, _}} ->
                    "#{field} #{msg}"
                  end)

                {:noreply,
                 socket
                 |> put_flash(:error, "Failed to save strategy: #{error_message}")
                 |> assign(:form, to_form(socket.assigns.form_data, errors: changeset.errors))}
            end

          {:error, error_message} ->
            {:noreply,
             socket
             |> put_flash(:error, "Invalid strategy data: #{error_message}")}
        end
      end
    end
  end

  @impl true
  def handle_event("cancel", _, socket) do
    {:noreply, redirect(socket, to: ~p"/strategies")}
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

      # Replace the rule in the list
      updated_rules = List.replace_at(current_rules, index, updated_rule)

      # Generate form data for the updated rule
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

    # Extract condition value
    condition =
      case params["value"] do
        nil -> ""
        value when is_map(value) -> Map.get(value, "value", "")
        value when is_binary(value) -> value
        _ -> ""
      end

    if rule_type && is_integer(index) do
      # Get the list of rules for this type (entry or exit)
      rules_key = String.to_atom("#{rule_type}_rules")
      current_rules = socket.assigns[rules_key]

      # Get the current rule at this index
      current_rule = Enum.at(current_rules, index)

      # Update rule with new condition
      updated_rule = %{current_rule | condition: condition}

      # Replace the rule in the list
      updated_rules = List.replace_at(current_rules, index, updated_rule)

      # Update form data condition field
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
    # Get current rules and form data
    current_rules = socket.assigns.entry_rules
    current_form_data = socket.assigns.form_data

    # Generate a new rule index
    new_index = length(current_rules)

    # Create a new rule
    new_rule = FormContext.new_rule("entry", new_index)

    # Add to list
    updated_rules = current_rules ++ [new_rule]

    # Update form data
    form_updates = FormTransformer.rule_to_form(new_rule, "entry", new_index)
    updated_form_data = Map.merge(current_form_data, form_updates)

    # Update socket
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
      # Remove rule
      updated_rules = List.delete_at(current_rules, index_to_remove)

      # Rebuild form data based on updated rules
      # Skip the removed rule and reindex the remaining ones
      form_data_without_rules =
        Enum.filter(socket.assigns.form_data, fn {k, _} ->
          not String.starts_with?(k, "entry_")
        end)
        |> Map.new()

      # Add updated rules
      updated_form_data =
        Map.merge(
          form_data_without_rules,
          FormTransformer.rules_to_form(updated_rules, "entry")
        )

      # Update socket
      {:noreply,
       socket
       |> assign(:entry_rules, updated_rules)
       |> assign(:form_data, updated_form_data)
       |> assign(:form, to_form(updated_form_data))}
    end
  end

  @impl true
  def handle_event("add_exit_rule", _params, socket) do
    # Get current rules and form data
    current_rules = socket.assigns.exit_rules
    current_form_data = socket.assigns.form_data

    # Generate a new rule index
    new_index = length(current_rules)

    # Create a new rule
    new_rule = FormContext.new_rule("exit", new_index)

    # Add to list
    updated_rules = current_rules ++ [new_rule]

    # Update form data
    form_updates = FormTransformer.rule_to_form(new_rule, "exit", new_index)
    updated_form_data = Map.merge(current_form_data, form_updates)

    # Update socket
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
      # Remove rule
      updated_rules = List.delete_at(current_rules, index_to_remove)

      # Rebuild form data based on updated rules
      # Skip the removed rule and reindex the remaining ones
      form_data_without_rules =
        Enum.filter(socket.assigns.form_data, fn {k, _} ->
          not String.starts_with?(k, "exit_")
        end)
        |> Map.new()

      # Add updated rules
      updated_form_data =
        Map.merge(
          form_data_without_rules,
          FormTransformer.rules_to_form(updated_rules, "exit")
        )

      # Update socket
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
    field_key =
      case value do
        timeframe when timeframe in ["1m", "5m", "15m", "30m", "1h", "4h", "1d", "1w"] ->
          "timeframe"

        # Default to symbol or handle other cases
        _ ->
          "symbol"
      end

    updated_form_data = Map.put(socket.assigns.form_data, field_key, value)

    {:noreply,
     socket
     |> assign(:form_data, updated_form_data)
     |> assign(:form, to_form(updated_form_data))}
  end

  @impl true
  def handle_event("set_creation_mode", %{"mode" => mode}, socket)
      when mode in ["form", "json"] do
    socket =
      case mode do
        "json" ->
          # Generate JSON from current form data before switching to JSON mode
          updated_socket = sync_form_to_json(socket)
          # Also send a notification to the JsonConfigForm component
          send_update(JsonConfigForm,
            id: "json-config-form",
            json_config_input: updated_socket.assigns.json_config_input
          )

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
    socket =
      if method == "json" do
        # Sync form data to JSON before switching to JSON mode
        sync_form_to_json(socket)
      else
        # When switching to form mode, we'll keep form data as is
        # We could implement JSON-to-form sync here if needed
        socket
      end

    {:noreply, socket |> assign(:creation_method, method)}
  end

  # Helper functions

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
        complete_form_data =
          Map.merge(
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
end
