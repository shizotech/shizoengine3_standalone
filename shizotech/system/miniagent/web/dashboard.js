/* ── miniagent dashboard ──
 * One page for every node of the network: the sidebar lists the nodes (this one and
 * the others it sees on ShizoNet), their workspaces and sessions; the main pane has
 * the chat of a session, the tasks and the architecture graph of a workspace.
 *
 * Talking to nodes: NodeApi.at(nodeId) (components/nodeapi.js). A call for another
 * node goes to /api/nodes/<id>/api/... of this node, which asks that node over
 * ShizoNet — the API is the same for every node (../workspace_spec.md).
 *
 * Staying current: one long-poll per node on /api/live (it answers when something the
 * page shows has changed). What is drawn is patched in place (reconcile()), never
 * rebuilt, so nothing flashes when an update arrives.
 * No CDN, no build step.
 */

'use strict';

/* ── helpers ── */
const $ = (id) => document.getElementById(id);

const arr = (x) => {
  if (Array.isArray(x)) return x;
  if (x && typeof x === 'object') return Object.values(x);
  return [];
};

const esc = (s) => String(s == null ? '' : s)
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

const num = (x) => { const n = Number(x); return Number.isFinite(n) ? n : 0; };
const fmtNum = (x) => num(x).toLocaleString();
const enc = encodeURIComponent;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const truthy = (x) => x === true || x === 1 || x === '1' || x === 'true';

const fmtTokens = (x) => {
  const n = num(x);
  if (n >= 1e6) return (n / 1e6).toFixed(n >= 1e7 ? 0 : 1) + 'M';
  if (n >= 1e3) return (n / 1e3).toFixed(n >= 1e4 ? 0 : 1) + 'k';
  return String(n);
};

const timeAgo = (t) => {
  t = num(t);
  if (!t) return '';
  const sec = Math.max(0, Math.floor((Date.now() - t) / 1000));
  if (sec < 60) return 'just now';
  const min = Math.floor(sec / 60);
  if (min < 60) return min + ' min ago';
  const hour = Math.floor(min / 60);
  if (hour < 24) return hour + ' h ago';
  return Math.floor(hour / 24) + ' d ago';
};

const clip = (s, n) => { s = String(s == null ? '' : s); return s.length > n ? s.slice(0, n - 1) + '…' : s; };
const oneLine = (s) => String(s == null ? '' : s).replace(/\s+/g, ' ').trim();

function el(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text != null) e.textContent = text;
  return e;
}

const icon = (name) => '<i class="fa-solid fa-' + name + '" aria-hidden="true"></i>';

function store(key, value) {
  try {
    if (value === undefined) return localStorage.getItem('miniagent_' + key);
    if (value === null) localStorage.removeItem('miniagent_' + key);
    else localStorage.setItem('miniagent_' + key, String(value));
  } catch (e) { /* private mode */ }
  return null;
}

/* Patch the children of `parent` to match `items`: an element is kept for a key that is
 * still there (update() changes what differs), made for a new one, removed for one that
 * went. Nothing is rebuilt, so an update never flashes and keeps scroll and focus. */
function reconcile(parent, items, keyOf, create, update) {
  const old = new Map();
  Array.from(parent.children).forEach((c) => { if (c.dataset.key != null) old.set(c.dataset.key, c); else c.remove(); });
  let prev = null;
  items.forEach((item) => {
    const key = String(keyOf(item));
    let node = old.get(key);
    if (node) old.delete(key);
    else { node = create(item); node.dataset.key = key; }
    update(node, item);
    const want = prev ? prev.nextSibling : parent.firstChild;
    if (node !== want) parent.insertBefore(node, want);
    prev = node;
  });
  old.forEach((n) => n.remove());
}

/* set innerHTML only when it differs from what this element was last given */
function setHtml(node, html) {
  if (node._html !== html) { node.innerHTML = html; node._html = html; }
}
function setText(node, text) {
  text = String(text == null ? '' : text);
  if (node.textContent !== text) node.textContent = text;
}
function setClass(node, cls) {
  if (node.className !== cls) node.className = cls;
}

let markdownRenderer = null;
function mdRender(text) {
  if (!markdownRenderer) {
    markdownRenderer = typeof window.markdownit === 'function'
      ? window.markdownit({ breaks: true })
      : { render: (s) => '<p>' + esc(s).replace(/\n/g, '<br>') + '</p>' };
  }
  try { return markdownRenderer.render(String(text || '')); } catch (e) { return '<p>' + esc(text || '') + '</p>'; }
}

function toast(message, kind = 'info', timeout = 4200) {
  const box = $('toasts');
  const t = el('div', 'toast ' + kind, String(message || ''));
  box.appendChild(t);
  setTimeout(() => {
    t.style.opacity = '0';
    t.style.transform = 'translateX(18px)';
    setTimeout(() => t.remove(), 240);
  }, timeout);
}

/* ── status vocabulary ── */
const statusClass = (status) => {
  const s = String(status || '').toLowerCase();
  if (s === 'queued') return 'queued';
  if (['running', 'starting', 'waiting', 'planned', 'generating', 'dispatching', 'checkpoint'].includes(s)) return 'running';
  if (['done', 'finished', 'completed'].includes(s)) return 'done';
  if (s === 'question') return 'question';
  if (['failed', 'error', 'cancelled', 'lost'].includes(s)) return 'failed';
  return 'stopped';
};
const statusLabel = (status) => {
  const s = String(status || 'idle').toLowerCase();
  const map = { done: 'finished', waiting: 'ready', starting: 'starting', question: 'needs input', queued: 'queued' };
  return map[s] || s;
};
const isActive = (status) => ['starting', 'running', 'waiting', 'queued'].includes(String(status || '').toLowerCase());
const isGenerating = (status) => String(status || '').toLowerCase() === 'running';
const isTerminal = (status) => ['done', 'failed', 'question', 'stopped'].includes(String(status || '').toLowerCase());

/* ── state ── */
const state = {
  nodes: [],                 // [{id, name, kind, local, online, model, description, ...}]
  peersRev: -1,
  nodeData: {},              // node id -> what is known of that node (nd())
  openNodes: new Set(),
  openWs: new Set(),         // "<node>/<workspace>"
  sel: { node: null, ws: null, session: null },
  view: 'welcome',           // welcome | workspace | globalTasks
  tab: 'chat',
  session: null,             // the open session (GET /api/sessions/<id>)
  selGen: 0,                 // counts selections: an answer for an older one is dropped
  stream: null,
  streamSince: 0,
  pendingUser: null,
  composerMode: 'normal',
  composerEffort: 'medium',
  showDetails: true,
  notifications: [],         // [{node, message, time}]
  notifUnseen: 0,
  taskSig: '',
  dialogNode: null,          // the node of the settings dialog
  newWs: null,               // {node, parent} of the workspace dialog
};

function nd(id) {
  id = String(id);
  if (!state.nodeData[id]) {
    state.nodeData[id] = {
      loaded: false, loading: false, error: '',
      workspaces: [], byId: {}, general: null, projectsDir: '',
      settings: { max_sessions: 2 }, stats: {}, sessions: [],
      rev: 0, treeRev: -1, goalsRev: -1, notifCount: -1,
      liveRunning: false, liveAbort: null, linkOk: true,
    };
  }
  return state.nodeData[id];
}

const nodeById = (id) => state.nodes.find((n) => n.id === id) || null;
const api = (nodeId) => NodeApi.at(nodeId || 'local');
const wsKey = (node, ws) => node + '/' + ws;
const selApi = () => api(state.sel.node);

function workspaceOf(node, ws) {
  const d = nd(node);
  if (ws === 'node') return d.general;
  return d.byId[ws] || null;
}
function sessionsOf(node, ws) {
  return nd(node).sessions.filter((s) => String(s.workspace_id) === String(ws))
    .sort((a, b) => num(b.created) - num(a.created));
}
function childWorkspaces(node, parent) {
  const d = nd(node);
  const isRoot = !parent;
  return d.workspaces.filter((w) => {
    const p = String(w.parent || '');
    if (isRoot) return !p || p === 'root' || !d.byId[p];
    return p === String(parent);
  }).sort((a, b) => String(a.name || a.id).localeCompare(String(b.name || b.id)));
}

/* ── nodes ── */
async function loadNodes() {
  let data = null;
  try {
    data = await NodeApi.get('/api/nodes');
  } catch (e) {
    // a node without the /api/nodes route (an older one): it is the only node
    data = { nodes: [{ id: 'local', name: 'This node', kind: 'node', local: true, online: true }], rev: 0 };
  }
  state.nodes = arr(data.nodes).map((n) => Object.assign({}, n, {
    id: String(n.id), local: truthy(n.local), online: truthy(n.online), api: n.api == null ? true : truthy(n.api),
  }));
  state.peersRev = num(data.rev);

  const local = nodeById('local');
  if (local) $('brandSub').textContent = local.name || 'control console';

  state.nodes.forEach((n) => {
    if (n.kind === 'node' && n.online && (state.openNodes.has(n.id) || state.sel.node === n.id)) ensureNode(n.id);
  });
  renderTree();
  renderHeader();
}

/* load a node's workspaces (once) and keep following it */
function ensureNode(id) {
  const d = nd(id);
  if (!d.loaded && !d.loading) loadNode(id);
  startLive(id);
}

async function loadNode(id) {
  const d = nd(id);
  d.loading = true;
  d.error = '';
  renderTree();
  try {
    const data = await api(id).get('/api/workspaces');
    d.workspaces = arr(data.workspaces).filter((w) => w && w.id && String(w.id) !== 'root')
      .map((w) => Object.assign({}, w, { id: String(w.id) }));
    d.byId = {};
    d.workspaces.forEach((w) => { d.byId[w.id] = w; });
    d.general = data.general ? Object.assign({}, data.general, { id: 'node' }) : null;
    d.projectsDir = String(data.projects_dir || '');
    if (data.settings) d.settings = data.settings;
    if (data.stats) d.stats = data.stats;
    d.loaded = true;
  } catch (e) {
    d.error = e.message;
  }
  d.loading = false;

  // the selected workspace was removed on that node
  if (state.sel.node === id && state.sel.ws && d.loaded && !workspaceOf(id, state.sel.ws)) {
    clearSelection();
  }
  renderTree();
  renderHeader();
}

/* ── the live feed of a node ── */
function wantsLive(id) {
  const n = nodeById(id);
  if (!n || n.kind !== 'node' || !n.online) return false;
  return id === 'local' || state.openNodes.has(id) || state.sel.node === id;
}

// the page holds a long-poll for its own node and for the node it works on; another
// open node is asked every few seconds (a browser has only a few connections per host)
const livePrimary = (id) => id === 'local' || state.sel.node === id;

async function startLive(id) {
  const d = nd(id);
  if (d.liveRunning) return;
  d.liveRunning = true;
  let fails = 0;

  while (wantsLive(id)) {
    const long = livePrimary(id);
    const ws = state.sel.node === id && state.sel.ws ? state.sel.ws : '';
    const ctl = new AbortController();
    d.liveAbort = ctl;
    try {
      const snap = await api(id).get('/api/live?since=' + d.rev + '&wait=' + (long ? 20000 : 0) +
        (ws ? '&workspace=' + enc(ws) : ''), { signal: ctl.signal });
      fails = 0;
      if (!d.linkOk) { d.linkOk = true; }
      applyLive(id, snap);
      if (!long) await sleep(5000);
    } catch (e) {
      if (e.name === 'AbortError') continue;      // the selection changed: ask again with the new workspace
      fails++;
      d.linkOk = false;
      updateLamps();
      if (e.status === 404 && fails > 1) break;   // a node without the live feed
      await sleep(Math.min(15000, 1500 * fails));
    }
  }
  d.liveRunning = false;
  d.liveAbort = null;
}

