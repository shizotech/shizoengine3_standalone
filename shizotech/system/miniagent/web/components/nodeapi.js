/* ── NodeApi: the node JSON API (node_api.md, workspace_spec.md) for every page ──
 *
 *   await NodeApi.get('/api/tasks')            -> data of {ok, data}
 *   await NodeApi.post('/api/task', {goal})    -> data, throws Error(error) on ok=false
 *   NodeApi.headers()                          -> headers with the API token
 *
 *   const remote = NodeApi.at('GPUBox-03fc00000001');   // another node of the network
 *   await remote.get('/api/workspaces')        -> the same API of that node; the node this
 *                                                 page comes from asks it over ShizoNet
 *                                                 (/api/nodes/<id>/api/..., web_ui.shio)
 *   remote.url('/api/sessions/x/stream')       -> the path with the node prefix
 *   NodeApi.at('local') / NodeApi.at('')       -> the node itself (no prefix)
 *
 * A page opened with ?node=<id> (the architecture frame) uses that node for the plain
 * NodeApi.get / post / put / del calls as well.
 *
 * The token (shz miniagent --node --web --api-token <t>) is asked once and kept in the
 * browser (localStorage 'miniagent_api_token'); ?token=<t> in the URL sets it too.
 */
const NodeApi = (() => {
  const KEY = 'miniagent_api_token';

  function param(name) {
    try {
      return new URLSearchParams(window.location.search).get(name)
        || new URLSearchParams((window.top && window.top.location.search) || '').get(name);
    } catch (e) {
      try { return new URLSearchParams(window.location.search).get(name); } catch (e2) { return null; }
    }
  }

  function token() {
    try {
      const fromUrl = param('token');
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

  // '' for the node the page comes from, '/api/nodes/<id>' for another one
  function prefixOf(nodeId) {
    const id = String(nodeId || '');
    return (!id || id === 'local') ? '' : '/api/nodes/' + encodeURIComponent(id);
  }

  async function call(prefix, method, path, body, opts, retry = true) {
    const init = { method, headers: headers() };
    if (body !== undefined) init.body = JSON.stringify(body);
    if (opts && opts.signal) init.signal = opts.signal;
    const res = await fetch(prefix + path, init);
    if (res.status === 401 && retry) {
      if (await askToken()) return call(prefix, method, path, body, opts, false);
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

  function make(nodeId) {
    const prefix = prefixOf(nodeId);
    return {
      node: String(nodeId || 'local'),
      prefix,
      url: (p) => prefix + p,
      get: (p, opts) => call(prefix, 'GET', p, undefined, opts),
      post: (p, b, opts) => call(prefix, 'POST', p, b === undefined ? {} : b, opts),
      put: (p, b, opts) => call(prefix, 'PUT', p, b === undefined ? {} : b, opts),
      del: (p, opts) => call(prefix, 'DELETE', p, undefined, opts),
    };
  }

  const pageNode = (() => { try { return new URLSearchParams(window.location.search).get('node') || ''; } catch (e) { return ''; } })();
  const base = make(pageNode);

  return {
    token, headers,
    at: make,
    node: base.node,
    url: base.url,
    get: base.get,
    post: base.post,
    put: base.put,
    del: base.del,
  };
})();
