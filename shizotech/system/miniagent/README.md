# miniagent

The idea is

```
'shz miniagent'          -> starts __init__.shio, very simple direct action agent
'shz miniagent --web'    -> a node with its web interface: chat, tasks and the
                            architecture graph of the codebase (see "Web interface")
'shz miniagent.node'     -> starts a node for an AI expert sitting on this machine and taking
                            in requests, supported web-api and shizonet (shizonet preferred)
'shz miniagent.router'   -> starts the router: it detects the AI nodes in the private
                            network and routes tasks to them
```

In script
```
#include "miniagent/miniagent"
```
can be used.

## The pieces

| File | What it is |
|---|---|
| `model_config.shio` | `ModelConfig()` — endpoint/model/generation config, flat and profile JSON layouts |
| `model_config_cli.shio` | shared CLI config resolver: named configs, cwd search, profiles, create/list/save |
| `miniagent.shio` | the agent class: role loading, tools, subagents, LLM turn loop |
| `megamind.shio` | legacy `Megamind()` worker-pool code; the Node's `Receptionist` connector lives in `node.shio` |
| `node.shio` | `Node` — the runnable **AI node**: one `WorkspaceRegistry`, its own node `Workspace`, the `Receptionist` connector, one ShizoNet service, and optional web/API (`node_architecture.md`) |
| `workspaces.shio` | `Workspace`, `WorkspaceRegistry`, `WorkspaceStore`, `SessionManager` and the workspace API |
| `node_architecture.md` | the durable `Node` / `WorkspaceRegistry` / `Workspace` / terminal-protocol contract |
| `router_api.shio` | `Router()` — the runtime of the **router agent**: a `miniagent` with the `router` role decides which node owns a request, this class executes it over ShizoNet, mirrors the remote task state and forwards node events |
| `router.shio` | a **demo** CLI around `Router()` |
| `telegram_router.shio` | `TelegramRouter : Router` — the Telegram front end: trusted-chat access control + every node event pushed into the chat |
| `shizonet_ai.shio` | the node ⇄ router wire protocol (both sides, one place) |
| `node_api.shio` | optional JSON web API of a `Node` (`--webserver` / `--port`) |
| `telegram_client.shio` | `shz miniagent.telegram_client --bot-token ... --workspace_dir <dir>` — an isolated Telegram client for one workspace: 24/7 receptionist, worker only in a configured local window, no ShizoNet |
| `web_ui.shio` + `web/` | the web interface of a `Node` (`--web`): the workspace dashboard on top of the JSON API |
| `architecture.shio` | the architecture graph: a workspace's `.megamind/architecture/architecture.json`, plus the node-level graph under `std.user_path()/miniagent/node/.megamind/architecture`; pending edits, analyze / plan / apply jobs (`architecture_spec.md`) |
| `goal_engine.shio` | scheduled goals: `.agentspace/` Markdown goals, validation, the deterministic `GoalScheduler` (`goals_spec.md`) |
| `goal_time.shio` / `goal_frontmatter.shio` | time zones + DST, work windows / the front matter reader and writer |
| `goal_tools.shio` | the receptionist's goal tools (create / update / pause / run) |
| `goals.shio` | `shz miniagent.goals ...`: list, validate, run, pause, history, diff |
| `agent_slots.shio` | `max_running_agents` accounting: a waiting parent lends its slot to a child |
| `miniagent_storage.shio` | the one global storage root (`std.user_path()/miniagent`) shared by node, goals and workspaces |
| `flow_spec.md` | the runtime flow: workspace registry, web UI session subprocess, Telegram router path, the single finalize contract |
| `roles/` | the AI roles: `receptionist`, `router`, `adaptive`, `single_action/*`, `util/*` |

## Model configs

The runnable scripts share one config story:

```
shz __init__.shio --config gpu
shz router.shio --config router-fast
shz telegram_router.shio --bot-token ... --config router-fast

shz node.shio --config gpu
shz node.shio --receptionist-config chat --worker-config gpu
shz node.shio --worker-config ./endpoints.json#worker
```

A config spec can be:

- a plain name: `gpu`
- a file path: `./configs/gpu.json`
- a profile inside a file: `./endpoints.json#worker`