function restartLive(id) {
  const d = state.nodeData[id];
  if (d && d.liveAbort) d.liveAbort.abort();
}

function applyLive(id, snap) {
  if (!snap || typeof snap !== 'object') return;
  const d = nd(id);
  d.rev = num(snap.rev);
  d.sessions = arr(snap.sessions).map((s) => Object.assign({}, s, { id: String(s.id) }));
  if (snap.stats) d.stats = snap.stats;
  if (snap.settings) d.settings = snap.settings;

  if (num(snap.tree_rev) !== d.treeRev) {
    const first = d.treeRev < 0;
    d.treeRev = num(snap.tree_rev);
    if (!first || (!d.loaded && !d.loading)) loadNode(id);
  }

  if (id === 'local' && snap.peers_rev != null && num(snap.peers_rev) !== state.peersRev) loadNodes();

  if (num(snap.notifications) !== d.notifCount) {
    const first = d.notifCount < 0;
    d.notifCount = num(snap.notifications);
    loadNotifications(id, !first);
  }

  if (state.sel.node === id) {
    // the open session: its status / title / tokens as the node has them
    if (state.session) {
      const live = d.sessions.find((s) => s.id === state.session.id);
      if (!live) {
        // deleted somewhere else
        toast('The session was deleted.', 'warn');
        state.sel.session = null;
        state.session = null;
        closeStream();
        renderChatEmpty();
      } else {
        state.session.title = live.title;
        state.session.token_usage = live.token_usage;
        state.session.mode = live.mode;
        // the stream owns the status while it is open; without one (a finished session
        // that another page or a gateway continued) the feed brings it back to life
        if (!state.stream && state.session.status !== live.status) {
          state.session.status = live.status;
          if (isActive(live.status)) reloadSession();
        }
      }
    }
    if (state.tab === 'tasks' && state.view === 'workspace') {
      if (num(snap.goals_rev) !== d.goalsRev) d.goalsRev = num(snap.goals_rev);
      scheduleTasks();
    }
  }
  if (state.view === 'globalTasks') scheduleGlobalTasks();

  renderTree();
  renderStats();
  renderHeader();
  renderSessionHeader();
}

/* ── the tree: nodes › workspaces › sessions ── */
function renderTree() {
  const host = $('nodeTree');
  const online = state.nodes.filter((n) => n.online && n.kind === 'node').length;
  setText($('nodeCount'), state.nodes.length ? online + ' online' : '');

  reconcile(host, state.nodes, (n) => n.id, () => {
    const box = el('div', 'tree-node');
    box.innerHTML = '<div class="tree-row node-row"></div><div class="tree-children"></div>';
    return box;
  }, (box, n) => {
    const d = nd(n.id);
    const isNode = n.kind === 'node';
    const open = isNode && state.openNodes.has(n.id);
    const busy = d.sessions.some((s) => isGenerating(s.status)) || (!d.loaded && truthy(n.busy));
    setClass(box, 'tree-node' + (open ? ' is-open' : '') + (n.online ? '' : ' offline'));
    box.dataset.node = n.id;

    const row = box.children[0];
    const sub = !isNode ? 'gateway' : (n.model ? clip(n.model, 18) : '');
    setHtml(row,
      '<button class="tree-main" data-act="toggle-node" title="' + esc(nodeTitle(n)) + '">' +
        '<i class="fa-solid fa-chevron-right tree-caret' + (isNode ? '' : ' leaf') + '"></i>' +
        '<span class="node-dot' + (n.online ? (busy ? ' busy' : ' online') : '') + '"></span>' +
        '<span class="tree-name">' + esc(n.name || n.id) + '</span>' +
        (n.local ? '<span class="badge local">this node</span>' : '') +
        (!isNode ? '<span class="badge gateway">gateway</span>' : '') +
        (!n.online ? '<span class="badge off">offline</span>' : '') +
        (isNode && n.online && !n.local && sub ? '<span class="tree-sub">' + esc(sub) + '</span>' : '') +
      '</button>' +
      (isNode && n.online ? '<span class="tree-actions">' +
        '<button class="tree-action" data-act="add-ws" title="New workspace on ' + esc(n.name) + '">' + icon('folder-plus') + '</button>' +
      '</span>' : ''));

    const kids = box.children[1];
    kids.hidden = !open;
    if (!open) return;

    if (!n.api && !n.local) { renderNote(kids, 'This node runs an older version: it has no API over ShizoNet.', true); return; }
    if (d.error && !d.loaded) { renderNote(kids, 'Could not load: ' + d.error, true); return; }
    if (!d.loaded) { renderNote(kids, 'Loading…'); return; }

    const items = [];
    if (d.general) items.push({ type: 'w', ws: d.general, general: true });
    childWorkspaces(n.id, '').forEach((w) => items.push({ type: 'w', ws: w }));
    renderWorkspaceList(kids, n.id, items);
    if (!items.length) renderNote(kids, 'No workspaces yet. Add one with the folder button.');
  });

  if (!state.nodes.length) host.innerHTML = '<div class="tree-note">Looking for nodes…</div>';
}

function nodeTitle(n) {
  const parts = [n.name || n.id];
  if (n.description) parts.push(n.description);
  if (n.model) parts.push('model: ' + n.model);
  if (n.ip) parts.push(n.ip);
  if (!n.online) parts.push('offline');
  return parts.join('\n');
}

function renderNote(kids, text, error) {
  let note = kids.querySelector(':scope > .tree-note');
  Array.from(kids.children).forEach((c) => { if (c !== note) c.remove(); });
  if (!note) { note = el('div', 'tree-note'); kids.appendChild(note); }
  setClass(note, 'tree-note' + (error ? ' error' : ''));
  setText(note, text);
}

// items: [{type:'w', ws, general}] or [{type:'s', s}] mixed, in the order they show
function renderWorkspaceList(container, nodeId, items) {
  reconcile(container, items, (it) => (it.type === 'w' ? 'w:' + it.ws.id : 's:' + it.s.id), (it) => {
    if (it.type === 's') return el('div', 'tree-row session-row');
    const box = el('div', 'tree-ws');
    box.innerHTML = '<div class="tree-row ws-row"></div><div class="tree-children"></div>';
    return box;
  }, (node, it) => {
    if (it.type === 's') { updateSessionRow(node, nodeId, it.s); return; }

    const w = it.ws;
    const key = wsKey(nodeId, w.id);
    const open = state.openWs.has(key);
    const selected = state.sel.node === nodeId && state.sel.ws === w.id;
    const sessions = sessionsOf(nodeId, w.id);
    const children = it.general ? [] : childWorkspaces(nodeId, w.id);
    const running = sessions.filter((s) => isGenerating(s.status)).length;
    const asking = sessions.filter((s) => String(s.status) === 'question').length;

    setClass(node, 'tree-ws' + (open ? ' is-open' : ''));
    const row = node.children[0];
    setClass(row, 'tree-row ws-row' + (selected && !state.sel.session ? ' selected' : ''));
    row.dataset.node = nodeId;
    row.dataset.ws = w.id;
    setHtml(row,
      '<button class="tree-main" data-act="select-ws" title="' + esc((w.description ? w.description + '\n' : '') + (w.path || '')) + '">' +
        '<i class="fa-solid fa-chevron-right tree-caret' + (sessions.length || children.length ? '' : ' leaf') + '"></i>' +
        '<i class="fa-solid fa-' + (it.general ? 'home' : (open ? 'folder-open' : 'folder')) + ' tree-icon"></i>' +
        '<span class="tree-name">' + esc(w.name || w.id) + '</span>' +
        (running ? '<span class="status-dot running" title="' + running + ' running"></span>' : '') +
        (asking ? '<span class="status-dot question" title="' + asking + ' need input"></span>' : '') +
        (sessions.length ? '<span class="tree-sub">' + sessions.length + '</span>' : '') +
      '</button>' +
      '<span class="tree-actions">' +
        '<button class="tree-action" data-act="add-session" title="New session in ' + esc(w.name) + '">' + icon('plus') + '</button>' +
        (it.general ? '' : '<button class="tree-action" data-act="add-sub" title="New sub-workspace in ' + esc(w.name) + '">' + icon('folder-plus') + '</button>') +
        (it.general ? '' : '<button class="tree-action danger" data-act="del-ws" title="' +
          (children.length ? 'Remove its sub-workspaces first' : 'Remove ' + esc(w.name) + ' from this node (its files stay on disk)') + '"' +
          (children.length ? ' disabled' : '') + '>' + icon('trash') + '</button>') +
      '</span>');

    const kids = node.children[1];
    kids.hidden = !open;
    if (!open) return;
    const sub = sessions.map((s) => ({ type: 's', s })).concat(children.map((c) => ({ type: 'w', ws: c })));
    renderWorkspaceList(kids, nodeId, sub);
  });
}

function updateSessionRow(row, nodeId, s) {
  const selected = state.sel.node === nodeId && state.sel.session === s.id;
  const gen = isGenerating(s.status);
  setClass(row, 'tree-row session-row' + (selected ? ' selected' : ''));
  row.dataset.node = nodeId;
  row.dataset.ws = s.workspace_id;
  row.dataset.session = s.id;
  setHtml(row,
    '<button class="tree-main" data-act="select-session" title="' + esc((s.title || 'Session') + '\n' + statusLabel(s.status) + (s.mode === 'goal' ? ' · loop' : '')) + '">' +
      '<span class="status-dot ' + (gen ? 'running' : statusClass(s.status)) + '"></span>' +
      '<span class="tree-name">' + esc(s.title || 'Session') + '</span>' +
      '<span class="tree-sub">' + (num(s.token_usage) ? fmtTokens(s.token_usage) : '') + '</span>' +
    '</button>' +
    '<span class="tree-actions">' +
      '<button class="tree-action danger" data-act="del-session" title="Delete this session and its chat">' + icon('trash') + '</button>' +
    '</span>');
}

/* ── selection ── */
function saveSelection() {
  store('sel', JSON.stringify(state.sel));
  store('open_nodes', JSON.stringify(Array.from(state.openNodes)));
  store('open_ws', JSON.stringify(Array.from(state.openWs)));
}

function clearSelection() {
  const node = state.sel.node;
  state.sel = { node: null, ws: null, session: null };
  state.session = null;
  state.selGen++;
  closeStream();
  showView('welcome');
  saveSelection();
  if (node) restartLive(node);
}

async function selectWorkspace(nodeId, wsId, keepSession) {
  const changedNode = state.sel.node !== nodeId;
  const previous = state.sel.node;
  state.sel = { node: nodeId, ws: wsId, session: keepSession || null };
  state.selGen++;
  state.openNodes.add(nodeId);
  if (!keepSession) {
    state.session = null;
    closeStream();
    renderChatEmpty();
  }
  state.taskSig = '';
  saveSelection();
  ensureNode(nodeId);
  if (changedNode && previous) restartLive(previous);
  restartLive(nodeId);
  showView('workspace');
  renderTree();
  renderStats();
  renderSessionHeader();
  if (state.tab === 'tasks') loadTasks();
  if (state.tab === 'architecture') loadArchitecture();
}

async function selectSession(nodeId, wsId, sessionId) {
  if (state.sel.node !== nodeId || state.sel.ws !== wsId) await selectWorkspace(nodeId, wsId, sessionId);
  state.sel.session = sessionId;
  state.openWs.add(wsKey(nodeId, wsId));
  saveSelection();
  if (state.tab !== 'chat') showTab('chat');
  renderTree();
  await openSession(sessionId);
}

