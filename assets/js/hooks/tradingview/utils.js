/**
 * Utility functions for TradingView chart implementation
 */

/**
 * Debounce function to limit how often a function is called
 * @param {Function} fn - The function to debounce
 * @param {number} delay - Delay in milliseconds
 * @returns {Function} - Debounced function
 */
export const debounce = (fn, delay) => {
  let timeout;
  return (...args) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => fn(...args), delay);
  };
};

/**
 * Format price based on cryptocurrency rules with consistent 2 decimal places
 * @param {number} price - The price to format
 * @returns {string} - Formatted price string
 */
export const formatCryptoPrice = (price) => {
  // Always use 2 decimal places for consistency
  return '$' + price.toFixed(2);
};

/**
 * Determine precision for cryptocurrency price formatting
 * @param {number} price - Sample price to base precision on
 * @returns {number} - Precision (number of decimal places)
 */
export const getCryptoPricePrecision = (price) => {
  // Always use 2 decimal places for consistency
  return 2;
};

/**
 * Get minimum price movement for cryptocurrency
 * @param {number} price - Sample price to base precision on
 * @returns {number} - Minimum price movement value
 */
export const getCryptoMinMove = (price) => {
  // Always use 0.01 for consistent 2 decimal place movement
  return 0.01;
};

/**
 * Check if a symbol is likely a cryptocurrency
 * @param {string} symbol - The trading symbol
 * @returns {boolean} - True if likely crypto
 */
export const isCryptoSymbol = (symbol) => {
  if (!symbol) return false;
  return symbol.includes('BTC') || 
         symbol.includes('ETH') || 
         symbol.includes('USDT') || 
         symbol.endsWith('USD');
};

/**
 * Transform millisecond timestamps to seconds if needed
 * @param {Array} data - Chart data array
 * @returns {Array} - Data with corrected timestamps
 */
export const formatTimestamps = (data) => {
  return data.map(item => {
    const newItem = { ...item };
    if (typeof newItem.time === 'number' && newItem.time > 1000000000000) {
      newItem.time = Math.floor(newItem.time / 1000);
    }
    return newItem;
  });
};

/**
 * Validates the format of chart data
 * @param {Array} chartData - The chart data to validate
 * @returns {boolean} - True if data is valid
 */
export const validateChartData = (chartData) => {
  if (!Array.isArray(chartData) || chartData.length === 0) {
    console.error("Chart data is not valid or empty");
    return false;
  }

  const sample = chartData[0];
  
  // Check required fields
  const requiredFields = ['time', 'open', 'high', 'low', 'close'];
  const missingFields = requiredFields.filter(field => sample[field] === undefined);
  
  if (missingFields.length > 0) {
    console.error(`Data missing required fields: ${missingFields.join(', ')}`);
    return false;
  }
  
  // Check types
  if (typeof sample.time !== 'number') {
    console.error(`Invalid time format, expected number but got ${typeof sample.time}`);
    return false;
  }
  
  const numericFields = ['open', 'high', 'low', 'close'];
  for (const field of numericFields) {
    if (typeof sample[field] !== 'number') {
      console.error(`Invalid ${field} format, expected number but got ${typeof sample[field]}`);
      return false;
    }
  }
  
  return true;
};

/**
 * Fix invalid chart data by converting strings to numbers
 * @param {Array} chartData - The chart data to fix
 * @returns {Array} - Fixed chart data
 */
export const fixChartData = (chartData) => {
  return chartData.map(item => ({
    time: typeof item.time === 'number' ? item.time : parseInt(item.time) || Math.floor(Date.now() / 1000),
    open: typeof item.open === 'number' ? item.open : parseFloat(item.open) || 0,
    high: typeof item.high === 'number' ? item.high : parseFloat(item.high) || 0,
    low: typeof item.low === 'number' ? item.low : parseFloat(item.low) || 0,
    close: typeof item.close === 'number' ? item.close : parseFloat(item.close) || 0,
    volume: typeof item.volume === 'number' ? item.volume : parseFloat(item.volume) || 0
  }));
}; 