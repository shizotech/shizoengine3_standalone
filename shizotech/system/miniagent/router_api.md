# Gateway (router) ⇄ Node protocol (ShizoNet)

This is the **binding contract** between an AI **node** (a `Node` host, see
`node_lib.shio` / `workspaces.shio`) and an AI **router** (a `Router()` class, see
`router_api.shio`; the Telegram gateway is one). Both sides are plain ShizoNet servers on the
same private network: they discover each other automatically via beacons, no IPs are
configured anywhere. Nodes use the same protocol among themselves for the web interface
(`ai_api`).

```
telegram bot / CLI  ──►  Router()  ── ShizoNet ──►  node A (Node + WorkspaceRegistry: workspaces, worker sessions)
                            │                     ►  node B (Node + WorkspaceRegistry: workspaces, worker sessions)
                            └── on_event(cb)  ◄── ai_event pushes from every node

browser ──► node A (web interface) ── ai_api ──► node B        the same JSON API, without HTTP
```

The routing intelligence is the **router agent** — a `miniagent` running the `router` role
(`roles/router/`). That agent reads the fleet with `get_nodes()` (nodes **and their
workspaces**), decides *which node and which workspace* own a request and starts it with
`start_task()`. `Router()` is the substrate around that agent: it executes the agent's
decisions over ShizoNet, keeps the threads and a local mirror of the remote tasks and forwards
node events to its owner (a telegram bot registers `on_event`).

**A node has no agent in front of its work** (2026-11, #1015; before, a *receptionist* agent
on the node took every request and re-delegated it to a worker). A request of a router becomes
a **worker session in a workspace** of the node, directly: the worker reads the user's own
words, keeps the conversation, and a follow-up is a new prompt in the same session. The router
therefore has to say *where* (node + workspace) and has to remember *which session* a
conversation lives in: that is the **thread** (below).

**There is no keyword/capability scoring anywhere in the routing path.** The node table
(name, description, model, load, workspaces) is handed to the agent as data;
choosing the node and the workspace is the model's job. `Router.add_task()` refuses an empty
node name instead of guessing one, and an unknown workspace with the list of the ones the node
has.

All wire code lives in `shizonet_ai.shio`:

```
#include "shizonet_ai"

# node side (Node.start_shizonet, after the shizonet server exists)
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
* **An `on_get` handler never calls `device.get()`** (that deadlocks the transport), and the
  request handlers only enqueue work and return. Each GET is answered by a task of its own, so
  a handler that waits holds back only its own answer: `ai_api` uses that for the long-poll
  routes (`/api/live`, `.../events`), which answer when something changed (checked 2026-11
  with a 20 s long-poll and other calls to the same node next to it).
* **No JSON boolean in a payload.** A `json.bool` (what `std.json(text)` makes of `true`) is
  not deserialized by the receiver: the whole payload is dropped ("invalid json payload").
  `ai_wire(value)` turns every boolean into 1/0 and is applied to every reply, every pushed
  event and the node info; `ok` / `busy` / `online` / `goals` are tested for truthiness, never
  compared with a literal `true`. (Found 2026-11: the `ai_task` answer of a real session
  carried booleans and never arrived, a stub node's did.)
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
    busy           = 1|0,           # a request turn or workspace tasks running
    tasks_running  = int,           # across all workspaces
    tasks_planned  = int,           # across all workspaces
    goals          = 1|0,           # the Node's own Workspace runs a GoalScheduler (an .agentspace): it can do
                                    # scheduled work at set times; 0 = its goal tools refuse
    api            = 1|0,           # the node answers ai_api (its JSON API over ShizoNet)
    workspaces     = [[id, name, description, path, parent], ...],     # at most 64 (AI_INFO_MAX_WORKSPACES);
                                    # the first one is the node's own ("General", id "node")
    uptime_ms      = int,
]
```

