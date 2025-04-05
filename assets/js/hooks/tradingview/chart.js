/**
 * Main chart initialization and management
 */

import { createChart } from 'lightweight-charts';
import { themes, getChartOptions } from './themes';
import { isCryptoSymbol } from './utils';
import { 
  createCandlestickSeries, 
  createVolumeSeries, 
  processChartData, 
  updateChartSeries 
} from './series';
import { setupEventHandlers } from './events';

/**
 * Initialize the TradingView chart
 * @param {HTMLElement} container - The container element
 * @param {Array} chartData - The chart data
 * @param {string} themeName - Theme name ('dark' or 'light')
 * @param {string} symbol - Trading symbol
 * @param {string} timeframe - Chart timeframe
 * @returns {Object} - The chart instance and configuration
 */
export const initializeChart = (container, chartData, themeName, symbol, timeframe) => {
  const theme = themeName || 'dark';
  const activeTheme = themes[theme];
  const isCrypto = isCryptoSymbol(symbol);
  const samplePrice = chartData && chartData.length > 0 ? chartData[0].close : 0;

  // Set minimum container dimensions if needed
  if (container.clientWidth < 200 || container.clientHeight < 200) {
    container.style.width = '100%';
    container.style.height = '500px';
  }
  
  // Create chart with options
  const chartOptions = getChartOptions(
    activeTheme, 
    symbol, 
    timeframe, 
    container.clientWidth, 
    container.clientHeight, 
    isCrypto
  );
  const chart = createChart(container, chartOptions);
  
  // Create series
  const candleSeries = createCandlestickSeries(chart, activeTheme, isCrypto, samplePrice);
  
  // Process chart data
  const { data, hasVolume } = processChartData(chartData);
  
  // Create volume series if we have volume data
  let volumeSeries = null;
  if (hasVolume) {
    volumeSeries = createVolumeSeries(chart, activeTheme);
  }
  
  // Update series with data
  if (data.length > 0) {
    updateChartSeries(candleSeries, volumeSeries, data, activeTheme);
    chart.timeScale().fitContent();
  }
  
  // Force a resize after a short delay to ensure proper rendering
  setTimeout(() => {
    chart.applyOptions({
      width: container.clientWidth || 800,
      height: container.clientHeight || 600,
      rightPriceScale: {
        ...chart.options().rightPriceScale,
        // Ensure price formatting is consistent
        formatPrice: (price) => {
          return '$' + price.toFixed(2);
        }
      }
    });
    chart.timeScale().fitContent();
  }, 300);
  
  return { chart, candleSeries, volumeSeries };
};

/**
 * Clean up chart resources
 * @param {Object} chart - The chart instance
 * @param {Function} resizeHandler - The resize event handler to remove
 */
export const destroyChart = (chart, resizeHandler) => {
  if (resizeHandler) {
    window.removeEventListener('resize', resizeHandler);
  }
  
  if (chart) {
    chart.remove();
  }
}; 