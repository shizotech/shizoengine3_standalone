# mcp — Model Context Protocol server

Serve tools, resources and prompts of a shizoscript program to MCP clients
(Claude Desktop, Claude Code, IDE agents, ...) over HTTP.

> This include is the **server**. To *use* an MCP server from a shizoscript
> program (or from the miniagent), see the client library and skill in
> `system/miniagent/skills/mcp_client/` (`mcp_client.shio`, `mcpclient(...)`),
> which speaks 2026-07-28, Streamable HTTP, HTTP+SSE and stdio.

```
#include "mcp/mcp_server"

server = mcpserver("My server", 13338);

server.add_tool(
	"echo",
	"Echo a message",
	[message = "&string(): Message to echo"],
	[](svr, args) {
		return args.message;
	}
);

std.sleep(-1);
```

One server answers every protocol version, the version of each request decides
how it is handled:

| Request | Protocol | Handled by |
|---|---|---|
| `MCP-Protocol-Version: 2026-07-28` header, or `server/discover` | 2026-07-28, stateless | `mcp_protocol_26.shio` |
| anything else (`initialize`, 2024-11-05 ... 2025-11-25) | initialize based | `mcp_protocol_25.shio` |

## Endpoints

| Endpoint | Use |
|---|---|
| `POST /mcp` (also `POST /`) | Streamable HTTP (2025-03-26 and newer) and 2026-07-28 |
| `GET /sse` (also `GET /`) | legacy HTTP+SSE event stream (2024-11-05, the `sse` transport) |
| `POST /mcp?sessionid=...` | requests of a legacy SSE stream (the stream sends this url as its `endpoint` event) |
| `DELETE /mcp` | ends the Streamable HTTP session named by `Mcp-Session-Id` |
| `GET /mcp` | 405, the server does not open streams on its own |

Connecting a client, e.g. Claude Code:

```
claude mcp add --transport http my-server http://localhost:13338/mcp
claude mcp add --transport sse  my-server http://localhost:13338/sse
```

### Initialize based protocol (2024-11-05 ... 2025-11-25)

- `initialize` answers with the version the client asked for when it is one of
  `MCP_VERSIONS_2025`, otherwise with the newest (`MCP_VERSION_2025`).
- Streamable HTTP: `initialize` returns an `Mcp-Session-Id` header. A request
  with an unknown session id gets 404, the client then initializes again (for
  example after the server restarted). Requests without a session id are
  served too. A request with an unsupported `MCP-Protocol-Version` header gets 400.
- Notifications and client responses get `202 Accepted` without a body.
- Legacy SSE: every POST is answered with 202, the JSON-RPC response is sent
  as `event: message` on the stream.

### 2026-07-28

- No handshake and no sessions: every request carries `MCP-Protocol-Version`,
  `Mcp-Method` and (for `tools/call`, `prompts/get`, `resources/read`)
  `Mcp-Name`. Headers that do not match the body get 400.
- `server/discover` returns the supported versions (2026-07-28 and the 2025
  ones), capabilities, server info and instructions.
- Discovery, list and read results carry `ttlMs` / `cacheScope`, see `set_cache()`.

## API

### `mcpserver(name, port, http_backend = None, autostart = true)`

Creates the server and (with `autostart`) starts it. `running` is false and
`error` says why when the port cannot be bound. Every instance has its own
registries, several servers can run side by side on different ports.

| Member | |
|---|---|
| `start()` / `stop()` | bind and serve / end all streams and sessions and unbind. Create a new `mcpserver` to serve again after `stop()`. |
| `running`, `error` | state of the HTTP server |
| `version` | server version reported in `serverInfo` (default `"1.0.0"`) |
| `set_instructions(text)` | instructions for the client / model (`add_instruction` is an alias) |
| `set_cache(ttl_ms, scope)` | 2026-07-28 cache hints, default `0` / `"private"` (do not cache) |
| `enabled` | `false` keeps the server bound but rejects everything except `initialize`, `server/discover` and `ping` with error `-32005` |
| `verbose` | print every request to the console |
| `status()` | name, port, running, enabled, counts of tools / resources / prompts / streams / sessions / requests / errors |
| `connected_clients(max_age_ms = 300000)` | clients seen recently: client, protocol, version, transport, last_seen_ms |
| `history` | the last `history_size` (100) requests, see below |

