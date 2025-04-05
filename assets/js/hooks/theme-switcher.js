// Shared utility functions to avoid duplication
const themeUtils = {
  // Get the current theme from localStorage or system preference
  getTheme: () => {
    return localStorage.getItem('theme') || 
           (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
  },
  
  // Helper to update the theme dropdown UI
  updateThemeUI: (theme) => {
    const themeDropdownTrigger = document.getElementById('theme-dropdown-trigger');
    if (!themeDropdownTrigger) return;
    
    // Update the icon
    const iconElement = themeDropdownTrigger.querySelector('.theme-icon');
    if (iconElement) {
      iconElement.innerHTML = '';
      const iconSpan = document.createElement('span');
      iconSpan.className = `hero-${theme === 'light' ? 'sun' : 'moon'} h-4 w-4`;
      iconElement.appendChild(iconSpan);
    }
    
    // Update the text
    const textElement = themeDropdownTrigger.querySelector('.theme-text');
    if (textElement) {
      textElement.textContent = theme === 'light' ? 'Light' : 'Dark';
    }
  },
  
  // Apply theme to DOM and localStorage
  applyTheme: (theme) => {
    const htmlElement = document.documentElement;
    htmlElement.classList.remove('dark', 'light');
    htmlElement.classList.add(theme);
    htmlElement.style.colorScheme = theme;
    localStorage.setItem('theme', theme);
  }
};

// Main theme switcher hook
const ThemeSwitcher = {
  mounted() {
    // Keep track of current theme to avoid infinite loops
    this.currentTheme = null;
    
    // Apply theme to DOM and handle LiveView updates
    const setTheme = (theme) => {
      // Avoid infinite loops by checking if theme has changed
      if (this.currentTheme === theme) return;
      
      console.log("ThemeSwitcher: Setting theme to", theme);
      
      // Update current theme tracker
      this.currentTheme = theme;
      
      // Apply theme to DOM and localStorage
      themeUtils.applyTheme(theme);
      
      // Dispatch the set-theme event (this will trigger all other components to update)
      document.dispatchEvent(new CustomEvent('set-theme', { 
        bubbles: true, 
        detail: { theme } 
      }));
      
      // Push event to LiveView
      if (this.el.dataset.connected === "true") {
        this.pushEventSafe('theme-changed', { theme });
      } else {
        setTimeout(() => this.pushEventSafe('theme-changed', { theme }), 100);
      }

      // Update UI
      themeUtils.updateThemeUI(theme);
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
    const currentTheme = themeUtils.getTheme();
    setTheme(currentTheme);
    
    // Mark as connected when LiveView is ready
    window.addEventListener('phx:page-loading-stop', () => {
      this.el.dataset.connected = "true";
      const theme = themeUtils.getTheme();
      if (this.currentTheme !== theme) {
        this.pushEventSafe('theme-changed', { theme });
      }
      themeUtils.updateThemeUI(theme);
    });
    
    // Handle theme change events from LiveView
    this.handleEvent('change_theme', ({ theme }) => {
      if (this.currentTheme !== theme) {
        setTheme(theme);
      }
    });
    
    // Listen for global theme changes (from other sources)
    window.addEventListener('set-theme', (event) => {
      if (event.detail?.theme && this.currentTheme !== event.detail.theme) {
        setTheme(event.detail.theme);
      }
    });
    
    // Make setTheme available to this hook instance
    this.setTheme = setTheme;
  }
};

// Dedicated hook for theme UI updates
const ThemeUIUpdater = {
  mounted() {
    // Update UI when theme changes via LiveView
    this.handleEvent('change_theme', ({ theme }) => {
      themeUtils.updateThemeUI(theme);
    });
    
    // Initialize with current theme
    themeUtils.updateThemeUI(themeUtils.getTheme());
    
    // Listen for theme changes from any source
    window.addEventListener('set-theme', (event) => {
      if (event.detail?.theme) {
        themeUtils.updateThemeUI(event.detail.theme);
      }
    });
  }
};

export { ThemeSwitcher as default, ThemeUIUpdater, themeUtils }; 