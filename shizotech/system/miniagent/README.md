# miniagent

```
shz miniagent                      the console agent in the current directory (__init__.shio)
shz miniagent --node               a node on ShizoNet: the workspaces of this machine, worker
                                   sessions, scheduled goals. Other nodes and gateways find it.
shz miniagent --node --web         the node plus the web interface (every node of the network)
shz miniagent --init [<dir>]       register a directory as a workspace of the node, then return
shz miniagent --telegram-gateway   the Telegram gateway: not a node, it passes chat requests to
                                   the nodes and brings their reports back
shz miniagent --help               every option
```

In script
```
#include "miniagent/miniagent"
```
can be used.

## How the parts fit (#1015)

```
Telegram chat Ã¢â€â‚¬Ã¢â€“Âº gateway (router agent) Ã¢â€â‚¬Ã¢â€Â
                                          Ã¢â€Å“Ã¢â€â‚¬ ShizoNet Ã¢â€â‚¬Ã¢â€“Âº node A Ã¢â€â‚¬ workspaces Ã¢â€â‚¬ worker sessions
browser Ã¢â€â‚¬Ã¢â€“Âº web interface of ANY node Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€Ëœ            Ã¢â€“Âº node B Ã¢â€â‚¬ workspaces Ã¢â€â‚¬ worker sessions
```

