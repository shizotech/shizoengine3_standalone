// ════════════════════════════════════════════
//  Configuration
// ════════════════════════════════════════════
const STORAGE_KEY = 'shizolocal_conversations';
const ACTIVE_KEY  = 'shizolocal_active_id';

const DEEP_RESEARCH_GUIDELINE = `***PROMPT GUIDELINE***\nI want you to act as an unbiased deep research agent.\nIn order to detect truthful information, you should follow these three steps:\n\n1. Information Gathering\n- search for information which supports the claim and keep track of the sources.\n- search for information which contradicts the claim and also keep track of the sources.\n- for each search, keep the max search count below 5 before you give up.\n\n2. Source evaluation\n- Research how trustworthy the sources are.\n- Do a short independent research on the credibility of the sources you found.\n- Conclude which information from which source seems most unbiased.\n\n3. Evaluation\n- Formulate a final unbiased truthful statement.\n- Only consider facts and information that you could verify.\n***PROMPT GUIDELINE END***`;

const CODING_GUIDELINES = `***CODING GUIDELINES***\nYou are an expert AI web developer. Follow these rules strictly:\n1. Always generate the full HTML code. Do NOT omit parts.\n2. Use modern HTML5, CSS3, ES6+. Ensure responsive design.\n3. Enclose code blocks in triple backticks with the language tag.\n4. Avoid broken links, missing tags, or invalid HTML/CSS/JS.\n5. Include proper accessibility considerations.\n6. When editing, always output the entire file again.\n***CODING GUIDELINES END***`;

// ════════════════════════════════════════════
//  Markdown Renderer
// ════════════════════════════════════════════
const md = window.markdownit({ html: false, linkify: true, breaks: true });

function renderMarkdown(text) {
  const advancedPatterns = [
    /^\|.*\|/m, /^#{1,6}\s/m, /^>\s/m,
    /^\s*[-+*]\s/m, /^\s*\d+\.\s/m, /\[.*?\]\(.*?\)/
  ];
  if (advancedPatterns.some(re => re.test(text))) {
    try { return md.render(text); } catch {}
  }
  // Simple fallback
  const lines = text.split('\n');
  let inCode = false, out = '';
  for (const line of lines) {
    if (line.startsWith('```')) {
      inCode = !inCode;
      out += inCode ? '<pre><code>' : '</code></pre>';
    } else if (inCode) {
      out += line.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;') + '\n';
    } else {
      let s = line.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
      s = s.replace(/\*\*\*(.*?)\*\*\*/g,'<b><i>$1</i></b>')
           .replace(/\*\*(.*?)\*\*/g,'<b>$1</b>')
           .replace(/\*(.*?)\*/g,'<i>$1</i>')
           .replace(/`(.*?)`/g,'<code>$1</code>');
      out += s + '\n';
    }
  }
  return out;
}

// ════════════════════════════════════════════
//  Local Conversation Store
// ════════════════════════════════════════════
function loadConversations() {
  try { return JSON.parse(localStorage.getItem(STORAGE_KEY)) || []; }
  catch { return []; }
}
function saveConversations(convs) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(convs));
}
function getActiveId() {
  return localStorage.getItem(ACTIVE_KEY);
}
function setActiveId(id) {
  localStorage.setItem(ACTIVE_KEY, id);
}
function generateId() {
  return 'conv_' + Date.now() + '_' + Math.random().toString(36).slice(2, 8);
}

function createConversation(title = 'New Chat') {
  const conv = { id: generateId(), title, messages: [], messagesHTML: [], createdAt: Date.now(), updatedAt: Date.now() };
  const convs = loadConversations();
  convs.unshift(conv);
  saveConversations(convs);
  setActiveId(conv.id);
  return conv;
}
function deleteConversation(id) {
  let convs = loadConversations();
  convs = convs.filter(c => c.id !== id);
  saveConversations(convs);
  if (getActiveId() === id) {
    setActiveId(convs.length ? convs[0].id : null);
  }
}
function renameConversation(id, newTitle) {
  const convs = loadConversations();
  const c = convs.find(c => c.id === id);
  if (c) { c.title = newTitle; c.updatedAt = Date.now(); }
  saveConversations(convs);
}
function addMessage(convId, role, content) {
  const convs = loadConversations();
  const c = convs.find(c => c.id === convId);
  if (!c) return;
  c.messages.push({ role, content, timestamp: Date.now() });
  c.updatedAt = Date.now();
  // Auto-title from first user message
  if (c.title === 'New Chat' && role === 'user') {
    c.title = content.substring(0, 50) + (content.length > 50 ? '…' : '');
  }
  saveConversations(convs);
}
function updateLastAssistantMessage(convId, content) {
  const convs = loadConversations();
  const c = convs.find(c => c.id === convId);
  if (!c) return;
  for (let i = c.messages.length - 1; i >= 0; i--) {
    if (c.messages[i].role === 'assistant') {
      c.messages[i].content = content;
      break;
    }
  }
  c.updatedAt = Date.now();
  saveConversations(convs);
}
function getConversation(id) {
  return loadConversations().find(c => c.id === id) || null;
}

// ════════════════════════════════════════════
//  Session ID Update Function
// ════════════════════════════════════════════
function updateSessionId(convId, sessionId) {
  if (!convId || !sessionId) return;
  
  const convs = loadConversations();
  const c = convs.find(c => c.id === convId);
  if (c) {
    c.sessionId = sessionId;
    c.updatedAt = Date.now();
    saveConversations(convs);
  }
}

// ════════════════════════════════════════════
//  Conversation Saving with HTML Bubbles
// ════════════════════════════════════════════
function saveCurrentConversationHTML() {
  const activeId = getActiveId();
  if (!activeId) return;
  
  // Get the conversation
  const conv = getConversation(activeId);
  if (!conv) return;
  
  // Get all message bubbles from the DOM
  const messageBubbles = messagesInner.querySelectorAll('.bubble');
  
  // Convert each bubble to HTML string
  const messagesHTML = [];
  messageBubbles.forEach(bubble => {
    messagesHTML.push(bubble.outerHTML);
  });
  
  // Update conversation data
  conv.messagesHTML = messagesHTML;
  conv.updatedAt = Date.now();
  
  // Save updated conversations
  const convs = loadConversations();
  const idx = convs.findIndex(c => c.id === activeId);
  if (idx !== -1) {
    convs[idx] = conv;
  } else {
    convs.push(conv);
  }
  saveConversations(convs);
}

