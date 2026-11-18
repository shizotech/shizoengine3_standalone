// The cue call of the lighting desk for the crews on their phones (#719): what comes next on the master deck, per crew,
// in bars.beats with standby / 3 / 2 / 1 / GO. Polls /api/cuecall with the token of the remote (paired on /).
(function () {
	'use strict';
	const $ = (id) => document.getElementById(id);
	const store = {
		get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
		set(k, v) { try { localStorage.setItem(k, v); } catch (e) { } },
	};
	const token = store.get('vibevj-remote-token');
	let crew = store.get('vibevj-cuecall-crew') || '';
	let crews = [];
	let lastGo = {};

	function msg(text) { $('cc-msg').textContent = text || ''; }

	function fillCrews(list) {
		const names = list.join('|');
		if (names === crews.join('|')) return;
		crews = list.slice();
		const sel = $('cc-crew');
		while (sel.options.length > 1) sel.remove(1);
		for (const c of crews) {
			const o = document.createElement('option');
			o.value = c;
			o.textContent = c;
			sel.appendChild(o);
		}
		sel.value = crews.includes(crew) ? crew : '';
	}

	function tile(row, big) {
		const el = document.createElement('section');
		el.className = 'cc-tile' + (row.state ? ' cc-' + row.state : '') + (big ? ' cc-big' : '');
		const head = document.createElement('div');
		head.className = 'cc-crew';
		head.textContent = row.crew + (row.state === 'standby' ? ' · STANDBY' : '');
		const what = document.createElement('div');
		what.className = 'cc-what';
		what.textContent = row.what || 'nothing ahead';
		const count = document.createElement('div');
		count.className = 'cc-count';
		count.textContent = row.state === 'go' ? 'GO' : (['1', '2', '3'].includes(row.state) ? row.state : (row.what ? row.text : ''));
		const at = document.createElement('div');
		at.className = 'cc-at';
		at.textContent = row.at || '';
		el.append(head, what, count, at);
		return el;
	}

	function render(c) {
		if (!c || !c.deck) {
			$('cc-title').textContent = '—';
			$('cc-pos').textContent = '';
			$('cc-rows').replaceChildren();
			msg((c && c.waiting) || 'No master deck');
			return;
		}
		msg('');
		$('cc-title').textContent = 'Deck ' + c.deck + ' · ' + (c.title || '');
		$('cc-pos').textContent = ' ' + (c.bar || '') + (c.playing ? '' : ' (paused)') + (c.phrase ? ' · ' + c.phrase : '');
		fillCrews((c.rows || []).map((r) => r.crew));
		const rows = (c.rows || []).filter((r) => !crew || r.crew === crew);
		if (c.next_phrase) rows.push(c.next_phrase);
		$('cc-rows').replaceChildren(...rows.map((r) => tile(r, !!crew && r.crew === crew)));
		// a short buzz on GO of the picked crew (phones that can)
		for (const r of rows) {
			if (r.state === 'go' && crew && r.crew === crew && lastGo[r.crew] !== r.what + r.at && navigator.vibrate) navigator.vibrate(200);
			if (r.state === 'go') lastGo[r.crew] = r.what + r.at;
		}
	}

	async function poll() {
		if (!token) {
			msg('Pair this phone first: open the remote (‹) and enter the PIN shown in VibeVJ.');
			return;
		}
		try {
			const res = await fetch('api/cuecall', { headers: { 'X-Remote-Token': token }, cache: 'no-store' });
			if (res.status === 401) {
				msg('Not paired: open the remote (‹) and enter the PIN shown in VibeVJ.');
				setTimeout(poll, 2000);
				return;
			}
			render(res.ok ? await res.json() : null);
			if (!res.ok) msg('VibeVJ answers ' + res.status);
		} catch (e) {
			msg('No connection to VibeVJ');
			setTimeout(poll, 1000);
			return;
		}
		setTimeout(poll, 120);
	}

	$('cc-crew').addEventListener('change', (e) => {
		crew = e.target.value;
		store.set('vibevj-cuecall-crew', crew);
	});
	poll();
})();
