import { createChart, CandlestickSeries } from 'lightweight-charts';

const TradingViewChart = {
    mounted() {
        console.log("TradingView Chart hook mounted");
        
        try {
          // Ensure the library is properly loaded
          if (typeof createChart !== 'function') {
            console.error("createChart is not a function. Library may not be loaded properly.");
            return;
          }
    
          // Parse the chart data
          let chartData;
          try {
            chartData = JSON.parse(this.el.dataset.chartData);
            console.log("Chart data parsed successfully:", chartData);
          } catch (e) {
            console.error("Error parsing chart data:", e);
            chartData = [];
          }
          
          // Get theme from data attribute or default to dark
          const theme = this.el.dataset.theme || 'dark';
          
          // Create chart container
          const container = this.el;
          
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
          
          // Initialize the chart
          const chart = createChart(container, {
            width: container.clientWidth,
            height: container.clientHeight,
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
          
          candleSeries.setData(formattedData);
          
          // Fit the content initially
          chart.timeScale().fitContent();
          
          // Make responsive
          const resizeHandler = () => {
            chart.applyOptions({
              width: container.clientWidth,
              height: container.clientHeight,
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
            console.log("Received new data:", data);
            if (Array.isArray(data)) {
              // Format timestamps for incoming data as well
              const formattedUpdateData = data.map(item => {
                const newItem = { ...item };
                if (typeof newItem.time === 'number' && newItem.time > 1000000000000) {
                  newItem.time = Math.floor(newItem.time / 1000);
                }
                return newItem;
              });
              
              this.series.setData(formattedUpdateData);
              chart.timeScale().fitContent();
            } else {
              // Format single update
              const updateItem = { ...data };
              if (typeof updateItem.time === 'number' && updateItem.time > 1000000000000) {
                updateItem.time = Math.floor(updateItem.time / 1000);
              }
              this.series.update(updateItem);
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
          
          console.log("TradingView Chart initialization completed");
        } catch (error) {
          console.error("Error initializing TradingView chart:", error);
        }
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