# roadmap

Goal: `miniagent.stop()` must stop generation everywhere, including the subagents
the `adaptive` role spawns (start_task, continue_task, fork, file_task_batch).

Direction taken: make the agent tree the single source of truth for stopping —
one registry (`_child_agents`), one top-down walk, one inherited predicate
(`should_stop()`), and every blocking loop polls it.

Key discoveries:
- the registry was being wiped on every child creation → stop reached one child;
- `stream.start(reset_stop=true)` clears the stream stop on the first request of a
  `task()`, so a stop that lands before the start is undone → the guard belongs in
  `task()`, not in the stream layer;
- a tool callback returning `None` on a stop feeds the model an empty tool result
  and it keeps generating;
- `max_running_agents = 0` (the ModelConfig default) queued every child forever.

Status: done, verified offline (no LLM endpoint on this box).
