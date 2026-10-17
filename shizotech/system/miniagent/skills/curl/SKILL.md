# Skill: curl — HTTP requests, one-shot and streaming

This skill gives the agent the shizoscript **`curl` module**: send any HTTP request,
upload files, download bodies, and run **background requests** that can be polled,
waited for, and stopped.

> "The important thing is to be able to say 'I don't know' when you don't know." —
> and to read `http_code` when you do. `ok = true` only means a response arrived.

Everything is built on the builtin `curl.curl()` object (`import curl;`). No external
binary, no API key, no python.

---

## What you get

| Tool | Purpose |
|---|---|
| `curl_request` | one synchronous request → status, headers, body (or `save_to` a file) |
| `curl_start` | start a request in the **background**, returns an `id` immediately |
| `curl_poll` | non-blocking: the chunks that arrived **since the last poll** |
| `curl_wait` | blocking: wait for the transfer to finish, get the **whole** buffer |
| `curl_stop` | abort a running request, return what was received, free it |
| `curl_streams` | list this agent's open background requests + counters |
| `curl_upload` | `multipart/form-data` upload (file on disk, or content from memory) |
| `curl_status` | libcurl version, limits, transport facts, what is open |

---

# WORKFLOW

## 1. A normal request

```
curl_request(url = "http://localhost:13337/api/health")
curl_request(url = "http://localhost:13337/api/request", method = "POST",
             body = '{"prompt":"hello"}',
             headers = {"Content-Type":"application/json","Authorization":"Bearer secret"})
```

Returns `[ok, http_code, content_type, body, bytes]`, plus `warning` on 4xx/5xx and
`truncated` / `note` when the body was cut.

**`ok = true` means a response arrived.** HTTP 404 and 500 are `ok = true` with that
`http_code`. `ok = false` is a transport failure (dns, refused, timeout) and carries
`error`.

Big body? `curl_request(url = ..., save_to = "out.json")` writes it to a file and
answers with `{saved_to, bytes}` instead of dumping it into the conversation.

## 2. A request you must not block on

For streaming endpoints (SSE, `/events`), long jobs, or anything you want to watch
while you keep working:

```
s = curl_start(url = "http://192.168.1.10:13337/api/request/stream?request_id=abc",
               timeout_ms = 120000, label = "node-run")
# -> {"ok":true,"id":"req_9f2c…","status":"running", …}

curl_poll(id = "req_9f2c…")     # non-blocking, gives the new chunks
curl_wait(id = "req_9f2c…", timeout_ms = 20000)   # blocks, gives the whole buffer
curl_stop(id = "req_9f2c…")     # abort + free
```

Status lifecycle: `running` → `finished` | `stopped` | `error`.

- **`curl_poll`** is cursor based: every chunk is handed out exactly once, it never
  blocks. `status = "running"` with `new_chunks = 0` means "nothing new yet, sleep a
  moment and ask again".
- **`curl_wait`** returns the **whole** buffer and does not move the poll cursor, so
  you can wait first and poll afterwards without losing anything.
- **`curl_stop`** always. The number of open streams is limited (8).

## 3. Uploads

```
curl_upload(url = "http://host/import", path = "notes.md", fieldname = "file")
curl_upload(url = "http://host/import", data = "# hello", filename = "note.md",
            content_type = "text/markdown")
```

## 4. When things fail

```
curl_status()
```

Reports the libcurl version, the open streams, the buffer/timeout limits, and the
transport facts below. Use it when requests keep failing or when you forgot what is
still open.

---

# IMPORTANT RULES

## 1. Check `http_code`, not just `ok`

`ok` is about the transport. A 404, a 500 and a redirect loop all arrive as `ok = true`.
The tool adds a `warning` for `http_code >= 400` — read it.

## 2. Chunks are raw bytes, not lines

A chunk can end in the middle of a line. When you parse a line protocol
(SSE `data: …`, JSON-lines), keep the tail of the last partial line yourself and
prepend it to the next poll. `curl_poll` concatenates the new chunks into `text`.

## 3. A stream without a timeout runs forever

`start_stream` with `timeout_ms = 0` sets **no** timeout at all. This skill always
applies one (default 20 s, max 600 s). For a long-lived stream pass a large
`timeout_ms` explicitly, and stop it when you are done.

## 4. `dropped > 0` means you lost data

libcurl aborts a stream whose chunks are not drained (queue limit **256**), so this
skill drains them in a background reader thread and keeps a bounded buffer
(4000 chunks / 4 MB). If `curl_poll` reports `dropped`, you polled too slowly: the
oldest data is gone. Poll more often, or `curl_wait` for the whole thing.

## 5. Stop what you open

`curl_start` is capped at 8 concurrent streams; the 9th is refused with the list of
open ones. Finished streams are swept after 2 min idle and running ones after 30 min,
but do not rely on that — call `curl_stop`.

## 6. Headers

Pass a json object: `{"Authorization" = "Bearer xyz"}`. A **JSON string** is accepted
too (`'{"Authorization":"Bearer xyz"}'`); shizoscript's own `[k = v]` literal syntax is
**not** valid JSON and will not parse. Header lookup on the server side is
case-insensitive.

## 7. No binary transfers

`curl.curl().request(..., binary = 1)` is broken (it returns all-null fields). This
skill never uses it. For a download, use `save_to` — you get the file, not the bytes.

## 8. Truncation is explicit

Bodies are cut at `max_chars` (default 20000, max 60000) with `truncated = 1` and the
real `bytes` count. Raise `max_chars` or use `save_to` — do not guess what was past
the cut.

## 9. Transports, not scraping

