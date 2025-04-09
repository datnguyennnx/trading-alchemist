defmodule Central.Backtest.Services.StrategyExecutor do
  @moduledoc """
  Executes trading strategies against historical market data for backtesting.

  This module coordinates the overall execution of a backtest, delegating to specialized
  helper modules for specific functionality like market data handling, rule evaluation,
  and trade management.
  """

  require Logger
  alias Ecto.Multi

  alias Central.Backtest.Contexts.BacktestContext

  alias Central.Backtest.Services.{
    RiskManager,
    TradeManager,
    RuleEvaluator,
    MarketDataHandler
  }

  alias Central.Utils.DatetimeUtils
  alias Central.Repo

  @doc """
  Executes a backtest with the given backtest_id.
  Updates progress through the provided progress_callback function.

  ## Parameters
    - backtest_id: ID of the backtest to execute
    - progress_callback: Function that accepts an integer (0-100) to report progress

  ## Returns
    - {:ok, result} where result contains summary information
    - {:error, reason} if execution failed
  """
  def execute_backtest(backtest_id, progress_callback) when is_function(progress_callback, 1) do
    # Get the backtest with strategy
    backtest = BacktestContext.get_backtest!(backtest_id) |> Repo.preload(:strategy)

    Logger.info("Starting backtest execution for backtest_id: #{backtest_id}")
    log_backtest_params(backtest)

    # Call progress callback with initial progress
    progress_callback.(0)

    try do
      # Fetch market data for the backtest period
      {:ok, market_data} = MarketDataHandler.fetch_market_data(backtest)
      total_candles = length(market_data)

      Logger.info("Fetched #{total_candles} candles for backtest_id: #{backtest_id}")

      if total_candles == 0 do
        Logger.error("No market data available for backtest_id: #{backtest_id}")
        raise "No market data available for the specified time period"
      end

      # Initialize state for the backtest
      initial_state = initialize_backtest_state(backtest)
      Logger.debug("Initial state created: #{inspect(initial_state)}")

      # Process each candle
      {final_state, _} =
        process_all_candles(market_data, initial_state, backtest, progress_callback)

      Logger.info("Completed processing candles. Final balance: #{inspect(final_state.balance)}")
      Logger.debug("Total trades executed: #{length(final_state.trades)}")

      # Close any open positions at the end of the backtest
      final_state = close_final_position(final_state, backtest)

      # Update the backtest with results
      Logger.info("Updating backtest results in database for backtest_id: #{backtest_id}")
      {:ok, _updated_backtest} = update_backtest_results(backtest, final_state)

      Logger.info(
        "Backtest completed successfully: backtest_id=#{backtest_id}, final_balance=#{inspect(final_state.balance)}"
      )

      # Final progress update
      progress_callback.(100)

      {:ok,
       %{
         backtest_id: backtest_id,
         final_balance: final_state.balance,
         trade_count: length(final_state.trades)
       }}
    rescue
      e ->
        Logger.error("Error executing backtest #{backtest_id}: #{inspect(e)}")
        Logger.error("Stacktrace: #{Exception.format_stacktrace()}")

        # Update backtest status to failed
        update_backtest_status(BacktestContext.get_backtest!(backtest_id), :failed, %{
          error: "#{inspect(e)}"
        })

        {:error, e}
    end
  end

  # Log important backtest parameters
  defp log_backtest_params(backtest) do
    Logger.debug(
      "Backtest details: id=#{inspect(backtest.id)}, symbol=#{inspect(backtest.symbol)}, timeframe=#{inspect(backtest.timeframe)}"
    )

    Logger.debug(
      "Backtest period: start=#{inspect(backtest.start_time)}, end=#{inspect(backtest.end_time)}"
    )

    Logger.debug(
      "Backtest config: initial_balance=#{inspect(backtest.initial_balance)}, position_size=#{inspect(RiskManager.get_position_size(backtest))}"
    )

    Logger.debug(
      "Strategy: id=#{inspect(backtest.strategy.id)}, name=#{inspect(backtest.strategy.name)}"
    )

    Logger.debug("Strategy config: #{inspect(backtest.strategy.config)}")
  end

  # Initialize the state for a backtest
  defp initialize_backtest_state(backtest) do
    # Get initial balance
    initial_balance =
      MarketDataHandler.parse_decimal_or_float(backtest.initial_balance) || 10000.0

    Logger.debug("Initial balance set to: #{inspect(initial_balance)}")

    %{
      balance: initial_balance,
      position: nil,
      trades: [],
      last_price: nil,
      processed_candles: 0
    }
  end

  # Process all candles for a backtest
  defp process_all_candles(market_data, initial_state, backtest, progress_callback) do
    total_candles = length(market_data)

    Logger.info("Starting to process #{total_candles} candles for backtest_id: #{backtest.id}")

    Enum.reduce_while(market_data, {initial_state, nil}, fn candle,
                                                            {state, _prev_candle} = _acc ->
      try do
        # Update progress every 5% of candles
        if rem(state.processed_candles, max(1, div(total_candles, 20))) == 0 do
          progress = round(state.processed_candles / total_candles * 100)

          Logger.debug(
            "Processing progress: #{progress}% (candle #{state.processed_candles + 1} of #{total_candles})"
          )

          progress_callback.(progress)
        end

        # Process this candle
        Logger.debug(
          "Processing candle #{state.processed_candles + 1}: timestamp=#{inspect(candle.timestamp)}, close=#{inspect(candle.close)}"
        )

        updated_state = process_candle(candle, state, backtest)

        # Log position changes
        log_position_changes(state, updated_state, candle, state.processed_candles + 1)

        # Return the updated state and current candle
        {:cont, {%{updated_state | processed_candles: state.processed_candles + 1}, candle}}
      rescue
        e ->
          Logger.error("Error processing candle #{state.processed_candles + 1}: #{inspect(e)}")
          Logger.error("Candle: #{inspect(candle)}")
          Logger.error("State: #{inspect(state)}")
          Logger.error("Stacktrace: #{Exception.format_stacktrace()}")
          {:halt, {state, nil}}
      end
    end)
  end

  # Log position changes for better visibility
  defp log_position_changes(old_state, new_state, candle, candle_number) do
    if new_state.position != old_state.position do
      if new_state.position != nil do
        Logger.info(
          "Position opened at candle #{candle_number}: price=#{inspect(candle.close)}, size=#{inspect(new_state.position.size)}"
        )
      end

      if old_state.position != nil && new_state.position == nil do
        latest_trade = List.first(new_state.trades)

        Logger.info(
          "Position closed at candle #{candle_number}: profit/loss=#{inspect(latest_trade.pnl)}"
        )
      end
    end
  end

  # Process a single candle for the backtest
  defp process_candle(candle, state, backtest) do
    # Update the last price
    last_price = MarketDataHandler.parse_decimal_or_float(candle.close)
    state = %{state | last_price: last_price}

    # Check entry conditions if we have no position
    state =
      if is_nil(state.position) do
        check_entry_conditions(state, candle, backtest)
      else
        check_exit_conditions(state, candle, backtest)
      end

    state
  end

  # Check if we should enter a position
  defp check_entry_conditions(state, candle, backtest) do
    # Get entry rules from strategy config
    entry_rules = RuleEvaluator.get_entry_rules(backtest.strategy)

    # Check if any entry rule is satisfied
    should_enter = RuleEvaluator.evaluate_entry_rules(entry_rules, candle, backtest)

    if should_enter do
      # Calculate position size
      position_size = RiskManager.calculate_position_size(state.balance, backtest)

      # Ensure timestamp is in UTC DateTime format for database compatibility
      timestamp = DatetimeUtils.to_utc_datetime(candle.timestamp)

      # Enter position
      %{
        state
        | position: %{
            entry_price: MarketDataHandler.parse_decimal_or_float(candle.close),
            entry_time: timestamp,
            size: position_size,
            # For simplicity, only long positions for now
            direction: :long
          }
      }
    else
      state
    end
  end

  # Check if we should exit a position
  defp check_exit_conditions(state, candle, backtest) do
    # Get exit rules from strategy config
    exit_rules = RuleEvaluator.get_exit_rules(backtest.strategy)

    # Check if any exit rule is satisfied
    should_exit = RuleEvaluator.evaluate_exit_rules(exit_rules, candle, state, backtest)

    if should_exit do
      # Close the position
      TradeManager.close_position(state, candle.close, "Exit rule triggered", backtest)
    else
      state
    end
  end

  # Close any open positions at the end of the backtest
  defp close_final_position(state, backtest) do
    if state.position do
      Logger.debug("Closing final position: #{inspect(state.position)}")
      TradeManager.close_position(state, state.last_price, "End of backtest", backtest)
    else
      state
    end
  end

  # Update backtest results in the database
  defp update_backtest_results(backtest, final_state) do
    # Get original balance as float for calculation
    initial_balance =
      MarketDataHandler.parse_decimal_or_float(backtest.initial_balance) || 10000.0

    # Ensure final balance is a number
    final_balance = MarketDataHandler.parse_decimal_or_float(final_state.balance)
    profit_loss = final_balance - initial_balance

    # First update the backtest status and final balance
    multi =
      Multi.new()
      |> Multi.update(
        :backtest,
        Ecto.Changeset.change(backtest, %{
          final_balance: final_balance,
          status: :completed,
          metadata:
            Map.merge(backtest.metadata || %{}, %{
              "trade_count" => length(final_state.trades),
              "profit_loss" => profit_loss
            })
        })
      )

    # Prepare trade records for database
    trade_entries = prepare_trade_entries(final_state.trades, backtest.id)

    # Add each trade as a separate insert operation
    multi_with_trades =
      if Enum.empty?(trade_entries) do
        multi
      else
        # Insert all trades in a single operation
        Multi.insert_all(multi, :trades, Central.Backtest.Schemas.Trade, trade_entries)
      end

    # Execute the transaction
    Repo.transaction(multi_with_trades)
  end

  # Prepare trade entries for database insertion
  defp prepare_trade_entries(trades, backtest_id) do
    Enum.map(trades, fn trade ->
      # Calculate percentage PnL
      entry_price = MarketDataHandler.parse_decimal_or_float(trade.entry_price)
      pnl = MarketDataHandler.parse_decimal_or_float(trade.pnl)
      pnl_percentage = if entry_price > 0, do: pnl / entry_price * 100, else: 0

      # Get current timestamp as NaiveDateTime for database compatibility with inserted_at/updated_at
      now = DatetimeUtils.naive_utc_now_sec()

      # Convert DateTime values to UTC DateTime for database compatibility
      entry_time = DatetimeUtils.to_utc_datetime(trade.entry_time)
      exit_time = DatetimeUtils.to_utc_datetime(trade.exit_time)

      # Log the datetime conversions for debugging
      Logger.debug(
        "Entry time conversion: #{inspect(trade.entry_time)} -> #{inspect(entry_time)}"
      )

      Logger.debug("Exit time conversion: #{inspect(trade.exit_time)} -> #{inspect(exit_time)}")

      %{
        backtest_id: backtest_id,
        entry_price: MarketDataHandler.parse_decimal_or_float(trade.entry_price),
        entry_time: entry_time,
        exit_price: MarketDataHandler.parse_decimal_or_float(trade.exit_price),
        exit_time: exit_time,
        quantity: MarketDataHandler.parse_decimal_or_float(trade.size),
        # Keep as atom for Ecto.Enum field
        side: trade.direction,
        pnl: pnl,
        pnl_percentage: pnl_percentage,
        fees: 0.0,
        tags: [],
        entry_reason: "Strategy signal",
        exit_reason: trade.reason,
        metadata: %{},
        inserted_at: now,
        updated_at: now
      }
    end)
  end

  # Update backtest status in the database
  defp update_backtest_status(backtest, status, metadata) do
    # Merge new metadata with existing metadata
    updated_metadata = Map.merge(backtest.metadata || %{}, metadata)

    # Create changeset and update
    backtest
    |> Ecto.Changeset.change(%{status: status, metadata: updated_metadata})
    |> Repo.update()
  end
end
