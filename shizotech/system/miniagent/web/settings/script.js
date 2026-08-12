// ════════════════════════════════════════════
//  Settings Module
// ════════════════════════════════════════════
// Provides settings management for:
// - Max Active Agents
// - Agent Check Interval

// ════════════════════════════════════════════
//  Settings API Client
// ════════════════════════════════════════════

const SettingsAPI = {
  // Get settings from server
  async getSettings() {
    try {
      const res = await fetch('/api/settings', {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' }
      });
      
      if (!res.ok) {
        throw new Error(`Server error: ${res.status}`);
      }
      
      const data = await res.json();
      return { ok: data.ok, data: data.data, error: data.error };
    } catch (error) {
      console.error('Settings API Error:', error);
      return { ok: false, error: error.message };
    }
  },
  
  // Update settings on server
  async updateSettings(settings) {
    try {
      const res = await fetch('/api/settings', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(settings)
      });
      
      if (!res.ok) {
        throw new Error(`Server error: ${res.status}`);
      }
      
      const data = await res.json();
      return { ok: data.ok, data: data.data, error: data.error };
    } catch (error) {
      console.error('Settings API Error:', error);
      return { ok: false, error: error.message };
    }
  }
};

// ════════════════════════════════════════════
//  Settings Manager
// ════════════════════════════════════════════

const SettingsManager = {
  // Storage keys
  STORAGE_KEYS: {
    SETTINGS: 'settings_dashboard'
  },
  
  // Default settings
  defaults: {
    maxActiveAgents: 5,
    checkInterval: 5000
  },
  
  // Settings state
  settings: null,
  
  // Load settings from localStorage
  loadSettings() {
    try {
      const stored = localStorage.getItem(this.STORAGE_KEYS.SETTINGS);
      if (stored) {
        this.settings = JSON.parse(stored);
        console.log('Settings loaded from localStorage:', this.settings);
      } else {
        this.settings = { ...this.defaults };
        console.log('Using default settings:', this.settings);
      }
    } catch (error) {
      console.error('Error loading settings:', error);
      this.settings = { ...this.defaults };
    }
  },
  
  // Save settings to localStorage
  saveSettings() {
    try {
      localStorage.setItem(this.STORAGE_KEYS.SETTINGS, JSON.stringify(this.settings));
      console.log('Settings saved to localStorage:', this.settings);
    } catch (error) {
      console.error('Error saving settings:', error);
    }
  },
  
  // Update settings
  updateSettings(newSettings) {
    this.settings = { ...this.settings, ...newSettings };
    this.saveSettings();
    console.log('Settings updated:', this.settings);
  },
  
  // Validate settings
  validateSettings() {
    const maxAgents = parseInt(this.settings.maxActiveAgents, 10);
    const checkInterval = parseInt(this.settings.checkInterval, 10);
    
    const errors = [];
    
    if (isNaN(maxAgents) || maxAgents < 1 || maxAgents > 100) {
      errors.push('Max Active Agents must be between 1 and 100');
    }
    
    if (isNaN(checkInterval) || checkInterval < 1000) {
      errors.push('Check Interval must be at least 1000ms');
    }
    
    return errors;
  }
};

// ════════════════════════════════════════════
//  Settings UI Controller
// ════════════════════════════════════════════

