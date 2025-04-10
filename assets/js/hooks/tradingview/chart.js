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
  
  return { chart, candleSeries, volumeSeries };
};


export const destroyChart = (chart, resizeHandler) => {
  if (resizeHandler) {
    window.removeEventListener('resize', resizeHandler);
  }
  
  if (chart) {
    chart.remove();
  }
}; 