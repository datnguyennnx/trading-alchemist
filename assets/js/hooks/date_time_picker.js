const DateTimePicker = {
  mounted() {
    try {
      // Store references to elements
      this.container = this.el;
      this.input = this.el.querySelector(`#${this.el.id}-input`);
      
      if (!this.input) {
        console.error("DateTimePicker hook: Input element not found");
        return;
      }
      
      this.calendar = this.el.querySelector(`#${this.el.id}-calendar`);
      if (!this.calendar) {
        console.error("DateTimePicker hook: Calendar element not found");
        return;
      }
      
      this.calendarDays = this.calendar.querySelector('.calendar-days');
      this.monthDisplay = this.calendar.querySelector('.current-month-display');
      this.hourInput = this.calendar.querySelector(`#${this.el.id}-hour-input`);
      this.minuteInput = this.calendar.querySelector(`#${this.el.id}-minute-input`);
      this.periodSelectContainer = this.calendar.querySelector(`#${this.el.id}-period-select`);
      
      // Set up state
      this.isOpen = false;
      this.suppressEvents = true;
      this.currentDate = new Date();
      this.selectedDate = null;
      
      // Parse initial value if available
      const initialValue = this.el.dataset.value;
      
      if (initialValue) {
        try {
          this.selectedDate = new Date(initialValue);
          if (isNaN(this.selectedDate.getTime())) {
            this.selectedDate = null;
          } else {
            this.currentDate = new Date(this.selectedDate);
            this.updateTimeInputs(this.selectedDate);
          }
        } catch (error) {
          this.selectedDate = null;
        }
      }
      
      this.setupEventListeners();
      
      // Make this hook instance accessible to parent components through a global registry
      // This allows the form to access the date picker's value on submit
      if (!window.DateTimePickerRegistry) {
        window.DateTimePickerRegistry = {};
      }
      window.DateTimePickerRegistry[this.el.id] = this;
      
      // Find closest form and listen for submit event
      const closestForm = this.el.closest('form');
      if (closestForm) {
        closestForm.addEventListener('submit', (e) => {
          // Update hidden field with current value before form submission
          this.pushDateTimeValue();
        });
      }
      
      console.log(`DateTimePicker mounted with suppressEvents = ${this.suppressEvents}`);
    } catch (error) {
      console.error("DateTimePicker hook: Error in mounted()", error);
    }
  },
  
  updated() {
    this.input = this.el.querySelector(`#${this.el.id}-input`);
    this.calendar = this.el.querySelector(`#${this.el.id}-calendar`);
    this.calendarDays = this.calendar ? this.calendar.querySelector('.calendar-days') : null;
    this.monthDisplay = this.calendar ? this.calendar.querySelector('.current-month-display') : null;
    this.hourInput = this.calendar ? this.calendar.querySelector(`#${this.el.id}-hour-input`) : null;
    this.minuteInput = this.calendar ? this.calendar.querySelector(`#${this.el.id}-minute-input`) : null;
    this.periodSelectContainer = this.calendar ? this.calendar.querySelector(`#${this.el.id}-period-select`) : null;
    
    if (this.calendar && !this.calendar.classList.contains('hidden')) {
      this.isOpen = true;
      if(this.calendarDays && this.monthDisplay) {
        this.renderCalendar();
      }
    } else {
      this.isOpen = false;
    }
  },
  
  destroyed() {
    document.removeEventListener('click', this.boundHandleDocumentClick);
    
    // Clean up registry
    if (window.DateTimePickerRegistry && window.DateTimePickerRegistry[this.el.id]) {
      delete window.DateTimePickerRegistry[this.el.id];
    }
  },
  
  setupEventListeners() {
    if (!this.input || !this.calendar) return;
    
    // Toggle calendar on input click
    this.input.addEventListener('click', (e) => {
      if (this.el.dataset.disabled === 'true') return;
      this.toggleCalendar();
    });
    
    // Navigate months without triggering events
    const prevBtn = this.calendar.querySelector('.prev-month-btn');
    const nextBtn = this.calendar.querySelector('.next-month-btn');
    
    if(prevBtn) {
      prevBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        this.navigateMonth(-1);
      });
    }
    
    if(nextBtn) {
      nextBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        this.navigateMonth(1);
      });
    }
    
    // Time inputs - update display but don't push events yet
    if (this.hourInput) {
      this.hourInput.addEventListener('input', () => {
        if (this.selectedDate) this.updateDateTimeDisplay();
      });
      this.hourInput.addEventListener('blur', () => this.formatHourInput());
    }
    
    if (this.minuteInput) {
      this.minuteInput.addEventListener('input', () => {
        if (this.selectedDate) this.updateDateTimeDisplay();
      });
      this.minuteInput.addEventListener('blur', () => this.formatMinuteInput());
    }
    
    // Close calendar when clicking outside
    this.boundHandleDocumentClick = this.handleDocumentClick.bind(this);
    document.addEventListener('click', this.boundHandleDocumentClick);
  },
  
  handleDocumentClick(e) {
    if (this.isOpen && !this.el.contains(e.target)) {
      this.closeCalendar();
    }
  },
  
  toggleCalendar() {
    if (this.isOpen) {
      this.closeCalendar();
    } else {
      this.openCalendar();
    }
  },
  
  openCalendar() {
    if (!this.calendar) return;
    this.calendar.classList.remove('hidden');
    this.isOpen = true;
    this.renderCalendar();
  },
  
  closeCalendar() {
    if (!this.calendar) return;
    this.calendar.classList.add('hidden');
    this.isOpen = false;
  },
  
  navigateMonth(direction) {
    // This just changes the visible month, no need to trigger events
    this.currentDate.setMonth(this.currentDate.getMonth() + direction);
    this.renderCalendar();
  },
  
  renderCalendar() {
    if (!this.calendarDays || !this.monthDisplay) return;
    
    const year = this.currentDate.getFullYear();
    const month = this.currentDate.getMonth();
    
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 
                         'July', 'August', 'September', 'October', 'November', 'December'];
    this.monthDisplay.textContent = `${monthNames[month]} ${year}`;
    
    this.calendarDays.innerHTML = '';
    
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);
    const daysInMonth = lastDay.getDate();
    
    let firstDayIndex = firstDay.getDay() - 1;
    if (firstDayIndex === -1) firstDayIndex = 6;
    
    const grid = document.createElement('div');
    grid.className = 'grid grid-cols-7 gap-1';
    
    const fragment = document.createDocumentFragment();

    // Add empty cells
    for (let i = 0; i < firstDayIndex; i++) {
      const emptyCell = document.createElement('div');
      emptyCell.className = 'p-0 h-9 w-9 flex items-center justify-center text-sm opacity-50 cursor-default';
      fragment.appendChild(emptyCell);
    }
    
    // Add day cells as buttons
    for (let day = 1; day <= daysInMonth; day++) {
      const dayCell = document.createElement('button');
      dayCell.type = 'button';
      dayCell.dataset.day = day;
      let classes = 'p-0 h-9 w-9 flex items-center justify-center rounded-md text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 hover:bg-accent hover:text-accent-foreground';
      dayCell.textContent = day;
      
      const today = new Date();
      const isToday = day === today.getDate() && 
                      this.currentDate.getMonth() === today.getMonth() && 
                      this.currentDate.getFullYear() === today.getFullYear();
      
      const isSelected = this.selectedDate && 
                         this.selectedDate.getDate() === day && 
                         this.selectedDate.getMonth() === this.currentDate.getMonth() && 
                         this.selectedDate.getFullYear() === this.currentDate.getFullYear();
      
      if (isSelected) {
        classes += ' bg-primary text-primary-foreground font-semibold hover:bg-primary/90';
      } else if (isToday) {
        classes += ' bg-accent/50 font-medium';
      }
      
      dayCell.className = classes;
      fragment.appendChild(dayCell);
    }
    
    grid.appendChild(fragment);
    this.calendarDays.appendChild(grid);

    // Add delegated click handler
    if (this.dayClickListener) {
        this.calendarDays.removeEventListener('click', this.dayClickListener);
    }
    this.dayClickListener = this.handleDayClick.bind(this);
    this.calendarDays.addEventListener('click', this.dayClickListener);
  },
  
  handleDayClick(e) {
    const targetButton = e.target.closest('button[data-day]');
    if (targetButton && this.calendarDays.contains(targetButton)) {
        e.stopPropagation();
        const day = parseInt(targetButton.dataset.day, 10);
        if (!isNaN(day)) {
            this.selectDay(day);
        }
    }
  },
  
  selectDay(day) {
    const newSelectedDate = new Date(
      this.currentDate.getFullYear(),
      this.currentDate.getMonth(),
      day
    );
    
    // Preserve time if already set, otherwise default to current time
    if (this.selectedDate) {
      newSelectedDate.setHours(this.selectedDate.getHours());
      newSelectedDate.setMinutes(this.selectedDate.getMinutes());
      newSelectedDate.setSeconds(0);
      newSelectedDate.setMilliseconds(0);
    } else {
      newSelectedDate.setHours(12, 0, 0, 0);
      this.updateTimeInputs(newSelectedDate);
    }
    
    this.selectedDate = newSelectedDate;
    this.currentDate = new Date(newSelectedDate);
    
    // Update the input display
    this.updateInputValue();
    this.renderCalendar();
    
    // Close the calendar but DON'T push events to LiveView
    this.closeCalendar();
  },
  
  formatHourInput() {
    if (!this.hourInput || !this.selectedDate) return;
    let val = parseInt(this.hourInput.value, 10);
    if (isNaN(val) || val < 1) val = 1;
    if (val > 12) val = 12;
    this.hourInput.value = val;
    this.updateDateTimeDisplay();
  },
  
  formatMinuteInput() {
    if (!this.minuteInput || !this.selectedDate) return;
    let val = parseInt(this.minuteInput.value, 10);
    if (isNaN(val) || val < 0) val = 0;
    if (val > 59) val = 59;
    this.minuteInput.value = String(val).padStart(2, '0');
    this.updateDateTimeDisplay();
  },
  
  updateTimeInputs(date) {
    if (!this.hourInput || !this.minuteInput) return;
    
    let hours = date.getHours();
    let period = "AM";
    if (hours === 0) { hours = 12; } 
    else if (hours === 12) { period = "PM"; } 
    else if (hours > 12) { hours -= 12; period = "PM"; }
    
    let minutes = date.getMinutes();
    
    this.hourInput.value = hours;
    this.minuteInput.value = String(minutes).padStart(2, '0');
    // Set period data attribute for LiveView
    this.el.dataset.period = period;
  },
  
  updateDateTimeDisplay() {
    if (!this.selectedDate || !this.hourInput || !this.minuteInput) return;

    // Get values from inputs
    let hours = parseInt(this.hourInput.value, 10) || 12;
    let minutes = parseInt(this.minuteInput.value, 10) || 0;
    const period = this.el.dataset.period || 'AM';
    
    // Convert to 24-hour time
    let hours24 = hours;
    if (period === "PM" && hours24 < 12) {
      hours24 += 12;
    } else if (period === "AM" && hours24 === 12) {
      hours24 = 0;
    }
    
    // Update the date object
    this.selectedDate.setHours(hours24);
    this.selectedDate.setMinutes(minutes);
    this.selectedDate.setSeconds(0, 0);

    // Update display
    this.updateInputValue();
  },
  
  updateInputValue() {
    if (!this.input) return;
    if (!this.selectedDate) {
      this.input.value = this.el.dataset.placeholder || '';
      return;
    }
    
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    const month = monthNames[this.selectedDate.getMonth()];
    const day = this.selectedDate.getDate();
    const year = this.selectedDate.getFullYear();
    let hours = this.selectedDate.getHours();
    let period = "AM";
    if (hours === 0) { hours = 12; } 
    else if (hours === 12) { period = "PM"; } 
    else if (hours > 12) { hours -= 12; period = "PM"; }
    const minutes = String(this.selectedDate.getMinutes()).padStart(2, '0');
    
    this.input.value = `${month} ${day}, ${year} at ${hours}:${minutes} ${period}`;
  },
  
  // Prevent any automatic event pushing, only update UI
  pushDateTimeValue() {
    try {
      if (!this.selectedDate) return;
      
      const isoString = this.selectedDate.toISOString();
      const name = this.el.dataset.name || this.el.id;
      
      // Update the hidden input with the current value
      const hiddenInput = document.createElement('input');
      hiddenInput.type = 'hidden';
      hiddenInput.name = name;
      hiddenInput.value = isoString;
      
      // Replace any existing hidden input or add a new one
      const existingInput = this.el.querySelector(`input[name="${name}"][type="hidden"]`);
      if (existingInput) {
        existingInput.value = isoString;
      } else {
        this.el.appendChild(hiddenInput);
      }
      
      return isoString;
    } catch (error) {
      console.error("DateTimePicker hook: Error preparing date value", error);
      return null;
    }
  },
  
  // Keep compatibility but NEVER send events to the server automatically
  pushEventToLiveView() {
    // Complete no-op to prevent accidental backtests
    // Only the form submission should push values
    console.log("Prevented automatic pushEvent - date picker events are suppressed");
    return;
  },
  
  // Expose method to get current value (can be called from parent components)
  getCurrentValue() {
    if (!this.selectedDate) {
      // Try to parse from input field as a fallback
      const inputValue = this.input?.value;
      if (inputValue) {
        try {
          // Simple date parsing as fallback
          const parsed = new Date(inputValue);
          if (!isNaN(parsed.getTime())) {
            console.log("DateTimePicker: Parsed value from input:", parsed.toISOString());
            return parsed.toISOString();
          }
        } catch (e) {
          console.error("DateTimePicker: Error parsing input value:", e);
        }
      }
      
      // Check if there's a value in the data attribute
      const dataValue = this.el.dataset.value;
      if (dataValue) {
        try {
          const parsed = new Date(dataValue);
          if (!isNaN(parsed.getTime())) {
            console.log("DateTimePicker: Using value from data attribute:", parsed.toISOString());
            return parsed.toISOString();
          }
        } catch (e) {
          console.error("DateTimePicker: Error parsing data-value:", e);
        }
      }
      
      console.warn("DateTimePicker: No selectedDate available");
      return null;
    }
    
    console.log("DateTimePicker: Using selectedDate:", this.selectedDate.toISOString());
    return this.selectedDate.toISOString();
  }
};

export default DateTimePicker; 