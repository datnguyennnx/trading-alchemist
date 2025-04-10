export const debounce = (fn, delay) => {
  let timeout;
  return (...args) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => fn(...args), delay);
  };
};


export const formatCryptoPrice = (price) => {
  // Always use 2 decimal places for consistency
  return '$' + price.toFixed(2);
};


export const getCryptoPricePrecision = (price) => {
  // Always use 2 decimal places for consistency
  return 2;
};


export const getCryptoMinMove = (price) => {
  // Always use 0.01 for consistent 2 decimal place movement
  return 0.01;
};


export const isCryptoSymbol = (symbol) => {
  if (!symbol) return false;
  return symbol.includes('BTC') || 
         symbol.includes('ETH') || 
         symbol.includes('USDT') || 
         symbol.endsWith('USD');
};

export const formatTimestamps = (data) => {
  return data.map(item => {
    const newItem = { ...item };
    if (typeof newItem.time === 'number' && newItem.time > 1000000000000) {
      newItem.time = Math.floor(newItem.time / 1000);
    }
    return newItem;
  });
};

export const validateChartData = (chartData) => {
  if (!Array.isArray(chartData) || chartData.length === 0) {
    return false;
  }

  const sample = chartData[0];
  
  // Check required fields
  const requiredFields = ['time', 'open', 'high', 'low', 'close'];
  const missingFields = requiredFields.filter(field => sample[field] === undefined);
  
  if (missingFields.length > 0) {
    return false;
  }
  
  // Check types
  if (typeof sample.time !== 'number') {
    return false;
  }
  
  const numericFields = ['open', 'high', 'low', 'close'];
  for (const field of numericFields) {
    if (typeof sample[field] !== 'number') {
      return false;
    }
  }
  
  return true;
};

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