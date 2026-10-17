# taskboard

- [x] reproduce: stop() reaches only the newest child (probe_stop.shio)
- [x] miniagent.subagent(): prune only dead entries, i-- inside the if, tree lock
- [x] miniagent.simple_agent(): same fix (loop also spun forever)
- [x] miniagent.stop(): snapshot children under the lock, guard llm_api.stop, recurse
- [x] ancestor_stopped() + should_stop() ancestor-aware
- [x] children born stopped under a stopped parent
- [x] task(): refuse to start under a stopped ancestor; no finalize nudge after stop;
      stopped result shape instead of "crashed"
- [x] sleep tool: ms unit + interruptible
- [x] adaptive role: parallel_run_guard (unlimited cap, stop-aware, slot accounting),
      start_task / continue_task / fork / batch_run_child / batch scheduler stop-aware
- [x] SHARED.shio command waits: optional stop_check
- [x] megamind: stop_task stops the running worker; worker_thread skips phase 2
- [x] tests/stop_propagation_test.shio -> 45 checks, ALL PASSED
- [x] regression: router 94, shizonet_ai 94, node_api 37, telegram_router 69 -> ALL PASSED
- [x] README § Stop + § Tests

# deferred (not required by this task)

- `_child_agents` grows for the lifetime of a parent (no pruning of finished
  children). Bounded by the number of tasks one agent creates; pruning finished
  children is unsafe because `continue_task` must still reach them.
- `env.tasks[i].agent` keeps a JSON reference to every child (the adaptive role);
  combined with `_parent` this is a cycle — the code comments already flag it.
- `parallel_run_guard` slot accounting is still a read-then-increment race
  (over-subscription by at most one per race).
- `tests/mind_*.shio` / `receptionist_tools_test.shio` reference a missing
  `runtime/` directory.
