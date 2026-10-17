# Router ⇄ Node protocol (ShizoNet)

This is the **binding contract** between an AI **node** (a `Megamind()` host, see
`megamind.shio` / `node.shio`) and an AI **router** (a `Router()` class, see
`router_api.shio`). Both sides are plain ShizoNet servers on the same private network: they
discover each other automatically via beacons, no IPs are configured anywhere.

```
telegram bot / CLI / web  ──►  Router()  ── ShizoNet ──►  node A (Megamind + receptionist)
                                │                       ►  node B (Megamind + receptionist)
                                └── on_event(cb)  ◄── ai_event pushes from every node
```

The router is a **receptionist of receptionists**: the routing intelligence is the
**router agent** — a `miniagent` running the `router` role (`roles/router/`), the same
kind of LLM turn layer the local `Megamind` gives its receptionist. That agent reads the
fleet with `get_nodes()`, decides *which node* owns a task and delegates it with
`start_task()`. `Router()` is the substrate around that agent: it executes the agent's
decisions over ShizoNet, keeps a local mirror of the remote tasks and forwards node
events to its owner (a telegram bot registers `on_event`).

**There is no keyword/capability scoring anywhere in the routing path.** The node table
(name, description, capabilities, tags, model, load) is handed to the agent as data;
choosing the node is the model's job. `Router.add_task()` refuses an empty node name
instead of guessing one.

All wire code lives in `shizonet_ai.shio`:

```
#include "shizonet_ai"

# node side (inside node.shio, after the shizonet server exists)
ai_node_attach(node, host, [name = <node name>, description = ..., capabilities = [...]])

# router side (inside the Router class)
ai_router_attach(server, router)      # registers the ai_event receiver + AIRouter props
```

---

## Ground rules (ShizoNet specifics that bind both sides)

* Verified API: `shizonet.server(name)`, `server.set_prop(name, value)`,
  `server.on_get(cmd, fn(dev, data) -> reply)`, `server.on(cmd, fn)` (empty reply),
  `server.on_command(cmd, fn)` (for reliable `dev.send`), `server.devices()` (online),
  `server.all_devices()`, `server.find_device(mac)`, `server.on_connect(fn)`,
  `server.on_disconnect(fn)`, `server.broadcast(cmd, data) -> accepted_count`,
  `server.get(cmd, data, timeout)`, `device.get(cmd, data, timeout) -> reply`,
  `device.get_prop(name, timeout)`, `device.name() .mac() .ip() .state() .online()`.
* **`on_get` handlers run on the ShizoNet script thread and must never block.** They only
  enqueue work and return. A handler that calls `device.get()` deadlocks the transport.
* `broadcast(cmd, data)` is a fire-and-forget GET: devices that do not register the command
  are skipped (the return value is the number of devices that accepted it). That is how a
  node pushes events to routers without knowing who the routers are.
* Every `device.get()` from the router passes an explicit timeout:
  **5000 ms** for control calls, **2000 ms** for polls.
* A device object survives disconnects (`state()` goes to `"offline"`), so node records keep
  their identity across restarts. Key node records by `mac`.

## Version + discovery

| Prop | Set by | Value |
|---|---|---|
| `AINode` | node | version string `"1.0"` (`AI_NET_VERSION`) |
| `AINodeInfo` | node | node info json (below), fetched live with `get_prop` |
| `AIRouter` | router | version string `"1.0"` |
| `AIRouterInfo` | router | `[name, version, nodes, tasks, uptime_ms]` |

Discovery is one-sided and cheap: the router's `on_connect(dev)` asks
`dev.get_prop("AINode")`; a non-empty answer means "this is an AI node" → register it.
The node registers the router implicitly: routers are the only devices that answer
`ai_event`, and `broadcast` reports how many accepted.

### Node info (`ai_info` reply / `AINodeInfo` prop)

