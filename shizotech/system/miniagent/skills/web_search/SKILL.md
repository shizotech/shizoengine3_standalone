# Skill: Web Search & URL Fetch

This skill gives the agent **internet access**: search the web, and read any URL as
clean text.

> "A search engine is a question answering system that is controlled by a search engine
> ranking system." — the honest definition. Read the page, do not trust the snippet.

Everything is built on the shizoscript builtin web APIs (`curl.curl()`, `std.web_get()`)
plus the free [Jina reader](https://r.jina.ai). **No API key is required.**

---

## What you get

| Tool | Purpose |
|---|---|
| `web_search` | search the web → ranked `title` / `url` / `snippet` results |
| `web_fetch` | read one URL → markdown (default), plain text, or raw html |
| `web_status` | which providers are reachable, and why a call is failing |

---

# WORKFLOW

## 1. Search

```
web_search(query = "shizoscript creative coding language", max_results = 5)
```

Returns `[ok, query, provider, relevance, results, note]`, where every result is
`[rank, title, url, snippet, site]`.

Search operators work: `site:github.com`, `-term`, `"exact phrase"`.
Useful filters: `time_range` (`day|week|month|year`), `include_domains`,
`exclude_domains`, `region` (`us-en`, `de-de`, `wt-wt`), `page`.

## 2. Read the page

The snippet is a teaser. **Fetch the page before you rely on it.**

```
web_fetch(url = "https://github.com/shizotech/shizoscript3", max_chars = 20000)
```

Returns `[ok, url, title, format, provider, http_code, content_type, content]`,
plus `truncated` / `total_chars` / `note` when the content was cut.

- `format = "markdown"` (default) — Jina reader: renders javascript, strips navigation,
  keeps headings and links. Best for articles, docs, blogs.
- `format = "text"` — plain text, no markdown.
- `format = "html"` — the raw source. Use this for **APIs, JSON endpoints, and pages you
  must parse yourself**. This path never touches Jina.

## 3. Diagnose

```
web_status()
```

Answers: is there internet, is the Jina reader reachable, is direct fetching reachable,
and does each search provider currently return results. Use it when calls keep failing —
it distinguishes *offline* from *rate limited* from *markup changed*.

---

# IMPORTANT RULES

## 1. Search results are leads, not facts

A snippet is 1–2 sentences cut out of context. `web_fetch` the url before you state
anything from it. If two results disagree, fetch both.

## 2. DuckDuckGo rate limits hard — the skill handles it, so must you

DuckDuckGo answers an **anti-bot challenge page** (HTTP 202) after a handful of requests
per IP. The skill throttles per provider and falls back to **Bing RSS** automatically.

Do not loop `web_search` with rephrased queries when it fails. One retry, then
`web_status`, then change strategy (fetch a page you already know, use a domain filter,
or set `provider = "bing"`). Hammering a rate-limited engine makes it worse.

## 3. Read `relevance` — a green result can still be junk

Every answer carries a `relevance` percentage: how many results mention a word of your
query. Bing answers **niche queries** with generic localized filler (it once answered
"shizoscript" with gutter-cleaning listings). The skill rejects that and moves to the
next provider; if nothing is relevant it returns the least bad answer **with a
`warning`**.

- `relevance >= 60` — trust it.
- `relevance < 40` or a `warning` present — do not use these results. Rephrase, add
  `include_domains`, or fetch a known source.
- `min_relevance = 0` accepts whatever the engine returns (broad queries, browsing).

## 4. Pick the right format

`markdown` is for humans. For a JSON API use `format = "html"` — it is the untouched
response body, and the Jina reader would rewrite it.

## 5. Truncation is explicit

Content is cut at `max_chars` (default 20000, max 60000). When `truncated = 1` the
result says so and gives `total_chars`. Raise `max_chars` to see more — do not guess
what was past the cut.

## 6. Non-http schemes are refused

`web_fetch` accepts `http://` and `https://` only. A missing scheme is assumed `https://`.
File paths belong to the file tools, not here.

---

# USING THE LIBRARY FROM A SCRIPT

The tools are thin wrappers over `web_client.shio`, which is plain shizoscript —
`#include` it and call the functions directly.

```
#include "web_client.shio"

r = web_search("shizoscript", [max_results = 5, include_domains = "github.com"]);
if(r.ok)
{
    for(i = 0; i < r.results.size(); i++)
        std.print(r.results[i].title, " -> ", r.results[i].url);

    p = web_fetch(r.results[0].url, 10000, "markdown");
    if(p.ok) std.print(p.content);
}
```

## Library reference

| Function | Result |
|---|---|
| `web_search(query, opts)` | `[ok, query, provider, relevance, results, attempted]` |
| `web_fetch(url, max_chars, mode, timeout)` | `[ok, url, title, content, format, provider, http_code, content_type, truncated, total, warnings]` |
| `web_http(method, url, body, headers, timeout)` | `[ok, http_code, body, content_type, error]` |
| `web_jina_fetch(url, timeout, mode)` | `[ok, text, provider]` — raw Jina envelope |
| `web_html_to_text(html)` | readable text, tags/scripts/comments stripped |
| `web_inline_text(html)` | the same, collapsed to one line |
| `web_decode_entities(s)` | `&amp;` `&#x263A;` `&#128512;` decoded |
| `web_url_encode(s)` / `web_url_decode(s)` | percent encoding, utf-8 safe |
| `web_parse_rss(xml)` | RSS 2.0 **and** Atom → result list |
| `web_absolute_url(base, url)` | resolve a relative link |
| `web_host(url)` / `web_is_http(url)` / `web_clean_url(url)` | url parts |
| `web_bing_unwrap(url)` / `web_ddg_unwrap(href)` | engine redirect → real target |
| `web_query_tokens(q)` / `web_relevance(results, tokens)` | the relevance guard |

`web_search` options: `max_results`, `page`, `time_range`, `include_domains`,
`exclude_domains`, `region`, `provider`, `min_relevance`.

Every function returns a json result and **never throws** on network failure —
`ok = false` carries `error`.

## Configuration

Optional file, `std.config_path("miniagent", "websearch")`
(Windows: `Documents/Shizoscript/Configs/miniagent/websearch.json`):

```
[
    jina_api_key = "jina_xxx",              // unlocks s.jina.ai search + paid features
    jina_base = "https://r.jina.ai/",       // self-hosted reader endpoint
    search_providers = ["duckduckgo_lite", "bing"],
]
```

Without a key everything here works; `s.jina.ai` search is the only key-gated feature.

---

# ENGINE NOTES (verified, not guessed)

These shaped the implementation. They will save you hours.

- **`curl.curl()` needs `import curl;`.** `get/post/request` return
  `[ok, http_code, body, content_type]`. `ok = 1` means *a response arrived* — even for
  HTTP 404. A transport failure returns `[ok=0, code, error]` and does **not** throw.
- **`request(..., binary = 1)` is broken** — it returns all-null fields. Never use it.
- **`std.web_get(url)` throws** on failure and gives no status code. `curl` is the
  transport here.
- **`std.string.regex_*` rejects input over 16384 characters** (issue #102). Real pages
  are bigger, so `web_html_to_text` is a hand-written `find`/`substr` scanner
  (550 KB in ~0.5 s), not a regex.
- **No url encoder, no entity decoder, no html parser, no `<<`/`>>`** in the stdlib.
  UTF-8 is built with division tables.
- **User-Agent matters:** search engines want a browser UA; sending one to `r.jina.ai`
  gets a Cloudflare 403. Each path uses its own.
- **Bing `format=rss`** is the most reliable fallback: stable XML, no challenge, and
  **direct target urls** (the html page wraps them in base64 `/ck/a?...&u=a1<base64>`,
  which `web_bing_unwrap` decodes).
- Public **SearXNG** instances have JSON disabled and answer bot challenges; Mojeek,
  Startpage, Ecosia, Qwant and Brave all challenge. Marginalia challenges data-centre
  IPs. DDG + Bing RSS is the working set.

---

# FILES

| File | |
|---|---|
| `SKILL.md` | this document |
| `summary.md` | one-liner shown in the skill list |
| `SKILL.shio` | the agent tools (entry point `add_tools(agt)`) |
| `web_client.shio` | the library (`web_search/web_fetch/web_http/...`) |
| `web_client_selftest.shio` | `shz web_client_selftest.shio`: library tests, exits 1 on failure |
| `skill_selftest.shio` | `shz skill_selftest.shio`: loads `SKILL.shio` with a stub agent and drives every tool |
| `ddg_lite.html` | fixture: a real DuckDuckGo lite results page |
| `bing_rss.xml` | fixture: a real Bing RSS results feed |

Both selftests are self-contained. The offline half (encoding, entities, html→text,
parsers, fixtures) always runs; the online half is skipped when there is no internet,
so the parsing contract is verifiable anywhere.