Plain names are searched in this order:

1. current working directory (`gpu.json`)
2. `.agent/configs/gpu.json`
3. the default ShizoScript config directory

New plain-name configs are created in the current working directory, so a project
can carry its own endpoint files.

Useful CLI commands:

```
--list-configs
--config-path
--new-config <name|path[#profile]>
--save-config <name|path[#profile]>
--config-url <url> --config-token <token> --config-model <name>
--config-context <tokens> --config-agents <n>
```

For `node.shio`, the receptionist connector and workspace sessions can use different endpoints:

```
shz node.shio \
  --new-receptionist-config chat \
  --receptionist-url http://localhost:8000 \
  --receptionist-model small-chat

shz node.shio \
  --new-worker-config gpu \
  --worker-url http://localhost:8001 \
  --worker-model big-coder \
  --worker-context 128000 \
  --worker-agents 8

shz node.shio --receptionist-config chat --worker-config gpu
```

The same file can store multiple endpoints as profiles:

```
{
  "profiles": {
    "default": {"url": "http://localhost:8000", "name": "chat"},
    "worker": {"url": "http://localhost:8001", "name": "coder"}
  }
}
```

Then use:

```
shz node.shio --config ./endpoints.json#default --worker-config ./endpoints.json#worker
```

Workspace sessions receive the default config or the `--worker-config` spec as `--config-spec`;
no endpoint or API token is stored per session.

## Web interface

```
shz miniagent --web                          (= shz miniagent.node --web)
shz miniagent --web --port 8080 --api-token secret --config gpu
```

Starts a `Node` (receptionist connector, `WorkspaceRegistry`, ShizoNet like `node.shio`) and serves
http://localhost:13337/ — every page works offline (no CDN):

* **Chat** — talk to the Node's receptionist (`/api/adminagent`, the chat page's protocol).
* **Tasks** — workspace tasks: running / planned with live output, finished ones with
  their report; start a task, send an update, stop it.
* **Architecture** — the codebase as a per-workspace node graph (`architecture_spec.md`). On first use
   *Analyze the codebase* lets a workspace task agent write the workspace's
   `.megamind/architecture/architecture.json` (modules, files, services with a one-line purpose;
   calls / data / includes / events / network between them). Add, change, connect or remove nodes
   on the graph: the edits stay **pending**. *Review plan* lets a task agent write a plan for them
   (no code changes), you give feedback and revise it; *Apply* lets a task agent implement them,
   and when it finishes the edits become the model. *Re-sync* analyzes again (positions and pending
   edits stay). Each job is one `adaptive` workspace task; a big change set is split into subtasks
   (one per group of edits) within `max_running_agents` — `architecture_spec.md`, "Context".

With `--api-token` the pages ask for the token once. The JSON API (`node_api.md`) is the
same as with `--port`, its index moves to `/api`.

## Initializing a workspace

```
shz miniagent --init          (= shz miniagent.node --init)
```

Registers the current directory as a project workspace under
`std.user_path()/miniagent/workspaces`, creates its `.megamind` and `.agentspace`, and writes a
short `AGENTS.md` if the directory has none. It returns without starting the node, ShizoNet,
goals or the web UI. The workspace then shows in the web UI tree. Every newly created workspace
also gets `AGENTS.md` when it is missing; an existing project `AGENTS.md` is never overwritten.

## Goals (scheduled autonomous work)

A node can run work on its own at set times: "tonight, explore a new app idea", "every Sunday
clean up the repository", "check the server logs every 2 days at 06:00" (`schedule.every: 2d`) or
"check the service every 5 minutes" (`schedule.every: 5m`),
"fix GitHub issues from 05:00 to 10:00". Goals are Markdown files in
`.agentspace/goals/<status>/<id>/goal.md` (front matter = schedule + policy, body = the
instructions); the Node's own workspace scheduler — plain code — activates each window exactly once, applies
the stop policy at the window end, retries, verifies and reports. Contract: `goals_spec.md`.
The Node's own goal store is `std.user_path()/miniagent/node/.agentspace`; every project workspace
also has its own `.agentspace`, and all registered workspace schedulers run at node startup.

