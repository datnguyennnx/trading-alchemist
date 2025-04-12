/**
 * BacktestForm hook
 * 
 * Handles the integration between date pickers and the backtest form
 * to ensure date/time values are correctly submitted
 */

const BacktestForm = {
  mounted() {
    console.log("BacktestForm hook mounted on", this.el.id);
    this.formElement = this.el;
    
    // Add a submit handler that runs before the LiveView processes the form
    this.formElement.addEventListener('submit', this.handleSubmit.bind(this));
  },
  
  disconnected() {
    // Clean up event listeners
    this.formElement.removeEventListener('submit', this.handleSubmit);
  },
  
  handleSubmit(e) {
    console.log("Backtest form submission intercepted");
    
    // If this was triggered by a date picker change rather than the submit button, prevent submission
    if (e.submitter !== document.querySelector('#backtest-config-form button[type="submit"]')) {
      console.log("Preventing submission - not triggered by submit button");
      e.preventDefault();
      e.stopPropagation();
      return;
    }
    
    // Get references to date picker containers
    const startTimeContainer = document.getElementById('start_time_container');
    const endTimeContainer = document.getElementById('end_time_container');
    
    console.log("Start time container:", startTimeContainer);
    console.log("End time container:", endTimeContainer);
    
    // Find date picker elements
    const startTimePicker = startTimeContainer?.querySelector('[id^="backtest-start-time"]');
    const endTimePicker = endTimeContainer?.querySelector('[id^="backtest-end-time"]');
    
    console.log("Start time picker:", startTimePicker?.id);
    console.log("End time picker:", endTimePicker?.id);
    
    // Update start date value
    if (startTimePicker && window.DateTimePickerRegistry && 
        window.DateTimePickerRegistry[startTimePicker.id]) {
      
      const pickerInstance = window.DateTimePickerRegistry[startTimePicker.id];
      const startDateValue = pickerInstance.getCurrentValue();
      console.log("Setting start_time value:", startDateValue);
      
      if (!startDateValue) {
        console.warn("Warning: start_time value is null or undefined");
      }
      
      // Create/replace hidden input for start_time
      this.createOrUpdateHiddenInput('start_time', startDateValue || '');
    }
    
    // Update end date value
    if (endTimePicker && window.DateTimePickerRegistry && 
        window.DateTimePickerRegistry[endTimePicker.id]) {
      
      const pickerInstance = window.DateTimePickerRegistry[endTimePicker.id];
      const endDateValue = pickerInstance.getCurrentValue();
      console.log("Setting end_time value:", endDateValue);
      
      if (!endDateValue) {
        console.warn("Warning: end_time value is null or undefined");
      }
      
      // Create/replace hidden input for end_time
      this.createOrUpdateHiddenInput('end_time', endDateValue || '');
    }
    
    // Log all form inputs for debugging
    this.logFormInputs();
  },
  
  createOrUpdateHiddenInput(name, value) {
    // Remove existing field if present
    const oldInput = this.formElement.querySelector(`input[name="${name}"]`);
    if (oldInput) {
      oldInput.remove();
    }
    
    // Create new hidden input
    const hiddenInput = document.createElement('input');
    hiddenInput.type = 'hidden';
    hiddenInput.name = name;
    hiddenInput.value = value;
    this.formElement.appendChild(hiddenInput);
    
    console.log(`Added hidden input for ${name}:`, hiddenInput);
  },
  
  logFormInputs() {
    const formInputs = this.formElement.querySelectorAll('input[type="hidden"]');
    console.log("Form hidden inputs count:", formInputs.length);
    formInputs.forEach(input => {
      console.log(`Input ${input.name}: ${input.value}`);
    });
  }
};

export default BacktestForm; 