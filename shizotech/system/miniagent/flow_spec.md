# miniagent runtime flow: web UI, Telegram gateway, goals and finalize

This is the operational contract after the workspace refactor. It describes what actually
happens when a prompt is sent from the web UI or from the Telegram gateway, which directories
are read, how a workspace session subprocess is spawned, and how a task's terminal state
reaches the owner.

## 1. Storage roots (no current-working-directory dependency)

```text
std.user_path()/miniagent/           (--data-dir <dir> moves this root)
  node/                              the Node's own workspace ("General", id "node")
    .agentspace/                     node-level goals, preferences, ledger
    .megamind/sessions/<sid>/        its sessions: session.json, chat.json, chat.json.result.json
    .megamind/architecture/          node-level architecture graph
  workspaces/                        WorkspaceRegistry root
    workspaces.json                  registry (id, name, path, parent, description)
    settings.json                    max_sessions
<any folder>/                        a real project workspace (registered by path)
  .agentspace/                       that workspace's goals, preferences, ledger
  .megamind/sessions/<sid>/          session.json, chat.json, chat.json.result.json
  .megamind/architecture/            that workspace's architecture graph
<cwd of the node>/workspaces/<name>/ where a workspace created WITHOUT a path gets its folder
```

`miniagent_storage.shio` owns the path helpers. `node_lib.shio`, `goals.shio`, `web_ui.shio` and
`workspaces.shio` use them, so starting a node from any directory does not create `./.agentspace`.
The runnable node is a `Node` class (`node_lib.shio`); it owns a `WorkspaceRegistry`, its own
node Workspace, the route table of the API and the ShizoNet `AiService`
(`node_architecture.md`). There is no receptionist agent on a node (#1015). `WorkspaceRegistry`
loads and instantiates every `Workspace` from `std.user_path()/miniagent/workspaces`, owns one
shared `SessionManager`, and `WorkspaceStore` owns `workspaces.json` and `settings.json`.

The registry root is a container, not a project workspace; it has no `.agentspace`. Every real
workspace scheduler starts when the node/web UI starts, and a newly created workspace gets its
scheduler immediately.

## 2. Web UI prompt flow

`shz miniagent --node --web`:

1. `__init__.shio` sees `--node` / `--web` / `--init` and loads `node.shio`
   (`--telegram-gateway` loads `telegram_gateway.shio`; `--web` without `--node` still starts
   the node and says so). `--init [<dir>]` registers the directory (default: cwd) and returns
   before any model/ShizoNet/web startup.
2. `node.shio` creates a `Node` (`node_lib.shio`): a `WorkspaceRegistry`, the Node's own
   `Workspace`, the API route table and the ShizoNet AI node service. `--workspace <dir>`
   registers folders first.
3. `Node.start_node_goals()` starts the Node's own Workspace `GoalScheduler` on
   `std.user_path()/miniagent/node/.agentspace` (unless `--no-goals` / `--agentspace` says
   otherwise), with `workspace_id = "node"`.
4. The `WorkspaceRegistry` starts every registered real workspace scheduler at node startup,
   before the web UI or API is bound. Each `Workspace` owns its `ArchitectureBoard` and
   `GoalScheduler`; the registry owns one shared `SessionManager` for all workspaces.
5. `web_ui_start()` starts the HTTP server on port 13337 (or `--port`) on the route table
   (Node JSON API, workspace API, gateway settings) and adds the routes for the other nodes
   (`GET /api/nodes`, `/api/nodes/<id>/api/...`: the same API of a peer, asked over ShizoNet
   with `ai_api`). The dashboard is the connector to the registries; it holds no task or
   architecture data of its own. When the gateway settings say so, `GatewayRunner` starts
   `shz miniagent --telegram-gateway` as a process of its own.
6. The workspace API is backed by the `WorkspaceRegistry`:
   - `GET /api/workspaces` -> tree, settings, stats
   - `POST /api/workspaces/<id>/sessions` -> new session (title, mode, prompt, reasoning_effort)
   - `POST /api/sessions/<id>/prompt` -> prompt into an existing session
   - `POST /api/sessions/<id>/effort` -> persist low/medium/high reasoning effort for future turns
   - `GET /api/sessions/<id>/stream` -> SSE (`delta`, `user`, `status`, `done`, `error`, `stats`)
   - `GET /api/sessions/<id>` -> the session with its saved chat and, while a turn runs, the
     turn so far as items (`turn`, `turn_seq`): a page that opens it later draws all of it and
     takes the stream from `turn_seq`
   - `GET /api/live` -> the change feed the page long-polls instead of polling on a timer
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
    - loads `<workspace>/.env/vars` at startup when it exists and exports each `KEY=VALUE` line
      with `std.set_env`; the `SHARED.shio` command tools run in this process and inherit them;
    - loads `chat.json` (the complete conversation, source of truth) and imports it into the agent;
   - creates `GoalSpace(workspace + "/.agentspace")` and a `GoalScheduler` for its goal tools;
    - rescans that local scheduler once at startup (`notify = false`) so `get_goals` sees the
      goals that already exist; the registry scheduler, not this local one, dispatches windows;
    - goal tools rescan after create / update / status changes, so a new or moved goal is visible
      to the next `get_goals` call;
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
    - `max_sessions` is the number of sessions that run at once. When every slot is busy the session is
      created with `status = "queued"` (not refused); `SessionManager.dispatch_queue()` starts queued
      sessions FIFO when a session finishes, is stopped or is deleted, and when `max_sessions` is raised.
      A queued task is still open for the goal scheduler and the router (`state = "queued"`).
    - The Node's own workspace scheduler works the same way for
      `std.user_path()/miniagent/node/.agentspace`; there is no node-level worker pool.

## 3. Telegram gateway prompt flow

`shz miniagent --telegram-gateway [--bot-token ...]` (not a node; a node starts it as a
process of its own when the settings of the web interface say so):

1. `TelegramRouter(cfg, opts)` builds a `Router` (a `miniagent` with the `router` role) and
   starts the ShizoNet router service. The token comes from `--bot-token` or the saved
   settings (`gateway_config.shio`); without one it exits with code 2.
2. The chat list is read from `trusted_chats` (default `std.config_path("miniagent",
   "trusted_chats")`). No file / empty list -> the first chat that messages the bot becomes the
   owner chat and is written to disk. Unknown chats are ignored; the owner chats are told once
   that a chat knocked. An entry with `role = "guest"` is bound to one node + workspace.
3. The bot transport's `on_any_message` calls `TelegramRouter.tg_handle_message`:
   - text and text documents (`.md`, `.txt`, `.json`, code, up to 256 KB) are accepted;
   - the caption of a document is the instruction;
   - a burst of messages from the same chat within 1500 ms becomes one turn;
   - commands such as `/nodes`, `/tasks`, `/status`, `/goals`, `/goal ...`, `/allow`, `/deny`,
     `/forget`, `/guest ...`, `/guests`, `/help`, `/id` are handled locally or in the worker
     thread; a guest chat has `/help /new /stop /status /id`.
4. `tg_worker()` sends queued notifications and runs one router-agent turn at a time.
   Telegram HTTP never runs on the ShizoNet thread.
5. An **owner** message is one router-agent turn (`roles/router`). The prompt is a
   `<context>` block (`Router.turn_context(chat)`: the threads of this chat, the nodes with
   their workspaces) followed by the message; `Router.turn_text` holds the message verbatim and
   `Router.turn_origin = [chat]`. The agent has `get_nodes`, `get_node_overview`, `get_tasks`,
   `get_goals`, `start_task`, `update_task`, `stop_task`, `inspect_task`, `get_last_actions`,
   `notify`, `finish(report)`. It picks node **and workspace** from the table; it does not
   keyword-match, and it asks back when it cannot place the message.
   A **guest** message skips the agent: it starts a thread in the guest's workspace or
   continues the guest's current one.
6. `Router.add_task(name, goal, node, "worker", workspace)`:
   - refuses an unknown/offline node and an unknown workspace with a concrete reason;
   - is idempotent for the same goal on the same node + workspace while the task is open;
   - sends `ai_task_add`: a worker session in that workspace (`origin = "net"`), no agent in
     between. The mirror record is a **thread** (`T<n>`, `remote_taskid` = the session id);
   - mode `request` sends one blocking `ai_request` turn instead (`Router.delegate`).
   `Router.update_task(thread, message)` sends `ai_task_update`: into the running turn, or as
   a new turn of the finished session (the thread is reopened).
7. The router poller (`poll_ms`, default 1000) polls open mirror records:
   - `ai_task` for worker threads;
   - `ai_request_poll` for request turns;
   - node refresh every 5 s; the router announces node online/offline itself.
8. Terminal task states are mirrored and emitted as `task_state`:
   `queued | generating | finished | failed | question | stopped | lost`.
   `task_finished` from the Node is deduplicated against the poller transition; Telegram
   keeps one terminal message per **turn** of a thread (`taskid#turn`). The message goes to
   the chat that started the thread (`origin_chat`), what no chat started to the owner chats.
   A session of the web interface (`origin = "web"`) is not announced.
9. `lost` is definitive only: after the node has been offline for the grace period
   (`ROUTER_TASK_LOST_GRACE_MS`) or after a definitive `not found` with no report. Transient
   poll failures keep the task open and only update `last_error`. The node's completed
   `ai_request` stays pollable for one hour (`AI_REQUEST_TTL_MS`), so a late poll does not
   turn a completed task into `lost`.
10. Telegram notifications are the owner-facing sink: `task_state` terminal, `task_stalled`,
    node `notify`, and `file` (send_file) are rendered with the place of the task
    (`T12 · GPUBox / Shop Frontend`). Node online/offline, running progress,
    and tool calls are silent unless `--verbose-events` is used.
11. The thread table is saved (`gateway_threads.json` next to the trust file) and loaded at
    start, so a follow-up after a restart of the gateway still reaches its session.

## 3b. Isolated Telegram client (`telegram_client.shio`)

`shz miniagent.telegram_client --bot-token ... --workspace_dir <dir>` creates one project
workspace with a private registry under `<workspace_dir>/.client_registry`; it does not use the
node's ShizoNet service or workspace tree. The receptionist agent runs 24/7 and answers trusted
chats; it also has read-only workspace file tools so it can answer questions about the workspace
immediately, without waiting for the worker or its work window. `Workspace.add_task` is called
only inside the configured local work window. Requests outside the window are queued in
`ClientMind.queue` and dispatched when the window opens; active worker sessions are stopped at
close. The GoalScheduler is hosted by `ClientMind`, so it obeys the same window and queue. Reports
longer than the message limit and `send_file` documents are sent as Telegram documents.

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
## 13. Compaction, handover and listener lifecycle

- An internal compaction run (`compact_handover`) is not a user turn. `miniagent` sets
  `internal_run` while the handover model call runs, so its `text`, `reasoning`, `tool_start` and
  `tool_end` deltas are not streamed to the web UI. The session's chat shows only the real turn
  (and its final `done` report).
- `compact_handover` calls the model with `finalize`, which sets `stopped=true`. A successful
  handover must reset `stopped=false` and `running=true` before the real task continues; otherwise
  `task()` returns `failed` with "Agent was stopped during its run." The web UI then shows a
  failed session after a perfectly good compaction.
- The `on_usage` context warning is injected once per compaction episode (`compaction_requested`),
  and the flag is reset after the handover, so a long open-ended task can compact repeatedly,
  not only once.
- A warning run that finalizes with `finished` is treated as a handover, not as the task's
  terminal result; the real task prompt is restored after every compaction.
- A stopped / deleted `Workspace` removes its scheduler and architecture-board task-finished
  listeners by owner (`remove_task_finished_listener(owner)`). A listener whose captured `this`
  was released otherwise throws `class not valid`, printed as `[workspaces] finished listener failed`.

