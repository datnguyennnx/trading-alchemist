/**
 * Generate chart options based on theme
 * 
 * @param {Object} config - Chart configuration
 * @param {string} [config.theme='light'] - Chart theme ('dark' or 'light')
 * @param {string} config.symbol - Trading symbol
 * @param {string} config.timeframe - Chart timeframe
 * @returns {Object} Chart options
 */
export const generateChartOptions = (config) => {
  const { theme = 'light', symbol, timeframe } = config; // Default theme to 'light'
  
  return {
    layout: {
      background: { color: theme === 'dark' ? '#1e1e2d' : '#ffffff' },
      textColor: theme === 'dark' ? '#d1d4dc' : '#000000',
    },
    grid: {
      vertLines: { color: theme === 'dark' ? '#2e2e3e' : '#f0f3fa' },
      horzLines: { color: theme === 'dark' ? '#2e2e3e' : '#f0f3fa' },
    },
    timeScale: {
      timeVisible: true,
      secondsVisible: false,
      borderColor: theme === 'dark' ? '#2e2e3e' : '#f0f3fa',
    },
    crosshair: {
      mode: 0,
      vertLine: {
        width: 1,
        color: theme === 'dark' ? '#758696' : '#32325d',
        style: 1,
      },
      horzLine: {
        width: 1,
        color: theme === 'dark' ? '#758696' : '#32325d',
        style: 1,
      },
    },
    watermark: {
      visible: true,
      text: `${symbol} / ${timeframe}`,
      fontSize: 24,
      color: theme === 'dark' ? 'rgba(255, 255, 255, 0.2)' : 'rgba(0, 0, 0, 0.1)',
    },
  };
};
