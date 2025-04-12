/**
 * BacktestForm hook
 * 
 * Handles the integration between date pickers and the backtest form
 * to ensure date/time values are correctly submitted
 */

const BacktestForm = {
  mounted() {
    this.formElement = this.el;
    
    // Add a submit handler that runs before the LiveView processes the form
    this.formElement.addEventListener('submit', this.handleSubmit.bind(this));
  },
  
  disconnected() {
    // Clean up event listeners
    this.formElement.removeEventListener('submit', this.handleSubmit);
  },
  
  handleSubmit(e) {
    // If this was triggered by a date picker change rather than the submit button, prevent submission
    if (e.submitter !== document.querySelector('#backtest-config-form button[type="submit"]')) {
      e.preventDefault();
      e.stopPropagation();
      return;
    }
    
    // Get references to date picker containers
    const startTimeContainer = document.getElementById('start_time_container');
    const endTimeContainer = document.getElementById('end_time_container');
    
    // Find date picker elements
    const startTimePicker = startTimeContainer?.querySelector('[id^="backtest-start-time"]');
    const endTimePicker = endTimeContainer?.querySelector('[id^="backtest-end-time"]');
    
    // Update start date value
    if (startTimePicker && window.DateTimePickerRegistry && 
        window.DateTimePickerRegistry[startTimePicker.id]) {
      
      const pickerInstance = window.DateTimePickerRegistry[startTimePicker.id];
      const startDateValue = pickerInstance.getCurrentValue();
      
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
      
      if (!endDateValue) {
        console.warn("Warning: end_time value is null or undefined");
      }
      
      // Create/replace hidden input for end_time
      this.createOrUpdateHiddenInput('end_time', endDateValue || '');
    }
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
  },
  
  logFormInputs() {
    const formInputs = this.formElement.querySelectorAll('input[type="hidden"]');
    formInputs.forEach(input => {
      // Do nothing, method kept for potential future debugging
    });
  }
};

export default BacktestForm; 