```
shz miniagent.goals init                 create the Node's own goal store .agentspace/ (preferences, examples, templates)
 shz miniagent.node                       a node uses std.user_path()/miniagent/node/.agentspace
 shz miniagent.node --agentspace <dir>    ... or point it there
shz miniagent.goals list | show <id> | validate | run <id> [--dry-run] | pause <id> | history <id>
```

* Edit the files directly; an invalid edit is reported once and the last valid revision keeps
  running. Moving a goal folder (`active/` → `paused/`) is the status change.
* From the chat: "tonight, try X" reaches the Node's receptionist connector, which resolves "tonight" with
  `preferences/scheduling.md` and creates the goal through validated tools (`get_goals`,
  `create_goal`, `update_goal`, `set_goal_status`, `run_goal_now`). Goals that may merge,
  release or delete stay *proposed* until the owner says yes.
* Background work stays out of the way: `preferences/resource-policy.md` limits it
  (`max_background_tasks`, `reserve_interactive_workers`, `yield_after_interactive`).
* Telegram: `/goals`, `/goal pause <id>`; every start, missed window, result, question and
  refused dispatch of a goal arrives as a node notification.

## Parallel agents

`max_running_agents` (model config) counts agents that **generate** at the same time. Agents
form a tree and a parent that waits for its children does not generate, so a waiting parent
lends its slot to one child: a chain root → child → grandchild uses one slot; only the second
and further children running in parallel (fork siblings, batch items) take more. A workspace
session task takes its slot from `max_running_agents`; the receptionist connector does not (it
stays responsive).
`agent_slots.shio`, `tests/agent_slots_test.shio`.

## Router

The router is an **agent**, not a scoring function. `Router()` runs a `miniagent` with the
`router` role — the receptionist of a fleet of nodes — and that agent decides, with the model,
which node owns a request: it reads the routing table with `get_nodes()` and delegates with
`start_task()`. The node table (name, description, capabilities, tags, model, load) is data
for the agent. `Router` itself has no keyword matching, no capability scoring and no fallback
node: `add_task()` refuses an empty node name instead of guessing one.

`Router()` is a class, so it is built upon, not forked:

```
#include "router_api"

rtr = Router(cfg);                                  // role "router", shizonet server up

rtr.on_event([](e) { send_to_telegram(e); });       // node events -> your transport
rtr.on_notify([](m) { send_to_telegram(m); });      // node notifications
rtr.request("train the model with cuda");           // one router-agent turn: the agent routes
rtr.route_task("train the model with cuda");        // agent turn -> [ok, routed, taskid, node, answer]
                                                    // ok = the turn worked, routed = a task
                                                    // was delegated; a plain question is
                                                    // ok with routed = false
rtr.delegate("GPUBox", "summarize this repo");      // explicit node, no model
rtr.update_task(taskid, "use tabs");                // follow-up into the running turn
rtr.stop_task(taskid);
```

`on_event` is the **single** event stream and the router de-duplicates it: a node
coming online is announced once (the router's own discovery wins, the node's
`ai_event` push of the same state is dropped) and a finished task is announced
once (the poller's `task_state` carries the report, the node's `task_finished`
push of the same state is dropped). `on_notify` is a second sink for **local**
`notify_user()` only — register `on_event` *or* `on_notify`, not both, or your own
notifications reach the user twice.

One user goal is **one task**: `add_task` is idempotent (the same goal text on the same
node while that task is open returns the existing taskid), and the workspace session task
that executes a delegated request never becomes a second mirror entry — the router
adopts node work only when it is not already waiting on that node.

Subclass it directly:

```
class TelegramRouter : Router
{
    __init__(cfg, token) {
        super.__init__(cfg, [name = "TelegramRouter", description = "telegram front"]);
        on_event([this](e) { this.push(e); });
    }
    push(e) { /* telegram sendMessage */ }
}
```

### Telegram front end (`telegram_router.shio`)

That example, built for real: `class TelegramRouter : Router`.

```
shz telegram_router.shio --bot-token 123456:ABC...
    [--config <name|path[#profile]>]
    [--name TelegramRouter] [--role router] [--poll 1000] [--stall 900000]
    [--trusted <path>] [--no-stream] [--verbose-events]
    [--list-configs] [--new-config <name>]
```

