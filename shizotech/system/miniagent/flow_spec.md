# miniagent runtime flow: web UI, Telegram router, goals and finalize

This is the operational contract after the workspace refactor. It describes what actually
happens when a prompt is sent from the web UI or from the Telegram router, which directories
are read, how a workspace session subprocess is spawned, and how a task's terminal state
reaches the owner.

## 1. Storage roots (no current-working-directory dependency)

```text
std.user_path()/miniagent/
  node/                              the Node's own goal/architecture store
    .agentspace/                     node-level goals, preferences, ledger
    .megamind/architecture/          node-level architecture graph
  workspaces/                        WorkspaceRegistry root (the root Workspace)
    workspaces.json                  registry
    settings.json                    max_sessions
    .megamind/sessions/<sid>/        root Workspace sessions: session.json, chat.json, chat.json.result.json
    .megamind/architecture/          root Workspace architecture graph
    <workspace>/                     a real project workspace
      .agentspace/                   that workspace's goals, preferences, ledger
      .megamind/sessions/<sid>/      session.json, chat.json, chat.json.result.json
      .megamind/architecture/        that workspace's architecture graph
```

`miniagent_storage.shio` owns the path helpers. `node.shio`, `goals.shio`, `web_ui.shio` and
`workspaces.shio` use them, so starting a node from any directory does not create `./.agentspace`.
The runnable node is a `Node` class (`node.shio`); it owns a `WorkspaceRegistry`, the registry's
`root` Workspace as its own node Workspace, the `Receptionist` connector, and the ShizoNet
`AiService` (`node_architecture.md`). `WorkspaceRegistry` loads and instantiates every `Workspace`
from `std.user_path()/miniagent/workspaces`, owns one shared `SessionManager`, and `WorkspaceStore`
owns `workspaces.json` and `settings.json`.

The registry root is a container, not a project workspace; it has no `.agentspace`. Every real
workspace scheduler starts when the node/web UI starts, and a newly created workspace gets its
scheduler immediately.

## 2. Web UI prompt flow

`shz miniagent --web` (or `shz miniagent.node --web`):

1. `__init__.shio` sees `--web` / `--node` / `--web=<port>` and loads `node.shio`.
2. `node.shio` creates a `Node`: a `WorkspaceRegistry`, the Node's own `Workspace`, one
   `Receptionist` connector (a single receptionist agent), and the ShizoNet AI node service.
3. `Node.start_node_goals()` starts the Node's own Workspace `GoalScheduler` on
   `std.user_path()/miniagent/node/.agentspace` (unless `--no-goals` / `--agentspace` says
   otherwise), with `workspace_id = "node"`.
4. The `WorkspaceRegistry` starts every registered real workspace scheduler at node startup,
   before the web UI or API is bound. Each `Workspace` owns its `ArchitectureBoard` and
   `GoalScheduler`; the registry owns one shared `SessionManager` for all workspaces.
5. `web_ui_start()` starts the HTTP server on port 13337 (or `--port`), registers the Node JSON
   API, the chat protocol, and the workspace API. The dashboard is the connector to the
   registry; it holds no node-scoped task or architecture data.
6. The workspace API is backed by the `WorkspaceRegistry`:
   - `GET /api/workspaces` -> tree, settings, stats
   - `POST /api/workspaces/<id>/sessions` -> new session (title, mode, prompt, reasoning_effort)
   - `POST /api/sessions/<id>/prompt` -> prompt into an existing session
   - `POST /api/sessions/<id>/effort` -> persist low/medium/high reasoning effort for future turns
   - `GET /api/sessions/<id>/stream` -> SSE (`delta`, `user`, `status`, `done`, `error`, `stats`)
7. Creating a session (`Workspace.add_task` / `SessionManager.create_session`) writes
   `session.json` and `chat.json` below the workspace's `.megamind/sessions/<sid>/`, then spawns
   a subprocess in the workspace directory:

   ```text
   std.local_executable() workspace_agent.shio
       --workspace <workspace path>
       --config-spec <name|path[#profile]>
       --session-id <sid>
       --history-file <session dir>/chat.json
       --reasoning-effort low|medium|high
       --role adaptive
       --mode normal|goal
   ```

   `--config-spec` is the default model config or the Node's CLI worker config. No
   `config.json`, endpoint or API token is written next to the conversation.