/* ── header / stats ── */
function renderHeader() {
  if (state.view === 'globalTasks') {
    setText($('breadcrumb'), 'all nodes');
    setText($('pageTitle'), 'All tasks');
    setText($('pageMeta'), 'Scheduled goals and sessions of every workspace of every online node');
    return;
  }
  const n = state.sel.node ? nodeById(state.sel.node) : null;
  const w = n ? workspaceOf(n.id, state.sel.ws) : null;
  if (!n || !w) {
    setText($('breadcrumb'), 'nodes');
    setText($('pageTitle'), 'miniagent');
    const online = state.nodes.filter((x) => x.online && x.kind === 'node').length;
    setText($('pageMeta'), state.nodes.length ? online + ' node' + (online === 1 ? '' : 's') + ' online' : '');
    return;
  }
  const d = nd(n.id);
  const parent = w.parent && String(w.parent) !== 'root' ? d.byId[w.parent] : null;
  setText($('breadcrumb'), (n.name || n.id) + (parent ? ' / ' + parent.name : ''));
  setText($('pageTitle'), w.name || w.id);
  const count = sessionsOf(n.id, w.id).length;
  setText($('pageMeta'), (w.path || '') + '  ·  ' + count + ' session' + (count === 1 ? '' : 's'));
}

function sumTokens(map) {
  let t = 0;
  if (map && typeof map === 'object') Object.values(map).forEach((v) => { t += num(v); });
  return t;
}

function renderStats() {
  const id = state.sel.node || 'local';
  const n = nodeById(id);
  const d = nd(id);
  const st = d.stats || {};
  const tokens = sumTokens(st.token_usage);
  const active = num(st.active_sessions);
  const max = num(d.settings && d.settings.max_sessions) || num(st.max_sessions);

  setHtml($('statsPanel'),
    '<div class="stat-cell"><span>Node</span><b title="' + esc(n ? n.name : '') + '">' + esc(clip(n ? n.name : '—', 12)) + '</b></div>' +
    '<div class="stat-cell"><span>Sessions</span><b>' + active + ' / ' + (max || '—') + '</b></div>' +
    '<div class="stat-cell"><span>Processes</span><b>' + num(st.running_processes) + '</b></div>' +
    '<div class="stat-cell"><span>Tokens</span><b>' + fmtTokens(tokens) + '</b></div>');

  setHtml($('headerStats'),
    '<span class="stat-chip">' + icon('bolt') + ' <b>' + fmtTokens(tokens) + '</b> tok</span>' +
    '<span class="stat-chip">active <b>' + active + '</b> / ' + (max || '—') + '</span>');
  updateLamps();
}

function updateLamps() {
  let busy = false;
  let warn = false;
  Object.keys(state.nodeData).forEach((id) => {
    const d = state.nodeData[id];
    if (!wantsLive(id)) return;
    if (!d.linkOk) warn = true;
    d.sessions.forEach((s) => {
      if (isGenerating(s.status)) busy = true;
      if (String(s.status) === 'question') warn = true;
    });
  });
  $('lampLink').classList.toggle('on', nd('local').linkOk && state.nodes.length > 0);
  $('lampBusy').classList.toggle('on', busy);
  $('lampWarn').classList.toggle('on', warn);
}

/* ── views / tabs ── */
function showView(view) {
  state.view = view;
  $('workspaceView').classList.toggle('hidden', view !== 'workspace');
  $('globalTasksView').classList.toggle('hidden', view !== 'globalTasks');
  $('welcomeView').classList.toggle('hidden', view !== 'welcome');
  $('btnGlobalTasks').classList.toggle('active', view === 'globalTasks');
  renderHeader();
}

function showTab(tab) {
  state.tab = tab;
  store('tab', tab);
  document.querySelectorAll('.tab').forEach((b) => b.classList.toggle('active', b.dataset.tab === tab));
  $('tabChat').classList.toggle('hidden', tab !== 'chat');
  $('tabTasks').classList.toggle('hidden', tab !== 'tasks');
  $('tabArchitecture').classList.toggle('hidden', tab !== 'architecture');
  if (tab === 'tasks') { state.taskSig = ''; loadTasks(); }
  if (tab === 'architecture') loadArchitecture();
  if (tab === 'chat') scrollChat(true);
}

/* ══ chat ══════════════════════════════════════════════════════════════════ */

/* What is in the chat pane is a list of items, the same for a transcript that is read
 * from chat.json, for the running turn the node hands over (session.turn) and for the
 * events of the stream:
 *   user | text | reasoning | tool | report | error | notice | milestone
 * A reasoning item and a tool item are one line that opens: the preview stays small,
 * the whole reasoning / every parameter and the result are one click away. */
const chat = {
  textEl: null, textRaw: '', textTimer: 0,
  reasonEl: null,
  tools: new Map(),          // tool id -> element
  stick: true,
  earlier: [],               // items of the transcript that are not drawn yet (older ones)
};

const SYSTEM_MARKS = ['<---SYTEM MESSAGE--->', '<!---SYTEM MESSAGE---!>'];
const PAGE_ITEMS = 160;

function chatBox() { return $('chatMessages'); }

function chatReset() {
  chatBox().innerHTML = '';
  chat.textEl = null; chat.textRaw = '';
  chat.reasonEl = null;
  chat.tools = new Map();
  chat.earlier = [];
  chat.stick = true;
  $('btnScrollDown').classList.add('hidden');
}

function renderChatEmpty() {
  chatReset();
  const w = state.sel.node ? workspaceOf(state.sel.node, state.sel.ws) : null;
  const box = el('div', 'empty-state');
  box.innerHTML = icon('comments') +
    '<div class="empty-title">' + (w ? 'New session in ' + esc(w.name) : 'No workspace selected') + '</div>' +
    '<div>' + (w ? 'Write a prompt below to start one, or pick a session in the sidebar.' : 'Pick a workspace in the sidebar.') + '</div>';
  chatBox().appendChild(box);
}

function nearBottom() {
  const b = chatBox();
  return b.scrollHeight - b.scrollTop - b.clientHeight < 90;
}
function scrollChat(force) {
  const b = chatBox();
  if (force || chat.stick) { b.scrollTop = b.scrollHeight; chat.stick = true; $('btnScrollDown').classList.add('hidden'); }
  else $('btnScrollDown').classList.remove('hidden');
}

function appendMsg(node, before) {
  const empty = chatBox().querySelector(':scope > .empty-state');
  if (empty) empty.remove();
  if (before) chatBox().insertBefore(node, before);
  else chatBox().appendChild(node);
  return node;
}

function endRun() {           // what follows starts a new text / reasoning block
  flushText();
  chat.textEl = null; chat.textRaw = '';
  if (chat.reasonEl) chat.reasonEl.classList.remove('live');
  chat.reasonEl = null;
}

function addUser(text, before) {
  if (!text) return null;
  if (!before) endRun();
  const m = el('div', 'msg user');
  m.innerHTML = '<div class="msg-label"><span>You</span></div><div class="msg-body"></div>';
  m.lastChild.textContent = text;
  return appendMsg(m, before);
}

function makeText(text, before) {
  const m = el('div', 'msg agent');
  m.innerHTML = '<div class="msg-label"><span>Agent</span></div><div class="msg-body"></div>';
  m.lastChild.innerHTML = mdRender(text);
  return appendMsg(m, before);
}

function addTextDelta(text) {
  if (!text) return;
  if (chat.reasonEl) { chat.reasonEl.classList.remove('live'); chat.reasonEl = null; }
  if (!chat.textEl) {
    chat.textEl = makeText('');
    chat.textRaw = '';
  }
  chat.textRaw += text;
  // markdown of the whole block again per token is quadratic: draw at most every 70 ms
  if (!chat.textTimer) chat.textTimer = setTimeout(flushText, 70);
}

function flushText() {
  if (chat.textTimer) { clearTimeout(chat.textTimer); chat.textTimer = 0; }
  if (chat.textEl) {
    chat.textEl.lastChild.innerHTML = mdRender(chat.textRaw);
    scrollChat();
  }
}

/* the sentence that is being thought right now (the preview line of a reasoning block) */
function lastSentence(text) {
  const t = oneLine(text);
  if (!t) return '';
  const tail = t.length > 600 ? t.slice(-600) : t;
  const parts = tail.split(/(?<=[.!?])\s+/);
  let s = parts[parts.length - 1];
  if (s.length < 24 && parts.length > 1) s = parts[parts.length - 2] + ' ' + s;
  return clip(s, 220);
}

function makeReasoning(text, before, live) {
  const m = el('div', 'msg reasoning' + (live ? ' live' : ''));
  m.innerHTML =
    '<button class="detail-head" data-act="toggle-detail" title="Show the whole reasoning">' +
      '<i class="fa-solid fa-chevron-right detail-caret"></i>' +
      '<span class="detail-kind">' + icon('brain') + ' Reasoning</span>' +
      '<span class="detail-preview"></span>' +
      '<span class="detail-meta"></span>' +
      '<span class="detail-open" data-act="open-detail" title="Open in a window">' + icon('expand') + '</span>' +
    '</button>' +
    '<div class="detail-body"></div>';
  m._kind = 'reasoning';
  m._text = text || '';
  paintReasoning(m);
  return appendMsg(m, before);
}

function paintReasoning(m) {
  m.querySelector('.detail-preview').textContent = lastSentence(m._text);
  m.querySelector('.detail-meta').textContent = fmtNum(m._text.length) + ' chars';
  if (m.classList.contains('open')) fillDetail(m);
}

function addReasoningDelta(text) {
  if (!text) return;
  flushText();
  chat.textEl = null; chat.textRaw = '';
  if (!chat.reasonEl) chat.reasonEl = makeReasoning('', null, true);
  chat.reasonEl._text += text;
  if (!chat.reasonEl._raf) {
    const m = chat.reasonEl;
    m._raf = requestAnimationFrame(() => { m._raf = 0; paintReasoning(m); scrollChat(); });
  }
}

/* a tool call: {id, name, args, state: running|ok|failed, result, sub, elapsed} */
const HIDDEN_ARGS = ['tool_call', 'tool_call_index'];

function cleanArgs(args) {
  if (!args || typeof args !== 'object' || Array.isArray(args)) return {};
  const out = {};
  Object.keys(args).forEach((k) => { if (!HIDDEN_ARGS.includes(k)) out[k] = args[k]; });
  return out;
}

function argSummary(args) {
  const keys = Object.keys(args);
  if (!keys.length) return '';
  const first = ['path', 'file', 'command', 'name', 'target', 'goal', 'query', 'url', 'node', 'workspace', 'taskid', 'signal', 'source'];
  const ordered = keys.slice().sort((a, b) => {
    const ia = first.indexOf(a); const ib = first.indexOf(b);
    return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib);
  });
  return ordered.slice(0, 3).map((k) => {
    const v = args[k];
    const s = typeof v === 'string' ? v : JSON.stringify(v);
    return k + ': ' + clip(oneLine(s), 70);
  }).join('   ');
}

function toolError(t) {
  const r = t.result;
  if (r && typeof r === 'object' && !Array.isArray(r)) {
    if (r.error && (r.ok === false || r.ok === 0 || r.ok === undefined)) return String(r.error);
  }
  return '';
}

function makeTool(t, before) {
  const m = el('div', 'msg tool');
  m.innerHTML =
    '<button class="detail-head" data-act="toggle-detail" title="Show the parameters and the result">' +
      '<i class="fa-solid fa-chevron-right detail-caret"></i>' +
      '<span class="detail-kind">' + icon('wrench') + '</span>' +
      '<span class="tool-name"></span>' +
      '<span class="detail-preview"></span>' +
      '<span class="detail-meta"></span>' +
      '<span class="tool-state"></span>' +
      '<span class="detail-open" data-act="open-detail" title="Open in a window">' + icon('expand') + '</span>' +
    '</button>' +
    '<div class="detail-body"></div>';
  m._kind = 'tool';
  m._tool = Object.assign({ state: 'running' }, t, { args: cleanArgs(t.args) });
  paintTool(m);
  return appendMsg(m, before);
}

