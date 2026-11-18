# Node JSON API (`node_api.shio`)

A **node** (`shz miniagent --node`) is a `WorkspaceRegistry` with a task executor for every
registered workspace; every request is a worker session in a workspace (there is no
receptionist agent, #1015). `node_api.shio` exposes that node as a plain JSON API, and the
same routes are reached three ways:

```
shz miniagent --node --webserver --port 13337 [--api-token secret]    HTTP, the API only
shz miniagent --node --web [--port 13337]                             HTTP, with the web interface
(always)                                                              ShizoNet: the ai_api command
                                                                      (router_api.md), no HTTP
```

The routes live in a table (`ApiRouter`, `api_router.shio`): the HTTP server serves it, and
`ApiRouter.dispatch(method, path, body, query, headers)` runs the same handler without HTTP.
That is how the web interface of one node works with every other node: it calls
`/api/nodes/<id>/api/...` on its own node, which passes the call on over ShizoNet.

`node_api_start(host, cfg, port, api_token = "", web_root = "", web_protect = None)` returns
the `ApiRouter` (its `server` is the `webserver.http_server`), or `None` when the port cannot
be bound. `host` is a `Node`. `node_api_register(table, host, cfg, port, api_token, api_at_root)`
only registers the routes on a table (a node without a web server has one for `ai_api`).
With `web_root` the folder is served at `/` and the API index moves to `GET /api` — that is
how `--web` (`web_ui.shio`) serves the dashboard and the workspace API (`workspace_spec.md`)
on top of this API.

## Envelope

Every response is `application/json`:

```json
{ "ok": true,  "data":  { } }
{ "ok": false, "error": "message" }
```

Errors also set a proper HTTP status: `400` bad/missing body, `401` unauthorized,
`404` unknown task/request, `409` task no longer updatable, `503` the host refused a new task
(empty taskid or `add_task` returned `ok=false`).
CORS is open (`Access-Control-Allow-Origin: *`) and `OPTIONS` answers `204`, so
browsers can call the API directly.

## Auth

When `--api-token` is given, every endpoint except `GET /api/health` requires

```
Authorization: Bearer <token>        or        X-Api-Token: <token>
```

For a browser SSE stream (`EventSource`) the token may also be passed as `?token=<token>`;
EventSource cannot send headers. SSE responses use `Content-Type: text/event-stream`.

The model endpoint token (`ModelConfig.token`) is never returned by any endpoint.

## Endpoints

| Method | Path | Body | Result |
|---|---|---|---|
| GET | `/` | – | API index (endpoint list) |
| GET | `/api/health` | – | liveness, uptime, request counter (no token needed) |
| GET | `/api/status` | – | node (name, description, version), model, workspace and task statistics, `requests.active` |
| GET | `/api/overview` | – | raw Node overview across workspaces |
| GET | `/api/tasks` | – | flattened task list across all workspaces (`queued`, `planned`, `research`, `implement`, `finished`, `failed`, `question`, `stopped`) |
| GET | `/api/task/<id>` | – | one task, full detail |
| POST | `/api/task` | `{"name":"Sexy-Sushi","goal":"…","workspace?":"…"}` | `{"taskid":"…","name":"…","state":"queued|planned","workspace_id?"}` (calls `Node.add_task`: a worker session in that workspace, an id or a name; default the node's own; a full session pool returns a queued task) |
| PUT | `/api/task/<id>` | `{"message":"…"}` | a prompt into that session (a running turn continues with it, a finished one starts a new turn; if the pool is full that turn is queued) |
| DELETE | `/api/task/<id>` | – | stops the task |
| POST | `/api/request` | `{"prompt":"…","workspace?":"…"}` | `{"request_id":"…","status":"queued"}` |
| POST | `/api/request/poll` | `{"request_id":"…"}` | `{"status":"…","delta":{…}}` |
| GET | `/api/request/stream?request_id=<id>` | – | Server-Sent Events stream of the same deltas |
| POST | `/api/request/stop` | `{"request_id":"…"}` | stops that turn |
| GET | `/api/notifications` | – | messages agents pushed with `notify()` (`?drain=1` clears) |
| GET | `/api/events` | – | task lifecycle events (`?since=<ms>` returns newer ones only) |
| POST | `/api/shutdown` | – | stops the node (the process exits) |

The workspace API is registered on the same table (`workspace_spec.md`): workspaces, sessions
and their stream, tasks and goals per workspace, architecture, settings, and

| Method | Path | Result |
|---|---|---|
| GET | `/api/live?since=<rev>&wait=<ms>&workspace=<id>` | the change feed: answers at once when the caller is behind, otherwise when something changes or after `wait` (`workspace_spec.md`, "Live feed") |
| GET | `/api/sessions/<id>/events?since=<seq>&wait=<ms>` | the session stream as JSON (a long-poll), for callers that cannot hold an SSE stream |
| GET | `/api/tasks/overview` | the goals and sessions of every workspace in one answer |
| GET / PUT | `/api/gateway` | the Telegram gateway settings of this node: `{settings: {enabled, name, config, token_set, token_hint}, status: {running, wanted, pid, started, restarts, last_exit, log}, managed}`. `PUT {enabled?, bot_token?, config?, name?, clear_token?}` changes what is sent and starts / stops / restarts the gateway; the bot token is write-only (`gateway_config.shio`) |

Only on the HTTP server of the web interface (`web_ui.shio`), not over `ai_api`:

| Method | Path | Result |
|---|---|---|
| GET | `/api/nodes` | `{nodes: [{id, name, kind: node|gateway|other, local, online, api, model, description, busy, tasks_running, goals, workspaces, ip, last_seen}], rev}` — this node first (`id: "local"`), then what it sees on ShizoNet |
| * | `/api/nodes/<id>/api/...` | the same route on that node, over ShizoNet, with that node's status code and body. Errors of the way there: `404` unknown node, `400` not an AI node (a gateway), `503` the node is offline (or this node is not on ShizoNet), `502` / `504` it did not answer, `501` it has no API over ShizoNet |

## A request turn

`POST /api/request` is **one worker turn**: a new session in the workspace (default: the
node's own, "General"), answered when the worker finalizes. It is **asynchronous**: it answers
immediately with a `request_id`, the turn runs in the background. Then either poll or stream.
For work that will get follow-ups use `POST /api/task` (or a session of the workspace API):
the task id is the session, `PUT /api/task/<id>` continues it.

Status lifecycle:

```
queued  ->  generating  ->  waiting  ->  done | error
```

* `generating` — `data.delta` carries one agent action
* `waiting` — nothing new yet, poll again (back off a little)
* `done` — `data.result` is the worker's report, the `request_id` is freed
* `error` — `data.error` is the failure message

Each `delta` is a raw agent action, one of:

```json
{ "text": "…" }
{ "reasoning": "…" }
{ "tool_start": { "id": "…", "name": "…", "args": { } } }
{ "tool_end":   { "id": "…", "name": "…", "result": { } } }
```

Tasks a worker starts are **not** part of the request result: they appear
in `/api/tasks`, and their completion arrives in `/api/events`.

## Examples

```bash
# is it alive?
curl http://192.168.1.10:13337/api/health

# start work
curl -X POST http://192.168.1.10:13337/api/request \
     -H 'Content-Type: application/json' \
     -H 'Authorization: Bearer secret' \
     -d '{"prompt":"Give the repo a proper README"}'
# -> {"ok":true,"data":{"request_id":"cd0ff23f…","status":"queued"}}

# follow it
curl -X POST http://192.168.1.10:13337/api/request/poll \
     -H 'Authorization: Bearer secret' \
     -d '{"request_id":"cd0ff23f…"}'

# or stream it
curl -N http://192.168.1.10:13337/api/request/stream?request_id=cd0ff23f…

# what is the node busy with?
curl -H 'Authorization: Bearer secret' http://192.168.1.10:13337/api/tasks
curl -H 'Authorization: Bearer secret' http://192.168.1.10:13337/api/events?since=1792170000000

# start work in a workspace (a session that can be continued)
curl -X POST http://192.168.1.10:13337/api/task \
     -H 'Authorization: Bearer secret' \
     -d '{"name":"Sexy-Sushi","goal":"Implement the export button","workspace":"my-project"}'

# the same API of another node, through this one
curl -H 'Authorization: Bearer secret' http://192.168.1.10:13337/api/nodes
curl -H 'Authorization: Bearer secret' http://192.168.1.10:13337/api/nodes/GPUBox-03fc00000001/api/workspaces'
```

## Notes

* Request turns run next to each other (each is a session of its own); `max_sessions` (the
  settings) and `max_running_agents` (the model config) limit how many generate. A task or request
  that arrives while every session slot is busy is accepted as `queued` and started FIFO when a
  slot frees; `POST /api/task` reports that `state`.
* Notifications and task-finished events are registered as additive listeners
  (`add_notify_listener` / `add_task_finished_listener`) when the host provides them, so the
  ShizoNet service keeps its own hook; stub hosts fall back to the legacy single slot.
* Request deltas, notifications and events are kept in memory, capped at 200 entries.
* `OPTIONS` answers `204`; an unknown path is `404` for every other method.
* Run `shz node_api_selftest.shio` for an end-to-end check (stub host, real HTTP,
  40 assertions, exit code 0 on success); `web_ui_selftest.shio` covers the live feed, the
  node list and a call through another node.
