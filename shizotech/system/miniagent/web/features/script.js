/* ── Feature Tracker Dashboard Logic ── */

// ════════════════════════════════════════════
//  Feature Module IIFE
// ════════════════════════════════════════════

(function() {
  // Use DashboardFeatures namespace to avoid global conflicts
  window.DashboardFeatures = window.DashboardFeatures || {};

  // ════════════════════════════════════════════
  //  Backend API Client
  // ════════════════════════════════════════════

  window.DashboardFeatures.API = {
    baseUrl: 'http://localhost:13337',
    
    // Fetch all features from backend
    async list() {
      try {
        const response = await fetch(`${this.baseUrl}/api/features/list`);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data = await response.json();
        if (data.ok) return data.data || [];
        throw new Error(data.error || 'Failed to fetch features');
      } catch (e) {
        console.error('Error fetching features:', e);
        return [];
      }
    },
    
    // Fetch specific feature by ID
    async get(featureId) {
      try {
        const response = await fetch(`${this.baseUrl}/api/features/${encodeURIComponent(featureId)}`);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data = await response.json();
        if (data.ok) return data.data || null;
        throw new Error(data.error || 'Feature not found');
      } catch (e) {
        console.error('Error fetching feature:', e);
        return null;
      }
    },
    
    // Create new feature
    async create(featureData) {
      try {
        const response = await fetch(`${this.baseUrl}/api/features`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(featureData)
        });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data = await response.json();
        if (data.ok) return data.data || null;
        throw new Error(data.error || 'Failed to create feature');
      } catch (e) {
        console.error('Error creating feature:', e);
        return null;
      }
    },
    
    // Update feature
    async update(featureId, updates) {
      try {
        const response = await fetch(`${this.baseUrl}/api/features/${encodeURIComponent(featureId)}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(updates)
        });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data = await response.json();
        if (data.ok) return data.data || null;
        throw new Error(data.error || 'Failed to update feature');
      } catch (e) {
        console.error('Error updating feature:', e);
        return null;
      }
    },
    
    // Delete feature
    async delete(featureId) {
      try {
        const response = await fetch(`${this.baseUrl}/api/features/${encodeURIComponent(featureId)}`, {
          method: 'DELETE'
        });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data = await response.json();
        return data.ok || false;
      } catch (e) {
        console.error('Error deleting feature:', e);
        return false;
      }
    }
  };

  // ════════════════════════════════════════════
  //  Feature Store
  // ════════════════════════════════════════════

  window.DashboardFeatures.Store = {
    storageKey: 'dashboard_features',
    
    // Load features from backend
    async load() {
      try {
        const features = await window.DashboardFeatures.API.list();
        return features;
      } catch {
        return [];
      }
    },
    
    // Save features to storage
    save(features) {
      try {
        localStorage.setItem(this.storageKey, JSON.stringify(features));
      } catch (e) {
        console.error('Error saving features:', e);
      }
    },
    
    // Add a feature
    async add(feature) {
      const newFeature = await window.DashboardFeatures.API.create({
        ...feature,
        createdAt: Date.now(),
        updatedAt: Date.now(),
        progress: 0,
        status: 'planned'
      });
      return newFeature;
    },
    
    // Update a feature
    async update(id, updates) {
      const updated = await window.DashboardFeatures.API.update(id, updates);
      return updated;
    },
    
    // Delete a feature
    async delete(id) {
      const result = await window.DashboardFeatures.API.delete(id);
      return result;
    },
    
    // Get a feature by ID
    async getById(id) {
      const feature = await window.DashboardFeatures.API.get(id);
      return feature || null;
    },
    
    // Get features by filter
    getByFilter(features, filters = {}) {
      // Status filter
      if (filters.status && filters.status !== 'all') {
        features = features.filter(f => f.status === filters.status);
      }
      
      // Priority filter
      if (filters.priority && filters.priority !== 'all') {
        features = features.filter(f => f.priority === filters.priority);
      }
      
      return features;
    },
    
    // Update progress
    async updateProgress(id, progress) {
      return this.update(id, { progress: Math.min(100, Math.max(0, progress)) });
    }
  };

  // ════════════════════════════════════════════
  //  Feature Manager
  // ════════════════════════════════════════════

  window.DashboardFeatures.Manager = {
    state: {
      filters: {
        status: 'all',
        priority: 'all'
      },
      features: []
    },

    // Initialize feature manager
    async init() {
      this.state.features = [];
      this.setupEventListeners();
      await this.loadFeatures(); // Initial fetch from backend
      this.renderFeatures();
      this.updateCount();
      
      // Start polling backend every 10 seconds
      this.startPolling();
      
      // Notify dashboard of loaded features
      this.notifyDashboard('featuresLoaded', { count: this.state.features.length });
    },
    
    // Start polling for updates
    startPolling() {
      if (this.state.polling) {
        clearInterval(this.state.polling);
      }
      
      this.state.polling = setInterval(async () => {
        try {
          const features = await window.DashboardFeatures.API.list();
          if (JSON.stringify(features) !== JSON.stringify(this.state.features)) {
            this.state.features = features;
            this.renderFeatures();
            this.updateCount();
            this.state.lastUpdate = Date.now();
          }
        } catch (e) {
          console.error('Error polling features:', e);
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
    
    // Load features from backend
    async loadFeatures() {
      try {
        const features = await window.DashboardFeatures.API.list();
        this.state.features = features;
      } catch (e) {
        console.error('Failed to load features:', e);
        this.state.features = [];
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
          
          // Re-render features
          this.renderFeatures();
        });
      });

      // Modal close buttons
      document.querySelectorAll('.ui-modal-close, [data-modal-action="cancel"]').forEach(btn => {
        btn.addEventListener('click', () => {
          this.closeModals();
        });
      });

      // Click outside modals
      document.querySelectorAll('.ui-modal-overlay').forEach(overlay => {
        overlay.addEventListener('click', (e) => {
          if (e.target === overlay) {
            this.closeModals();
          }
        });
      });

      // Add feature button
      document.getElementById('btnAddFeature')?.addEventListener('click', () => {
        this.openAddModal();
      });

      // Submit feature form
      document.getElementById('btnSubmitFeature')?.addEventListener('click', () => {
        this.submitFeature();
      });

      // Delete feature button
      document.getElementById('btnDeleteFeature')?.addEventListener('click', () => {
        this.deleteCurrentFeature();
      });

      // Close feature details button
      document.getElementById('btnCloseFeatureDetails')?.addEventListener('click', () => {
        this.closeModals();
      });

      // Confirm delete modal buttons
      document.getElementById('btnCancelDelete')?.addEventListener('click', () => {
        this.closeConfirmDeleteModal();
      });

      document.getElementById('btnConfirmDelete')?.addEventListener('click', () => {
        this.executeDelete();
      });
    },

    // Open add feature modal
    openAddModal() {
      document.getElementById('addFeatureModal').style.display = 'flex';
      document.getElementById('featureTitle').focus();
    },

    // Close all modals
    closeModals() {
      document.querySelectorAll('.ui-modal-overlay').forEach(overlay => {
        overlay.style.display = 'none';
      });
    },

    // Open confirm delete modal
    openConfirmDeleteModal(itemId, eventType, idKey) {
      const modal = document.getElementById('confirmDeleteModal');
      modal.dataset.itemId = itemId;
      modal.dataset.eventType = eventType;
      modal.dataset.idKey = idKey;
      modal.style.display = 'flex';
    },

    // Close confirm delete modal
    closeConfirmDeleteModal() {
      const modal = document.getElementById('confirmDeleteModal');
      modal.style.display = 'none';
    },

    // Execute delete after confirmation
    async executeDelete() {
      const modal = document.getElementById('confirmDeleteModal');
      const itemId = modal.dataset.itemId;
      const eventType = modal.dataset.eventType;
      const idKey = modal.dataset.idKey;

      if (itemId && eventType) {
        if (eventType === 'featureDeleted') {
          await window.DashboardFeatures.Store.delete(itemId);
          
          this.closeModals();
          
          // Notify dashboard
          this.notifyDashboard(eventType, { [idKey]: itemId });
          
          // Refresh from backend
          await this.loadFeatures();
          this.renderFeatures();
          this.updateCount();
        }
      }
    },

    // Submit feature form
    async submitFeature() {
      const title = document.getElementById('featureTitle').value.trim();
      const description = document.getElementById('featureDescription').value.trim();
      const priority = document.getElementById('featurePriority').value;
      const category = document.getElementById('featureCategory').value;
      const targetDate = document.getElementById('featureTargetDate').value;

      if (!title) {
        alert('Please enter a feature title');
        return;
      }

      const feature = {
        title,
        description,
        priority,
        category,
        targetDate: targetDate || null,
        status: 'planned',
        progress: 0,
        history: [
          {
            status: 'planned',
            timestamp: Date.now(),
            notes: 'Feature created'
          }
        ]
      };

      const newFeature = await window.DashboardFeatures.Store.add(feature);
      
      // Reset form
      document.getElementById('addFeatureForm').reset();
      this.closeModals();

      // Notify dashboard
      this.notifyDashboard('featureAdded', { feature: newFeature });
      
      // Refresh from backend
      await this.loadFeatures();
      this.renderFeatures();
      this.updateCount();
    },

    // Delete current feature
    async deleteCurrentFeature() {
      const modal = document.getElementById('featureDetailsModal');
      const featureId = modal.dataset.featureId;
      
      if (featureId) {
        this.openConfirmDeleteModal(featureId, 'featureDeleted', 'featureId');
      }
    },

    // Delete feature directly from card
    async deleteFeatureFromCard(featureId) {
      this.openConfirmDeleteModal(featureId, 'featureDeleted', 'featureId');
    },

    // Open feature details modal
    async openFeatureDetails(featureId) {
      const feature = await window.DashboardFeatures.Store.getById(featureId);
      if (!feature) return;

      const modal = document.getElementById('featureDetailsModal');
      modal.dataset.featureId = featureId;
      
      // Format dates
      const formatDate = (date) => {
        return new Date(date).toLocaleDateString('en-US', {
          month: 'short',
          day: 'numeric',
          year: 'numeric'
        });
      };

      const targetDate = feature.targetDate ? formatDate(feature.targetDate) : 'No target date';

      modal.querySelector('.ui-modal-title').textContent = feature.title;
      modal.querySelector('.ui-modal-body').innerHTML = `
        <div class="feature-details-content">
          <div class="feature-details-header">
            <div class="feature-details-title">
              <h2>${this.escapeHtml(feature.title)}</h2>
              <div class="feature-details-title-meta">
                <span class="status-badge ${feature.status}">${this.escapeHtml(feature.status)}</span>
                <span class="priority-badge ${feature.priority}">
                  <span class="priority-dot"></span>
                  ${this.escapeHtml(feature.priority)}
                </span>
              </div>
            </div>
          </div>

          <div class="feature-details-desc">
            ${feature.description || 'No description provided.'}
          </div>

          <div class="feature-details-meta">
            <div class="feature-details-meta-item">
              <span class="feature-details-meta-label">Category</span>
              <span class="feature-details-meta-value">${this.escapeHtml(feature.category)}</span>
            </div>
            <div class="feature-details-meta-item">
              <span class="feature-details-meta-label">Priority</span>
              <span class="feature-details-meta-value priority-${feature.priority}">${this.escapeHtml(feature.priority)}</span>
            </div>
            <div class="feature-details-meta-item">
              <span class="feature-details-meta-label">Target Date</span>
              <span class="feature-details-meta-value">${this.escapeHtml(targetDate)}</span>
            </div>
            <div class="feature-details-meta-item">
              <span class="feature-details-meta-label">Created</span>
              <span class="feature-details-meta-value">${formatDate(feature.createdAt)}</span>
            </div>
            <div class="feature-details-meta-item">
              <span class="feature-details-meta-label">Last Updated</span>
              <span class="feature-details-meta-value">${formatDate(feature.updatedAt)}</span>
            </div>
            <div class="feature-details-meta-item">
              <span class="feature-details-meta-label">Progress</span>
              <span class="feature-details-meta-value">${feature.progress}%</span>
            </div>
          </div>

          <div class="progress-bar-container">
            <div class="progress-bar-label">Feature Progress</div>
            <div class="progress-bar-track">
              <div class="progress-bar-fill" style="width: ${feature.progress}%"></div>
            </div>
          </div>

          ${feature.history ? this.renderStatusHistory(feature.history) : ''}

          <div class="feature-details-actions">
            <button class="ui-btn ui-btn-secondary" id="btnUpdateStatus">
              <i class="fa-solid fa-sync"></i>
              Update Status
            </button>
          </div>
        </div>
      `;

      modal.style.display = 'flex';

      // Setup status update button
      const btnUpdateStatus = modal.querySelector('#btnUpdateStatus');
      if (btnUpdateStatus) {
        btnUpdateStatus.addEventListener('click', () => {
          this.updateFeatureStatus(featureId);
        });
      }
    },

    // Render status history
    renderStatusHistory(history) {
      let html = '<div class="feature-details-meta-item"><span class="feature-details-meta-label">Status History</span><ul class="feature-details-meta-value" style="padding-left: 20px; margin-top: 8px;">';
      
      history.forEach(item => {
        html += `
          <li>
            <span class="status-badge ${item.status}">${this.escapeHtml(item.status)}</span>
            <span class="feature-details-meta-value" style="margin-left: 8px; color: var(--text-secondary);">${item.notes || 'No notes'}</span>
            <span class="feature-details-meta-value" style="margin-left: 12px; color: var(--text-secondary);">${new Date(item.timestamp).toLocaleDateString()}</span>
          </li>
        `;
      });
      
      html += '</ul></div>';
      return html;
    },

    // Update feature status
    async updateFeatureStatus(featureId) {
      const feature = await window.DashboardFeatures.Store.getById(featureId);
      if (!feature) return;

      const nextStatus = this.getNextStatus(feature.status);
      
      if (nextStatus) {
        await window.DashboardFeatures.Store.update(featureId, {
          status: nextStatus,
          history: [...(feature.history || []), {
            status: nextStatus,
            timestamp: Date.now(),
            notes: `Status updated to ${nextStatus}`
          }]
        });

        // Notify dashboard
        this.notifyDashboard('featureUpdated', { feature: await window.DashboardFeatures.Store.getById(featureId) });
        
        // Refresh modal
        this.openFeatureDetails(featureId);
        
        // Refresh from backend
        await this.loadFeatures();
        this.renderFeatures();
      }
    },

    // Get next status in workflow
    getNextStatus(currentStatus) {
      const workflow = ['planned', 'in-progress', 'running', 'error', 'completed'];
      const currentIndex = workflow.indexOf(currentStatus);
      
      if (currentIndex === -1) return 'planned';
      if (currentIndex === workflow.length - 1) return null;
      
      return workflow[currentIndex + 1];
    },

    // Render features
    renderFeatures() {
      const container = document.getElementById('featureGrid');
      const emptyState = document.getElementById('emptyState');
      
      const features = this.getFilteredFeatures();
      
      if (features.length === 0) {
        container.innerHTML = '';
        emptyState.style.display = 'block';
        return;
      }
      
      emptyState.style.display = 'none';
      
      const html = features.map(f => this.renderFeatureCard(f)).join('');
      container.innerHTML = html;

      // Setup card action buttons
      container.querySelectorAll('.feature-card-action-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          const card = btn.closest('.feature-card');
          const featureId = card.dataset.featureId;
          
          if (btn.dataset.action === 'view') {
            this.openFeatureDetails(featureId);
          } else if (btn.dataset.action === 'progress') {
            const progress = parseInt(btn.dataset.progress) || 0;
            window.DashboardFeatures.Store.updateProgress(featureId, progress);
            this.renderFeatures();
            this.updateCount();
          } else if (btn.dataset.action === 'delete') {
            this.deleteFeatureFromCard(featureId);
          }
        });
      });
    },

    // Render feature card
    renderFeatureCard(feature) {
      const formatDate = (date) => {
        return new Date(date).toLocaleDateString('en-US', {
          month: 'short',
          day: 'numeric'
        });
      };

      return `
        <div class="feature-card ${feature.status === 'running' ? 'running' : ''} ${feature.status === 'error' ? 'error' : ''}" data-feature-id="${feature.id}">
          <div class="feature-card-header">
            <div class="feature-card-category">
              <i class="fa-solid fa-tag"></i>
              ${this.escapeHtml(feature.category)}
            </div>
            <div class="feature-card-title">
              ${this.escapeHtml(feature.title)}
            </div>
            <div class="feature-card-actions">
              <button class="feature-card-action-btn" data-action="delete" title="Delete">
                <i class="fa-solid fa-trash"></i>
              </button>
              <button class="feature-card-action-btn" data-action="view" title="View Details">
                <i class="fa-solid fa-eye"></i>
              </button>
              <button class="feature-card-action-btn" data-action="progress" data-progress="0" title="Reset Progress">
                <i class="fa-solid fa-rotate-left"></i>
              </button>
            </div>
          </div>
          <div class="feature-card-body">
            <div class="feature-card-desc">
              ${this.escapeHtml(feature.description || 'No description provided.')}
            </div>
            <div class="feature-card-meta">
              <div class="feature-card-meta-left">
                <span class="priority-badge ${feature.priority}">
                  <span class="priority-dot"></span>
                  ${this.escapeHtml(feature.priority)}
                </span>
                <span class="status-badge ${feature.status}">
                  ${this.escapeHtml(feature.status)}
                </span>
              </div>
              <div class="feature-card-meta-right">
                ${feature.targetDate ? `<span style="font-size: 11px; color: var(--text-secondary);">Due: ${formatDate(feature.targetDate)}</span>` : ''}
                <span style="font-size: 11px; color: var(--text-secondary);">Updated: ${formatDate(feature.updatedAt)}</span>
              </div>
            </div>
            <div class="progress-bar-container" style="margin-top: 16px;">
              <div class="progress-bar-label">Progress</div>
              <div class="progress-bar-track">
                <div class="progress-bar-fill" style="width: ${feature.progress}%"></div>
              </div>
              <div class="progress-bar-text" style="font-size: 11px; color: var(--text-secondary);">${feature.progress}% Complete</div>
            </div>
          </div>
        </div>
      `;
    },

    // Get filtered features
    getFilteredFeatures() {
      return window.DashboardFeatures.Store.getByFilter(this.state.features, this.state.filters);
    },

    // Update feature count
    updateCount() {
      const count = this.state.features.length;
      const el = document.getElementById('featureCount');
      if (el) {
        el.textContent = count;
      }
    },

    // Notify dashboard of events
    notifyDashboard(eventType, payload = {}) {
      window.parent.postMessage({
        type: eventType,
        module: 'features',
        payload
      }, '*');
    },

    // Escape HTML for security
    escapeHtml(s) {
      const d = document.createElement('div');
      d.textContent = s;
      return d.innerHTML;
    }
  };

  // ════════════════════════════════════════════
  //  Initialize Feature Manager
  // ════════════════════════════════════════════

  document.addEventListener('DOMContentLoaded', () => {
    window.DashboardFeatures.Manager.init();
  });

})();
