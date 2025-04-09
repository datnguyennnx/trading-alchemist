defmodule Central.Backtest.Services.RuleEvaluator do
  @moduledoc """
  Evaluates trading rules and conditions for strategy execution during backtesting.
  Provides functions for processing entry and exit conditions defined in strategies.
  """

  require Logger
  alias Central.Backtest.Services.MarketDataHandler

  @doc """
  Extract entry rules from a strategy configuration.

  ## Parameters
    - strategy: The strategy struct containing rules configuration

  ## Returns
    - List of entry rule maps
  """
  def get_entry_rules(strategy) do
    entry_rules =
      cond do
        # Check if entry_rules is a field in the strategy and has "conditions" key
        Map.has_key?(strategy, :entry_rules) &&
          is_map(strategy.entry_rules) &&
            Map.has_key?(strategy.entry_rules, "conditions") ->
          strategy.entry_rules["conditions"]

        # Check if entry_rules is directly in config in new format
        is_map(strategy.config) &&
          Map.has_key?(strategy.config, "entry_rules") &&
          is_map(strategy.config["entry_rules"]) &&
            Map.has_key?(strategy.config["entry_rules"], "conditions") ->
          strategy.config["entry_rules"]["conditions"]

        # Check legacy format directly in entry_rules
        Map.has_key?(strategy, :entry_rules) &&
            is_map(strategy.entry_rules) ->
          [strategy.entry_rules]

        # Check legacy format in config
        is_map(strategy.config) &&
            Map.has_key?(strategy.config, "entry_rules") ->
          rules = strategy.config["entry_rules"]
          if is_map(rules), do: [rules], else: rules

        # Default if nothing found
        true ->
          [%{"indicator" => "price", "condition" => "crosses_above", "value" => "200"}]
      end

    # Ensure we always return a list
    case entry_rules do
      nil -> [%{"indicator" => "price", "condition" => "crosses_above", "value" => "200"}]
      rules when is_list(rules) -> rules
      rule when is_map(rule) -> [rule]
      _ -> [%{"indicator" => "price", "condition" => "crosses_above", "value" => "200"}]
    end
  end

  @doc """
  Extract exit rules from a strategy configuration.

  ## Parameters
    - strategy: The strategy struct containing rules configuration

  ## Returns
    - List of exit rule maps
  """
  def get_exit_rules(strategy) do
    exit_rules =
      cond do
        # Check if exit_rules is a field in the strategy and has "conditions" key
        Map.has_key?(strategy, :exit_rules) &&
          is_map(strategy.exit_rules) &&
            Map.has_key?(strategy.exit_rules, "conditions") ->
          strategy.exit_rules["conditions"]

        # Check if exit_rules is directly in config in new format
        is_map(strategy.config) &&
          Map.has_key?(strategy.config, "exit_rules") &&
          is_map(strategy.config["exit_rules"]) &&
            Map.has_key?(strategy.config["exit_rules"], "conditions") ->
          strategy.config["exit_rules"]["conditions"]

        # Check legacy format directly in exit_rules
        Map.has_key?(strategy, :exit_rules) &&
            is_map(strategy.exit_rules) ->
          [strategy.exit_rules]

        # Check legacy format in config
        is_map(strategy.config) &&
            Map.has_key?(strategy.config, "exit_rules") ->
          rules = strategy.config["exit_rules"]
          if is_map(rules), do: [rules], else: rules

        # Default if nothing found
        true ->
          [%{"indicator" => "price", "condition" => "crosses_below", "value" => "190"}]
      end

    # Ensure we always return a list
    case exit_rules do
      nil -> [%{"indicator" => "price", "condition" => "crosses_below", "value" => "190"}]
      rules when is_list(rules) -> rules
      rule when is_map(rule) -> [rule]
      _ -> [%{"indicator" => "price", "condition" => "crosses_below", "value" => "190"}]
    end
  end

  @doc """
  Evaluate if any entry rule is satisfied.

  ## Parameters
    - rules: List of rule maps to evaluate
    - candle: Current market data candle
    - backtest: Backtest struct with configuration

  ## Returns
    - Boolean indicating if entry should occur
  """
  def evaluate_entry_rules(rules, candle, _backtest) do
    # Check if any rule is satisfied
    Enum.any?(rules, fn rule ->
      # Handle different keys used in rule configuration
      indicator = rule["indicator"] || "price"
      condition = rule["condition"] || rule["comparison"] || "greater_than"
      value = rule["value"] || "0"

      # Convert value to float if needed
      threshold =
        try do
          MarketDataHandler.parse_decimal_or_float(value)
        rescue
          _ -> 0.0
        end

      # Get indicator value (ensure it's a float)
      indicator_value = get_indicator_value(indicator, candle)

      # Evaluate condition (with safe comparison)
      safe_compare(indicator_value, threshold, condition)
    end)
  end

  @doc """
  Evaluate if any exit rule is satisfied.

  ## Parameters
    - rules: List of rule maps to evaluate
    - candle: Current market data candle
    - state: Current backtest state
    - backtest: Backtest struct with configuration

  ## Returns
    - Boolean indicating if exit should occur
  """
  def evaluate_exit_rules(rules, candle, state, backtest) do
    # Similar to entry rules, but can include position-specific conditions
    position = state.position

    # Get stop loss and take profit values from exit rules or strategy config
    {stop_loss_pct, take_profit_pct} = get_stop_loss_take_profit(rules, backtest.strategy)

    # Get entry price as float
    entry_price = MarketDataHandler.parse_decimal_or_float(position.entry_price)
    close_price = MarketDataHandler.parse_decimal_or_float(candle.close)

    # Always include take-profit and stop-loss checks
    take_profit_reached = position && close_price >= entry_price * (1 + take_profit_pct)
    stop_loss_reached = position && close_price <= entry_price * (1 - stop_loss_pct)

    # Check strategy-defined rules
    rules_satisfied =
      Enum.any?(rules, fn rule ->
        # Handle different keys used in rule configuration
        indicator = rule["indicator"] || "price"
        condition = rule["condition"] || rule["comparison"] || "less_than"
        value = rule["value"] || "0"

        # Convert value to float if needed
        threshold =
          try do
            MarketDataHandler.parse_decimal_or_float(value)
          rescue
            _ -> 0.0
          end

        # Get indicator value
        indicator_value = get_indicator_value(indicator, candle)

        # Evaluate condition (with safe comparison)
        safe_compare(indicator_value, threshold, condition)
      end)

    # Exit if any condition is met
    take_profit_reached || stop_loss_reached || rules_satisfied
  end

  # Extract stop loss and take profit values from rules or strategy config
  defp get_stop_loss_take_profit(rules, strategy) do
    # Default values
    # 3%
    default_stop_loss = 0.03
    # 5%
    default_take_profit = 0.05

    # Try to find in the first rule with stop_loss/take_profit
    stop_loss =
      Enum.find_value(rules, default_stop_loss, fn rule ->
        if rule["stop_loss"], do: parse_percentage(rule["stop_loss"]), else: nil
      end)

    take_profit =
      Enum.find_value(rules, default_take_profit, fn rule ->
        if rule["take_profit"], do: parse_percentage(rule["take_profit"]), else: nil
      end)

    # If not found in rules, check strategy config
    stop_loss =
      if stop_loss == default_stop_loss &&
           is_map(strategy.config) &&
           Map.has_key?(strategy.config, "risk_per_trade") do
        parse_percentage(strategy.config["risk_per_trade"])
      else
        stop_loss
      end

    {stop_loss, take_profit}
  end

  # Parse percentage string to float
  defp parse_percentage(value) when is_binary(value) do
    case Float.parse(value) do
      {num, _} -> num / 100.0
      # Default to 3%
      :error -> 0.03
    end
  end

  defp parse_percentage(value) when is_number(value), do: value / 100.0
  # Default to 3%
  defp parse_percentage(_), do: 0.03

  # Get indicator value for a specific indicator type
  defp get_indicator_value(indicator, candle) do
    case indicator do
      "price" -> candle.close
      # 50-period MA as example
      "moving_average" -> calculate_moving_average(candle, 50)
      # Alias for moving_average
      "sma" -> calculate_moving_average(candle, 50)
      # 14-period RSI as example
      "rsi" -> calculate_rsi(candle, 14)
      # Default to price
      _ -> candle.close
    end
  end

  # Safe comparison function that handles different types
  defp safe_compare(left, right, operator) do
    # Convert both values to floats to ensure consistent comparison
    left_float = MarketDataHandler.parse_decimal_or_float(left)
    right_float = MarketDataHandler.parse_decimal_or_float(right)

    case operator do
      "greater_than" -> left_float > right_float
      "less_than" -> left_float < right_float
      # Simplified, should check previous value too
      "crosses_above" -> left_float > right_float
      # Simplified, should check previous value too
      "crosses_below" -> left_float < right_float
      # Alias for greater_than
      "above" -> left_float > right_float
      # Alias for less_than
      "below" -> left_float < right_float
      "equals" -> left_float == right_float
      _ -> false
    end
  end

  # Simple placeholder functions for technical indicators
  # In a real implementation, these would use the Indicators module

  defp calculate_moving_average(_candle, _period) do
    # Placeholder - would calculate MA from historical data
    # For this test implementation, just return a random value
    :rand.uniform() * 1000 + 40000
  end

  defp calculate_rsi(_candle, _period) do
    # Placeholder - would calculate RSI from historical data
    # For this test implementation, just return a random value between 0-100
    :rand.uniform() * 100
  end
end
