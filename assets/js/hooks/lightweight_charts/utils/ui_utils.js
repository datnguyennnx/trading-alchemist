/**
 * UI Utilities for chart display
 */

/**
 * Setup resize handling for the chart
 * 
 * @param {Object} context - The hook context
 * @returns {ResizeObserver} - The resize observer
 */
export const setupResizeListener = (context) => {
  // Create a resize observer to handle chart resizing
  const resizeObserver = new ResizeObserver(entries => {
    for (const entry of entries) {
      if (entry.target === context.el && context.chart) {
        const { width, height } = entry.contentRect;
        context.chart.resize(width, height);
      }
    }
  });
  
  // Start observing the chart container
  resizeObserver.observe(context.el);
  
  return resizeObserver;
};

/**
 * Hide the loading indicator
 * 
 * @param {Object} context - The hook context
 * @returns {void}
 */
export const hideLoadingIndicator = (context) => {
  // Find the loading overlay element
  const loaderId = `${context.chartConfig.chartId}-loader`;
  const loader = document.getElementById(loaderId);
  if (loader) {
    loader.style.display = 'none';
  }
  context.isLoading = false;
};

/**
 * Show the "no data available" message
 * 
 * @param {Object} context - The hook context
 * @returns {void}
 */
export const showNoDataMessage = (context) => {
  // Show "No data available" message
  const noDataEl = document.getElementById(`${context.chartConfig.chartId}-no-data-text`);
  if (noDataEl) {
    noDataEl.classList.remove('hidden');
  }
};

/**
 * Hide the "no data available" message
 * 
 * @param {Object} context - The hook context
 * @returns {void}
 */
export const hideNoDataMessage = (context) => {
  // Hide "No data available" message
  const noDataEl = document.getElementById(`${context.chartConfig.chartId}-no-data-text`);
  if (noDataEl) {
    noDataEl.classList.add('hidden');
  }
}; 