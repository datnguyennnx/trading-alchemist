/**
 * Scroll handling for chart navigation and historical data loading
 */

/**
 * Initialize scroll handler for loading historical data
 * 
 * @param {Object} context - The hook context
 * @returns {Function} - Cleanup function
 */
export const initScrollHandler = (context) => {
  // Only activate scroll handling for non-backtest charts
  if (!context.chart || context.chartConfig.chartType === 'backtest') return () => {};
  
  // Create scroll handler function
  const handleScroll = (logicalRange) => {
    // If we're at the beginning of the available data, request more
    if (logicalRange && logicalRange.from <= 0.5 && !context.isLoadingHistorical && context.dataLoaded) {
      context.isLoadingHistorical = true;
      
      // Get the oldest timestamp in the current data
      if (!context.chartData.length) return;
      
      const oldestCandle = context.chartData.reduce(
        (oldest, candle) => candle.time < oldest.time ? candle : oldest, 
        context.chartData[0]
      );
      
      const oldestTimeISO = new Date(oldestCandle.time * 1000).toISOString();
      
      // Request more historical data
      context.pushEvent('load-historical-data', {
        oldestTimeISO,
        limit: 200 // Default chunk size
      });
      
      // Add a small delay to prevent multiple rapid requests
      setTimeout(() => {
        context.isLoadingHistorical = false;
      }, 1000);
    }
  };
  
  // Subscribe to visible range changes
  const subscription = context.chart.timeScale().subscribeVisibleLogicalRangeChange(handleScroll);
  
  // Return cleanup function
  return () => {
    if (subscription) {
      subscription.unsubscribe();
    }
  };
}; 