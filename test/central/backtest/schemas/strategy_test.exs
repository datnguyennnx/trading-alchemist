defmodule Central.Backtest.Schemas.StrategyTest do
  use Central.DataCase, async: true

  alias Central.Backtest.Schemas.Strategy
  alias Central.BacktestFixtures
  alias Central.AccountsFixtures

  describe "strategy schema" do
    setup do
      user = AccountsFixtures.user_fixture()

      valid_attrs = %{
        name: "RSI Strategy",
        description: "Buy when RSI is below 30, sell when above 70",
        config: %{
          "risk_percentage" => 2,
          "take_profit" => 5,
          "stop_loss" => 3
        },
        entry_rules: %{
          "conditions" => [
            %{"indicator" => "rsi", "comparison" => "below", "value" => 30}
          ]
        },
        exit_rules: %{
          "conditions" => [
            %{"indicator" => "rsi", "comparison" => "above", "value" => 70}
          ]
        },
        is_active: true,
        is_public: true,
        user_id: user.id
      }

      %{user: user, valid_attrs: valid_attrs}
    end

    test "changeset with valid attributes", %{valid_attrs: valid_attrs} do
      changeset = Strategy.changeset(%Strategy{}, valid_attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = Strategy.changeset(%Strategy{}, %{})
      refute changeset.valid?

      assert %{
               name: ["can't be blank"],
               config: ["can't be blank"],
               entry_rules: ["can't be blank"],
               exit_rules: ["can't be blank"],
               user_id: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "changeset with name too short", %{valid_attrs: valid_attrs} do
      attrs = %{valid_attrs | name: "AB"}
      changeset = Strategy.changeset(%Strategy{}, attrs)
      refute changeset.valid?
      assert %{name: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "changeset with name too long", %{valid_attrs: valid_attrs} do
      attrs = %{valid_attrs | name: String.duplicate("A", 101)}
      changeset = Strategy.changeset(%Strategy{}, attrs)
      refute changeset.valid?
      assert %{name: ["should be at most 100 character(s)"]} = errors_on(changeset)
    end

    test "changeset with invalid config", %{valid_attrs: valid_attrs} do
      attrs = %{valid_attrs | config: "not a map"}
      changeset = Strategy.changeset(%Strategy{}, attrs)
      refute changeset.valid?
      errors = errors_on(changeset)
      assert errors[:config] == ["is invalid"]
    end

    test "changeset with invalid entry_rules", %{valid_attrs: valid_attrs} do
      attrs = %{valid_attrs | entry_rules: "not a map"}
      changeset = Strategy.changeset(%Strategy{}, attrs)
      refute changeset.valid?
      errors = errors_on(changeset)
      assert errors[:entry_rules] == ["is invalid"]
    end

    test "changeset with invalid exit_rules", %{valid_attrs: valid_attrs} do
      attrs = %{valid_attrs | exit_rules: "not a map"}
      changeset = Strategy.changeset(%Strategy{}, attrs)
      refute changeset.valid?
      errors = errors_on(changeset)
      assert errors[:exit_rules] == ["is invalid"]
    end

    test "creating strategy with fixture" do
      strategy = BacktestFixtures.strategy_fixture()
      assert strategy.name == "Test Strategy"
      assert strategy.description == "A strategy for testing"

      assert strategy.config == %{
               "risk_percentage" => 1,
               "take_profit" => 3,
               "stop_loss" => 2
             }

      assert strategy.entry_rules == %{
               "conditions" => [
                 %{"indicator" => "price", "comparison" => "above", "value" => 50000}
               ]
             }

      assert strategy.exit_rules == %{
               "conditions" => [
                 %{"indicator" => "price", "comparison" => "below", "value" => 48000}
               ]
             }

      assert strategy.is_active == true
      assert strategy.is_public == false
      assert strategy.user_id
    end

    test "creating strategy with custom attributes", %{user: user} do
      custom_attrs = %{
        name: "Custom Bollinger Strategy",
        description: "Uses Bollinger Bands for entries and exits",
        config: %{
          "risk_percentage" => 1.5,
          "bands_deviation" => 2.0
        },
        entry_rules: %{
          "conditions" => [
            %{"indicator" => "price", "comparison" => "below", "value" => "lower_band"}
          ]
        },
        exit_rules: %{
          "conditions" => [
            %{"indicator" => "price", "comparison" => "above", "value" => "middle_band"}
          ]
        },
        is_active: false,
        is_public: true,
        user_id: user.id
      }

      strategy = BacktestFixtures.strategy_fixture(custom_attrs)
      assert strategy.name == "Custom Bollinger Strategy"
      assert strategy.description == "Uses Bollinger Bands for entries and exits"

      assert strategy.config == %{
               "risk_percentage" => 1.5,
               "bands_deviation" => 2.0
             }

      assert strategy.entry_rules == %{
               "conditions" => [
                 %{"indicator" => "price", "comparison" => "below", "value" => "lower_band"}
               ]
             }

      assert strategy.exit_rules == %{
               "conditions" => [
                 %{"indicator" => "price", "comparison" => "above", "value" => "middle_band"}
               ]
             }

      assert strategy.is_active == false
      assert strategy.is_public == true
      assert strategy.user_id == user.id
    end

    test "creating strategy with invalid user id" do
      # We need to use a non-integer value to trigger an error
      invalid_user_id = "not-an-integer"

      attrs = %{
        name: "Invalid Strategy",
        description: "Strategy with invalid user ID",
        config: %{"risk_percentage" => 1},
        entry_rules: %{"conditions" => []},
        exit_rules: %{"conditions" => []},
        user_id: invalid_user_id
      }

      changeset = Strategy.changeset(%Strategy{}, attrs)
      refute changeset.valid?
      assert errors_on(changeset)[:user_id] == ["is invalid"]
    end
  end
end
