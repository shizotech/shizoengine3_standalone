/* ── NodeApi: the node JSON API (node_api.md) for every page of the dashboard ──
 *
 *   await NodeApi.get('/api/tasks')            -> data of {ok, data}
 *   await NodeApi.post('/api/task', {goal})    -> data, throws Error(error) on ok=false
 *   NodeApi.headers()                          -> headers with the API token
 *
 * The token (shz miniagent --web --api-token <t>) is asked once and kept in the
 * browser (localStorage 'miniagent_api_token'); ?token=<t> in the URL sets it too.
 */
const NodeApi = (() => {
  const KEY = 'miniagent_api_token';

  function token() {
    try {
      const fromUrl = new URLSearchParams(window.location.search).get('token')
        || new URLSearchParams((window.top && window.top.location.search) || '').get('token');
      if (fromUrl) localStorage.setItem(KEY, fromUrl);
      return localStorage.getItem(KEY) || '';
    } catch (e) {
      return '';
    }
  }

  function headers(extra) {
    const h = Object.assign({ 'Content-Type': 'application/json' }, extra || {});
    const t = token();
    if (t) h['X-Api-Token'] = t;
    return h;
  }

  let asking = null;

  async function askToken() {
    if (!asking) {
      asking = new Promise((resolve) => {
        const t = window.prompt('This node needs its API token (--api-token):', '');
        if (t) { try { localStorage.setItem(KEY, t.trim()); } catch (e) {} }
        resolve(!!t);
        setTimeout(() => { asking = null; }, 0);
      });
    }
    return asking;
  }

  async function call(method, path, body, retry = true) {
    const opts = { method, headers: headers() };
    if (body !== undefined) opts.body = JSON.stringify(body);
    const res = await fetch(path, opts);
    if (res.status === 401 && retry) {
      if (await askToken()) return call(method, path, body, false);
    }
    let data = null;
    try { data = await res.json(); } catch (e) { data = null; }
    if (!res.ok || !data || data.ok === false) {
      const err = new Error((data && data.error) || `HTTP ${res.status}`);
      err.status = res.status;
      throw err;
    }
    return data.data;
  }

  return {
    token, headers,
    get: (p) => call('GET', p),
    post: (p, b) => call('POST', p, b === undefined ? {} : b),
    put: (p, b) => call('PUT', p, b === undefined ? {} : b),
    del: (p) => call('DELETE', p),
  };
})();
