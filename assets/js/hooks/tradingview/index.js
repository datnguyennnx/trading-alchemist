import { themes } from './themes';
import { initializeChart, destroyChart } from './chart';
import { setupEventHandlers } from './events';

const chartDataCache = new WeakMap();

const TradingViewChart = {
  mounted() {
    try {
      // Clear any potential "Loading" overlay
      const loadingElements = this.el.querySelectorAll('.absolute');
      loadingElements.forEach(overlay => {
        overlay.style.display = 'none';
      });
      
      // Parse the chart data - with caching for performance
      let chartData;
      if (chartDataCache.has(this.el)) {
        // Use cached data if available
        chartData = chartDataCache.get(this.el);
      } else {
        try {
          chartData = JSON.parse(this.el.dataset.chartData);
          // Cache the parsed data for future use
          chartDataCache.set(this.el, chartData);
        } catch (e) {
          chartData = [];
        }
      }
      
      // Get configuration from data attributes
      // Use localStorage or server theme to ensure consistency with global theme
      const globalTheme = localStorage.getItem('theme') || 
                        (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
      const theme = globalTheme || this.el.dataset.theme || 'dark';
      
      const symbol = this.el.dataset.symbol || '';
      const timeframe = this.el.dataset.timeframe || '';
      
      // Create chart container
      const container = this.el;
      
      // Clear the container first to avoid overlapping charts
      while (container.firstChild) {
        if (container.firstChild.className && container.firstChild.className.includes('absolute')) {
          // Keep loading overlays but hide them
          container.firstChild.style.display = 'none';
          container.firstChild = container.firstChild.nextSibling;
        } else {
          container.removeChild(container.firstChild);
        }
      }
      
      // Initialize chart with performance optimizations
      const { chart, candleSeries, volumeSeries } = initializeChart(
        container, 
        chartData,
        theme,
        symbol,
        timeframe
      );
      
      // Set up event handlers with optimized event delegation
      setupEventHandlers(this, chart, candleSeries, volumeSeries, themes, theme);
      
      // Set up global theme change listener - using passive events for better performance
      this.themeChangeListener = (event) => {
        if (event.detail?.theme && themes[event.detail.theme]) {
          // Only update if theme is different from current
          if (event.detail.theme !== this.theme) {
            // Push event to server to update theme
            this.pushEvent("chart-theme-updated", { theme: event.detail.theme });
            
            // Update theme tracking
            this.theme = event.detail.theme;
            
            // Update data attribute for consistency
            this.el.dataset.theme = event.detail.theme;
          }
        }
      };
      
      // Add event listeners with passive option for better performance
      window.addEventListener('set-theme', this.themeChangeListener, { passive: true });
      document.addEventListener('theme-updated', this.themeChangeListener, { passive: true });
      
      // Set a flag to indicate the chart is mounted (for LiveView updates)
      this.el.dataset.connected = "true";
      
    } catch (error) {
    }
  },
  
  updated() {
    // Optimize updates to avoid unnecessary re-renders
    const newChartData = this.el.dataset.chartData;
    const newSymbol = this.el.dataset.symbol;
    const newTimeframe = this.el.dataset.timeframe;
    
    // Only process update if data has actually changed
    if (this._lastChartData !== newChartData || 
        this._lastSymbol !== newSymbol || 
        this._lastTimeframe !== newTimeframe) {
      
      // Store current values for future comparison
      this._lastChartData = newChartData;
      this._lastSymbol = newSymbol;
      this._lastTimeframe = newTimeframe;
      
      // Clear data cache when inputs change
      chartDataCache.delete(this.el);
    }
  },
  
  disconnected() {
    // Clear the cache when the element is disconnected
    chartDataCache.delete(this.el);
  },
  
  destroyed() {
    // Clean up resources to prevent memory leaks
    chartDataCache.delete(this.el);
    
    // Remove global theme change listeners
    if (this.themeChangeListener) {
      window.removeEventListener('set-theme', this.themeChangeListener);
      document.removeEventListener('theme-updated', this.themeChangeListener);
    }
    
    destroyChart(this.chart, this.resizeHandler);
  }
};

export default TradingViewChart; 