`goals` is presence only (the node knows whether it started a scheduler), never a file scan.
`Router._apply_node_info` mirrors `goals`, `api` and `workspaces` into the node record and
`nodes_summary()` hands them to the router agent: it picks the workspace from that list (the
description of a workspace, set when it is created, is the routing hint) and can tell the user
that a node has no goal system **before** routing a schedule there.

## Commands (node answers, router asks)

All payloads and replies are JSON objects. Every reply carries `ok = true|false`; on
`false` it carries `error`. Unknown `taskid` / `request_id` → `ok = false`,
`error = "not found"`.

| Command | Request | Reply |
|---|---|---|
| `ai_info` | `[]` | node info json |
| `ai_request` | `[prompt, workspace?]` | `[ok, request_id, status="queued"]` |
| `ai_request_poll` | `[request_id]` | `[ok, request_id, status, delta?, result?, error?]` |
| `ai_request_stop` | `[request_id]` | `[ok]` |
| `ai_request_update` | `[request_id, message]` | `[ok, request_id, state="updated"]` |
| `ai_overview` | `[]` | `[ok, overview]` — exactly `Node.get_overview()` across workspaces |
| `ai_tasks` | `[]` | `[ok, tasks]` — flattened task list across all workspaces |
| `ai_task` | `[taskid]` | `[ok, task]` — a task in any workspace |
| `ai_task_add` | `[name, goal, workspace?]` | `[ok, taskid, name, state="planned", workspace_id?]` — a worker session in that workspace (an id or a name; empty: the node's own). An unknown workspace is refused with the names the node has |
| `ai_task_update` | `[taskid, message]` | `[ok]` — a prompt into that session: a running turn is interrupted and continued with it, a finished session starts a new turn |
| `ai_task_stop` | `[taskid]` | `[ok]` |
| `ai_goals` | `[action="list"]` | `[ok, goals]` — the Node's own Workspace scheduled goals (`GoalScheduler.overview()`) |
| `ai_goals` | `[action, goal]` | `[ok, goal, from, to]` / `[ok, queued]` — `run`, `pause`, `resume`, `activate`, `cancel`, `archive`, `complete` |
| `ai_api` | `[method, path, body?, query?]` | `[ok, status_code, body]` — one call of the node's JSON API (`node_api.md`, `workspace_spec.md`) |

`ai_goals` answers `ok = false` on a node without an `.agentspace` (goals off). A `run` is
queued for the node's scheduler thread; a status change moves the goal folder
(`goals_spec.md`).

**`ai_task_add` is the path of user work.** The router's `start_task` uses it: the task is a
worker session (role `adaptive`) of the workspace, marked `origin = "net"`. Its `taskid` is the
session id; `ai_task` polls it, `ai_task_update` continues it, also after it finished.

**`ai_request`** is one blocking worker turn (`Node.request(prompt, ..., workspace)`): a new
session in the workspace (empty: the node's own), the answer is its report. It is for a
question that wants an answer now (`Router.delegate`, the `/node` command of the demo console),
not for work that will get follow-ups. Its poll status lifecycle is the node_api one:
`queued → generating → waiting → done | error`.
`delta` is a raw agent action (`text` / `reasoning` / `tool_start` / `tool_end`).
`result` is the normalized turn result: `[ok, reports=[[report=...]], error, execution_time_ms]`.
`ai_request_update` applies `message` to the turn that owns `request_id`: a running turn gets
it as a prompt into its session, a queued one gets it appended to its prompt, a finished /
reaped / unknown one answers `[ok = false, error = "not found"]`.

### `ai_api` — the JSON API of a node without HTTP

```
dev.get("ai_api", [method = "GET", path = "/api/workspaces", query = [since = "7"]], 15000)
    -> [ok = 1, status_code = 200, body = "{\"ok\":true,\"data\":{...}}"]
dev.get("ai_api", [method = "POST", path = "/api/workspaces", body = [name = "Shop"]], 15000)
```

One call of the route table the node's HTTP server uses (`api_router.shio`, `ApiRouter.dispatch`):
the same handlers, the same answers. `body` is the response **text** (JSON as the HTTP route
would send it), so booleans in it survive the wire. A node answers it whether it has a web
server or not; `status_code = 501` means the host has no API table (a stub).

The node's own API token is **not** needed and not sent: who is on the ShizoNet network may
drive the nodes (the same trust the other `ai_*` commands have). The HTTP side keeps its token:
the web interface of node A asks for A's token, then calls B through A
(`/api/nodes/<id>/api/...`, `web_ui.shio`), and A strips the `token` query before it passes the
call on. A stream route cannot travel in one answer: the session stream is served by
long-polling `GET /api/sessions/<id>/events?since=<seq>&wait=<ms>` on B and writing the events
as SSE on A (`web_ui_remote_stream`). `NodePeers.call(id, method, path, body, query, timeout)`
(`node_peers.shio`) is the caller.

## Events (node pushes, router receives)

Command `ai_event`, sent with `broadcast("ai_event", payload)` by the Node whenever a
Workspace task-finished, notify or file listener fires, and on node state changes.
The router answers `"ok"` (it registers `on_get("ai_event", ...)`); no other device does.

```
[
    kind    = "task_finished" | "notify" | "file" | "node_state",
    time    = <ms on the node>,
    node    = <node name>,
    # task_finished (one per TURN of a session: a continued session finishes again):
    taskid, name, state, report, error,
    workspace_id,                   # the workspace of the session
    origin,                         # "net" (started by a router / another node), "web" (the web
                                    # interface), "" (a scheduled goal, a tool of an agent)
    # notify:
    message,
    # file (send_file of a workspace agent, forwarded by Workspace):
    name, bytes, caption, data = <base64 of the file>,
    # node_state:
    online = bool,
]
```

### The `on_event` stream (node pushes + the router's own kinds)

| kind | payload | source |
|---|---|---|
| `task_finished` | `[kind, time, node, taskid, name, state, report, error, workspace_id, origin, thread, workspace, turn, origin_chat]` | node push; the last four are added by the Router when the task is one of its threads |
| `notify` | `[kind, time, node, message]` | node push (`notify_user` on the node) |
| `file` | `[kind, time, node, name, bytes, caption, data]` | node push (`share_file` on the node, the `send_file` tool); `data` is base64 |
| `node_state` | `[kind, time, node, online]` | node push + the router's own discovery |
| `task_state` | `[kind, time, node, taskid, name, state, prev, report, error, thread, workspace, turn, origin_chat]` | the router's mirror moved a task |
| `task_stalled` | `[kind, time, node, taskid, name, state, idle_ms, error, thread, workspace, turn, origin_chat]` | the router's stall watchdog |

`thread` is the label of the thread (`T12`), `workspace` its workspace name, `turn` the number
of the turn that ended (a front end announces a task once per turn: key `taskid#turn`),
`origin_chat` the chat that started it (0: none, a scheduled goal or a session of the web
interface).

`task_state` gained `error`: the failure text of that transition — the node's `status="error"`
answer, `"node offline for N min"`, `"remote request expired"`, `"no reply from node"`, ... — and `""` when
there is none. A front end renders it, so the user sees **why** a task failed, not only that it
did. `report` stays the node's report on a terminal state.

`task_stalled` fires when an **open** task (`queued` / `generating`) made no progress for
`Router.stall_ms` (default `ROUTER_TASK_STALL_MS` = 900000 = 15 min, `opts.stall_ms` overrides,
`0` turns the watchdog off): no state change, no report/delta, no poll returning new data —
progress is recorded in the mirror record's `last_progress`. At most one event per stall
episode; `idle_ms` is how long the task has been silent. A task that reports again is not
announced as stalled a second time.

The router appends every event to `events` (capped at 200), mirrors task state into its
remote task table, and calls the owner callback registered with `Router.on_event(cb)`.
That is the telegram hook: a bot subclass does `router.on_event([](e) { send_to_telegram(e); })`.

**One event per fact.** A node coming online is visible on two channels: the router
discovers it (`shizonet on_connect` → `_register_node`, which emits `node_state`) and the
node pushes `node_state` over `ai_event`, in either order. The router announces the
transition itself and drops the node's push of a state it has already announced (per node
record `online_announced`). A push that arrives first, before the router has a record under
the node's display name (not registered yet, or its AINodeInfo not fetched yet), is passed
on and remembered (`_pushed_online`), and the router's own announcement is skipped then.
When `refresh_nodes()` and `on_connect` register the same node at the same time, only the
call that saw the transition announces it (an owner token, #513). Same rule for a finished task: when the poller already moved the
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
                                   #        on_event, on_notify, on_action, poll_ms, stall_ms,
                                   #        threads_path (file of the thread table; none: memory only),
                                   #        adopt_web (announce sessions of the web interface too)]
    running = true;

    request(prompt, on_finish_cb = None, on_action_cb = None)   # one router-agent turn, queued
        # The result is normalized by `_turn_result`: the role's `finish(report)` /
        # `finalize(signal, result)` sets `agent.task_result`, and the Router folds
        # that into the legacy owner-facing shape `[ok, reports=[[report=...]]]`.
        # The report is the answer and the turn is ok when the signal is not failed.
    stop()

    nodes()                        # online node records
    nodes_summary()                # routing table handed to the agent (no device objects):
                                   # name, description, capabilities, tags, model, load,
                                   # open tasks, `goals` (does the node run a scheduler) and
                                   # `workspaces` ([id, name, description])
    refresh_nodes()                # re-discover + re-fetch ai_info
    delegate(node_name, prompt, workspace = "")   # one request (ai_request), no agent turn -> [ok, taskid, node]
    route_task(prompt, node_name = None, workspace = "")
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
    add_task(name, goal, node_name, mode = "worker", workspace = "")
        # role tool entry point, -> taskid (None on failure)
        # node_name is REQUIRED: the agent picks it from get_nodes(). Empty, unknown
        #   or offline node -> None. This class never invents a node.
        # workspace: an id or a name of a workspace of that node ("" = the node's own,
        #   "General"). Unknown -> None, add_task_error() names the ones the node has.
        # mode "worker" (default): a worker session in that workspace (ai_task_add) — the
        #   path of user work. The record is a thread (T<n>).
        # mode "request": one blocking request turn (ai_request); "receptionist" is accepted
        #   as its old name.
    add_task_error()               # -> string: the reason of the LAST add_task failure (""
                                   # after a success): "node offline: X", "unknown node: X",
                                   # "empty node name", "unknown workspace 'Y' on node 'X'. Its
                                   # workspaces: ...", "the node did not answer". `add_task` returns only
                                   # taskid|None, so this is how the role tool tells the user
                                   # WHY the node refused.
    update_task(taskid, message)   # -> bool. taskid: a taskid or a thread label ("T12").
                                   # An open task gets the message into its running turn; a
                                   # finished / failed / question / stopped worker thread is
                                   # REOPENED: the message starts a new turn in the same session
                                   # (state back to generating, turn + 1).
    update_task_error()            # -> string: why the last update_task returned false
    threads_summary(limit = 12, origin_chat = 0)
        # the threads, newest first: [thread, taskid, node, workspace, title, state, open,
        #   turns, minutes_ago, first_message, last_message, last_report, continuable];
        #   origin_chat restricts to the threads one chat started
    turn_context(origin_chat = 0, max_threads = 8)
        # text for the router agent's turn: the tasks of this conversation and the nodes
        # with their workspaces (the front end puts it in front of the user's message)
    turn_text / turn_origin        # set by the front end before request(): the user's words of
                                   # this turn (start_task without `task` sends them verbatim)
                                   # and who asked ([chat = <id>]) — the origin of the threads
                                   # the turn starts
    stop_task(taskid)              # -> bool
    inspect_task(taskid)           # -> task json | "Not found."
    tasks_summary(state = None, node_name = None)
        # the router's own task mirror as a compact serializable list, newest first:
        # [taskid, node, name, state, open, goal, report, last_error,
        #  user_updates, created, updated]
        # state: "all" (default) | "open"/"running" (queued+generating) |
        #        "finished" | "failed" | "question" | "stopped" | "lost"; node_name restricts to one node.
    get_overview()                 # nodes + remote_tasks + events, device objects stripped
    notify_user(msg)
    on_notify(cb) / on_event(cb) / on_action(cb)
}
```

Remote task record (the router's mirror, one per thread):

```
[taskid, node, nodeid, remote_request_id, remote_taskid, name, goal, state, report,
 created, updated, last_poll, last_error, last_progress,
 thread, seq, workspace, workspace_name, origin, turn, turns, user_updates]
```

`remote_taskid` is the session id on the node (a worker thread; `remote_request_id` is set for
an `ai_request` instead), `thread` is `"T" + seq` (a counter that survives restarts),
`workspace` the workspace id on the node, `origin` who started it (`[chat = <id>]`), `turn` the number of the current turn and
`turns` the last `ROUTER_MAX_TURNS_KEPT` (6) turns as `[user, report, state, time]`, each text
cut to `ROUTER_TURN_TEXT_CHARS` (400): enough for the router agent to recognise a
conversation, the session on the node has all of it. The table is written to
`opts.threads_path` (the gateway: `gateway_threads.json` next to its trust file) at most every
2 s and loaded at start: a follow-up finds its session after a restart of the gateway.

`last_error` is the reason of the last failure/loss (rendered into the `task_state` event's
`error`), `last_progress` the ms timestamp of the last visible progress (state change, report,
delta, a poll with new data) — the stall watchdog measures against it.

`state`: `queued | generating | finished | failed | question | stopped | lost`
(`question` is terminal: the node's `finalize(signal=question, result=...)` needs the owner. `lost` means the
node/task is definitively gone — after a grace period while the node is offline, or a
definitive `not found` with no report. A transient poll failure keeps the task open.)

### Threads (why a follow-up reaches the worker that did the work)

The problem: with workers started directly, "make the button blue instead" three messages
later must not start a new worker that has never seen the button. The answer is not a second
agent on the node that remembers; it is that **the task is the conversation**:

1. `start_task` opens a worker session in a workspace and the router records the thread.
2. Every turn of the router agent starts with `turn_context()`: the threads of this chat
   (label, node / workspace, title, state, the last user message and the last report).
3. A message that continues one of them is passed on with `update_task(thread)`: into the
   running turn, or as a new turn of the finished session. The worker has its whole history.
4. A message that starts something else is a new `start_task`. A message the agent cannot
   place is answered with a question, not routed on a guess.

A guest chat of the gateway skips the agent: it is bound to one node + workspace and has one
current thread, which every message continues until `/new`.

### Mirror rules (why one user goal is exactly one task)

* **One goal, one task.** `add_task` is idempotent: the same goal text on the same
  node and workspace while that task is still open returns the **existing** taskid and starts
  nothing new. It is exact-match idempotence (goal text + node), not guessing: it
  covers an agent that routes one goal twice and a transport that delivers one
  message twice.
* **Adoption.** A node `task_finished` push with a taskid the mirror does not know is
  work the router did not start. With `origin = "web"` it is dropped: a session someone runs
  in the web interface of a node is theirs, a chat has nothing to do with it
  (`opts.adopt_web` passes those on too). Anything else (a scheduled goal, `origin = ""`) is
  passed to `on_event`, as intended: its report goes to the owner chats. While the node has
  an open `ai_request` of this router, an unknown finish is the session of that request and
  is not adopted (the request record is settled by `ai_request_poll`). A task this router
  started is announced whatever its origin.
* A front end must deduplicate its inbound messages too: Telegram can replay an
  update (`telegram_router.shio` ignores the identical text from the same chat inside
  `TG_DEDUPE_MS`).

## Router role surface (`roles/router/ROLE.shio`, `agt.env.router` = the Router)

Exactly these tools, nothing else — the router cannot execute, only route:

| Tool | Backed by |
|---|---|
| `get_nodes()` | `router.nodes_summary()` — includes per node `goals` (goal system available?) |
| `get_node_overview(node)` | `router.node_overview(node)` |
| `get_tasks(state?, node?)` | `router.tasks_summary(...)` — the fleet-wide task mirror |
| `get_goals(node?)` | `router.goals(node)` — the scheduled goals of the nodes (`ai_goals`) |
| `start_task(node, name, workspace?, task?, summary?)` | `router.add_task(name, task, node, "worker", workspace)`; without `task` the worker gets the user's message verbatim (`router.turn_text`); answers `[thread, taskid, name, node, workspace]`; a refusal answer carries `router.add_task_error()` |
| `update_task(taskid, message?)` | `router.update_task(...)`; `taskid` may be the thread label; without `message` the user's message verbatim; "The message was NOT delivered. Reason: ..." carries `router.update_task_error()` |
| `stop_task(taskid, reason?)` | `router.stop_task(...)` |
| `inspect_task(taskid)` | `router.inspect_task(...)` |
| `get_last_actions(limit?)` | `agt.env.last_actions` |
| `notify(message)` | `router.notify_user(...)` |
| `finish(report)` | ends the turn; `report` is the text the owner shows the user (mandatory, never empty) — the **only** channel to the user, so every tool error belongs in it |

`node` arguments are node **names** as shown by `get_nodes`, `workspace` a workspace name of
that node; the role must pick them before `start_task` and must never invent one. A request
it cannot place is answered with a question to the user. Picking it is the **agent's** job (the model, reading
the routing table), never the runtime's: `Router` has no scoring, no keyword matching and no
fallback node.

The role prompt (`roles/router/ROLE.md`, "Feedback to the owner") binds the agent to relay what
the tools answered: the concrete `add_task_error()` reason of a refused delegation, and the fact
that a node has `goals=false` when the user asked for scheduled work. A request that cannot
become a goal on that node is **reported**, never quietly routed as plain work.

## Entry points

```
shz miniagent --node [--web]     a node (README.md, "Node")
shz miniagent --node --name Box --description "GPU box"   node with a routing identity
shz miniagent --telegram-gateway [--bot-token <token>]
                                 the Telegram gateway: owner and guest chats on disk, plain text
                                 is a router-agent turn, every terminal fact of a task is pushed
                                 to the chat that started it
shz router.shio                DEMO router console: plain text is a router-agent turn
                                 (/nodes, /tasks, /overview [node],
                                  /route <text>, /node <node> <text>, /addworker,
                                  /notify, /clear, /config, /help, /exit)
shz router.shio "task text"    single shot: one agent turn, print the answer
shz router_selftest.shio         full-stack seam test (Router + protocol + role tools),
                                 stub nodes + stub agent turn, no LLM, prints ALL PASSED
shz telegram_router_selftest.shio front-end test (TelegramRouter + fake bot + stub nodes)
shz shizonet_ai_selftest.shio    protocol-only test (node service + router service), ALL PASSED
```

`router.shio` is a **demo application** — it `#include`s `router_api.shio`, the class. Library
code includes `router_api`, never `router` (that starts the CLI). The product is the `Router`
class plus the `router` role: embed them in a telegram bot, a web front end, anything
(`on_event` is the notification hook, `request()` / `route_task()` are the entry points).

CLI commands of `router.shio`: `/nodes`, `/tasks`, `/overview [node]`,
`/route <text>` (router-agent turn), `/node <node> <text>` (explicit delegation, no agent
turn), `/addworker <node> <name> <goal>` (a worker session via `ai_task_add` in the node's own
workspace), `/node <node> <text>` (one `ai_request` turn), `/notify <text>`, `/config`, `/help`, `/exit`.