* **Trusted chats.** The bot answers only chats listed in the `trusted_chats` json
  (default `std.config_path("miniagent", "trusted_chats")`, override with `--trusted`):

  ```
  {"chats":[{"chatid":123456,"name":"Peter","added":1700000000000}]}
  ```

  No file / empty list → **the first chat that messages the bot becomes the trusted
  chat** and is written to the file. Every other chat is ignored (console log only,
  the bot never answers strangers). `/allow <chatid> [name]`, `/deny <chatid>` and
  `/forget` edit the list from the chat; `/id` shows the chat id to put in the file.
* **Plain text** from a trusted chat is one router-agent turn; the answer goes back to
  that chat and the turn's progress streams as a Telegram draft (`--no-stream` off).
  The agent's `finish(report)` text is what you see: a job gets the routing
  confirmation, a question gets an answer — a turn that routes nothing is never
  reported as an error, and streaming never breaks a turn.
* **Notifications — only what matters.** The chat gets the router agent's answer, a task
  that **finished / failed / was lost / was stopped / asks a question on any node** (with the
  node's report, exactly one message per completion — the Router de-duplicates the node push
  and the poller transition; an empty report renders a visible fallback), a task that
  **stalled** (open for 15 minutes with no progress, once per episode, `--stall <ms>`), and a
  `notify` from a node (its report, or its question to the owner).
  **Failures carry the reason**: the `task_state` event's `error` (the node's error answer,
  "node offline", "no reply from node", ...) is rendered, a **refused delegation** is relayed
  by the router agent with the reason `add_task_error()` gives, and a goal run the node
  refuses is notified by the Node's own workspace scheduler — nothing fails silently. The Node's
   **receptionist report is the delivery channel**: `finish(summary)` becomes the task report
   (the receptionist turn result), so "Goals are not enabled on this node: ..." arrives as text
   instead of "Agent was stopped.".
  Node online/offline, queued/running progress and tool calls are **not** sent;
  `--verbose-events` restores the full event stream.
* **Follow-ups and files.** Messages a chat sends in quick succession are one turn (Telegram
  splits long texts, people correct themselves); every user message is recorded in the
  router's action ring, so `get_last_actions` resolves "make it 6am instead". A reply quotes
  the message it answers. A text document (`.md` plan, `.txt`, `.json`, code, up to 256 KB) is
  read, kept in `telegram_inbox/` next to the trust file, shown to the router agent and
  attached verbatim to the goal the turn delegates; its caption is the instruction.
* **Files to the chat.** A report longer than 2500 characters (a notify: 3500) is clipped in
  the message and attached in full as a `.md` document. The workspace agents and receptionist
   connector have `send_file(path, caption)`: the file travels as a `file` event
  (base64, up to 20 MB) to every router and arrives as a Telegram document.
* Commands: `/help` `/id` `/nodes` `/tasks [state]` `/status` `/goals [node]`
  `/goal <run|pause|resume|cancel|archive> <id> [node]` `/allow` `/deny` `/forget`.
  `/nodes` shows per node whether it runs a goal system (`goals`), so a schedule request aimed
  at a node that cannot schedule is visible before it is routed.
* Telegram HTTP never runs on the ShizoNet thread: `on_event` queues the text, the
  bot's own worker thread sends it (the `router_api.md` ground rule for handlers).

