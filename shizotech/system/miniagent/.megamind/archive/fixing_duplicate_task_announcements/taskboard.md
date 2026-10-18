# Taskboard

Baseline: `router_selftest` 93/94 (1 environmental: a background `AIBackendServer`
shizonet node on this machine), `telegram_router_selftest` 68/69 (the
"answer promises the completion notification" check had been failing all along),
`shizonet_ai_selftest` 94/94, `node_api_selftest` 37/37, `tests/stop_propagation_test` 45/45.

- [x] 1. `megamind.shio`: `on_task_started(cb)` + fire it from `add_task`
- [x] 2. `shizonet_ai.shio`: `current_request_id`, `pending_events` queue, `task_started` push
- [x] 3. `router_api.shio`: handoff records (`handoff`, `ack`, `acked_at`, `handoff_settle_ms`)
- [x] 4. `router_api.shio`: `_poll_task` — ack is not a completion, no request poll after the ack
- [x] 5. `router_api.shio`: `_mirror_event` — bind on `task_started`, settle on `task_finished`
- [x] 6. `roles/router/ROLE.shio` + `ROLE.md`: the router names nothing
- [x] 7. `telegram_router.shio`: routed answer promises the notification; `task_started` rendering
- [x] 8. `router_api.md`: `task_started` event, handoff mirror rules
- [x] 9. `README.md`: events bullet + test counts
- [x] 10. `shizonet_ai_selftest.shio`: `task_started` checks -> 105/105
- [x] 11. `router_selftest.shio`: handoff contract checks -> 114/114
- [x] 12. `telegram_router_selftest.shio`: one task name per routed goal -> 83/83
- [x] 13. `node_api_selftest` 37/37, `tests/stop_propagation_test` 45/45 (no regression)
- [x] 14. `router.shio` demo CLI renders `task_started`
- [x] 15. final serial re-run: router 114/114, telegram 83/83, shizonet_ai 105/105,
  node_api 37/37, stop_propagation 45/45, model_config 24/24
- [x] 16. Mind pruned, topic archived

Deferred (not required by this task):
- `Megamind` keeps only 5 finished/failed tasks, so a late `ai_task` poll of a settled
  task answers `not found`; harmless now, worth a bigger ring later.
- `stop_task` on an acked handoff with no bound task can only stop the mirror, not the
  node's work (the receptionist turn is over). Bounded by the node naming its task.
- The router selftests are sensitive to other shizonet nodes on the machine; the
  node_state check now filters to the fixture's own node names.
