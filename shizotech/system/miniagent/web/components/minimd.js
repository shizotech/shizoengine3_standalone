/* ── minimd.js: a small Markdown renderer and a highlight.js stand-in ──
 * The chat page used markdown-it and highlight.js from a CDN; these shims keep it
 * working without internet. They only define window.markdownit / window.hljs when
 * no real library was loaded before.
 * Supported: headings, fenced code, inline code, bold, italic, links, lists,
 * block quotes, horizontal rules, paragraphs. HTML in the input is escaped.
 */
(function () {
  function esc(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function inline(s) {
    const codes = [];
    s = s.replace(/`([^`]+)`/g, (m, c) => { codes.push(c); return '\u0000' + (codes.length - 1) + '\u0000'; });
    s = esc(s);
    s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
         .replace(/(^|[^*])\*([^*\s][^*]*)\*/g, '$1<em>$2</em>')
         .replace(/\[([^\]]+)\]\((https?:[^)\s]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>')
         .replace(/(^|[\s(])(https?:\/\/[^\s<)]+)/g, '$1<a href="$2" target="_blank" rel="noopener">$2</a>');
    return s.replace(/\u0000(\d+)\u0000/g, (m, i) => '<code>' + esc(codes[+i]) + '</code>');
  }

  function tableCells(row) {
    let s = String(row).trim();
    if (s.startsWith('|')) s = s.slice(1);
    if (s.endsWith('|')) s = s.slice(0, -1);
    return s.split('|').map((c) => c.trim());
  }

  function render(src, opts) {
    const lines = String(src || '').replace(/\r\n/g, '\n').split('\n');
    const out = [];
    let para = [];
    let list = null;

    const flushPara = () => {
      if (para.length) out.push('<p>' + para.map(inline).join(opts.breaks ? '<br>' : ' ') + '</p>');
      para = [];
    };
    const flushList = () => {
      if (list) out.push('<' + list.tag + '>' + list.items.map(i => '<li>' + inline(i) + '</li>').join('') + '</' + list.tag + '>');
      list = null;
    };

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const fence = line.match(/^\s*(```|~~~)\s*([\w+-]*)/);
      if (fence) {
        flushPara(); flushList();
        const body = [];
        for (i++; i < lines.length && !lines[i].trim().startsWith(fence[1]); i++) body.push(lines[i]);
        out.push('<pre><code class="language-' + esc(fence[2] || 'text') + '">' + esc(body.join('\n')) + '</code></pre>');
        continue;
      }
      if (line.includes('|') && i + 1 < lines.length) {
        const sep = lines[i + 1].trim();
        if (/^\|?\s*:?-{2,}:?(\s*\|\s*:?-{2,}:?)*\s*\|?$/.test(sep)) {
          flushPara(); flushList();
          const head = tableCells(line);
          const rows = [];
          let j = i + 2;
          while (j < lines.length && lines[j].includes('|')) {
            const row = tableCells(lines[j]);
            if (row.length) rows.push(row);
            j++;
          }
          out.push('<table><thead><tr>' + head.map((c) => '<th>' + inline(c) + '</th>').join('') + '</tr></thead><tbody>' + rows.map((row) => '<tr>' + row.map((c) => '<td>' + inline(c) + '</td>').join('') + '</tr>').join('') + '</tbody></table>');
          i = j - 1;
          continue;
        }
      }
      const h = line.match(/^(#{1,6})\s+(.*)$/);
      if (h) { flushPara(); flushList(); out.push('<h' + h[1].length + '>' + inline(h[2]) + '</h' + h[1].length + '>'); continue; }
      if (/^\s*([-*_])(\s*\1){2,}\s*$/.test(line)) { flushPara(); flushList(); out.push('<hr>'); continue; }
      const q = line.match(/^>\s?(.*)$/);
      if (q) { flushPara(); flushList(); out.push('<blockquote>' + inline(q[1]) + '</blockquote>'); continue; }
      const ul = line.match(/^\s*[-*+]\s+(.*)$/);
      const ol = line.match(/^\s*\d+[.)]\s+(.*)$/);
      if (ul || ol) {
        flushPara();
        const tag = ul ? 'ul' : 'ol';
        if (!list || list.tag !== tag) { flushList(); list = { tag, items: [] }; }
        list.items.push((ul || ol)[1]);
        continue;
      }
      if (!line.trim()) { flushPara(); flushList(); continue; }
      if (list && /^\s+/.test(line)) { list.items[list.items.length - 1] += ' ' + line.trim(); continue; }
      flushList();
      para.push(line);
    }
    flushPara(); flushList();
    return out.join('\n');
  }

  if (typeof window.markdownit !== 'function') {
    window.markdownit = function (opts) {
      opts = opts || {};
      return { render: (s) => render(s, opts), renderInline: (s) => inline(s) };
    };
  }
  if (!window.hljs) {
    window.hljs = { highlightElement() {}, highlightAll() {}, highlight: (c) => ({ value: esc(c) }) };
  }
})();
