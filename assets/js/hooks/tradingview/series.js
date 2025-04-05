/**
 * Chart series management for TradingView
 */

import { CandlestickSeries, HistogramSeries } from 'lightweight-charts';
import { getCandlestickOptions, getVolumeOptions } from './themes';
import { validateChartData, fixChartData, formatTimestamps } from './utils';

/**
 * Creates and configures a candlestick series
 * @param {Object} chart - The chart instance
 * @param {Object} activeTheme - Active theme settings
 * @param {boolean} isCrypto - Whether the symbol is a cryptocurrency
 * @param {number} price - Sample price for precision calculation
 * @returns {Object} - The candlestick series
 */
export const createCandlestickSeries = (chart, activeTheme, isCrypto, price) => {
  const options = getCandlestickOptions(activeTheme, isCrypto, price);
  return chart.addSeries(CandlestickSeries, options);
};

/**
 * Creates and configures a volume series
 * @param {Object} chart - The chart instance
 * @param {Object} activeTheme - Active theme settings
 * @returns {Object} - The volume series
 */
export const createVolumeSeries = (chart, activeTheme) => {
  const options = getVolumeOptions(activeTheme);
  return chart.addSeries(HistogramSeries, options);
};

/**
 * Prepare volume data with appropriate coloring
 * @param {Array} formattedData - Candle data array 
 * @param {Object} activeTheme - Active theme settings
 * @returns {Array} - Formatted volume data
 */
export const prepareVolumeData = (formattedData, activeTheme) => {
  return formattedData.map(item => ({
    time: item.time,
    value: item.volume || 0,
    color: item.close >= item.open ? activeTheme.volumeColor : activeTheme.volumeDownColor,
  }));
};

/**
 * Process and validate chart data for display
 * @param {Array} chartData - Raw chart data
 * @returns {Object} - Processed data and validation status
 */
export const processChartData = (chartData) => {
  if (!Array.isArray(chartData) || chartData.length === 0) {
    return { isValid: false, data: [] };
  }
  
  // Validate data format
  const isValid = validateChartData(chartData);
  let processedData = chartData;
  
  // Fix data if needed
  if (!isValid) {
    processedData = fixChartData(chartData);
  }
  
  // Ensure timestamps are in the correct format
  const formattedData = formatTimestamps(processedData);
  
  return { 
    isValid: true, 
    data: formattedData,
    hasVolume: formattedData.length > 0 && 'volume' in formattedData[0]
  };
};

/**
 * Update chart series with new data
 * @param {Object} candleSeries - The candlestick series
 * @param {Object} volumeSeries - The volume series (optional)
 * @param {Array} chartData - The chart data
 * @param {Object} activeTheme - Active theme settings
 */
export const updateChartSeries = (candleSeries, volumeSeries, chartData, activeTheme) => {
  const { data, hasVolume } = processChartData(chartData);
  
  if (data.length === 0) {
    console.error("No valid data to display");
    return;
  }
  
  // Set candle data
  candleSeries.setData(data);
  
  // Update volume data if available
  if (volumeSeries && hasVolume) {
    const volumeData = prepareVolumeData(data, activeTheme);
    volumeSeries.setData(volumeData);
  }
}; 