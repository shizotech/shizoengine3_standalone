/* ── Dashboard Ecosystem Logic ── */

// ════════════════════════════════════════════
//  Dashboard State
// ════════════════════════════════════════════

const DashboardState = {
  currentModule: 'chat',
  modules: new Map(),
  sidebarVisible: true,
  theme: 'dark',
  workMode: false,
  notifications: 0,

  // Initialize dashboard state
  init() {
    this.modules.set('chat', { title: 'Chat', active: true });
    this.modules.set('features', { title: 'Features', active: false });
    this.modules.set('history', { title: 'History', active: false }); 
    this.modules.set('settings', { title: 'Settings', active: false });
  },

  // Switch to a different module
  switchModule(moduleName) {
    // Update current module
    this.modules.forEach((mod, name) => {
      mod.active = name === moduleName;
    });
    
    this.currentModule = moduleName;
    this.updateUI();
    this.updateURL(moduleName);
  },

  // Update UI based on current state
  updateUI() {
    // Update module visibility
    document.querySelectorAll('.module').forEach(el => {
      el.classList.remove('active');
    });
    
    const activeModule = document.getElementById(`${this.currentModule}Module`);
    if (activeModule) {
      activeModule.classList.add('active');
    }

    // Update navigation
    document.querySelectorAll('.nav-item').forEach(el => {
      el.classList.remove('active');
      if (el.dataset.module === this.currentModule) {
        el.classList.add('active');
      }
    });

    // Update dashboard title
    const module = this.modules.get(this.currentModule);
    const titleEl = document.getElementById('dashboardTitle');
    if (titleEl && module) {
      titleEl.textContent = module.title;
    }
  },

  // Update URL with module
  updateURL(moduleName) {
    if (typeof history !== 'undefined' && history.pushState) {
      const url = new URL(window.location.href);
      url.searchParams.set('module', moduleName);
      history.pushState({ module: moduleName }, '', url);
    }
  },

  // Handle theme toggle
  toggleTheme() {
    this.theme = this.theme === 'dark' ? 'light' : 'dark';
    this.applyTheme();
    this.saveTheme();
  },

  // Apply theme to document
  applyTheme() {
    if (this.theme === 'light') {
      document.body.classList.add('theme-light');
    } else {
      document.body.classList.remove('theme-light');
    }
  },

  // Save theme preference
  saveTheme() {
    localStorage.setItem('dashboard_theme', this.theme);
  },

  // Load saved theme
  loadTheme() {
    const savedTheme = localStorage.getItem('dashboard_theme');
    if (savedTheme) {
      this.theme = savedTheme;
    }
    this.applyTheme();
  },

  // Toggle work mode
   async toggleWorkMode() {
     this.workMode = !this.workMode;
     
     // Update UI immediately for responsiveness
     this.updateWorkModeIcon();
     
     try {
       // Call backend API to persist work mode state
       const res = await fetch('/api/workmode', {
         method: 'PUT',
         headers: { 'Content-Type': 'application/json' },
         body: JSON.stringify({ enabled: this.workMode })
       });
       
       if (!res.ok) {
         throw new Error(`Server error: ${res.status}`);
       }
       
       const data = await res.json();
       if (data.ok) {
         // Save to localStorage as backup
         this.saveWorkMode();
         console.log('Work mode toggled and synced with backend:', this.workMode);
       } else {
         throw new Error(data.error || 'Backend rejected the request');
       }
     } catch (error) {
       console.error('Failed to sync work mode with backend:', error);
       // Revert UI on error to maintain consistency
       this.workMode = !this.workMode;
       this.updateWorkModeIcon();
     }
   },

  // Save work mode preference
  saveWorkMode() {
    localStorage.setItem('dashboard_workmode', JSON.stringify(this.workMode));
  },

  // Load saved work mode
   loadWorkMode() {
     const savedWorkMode = localStorage.getItem('dashboard_workmode');
     if (savedWorkMode !== null) {
       this.workMode = JSON.parse(savedWorkMode);
     }
     this.updateWorkModeIcon();
   },

   // Load work mode from server
   async loadWorkModeFromServer() {
     try {
       const res = await fetch('/api/workmode', {
         method: 'GET',
         headers: { 'Content-Type': 'application/json' }
       });
       
       if (!res.ok) {
         throw new Error(`Server error: ${res.status}`);
       }
       
       const data = await res.json();
       if (data.ok && data.data && data.data.enabled !== undefined) {
         this.workMode = data.data.enabled;
         this.saveWorkMode();
       }
     } catch (error) {
       console.error('Work Mode API Error:', error);
       // Fall back to localStorage on error
       const savedWorkMode = localStorage.getItem('dashboard_workmode');
       if (savedWorkMode !== null) {
         this.workMode = JSON.parse(savedWorkMode);
       }
     }
     this.updateWorkModeIcon();
   },

  // Update work mode icon
  updateWorkModeIcon() {
    const btn = document.getElementById('btnWorkMode');
    if (!btn) return;
    
    if (this.workMode) {
      btn.querySelector('i').className = 'fa-solid fa-play';
      btn.classList.remove('workmode-stopped');
      btn.classList.add('workmode-active');
    } else {
      btn.querySelector('i').className = 'fa-solid fa-pause';
      btn.classList.remove('workmode-active');
      btn.classList.add('workmode-stopped');
    }
  },

  // Update notification badge
  updateNotifications(count) {
    this.notifications = count;
    const badge = document.getElementById('notificationBadge');
    if (badge) {
      badge.textContent = count > 0 ? count : '';
      badge.style.display = count > 0 ? 'flex' : 'none';
    }
  }
};