8. `workspace_agent.shio`:
   - loads `chat.json` (the complete conversation, source of truth) and imports it into the agent;
   - creates `GoalSpace(workspace + "/.agentspace")` and a `GoalScheduler` for its goal tools;
   - registers `get_goals`, `create_goal`, `create_recurring_goal`, `update_goal`,
     `set_goal_status`, `run_goal_now`, `create_workspace_task`, `goal_finish`;
   - registers the architecture board at `workspace + "/.megamind/architecture"`;
   - emits one JSON object per stdout line: `ready`, `delta`, `stats`, `done`, `error`, `warning`.
   - emits `file` and `notify` protocol lines from the local `share_file` / `notify_user` hub.
9. The registry `SessionManager.pump()` thread reads those lines and updates `session.json`,
   pushes SSE events, calls the workspace `GoalScheduler` finished listener and the Node's
   additive listeners. `file` / `notify` protocol lines become listener events on the
   `SessionManager` (and fan out through `Node`). The chat itself is loaded from `chat.json`;
   `session.json.events` is only a bounded replay window, not a second transcript. The session
   agent serializes and retries `chat.json` snapshots after each turn and at tool starts; a transient
   save failure is a `warning`, not a terminal `error`, so the live answer still streams.
10. A new prompt while the turn is running:
    - `SessionManager.send_prompt()` sends `{"type":"prompt",...}` only.
    - `workspace_agent.shio`'s protocol reader calls `agent.task_update(text)` when the agent is
      running; it does not spawn a new task. If the agent is idle, the prompt is queued as the
      next turn. `task_update` ends the current generation and continues the same running task
      with the injected prompt.
    - `{"type":"interrupt"}` remains an explicit stop channel (no prompt attached).
11. Terminal result:
    - the adaptive `finalize` tool is the single model endpoint:
      `finalize(signal=finished|failed|question|continue, result=...)`;
    - `run_turn()` reads `agent.task_result.signal` and `.result` and emits
      `{"type":"done","status":"finished|failed|question|stopped",...}`.
      `stopped` is the runtime state for an intentional stop, not a model signal.
    - `goal_finish(status=finished|failed, report=...)` is an alias that sets the same
      `task_result` (used by Loop mode).
    - a `question` is terminal and needs the owner; it is not mapped to `failed`.
    - an exited subprocess with a matching `chat.json.result.json` is recovered as
      `finished|failed|question|stopped`; an exit without a terminal result is reported as
      `failed` with the reason, unless the manager's `stop_requested` flag says the exit was
      an intentional stop (`stopped`). It is not silently restarted.
12. Scheduled goals in a workspace:
    - `GoalScheduler` ticks every 15 s, rescans the workspace `.agentspace`, activates windows
      exactly once, and calls `Workspace.add_task(...)`.
    - `Workspace.add_task` calls the shared `SessionManager.create_session(workspace_id, name, "normal",
     goal, "adaptive")`, i.e. the goal run is a subprocess session in that same workspace
      directory. The scheduler settles it through `inspect_task` / the finished listener.
    - The Node's own workspace scheduler works the same way for
      `std.user_path()/miniagent/node/.agentspace`; there is no node-level worker pool.

## 3. Telegram router prompt flow

`shz telegram_router.shio --bot-token ...`:

1. `TelegramRouter(cfg, opts)` builds a `Router` (a `miniagent` with the `router` role) and
   starts the ShizoNet router service.
2. The trusted-chat list is read from `trusted_chats` (default `std.config_path("miniagent",
   "trusted_chats")`). No file / empty list -> the first chat that messages the bot becomes the
   trusted chat and is written to disk. Untrusted chats are ignored.
