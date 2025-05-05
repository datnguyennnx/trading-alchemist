defmodule Central.Backtest.DynamicForm.FormProcessor do
  @moduledoc """
  Processes and validates form data for strategy creation and updates.

  This module handles the conversion between raw form data and the domain
  representation of trading strategies.
  """

  alias Central.Backtest.DynamicForm.FormContext
  alias Central.Backtest.DynamicForm.Rule

  @doc """
  Process strategy creation by handling form data or JSON data.

  This function provides two distinct paths for strategy creation:
  1. Form-based: Uses parsed form data with nested rule structures
  2. JSON-based: Uses a JSON string representation of the complete strategy

  The method used is determined by the presence of the 'creation_method' parameter,
  which should be either "form" or "json".

  ## Parameters
    - params: Map containing form data or JSON configuration
    - user_id: ID of the user creating the strategy

  ## Returns
    - {:ok, strategy_params} if processing is successful
    - {:error, message} if validation fails
  """
  def process_strategy(params, user_id) do
    # Check which creation method was explicitly selected
    creation_method = Map.get(params, "creation_method", "form")

    case creation_method do
      "json" ->
        # JSON path - we explicitly try to use the JSON config
        json_config = Map.get(params, "json_config")

        if is_binary(json_config) && json_config != "" do
          result = FormContext.prepare_strategy_from_json(json_config, user_id)
          result
        else
          {:error, "JSON configuration is empty or invalid"}
        end

      "form" ->
        # Form data path
        process_from_form_data(params, user_id)

      _ ->
        # Default to form path for unknown methods
        process_from_form_data(params, user_id)
    end
  end

  @doc """
  Process strategy creation from form data.
  """
  def process_from_form_data(params, user_id) do
    # Parse rules data from form
    {entry_rules, exit_rules} = parse_rules_from_form(params)

    # Prepare strategy params
    strategy_params =
      FormContext.prepare_strategy_params(params, entry_rules, exit_rules, user_id)

    # Simple validation
    case validate_strategy(strategy_params) do
      :ok ->
        {:ok, strategy_params}

      {:error, message} ->
        {:error, message}
    end
  end

  @doc """
  Parses entry and exit rules from form data
  """
  def parse_rules_from_form(params) do
    # Extract rule definitions from form data
    entry_rules = parse_rule_group(params, "entry")
    exit_rules = parse_rule_group(params, "exit")

    {entry_rules, exit_rules}
  end

  @doc """
  Parse a group of rules (entry or exit) from form data
  """
  def parse_rule_group(params, prefix) do
    # Count how many rules exist by counting indicator fields
    indicator_keys =
      params
      |> Map.keys()
      |> Enum.filter(&String.starts_with?(&1, "#{prefix}_indicator_"))

    count = length(indicator_keys)

    # Parse each rule
    rules =
      0..(count - 1)
      |> Enum.map(fn index ->
        parse_rule(params, prefix, index)
      end)
      |> Enum.filter(&(&1 != nil))

    rules
  end

  @doc """
  Parse a single rule from form data by index
  """
  def parse_rule(params, prefix, index) do
    indicator_key = "#{prefix}_indicator_#{index}"
    condition_key = "#{prefix}_condition_#{index}"
    value_key = "#{prefix}_value_#{index}"

    # Get basic rule components with defaults
    indicator_id = Map.get(params, indicator_key, "sma")

    # Set default values for condition and value since they're not in the UI anymore
    # but the rule structure still requires them
    condition = Map.get(params, condition_key, "crosses_above")
    value = Map.get(params, value_key, "0")

    # Exit early if no indicator was selected, but provide a default
    if is_nil(indicator_id) || indicator_id == "" do
      # Create a rule with default indicator instead of returning nil
      rule_id = "#{prefix}_#{index}"
      default_params = get_default_params_for_indicator("sma")

      rule_attrs =
        if prefix == "exit" do
          %{
            id: rule_id,
            indicator_id: "sma",
            condition: condition,
            value: value,
            params: default_params,
            stop_loss: "0.02",
            take_profit: "0.04"
          }
        else
          %{
            id: rule_id,
            indicator_id: "sma",
            condition: condition,
            value: value,
            params: default_params
          }
        end

      Rule.new(rule_attrs)
    else
      # Build rule struct
      rule_id = "#{prefix}_#{index}"

      # Extract parameters for this indicator
      params_map = extract_indicator_params(params, prefix, index, indicator_id)

      # Add special fields for exit rules
      rule_attrs =
        if prefix == "exit" do
          stop_loss_key = "#{prefix}_stop_loss_#{index}"
          take_profit_key = "#{prefix}_take_profit_#{index}"

          stop_loss = Map.get(params, stop_loss_key)
          take_profit = Map.get(params, take_profit_key)

          %{
            id: rule_id,
            indicator_id: indicator_id,
            condition: condition,
            value: value,
            params: params_map,
            stop_loss: stop_loss,
            take_profit: take_profit
          }
        else
          %{
            id: rule_id,
            indicator_id: indicator_id,
            condition: condition,
            value: value,
            params: params_map
          }
        end

      Rule.new(rule_attrs)
    end
  end

  @doc """
  Extract indicator parameters from form data for a specific rule
  """
  def extract_indicator_params(params, prefix, rule_index, indicator_id) do
    # Find all parameter keys for this rule
    param_prefix = "#{prefix}_param_#{rule_index}_"

    param_keys =
      params
      |> Map.keys()
      |> Enum.filter(&String.starts_with?(&1, param_prefix))

    # Extract parameter values
    raw_params =
      param_keys
      |> Enum.reduce(%{}, fn key, acc ->
        # Extract parameter name from key
        param_name = String.replace_prefix(key, param_prefix, "")
        param_value = Map.get(params, key)

        Map.put(acc, param_name, param_value)
      end)

    # Transform parameters to their correct types
    FormContext.transform_params(raw_params, indicator_id)
  end

  @doc """
  Validates a strategy params map
  """
  def validate_strategy(strategy_params) do
    cond do
      is_nil(strategy_params.name) || strategy_params.name == "" ->
        {:error, "Strategy name is required"}

      is_nil(strategy_params.config["timeframe"]) || strategy_params.config["timeframe"] == "" ->
        {:error, "Timeframe is required"}

      is_nil(strategy_params.config["symbol"]) || strategy_params.config["symbol"] == "" ->
        {:error, "Symbol is required"}

      entry_rules_empty?(strategy_params.entry_rules) ->
        {:error, "At least one entry rule is required"}

      exit_rules_empty?(strategy_params.exit_rules) ->
        {:error, "At least one exit rule or stop loss/take profit is required"}

      true ->
        :ok
    end
  end

  defp entry_rules_empty?(rules) do
    # Handle both atom and string keys (from JSON parsing)
    case rules do
      %{conditions: conditions} when is_list(conditions) ->
        Enum.empty?(conditions)

      %{"conditions" => conditions} when is_list(conditions) ->
        Enum.empty?(conditions)

      _ ->
        true
    end
  end

  defp exit_rules_empty?(rules) do
    # Handle both atom and string keys (from JSON parsing)
    case rules do
      %{conditions: conditions} when is_list(conditions) ->
        Enum.empty?(conditions)

      %{"conditions" => conditions} when is_list(conditions) ->
        Enum.empty?(conditions)

      _ ->
        true
    end
  end

  # Helper function to get default parameters for a given indicator
  defp get_default_params_for_indicator(indicator_id) do
    alias Central.Backtest.DynamicForm.FormContext
    FormContext.get_indicator_params(indicator_id)
  end
end
