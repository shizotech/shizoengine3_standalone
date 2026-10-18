# The fix: a delegated ai_request is a HANDOFF, the node owns the task

One user goal = one mirror record, and that record's visible identity is the
**node's** task, not a name the router invented.

## Wire addition (shizonet_ai.shio)

New node push `kind = "task_started"`: `[kind, time, node, taskid, name, task, request_id]`.
`request_id` = the delegated request whose receptionist turn created the task, `""` for
work the node started on its own.

- `Megamind.on_task_started(cb)` fires from `add_task` (the task is planned).
- `AiService.current_request_id` is set in `worker_loop` around `host.request(...)`,
  so the push can name the request that owns the task.
- `add_task` can be reached on the ShizoNet script thread (`ai_task_add`), and handlers
  must not touch the transport -> the push goes through `AiService.pending_events`,
  flushed by `refresh_loop` (the same pattern as `pending_state`).

## Router mirror (router_api.shio)

A record created through `ai_request` is `handoff = true`.

- request status `done` = the node **accepted** the goal. Store `ack`/`acked`/`acked_at`,
  keep the record open in `generating`, emit NO transition.
- `task_started` whose `request_id` matches an open handoff record -> bind:
  `remote_taskid = taskid`, `name = <the node's task name>`, state `generating`.
  No new mirror entry.
- `task_finished` settles the record (by `remote_taskid`, or by "the node has an open
  handoff" as the fallback for nodes that never send `task_started`). Exactly one
  transition, carrying the node's name and the node's report.
- After the ack the request id is never polled again (kills the spurious `lost`).
  Bound -> poll `ai_task`. Unbound -> settle as `finished` with the ack after
  `Router.handoff_settle_ms` (the receptionist answered and spawned no task, e.g. a
  question). The receptionist creates its task *during* the turn, so `task_started`
  arrives before the ack: the window only covers event latency, not the task runtime.
- request status `error` on a handoff = the receptionist turn itself failed -> settle
  `failed` (that is news).
- `ai_task` "not found" on a handoff record is ignored (the push settles it;
  `_on_disconnect` marks it `lost` if the node dies).
- The `task_finished`-for-an-unknown-taskid fallback picks the **newest** open handoff
  record of that node: the node announces the task it created for the goal the router
  delegated, and the newest record is the one that goal became. (Oldest-first broke
  `router_selftest` section 9: the probe is the newest goal, the old worker-mode
  record with the same goal is older.)

## Front end / role

- `roles/router/ROLE.shio` `start_task` suggestion: do NOT name the task to the user,
  the node names its own task; report the node and that the chat will be notified.
  Its return json drops `name` entirely, so the model cannot quote it.
- `TelegramRouter.tg_answer_text`: a routed turn goes through `tg_routed_text`, which
  appends "I will report back here when it is done." (idempotent: skipped if the agent
  already promised it). This is what `telegram_router_selftest`'s
  "the answer promises the completion notification" check has been demanding, and
  failing, since it was written.
- `tg_render_event`: `task_started` renders only in `tg_events = "all"`; in the default
  "reports" mode the chat hears nothing until the goal finishes/fails.
- `router.shio` (demo CLI) renders `[started] <node> <name>`.
- `Router` opts gained `handoff_settle_ms`; `TelegramRouter` passes it through
  (`tg_super_opts`). Tests use 500-2000 ms.

## Verified

`router_selftest` 114/114, `telegram_router_selftest` 83/83, `shizonet_ai_selftest`
105/105, `node_api_selftest` 37/37, `tests/stop_propagation_test` 45/45,
`model_config_selftest` 24/24. Selftests must run SERIALLY: they all want UDP 6454,
and a second process binding it loses discovery.

Repro of the binding path: `testbench/fixing_duplicate_task_announcements/probe.shio`
(delegate -> ack -> bind -> settle, prints the mirror and the event stream).

Related: [two messages](two_messages.md), [avoid](../avoid.md)
