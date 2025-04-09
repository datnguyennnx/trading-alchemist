export const themes = {
  dark: {
    background: { type: 'solid', color: 'hsl(var(--card))' },
    chartBackground: 'rgb(13, 17, 23)', 
    textColor: 'rgba(255, 255, 255, 0.9)',
    grid: {
      vertLines: { 
        color: 'rgba(255, 255, 255, 0.15)',
        visible: true,
        style: 0 // 0 = solid, 1 = dotted, 2 = dashed
      },
      horzLines: { 
        color: 'rgba(255, 255, 255, 0.15)',
        visible: true,
        style: 0
      },
    },
    upColor: '#22c55e', // Brighter green
    downColor: '#ef4444', // Brighter red
    borderColor: 'rgba(255, 255, 255, 0.3)',
    watermarkColor: 'rgba(255, 255, 255, 0.07)',
    crosshairColor: '#9B7DFF',
    volumeColor: 'rgba(150, 125, 255, 0.7)',
    volumeDownColor: 'rgba(239, 83, 80, 0.7)'
  },
  light: {
    background: { type: 'solid', color: 'hsl(var(--card))' },
    chartBackground: 'rgb(249, 250, 251)',
    textColor: 'rgba(0, 0, 0, 0.9)',
    grid: {
      vertLines: { 
        color: 'rgba(0, 0, 0, 0.15)',
        visible: true,
        style: 0
      },
      horzLines: { 
        color: 'rgba(0, 0, 0, 0.15)',
        visible: true,
        style: 0
      },
    },
    upColor: '#16a34a', // Darker green for better contrast
    downColor: '#dc2626', // Darker red for better contrast
    borderColor: 'rgba(0, 0, 0, 0.3)',
    watermarkColor: 'rgba(0, 0, 0, 0.07)',
    crosshairColor: '#7754E8',
    volumeColor: 'rgba(119, 84, 232, 0.7)',
    volumeDownColor: 'rgba(244, 67, 54, 0.7)'
  }
};


export const getChartOptions = (activeTheme, symbol, timeframe, clientWidth, clientHeight, isCrypto) => {
  return {
    width: clientWidth || 800,
    height: clientHeight || 600,
    layout: {
      background: { 
        type: 'solid', 
        color: activeTheme.chartBackground
      },
      textColor: activeTheme.textColor,
      fontFamily: 'Inter, system-ui, sans-serif',
      fontSize: 12,
    },
    grid: {
      vertLines: {
        color: activeTheme.grid.vertLines.color,
        visible: true,
        style: activeTheme.grid.vertLines.style,
      },
      horzLines: {
        color: activeTheme.grid.horzLines.color,
        visible: true,
        style: activeTheme.grid.horzLines.style,
      },
    },
    rightPriceScale: {
      borderColor: activeTheme.borderColor,
      visible: true,
      borderVisible: true,
      scaleMargins: {
        top: 0.1,
        bottom: 0.2, // Make room for volume
      },
      formatPrice: (price) => {
        return '$' + price.toFixed(2);
      },
      drawTicks: true,
      entireTextOnly: false,
      ticksVisible: true,
      textColor: activeTheme.textColor,
    },
    timeScale: {
      timeVisible: true,
      secondsVisible: false,
      borderVisible: true,
      borderColor: activeTheme.borderColor,
      timeFormat: timeframe && timeframe.includes('d') ? 'yyyy-MM-dd' : 
                 timeframe && (timeframe.includes('h') || timeframe.includes('4h')) ? 'yyyy-MM-dd HH:mm' : 
                 'MM-dd HH:mm',
      rightOffset: 5,
      fixLeftEdge: true,
      lockVisibleTimeRangeOnResize: true,
      rightBarStaysOnScroll: true,
      visible: true,
      ticksVisible: true,
      textColor: activeTheme.textColor,
      animate: true,
      tickMarkFormatter: (time, tickMarkType) => {
        const date = new Date(time * 1000);
        const hours = date.getHours().toString().padStart(2, '0');
        const minutes = date.getMinutes().toString().padStart(2, '0');
        const month = (date.getMonth() + 1).toString().padStart(2, '0');
        const day = date.getDate().toString().padStart(2, '0');
        
        if (tickMarkType === 3) { // Years
          return date.getFullYear().toString();
        } else if (tickMarkType === 2) { // Months
          return `${date.getFullYear()}-${month}`;
        } else if (tickMarkType === 1) { // Days
          return `${month}-${day}`;
        } 
        return `${hours}:${minutes}`;
      },
    },
    crosshair: {
      mode: 1, // 0 for normal, 1 for magnet
      vertLine: {
        color: activeTheme.crosshairColor,
        width: 1,
        style: 1, // 0 for solid, 1 for dotted, 2 for dashed
        labelBackgroundColor: activeTheme.crosshairColor,
        labelVisible: true,
      },
      horzLine: {
        color: activeTheme.crosshairColor,
        width: 1,
        style: 1, 
        labelBackgroundColor: activeTheme.crosshairColor,
        labelVisible: true,
      },
    },
    watermark: {
      visible: symbol ? true : false,
      text: symbol,
      color: activeTheme.watermarkColor,
      fontSize: 56,
      horzAlign: 'center',
      vertAlign: 'center',
    },
    handleScroll: { 
      mouseWheel: true, 
      pressedMouseMove: true, 
      horzTouchDrag: true, 
      vertTouchDrag: true 
    },
    handleScale: { 
      mouseWheel: true, 
      pinch: true, 
      axisPressedMouseMove: {
        time: true,
        price: true,
      }
    }
  };
};

export const getCandlestickOptions = (activeTheme, isCrypto, price) => {
  return {
    upColor: activeTheme.upColor,
    downColor: activeTheme.downColor,
    borderVisible: false,
    wickUpColor: activeTheme.upColor,
    wickDownColor: activeTheme.downColor,
    priceLineVisible: true,
    priceLineWidth: 1,
    priceLineColor: activeTheme.borderColor,
    priceLineStyle: 2, // 0 for solid, 1 for dotted, 2 for dashed
    lastValueVisible: true,
    priceFormat: {
      type: 'price',
      precision: 2, // Always use 2 decimal places
      minMove: 0.01, // Consistent minimum price movement
      formatter: (price) => {
        // Custom formatter to ensure 2 decimal places
        return '$' + price.toFixed(2);
      }
    },
  };
};


export const getVolumeOptions = (activeTheme) => {
  return {
    color: activeTheme.volumeColor,
    priceFormat: {
      type: 'volume',
    },
    priceScaleId: '', // Set to an empty string to use the right scale
    scaleMargins: {
      top: 0.8, // Position the volume series at the bottom 20% of the chart
      bottom: 0.0,
    },
  };
}; 