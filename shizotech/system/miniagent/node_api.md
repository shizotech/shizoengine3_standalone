# Node JSON Web API (`node_api.shio`)

`node.shio` runs a **Node**: a *receptionist* connector that answers quickly and a
`WorkspaceRegistry` with task executors for every registered workspace. `node_api.shio` exposes
that Node as a plain JSON web API so it can be driven from any machine in the network — one node
per server, clients talk to all of them over HTTP.

```
shz node.shio                       interactive console
shz node.shio "your request"        single request, prints the answer
shz node.shio --port 13337          headless JSON web API
shz node.shio --port 13337 --api-token secret
```

`node_api_start(host, cfg, port, api_token = "", web_root = "")` returns the
`webserver.http_server` object, or `None` when the port cannot be bound. `host` is a `Node`.
With `web_root` the folder is served at `/` and the API index moves to `GET /api` — that is
how `shz miniagent --web` (`web_ui.shio`) serves the dashboard, the chat protocol
`/api/adminagent` and the workspace architecture/tasks API on top of this API.

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
| GET | `/api/status` | – | node, model, receptionist, workspace and task statistics |
| GET | `/api/overview` | – | raw Node overview across workspaces |
| GET | `/api/tasks` | – | flattened task list across all workspaces (`planned`, `research`, `implement`, `finished`, `failed`, `question`, `stopped`) |
| GET | `/api/task/<id>` | – | one task, full detail |
| POST | `/api/task` | `{"name":"Sexy-Sushi","goal":"…","workspace_id?":"…"}` | `{"taskid":"…","name":"…","state":"planned","workspace_id?"}` (calls `Node.add_task`; workspace id defaults to the Node's own workspace) |
| PUT | `/api/task/<id>` | `{"message":"…"}` | follow-up instruction for a planned/running task |
| DELETE | `/api/task/<id>` | – | stops the task |
| POST | `/api/request` | `{"prompt":"…"}` | `{"request_id":"…","status":"queued"}` |
| POST | `/api/request/poll` | `{"request_id":"…"}` | `{"status":"…","delta":{…}}` |
| GET | `/api/request/stream?request_id=<id>` | – | Server-Sent Events stream of the same deltas |
| POST | `/api/request/stop` | `{"request_id":"…"}` | aborts the receptionist turn |
| GET | `/api/notifications` | – | messages the receptionist pushed with `notify()` (`?drain=1` clears) |
| GET | `/api/events` | – | task lifecycle events (`?since=<ms>` returns newer ones only) |
| POST | `/api/shutdown` | – | stops the node (the process exits) |

## Talking to the receptionist

`POST /api/request` is **asynchronous**: it answers immediately with a `request_id`,
the receptionist runs in the background. Then either poll or stream.

Status lifecycle — the same contract the miniagent dashboard chat uses for
`/api/adminagent`:

```
queued  ->  generating  ->  waiting  ->  done | error
```

* `generating` — `data.delta` carries one receptionist action
* `waiting` — nothing new yet, poll again (back off a little)
* `done` — `data.result` is the receptionist's final answer, the `request_id` is freed
* `error` — `data.error` is the failure message

Each `delta` is a raw agent action, one of:

```json
{ "text": "…" }
{ "reasoning": "…" }
{ "tool_start": { "id": "…", "name": "…", "args": { } } }
{ "tool_end":   { "id": "…", "name": "…", "result": { } } }
# legacy action, no milestone() tool in the adaptive role
# { "milestone": "…" }
```

Tasks created by the receptionist are **not** part of the request result: they appear
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

# add a workspace task without the receptionist
curl -X POST http://192.168.1.10:13337/api/task \
     -H 'Authorization: Bearer secret' \
     -d '{"name":"Sexy-Sushi","goal":"Implement the export button","workspace_id":"my-project"}'
```

## Notes

* The receptionist is a single shared agent per node: requests are queued and handled
  one after another, and `POST /api/request/stop` ends the current turn for that node.
* Workspace task capacity comes from `max_running_agents` in the model config; the
  receptionist connector stays separate.
* Notifications and task-finished events are registered as additive listeners
  (`add_notify_listener` / `add_task_finished_listener`) when the host provides them, so the
  ShizoNet service keeps its own hook; stub hosts fall back to the legacy single slot.
* Request deltas, notifications and events are kept in memory, capped at 200 entries.
* Run `shz node_api_selftest.shio` for an end-to-end check (stub host, real HTTP,
  40 assertions, exit code 0 on success).