### Tools

```
server.add_tool(name, description, parameters, callback, with_context = false);
server.remove_tool(name);  server.has_tool(name);  server.clear_tools();
server.list_tools();       // the tools/list entries
```

- `parameters` uses the notation of the openai include (`openai/simple_json.shio`),
  `None` for a tool without arguments:

  | Spec | JSON schema |
  |---|---|
  | `"&string(): Text"` | required string (`&` = required, the text after `:` is the description) |
  | `"string(1,64): Text"` | optional string with min / max length |
  | `"int(0,10): Count"` | integer with minimum / maximum |
  | `"float(0,1): Mix"` | number with minimum / maximum |
  | `"array(string): Names"` | array of strings |
  | `"enum(a,b,c): Mode"` | one of the listed strings |
  | `"any(): Value"` | any JSON value |
  | `["a", "b"]` | required enum |
  | `[nested = "...", ...]` | required nested object |

- `callback(server, args)` returns a string or a json (written as text).
  With `with_context = true` it is called as `callback(server, args, ctx)`
  (see Hooks for `ctx`), e.g. to tell clients apart.
  A runtime error inside the callback becomes a tool result with `isError`
  and the error message, so the model learns what went wrong. Unknown tools
  are a JSON-RPC error `-32602`.
- `server.tools` is the `toolset` of the openai include, `server.tools.add_tool(...)`
  works as before.

### Resources

```
server.add_resource(uri, name, description, mime_type, text);               // static text
server.add_resource_file(uri, name, description, path, mime_type);          // read on every resources/read
server.add_resource_callback(uri, name, description, mime_type, callback);  // callback(server, uri) -> text
```

### Prompts

```
server.add_prompt(name, description,
	[[name = "user", description = "Name of the user", required = true]],
	[](svr, args) { return "Welcome, " + args.user + "!"; });
```

A missing required argument is a JSON-RPC error `-32602`.

### Hooks

- `tool_filter(name, args, ctx)`: return `None` to run the tool, or a string to
  reject the call (the client gets a tool result with `isError` and the reason).
- `on_request(entry)`: called after every request with its history entry.

`ctx` describes the request: `protocol` (`"2025"` / `"2026"`), `version`,
`client` (client name from `initialize`, else the user agent or ip) and
`transport` (`"streamable-http"`, `"sse"` or `"http"`).

History entries: `time, protocol, version, client, transport, method, name, ok, error, duration_ms`
(`name` is the tool / prompt name or the resource uri, `error` the message of a failed request or tool call).

Route handlers run on their own script threads, a slow tool only delays its
own request.

## Files

| File | |
|---|---|
| `mcp_server.shio` | `mcpserver`, the include scripts use |
| `mcp_protocol_25.shio` | initialize based protocol, Streamable HTTP + legacy SSE |
| `mcp_protocol_26.shio` | 2026-07-28 stateless protocol |
| `mcp_types.shio` | constants, JSON-RPC helpers, resource / prompt registries |
| `mcp_server_25.shio`, `mcp_server_26.shio` | old include names, both include `mcp_server.shio` |
| `mcp_selftest.shio` | `shz mcp_selftest.shio`: exercises every protocol and transport over HTTP, exits with 1 on a failure |
| `docs/welcome.txt` | resource file used by the self test |

### Changes for scripts of the old includes

- `mcp_server_25` and `mcp_server_26` declared the same class and could not be
  used together. Both names now include the one server that speaks all versions.
- Tool callbacks are `callback(server, args)` for every protocol
  (`mcp_server_26` called `callback(args)`).
- A failing tool returns its error message (`isError`) instead of
  "Internal server error.".

## Empty lists

shizoscript writes every empty JSON container as `{}`. List fields of MCP
results go through `mcp_list()` and every message is written with
`mcp_encode()`, so an empty list is sent as `[]` (`"tools": []`). Use the same
helpers when you build MCP messages yourself.
