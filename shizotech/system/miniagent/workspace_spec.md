# miniagent workspace + session spec (issues #907, #1015)

The node's web UI becomes a workspace tree, and every workspace owns its own `.megamind`:
sessions, architecture and tasks live inside the workspace directory, not in the node's CWD.

## Files

| Path | Owner | Purpose |
|---|---|---|
| `node_lib.shio` | backend | `Node` class: `WorkspaceRegistry`, own node `Workspace`, the API route table, ShizoNet service, web/API (`node.shio` is its command line) |
| `api_router.shio` | backend | `ApiRouter`: the routes of this spec are registered on it; HTTP and ShizoNet (`ai_api`) serve the same table |
| `workspaces.shio` | backend | `Workspace`, `WorkspaceRegistry`, `WorkspaceStore`, `SessionManager`, API registration |
| `workspace_agent.shio` | backend | subprocess session agent, `--config-spec`, JSON line protocol (`done status=stopped` on intentional stop; `file` / `notify` events) |
| `workspaces_selftest.shio` | backend | store / settings / protocol tests |
| `web/index.html`, `web/dashboard.css`, `web/dashboard.js` | frontend | workspace dashboard |
| `web/*` existing modules | frontend may reuse components, must not rewrite archive/chat/tasks pages |
| `web_ui.shio` | parent | includes and registers `workspaces.shio`; the web UI is the connector to `WorkspaceRegistry`, and to the registries of the other nodes (`/api/nodes/<id>/api/...`) |

## User data root

`store_root = std.user_path() + "/miniagent/workspaces"`

- The registry root is a container, not a project workspace; it has no `.agentspace`.
- `shz miniagent --init [<dir>] [--name <n>]` registers a directory (default: the current one) as a real workspace, creates `.megamind`/`.agentspace`, writes `AGENTS.md` if missing, and returns without starting the node/web/ShizoNet. An already registered directory is reused.
- `WorkspaceStore.ensure_agents_md(path)` writes a short project-agent `AGENTS.md` when missing; it never overwrites an existing project file. It runs on workspace creation and on load of registered non-root workspaces.
- `workspaces.json` is the registry.
- `settings.json` holds `max_sessions` (default 2), the number of sessions that may run at once. Further tasks are not refused: they are accepted with `status = "queued"` and started FIFO when a slot frees.
- `WorkspaceStore.ensure_agentspace` initializes each real workspace/subworkspace with `.agentspace/` when registered and repairs missing template files on load (2026-11-06). The synthetic `root` workspace does not get its own `.agentspace/`.
- `.agentspace/` is the sole goal-engine root per real workspace: preferences, templates, goals and runtime ledger. It is initialized from the bundled `agentspace_template/` without overwriting existing files. Existing goal files under the former `.megamind/tasks/` root are imported here on workspace load; the legacy directory is left intact as a backup and is no longer read or written. All registered real workspace schedulers start at node startup; the synthetic `root` workspace has no project goal store.
- The Node's own goal/architecture store is node-level at `std.user_path()/miniagent/node`: `.agentspace` and `.megamind/architecture`. The Node's own Workspace ("General", id `node`) lives there too, with its sessions under `node/.megamind/sessions`; the registry adopts it (`WorkspaceRegistry.adopt`), so every route of this spec takes `node` as a workspace id. It is independent of the directory the node was started from.
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
a child created without an explicit path goes below the parent's directory. A top-level
workspace created **without a path** goes to `<projects_dir>/<name as a slug>`, where
`projects_dir` is `./workspaces` below the directory the node was started in (#1015;
`WorkspaceStore.projects_dir`, a store with its own root keeps them in that root). Existing
directories are reused; missing directories are created. `.megamind` is created if missing.

## Workspace object

```json
{"id":"...","name":"...","path":"...","parent":"...","created":123,"description":""}
```

`GET /api/workspaces` returns `{tree, workspaces, settings, stats, projects_dir, general}`
(`general`: the record of the node's own workspace, `projects_dir`: where a workspace without
a path will go — the dialog of the page shows it).
`POST /api/workspaces` takes `{name, path?, parent?, description?}` and returns the workspace.
The description is what a gateway's router agent reads when it picks the workspace for a request.
`GET /api/workspaces/<id>` returns workspace, sessions, architecture state and task overview.
`DELETE /api/workspaces/<id>` stops and deletes every session of the workspace, then removes the registry entry; a workspace with children is refused (delete the children first), and project files stay on disk. The response lists `sessions_removed`.

## Session object