3. The bot transport's `on_any_message` calls `TelegramRouter.tg_handle_message`:
   - text and text documents (`.md`, `.txt`, `.json`, code, up to 256 KB) are accepted;
   - the caption of a document is the instruction;
   - a burst of messages from the same chat within 1500 ms becomes one turn;
   - commands such as `/nodes`, `/tasks`, `/status`, `/goals`, `/goal ...`, `/allow`, `/deny`,
     `/forget`, `/help`, `/id` are handled locally or in the worker thread.
4. `tg_worker()` sends queued notifications and runs one router-agent turn at a time.
   Telegram HTTP never runs on the ShizoNet thread.
5. The router-agent turn (`roles/router`) gets `get_nodes`, `get_node_overview`, `get_tasks`,
   `start_task`, `update_task`, `stop_task`, `inspect_task`, `get_last_actions`, `notify`,
   `finish(report)`. The agent reads the node table and picks a node; it does not keyword-match.
6. `Router.add_task(node, goal)`:
   - refuses an unknown/offline node with a concrete reason;
   - is idempotent for the same goal on the same node while the task is open;
   - default mode `receptionist` sends `ai_request` to the Node's `Receptionist` connector and
     stores the mirror record with `remote_request_id`;
   - mode `worker` sends `ai_task_add` to a `Workspace`; an optional workspace id defaults to
     the Node's own workspace.
7. The router poller (`poll_ms`, default 1000) polls open mirror records:
   - `ai_request_poll` for delegated receptionist turns;
   - `ai_task` for workspace tasks;
   - node refresh every 5 s; the router announces node online/offline itself.
8. Terminal task states are mirrored and emitted as `task_state`:
   `queued | generating | finished | failed | question | stopped | lost`.
   `task_finished` from the Node is deduplicated against the poller transition; Telegram also
   keeps one terminal message per taskid. A plain finished goal run produces one terminal task
   message, not a second goal-status message.
9. `lost` is definitive only: after the node has been offline for the grace period
   (`ROUTER_TASK_LOST_GRACE_MS`) or after a definitive `not found` with no report. Transient
   poll failures keep the task open and only update `last_error`. The node's completed
   `ai_request` stays pollable for one hour (`AI_REQUEST_TTL_MS`), so a late poll does not
   turn a completed task into `lost`.
10. Telegram notifications are the owner-facing sink: `task_state` terminal, `task_stalled`,
    node `notify`, and `file` (send_file) are rendered. Node online/offline, running progress,
    and tool calls are silent unless `--verbose-events` is used.

## 4. The single finalize contract

| State | Produced by | Meaning |
|---|---|---|
| `finished` | `finalize(signal=finished, result)` / `goal_finish(status=finished)` / a normal turn result | the task met its contract; result is the report |
| `failed` | `finalize(signal=failed, result)` / `goal_finish(status=failed)` / crash, API failure, exit without result | the task could not complete; result is the reason |
| `question` | `finalize(signal=question, result)` | terminal; the owner must answer before work continues |
| `continue` | `finalize(signal=continue, result)` | hand-over; not terminal for the task, the same task continues with a fresh context |
| `stopped` | `stop_task`, window end, pause/cancel | the task was intentionally stopped |
| `lost` | router only | the node/task is definitively gone after grace or a definitive not-found |

The model does **not** invent `lost`; it emits `finished`, `failed`, `question` or `continue`.
`stopped` and `lost` are transport/runtime observations, not model signals. This keeps the
Telegram messages truthful: a task with a complete execution log is not reported as lost
because a poll hiccupped.
The node-side protocol enforces one terminal event per task turn: `SessionManager.finish_terminal`
dedupes by session id, `GoalScheduler.settle_runs` dedupes by taskid/run, and the goal scheduler
does not notify a plain finished run again. Notify, file and task-finished hooks are additive
on `SessionManager` / `Workspace` / `Node` (`add_notify_listener`, `add_file_listener`,
`add_task_finished_listener`); the web API and ShizoNet service both register them instead of
overwriting each other.
