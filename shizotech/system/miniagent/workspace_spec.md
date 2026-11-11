# miniagent workspace + session spec (issue #907)

The node's web UI becomes a workspace tree, and every workspace owns its own `.megamind`:
sessions, architecture and tasks live inside the workspace directory, not in the node's CWD.

## Files

| Path | Owner | Purpose |
|---|---|---|
| `node.shio` | backend | `Node` class: `WorkspaceRegistry`, own node `Workspace`, `Receptionist` connector, ShizoNet service, web/API |
| `workspaces.shio` | backend | `Workspace`, `WorkspaceRegistry`, `WorkspaceStore`, `SessionManager`, API registration |
| `workspace_agent.shio` | backend | subprocess session agent, `--config-spec`, JSON line protocol (`done status=stopped` on intentional stop; `file` / `notify` events) |
| `workspaces_selftest.shio` | backend | store / settings / protocol tests |
| `web/index.html`, `web/dashboard.css`, `web/dashboard.js` | frontend | workspace dashboard |
| `web/*` existing modules | frontend may reuse components, must not rewrite archive/chat/tasks pages |
| `web_ui.shio` | parent | includes and registers `workspaces.shio`; the web UI is the connector to `WorkspaceRegistry` |
| `telegram_router.shio` | follow-up | client mode |

## User data root

`store_root = std.user_path() + "/miniagent/workspaces"`

