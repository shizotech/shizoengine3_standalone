# Node architecture (`node.shio`, `workspaces.shio`, `workspace_agent.shio`)

The runnable miniagent node is a `Node` class plus workspace and connector classes:

```text
Node
├── WorkspaceRegistry (WorkspaceStore + one SessionManager + id -> Workspace map)
│   └── Workspace per registered real workspace
│       ├── GoalScheduler (host = Workspace)
│       ├── ArchitectureBoard (host = Workspace)
│       └── workspace task API (through the shared SessionManager)
├── node Workspace (the Node's own task executor)
│   └── GoalScheduler and ArchitectureBoard (task API through the shared SessionManager)
├── Receptionist connector (one receptionist agent for node requests)
├── AiService (ShizoNet AI node service)
└── optional web server / JSON API
```

`Node` owns the whole runtime. `Node.start_shizonet()`, `Node.ensure_workspace_registry()`,
`Node.start_node_goals(root)`, `Node.start_web(opts)`, `Node.start_api(port, token)`,
`Node.request(prompt)`, `Node.update_receptionist(message)`, `Node.overview()` and `Node.stop()`.
The command-line script wires these pieces and keeps the interactive, `--web`, `--webserver` /
`--port`, single-shot and headless modes.

`WorkspaceRegistry` loads and instantiates every `Workspace` from
`std.user_path()/miniagent/workspaces`; `WorkspaceStore` owns `workspaces.json` and
`settings.json`, and the registry owns one `SessionManager` shared by every workspace.
The registry exposes create / delete / get / list / tree / stop. `Workspace` is the single task
executor: it owns its `GoalScheduler` and `ArchitectureBoard`, and exposes `add_task`,
`update_task`, `stop_task`, `inspect_task`, `get_overview`, task listing, `notify_user`,
listeners and `share_file` forwarding through the shared manager.
`Node.add_task(name, goal, role = "adaptive", workspace_id = "")` routes to a `Workspace`;
an empty workspace id means the Node's own workspace (`root`). The Node's own goal scheduler is
attached to that root Workspace but uses `std.user_path()/miniagent/node/.agentspace`; the
node-level architecture graph is at `std.user_path()/miniagent/node/.megamind/architecture`.
`Node.update_task`, `stop_task`, `inspect_task`, `overview` and task listing search all
workspaces; listeners are registered on the shared `SessionManager` and therefore cover every
workspace.

`SessionManager` spawns `workspace_agent.shio` as a subprocess in the workspace directory.
It writes only `session.json`, `chat.json` and `chat.json.result.json`; there is no per-session
`config.json`. The agent receives a config spec (name, path, or `path#profile`) via
`--config-spec` from the Node's default or worker config. The endpoint and API token are not
persisted with the conversation.

`Node.start_web(opts)` serves `web/index.html` and its component files. `web_ui_protect` denies
the legacy standalone `/chat` and `/tasks` pages, but serves `/architecture/` because the
dashboard's Architecture tab embeds `architecture/index.html`. The dashboard shell is plain
HTML/CSS/JS; `web/components/industrial.css` adds the animated console layer (moving hazard
stripe, lamp bank, CRT overlay) without changing API or task logic.

`Receptionist` is the connector around a single receptionist agent: it answers node requests
and handles follow-ups (`Node.request` / `Node.update_receptionist`). It is not a worker pool.
The agent has read-only workspace tools (`list_dir`, `file_info`, `file_line_count`, `read_file`)
to answer questions about the node's own workspace; it has no write, command or execution tool.
`AiService` is the ShizoNet AI node service; routers talk to `Node`, and the node pushes
workspace task lifecycle, notify and file events.

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