// ════════════════════════════════════════════
//  Module Manager
// ════════════════════════════════════════════

const ModuleManager = {
  modules: new Map(),

  // Register a module
  register(name, moduleConfig) {
    this.modules.set(name, moduleConfig);
  },

  // Load a module
  load(name, containerId) {
    const module = this.modules.get(name);
    if (module) {
      const container = document.getElementById(containerId);
      if (container && module.iframeSrc) {
        const iframe = container.querySelector('iframe');
        if (iframe) {
          iframe.src = module.iframeSrc;
        }
      }
    }
  },

  // Unload a module
  unload(name) {
    const module = this.modules.get(name);
    if (module) {
      const container = document.getElementById(`${name}Module`);
      if (container) {
        const iframe = container.querySelector('iframe');
        if (iframe) {
          iframe.src = 'about:blank';
        }
      }
    }
  },

  // Initialize all modules
  init() {
    this.modules.forEach((module, name) => {
      this.load(name, `${name}Module`);
    });
  }
};

// ════════════════════════════════════════════
//  Sidebar Manager
// ════════════════════════════════════════════

const SidebarManager = {
  sidebar: document.getElementById('sidebar'),
  overlay: document.getElementById('sidebarOverlay'),
  toggleBtn: document.getElementById('btnToggleSidebar'),
  toggleBtnMobile: document.getElementById('btnToggleSidebarMobile'),

  // Initialize sidebar
  init() {
    this.setupToggleListeners();
    this.setupMobileClose();
  },

  // Toggle sidebar visibility
  toggle() {
    this.sidebar.classList.toggle('collapsed');
    
    if (this.sidebar.classList.contains('collapsed')) {
      this.overlay.classList.remove('visible');
    } else {
      this.overlay.classList.add('visible');
    }
    
    DashboardState.sidebarVisible = !this.sidebar.classList.contains('collapsed');
  },

  // Setup toggle button listeners
  setupToggleListeners() {
    if (this.toggleBtn) {
      this.toggleBtn.addEventListener('click', () => this.toggle());
    }
    
    if (this.toggleBtnMobile) {
      this.toggleBtnMobile.addEventListener('click', () => this.toggle());
    }
  },

  // Setup mobile overlay close
  setupMobileClose() {
    if (this.overlay) {
      this.overlay.addEventListener('click', () => {
        this.sidebar.classList.add('collapsed');
        this.overlay.classList.remove('visible');
        DashboardState.sidebarVisible = false;
      });
    }
  },

  // Set visibility
  setVisible(visible) {
    if (visible) {
      this.sidebar.classList.remove('collapsed');
      this.overlay.classList.remove('visible');
    } else {
      this.sidebar.classList.add('collapsed');
      this.overlay.classList.add('visible');
    }
    DashboardState.sidebarVisible = visible;
  },

  // Get visibility
  isVisible() {
    return DashboardState.sidebarVisible;
  }
};

