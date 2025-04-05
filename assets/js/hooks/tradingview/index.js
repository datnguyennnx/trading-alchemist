/**
 * TradingView Chart LiveView Hook
 * 
 * This hook integrates the lightweight-charts library with Phoenix LiveView.
 * It manages chart rendering, data updates, theme changes, and responsive behavior.
 */

import { themes } from './themes';
import { initializeChart, destroyChart } from './chart';
import { setupEventHandlers } from './events';

/**
 * TradingView Chart Phoenix LiveView Hook
 */
const TradingViewChart = {
  mounted() {
    console.log("TradingView Chart hook mounted");
    
    try {
      // Clear any potential "Loading" overlay that might block the chart
      const loadingOverlays = this.el.querySelectorAll('.absolute');
      loadingOverlays.forEach(overlay => {
        overlay.style.display = 'none';
      });
      
      // Parse the chart data
      let chartData;
      try {
        chartData = JSON.parse(this.el.dataset.chartData);
        
        // For production, reduce logging
        if (process.env.NODE_ENV !== 'production') {
          console.log("Chart data parsed successfully, first item:", chartData[0]);
          console.log("Chart data length:", chartData.length);
          
          // Log debugging info
          if (this.el.dataset.debug) {
            console.log("Debug info:", JSON.parse(this.el.dataset.debug));
          }
        }
      } catch (e) {
        console.error("Error parsing chart data:", e);
        console.error("Raw chart data:", this.el.dataset.chartData);
        chartData = [];
      }
      
      // Get configuration from data attributes
      // Use localStorage or server theme to ensure consistency with global theme
      const globalTheme = localStorage.getItem('theme') || 
                        (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
      const theme = globalTheme || this.el.dataset.theme || 'dark';
      console.log("TradingView initializing with theme:", theme);
      
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
      
      // Initialize chart
      const { chart, candleSeries, volumeSeries } = initializeChart(
        container, 
        chartData,
        theme,
        symbol,
        timeframe
      );
      
      // Set up event handlers
      setupEventHandlers(this, chart, candleSeries, volumeSeries, themes, theme);
      
      // Set up global theme change listener
      this.themeChangeListener = (event) => {
        if (event.detail?.theme && themes[event.detail.theme]) {
          // Only update if theme is different from current
          if (event.detail.theme !== this.theme) {
            console.log("TradingView chart: Detected global theme change to", event.detail.theme);
            
            // Get the new theme
            const newTheme = themes[event.detail.theme];
            
            // Apply theme directly to chart
            chart.applyOptions({
              layout: {
                background: { 
                  type: 'solid', 
                  color: event.detail.theme === 'dark' ? 'rgb(13, 17, 23)' : 'rgb(249, 250, 251)' 
                },
                textColor: newTheme.textColor,
              },
              grid: {
                vertLines: newTheme.grid.vertLines,
                horzLines: newTheme.grid.horzLines,
              },
              timeScale: {
                borderColor: newTheme.borderColor,
                textColor: newTheme.textColor,
              },
              rightPriceScale: {
                borderColor: newTheme.borderColor,
                textColor: newTheme.textColor,
              },
              crosshair: {
                vertLine: {
                  color: newTheme.crosshairColor,
                  labelBackgroundColor: newTheme.crosshairColor,
                },
                horzLine: {
                  color: newTheme.crosshairColor,
                  labelBackgroundColor: newTheme.crosshairColor,
                },
              },
              watermark: {
                ...chart.options().watermark,
                color: newTheme.watermarkColor,
              }
            });
            
            // Apply theme to candlestick series
            candleSeries.applyOptions({
              upColor: newTheme.upColor,
              downColor: newTheme.downColor,
              wickUpColor: newTheme.upColor,
              wickDownColor: newTheme.downColor,
              priceLineColor: newTheme.borderColor,
            });
            
            // Update volume series if it exists
            if (volumeSeries) {
              // Re-color the volume bars based on candle direction
              const volumeData = volumeSeries.data().map(item => {
                const candle = candleSeries.data().find(c => c.time === item.time);
                return {
                  time: item.time,
                  value: item.value,
                  color: candle && candle.close >= candle.open ? 
                    newTheme.volumeColor : newTheme.volumeDownColor,
                };
              });
              
              volumeSeries.setData(volumeData);
            }
            
            // Update theme tracking
            this.theme = event.detail.theme;
            
            // Update data attribute for consistency
            this.el.dataset.theme = event.detail.theme;
            
            console.log("TradingView chart: Theme updated to", event.detail.theme);
          }
        }
      };
      
      // Add listener for global theme changes
      window.addEventListener('set-theme', this.themeChangeListener);
      
      // Also listen for the theme-updated event (backup method)
      this.themeUpdatedListener = (event) => {
        if (event.detail?.theme && themes[event.detail.theme]) {
          console.log("TradingView chart: Detected theme-updated event:", event.detail.theme);
          if (event.detail.theme !== this.theme) {
            // Use the same implementation as themeChangeListener
            this.themeChangeListener({ detail: { theme: event.detail.theme } });
          }
        }
      };
      document.addEventListener('theme-updated', this.themeUpdatedListener);
      
    } catch (error) {
      console.error("Error initializing TradingView chart:", error);
    }
  },
  
  destroyed() {
    // Remove global theme change listener
    if (this.themeChangeListener) {
      window.removeEventListener('set-theme', this.themeChangeListener);
    }
    if (this.themeUpdatedListener) {
      document.removeEventListener('theme-updated', this.themeUpdatedListener);
    }
    
    destroyChart(this.chart, this.resizeHandler);
  }
};

export default TradingViewChart; 