function loadConversationHTML(conv) {
  if (!conv || !conv.messagesHTML || !conv.messagesHTML.length) return false;
  
  // Clear current messages
  messagesInner.innerHTML = '';
  
  // If no messages, show empty state
  if (!conv.messagesHTML.length) {
    messagesInner.appendChild(emptyState);
    emptyState.style.display = 'block';
    return true;
  }
  
  // Hide empty state
  emptyState.style.display = 'none';
  
  // Append each saved HTML bubble
   conv.messagesHTML.forEach(html => {
     const tempDiv = document.createElement('div');
     tempDiv.innerHTML = html;
     const bubble = tempDiv.firstElementChild;
     if (bubble) {
       // Reinitialize any necessary event listeners or state for the bubble
       // For example, reattach copy buttons for assistant messages
       if (bubble.classList.contains('role-assistant')) {
         const copyBtn = bubble.querySelector('.copy-btn');
         if (copyBtn) {
           copyBtn.addEventListener('click', () => navigator.clipboard.writeText(bubble.querySelector('.msg-content')?.innerText || ''));
         }
       }
       
       messagesInner.appendChild(bubble);
     }
   });
   
   // ── RECONSTRUCT AGENT FLOW STATE FROM DOM ──
   // Extract all worker sub-bubbles from loaded DOM
   const allWorkerSubBubbles = messagesInner.querySelectorAll('[id^="worker-"]');
   const loadedWorkerGroupBubbles = Array.from(messagesInner.querySelectorAll('.bubble.role-assistant'));
   
   // Extract worker IDs from DOM element IDs
   const extractedWorkerIds = new Set();
   const reconstructedWorkerSubBubbles = {};
   const reconstructedWorkerBuffers = {};
   
   allWorkerSubBubbles.forEach(workerBubble => {
     try {
       // Extract worker ID from element ID (format: worker-XXX)
       const elementId = workerBubble.id;
       if (!elementId.startsWith('worker-')) return;
       
       const workerId = elementId.slice(7); // Remove 'worker-' prefix
       extractedWorkerIds.add(workerId);
       
       // Extract buffer content from DOM text
       const workerContent = workerBubble.querySelector('.worker-content');
       const bufferContent = workerContent ? workerContent.innerHTML || '' : '';
       
       // Store reference to worker sub-bubble with text buffer reference
       reconstructedWorkerSubBubbles[workerId] = {
         content: workerContent,
         buffer: bufferContent,
         finished: workerBubble.classList.contains('completed'),
         bubble: workerBubble,
         statusBar: workerBubble.querySelector('.worker-status-bar')
       };
       
       // Store buffer content
       reconstructedWorkerBuffers[workerId] = bufferContent;
       
       console.log('Reconstructed worker sub-bubble:', {
         workerId: workerId,
         hasContent: !!workerContent,
         bufferLength: bufferContent.length,
         isFinished: workerBubble.classList.contains('completed')
       });
     } catch (err) {
       console.error('Error reconstructing worker sub-bubble:', err);
     }
   });
   
   // Restore the agent bubbles state with loaded worker group bubbles
   agentBubbles = {
     currentPlannerBubble: null,
     plannerBuffer: '',
     currentWorkerGroupBubble: null,
     workerGroupBubbles: loadedWorkerGroupBubbles, // Use loaded worker group bubbles
     workerBuffers: reconstructedWorkerBuffers,
     workerSubBubbles: reconstructedWorkerSubBubbles
   };
   
   // Set flags based on actual loaded state
   hasCreatedWorkerGroup = loadedWorkerGroupBubbles.length > 0;
   inWorkerMode = extractedWorkerIds.size > 0 && loadedWorkerGroupBubbles.some(group => {
     // Check if any worker group has active workers (not all completed)
     const workers = group.querySelectorAll('.worker-sub-bubble');
     return workers.length > 0 && !Array.from(workers).every(w => w.classList.contains('completed'));
   });
   knownWorkerIds.clear();
   knownWorkerIds.addAll(extractedWorkerIds);
   
   console.log('Agent flow state restored from conversation:', {
     workerGroupBubblesCount: loadedWorkerGroupBubbles.length,
     knownWorkerIds: Array.from(extractedWorkerIds),
     workerSubBubblesCount: Object.keys(reconstructedWorkerSubBubbles).length,
     inWorkerMode: inWorkerMode,
     hasCreatedWorkerGroup: hasCreatedWorkerGroup
   });
  
  // Scroll to bottom
  messagesEl.scrollTop = messagesEl.scrollHeight;
  
  return true;
}

// ════════════════════════════════════════════
//  DOM References
// ════════════════════════════════════════════
const sidebar = document.getElementById('sidebar');
const sidebarOverlay = document.getElementById('sidebarOverlay');
const conversationList = document.getElementById('conversationList');
const btnNewChat = document.getElementById('btnNewChat');
const btnToggleSidebar = document.getElementById('btnToggleSidebar');
const headerTitle = document.getElementById('headerTitle');
const statusBadge = document.getElementById('statusBadge');
const messagesEl = document.getElementById('messages');
const messagesInner = document.getElementById('messagesInner');
const emptyState = document.getElementById('emptyState');
const promptInput = document.getElementById('prompt');
const composerInner = document.querySelector('.composer-inner');
const btnSend = document.getElementById('btnSend');
const btnStop = document.getElementById('btnStop');
const modeSelect = document.getElementById('modeSelect');

// Editor panel
const editorPanel = document.getElementById('editorPanel');
const panelResizer = document.getElementById('panelResizer');
const htmlCode = document.getElementById('htmlCode');
const htmlPreview = document.getElementById('htmlPreview');
const btnCloseEditor = document.getElementById('btnCloseEditor');
const btnDesktop = document.getElementById('btnDesktop');
const btnMobile = document.getElementById('btnMobile');
const editorResizer = document.getElementById('editorResizer');

let sending = false;

// ── Throttle / Debounce Logic Variables ──
let lastUpdate = 0; 
let updateDebounceTimer = null;
const UPDATE_DELAY_MS = 2000; // 2 Seconds

// ── Conditional Autoscroll Logic Variables ──
let shouldAutoScroll = true;

// Scroll listener to track user scroll position
messagesEl.addEventListener('scroll', () => {
  const threshold = 20; // pixels from bottom to consider "at bottom"
  const isAtBottom = messagesEl.scrollTop + messagesEl.clientHeight >= messagesEl.scrollHeight - threshold;
  
  if (isAtBottom) {
    shouldAutoScroll = true;
  } else {
    shouldAutoScroll = false;
  }
});

// ── Throttle / Debounce Logic Variables ──