// ════════════════════════════════════════════
//  Navigation Manager
// ════════════════════════════════════════════

const NavigationManager = {
  navItems: document.querySelectorAll('.nav-item'),

  // Initialize navigation
  init() {
    this.setupNavigationListeners();
    this.setupSecondaryButtons();
    this.loadInitialModule();
  },

  // Setup navigation item listeners
  setupNavigationListeners() {
    this.navItems.forEach(item => {
      item.addEventListener('click', (e) => {
        const module = item.dataset.module;
        if (module) {
          this.activateModule(module);
        }
      });
    });
  },

  // Setup secondary buttons
  setupSecondaryButtons() {
    const clearDataBtn = document.getElementById('btnClearData');
    if (clearDataBtn) {
      clearDataBtn.addEventListener('click', () => {
        ModalManager.create('clearDataModal', {
          title: 'Clear Dashboard Data',
          content: '<p>Are you sure you want to clear all dashboard data? This action cannot be undone.</p>',
          footer: [
            { label: 'Cancel', action: 'close' },
            { label: 'Clear Data', class: 'ui-btn-danger', action: 'clear' }
          ]
        });
        
        const modal = document.getElementById('clearDataModal');
        if (modal) {
          const clearBtn = modal.querySelector('[data-action="clear"]');
          if (clearBtn) {
            clearBtn.addEventListener('click', () => {
              this.clearAllData();
              ModalManager.close('clearDataModal');
            });
          }
        }
        
        ModalManager.open('clearDataModal');
      });
    }

    const themeToggleBtn = document.getElementById('btnThemeToggle');
    if (themeToggleBtn) {
      themeToggleBtn.addEventListener('click', () => {
        DashboardState.toggleTheme();
        this.updateThemeIcon();
      });
    }
    
    const workModeBtn = document.getElementById('btnWorkMode');
    if (workModeBtn) {
      workModeBtn.addEventListener('click', async () => {
        await DashboardState.toggleWorkMode();
      });
    }
  },

  // Activate a module
  activateModule(module) {
    DashboardState.switchModule(module);
  },

  // Load initial module from URL
  loadInitialModule() {
    const urlParams = new URLSearchParams(window.location.search);
    const module = urlParams.get('module');
    
    if (module && DashboardState.modules.has(module)) {
      DashboardState.switchModule(module);
    }
  },

  // Clear all dashboard data
  clearAllData() {
    window.DashboardUtils.StorageUtils.clear();
    window.DashboardUtils.HistoryManager.clear();
    
    // Clear conversation data
    localStorage.removeItem('shizolocal_conversations');
    localStorage.removeItem('shizolocal_active_id');
    
    // Clear feature and bug data
    localStorage.removeItem('dashboard_features');
    localStorage.removeItem('dashboard_bugs');
    
    // Clear history data
    localStorage.removeItem('dashboard_history');
    
    // Clear settings
    localStorage.removeItem('dashboard_theme');
    
    // Clear chat iframe data
    const chatFrame = document.getElementById('chatFrame');
    if (chatFrame) {
      chatFrame.src = chatFrame.src;
    }
    
    // Show confirmation
    alert('All dashboard data has been cleared!');
  },

  // Update theme toggle icon
  updateThemeIcon() {
    const themeToggleBtn = document.getElementById('btnThemeToggle');
    if (themeToggleBtn && DashboardState.theme === 'light') {
      themeToggleBtn.querySelector('i').className = 'fa-solid fa-sun';
      themeToggleBtn.querySelector('span').textContent = 'Light Mode';
    } else if (themeToggleBtn) {
      themeToggleBtn.querySelector('i').className = 'fa-solid fa-moon';
      themeToggleBtn.querySelector('span').textContent = 'Dark Mode';
    }
  }
};

