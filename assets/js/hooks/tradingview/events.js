import { debounce } from './utils';
import { updateChartSeries } from './series';

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
  
  // Reference to range change handler for reset functionality
  const rangeHandlerContext = {};
  setupRangeChangeHandler(hook, candleSeries, volumeSeries, rangeHandlerContext);
  
  // Store reference to reset function for external access
  hook.resetHistoryTracking = () => {
    if (rangeHandlerContext.resetLastFetchTimestamp) {
      rangeHandlerContext.resetLastFetchTimestamp();
    }
  };
};

const createResizeHandler = (hook, chart) => {
  return debounce(() => {
    const container = hook.el;
    chart.applyOptions({
      width: container.clientWidth || 800,
      height: container.clientHeight || 600,
      timeScale: {
        ...chart.options().timeScale,
      },
      rightPriceScale: {
        ...chart.options().rightPriceScale,
      }
    });
    // Re-fit content after resize for better UX
    chart.timeScale().fitContent();
  }, 100); // 100ms debounce
};

const setupChartDataHandler = (hook, chart, candleSeries, volumeSeries, themes) => {
  hook.handleEvent("chart-data-updated", ({ data, symbol, timeframe, append }) => {
    try {
      if (!data || !Array.isArray(data) || data.length === 0) {
        console.error("Received invalid data update");
        return;
      }
      
      // Hide any loading overlays
      const loadingElements = hook.el.querySelectorAll('.absolute');
      loadingElements.forEach(el => {
        el.style.display = 'none';
      });
      
      // Update chart data
      const activeTheme = themes[hook.theme];
      
      if (append) {
        // Get the existing data
        const existingData = candleSeries.data();
        
        // Optimization: Assuming server sends historical data sorted and older than existing.
        // Combine without sorting the full array.
        // Ensure the new data itself is sorted if needed (though server likely handles this).
        // Remove duplicates more efficiently, assuming 'data' contains older candles.
        const combinedData = [...data, ...existingData]; // Prepend new (older) data
        
        const uniqueData = [];
        const timeSet = new Set();
        
        // Iterate through combined data (new first) and add unique timestamps
        for (const candle of combinedData) {
          if (!timeSet.has(candle.time)) {
            timeSet.add(candle.time);
            uniqueData.push(candle);
          }
        }
        
        console.log(`Combined data: existing=${existingData.length}, new=${data.length}, unique=${uniqueData.length}`);
        
        // Update the series with combined unique data
        updateChartSeries(candleSeries, volumeSeries, uniqueData, activeTheme);
      } else {
        // Replace existing data
        updateChartSeries(candleSeries, volumeSeries, data, activeTheme);
        
        // Reset history tracking when chart data is replaced (not appended)
        // This happens when symbol or timeframe changes
        if (hook.resetHistoryTracking) {
          // Check if timeframe has changed
          if (timeframe && timeframe !== hook.el.dataset.prevTimeframe) {
            console.log("Timeframe changed, resetting history tracking");
            hook.resetHistoryTracking();
            hook.el.dataset.prevTimeframe = timeframe;
          }
        }
      }
      
      // Update the timeframe if it changed
      if (timeframe && timeframe !== hook.el.dataset.timeframe) {
        // Store previous timeframe before updating
        hook.el.dataset.prevTimeframe = hook.el.dataset.timeframe || timeframe;
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
      console.error("Error in chart-data-updated handler:", error);
    }
  });
};

const setupThemeUpdateHandler = (hook, chart, candleSeries, volumeSeries, themes) => {
  hook.handleEvent("chart-theme-updated", ({ theme }) => {
    try {
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
          },
          rightPriceScale: {
            borderColor: newTheme.borderColor,
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
          // Optimization: Create a Map for faster candle lookup
          const candleDataMap = new Map(candleSeries.data().map(c => [c.time, c]));
          
          const volumeData = volumeSeries.data().map(item => {
            const candle = candleDataMap.get(item.time); // O(1) average lookup
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
    } catch (error) {
      console.error("Error in chart-theme-updated handler:", error);
    }
  });
};

const setupRangeChangeHandler = (hook, candleSeries, volumeSeries, rangeHandlerContext) => {
  let isFetching = false;
  let lastFetchTimestamp = null;
  const fetchThreshold = 50; // When fewer than this many bars are visible before the start, load more
  const fetchCooldown = 500; // Further reduced cooldown for better responsiveness (ms)
  let lastFetchTime = Date.now() - fetchCooldown; // Initialize to allow immediate first fetch
  let hasMoreData = true; // Track if we have more data to load
  let batchSize = 200; // Default batch size
  
  // Track loading state to show/hide loading indicator
  const setLoading = (isLoading) => {
    // Remove any existing loading indicators first
    const existingIndicators = hook.el.querySelectorAll('.history-loading-indicator');
    existingIndicators.forEach(el => el.remove());
    
    if (isLoading) {
      const loadingEl = document.createElement('div');
      loadingEl.className = 'absolute bottom-2 left-2 bg-black bg-opacity-70 text-white text-xs rounded px-2 py-1 flex items-center history-loading-indicator z-10';
      loadingEl.innerHTML = '<div class="animate-spin rounded-full h-3 w-3 border-b-2 border-white mr-2"></div> Loading historical data...';
      hook.el.appendChild(loadingEl);
    }
  };
  
  hook.chart.timeScale().subscribeVisibleLogicalRangeChange(async (range) => {
    if (!range || isFetching || !hasMoreData) return;
    
    const now = Date.now();
    if (now - lastFetchTime < fetchCooldown) return; // Apply cooldown
    
    const barsInfo = candleSeries.barsInLogicalRange(range);
    if (!barsInfo || barsInfo.barsBefore === undefined) return;
    
    // If we're near the beginning of the data, fetch historical data
    if (barsInfo.barsBefore < fetchThreshold) {
      isFetching = true;
      lastFetchTime = now;
      
      try {
        // Get all current data to find the earliest point
        const allData = candleSeries.data();
        if (!allData || allData.length === 0) {
          isFetching = false;
          return;
        }
        
        // Use a faster way to find the earliest candle (optimization)
        // This is faster than sorting the entire array
        let earliestCandle = allData[0];
        for (let i = 1; i < allData.length; i++) {
          if (allData[i].time < earliestCandle.time) {
            earliestCandle = allData[i];
          }
        }

        // Convert the UTC timestamp to a Date object
        const earliestTime = new Date(earliestCandle.time * 1000);
        
        // Allow fetching if we're looking at earlier data than before
        if (lastFetchTimestamp && earliestCandle.time >= lastFetchTimestamp) {
          console.log("Skipping fetch - need to scroll further left to load more data");
          isFetching = false;
          return;
        }
        
        // Record this fetch timestamp - this is now the earliest point we've fetched
        lastFetchTimestamp = earliestCandle.time;
        
        // Show loading indicator
        setLoading(true);
        
        console.log(`Fetching historical data before ${earliestTime.toISOString()}`);
        
        // Request historical data from LiveView
        const response = await hook.pushEvent("load-historical-data", {
          timestamp: earliestCandle.time,
          symbol: hook.el.dataset.symbol,
          timeframe: hook.el.dataset.timeframe,
          batchSize: batchSize // Allow server to adjust batch size
        });
        
        console.log("Response from load-historical-data:", response);
        
        // Check if we have a valid response before using it
        if (response && response.has_more !== undefined) {
          hasMoreData = response.has_more;
          console.log(`Historical data load complete, has more: ${hasMoreData}`);
          
          // Dynamically adjust batch size based on response time and data volume
          if (response.batchSize) {
            batchSize = response.batchSize;
          } else if (hasMoreData) {
            // If loading was fast (< 300ms), increase batch size for next time
            const fetchDuration = Date.now() - lastFetchTime;
            if (fetchDuration < 300 && batchSize < 500) {
              batchSize = Math.min(500, batchSize * 1.5);
              console.log(`Increased batch size to ${batchSize} (fetch took ${fetchDuration}ms)`);
            } else if (fetchDuration > 800 && batchSize > 50) {
              // If loading was slow, decrease batch size
              batchSize = Math.max(50, batchSize * 0.7);
              console.log(`Decreased batch size to ${batchSize} (fetch took ${fetchDuration}ms)`);
            }
          }
        } else {
          console.warn("Invalid response from load-historical-data event", response);
          // Default to true so we can try again
          hasMoreData = true;
        }
        
        // Remove loading indicator
        setLoading(false);
      } catch (error) {
        console.error("Error fetching historical data:", error);
        // Keep hasMoreData true to allow retries after errors
        hasMoreData = true;
        setLoading(false);
      } finally {
        // Release the fetch lock with shorter delay
        setTimeout(() => {
          isFetching = false;
        }, 100);
      }
    }
  });
  
  // Store reference to reset function for external access
  rangeHandlerContext.resetLastFetchTimestamp = () => {
    console.log("Resetting history tracking state");
    lastFetchTimestamp = null;
    hasMoreData = true; // Reset this flag too to ensure we can load data
    batchSize = 200; // Reset batch size to default
  };
}; 