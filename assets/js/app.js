// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

// Import hooks
import { FlickeringGrid, ThemeSwitcher, DatePicker, BacktestForm } from "./hooks";
import { ThemeUIUpdater, themeUtils } from "./hooks/theme-switcher";
import TradingViewChart from "./hooks/tradingview";

// Run theme initialization BEFORE LiveView connects
document.addEventListener('DOMContentLoaded', () => {
  const theme = themeUtils.getTheme();
  themeUtils.applyTheme(theme);
});

// Register all hooks
const Hooks = {
  FlickeringGrid,
  ThemeSwitcher,
  ThemeUIUpdater,
  TradingViewChart,
  DateTimePicker: DatePicker,
  BacktestForm
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Allows to execute JS commands from the server
window.addEventListener("phx:js-exec", ({detail}) => {
  document.querySelectorAll(detail.to).forEach(el => {
    liveSocket.execJS(el, el.getAttribute(detail.attr))
  })
})

// Single event listener for theme changes
let lastSetTheme = null; // Track last theme set to avoid loops

document.addEventListener('set-theme', (event) => {
  if (event.detail?.theme) {
    const { theme } = event.detail;
    
    // Avoid infinite loops by checking if theme has already been set
    if (lastSetTheme === theme) return;
    lastSetTheme = theme;
    
    console.log("Global theme changed to:", theme);
    
    // Apply theme to DOM and localStorage using shared utility
    themeUtils.applyTheme(theme);
    
    // Update theme UI using shared utility
    themeUtils.updateThemeUI(theme);
    
    // No need to dispatch another set-theme event - that would create a loop
    // Instead, dispatch a separate event for non-LiveView components
    const themeEvent = new CustomEvent('theme-updated', { 
      bubbles: true, 
      detail: { theme } 
    });
    document.dispatchEvent(themeEvent);
  }
});