function paintTool(m) {
  const t = m._tool;
  const err = t.state === 'failed' ? toolError(t) : '';
  setClass(m, 'msg tool' + (t.sub ? ' sub' : '') + (t.state === 'ok' ? ' ok' : '') + (t.state === 'failed' ? ' failed' : '') +
    (m.classList.contains('open') ? ' open' : ''));
  m.querySelector('.tool-name').textContent = (t.sub ? 'sub-agent · ' : '') + (t.name || 'tool');
  m.querySelector('.detail-preview').textContent = err ? clip(oneLine(err), 160) : argSummary(t.args);
  m.querySelector('.detail-preview').classList.toggle('tool-error', !!err);
  m.querySelector('.detail-meta').textContent = t.elapsed || '';
  m.querySelector('.tool-state').textContent = t.state === 'running' ? 'running' : (t.state === 'failed' ? 'failed' : 'done');
  if (m.classList.contains('open')) fillDetail(m);
}

function toolStart(t, sub) {
  endRun();
  const m = makeTool({ id: String(t.id || ''), name: t.name, args: t.args, state: 'running', sub: !!sub });
  if (t.id) chat.tools.set(String(t.id), m);
  scrollChat();
}

function toolEnd(t) {
  const id = String(t.id || '');
  let m = chat.tools.get(id);
  if (!m) {
    // the start was before this page connected
    m = makeTool({ id, name: t.name, args: {}, state: 'running' });
  }
  const res = t.result;
  let failed = false;
  if (res && typeof res === 'object' && !Array.isArray(res) && res.error && (res.ok === false || res.ok === 0)) failed = true;
  m._tool.result = res;
  m._tool.result_truncated = truthy(t.result_truncated);
  m._tool.state = failed ? 'failed' : 'ok';
  chat.tools.delete(id);
  paintTool(m);
}

/* the body of an opened reasoning / tool item (made when it is opened, not before) */
function valueText(v) {
  if (typeof v === 'string') return v;
  try { return JSON.stringify(v, null, 2); } catch (e) { return String(v); }
}

function detailHtml(m) {
  if (m._kind === 'reasoning') return '<pre class="reasoning-text">' + esc(m._text) + '</pre>';

  const t = m._tool;
  const keys = Object.keys(t.args || {});
  let html = '<div class="kv-title">Parameters</div>';
  if (!keys.length) html += '<div class="form-hint">none</div>';
  else {
    html += '<dl class="kv">';
    keys.forEach((k) => {
      const s = valueText(t.args[k]);
      const long = s.length > 90 || s.includes('\n');
      html += '<dt>' + esc(k) + '</dt><dd' + (long ? ' class="long"' : '') + '>' + esc(s) + '</dd>';
    });
    html += '</dl>';
  }
  if (t.state === 'running') {
    html += '<div class="kv-title">Result</div><div class="form-hint">running…</div>';
  } else if (t.result !== undefined && t.result !== null) {
    html += '<div class="kv-title">Result' + (t.result_truncated ? ' (a long result: its head and tail)' : '') + '</div>' +
      '<pre class="block' + (t.state === 'failed' ? ' tool-error' : '') + '">' + esc(valueText(t.result)) + '</pre>';
  }
  return html;
}

function fillDetail(m) {
  const body = m.querySelector('.detail-body');
  const html = detailHtml(m);
  if (body._html !== html) {
    const pre = body.querySelector('pre');
    const atEnd = pre ? pre.scrollHeight - pre.scrollTop - pre.clientHeight < 40 : true;
    body.innerHTML = html;
    body._html = html;
    const now = body.querySelector('pre');
    if (now && atEnd && m.classList.contains('live')) now.scrollTop = now.scrollHeight;
  }
}

function detailPlain(m) {
  if (m._kind === 'reasoning') return m._text;
  const t = m._tool;
  let out = (t.name || 'tool') + '\n\nParameters:\n' + valueText(t.args);
  if (t.result !== undefined && t.result !== null) out += '\n\nResult:\n' + valueText(t.result);
  return out;
}

function openDetailDialog(m) {
  $('detailTitle').innerHTML = m._kind === 'reasoning'
    ? icon('brain') + ' <span>Reasoning</span>'
    : icon('wrench') + ' <span>' + esc((m._tool.sub ? 'sub-agent · ' : '') + (m._tool.name || 'tool')) + '</span>';
  $('detailBody').innerHTML = detailHtml(m);
  $('detailDialog')._plain = detailPlain(m);
  openDialog('detailDialog');
}

function addReport(text, status, before) {
  if (!text) return null;
  if (!before) endRun();
  const st = String(status || 'finished');
  const cls = st === 'failed' ? ' failed' : st === 'question' ? ' question' : st === 'stopped' ? ' failed' : '';
  const label = st === 'failed' ? 'Failed' : st === 'question' ? 'Question' : st === 'stopped' ? 'Stopped' : 'Report';
  const m = el('div', 'msg report' + cls);
  m.innerHTML = '<div class="msg-label"><span>' + label + '</span></div><div class="msg-body">' + mdRender(text) + '</div>';
  return appendMsg(m, before);
}

function addError(text, before) {
  if (!before) endRun();
  const m = el('div', 'msg error');
  m.innerHTML = '<div class="msg-label"><span>Error</span></div><div class="msg-body"></div>';
  m.lastChild.textContent = text;
  return appendMsg(m, before);
}

function addNotice(text, before) {
  if (!text) return null;
  if (!before) endRun();
  return appendMsg(el('div', 'msg notice', text), before);
}

/* one item of a transcript (not streamed) */
function drawItem(it, before) {
  if (it.kind === 'user') return addUser(it.text, before);
  if (it.kind === 'text') return it.text ? makeText(it.text, before) : null;
  if (it.kind === 'reasoning') return it.text ? makeReasoning(it.text, before, false) : null;
  if (it.kind === 'tool') return makeTool(it, before);
  if (it.kind === 'report') return addReport(it.text, it.status, before);
  if (it.kind === 'error') return addError(it.text, before);
  if (it.kind === 'notice' || it.kind === 'milestone') return addNotice(it.text, before);
  return null;
}

/* chat.json -> items */
function contentText(content) {
  if (typeof content === 'string') return content;
  if (!Array.isArray(content)) return '';
  return content.filter((p) => p && typeof p.text === 'string').map((p) => p.text).join('');
}

function userText(text) {
  // the harness's own prompts are not the user's: a finalize reminder is dropped, a
  // handover that was appended to the task is cut off
  let t = String(text || '');
  let cut = -1;
  SYSTEM_MARKS.forEach((mark) => { const i = t.indexOf(mark); if (i >= 0 && (cut < 0 || i < cut)) cut = i; });
  if (cut === 0) return '';
  if (cut > 0) t = t.slice(0, cut);
  return t.trim();
}

function parseArgs(raw) {
  if (raw && typeof raw === 'object') return raw;
  try { const v = JSON.parse(String(raw || '{}')); return v && typeof v === 'object' ? v : { value: v }; } catch (e) { return { arguments: String(raw || '') }; }
}

// a tool message: "Time: ...\nTotal Elapsed Time: 2 Seconds\n\n<result>"
function parseToolResult(content) {
  let text = contentText(content);
  let elapsed = '';
  const m = text.match(/^Time: [^\n]*\nTotal Elapsed Time: ([^\n]*)\n\n?/);
  if (m) { elapsed = m[1].replace(/ Seconds?/, ' s').replace(/ Minutes?/, ' min'); text = text.slice(m[0].length); }
  let value = text;
  const trimmed = text.trim();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    try { value = JSON.parse(trimmed); } catch (e) { value = text; }
  }
  return { value, elapsed };
}

function historyItems(messages) {
  const items = [];
  const byCall = {};
  messages.forEach((msg) => {
    if (!msg || typeof msg !== 'object') return;
    if (msg.role === 'user') {
      const t = userText(contentText(msg.content));
      if (t) items.push({ kind: 'user', text: t });
    } else if (msg.role === 'assistant') {
      if (msg.reasoning_content) items.push({ kind: 'reasoning', text: String(msg.reasoning_content) });
      const t = contentText(msg.content);
      if (t && t.trim()) items.push({ kind: 'text', text: t });
      arr(msg.tool_calls).forEach((c) => {
        const fn = (c && c.function) || {};
        const it = { kind: 'tool', id: String(c.id || ''), name: fn.name || 'tool', args: parseArgs(fn.arguments), state: 'ok', result: undefined };
        items.push(it);
        if (c.id) byCall[String(c.id)] = it;
      });
    } else if (msg.role === 'tool') {
      const it = byCall[String(msg.tool_call_id || '')];
      const r = parseToolResult(msg.content);
      if (it) {
        it.result = r.value;
        it.elapsed = r.elapsed;
        const v = r.value;
        if (v && typeof v === 'object' && !Array.isArray(v) && v.error && (v.ok === false || v.ok === 0)) it.state = 'failed';
      }
    }
  });
  return items;
}

/* the whole session into the pane */
function renderSession(session) {
  chatReset();
  const hist = Array.isArray(session.chat_history) ? session.chat_history : arr(session.chat_history);
  const turn = arr(session.turn);
  const cutAt = Math.min(hist.length, Math.max(0, num(session.chat_history_size_at_prompt)));
  const terminal = isTerminal(session.status);
  const saved = hist.slice(cutAt);

  let items;
  if (terminal && saved.length) {
    // the turn has ended and chat.json has all of it
    items = historyItems(hist);
  } else if (turn.length) {
    // the turn runs (or its end was not saved): the earlier turns from chat.json,
    // this one as the node folded it from the stream
    items = historyItems(hist.slice(0, cutAt)).concat(turn.map((t) => Object.assign({}, t, { sub: truthy(t.sub) })));
  } else {
    items = historyItems(hist);
    if (session.prompt && !items.some((i) => i.kind === 'user' && i.text === userText(session.prompt)) && !saved.length) {
      items.push({ kind: 'user', text: userText(session.prompt) });
    }
  }

  if (terminal && session.report) items.push({ kind: 'report', text: session.report, status: session.status === 'done' ? 'finished' : session.status });
  else if (terminal && session.error) items.push({ kind: 'error', text: session.error });

  if (!items.length) { renderChatEmpty(); return; }

  // a long transcript: the newest part now, the rest on request
  chat.earlier = items.length > PAGE_ITEMS ? items.slice(0, items.length - PAGE_ITEMS) : [];
  const shown = items.slice(chat.earlier.length);
  drawEarlierButton();
  shown.forEach((it) => drawItem(it));

  // a tool of the running turn that has no result yet takes its tool_end from the stream;
  // a running reasoning / text block at the end continues with the next delta
  if (!terminal) {
    Array.from(chatBox().querySelectorAll('.msg.tool')).forEach((m) => {
      if (m._tool && m._tool.state === 'running' && m._tool.id) chat.tools.set(m._tool.id, m);
    });
    const last = chatBox().lastElementChild;
    const lastItem = shown[shown.length - 1];
    if (last && lastItem && lastItem.kind === 'reasoning') { chat.reasonEl = last; last.classList.add('live'); }
    if (last && lastItem && lastItem.kind === 'text') { chat.textEl = last; chat.textRaw = lastItem.text; }
  }
  scrollChat(true);
}