// ════════════════════════════════════════════
//  Sidebar Rendering
// ════════════════════════════════════════════
function renderSidebar() {
  const convs = loadConversations();
  const activeId = getActiveId();
  conversationList.innerHTML = '';

  if (!convs.length) {
    conversationList.innerHTML = `<div style="padding:20px; text-align:center; color:var(--text-secondary); font-size:13px;">No conversations yet</div>`;
    return;
  }

  // Group by date
  const now = Date.now();
  const day = 86400000;
  const groups = { today: [], yesterday: [], week: [], older: [] };
  for (const c of convs) {
    const age = now - c.updatedAt;
    if (age < day) groups.today.push(c);
    else if (age < 2 * day) groups.yesterday.push(c);
    else if (age < 7 * day) groups.week.push(c);
    else groups.older.push(c);
  }

  const sections = [
    ['Today', groups.today],
    ['Yesterday', groups.yesterday],
    ['Previous 7 Days', groups.week],
    ['Older', groups.older],
  ];

  for (const [label, items] of sections) {
    if (!items.length) continue;
    const lbl = document.createElement('div');
    lbl.className = 'sidebar-section-label';
    lbl.textContent = label;
    conversationList.appendChild(lbl);

    for (const conv of items) {
      const item = document.createElement('div');
      item.className = 'conv-item' + (conv.id === activeId ? ' active' : '');
      item.innerHTML = `
        <i class="fa-regular fa-message conv-icon"></i>
        <span class="conv-title">${escapeHtml(conv.title)}</span>
        <div class="conv-actions">
          <button class="conv-action-btn" data-action="rename" title="Rename"><i class="fa-solid fa-pen"></i></button>
          <button class="conv-action-btn danger" data-action="delete" title="Delete"><i class="fa-solid fa-trash"></i></button>
        </div>
      `;
      item.addEventListener('click', (e) => {
        if (e.target.closest('[data-action]')) return;
        switchConversation(conv.id);
      });
      item.querySelector('[data-action="rename"]').addEventListener('click', () => showRenameDialog(conv.id, conv.title));
      item.querySelector('[data-action="delete"]').addEventListener('click', () => {
        deleteConversation(conv.id);
        const remaining = loadConversations();
        if (!remaining.length) newChat();
        else switchConversation(getActiveId() || remaining[0].id);
        renderSidebar();
      });
      conversationList.appendChild(item);
    }
  }
}

function escapeHtml(s) {
  const d = document.createElement('div');
  d.textContent = s;
  return d.innerHTML;
}

// ════════════════════════════════════════════
//  Rename Dialog
// ════════════════════════════════════════════
function showRenameDialog(id, currentTitle) {
  const overlay = document.createElement('div');
  overlay.className = 'rename-dialog';
  overlay.innerHTML = `
    <div class="rename-dialog-box">
      <h3>Rename conversation</h3>
      <input type="text" id="renameInput" value="${escapeHtml(currentTitle)}" maxlength="100" />
      <div class="rename-dialog-actions">
        <button class="btn-cancel">Cancel</button>
        <button class="btn-confirm">Save</button>
      </div>
    </div>
  `;
  document.body.appendChild(overlay);

  const input = overlay.querySelector('#renameInput');
  input.focus();
  input.select();

  const close = () => overlay.remove();
  overlay.querySelector('.btn-cancel').addEventListener('click', close);
  overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });

  const save = () => {
    const v = input.value.trim();
    if (v) {
      renameConversation(id, v);
      renderSidebar();
      if (getActiveId() === id) headerTitle.textContent = v;
    }
    close();
  };
  overlay.querySelector('.btn-confirm').addEventListener('click', save);
  input.addEventListener('keydown', (e) => { if (e.key === 'Enter') save(); if (e.key === 'Escape') close(); });
}

// ════════════════════════════════════════════
//  Messages Rendering
// ════════════════════════════════════════════
function renderMessages(conv) {
  messagesInner.innerHTML = '';
  if (!conv || (!conv.messages.length && !conv.messagesHTML.length)) {
    messagesInner.appendChild(emptyState);
    emptyState.style.display = 'block';
    // Ensure empty state fills available space when no messages
    messagesInner.style.display = 'block';
    messagesInner.style.justifyContent = 'center';
    messagesInner.style.alignItems = 'center';
    return;
  }
  emptyState.style.display = 'none';
  // Reset flex properties when there are messages
  messagesInner.style.display = 'block';
  messagesInner.style.justifyContent = 'flex-start';
  messagesInner.style.alignItems = 'center';
  
  // If we have HTML messages, use them
  if (conv.messagesHTML && conv.messagesHTML.length > 0) {
    conv.messagesHTML.forEach(html => {
      const tempDiv = document.createElement('div');
      tempDiv.innerHTML = html;
      const bubble = tempDiv.firstElementChild;
      if (bubble) {
        // Reattach copy button listener for assistant messages
        if (bubble.classList.contains('role-assistant')) {
          const copyBtn = bubble.querySelector('.copy-btn');
          if (copyBtn) {
            copyBtn.addEventListener('click', () => navigator.clipboard.writeText(bubble.querySelector('.msg-content')?.innerText || ''));
          }
        }
        messagesInner.appendChild(bubble);
      }
    });
  } 
  // Otherwise, render from message data
  else if (conv.messages && conv.messages.length > 0) {
    for (const msg of conv.messages) {
      appendBubbleFromData(msg.role, msg.content);
    }
  }
  
  messagesEl.scrollTop = messagesEl.scrollHeight;
}

function appendBubbleFromData(role, content) {
  const article = document.createElement('article');
  article.className = `bubble role-${role}`;
  article.style.marginTop = '16px'; // Add spacing between bubbles

  const wrapper = document.createElement('div');
  wrapper.className = 'msg-wrapper';

  const avatar = document.createElement('div');
  avatar.className = 'avatar';
  avatar.innerHTML = role === 'user'
    ? '<i class="fa-solid fa-user" style="font-size:14px"></i>'
    : '<i class="fa-solid fa-bolt" style="font-size:14px"></i>';

  const msg = document.createElement('div');
  msg.className = 'msg';

  const msgContent = document.createElement('div');
  msgContent.className = 'msg-content';

  if (role === 'user') {
    msgContent.textContent = content;
  } else {
    msgContent.innerHTML = renderMarkdown(content);
  }

  if (role === 'assistant') {
    const copyBtn = document.createElement('button');
    copyBtn.className = 'copy-btn';
    copyBtn.textContent = 'Copy';
    copyBtn.addEventListener('click', () => navigator.clipboard.writeText(msgContent.innerText));
    msg.appendChild(copyBtn);
  }

  msg.appendChild(msgContent);
  wrapper.appendChild(avatar);
  wrapper.appendChild(msg);
  article.appendChild(wrapper);
  messagesInner.appendChild(article);

  return { article, msg, msgContent, avatar };
}

function appendLiveBubble(role, content = '') {
  emptyState.style.display = 'none';
  const result = appendBubbleFromData(role, content);
  if (shouldAutoScroll) {
    messagesEl.scrollTop = messagesEl.scrollHeight;
  }
  return result;
}

// ════════════════════════════════════════════
//  Conversation Switching
// ════════════════════════════════════════════
function switchConversation(id) {
  setActiveId(id);
  const conv = getConversation(id);
  headerTitle.textContent = conv ? conv.title : 'New Chat';
  
  // Try to load conversation with HTML bubbles first
  if (!loadConversationHTML(conv)) {
    // Fallback to rendering messages from data if HTML loading fails
    renderMessages(conv);
  }
  
  renderSidebar();
  closeEditorPanel();
}

