/* ── History Dashboard Logic ── */

// ════════════════════════════════════════════
//  History Module IIFE
// ════════════════════════════════════════════

(function() {
  // Use DashboardHistory namespace to avoid global conflicts
  window.DashboardHistory = window.DashboardHistory || {};

  // ════════════════════════════════════════════
  //  Backend API Client
  // ════════════════════════════════════════════

  window.DashboardHistory.API = {
    baseUrl: 'http://localhost:13337',
    
    // Fetch all history entries from backend
    async list() {
      try {
        const response = await fetch(`${this.baseUrl}/api/history/list`);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data = await response.json();
        if (data.ok) return data.data || [];
        throw new Error(data.error || 'Failed to fetch history');
      } catch (e) {
        console.error('Error fetching history:', e);
        return [];
      }
    },
    
    // Fetch specific history entry by ID
    async get(historyId) {
      try {
        const response = await fetch(`${this.baseUrl}/api/history/${encodeURIComponent(historyId)}`);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data = await response.json();
        if (data.ok) return data.data || null;
        throw new Error(data.error || 'History entry not found');
      } catch (e) {
        console.error('Error fetching history entry:', e);
        return null;
      }
    },
    
    // Create new history entry
    async create(historyData) {
      try {
        const response = await fetch(`${this.baseUrl}/api/history`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(historyData)
        });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data = await response.json();
        if (data.ok) return data.data || null;
        throw new Error(data.error || 'Failed to create history entry');
      } catch (e) {
        console.error('Error creating history entry:', e);
        return null;
      }
    },
    
    // Update history entry
    async update(historyId, updates) {
      try {
        const response = await fetch(`${this.baseUrl}/api/history/${encodeURIComponent(historyId)}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(updates)
        });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data = await response.json();
        if (data.ok) return data.data || null;
        throw new Error(data.error || 'Failed to update history entry');
      } catch (e) {
        console.error('Error updating history entry:', e);
        return null;
      }
    },
    
    // Delete history entry
    async delete(historyId) {
      try {
        const response = await fetch(`${this.baseUrl}/api/history/${encodeURIComponent(historyId)}`, {
          method: 'DELETE'
        });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data = await response.json();
        return data.ok || false;
      } catch (e) {
        console.error('Error deleting history entry:', e);
        return false;
      }
    }
  };

  // ════════════════════════════════════════════
  //  History Manager
  // ════════════════════════════════════════════

  window.DashboardHistory.Manager = {
    state: {
      filters: {
        type: 'all',
        time: 'all'
      },
      history: [],
      polling: null,
      lastUpdate: null
    },

    // Initialize history manager
    async init() {
      this.state.history = [];
      this.setupEventListeners();
      await this.loadHistory(); // Initial fetch from backend
      this.renderHistory();
      this.updateCount();
      
      // Setup window message listener for events from other modules
      window.addEventListener('message', (e) => {
        if (e.data && e.data.module && e.data.type) {
          this.handleModuleEvent(e.data);
        }
      });
      
      // Start polling backend every 2 seconds
      this.startPolling();
    },
    
    // Start polling for updates
    startPolling() {
      if (this.state.polling) {
        clearInterval(this.state.polling);
      }
      
      this.state.polling = setInterval(async () => {
        try {
          const history = await window.DashboardHistory.API.list();
          if (JSON.stringify(history) !== JSON.stringify(this.state.history)) {
            this.state.history = history;
            this.renderHistory();
            this.updateCount();
            this.state.lastUpdate = Date.now();
          }
        } catch (e) {
          console.error('Error polling history:', e);
        }
      }, 10000); // Poll every 10 seconds
    },
    
    // Stop polling
    stopPolling() {
      if (this.state.polling) {
        clearInterval(this.state.polling);
        this.state.polling = null;
      }
    },
    
    // Load history from backend
    async loadHistory() {
      try {
        const history = await window.DashboardHistory.API.list();
        this.state.history = history;
      } catch (e) {
        console.error('Failed to load history:', e);
        this.state.history = [];
      }
    },

    // Save history to storage (fallback)
    saveHistory(history) {
      try {
        localStorage.setItem('dashboard_history', JSON.stringify(history));
      } catch (e) {
        console.error('Error saving history:', e);
      }
    },

    // Add history entry
    async addEntry(entry) {
      const newEntry = await window.DashboardHistory.API.create({
        ...entry,
        timestamp: Date.now()
      });
      
      // Keep only last 1000 entries
      if (this.state.history.length > 1000) {
        this.state.history = this.state.history.slice(0, 1000);
      }
      
      return newEntry;
    },

    // Delete history entry
    async deleteEntry(id) {
      const result = await window.DashboardHistory.API.delete(id);
      return result;
    },

    // Revert an action
    async revertAction(historyId) {
      const history = this.state.history;
      const entry = history.find(h => h.id === historyId);
      
      if (entry && entry.revertAction) {
        try {
          const result = entry.revertAction(entry);
          
          // Add revert history entry
          await this.addEntry({
            type: 'revert',
            description: `Reverted: ${entry.description}`,
            originalEntry: entry,
            result
          });
          
          // Refresh from backend
          await this.loadHistory();
          
          return { success: true, result };
        } catch (e) {
          return { success: false, error: e.message };
        }
      }
      
      return { success: false, error: 'No revert action available' };
    },

    // Clear history
    async clearHistory() {
      if (confirm('Are you sure you want to clear all history? This action cannot be undone.')) {
        this.state.history = [];
        this.renderHistory();
        this.updateCount();
      }
    },

    // Setup event listeners
    setupEventListeners() {
      // Filter buttons
      document.querySelectorAll('.filter-chips button').forEach(btn => {
        btn.addEventListener('click', (e) => {
          const chips = btn.closest('.filter-chips');
          const filterType = chips.id;
          
          // Remove active class from all buttons in this group
          chips.querySelectorAll('.ui-filter-chip').forEach(b => b.classList.remove('active'));
          
          // Add active class to clicked button
          btn.classList.add('active');
          
          // Update filter
          const value = btn.dataset[filterType];
          this.state.filters[filterType] = value;
          
          // Re-render history
          this.renderHistory();
        });
      });

      // Modal close buttons
      document.querySelectorAll('.ui-modal-close').forEach(btn => {
        btn.addEventListener('click', () => {
          this.closeModal();
        });
      });

      // Click outside modal
      document.querySelectorAll('.ui-modal-overlay').forEach(overlay => {
        overlay.addEventListener('click', (e) => {
          if (e.target === overlay) {
            this.closeModal();
          }
        });
      });

      // Clear history button
      document.getElementById('btnClearHistory')?.addEventListener('click', () => {
        this.clearHistory();
      });
    },

    // Handle module events
    handleModuleEvent(data) {
      if (data.module === 'features' && data.type === 'featureAdded') {
        this.addEntry({
          type: 'feature',
          description: `New feature: ${data.payload.feature.title}`,
          data: data.payload.feature
        });
      } else if (data.module === 'features' && data.type === 'featureUpdated') {
        this.addEntry({
          type: 'feature',
          description: `Feature updated: ${data.payload.feature.title}`,
          data: data.payload.feature
        });
      } else if (data.module === 'features' && data.type === 'featureDeleted') {
        this.addEntry({
          type: 'feature',
          description: `Feature deleted: ${data.payload.id}`,
          data: { id: data.payload.id }
        });
      } else if (data.module === 'bugs' && data.type === 'bugAdded') {
        this.addEntry({
          type: 'bug',
          description: `New bug: ${data.payload.bug.title}`,
          data: data.payload.bug
        });
      } else if (data.module === 'bugs' && data.type === 'bugUpdated') {
        this.addEntry({
          type: 'bug',
          description: `Bug updated: ${data.payload.bug.title}`,
          data: data.payload.bug
        });
      } else if (data.module === 'bugs' && data.type === 'bugDeleted') {
        this.addEntry({
          type: 'bug',
          description: `Bug deleted: ${data.payload.id}`,
          data: { id: data.payload.id }
        });
      } else if (data.module === 'chat' && data.type === 'conversationAdded') {
        this.addEntry({
          type: 'chat',
          description: `New chat conversation: ${data.payload.conversation.title}`,
          data: data.payload.conversation
        });
      } else if (data.module === 'chat' && data.type === 'conversationDeleted') {
        this.addEntry({
          type: 'chat',
          description: `Chat conversation deleted: ${data.payload.id}`,
          data: { id: data.payload.id }
        });
      } else if (data.module === 'chat' && data.type === 'conversationRenamed') {
        this.addEntry({
          type: 'chat',
          description: `Chat conversation renamed: ${data.payload.newTitle}`,
          data: { id: data.payload.id, newTitle: data.payload.newTitle }
        });
      }
    },

    // Render history
    renderHistory() {
      const container = document.getElementById('historyTimeline');
      const emptyState = document.getElementById('emptyState');
      
      const history = this.getFilteredHistory();
      
      if (history.length === 0) {
        container.innerHTML = '';
        emptyState.style.display = 'block';
        return;
      }
      
      emptyState.style.display = 'none';
      
      const html = history.map(h => this.renderHistoryItem(h)).join('');
      container.innerHTML = html;

      // Setup action buttons
      container.querySelectorAll('.ui-timeline-action-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          const item = btn.closest('.ui-timeline-item');
          const historyId = item.dataset.historyId;
          
          if (btn.dataset.action === 'view') {
            this.openModal(historyId);
          } else if (btn.dataset.action === 'revert') {
            this.handleRevert(historyId, btn);
          } else if (btn.dataset.action === 'delete') {
            this.handleDelete(historyId, btn);
          }
        });
      });
    },

    // Render history item
    renderHistoryItem(entry) {
      const formatDate = (date) => {
        return new Date(date).toLocaleDateString('en-US', {
          month: 'short',
          day: 'numeric',
          hour: '2-digit',
          minute: '2-digit'
        });
      };

      const getTypeIcon = (type) => {
        const icons = {
          feature: '<i class="fa-solid fa-rocket"></i>',
          bug: '<i class="fa-solid fa-bug"></i>',
          chat: '<i class="fa-solid fa-comments"></i>',
          revert: '<i class="fa-solid fa-rotate-left"></i>'
        };
        return icons[type] || '<i class="fa-solid fa-clock"></i>';
      };

      const getTypeClass = (type) => {
        const classes = {
          feature: 'feature',
          bug: 'bug',
          chat: 'chat',
          revert: 'revert'
        };
        return classes[type] || 'default';
      };

      return `
        <div class="ui-timeline-item" data-history-id="${entry.id}">
          <div class="ui-timeline-content">
            <div class="ui-timeline-header">
              <span class="history-type-icon ${getTypeClass(entry.type)}">
                ${getTypeIcon(entry.type)}
              </span>
              <span class="ui-timeline-title">${this.escapeHtml(entry.description)}</span>
            </div>
            <div class="ui-timeline-time">${formatDate(entry.timestamp)}</div>
            ${entry.data ? `<div class="ui-timeline-desc">${this.formatData(entry.data, entry.type)}</div>` : ''}
            <div class="ui-timeline-actions">
              <button class="ui-timeline-action-btn" data-action="view">
                <i class="fa-solid fa-eye"></i>
                Details
              </button>
              ${entry.revertAction ? `<button class="ui-timeline-action-btn revert" data-action="revert">
                <i class="fa-solid fa-rotate-left"></i>
                Revert
              </button>` : ''}
              <button class="ui-timeline-action-btn delete" data-action="delete">
                <i class="fa-solid fa-trash"></i>
                Delete
              </button>
            </div>
          </div>
        </div>
      `;
    },

    // Format data for display
    formatData(data, type) {
      if (!data) return '';
      
      switch (type) {
        case 'feature':
          return `Category: ${data.category || 'N/A'} | Priority: ${data.priority || 'N/A'} | Status: ${data.status || 'N/A'}`;
        case 'bug':
          return `Source: ${data.source || 'N/A'} | Environment: ${data.environment || 'N/A'} | Status: ${data.status || 'N/A'}`;
        case 'chat':
          return `Messages: ${data.messages || 0} | Last updated: ${new Date(data.updatedAt).toLocaleDateString()}`;
        case 'revert':
          return `Original: ${data.originalEntry?.description || 'N/A'} | Result: ${data.result ? 'Success' : 'Failed'}`;
        default:
          return JSON.stringify(data, null, 2);
      }
    },

    // Get filtered history
    getFilteredHistory() {
      let history = this.state.history;
      
      // Type filter
      if (this.state.filters.type !== 'all') {
        history = history.filter(h => h.type === this.state.filters.type);
      }
      
      // Time filter
      if (this.state.filters.time !== 'all') {
        const now = Date.now();
        const day = 86400000;
        const timeFilterMap = {
          'today': day,
          '7days': 7 * day,
          '30days': 30 * day
        };
        
        const timeLimit = timeFilterMap[this.state.filters.time];
        if (timeLimit) {
          history = history.filter(h => now - h.timestamp < timeLimit);
        }
      }
      
      return history;
    },

    // Update history count
    updateCount() {
      const count = this.state.history.length;
      const el = document.getElementById('historyCount');
      if (el) {
        el.textContent = count;
      }
    },

    // Open history details modal
    openModal(historyId) {
      const entry = this.state.history.find(h => h.id === historyId);
      if (!entry) return;

      const modal = document.getElementById('historyDetailsModal');
      modal.dataset.historyId = historyId;
      
      // Format dates
      const formatDate = (date) => {
        return new Date(date).toLocaleDateString('en-US', {
          month: 'short',
          day: 'numeric',
          year: 'numeric',
          hour: '2-digit',
          minute: '2-digit'
        });
      };

      modal.querySelector('.ui-modal-title').textContent = `Action: ${entry.type}`;
      modal.querySelector('.ui-modal-body').innerHTML = `
        <div class="history-details-content">
          <div class="history-details-header">
            <div class="history-details-title">
              <h2>${this.escapeHtml(entry.description)}</h2>
              <div class="history-details-title-meta">
                <span class="status-badge ${entry.type === 'revert' ? 'success' : 'info'}">
                  ${this.escapeHtml(entry.type)}
                </span>
              </div>
            </div>
          </div>

          <div class="history-details-meta" style="display: flex; flex-direction: column; gap: 12px;">
            <div class="history-details-meta-item">
              <span class="history-details-meta-label">Timestamp</span>
              <span class="history-details-meta-value">${formatDate(entry.timestamp)}</span>
            </div>
            
            ${entry.data ? `
              <div class="history-details-meta-item">
                <span class="history-details-meta-label">Data</span>
                <pre class="history-details-meta-value" style="background: var(--surface); padding: 12px; border-radius: var(--radius-sm); overflow: auto; max-height: 200px;">${this.escapeHtml(JSON.stringify(entry.data, null, 2))}</pre>
              </div>
            ` : ''}
            
            ${entry.revertAction ? `
              <div class="history-details-meta-item">
                <span class="history-details-meta-label">Revert Available</span>
                <span class="history-details-meta-value" style="color: var(--success);">Yes</span>
              </div>
            ` : ''}
          </div>

          ${entry.revertAction ? `
            <div class="history-details-actions">
              <button class="ui-btn ui-btn-secondary" id="btnRevertAction">
                <i class="fa-solid fa-rotate-left"></i>
                Revert Action
              </button>
            </div>
          ` : ''}
        </div>
      `;

      modal.style.display = 'flex';

      // Setup revert button
      const btnRevert = modal.querySelector('#btnRevertAction');
      if (btnRevert && entry.revertAction) {
        btnRevert.addEventListener('click', () => {
          this.handleRevert(historyId, btnRevert);
        });
      }
    },

    // Handle revert action
    async handleRevert(historyId, btn) {
      const result = await this.revertAction(historyId);

      if (result.success) {
        btn.innerHTML = '<i class="fa-solid fa-check"></i> Reverted';
        btn.classList.remove('revert');
        btn.classList.add('success');
        setTimeout(() => {
          btn.innerHTML = '<i class="fa-solid fa-rotate-left"></i> Revert';
          btn.classList.add('revert');
          btn.classList.remove('success');
        }, 2000);
      } else {
        btn.innerHTML = '<i class="fa-solid fa-xmark"></i> Failed';
        btn.classList.remove('revert');
        btn.classList.add('failed');
        setTimeout(() => {
          btn.innerHTML = '<i class="fa-solid fa-rotate-left"></i> Revert';
          btn.classList.add('revert');
          btn.classList.remove('failed');
        }, 2000);
      }
      
      // Refresh history display
      await this.loadHistory();
      this.renderHistory();
      this.updateCount();
      
      // Show toast notification
      this.showToast(result.success ? 'Action reverted successfully' : `Failed to revert: ${result.error}`);
    },

    // Handle delete action
    async handleDelete(historyId, btn) {
      if (confirm('Are you sure you want to delete this history entry?')) {
        await this.deleteEntry(historyId);
        
        // Refresh history display
        await this.loadHistory();
        this.renderHistory();
        this.updateCount();
        
        this.showToast('History entry deleted');
      }
    },

    // Close modal
    closeModal() {
      document.getElementById('historyDetailsModal').style.display = 'none';
    },

    // Show toast notification
    showToast(message) {
      // Create toast element
      const toast = document.createElement('div');
      toast.className = 'history-toast';
      toast.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: linear-gradient(to bottom, var(--surface), var(--panel));
        border: 2px solid var(--border);
        border-radius: var(--radius-md);
        padding: 16px;
        box-shadow: 0 8px 16px rgba(0,0,0,0.4);
        z-index: 10000;
        animation: slideInRight 300ms cubic-bezier(0.4, 0, 0.2, 1);
        display: flex;
        align-items: center;
        gap: 12px;
      `;
      toast.innerHTML = `
        <i class="fa-solid fa-check-circle" style="color: var(--success); font-size: 20px;"></i>
        <span>${this.escapeHtml(message)}</span>
      `;
      
      document.body.appendChild(toast);
      
      // Remove after 3 seconds
      setTimeout(() => {
        toast.style.animation = 'slideOutRight 300ms cubic-bezier(0.4, 0, 0.2, 1)';
        setTimeout(() => {
          toast.remove();
        }, 300);
      }, 3000);
    },

    // Escape HTML for security
    escapeHtml(s) {
      const d = document.createElement('div');
      d.textContent = s;
      return d.innerHTML;
    }
  };

  // Add toast animations dynamically
  const style = document.createElement('style');
  style.textContent = `
    @keyframes slideInRight {
      from {
        opacity: 0;
        transform: translateX(100%);
      }
      to {
        opacity: 1;
        transform: translateX(0);
      }
    }
    @keyframes slideOutRight {
      from {
        opacity: 1;
        transform: translateX(0);
      }
      to {
        opacity: 0;
        transform: translateX(100%);
      }
    }
  `;
  document.head.appendChild(style);

  // ════════════════════════════════════════════
  //  Initialize History Manager
  // ════════════════════════════════════════════

  document.addEventListener('DOMContentLoaded', () => {
    window.DashboardHistory.Manager.init();
  });

})();