function drawEarlierButton() {
  const old = chatBox().querySelector(':scope > .earlier');
  if (old) old.remove();
  if (!chat.earlier.length) return;
  const b = el('button', 'btn btn-small btn-ghost earlier', 'Show ' + Math.min(PAGE_ITEMS, chat.earlier.length) + ' earlier items (' + chat.earlier.length + ' more)');
  b.dataset.act = 'earlier';
  b.style.alignSelf = 'center';
  chatBox().insertBefore(b, chatBox().firstChild);
}

function showEarlier() {
  const box = chatBox();
  const take = chat.earlier.splice(Math.max(0, chat.earlier.length - PAGE_ITEMS));
  const btn = box.querySelector(':scope > .earlier');
  const anchor = btn ? btn.nextSibling : box.firstChild;
  const before = box.scrollHeight;
  take.forEach((it) => drawItem(it, anchor));
  drawEarlierButton();
  box.scrollTop += box.scrollHeight - before;
}

/* ── a session: open, stream ── */
async function openSession(sessionId) {
  const gen = state.selGen;
  const nodeId = state.sel.node;
  closeStream();
  state.session = null;
  state.pendingUser = null;
  chatReset();
  chatBox().appendChild(el('div', 'empty-state compact', 'Loading the session…'));
  renderSessionHeader();

  let s = null;
  try {
    s = await api(nodeId).get('/api/sessions/' + enc(sessionId));
  } catch (e) {
    if (gen !== state.selGen || state.sel.session !== sessionId) return;
    chatReset();
    chatBox().appendChild(el('div', 'empty-state compact', 'Could not load the session: ' + e.message));
    return;
  }
  if (gen !== state.selGen || state.sel.session !== sessionId) return;

  s.id = String(s.id || sessionId);
  state.session = s;
  state.composerEffort = String(s.reasoning_effort || state.composerEffort);
  renderSession(s);
  renderSessionHeader();
  renderTree();

  // the stream continues where the answer ended
  state.streamSince = Math.max(num(s.turn_seq), num(s.seq));
  if (!isTerminal(s.status)) openStream();
}

async function reloadSession() {
  if (state.sel.session) await openSession(state.sel.session);
}

function closeStream() {
  if (state.stream) {
    try { state.stream.close(); } catch (e) {}
    state.stream = null;
  }
}

function openStream() {
  closeStream();
  if (!state.session) return;
  const sessionId = state.session.id;
  const gen = state.selGen;
  const params = new URLSearchParams();
  params.set('since', String(state.streamSince || 0));
  const token = NodeApi.token();
  if (token) params.set('token', token);
  const es = new EventSource(selApi().url('/api/sessions/' + enc(sessionId) + '/stream?' + params.toString()));
  state.stream = es;

  const mine = () => state.stream === es && gen === state.selGen && state.sel.session === sessionId;
  ['delta', 'user', 'status', 'done', 'error', 'stats', 'file', 'notify'].forEach((name) => {
    es.addEventListener(name, (ev) => { if (mine() && ev.data) streamEvent(name, ev.data); });
  });
  es.onerror = () => {
    if (!mine()) { es.close(); return; }
    // the server closed the stream (the turn ended) or the connection broke. An
    // EventSource would connect again by itself with the OLD position: do it by hand.
    es.close();
    state.stream = null;
    if (state.session && !isTerminal(state.session.status)) {
      setTimeout(() => { if (gen === state.selGen && state.sel.session === sessionId && !state.stream && state.session && !isTerminal(state.session.status)) openStream(); }, 1500);
    }
  };
}

function applyAction(action, sub) {
  if (!action || typeof action !== 'object') return;
  if (action.agent && typeof action.agent === 'object') { applyAction(action.agent.action, true); return; }
  if (action.tool_start) { toolStart(action.tool_start, sub); return; }
  if (action.tool_end) { toolEnd(action.tool_end); return; }
  if (sub) return;                      // the text of sub-agents would interleave
  if (action.reasoning != null) { addReasoningDelta(String(action.reasoning)); return; }
  if (action.text != null) { addTextDelta(String(action.text)); return; }
  if (action.milestone != null) addNotice(String(action.milestone));
}

function streamEvent(name, raw) {
  let data = raw;
  if (typeof raw === 'string') { try { data = JSON.parse(raw); } catch (e) { return; } }
  if (!data || typeof data !== 'object') return;
  if (data.seq != null) {
    if (num(data.seq) <= state.streamSince) return;        // drawn already
    state.streamSince = num(data.seq);
  }
  chat.stick = nearBottom();

  if (name === 'delta') {
    applyAction(data.action || data.delta);
    setSessionStatus('running');
  } else if (name === 'user') {
    const text = String(data.text || '');
    if (state.pendingUser && text === state.pendingUser) state.pendingUser = null;
    else addUser(text);
  } else if (name === 'status') {
    const st = data.status;
    if (data.reasoning_effort && state.session) state.session.reasoning_effort = String(data.reasoning_effort);
    if (data.mode && state.session) state.session.mode = String(data.mode);
    if (st && st !== 'connected') setSessionStatus(st);
    else renderSessionHeader();
  } else if (name === 'stats') {
    if (state.session && data.token_usage != null) state.session.token_usage = num(data.token_usage);
    renderSessionHeader();
  } else if (name === 'file') {
    addNotice('sent the file ' + (data.name || '') + (data.caption ? ': ' + data.caption : ''));
  } else if (name === 'notify') {
    addNotice('notification: ' + (data.message || ''));
  } else if (name === 'error') {
    addError(String(data.message || data.error || 'The agent reported an error'));
  } else if (name === 'done') {
    const st = data.status === 'finished' ? 'done' : String(data.status || 'done');
    endRun();
    if (data.report) addReport(data.report, data.status);
    if (state.session) {
      state.session.report = data.report || '';
      if (data.token_usage != null) state.session.token_usage = num(data.token_usage);
    }
    setSessionStatus(st);
    closeStream();
    if (st === 'failed') toast('The session failed.', 'error');
    else if (st === 'question') toast('The agent needs input.', 'warn');
  }
  scrollChat();
}

function setSessionStatus(status) {
  if (!state.session) return;
  const st = String(status || '').toLowerCase();
  const mapped = st === 'finished' ? 'done' : st === 'error' ? 'failed' : st;
  if (state.session.status === mapped) return;
  state.session.status = mapped;
  const d = nd(state.sel.node);
  const live = d.sessions.find((s) => s.id === state.session.id);
  if (live) live.status = mapped;
  renderSessionHeader();
  renderTree();
  updateLamps();
}

function renderSessionHeader() {
  const s = state.session;
  const hasWs = !!(state.sel.node && state.sel.ws);
  const modeButtons = document.querySelectorAll('#modeToggle button');
  $('promptInput').disabled = !hasWs;
  $('btnSendPrompt').disabled = !hasWs;

  if (!s) {
    setText($('sessionTitleEl'), hasWs ? 'New session' : 'No workspace selected');
    setHtml($('sessionMetaEl'), '');
    modeButtons.forEach((b) => b.classList.toggle('active', b.dataset.mode === state.composerMode));
    $('reasoningEffort').value = state.composerEffort;
    $('btnStopSession').disabled = true;
    setText($('composerHint'), hasWs ? 'Ctrl+Enter sends. The first prompt starts a session.' : '');
    return;
  }

  setText($('sessionTitleEl'), s.title || 'Session');
  const cls = isGenerating(s.status) ? 'running' : statusClass(s.status);
  setHtml($('sessionMetaEl'),
    '<span class="chip ' + cls + '">' + esc(statusLabel(s.status)) + '</span>' +
    (s.mode === 'goal' ? '<span class="chip">loop</span>' : '') +
    '<span class="chip">' + icon('bolt') + ' ' + fmtNum(s.token_usage) + ' tokens</span>' +
    (s.origin === 'net' ? '<span class="chip" title="Started by a gateway or another node">via network</span>' : '') +
    (s.role && s.role !== 'adaptive' ? '<span class="chip">' + esc(s.role) + '</span>' : ''));
  modeButtons.forEach((b) => b.classList.toggle('active', b.dataset.mode === (s.mode || 'normal')));
  if (document.activeElement !== $('reasoningEffort')) $('reasoningEffort').value = String(s.reasoning_effort || 'medium');
  $('btnStopSession').disabled = !isActive(s.status);

  if (isGenerating(s.status)) setText($('composerHint'), 'Running — a prompt you send now is handed to the agent in the middle of its turn.');
  else if (String(s.status) === 'question') setText($('composerHint'), 'The agent asked a question — answer it to continue.');
  else if (s.mode === 'goal') setText($('composerHint'), 'Loop: the agent keeps working until the goal is finished or failed.');
  else setText($('composerHint'), 'Ctrl+Enter sends.');
}

/* ── chat actions ── */
async function sendPrompt() {
  const text = $('promptInput').value.trim();
  if (!text || !state.sel.node || !state.sel.ws) return;
  const effort = $('reasoningEffort').value;
  const nodeId = state.sel.node;
  const wsId = state.sel.ws;
  const a = api(nodeId);
  $('btnSendPrompt').disabled = true;

  try {
    if (!state.session) {
      const made = await a.post('/api/workspaces/' + enc(wsId) + '/sessions', { mode: state.composerMode, prompt: text, reasoning_effort: effort });
      const id = made && String(made.id || '');
      if (!id) throw new Error('The node did not return the new session.');
      $('promptInput').value = '';
      state.openWs.add(wsKey(nodeId, wsId));
      // the feed brings the session into the tree; show it now
      const d = nd(nodeId);
      if (!d.sessions.some((s) => s.id === id)) d.sessions.push({ id, workspace_id: wsId, title: made.title, status: made.status, mode: made.mode, token_usage: 0, created: Date.now() });
      await selectSession(nodeId, wsId, id);
      return;
    }

    const id = state.session.id;
    state.pendingUser = text;
    await a.post('/api/sessions/' + enc(id) + '/prompt', { prompt: text, reasoning_effort: effort });
    $('promptInput').value = '';
    chat.stick = true;
    addUser(text);
    scrollChat(true);
    setSessionStatus('running');
    if (!state.stream) openStream();
  } catch (e) {
    state.pendingUser = null;
    toast('The prompt was not sent: ' + e.message, 'error');
  } finally {
    renderSessionHeader();
  }
}

async function setMode(mode) {
  state.composerMode = mode;
  if (!state.session) { renderSessionHeader(); return; }
  try {
    await selApi().post('/api/sessions/' + enc(state.session.id) + '/mode', { mode });
    state.session.mode = mode;
    renderSessionHeader();
  } catch (e) {
    toast('Could not change the mode: ' + e.message, 'error');
  }
}

async function setEffort(value) {
  const effort = String(value || '').toLowerCase();
  if (!['low', 'medium', 'high'].includes(effort)) return;
  state.composerEffort = effort;
  if (!state.session) return;
  const before = state.session.reasoning_effort;
  state.session.reasoning_effort = effort;
  try {
    await selApi().post('/api/sessions/' + enc(state.session.id) + '/effort', { reasoning_effort: effort });
  } catch (e) {
    state.session.reasoning_effort = before;
    $('reasoningEffort').value = String(before || 'medium');
    toast('Could not set the reasoning effort: ' + e.message, 'error');
  }
}

async function stopSession() {
  if (!state.session) return;
  try {
    await selApi().post('/api/sessions/' + enc(state.session.id) + '/stop');
    endRun();
    addNotice('stopped');
    setSessionStatus('stopped');
    closeStream();
  } catch (e) {
    toast('Could not stop the session: ' + e.message, 'error');
  }
}

async function newSession(nodeId, wsId) {
  // a session starts with its first prompt: select the workspace and focus the composer
  await selectWorkspace(nodeId, wsId);
  state.openWs.add(wsKey(nodeId, wsId));
  if (state.tab !== 'chat') showTab('chat');
  renderTree();
  $('promptInput').focus();
}