function newChat() {
  // Reset agent bubbles state for new conversation
  agentBubbles = {
    currentPlannerBubble: null,
    plannerBuffer: '',
    currentWorkerGroupBubble: null,
    workerGroupBubbles: [], // Reset worker group bubbles for new conversation
    workerBuffers: {},
    workerSubBubbles: {}
  };
  
  // Reset tracking flags
  knownWorkerIds.clear();
  hasCreatedWorkerGroup = false;
  inWorkerMode = false;
  
  // Create new conversation and switch to it
  const conv = createConversation();
  switchConversation(conv.id);
}

// ════════════════════════════════════════════
//  HTML Editor Panel
// ════════════════════════════════════════════
function extractHtmlBlock(text) {
  const start = text.indexOf('```html');
  if (start === -1) return { html: '', text };
  let rest = text.slice(start + 7);
  const end = rest.indexOf('```');
  const code = end !== -1 ? rest.slice(0, end) : rest;
  const before = text.slice(0, start);
  const after = end !== -1 ? rest.slice(end + 3) : '';
  return { html: code.trim(), text: (before + after).trim() };
}

// The function that actually updates the DOM
function updateEditorPanel(html) {
  editorPanel.classList.add('visible');
  panelResizer.style.display = 'block';
  htmlCode.textContent = html;
  hljs.highlightElement(htmlCode);
  htmlPreview.srcdoc = html;
}

function closeEditorPanel() {
  editorPanel.classList.remove('visible');
  panelResizer.style.display = 'none';
  htmlPreview.srcdoc = '';
  if (updateDebounceTimer) {
    clearTimeout(updateDebounceTimer);
    updateDebounceTimer = null;
  }
}

// The "Debounced" wrapper
function scheduleEditorUpdate(html) {
  // If the panel isn't visible, show it immediately
  if (!editorPanel.classList.contains('visible')) {
    updateEditorPanel(html);
    lastUpdate = Date.now();
    return;
  }

  // Clear existing timer
  if (updateDebounceTimer) {
    clearTimeout(updateDebounceTimer);
  }

  // Check if enough time has passed since last update
  const now = Date.now();
  if (now - lastUpdate >= UPDATE_DELAY_MS) {
    // More than 2 seconds passed, update immediately
    updateEditorPanel(html);
    lastUpdate = now;
  } else {
    // Set timer to update after the delay
    updateDebounceTimer = setTimeout(() => {
      updateEditorPanel(html);
      lastUpdate = now;
    }, UPDATE_DELAY_MS);
  }
}

function showEditorPanel(html) {
  editorPanel.classList.add('visible');
  panelResizer.style.display = 'block';
  htmlCode.textContent = html;
  hljs.highlightElement(htmlCode);
  htmlPreview.srcdoc = html;
}

btnCloseEditor.addEventListener('click', closeEditorPanel);
btnDesktop.addEventListener('click', () => {
  htmlPreview.style.width = '100%';
  btnDesktop.classList.add('active');
  btnMobile.classList.remove('active');
});
btnMobile.addEventListener('click', () => {
  htmlPreview.style.width = '375px';
  btnMobile.classList.add('active');
  btnDesktop.classList.remove('active');
});

// ════════════════════════════════════════════
//  Server Communication
//  POST /api/adminagent       → { session_id }
//  POST /api/adminagent/poll  → { status, delta, tool }
//  POST /api/adminagent/stop  → { ok }
// ════════════════════════════════════════════

const POLL_INTERVAL_MS = 50;
const POLL_WAIT_MS = 250;

/**
 * Sends initial prompt and session_id to the server and starts polling for agent deltas
 *
 * @param {Object} opts
 * @param {string} opts.prompt       - The latest user message
 * @param {string} opts.sessionId    - Current session_id or empty string for new session
 * @param {string} opts.mode         - "normal" | "research" | "coding"
 * @param {string} opts.activeId     - Active conversation ID for saving session_id
 * @param {Function} opts.onDelta    - Called with each agent delta
 * @param {Function} opts.onDone     - Called when generation is complete
 * @param {Function} opts.onError    - Called on error
 * @returns {string}                 - Updated session_id
 */