- The registry root is a container, not a project workspace; it has no `.agentspace`.
- `workspaces.json` is the registry.
- `settings.json` holds `max_sessions` (default 2).
- `WorkspaceStore.ensure_agentspace` initializes each real workspace/subworkspace with `.agentspace/` when registered and repairs missing template files on load (2026-11-06). The synthetic `root` workspace does not get its own `.agentspace/`.
- `.agentspace/` is the sole goal-engine root per real workspace: preferences, templates, goals and runtime ledger. It is initialized from the bundled `agentspace_template/` without overwriting existing files. Existing goal files under the former `.megamind/tasks/` root are imported here on workspace load; the legacy directory is left intact as a backup and is no longer read or written. All registered real workspace schedulers start at node startup; the synthetic `root` workspace has no project goal store.
- The Node's own goal/architecture store is node-level at `std.user_path()/miniagent/node`: `.agentspace` and `.megamind/architecture`. The Node's own Workspace is the registry's `root` Workspace, whose sessions live under `workspaces/.megamind/sessions`. It is independent of the directory the node was started from.
- `.megamind/` contains:
  - `.megamind/sessions/<session_id>/session.json` (metadata and a bounded 300-event live/replay window)
  - `.megamind/sessions/<session_id>/chat.json` (the complete agent conversation, the source for chat reloads)
  - `.megamind/sessions/<session_id>/chat.json.result.json` (durable terminal result, written before the session agent's `done` event)
  
  - `.megamind/architecture/architecture.json`

The 300-entry `session.json.events` window serves live replay only; it is not the chat transcript.
The session agent writes the full conversation to `chat.json` after each agent turn and also on every
tool start (so a crash keeps the latest conversation), and a matching terminal result to
`chat.json.result.json` before announcing completion. `chat.json` is the only source of truth
for the UI's chat; `session.json.events` is a bounded live/replay window, not a transcript copy.

Workspaces are bound to physical directories and can be nested. `parent` is a workspace id;
a child created without an explicit path goes below the parent's directory. Existing directories
are reused; missing directories are created. `.megamind` is created if missing.

## Workspace object

```json
{"id":"...","name":"...","path":"...","parent":"...","created":123,"description":""}
```

`GET /api/workspaces` returns `{tree, workspaces, settings, stats}`.
`POST /api/workspaces` takes `{name, path?, parent?}` and returns the workspace.
`GET /api/workspaces/<id>` returns workspace, sessions, architecture state and task overview.
`DELETE /api/workspaces/<id>` stops and deletes every session of the workspace, then removes the registry entry; a workspace with children is refused (delete the children first), and project files stay on disk. The response lists `sessions_removed`.

## Session object

```json
{"id":"...","workspace_id":"...","title":"...","mode":"normal|goal",
 "reasoning_effort":"low|medium|high",
 "status":"starting|running|waiting|done|failed|question|stopped",
 "prompt":"...","events":[...],"chat_history_size_at_prompt":0,
 "token_usage":0,"created":123,"updated":123}
```

Routes:

- `GET /api/workspaces/<id>/sessions`
- `POST /api/workspaces/<id>/sessions` body `{title?, mode?, prompt?, reasoning_effort?}`; effort defaults to
  `medium` and accepts `low`, `medium` or `high`. At most `max_sessions` active sessions globally.
- `GET /api/sessions/<id>` includes the complete `chat_history` plus in-flight `live_text`; the event array is only a bounded replay window and must not be used as the full transcript.
- `DELETE /api/sessions/<id>` stops the worker if needed and permanently removes that session's stored files.
- `POST /api/sessions/<id>/prompt` body `{prompt, reasoning_effort?}`; an effort override is persisted,
  then the running turn is interrupted and the new prompt is sent.
- `POST /api/sessions/<id>/mode` body `{mode}`.
- `POST /api/sessions/<id>/effort` body `{reasoning_effort}`; persists `low`, `medium` or `high` for every
  future turn and returns the updated session.
- `POST /api/sessions/<id>/stop`
- `GET /api/sessions/<id>/stream` => SSE `delta`, `user`, `status`, `done`, `error`, `stats`
- `GET /api/settings`, `PUT /api/settings` body `{max_sessions}`
- `GET /api/stats` => active sessions, running processes, token usage and a `session_status` map keyed by
  session ID; the dashboard uses it to update activity indicators without reloading workspace data.

## Session agent protocol

`workspace_agent.shio` runs in the workspace directory, with `--workspace`, `--config-spec`,
`--session-id`, `--history-file`, `--reasoning-effort`, `--role`, `--mode`. The spec is a
`name|path[#profile]`; `model_config_cli` resolves it and falls back to the default config. No
`config.json` is written per session. It emits one JSON object per line on stdout:

```json
{"type":"ready","session_id":"..."}
{"type":"delta","action":{...}}
{"type":"done","ok":true,"status":"finished|failed|question|stopped","report":"...","token_usage":0}
{"type":"error","message":"..."}
{"type":"warning","message":"..."}
{"type":"stats","token_usage":0}
{"type":"file",...}          // share_file protocol event
{"type":"notify",...}        // notify_user protocol event
```

It reads stdin JSON lines:

```json
{"type":"prompt","text":"...","reasoning_effort":"low|medium|high"}
{"type":"interrupt"}
{"type":"mode","mode":"normal|goal"}
{"type":"stop"}
```

The UI labels the existing `goal` mode as **Loop**. A new prompt while a turn runs interrupts:
the agent calls `stop()`, the turn returns, and the new prompt is taken next. Loop mode loops the
same prompt until the agent finalizes with `finished`, `failed` or `question`. A `question` is terminal
and needs the owner; a crash / API failure / process exit before a terminal state is reported as
`failed` with its reason (the subprocess exit is the terminal result, not an invisible retry).

## Architecture and tasks

For a workspace `W`, `W.scheduler` owns the scheduler and `W.board` owns the board:

- `ArchitectureBoard(W, W.path + "/.megamind/architecture", role)`
- `GoalScheduler(W.path + "/.agentspace", W, [workspace_id = W.id])`

`Workspace` holds the registry's shared `manager`, plus its `board`, `scheduler`, `cfg` and
`token`; it starts and stops its scheduler and its workspace sessions. `WorkspaceRegistry` owns
`store`, `manager`, the `workspaces` map, `cfg` and `token`, starts every real workspace scheduler
in `start_all_schedulers()`, and stops them plus active session workers in `stop()`. `Node` owns the registry and its own `goals` scheduler;
`WorkspaceRegistry.scheduler(workspace_id)` and `WorkspaceRegistry.board(workspace_id)` expose
the per-workspace scheduler and board.

`Workspace` is the duck-typed host for architecture and goals:

- `add_task(name, goal, role)` -> session id (empty = refused)
- `inspect_task(taskid)` -> canonical JSON `{ok, taskid, state, active, report, error, name, token_usage, last_update_ms}`; unknown -> `ok=false, state="lost", error="not found"`.
- `get_overview()` / `tasks()`
- `stop_task(taskid)`
- `update_task(taskid, message)`
- `background_capacity()`
- `add_task_finished_listener(cb)`
- `add_notify_listener(cb)` / `add_file_listener(cb)`
- `notify_user(msg)`
- `share_file(path, caption)` -> forwards a workspace agent's `file` protocol event

API routes for architecture/tasks mirror the existing node routes under
`/api/workspaces/<id>/architecture/...` and `/api/workspaces/<id>/tasks/...`.

## Frontend contract

Single page at `/`. Sidebar: recursive workspace tree, global tasks, settings, live stats.
Main: selected workspace header, sessions, chat with normal/goal toggle, architecture graph tab,
tasks tab. Selecting a different session only replaces the browser's SSE listener; it never stops the
session worker. On selection the dashboard reloads the complete `chat.json` transcript plus the
in-flight `live_text`, then resumes the SSE stream from the latest sequence; it does not rebuild the
transcript from the bounded `session.json.events` window.
SSE keeps the chat fluid; animations for running/working states. No CDN.
The session agent initializes the workspace goal store and registers the validated `get_goals`,
`create_goal`, `create_recurring_goal`, `update_goal`, `set_goal_status`, and `run_goal_now` tools plus
`create_workspace_task` for one-off tasks. In the goal engine, a recurring task is a recurring Goal, not a
separate task system or just an abstract objective. Chat workers must use `create_recurring_goal` for repeated
work (weekdays or an interval such as `every: 5m` or `every: 2d`); `create_workspace_task` is strictly one-off. Sub-day intervals run continuously from activation and need no time window. A recurring goal stays proposed until the user approves activation.
session ensures its parent goal scheduler is running, so an active
one-off task queued by a worker is consumed by the goal engine. The dashboard's Create & run action creates
an active manual goal and queues it through the same scheduler. Workspace agents also expose `architecture_overview`
and validated pending node/edge edit tools; they cannot run architecture jobs or apply graph/source changes.
Retry has no attempt cap: the manager restarts
an exited non-terminal process, and the agent retries API failures with backoff capped at 30 s. The selected
reasoning effort is persisted with the session and applied before every turn.

## Follow-up fixes for the last #907 comment

- The SSE route sets `Content-Type: text/event-stream` (it used to merge the JSON content type
  into the header set), accepts `?token=<t>` because EventSource cannot send headers, and
  accepts `?since=<last_seq>` so the dashboard does not replay history it already rendered.
- The registry `SessionManager` loads every saved `session.json` from each workspace's `.megamind/sessions/` on start. Non-terminal saved sessions are marked stopped because their subprocess is gone.
- `WorkspaceStore.ensure_megamind` copies a legacy `.agentspace/architecture.json` into
  `.megamind/architecture/architecture.json` when that workspace has no per-workspace graph.
- Task API: `GET /api/workspaces/<id>/tasks` returns `{goals, sessions, templates}`; goal summaries expose
  `active_run_state` and `active_taskid` while work is dispatched, distinct from the goal's configured status.
  `POST /api/workspaces/<id>/goals` creates a validated goal (via `goal_tool_create`),
  `POST /api/workspaces/<id>/goals/<goal_id>/run` queues an active goal in the scheduler, and
  `POST /api/workspaces/<id>/goals/<goal_id>/status` moves a proposed goal to active/paused.
- The dashboard has one sidebar: workspace tree with the selected workspace's sessions nested
  below it. Selecting a workspace refreshes the already-open Architecture or Tasks tab; task responses
  from a previous workspace are ignored. The visible Tasks or Global Tasks view refreshes every five seconds
  without a loading flash; active workspace tasks use the API's live `active` flag. Goal cards show a dispatched
  run as Running, with its task ID, independently of the goal's configured status. A `+` creates an empty session immediately with an auto title
  (the first prompt renames it); there is no session popup. Tasks are split into Active, Proposed, Templates and
  Finished; the task menu can start a normal/goal session task. Architecture has Analyze,
  Review plan, Apply and Discard buttons and imports an existing legacy model.
