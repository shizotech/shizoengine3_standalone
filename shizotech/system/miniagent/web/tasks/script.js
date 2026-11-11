/* Tasks: the worker pool of the node (GET /api/tasks, /api/status, /api/events) */
const $ = (id) => document.getElementById(id);
// an empty list arrives as {} (ShizoScript json)
const arr = (x) => (Array.isArray(x) ? x : x && typeof x === 'object' ? Object.values(x) : []);
const esc = (s) => String(s == null ? '' : s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const LIVE_STATES = ['planned', 'research', 'implement', 'running'];
let lastRenderSignature = '';

function taskSignature(tasks, events, status) {
  const visibleTask = (task) => [
    task.taskid, task.name, task.state, task.task, task.goal,
    task.report, task.raw_output ? String(task.raw_output).slice(-1200) : '', task.start_time, task.end_time, task.last_update_ms
  ];
  const eventSignature = arr(events).map((event) => [
    event.taskid, event.name, event.state, event.report, event.time
  ]);
  status = status || {};
  return JSON.stringify([
    status.receptionist && status.receptionist.active,
    status.receptionist && status.receptionist.queued,
    status.tasks && status.tasks.running,
    status.tasks && status.tasks.planned,
    status.model && status.model.name,
    arr(tasks).map(visibleTask),
    eventSignature
  ]);
}

function ago(ms) {
  if (!ms) return '';
  const s = Math.max(0, Math.round((Date.now() - ms) / 1000));
  if (s < 60) return s + ' s ago';
  if (s < 3600) return Math.round(s / 60) + ' min ago';
  return Math.round(s / 3600) + ' h ago';
}

function taskCard(t) {
  const st = t.state || 'planned';
  const live = st === 'research' || st === 'implement' || st === 'running';
  const id = t.taskid;
  const out = t.raw_output ? `<div class="task-out">${esc(String(t.raw_output).slice(-1200))}</div>` : '';
  const report = t.report ? `<div class="report">${esc(t.report)}</div>` : '';
  const actions = (live || st === 'planned')
    ? `<div class="task-actions">
         <button class="btn" data-update="${esc(id)}">Send update</button>
         <button class="btn danger" data-stop="${esc(id)}">Stop</button>
       </div>` : '';
  return `<div class="task-head">${live ? '<span class="pulse"></span>' : ''}
      <span class="task-name" title="${esc(t.name)}">${esc(t.name)}</span>
      <span class="badge ${esc(st)}">${esc(st)}</span></div>
    <div class="task-goal">${esc(t.task || t.goal || '')}</div>
    <div class="task-meta">${t.start_time ? (String(t.start_time).startsWith('ended') ? esc(t.start_time) : 'started ' + esc(t.start_time)) : 'waiting for a worker'}${t.last_update_ms ? ' · last activity ' + ago(t.last_update_ms) : ''}</div>
    ${report}${out}${actions}`;
}

function renderTaskList(host, items, emptyText) {
  if (!items.length) {
    if (host.children.length !== 1 || !host.firstElementChild.classList.contains('empty')) {
      host.innerHTML = `<div class="empty">${emptyText}</div>`;
    }
    return;
  }

  if (host.firstElementChild && host.firstElementChild.classList.contains('empty')) host.textContent = '';
  const existing = new Map(Array.from(host.querySelectorAll(':scope > .card')).map((card) => [card.dataset.taskId, card]));
  items.forEach((task, index) => {
    const id = String(task.taskid || `${task.name || 'task'}-${index}`);
    let card = existing.get(id);
    if (!card) {
      card = document.createElement('div');
      card.className = 'card';
      card.dataset.taskId = id;
    }
    const renderKey = JSON.stringify([
      task.name, task.state, task.task, task.goal, task.report, task.raw_output ? String(task.raw_output).slice(-1200) : '', task.start_time, task.end_time, task.last_update_ms, task.last_update_ms
    ]);
    if (card.dataset.renderKey !== renderKey) {
      card.innerHTML = taskCard(task);
      card.dataset.renderKey = renderKey;
    }
    const current = host.children[index];
    if (current !== card) host.insertBefore(card, current || null);
    existing.delete(id);
  });
  existing.forEach((card) => card.remove());
}

let refreshInFlight = false;
async function refresh() {
  if (refreshInFlight) return;
  refreshInFlight = true;
  try {
    const [st, tasks, events] = await Promise.all([
      NodeApi.get('/api/status'), NodeApi.get('/api/tasks'), NodeApi.get('/api/events'),
    ]);
    const signature = taskSignature(tasks, events, st);
    const t = st.tasks || {};
    const statsHtml = `<span>receptionist <b>${st.receptionist && st.receptionist.active ? 'busy' : 'idle'}</b></span>
      <span>queued requests <b>${(st.receptionist && st.receptionist.queued) || 0}</b></span>
      <span>running <b>${t.running || 0}</b></span><span>planned <b>${t.planned || 0}</b></span>
      <span>model <b>${esc((st.model && st.model.name) || '?')}</b></span>`;
    if ($('stats').innerHTML !== statsHtml) $('stats').innerHTML = statsHtml;
    if (signature === lastRenderSignature) return;

    const live = arr(tasks).filter((x) => LIVE_STATES.includes(x.state));
    renderTaskList($('tasks'), live, 'No running or planned task.');

    // the node keeps the last finished / failed tasks, the events have the rest of this session
    const done = arr(tasks).filter((x) => !LIVE_STATES.includes(x.state));
    const seen = new Set(done.map((x) => x.taskid));
    arr(events).forEach((e) => {
      if (!seen.has(e.taskid)) done.push({ name: e.name, state: e.state, report: e.report, taskid: e.taskid, end_time: new Date(e.time).toLocaleString() });
    });
    const finished = done.map((task) => Object.assign({}, task, { start_time: task.end_time ? 'ended ' + task.end_time : task.start_time }));
    renderTaskList($('events'), finished, 'Nothing finished yet.');
    lastRenderSignature = signature;
  } catch (e) {
    $('stats').textContent = e.status === 401 ? 'The node needs its API token.' : 'The node does not answer: ' + e.message;
  } finally {
    refreshInFlight = false;
  }
}

document.addEventListener('click', async (ev) => {
  const stop = ev.target.closest('[data-stop]');
  const upd = ev.target.closest('[data-update]');
  try {
    if (stop && confirm('Stop this task?')) { await NodeApi.del('/api/task/' + stop.dataset.stop); refresh(); }
    if (upd) {
      const msg = prompt('Message for the worker of this task:');
      if (msg) { await NodeApi.put('/api/task/' + upd.dataset.update, { message: msg }); refresh(); }
    }
  } catch (e) { alert(e.message); }
});

$('btnNew').onclick = () => { $('newTask').classList.toggle('hidden'); $('taskGoal').focus(); };
$('btnCancel').onclick = () => $('newTask').classList.add('hidden');
$('newTask').onsubmit = async (ev) => {
  ev.preventDefault();
  const goal = $('taskGoal').value.trim();
  if (!goal) return;
  try {
    await NodeApi.post('/api/task', { name: $('taskName').value.trim(), goal });
    $('taskGoal').value = ''; $('taskName').value = '';
    $('newTask').classList.add('hidden');
    refresh();
  } catch (e) { alert(e.message); }
};

refresh();
setInterval(() => { if (!document.hidden) refresh(); }, 10000);
document.addEventListener('visibilitychange', () => { if (!document.hidden) refresh(); });
