# miniagent

The idea is

```
'shz miniagent'          -> starts __init__.shio, very simple direct action agent
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
| `megamind.shio` | `Megamind()` — one machine: a *receptionist* agent that routes user requests into a pool of worker agents |
| `node.shio` | the runnable **AI node**: a `Megamind()` plus a ShizoNet service, so other machines can drive it |
| `router_api.shio` | `Router()` — the runtime of the **router agent**: a `miniagent` with the `router` role decides which node owns a request, this class executes it over ShizoNet, mirrors the remote task state and forwards node events |
| `router.shio` | a **demo** CLI around `Router()` |
| `telegram_router.shio` | `TelegramRouter : Router` — the Telegram front end: trusted-chat access control + every node event pushed into the chat |
| `shizonet_ai.shio` | the node ⇄ router wire protocol (both sides, one place) |
| `node_api.shio` | optional JSON web API of a node (`--webserver` / `--port`) |
| `goal_engine.shio` | scheduled goals: `.agentspace/` Markdown goals, validation, the deterministic `GoalScheduler` (`goals_spec.md`) |
| `goal_time.shio` / `goal_frontmatter.shio` | time zones + DST, work windows / the front matter reader and writer |
| `goal_tools.shio` | the receptionist's goal tools (create / update / pause / run) |
| `goals.shio` | `shz miniagent.goals ...`: list, validate, run, pause, history, diff |
| `agent_slots.shio` | `max_running_agents` accounting: a waiting parent lends its slot to a child |
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
shz node.shio --max-workers 4
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

For `node.shio`, the receptionist and worker pool can use different endpoints:

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

shz node.shio --receptionist-config chat --worker-config gpu --max-workers 4
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

## Goals (scheduled autonomous work)

A node can run work on its own at set times: "tonight, explore a new app idea", "every Sunday
clean up the repository", "fix GitHub issues from 05:00 to 10:00". Goals are Markdown files in
`.agentspace/goals/<status>/<id>/goal.md` (front matter = schedule + policy, body = the
instructions); the node's scheduler — plain code — activates each window exactly once, applies
the stop policy at the window end, retries, verifies and reports. Contract: `goals_spec.md`.

```
shz miniagent.goals init                 create .agentspace/ (preferences, examples, templates)
shz miniagent.node                       a node started next to .agentspace/ runs the scheduler
shz miniagent.node --agentspace <dir>    ... or point it there
shz miniagent.goals list | show <id> | validate | run <id> [--dry-run] | pause <id> | history <id>
```

* Edit the files directly; an invalid edit is reported once and the last valid revision keeps
  running. Moving a goal folder (`active/` → `paused/`) is the status change.
* From the chat: "tonight, try X" reaches the node's receptionist, which resolves "tonight" with
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
and further children running in parallel (fork siblings, batch items) take more. A Megamind
worker task takes its slot from the pool, the receptionist does not (it stays responsive).
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
node while that task is open returns the existing taskid), and the node's internal worker
task that executes a delegated request never becomes a second mirror entry — the router
adopts node work only when it is not already waiting on that node.

Subclass it the way `Megamind` is subclassed:

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
  refuses is notified by the node's scheduler — nothing fails silently. The node's
  **receptionist report is the delivery channel**: `finish(summary)` becomes the task report
  (`megamind_turn_result`), so "Goals are not enabled on this node: ..." arrives as text
  instead of "Agent was stopped.".
  Node online/offline, queued/running progress and tool calls are **not** sent;
  `--verbose-events` restores the full event stream.
* **Follow-ups and files.** Messages a chat sends in quick succession are one turn (Telegram
  splits long texts, people correct themselves); every user message is recorded in the
  router's action ring, so `get_last_actions` resolves "make it 6am instead". A reply quotes
  the message it answers. A text document (`.md` plan, `.txt`, `.json`, code, up to 256 KB) is
  read, kept in `telegram_inbox/` next to the trust file, shown to the router agent and
  attached verbatim to the goal the turn delegates; its caption is the instruction.
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
cannot do the work it routes. It is the local receptionist's tool surface pointed at
**remote nodes**: start / stop / update / check tasks across the network, and every node
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

## Node

```
shz node.shio                                        interactive
shz node.shio --interactive --config gpu             interactive with a named config
shz node.shio --name GPUBox --description "cuda training box"
shz node.shio --receptionist-config chat --worker-config gpu
shz node.shio --worker-config ./endpoints.json#worker --max-workers 4
shz node.shio --webserver --port 13337 --api-token secret   + JSON web API
shz node.shio --agentspace .agentspace               scheduled goals (auto when ./.agentspace exists)
```

A node announces itself with the ShizoNet props `AINode` (protocol version) and
`AINodeInfo` (name, description, capabilities, model, load, `goals` = it runs a goal scheduler)
— that table is the data the router **agent** reads when it picks a node. Every node pushes task
lifecycle and notification events to the routers, which is how a task started on one server
reaches a chat on another.

## Protocol

`router_api.md` is the binding contract: command names, payloads, props, events, the
`Router` surface and the role tool surface. `shizonet_ai.shio` is the only place the wire
format is implemented.

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
* A child stopping **itself** (`signal()`, `finalize()`) stops only its own subtree:
  the parent keeps running and can continue that child later.
* Blocking tools (`sleep`, `command_start` / `command_read` / `command_wait`) poll
  `should_stop()`: a stopped agent leaves the wait instead of sitting out the
  timeout. A command process is never killed by a stop — only the wait ends.
* `Megamind.stop_task()` stops the **running** worker (and with it its whole
  subagent tree), not only a task that was still scheduled.

## Tests

```
shz model_config_selftest.shio    config paths, cwd search, profiles, save/load
                                 -> 24 checks, ALL PASSED