async function streamAgentResponse({ prompt, sessionId, mode, activeId, onDelta, onDone, onError }) {
  // Log session_id usage for debugging
  console.log('Starting streamAgentResponse with session_id:', {
    sessionId: sessionId || 'none',
    activeId: activeId,
    timestamp: new Date().toISOString()
  });
  
  // 1) Start session with prompt only
  try {
    const res = await fetch(`/api/adminagent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        prompt: prompt,
        session_id: sessionId || ''
      })
    });

    if (!res.ok) {
      const errText = await res.text();
      onError?.(`Server error ${res.status}: ${errText}`);
      onDone();
      return sessionId;
    }

    const data = await res.json();
    const newSessionId = data.session_id;

    if (!newSessionId) {
      onError?.('No session_id returned from server.');
      onDone();
      return sessionId;
    }

    // Update sessionId for subsequent requests
    sessionId = newSessionId;

    // Save session_id to conversation if activeId is provided
    if (activeId) {
      updateSessionId(activeId, newSessionId);
    }
    
    // Notify caller of session_id update
    if (onDelta) {
      onDelta({ session_id: newSessionId });
    }
  } catch (e) {
    onError?.(`Network error: ${e.message}`);
    onDone();
    return sessionId;
  }

  // 2) Poll for agent deltas
  let done = false;
  let consecutiveWaitCount = 0;  // Track consecutive waiting responses for backoff
  while (!done) {
    try {
      const res = await fetch(`/api/adminagent/poll`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ session_id: sessionId })
      });

      if (!res.ok) {
        onError?.(`Poll error ${res.status}`);
        done = true;
        break;
      }

      const data = await res.json();

      switch (data.status) {
        case 'generating':
          if (data.delta) onDelta(data.delta);
          // Reset consecutive wait count on active generation
          consecutiveWaitCount = 0;
          await sleep(POLL_INTERVAL_MS);
          break;

        case 'waiting':
          // Model is still thinking, no new tokens yet
          // Add exponential backoff for consecutive waiting responses
          consecutiveWaitCount++;
          // Calculate wait time with exponential backoff (capped at 2000ms)
          const backoffDelay = Math.min(2000, POLL_WAIT_MS + (consecutiveWaitCount * POLL_WAIT_MS));
          await sleep(backoffDelay);
          break;

        case 'done':
          done = true;
          break;

        case 'error':
          onError?.(data.error || 'Unknown server error');
          done = true;
          break;

        default:
          // Reset consecutive wait count for unknown responses
          consecutiveWaitCount = 0;
          await sleep(POLL_INTERVAL_MS);
          break;
      }
    } catch (e) {
      console.warn('Poll network error, retrying...', e);
      // Reset consecutive wait count on network error
      consecutiveWaitCount = 0;
      await sleep(500);
    }
  }

  onDone();
  return sessionId;
}

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

// ════════════════════════════════════════════
//  Agent Flow State Management
// ════════════════════════════════════════════

// Stores current agent bubbles structure with text buffers
// workerGroupBubbles: Array of worker group bubbles to maintain history across messages
// workerSubBubbles: Map of worker_id -> sub-bubble object with content and buffer references
// workerBuffers: Map of worker_id -> text buffer (for accumulating deltas)
let agentBubbles = {
  currentPlannerBubble: null,
  plannerBuffer: '',
  currentWorkerGroupBubble: null,
  workerGroupBubbles: [], // Array of worker group bubbles to maintain history across messages
  workerBuffers: {}, // Map of worker_id -> text buffer (for accumulating deltas)
  workerSubBubbles: {} // Map of worker_id -> sub-bubble object with content and buffer references
};

// Track if we've created any worker groups yet (to avoid duplicate separators)
let hasCreatedWorkerGroup = false;

// Keep track of all known worker IDs to handle cases where spawn events arrive late
let knownWorkerIds = new Set();

// Track if we're in worker mode (to prevent creating duplicate worker groups)
let inWorkerMode = false;

// ════════════════════════════════════════════
//  Set Polyfill for addAll method
// ════════════════════════════════════════════
if (!Set.prototype.addAll) {
  Set.prototype.addAll = function(iterable) {
    for (const item of iterable) {
      this.add(item);
    }
    return this;
  };
}

// ════════════════════════════════════════════
//  DEBUGGING CONSOLE LOGS
// ════════════════════════════════════════════

// Log worker group bubble creation
function logWorkerGroupCreation(workerIds) {
  console.log(' Worker Group Bubble Created:', {
    workerIds: workerIds,
    timestamp: new Date().toISOString(),
    knownWorkerIds: Array.from(knownWorkerIds),
    totalWorkerGroups: agentBubbles.workerGroupBubbles.length + 1 // +1 for the new one being created
  });
}

// Log worker sub-bubble initialization
function logWorkerSubBubbleInit(workerId) {
  console.log(' Worker Sub-Bubble Initialized:', {
    workerId: workerId,
    timestamp: new Date().toISOString(),
    knownWorkerIds: Array.from(knownWorkerIds)
  });
}

// Log worker delta processing
function logWorkerDeltaProcessing(delta) {
  console.log(' Worker Delta Processing:', {
    agent: delta.agent,
    workerId: delta.id,
    textLength: (delta.text || '').length,
    hasText: !!delta.text,
    timestamp: new Date().toISOString()
  });
}

// Log worker group bubble state
function logWorkerGroupState() {
  console.log(' Worker Group State:', {
    hasCurrentGroup: !!agentBubbles.currentWorkerGroupBubble,
    knownWorkerIds: Array.from(knownWorkerIds),
    totalKnownWorkers: knownWorkerIds.size,
    workerSubBubblesCount: Object.keys(agentBubbles.workerSubBubbles).length,
    workerBuffersCount: Object.keys(agentBubbles.workerBuffers).length,
    workerGroupBubblesCount: agentBubbles.workerGroupBubbles.length
  });
}

// Log worker delta handling
function logWorkerDeltaHandling(workerId, workerSubBubble) {
  console.log(' Worker Delta Handling:', {
    workerId: workerId,
    hasWorkerSubBubble: !!workerSubBubble,
    workerFinished: workerSubBubble?.finished || false,
    bufferLength: workerSubBubble?.buffer?.length || 0,
    timestamp: new Date().toISOString()
  });
}

// Helper to create planner bubble
function createPlannerBubble() {
  const { msgContent } = appendLiveBubble('assistant', '');
  msgContent.innerHTML = '<span style="color:var(--accent-secondary); font-weight:700;">Planner</span> is thinking...';
  // Initialize text buffer
  agentBubbles.plannerBuffer = '';
  return msgContent;
}

// Helper to create worker group bubble with proper vertical layout
function createWorkerGroupBubble(workerIds) {
  // Create separator between worker groups if this isn't the first one
  if (hasCreatedWorkerGroup) {
    const separator = document.createElement('div');
    separator.className = 'worker-group-separator';
    messagesInner.appendChild(separator);
  }
  
  // Create new worker group bubble (don't remove existing ones)
  const article = document.createElement('article');
  article.className = 'bubble role-assistant';
  article.id = 'worker-group-' + Date.now();

  const wrapper = document.createElement('div');
  wrapper.className = 'msg-wrapper';

  const msg = document.createElement('div');
  msg.className = 'msg';

  // Worker group header
  const header = document.createElement('div');
  header.style.cssText = 'font-size:12px; font-weight:700; color:var(--accent-secondary); margin-bottom:10px;';
  header.textContent = 'Worker Group';

  // Worker sub-bubbles container - ensure vertical layout with fixed heights
  const workersContainer = document.createElement('div');
  workersContainer.className = 'worker-group-container';

  // Create sub-bubbles for each worker
  workerIds.forEach(workerId => {
    const workerBubble = document.createElement('div');
    workerBubble.className = 'worker-sub-bubble';
    workerBubble.id = 'worker-' + workerId;

    const workerHeader = document.createElement('div');
    workerHeader.className = 'worker-header';
    workerHeader.innerHTML = '<i class="fa-solid fa-robot" style="font-size:10px;"></i> Worker: ' + workerId;
    workerHeader.classList.add('active'); // Add active class to header

    // Worker Status Bar - Fixed at top, outside scrollable area
    const workerStatusBar = document.createElement('div');
    workerStatusBar.className = 'worker-status-bar';
    workerStatusBar.innerHTML = '<i class="fa-solid fa-circle-notch fa-spin"></i> Running...';

    const workerContent = document.createElement('div');
    workerContent.className = 'worker-content';

    workerBubble.appendChild(workerHeader);
    workerBubble.appendChild(workerStatusBar);
    workerBubble.appendChild(workerContent);
    workersContainer.appendChild(workerBubble);
    
    // Add active class to indicate worker is running
    workerBubble.classList.add('active');
    
    // Initialize text buffer for this worker
    agentBubbles.workerBuffers[workerId] = '';
    
    // Store reference to worker sub-bubble with text buffer reference
    agentBubbles.workerSubBubbles[workerId] = {
      content: workerContent,
      buffer: agentBubbles.workerBuffers[workerId],
      finished: false,
      bubble: workerBubble, // Store reference to bubble element
      statusBar: workerStatusBar // Store reference to status bar
    };
    
    // Log worker sub-bubble initialization
    logWorkerSubBubbleInit(workerId);
    
    // Auto-scroll worker sub-bubble to bottom when created
    setTimeout(() => {
      workerContent.scrollTop = workerContent.scrollHeight;
    }, 50);
  });

  msg.appendChild(header);
  msg.appendChild(workersContainer);
  wrapper.appendChild(msg);
  article.appendChild(wrapper);
  messagesInner.appendChild(article);

  // Auto-scroll to bottom
  if (shouldAutoScroll) {
    messagesEl.scrollTop = messagesEl.scrollHeight;
  }

  // Add to worker group bubbles array
  agentBubbles.workerGroupBubbles.push(article);
  
  // Set the current worker group bubble reference
  agentBubbles.currentWorkerGroupBubble = article;
  
  // Set inWorkerMode flag to true
  inWorkerMode = true;
  
  // Mark that we've created at least one worker group
  hasCreatedWorkerGroup = true;
  
  // Log worker group creation
  logWorkerGroupCreation(workerIds);
  
  // Log worker group state after creation
  logWorkerGroupState();
  
  return workersContainer;
}

// Helper to append delta to appropriate bubble
function appendAgentDelta(delta) {
  const agent = delta.agent;
  const text = delta.text || '';
  const workerId = delta.id;

  // Log worker delta processing
  logWorkerDeltaProcessing(delta);
  
  // Log worker group state before processing
  logWorkerGroupState();

  // Planner delta
  if (agent === 'planner') {
    // If we have an active worker group, close it
    if (agentBubbles.currentWorkerGroupBubble && inWorkerMode) {
      closeWorkerGroupBubble();
    }

    // If no active planner bubble, create one
    if (!agentBubbles.currentPlannerBubble) {
      agentBubbles.currentPlannerBubble = createPlannerBubble();
    }

    // Append text to planner buffer
    agentBubbles.plannerBuffer += text;
    
    // Convert buffer to markdown and update HTML directly
    agentBubbles.currentPlannerBubble.innerHTML = renderMarkdown(agentBubbles.plannerBuffer);
  }

  // Worker delta
  else if (agent === 'worker' && workerId) {
    // If we have an active planner bubble, close it
    if (agentBubbles.currentPlannerBubble) {
      agentBubbles.currentPlannerBubble = null;
    }

    // Ensure we have an active worker group bubble
    if (!agentBubbles.currentWorkerGroupBubble) {
      // If we have a known worker group bubble in history that is still active, use it
      if (agentBubbles.workerGroupBubbles.length > 0 && inWorkerMode) {
        agentBubbles.currentWorkerGroupBubble = agentBubbles.workerGroupBubbles[agentBubbles.workerGroupBubbles.length - 1];
      } else {
        // Fallback: create a new worker group bubble with the worker ID from the delta
        // This handles backend timing issues where worker deltas arrive before spawn events
        console.warn('No active worker group bubble available, creating new one for worker:', workerId);
        createWorkerGroupBubble([workerId]);
      }
    }

    // If we still don't have a worker group bubble after fallback, skip this delta
    if (!agentBubbles.currentWorkerGroupBubble) {
      console.error('Failed to create worker group bubble for worker:', workerId, ', skipping delta');
      return;
    }

     // Find worker sub-bubble for this worker ID
    let workerSubBubble = agentBubbles.workerSubBubbles[workerId];
    
    // Log worker delta handling
    logWorkerDeltaHandling(workerId, workerSubBubble);
    
    // If worker sub-bubble doesn't exist, create it in the current worker group bubble
    if (!workerSubBubble) {
      console.log('Creating worker sub-bubble for worker ID:', workerId);
      
      // Get the workersContainer from the current worker group bubble
      const workersContainer = agentBubbles.currentWorkerGroupBubble.querySelector('.worker-group-container');
      
      if (workersContainer) {
        // Create the worker sub-bubble DOM elements with proper CSS classes
        const workerBubble = document.createElement('div');
        workerBubble.className = 'worker-sub-bubble';
        workerBubble.id = 'worker-' + workerId;

        const workerHeader = document.createElement('div');
        workerHeader.className = 'worker-header';
        workerHeader.innerHTML = '<i class="fa-solid fa-robot" style="font-size:10px;"></i> Worker: ' + workerId;
        workerHeader.classList.add('active'); // Add active class to header

        // Worker Status Bar - Fixed at top, outside scrollable area
        const workerStatusBar = document.createElement('div');
        workerStatusBar.className = 'worker-status-bar';
        workerStatusBar.innerHTML = '<i class="fa-solid fa-circle-notch fa-spin"></i> Running...';

        const workerContent = document.createElement('div');
        workerContent.className = 'worker-content';

        workerBubble.appendChild(workerHeader);
        workerBubble.appendChild(workerStatusBar);
        workerBubble.appendChild(workerContent);
        workersContainer.appendChild(workerBubble);
        
        // Add active class to indicate worker is running
        workerBubble.classList.add('active');

        // Initialize text buffer for this worker
        agentBubbles.workerBuffers[workerId] = '';
        
        // Store reference to worker sub-bubble with text buffer reference
        workerSubBubble = {
          content: workerContent,
          buffer: agentBubbles.workerBuffers[workerId],
          finished: false,
          bubble: workerBubble,
          statusBar: workerStatusBar
        };
        
        // Store in workerSubBubbles map for future deltas
        agentBubbles.workerSubBubbles[workerId] = workerSubBubble;
        
        // Log worker sub-bubble initialization
        logWorkerSubBubbleInit(workerId);
      } else {
        // ── SELF-HEALING LOGIC ──
        // If the workersContainer is missing, the entire worker group bubble context is likely corrupted.
        // We will recreate the entire worker group bubble to restore the missing context.
        console.warn('Self-healing: workersContainer not found. Recreating worker group bubble for worker:', workerId);
        
        // 1. Create a new worker group bubble, which will set `agentBubbles.currentWorkerGroupBubble`
        createWorkerGroupBubble([workerId]);
        
        // 2. Now that the context is restored, retry finding the workersContainer
        const healedWorkersContainer = agentBubbles.currentWorkerGroupBubble.querySelector('.worker-group-container');
        
        if (healedWorkersContainer) {
          // 3. Proceed with creating the worker sub-bubble in the newly created group
          const workerBubble = document.createElement('div');
          workerBubble.className = 'worker-sub-bubble';
          workerBubble.id = 'worker-' + workerId;

          const workerHeader = document.createElement('div');
          workerHeader.className = 'worker-header';
          workerHeader.innerHTML = '<i class="fa-solid fa-robot" style="font-size:10px;"></i> Worker: ' + workerId;
          workerHeader.classList.add('active'); // Add active class to header

          // Worker Status Bar - Fixed at top, outside scrollable area
          const workerStatusBar = document.createElement('div');
          workerStatusBar.className = 'worker-status-bar';
          workerStatusBar.innerHTML = '<i class="fa-solid fa-circle-notch fa-spin"></i> Running...';

          const workerContent = document.createElement('div');
          workerContent.className = 'worker-content';

          workerBubble.appendChild(workerHeader);
          workerBubble.appendChild(workerStatusBar);
          workerBubble.appendChild(workerContent);
          healedWorkersContainer.appendChild(workerBubble);
          
          // Add active class to indicate worker is running
          workerBubble.classList.add('active');

          // Initialize text buffer for this worker
          agentBubbles.workerBuffers[workerId] = '';
          
          // Store reference to worker sub-bubble with text buffer reference
          workerSubBubble = {
            content: workerContent,
            buffer: agentBubbles.workerBuffers[workerId],
            finished: false,
            bubble: workerBubble,
            statusBar: workerStatusBar
          };
          
          // Store in workerSubBubbles map for future deltas
          agentBubbles.workerSubBubbles[workerId] = workerSubBubble;
          
          // Log worker sub-bubble initialization after healing
          logWorkerSubBubbleInit(workerId);
          console.log('Self-healing successful: Worker sub-bubble created in new group.');
        } else {
          // This should be extremely rare, but log a critical error if it happens
          console.error('Critical: Self-healing failed. workersContainer still not found after recreation.');
          return;
        }
      }
    }
    
    // Now append text to the worker sub-bubble
    if (workerSubBubble && !workerSubBubble.finished) {
      // Append text to worker buffer (NOT directly to HTML)
      workerSubBubble.buffer += text;
      
      // Convert entire buffer to markdown and update HTML directly
      workerSubBubble.content.innerHTML = renderMarkdown(workerSubBubble.buffer);
      
      // Auto-scroll worker sub-bubble to bottom
      workerSubBubble.content.scrollTop = workerSubBubble.content.scrollHeight;
      
      // Add smooth animation class for content updates
      const updateIndicator = document.createElement('div');
      updateIndicator.className = 'worker-content-update';
      updateIndicator.innerHTML = '...';
      updateIndicator.style.opacity = '0';
      workerSubBubble.content.appendChild(updateIndicator);
      
      // Smooth fade in of update indicator
      setTimeout(() => {
        updateIndicator.style.opacity = '0.5';
        setTimeout(() => {
          updateIndicator.style.opacity = '0';
        }, 200);
      }, 10);
    } else if (workerSubBubble && workerSubBubble.finished) {
      console.warn('Worker sub-bubble is finished for worker ID:', workerId, {
        bufferLength: workerSubBubble.buffer.length,
        timestamp: new Date().toISOString()
      });
    }
  }
}

// Helper to handle spawn event
function handleSpawnEvent(delta) {
  console.log(' Spawn Event Received:', {
    workerIds: delta.spawn || [],
    timestamp: new Date().toISOString()
  });

  // Close any active planner bubble
  if (agentBubbles.currentPlannerBubble) {
    agentBubbles.currentPlannerBubble = null;
  }

  // Close any active worker group bubble before creating a new one
  if (agentBubbles.currentWorkerGroupBubble && inWorkerMode) {
    closeWorkerGroupBubble();
  }

  // Create new worker group bubble with all worker IDs from spawn event
  const workerIds = delta.spawn || [];
  if (workerIds.length > 0) {
    // Add worker IDs to knownWorkerIds Set
    workerIds.forEach(workerId => {
      knownWorkerIds.add(workerId);
      console.log(' Added worker ID to known set:', workerId);
    });
    createWorkerGroupBubble(workerIds);
  }
  
  // Log worker group state after spawn
  logWorkerGroupState();
}

// Helper to close worker group bubble
function closeWorkerGroupBubble() {
  console.log(' Closing Worker Group Bubble:', {
    knownWorkerIds: Array.from(knownWorkerIds),
    totalKnownWorkers: knownWorkerIds.size,
    workerSubBubblesCount: Object.keys(agentBubbles.workerSubBubbles).length,
    workerGroupBubblesCount: agentBubbles.workerGroupBubbles.length,
    timestamp: new Date().toISOString()
  });

  // Mark all workers as finished and update visual status
  Object.keys(agentBubbles.workerSubBubbles).forEach(id => {
    agentBubbles.workerSubBubbles[id].finished = true;
    
    // Update worker bubble to completed state
    const workerBubble = agentBubbles.workerSubBubbles[id].bubble;
    if (workerBubble) {
      // Remove active class and add completed class
      workerBubble.classList.remove('active');
      workerBubble.classList.add('completed');
      
      // Update worker header to show completed status
      const workerHeader = workerBubble.querySelector('.worker-header');
      if (workerHeader) {
        workerHeader.classList.remove('active');
        workerHeader.classList.add('completed');
        workerHeader.innerHTML = '<i class="fa-solid fa-check-circle" style="color:var(--success); font-size:10px;"></i> Completed';
      }
      
      // Update worker status bar to show completed status (outside scrollable area)
      const workerStatusBar = workerBubble.querySelector('.worker-status-bar');
      if (workerStatusBar) {
        workerStatusBar.classList.add('completed');
        workerStatusBar.innerHTML = '<i class="fa-solid fa-check-circle"></i> Task Completed Successfully';
      }
    }
  });
  
  // Keep worker group bubbles in DOM - don't remove them
  // They remain visible as part of the conversation history
  
  // Clear worker buffers and sub-bubbles references for current group
  // But preserve the workerGroupBubbles array that contains the actual DOM elements
  agentBubbles.workerBuffers = {};
  agentBubbles.workerSubBubbles = {};
  
  // Clear current worker group reference (but keep in history array)
  agentBubbles.currentWorkerGroupBubble = null;
  
  // Reset flags
  // Important: when a new worker group is spawned in the same chat again, it should also create a new worker group (and not append to the old finished one)
  inWorkerMode = false;
  knownWorkerIds.clear();
  hasCreatedWorkerGroup = false;

  // Note: We do NOT remove worker group bubbles from the array
  // They remain in agentBubbles.workerGroupBubbles to preserve conversation history
  
  // Log worker group state after closing
  logWorkerGroupState();
}

// ════════════════════════════════════════════
//  Utility Functions
// ════════════════════════════════════════════
function autoResizeTextarea() {
  promptInput.style.height = 'auto';
  promptInput.style.height = Math.min(promptInput.scrollHeight, 160) + 'px';
}

// ════════════════════════════════════════════
//  Send Prompt with Agent Flow
// ════════════════════════════════════════════
function setStatus(state) {
  const label = statusBadge.querySelector('.status-label');
  if (state === 'thinking') {
    statusBadge.classList.add('thinking');
    label.textContent = 'Thinking…';
  } else {
    statusBadge.classList.remove('thinking');
    label.textContent = 'Ready';
  }
}

async function sendPrompt() {
  if (sending) return;
  const text = promptInput.value.trim();
  if (!text) return;
  sending = true;
  btnSend.disabled = true;
  btnStop.disabled = false;
  
  // Add blinking red outline to prompt box during processing
  composerInner.classList.add('prompt-processing');

  let activeId = getActiveId();
  if (!activeId) {
    const conv = createConversation();
    activeId = conv.id;
    renderSidebar();
  }

  // Add user message
  addMessage(activeId, 'user', text);
  appendLiveBubble('user', text);
  promptInput.value = '';
  autoResizeTextarea();

  const mode = modeSelect.value;

  // Get current session_id from conversation if available
  const conv = getConversation(activeId);
  const sessionId = conv?.sessionId || '';
  
  // Log session_id for debugging
  console.log('Current session_id for conversation:', {
    activeId: activeId,
    sessionId: sessionId,
    timestamp: new Date().toISOString()
  });

  setStatus('thinking');

  // Reset agent flow state for new message but preserve conversation history
  agentBubbles = {
    currentPlannerBubble: null,
    plannerBuffer: '',
    workerGroupBubbles: agentBubbles.workerGroupBubbles || [], // Preserve conversation history
    currentWorkerGroupBubble: null,
    workerBuffers: {},
    workerSubBubbles: {}
  };
  
  // Reset all flags for new message
  knownWorkerIds.clear();
  hasCreatedWorkerGroup = false;
  inWorkerMode = false;
  
  console.log(' Agent flow state reset:', {
    hasCreatedWorkerGroup: hasCreatedWorkerGroup,
    timestamp: new Date().toISOString()
  });

  // Store activeId for use in streamAgentResponse to save session_id
  let activeConversationId = activeId;
  let currentSessionId = sessionId;

  // Process response and get updated session_id
  currentSessionId = await streamAgentResponse({
    prompt: text,
    sessionId: sessionId,
    mode,
    activeId: activeConversationId,
    onDelta(delta) {
      // Log session_id from delta if present
      if (delta.session_id) {
        console.log('Received session_id in delta:', {
          session_id: delta.session_id,
          timestamp: new Date().toISOString()
        });
      }
      
      // Handle spawn event FIRST - before any delta processing
      // This ensures worker group bubbles are created before worker deltas
      if (delta.spawn && Array.isArray(delta.spawn)) {
        handleSpawnEvent(delta);
      }
      
      // Handle different delta types
      if (delta.agent === 'planner' || (delta.agent === 'worker' && delta.id)) {
        appendAgentDelta(delta);
      }
      
      // Log worker group state after delta processing
      logWorkerGroupState();
      
      // Update conversation with session_id if provided
      if (delta.session_id && activeId) {
        updateSessionId(activeId, delta.session_id);
        currentSessionId = delta.session_id;
      }
    },
    onError(err) {
      // Display error in planner bubble
      if (!agentBubbles.currentPlannerBubble) {
        agentBubbles.currentPlannerBubble = createPlannerBubble();
      }
      // Append error to planner buffer and update HTML directly
      agentBubbles.plannerBuffer += ` Error: ${err}`;
      agentBubbles.currentPlannerBubble.innerHTML = renderMarkdown(agentBubbles.plannerBuffer);
      console.error(' Agent error:', err, {
        plannerBufferLength: agentBubbles.plannerBuffer.length,
        timestamp: new Date().toISOString()
      });
    },
    onDone() {
      // Close any active worker group
      closeWorkerGroupBubble();
      
      // Log final worker group state
      logWorkerGroupState();
      
      renderSidebar();
      setStatus('idle');
      sending = false;
      btnSend.disabled = false;
      btnStop.disabled = true;
      
      // Remove blinking red outline from prompt box
      composerInner.classList.remove('prompt-processing');
    }
  });
  
  // Save session_id after response is complete
  if (currentSessionId) {
    updateSessionId(activeId, currentSessionId);
  }
  
  // Save conversation HTML after all messages are processed
  saveCurrentConversationHTML();
}

// ════════════════════════════════════════════
//  Event Listeners
// ════════════════════════════════════════════
btnSend.addEventListener('click', sendPrompt);
btnStop.addEventListener('click', stopRequest);
promptInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    sendPrompt();
  }
});

// ─────────────────────────────────────────────
//  Stop Button Handler
// ─────────────────────────────────────────────
async function stopRequest() {
  if (!sending) return;
  
  // Disable stop button to prevent multiple clicks
  btnStop.disabled = true;
  
  try {
    // Get current session_id from conversation if available
    const activeId = getActiveId();
    const conv = getConversation(activeId);
    const sessionId = conv?.sessionId || '';
    
    // Call the stop API endpoint
    const res = await fetch('/api/adminagent/stop', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ session_id: sessionId })
    });
    
    if (res.ok) {
      console.log('Request stopped successfully');
      
      // Close any active worker group
      closeWorkerGroupBubble();
      
      // Log final worker group state
      logWorkerGroupState();
      
      renderSidebar();
      setStatus('idle');
      sending = false;
      btnSend.disabled = false;
      
      // Remove blinking red outline from prompt box
      composerInner.classList.remove('prompt-processing');
    } else {
      // Show error message
      console.error('Failed to stop request:', await res.text());
      btnStop.disabled = false; // Re-enable stop button on error
    }
  } catch (error) {
    console.error('Error stopping request:', error);
    btnStop.disabled = false; // Re-enable stop button on error
  }
}

// Auto-resize textarea on input
promptInput.addEventListener('input', autoResizeTextarea);

btnNewChat.addEventListener('click', newChat);

btnToggleSidebar.addEventListener('click', () => {
  sidebar.classList.toggle('collapsed');
  sidebarOverlay.classList.toggle('visible', !sidebar.classList.contains('collapsed'));
});
sidebarOverlay.addEventListener('click', () => {
  sidebar.classList.add('collapsed');
  sidebarOverlay.classList.remove('visible');
});

// Panel resizer (horizontal)
{
  let resizing = false, startX, startW;
  panelResizer.addEventListener('mousedown', (e) => {
    resizing = true; startX = e.clientX; startW = editorPanel.offsetWidth;
    document.body.style.cursor = 'col-resize'; e.preventDefault();
  });
  document.addEventListener('mousemove', (e) => {
    if (!resizing) return;
    const w = Math.min(Math.max(startW + (startX - e.clientX), 300), window.innerWidth * 0.6);
    editorPanel.style.width = w + 'px';
  });
  document.addEventListener('mouseup', () => { resizing = false; document.body.style.cursor = ''; });
}

// Editor resizer (vertical)
{
  let resizing = false, startY, startH;
  editorResizer.addEventListener('mousedown', (e) => {
    resizing = true; startY = e.clientY; startH = htmlCode.offsetHeight;
    document.body.style.cursor = 'row-resize'; e.preventDefault();
  });
  document.addEventListener('mousemove', (e) => {
    if (!resizing) return;
    const h = Math.min(Math.max(startH + (e.clientY - startY), 50), 600);
    htmlCode.style.flex = 'none';
    htmlCode.style.height = h + 'px';
  });
  document.addEventListener('mouseup', () => { resizing = false; document.body.style.cursor = ''; });
}

// ════════════════════════════════════════════
//  Init
// ════════════════════════════════════════════
(function init() {
  const convs = loadConversations();
  let activeId = getActiveId();

  if (!convs.length) {
    newChat();
  } else {
    if (!activeId || !convs.find(c => c.id === activeId)) {
      activeId = convs[0].id;
      setActiveId(activeId);
    }
    switchConversation(activeId);
  }
  renderSidebar();

  // Collapse sidebar on mobile by default
  if (window.innerWidth <= 768) {
    sidebar.classList.add('collapsed');
  }
  
  // Initialize syntax highlighting
  hljs.highlightAll();
})();