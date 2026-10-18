# Why one routed goal produced two "Task X started" messages

Owner sends text in a trusted Telegram chat. Path:

1. `TelegramRouter.tg_run_turn` -> `Router.route_task` -> router agent turn ->
   role tool `start_task` -> `Router.add_task` -> `_delegate` -> `ai_request` on the node.
2. `_delegate` -> `_add_remote_task` mirrors a record named by the **router agent**
   (`roles/router/ROLE.shio` `start_task`: `name + "-" + random_hash(6)`).
3. **Message 1** = the router agent's `finish(report)` answer. The tool's
   `suggestion` says "Tell the user the task name and the node it runs on", so the
   report is "Task <RouterName>-xxxx started on <Node>".
4. The node's receptionist runs the prompt, creates **its own** task
   (`roles/receptionist/ROLE.shio` `start_task` -> `Megamind.add_task`) and answers
   with its own name. That answer is the `ai_request` `result`.
5. **Message 2** = `Router._poll_task` maps the request status `done` to mirror state
   `finished` -> `_set_task_state` emits `task_state(finished, report=<the receptionist's
   ack>)` -> `tg_render_event` renders `[done] <Node>: task <RouterName> finished` +
   the ack text, which is "Task <NodeName>-yyyy started".

So both messages say "started", with two different names.

## Two further defects found on the way

- `_mirror_event` **drops** the node's `task_finished` push while the node has an open
  delegated request (router_api.md "Adoption"), so the real completion of the goal
  never reaches the chat. The user gets a fake completion (the ack) and no real one.
- After the ack the poller keeps polling the request id. The node's reaper drops a
  finished request `AI_REQUEST_TTL_MS` (120 s) after its **last poll**, so a long node
  task is answered `not found` -> `_set_task_state(rec, "lost")` -> a spurious
  `[lost] <Node>: task X lost` for work that is running happily.

Related: [handoff design](handoff_design.md)