shz router_selftest.shio        full stack: Router + protocol + role tools, stub nodes,
                                 stub router-agent turn, no LLM, the failure reason in
                                 every task_state event, the stall watchdog, the refused
                                 delegation reason, the goals flag
                                 -> 126 checks, ALL PASSED
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
                                 /goals
                                 -> 102 checks, ALL PASSED
shz shizonet_ai_selftest.shio   protocol only: node service + router service, no LLM,
                                 the node info advertising goals = 1|0 over the wire
                                 -> 114 checks, ALL PASSED
shz node_api_selftest.shio      node JSON API over real HTTP, stub host
                                 -> 37 checks, ALL PASSED
shz goals_selftest.shio         time zones / DST, front matter, validation, the scheduler
                                 (activation once per window, restart recovery, misfire
                                 policies, retries, stop policy, invalid edits, conflicts,
                                 pause, dry run, verification, capacity, a refused dispatch
                                 is notified) and the agent goal
                                 tools, stall watchdog, state/overview.md, fake host +
                                 fake clock -> 127 checks, ALL PASSED
shz tests/agent_slots_test.shio  max_running_agents: lending, forks, roots, stops
                                 -> 13 checks, ALL PASSED
shz tests/stop_propagation_test.shio  miniagent.stop() across the agent tree, no LLM:
                                  every child and grandchild registered and stopped,
                                  no generation under a stopped ancestor, a child
                                  that signalled itself stays continuable, no finalize
                                  nudge after a stop, interruptible sleep, and
                                  start_task / continue_task / fork / file_task_batch
                                  obeying a stop  -> 45 checks, ALL PASSED
shz tests/receptionist_tools_test.shio  the receptionist role's tools against a stub
                                  node + the turn-result fold: every goal tool answers
                                  the disabled-node error when the node has no
                                  .agentspace, finish(summary) becomes the report, a
                                  crash / stop / silent turn ends with readable text
                                  -> 58 checks, ALL PASSED
shz tests/feedback_chain_test.shio  the whole feedback chain, no LLM: a stub AI node
                                  behind the real ShizoNet service, the real Router
                                  mirror + poller + watchdog, the real TelegramRouter
                                  into a fake bot — the node's report, the failure
                                  reason, the stall, the notify, the refused delegation
                                  and the goals flag all arrive in the chat
                                  -> 23 checks, ALL PASSED
```

ShizoNet on one machine: only the process binding UDP **6454** hears every beacon, so a
selftest starts the router first and gives the stub nodes explicit ports (6455, 6456) —
and a check that asks a *second* server to see a *third* one can never pass: ask the
6454 owner.
