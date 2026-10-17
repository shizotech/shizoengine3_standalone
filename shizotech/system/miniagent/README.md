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
| `miniagent.shio` | the agent class: role loading, tools, subagents, LLM turn loop |
| `megamind.shio` | `Megamind()` — one machine: a *receptionist* agent that routes user requests into a pool of worker agents |
| `node.shio` | the runnable **AI node**: a `Megamind()` plus a ShizoNet service, so other machines can drive it |
| `router_api.shio` | `Router()` — the runtime of the **router agent**: a `miniagent` with the `router` role decides which node owns a request, this class executes it over ShizoNet, mirrors the remote task state and forwards node events |
| `router.shio` | a **demo** CLI around `Router()` |
| `telegram_router.shio` | `TelegramRouter : Router` — the Telegram front end: trusted-chat access control + every node event pushed into the chat |
| `shizonet_ai.shio` | the node ⇄ router wire protocol (both sides, one place) |
| `node_api.shio` | optional JSON web API of a node (`--webserver` / `--port`) |
| `roles/` | the AI roles: `receptionist`, `router`, `adaptive`, `single_action/*`, `util/*` |

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
    [--name TelegramRouter] [--role router] [--poll 1000] [--trusted <path>] [--no-stream]
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
  that **finished / failed / was lost on any node** (with the node's report, exactly one
  message per completion — the Router de-duplicates the node push and the poller
  transition), and a `notify` from a node (its report, or its question to the owner).
  Node online/offline, queued/running progress and tool calls are **not** sent;
  `--verbose-events` restores the full event stream.
* Commands: `/help` `/id` `/nodes` `/tasks [state]` `/status` `/allow` `/deny` `/forget`.
* Telegram HTTP never runs on the ShizoNet thread: `on_event` queues the text, the
  bot's own worker thread sends it (the `router_api.md` ground rule for handlers).

The router role (`roles/router/`) is a coordinator only: it gets `get_nodes`,
`get_node_overview`, `get_tasks` (the fleet-wide task mirror), `start_task`,
`update_task`, `stop_task`, `inspect_task`,
`get_last_actions`, `notify`, `finish(report)` — no file, command or execution tools, so it
cannot do the work it routes. It is the local receptionist's tool surface pointed at
**remote nodes**: start / stop / update / check tasks across the network, and every node
notification lands on `on_event` so the owner can show it to the user.

CLI (a demo application — the product is `Router()` + the `router` role):

```
shz router.shio                    console: plain text is a router-agent turn
                                     /nodes /tasks /overview [node] /route <text>
                                     /node <node> <text>  explicit delegation (no agent turn)
                                     /addworker <node> <name> <goal> /notify /config /exit
shz router.shio "task text"        single shot: one agent turn, print the answer
```

## Node

```
shz node.shio                                        interactive
shz node.shio --name GPUBox --description "cuda training box"
shz node.shio --webserver --port 13337 --api-token secret   + JSON web API
```

A node announces itself with the ShizoNet props `AINode` (protocol version) and
`AINodeInfo` (name, description, capabilities, model, load) — that table is the data the
router **agent** reads when it picks a node. Every node pushes task lifecycle and
notification events to the routers, which is how a task started on one server reaches a
chat on another.

## Protocol

`router_api.md` is the binding contract: command names, payloads, props, events, the
`Router` surface and the role tool surface. `shizonet_ai.shio` is the only place the wire
format is implemented.

## Tests

```
shz router_selftest.shio        full stack: Router + protocol + role tools, stub nodes,
                                stub router-agent turn, no LLM  -> 94 checks, ALL PASSED
shz telegram_router_selftest.shio  Telegram front end against a fake bot + stub nodes:
                                trusted-chat bootstrap, untrusted chats ignored,
                                /allow /deny /forget /nodes /tasks /status, agent turn,
                                a question that routes nothing is not an error, no
                                "Agent returned nothing" on a reported turn, every
                                new_draft_id shape handled (int/json/string/None/throw),
                                a replayed update is one task, task-finished notification
                                in every trusted chat, exactly once, node state /
                                progress / tool calls silent by default
                                -> 69 checks, ALL PASSED
shz shizonet_ai_selftest.shio   protocol only: node service + router service, no LLM
                                -> 94 checks, ALL PASSED
shz node_api_selftest.shio      node JSON API over real HTTP, stub host
                                -> 37 checks, ALL PASSED
```

ShizoNet on one machine: the process binding UDP **6454** sees every peer, so a selftest
starts the router first and gives the stub nodes explicit ports (6455, 6456).
