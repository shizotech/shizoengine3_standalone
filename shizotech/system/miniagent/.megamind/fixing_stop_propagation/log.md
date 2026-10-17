# log

2026-10-17 reproduced: root.stop() reached 1 of 3 children and 0 grandchildren
(testbench/fixing_stop_propagation/probe_stop.shio).
2026-10-17 root cause: subagent() "clear old entries" loop erased live children;
simple_agent() same loop spun forever. Fixed + tree lock + snapshot in stop().
2026-10-17 added ancestor_stopped()/should_stop(), born-stopped children, task()
guard, no finalize nudge after stop, stopped result shape.
2026-10-17 fixed sleep (ms + interruptible), parallel_run_guard (0 cap, stop
aware, slot accounting), adaptive tool stop payloads, batch scheduler, command
wait stop_check, Megamind.stop_task + worker phase guard.
2026-10-17 tests/stop_propagation_test.shio: 45 checks ALL PASSED. Regression:
router 94, shizonet_ai 94, node_api 37, telegram_router 69 — all passed.
2026-10-17 promoted the contract to README § Stop; landmines in avoid.md.
2026-10-17 re-verified for the user: `shz tests/stop_propagation_test.shio` -> 45/45 passed.