async function deleteSession(nodeId, wsId, sessionId) {
  if (!window.confirm('Delete this session and its chat history?')) return;
  try {
    await api(nodeId).del('/api/sessions/' + enc(sessionId));
    const d = nd(nodeId);
    d.sessions = d.sessions.filter((s) => s.id !== sessionId);
    if (state.sel.node === nodeId && state.sel.session === sessionId) {
      state.sel.session = null;
      state.session = null;
      closeStream();
      renderChatEmpty();
      renderSessionHeader();
      saveSelection();
    }
    renderTree();
  } catch (e) {
    toast('Could not delete the session: ' + e.message, 'error');
  }
}

/* ── workspaces ── */
function slug(name) {
  const s = String(name || '').toLowerCase().trim().replace(/[^a-z0-9]/g, '_').slice(0, 48);
  return s || 'workspace';
}

function openWorkspaceDialog(nodeId, parentId) {
  const n = nodeById(nodeId);
  const d = nd(nodeId);
  const parent = parentId ? d.byId[parentId] : null;
  state.newWs = { node: nodeId, parent: parentId || '' };
  setText($('workspaceDialogTitle'), parent ? 'New sub-workspace' : 'New workspace');
  setText($('workspaceWhere'), 'On ' + (n ? n.name : nodeId) + (parent ? ', inside ' + parent.name : ''));
  $('workspaceName').value = '';
  $('workspacePath').value = '';
  $('workspaceDescription').value = '';
  updateWorkspacePathHint();
  openDialog('workspaceDialog');
  $('workspaceName').focus();
}

function updateWorkspacePathHint() {
  if (!state.newWs) return;
  const d = nd(state.newWs.node);
  const parent = state.newWs.parent ? d.byId[state.newWs.parent] : null;
  const base = parent ? parent.path : d.projectsDir;
  const name = $('workspaceName').value.trim();
  const where = base ? base.replace(/[\\/]+$/, '') + '/' + slug(name || 'name') : '';
  $('workspacePath').placeholder = where;
  setText($('workspacePathHint'), $('workspacePath').value.trim()
    ? 'An existing folder is registered as it is; a missing one is created.'
    : 'Empty: a new folder ' + (where || 'below the node\'s working directory') + ' on that node.');
}

async function createWorkspace() {
  if (!state.newWs) return;
  const name = $('workspaceName').value.trim();
  if (!name) { toast('The workspace needs a name.', 'warn'); return; }
  const body = { name };
  const path = $('workspacePath').value.trim();
  const description = $('workspaceDescription').value.trim();
  if (path) body.path = path;
  if (description) body.description = description;
  if (state.newWs.parent) body.parent = state.newWs.parent;
  const nodeId = state.newWs.node;
  try {
    const made = await api(nodeId).post('/api/workspaces', body);
    closeDialog('workspaceDialog');
    await loadNode(nodeId);
    if (state.newWs.parent) state.openWs.add(wsKey(nodeId, state.newWs.parent));
    if (made && made.id) await selectWorkspace(nodeId, String(made.id));
    toast('Workspace created: ' + (made && made.path ? made.path : name), 'success');
  } catch (e) {
    toast('Could not create the workspace: ' + e.message, 'error');
  }
}

async function deleteWorkspace(nodeId, wsId) {
  const w = workspaceOf(nodeId, wsId);
  if (!w) return;
  if (!window.confirm('Remove "' + (w.name || w.id) + '" from this node?\n\nIts sessions are stopped and deleted. The files in ' + (w.path || 'its folder') + ' stay on disk.')) return;
  try {
    await api(nodeId).del('/api/workspaces/' + enc(wsId));
    state.openWs.delete(wsKey(nodeId, wsId));
    if (state.sel.node === nodeId && state.sel.ws === wsId) clearSelection();
    await loadNode(nodeId);
    toast('Workspace removed. Its files were kept.', 'success');
  } catch (e) {
    toast('Could not remove the workspace: ' + e.message, 'error');
  }
}

/* ── tasks ── */
const goalStatus = (g) => String(g && g.status || '').toLowerCase();
const goalRunOpen = (g) => ['dispatching', 'running', 'checkpoint'].includes(String(g && g.active_run_state || '').toLowerCase());
const goalNeedsInput = (g) => String(g && g.active_run_state || '').toLowerCase() === 'question';
const goalInvalid = (g) => truthy(g && g.invalid_edit) || (g && Array.isArray(g.errors) && g.errors.length > 0) || ['invalid', '?'].includes(goalStatus(g));
const taskIdOf = (t) => String(t && (t.taskid || t.id) || '');

function fmtSchedule(schedule) {
  if (!schedule) return '';
  if (typeof schedule === 'string') return schedule;
  const parts = [];
  if (schedule.type) parts.push(String(schedule.type));
  if (schedule.every) parts.push('every ' + schedule.every);
  if (schedule.days) parts.push(Array.isArray(schedule.days) ? schedule.days.join(', ') : String(schedule.days));
  if (schedule.date) parts.push(String(schedule.date));
  if (schedule.start) parts.push('from ' + schedule.start);
  if (schedule.end) parts.push('to ' + schedule.end);
  return parts.join(' · ') || JSON.stringify(schedule);
}

function goalErrors(g) {
  return arr(g.errors).map((e) => (typeof e === 'string' ? e : (e && (e.message || e.error)) || JSON.stringify(e))).join('; ');
}

// -> {key, section, html}: the card of a goal
function goalCard(g, nodeId, wsId) {
  const st = goalStatus(g);
  const running = goalRunOpen(g);
  const asking = goalNeedsInput(g);
  const invalid = goalInvalid(g);
  const inWindow = !!String(g.active_window || '').trim();
  const dry = truthy(g.dry_run);
  const label = invalid ? 'invalid' : asking ? 'needs input' : running ? (String(g.active_run_state).toLowerCase() === 'checkpoint' ? 'checkpoint' : 'running')
    : (inWindow && (st === 'active' || st === 'paused') ? 'window open' : (st || 'planned'));
  const cls = label.replace(/[^a-z]/g, '');
  let section = 'invalid';
  if (invalid) section = 'invalid';
  else if (asking) section = 'input';
  else if (running || ((st === 'active' || st === 'paused') && inWindow)) section = 'running';
  else if (st === 'proposed') section = 'proposed';
  else if (st === 'active' || st === 'paused') section = 'scheduled';
  else if (['completed', 'cancelled', 'archived'].includes(st)) section = 'finished';

  const data = ' data-node="' + esc(nodeId) + '" data-ws="' + esc(wsId) + '" data-goal="' + esc(g.id) + '"';
  let actions = '';
  if (!invalid && st === 'proposed') actions += '<button class="btn btn-small btn-primary" data-act="goal-status" data-status="active"' + data + '>Activate</button>';
  if (!invalid && st === 'active') {
    if (!running) actions += '<button class="btn btn-small" data-act="goal-run"' + data + ' title="Start a run now">' + icon('play') + ' Run now</button>';
    actions += '<button class="btn btn-small btn-ghost" data-act="goal-status" data-status="paused"' + data + '>Pause</button>';
  }
  if (!invalid && st === 'paused') actions += '<button class="btn btn-small btn-primary" data-act="goal-status" data-status="active"' + data + '>Resume</button>';
  if (g.id != null) actions += '<button class="btn btn-small btn-danger" data-act="goal-delete"' + data + '>Delete</button>';

  const html =
    '<div class="task-top"><div class="task-name">' + esc(g.title || g.id || 'Goal') + '</div>' +
      '<span class="task-state ' + esc(cls) + '">' + esc(label) + '</span></div>' +
    (g.schedule ? '<div class="task-line">' + icon('clock') + ' ' + esc(fmtSchedule(g.schedule)) + '</div>' : '') +
    (g.active_window ? '<div class="task-line"><b>Now:</b> ' + esc(g.active_window) + '</div>' : '') +
    (!g.active_window && g.next_window ? '<div class="task-line"><b>Next:</b> ' + esc(g.next_window) + '</div>' : '') +
    (dry ? '<div class="task-line">Dry run: the prompt is written to history.md, no worker starts. Activating clears it.</div>' : '') +
    (g.last_outcome ? '<div class="task-line"><b>Last:</b> ' + esc(g.last_outcome) + '</div>' : '') +
    (invalid && goalErrors(g) ? '<div class="task-report">' + esc(goalErrors(g)) + '</div>' : '') +
    (running && g.active_taskid ? '<div class="task-line"><button class="btn btn-small btn-ghost" data-act="open-task" data-node="' + esc(nodeId) + '" data-ws="' + esc(wsId) + '" data-session="' + esc(g.active_taskid) + '">' + icon('comments') + ' Open its session</button></div>' : '') +
    (actions ? '<div class="task-actions">' + actions + '</div>' : '');
  return { key: 'g:' + nodeId + ':' + wsId + ':' + g.id, section, html, invalid };
}

function sessionCard(s, nodeId, wsId) {
  const raw = String(s.state || s.status || 'planned').toLowerCase();
  const active = truthy(s.active) || ['running', 'planned', 'starting', 'waiting', 'queued'].includes(raw);
  const st = active && !['running', 'planned', 'queued'].includes(raw) ? 'running' : raw;
  let section = 'finished';
  if (raw === 'question') section = 'input';
  else if (raw === 'queued') section = 'queued';
  else if (active) section = 'running';
  const id = taskIdOf(s);
  const data = ' data-node="' + esc(nodeId) + '" data-ws="' + esc(wsId) + '" data-session="' + esc(id) + '"';
  const html =
    '<div class="task-top"><div class="task-name">' + esc(s.name || s.title || id || 'Session') + '</div>' +
      '<span class="task-state ' + esc(st.replace(/[^a-z]/g, '')) + '">' + esc(raw === 'question' ? 'needs input' : st) + '</span></div>' +
    '<div class="task-line">' + icon('bolt') + ' ' + fmtNum(s.token_usage) + ' tokens' + (s.origin === 'net' ? '  ·  via network' : '') +
      (num(s.last_update_ms) ? '  ·  ' + esc(timeAgo(s.last_update_ms)) : '') + '</div>' +
    (s.report || s.error ? '<div class="task-report">' + esc(clip(s.report || s.error, 900)) + '</div>' : '') +
    '<div class="task-actions">' +
      '<button class="btn btn-small btn-ghost" data-act="open-task"' + data + '>' + icon('comments') + ' Open</button>' +
      (active ? '<button class="btn btn-small btn-danger" data-act="task-stop"' + data + '>' + icon('stop') + ' Stop</button>' : '') +
    '</div>';
  return { key: 's:' + nodeId + ':' + wsId + ':' + id, section, html };
}

const TASK_SECTIONS = [
  ['running', 'Running now'],
  ['queued', 'Queued — waiting for a free session'],
  ['input', 'Needs input'],
  ['scheduled', 'Scheduled'],
  ['proposed', 'Proposed — waiting for your go'],
  ['finished', 'Finished'],
  ['invalid', 'Invalid goals'],
];

function taskCards(data, nodeId, wsId) {
  const goals = arr(data && data.goals).filter((g) => g && typeof g === 'object');
  const sessions = arr(data && data.sessions).filter((s) => s && typeof s === 'object');
  const goalTasks = new Set(goals.map((g) => String(g.active_taskid || '')).filter(Boolean));
  const cards = goals.map((g) => goalCard(g, nodeId, wsId));
  sessions.forEach((s) => {
    // the session of a running goal shows on the goal's card
    if (goalTasks.has(taskIdOf(s)) && (truthy(s.active) || String(s.state) === 'question')) return;
    cards.push(sessionCard(s, nodeId, wsId));
  });
  return cards;
}

