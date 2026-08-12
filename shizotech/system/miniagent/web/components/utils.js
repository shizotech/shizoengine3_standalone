/* ── Dashboard Ecosystem Shared Utilities ── */

// ════════════════════════════════════════════
//  Dashboard Utilities IIFE
// ════════════════════════════════════════════

(function() {
  // Use DashboardUtils namespace to avoid global conflicts
  window.DashboardUtils = window.DashboardUtils || {};

  // ════════════════════════════════════════════
  //  Date Formatters
  // ════════════════════════════════════════════

  window.DashboardUtils.DateUtils = {
    /**
     * Format date to human-readable string
     * @param {Date|number|string} date - Date to format
     * @param {string} format - Format pattern
     * @returns {string} Formatted date string
     */
    formatDate(date, format = 'medium') {
      const d = new Date(date);
      
      const options = {
        short: { 
          month: 'short', day: 'numeric', year: 'numeric' 
        },
        medium: { 
          month: 'short', day: 'numeric', year: 'numeric', 
          hour: '2-digit', minute: '2-digit' 
        },
        full: { 
          weekday: 'short', month: 'short', day: 'numeric', 
          year: 'numeric', hour: '2-digit', minute: '2-digit' 
        },
        time: {
          hour: '2-digit', minute: '2-digit'
        }
      };
      
      return new Intl.DateTimeFormat('en-US', options[format]).format(d);
    },

    /**
     * Get relative time string
     * @param {Date|number|string} date - Date to compare
     * @returns {string} Relative time string
     */
    fromNow(date) {
      const d = new Date(date);
      const now = new Date();
      const diff = now - d;
      
      const seconds = Math.floor(diff / 1000);
      const minutes = Math.floor(seconds / 60);
      const hours = Math.floor(minutes / 60);
      const days = Math.floor(hours / 24);
      const months = Math.floor(days / 30);
      const years = Math.floor(months / 12);
      
      if (years > 0) return `${years}y ago`;
      if (months > 0) return `${months}mo ago`;
      if (days > 0) return `${days}d ago`;
      if (hours > 0) return `${hours}h ago`;
      if (minutes > 0) return `${minutes}m ago`;
      return 'Just now';
    },

    /**
     * Get time ago string
     * @param {Date|number|string} date - Date to compare
     * @returns {string} Time ago string
     */
    timeAgo(date) {
      const d = new Date(date);
      const now = new Date();
      const diff = now - d;
      
      if (diff < 1000) return 'Just now';
      if (diff < 60000) return '1 minute ago';
      if (diff < 3600000) return `${Math.floor(diff / 60000)} minutes ago`;
      if (diff < 86400000) return `${Math.floor(diff / 3600000)} hours ago`;
      if (diff < 604800000) return `${Math.floor(diff / 86400000)} days ago`;
      return this.formatDate(date, 'medium');
    }
  };

  // ════════════════════════════════════════════
  //  Status Badge Generator
  // ════════════════════════════════════════════

  window.DashboardUtils.StatusBadge = {
    /**
     * Generate status badge HTML
     * @param {string} status - Status type
     * @param {string} text - Display text
     * @returns {string} HTML string
     */
    create(status, text = null) {
      const statusTypes = {
        success: { class: 'success', icon: 'fa-check-circle', color: '#00a884' },
        danger: { class: 'danger', icon: 'fa-times-circle', color: '#8b6c6c' },
        warning: { class: 'warning', icon: 'fa-exclamation-circle', color: '#ffa500' },
        info: { class: 'info', icon: 'fa-info-circle', color: '#00a884' },
        pending: { class: 'info', icon: 'fa-clock', color: '#00a884' }
      };
      
      const type = statusTypes[status] || statusTypes.pending;
      const statusText = text || status.charAt(0).toUpperCase() + status.slice(1);
      
      return `
        <span class="ui-badge ${type.class}">
          <i class="fa-solid ${type.icon}"></i>
          ${statusText}
        </span>
      `;
    },

    /**
     * Generate status dot indicator
     * @param {string} status - Status type
     * @returns {string} HTML string
     */
    dot(status) {
      const statusTypes = {
        success: 'active',
        danger: 'error',
        warning: 'warning',
        info: 'active'
      };
      
      const type = statusTypes[status] || 'active';
      
      return `
        <span class="ui-status-dot ${type}"></span>
      `;
    }
  };

  // ════════════════════════════════════════════
  //  Modal Manager
  // ════════════════════════════════════════════

  window.DashboardUtils.ModalManager = {
    _modals: new Map(),

    /**
     * Create a new modal
     * @param {string} id - Modal ID
     * @param {object} options - Modal options
     * @returns {HTMLElement} Modal element
     */
    create(id, options = {}) {
      const modal = document.createElement('div');
      modal.className = 'ui-modal-overlay';
      modal.id = id;
      
      modal.innerHTML = `
        <div class="ui-modal">
          <div class="ui-modal-header">
            <span class="ui-modal-title">${options.title || 'Modal'}</span>
            <button class="ui-modal-close" aria-label="Close">
              <i class="fa-solid fa-xmark"></i>
            </button>
          </div>
          <div class="ui-modal-body">
            ${options.content || ''}
          </div>
          <div class="ui-modal-footer">
            ${this._createFooter(options.footer || [])}
          </div>
        </div>
      `;
      
      document.body.appendChild(modal);
      this._modals.set(id, modal);
      
      // Setup close handlers
      const closeBtn = modal.querySelector('.ui-modal-close');
      const closeOverlay = (e) => {
        if (e.target === modal || e.key === 'Escape') {
          this.close(id);
        }
      };
      
      closeBtn.addEventListener('click', () => this.close(id));
      modal.addEventListener('click', closeOverlay);
      document.addEventListener('keydown', closeOverlay);
      
      return modal;
    },

    /**
     * Open a modal
     * @param {string} id - Modal ID
     */
    open(id) {
      const modal = this._modals.get(id);
      if (modal) {
        modal.style.display = 'flex';
        // Trigger reflow for animation
        void modal.offsetWidth;
        modal.classList.remove('closing');
      }
    },

    /**
     * Close a modal
     * @param {string} id - Modal ID
     */
    close(id) {
      const modal = this._modals.get(id);
      if (modal) {
        modal.classList.add('closing');
        setTimeout(() => {
          modal.style.display = 'none';
        }, 200);
      }
    },

    /**
     * Close all modals
     */
    closeAll() {
      this._modals.forEach((_, id) => this.close(id));
    },

    /**
     * Create footer buttons
     * @param {array} buttons - Button configurations
     * @returns {string} Footer HTML
     */
    _createFooter(buttons) {
      if (!buttons.length) return '';
      
      return buttons.map(btn => `
        <button class="ui-btn ${btn.class || ''}" data-action="${btn.action || ''}">
          ${btn.icon ? `<i class="fa-solid ${btn.icon}"></i>` : ''}
          ${btn.label}
        </button>
      `).join('');
    }
  };

  // ════════════════════════════════════════════
  //  Storage Utilities
  // ════════════════════════════════════════════

  window.DashboardUtils.StorageUtils = {
    _prefix: 'dashboard_',

    /**
     * Set item in storage
     * @param {string} key - Key
     * @param {*} value - Value
     */
    set(key, value) {
      try {
        const fullKey = `${this._prefix}${key}`;
        if (typeof value === 'object') {
          value = JSON.stringify(value);
        }
        localStorage.setItem(fullKey, value);
      } catch (e) {
        console.error('Storage set error:', e);
      }
    },

    /**
     * Get item from storage
     * @param {string} key - Key
     * @param {*} defaultValue - Default value if not found
     * @returns {*} Stored value or default
     */
    get(key, defaultValue = null) {
      try {
        const fullKey = `${this._prefix}${key}`;
        const value = localStorage.getItem(fullKey);
        if (!value) return defaultValue;
        
        try {
          return JSON.parse(value);
        } catch {
          return value;
        }
      } catch (e) {
        console.error('Storage get error:', e);
        return defaultValue;
      }
    },

    /**
     * Remove item from storage
     * @param {string} key - Key
     */
    remove(key) {
      try {
        const fullKey = `${this._prefix}${key}`;
        localStorage.removeItem(fullKey);
      } catch (e) {
        console.error('Storage remove error:', e);
      }
    },

    /**
     * Clear all dashboard storage
     */
    clear() {
      try {
        const keys = Object.keys(localStorage);
        keys.forEach(key => {
          if (key.startsWith(this._prefix)) {
            localStorage.removeItem(key);
          }
        });
      } catch (e) {
        console.error('Storage clear error:', e);
      }
    }
  };

  // ════════════════════════════════════════════
  //  DOM Utilities
  // ════════════════════════════════════════════

  window.DashboardUtils.DOMUtils = {
    /**
     * Create element with attributes
     * @param {string} tag - Element tag
     * @param {object} options - Attributes and content
     * @returns {HTMLElement} Created element
     */
    create(tag, options = {}) {
      const el = document.createElement(tag);
      
      // Classes
      if (options.classes) {
        el.classList.add(...options.classes);
      }
      
      // Content
      if (options.html) {
        el.innerHTML = options.html;
      } else if (options.text) {
        el.textContent = options.text;
      }
      
      // Attributes
      if (options.attrs) {
        Object.entries(options.attrs).forEach(([key, value]) => {
          el.setAttribute(key, value);
        });
      }
      
      // Styles
      if (options.style) {
        Object.assign(el.style, options.style);
      }
      
      // Event listeners
      if (options.events) {
        Object.entries(options.events).forEach(([event, handler]) => {
          el.addEventListener(event, handler);
        });
      }
      
      return el;
    },

    /**
     * Debounce function
     * @param {Function} fn - Function to debounce
     * @param {number} delay - Delay in ms
     * @returns {Function} Debounced function
     */
    debounce(fn, delay = 300) {
      let timeoutId;
      return (...args) => {
        clearTimeout(timeoutId);
        timeoutId = setTimeout(() => {
          fn.apply(null, args);
        }, delay);
      };
    },

    /**
     * Throttle function
     * @param {Function} fn - Function to throttle
     * @param {number} limit - Limit in ms
     * @returns {Function} Throttled function
     */
    throttle(fn, limit = 100) {
      let inThrottle;
      return (...args) => {
        if (!inThrottle) {
          fn.apply(null, args);
          inThrottle = true;
          setTimeout(() => inThrottle = false, limit);
        }
      };
    },

    /**
     * Get element dimensions
     * @param {HTMLElement} el - Element
     * @returns {object} Width and height
     */
    getDimensions(el) {
      return {
        width: el.offsetWidth,
        height: el.offsetHeight
      };
    },

    /**
     * Scroll to element
     * @param {HTMLElement} el - Element
     * @param {object} options - Scroll options
     */
    scrollTo(el, options = {}) {
      const defaultOptions = {
        behavior: 'smooth',
        block: 'nearest',
        inline: 'nearest'
      };
      
      el.scrollTo({ ...defaultOptions, ...options });
    },

    /**
     * Check if element is in viewport
     * @param {HTMLElement} el - Element
     * @returns {boolean} Whether element is visible
     */
    isInViewport(el) {
      const rect = el.getBoundingClientRect();
      return (
        rect.top >= 0 &&
        rect.left >= 0 &&
        rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) &&
        rect.right <= (window.innerWidth || document.documentElement.clientWidth)
      );
    }
  };

  // ════════════════════════════════════════════
  //  Feature Management (dashboard-wide)
  // ════════════════════════════════════════════

  window.DashboardUtils.FeatureManager = {
    _features: new Map(),
    _onChange: null,

    /**
     * Register a feature
     * @param {string} id - Feature ID
     * @param {object} config - Feature configuration
     */
    register(id, config) {
      this._features.set(id, {
        id,
        enabled: true,
        ...config
      });
      
      if (this._onChange) {
        this._onChange(this.getFeature(id));
      }
    },

    /**
     * Unregister a feature
     * @param {string} id - Feature ID
     */
    unregister(id) {
      this._features.delete(id);
      if (this._onChange) {
        this._onChange(null);
      }
    },

    /**
     * Get a feature
     * @param {string} id - Feature ID
     * @returns {object|null} Feature configuration
     */
    getFeature(id) {
      return this._features.get(id) || null;
    },

    /**
     * Get all features
     * @returns {array} Array of all features
     */
    getAllFeatures() {
      return Array.from(this._features.values());
    },

    /**
     * Enable a feature
     * @param {string} id - Feature ID
     */
    enable(id) {
      const feature = this._features.get(id);
      if (feature) {
        feature.enabled = true;
        if (this._onChange) {
          this._onChange(feature);
        }
      }
    },

    /**
     * Disable a feature
     * @param {string} id - Feature ID
     */
    disable(id) {
      const feature = this._features.get(id);
      if (feature) {
        feature.enabled = false;
        if (this._onChange) {
          this._onChange(feature);
        }
      }
    },

    /**
     * Toggle a feature
     * @param {string} id - Feature ID
     */
    toggle(id) {
      const feature = this._features.get(id);
      if (feature) {
        feature.enabled = !feature.enabled;
        if (this._onChange) {
          this._onChange(feature);
        }
      }
    },

    /**
     * Set change handler
     * @param {Function} handler - Change handler
     */
    onChange(handler) {
      this._onChange = handler;
    }
  };

  // ════════════════════════════════════════════
  //  Bug Management (dashboard-wide)
  // ════════════════════════════════════════════

  window.DashboardUtils.BugManager = {
    _bugs: new Map(),
    _onChange: null,

    /**
     * Register a bug
     * @param {string} id - Bug ID
     * @param {object} bug - Bug data
     */
    register(id, bug) {
      this._bugs.set(id, {
        id,
        createdAt: Date.now(),
        ...bug
      });
      
      if (this._onChange) {
        this._onChange(this.getBug(id));
      }
    },

    /**
     * Update a bug
     * @param {string} id - Bug ID
     * @param {object} updates - Bug updates
     */
    update(id, updates) {
      const bug = this._bugs.get(id);
      if (bug) {
        Object.assign(bug, updates, { updatedAt: Date.now() });
        this._bugs.set(id, bug);
        
        if (this._onChange) {
          this._onChange(bug);
        }
      }
    },

    /**
     * Delete a bug
     * @param {string} id - Bug ID
     */
    delete(id) {
      this._bugs.delete(id);
      if (this._onChange) {
        this._onChange(null);
      }
    },

    /**
     * Get a bug
     * @param {string} id - Bug ID
     * @returns {object|null} Bug data
     */
    getBug(id) {
      return this._bugs.get(id) || null;
    },

    /**
     * Get all bugs
     * @returns {array} Array of all bugs
     */
    getAllBugs() {
      return Array.from(this._bugs.values());
    },

    /**
     * Set change handler
     * @param {Function} handler - Change handler
     */
    onChange(handler) {
      this._onChange = handler;
    },

    /**
     * Get bugs by status
     * @param {string} status - Status filter
     * @returns {array} Filtered bugs
     */
    getByStatus(status) {
      return this.getAllBugs().filter(b => b.status === status);
    },

    /**
     * Get bugs by priority
     * @param {string} priority - Priority filter
     * @returns {array} Filtered bugs
     */
    getByPriority(priority) {
      return this.getAllBugs().filter(b => b.priority === priority);
    }
  };

  // ════════════════════════════════════════════
  //  History Manager (dashboard-wide)
  // ════════════════════════════════════════════

  window.DashboardUtils.HistoryManager = {
    _history: [],
    _onChange: null,

    /**
     * Add to history
     * @param {object} action - Action data
     */
    add(action) {
      const entry = {
        id: `history_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
        timestamp: Date.now(),
        ...action
      };
      
      this._history.unshift(entry);
      
      // Keep only last 1000 entries
      if (this._history.length > 1000) {
        this._history = this._history.slice(0, 1000);
      }
      
      if (this._onChange) {
        this._onChange(entry);
      }
    },

    /**
     * Get history entries
     * @param {object} options - Filter options
     * @returns {array} Filtered history
     */
    getEntries(options = {}) {
      let entries = [...this._history];
      
      if (options.type) {
        entries = entries.filter(e => e.type === options.type);
      }
      
      if (options.startTime) {
        entries = entries.filter(e => e.timestamp >= options.startTime);
      }
      
      if (options.endTime) {
        entries = entries.filter(e => e.timestamp <= options.endTime);
      }
      
      return entries;
    },

    /**
     * Revert an action
     * @param {string} historyId - History entry ID
     * @returns {object} Revert result
     */
    revert(historyId) {
      const entry = this._history.find(e => e.id === historyId);
      if (entry && entry.revertAction) {
        try {
          const result = entry.revertAction(entry);
          
          this.add({
            type: 'revert',
            description: `Reverted: ${entry.description}`,
            originalAction: entry,
            result
          });
          
          return { success: true, result };
        } catch (e) {
          return { success: false, error: e.message };
        }
      }
      
      return { success: false, error: 'No revert action available' };
    },

    /**
     * Clear history
     * @param {number} keepCount - Number of entries to keep
     */
    clear(keepCount = 0) {
      if (keepCount > 0) {
        this._history = this._history.slice(0, keepCount);
      } else {
        this._history = [];
      }
      
      if (this._onChange) {
        this._onChange(null);
      }
    },

    /**
     * Set change handler
     * @param {Function} handler - Change handler
     */
    onChange(handler) {
      this._onChange = handler;
    }
  };

  // ════════════════════════════════════════════
  //  Initialization
  // ════════════════════════════════════════════

  document.addEventListener('DOMContentLoaded', () => {
    // Global modal close on Escape key
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        window.DashboardUtils.ModalManager.closeAll();
      }
    });
  });

})();
