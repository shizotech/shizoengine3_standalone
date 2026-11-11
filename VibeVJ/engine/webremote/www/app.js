// The web remote of VibeVJ (#359): pairing, the transport, the clips, the pages of controls (with an edit mode) and the
// live preview. Talks to engine/webremote/webremote.shio: POST /api/pair, GET /api/state, GET /api/events (Server-Sent
// Events), POST /api/set, POST /api/action, GET /api/controls, POST /api/edit, GET /api/preview. Values from VibeVJ
// move the faders, except the ones a finger holds.
'use strict';
(function () {
	const $ = (id) => document.getElementById(id);
	// VibeVJ writes an empty list as {} (its JSON does not know the difference)
	const arr = (x) => (Array.isArray(x) ? x : []);
	const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
	const now = () => Date.now();
	const HOLD_MS = 600; // after a finger lets go, values from VibeVJ wait this long (no jumps back)
	const KIND_NAMES = { fader: 'Fader', hfader: 'Across', number: '− +', xy: 'XY', button: 'Button', choice: 'Choice' };
	const SIZE_NAMES = ['S', 'M', 'L'];
	const PICK_MAX = 80; // rows the search shows

	const store = {
		get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
		set(k, v) { try { if (v === null) localStorage.removeItem(k); else localStorage.setItem(k, v); } catch (e) { } },
	};

	let token = store.get('vibevj-remote-token');
	let layout = null;
	let layoutText = '';
	let values = {};
	let viewId = store.get('vibevj-remote-view');
	let tab = store.get('vibevj-remote-tab') || 'clips'; // 'clips' or the id of a page
	let events = null;
	let pending = {};
	let flushTimer = null;
	let sending = false;
	let editing = false;
	let sheetId = null;    // the control the sheet shows
	let pickMode = 'add';  // 'add' controls, or 'y' (the Y fader of an XY pad)
	let catalog = null;    // the controls of the project (api/controls)
	let catalogAt = 0;
	const touched = {};   // id -> time a finger last moved it
	const active = {};    // id -> a finger is on it now
	let widgets = {};     // id -> {set(value)}
	let cells = [];       // [row][col] -> element (the Clipview shown)

	// ---------------------------------------------------------------- talking to VibeVJ

	function toast(text) {
		const t = $('toast');
		t.textContent = text;
		t.classList.add('on');
		clearTimeout(toast.timer);
		toast.timer = setTimeout(() => t.classList.remove('on'), 2200);
	}

	async function api(path, body) {
		const opts = { method: body ? 'POST' : 'GET', headers: {}, cache: 'no-store' };
		if (token) opts.headers['X-Remote-Token'] = token;
		if (body) {
			opts.headers['Content-Type'] = 'application/json';
			opts.body = JSON.stringify(body);
		}
		let res;
		try {
			res = await fetch(path, opts);
		} catch (e) {
			setLink(false);
			return null;
		}
		if (res.status === 401 && path !== 'api/pair') {
			unpaired('Paired again? Enter the new PIN.');
			return null;
		}
		let data = null;
		if (res.status !== 204) {
			try { data = await res.json(); } catch (e) { }
		}
		if (res.status === 429) toast((data && data.error) || 'Too fast');
		else if (!res.ok && data && data.error && path !== 'api/pair' && !path.startsWith('api/preview')) toast(data.error);
		return { status: res.status, data };
	}

	function action(a, extra) {
		return api('api/action', Object.assign({ a }, extra || {}));
	}

	// Values go out together, at most every 30 ms
	function send(id, v) {
		pending[id] = v;
		touched[id] = now();
		if (!flushTimer) flushTimer = setTimeout(flush, 30);
	}

	async function flush() {
		flushTimer = null;
		if (sending) {
			flushTimer = setTimeout(flush, 30);
			return;
		}
		const batch = pending;
		pending = {};
		if (!Object.keys(batch).length) return;
		sending = true;
		await api('api/set', { v: batch });
		sending = false;
		if (Object.keys(pending).length && !flushTimer) flushTimer = setTimeout(flush, 30);
	}

	function setLink(ok) {
		$('link').classList.toggle('ok', !!ok);
	}

	function listen() {
		if (events) events.close();
		events = new EventSource('api/events?t=' + encodeURIComponent(token));
		events.addEventListener('open', () => setLink(true));
		events.addEventListener('layout', (e) => applyLayout(e.data));
		events.addEventListener('values', (e) => {
			try { applyValues(JSON.parse(e.data)); } catch (err) { }
		});
		events.addEventListener('error', () => {
			setLink(false);
			// Closed for good (not paired any more, the remote was switched off): ask once, then again later
			if (events.readyState === EventSource.CLOSED) {
				events = null;
				setTimeout(reconnect, 2000);
			}
		});
	}

	async function reconnect() {
		if (!token || events) return;
		const r = await api('api/state');
		if (!token) return;
		if (r && r.status === 200 && r.data) {
			applyLayout(JSON.stringify(r.data.layout));
			applyValues(r.data.values);
			listen();
		} else {
			setTimeout(reconnect, 3000);
		}
	}

	// The layout at once (after an edit), not with the next event
	async function refreshState() {
		const r = await api('api/state');
		if (r && r.status === 200 && r.data) {
			applyLayout(JSON.stringify(r.data.layout));
			applyValues(r.data.values);
		}
	}

	// ---------------------------------------------------------------- pairing

	function unpaired(msg) {
		token = null;
		store.set('vibevj-remote-token', null);
		if (events) { events.close(); events = null; }
		$('app').hidden = true;
		$('pair').hidden = false;
		$('pair-msg').textContent = msg || '';
		$('pin').focus();
	}

	async function pair(pin) {
		$('pair-msg').textContent = '';
		const r = await api('api/pair', { pin: String(pin).trim() });
		if (!r) {
			$('pair-msg').textContent = 'VibeVJ does not answer. Is the web remote on?';
			return false;
		}
		if (r.status !== 200 || !r.data || !r.data.token) {
			$('pair-msg').textContent = (r.data && r.data.error) || 'Could not pair.';
			return false;
		}
		token = r.data.token;
		store.set('vibevj-remote-token', token);
		start();
		return true;
	}

	$('pair-form').addEventListener('submit', (e) => {
		e.preventDefault();
		pair($('pin').value);
	});

	async function start() {
		$('pair').hidden = true;
		$('app').hidden = false;
		showTab(tab);
		await reconnect();
	}

	// ---------------------------------------------------------------- widgets

	// A fader: grab it anywhere and slide (relative, so a touch never makes the value jump). Each finger has its own
	// fader: several move at once. across: a fader that slides left and right
	function fader(id, min, max, whole, onChange, across) {
		const el = document.createElement('div');
		el.className = across ? 'fader across' : 'fader';
		const fill = document.createElement('div');
		fill.className = 'fill';
		const cap = document.createElement('div');
		cap.className = 'cap';
		el.append(fill, cap);
		let norm = 0;
		let pointer = null;
		let start = 0;
		let startNorm = 0;
		const span = max - min || 1;
		const draw = () => {
			if (across) {
				fill.style.width = (norm * 100) + '%';
				cap.style.left = (norm * 100) + '%';
			} else {
				fill.style.height = (norm * 100) + '%';
				cap.style.top = ((1 - norm) * 100) + '%';
			}
		};
		el.addEventListener('pointerdown', (e) => {
			if (pointer !== null || editing) return;
			pointer = e.pointerId;
			el.setPointerCapture(e.pointerId);
			start = across ? e.clientX : e.clientY;
			startNorm = norm;
			active[id] = true;
			el.classList.add('held');
			e.preventDefault();
		});
		el.addEventListener('pointermove', (e) => {
			if (e.pointerId !== pointer) return;
			const size = (across ? el.clientWidth : el.clientHeight) || 1;
			const moved = across ? e.clientX - start : start - e.clientY;
			norm = clamp(startNorm + moved / size, 0, 1);
			draw();
			let v = min + norm * span;
			if (whole) v = Math.round(v);
			onChange(v);
		});
		const end = (e) => {
			if (e.pointerId !== pointer) return;
			pointer = null;
			active[id] = false;
			touched[id] = now();
			el.classList.remove('held');
		};
		el.addEventListener('pointerup', end);
		el.addEventListener('pointercancel', end);
		return {
			el,
			set(v) {
				norm = clamp((Number(v) - min) / span, 0, 1);
				draw();
			},
		};
	}

	function fmt(v, whole) {
		if (typeof v !== 'number') return '';
		if (whole) return String(Math.round(v));
		const a = Math.abs(v);
		return a >= 100 ? v.toFixed(0) : a >= 10 ? v.toFixed(1) : v.toFixed(2);
	}

	function heldNow(id) {
		return active[id] || (touched[id] && now() - touched[id] < HOLD_MS);
	}

	function box(item, cls) {
		const el = document.createElement('div');
		el.className = 'ctl' + (cls ? ' ' + cls : '');
		const lbl = document.createElement('div');
		lbl.className = 'lbl';
		lbl.textContent = item.label;
		el.append(lbl);
		return el;
	}

	function pageControl(item) {
		const id = item.id;
		if (!item.ok) {
			const el = box(item, 'gone');
			const v = document.createElement('div');
			v.className = 'val';
			v.textContent = 'not in this project';
			el.append(v);
			return { el };
		}
		if (item.kind === 'fader' || item.kind === 'hfader') {
			const across = item.kind === 'hfader';
			const el = box(item, across ? 'across-box' : '');
			const val = document.createElement('div');
			val.className = 'val';
			const f = fader(id, item.min, item.max, item.whole, (v) => {
				val.textContent = fmt(v, item.whole);
				send(id, v);
			}, across);
			el.append(f.el, val);
			return { el, set(v) { f.set(v); val.textContent = fmt(v, item.whole); } };
		}
		if (item.kind === 'button') {
			const el = box(item);
			const b = document.createElement('button');
			b.className = 'btn pushbtn';
			b.textContent = item.label;
			el.firstChild.remove();
			el.append(b);
			let on = false;
			if (item.toggle) {
				b.addEventListener('click', () => {
					if (editing) return;
					on = !on;
					b.classList.toggle('on', on);
					send(id, on ? 1 : 0);
				});
			} else {
				let pointer = null;
				b.addEventListener('pointerdown', (e) => {
					if (editing) return;
					pointer = e.pointerId;
					b.setPointerCapture(e.pointerId);
					active[id] = true;
					b.classList.add('on', 'down');
					send(id, 1);
				});
				const up = (e) => {
					if (e.pointerId !== pointer) return;
					pointer = null;
					active[id] = false;
					b.classList.remove('on', 'down');
					send(id, 0);
				};
				b.addEventListener('pointerup', up);
				b.addEventListener('pointercancel', up);
			}
			return { el, set(v) { on = Number(v) !== 0; b.classList.toggle('on', on); } };
		}
		if (item.kind === 'choice') {
			const el = box(item);
			const seg = document.createElement('div');
			seg.className = 'seg';
			const opts = arr(item.opts);
			const btns = opts.map((name, i) => {
				const b = document.createElement('button');
				b.className = 'btn';
				b.textContent = name;
				b.addEventListener('click', () => {
					if (editing) return;
					btns.forEach((x, k) => x.classList.toggle('on', k === i));
					send(id, i);
				});
				seg.append(b);
				return b;
			});
			el.append(seg);
			return { el, set(v) { btns.forEach((x, k) => x.classList.toggle('on', k === Number(v))); } };
		}
		if (item.kind === 'xy') {
			const el = box(item);
			const pad = document.createElement('div');
			pad.className = 'xy';
			const pt = document.createElement('div');
			pt.className = 'pt';
			pad.append(pt);
			const ranges = arr(item.ranges);
			const rx = ranges[0] || [0, 1];
			const ry = ranges[1] || [0, 1];
			let pointer = null;
			const place = (nx, ny) => {
				pt.style.left = (nx * 100) + '%';
				pt.style.top = ((1 - ny) * 100) + '%';
			};
			const move = (e) => {
				const r = pad.getBoundingClientRect();
				const nx = clamp((e.clientX - r.left) / r.width, 0, 1);
				const ny = clamp(1 - (e.clientY - r.top) / r.height, 0, 1);
				place(nx, ny);
				send(id, [rx[0] + nx * (rx[1] - rx[0]), ry[0] + ny * (ry[1] - ry[0])]);
			};
			pad.addEventListener('pointerdown', (e) => {
				if (pointer !== null || editing) return;
				pointer = e.pointerId;
				pad.setPointerCapture(e.pointerId);
				active[id] = true;
				pad.classList.add('held');
				move(e);
				e.preventDefault();
			});
			pad.addEventListener('pointermove', (e) => { if (e.pointerId === pointer) move(e); });
			const end = (e) => {
				if (e.pointerId !== pointer) return;
				pointer = null;
				active[id] = false;
				touched[id] = now();
				pad.classList.remove('held');
			};
			pad.addEventListener('pointerup', end);
			pad.addEventListener('pointercancel', end);
			el.append(pad);
			if (item.ylabel) {
				const yl = document.createElement('div');
				yl.className = 'val';
				yl.textContent = '↕ ' + item.ylabel;
				el.append(yl);
			}
			place(0.5, 0.5);
			return {
				el,
				set(v) {
					const a = arr(v);
					if (a.length < 2) return;
					place(clamp((a[0] - rx[0]) / ((rx[1] - rx[0]) || 1), 0, 1), clamp((a[1] - ry[0]) / ((ry[1] - ry[0]) || 1), 0, 1));
				},
			};
		}
		// a number: - and +
		const el = box(item);
		const row = document.createElement('div');
		row.className = 'num';
		const minus = document.createElement('button');
		minus.className = 'btn';
		minus.textContent = '−';
		const plus = document.createElement('button');
		plus.className = 'btn';
		plus.textContent = '+';
		const val = document.createElement('div');
		val.className = 'val';
		row.append(minus, val, plus);
		el.append(row);
		let cur = 0;
		const bump = (d) => {
			if (editing) return;
			const step = item.whole ? 1 : (item.max - item.min <= 2 ? 0.05 : Math.abs(cur) >= 10 ? 1 : 0.1);
			cur = clamp(cur + d * step, item.min, item.max);
			val.textContent = fmt(cur, item.whole);
			send(id, cur);
		};
		minus.addEventListener('click', () => bump(-1));
		plus.addEventListener('click', () => bump(1));
		return { el, set(v) { cur = Number(v); val.textContent = fmt(cur, item.whole); } };
	}

	// ---------------------------------------------------------------- layout and values

	const ICON_PLAY = '<svg viewBox="0 0 24 24"><path d="M7 4.5v15l13-7.5z"/></svg>';
	const ICON_STOP = '<svg viewBox="0 0 24 24"><path d="M6 6h12v12H6z"/></svg>';

	function currentView() {
		const views = arr(layout && layout.clipviews);
		return views.find((v) => v.id === viewId) || views[0] || null;
	}

	function pages() {
		return arr(layout && layout.pages);
	}

	function currentPage() {
		const list = pages();
		return list.find((p) => p.id === tab) || null;
	}

	function itemOf(id) {
		for (const p of pages()) {
			const it = arr(p.items).find((x) => x.id === id);
			if (it) return it;
		}
		return null;
	}

	function renderClips() {
		const views = arr(layout.clipviews);
		const chips = $('views');
		chips.textContent = '';
		const view = currentView();
		$('no-clips').hidden = !!view;
		$('grid').textContent = '';
		$('masters').textContent = '';
		cells = [];
		if (views.length > 1) {
			views.forEach((v) => {
				const c = document.createElement('button');
				c.className = 'chip' + (view && v.id === view.id ? ' on' : '');
				c.textContent = v.name;
				c.addEventListener('click', () => {
					viewId = v.id;
					store.set('vibevj-remote-view', viewId);
					renderClips();
					applyValues(values);
				});
				chips.append(c);
			});
		}
		if (!view) return;
		const grid = $('grid');
		const cols = view.cols || 0;
		grid.style.gridTemplateColumns = '112px repeat(' + cols + ', minmax(88px, 1fr))';
		const corner = document.createElement('div');
		corner.className = 'gh corner';
		grid.append(corner);
		for (let c = 0; c < cols; c++) {
			const h = document.createElement('button');
			h.className = 'btn gh';
			h.innerHTML = ICON_PLAY;
			h.append(String(c + 1));
			h.setAttribute('aria-label', 'Launch column ' + (c + 1));
			h.addEventListener('click', () => action('column', { view: view.id, col: c }));
			grid.append(h);
		}
		arr(view.rows).forEach((row, r) => {
			const lh = document.createElement('div');
			lh.className = 'lh';
			const ln = document.createElement('span');
			ln.className = 'ln';
			ln.textContent = row.name;
			const stop = document.createElement('button');
			stop.className = 'btn';
			stop.innerHTML = ICON_STOP;
			stop.setAttribute('aria-label', 'Stop ' + row.name);
			stop.addEventListener('click', () => action('stop_layer', { view: view.id, row: r }));
			lh.append(ln, stop);
			grid.append(lh);
			cells[r] = [];
			arr(row.cells).forEach((name, c) => {
				const cell = document.createElement('button');
				cell.className = 'cell' + (name ? '' : ' empty');
				cell.textContent = name || '·';
				if (name) {
					cell.addEventListener('click', () => {
						// at once on the phone too, VibeVJ confirms with the next values
						cells[r].forEach((x) => x.classList.remove('live'));
						cell.classList.add('live');
						action('clip', { view: view.id, row: r, col: c, down: 1 });
					});
				} else {
					cell.disabled = true;
				}
				cells[r][c] = cell;
				grid.append(cell);
			});
			// the master of the layer
			const id = 'm:' + view.id + ':' + r;
			const m = box({ label: row.name });
			const val = document.createElement('div');
			val.className = 'val';
			const f = fader(id, 0, 1, false, (v) => {
				val.textContent = Math.round(v * 100) + '%';
				send(id, v);
			});
			m.append(f.el, val);
			$('masters').append(m);
			widgets[id] = { set(v) { f.set(v); val.textContent = Math.round(Number(v) * 100) + '%'; } };
		});
	}

	function renderTabs() {
		const nav = $('tabs');
		nav.textContent = '';
		const mk = (key, name) => {
			const t = document.createElement('button');
			t.className = 'tab' + (tab === key ? ' on' : '');
			t.dataset.tab = key;
			t.textContent = name;
			t.addEventListener('click', () => showTab(key));
			nav.append(t);
			return t;
		};
		mk('clips', 'Clips');
		pages().forEach((p) => mk(p.id, p.name));
		if (editing) {
			const add = mk('+', '+ Page');
			add.classList.add('add');
		}
	}

	function renderPage() {
		const page = $('page');
		page.textContent = '';
		const p = currentPage();
		const items = p ? arr(p.items) : [];
		$('no-page').hidden = items.length > 0 || editing;
		items.forEach((item, i) => {
			const w = pageControl(item);
			w.el.classList.add('s' + clamp(Number(item.size) || 1, 1, 3));
			w.el.dataset.id = item.id;
			if (editing) w.el.append(editOverlay(item, i, items.length));
			page.append(w.el);
			if (w.set) widgets[item.id] = w;
		});
		if (editing && p) {
			const add = document.createElement('button');
			add.className = 'ctl add-tile s1';
			add.id = 'add-ctl';
			add.textContent = '+ Add';
			add.addEventListener('click', () => openPicker('add'));
			page.append(add);
		}
		// the tools of the page
		const canEdit = !!(layout && layout.edit);
		$('edit-btn').hidden = !canEdit || !p;
		$('edit-btn').textContent = editing ? 'Done' : 'Edit';
		$('edit-btn').classList.toggle('accent', editing);
		$('page-edit-tools').hidden = !editing || !p;
		if (p && document.activeElement !== $('page-name')) $('page-name').value = p.name;
		$('page-del').disabled = pages().length <= 1;
	}

	// Edit mode: the control does not play, a tap opens its sheet, ◀ ▶ move it
	function editOverlay(item, index, count) {
		const ov = document.createElement('div');
		ov.className = 'edit-ov';
		const left = document.createElement('button');
		left.className = 'btn mini';
		left.textContent = '◀';
		left.disabled = index === 0;
		left.setAttribute('aria-label', 'Earlier');
		left.addEventListener('click', (e) => { e.stopPropagation(); edit({ op: 'move', id: item.id, step: -1 }); });
		const mid = document.createElement('span');
		mid.className = 'ov-name';
		mid.textContent = (KIND_NAMES[item.kind] || item.kind) + ' · ' + SIZE_NAMES[clamp(Number(item.size) || 1, 1, 3) - 1];
		const right = document.createElement('button');
		right.className = 'btn mini';
		right.textContent = '▶';
		right.disabled = index === count - 1;
		right.setAttribute('aria-label', 'Later');
		right.addEventListener('click', (e) => { e.stopPropagation(); edit({ op: 'move', id: item.id, step: 1 }); });
		const btns = document.createElement('div');
		btns.className = 'ov-btns';
		btns.append(left, right);
		ov.append(mid, btns);
		ov.addEventListener('click', () => openSheet(item.id));
		return ov;
	}

	function applyLayout(text) {
		if (text === layoutText) return;
		let next;
		try { next = JSON.parse(text); } catch (e) { return; }
		layoutText = text;
		layout = next;
		widgets = {};
		if (tab !== 'clips' && !currentPage()) tab = pages().length ? pages()[0].id : 'clips';
		renderTabs();
		renderClips();
		renderPage();
		showTab(tab, true);
		renderPreviewSources();
		if (sheetId) fillSheet();
		applyValues(values);
	}

	function applyValues(v) {
		if (!v) return;
		values = v;
		$('play').classList.toggle('on', !!v.play);
		if (typeof v.bpm === 'number') $('bpm').textContent = v.bpm.toFixed(v.bpm % 1 ? 1 : 0);
		$('blackout').classList.toggle('on', !!v.blackout);
		$('show').hidden = !v.show;
		const dots = $('beat').children;
		const beat = typeof v.beat === 'number' ? ((v.beat % 4) + 4) % 4 : -1;
		for (let i = 0; i < dots.length; i++) {
			dots[i].classList.toggle('on', i === beat && !!v.play);
			dots[i].classList.toggle('one', i === 0);
		}
		// show mode: no editing
		if (v.show && editing) setEditing(false, 'Show mode in VibeVJ: the pages cannot be changed now.');
		const vals = v.v || {};
		for (const id in vals) {
			const w = widgets[id];
			if (w && w.set && !heldNow(id) && !(id in pending)) w.set(vals[id]);
		}
		const view = currentView();
		const clips = view && v.clips ? v.clips[view.id] : null;
		if (clips) {
			arr(clips.live).forEach((col, r) => {
				(cells[r] || []).forEach((cell, c) => cell.classList.toggle('live', c === col));
			});
			arr(clips.master).forEach((m, r) => {
				const id = 'm:' + view.id + ':' + r;
				const w = widgets[id];
				if (w && !heldNow(id) && !(id in pending)) w.set(m);
			});
		}
	}

	// ---------------------------------------------------------------- the bar and the tabs

	function showTab(name, quiet) {
		if (name === '+') {
			edit({ op: 'page_add', name: '' }).then((r) => {
				if (r && r.page) {
					tab = r.page;
					store.set('vibevj-remote-tab', tab);
					refreshState();
				}
			});
			return;
		}
		const isPage = name !== 'clips' && pages().some((p) => p.id === name);
		tab = isPage ? name : (layout ? 'clips' : name);
		store.set('vibevj-remote-tab', tab);
		document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('on', t.dataset.tab === tab));
		$('tab-clips').hidden = tab !== 'clips';
		$('tab-page').hidden = tab === 'clips';
		if (!quiet && layout) {
			widgets = {};
			renderClips();
			renderPage();
			applyValues(values);
		}
	}

	$('play').addEventListener('click', () => {
		const on = !$('play').classList.contains('on');
		$('play').classList.toggle('on', on);
		action('play', { v: on ? 1 : 0 });
	});
	$('stop').addEventListener('click', () => {
		$('play').classList.remove('on');
		action('stop');
	});
	// Tap on the press, not on the release: the moment counts
	$('tap').addEventListener('pointerdown', (e) => {
		e.preventDefault();
		$('tap').classList.add('down');
		action('tap');
	});
	['pointerup', 'pointercancel'].forEach((n) => $('tap').addEventListener(n, () => $('tap').classList.remove('down')));
	const nudge = (d) => {
		const bpm = values && typeof values.bpm === 'number' ? values.bpm : 120;
		const next = clamp(Math.round(bpm) + d, 20, 400);
		$('bpm').textContent = String(next);
		action('bpm', { v: next });
	};
	$('bpm-down').addEventListener('click', () => nudge(-1));
	$('bpm-up').addEventListener('click', () => nudge(1));
	$('blackout').addEventListener('click', () => {
		const on = !$('blackout').classList.contains('on');
		$('blackout').classList.toggle('on', on);
		action('blackout', { v: on ? 1 : 0 });
	});

	// ---------------------------------------------------------------- edit mode

	async function edit(body) {
		const r = await api('api/edit', body);
		if (!r || r.status !== 200 || !r.data) return null;
		refreshState();
		return r.data.result || true;
	}

	function setEditing(on, why) {
		editing = !!on;
		document.body.classList.toggle('editing', editing);
		if (!editing) {
			closeSheet();
			closePicker();
		}
		if (why) toast(why);
		if (layout) {
			widgets = {};
			renderTabs();
			renderPage();
			applyValues(values);
		}
	}

	$('edit-btn').addEventListener('click', () => {
		if (!editing && values && values.show) {
			toast('Show mode in VibeVJ: the pages cannot be changed now.');
			return;
		}
		setEditing(!editing);
	});
	$('page-name').addEventListener('change', () => {
		const p = currentPage();
		const name = $('page-name').value.trim();
		if (p && name && name !== p.name) edit({ op: 'page_rename', page: p.id, name });
	});
	$('page-left').addEventListener('click', () => { const p = currentPage(); if (p) edit({ op: 'page_move', page: p.id, step: -1 }); });
	$('page-right').addEventListener('click', () => { const p = currentPage(); if (p) edit({ op: 'page_move', page: p.id, step: 1 }); });
	$('page-del').addEventListener('click', () => {
		const p = currentPage();
		if (!p) return;
		if (!window.confirm('Remove the page "' + p.name + '"? The controls themselves stay in VibeVJ.')) return;
		edit({ op: 'page_remove', page: p.id });
	});

	// The sheet of one control: name, how it shows, its width, its place, remove
	function openSheet(id) {
		sheetId = id;
		$('ctl-sheet').hidden = false;
		fillSheet();
	}

	function closeSheet() {
		sheetId = null;
		$('ctl-sheet').hidden = true;
	}

	function fillSheet() {
		const item = itemOf(sheetId);
		if (!item) { closeSheet(); return; }
		$('cs-title').textContent = item.label;
		if (document.activeElement !== $('cs-name')) $('cs-name').value = item.label;
		const kinds = $('cs-kinds');
		kinds.textContent = '';
		arr(item.kinds).forEach((k) => {
			const b = document.createElement('button');
			b.className = 'btn' + (k === item.kind ? ' on' : '');
			b.textContent = KIND_NAMES[k] || k;
			b.dataset.kind = k;
			b.addEventListener('click', () => {
				// an XY pad of a fader needs a second fader for Y
				if (k === 'xy' && item.kind !== 'xy' && !(item.ranges && item.ranges.length >= 2)) {
					openPicker('y');
					return;
				}
				edit({ op: 'set', id: item.id, kind: k });
			});
			kinds.append(b);
		});
		const pair = item.kind === 'xy' && item.ylabel;
		$('cs-y').hidden = !pair;
		$('cs-y-name').textContent = item.ylabel || '';
		const sizes = $('cs-sizes');
		sizes.textContent = '';
		SIZE_NAMES.forEach((n, i) => {
			const b = document.createElement('button');
			b.className = 'btn' + (Number(item.size) === i + 1 ? ' on' : '');
			b.textContent = n;
			b.addEventListener('click', () => edit({ op: 'set', id: item.id, size: i + 1 }));
			sizes.append(b);
		});
	}

	$('cs-close').addEventListener('click', closeSheet);
	$('cs-name').addEventListener('change', () => {
		const name = $('cs-name').value.trim();
		if (sheetId && name) edit({ op: 'set', id: sheetId, label: name });
	});
	$('cs-left').addEventListener('click', () => { if (sheetId) edit({ op: 'move', id: sheetId, step: -1 }); });
	$('cs-right').addEventListener('click', () => { if (sheetId) edit({ op: 'move', id: sheetId, step: 1 }); });
	$('cs-del').addEventListener('click', () => {
		if (!sheetId) return;
		const id = sheetId;
		closeSheet();
		edit({ op: 'remove', id });
	});
	$('cs-y-pick').addEventListener('click', () => openPicker('y'));
	$('ctl-sheet').addEventListener('click', (e) => { if (e.target === $('ctl-sheet')) closeSheet(); });

	// The controls of the project: search and add (or pick the Y fader of an XY pad)
	async function openPicker(mode) {
		pickMode = mode;
		$('pk-title').textContent = mode === 'y' ? 'The fader for Y' : 'Add controls';
		$('picker').hidden = false;
		$('pk-search').value = '';
		$('pk-list').textContent = '';
		$('pk-note').textContent = 'Loading…';
		if (!catalog || now() - catalogAt > 20000) {
			const r = await api('api/controls');
			if (!r || r.status !== 200 || !r.data) {
				$('pk-note').textContent = (r && r.data && r.data.error) || 'VibeVJ does not answer.';
				return;
			}
			catalog = arr(r.data.controls);
			catalogAt = now();
			catalog.more = !!r.data.more;
		}
		fillPicker();
		$('pk-search').focus();
	}

	function closePicker() {
		$('picker').hidden = true;
	}

	function fillPicker() {
		const list = $('pk-list');
		list.textContent = '';
		const words = $('pk-search').value.trim().toLowerCase().split(/\s+/).filter((w) => w);
		const p = currentPage();
		const sheetItem = itemOf(sheetId);
		let shown = 0;
		let found = 0;
		for (const c of arr(catalog)) {
			if (pickMode === 'y' && c.k !== 'fader') continue;
			const text = (c.l + ' ' + c.g + ' ' + c.lp).toLowerCase();
			if (!words.every((w) => text.includes(w))) continue;
			found++;
			if (shown >= PICK_MAX) continue;
			shown++;
			const row = document.createElement('button');
			row.className = 'pick';
			const name = document.createElement('b');
			name.textContent = c.l;
			const where = document.createElement('small');
			where.textContent = c.g + ' · ' + c.lp;
			const kind = document.createElement('span');
			kind.className = 'kind';
			kind.textContent = KIND_NAMES[c.k] || c.k;
			row.append(name, kind, where);
			row.addEventListener('click', async () => {
				if (pickMode === 'y') {
					if (!sheetItem) return;
					const r = await edit({ op: 'set', id: sheetItem.id, kind: 'xy', y: c.p });
					if (r) closePicker();
					return;
				}
				const r = await edit({ op: 'add', path: c.p, page: p ? p.id : '' });
				if (r) {
					row.classList.add('added');
					toast('Added: ' + c.l);
				}
			});
			list.append(row);
		}
		$('pk-note').textContent = found === 0 ? 'Nothing found.' :
			(found > shown ? shown + ' of ' + found + ' shown: type more to narrow it down.' : found + (found === 1 ? ' control' : ' controls')) +
			(catalog && catalog.more ? ' (the project has more controls than the list takes)' : '');
	}

	$('pk-search').addEventListener('input', fillPicker);
	$('pk-close').addEventListener('click', closePicker);
	$('picker').addEventListener('click', (e) => { if (e.target === $('picker')) closePicker(); });

	// ---------------------------------------------------------------- the live preview

	let pvOn = store.get('vibevj-remote-preview') === '1';
	let pvSrc = store.get('vibevj-remote-pv-src') || '';
	let pvLoop = 0;        // the running loop (a new one ends the old)
	let pvFrame = -1;
	let pvTimes = [];

	function previewAllowed() {
		return !!(layout && layout.preview && layout.preview.on && arr(layout.preview.sources).length);
	}

	function renderPreviewSources() {
		const allowed = previewAllowed();
		$('pv-btn').hidden = !allowed;
		const sel = $('pv-src');
		const sources = allowed ? arr(layout.preview.sources) : [];
		const text = sources.map((s) => s.id + '=' + s.name).join('|');
		if (sel.dataset.text !== text) {
			sel.dataset.text = text;
			sel.textContent = '';
			sources.forEach((s) => {
				const o = document.createElement('option');
				o.value = s.id;
				o.textContent = s.name;
				sel.append(o);
			});
		}
		if (!sources.some((s) => s.id === pvSrc)) pvSrc = sources.length ? sources[0].id : '';
		sel.value = pvSrc;
		sel.hidden = sources.length < 2;
		setPreview(pvOn && allowed);
	}

	function setPreview(on) {
		const show = !!on && previewAllowed();
		$('preview').hidden = !show;
		$('pv-btn').classList.toggle('on', show);
		$('pv-btn').setAttribute('aria-pressed', show ? 'true' : 'false');
		if (show && !document.hidden) {
			if (!setPreview.running) runPreview();
		} else {
			pvLoop++;
			setPreview.running = false;
		}
	}

	async function runPreview() {
		const me = ++pvLoop;
		setPreview.running = true;
		while (me === pvLoop && token) {
			const r = await api('api/preview?src=' + encodeURIComponent(pvSrc) + '&after=' + pvFrame);
			if (me !== pvLoop) break;
			if (!r) { await new Promise((ok) => setTimeout(ok, 1000)); continue; }
			if (r.status === 200 && r.data && r.data.img) {
				pvFrame = r.data.frame;
				$('pv-img').src = 'data:image/jpeg;base64,' + r.data.img;
				$('pv-img').dataset.frame = String(pvFrame);
				$('pv-frame').classList.add('has');
				$('pv-frame').style.aspectRatio = r.data.w + ' / ' + r.data.h;
				const t = now();
				pvTimes.push(t);
				pvTimes = pvTimes.filter((x) => t - x < 3000);
				const kb = Math.round(r.data.img.length * 0.75 / 102.4) / 10;
				$('pv-info').textContent = (pvTimes.length / 3).toFixed(1) + ' /s · ' + kb + ' KB';
			} else if (r.status === 204) {
				continue;
			} else if (r.status === 429) {
				await new Promise((ok) => setTimeout(ok, 1000));
			} else {
				// off in VibeVJ, the picture is gone: the layout says what is there now
				$('pv-frame').classList.remove('has');
				await new Promise((ok) => setTimeout(ok, 2000));
				if (me === pvLoop) refreshState();
			}
		}
		if (me === pvLoop) setPreview.running = false;
	}

	$('pv-btn').addEventListener('click', () => {
		pvOn = !pvOn;
		store.set('vibevj-remote-preview', pvOn ? '1' : '0');
		setPreview(pvOn);
	});
	$('pv-src').addEventListener('change', () => {
		pvSrc = $('pv-src').value;
		pvFrame = -1;
		store.set('vibevj-remote-pv-src', pvSrc);
		$('pv-frame').classList.remove('has');
		pvLoop++;
		setPreview.running = false;
		setPreview(pvOn);
	});
	// A phone in the pocket asks for no pictures
	document.addEventListener('visibilitychange', () => setPreview(pvOn));

	// ---------------------------------------------------------------- start

	// Opened from the QR code: the PIN is in the address. It is taken out right away (not kept in the history)
	const m = /(?:^#|&)pin=(\d{6})/.exec(location.hash);
	if (m) {
		history.replaceState(null, '', location.pathname);
		pair(m[1]).then((ok) => {
			if (ok) return;
			if (token) start(); // paired before: keep that
			else unpaired($('pair-msg').textContent);
		});
		$('pair').hidden = false;
	} else if (token) {
		start();
	} else {
		unpaired();
	}
})();