/* draw cards into `host` in sections; nothing is rebuilt when nothing changed */
function renderTaskSections(host, cards, emptyText) {
  reconcile(host, TASK_SECTIONS.map(([id, title]) => ({ id, title })).concat([{ id: 'empty' }]), (s) => s.id, (s) => {
    if (s.id === 'empty') return el('div', 'empty-state compact');
    const sec = el('section', 'task-section');
    sec.innerHTML = '<div class="task-section-head"><h3></h3><span></span></div><div class="task-grid"></div>';
    return sec;
  }, (sec, s) => {
    if (s.id === 'empty') {
      sec.hidden = cards.length > 0;
      setHtml(sec, icon('tasks') + '<div class="empty-title">Nothing here yet</div><div>' + esc(emptyText || '') + '</div>');
      return;
    }
    const mine = cards.filter((c) => c.section === s.id);
    setClass(sec, 'task-section' + (mine.length ? '' : ' is-empty'));
    setText(sec.querySelector('h3'), s.title);
    setText(sec.querySelector('.task-section-head span'), mine.length ? String(mine.length) : '');
    reconcile(sec.querySelector('.task-grid'), mine, (c) => c.key, () => el('div', 'task-card'), (card, c) => {
      setClass(card, 'task-card' + (c.invalid ? ' invalid' : ''));
      setHtml(card, c.html);
    });
  });
}

let tasksTimer = 0;
function scheduleTasks() {
  if (tasksTimer) return;
  tasksTimer = setTimeout(() => { tasksTimer = 0; loadTasks(); }, 250);
}

async function loadTasks() {
  if (state.view !== 'workspace' || state.tab !== 'tasks' || !state.sel.node || !state.sel.ws) return;
  const nodeId = state.sel.node;
  const wsId = state.sel.ws;
  const gen = state.selGen;
  const w = workspaceOf(nodeId, wsId);
  setText($('taskTitle'), 'Tasks — ' + (w ? w.name : ''));
  let data = null;
  try {
    data = await api(nodeId).get('/api/workspaces/' + enc(wsId) + '/tasks');
  } catch (e) {
    if (gen !== state.selGen) return;
    $('taskContent').innerHTML = '<div class="empty-state compact">Could not load the tasks: ' + esc(e.message) + '</div>';
    return;
  }
  if (gen !== state.selGen || state.tab !== 'tasks') return;
  const cards = taskCards(data, nodeId, wsId);
  renderTaskSections($('taskContent'), cards, 'Add a task above, or ask the agent in the chat to schedule one.');
}

async function submitTask(e) {
  e.preventDefault();
  const goal = $('taskGoal').value.trim();
  if (!goal || !state.sel.node || !state.sel.ws) { toast('Describe what the task should do.', 'warn'); return; }
  const title = $('taskTitleInput').value.trim() || clip(oneLine(goal), 48);
  const a = selApi();
  const ws = state.sel.ws;
  try {
    // the goal's id comes from its title: a second task with the same title gets a number
    let made = null;
    for (let n = 1; !made; n++) {
      try {
        made = await a.post('/api/workspaces/' + enc(ws) + '/goals',
          { title: n > 1 ? title + ' (' + n + ')' : title, instructions: goal, schedule_type: 'manual', activate: 'yes' });
      } catch (err) {
        if (n >= 9 || !/exists already|already exists/.test(err.message)) throw err;
      }
    }
    const id = made && (made.id || (made.goal && made.goal.id));
    if (!id) throw new Error('The goal engine did not return the new task.');
    await a.post('/api/workspaces/' + enc(ws) + '/goals/' + enc(id) + '/run', {});
    $('taskForm').classList.add('hidden');
    $('taskTitleInput').value = '';
    $('taskGoal').value = '';
    toast('The task is queued.', 'success');
    loadTasks();
  } catch (err) {
    toast('Could not create the task: ' + err.message, 'error');
  }
}

async function taskAction(btn) {
  const act = btn.dataset.act;
  const nodeId = btn.dataset.node;
  const wsId = btn.dataset.ws;
  const a = api(nodeId);
  const again = () => { if (state.view === 'globalTasks') loadGlobalTasks(); else loadTasks(); };
  try {
    if (act === 'open-task') {
      state.openWs.add(wsKey(nodeId, wsId));
      await selectSession(nodeId, wsId, btn.dataset.session);
      return;
    }
    btn.disabled = true;
    if (act === 'goal-status') {
      const body = { status: btn.dataset.status };
      if (btn.dataset.status === 'active') body.clear_dry_run = 'yes';
      await a.post('/api/workspaces/' + enc(wsId) + '/goals/' + enc(btn.dataset.goal) + '/status', body);
    } else if (act === 'goal-run') {
      await a.post('/api/workspaces/' + enc(wsId) + '/goals/' + enc(btn.dataset.goal) + '/run', {});
      toast('The run is queued.', 'success');
    } else if (act === 'goal-delete') {
      if (!window.confirm('Delete the goal "' + btn.dataset.goal + '"? Its open runs are stopped; project files stay.')) { btn.disabled = false; return; }
      await a.del('/api/workspaces/' + enc(wsId) + '/goals/' + enc(btn.dataset.goal));
    } else if (act === 'task-stop') {
      await a.del('/api/workspaces/' + enc(wsId) + '/tasks/' + enc(btn.dataset.session));
    }
    again();
  } catch (e) {
    btn.disabled = false;
    toast('That did not work: ' + e.message, 'error');
  }
}

/* ── all tasks (every online node) ── */
let globalTimer = 0;
function scheduleGlobalTasks() {
  if (globalTimer) return;
  globalTimer = setTimeout(() => { globalTimer = 0; loadGlobalTasks(); }, 600);
}

async function loadGlobalTasks() {
  if (state.view !== 'globalTasks') return;
  const host = $('globalTasksContent');
  const nodes = state.nodes.filter((n) => n.kind === 'node' && n.online && n.api);
  if (!host.children.length) host.innerHTML = '<div class="empty-state compact">Loading…</div>';

  const results = await Promise.all(nodes.map(async (n) => {
    try {
      return { n, data: await api(n.id).get('/api/tasks/overview') };
    } catch (e) {
      return { n, error: e.message };
    }
  }));
  if (state.view !== 'globalTasks') return;

  const groups = [];
  results.forEach(({ n, data, error }) => {
    if (error) { groups.push({ key: n.id, n, error }); return; }
    arr(data && data.workspaces).forEach((w) => {
      const cards = taskCards(w, n.id, String(w.id));
      if (cards.length) groups.push({ key: n.id + '/' + w.id, n, w, cards });
    });
  });

  reconcile(host, groups.length ? groups : [{ key: 'empty' }], (g) => g.key, (g) => {
    if (g.key === 'empty') return el('div', 'empty-state');
    const box = el('div', 'global-group');
    box.innerHTML = '<h3></h3><div class="global-body"></div>';
    return box;
  }, (box, g) => {
    if (g.key === 'empty') {
      setHtml(box, icon('tasks') + '<div class="empty-title">No tasks anywhere</div><div>Open a workspace and add a task, or ask an agent to schedule one.</div>');
      return;
    }
    setHtml(box.children[0], icon(g.w ? (g.w.id === 'node' ? 'home' : 'folder') : 'server') + ' ' + esc(g.w ? g.w.name : g.n.name) +
      ' <span class="tree-sub">' + esc(g.n.name) + '</span>');
    if (g.error) { setHtml(box.children[1], '<div class="form-hint">Could not load: ' + esc(g.error) + '</div>'); return; }
    box.children[1]._html = null;
    renderTaskSections(box.children[1], g.cards, '');
  });
}

/* ── architecture ── */
function loadArchitecture() {
  if (!state.sel.node || !state.sel.ws) return;
  const host = $('architectureView');
  const key = state.sel.node + '/' + state.sel.ws;
  let frame = host.querySelector('.architecture-frame');
  if (frame && frame.dataset.key === key) return;
  host.innerHTML = '';
  frame = el('iframe', 'architecture-frame');
  frame.title = 'Architecture graph of the workspace';
  frame.dataset.key = key;
  frame.src = 'architecture/index.html?workspace=' + enc(state.sel.ws) + (state.sel.node !== 'local' ? '&node=' + enc(state.sel.node) : '');
  host.appendChild(frame);
}

/* ── notifications ── */
async function loadNotifications(nodeId, announce) {
  let list = [];
  try { list = arr(await api(nodeId).get('/api/notifications')); } catch (e) { return; }
  const n = nodeById(nodeId);
  const name = n ? n.name : nodeId;
  const known = new Set(state.notifications.filter((x) => x.node === nodeId).map((x) => x.time + '|' + x.message));
  const fresh = [];
  list.forEach((x) => {
    const item = { node: nodeId, nodeName: name, message: String(x.message || x.text || ''), time: num(x.time) };
    if (!known.has(item.time + '|' + item.message)) { state.notifications.push(item); fresh.push(item); }
  });
  state.notifications.sort((a, b) => a.time - b.time);
  if (state.notifications.length > 120) state.notifications = state.notifications.slice(-120);
  if (announce && fresh.length) {
    state.notifUnseen += fresh.length;
    const last = fresh[fresh.length - 1];
    toast(name + ': ' + clip(last.message, 300), 'info', 7000);
  }
  renderNotificationBadge();
  if (!$('notificationPanel').classList.contains('hidden')) renderNotifications();
}

function renderNotificationBadge() {
  const b = $('notificationBadge');
  b.textContent = String(state.notifUnseen);
  b.classList.toggle('hidden', !state.notifUnseen);
}

function renderNotifications() {
  const panel = $('notificationPanel');
  if (!state.notifications.length) { panel.innerHTML = '<div class="empty-state compact">No notifications.</div>'; return; }
  panel.innerHTML = state.notifications.slice().reverse().map((n) =>
    '<div class="notification-item">' + esc(n.message) +
    '<div class="notification-meta">' + esc(n.nodeName) + (n.time ? '  ·  ' + esc(timeAgo(n.time)) : '') + '</div></div>').join('');
}

/* ── dialogs ── */
function openDialog(id) { $(id).classList.remove('hidden'); }
function closeDialog(id) {
  $(id).classList.add('hidden');
  if (id === 'settingsDialog') state.dialogNode = null;
}

/* settings: the sessions of a node and its Telegram gateway */
async function openSettings() {
  const sel = $('settingsNode');
  const nodes = state.nodes.filter((n) => n.kind === 'node' && n.online && n.api);
  sel.innerHTML = nodes.map((n) => '<option value="' + esc(n.id) + '">' + esc(n.name) + (n.local ? ' (this node)' : '') + '</option>').join('');
  const want = state.sel.node && nodes.some((n) => n.id === state.sel.node) ? state.sel.node : 'local';
  sel.value = want;
  openDialog('settingsDialog');
  await loadSettings(sel.value);
}

async function loadSettings(nodeId) {
  state.dialogNode = nodeId;
  $('gatewayToken').value = '';
  setHtml($('gatewayStatus'), '<span class="form-hint">Loading…</span>');
  try {
    const s = await api(nodeId).get('/api/settings');
    $('maxSessionsInput').value = num(s.max_sessions) || 2;
  } catch (e) {
    toast('Could not load the settings: ' + e.message, 'error');
  }
  await refreshGateway(true);
}

