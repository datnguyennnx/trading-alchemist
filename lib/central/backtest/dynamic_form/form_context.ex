defmodule Central.Backtest.DynamicForm.FormContext do
  @moduledoc """
  Centralizes form operations for strategy configuration.

  This module coordinates between UI components and the domain model,
  providing consistent handling of indicator parameters, rule manipulation,
  and form data processing.
  """

  alias Central.Backtest.DynamicForm.Rule
  alias Central.Backtest.DynamicForm.FormTransformer
  alias Central.Backtest.DynamicForm.FormGenerator
  alias Central.Backtest.Indicators.ListIndicator
  alias Central.Backtest.Indicators

  @doc """
  Gets default parameters for an indicator
  """
  def get_indicator_params(indicator_id) when is_binary(indicator_id) do
    ListIndicator.get_params(indicator_id)
    |> generate_default_params_map()
  end

  def get_indicator_params(_), do: %{}

  @doc """
  Generate a map of default values from a list of parameters.

  This function takes a list of parameter maps and extracts their default values
  into a map where keys are parameter names.

  ## Example

      iex> params = [%{name: :period, default: 14}, %{name: :source, default: "close"}]
      iex> FormContext.generate_default_params_map(params)
      %{period: 14, source: "close"}
  """
  def generate_default_params_map(params_list) when is_list(params_list) do
    Enum.reduce(params_list, %{}, fn param, acc ->
      Map.put(acc, param.name, param.default)
    end)
  end

  def generate_default_params_map(_), do: %{}

  @doc """
  Initialize a new rule with defaults
  """
  def new_rule(type, index) do
    id = "#{type}_#{index}"

    base_attrs = %{id: id}

    # Add stop_loss and take_profit for exit rules
    attrs = if type == "exit" do
      Map.merge(base_attrs, %{stop_loss: "0.02", take_profit: "0.04"})
    else
      base_attrs
    end

    Rule.new(attrs)
  end

  @doc """
  Updates a rule with new indicator values and fetches default params
  """
  def update_rule_indicator(rule, indicator_id) do
    # Get default params for the indicator
    default_params = get_indicator_params(indicator_id)

    # Update the rule with new indicator and params
    # Ensure rule is a valid struct before updating
    if is_nil(rule) do
      new_rule("entry", 0) |> Map.put(:indicator_id, indicator_id) |> Map.put(:params, default_params)
    else
      %{rule | indicator_id: indicator_id, params: default_params}
    end
  end

  @doc """
  Updates a rule with a new condition
  """
  def update_rule_condition(rule, condition) do
    %{rule | condition: condition}
  end

  @doc """
  Adds a new rule to an existing list and returns updated form data
  """
  def add_rule(form_data, nil, rule_type), do: add_rule(form_data, [], rule_type)
  def add_rule(form_data, current_rules, rule_type) do
    # Create new rule
    index = length(current_rules)
    new_rule = new_rule(rule_type, index)

    # Add to list
    updated_rules = current_rules ++ [new_rule]

    # Update form data
    form_data_updates = FormTransformer.rules_to_form([new_rule], rule_type)
    updated_form_data = Map.merge(form_data, form_data_updates)

    {updated_rules, updated_form_data}
  end

  @doc """
  Removes a rule from a list and returns updated form data
  """
  def remove_rule(form_data, current_rules, rule_type, index) do
    # Remove rule
    updated_rules = List.delete_at(current_rules, index)

    # Build new form data
    # First, filter out fields related to this rule type
    base_form_data = form_data
                    |> Enum.filter(fn {k, _} ->
                      not String.starts_with?(k, "#{rule_type}_")
                    end)
                    |> Map.new()

    # Then add back all rules
    form_data_updates = FormTransformer.rules_to_form(updated_rules, rule_type)
    updated_form_data = Map.merge(base_form_data, form_data_updates)

    {updated_rules, updated_form_data}
  end

  @doc """
  Prepares strategy parameters from form data and parsed rule structs.
  """
  def prepare_strategy_params(params, entry_rules, exit_rules, user_id) do
    # Extract basic fields
    name = Map.get(params, "name")
    description = Map.get(params, "description", "")

    # Prepare strategy params structure
    %{
      name: name,
      description: description,
      config: %{
        "timeframe" => Map.get(params, "timeframe"),
        "symbol" => Map.get(params, "symbol"),
        "risk_per_trade" => Map.get(params, "risk_per_trade", "0.02"),
        "max_position_size" => Map.get(params, "max_position_size", "5")
      },
      entry_rules: %{
        "conditions" => FormTransformer.rules_to_conditions(entry_rules)
      },
      exit_rules: %{
        "conditions" => FormTransformer.rules_to_conditions(exit_rules)
      },
      user_id: user_id,
      is_active: true,
      is_public: false
    }
  end

  @doc """
  Prepares a strategy from JSON configuration.
  """
  def prepare_strategy_from_json(json_string, user_id) do
    # Parse the JSON
    case Jason.decode(json_string) do
      {:ok, json_data} ->
        # Validate the JSON structure
        case validate_strategy_json(json_data) do
          :ok ->
            # Create strategy params from JSON
            strategy_params = %{
              name: json_data["name"],
              description: json_data["description"] || "",
              config: json_data["config"] || %{},
              entry_rules: json_data["entry_rules"] || %{"conditions" => []},
              exit_rules: json_data["exit_rules"] || %{"conditions" => []},
              user_id: user_id,
              is_active: true,
              is_public: false
            }

            {:ok, strategy_params}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, error} ->
        {:error, "JSON parse error: #{inspect(error)}"}
    end
  end

  @doc """
  Validates a JSON strategy definition.
  """
  def validate_strategy_json(json_data) do
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
          # Check entry_rules
          entry_rules = json_data["entry_rules"]
          unless is_map(entry_rules) do
            {:error, "entry_rules must be an object"}
          else
            # Check exit_rules
            exit_rules = json_data["exit_rules"]
            unless is_map(exit_rules) do
              {:error, "exit_rules must be an object"}
            else
              # Check entry_rules.conditions
              unless Map.has_key?(entry_rules, "conditions") do
                {:error, "entry_rules must have a conditions array"}
              else
                # Check exit_rules.conditions
                unless Map.has_key?(exit_rules, "conditions") do
                  {:error, "exit_rules must have a conditions array"}
                else
                  # Check entry_rules.conditions is array
                  unless is_list(entry_rules["conditions"]) do
                    {:error, "entry_rules.conditions must be an array"}
                  else
                    # Check exit_rules.conditions is array
                    unless is_list(exit_rules["conditions"]) do
                      {:error, "exit_rules.conditions must be an array"}
                    else
                      :ok
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  @doc """
  Prepares initial form data for a new strategy
  """
  def init_new_form do
    %{
      "name" => "",
      "description" => "",
      "timeframe" => "1h",  # Default to 1 hour timeframe
      "symbol" => "BTCUSDT", # Default to BTC/USDT pair
      "risk_per_trade" => "0.02",
      "max_position_size" => "5"
    }
  end

  @doc """
  Generate a default strategy JSON template
  """
  def generate_default_json_template do
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
    }
    |> Jason.encode!(pretty: true)
  end

  @doc """
  Extracts metadata for the selected indicator to display in the UI
  """
  def get_indicator_metadata(indicator_id) do
    FormGenerator.generate_indicator_form(indicator_id)
  end

  @doc """
  Gets available conditions for rule comparison
  """
  def available_conditions do
    FormGenerator.available_conditions()
  end

  @doc """
  Get a list of available indicators for selection.

  Returns a lightweight list of indicators suitable for dropdowns and selectors.
  Accepts a grouping option to organize indicators by their type.

  ## Options

    * `:group_by_type` - When true, returns indicators grouped by their type
  """
  def available_indicators(opts \\ []) do
    Indicators.indicators_for_select(opts)
  end

  @doc """
  Transform parameter values based on their expected types.

  This ensures that values submitted from forms are correctly typed
  for use in indicator calculations.

  ## Parameters
    - params_map: Map of parameter values from form submission
    - indicator_id: ID of the indicator to get parameter specifications
  """
  def transform_params(params_map, indicator_id) do
    if is_nil(params_map) or params_map == %{}, do: %{}, else: do_transform_params(params_map, indicator_id)
  end

  defp do_transform_params(params_map, indicator_id) do
    # Get parameter specifications from indicator
    params_list = ListIndicator.get_params(indicator_id) || []

    # Transform each parameter according to its type
    transformed_params = Enum.reduce(params_map, %{}, fn {key, value}, acc ->
      # Special handling for timeframe parameters to prevent the KeyError
      if is_binary(key) && (
        String.contains?(key, "timeframe") ||
        String.contains?(key, "price_key") ||
        key == "open" || key == "close" || key == "high" || key == "low") && is_binary(value) do
        Map.put(acc, safe_key_to_atom(key), value)
      else
        param_spec = find_param_spec(params_list, key)
        transformed_value = transform_value(value, param_spec)
        Map.put(acc, safe_key_to_atom(key), transformed_value)
      end
    end)

    transformed_params
  end

  @doc """
  Normalize a parameter key to atom if it's a valid existing atom
  or string otherwise. Safely handles both atom and string keys.
  """
  def safe_key_to_atom(key) when is_atom(key), do: key
  def safe_key_to_atom(key) when is_binary(key) do
    try do
      String.to_existing_atom(key)
    rescue
      ArgumentError -> key
    end
  end
  def safe_key_to_atom(key), do: key

  @doc """
  Validate indicator parameters against their specifications.

  Returns a list of validation errors if any parameters fail validation.
  """
  def validate_params(params_map, indicator_id) do
    params_list = ListIndicator.get_params(indicator_id) || []

    Enum.reduce(params_list, [], fn param_spec, errors ->
      param_key = param_spec.name
      param_value = Map.get(params_map, param_key)

      case validate_parameter(param_value, param_spec) do
        :ok -> errors
        {:error, message} -> [{param_key, message} | errors]
      end
    end)
  end

  # Find parameter specification by name (handles both string and atom keys)
  defp find_param_spec(params_list, key) do
    atom_key = safe_key_to_atom(key)

    # If the key contains specific strings or is a common parameter value, return a special param spec
    if is_binary(key) && (
      String.contains?(key, "timeframe") ||
      String.contains?(key, "price_key") ||
      key == "open" || key == "close" || key == "high" || key == "low") do
      %{name: String.to_atom(key), type: :string_param}
    else
      Enum.find(params_list, fn param ->
        param.name == atom_key || to_string(param.name) == to_string(key)
      end)
    end
  end

  # Special handler for string parameter type (for timeframes, price keys, etc.)
  defp transform_value(value, %{type: :string_param}) when is_binary(value), do: value

  # Add a list of common string values that should never be processed as maps
  defp transform_value(value, _) when is_binary(value) and value in [
    "daily", "weekly", "monthly", "yearly", "1h", "4h", "30m", "15m", "1d", "1w",
    "open", "close", "high", "low", "volume", "hl2", "hlc3", "ohlc4"
  ], do: value

  # Transform values based on parameter type
  defp transform_value(value, nil) when is_binary(value), do: value

  # Special handler for timeframe type (new type we're introducing)
  defp transform_value(value, %{type: :timeframe}) when is_binary(value), do: value

  defp transform_value(value, %{type: :number}) when is_binary(value) do
    case Float.parse(value) do
      {num, _} -> num
      :error -> value
    end
  end

  defp transform_value(value, %{type: :number}) when is_integer(value) or is_float(value) do
    value
  end

  defp transform_value(value, %{type: :select, options: options}) do
    # First - special case for timeframe strings that are common in the system
    if is_binary(value) && Enum.member?(["daily", "weekly", "monthly", "yearly", "1h", "4h", "30m", "15m", "1d", "1w"], value) do
      value
    else
      # Ensure the value is one of the allowed options
      if Enum.any?(options, fn opt -> to_string(opt.value) == to_string(value) end) do
        value
      else
        # Return the first option value if invalid
        case List.first(options) do
          %{value: default_value} -> default_value
          _ -> value
        end
      end
    end
  end

  # Special handling for timeframe parameters
  defp transform_value(value, %{name: :timeframe}) when is_binary(value), do: value
  defp transform_value(value, %{name: "timeframe"}) when is_binary(value), do: value

  # Handle any parameter whose name contains "timeframe"
  defp transform_value(value, param_spec) when is_binary(value) and not is_nil(param_spec) do
    param_name = param_spec[:name]
    if is_binary(param_name) && String.contains?(param_name, "timeframe") do
      value
    else
      if is_atom(param_name) && String.contains?(Atom.to_string(param_name), "timeframe") do
        value
      else
        # For non-timeframe parameters, proceed with default handling
        transform_value_default(value)
      end
    end
  end

  # Handle maps specifically and safely check for :value key
  defp transform_value(%{value: value}, _), do: value

  # Default handler for values that don't match other patterns
  defp transform_value(value, _), do: transform_value_default(value)

  # Helper for default value transformation
  defp transform_value_default(value) when is_binary(value), do: value
  defp transform_value_default(value), do: value

  # Validate parameter against its specification
  defp validate_parameter(value, %{type: :number, min: min, max: max})
       when is_number(value) and not is_nil(min) and not is_nil(max) do
    if value >= min and value <= max do
      :ok
    else
      {:error, "Value must be between #{min} and #{max}"}
    end
  end

  defp validate_parameter(value, %{type: :number, min: min})
       when is_number(value) and not is_nil(min) do
    if value >= min do
      :ok
    else
      {:error, "Value must be at least #{min}"}
    end
  end

  defp validate_parameter(value, %{type: :number, max: max})
       when is_number(value) and not is_nil(max) do
    if value <= max do
      :ok
    else
      {:error, "Value must be at most #{max}"}
    end
  end

  defp validate_parameter(value, %{type: :select, options: options}) do
    if Enum.any?(options, fn opt -> to_string(opt.value) == to_string(value) end) do
      :ok
    else
      {:error, "Invalid selection"}
    end
  end

  defp validate_parameter(_value, _param_spec), do: :ok
end
