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
import FlickeringGrid from "./hooks/flickering_grid"
import ThemeSwitcher from "./hooks/theme-switcher"

// Apply theme from localStorage or system preference on initial page load
const initializeTheme = () => {
  const theme = localStorage.getItem('theme') || 
                (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
  
  const htmlElement = document.documentElement;
  htmlElement.classList.toggle('dark', theme === 'dark');
  htmlElement.style.colorScheme = theme;
};

// Run theme initialization BEFORE LiveView connects
document.addEventListener('DOMContentLoaded', initializeTheme);

const Hooks = {
  FlickeringGrid,
  ThemeSwitcher
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
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
document.addEventListener('set-theme', (event) => {
  if (event.detail?.theme) {
    const { theme } = event.detail;
    const htmlElement = document.documentElement;
    htmlElement.classList.toggle('dark', theme === 'dark');
    htmlElement.style.colorScheme = theme;
    localStorage.setItem('theme', theme);
    
    // Update dropdown UI directly
    const themeDropdownTrigger = document.getElementById('theme-dropdown-trigger');
    if (themeDropdownTrigger) {
      // Clear existing content
      themeDropdownTrigger.innerHTML = '';
      
      // Create icon span
      const iconSpan = document.createElement('span');
      iconSpan.className = 'h-4 w-4 flex items-center';
      
      // Create SVG element for the icon
      // For simplicity, we'll set a class that should match what's expected in SaladUI.Icon
      const iconElement = document.createElement('span');
      iconElement.className = theme === 'light' ? 'hero-sun h-4 w-4' : 'hero-moon h-4 w-4';
      iconSpan.appendChild(iconElement);
      
      // Add a space between icon and text
      const spacer = document.createTextNode(' ');
      
      // Create text span
      const textSpan = document.createElement('span');
      textSpan.textContent = theme === 'light' ? 'Light' : 'Dark';
      
      // Append elements to button
      themeDropdownTrigger.appendChild(iconSpan);
      themeDropdownTrigger.appendChild(spacer);
      themeDropdownTrigger.appendChild(textSpan);
    }
  }
});
