/**
 * Event handlers for TradingView chart
 */

import { debounce } from './utils';
import { updateChartSeries } from './series';

/**
 * Set up all event handlers for the chart
 * @param {Object} hook - The LiveView hook
 * @param {Object} chart - The chart instance
 * @param {Object} candleSeries - The candlestick series
 * @param {Object} volumeSeries - The volume series (optional)
 * @param {Object} themes - Available themes
 * @param {string} currentTheme - Current theme name
 */
export const setupEventHandlers = (hook, chart, candleSeries, volumeSeries, themes, currentTheme) => {
  // Set up resize handler
  const resizeHandler = createResizeHandler(hook, chart);
  window.addEventListener('resize', resizeHandler);
  
  // Store references for later disposal
  hook.chart = chart;
  hook.series = candleSeries;
  hook.volumeSeries = volumeSeries;
  hook.resizeHandler = resizeHandler;
  hook.theme = currentTheme;
  
  // Set up LiveView event handlers
  setupChartDataHandler(hook, chart, candleSeries, volumeSeries, themes);
  setupThemeUpdateHandler(hook, chart, candleSeries, volumeSeries, themes);
  setupRangeChangeHandler(hook, candleSeries, volumeSeries);
};

/**
 * Create a debounced resize handler
 * @param {Object} hook - The LiveView hook
 * @param {Object} chart - The chart instance
 * @returns {Function} - Debounced resize handler
 */
const createResizeHandler = (hook, chart) => {
  return debounce(() => {
    const container = hook.el;
    chart.applyOptions({
      width: container.clientWidth || 800,
      height: container.clientHeight || 600,
      timeScale: {
        ...chart.options().timeScale,
        visible: true,
        borderVisible: true,
        ticksVisible: true,
      },
      rightPriceScale: {
        ...chart.options().rightPriceScale,
        visible: true,
        borderVisible: true,
        ticksVisible: true,
      }
    });
    // Re-fit content after resize for better UX
    chart.timeScale().fitContent();
  }, 100); // 100ms debounce
};

/**
 * Set up handler for chart data updates
 * @param {Object} hook - The LiveView hook
 * @param {Object} chart - The chart instance
 * @param {Object} candleSeries - The candlestick series
 * @param {Object} volumeSeries - The volume series (optional)
 * @param {Object} themes - Available themes
 */
const setupChartDataHandler = (hook, chart, candleSeries, volumeSeries, themes) => {
  hook.handleEvent("chart-data-updated", ({ data, symbol, timeframe }) => {
    if (!data || !Array.isArray(data) || data.length === 0) {
      console.error("Received invalid data update");
      return;
    }
    
    try {
      // Hide any loading overlays
      const loadingElements = hook.el.querySelectorAll('.absolute');
      loadingElements.forEach(el => {
        el.style.display = 'none';
      });
      
      // Update chart data
      const activeTheme = themes[hook.theme];
      updateChartSeries(candleSeries, volumeSeries, data, activeTheme);
      
      // Update watermark if symbol changed
      if (symbol && symbol !== hook.el.dataset.symbol) {
        hook.el.dataset.symbol = symbol;
        chart.applyOptions({
          watermark: {
            ...chart.options().watermark,
            visible: true,
            text: symbol,
          }
        });
      }
      
      // Update the timeframe if it changed
      if (timeframe && timeframe !== hook.el.dataset.timeframe) {
        hook.el.dataset.timeframe = timeframe;
        // Adjust time scale formatting based on timeframe
        chart.applyOptions({
          timeScale: {
            ...chart.options().timeScale,
            timeFormat: timeframe.includes('d') ? 'yyyy-MM-dd' : 
                        timeframe.includes('h') ? 'yyyy-MM-dd HH:mm' : 
                        'MM-dd HH:mm',
          }
        });
      }
      
      // Fit content with slight animation for smoother UX
      chart.timeScale().fitContent();
      
    } catch (error) {
      console.error("Error updating chart data:", error);
    }
  });
};

/**
 * Set up handler for theme updates
 * @param {Object} hook - The LiveView hook
 * @param {Object} chart - The chart instance
 * @param {Object} candleSeries - The candlestick series
 * @param {Object} volumeSeries - The volume series (optional)
 * @param {Object} themes - Available themes
 */
const setupThemeUpdateHandler = (hook, chart, candleSeries, volumeSeries, themes) => {
  hook.handleEvent("chart-theme-updated", ({ theme }) => {
    console.log("Chart received theme-updated event:", theme);
    
    if (themes[theme]) {
      console.log("Applying theme:", theme);
      const newTheme = themes[theme];
      
      chart.applyOptions({
        layout: {
          background: { 
            type: 'solid', 
            color: theme === 'dark' ? 'rgb(13, 17, 23)' : 'rgb(249, 250, 251)' 
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
          borderVisible: true,
          ticksVisible: true,
          visible: true
        },
        rightPriceScale: {
          borderColor: newTheme.borderColor,
          textColor: newTheme.textColor,
          borderVisible: true,
          ticksVisible: true,
          visible: true
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
      
      candleSeries.applyOptions({
        upColor: newTheme.upColor,
        downColor: newTheme.downColor,
        wickUpColor: newTheme.upColor,
        wickDownColor: newTheme.downColor,
        priceLineColor: newTheme.borderColor,
      });
      
      // Update volume series colors if it exists
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
      
      // Store theme on hook for reference
      hook.theme = theme;
      
      // If this update was triggered from a local chart theme change (not global),
      // notify the LiveView about the theme change
      if (hook.el.dataset.connected === "true" && hook.el.dataset.theme !== theme) {
        try {
          hook.pushEvent("chart-theme-changed", { theme });
        } catch (error) {
          console.error("Failed to push chart theme change event:", error);
        }
      }
      
      // Update data attribute
      hook.el.dataset.theme = theme;
      
      console.log("Chart theme updated successfully to:", theme);
    } else {
      console.error("Invalid theme specified:", theme, "Available themes:", Object.keys(themes));
    }
  });
};

/**
 * Set up handler for visible range changes
 * @param {Object} hook - The LiveView hook
 * @param {Object} candleSeries - The candlestick series
 * @param {Object} volumeSeries - The volume series (optional) 
 */
const setupRangeChangeHandler = (hook, candleSeries, volumeSeries) => {
  hook.chart.timeScale().subscribeVisibleLogicalRangeChange(() => {
    // This could be used for dynamic data loading or other optimizations
    // For now, we'll just use it to ensure volume series is properly colored
    
    if (volumeSeries && candleSeries) {
      const visibleData = candleSeries.data();
      if (visibleData.length === 0) return;
      
      // This would be the place to dynamically update volume colors
      // if we were implementing more advanced features
    }
  });
}; 