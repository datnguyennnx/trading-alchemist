/**
 * Event handlers for LiveView events related to chart data
 */

/**
 * Set up event handlers for the chart
 * 
 * @param {Object} context - The hook context
 * @param {Function} onHistoricalData - Callback when historical data is loaded
 * @returns {void}
 */
export const setupEventHandlers = (context, onHistoricalData) => {
  // Let the LiveView know the chart is initialized
  if (context.pushEvent) {
    setTimeout(() => {
      context.pushEvent("chart-initialized", {
        chartId: context.chartConfig.chartId
      });
    }, 100); // Small delay to ensure DOM is ready
  }
  
  // Listen for initial data
  context.handleEvent('set-initial-data', (payload) => {
    // Verify this event is for our chart
    if (!payload || payload.chartId !== context.chartConfig.chartId) {
      return;
    }
    
    // Set the data on the chart
    if (payload.data && payload.data.length > 0) {
      context.chartData = payload.data;
      
      // Check data format validity
      const validCandles = payload.data.every(candle => 
        typeof candle.time === 'number' &&
        typeof candle.open === 'number' &&
        typeof candle.high === 'number' &&
        typeof candle.low === 'number' &&
        typeof candle.close === 'number' &&
        typeof candle.volume === 'number'
      );
      
      if (!validCandles) {
        // Attempt to fix data by converting to numbers
        payload.data = payload.data.map(candle => ({
          time: Number(candle.time),
          open: Number(candle.open),
          high: Number(candle.high),
          low: Number(candle.low),
          close: Number(candle.close),
          volume: Number(candle.volume)
        }));
        
        context.chartData = payload.data;
      }
      
      try {
        // Log the price range of the data for verification
        const highPrices = payload.data.map(c => c.high);
        const lowPrices = payload.data.map(c => c.low);
        const maxPrice = Math.max(...highPrices);
        const minPrice = Math.min(...lowPrices);
        
        context.mainSeries.setData(payload.data);
      } catch (error) {
        // Error setting data on chart series
      }
      context.dataLoaded = true;
      
      // If there are trades and we're in backtest mode, add markers
      if (context.chartConfig.chartType === 'backtest' && payload.opts && payload.opts.trades) {
        context.trades = payload.opts.trades;
        try {
          context.renderTradeMarkers();
        } catch (error) {
          // Error rendering trade markers
        }
      }
      
      // Fit content and hide loading indicators
      try {
        context.chart.timeScale().fitContent();
      } catch (error) {
        // Error fitting chart content
      }
      context.hideLoadingIndicator();
      context.hideNoDataMessage();
    } else {
      // No data available
      context.showNoDataMessage();
      context.hideLoadingIndicator();
    }
  });
  
  // Listen for historical data
  context.handleEvent('historical-data-loaded', (payload) => {
    // Verify this event is for our chart
    if (payload.chartId !== context.chartConfig.chartId) {
      return;
    }
    
    // Add historical data to the beginning of the chart
    if (payload.data && payload.data.length > 0) {
      // Process the data and update the chart
      try {
        onHistoricalData(payload);
      } catch (error) {
        // Error applying historical data
      }
    }
  });
};

/**
 * Merge new historical data with existing data
 * 
 * @param {Array} existingData - Existing chart data
 * @param {Array} newData - New historical data to merge
 * @returns {Array} - Combined data sorted by time
 */
export const mergeHistoricalData = (existingData, newData) => {
  // Create a map of existing data by timestamp for efficient lookups
  const existingDataMap = new Map(existingData.map(candle => [candle.time, candle]));
  
  // Add new data that doesn't already exist
  for (const candle of newData) {
    if (!existingDataMap.has(candle.time)) {
      existingData.push(candle);
    }
  }
  
  // Sort data by time
  existingData.sort((a, b) => a.time - b.time);
  
  return existingData;
}; 