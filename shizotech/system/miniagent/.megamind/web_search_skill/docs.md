# Verified facts about shizoscript web APIs (probed live, 2026-10-10)

## Builtins

- `import curl;` is REQUIRED (bare `curl` = compile error "Variable 'curl' does not exist").
- `curl.curl()` → handle. Methods:
  - `get(url, headers_json?, timeout_ms?)` → `[ok, http_code, body, content_type]`
  - `post(url, payload, headers_json?, timeout_ms?)`
  - `request(method, url, body?, headers_json?, timeout_ms?, binary?)`
  - `delete(...)`, `post_file(...)`, `post_file_data(...)`, `version()`, `last_error()`
  - `start_stream()/poll_stream()/stop_stream()`
- Transport failure → `[ok=0, code=<curl code>, error="<text>"]`, **no throw**.
  `ok` is absent on success only when transport failed; on success `ok=1` even for HTTP 404.
  → `ok` means "got a response", `http_code` is the status.
- Header keys are quoted: `["User-Agent" = "..."]`.
- **`request(..., binary=1)` is BROKEN** — returns `{body:null, content_type:null, http_code:null, ok:null}`.
  Never pass binary=1.
- `std.web_get(url)` → body string, **throws** on failure ("HTTP request failed: ..."). No status code.
- libcurl/8.17.0-DEV Schannel zlib/1.3.1.

## Hard limits

- `std.string.regex_replace/match/search`: input **> 16384 chars throws a runtime error** (issue #102).
  → HTML→text MUST be a hand-written `find`/`substr` scanner. Verified: 550 KB scanned in 484 ms.
- No `<<`/`>>` operators → UTF-8 encode with division: `192+cp/64`, `128+(cp/64)%64`, ...
- No URL encode/decode, no HTML entity decoder, no HTML parser in the stdlib.
- `std.hex_to_char("41")` returns **int 65**, not a string.
- `std.int("0x1a")` → 26. `std.int("abc")` → 0 + runtime warning (validate digits first).
- `std.buffer()` takes **no args**; build bytes with `buf.append([226,130,172])`, read with
  `buf.read("u8", i)` (out of range throws), `buf.string()` is byte-exact.
- `std.string.find(needle, start)` → -1 if absent; `substr(i,1)` is byte-exact (UTF-8 multi-byte
  chars split into bytes).
- `json.geti(key)` takes exactly 1 arg (no default).

## Search providers (live)

| provider | result |
|---|---|
| `POST https://lite.duckduckgo.com/lite/` body `q=...` | **200, parseable** (`result-link`, `result-snippet`, `link-text`, `uddg=`) |
| `GET lite/?q=...` | works once, then **202 anomaly challenge** (~14 KB page, contains "anomaly") |
| `lite/?q=...&o=json` / `&df=` / `&kl=` / `&dc=` | **202 challenge** — extra GET params trigger it |
| `POST html.duckduckgo.com/html/` | 202 challenge (needs `result__a` parse if it ever succeeds) |
| `GET bing.com/search?q=` | 200, 126 KB, anchors `class="b_algo"`, `<h2><a href=` |
| `mojeek.com/search` | 200 but **5.5 KB challenge page**, no results |
| `startpage`, `searx.be`, `ecosia`, `qwant` | 403 / antibot challenge |
| `search.marginalia.nu/search?query=` | 200, 37 KB |
| `en.wikipedia.org/w/api.php` | 403 **unless a real User-Agent is set**; then clean JSON |

DDG rate-limits aggressively per IP. Throttle + fallback chain is mandatory.

## Jina reader

- `GET https://r.jina.ai/<url>` → **200, `text/plain`, markdown, no API key needed**, ~400 ms.
- **MUST NOT send a browser User-Agent** → Cloudflare "Just a moment..." 403.
  Default curl UA, `miniagent-web/1.0`, or no headers all work.
- Output shape: `Title: X\n\nURL Source: ...\n\n[Published Time:]\n\n[Warning: ...]\n\nMarkdown Content:\n<body>`
- Optional headers that work keyless: `x-respond-with: markdown|text`, `x-timeout: N`, `x-no-cache: true`.
- `x-respond-with: json` → 400 (needs Accept). `x-with-generated-alt` → 401 (needs key).
- Errors are JSON: `{"data":null,"code":401|422|403,"name":"...","message":"..."}`.
  403 = `AbuseAlleviationError` (domain blocked), 422 = unresolvable URL.
- Target 404 → 200 with `Warning: Target URL returned error 404` inside the text.
- `s.jina.ai/<query>` (search) → **401 AuthenticationRequiredError** keyless. Needs `Authorization: Bearer <key>`.