```json
{"id":"...","workspace_id":"...","title":"...","mode":"normal|goal",
 "reasoning_effort":"low|medium|high",
 "status":"queued|starting|running|waiting|done|failed|question|stopped",
 "prompt":"...","events":[...],"chat_history_size_at_prompt":0,
 "token_usage":0,"created":123,"updated":123,
 "origin":"web|net|"}
```

Routes:

- `GET /api/workspaces/<id>/sessions`
- `POST /api/workspaces/<id>/sessions` body `{title?, mode?, prompt?, reasoning_effort?}`; effort defaults to
  `medium` and accepts `low`, `medium` or `high`. At most `max_sessions` sessions run at once; a session created
  while all slots are busy is accepted as `status = "queued"` and started when a slot frees.
- `GET /api/sessions/<id>` includes the complete `chat_history` plus in-flight `live_text`; the event array is only a bounded replay window and must not be used as the full transcript. While a turn runs it also has `turn` (the turn so far as items, below) and `turn_seq` (the `seq` of the last event that is in it), and its `status` is the current one.
- `GET /api/sessions/<id>/events?since=<seq>&wait=<ms>` => `{session_id, status, seq, terminal, events}`: the events of the stream as JSON. It answers at once when there are newer ones or the session is terminal, otherwise when one arrives or after `wait` (at most 10 s). For a caller that cannot hold an SSE stream: a node that serves another node's session (`web_ui_remote_stream`).
- `DELETE /api/sessions/<id>` stops the worker if needed and permanently removes that session's stored files.
- `POST /api/sessions/<id>/prompt` body `{prompt, reasoning_effort?}`; an effort override is persisted,
  then the running turn is interrupted and the new prompt is sent.
- `POST /api/sessions/<id>/mode` body `{mode}`.
- `POST /api/sessions/<id>/effort` body `{reasoning_effort}`; persists `low`, `medium` or `high` for every
  future turn and returns the updated session.
- `POST /api/sessions/<id>/stop`
- `GET /api/sessions/<id>/stream` => SSE `delta`, `user`, `status`, `done`, `error`, `stats`
- `GET /api/settings`, `PUT /api/settings` body `{max_sessions}`
- `GET /api/stats` => active and queued sessions, running processes, token usage and a `session_status` map keyed by
  session ID.
- `GET /api/live?since=<rev>&wait=<ms>&workspace=<id>` => the live feed, below.
- `GET /api/tasks/overview` => `{workspaces: [{id, name, goals, sessions}]}`, the tasks of every
  workspace in one answer (the "All tasks" view asks each node once).

`origin` says who started the session: `web` (a route of this API over HTTP), `net` (a gateway
or another node, `ai_task_add` / `ai_request`), empty (a scheduled goal, a tool of an agent).
It is in the `task_finished` event, so a gateway does not announce a session of the web
interface in a chat.

### The running turn as items (`turn`)

The event window (`events`, 300 entries) is token deltas: a long turn overruns it, and a page
that opens the session in the middle of a turn could show only its tail. `SessionManager`
therefore folds the stream of the running turn into items as it passes
(`turn_log_add`, memory only, reset by every prompt):

```json
[{"kind":"user","text":"..."},
 {"kind":"reasoning","text":"the whole block"},
 {"kind":"text","text":"..."},
 {"kind":"tool","id":"call_1","name":"read_file","args":{"path":"a.txt"},
  "state":"running|ok|failed","result":{...},"sub":false},
 {"kind":"milestone|notice|error","text":"..."}]
```

Deltas of one reasoning / text block are one item; a tool call is one item that gets its
result; the tool calls of sub-agents are in it (`sub`), their text is not. At most 600 items
(the prompt stays) and 400 000 characters per text item. A finished turn is read from
`chat.json`, which has all of it. A tool result longer than 16 000 characters is clipped to
its head and tail in the event and the item (`result_truncated`); `chat.json` keeps it whole.

### Live feed (`GET /api/live`)