```
[
    name           = <shizonet node name>,
    version        = "1.0",
    description    = <one line, what this node is good for>,
    capabilities   = ["gpu", "coding", ...],   # free-form routing hints
    tags           = ["home-server"],
    model          = <model name>,
    max_workers    = int,
    busy           = bool,          # receptionist generating or workers running
    tasks_running  = int,
    tasks_planned  = int,
    uptime_ms      = int,
]
```

## Commands (node answers, router asks)

All payloads and replies are JSON objects. Every reply carries `ok = true|false`; on
`false` it carries `error`. Unknown `taskid` / `request_id` → `ok = false`,
`error = "not found"`.

| Command | Request | Reply |
|---|---|---|
| `ai_info` | `[]` | node info json |
| `ai_request` | `[prompt]` | `[ok, request_id, status="queued"]` |
| `ai_request_poll` | `[request_id]` | `[ok, request_id, status, delta?, result?, error?]` |
| `ai_request_stop` | `[request_id]` | `[ok]` |
| `ai_request_update` | `[request_id, message]` | `[ok, request_id, state="updated"]` |
| `ai_overview` | `[]` | `[ok, overview]` — exactly `Megamind.get_overview()` |
| `ai_tasks` | `[]` | `[ok, tasks]` — flattened task list |
| `ai_task` | `[taskid]` | `[ok, task]` |
| `ai_task_add` | `[name, goal]` | `[ok, taskid, name, state="planned"]` |
| `ai_task_update` | `[taskid, message]` | `[ok]` |
| `ai_task_stop` | `[taskid]` | `[ok]` |

`ai_request_poll` status lifecycle is the node_api one, unchanged:
`queued → generating → waiting → done | error`.
`delta` is a raw agent action (`text` / `reasoning` / `tool_start` / `tool_end` / `milestone`).
`result` is the miniagent result json: `[ok, reports=[[report=...]], execution_time_ms]`.

`ai_task_add` / `ai_task_update` / `ai_task_stop` bypass the remote receptionist and drive
the remote worker pool directly (the router's role tools use `ai_request` for real user
work, these are for management and for the CLI).

### `ai_request_update` — follow-ups on delegated work

A delegated task is owned by the **remote receptionist**, so a follow-up must reach that
receptionist, not a worker. The node applies `message` to the receptionist turn that owns
`request_id`:

* request **running** (`generating`): inject it into the live receptionist conversation —
  the same mechanism `Megamind.update_task` uses for a running worker
  (`host.receptionist.send_prompt(message)`), which stops the current generation, keeps the
  chat and continues with the new user message.
* request **queued** (not started yet): append the message to the stored prompt so it is
  part of the task when it starts.
* request **finished / reaped / unknown**: `[ok = false, error = "not found"]`.

The `on_get` handler must not block: it records the update in a queue, and the service
worker thread applies it. The router's `Router.update_task(taskid, message)` uses this
command for `ai_request`-backed tasks and `ai_task_update` for `ai_task_add`-backed ones.

## Events (node pushes, router receives)

Command `ai_event`, sent with `broadcast("ai_event", payload)` by the node whenever
`Megamind.on_task_finished` or `Megamind.on_notify` fires, and on node state changes.
The router answers `"ok"` (it registers `on_get("ai_event", ...)`); no other device does.

```
[
    kind    = "task_finished" | "notify" | "node_state",
    time    = <ms on the node>,
    node    = <node name>,
    # task_finished:
    taskid, name, state, report,
    # notify:
    message,
    # node_state:
    online = bool,
]
```

The router appends every event to `events` (capped at 200), mirrors task state into its
remote task table, and calls the owner callback registered with `Router.on_event(cb)`.
That is the telegram hook: a bot subclass does `router.on_event([](e) { send_to_telegram(e); })`.

**One event per fact.** A node coming online is visible on two channels: the router
discovers it (`shizonet on_connect` → `_register_node`, which emits `node_state`) and the
node pushes `node_state` over `ai_event`. The router announces the transition itself and
drops the node's push of a state it has already announced (per node record
`online_announced`). Same rule for a finished task: when the poller already moved the
mirror into that terminal state (its `task_state` event carries the report), the node's
`task_finished` push is mirrored but not delivered again. The mirror is updated in every
case — only the owner callback is skipped. The `Router` class never prints: rendering
events belongs to the owner.