async function refreshGateway(fill) {
  const nodeId = state.dialogNode;
  if (!nodeId || $('settingsDialog').classList.contains('hidden')) return;
  let g = null;
  try {
    g = await api(nodeId).get('/api/gateway');
  } catch (e) {
    if (state.dialogNode !== nodeId) return;
    setHtml($('gatewayStatus'), '<span class="form-hint">' + (e.status === 404 ? 'This node has no gateway settings (an older version).' : 'Could not load: ' + esc(e.message)) + '</span>');
    return;
  }
  if (state.dialogNode !== nodeId) return;
  const s = g.settings || {};
  const st = g.status || {};
  if (fill) {
    $('gatewayEnabled').checked = truthy(s.enabled);
    $('gatewayName').value = s.name || '';
    $('gatewayConfig').value = s.config || '';
    $('gatewayToken').placeholder = truthy(s.token_set) ? 'saved (' + (s.token_hint || 'set') + ') — type a new one to replace it' : '123456:ABC-DEF…';
  }
  const running = truthy(st.running);
  const log = arr(st.log).slice(-12).map((l) => (typeof l === 'string' ? l : String(l.text || ''))).join('\n');
  setHtml($('gatewayStatus'),
    '<span class="chip ' + (running ? 'done' : (truthy(st.wanted) ? 'running' : '')) + '">' + (running ? 'running' : (truthy(st.wanted) ? 'starting…' : 'not running')) + '</span>' +
    (running && st.pid ? '<span class="form-hint">pid ' + esc(st.pid) + (num(st.restarts) ? ', restarted ' + num(st.restarts) + '×' : '') + '</span>' : '') +
    (!truthy(g.managed) ? '<div class="form-hint" style="margin-top:6px">This node was started with --no-gateway: the settings are saved, the gateway is started with <code>shz miniagent --telegram-gateway</code>.</div>' : '') +
    (st.last_exit && !running ? '<div class="form-hint" style="margin-top:6px">' + esc(st.last_exit) + '</div>' : '') +
    (log ? '<div class="gateway-log">' + esc(log) + '</div>' : ''));
}

async function saveSettings() {
  const nodeId = state.dialogNode;
  if (!nodeId) return;
  const a = api(nodeId);
  const max = Number($('maxSessionsInput').value);
  if (!Number.isInteger(max) || max < 1 || max > 64) { toast('The session limit is a number from 1 to 64.', 'warn'); return; }
  try {
    await a.put('/api/settings', { max_sessions: max });
    nd(nodeId).settings.max_sessions = max;
    const body = { enabled: $('gatewayEnabled').checked ? 'true' : 'false', name: $('gatewayName').value.trim(), config: $('gatewayConfig').value.trim() };
    const token = $('gatewayToken').value.trim();
    if (token) body.bot_token = token;
    try {
      await a.put('/api/gateway', body);
      $('gatewayToken').value = '';
    } catch (e) {
      if (e.status !== 404) throw e;      // a node without gateway settings: the rest was saved
    }
    toast('Settings saved.', 'success');
    renderStats();
    await refreshGateway(true);
  } catch (e) {
    toast('Could not save: ' + e.message, 'error');
  }
}

/* ── events ── */
function toggleSidebar() {
  const sb = $('sidebar');
  if (window.innerWidth <= 900) {
    sb.classList.toggle('open');
    $('sidebarOverlay').classList.toggle('hidden', !sb.classList.contains('open'));
  } else {
    sb.classList.toggle('collapsed');
    store('sidebar', sb.classList.contains('collapsed') ? 'collapsed' : null);
  }
}

function onTreeClick(e) {
  const btn = e.target.closest('[data-act]');
  if (!btn) return;
  const row = btn.closest('.tree-row');
  const nodeBox = btn.closest('.tree-node');
  const nodeId = (row && row.dataset.node) || (nodeBox && nodeBox.dataset.node);
  const wsId = row && row.dataset.ws;
  const act = btn.dataset.act;

  if (act === 'toggle-node') {
    const n = nodeById(nodeId);
    if (!n || n.kind !== 'node') return;
    if (state.openNodes.has(nodeId)) state.openNodes.delete(nodeId);
    else { state.openNodes.add(nodeId); if (n.online) ensureNode(nodeId); }
    saveSelection();
    renderTree();
  } else if (act === 'add-ws') {
    openWorkspaceDialog(nodeId, '');
  } else if (act === 'add-sub') {
    openWorkspaceDialog(nodeId, wsId);
  } else if (act === 'select-ws') {
    const key = wsKey(nodeId, wsId);
    const selected = state.sel.node === nodeId && state.sel.ws === wsId && !state.sel.session;
    // a click on the selected workspace folds it; any other click opens and selects
    if (selected && state.openWs.has(key)) state.openWs.delete(key);
    else state.openWs.add(key);
    selectWorkspace(nodeId, wsId);
  } else if (act === 'add-session') {
    newSession(nodeId, wsId);
  } else if (act === 'del-ws') {
    deleteWorkspace(nodeId, wsId);
  } else if (act === 'select-session') {
    selectSession(nodeId, wsId, row.dataset.session);
  } else if (act === 'del-session') {
    deleteSession(nodeId, wsId, row.dataset.session);
  }
  if (window.innerWidth <= 900 && (act === 'select-ws' || act === 'select-session')) {
    $('sidebar').classList.remove('open');
    $('sidebarOverlay').classList.add('hidden');
  }
}

function onChatClick(e) {
  const btn = e.target.closest('[data-act]');
  if (!btn) return;
  const act = btn.dataset.act;
  if (act === 'earlier') { showEarlier(); return; }
  const m = btn.closest('.msg');
  if (!m) return;
  if (act === 'open-detail') { e.stopPropagation(); openDetailDialog(m); return; }
  if (act === 'toggle-detail') {
    m.classList.toggle('open');
    if (m.classList.contains('open')) fillDetail(m);
  }
}

function bindEvents() {
  $('nodeTree').addEventListener('click', onTreeClick);
  $('chatMessages').addEventListener('click', onChatClick);
  $('chatMessages').addEventListener('scroll', () => {
    chat.stick = nearBottom();
    if (chat.stick) $('btnScrollDown').classList.add('hidden');
  });
  $('btnScrollDown').addEventListener('click', () => scrollChat(true));

  $('btnToggleSidebar').addEventListener('click', toggleSidebar);
  $('btnMobileMenu').addEventListener('click', toggleSidebar);
  $('sidebarOverlay').addEventListener('click', toggleSidebar);

  $('tabbar').addEventListener('click', (e) => { const b = e.target.closest('[data-tab]'); if (b) showTab(b.dataset.tab); });
  $('btnGlobalTasks').addEventListener('click', () => {
    if (state.view === 'globalTasks') { showView(state.sel.ws ? 'workspace' : 'welcome'); return; }
    showView('globalTasks');
    $('globalTasksContent').innerHTML = '';
    loadGlobalTasks();
  });
  $('btnSettings').addEventListener('click', openSettings);
  $('settingsNode').addEventListener('change', (e) => loadSettings(e.target.value));
  $('btnSaveSettings').addEventListener('click', saveSettings);

  $('modeToggle').addEventListener('click', (e) => { const b = e.target.closest('button[data-mode]'); if (b) setMode(b.dataset.mode); });
  $('reasoningEffort').addEventListener('change', (e) => setEffort(e.target.value));
  $('btnStopSession').addEventListener('click', stopSession);
  $('btnSendPrompt').addEventListener('click', sendPrompt);
  $('promptInput').addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) { e.preventDefault(); sendPrompt(); }
  });
  $('toggleDetails').addEventListener('change', (e) => {
    state.showDetails = e.target.checked;
    store('details', state.showDetails ? null : 'off');
    $('chatMessages').classList.toggle('no-details', !state.showDetails);
    scrollChat();
  });

  $('btnNewTask').addEventListener('click', () => { $('taskForm').classList.remove('hidden'); $('taskGoal').focus(); });
  $('btnCancelTask').addEventListener('click', () => $('taskForm').classList.add('hidden'));
  $('taskForm').addEventListener('submit', submitTask);
  const onTask = (e) => { const b = e.target.closest('[data-act]'); if (b && b.dataset.node) taskAction(b); };
  $('taskContent').addEventListener('click', onTask);
  $('globalTasksContent').addEventListener('click', onTask);

  $('workspaceForm').addEventListener('submit', (e) => { e.preventDefault(); createWorkspace(); });
  $('workspaceName').addEventListener('input', updateWorkspacePathHint);
  $('workspacePath').addEventListener('input', updateWorkspacePathHint);

  $('btnNotifications').addEventListener('click', () => {
    const panel = $('notificationPanel');
    panel.classList.toggle('hidden');
    if (!panel.classList.contains('hidden')) { state.notifUnseen = 0; renderNotificationBadge(); renderNotifications(); }
  });
  $('btnCopyDetail').addEventListener('click', async () => {
    try { await navigator.clipboard.writeText($('detailDialog')._plain || ''); toast('Copied.', 'success', 1500); }
    catch (e) { toast('The browser did not allow the copy.', 'warn'); }
  });

  document.addEventListener('click', (e) => {
    const closer = e.target.closest('[data-close]');
    if (closer) { closeDialog(closer.dataset.close); return; }
    if (e.target.classList && e.target.classList.contains('dialog-backdrop')) closeDialog(e.target.id);
    if (!e.target.closest('#notificationPanel') && !e.target.closest('#btnNotifications')) $('notificationPanel').classList.add('hidden');
  });
  document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    ['detailDialog', 'workspaceDialog', 'settingsDialog'].some((id) => {
      if ($(id).classList.contains('hidden')) return false;
      closeDialog(id);
      return true;
    });
  });
}

/* ── boot ── */
function restoreState() {
  try {
    state.openNodes = new Set(JSON.parse(store('open_nodes') || '["local"]'));
    state.openWs = new Set(JSON.parse(store('open_ws') || '[]'));
  } catch (e) { state.openNodes = new Set(['local']); }
  state.openNodes.add('local');
  state.showDetails = store('details') !== 'off';
  $('toggleDetails').checked = state.showDetails;
  $('chatMessages').classList.toggle('no-details', !state.showDetails);
  if (store('sidebar') === 'collapsed' && window.innerWidth > 900) $('sidebar').classList.add('collapsed');
  const tab = store('tab');
  if (tab && ['chat', 'tasks', 'architecture'].includes(tab)) state.tab = tab;
}

async function restoreSelection() {
  let sel = null;
  try { sel = JSON.parse(store('sel') || 'null'); } catch (e) { sel = null; }
  if (!sel || !sel.node || !sel.ws) return;
  const n = nodeById(sel.node);
  if (!n || !n.online || n.kind !== 'node') return;
  // wait for that node's workspaces
  for (let i = 0; i < 40 && !nd(sel.node).loaded && !nd(sel.node).error; i++) {
    ensureNode(sel.node);
    await sleep(100);
  }
  if (!workspaceOf(sel.node, sel.ws)) return;
  if (sel.session) {
    // (the session list comes with the first answer of the live feed)
    for (let i = 0; i < 30 && !nd(sel.node).rev; i++) await sleep(100);
    if (nd(sel.node).sessions.some((s) => s.id === sel.session)) { await selectSession(sel.node, sel.ws, sel.session); return; }
  }
  await selectWorkspace(sel.node, sel.ws);
}

async function init() {
  bindEvents();
  restoreState();
  showTab(state.tab);
  showView('welcome');
  renderChatEmpty();
  renderSessionHeader();
  renderStats();

  await loadNodes();
  ensureNode('local');
  await restoreSelection();

  // the gateway status of an open settings dialog; the node list as a fallback for
  // a node whose live feed does not tell (an older one)
  setInterval(() => refreshGateway(false), 3000);
  setInterval(() => { if (nd('local').treeRev < 0 || !nd('local').linkOk) loadNodes().catch(() => {}); }, 15000);
  setInterval(() => { if (state.view === 'workspace' && state.tab === 'tasks') loadTasks(); else if (state.view === 'globalTasks') loadGlobalTasks(); }, 30000);
}

document.addEventListener('DOMContentLoaded', init);
