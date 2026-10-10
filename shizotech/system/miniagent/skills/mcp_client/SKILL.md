# Skill: MCP Client — connect to MCP servers

This skill lets you **use MCP servers as a client**.

The standard library ships an MCP *server* (`mcp/mcp_server`, `includes/mcp`): it exposes
your own tools, resources and prompts to MCP clients. This skill is the mirror of it:
it connects **out** to any MCP server and lets you call what that server offers.

> "A server answers. A client asks. Be the one who asks."

---

## What you get

After `mcp_connect` you can

- list / call the **tools** of the server
- list / read its **resources**
- list / render its **prompts**
- **expose its tools as real agent tools** (`mcp_expose_tools`) and call them directly

Transports are handled for you: `2026-07-28` stateless, `2025` Streamable HTTP,
legacy `HTTP+SSE`, and `stdio` (a server you start as a process).

---

# WORKFLOW

## 1. Connect

```
mcp_connect(name = "files", url = "http://localhost:13338/mcp")
```

HTTP servers: pass `url`.
Process servers (the usual `npx` style MCP servers): pass `command` as a list:

```
mcp_connect(name = "everything", command = ["npx", "-y", "@modelcontextprotocol/server-everything"])
```

`transport` is chosen automatically: `2026` → `http` → `sse`.
Pass `transport` explicitly (`"2026"`, `"http"`, `"sse"`, `"stdio"`) to force one.
Servers that need authentication: `headers = [Authorization = "Bearer ..."]`.

The result contains the server info, its instructions and the lists of tools,
resources and prompts. **Read them, do not guess tool names or arguments.**

## 2. Use it

Either call one tool explicitly:

```
mcp_call_tool(name = "files", tool = "read_file", arguments = [path = "./notes.md"])
```

or expose the ones you need and call them like normal tools:

```
mcp_expose_tools(name = "files", tools = ["read_file", "write_file"])
// -> now available: mcp_files_read_file, mcp_files_write_file
```

`tools = ["*"]` exposes every tool of the server.

Resources and prompts:

```
mcp_list_resources(name = "files")
mcp_read_resource(name = "files", uri = "file:///notes/welcome.txt")
mcp_list_prompts(name = "files")
mcp_get_prompt(name = "files", prompt = "welcome", arguments = [user = "Alice"])
```

## 3. Clean up

```
mcp_disconnect(name = "files")
```

A stdio server process is terminated by `mcp_disconnect`.

---

# IMPORTANT RULES

## 1. One connection per server, named by you

Connections live in a shared registry and survive across tool calls.
Use short stable names (`files`, `browser`, `db`). `mcp_servers()` lists them.
Reconnecting a name that is already connected reuses the existing connection.

## 2. Never invent remote tool arguments

Call `mcp_list_tools(name, with_schema = 1)` and build `arguments` from the
returned JSON schema. A wrong argument is a tool error, not a hint.

## 3. Prefer exposing tools over repeated `mcp_call_tool`

`mcp_expose_tools` registers the remote tools in your own toolset, so the
arguments are validated by the tool definition and you call them directly.
Expose only what you need — every exposed tool costs context.

## 4. A failing remote tool is data, not a crash

Every mcp tool answers `[ok, ...]`. `ok = false` carries `error` (and often the
server's `code`). Read the message, fix the arguments, retry once.
Do not hammer a server that keeps answering `ok = false`.

## 5. Images

A tool result may contain image blocks. They are summarised as
`[image image/png N bytes base64]` so they do not flood the context.
If you need to see it, call `mcp_call_tool(..., with_image = 1)` — that ends the
current run and continues with the image attached.

## 6. Servers can be slow

stdio servers (npx packages) may take seconds to start. `mcp_connect` waits for
the handshake; if it fails, read `error` — it says which transport failed.

---

# TOOL REFERENCE

| Tool | Purpose |
|---|---|
| `mcp_connect` | connect to an HTTP (`url`) or stdio (`command`) MCP server |
| `mcp_servers` | list all connections of this agent |
| `mcp_server_info` | details of one connection (add `with_schema = 1` for tool schemas) |
| `mcp_list_tools` | tools of a server |
| `mcp_call_tool` | call one remote tool |
| `mcp_expose_tools` | register remote tools as agent tools (`mcp_<server>_<tool>`) |
| `mcp_list_resources` / `mcp_read_resource` | resources |
| `mcp_list_prompts` / `mcp_get_prompt` | prompt templates |
| `mcp_refresh` | re-read tools / resources / prompts |
| `mcp_disconnect` | close a connection (kills a stdio server) |

---

# FILES

| File | |
|---|---|
| `SKILL.md` | this document |
| `summary.md` | one-liner shown in the skill list |
| `SKILL.shio` | the agent tools (entry point `add_tools(agt)`) |
| `mcp_client.shio` | the client library (`mcpclient(...)`, `mcp_client_connect/get/list/disconnect`) |
| `mcp_client_selftest.shio` | `shz mcp_client_selftest.shio`: tests the library over every transport, exits 1 on failure |
| `skill_selftest.shio` | `shz skill_selftest.shio`: loads `SKILL.shio` with a stub agent and drives every `mcp_*` tool |
| `miniagent_integration.shio` | `shz miniagent_integration.shio`: the real `miniagent` class discovers, loads and uses the skill |
| `concurrency_test.shio` | `shz concurrency_test.shio`: parallel calls on shared HTTP/stdio connections and parallel connects |
| `stdio_test_server.shio` | minimal stdio MCP server used by the tests |

All four test scripts are self contained: they start their own server on a test
port and need no LLM endpoint.

## Using the library directly (scripts)

```
#include "mcp_client.shio"

c = mcp_client_connect("target", "http://localhost:13338/mcp");

if(c.connected)
{
    std.print(c.tools);
    r = c.call_tool("echo", [message = "hi"]);
    if(r.ok) std.print(r.text);
}

mcp_client_disconnect("target");
```

Every method returns `[ok, result, error]`; a JSON-RPC error is a normal
`ok = false` result and never throws.

## Concurrency

The agent loop runs tool callbacks on their own threads, so several agents call
these functions at the same time. The registry is guarded by a named critical
section (`"mcp_clients"`), a connect reserves its name before the handshake, and
the stdio pipes and the SSE stream of one client are serialised per client.
Connections are safe to share between threads; do not add your own locking.