`notify_user(msg)` is the local pair: it emits a `notify` event **and** calls
`on_notify(msg)`. A front end registers `on_event` **or** `on_notify`, not both, or it
shows its own notification twice.

**An `on_event` callback is not a place to do I/O.** It runs on the ShizoNet script
thread (node push) or on the router's poller thread (mirror transition), and the
ground rule for handlers is "never block". A real transport queues the rendered text
and sends it from its own thread — `telegram_router.shio` is the reference
implementation (`tg_notify` → worker thread → `send_rich`).

## Router class surface (`router_api.shio`)

```
class Router
{
    __init__(cfg, opts = None)     # opts: [name, description, capabilities, tags, role,
                                   #        on_event, on_notify, on_action, poll_ms]
    running = true;

    request(prompt, on_finish_cb = None, on_action_cb = None)   # one router-agent turn, queued
        # The result is normalized by `_turn_result`: the role's `finish(report)`
        # tool puts the agent's answer into `agent.env.reports`, and miniagent only
        # returns those when `env.use_finalize` is set — without the fold, a turn
        # that ended with `finish()` comes back as
        # `[ok=false, error="Agent returned nothing (maybe crashed)."]` although
        # everything worked. The Router folds `agent.env.reports` in: the report is
        # the answer and the turn is ok.
    stop()

    nodes()                        # online node records
    nodes_summary()                # routing table handed to the agent (no device objects)
    refresh_nodes()                # re-discover + re-fetch ai_info
    delegate(node_name, prompt)    # explicit node, no agent turn -> [ok, taskid, node]
    route_task(prompt, node_name = None)
        # THE routing path.
        #   without node_name: ONE router-agent turn — the agent reads get_nodes()
        #     and delegates with its own start_task tool. The MODEL picks the node;
        #     nothing in this class scores or guesses. Blocks until the turn is done
        #     (request() semantics).
        #   with node_name: the explicit delegate() path, no model involved.
        # -> [ok, routed, taskid, node, name, answer, error]
        # `ok` is about the TURN, `routed` about the DELEGATION: an arbitrary
        # question ("what nodes do you have?", "hi") is answered by the agent and
        # routes no task -> ok = true, routed = false, answer = the agent's text.
        # ok = false only when the agent turn itself failed. Callers must check
        # `routed` before treating taskid/node as real, and must not render
        # routed = false as an error.
        # `answer` is what the agent reported with `finish(report)` — the role
        # reports on every turn, so there is always text to show the user.
    add_task(name, goal, node_name, mode = "receptionist")
        # role tool entry point, -> taskid (None on failure)
        # node_name is REQUIRED: the agent picks it from get_nodes(). Empty, unknown
        #   or offline node -> None. This class never invents a node.
        # mode "receptionist": the goal goes to the node's receptionist (ai_request) —
        #   the normal path for user work, the remote receptionist decides how to execute.
        # mode "worker": drives the remote worker pool directly (ai_task_add) — CLI/admin.
    update_task(taskid, message)   # -> bool
    stop_task(taskid)              # -> bool
    inspect_task(taskid)           # -> task json | "Not found."
    tasks_summary(state = None, node_name = None)
        # the router's own task mirror as a compact serializable list, newest first:
        # [taskid, node, name, state, open, goal, report, last_error,
        #  user_updates, created, updated]
        # state: "all" (default) | "open"/"running" (queued+generating) |
        #        "finished" | "failed" | "stopped" | "lost"; node_name restricts to one node.
    get_overview()                 # nodes + remote_tasks + events, device objects stripped
    notify_user(msg)
    on_notify(cb) / on_event(cb) / on_action(cb)
}
```