* A **node** has no agent in front of its work. Every request, from the web interface, from a
  gateway or from another node, is a **worker session in a workspace** (`workspace_agent`,
  role `adaptive`). The node used to have a *receptionist* agent that re-delegated each request
  to a worker; it is gone (2026-11, #1015): the worker gets the user's words directly and keeps
  the whole conversation, so nothing is lost in a paraphrase and a follow-up reaches the agent
  that did the work.
* The **gateway** (`--telegram-gateway`) is the only place with a routing agent: the `router`
  role picks the node **and the workspace** for a request and starts a worker session there. A
  routed task is a **thread** (`T12`): later messages of the chat go into the same session, also
  after it finished. When the agent cannot tell where a message belongs, it asks in the chat.
* The **web interface** of one node shows every node of the network: their workspaces,
  sessions, tasks and architecture graphs, all through the same JSON API, which a node also
  answers over ShizoNet (`ai_api`). A node without a web server is fully usable from the
  browser of another one.

## The pieces

| File | What it is |
|---|---|
| `__init__.shio` | the CLI: the console agent, and the dispatch to `--node` / `--init` / `--telegram-gateway` |
| `model_config.shio` | `ModelConfig()` Ã¢â‚¬â€ endpoint/model/generation config, flat and profile JSON layouts |
| `model_config_cli.shio` | shared CLI config resolver: named configs, cwd search, profiles, create/list/save |
| `miniagent.shio` | the agent class: role loading, tools, subagents, LLM turn loop |
| `node_lib.shio` | `Node` Ã¢â‚¬â€ the **AI node** as a class: one `WorkspaceRegistry`, its own "General" workspace, the ShizoNet service, the peers, optional web/API (`node_architecture.md`) |
| `node.shio` | the command line of a node (`shz miniagent --node ...`), nothing else |
| `node_peers.shio` | `NodePeers` Ã¢â‚¬â€ the other nodes and gateways this node sees on ShizoNet, and one API call to one of them |
| `workspaces.shio` | `Workspace`, `WorkspaceRegistry`, `WorkspaceStore`, `SessionManager`, the live feed and the workspace API (`workspace_spec.md`) |
| `workspace_agent.shio` | the subprocess of one worker session |
| `workspace_env.shio` | workspace-local env vars from `<workspace>/.env/vars`, exported with `std.set_env` for the session and its command tools |
| `api_router.shio` | `ApiRouter` Ã¢â‚¬â€ the route table of the JSON API, served over HTTP and callable without HTTP (`dispatch`) |
| `node_api.shio` | the JSON API of a `Node` (`node_api.md`) |
| `web_ui.shio` + `web/` | the web interface (`--web`): the dashboard, the calls for other nodes (`/api/nodes/...`) |
| `shizonet_ai.shio` | the node Ã¢â€¡â€ž gateway wire protocol, both sides, one place (`router_api.md`) |
| `router_api.shio` | `Router()` Ã¢â‚¬â€ the runtime of the **router agent**: discovers the nodes, starts worker sessions on them, keeps the threads, mirrors the task state, forwards node events |
| `telegram_router.shio` | `TelegramRouter : Router` Ã¢â‚¬â€ the Telegram gateway: owner and guest chats, every task report pushed into the chat that started it |
| `telegram_gateway.shio` | the runnable of the gateway (`shz miniagent --telegram-gateway`) |
| `gateway_config.shio` | the gateway settings of the web interface and `GatewayRunner`, which starts the gateway with the node |
| `router.shio` | a **demo** console around `Router()` |
| `telegram_client.shio` | `shz miniagent.telegram_client --bot-token ... --workspace_dir <dir>` Ã¢â‚¬â€ an isolated Telegram client for one workspace: 24/7 receptionist, worker only in a configured local window, no ShizoNet |
| `architecture.shio` | the architecture graph: a workspace's `.megamind/architecture/architecture.json`, plus the node-level graph; pending edits, analyze / plan / apply jobs (`architecture_spec.md`) |
| `goal_engine.shio` | scheduled goals: `.agentspace/` Markdown goals, validation, the deterministic `GoalScheduler` (`goals_spec.md`) |
| `goal_time.shio` / `goal_frontmatter.shio` | time zones + DST, work windows / the front matter reader and writer |
| `goal_tools.shio` | the goal tools of a worker session (create / update / pause / run) |
| `goals.shio` | `shz miniagent.goals ...`: list, validate, run, pause, history, diff |
| `agent_slots.shio` | `max_running_agents` accounting: a waiting parent lends its slot to a child |
| `miniagent_storage.shio` | the one storage root (`std.user_path()/miniagent`, `--data-dir <dir>` moves it) shared by node, goals and workspaces |
| `megamind.shio` | legacy `Megamind()` worker pool; the node does not use it |
| `flow_spec.md` | the runtime flow: workspace registry, session subprocess, gateway path, the single finalize contract |
| `roles/` | the AI roles: `adaptive` (workers), `router` (gateway), `receptionist` (only the isolated Telegram client), `single_action/*`, `util/*` (`blind_tester`: tests from a spec) |

## Model configs

The runnable scripts share one config story:

```
shz miniagent --config gpu
shz miniagent --node --config gpu
shz miniagent --node --config ./endpoints.json#worker
shz miniagent --telegram-gateway --config router-fast
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

A node has **one** model config, the one of its workers: `--config` (the old name
`--worker-config` still works; `--receptionist-config` is ignored with a warning, a node has no
receptionist). The same file can hold several endpoints as profiles:

```
{
  "profiles": {
    "default": {"url": "http://localhost:8000", "name": "chat"},
    "worker": {"url": "http://localhost:8001", "name": "coder"}
  }
}
```

```
shz miniagent --node --config ./endpoints.json#worker
shz miniagent --telegram-gateway --config ./endpoints.json#default     a small model is enough to route
```

A worker session receives the config spec as `--config-spec`; no endpoint or API token is stored
per session.

## Workspace environment variables

A worker session reads `<workspace>/.env/vars` when it exists and exports every line with
`std.set_env` before its first turn. The lines are `KEY=VALUE`:

```
ENV_VAR=Something
ENV_VAR2=SomethingElse
```

Blank lines and lines starting with `#` are ignored. Because `std.set_env` sets the environment of
the session process, the command tools of `roles/SHARED.shio` (`command_start`, `command_wait`,
`command_read`, ...) inherit the variables in the commands they run. The file is read once at
session start; changing it does not affect a session that is already running.

## Web interface

```
shz miniagent --node --web
shz miniagent --node --web --port 8080 --api-token secret --config gpu
```

Serves http://localhost:13337/ Ã¢â‚¬â€ every page works offline (no CDN). `web/readme.md` has the
page internals.

* **Sidebar: every node of the network**, each one collapsible: this node first, then the others
  it sees on ShizoNet (a gateway shows as a row without workspaces). Under a node its
  workspaces (the node's own one is "General"), under a workspace its sessions. `+` on a node
  makes a workspace **on that node**, `+` on a workspace starts a session. Everything a node
  shows for itself works for the others: sessions, tasks, architecture, settings.
* **Chat** Ã¢â‚¬â€ a session of a workspace. The first prompt starts it. Reasoning is one line (the
  sentence being thought); a click opens the whole text. A tool call is one line with its
  state; a click shows **every parameter and the result**, the square icon opens it in a window
  with a copy button. Opening a session in the middle of a turn shows the turn so far and
  continues live. Ctrl+Enter sends.
* **Tasks** Ã¢â‚¬â€ the scheduled goals and the sessions of the workspace: running, needs input,
  scheduled, proposed, finished. The page is told about changes by the node (`GET /api/live`,
  a long-poll) and patches what differs; nothing is redrawn on a timer. *All tasks* shows the
  same for every workspace of every online node.
* **Architecture** Ã¢â‚¬â€ the codebase as a per-workspace node graph (`architecture_spec.md`). On first use
   *Analyze the codebase* lets a workspace task agent write the workspace's
   `.megamind/architecture/architecture.json` (modules, files, services with a one-line purpose;
   calls / data / includes / events / network between them). Add, change, connect or remove nodes
   on the graph: the edits stay **pending**. *Review plan* lets a task agent write a plan for them
   (no code changes), you give feedback and revise it; *Apply* lets a task agent implement them,
   and when it finishes the edits become the model. *Re-sync* analyzes again (positions and pending
   edits stay). Each job is one `adaptive` workspace task; a big change set is split into subtasks
   (one per group of edits) within `max_running_agents` Ã¢â‚¬â€ `architecture_spec.md`, "Context".
* **Settings** (per node) Ã¢â‚¬â€ how many sessions may run at once, and the **Telegram gateway**:
  bot token, name, model config, "start the gateway with this node". A node with that switched
  on starts the gateway as a process of its own and restarts it when it ends
  (`gateway_config.shio`; `--no-gateway` leaves it off for one run).

With `--api-token` the pages ask for the token once. The JSON API (`node_api.md`,
`workspace_spec.md`) is the same as with `--webserver --port`, its index is at `/api`.
The API of another node is reached through this one: `/api/nodes/<id>/api/...` (ShizoNet,
`ai_api`), so the browser needs only the one address.

## Workspaces of a node

```
shz miniagent --init                       the current directory
shz miniagent --init ~/code/shop --name "Shop"
shz miniagent --node --workspace ~/code/shop --workspace ~/code/api      register at start (repeatable)
```

`--init` registers a directory as a workspace of the node on this machine
(`std.user_path()/miniagent/workspaces`), creates its `.megamind` and `.agentspace`, writes a
short `AGENTS.md` if the directory has none (an existing one is never overwritten) and returns
without starting anything. A node that is already running reads the list at its next start; to
add a folder to a running node use `+` in the web interface with the folder filled in.

A workspace that is **created without a path** (the `+` of the web interface with the folder
field empty, `POST /api/workspaces` without `path`) gets a new folder
`./workspaces/<name>` below the directory the node was started in; the dialog shows the folder
before it is made. A sub-workspace without a path goes below its parent's folder.

## Goals (scheduled autonomous work)

A node can run work on its own at set times: "tonight, explore a new app idea", "every Sunday
clean up the repository", "check the server logs every 2 days at 06:00" (`schedule.every: 2d`) or
"check the service every 5 minutes" (`schedule.every: 5m`),
"fix GitHub issues from 05:00 to 10:00". Goals are Markdown files in
`.agentspace/goals/<status>/<id>/goal.md` (front matter = schedule + policy, body = the
instructions); the Node's own workspace scheduler Ã¢â‚¬â€ plain code Ã¢â‚¬â€ activates each window exactly once, applies
the stop policy at the window end, retries, verifies and reports. Contract: `goals_spec.md`.
The Node's own goal store is `std.user_path()/miniagent/node/.agentspace`; every project workspace
also has its own `.agentspace`, and all registered workspace schedulers run at node startup.

```
shz miniagent.goals init                 create the Node's own goal store .agentspace/ (preferences, examples, templates)
shz miniagent --node                     a node uses std.user_path()/miniagent/node/.agentspace
shz miniagent --node --agentspace <dir>  ... or point it there (--no-goals: none)
shz miniagent.goals list | show <id> | validate | run <id> [--dry-run] | pause <id> | history <id>
```

* Edit the files directly; an invalid edit is reported once and the last valid revision keeps
  running. Moving a goal folder (`active/` Ã¢â€ â€™ `paused/`) is the status change.
* From a chat or a session: "tonight, try X" reaches a worker session of the workspace, which
  resolves "tonight" with `preferences/scheduling.md` and creates the goal through validated
  tools (`get_goals`, `create_goal`, `update_goal`, `set_goal_status`, `run_goal_now`). Goals
  that may merge, release or delete stay *proposed* until the owner says yes.
* Background work stays out of the way: `preferences/resource-policy.md` limits it
  (`max_background_tasks`, `reserve_interactive_workers`, `yield_after_interactive`).
  A run a person starts ("Run now", `goals run`, a task made in the Tasks tab) does not wait
  for `yield_after_interactive`: it is the interactive use.
* Telegram: `/goals`, `/goal pause <id>`; every start, missed window, result, question and
  refused dispatch of a goal arrives as a node notification.

## Default tools and blind tests

The tools every role gets are in `roles/SHARED.shio` (files, commands, finalize); the bridge
around every tool call is `miniagent.add_tool()`.

* **A failure says what failed and what to do.** A tool answers a value or
  `[ok = false, error, hint]`. An exception inside a tool reaches the model (and the session
  view) with its text and the name of the tool, plus the `&` parameters the call left out;
  before, every exception became "The tool call caused an unexpected exception.".
* **Results are bounded and say so.** `read_file`: 2000 lines / 80 KB per call with
   `total_lines` and `next_start_line`; a UTF-16LE or UTF-16BE text file with a BOM is decoded
   to UTF-8 before the binary check, so `.md` and other text files are not refused because
   their bytes contain zeros; `list_dir`: 400 files and 400 directories (200 each
  recursive) with the totals; command output: head and tail of 40 KB with the dropped byte
  count. Whatever still comes out above 200 KB is cut by the bridge: a structured result keeps
  every entry and loses the middle of its long texts, a plain text keeps head and tail.
* **Paths** are relative to the working directory; `..` out of it, absolute paths, `~` and a
  link that leads out are refused with the reason (and the relative form when there is one).
* `write_file` does not overwrite a file that has content, `replace_string` says how often the
  text occurs and where when it is not unique, `remove` asks once (the first call is a
  confirmation step, not an error). Yes / no parameters accept `"true"`, `true`, `1`, `"yes"`.
* **Blind tests** (`write_blind_tests(spec, api, test_path, framework?, reference_paths?,
  run_command?, run_timeout?, constraints?)`, role `util/blind_tester`): the tests of
  non-trivial work are written by a sub-agent that gets the specification and the signatures
  and nothing else. Its file tools work on a restricted view (`fs_path_guard`): it reads and
  writes `test_path`, reads `reference_paths`, every other path is refused; it has no command
  or skill tools. The parent runs the tests and sends findings with
  `continue_task(task_id, ...)` (the feedback goes out with the task again). With
  `run_command` the test writer may run that one command itself; tests that run are code with
  the access of the workspace, so that mode is not blind by construction: the harness stops
  the test writer from reading files a run left in the test path and names them to the parent
  (`files_changed_by_test_runs`), nothing more. Leave it out unless you need it.

## Parallel agents

`max_running_agents` (model config) counts agents that **generate** at the same time. Agents
form a tree and a parent that waits for its children does not generate, so a waiting parent
lends its slot to one child: a chain root Ã¢â€ â€™ child Ã¢â€ â€™ grandchild uses one slot; only the second
and further children running in parallel (fork siblings, batch items) take more. A workspace
session task takes its slot from `max_running_agents`.
`agent_slots.shio`, `tests/agent_slots_test.shio`.

## Gateway and router

The router is an **agent**, not a scoring function. `Router()` runs a `miniagent` with the
`router` role, and that agent decides, with the model, which node **and which workspace** own
a request: its turn starts with a context block (the tasks of this chat, the nodes with their
workspaces), it reads more with `get_nodes()` and starts the work with `start_task()`. The node
table (name, description, model, load, workspaces with their descriptions) is data for the
agent. `Router` itself has no keyword matching, no capability scoring and no fallback node:
`add_task()` refuses an empty node name instead of guessing one.

**A routed task is a thread.** `start_task` opens a worker session in the workspace
(`ai_task_add`, no agent in between) and the worker gets the user's message **verbatim**
(`Router.turn_text`), not the router's paraphrase. The session keeps the whole conversation;
the gateway keeps a small table of the threads (`T1`, `T2`, ...: node, workspace, session, the
last messages of both sides, saved in `gateway_threads.json`). A follow-up ("make it blue
instead") goes into the same session with `update_task(thread)`, while it runs and after it
finished (the session is continued with a new turn), so the worker that answers is the one
that did the work. This replaced the receptionist on the node: the question "which worker did
that?" is answered by the thread table, not by a second agent re-reading the request.

`Router()` is a class, so it is built upon, not forked:

```
#include "router_api"

rtr = Router(cfg);                                  // role "router", shizonet server up

rtr.on_event([](e) { send_to_telegram(e); });       // node events -> your transport
rtr.on_notify([](m) { send_to_telegram(m); });      // node notifications
rtr.request("train the model with cuda");           // one router-agent turn: the agent routes
rtr.route_task("train the model with cuda");        // agent turn -> [ok, routed, taskid, node, answer]
                                                    // ok = the turn worked, routed = a task
                                                    // was started; a plain question is
                                                    // ok with routed = false
rtr.add_task("Train", "train the model", "GPUBox", "worker", "ml-project");
                                                    // explicit node + workspace, no model
rtr.update_task(taskid, "use tabs");                // the same conversation, running or finished
rtr.stop_task(taskid);
rtr.delegate("GPUBox", "what is your uptime?");     // one blocking request (ai_request)
```

`on_event` is the **single** event stream and the router de-duplicates it: a node
coming online is announced once (the router's own discovery wins, the node's
`ai_event` push of the same state is dropped) and a finished task is announced
once per turn (the poller's `task_state` carries the report, the node's `task_finished`
push of the same state is dropped). `on_notify` is a second sink for **local**
`notify_user()` only Ã¢â‚¬â€ register `on_event` *or* `on_notify`, not both, or your own
notifications reach the user twice.

One user goal is **one task**: `add_task` is idempotent (the same goal text on the same
node and workspace while that task is open returns the existing taskid). A session someone
started in the web interface of a node is not the gateway's business: its finish is not
announced in a chat (`origin = "web"`; `opts.adopt_web` turns that on).

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

### The Telegram gateway (`shz miniagent --telegram-gateway`)

That example, built for real: `class TelegramRouter : Router` (`telegram_router.shio`). It is
**not a node**: it runs no work and owns no workspace, it sees the nodes on ShizoNet and passes
chat messages to them.

```
shz miniagent --telegram-gateway [--bot-token 123456:ABC...]
    [--config <name|path[#profile]>]
    [--name TelegramGateway] [--poll 1000] [--stall 900000]
    [--trusted <path>] [--no-stream] [--verbose-events]
```

Without `--bot-token` it uses the token saved in the web interface (Settings Ã¢â€ â€™ Telegram
gateway); with "start the gateway with this node" switched on there, `shz miniagent --node`
starts and supervises it, so one command runs the node, the web interface and the bot.

* **Owner chats.** The bot answers only chats listed in the `trusted_chats` json
  (default `std.config_path("miniagent", "trusted_chats")`, override with `--trusted`):

  ```
  {"chats":[{"chatid":123456,"name":"Peter","added":1700000000000},
            {"chatid":777,"name":"Anna","role":"guest","node":"GPUBox","workspace":"Shop Frontend"}]}
  ```

  No file / empty list Ã¢â€ â€™ **the first chat that messages the bot becomes the owner
  chat** and is written to the file. Every other chat is ignored: the bot never answers
  strangers, and the owner chats are told once that a new chat knocked, with the command that
  lets it in. `/allow <chatid> [name]`, `/deny <chatid>` and `/forget` edit the list from the
  chat; `/id` shows the chat id to put in the file.
* **Guests.** `/guest add <chatid> <node> <workspace> [name]` lets a chat in for **one
  workspace of one node**, through the same bot. A guest has no router agent and no command
  that looks at the fleet: every message goes into that workspace, the same conversation until
  `/new`, and only the reports of its own tasks come back. `/guest remove <chatid>`, `/guests`.
  Guest commands: `/help /new /stop /status /id`.
* **Plain text** from an owner chat is one router-agent turn; the answer goes back to
  that chat and the turn's progress streams as a Telegram draft (`--no-stream` off).
  The agent's `finish(report)` text is what you see: a job gets the routing
  confirmation with the thread label, a question gets an answer, and a message the agent cannot
  place gets a question back ("Which workspace do you mean?") Ã¢â‚¬â€ a turn that routes nothing is
  never reported as an error, and streaming never breaks a turn.
* **Notifications Ã¢â‚¬â€ only what matters.** A chat gets the router agent's answer and every
  terminal fact about **its** tasks: **finished / failed / lost / stopped / a question**, with
  the thread label, the node, the workspace (`T12 Ã‚Â· GPUBox / Shop Frontend`) and the worker's
  report, exactly one message per turn (the Router de-duplicates the node push and the poller
  transition; an empty report renders a visible fallback), a task that **stalled** (open for
  15 minutes with no progress, once per episode, `--stall <ms>`), and a `notify` from a node.
  What no chat started (a scheduled goal, a notify of a node) goes to the owner chats.
  **Failures carry the reason**: the `task_state` event's `error` (the node's error answer,
  "node offline", "no reply from node", ...) is rendered, a **refused start** is relayed
  by the router agent with the reason `add_task_error()` gives (an unknown workspace names the
  ones the node has), a follow-up that could not be delivered says why
  (`update_task_error()`), and a goal run the node refuses is notified by the workspace
  scheduler Ã¢â‚¬â€ nothing fails silently.
  Node online/offline, queued/running progress and tool calls are **not** sent;
  `--verbose-events` restores the full event stream.
* **Follow-ups and files.** Messages a chat sends in quick succession are one turn (Telegram
  splits long texts, people correct themselves); every user message is recorded in the
  router's action ring. A reply quotes the message it answers; a reply to a report continues
  that thread. A text document (`.md` plan, `.txt`, `.json`, code, up to 256 KB) is
  read, kept in `telegram_inbox/` next to the trust file, shown to the router agent and
  attached verbatim to the task the turn starts or continues; its caption is the instruction.
* **Files to the chat.** A report longer than 2500 characters (a notify: 3500) is clipped in
  the message and attached in full as a `.md` document. The workspace agents have
  `send_file(path, caption)`: the file travels as a `file` event
  (base64, up to 20 MB) to every gateway and arrives as a Telegram document.
* Commands of an owner chat: `/help` `/id` `/nodes` `/tasks [state]` `/status` `/goals [node]`
  `/goal <run|pause|resume|cancel|archive> <id> [node]` `/allow` `/deny` `/forget`
  `/guest add|remove` `/guests`.
  `/nodes` shows per node whether it runs a goal system (`goals`), so a schedule request aimed
  at a node that cannot schedule is visible before it is routed.
* Telegram HTTP never runs on the ShizoNet thread: `on_event` queues the text, the
  bot's own worker thread sends it (the `router_api.md` ground rule for handlers).

The router role (`roles/router/`) is a coordinator only: it gets `get_nodes`,
`get_node_overview`, `get_tasks` (the fleet-wide task mirror), `get_goals`, `start_task`,
`update_task`, `stop_task`, `inspect_task`,
`get_last_actions`, `notify`, `finish(report)` Ã¢â‚¬â€ no file, command or execution tools, so it
cannot do the work it routes: start / stop / continue / check tasks across the network, and
every node notification lands on `on_event` so the owner can show it to the user.
`get_nodes` reports per node its workspaces and whether it has a goal system (`goals`), and the
role relays every tool error into its `finish(report)` Ã¢â‚¬â€ the concrete reason of a refused
start (`add_task_error()`), a schedule request aimed at a node without goals Ã¢â‚¬â€ so the user
learns *why*, not only *that* something did not happen (`roles/router/ROLE.md`).

Demo console (the product is `Router()` + the `router` role):

```
shz router.shio                    console: plain text is a router-agent turn
                                      /nodes /tasks /overview [node] /route <text>
                                      /node <node> <text>  one request to a node (no agent turn)
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

When the workspace is one of a running node, a **guest chat of the gateway** does the same
through the owner's bot (`/guest add <chatid> <node> <workspace>`, above): no second bot, no
second process, and the owner sees the sessions in the web interface. The isolated client is
for a workspace that should not be on the network at all.

## Node

```
shz miniagent --node                                    headless: ShizoNet, goals, the saved gateway
shz miniagent --node --web [--port 13337]               + the web interface
shz miniagent --node --webserver --port 13337 --api-token secret    + the JSON API only
shz miniagent --node --interactive                      + a console (/workspaces /use /overview /goals /nodes)
shz miniagent --node --name GPUBox --description "cuda training box"
shz miniagent --node --workspace ~/code/shop            register a folder as a workspace at start
shz miniagent --node --agentspace <dir> | --no-goals    the node's own scheduled goals
shz miniagent --node --data-dir <dir>                   another storage root (a second node on one machine, tests)
shz miniagent --node --no-gateway                       do not start the Telegram gateway saved in the settings
```

(`shz miniagent.node ...` and `shz node.shio ...` are the same command line.)

Tasks of a node: `Node.add_task(name, goal, role = "adaptive", workspace_id = "", origin = "")`
routes to a `Workspace` (an id or a name; empty: the node's own "General" workspace). The
registry's `SessionManager` spawns a `workspace_agent` session, which keeps the conversation.
`update_task` sends a prompt into that session: a running agent stops its generation and
continues the same conversation with the message, an idle or finished session starts a new
turn with it. `Node.request(prompt, ..., workspace_id)` is one blocking worker turn (what
`ai_request` and `POST /api/request` run). Nothing ends a workspace session, a router poller or
a Telegram thread: an error fails that one task / turn with its reason.

A node announces itself with the ShizoNet props `AINode` (protocol version) and
`AINodeInfo` (name, description, model, load, task counts, `goals`, `api` = it answers its API
over ShizoNet, and its **workspaces** with their descriptions) Ã¢â‚¬â€ that table is the data the
router **agent** reads when it picks a node and a workspace. The node pushes task
lifecycle and notification events to the gateways, which is how a task started on one server
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

* Live children stay in `_child_agents` Ã¢â‚¬â€ that list is the propagation path. Pruning
  it down to the newest child leaves the siblings generating after a stop.
* `should_stop()` is true for an agent whose **ancestor** was stopped. `task()`
  refuses to start under a stopped ancestor, and a child created under a stopped
  parent is born stopped, so a stop cannot be undone by a late `start_task`,
  `continue_task` or batch item.
* A child stopping **itself** (`finalize()`) stops only its own subtree:
  the parent keeps running and can continue that child later.
* Blocking tools (`sleep`, `command_start` / `command_read` / `command_wait`) poll
  `should_stop()`: a stopped agent leaves the wait instead of sitting out the
  timeout. A command process is never killed by a stop Ã¢â‚¬â€ only the wait ends.
* `Node.stop_task()` stops the **running** workspace session (and with it its whole
  subagent tree), not only a task that was still queued.

## Tests

Run a test from `system/miniagent`, as written here (`cd system/miniagent && shz router_selftest.shio`).
None needs a model; each prints its checks and ends with exit code 1 when one failed.

```
shz model_config_selftest.shio    config paths, cwd search, profiles, save/load
                                  -> 24 checks
shz router_selftest.shio        full stack: Router + protocol + role tools, stub nodes,
                                 stub router-agent turn: the failure reason in every
                                 task_state event, the stall watchdog, the refused start
                                 reason, the goals flag, node + workspace routing, threads
                                 (a follow-up into a finished task, the thread table saved
                                 and loaded), a session of the web interface is not adopted
                                 -> 158 checks
shz telegram_router_selftest.shio  the gateway against a fake bot + stub nodes: owner-chat
                                 bootstrap, strangers ignored, /allow /deny /forget /nodes
                                 /tasks /status, the agent turn, a question that routes
                                 nothing is not an error, every new_draft_id shape, a
                                 replayed update is one task, one finish notification per
                                 turn in the chat that started it, failed / lost / stopped /
                                 stalled / question WITH the reason, a burst of messages is
                                 one turn, replies quoted, a text file reaches the node
                                 verbatim, /goals, a turn that throws is reported
                                 -> 107 checks
shz shizonet_ai_selftest.shio   protocol only: node service + gateway service, the node info
                                 over the wire, no JSON boolean in any payload (ai_wire)
                                 -> 130 checks
shz workspaces_selftest.shio    workspace store, session manager, scheduler, deletion, the
                                  agent protocol, the turn log of a running turn, and the
                                  max_sessions queue (a full pool accepts a queued task; the oldest starts when a slot frees)
                                  -> 91 checks
shz tests/session_queue_test.shio  max_sessions queue: a full pool accepts tasks instead of
                                  refusing them; FIFO start when a slot frees; prompt and delete behavior
                                  -> 85 checks
shz node_api_selftest.shio      node JSON API over real HTTP, stub host
                                 -> 40 checks
shz web_ui_selftest.shio         the web interface under browser load, stub host: every page
                                 and file, request turns while the pages poll, parallel
                                 requests, keep-alive, the live feed (answers at once when
                                 behind, holds when nothing changed, ends on a change), the
                                 tasks overview, the node list, the gateway settings, and
                                 another node through this one over ShizoNet (GET / POST /
                                 the session stream) -> 56 checks
shz goals_selftest.shio         time zones / DST, front matter, validation, the scheduler
                                 (activation once per window, restart recovery, misfire
                                 policies, retries, stop policy, invalid edits, conflicts,
                                 pause, dry run, verification, capacity, a manual run does
                                 not yield to interactive use, a refused dispatch is
                                 notified, day and minute interval schedules, agent goal
                                 tools, stall watchdog, a run request and a finished run
                                 wake the loop), fake host + fake clock -> 236 checks
shz architecture_selftest.shio   the architecture board: model file, merge of a re-sync,
                                 pending edits, analyze / plan / apply jobs on a fake
                                 host, restart, the job role (adaptive), the split of a big
                                 change set into subtasks -> 95 checks
shz testbench/telegram_client/telegram_client_selftest.shio  the isolated Telegram client
                                  against a fake bot and a fake workspace -> 45 checks
shz testbench/file_delivery/full_file_chain.shio   send_file of a worker to a Telegram
                                  document through the real node service -> 11 checks
shz tests/shared_tools_test.shio  the default tools of every role (roles/SHARED.shio): paging
                                 and limits of read_file / list_dir, the diagnostics of
                                 write / append / replace, the JSON results of the file
                                 operations, finalize validation, the tool bridge (an
                                 exception, a missing parameter, an oversized result that
                                 keeps its entries) -> 154 checks
shz tests/blind_tests_test.shio  write_blind_tests: the sub-agent gets the spec and the
                                 signatures only, every path into the implementation is
                                 refused, a file a test run left is unreadable and named to
                                 the parent, argument errors, the result for the parent
                                 -> 125 checks
shz tests/command_tools_test.shio  command_start with multi-line sh / python scripts:
                                 state across lines, quotes, here documents, exit codes,
                                 a running script as a session, long output keeps its
                                 head and its end -> 34 checks
shz tests/role_slots_test.shio   max_running_agents with a real ModelConfig and the
                                 adaptive role's file_task_batch / fork / start_task,
                                 stub LLM: never more than the limit generating, every
                                 batch item exactly once  -> 27 checks
shz tests/agent_slots_test.shio  max_running_agents: lending, forks, roots, stops
                                 -> 13 checks
shz tests/stop_propagation_test.shio  miniagent.stop() across the agent tree, no LLM:
                                  every child and grandchild registered and stopped,
                                  no generation under a stopped ancestor, a child
                                  that finalized itself stays continuable, interruptible
                                  sleep, start_task / continue_task / fork /
                                  file_task_batch obeying a stop  -> 45 checks
shz tests/feedback_chain_test.shio  the whole feedback chain, no LLM: a stub AI node
                                  behind the real ShizoNet service, the real Router
                                  mirror + poller + watchdog, the real TelegramRouter
                                  into a fake bot Ã¢â‚¬â€ the node's report, the failure
                                  reason, the stall, the notify, the refused start
                                  and the goals flag all arrive in the chat, a long
                                  report / notify in full as an attached .md, a
                                  node's send_file document -> 34 checks
shz tests/megamind_tasks_test.shio      the legacy Megamind worker pool -> 28 checks
shz tests/receptionist_tools_test.shio  the receptionist role (the isolated Telegram client
                                    uses it): read-only workspace tools, goal tools on a
                                    node without goals, the turn result -> 73 checks
```

ShizoNet on one machine: only the process binding UDP **6454** hears every beacon, so a
selftest starts the router first and gives the stub nodes explicit ports (6455, 6456) Ã¢â‚¬â€
and a check that asks a *second* server to see a *third* one can never pass: ask the
6454 owner. The same holds for real processes on one machine: start the one that has to see
all the others first (the gateway, or the node whose web interface you open). The tests that
open ShizoNet (router, telegram_router, shizonet_ai, web_ui, feedback_chain, full_file_chain)
do not run next to each other or next to a node on the same machine.

## Workspaces, sessions and the dashboard (#907, #1015)

`workspace_spec.md` is the contract; in short:

- The `WorkspaceRegistry` lives under `std.user_path()/miniagent/workspaces` (`--data-dir`
  moves the root). Each workspace is bound to a physical directory and owns `.megamind/`
  (sessions, architecture) plus its own `.agentspace` (goals). The node's own workspace
  ("General", id `node`) has its stores under `std.user_path()/miniagent/node`.
- A session is a `workspace_agent` subprocess spawned by the registry's `SessionManager`.
  Its output streams to the page through SSE; a new prompt interrupts the running turn. The
  running turn is also kept as merged items (`turn` of `GET /api/sessions/<id>`), so a page
  that opens the session later shows all of it.
- Loop mode loops until the agent finalizes with `finished`, `failed` or `question`; a
  subprocess exit without a terminal result is reported as a failure, not silently restarted.
- Architecture and tasks are per `Workspace`, driven by its own `ArchitectureBoard`,
  `GoalScheduler` and task API; `Node` routes tasks to a workspace.
- `max_sessions` is editable in the settings; `max_running_agents` comes from the model config.
- **Tasks are always accepted.** When every session slot is busy, a new task becomes a `queued`
  session (`session.json.status = "queued"`, `inspect_task.state = "queued"`) instead of being
  refused. The registry keeps them FIFO and starts the oldest one as soon as a session ends,
  is stopped or is deleted; raising `max_sessions` also starts waiting tasks. `stats` reports
  `active_sessions` and `queued_sessions`, and the dashboard shows a **Queued** section.
- Removing a workspace stops and deletes its sessions automatically; its project files stay on
  disk. A workspace with sub-workspaces is refused until the children are removed first.
- The page follows a node with one long-poll (`GET /api/live`): sessions, token usage,
  notifications and the goal revision of the open workspace arrive when they change.
