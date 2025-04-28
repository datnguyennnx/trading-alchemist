/**
 * @fileoverview Phoenix LiveView hook for integrating Lightweight Charts.
 *
 * This hook manages the lifecycle of a Lightweight Charts instance within a LiveView page.
 *
 * Responsibilities:
 * - `mounted()`: Initializes the chart instance, sets up the main candlestick series,
 *   parses configuration from data attributes, establishes event listeners for LiveView
 *   events (like receiving initial/historical data), sets up resize handling, and notifies
 *   the LiveView backend that the chart is ready (`chart-initialized` event).
 * - `updated()`: Primarily handles updates pushed from LiveView, though in the current
 *   data flow model, most data updates are handled via specific event listeners setup
 *   in `setupEventHandlers`.
 * - `destroyed()`: Cleans up the chart instance and any listeners when the LiveView
 *   component is removed.
 * - `disconnected()` / `reconnected()`: Handle temporary disconnection/reconnection.
 * - `handleSetInitialData(payload)`: Processes the initial data payload received from the
 *   `set-initial-data` event, validates it, sets the data on the main series, renders
 *   trade markers (if applicable), fits the chart view, and hides loading indicators.
 * - `handleHistoricalDataLoaded(payload)`: Processes historical data received from the
 *   `historical-data-loaded` event, merges it with existing data, updates the chart series,
 *   and renders any new trade markers.
 * - `setupEventHandlers()`: Registers listeners for events pushed from the LiveView backend
 *   (e.g., `set-initial-data`, `historical-data-loaded`). Delegates processing to
 *   `handleSetInitialData` and `handleHistoricalDataLoaded`.
 * - `initChart()`: Creates the Lightweight Charts instance and adds the main candlestick series.
 * - `renderTradeMarkers()`: Calculates and applies trade markers to the chart series
 *   based on the `this.trades` data.
 * - Helper functions (`show/hideLoadingIndicator`, `show/hideNoDataMessage`) for UI state.
 *
 * Interaction:
 * - Receives configuration and initial data signals from the `ChartComponent` LiveComponent.
 * - Pushes `chart-initialized` and `load-historical-data` events back to the backend
 *   (specifically to the parent component like `BacktestChartComponent`).
 * - Uses helper modules (`./config`, `./markers`, `./utils`, etc.) for specific tasks.
 */

import { createChart, CandlestickSeries } from 'lightweight-charts';

// Import our modular components
import { generateChartOptions } from './config/chart_options';
import { getCandlestickOptions } from './series/candlestick_series';
import { setupEventHandlers, mergeHistoricalData } from './handlers/event_handlers';
import { initScrollHandler } from './handlers/scroll_handler';
import { renderTradeMarkers, addNewTradeMarkers } from './markers/trade_markers';
import { 
  setupResizeListener,
  hideLoadingIndicator,
  showNoDataMessage,
  hideNoDataMessage
} from './utils/ui_utils';