Remote task record (the router's mirror):

```
[taskid, node, nodeid, remote_request_id, name, goal, state, report,
 created, updated, last_poll]
```

`state`: `queued | generating | finished | failed | stopped | lost`
(`lost` = the node went offline and the request id is gone).

### Mirror rules (why one user goal is exactly one task)

* **One goal, one task.** `add_task` is idempotent: the same goal text on the same
  node while that task is still open returns the **existing** taskid and delegates
  nothing new. It is exact-match idempotence (goal text + node), not guessing: it
  covers an agent that routes one goal twice and a transport that delivers one
  message twice.
* **Adoption.** A node `task_finished` push with a taskid the mirror does not know is
  adopted into the mirror **only when that node has no open delegated request**.
  A delegated `ai_request` is executed by the node's own receptionist, and the worker
  task it finishes is unknown to the router — adopting it would show the user two
  tasks for one goal and notify twice. The request record is settled by
  `ai_request_poll` (state + report). Work a node does while the router is not
  waiting on it (a local CLI job) is adopted, as intended.
* A front end must deduplicate its inbound messages too: Telegram can replay an
  update (`telegram_router.shio` ignores the identical text from the same chat inside
  `TG_DEDUPE_MS`).

## Router role surface (`roles/router/ROLE.shio`, `agt.env.router` = the Router)

Exactly these tools, nothing else — the router cannot execute, only route:

| Tool | Backed by |
|---|---|
| `get_nodes()` | `router.nodes_summary()` |
| `get_node_overview(node)` | `router.node_overview(node)` |
| `get_tasks(state?, node?)` | `router.tasks_summary(...)` — the fleet-wide task mirror |
| `start_task(node, name, task, summary)` | `router.add_task(...)` |
| `update_task(taskid, message)` | `router.update_task(...)` |
| `stop_task(taskid, reason?)` | `router.stop_task(...)` |
| `inspect_task(taskid)` | `router.inspect_task(...)` |
| `get_last_actions(limit?)` | `agt.env.last_actions` |
| `notify(message)` | `router.notify_user(...)` |
| `finish(report)` | ends the turn; `report` is the text the owner shows the user (mandatory, never empty) |

`node` arguments are node **names** as shown by `get_nodes`; the role must pick one before
`start_task` and must never invent one. Picking it is the **agent's** job (the model, reading
the routing table), never the runtime's: `Router` has no scoring, no keyword matching and no
fallback node.

## Entry points

```
shz node.shio                    interactive node host
shz node.shio --name Box --description "GPU box"   node with a routing identity
shz telegram_router.shio --bot-token <token>
                                 Telegram front end: trusted chats on disk, plain text is a
                                 router-agent turn, every node event (task finished on any
                                 node, notify, online/offline) is pushed to the chats
shz router.shio                DEMO router CLI: plain text is a router-agent turn
                                 (console: /nodes, /tasks, /overview [node],
                                  /route <text>, /node <node> <text>, /addworker,
                                  /notify, /clear, /config, /help, /exit)
shz router.shio "task text"    single shot: one agent turn, print the answer
shz router_selftest.shio         full-stack seam test (Router + protocol + role tools),
                                 stub nodes + stub agent turn, no LLM, prints ALL PASSED
shz telegram_router_selftest.shio front-end test (TelegramRouter + fake bot + stub nodes),
                                 trusted chats + finish notifications, ALL PASSED
shz shizonet_ai_selftest.shio    protocol-only test (node service + router service), ALL PASSED
```

`router.shio` is a **demo application** — it `#include`s `router_api.shio`, the class. Library
code includes `router_api`, never `router` (that starts the CLI). The product is the `Router`
class plus the `router` role: embed them in a telegram bot, a web front end, anything
(`on_event` is the notification hook, `request()` / `route_task()` are the entry points).

CLI commands of `router.shio`: `/nodes`, `/tasks`, `/overview [node]`,
`/route <text>` (router-agent turn), `/node <node> <text>` (explicit delegation, no agent
turn), `/addworker <node> <name> <goal>` (direct worker-pool task, bypasses the remote
receptionist), `/notify <text>`, `/config`, `/help`, `/exit`.
