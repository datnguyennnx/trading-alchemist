import { createChart, CandlestickSeries } from 'lightweight-charts';

const TradingViewChart = {
    mounted() {
        console.log("TradingView Chart hook mounted");
        
        try {
          // Clear any potential "Loading" overlay that might block the chart
          const loadingOverlays = this.el.querySelectorAll('.absolute');
          loadingOverlays.forEach(overlay => {
            overlay.style.display = 'none';
          });
          
          // Ensure the library is properly loaded
          if (typeof createChart !== 'function') {
            console.error("createChart is not a function. Library may not be loaded properly.");
            return;
          }
    
          // Parse the chart data
          let chartData;
          try {
            chartData = JSON.parse(this.el.dataset.chartData);
            console.log("Chart data parsed successfully, first item:", chartData[0]);
            console.log("Chart data length:", chartData.length);
            
            // Log debugging info
            if (this.el.dataset.debug) {
              console.log("Debug info:", JSON.parse(this.el.dataset.debug));
            }
            
          } catch (e) {
            console.error("Error parsing chart data:", e);
            console.error("Raw chart data:", this.el.dataset.chartData);
            chartData = [];
          }
          
          // Check chart data immediately
          if (!Array.isArray(chartData) || chartData.length === 0) {
            console.error("Chart data is not valid or empty. Cannot display chart.");
            console.error("Raw dataset:", this.el.dataset.chartData);
            console.error("Parsed data:", chartData);
            // Don't return yet - we'll set up the chart container anyway
          }
          
          // Get theme from data attribute or default to dark
          const theme = this.el.dataset.theme || 'dark';
          
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
          
          // Define themes
          const themes = {
            dark: {
              background: { type: 'solid', color: 'hsl(var(--card))' },
              textColor: 'hsl(var(--card-foreground))',
              grid: {
                vertLines: { color: 'rgba(255, 255, 255, 0.1)' },
                horzLines: { color: 'rgba(255, 255, 255, 0.1)' },
              },
              upColor: '#26a69a',
              downColor: '#ef5350',
              borderColor: 'hsl(var(--border))'
            },
            light: {
              background: { type: 'solid', color: 'hsl(var(--card))' },
              textColor: 'hsl(var(--card-foreground))',
              grid: {
                vertLines: { color: 'rgba(0, 0, 0, 0.1)' },
                horzLines: { color: 'rgba(0, 0, 0, 0.1)' },
              },
              upColor: '#4caf50',
              downColor: '#f44336',
              borderColor: 'hsl(var(--border))'
            }
          };
          
          const activeTheme = themes[theme];
          
          // Log container dimensions
          console.log("Chart container dimensions:", {
            width: container.clientWidth,
            height: container.clientHeight,
            offsetWidth: container.offsetWidth,
            offsetHeight: container.offsetHeight
          });
          
          // Check container size and give it minimum dimensions if needed
          if (container.clientWidth < 200 || container.clientHeight < 200) {
            container.style.width = '100%';
            container.style.height = '500px';
            console.log("Container resized to minimum dimensions");
          }
          
          // Initialize the chart
          const chart = createChart(container, {
            width: container.clientWidth || 800,
            height: container.clientHeight || 600,
            layout: {
              background: activeTheme.background,
              textColor: activeTheme.textColor,
            },
            grid: {
              vertLines: activeTheme.grid.vertLines,
              horzLines: activeTheme.grid.horzLines,
            },
            timeScale: {
              timeVisible: true,
              secondsVisible: false,
              borderColor: activeTheme.borderColor,
            },
            crosshair: {
              mode: 1,
              vertLine: {
                color: '#9B7DFF',
                width: 1,
                style: 1,
                labelBackgroundColor: '#9B7DFF',
              },
              horzLine: {
                color: '#9B7DFF',
                width: 1,
                style: 1,
                labelBackgroundColor: '#9B7DFF',
              },
            },
          });
          
          // Create a candlestick series using the Series Factory pattern for v5+
          console.log("Adding candlestick series");
          const candleSeries = chart.addSeries(CandlestickSeries, {
            upColor: activeTheme.upColor,
            downColor: activeTheme.downColor,
            borderVisible: false,
            wickUpColor: activeTheme.upColor,
            wickDownColor: activeTheme.downColor,
          });
          
          // Set the data
          console.log("Setting chart data");
          
          // First validate that we have data in the expected format
          if (!Array.isArray(chartData) || chartData.length === 0) {
            console.error("Chart data is not valid or empty. Skipping chart data setting.");
            // Just set up the chart without data
            this.chart = chart;
            this.series = candleSeries;
            this.setupEventHandlers(chart, candleSeries, themes, theme);
            return;
          }
          
          // Validate data format
          const validateData = () => {
            // Check first item as sample
            const sample = chartData[0];
            console.log("Sample data structure:", sample);
            
            // Check required fields
            const requiredFields = ['time', 'open', 'high', 'low', 'close'];
            const missingFields = requiredFields.filter(field => sample[field] === undefined);
            
            if (missingFields.length > 0) {
              console.error(`Data missing required fields: ${missingFields.join(', ')}`);
              return false;
            }
            
            // Check types
            if (typeof sample.time !== 'number') {
              console.error(`Invalid time format, expected number but got ${typeof sample.time}:`, sample.time);
              return false;
            }
            
            const numericFields = ['open', 'high', 'low', 'close'];
            for (const field of numericFields) {
              if (typeof sample[field] !== 'number') {
                console.error(`Invalid ${field} format, expected number but got ${typeof sample[field]}:`, sample[field]);
                return false;
              }
            }
            
            return true;
          };
          
          // Check data validity
          const isValidData = validateData();
          console.log("Data validation result:", isValidData);
          
          if (!isValidData) {
            console.error("Chart data is not in the correct format. Attempting to fix...");
            // Try to fix data if needed
            chartData = chartData.map(item => ({
              time: typeof item.time === 'number' ? item.time : parseInt(item.time) || Math.floor(Date.now() / 1000),
              open: typeof item.open === 'number' ? item.open : parseFloat(item.open) || 0,
              high: typeof item.high === 'number' ? item.high : parseFloat(item.high) || 0,
              low: typeof item.low === 'number' ? item.low : parseFloat(item.low) || 0,
              close: typeof item.close === 'number' ? item.close : parseFloat(item.close) || 0,
              volume: typeof item.volume === 'number' ? item.volume : parseFloat(item.volume) || 0
            }));
            console.log("Fixed data:", chartData[0]);
          }
          
          // Ensure timestamps are in the correct format for v5
          // Convert millisecond timestamps to seconds if needed
          const formattedData = chartData.map(item => {
            // Clone the item to avoid modifying the original
            const newItem = { ...item };
            
            // If time is in milliseconds, convert to seconds
            if (typeof newItem.time === 'number' && newItem.time > 1000000000000) {
              newItem.time = Math.floor(newItem.time / 1000);
            }
            
            return newItem;
          });
          
          console.log(`Setting ${formattedData.length} candles on the chart`);
          if (formattedData.length > 0) {
            console.log("First candle:", formattedData[0]);
            console.log("Last candle:", formattedData[formattedData.length - 1]);
          }
          
          // Try-catch around setData to catch any errors
          try {
            candleSeries.setData(formattedData);
            console.log("Chart data set successfully");
            
            // Fit the content 
            chart.timeScale().fitContent();
            console.log("Chart content fitted");
            
            // Update loading state in the DOM
            const loadingElements = this.el.querySelectorAll('.absolute');
            loadingElements.forEach(el => {
              el.style.display = 'none';
            });
          } catch (error) {
            console.error("Error setting chart data:", error);
            console.error("Data that caused error:", formattedData);
          }
          
          // Set up event handlers and store references
          this.setupEventHandlers(chart, candleSeries, themes, theme);
          
          console.log("TradingView Chart initialization completed");
        } catch (error) {
          console.error("Error initializing TradingView chart:", error);
        }
      },
      
      setupEventHandlers(chart, candleSeries, themes, theme) {
        // Make responsive
        const resizeHandler = () => {
          const container = this.el;
          console.log("Resizing chart to:", container.clientWidth, "x", container.clientHeight);
          chart.applyOptions({
            width: container.clientWidth || 800,
            height: container.clientHeight || 600,
          });
        };
        
        window.addEventListener('resize', resizeHandler);
        
        // Store references for later use
        this.chart = chart;
        this.series = candleSeries;
        this.resizeHandler = resizeHandler;
        this.theme = theme;
        
        // Handle data updates
        this.handleEvent("chart-data-updated", ({ data }) => {
          console.log("Received new data update:", data ? data.length : 0, "candles");
          
          if (!data || !Array.isArray(data) || data.length === 0) {
            console.error("Received invalid data update:", data);
            return;
          }
          
          try {
            // Hide any loading overlays
            const loadingElements = this.el.querySelectorAll('.absolute');
            loadingElements.forEach(el => {
              el.style.display = 'none';
            });
            
            // Format timestamps for incoming data
            const formattedUpdateData = data.map(item => {
              const newItem = { ...item };
              if (typeof newItem.time === 'number' && newItem.time > 1000000000000) {
                newItem.time = Math.floor(newItem.time / 1000);
              }
              return newItem;
            });
            
            console.log("Setting updated data:", formattedUpdateData.length, "candles");
            this.series.setData(formattedUpdateData);
            chart.timeScale().fitContent();
            console.log("Chart updated successfully");
          } catch (error) {
            console.error("Error updating chart data:", error);
          }
        });
        
        // Handle theme updates
        this.handleEvent("chart-theme-updated", ({ theme }) => {
          console.log("Updating chart theme to:", theme);
          if (themes[theme]) {
            const newTheme = themes[theme];
            
            chart.applyOptions({
              layout: {
                background: newTheme.background,
                textColor: newTheme.textColor,
              },
              grid: {
                vertLines: newTheme.grid.vertLines,
                horzLines: newTheme.grid.horzLines,
              },
              timeScale: {
                borderColor: newTheme.borderColor
              }
            });
            
            candleSeries.applyOptions({
              upColor: newTheme.upColor,
              downColor: newTheme.downColor,
              wickUpColor: newTheme.upColor,
              wickDownColor: newTheme.downColor,
            });
            
            this.theme = theme;
          }
        });
      },
      
      destroyed() {
        console.log("TradingView Chart hook destroyed");
        if (this.resizeHandler) {
          window.removeEventListener('resize', this.resizeHandler);
        }
        
        if (this.chart) {
          this.chart.remove();
        }
      }
    };
    
export default TradingViewChart; 