// ════════════════════════════════════════════
//  Module Integration Events
// ════════════════════════════════════════════

const ModuleEvents = {
  // Listen for chat events
  chat: {
    notificationCount: 0,
    
    // Handle chat notification
    onNotification(count) {
      this.notificationCount = count;
      DashboardState.updateNotifications(count);
    }
  },

  // Listen for features events
  features: {
    onFeatureAdded(feature) {
      // Sync with dashboard-wide feature manager
      window.DashboardUtils.FeatureManager.register(feature.id, feature);
    },

    onFeatureUpdated(feature) {
      window.DashboardUtils.FeatureManager.update(feature.id, feature);
    }
  },

  // Listen for history events
  history: {
    onActionAdded(action) {
      // Sync with dashboard-wide history manager
      window.DashboardUtils.HistoryManager.add(action);
    }
  },

  // Initialize all module event listeners
  init() {
    // Listen for window messages from iframes
    window.addEventListener('message', (e) => {
      if (e.data && e.data.type && e.data.module) {
        const handler = this[e.data.module]?.[e.data.type];
        if (handler) {
          handler(e.data.payload);
        }
      }
    });
  }
};



// ════════════════════════════════════════════
//  Dashboard Initialization
// ════════════════════════════════════════════

const Dashboard = {
  // Initialize dashboard
  init() {
    // Initialize state
    DashboardState.init();
    
    // Initialize managers
    SidebarManager.init();
    NavigationManager.init();
    ModuleEvents.init();
    
    // Load saved theme
    DashboardState.loadTheme();
    NavigationManager.updateThemeIcon();
    
    // Load work mode from server (with localStorage fallback)
    DashboardState.loadWorkModeFromServer();
    DashboardState.updateWorkModeIcon();
    
    // Initialize module manager
    ModuleManager.register('chat', { iframeSrc: 'chat/index.html' });
    ModuleManager.register('features', { iframeSrc: 'features/index.html' });
    ModuleManager.register('history', { iframeSrc: 'history/index.html' });
    ModuleManager.register('settings', { iframeSrc: 'settings/index.html' });
    
    ModuleManager.init();
    
    
    
    
    
    // Setup hidden button in settings section
    const hiddenBtn = document.getElementById('btnSecretEgg');
    if (hiddenBtn) {
      hiddenBtn.addEventListener('click', () => {
        const container = document.getElementById('cowLaysEggsModule');
        if (container) {
          container.classList.toggle('active');
          if (container.classList.contains('active')) {
            // Load iframe when shown
            const iframe = container.querySelector('iframe');
            if (iframe && iframe.src === '') {
              iframe.src = 'cow_lays_eggs.html';
            }
          }
        }
      });
    }
    
    // Log initialization
    console.log('Dashboard Ecosystem initialized');
    console.log('Active modules:', Array.from(DashboardState.modules.keys()));
  },

  // Register module
  registerModule(name, config) {
    ModuleManager.register(name, config);
  },

  // Get current module
  getCurrentModule() {
    return DashboardState.currentModule;
  },

  // Switch module programmatically
  switchModule(module) {
    DashboardState.switchModule(module);
  }
};

// ════════════════════════════════════════════
//  Event Listeners for Dashboard-wide Events
// ════════════════════════════════════════════

document.addEventListener('DOMContentLoaded', () => {
  Dashboard.init();
});

// Listen for module messages
window.addEventListener('message', (e) => {
  if (e.data && e.data.type) {
    switch (e.data.type) {
      case 'notification':
        if (e.data.module === 'chat') {
          ModuleEvents.chat.onNotification(e.data.payload?.count || 0);
        }
        break;
      case 'featureAdded':
        if (e.data.module === 'features') {
          ModuleEvents.features.onFeatureAdded(e.data.payload);
        }
        break;
      case 'featureUpdated':
        if (e.data.module === 'features') {
          ModuleEvents.features.onFeatureUpdated(e.data.payload);
        }
        break;
      case 'actionAdded':
        if (e.data.module === 'history') {
          ModuleEvents.history.onActionAdded(e.data.payload);
        }
        break;
    }
  }
});
