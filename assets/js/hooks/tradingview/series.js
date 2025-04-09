import { CandlestickSeries, HistogramSeries } from 'lightweight-charts';
import { getCandlestickOptions, getVolumeOptions } from './themes';
import { validateChartData, fixChartData, formatTimestamps } from './utils';

export const createCandlestickSeries = (chart, activeTheme, isCrypto, price) => {
  const options = getCandlestickOptions(activeTheme, isCrypto, price);
  return chart.addSeries(CandlestickSeries, options);
};


export const createVolumeSeries = (chart, activeTheme) => {
  const options = getVolumeOptions(activeTheme);
  return chart.addSeries(HistogramSeries, options);
};

export const prepareVolumeData = (formattedData, activeTheme) => {
  // For large datasets, optimize by reusing color objects
  const upColor = activeTheme.volumeColor;
  const downColor = activeTheme.volumeDownColor;
  
  // Preallocate array instead of building it incrementally
  const result = new Array(formattedData.length);
  
  for (let i = 0; i < formattedData.length; i++) {
    const item = formattedData[i];
    result[i] = {
      time: item.time,
      value: item.volume || 0,
      color: item.close >= item.open ? upColor : downColor
    };
  }
  
  return result;
};

export const processChartData = (chartData) => {
  if (!Array.isArray(chartData) || chartData.length === 0) {
    return { isValid: false, data: [], hasVolume: false };
  }
  
  // Sample first item to check format without validating entire array
  const firstItem = chartData[0];
  
  // Quick validation of required fields
  const hasRequiredFields = 
    firstItem.time !== undefined && 
    firstItem.open !== undefined && 
    firstItem.high !== undefined && 
    firstItem.low !== undefined && 
    firstItem.close !== undefined;
  
  // Check if data includes volume
  const hasVolume = firstItem.volume !== undefined;
  
  if (!hasRequiredFields) {
    // Only fix data if needed
    const fixedData = fixChartData(chartData);
    return { 
      isValid: true, 
      data: formatTimestamps(fixedData),
      hasVolume: hasVolume
    };
  }
  
  // If data is already valid, just ensure timestamps are in the correct format
  return { 
    isValid: true, 
    data: formatTimestamps(chartData),
    hasVolume: hasVolume
  };
};

export const updateChartSeries = (candleSeries, volumeSeries, chartData, activeTheme) => {
  if (!Array.isArray(chartData) || chartData.length === 0) {
    console.warn("No chart data to display");
    return;
  }
  
  // Skip full reprocessing for large datasets if possible
  if (chartData.length > 1000 && validateChartData([chartData[0]])) {
    // For very large datasets, just ensure timestamps are correct
    const formattedData = formatTimestamps(chartData);
    candleSeries.setData(formattedData);
    
    if (volumeSeries && chartData[0].volume !== undefined) {
      volumeSeries.setData(prepareVolumeData(formattedData, activeTheme));
    }
    return;
  }
  
  // For smaller datasets or invalid data, do full processing
  const { data, hasVolume } = processChartData(chartData);
  
  if (data.length === 0) {
    console.error("No valid data to display");
    return;
  }
  
  // Update candle data
  candleSeries.setData(data);
  
  // Update volume data if available
  if (volumeSeries && hasVolume) {
    const volumeData = prepareVolumeData(data, activeTheme);
    volumeSeries.setData(volumeData);
  }
}; 