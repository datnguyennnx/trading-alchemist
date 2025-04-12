/**
 * LiveView Hook for DateTimePicker
 * Integrates the core date picker with LiveView
 */

import DatePickerCore from './core';

const DatePickerHook = {
  mounted() {
    // Initialize core date picker
    this.state = DatePickerCore.init(this.el);
    
    // Store suppressEvents flag
    this.suppressEvents = this.el.dataset.suppressEvents === 'true';
    
    // Register in global registry for form access
    if (!window.DateTimePickerRegistry) {
      window.DateTimePickerRegistry = {};
    }
    window.DateTimePickerRegistry[this.el.id] = this;
    
    // Set up onChange handler for date picker
    this.state.onChange = (date) => {
      // Only push event if events are not suppressed
      if (!this.suppressEvents) {
        this.pushEventToLiveView(date);
      }
    };
    
    // Setup forms integration
    this.setupFormIntegration();
  },
  
  updated() {
    // Re-initialize if necessary (DOM changes)
    if (!this.state) {
      this.state = DatePickerCore.init(this.el);
      return;
    }
    
    // Update state with current suppressEvents flag
    this.suppressEvents = this.el.dataset.suppressEvents === 'true';
  },
  
  destroyed() {
    // Clean up event listeners
    if (this.state) {
      DatePickerCore.destroy(this.state);
    }
    
    // Remove from registry
    if (window.DateTimePickerRegistry && window.DateTimePickerRegistry[this.el.id]) {
      delete window.DateTimePickerRegistry[this.el.id];
    }
  },
  
  setupFormIntegration() {
    // Find closest form and add submit handler
    const closestForm = this.el.closest('form');
    if (closestForm) {
      this.formElement = closestForm;
      
      // Only add listener if form doesn't already have one
      if (!closestForm._datePickerSubmitListenerAdded) {
        closestForm.addEventListener('submit', (e) => {
          this.pushDateTimeValue();
        });
        
        // Mark form as having listener to prevent duplicates
        closestForm._datePickerSubmitListenerAdded = true;
      }
    }
  },
  
  pushEventToLiveView(date) {
    // No-op if events are suppressed
    if (this.suppressEvents) {
      return;
    }
    
    // Otherwise push event to LiveView
    try {
      const isoString = date ? date.toISOString() : this.getCurrentValue();
      if (!isoString) return;
      
      const name = this.el.dataset.name || this.el.id;
      
      this.pushEvent("date_time_picker_change", {
        id: this.el.id,
        name: name,
        value: isoString
      });
    } catch (error) {
      console.error("DateTimePicker hook: Error pushing event", error);
    }
  },
  
  pushDateTimeValue() {
    // Create/update hidden input with current date value
    try {
      const isoString = this.getCurrentValue();
      if (!isoString) return null;
      
      const name = this.el.dataset.name || this.el.id;
      
      // Create a new hidden input
      const hiddenInput = document.createElement('input');
      hiddenInput.type = 'hidden';
      hiddenInput.name = name;
      hiddenInput.value = isoString;
      
      // Replace existing or add new
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
  
  getCurrentValue() {
    // Try to get value from state
    if (this.state) {
      return DatePickerCore.getISOValue(this.state);
    }
    
    // Fallbacks if state is not available
    const dataValue = this.el.dataset.value;
    if (dataValue) {
      try {
        const date = new Date(dataValue);
        if (!isNaN(date.getTime())) {
          return date.toISOString();
        }
      } catch (e) {
        console.error("Error parsing date from data-value", e);
      }
    }
    
    // Input fallback
    const input = this.el.querySelector(`#${this.el.id}-input`);
    if (input && input.value) {
      try {
        const date = new Date(input.value);
        if (!isNaN(date.getTime())) {
          return date.toISOString();
        }
      } catch (e) {
        console.error("Error parsing date from input", e);
      }
    }
    
    return null;
  }
};

export default DatePickerHook; 