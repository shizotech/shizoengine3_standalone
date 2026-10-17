# other stop holes found on the way

All confirmed by probe/test, all fixed.

1. **finalize nudge after a stop** — `task()` fires
   `llm_api.task("Summarize your last actions so far with ONE SINGLE call to finalize()!")`
   when `env.use_finalize` is set and no report exists. A stop in the middle of the
   turn produced a brand new generation request. Repro:
   `testbench/fixing_stop_propagation/probe_double.shio` (explorer role, 2 stub
   calls for 1 `task()`).
2. **resurrection through `stream.start(reset_stop=true)`** — the first stream of a
   `task()` call clears `_stop_stream` (openai.shio). A stop that lands between
   `task()` entry and the stream start is undone. Guarded by the
   `ancestor_stopped()` check at the top of `task()` + born-stopped children.
3. **`sleep` tool**: `std.sleep(args.duration)` — `std.sleep` takes **milliseconds**,
   so "600 seconds" slept 600 ms, and it was not interruptible. Now ms-correct and
   chunked (250 ms) with a `should_stop()` check.
4. **`parallel_run_guard`**: `for(count >= max_running_agents)` with the default
   `max_running_agents = 0` blocks forever (0 >= 0), and the queue never notices a
   stop. `__deinit__` also decremented a slot that was never taken.
5. **`file_task_batch` scheduler** kept launching items after a stop;
   `batch_run_child` returned without publishing a terminal state.
6. **`start_task` / `continue_task`** did `return;` (None) on a stop → the openai
   layer turns None into an empty tool result and the model keeps generating.
7. **`Megamind.stop_task()`** only removed scheduled tasks; a running worker kept
   going, and `worker_thread` rolled straight into the implement phase
   (`worker.task()` clears the worker's own stop flag).
8. **command waits** blocked up to `cmd_max_wait_ms` (30 min) with no stop check.

See [stop contract](stop_contract.md).