const TradingViewChart = {
  mounted() {
    this.chart = null;
    this.mainSeries = null;
    
    // Get chart config from the element's data attributes
    const chartId = this.el.dataset.chartId;
    const symbol = this.el.dataset.symbol;
    const timeframe = this.el.dataset.timeframe;
    const theme = this.el.dataset.theme || 'light';
    const chartType = this.el.dataset.chartType || 'generic'; // 'generic' or 'backtest'
    
    // Parse optional configuration
    const startTimeLimit = this.el.dataset.startTimeLimit ? parseInt(this.el.dataset.startTimeLimit) : null;
    const endTimeLimit = this.el.dataset.endTimeLimit ? parseInt(this.el.dataset.endTimeLimit) : null;
    let opts = {};
    
    try {
      opts = this.el.dataset.opts ? JSON.parse(this.el.dataset.opts) : {};
    } catch (error) {
      // Error parsing chart options
    }
    
    // Store configuration for later use
    this.chartConfig = {
      chartId,
      symbol,
      timeframe,
      theme,
      chartType,
      startTimeLimit,
      endTimeLimit,
      ...opts
    };
    
    this.initChart();

    // Add the function callable via push_exec
    this.setInitialChartData = (payload) => {
      this.processInitialData(payload);
    };

    // Setup other event handlers (like scroll, resize) if needed, but not set-initial-data
    try {
      this.setupEventHandlers(); // This will now exclude set-initial-data listener
    } catch (error) {
      // Error setting up event handlers
    }
    
    // Handle window resize
    try {
      this.resizeObserver = setupResizeListener(this);
    } catch (error) {
      // Error setting up resize observer
    }

    // Notify the LiveView that the chart is initialized and ready for data
    setTimeout(() => {
      this.pushEvent("chart-initialized", {
        chartId: chartId
      });
    }, 0);
  },
  
  initChart() {
    if (this.chart) return; // Prevent re-initialization

    const chartOptions = generateChartOptions(this.chartConfig);

    this.chart = createChart(this.el, chartOptions);

    // Initialize candlestick series
    try {
      this.mainSeries = this.chart.addSeries(CandlestickSeries);
      const seriesOptions = getCandlestickOptions(this.chartConfig);
      this.mainSeries.applyOptions(seriesOptions);
    } catch (error) {
      if (this.chart) {
        this.chart.remove();
        this.chart = null;
      }
      throw error;
    }
    
    // Track data state
    this.chartData = [];
    this.trades = [];
    this.isLoading = true;
    this.dataLoaded = false;
    this.tradeMarkers = [];
  },
  
  updated() {
    // Log when the hook's DOM element is updated by LiveView
  },
  
  // NEW function to process the initial data payload
  processInitialData(payload) {
    if (!payload || payload.chartId !== this.chartConfig.chartId) {
      return;
    }

    if (payload.data && payload.data.length > 0) {
      this.chartData = payload.data;

      const validCandles = this.chartData.every(candle =>
        typeof candle.time === 'number' &&
        typeof candle.open === 'number' &&
        typeof candle.high === 'number' &&
        typeof candle.low === 'number' &&
        typeof candle.close === 'number' &&
        typeof candle.volume === 'number'
      );

      if (!validCandles) {
        this.showNoDataMessage();
        this.hideLoadingIndicator();
        return;
      }

      try {
        const highPrices = this.chartData.map(c => c.high);
        const lowPrices = this.chartData.map(c => c.low);
        const maxPrice = Math.max(...highPrices);
        const minPrice = Math.min(...lowPrices);

        this.mainSeries.setData(this.chartData);
        
        // Now handle trades if they were sent (currently commented out on server)
        if (this.chartConfig.chartType === 'backtest' && payload.opts && payload.opts.trades) {
            this.trades = payload.opts.trades;
            this.renderTradeMarkers(); 
        }
        
      } catch (error) {
        this.showNoDataMessage();
        this.hideLoadingIndicator();
        return;
      }
      this.dataLoaded = true;
      try {
        this.chart.timeScale().fitContent();
      } catch (error) {
        // Error fitting chart content
      }
      this.hideLoadingIndicator();
      this.hideNoDataMessage();
    } else {
      this.showNoDataMessage();
      this.hideLoadingIndicator();
    }
  },

  setupEventHandlers() {
    // Call the imported setup function which includes the 'set-initial-data' listener
    setupEventHandlers(this, (payload) => {
      // Define the callback for when historical data is loaded and merged
      if (payload.trades && payload.trades.length > 0) {
        this.trades = this.trades.concat(payload.trades);
        this.trades.sort((a, b) => a.time - b.time);
        this.renderTradeMarkers(); // Re-render all markers
      }
    });
    
    // Setup scroll handler for loading more data (if applicable)
    this.scrollHandlerCleanup = initScrollHandler(this);
  },
  
  // Expose UI utility methods
  hideLoadingIndicator() {
    hideLoadingIndicator(this);
  },
  
  showNoDataMessage() {
    showNoDataMessage(this);
  },
  
  hideNoDataMessage() {
    hideNoDataMessage(this);
  },
  
  // Expose trade marker methods
  renderTradeMarkers() {
    if (this.chartData.length === 0 && this.trades.length > 0) {
      // Found trades but no chart data
    }
    
    const markers = this.trades.map(trade => {
      // Implement marker rendering logic here
    });

    // For debugging marker format
    if (markers.length > 0) {
      if (markers.length > 1) {
      }
    }
  },
  
  destroyed() {
    // Clean up on element removal
    if (this.chart) {
      this.chart.remove();
    }
    
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
    }
    
    if (this.scrollHandlerCleanup) {
      this.scrollHandlerCleanup();
    }
  }
};

export default TradingViewChart; 