const ThemeSwitcher = {
  mounted() {
    // Get the current theme from localStorage or system preference
    const getTheme = () => {
      return localStorage.getItem('theme') || 
             (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    };
    
    // Apply theme to DOM and store in local storage
    const setTheme = (theme) => {
      const htmlElement = document.documentElement;
      
      // Toggle dark class on html element
      htmlElement.classList.toggle('dark', theme === 'dark');
      
      // Set color-scheme style
      htmlElement.style.colorScheme = theme;
      
      localStorage.setItem('theme', theme);
      
      // Push the event immediately if possible, or after a short delay to ensure it gets pushed
      if (this.el.dataset.connected === "true") {
        this.pushEventSafe('theme-changed', { theme });
      } else {
        // If not connected, schedule event to be pushed after connection
        setTimeout(() => {
          this.pushEventSafe('theme-changed', { theme });
        }, 100);
      }
    };
    
    // Helper to safely push events
    this.pushEventSafe = (event, payload) => {
      try {
        this.pushEvent(event, payload);
      } catch (error) {
        console.error(`Failed to push ${event} event:`, error);
      }
    };
    
    // Initial theme setup
    const currentTheme = getTheme();
    setTheme(currentTheme);
    
    // Set connected flag when LiveView is mounted and connected
    window.addEventListener('phx:page-loading-stop', () => {
      this.el.dataset.connected = "true";
      this.pushEventSafe('theme-changed', { theme: getTheme() });
    }, { once: true });
    
    // Handle theme change events from the server
    this.handleEvent('change_theme', ({ theme }) => setTheme(theme));
    
    // Make setTheme available to this hook instance
    this.setTheme = setTheme;
  }
};

export default ThemeSwitcher; 