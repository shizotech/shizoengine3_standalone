/* ── Architecture graph: .megimind/architecture/architecture.json as an editable node graph ──
 *
 * GET  /api/architecture            model with the pending edits applied (marked)
 * POST /api/architecture/edits      one edit -> pending (nothing changes in the code)
 * POST /api/architecture/plan       a worker writes a plan for the pending edits
 * POST /api/architecture/apply      a worker implements the pending edits
 * POST /api/architecture/analyze    a worker (re)writes the model from the code
 * POST /api/architecture/layout     node positions
 *
 * A small SVG renderer of its own (no library, no CDN): grouped force layout,
 * pan / zoom, drag, connect mode, search, focus on a node's neighbourhood.
 */
(() => {
  'use strict';

  const NS = 'http://www.w3.org/2000/svg';
  const NODE_W = 200, NODE_H = 60;
  const KIND = {
    module:   { color: '#d4ae45', glyph: '◆' },
    file:     { color: '#b8c0c2', glyph: '▤' },
    service:  { color: '#df6258', glyph: '⚙' },
    ui:       { color: '#e7a54f', glyph: '▣' },
    data:     { color: '#d8c46a', glyph: '⛁' },
    external: { color: '#899397', glyph: '☁' },
    test:     { color: '#bd8d50', glyph: '✔' },
    config:   { color: '#ef806b', glyph: '⚑' },
  };
  const EDGE = {
    calls:    { color: '#a9afb0', dash: '' },
    data:     { color: '#d8c46a', dash: '' },
    includes: { color: '#b8c0c2', dash: '2 5' },
    events:   { color: '#df6258', dash: '7 5' },
    network:  { color: '#e7a54f', dash: '10 4 2 4' },
  };

  const $ = (id) => document.getElementById(id);
  const workspaceId = new URLSearchParams(window.location.search).get('workspace');
  const apiBase = workspaceId ? '/api/workspaces/' + encodeURIComponent(workspaceId) + '/architecture' : '/api/architecture';
  const api = (path = '') => apiBase + path;
  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const md = window.markdownit ? window.markdownit({ html: false, linkify: true, breaks: true }) : { render: esc };

  const S = {
    data: null,           // the last /api/architecture answer
    sig: '',              // what was drawn (skip redraws while nothing changed)
    pos: new Map(),       // id -> {x, y}
    view: { x: 0, y: 0, k: 1 },
    selected: null,       // {type: 'node'|'edge', id}
    mode: null,           // null | 'connect'
    connectFrom: null,
    form: null,           // null | 'add'
    hover: null,
    dragging: null,
    fitted: false,
    busy: false,
  };

  // ── helpers ────────────────────────────────────────────────────────────────
  function el(tag, attrs, parent) {
    const e = document.createElementNS(NS, tag);
    for (const k in attrs || {}) e.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(e);
    return e;
  }

  function hash(s) {
    let h = 2166136261;
    for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
    return h >>> 0;
  }

  function groupColor(g) {
    const hue = 18 + hash(g || '-') % 36;
    return { fill: `hsla(${hue}, 48%, 38%, 0.08)`, stroke: `hsla(${hue}, 58%, 62%, 0.34)`, text: `hsla(${hue}, 66%, 76%, 0.88)` };
  }

  function toast(msg, err) {
    const t = document.createElement('div');
    t.className = 'toast' + (err ? ' err' : '');
    t.textContent = msg;
    document.body.appendChild(t);
    setTimeout(() => t.remove(), err ? 6000 : 3000);
  }

  function nodes() { return (S.data && S.data.nodes) || []; }
  function edges() { return (S.data && S.data.edges) || []; }
  function nodeById(id) { return nodes().find((n) => n.id === id); }
  function edgeById(id) { return edges().find((e) => e.id === id); }
  function jobOpen(j) { return j && ['planned', 'research', 'implement', 'running'].includes(j.state); }

  function trunc(text, max) {
    text = String(text || '');
    return text.length > max ? text.slice(0, max - 1) + '…' : text;
  }

  // ── layout: groups on a ring, then a force simulation ─────────────────────
  function layout(all) {
    const list = nodes();
    const need = list.filter((n) => all || !S.pos.has(n.id));
    if (!need.length) return [];

    const groups = [...new Set(list.map((n) => n.group || ''))].sort();
    const R = 160 + groups.length * 110 + Math.sqrt(list.length) * 40;
    const centers = {};
    groups.forEach((g, i) => {
      const a = (i / Math.max(1, groups.length)) * Math.PI * 2;
      centers[g] = { x: Math.cos(a) * R, y: Math.sin(a) * R * 0.7 };
    });

    const P = {};
    list.forEach((n) => {
      if (!all && S.pos.has(n.id)) { P[n.id] = { ...S.pos.get(n.id), fixed: true }; return; }
      const c = centers[n.group || ''];
      const h = hash(n.id);
      P[n.id] = { x: c.x + ((h % 200) - 100), y: c.y + (((h >> 8) % 160) - 80), vx: 0, vy: 0 };
    });

    const E = edges().filter((e) => P[e.source] && P[e.target]);
    for (let it = 0; it < 420; it++) {
      const cool = 1 - it / 420;
      for (let i = 0; i < list.length; i++) {
        const a = P[list[i].id];
        for (let j = i + 1; j < list.length; j++) {
          const b = P[list[j].id];
          let dx = a.x - b.x, dy = (a.y - b.y) * 1.6;
          let d2 = dx * dx + dy * dy;
          if (d2 < 1) { dx = 1; dy = 0; d2 = 1; }
          const same = (list[i].group || '') === (list[j].group || '');
          const f = (same ? 60000 : 140000) / d2;
          const d = Math.sqrt(d2);
          const fx = (dx / d) * f, fy = (dy / d) * f;
          if (!a.fixed) { a.vx += fx; a.vy += fy; }
          if (!b.fixed) { b.vx -= fx; b.vy -= fy; }
        }
      }
      for (const e of E) {
        const a = P[e.source], b = P[e.target];
        const dx = b.x - a.x, dy = b.y - a.y;
        const d = Math.sqrt(dx * dx + dy * dy) || 1;
        const f = (d - 300) * 0.01;
        const fx = (dx / d) * f, fy = (dy / d) * f;
        if (!a.fixed) { a.vx += fx; a.vy += fy; }
        if (!b.fixed) { b.vx -= fx; b.vy -= fy; }
      }
      // members pull towards their group centre, the groups to the middle
      const gc = {};
      list.forEach((n) => {
        const g = n.group || '';
        gc[g] = gc[g] || { x: 0, y: 0, c: 0 };
        gc[g].x += P[n.id].x; gc[g].y += P[n.id].y; gc[g].c++;
      });
      list.forEach((n) => {
        const p = P[n.id];
        if (p.fixed) return;
        const g = gc[n.group || ''];
        p.vx += (g.x / g.c - p.x) * 0.02 - p.x * 0.002;
        p.vy += (g.y / g.c - p.y) * 0.02 - p.y * 0.002;
        const max = 40 * cool + 2;
        p.vx = Math.max(-max, Math.min(max, p.vx));
        p.vy = Math.max(-max, Math.min(max, p.vy));
        p.x += p.vx; p.y += p.vy;
        p.vx *= 0.6; p.vy *= 0.6;
      });
    }
    // boxes must not overlap: push apart along the axis that overlaps least
    const GAP_X = 36, GAP_Y = 34;
    for (let pass = 0; pass < 120; pass++) {
      let any = false;
      for (let i = 0; i < list.length; i++) {
        for (let j = i + 1; j < list.length; j++) {
          const a = P[list[i].id], b = P[list[j].id];
          if (a.fixed && b.fixed) continue;
          const ox = NODE_W + GAP_X - Math.abs(a.x - b.x);
          const oy = NODE_H + GAP_Y - Math.abs(a.y - b.y);
          if (ox <= 0 || oy <= 0) continue;
          any = true;
          const share = a.fixed || b.fixed ? 1 : 0.5;
          if (ox / (NODE_W + GAP_X) < oy / (NODE_H + GAP_Y)) {
            const d = (a.x < b.x || (a.x === b.x && i < j) ? -1 : 1) * ox * share;
            if (!a.fixed) a.x += d;
            if (!b.fixed) b.x -= d;
          }
          else {
            const d = (a.y < b.y || (a.y === b.y && i < j) ? -1 : 1) * oy * share;
            if (!a.fixed) a.y += d;
            if (!b.fixed) b.y -= d;
          }
        }
      }
      if (!any) break;
    }

    const moved = [];
    need.forEach((n) => {
      const p = { x: Math.round(P[n.id].x), y: Math.round(P[n.id].y) };
      S.pos.set(n.id, p);
      moved.push(n.id);
    });
    return moved;
  }

  let saveTimer = null;
  const unsaved = new Set();
  function savePositions(ids) {
    ids.forEach((id) => unsaved.add(id));
    clearTimeout(saveTimer);
    saveTimer = setTimeout(async () => {
      const positions = {};
      unsaved.forEach((id) => { const p = S.pos.get(id); if (p) positions[id] = [p.x, p.y]; });
      unsaved.clear();
      try { await NodeApi.post(api('/layout'), { positions }); } catch (e) { /* positions are a convenience */ }
    }, 600);
  }

  // ── view ───────────────────────────────────────────────────────────────────
  let lastK = 1;
  function applyView() {
    $('viewport').setAttribute('transform', `translate(${S.view.x},${S.view.y}) scale(${S.view.k})`);
    if ((lastK >= 1.05) !== (S.view.k >= 1.05)) { lastK = S.view.k; if (S.data) highlight(); }
  }

  function fit() {
    const list = nodes();
    if (!list.length) return;
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    list.forEach((n) => {
      const p = S.pos.get(n.id); if (!p) return;
      x0 = Math.min(x0, p.x - NODE_W / 2); x1 = Math.max(x1, p.x + NODE_W / 2);
      y0 = Math.min(y0, p.y - NODE_H / 2 - 30); y1 = Math.max(y1, p.y + NODE_H / 2);
    });
    const r = $('stage').getBoundingClientRect();
    const pad = 60;
    const k = Math.min(1.4, Math.max(0.2, Math.min((r.width - pad * 2) / (x1 - x0), (r.height - pad * 2) / (y1 - y0))));
    S.view.k = k;
    S.view.x = r.width / 2 - ((x0 + x1) / 2) * k;
    S.view.y = r.height / 2 - ((y0 + y1) / 2) * k;
    applyView();
  }

  function toWorld(cx, cy) {
    const r = $('svg').getBoundingClientRect();
    return { x: (cx - r.left - S.view.x) / S.view.k, y: (cy - r.top - S.view.y) / S.view.k };
  }

  // ── drawing ──────────────────────────────────────────────────────────────
  function defs() {
    const d = $('defs');
    d.innerHTML = '';
    const mk = (id, color) => {
      const m = el('marker', { id, viewBox: '0 0 10 10', refX: 9, refY: 5, markerWidth: 7, markerHeight: 7, orient: 'auto-start-reverse' }, d);
      el('path', { d: 'M0,0 L10,5 L0,10 z', fill: color }, m);
    };
    for (const k in EDGE) mk('arrow-' + k, EDGE[k].color);
    mk('arrow-add', '#ffc24b');
    mk('arrow-remove', '#ff6b6b');
    const f = el('filter', { id: 'shadow', x: '-20%', y: '-20%', width: '140%', height: '160%' }, d);
    el('feDropShadow', { dx: 0, dy: 4, stdDeviation: 6, 'flood-color': '#000', 'flood-opacity': 0.45 }, f);
    const g = el('linearGradient', { id: 'cardGrad', x1: 0, y1: 0, x2: 0, y2: 1 }, d);
    el('stop', { offset: '0%', 'stop-color': '#242526' }, g);
    el('stop', { offset: '100%', 'stop-color': '#171819' }, g);
  }

  // where the line from the centre of a towards b leaves a's box
  function boxExit(a, b) {
    const dx = b.x - a.x, dy = b.y - a.y;
    const sx = (NODE_W / 2 + 4) / Math.abs(dx || 1e-6), sy = (NODE_H / 2 + 4) / Math.abs(dy || 1e-6);
    const s = Math.min(sx, sy);
    return { x: a.x + dx * s, y: a.y + dy * s };
  }

  function edgePath(e) {
    const a = S.pos.get(e.source), b = S.pos.get(e.target);
    if (!a || !b) return null;
    const p0 = boxExit(a, b), p1 = boxExit(b, a);
    // parallel / opposite edges bend apart
    const twins = edges().filter((x) => (x.source === e.source && x.target === e.target) || (x.source === e.target && x.target === e.source));
    const idx = twins.indexOf(e);
    const bend = twins.length > 1 ? (idx - (twins.length - 1) / 2) * 46 * (e.source < e.target ? 1 : -1) : 0;
    const mx = (p0.x + p1.x) / 2, my = (p0.y + p1.y) / 2;
    const dx = p1.x - p0.x, dy = p1.y - p0.y;
    const len = Math.sqrt(dx * dx + dy * dy) || 1;
    const nx = -dy / len, ny = dx / len;
    const curve = bend + Math.min(40, len * 0.08);
    const cx = mx + nx * curve, cy = my + ny * curve;
    return { d: `M${p0.x},${p0.y} Q${cx},${cy} ${p1.x},${p1.y}`, lx: (p0.x + 2 * cx + p1.x) / 4, ly: (p0.y + 2 * cy + p1.y) / 4 };
  }

  function drawGroups() {
    const G = $('groups');
    G.innerHTML = '';
    const by = {};
    nodes().forEach((n) => { if (n.group) (by[n.group] = by[n.group] || []).push(n); });
    for (const g in by) {
      let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
      by[g].forEach((n) => {
        const p = S.pos.get(n.id); if (!p) return;
        x0 = Math.min(x0, p.x - NODE_W / 2); x1 = Math.max(x1, p.x + NODE_W / 2);
        y0 = Math.min(y0, p.y - NODE_H / 2); y1 = Math.max(y1, p.y + NODE_H / 2);
      });
      if (x0 === Infinity) continue;
      const c = groupColor(g);
      const pad = 22;
      el('rect', { class: 'group-box', x: x0 - pad, y: y0 - pad - 18, width: x1 - x0 + pad * 2, height: y1 - y0 + pad * 2 + 18, rx: 18, fill: c.fill, stroke: c.stroke }, G);
      const t = el('text', { class: 'group-label', x: x0 - pad + 14, y: y0 - pad + 2, fill: c.text }, G);
      t.textContent = g;
    }
  }

  function drawEdges() {
    const E = $('edges'), L = $('edgeLabels');
    E.innerHTML = ''; L.innerHTML = '';
    edges().forEach((e) => {
      const p = edgePath(e);
      if (!p) return;
      const st = EDGE[e.kind] || EDGE.calls;
      const marker = e.pending === 'add' ? 'arrow-add' : e.pending === 'remove' ? 'arrow-remove' : 'arrow-' + (EDGE[e.kind] ? e.kind : 'calls');
      const cls = ['edge'];
      if (e.pending) cls.push('pending-' + e.pending);
      if (S.selected && S.selected.type === 'edge' && S.selected.id === e.id) cls.push('selected');
      if (e.kind === 'data' || e.kind === 'events') cls.push('flow');
      const path = el('path', { class: cls.join(' '), d: p.d, stroke: st.color, 'marker-end': `url(#${marker})`, 'data-edge': e.id }, E);
      if (st.dash && !cls.includes('flow')) path.setAttribute('stroke-dasharray', st.dash);
      const hit = el('path', { class: 'edge-hit', d: p.d, 'data-edge': e.id }, E);
      const tip = el('title', {}, hit);
      tip.textContent = `${e.source} → ${e.target} (${e.kind})${e.label ? ': ' + e.label : ''}`;
      if (e.label) {
        const t = el('text', { class: 'edge-label', x: p.lx, y: p.ly, 'text-anchor': 'middle', 'data-edge-label': e.id }, L);
        t.textContent = trunc(e.label, 28);
      }
    });
  }

  function drawNodes() {
    const N = $('nodes');
    N.innerHTML = '';
    nodes().forEach((n) => {
      const p = S.pos.get(n.id);
      if (!p) return;
      const k = KIND[n.kind] || KIND.module;
      const cls = ['node'];
      if (n.pending) cls.push('pending-' + n.pending);
      if (S.selected && S.selected.type === 'node' && S.selected.id === n.id) cls.push('selected');
      if (S.connectFrom === n.id) cls.push('connect-source');
      const g = el('g', { class: cls.join(' '), transform: `translate(${p.x - NODE_W / 2},${p.y - NODE_H / 2})`, 'data-node': n.id }, N);
      el('rect', { class: 'card', width: NODE_W, height: NODE_H, rx: 12, fill: 'url(#cardGrad)', stroke: k.color + '88', filter: 'url(#shadow)' }, g);
      el('rect', { class: 'accent', x: 0, y: 0, width: 5, height: NODE_H, rx: 2.5, fill: k.color }, g);
      el('circle', { cx: 26, cy: NODE_H / 2, r: 14, fill: k.color + '22', stroke: k.color + '66' }, g);
      const gl = el('text', { class: 'glyph', x: 26, y: NODE_H / 2 + 1, fill: k.color }, g);
      gl.textContent = k.glyph;
      const lb = el('text', { class: 'label', x: 48, y: 24 }, g);
      lb.textContent = trunc(n.label, 20);
      const pu = el('text', { class: 'purpose', x: 48, y: 42 }, g);
      pu.textContent = trunc(n.purpose || n.path || '', 30);
      if (n.pending) {
        const text = { add: 'NEW', update: 'CHANGED', remove: 'REMOVED' }[n.pending];
        const color = n.pending === 'remove' ? '#ff6b6b' : '#ffc24b';
        const w = text.length * 6.6 + 12;
        el('rect', { x: NODE_W - w - 6, y: NODE_H - 8, width: w, height: 15, rx: 7.5, fill: color }, g);
        const r = el('text', { class: 'ribbon', x: NODE_W - 6 - w / 2, y: NODE_H + 3, 'text-anchor': 'middle', fill: '#1a1a1a' }, g);
        r.textContent = text;
      }
      const tip = el('title', {}, g);
      tip.textContent = `${n.label} (${n.kind})${n.path ? '\n' + n.path : ''}${n.purpose ? '\n' + n.purpose : ''}`;
    });
  }

  function highlight() {
    const q = ($('search').value || '').trim().toLowerCase();
    const focus = S.hover || (S.selected && S.selected.type === 'node' ? S.selected.id : null);
    const near = new Set();
    if (focus) {
      near.add(focus);
      edges().forEach((e) => { if (e.source === focus) near.add(e.target); if (e.target === focus) near.add(e.source); });
    }
    document.querySelectorAll('[data-node]').forEach((g) => {
      const n = nodeById(g.dataset.node);
      const hit = q && n && (n.label + ' ' + n.id + ' ' + (n.path || '') + ' ' + (n.purpose || '') + ' ' + (n.group || '')).toLowerCase().includes(q);
      g.classList.toggle('match', !!hit);
      g.classList.toggle('dim', (focus && !near.has(g.dataset.node)) || (!!q && !hit));
    });
    document.querySelectorAll('path.edge').forEach((p) => {
      const e = edgeById(p.dataset.edge);
      p.classList.toggle('dim', !!(focus && e && e.source !== focus && e.target !== focus) || !!q);
    });
    // edge labels: for the focused node, or everywhere when zoomed in
    document.querySelectorAll('[data-edge-label]').forEach((t) => {
      const e = edgeById(t.dataset.edgeLabel);
      const near = focus && e && (e.source === focus || e.target === focus);
      t.style.display = near || (!focus && !q && S.view.k >= 1.05) ? '' : 'none';
    });
  }

  function draw() {
    drawGroups();
    drawEdges();
    drawNodes();
    highlight();
  }

  function drawLegend() {
    const kinds = [...new Set(nodes().map((n) => n.kind))];
    const ekinds = [...new Set(edges().map((e) => e.kind))];
    $('legend').innerHTML =
      `<div class="col">${kinds.map((k) => `<div class="item"><span class="sw" style="background:${(KIND[k] || KIND.module).color}"></span>${esc(k)}</div>`).join('')}</div>` +
      `<div class="col">${ekinds.map((k) => `<div class="item"><span class="ln" style="border-color:${(EDGE[k] || EDGE.calls).color};border-top-style:${k === 'includes' ? 'dotted' : k === 'events' || k === 'network' ? 'dashed' : 'solid'}"></span>${esc(k)}</div>`).join('')}` +
      `<div class="item"><span class="ln" style="border-color:#ffc24b;border-top-style:dashed"></span>pending</div></div>`;
    $('legend').classList.toggle('hidden', !nodes().length);
  }

  // ── panel ────────────────────────────────────────────────────────────────
  function jobText(j) {
    if (!j || !j.kind) return '';
    const what = { analyze: 'Analysis', plan: 'Plan', apply: 'Apply' }[j.kind] || j.kind;
    const st = { planned: 'waiting for a worker', research: 'reading the code', implement: 'working', finished: 'done', failed: 'failed', lost: 'lost', stopped: 'stopped', question: 'has a question' }[j.state] || j.state;
    return `${what}: ${st}`;
  }

  function renderJob() {
    const j = S.data && S.data.job;
    const box = $('job');
    if (!j || !j.kind || (!jobOpen(j) && Date.now() - (j.finished || 0) > 120000 && j.state === 'finished')) {
      box.classList.add('hidden');
    } else {
      box.className = 'job ' + (j.state || '');
      box.innerHTML = (jobOpen(j) ? '<span class="spin"></span>' : '') + esc(jobText(j));
      box.title = j.error || j.report || '';
    }
    const open = jobOpen(j);
    $('btnAnalyze').disabled = open;
    $('btnAnalyzeEmpty').disabled = open;
    $('emptyJob').innerHTML = j && j.kind === 'analyze' ? (open ? '<span class="spin"></span> ' : '') + esc(jobText(j)) + (j.error ? `<div class="errbox">${esc(j.error)}</div>` : '') : '';
  }

  function editText(p) {
    const name = (id) => { const n = nodeById(id); return n ? n.label : id; };
    switch (p.op) {
      case 'add_node': return `<b>Add</b> ${esc(p.node.label)} <span class="muted">(${esc(p.node.kind)})</span>`;
      case 'update_node': return `<b>Change</b> ${esc(name(p.target))}: ${Object.keys(p.node).map((k) => esc(k)).join(', ')}`;
      case 'remove_node': return `<b>Remove</b> ${esc(name(p.target))}`;
      case 'add_edge': return `<b>Connect</b> ${esc(name(p.edge.source))} → ${esc(name(p.edge.target))} <span class="muted">(${esc(p.edge.kind)})</span>`;
      case 'update_edge': return `<b>Change connection</b> ${esc(p.target)}`;
      case 'remove_edge': { const e = edgeById(p.target); return `<b>Disconnect</b> ${e ? esc(name(e.source)) + ' → ' + esc(name(e.target)) : esc(p.target)}`; }
      default: return esc(p.op);
    }
  }

  function kindOptions(sel, list) {
    return list.map((k) => `<option value="${k}"${k === sel ? ' selected' : ''}>${k}</option>`).join('');
  }

  function panelOverview() {
    const d = S.data || {};
    const pend = d.pending || [];
    const j = d.job || {};
    const plan = d.plan || {};
    const busy = jobOpen(j);
    let h = '';
    h += `<h3>Overview</h3>
      <div class="big-title">${esc(d.project || 'This codebase')}</div>
      <div class="muted">${esc(d.summary || 'No analysis yet.')}</div>
      <div class="stats"><div class="stat"><b>${nodes().filter((n) => n.pending !== 'add').length}</b><span>nodes</span></div>
        <div class="stat"><b>${edges().filter((e) => e.pending !== 'add').length}</b><span>connections</span></div>
        <div class="stat"><b>${pend.length}</b><span>pending</span></div></div>`;
    if (d.analyzed_at) h += `<div class="muted">analyzed ${esc(d.analyzed_at)} · revision ${esc(d.revision)}</div>`;
    if (j.kind && j.error) h += `<div class="errbox">${esc(jobText(j))}: ${esc(j.error)}</div>`;

    h += `<h3>Pending changes <span class="count">${pend.length}</span></h3>`;
    if (!pend.length) {
      h += `<div class="muted">Select a node to change, connect or remove it, or add a node with <b>+ Node</b>. Changes stay here until you press <b>Apply</b>; then a worker implements them in the code.</div>`;
    } else {
      h += pend.map((p) => `<div class="edit ${p.op.startsWith('remove') ? 'remove' : ''}"><div class="txt">${editText(p)}${p.note ? `<div class="note">${esc(p.note)}</div>` : ''}</div><button class="x" title="Drop this change" data-drop="${esc(p.id)}">✕</button></div>`).join('');
      h += `<div class="row"><button class="btn" id="pPlan" ${busy ? 'disabled' : ''}>Review plan</button><button class="btn warn" id="pApply" ${busy ? 'disabled' : ''}>Apply</button></div>
            <div class="row"><button class="btn small danger" id="pDiscard" ${busy ? 'disabled' : ''}>Discard all</button></div>`;
    }

    if (plan.text || (j.kind === 'plan' && busy)) {
      h += `<h3>Plan</h3>`;
      if (j.kind === 'plan' && busy) h += `<div class="muted"><span class="spin"></span> A worker is writing the plan…</div>`;
      if (plan.text) {
        if (plan.outdated) h += `<div class="warnbox">The changes were edited after this plan was written. Review the plan again before Apply.</div>`;
        h += `<div class="plan">${md.render(plan.text)}</div>
          <label>Your feedback on the plan</label>
          <textarea id="pFeedback" placeholder="What should change in the plan?"></textarea>
          <div class="row"><button class="btn" id="pRevise" ${busy ? 'disabled' : ''}>Revise plan</button></div>`;
      }
    }

    const hist = (d.history || []).slice(-6).reverse();
    if (hist.length) {
      h += `<h3>History</h3>` + hist.map((x) => `<div class="history-item">${new Date(x.time).toLocaleString()} · ${esc(x.kind)}${x.edits ? ' · ' + x.edits + ' changes' : ''}</div>`).join('');
    }
    return h;
  }

  function panelNode(n) {
    const ins = edges().filter((e) => e.target === n.id);
    const outs = edges().filter((e) => e.source === n.id);
    const conn = (e, other, dir) => `<div class="conn" data-goto="${esc(other)}"><span class="k">${dir} ${esc(e.kind)}</span>${esc((nodeById(other) || {}).label || other)}${e.label ? ` <span class="muted">· ${esc(e.label)}</span>` : ''}${e.pending ? ` <span class="muted">(${esc(e.pending)})</span>` : ''}<span style="flex:1"></span><button class="x" title="Remove this connection" data-cut="${esc(e.id)}" style="background:none;border:none;color:var(--text-secondary);cursor:pointer">✕</button></div>`;
    const locked = n.pending === 'add' || n.pending === 'remove';
    let h = `<h3><a href="#" id="pBack" style="color:inherit">← Overview</a></h3>
      <div class="big-title">${esc(n.label)}</div>
      <div class="muted">${esc(n.purpose || '')}</div>
      <div class="kv"><div>id</div><div><code>${esc(n.id)}</code></div><div>kind</div><div>${esc(n.kind)}</div>
        <div>group</div><div>${esc(n.group || '–')}</div><div>path</div><div>${n.path ? `<code>${esc(n.path)}</code>` : '–'}</div></div>`;
    if (n.pending) h += `<div class="warnbox">Pending: ${esc(n.pending)} (until Apply)${n.pending === 'add' || n.pending === 'remove' ? ' – drop the change in the overview to undo it.' : ''}</div>`;
    h += `<h3>Connections <span class="count">${ins.length + outs.length}</span></h3>`;
    h += outs.map((e) => conn(e, e.target, '→')).join('') + ins.map((e) => conn(e, e.source, '←')).join('') || '<div class="muted">none</div>';
    if (!locked) {
      h += `<h3>Change</h3>
        <label>Name</label><input id="fLabel" value="${esc(n.label)}" />
        <label>Kind</label><select id="fKind">${kindOptions(n.kind, Object.keys(KIND))}</select>
        <label>Group</label><input id="fGroup" value="${esc(n.group || '')}" />
        <label>Path</label><input id="fPath" value="${esc(n.path || '')}" />
        <label>Purpose</label><textarea id="fPurpose">${esc(n.purpose || '')}</textarea>
        <label>Note for the worker (optional)</label><textarea id="fNote" placeholder="Why / how it should change"></textarea>
        <div class="row"><button class="btn primary" id="pSave">Save change</button></div>
        <div class="row"><button class="btn" id="pConnect">Connect to…</button><button class="btn danger" id="pRemove">Remove node</button></div>`;
    }
    else if (n.pending === 'add') {
      h += `<div class="row"><button class="btn" id="pConnect">Connect to…</button></div>`;
    }
    return h;
  }

  function panelEdge(e) {
    const a = nodeById(e.source) || { label: e.source }, b = nodeById(e.target) || { label: e.target };
    return `<h3><a href="#" id="pBack" style="color:inherit">← Overview</a></h3>
      <div class="big-title">${esc(a.label)} → ${esc(b.label)}</div>
      <div class="kv"><div>kind</div><div>${esc(e.kind)}</div><div>label</div><div>${esc(e.label || '–')}</div><div>id</div><div><code>${esc(e.id)}</code></div></div>
      ${e.pending ? `<div class="warnbox">Pending: ${esc(e.pending)}</div>` : `
      <label>Kind</label><select id="eKind">${kindOptions(e.kind, Object.keys(EDGE))}</select>
      <label>Label</label><input id="eLabel" value="${esc(e.label || '')}" />
      <label>Note for the worker (optional)</label><textarea id="eNote"></textarea>
      <div class="row"><button class="btn primary" id="eSave">Save change</button><button class="btn danger" id="eRemove">Remove connection</button></div>`}`;
  }

  function panelAdd() {
    const groups = [...new Set(nodes().map((n) => n.group).filter(Boolean))];
    return `<h3><a href="#" id="pBack" style="color:inherit">← Overview</a></h3>
      <div class="big-title">New node</div>
      <div class="muted">It is added as a pending change; a worker builds it when you press Apply.</div>
      <label>Name</label><input id="aLabel" placeholder="e.g. Cache" />
      <label>Kind</label><select id="aKind">${kindOptions('module', Object.keys(KIND))}</select>
      <label>Group</label><input id="aGroup" list="groupList" placeholder="subsystem" /><datalist id="groupList">${groups.map((g) => `<option value="${esc(g)}">`).join('')}</datalist>
      <label>Path (optional)</label><input id="aPath" placeholder="src/cache.cpp" />
      <label>Purpose</label><textarea id="aPurpose" placeholder="One line: what it is for"></textarea>
      <label>Note for the worker (optional)</label><textarea id="aNote"></textarea>
      <div class="row"><button class="btn primary" id="aSave">Add node</button></div>`;
  }

  function renderPanel() {
    const P = $('panel');
    const keep = document.activeElement && P.contains(document.activeElement) && ['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement.tagName);
    if (keep) return; // do not wipe what the user is typing
    let h;
    if (S.form === 'add') h = panelAdd();
    else if (S.selected && S.selected.type === 'node' && nodeById(S.selected.id)) h = panelNode(nodeById(S.selected.id));
    else if (S.selected && S.selected.type === 'edge' && edgeById(S.selected.id)) h = panelEdge(edgeById(S.selected.id));
    else h = panelOverview();
    P.innerHTML = h;
  }

  // ── actions ────────────────────────────────────────────────────────────────
  async function act(fn, ok) {
    if (S.busy) return;
    S.busy = true;
    try {
      await fn();
      if (ok) toast(ok);
      await refresh(true);
    } catch (e) {
      toast(e.message, true);
    } finally {
      S.busy = false;
    }
  }

  const val = (id) => { const e = $(id); return e ? e.value.trim() : ''; };

  function edit(body, ok) {
    return act(() => NodeApi.post(api('/edits'), body), ok || 'Added to the pending changes');
  }

  $('panel').addEventListener('click', (ev) => {
    const t = ev.target;
    const id = t.id;
    const drop = t.closest('[data-drop]');
    const cut = t.closest('[data-cut]');
    const go = t.closest('[data-goto]');
    if (drop) return act(() => NodeApi.del(api('/edits/' + drop.dataset.drop)), 'Change dropped');
    if (cut) { ev.stopPropagation(); return edit({ op: 'remove_edge', target: cut.dataset.cut }); }
    if (go) { select('node', go.dataset.goto, true); return; }
    if (id === 'pBack') { ev.preventDefault(); S.form = null; select(null); return; }
    if (id === 'pPlan') return act(() => NodeApi.post(api('/plan'), {}), 'A worker writes the plan');
    if (id === 'pRevise') return act(() => NodeApi.post(api('/plan'), { feedback: val('pFeedback') }), 'A worker revises the plan');
    if (id === 'pApply') {
      const plan = S.data.plan || {};
      const msg = !plan.text ? 'Apply without reviewing a plan first?' : plan.outdated ? 'The plan is outdated. Apply anyway?' : 'Let a worker implement the pending changes?';
      if (confirm(msg)) act(() => NodeApi.post(api('/apply'), {}), 'A worker implements the changes');
      return;
    }
    if (id === 'pDiscard') { if (confirm('Drop every pending change?')) act(() => NodeApi.post(api('/discard'), {}), 'Pending changes dropped'); return; }
    const sel = S.selected;
    if (id === 'pSave' && sel) {
      const n = nodeById(sel.id);
      const ch = {};
      const f = { label: val('fLabel'), kind: val('fKind'), group: val('fGroup'), path: val('fPath'), purpose: val('fPurpose') };
      for (const k in f) if ((n[k] || '') !== f[k]) ch[k] = f[k];
      if (!Object.keys(ch).length) { toast('Nothing changed'); return; }
      return edit({ op: 'update_node', target: sel.id, node: ch, note: val('fNote') });
    }
    if (id === 'pRemove' && sel) {
      if (confirm('Remove this node (and its connections) from the architecture?')) edit({ op: 'remove_node', target: sel.id, note: val('fNote') });
      return;
    }
    if (id === 'pConnect' && sel) { startConnect(sel.id); return; }
    if (id === 'eSave' && sel) {
      const e = edgeById(sel.id); const ch = {};
      if (val('eKind') !== e.kind) ch.kind = val('eKind');
      if (val('eLabel') !== (e.label || '')) ch.label = val('eLabel');
      if (!Object.keys(ch).length) { toast('Nothing changed'); return; }
      return edit({ op: 'update_edge', target: sel.id, edge: ch, note: val('eNote') });
    }
    if (id === 'eRemove' && sel) return edit({ op: 'remove_edge', target: sel.id, note: val('eNote') });
    if (id === 'aSave') {
      if (!val('aLabel')) { toast('The node needs a name', true); return; }
      const r = $('stage').getBoundingClientRect();
      const c = toWorld(r.left + r.width / 2, r.top + r.height / 2);
      S.form = null;
      return edit({ op: 'add_node', note: val('aNote'), node: { label: val('aLabel'), kind: val('aKind'), group: val('aGroup'), path: val('aPath'), purpose: val('aPurpose'), x: Math.round(c.x), y: Math.round(c.y) } });
    }
  });

  function select(type, id, center) {
    S.selected = type ? { type, id } : null;
    S.form = null;
    draw();
    document.activeElement && document.activeElement.blur && document.activeElement.blur();
    renderPanel();
    if (center && type === 'node') {
      const p = S.pos.get(id); const r = $('stage').getBoundingClientRect();
      if (p) { S.view.x = r.width / 2 - p.x * S.view.k; S.view.y = r.height / 2 - p.y * S.view.k; applyView(); }
    }
  }

  function startConnect(id) {
    S.mode = 'connect';
    S.connectFrom = id;
    $('svg').classList.add('connecting');
    $('hint').textContent = `Click the node "${(nodeById(id) || {}).label || id}" should connect to — Esc cancels`;
    draw();
  }

  function stopConnect() {
    S.mode = null; S.connectFrom = null;
    $('svg').classList.remove('connecting');
    $('hint').textContent = '';
    $('ghost').setAttribute('d', '');
    draw();
  }

  function finishConnect(target) {
    const src = S.connectFrom;
    stopConnect();
    if (!src || src === target) return;
    const kind = (prompt('Kind of the connection: ' + Object.keys(EDGE).join(', '), 'calls') || '').trim().toLowerCase();
    if (!kind) return;
    if (!EDGE[kind]) { toast('Unknown kind: ' + kind, true); return; }
    const label = prompt('Label (optional, e.g. the function or the data):', '') || '';
    edit({ op: 'add_edge', edge: { source: src, target, kind, label } });
  }

  // ── pointer: pan, zoom, drag, select ─────────────────────────────────────
  const svg = $('svg');
  let down = null;

  svg.addEventListener('pointerdown', (ev) => {
    const g = ev.target.closest('[data-node]');
    const ed = ev.target.closest('[data-edge]');
    down = { x: ev.clientX, y: ev.clientY, vx: S.view.x, vy: S.view.y, node: g ? g.dataset.node : null, edge: ed ? ed.dataset.edge : null, moved: false };
    if (down.node && S.mode !== 'connect') {
      const p = S.pos.get(down.node);
      const w = toWorld(ev.clientX, ev.clientY);
      S.dragging = { id: down.node, dx: p.x - w.x, dy: p.y - w.y };
    }
    else if (!down.node && !down.edge) svg.classList.add('panning');
    svg.setPointerCapture(ev.pointerId);
  });

  svg.addEventListener('pointermove', (ev) => {
    if (S.mode === 'connect' && S.connectFrom) {
      const a = S.pos.get(S.connectFrom); const w = toWorld(ev.clientX, ev.clientY);
      if (a) $('ghost').setAttribute('d', `M${a.x},${a.y} L${w.x},${w.y}`);
    }
    if (!down) {
      const g = ev.target.closest('[data-node]');
      const h = g ? g.dataset.node : null;
      if (h !== S.hover) { S.hover = h; highlight(); }
      return;
    }
    const dx = ev.clientX - down.x, dy = ev.clientY - down.y;
    if (Math.abs(dx) + Math.abs(dy) > 3) down.moved = true;
    if (S.dragging && down.moved) {
      const w = toWorld(ev.clientX, ev.clientY);
      S.pos.set(S.dragging.id, { x: Math.round(w.x + S.dragging.dx), y: Math.round(w.y + S.dragging.dy) });
      drawGroups(); drawEdges(); drawNodes(); highlight();
    }
    else if (!down.node && !down.edge) {
      S.view.x = down.vx + dx; S.view.y = down.vy + dy; applyView();
    }
  });

  svg.addEventListener('pointerup', () => {
    svg.classList.remove('panning');
    const d = down; down = null;
    const drag = S.dragging; S.dragging = null;
    if (!d) return;
    if (drag && d.moved) { savePositions([drag.id]); return; }
    if (d.moved) return;
    if (S.mode === 'connect') { if (d.node) finishConnect(d.node); else stopConnect(); return; }
    if (d.node) select('node', d.node);
    else if (d.edge) select('edge', d.edge);
    else if (S.selected) select(null);
  });

  svg.addEventListener('dblclick', (ev) => {
    const g = ev.target.closest('[data-node]');
    if (g) select('node', g.dataset.node, true);
  });

  svg.addEventListener('wheel', (ev) => {
    ev.preventDefault();
    const r = svg.getBoundingClientRect();
    const mx = ev.clientX - r.left, my = ev.clientY - r.top;
    const k = Math.max(0.15, Math.min(3, S.view.k * Math.exp(-ev.deltaY * 0.0015)));
    S.view.x = mx - (mx - S.view.x) * (k / S.view.k);
    S.view.y = my - (my - S.view.y) * (k / S.view.k);
    S.view.k = k;
    applyView();
  }, { passive: false });

  document.addEventListener('keydown', (ev) => {
    if (ev.key === 'Escape') { if (S.mode) stopConnect(); else if (S.selected || S.form) { S.form = null; select(null); } }
  });

  $('search').addEventListener('input', () => {
    highlight();
    const q = $('search').value.trim().toLowerCase();
    if (!q) return;
    const n = nodes().find((x) => (x.label + ' ' + x.id).toLowerCase().includes(q));
    if (n) { const p = S.pos.get(n.id); const r = $('stage').getBoundingClientRect(); if (p) { S.view.x = r.width / 2 - p.x * S.view.k; S.view.y = r.height / 2 - p.y * S.view.k; applyView(); } }
  });
  $('search').addEventListener('keydown', (ev) => {
    if (ev.key !== 'Enter') return;
    const q = $('search').value.trim().toLowerCase();
    const n = nodes().find((x) => (x.label + ' ' + x.id).toLowerCase().includes(q));
    if (n) select('node', n.id, true);
  });

  $('btnFit').onclick = fit;
  $('btnLayout').onclick = () => { const ids = layout(true); draw(); fit(); savePositions(ids); };
  $('btnRefresh').onclick = () => refresh(true);
  $('btnAdd').onclick = () => { S.form = 'add'; S.selected = null; draw(); renderPanel(); setTimeout(() => $('aLabel') && $('aLabel').focus(), 0); };
  const analyze = () => {
    const first = !nodes().length;
    if (first || confirm('Let a worker analyze the codebase again? Nodes keep their positions, pending changes stay.')) {
      act(() => NodeApi.post(api('/analyze'), {}), 'A worker analyzes the codebase');
    }
  };
  $('btnAnalyze').onclick = analyze;
  $('btnAnalyzeEmpty').onclick = analyze;
  window.addEventListener('resize', () => { if (!S.fitted) fit(); });

  // ── data ───────────────────────────────────────────────────────────────────
  let refreshTimer = null;
  function scheduleJobRefresh() {
    clearTimeout(refreshTimer);
    if (!jobOpen(S.data && S.data.job)) return;
    refreshTimer = setTimeout(() => refresh(false), 10000);
  }

  async function refresh(force) {
    let d;
    try {
      d = await NodeApi.get(api());
    } catch (e) {
      $('summary').textContent = e.status === 401 ? 'The node needs its API token.' : 'The node does not answer: ' + e.message;
      return;
    }
    // an empty list arrives as {} (ShizoScript json): lists are lists here
    const arr = (x) => (Array.isArray(x) ? x : x && typeof x === 'object' ? Object.values(x) : []);
    d.nodes = arr(d.nodes); d.edges = arr(d.edges); d.pending = arr(d.pending); d.history = arr(d.history);
    d.plan = d.plan || {}; d.job = d.job || {};
    S.data = d;
    $('project').textContent = d.project ? d.project + ' · architecture' : 'Architecture';
    $('summary').textContent = d.summary || 'The map of the codebase this node works on.';
    $('summary').title = d.summary || '';
    $('emptyFile').textContent = d.file || '.megimind/architecture/architecture.json';
    $('empty').classList.toggle('hidden', nodes().length > 0);
    renderJob();

    // positions: the stored ones win unless the user is dragging
    nodes().forEach((n) => {
      if (S.dragging && S.dragging.id === n.id) return;
      if (typeof n.x === 'number' && typeof n.y === 'number' && !unsaved.has(n.id)) S.pos.set(n.id, { x: n.x, y: n.y });
    });
    const ids = new Set(nodes().map((n) => n.id));
    [...S.pos.keys()].forEach((k) => { if (!ids.has(k)) S.pos.delete(k); });
    const placed = layout(false);
    if (placed.length) savePositions(placed);

    const sig = JSON.stringify([d.nodes, d.edges, d.pending, d.plan, d.job, d.history && d.history.length]);
    if (force || sig !== S.sig) {
      S.sig = sig;
      if (S.selected && !(S.selected.type === 'node' ? nodeById(S.selected.id) : edgeById(S.selected.id))) S.selected = null;
      drawLegend();
      if (!S.dragging) draw();
      renderPanel();
      if (!S.fitted && nodes().length) { fit(); S.fitted = true; }
    }
    scheduleJobRefresh();
  }

  defs();
  applyView();
  refresh(true);
})();
