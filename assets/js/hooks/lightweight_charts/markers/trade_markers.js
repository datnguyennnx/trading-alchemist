/**
 * Trade marker handling for backtest charts
 */

/**
 * Render all trade markers on the chart
 * 
 * @param {Object} context - The hook context
 * @returns {void}
 */
export const renderTradeMarkers = (context) => {
  if (!context.trades || context.trades.length === 0) return;
  
  // Clear existing markers
  clearTradeMarkers(context);
  
  // Add markers for all trades
  context.trades.forEach(trade => {
    addTradeMarker(context, trade);
  });
};

/**
 * Add markers for new trades
 * 
 * @param {Object} context - The hook context
 * @param {Array} newTrades - New trades to add markers for
 * @returns {void}
 */
export const addNewTradeMarkers = (context, newTrades) => {
  if (!newTrades || newTrades.length === 0) return;
  
  // Track which trades we've already added markers for
  const existingTradeIds = new Set(context.trades.map(t => t.id));
  
  // Add markers for new trades only
  newTrades.forEach(trade => {
    if (!existingTradeIds.has(trade.id)) {
      context.trades.push(trade);
      addTradeMarker(context, trade);
    }
  });
};

/**
 * Add a single trade marker to the chart
 * 
 * @param {Object} context - The hook context
 * @param {Object} trade - Trade data
 * @returns {void}
 */
export const addTradeMarker = (context, trade) => {
  // Format trade as marker
  const marker = {
    time: trade.time,
    position: trade.side === 'buy' ? 'belowBar' : 'aboveBar',
    color: trade.side === 'buy' ? '#26a69a' : '#ef5350',
    shape: trade.side === 'buy' ? 'arrowUp' : 'arrowDown',
    text: `${trade.side.toUpperCase()} @ ${trade.entry_price}`,
    id: trade.id
  };
  
  // Add marker to series
  context.mainSeries.setMarker(marker);
  context.tradeMarkers.push(marker);
  
  // If trade has exit time, add exit marker
  if (trade.exit_time) {
    const exitMarker = {
      time: trade.exit_time,
      position: trade.side === 'buy' ? 'aboveBar' : 'belowBar',
      color: trade.side === 'buy' ? '#26a69a' : '#ef5350',
      shape: 'circle',
      text: `EXIT @ ${trade.exit_price}`,
      id: `${trade.id}-exit`
    };
    
    context.mainSeries.setMarker(exitMarker);
    context.tradeMarkers.push(exitMarker);
  }
};

/**
 * Clear all trade markers from the chart
 * 
 * @param {Object} context - The hook context
 * @returns {void}
 */
export const clearTradeMarkers = (context) => {
  // Remove all markers from the series
  if (context.tradeMarkers) {
    context.tradeMarkers.forEach(marker => {
      context.mainSeries.removeMarker(marker);
    });
    context.tradeMarkers = [];
  }
}; 