const SettingsUI = {
  elements: {
    form: null,
    maxActiveAgents: null,
    checkInterval: null,
    btnSave: null,
    settingsStatus: null
  },
  
  init() {
    // Cache DOM elements
    this.elements.form = document.getElementById('settingsForm');
    this.elements.maxActiveAgents = document.getElementById('maxActiveAgents');
    this.elements.checkInterval = document.getElementById('checkInterval');
    this.elements.btnSave = document.getElementById('btnSaveSettings');
    this.elements.settingsStatus = document.getElementById('settingsStatus');
    
    if (!this.elements.form) {
      console.error('Settings form not found');
      return;
    }
    
    this.bindEvents();
    this.loadInitialSettings();
  },
  
  bindEvents() {
    // Form submission
    if (this.elements.form) {
      this.elements.form.addEventListener('submit', (e) => {
        e.preventDefault();
        this.handleSave();
      });
    }
    
    // Save button
    if (this.elements.btnSave) {
      this.elements.btnSave.addEventListener('click', () => {
        this.handleSave();
      });
    }
  },
  
  async loadInitialSettings() {
    // Load from localStorage first
    SettingsManager.loadSettings();
    
    // Populate form with settings
    this.elements.maxActiveAgents.value = SettingsManager.settings.maxActiveAgents;
    this.elements.checkInterval.value = SettingsManager.settings.checkInterval;
    
    // Load from server
    await this.fetchFromServer();
  },
  
  async fetchFromServer() {
    // Get settings from server
    const settingsResult = await SettingsAPI.getSettings();
    if (settingsResult.ok && settingsResult.data) {
      this.elements.maxActiveAgents.value = settingsResult.data.maxActiveAgents;
      this.elements.checkInterval.value = settingsResult.data.checkInterval;
      SettingsManager.settings = { ...settingsResult.data };
    }
  },
  
  async handleSave() {
    // Validate settings
    const errors = SettingsManager.validateSettings();
    
    if (errors.length > 0) {
      this.showStatus('error', 'Validation Error', errors.join('\n'));
      return;
    }
    
    // Get values from form
    const maxActiveAgents = parseInt(this.elements.maxActiveAgents.value, 10);
    const checkInterval = parseInt(this.elements.checkInterval.value, 10);
    
    // Update local manager
    SettingsManager.updateSettings({
      maxActiveAgents,
      checkInterval
    });
    
    // Show saving status
    this.showStatus('loading', 'Saving Settings', 'Updating dashboard configuration...');
    
    // Send to server
    const result = await SettingsAPI.updateSettings({
      maxActiveAgents,
      checkInterval
    });
    
    if (result.ok) {
      this.showStatus('success', 'Settings Saved', 'Configuration updated successfully');
    } else {
      this.showStatus('error', 'Save Failed', result.error || 'Failed to save settings');
    }
  },
  
  showStatus(type, title, message) {
    if (!this.elements.settingsStatus) return;
    
    const content = this.elements.settingsStatus.querySelector('.status-content');
    const iconEl = content.querySelector('.status-icon');
    const titleEl = content.querySelector('.status-title');
    const msgEl = content.querySelector('.status-message');
    
    // Set type
    this.elements.settingsStatus.style.display = 'block';
    
    if (type === 'success') {
      iconEl.className = 'status-icon success';
      iconEl.innerHTML = '<i class="fa-solid fa-check"></i>';
      this.elements.settingsStatus.style.borderColor = 'rgba(0, 168, 132, 0.3)';
    } else if (type === 'error') {
      iconEl.className = 'status-icon error';
      iconEl.innerHTML = '<i class="fa-solid fa-xmark"></i>';
      this.elements.settingsStatus.style.borderColor = 'rgba(139, 108, 108, 0.3)';
    } else {
      iconEl.className = 'status-icon';
      iconEl.innerHTML = '<i class="fa-solid fa-circle-notch fa-spin"></i>';
      this.elements.settingsStatus.style.borderColor = 'var(--accent)';
    }
    
    // Update text
    titleEl.textContent = title;
    msgEl.textContent = message;
    
    // Auto-hide after 3 seconds (except for loading)
    if (type !== 'loading') {
      setTimeout(() => {
        this.elements.settingsStatus.style.display = 'none';
      }, 3000);
    }
  }
};

// ════════════════════════════════════════════
//  Module Initialization
// ════════════════════════════════════════════

document.addEventListener('DOMContentLoaded', () => {
  console.log('Settings module initialized');
  SettingsUI.init();
});
