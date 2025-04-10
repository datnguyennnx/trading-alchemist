const DateTimePicker = {
  mounted() {
    try {
      // Store references to elements
      this.container = this.el;
      // Use the specific ID to select the input element reliably
      this.input = this.el.querySelector(`#${this.el.id}-input`);
      
      // Handle case when elements might not be fully loaded yet
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
      if (!this.calendarDays) {
        console.error("DateTimePicker hook: Calendar days container not found");
        return;
      }
      
      this.monthDisplay = this.calendar.querySelector('.current-month-display');
      if (!this.monthDisplay) {
        console.error("DateTimePicker hook: Month display element not found");
        return;
      }
      
      // Select the time input/select elements
      this.hourInput = this.calendar.querySelector(`#${this.el.id}-hour-input`);
      this.minuteInput = this.calendar.querySelector(`#${this.el.id}-minute-input`);
      this.periodSelectContainer = this.calendar.querySelector(`#${this.el.id}-period-select`);
      
      // Check if time elements are found
      if (!this.hourInput || !this.minuteInput || !this.periodSelectContainer) {
        console.error("DateTimePicker hook: One or more time input/select elements not found");
        return;
      }
      
      // Set up state
      this.isOpen = false;
      this.currentDate = new Date();
      this.selectedDate = null;
      
      // Parse initial value if available
      const initialValue = this.el.dataset.value;
      
      if (initialValue) {
        try {
          this.selectedDate = new Date(initialValue);
          if (isNaN(this.selectedDate.getTime())) {
            this.selectedDate = null;
            console.warn("DateTimePicker hook: Invalid initial date value");
          } else {
            this.currentDate = new Date(this.selectedDate);
            // Set initial values for the time inputs/select
            this.updateTimeInputs(this.selectedDate);
          }
        } catch (dateError) {
          console.error("DateTimePicker hook: Error parsing initial date", dateError);
          this.selectedDate = null;
        }
      }
      
      // Set up event listeners
      this.setupEventListeners();
      
      // Initial render of calendar - only needed if it starts open
      // this.renderCalendar();
    } catch (error) {
      console.error("DateTimePicker hook: Error in mounted()", error);
    }
  },
  
  updated() {
    // Re-select elements that might be replaced by morphdom
    this.input = this.el.querySelector(`#${this.el.id}-input`);
    this.calendar = this.el.querySelector(`#${this.el.id}-calendar`);
    this.calendarDays = this.calendar ? this.calendar.querySelector('.calendar-days') : null;
    this.monthDisplay = this.calendar ? this.calendar.querySelector('.current-month-display') : null;
    this.hourInput = this.calendar ? this.calendar.querySelector(`#${this.el.id}-hour-input`) : null;
    this.minuteInput = this.calendar ? this.calendar.querySelector(`#${this.el.id}-minute-input`) : null;
    this.periodSelectContainer = this.calendar ? this.calendar.querySelector(`#${this.el.id}-period-select`) : null;
    
    // Ensure calendar state is consistent with DOM
    if (this.calendar && !this.calendar.classList.contains('hidden')) {
      this.isOpen = true;
      // Re-render calendar if it's open to ensure day styles are correct
      if(this.calendarDays && this.monthDisplay) {
        this.renderCalendar();
      }
    } else {
      this.isOpen = false;
    }
  },
  
  destroyed() {
    // Clean up global event listener
    document.removeEventListener('click', this.handleDocumentClick);
  },
  
  // Store the bound listener function so it can be removed later
  boundHandleDocumentClick: null,
  
  setupEventListeners() {
    if (!this.input || !this.calendar) {
        console.error("DateTimePicker hook: Cannot setup listeners, input or calendar missing.");
        return;
    }
    
    // Toggle calendar on input click
    this.input.addEventListener('click', (e) => {
      // The input is readonly, so click might not bubble reliably
      // Let's attach to the parent wrapper if needed, but try input first
      if (this.el.dataset.disabled === 'true') return;
      this.toggleCalendar();
    });
    
    // Navigate months
    const prevBtn = this.calendar.querySelector('.prev-month-btn');
    const nextBtn = this.calendar.querySelector('.next-month-btn');
    if(prevBtn) {
      prevBtn.addEventListener('click', (e) => {
        e.stopPropagation(); // Prevent calendar from closing
        this.navigateMonth(-1);
      });
    }
    if(nextBtn) {
      nextBtn.addEventListener('click', (e) => {
        e.stopPropagation(); // Prevent calendar from closing
        this.navigateMonth(1);
      });
    }
    
    // Time inputs
    if (this.hourInput) {
      this.hourInput.addEventListener('input', () => this.handleTimeInputChange());
      this.hourInput.addEventListener('blur', () => this.formatHourInput());
    }
    if (this.minuteInput) {
      this.minuteInput.addEventListener('input', () => this.handleTimeInputChange());
      this.minuteInput.addEventListener('blur', () => this.formatMinuteInput());
    }
    // Period select is handled by SaladUI/LiveView, but we might need to react
    // If SaladUI Select pushes a standard 'change' or 'input' event, we could listen here.
    // For now, rely on LiveView state for period.
    
    // Close calendar when clicking outside - bind 'this'
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
    // Re-render calendar every time it opens to ensure correct styling
    this.renderCalendar();
  },
  
  closeCalendar() {
    if (!this.calendar) return;
    this.calendar.classList.add('hidden');
    this.isOpen = false;
  },
  
  navigateMonth(direction) {
    this.currentDate.setMonth(this.currentDate.getMonth() + direction);
    this.renderCalendar(); // Re-render with new month
  },
  
  renderCalendar() {
    if (!this.calendarDays || !this.monthDisplay) {
      // console.error("DateTimePicker hook: Cannot render calendar, elements missing.");
      return; // Don't try to render if elements are gone
    }
    
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
    grid.className = 'grid grid-cols-7 gap-1'; // Use gap-1 for consistency with Shadcn
    
    // Use a DocumentFragment for potentially faster appending
    const fragment = document.createDocumentFragment();

    // Add empty cells
    for (let i = 0; i < firstDayIndex; i++) {
      const emptyCell = document.createElement('div');
      // Match styling of button but make non-interactive
      emptyCell.className = 'p-0 h-9 w-9 flex items-center justify-center text-sm opacity-50 cursor-default';
      fragment.appendChild(emptyCell); // Append to fragment
    }
    
    // Add day cells as buttons
    for (let day = 1; day <= daysInMonth; day++) {
      const dayCell = document.createElement('button');
      dayCell.type = 'button'; // Important for accessibility and forms
      // Store day value in a data attribute for the delegated listener
      dayCell.dataset.day = day;
      // Base classes matching SaladUI button variants
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
        // Selected state takes precedence: Primary background
        classes += ' bg-primary text-primary-foreground font-semibold hover:bg-primary/90';
      } else if (isToday) {
        // Today state: Accent background (subtle)
        classes += ' bg-accent/50 font-medium'; // Using slightly transparent accent
      } else {
        // Default state (already includes hover:bg-accent)
      }
      
      dayCell.className = classes;
      // REMOVE individual event listener
      // dayCell.addEventListener('click', (e) => {
      //     e.stopPropagation(); // Prevent calendar closing
      //     this.selectDay(day)
      // });
      
      fragment.appendChild(dayCell); // Append to fragment
    }
    
    // Append the fragment to the grid once
    grid.appendChild(fragment);
    this.calendarDays.appendChild(grid);

    // --- Add Delegated Event Listener --- 
    // Remove previous listener if any to prevent duplicates
    if (this.dayClickListener) {
        this.calendarDays.removeEventListener('click', this.dayClickListener);
    }
    // Store the bound listener function to remove it later if necessary
    this.dayClickListener = this.handleDayClick.bind(this);
    this.calendarDays.addEventListener('click', this.dayClickListener);
  },
  
  // --- New Handler for Delegated Clicks ---
  handleDayClick(e) {
    // Check if the clicked element is a day button (has data-day attribute)
    const targetButton = e.target.closest('button[data-day]');
    if (targetButton && this.calendarDays.contains(targetButton)) {
        e.stopPropagation(); // Prevent calendar closing
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
      // Seconds and milliseconds are usually not needed for a date picker
      newSelectedDate.setSeconds(0);
      newSelectedDate.setMilliseconds(0);
    } else {
      const now = new Date();
      // Default to noon to avoid timezone issues near midnight?
      newSelectedDate.setHours(12, 0, 0, 0); 
      // Or keep previous logic: newSelectedDate.setHours(now.getHours(), now.getMinutes(), 0, 0);
      // We need to trigger an update for the selects if time wasn't set before
      this.updateTimeInputs(newSelectedDate);
    }
    
    this.selectedDate = newSelectedDate;
    this.currentDate = new Date(newSelectedDate); // Keep calendar view consistent
    
    // Update the input display immediately
    this.updateInputValue(); 
    // Re-render calendar to show selection
    this.renderCalendar(); 
    // Let LiveView know about the date part change
    this.pushEventToLiveView(); 
    // Close the calendar after selection
    this.closeCalendar(); 
  },
  
  // New handler for time input changes
  handleTimeInputChange() {
      // Basic validation/update can happen here if needed, 
      // but the main update happens on blur or when date is selected.
      // We call updateDateTime to immediately recalculate and push.
      this.updateDateTime(); 
  },
  
  // Format hour input on blur (e.g., ensure valid range)
  formatHourInput() {
      if (!this.hourInput) return;
      let val = parseInt(this.hourInput.value, 10);
      if (isNaN(val) || val < 1) val = 1;
      if (val > 12) val = 12;
      // Ensure the DOM reflects the validated value before updateDateTime reads it
      this.hourInput.value = val; 
      this.updateDateTime(); // Recalculate with potentially corrected value
  },
  
  // Format minute input on blur (e.g., add padding, ensure range)
  formatMinuteInput() {
      if (!this.minuteInput) return;
      let val = parseInt(this.minuteInput.value, 10);
      if (isNaN(val) || val < 0) val = 0;
      if (val > 59) val = 59;
      // Ensure the DOM reflects the validated value before updateDateTime reads it
      this.minuteInput.value = String(val).padStart(2, '0');
      this.updateDateTime(); // Recalculate with potentially corrected value
  },
  
  // Renamed from triggerSelectUpdates
  updateTimeInputs(date) {
      if (!this.hourInput || !this.minuteInput) return;
      
      let hours = date.getHours();
      let period = "AM"; // Needed for periodSelect update if done client-side
      if (hours === 0) { hours = 12; } 
      else if (hours === 12) { period = "PM"; } 
      else if (hours > 12) { hours -= 12; period = "PM"; }
      
      let minutes = date.getMinutes();
      
      this.hourInput.value = hours;
      this.minuteInput.value = String(minutes).padStart(2, '0');
      
      // If controlling SaladUI Select client-side (less ideal):
      // this.pushEventTo(`#${this.el.id}-period-select`, 'set_value', { value: period });
  },
  
  updateDateTime() {
    if (!this.selectedDate || !this.hourInput || !this.minuteInput) {
        console.warn("updateDateTime called without required elements or selectedDate");
        return;
    }

    // Read values directly from time inputs
    let hours = parseInt(this.hourInput.value, 10);
    let minutes = parseInt(this.minuteInput.value, 10);
    
    // *** Get period reliably from the data attribute ***
    const period = this.el.dataset.period || 'AM'; // Default AM

    if (isNaN(hours) || isNaN(minutes)) {
        console.warn("Invalid time input values");
        // If values are somehow invalid after blur formatting, use defaults
        hours = hours || 12; // Default to 12 if NaN
        minutes = minutes || 0; // Default to 0 if NaN
        // Optionally update the input fields visually too
        this.hourInput.value = hours;
        this.minuteInput.value = String(minutes).padStart(2, '0');
    }
    
    // No need to re-validate ranges here as blur handlers do it.
    
    // Convert from 12-hour to 24-hour for Date object
    let hours24 = hours;
    if (period === "PM" && hours24 < 12) {
      hours24 += 12;
    } else if (period === "AM" && hours24 === 12) {
      hours24 = 0; // Midnight case
    }
    
    // Update the time part of the selectedDate object
    this.selectedDate.setHours(hours24);
    this.selectedDate.setMinutes(minutes);
    this.selectedDate.setSeconds(0, 0); // Reset seconds/ms

    this.updateInputValue();
    this.pushEventToLiveView();
  },
  
  updateInputValue() {
    if (!this.input) return;
    if (!this.selectedDate) {
      this.input.value = this.el.dataset.placeholder || '';
      return;
    }
    
    // Format consistently
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
  
  pushEventToLiveView() {
    try {
      if (!this.selectedDate) {
        console.warn("pushEventToLiveView: No selected date to push.");
        return;
      }
      
      // Ensure seconds are zero for consistency, unless needed
      this.selectedDate.setSeconds(0, 0);
      const isoString = this.selectedDate.toISOString();
      const name = this.el.dataset.name || this.el.id;
      
      // Push change event to the parent LiveView/Component
      this.pushEvent("date_time_picker_change", {
        id: this.el.id,
        name: name,
        value: isoString
      });
    } catch (error) {
      console.error("DateTimePicker hook: Error pushing event", error);
    }
  }
};

export default DateTimePicker; 