The router role (`roles/router/`) is a coordinator only: it gets `get_nodes`,
`get_node_overview`, `get_tasks` (the fleet-wide task mirror), `start_task`,
`update_task`, `stop_task`, `inspect_task`,
`get_last_actions`, `notify`, `finish(report)` — no file, command or execution tools, so it
cannot do the work it routes. It is the coordination surface of the local receptionist pointed at
**remote nodes**; unlike the local receptionist it has no workspace file tools, because it does
not own a local workspace: start / stop / update / check tasks across the network, and every node
notification lands on `on_event` so the owner can show it to the user.
`get_nodes` reports per node whether it has a goal system (`goals`), and the role relays every
tool error into its `finish(report)` — the concrete reason of a refused delegation
(`add_task_error()`), a schedule request aimed at a node without goals — so the user learns
*why*, not only *that* something did not happen (`roles/router/ROLE.md`, "Feedback to the
owner").

CLI (a demo application — the product is `Router()` + the `router` role):

```
shz router.shio                    console: plain text is a router-agent turn
                                      /nodes /tasks /overview [node] /route <text>
                                      /node <node> <text>  explicit delegation (no agent turn)
                                      /addworker <node> <name> <goal> /notify /config /configs /exit
shz router.shio --config router-fast
shz router.shio "task text"        single shot: one agent turn, print the answer
```

### Isolated Telegram client for friends (`telegram_client.shio`)

```
shz miniagent.telegram_client --bot-token <token> --workspace_dir <dir>
    [--work-start 09:00] [--work-end 17:00] [--timezone Europe/Berlin]
    [--trusted <path>] [--config <name|path[#profile]>]
    [--receptionist-config <...>] [--worker-config <...>]
```

One project workspace, created/initialized if missing, with its own registry under
`<workspace_dir>/.client_registry` (it does not appear in the node's private workspace tree).
No ShizoNet: no `Router`, no node discovery, no polling. A 24/7 receptionist answers trusted
chats; the worker agent runs only inside the configured local work window. The receptionist also
has read-only workspace tools (`list_dir`, `file_info`, `file_line_count`, `read_file`), so a
question about the workspace is answered immediately, outside the work window and without waiting
for a worker; substantive work is still delegated. Requests outside the window are queued and
dispatched at the next window; active worker tasks are stopped at window close. Long reports and
`send_file` documents are delivered as Telegram documents. Trusted chats bootstrap like
`telegram_router` (`/allow`, `/deny`, `/forget`), and text files sent by a friend are read and
attached verbatim to the delegated task.

## Node

```
shz node.shio                                        interactive
shz node.shio --interactive --config gpu             interactive with a named config
shz node.shio --name GPUBox --description "cuda training box"
shz node.shio --receptionist-config chat --worker-config gpu
shz node.shio --worker-config ./endpoints.json#worker
shz node.shio --webserver --port 13337 --api-token secret   + JSON web API
shz node.shio --web [--port 13337]                   + the web interface (= shz miniagent --web)
shz node.shio --agentspace <dir>                    scheduled goals (default: std.user_path()/miniagent/node/.agentspace)
```

Tasks of a node: `Node.add_task(name, goal, role = "adaptive", workspace_id = "")` routes to a
`Workspace`; a task of another role gets an agent of its own. The registry's `SessionManager`
spawns a `workspace_agent` session (`planned`), which researches (`research`) and implements
(`implement`). `update_task` during the research adds the message to the implementation prompt;
during the implementation it sends a prompt to the running session agent, which stops the current
generation and continues the same conversation with the message. An idle session queues the
prompt for the next turn. A follow-up for a running receptionist turn (`ai_request_update`) is
continued the same way by the `Receptionist` connector (`Node.update_receptionist`). Nothing ends
a workspace session, receptionist, router poller or Telegram thread: an error fails that one
task / turn with its reason.

A node announces itself with the ShizoNet props `AINode` (protocol version) and
`AINodeInfo` (name, description, capabilities, model, load, task counts, `goals` = the Node's own Workspace runs a goal scheduler)
— that table is the data the router **agent** reads when it picks a node. The Node pushes task
lifecycle and notification events to the routers, which is how a task started on one server
reaches a chat on another.

## Protocol

`router_api.md` is the binding contract: command names, payloads, props, events, the
`Router` surface and the role tool surface. `shizonet_ai.shio` is the only place the wire
format is implemented.

## Long tasks and compaction

A context warning is injected once per compaction episode (`compaction_requested`), not on every
streamed usage chunk. After a successful handover the flag resets, so a long open-ended task can
compact repeatedly. The warning run is internal (`internal_run`): its text/tool deltas are not
shown, its finalize report is consumed as a handover, and the real task prompt is restored and
continues. A warning run that finalizes with `finished` is still treated as a handover, not as the
task's terminal answer. An unusable warning report falls back to `compact_handover()`.

## Stop

`miniagent.stop()` is **top-down and total**: it aborts the agent's own stream and
recurses into every child registered in `_child_agents` (a child's own `stop()`
walks its subtree), so one call on the root ends generation everywhere.

* Live children stay in `_child_agents` — that list is the propagation path. Pruning
  it down to the newest child leaves the siblings generating after a stop.
* `should_stop()` is true for an agent whose **ancestor** was stopped. `task()`
  refuses to start under a stopped ancestor, and a child created under a stopped
  parent is born stopped, so a stop cannot be undone by a late `start_task`,
  `continue_task` or batch item.
* A child stopping **itself** (`finalize()`) stops only its own subtree:
  the parent keeps running and can continue that child later.
* Blocking tools (`sleep`, `command_start` / `command_read` / `command_wait`) poll
  `should_stop()`: a stopped agent leaves the wait instead of sitting out the
  timeout. A command process is never killed by a stop — only the wait ends.
* `Node.stop_task()` stops the **running** workspace session (and with it its whole
  subagent tree), not only a task that was still queued.

## Tests

```
shz model_config_selftest.shio    config paths, cwd search, profiles, save/load
                                  -> 24 checks, ALL PASSED
shz router_selftest.shio        full stack: Router + protocol + role tools, stub nodes,
                                 stub router-agent turn, no LLM, the failure reason in
                                 every task_state event, the stall watchdog, the refused
                                 delegation reason, the goals flag
                                 -> 127 checks, ALL PASSED
shz telegram_router_selftest.shio  Telegram front end against a fake bot + stub nodes:
                                 trusted-chat bootstrap, untrusted chats ignored,
                                 /allow /deny /forget /nodes /tasks /status, agent turn,
                                 a question that routes nothing is not an error, no
                                 "Agent returned nothing" on a reported turn, every
                                 new_draft_id shape handled (int/json/string/None/throw),
                                 a replayed update is one task, task-finished notification
                                 in every trusted chat, exactly once, failed / lost /
                                 stopped / stalled / question rendered WITH its reason, an
                                 empty report shows a fallback, /nodes shows goals,
                                 node state / progress / tool calls silent by default,
                                 a burst of messages is one turn, replies quoted, a text
                                 file reaches the node verbatim, a binary file is refused,
                                 /goals, a turn that throws is reported and the
                                 bot keeps answering
                                 -> 104 checks, ALL PASSED
shz shizonet_ai_selftest.shio   protocol only: node service + router service, no LLM,
                                 the node info advertising goals = 1|0 over the wire
                                 -> 128 checks, ALL PASSED
shz workspaces_selftest.shio    workspace store, session manager, scheduler,
                                  deletion and the agent protocol
                                  -> 82 checks, ALL PASSED
shz testbench/telegram_client/telegram_client_selftest.shio  the isolated Telegram client against a fake bot and a fake
                                  workspace: trust bootstrap, window queue/dispatch, stop at
                                  close, files, no ShizoNet
                                  -> 44 checks, ALL PASSED
shz node_api_selftest.shio      node JSON API over real HTTP, stub host
                                 -> 40 checks, ALL PASSED
shz goals_selftest.shio         time zones / DST, front matter, validation, the scheduler
                                 (activation once per window, restart recovery, misfire
                                 policies, retries, stop policy, invalid edits, conflicts,
                                 pause, dry run, verification, capacity, a refused dispatch
                                 is notified, day and minute interval schedules, agent goal
                                 tools, stall watchdog, state/overview.md, fake host +
                                 fake clock -> 187 checks, ALL PASSED
shz architecture_selftest.shio   the architecture board: model file, merge of a re-sync,
                                 pending edits, analyze / plan / apply jobs on a fake
                                 host, restart, the --web command line
                                 , the job role (adaptive), the split of a big change
                                 set into subtasks -> 99 checks, ALL PASSED
shz web_ui_selftest.shio         the web interface under browser load, stub host: every
                                 page and file, 150 polls, chat turns with their /poll
                                 loop while the pages poll, 20 parallel requests,
                                 keep-alive reuse -> 28 checks, ALL PASSED
shz tests/megamind_tasks_test.shio  the node/workspace task system keeps running: an update
                                  during the implementation is continued by the workspace
                                  session agent (not by the caller), a follow-up of a running
                                  receptionist turn stays on the receptionist connector, a
                                  throwing finished listener / a crashing workspace session do not
                                  end the session agent, stop_task reaches a task that
                                  waits for a slot, the role of a task (adaptive by
                                  default, another role gets its own agent)
                                  -> 28 checks, ALL PASSED
shz tests/agent_slots_test.shio  max_running_agents: lending, forks, roots, stops
                                 -> 13 checks, ALL PASSED
shz tests/command_tools_test.shio  command_start with multi-line sh / python scripts:
                                 state across lines, quotes, here documents, exit codes,
                                 a running script as a session, no .shz_cmd folder
                                 -> 11 checks, ALL PASSED
shz tests/role_slots_test.shio   max_running_agents with a real ModelConfig and the
                                 adaptive role's file_task_batch / fork / start_task,
                                 stub LLM: never more than the limit generating, every
                                 batch item exactly once  -> 13 checks, ALL PASSED
shz tests/stop_propagation_test.shio  miniagent.stop() across the agent tree, no LLM:
                                  every child and grandchild registered and stopped,
                                  no generation under a stopped ancestor, a child
                                  that finalized itself stays continuable, no finalize
                                  nudge after a stop, interruptible sleep, and
                                  start_task / continue_task / fork / file_task_batch
                                  obeying a stop  -> 45 checks, ALL PASSED
shz tests/receptionist_tools_test.shio  the receptionist role's tools against a stub
                                    node + the turn-result fold: read-only workspace tools
                                    (list_dir / file_info / file_line_count / read_file)
                                    answer questions without touching a worker, every goal
                                    tool answers the disabled-node error when the node has no
                                    .agentspace, finish(summary) sets task_result, a
                                    crash / stop / silent turn ends with readable text
                                    + send_file -> 73 checks, ALL PASSED
shz tests/feedback_chain_test.shio  the whole feedback chain, no LLM: a stub AI node
                                  behind the real ShizoNet service, the real Router
                                  mirror + poller + watchdog, the real TelegramRouter
                                  into a fake bot — the node's report, the failure
                                  reason, the stall, the notify, the refused delegation
                                  and the goals flag all arrive in the chat, a long
                                  report / notify in full as an attached .md, a
                                  node's send_file document -> 34 checks, ALL PASSED
```

ShizoNet on one machine: only the process binding UDP **6454** hears every beacon, so a
selftest starts the router first and gives the stub nodes explicit ports (6455, 6456) —
and a check that asks a *second* server to see a *third* one can never pass: ask the
6454 owner.
## Workspace UI (issue #907)

`shz miniagent --web` now serves a recursive **workspace tree** instead of the node-scoped
Chat/Tasks/Architecture dashboard (`workspace_spec.md`).

- The `WorkspaceRegistry` lives under `std.user_path()/miniagent/workspaces`; the Node's own
  Workspace is the registry's `root` Workspace, while its node-level goal/architecture store
  lives under `std.user_path()/miniagent/node`. Each workspace is
  bound to a physical directory and owns `.megamind/` (sessions, architecture) plus its own
  `.agentspace` (goals).
- A session is a `workspace_agent` subprocess spawned by the registry's `SessionManager`.
  Its output streams to the UI through SSE; a new prompt interrupts the running turn.
- The UI's Loop mode loops until the agent finalizes with `finished`, `failed` or `question`; a
  subprocess exit without a terminal result is reported as a failure, not silently restarted.
- Architecture and tasks are per `Workspace`, driven by its own `ArchitectureBoard`,
  `GoalScheduler` and task API; `Node` routes tasks to a workspace. The registry root has a
  *Global tasks* view across all workspaces.
- `max_sessions` is editable in the UI; `max_running_agents` comes from the model config.
- Removing a workspace stops and deletes its sessions automatically; its project files stay on
  disk. A workspace with sub-workspaces is refused until the children are removed first.
- Live token usage, active sessions and notifications are in the dashboard.

Follow-up (#907 last comment): the SSE route returns `text/event-stream` and accepts
`?token=` + `?since=`; saved sessions are loaded from disk; a legacy `.agentspace/architecture.json`
is imported; the dashboard is one sidebar with workspace + session tree, `+` creates an empty
session, and tasks are split into active / proposed / templates / finished with an activate
action. `workspace_spec.md` has the details.
