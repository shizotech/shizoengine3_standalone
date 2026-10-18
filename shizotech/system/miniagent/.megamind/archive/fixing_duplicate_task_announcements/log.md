# Log

2026-10-18 traced the duplicate "Task X started" to the router agent's finish report
(router-invented name) + the receptionist ack rendered as a task completion; found the
dropped node completion and the spurious `lost` after the request TTL. Design decided,
see nodes/handoff_design.md.

2026-10-18 implemented the handoff: `Megamind.on_task_started`, the `task_started`
ai_event (taskid/name/task/request_id, queued through `pending_events`), handoff records
in `Router` (`handoff`/`ack`/`acked_at`/`handoff_settle_ms`), bind on `task_started`,
settle on `task_finished`, no request poll after the ack, router role names no task,
telegram routed answer promises the notification. Docs (router_api.md, README.md) updated.
All selftests green (114/83/105/37/45/24). Repro: testbench/fixing_duplicate_task_announcements/probe.shio.
