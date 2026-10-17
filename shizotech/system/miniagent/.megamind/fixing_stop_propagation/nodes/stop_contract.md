# stop contract (miniagent)

Durable facts, promoted to `README.md` § Stop.

- `miniagent.stop()`: sets `stopped`, calls `llm_api.stop()`, then recurses into
  every entry of `_child_agents` (snapshot taken under the named critical section
  `miniagent_tree`, because tool threads mutate the list concurrently).
- `_child_agents` is the propagation path. Only falsy entries may ever be pruned.
  A live child dropped from the list is a child that keeps generating after a stop.
- `ancestor_stopped()` walks `_parent` (miniagent only, `std.is_class` guard).
  `should_stop() = stopped || ancestor_stopped()`.
- `task()` refuses to start when `ancestor_stopped()` and returns
  `[ok=false, stopped=true, reports=[], error="The agent was stopped by its parent before the task started."]`.
  A new run clears only the agent's OWN stop flag — that is what keeps
  `send_prompt()` (self-stop then task) and `continue_task` working.
- `subagent()` / `simple_agent()`: a child created while the parent is stopped is
  born stopped (`sub_agt.stop()` right after registration).
- A child's own `stop()` (signal/finalize tools) never touches the parent.
- `task()` never fires the finalize nudge (`llm_api.task("Summarize ...")`) while
  stopped; a stopped run with no reports returns the stopped shape, not a crash.
- Blocking tools poll `should_stop()`: `sleep` (chunked, 250 ms),
  `cmd_wait_for_output` / `cmd_wait_for_exit` via an optional `stop_check`
  predicate. The process is never killed, only the wait ends.
- adaptive role: `parallel_run_guard` bails out on a stop and treats
  `max_running_agents <= 0` as unlimited (matches `batch_max_parallel`);
  `start_task` / `continue_task` / `fork` / `file_task_batch` stop their executors
  and return an explicit stopped payload instead of `return;` (None → empty tool
  result → the model keeps generating).
- `Megamind.stop_task()` stops a running worker; `worker_thread` skips the
  implement phase when the worker is stopped (worker.task() clears the worker's
  own stop flag, so phase 2 would have restarted generation).

See [root cause](root_cause_child_registry.md), [other stop holes](other_stop_holes.md).
