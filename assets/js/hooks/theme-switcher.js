// assets/js/hooks/theme-switcher.js

const ThemeManager = {
  mounted() {
    this.theme = this.getTheme();
    this.applyTheme(this.theme);
    this.updateSelectUI(this.theme); // Update UI on initial load

    // Listen for clicks on theme options within this hook's element
    document.body.addEventListener('click', (e) => {
      const targetItem = e.target.closest('[data-theme-value]');
      if (targetItem) {
        const newTheme = targetItem.dataset.themeValue;
        if (newTheme && newTheme !== this.theme) {
          this.setTheme(newTheme);
        }
      }
    });
  },

  getTheme() {
    const storedTheme = localStorage.getItem('theme');
    // Default to 'light' if localStorage theme is not set or invalid
    const theme = storedTheme === 'light' || storedTheme === 'dark' ? storedTheme : 'light';
    return theme;
  },

  applyTheme(theme) {
    if (!theme || (theme !== 'light' && theme !== 'dark')) {
       theme = 'light';
    }
    const htmlElement = document.documentElement;
    htmlElement.classList.remove('dark', 'light');
    htmlElement.classList.add(theme);
    htmlElement.style.colorScheme = theme;
    localStorage.setItem('theme', theme);
  },

  setTheme(newTheme) {
     if (newTheme === this.theme) return; 

     this.theme = newTheme;
     this.applyTheme(this.theme);
     this.updateSelectUI(this.theme);
  },

  updateSelectUI(theme) {
    const selectElement = document.querySelector('#theme-select'); 
    if (!selectElement) {
       return; // It's okay if the select UI isn't on every page
    }

    // Update the trigger display value
    const selectTrigger = selectElement.querySelector('.select-value');
    if (selectTrigger) {
       const label = theme === 'light' ? 'Light' : 'Dark';
       selectTrigger.setAttribute('data-content', label);
    }

    // Update the radio inputs and checkmarks
    const items = selectElement.querySelectorAll('[role="option"]');
    items.forEach(item => {
      const radio = item.querySelector('input[type="radio"]');
      if (radio) { 
        const isChecked = (radio.value === theme);
        radio.checked = isChecked;
        
        // In SaladUI's select_item, there's a specific span for the checkmark
        // It's located at the end and contains an SVG icon
        const checkmark = item.querySelector('span.absolute');
        
        if (checkmark) {
          if (isChecked) {
            checkmark.classList.remove('hidden');
          } else {
            checkmark.classList.add('hidden');
          }
        }
      }
    });
  }
};

export default ThemeManager;