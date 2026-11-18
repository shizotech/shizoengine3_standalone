# Node architecture (`node_lib.shio`, `workspaces.shio`, `workspace_agent.shio`)

The runnable miniagent node is a `Node` class plus workspace classes. `node.shio` is only its
command line (`shz miniagent --node ...`); a script that wants a node includes `node_lib`.

```text
Node
├── WorkspaceRegistry (WorkspaceStore + one SessionManager + id -> Workspace map)
│   ├── Workspace per registered real workspace
│   │   ├── GoalScheduler (host = Workspace)
│   │   ├── ArchitectureBoard (host = Workspace)
│   │   └── workspace task API (through the shared SessionManager)
│   └── LiveFeed (the change feed of the web interface, GET /api/live)
├── node Workspace ("General", id "node": work that belongs to no project)
│   └── GoalScheduler and ArchitectureBoard (task API through the shared SessionManager)
├── ApiRouter (the route table of the JSON API: HTTP and ShizoNet use the same one)
├── AiService (ShizoNet AI node service: tasks, requests, events, ai_api)
├── NodePeers (the other nodes and gateways on ShizoNet)
├── GatewayRunner (starts the Telegram gateway when the settings say so)
└── optional web server (the API alone, or with the web interface)
```

**There is no agent in front of the work** (#1015). Until 2026-11 a `Receptionist` connector,
one receptionist agent per node, took every request and re-delegated it to a worker; requests
queued behind it, the worker got a paraphrase, and a follow-up had to find its worker through
it. Now every request is a worker session in a workspace: `Node.add_task(...)` starts one,
`Node.update_task(taskid, message)` continues it (also after it finished), and
`Node.request(prompt, on_finish, on_action, workspace_id)` is one blocking worker turn. Who
decides *where* a request goes is the caller: a person in the web interface picks the
workspace, the router agent of a gateway names node and workspace (`router_api.md`).

`Node` owns the whole runtime: `Node.ensure_workspace_registry()`, `Node.start_api_table(token)`,
`Node.start_shizonet()`, `Node.start_node_goals(root)`, `Node.start_web(opts)`,
`Node.start_api(port, token)`, `Node.request(...)`, `Node.requests_active()`,
`Node.update_request(message)`, `Node.stop_request()`, `Node.resolve_workspace(id_or_name)`,
`Node.workspaces_summary(limit)`, `Node.get_overview()` and `Node.stop()`.
The command-line script wires these pieces and keeps the `--interactive`, `--web`,
`--webserver` / `--port` and headless modes.

`WorkspaceRegistry` loads and instantiates every `Workspace` from
`std.user_path()/miniagent/workspaces`; `WorkspaceStore` owns `workspaces.json` and
`settings.json`, and the registry owns one `SessionManager` shared by every workspace.
The registry exposes create / delete / get / list / tree / stop. `Workspace` is the single task
executor: it owns its `GoalScheduler` and `ArchitectureBoard`, and exposes `add_task`,
`update_task`, `stop_task`, `inspect_task`, `get_overview`, task listing, `notify_user`,
listeners and `share_file` forwarding through the shared manager.
`Node.add_task(name, goal, role = "adaptive", workspace_id = "", origin = "")` routes to a
`Workspace` (an id or a name); an empty workspace id means the Node's own workspace. `origin`
says who asked ("web", "net", "": a scheduled goal or a tool) and travels with the session
into its `task_finished` event, so a gateway does not announce a session someone runs in the
web interface. A new workspace without a path gets the folder `<cwd of the node>/workspaces/<name>`
(`WorkspaceStore.projects_dir`). The Node's own goal scheduler is
attached to that root Workspace but uses `std.user_path()/miniagent/node/.agentspace`; the
node-level architecture graph is at `std.user_path()/miniagent/node/.megamind/architecture`.
`Node.update_task`, `stop_task`, `inspect_task`, `overview` and task listing search all
workspaces; listeners are registered on the shared `SessionManager` and therefore cover every
workspace.

`SessionManager` spawns `workspace_agent.shio` as a subprocess in the workspace directory.
It writes only `session.json`, `chat.json` and `chat.json.result.json`; there is no per-session
`config.json`. The agent receives a config spec (name, path, or `path#profile`) via
`--config-spec` from the Node's config. The endpoint and API token are not
persisted with the conversation.

`Node.start_web(opts)` serves `web/index.html` and its component files. `web_ui_protect` denies
the legacy standalone `/chat` and `/tasks` pages, but serves `/architecture/` because the
dashboard's Architecture tab embeds `architecture/index.html`. The dashboard is plain
HTML/CSS/JS (`web/readme.md`).

**The API is one route table** (`ApiRouter`, `api_router.shio`): `node_api_register`,
the workspace routes and the gateway settings are registered on it once. The HTTP server
serves it; `AiService` answers the ShizoNet command `ai_api` with
`table.dispatch(method, path, body, query)`. A node without `--web` has the table too, so
every node can be driven from the web interface of any other node
(`/api/nodes/<id>/api/...` there, `NodePeers.call`).

`AiService` is the ShizoNet AI node service; gateways and other nodes talk to `Node` through
it, and the node pushes workspace task lifecycle, notify and file events. Nothing with a JSON
boolean goes over the wire (`ai_wire`, `router_api.md`).

`LiveFeed` (in the registry) watches what a dashboard shows — sessions with their status and
token usage, the workspace list, the goals of a workspace, notifications, peers — and counts a
revision up when one of them changes. `GET /api/live?since=<rev>&wait=<ms>` answers at once
when the caller is behind and otherwise holds the answer until a change: the page needs no
timer.

## Terminal protocol

- Model signals: `finished | failed | question`; `continue` is a hand-over, not terminal.
- Runtime states: `stopped` (intentional stop) and `lost` (definitive host not-found).
- One terminal event per task turn. `SessionManager.finish_terminal` / `notify_listeners`
  dedupe by session id; `GoalScheduler.settle_runs` dedupes by taskid and `r.settled`.
- A stopped session is not `failed`: `SessionManager.stop_session` sets `stop_requested`
  before signalling/killing, and the pump maps the exit to `stopped`.
- `workspace_agent.shio` emits JSON protocol lines: `ready`, `delta`, `stats`, `done`,
  `error`, `warning`, `file` and `notify`. `SessionManager` turns `file` / `notify` lines
  into additive listeners (`add_file_listener`, `add_notify_listener`); task-finished
  listeners are registered on `Workspace` / `SessionManager`, not on a worker pool.
- `add_task` returning an empty id or `[ok=false, ...]` is a refused dispatch, not a task.
- A plain finished goal run emits no second scheduler `[goals]` notification; the task's
  `task_finished` event carries the report. `question`, failed, stalled and refused dispatch
  notifications are deduped by event key.

Durable contract docs: `flow_spec.md`, `workspace_spec.md`, `goals_spec.md`.
