/**
 * Core date picker functionality
 * This module handles the pure UI aspects of the date picker
 * without any LiveView integration
 */

const DatePickerCore = {
  /**
   * Initialize a date picker with the given element and options
   */
  init(element, options = {}) {
    if (!element) return null;
    
    const state = {
      isOpen: false,
      currentDate: new Date(),
      selectedDate: null,
      elements: {
        container: element,
        input: element.querySelector(`#${element.id}-input`),
        calendar: element.querySelector(`#${element.id}-calendar`),
      }
    };
    
    // Find sub-elements
    if (state.elements.calendar) {
      state.elements.calendarDays = state.elements.calendar.querySelector('.calendar-days');
      state.elements.monthDisplay = state.elements.calendar.querySelector('.current-month-display');
      state.elements.hourInput = state.elements.calendar.querySelector(`#${element.id}-hour-input`);
      state.elements.minuteInput = state.elements.calendar.querySelector(`#${element.id}-minute-input`);
      state.elements.periodSelect = state.elements.calendar.querySelector(`#${element.id}-period-select`);
    }
    
    // Parse initial value if available
    const initialValue = element.dataset.value;
    if (initialValue) {
      try {
        const date = new Date(initialValue);
        if (!isNaN(date.getTime())) {
          state.selectedDate = date;
          state.currentDate = new Date(date);
          this.updateTimeInputs(state);
        }
      } catch (error) {
        console.error("Error parsing initial date:", error);
      }
    }
    
    // Set up event listeners
    this.setupEventListeners(state);
    
    return state;
  },
  
  /**
   * Set up all event listeners for the date picker
   */
  setupEventListeners(state) {
    const { elements } = state;
    if (!elements.input || !elements.calendar) return;
    
    // Input click to toggle calendar
    elements.input.addEventListener('click', () => {
      if (elements.container.dataset.disabled === 'true') return;
      this.toggleCalendar(state);
    });
    
    // Month navigation buttons
    const prevBtn = elements.calendar.querySelector('.prev-month-btn');
    const nextBtn = elements.calendar.querySelector('.next-month-btn');
    
    if (prevBtn) {
      prevBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        this.navigateMonth(state, -1);
      });
    }
    
    if (nextBtn) {
      nextBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        this.navigateMonth(state, 1);
      });
    }
    
    // Time inputs
    if (elements.hourInput) {
      elements.hourInput.addEventListener('input', () => {
        if (state.selectedDate) this.updateDateTimeDisplay(state);
      });
      elements.hourInput.addEventListener('blur', () => this.formatHourInput(state));
    }
    
    if (elements.minuteInput) {
      elements.minuteInput.addEventListener('input', () => {
        if (state.selectedDate) this.updateDateTimeDisplay(state);
      });
      elements.minuteInput.addEventListener('blur', () => this.formatMinuteInput(state));
    }
    
    // Period select (AM/PM)
    // Handle both the direct select element and the radios inside the dropdown
    if (elements.periodSelect) {
      // For traditional select
      elements.periodSelect.addEventListener('change', () => {
        if (state.selectedDate) this.updateDateTimeDisplay(state);
      });
      
      // For modern custom select with radio inputs
      const periodRadios = elements.calendar.querySelectorAll(`input[name="${elements.container.id}-period"]`);
      periodRadios.forEach(radio => {
        radio.addEventListener('change', () => {
          if (state.selectedDate) this.updateDateTimeDisplay(state);
        });
      });
      
      // Also listen for click events on the period select items
      const periodItems = elements.calendar.querySelectorAll(`.period-select label[role="option"]`);
      periodItems.forEach(item => {
        item.addEventListener('click', () => {
          setTimeout(() => {
            if (state.selectedDate) this.updateDateTimeDisplay(state);
          }, 50); // Small delay to allow the value to update
        });
      });
    }
    
    // Global click handler for closing calendar
    state.documentClickHandler = (e) => {
      if (state.isOpen && !elements.container.contains(e.target)) {
        this.closeCalendar(state);
      }
    };
    
    document.addEventListener('click', state.documentClickHandler);
  },
  
  /**
   * Clean up event listeners
   */
  destroy(state) {
    if (state.documentClickHandler) {
      document.removeEventListener('click', state.documentClickHandler);
    }
    
    if (state.elements.calendarDays && state.dayClickListener) {
      state.elements.calendarDays.removeEventListener('click', state.dayClickListener);
    }
  },
  
  /**
   * Toggle calendar visibility
   */
  toggleCalendar(state) {
    if (state.isOpen) {
      this.closeCalendar(state);
    } else {
      this.openCalendar(state);
    }
  },
  
  /**
   * Open the calendar dropdown
   */
  openCalendar(state) {
    const { elements } = state;
    if (!elements.calendar) return;
    
    elements.calendar.classList.remove('hidden');
    state.isOpen = true;
    this.renderCalendar(state);
  },
  
  /**
   * Close the calendar dropdown
   */
  closeCalendar(state) {
    const { elements } = state;
    if (!elements.calendar) return;
    
    elements.calendar.classList.add('hidden');
    state.isOpen = false;
  },
  
  /**
   * Navigate to previous/next month
   */
  navigateMonth(state, direction) {
    state.currentDate.setMonth(state.currentDate.getMonth() + direction);
    this.renderCalendar(state);
  },
  
  /**
   * Render the calendar with the current month
   */
  renderCalendar(state) {
    const { elements, currentDate } = state;
    if (!elements.calendarDays || !elements.monthDisplay) return;
    
    const year = currentDate.getFullYear();
    const month = currentDate.getMonth();
    
    // Update month/year display
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 
                       'July', 'August', 'September', 'October', 'November', 'December'];
    elements.monthDisplay.textContent = `${monthNames[month]} ${year}`;
    
    // Clear existing calendar days
    elements.calendarDays.innerHTML = '';
    
    // Generate calendar grid
    const firstDayOfMonth = new Date(year, month, 1);
    const lastDayOfMonth = new Date(year, month + 1, 0);
    const lastDayOfPrevMonth = new Date(year, month, 0);
    
    const daysInMonth = lastDayOfMonth.getDate();
    const daysInPrevMonth = lastDayOfPrevMonth.getDate();
    
    // Adjust for Monday as first day of week (0 = Sunday, 1 = Monday ... 6 = Saturday -> 0 = Monday ... 6 = Sunday)
    let startDayIndex = firstDayOfMonth.getDay() - 1;
    if (startDayIndex === -1) startDayIndex = 6; // Adjust Sunday (0) to be 6
    
    let endDayIndex = lastDayOfMonth.getDay() - 1;
    if (endDayIndex === -1) endDayIndex = 6; // Adjust Sunday (0) to be 6
    
    const grid = document.createElement('div');
    grid.className = 'grid grid-cols-7 gap-1';
    
    const fragment = document.createDocumentFragment();
    const totalCells = 35;

    // -- Common styling for all cells --
    const cellBaseClasses = 'p-0 h-8 w-8 flex items-center justify-center rounded-md text-sm';

    // -- Render days from previous month --
    for (let i = startDayIndex - 1; i >= 0; i--) {
      const day = daysInPrevMonth - i;
      const prevMonthCell = document.createElement('div');
      prevMonthCell.textContent = day;
      prevMonthCell.className = `${cellBaseClasses} text-muted-foreground opacity-50 cursor-default`;
      fragment.appendChild(prevMonthCell);
    }
    
    // -- Render days from current month --
    for (let day = 1; day <= daysInMonth; day++) {
      const dayCell = document.createElement('button');
      dayCell.type = 'button';
      dayCell.dataset.day = day;
      dayCell.textContent = day;
      
      const today = new Date();
      const isToday = day === today.getDate() && 
                     month === today.getMonth() && 
                     year === today.getFullYear();
      
      const isSelected = state.selectedDate && 
                        state.selectedDate.getDate() === day && 
                        state.selectedDate.getMonth() === month && 
                        state.selectedDate.getFullYear() === year;
      
      // Base classes + transition/focus/disabled for buttons
      let buttonBaseClasses = `${cellBaseClasses} transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50`;
      let stateClasses = ''; // State-specific classes (including hover)
      
      if (isSelected) {
        stateClasses = 'bg-primary text-primary-foreground font-semibold';
      } else if (isToday) {
        stateClasses = 'bg-accent/50 font-medium hover:bg-accent hover:text-accent-foreground';
      } else {
        stateClasses = 'hover:bg-accent hover:text-accent-foreground';
      }
      
      dayCell.className = `${buttonBaseClasses} ${stateClasses}`;
      fragment.appendChild(dayCell);
    }
    
    // -- Render days from next month --
    const cellsRendered = startDayIndex + daysInMonth;
    if (cellsRendered < totalCells) {
        const remainingCells = totalCells - cellsRendered;
        for (let day = 1; day <= remainingCells; day++) {
            const nextMonthCell = document.createElement('div');
            nextMonthCell.textContent = day;
            nextMonthCell.className = `${cellBaseClasses} text-muted-foreground opacity-50 cursor-default`;
            fragment.appendChild(nextMonthCell);
        }
    }

    grid.appendChild(fragment);
    elements.calendarDays.appendChild(grid);
    
    // Set up day click event delegation
    if (state.dayClickListener) {
      elements.calendarDays.removeEventListener('click', state.dayClickListener);
    }
    
    state.dayClickListener = (e) => {
      const targetButton = e.target.closest('button[data-day]');
      if (targetButton && elements.calendarDays.contains(targetButton)) {
        e.stopPropagation();
        const day = parseInt(targetButton.dataset.day, 10);
        if (!isNaN(day)) {
          this.selectDay(state, day);
        }
      }
    };
    
    elements.calendarDays.addEventListener('click', state.dayClickListener);
  },
  
  /**
   * Select a specific day
   */
  selectDay(state, day) {
    const { currentDate } = state;
    
    // Create date for selected day
    const newSelectedDate = new Date(
      currentDate.getFullYear(),
      currentDate.getMonth(),
      day
    );
    
    // Preserve time if already selected, otherwise use default
    if (state.selectedDate) {
      newSelectedDate.setHours(state.selectedDate.getHours());
      newSelectedDate.setMinutes(state.selectedDate.getMinutes());
      newSelectedDate.setSeconds(0);
      newSelectedDate.setMilliseconds(0);
    } else {
      newSelectedDate.setHours(12, 0, 0, 0);
      this.updateTimeInputs(state, newSelectedDate);
    }
    
    state.selectedDate = newSelectedDate;
    state.currentDate = new Date(newSelectedDate);
    
    // Update display
    this.updateInputValue(state);
    this.renderCalendar(state);
    
    // Close calendar
    this.closeCalendar(state);
    
    // Trigger change event for integration
    if (typeof state.onChange === 'function') {
      state.onChange(newSelectedDate);
    }
  },
  
  /**
   * Format and validate hour input
   */
  formatHourInput(state) {
    const { elements, selectedDate } = state;
    if (!elements.hourInput || !selectedDate) return;
    
    let val = parseInt(elements.hourInput.value, 10);
    if (isNaN(val) || val < 1) val = 1;
    if (val > 12) val = 12;
    
    elements.hourInput.value = val;
    this.updateDateTimeDisplay(state);
  },
  
  /**
   * Format and validate minute input
   */
  formatMinuteInput(state) {
    const { elements, selectedDate } = state;
    if (!elements.minuteInput || !selectedDate) return;
    
    let val = parseInt(elements.minuteInput.value, 10);
    if (isNaN(val) || val < 0) val = 0;
    if (val > 59) val = 59;
    
    elements.minuteInput.value = String(val).padStart(2, '0');
    this.updateDateTimeDisplay(state);
  },
  
  /**
   * Update time inputs based on a date
   */
  updateTimeInputs(state, date = null) {
    const { elements } = state;
    const dateToUse = date || state.selectedDate;
    
    if (!elements.hourInput || !elements.minuteInput || !dateToUse) return;
    
    let hours = dateToUse.getHours();
    let period = "AM";
    
    if (hours === 0) { 
      hours = 12; 
    } else if (hours === 12) { 
      period = "PM"; 
    } else if (hours > 12) { 
      hours -= 12; 
      period = "PM"; 
    }
    
    elements.hourInput.value = hours;
    elements.minuteInput.value = String(dateToUse.getMinutes()).padStart(2, '0');
    
    // Update period in select if available
    if (elements.periodSelect) {
      elements.periodSelect.value = period;
    } else {
      // Fall back to data attribute
      elements.container.dataset.period = period;
    }
  },
  
  /**
   * Update the date object from time inputs
   */
  updateDateTimeDisplay(state) {
    const { elements, selectedDate } = state;
    if (!selectedDate || !elements.hourInput || !elements.minuteInput) return;
    
    // Get values from inputs
    let hours = parseInt(elements.hourInput.value, 10) || 12;
    let minutes = parseInt(elements.minuteInput.value, 10) || 0;
    
    // Get period from select or data attribute
    let period = 'AM';
    
    // Check different ways the period might be stored
    if (elements.periodSelect) {
      // Try to get from the select element directly
      period = elements.periodSelect.value || 'AM';
      
      // If using custom select, also try to find selected radio
      const periodRadios = elements.calendar.querySelectorAll(`input[name="${elements.container.id}-period"]:checked`);
      if (periodRadios.length > 0) {
        period = periodRadios[0].value;
      }
      
      // Try to find from select value attribute
      const selectedItems = elements.calendar.querySelectorAll(`.period-select label[role="option"] input:checked`);
      if (selectedItems.length > 0) {
        period = selectedItems[0].value;
      }
    }
    
    // Fallback to data attribute
    if (!period || (period !== 'AM' && period !== 'PM')) {
      period = elements.container.dataset.period || 'AM';
    }
    
    // Convert to 24-hour time
    let hours24 = hours;
    if (period === "PM" && hours24 < 12) {
      hours24 += 12;
    } else if (period === "AM" && hours24 === 12) {
      hours24 = 0;
    }
    
    // Update the date object
    selectedDate.setHours(hours24);
    selectedDate.setMinutes(minutes);
    selectedDate.setSeconds(0, 0);
    
    // Update display
    this.updateInputValue(state);
    
    // Trigger change event
    if (typeof state.onChange === 'function') {
      state.onChange(selectedDate);
    }
  },
  
  /**
   * Update the input display value
   */
  updateInputValue(state) {
    const { elements, selectedDate } = state;
    if (!elements.input) return;
    
    if (!selectedDate) {
      elements.input.value = elements.container.dataset.placeholder || '';
      return;
    }
    
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    const month = monthNames[selectedDate.getMonth()];
    const day = selectedDate.getDate();
    const year = selectedDate.getFullYear();
    
    let hours = selectedDate.getHours();
    let period = "AM";
    
    if (hours === 0) { 
      hours = 12; 
    } else if (hours === 12) { 
      period = "PM"; 
    } else if (hours > 12) { 
      hours -= 12; 
      period = "PM"; 
    }
    
    const minutes = String(selectedDate.getMinutes()).padStart(2, '0');
    elements.input.value = `${month} ${day}, ${year} at ${hours}:${minutes} ${period}`;
  },
  
  /**
   * Get the current selected date as ISO string
   */
  getISOValue(state) {
    return state.selectedDate ? state.selectedDate.toISOString() : null;
  }
};

export default DatePickerCore; 