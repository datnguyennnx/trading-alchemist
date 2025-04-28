/**
 * Candlestick series configuration and utilities
 */

import { CandlestickSeries } from 'lightweight-charts';

/**
 * Get candlestick series options
 * 
 * @param {Object} config - Optional configuration overrides
 * @returns {Object} Candlestick series options
 */
export const getCandlestickOptions = (config = {}) => {
  return {
    upColor: config.upColor || '#26a69a',        // Green for up bars
    downColor: config.downColor || '#ef5350',    // Red for down bars
    borderVisible: config.borderVisible || false,
    wickUpColor: config.wickUpColor || '#26a69a',
    wickDownColor: config.wickDownColor || '#ef5350',
    ...config
  };
};

/**
 * Initializes a candlestick series on the chart
 * 
 * @param {IChartApi} chart - The chart instance
 * @param {Object} options - Optional series configuration
 * @returns {ISeriesApi<"Candlestick">} - The candlestick series
 */
export const initCandlestickSeries = (chart, options = {}) => {
  const series = chart.addSeries(CandlestickSeries);
  series.applyOptions(getCandlestickOptions(options));
  return series;
}; 