What a dashboard shows of a node changes rarely and then at once. Polling it on a timer was
both late and wasteful, and redrawing on every poll made the page flash (#1015). `LiveFeed`
looks at the state every 250 ms and counts `rev` up when it differs:

```json
{"rev":42,"tree_rev":3,"goals_rev":7,
 "sessions":[{"id","workspace_id","title","status","mode","token_usage","created"}],
 "stats":{...},"settings":{"max_sessions":2},"notifications":5,"peers_rev":12}
```

- `since` behind `rev`: answered at once. Otherwise the answer is held until something
  changes or `wait` ms passed (at most 25 s), then sent as it is.
- `tree_rev` counts changes of the workspace list (reload `GET /api/workspaces`),
  `goals_rev` the goals and the dispatched runs of the workspace named by `workspace`
  (reload its tasks), `notifications` their number (reload them when it differs),
  `peers_rev` the node list (`GET /api/nodes`; only a node on ShizoNet has it).
- A session row has no `updated` on purpose: it moves with every streamed token and would
  wake every page all the time. Token usage moves with each model call.

The same route works for another node through `/api/nodes/<id>/api/live`.

## Session agent protocol

`workspace_agent.shio` runs in the workspace directory, with `--workspace`, `--config-spec`,
`--session-id`, `--history-file`, `--reasoning-effort`, `--role`, `--mode`. It reads
`<workspace>/.env/vars` at session start when the file exists (`KEY=VALUE` lines; blank lines and
`#` comments are ignored) and exports every variable with `std.set_env`, so the command tools of
`roles/SHARED.shio` inherit them in the commands they run. The spec is a
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

- `add_task(name, goal, role)` -> session id (empty = process start failed; a busy slot returns a `queued` task)
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

Single page at `/` (`web/readme.md`). Sidebar: the **nodes** of the network (collapsible), under
each its recursive workspace tree with the sessions of a workspace below it; all tasks,
settings, live stats. Main: selected workspace header, chat with normal/loop toggle, tasks
tab, architecture graph tab. Every call of the page goes through `NodeApi.at(<node id>)`:
the node the page comes from directly, another one under `/api/nodes/<id>` — the routes of
this spec are the same for both.

Selecting a different session only replaces the browser's SSE listener; it never stops the
session worker. On selection the dashboard loads `GET /api/sessions/<id>`: the finished turns
from the complete `chat.json` transcript, the running turn from `turn`, then resumes the SSE
stream from `turn_seq`; it does not rebuild the transcript from the bounded
`session.json.events` window. For a terminal session, the dashboard
also renders the stored `session.report` (or the `done` event report) as a report bubble, even if
`chat.json` already contains the final assistant text, so the finalize report survives a
session switch.

Reasoning and tool calls are one line each and open on a click: the whole reasoning text,
every parameter of the call and its result. Nothing is refreshed on a timer: the page holds
one `GET /api/live` long-poll per node it shows and patches the elements that differ.
SSE keeps the chat fluid; animations for running/working states. No CDN.
The session agent initializes the workspace goal store and registers the validated `get_goals`,
`create_goal`, `create_recurring_goal`, `update_goal`, `set_goal_status`, and `run_goal_now` tools plus
`create_workspace_task` for one-off tasks. In the goal engine, a recurring task is a recurring Goal, not a
separate task system or just an abstract objective. Chat workers must use `create_recurring_goal` for repeated
work (weekdays or an interval such as `every: 5m` or `every: 2d`); `create_workspace_task` is strictly one-off. Sub-day intervals run continuously from activation and need no time window. A recurring goal is created active by default (`activate=yes`); pass `activate=no` to keep it proposed until the user approves activation.
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
  `POST /api/workspaces/<id>/goals/<goal_id>/status` moves a proposed goal to active/paused. With
  `clear_dry_run: "yes"` and `status: "active"`, it first edits the goal policy to `dry_run: false`
  so the scheduler dispatches a worker; without it, an activated dry-run goal only writes the prompt
  to history.md and stays quiet.
- The dashboard has one sidebar. Selecting a workspace refreshes the already-open Architecture or Tasks tab; task responses
  from a previous workspace are ignored. Goal cards show a dispatched
  run as Running, with its session, independently of the goal's configured status. The `+` of a
  workspace opens the composer; the first prompt creates the session (its title is the prompt).
  Tasks are split into Running now, Needs input, Scheduled, Proposed, Finished and Invalid.
  Architecture has Analyze, Review plan, Apply and Discard buttons and imports an existing legacy model.
- (#1015) The Tasks views were reloaded every five seconds and rebuilt, which showed as a
  flash every refresh. They are reloaded when `goals_rev` or a session changes and patched in
  place (a card whose content is the same is not touched).

## Listener lifecycle and compaction

`Workspace.add_task_finished_listener(cb, owner)` forwards the owner tag to the shared
`SessionManager`; `GoalScheduler` registers with `goal:<workspace_id>` and `ArchitectureBoard`
with `arch:<path>`. `Workspace.stop()` unregisters both before releasing them, so a later session
finish does not call a listener whose captured `this` is gone (`class not valid`).

The session agent's compaction handover run is internal: its streamed text/tool deltas are
suppressed (`internal_run`), and after `finalize` the agent clears `stopped` so the real prompt
still runs. The web UI therefore shows one real answer per turn, not the handover draft plus a
second answer. `compaction_requested` is reset after each handover, so a long task can compact
repeatedly; the warning run's report is consumed as a handover, and the original task prompt is
restored. A warning run that finalizes with `finished` is still a handover, not the task result.

