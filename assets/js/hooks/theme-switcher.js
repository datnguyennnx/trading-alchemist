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
    // Default to 'dark' if localStorage theme is not set or invalid
    const theme = storedTheme === 'light' || storedTheme === 'dark' ? storedTheme : 'dark';
    return theme;
  },

  applyTheme(theme) {
    if (!theme || (theme !== 'light' && theme !== 'dark')) {
       theme = 'dark';
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

    const selectTrigger = selectElement.querySelector('.select-value');
    if (selectTrigger) {
       const label = theme === 'light' ? 'Light' : 'Dark';
       selectTrigger.setAttribute('data-content', label);
    }

    const items = selectElement.querySelectorAll('.select-content [role="option"]');
    items.forEach(item => {
      const radio = item.querySelector('input[name="theme"]');
      const checkmark = item.querySelector('span.absolute.right-2'); 

      if (radio && checkmark) { 
        const isChecked = (radio.value === theme);
        radio.checked = isChecked; 
        checkmark.style.display = isChecked ? 'flex' : 'none'; 
      }
    });
  }
};

export default ThemeManager; 