This is a raw HTTP client: it returns the body as the server sent it. For reading
websites as readable text use the `web_search` skill (`web_fetch`), which renders and
strips html. For talking to your own services and APIs, use this one.

---

# USING THE LIBRARY FROM A SCRIPT

The tools are thin wrappers over `curl_client.shio`, plain shizoscript — `#include` it
and call the functions directly.

```
#include "curl_client.shio"

r = curl_get("http://localhost:13337/api/health");
if(r.ok)
    std.print(r.http_code, " ", r.body);

s = curl_stream_start("POST", "http://localhost:13337/api/request", '{"prompt":"hi"}',
                      ["Content-Type" = "application/json"], 30000, "my-run");

if(s.ok)
{
    w = curl_stream_wait(s.id, 20000);
    std.print(w.status, ": ", w.text);
    curl_stream_close(s.id);
}
```

## Library reference

| Function | Result |
|---|---|
| `curl_http(method, url, body, headers, timeout_ms)` | `[ok, http_code, body, content_type, error]` |
| `curl_get` / `curl_post` / `curl_put` / `curl_patch` / `curl_delete` / `curl_head` | same, per method |
| `curl_download(url, path, headers, timeout_ms)` | `[ok, http_code, saved_to, bytes]` |
| `curl_upload_file(url, path, fieldname, headers, timeout_ms)` | response of the server |
| `curl_upload_data(url, data, filename, fieldname, content_type, headers, timeout_ms)` | response of the server |
| `curl_stream_start(method, url, body, headers, timeout_ms, label)` | `[ok, id, status, …]` |
| `curl_stream_poll(id, max_chunks, max_chars)` | `[ok, status, new_chunks, text, pending, dropped, …]` |
| `curl_stream_wait(id, timeout_ms, max_chars)` | `[ok, status, text (whole buffer), timed_out, waited_ms, …]` |
| `curl_stream_stop(id, do_close)` | `[ok, status, bytes, text]` |
| `curl_stream_text(id)` | the whole buffer as one string |
| `curl_stream_get(id)` / `curl_stream_exists(id)` | the entry / a bool |
| `curl_stream_close(id)` | frees the registry slot |
| `curl_stream_list()` / `curl_stream_summaries()` | what is open |
| `curl_stream_sweep()` | closes idle finished streams, kills ancient ones |
| `curl_skill_info()` | version, limits, counters, open streams |
| `curl_skill_headers(v)` | json object headers from json / json string / None |
| `curl_skill_cut`, `curl_skill_str`, `curl_skill_int`, `curl_skill_url_error` | the small helpers |

Streams live in `std.global("curl_streams")`, guarded by
`std.critical_section_named("curl_streams")`, so they survive a single call and are
shared by the whole agent tree. Every function returns a json result and **never
throws** on network failure.

---

# ENGINE NOTES (verified in `shzmodule_curl/curl.cpp`, not guessed)

- `get/post/put/delete/request` return `[ok, http_code, body, content_type]`;
  `ok = 1` means a response arrived, **including 404/500**.
- A transport failure returns `[ok = 0, code, error]` and does **not** throw.
- `request(method, url, body?, headers?, timeout_ms?, binary?)` — `binary = 1` is
  broken (all-null fields).
- `start_stream(method, url, body?, headers?, timeout_ms?)` runs in its **own worker
  thread** and returns immediately. Starting a second stream on the same object stops
  the first, so use one `curl.curl()` object per stream.
- `poll_stream()` **blocks** until the next chunk and returns `None` once the transfer
  is finished and drained. There is no non-blocking peek — that is why this skill uses
  a reader thread.
- The chunk queue holds **256** chunks; a consumer that is too slow makes libcurl
  **abort the transfer**.
- `stop_stream()` returns 1 when a stop was signalled, 0 when there is no stream.
- `timeout_ms = 0` on a stream means **no timeout**. Without a timeout, a non-streaming
  request aborts after 300 s of <1 byte/s progress; connect timeout is always 10 s.
- Redirects are followed (max 10), staying on http/https; credentials are not sent on
  to other hosts.
- The destructor of a curl object blocks until its stream workers exit.
- `last_error()` carries the last transport error text.

### shizoscript pitfalls this skill works around (see `.megamind` notes)

- `some_call(...) ?? default` is broken in the current compiler → use
  `curl_skill_str/int/get` helpers.
- `json.bool` values never compare equal to `true`/`false`/`1`/`0` → only truthiness.
- `std.thread(<named function>)` started from a **skill tool callback** dies with
  "Global scope root mismatch when creating routine" → start
  `std.thread([captured]() { fn(captured); })` from a lambda created at the call site,
  and never park the thread object in the global registry json.
- `for(i = 0; i < n)` (no increment) is a syntax error; the condition-only form is
  `for(cond)`.

---

# FILES

| File | |
|---|---|
| `SKILL.md` | this document |
| `summary.md` | one-liner shown in the skill list |
| `SKILL.shio` | the agent tools (entry point `add_tools(agt)`) |
| `curl_client.shio` | the library (`curl_http`, `curl_stream_*`, `curl_upload_*`) |
| `curl_test_server.shio` | local HTTP fixture (plain, echo, 404, redirect, chunked stream, forever stream, multipart) |
| `curl_client_selftest.shio` | `shz curl_client_selftest.shio`: 87 library checks, exits 1 on failure |
| `skill_selftest.shio` | `shz skill_selftest.shio`: 103 checks, loads `SKILL.shio` with a stub agent and drives every tool |

Both selftests are self-contained: they start the fixture server on a local port, so
they need **no internet** and no LLM endpoint.
