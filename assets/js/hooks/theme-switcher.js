const ThemeManager = {
  mounted() {
    this.theme = this.getTheme();
    this.applyTheme(this.theme);
    this.updateSelectUI(this.theme); // Update UI on initial load

    // Listen for clicks on theme options within this hook's element
    this.el.addEventListener('click', (e) => {
      const targetItem = e.target.closest('[data-theme-value]');
      if (targetItem) {
        const newTheme = targetItem.dataset.themeValue;
        if (newTheme && newTheme !== this.theme) {
          this.setTheme(newTheme);
        }
      }
    });
    
    // Mark as connected and push initial theme
    window.addEventListener('phx:page-loading-stop', () => {
      this.el.dataset.connected = "true";
      // Push the initial theme AFTER UI is updated
      this.pushEventToServer('theme_changed', { theme: this.theme });
    });

    // Removed handleEvent for set_theme_from_server
    /*
    this.handleEvent('set_theme_from_server', ({ theme }) => {
      if (theme && theme !== this.theme) {
        this.setTheme(theme);
      }
    });
    */
  },

  // --- Helper Methods ---

  getTheme() {
    return localStorage.getItem('theme') ||
           (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
  },

  applyTheme(theme) {
    const htmlElement = document.documentElement;
    htmlElement.classList.remove('dark', 'light');
    htmlElement.classList.add(theme);
    htmlElement.style.colorScheme = theme;
    localStorage.setItem('theme', theme);
  },

  setTheme(newTheme) {
     if (newTheme === this.theme) return; // Avoid redundant work

     this.theme = newTheme;
     this.applyTheme(this.theme);
     this.updateSelectUI(this.theme); // Update UI immediately after setting theme
     this.pushEventToServer('theme_changed', { theme: this.theme }); // Notify server
  },

  // Add method to manually update the theme select UI
  updateSelectUI(theme) {
    const selectElement = this.el.querySelector('#theme-select');
    if (!selectElement) return; // Guard clause

    // Update the trigger label
    const selectTrigger = selectElement.querySelector('.select-value');
    if (selectTrigger) {
       const label = theme === 'light' ? 'Light' : 'Dark';
       selectTrigger.setAttribute('data-content', label);
    }

    // Update the checked state AND checkmark visibility using style.display
    const items = selectElement.querySelectorAll('.select-content [role="option"]');
    items.forEach(item => {
      const radio = item.querySelector('input[name="theme"]');
      // Find the checkmark span (now always present thanks to select.ex change)
      const checkmark = item.querySelector('span.absolute.right-2');

      if (radio && checkmark) { // Check if both elements are found
        const isChecked = (radio.value === theme);
        radio.checked = isChecked; // Set the underlying radio state

        // Directly control checkmark visibility via style.display
        checkmark.style.display = isChecked ? 'flex' : 'none'; // Use 'flex' as per select.ex
      }
    });
  },

  pushEventToServer(event, payload) {
    if (this.el.dataset.connected === "true") {
      try {
        this.pushEvent(event, payload);
      } catch (error) {
        console.error(`Failed to push ${event} event:`, error);
      }
    }
  }
};

export default ThemeManager; 