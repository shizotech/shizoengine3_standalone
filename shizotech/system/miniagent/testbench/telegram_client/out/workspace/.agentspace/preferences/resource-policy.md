---
max_background_tasks: 1
reserve_interactive_workers: 0
yield_after_interactive: 10m
default_stop_policy: checkpoint
default_max_attempts: 3
checkpoint_grace: 15m
stall_timeout: 30m
---

# Resource policy

* `max_background_tasks`: scheduled runs that may work at the same time on this node
  (`priority: urgent` goals may exceed it).
* `reserve_interactive_workers`: workers kept free for requests you send yourself
  (start the node with `--max-workers 2` and reserve 1 so a chat request never waits).
* `yield_after_interactive`: no new background run starts this long after your last request.
* `default_stop_policy`: what happens to a running task when its window ends:
  `drain` (let it finish), `checkpoint` (ask it to save progress and report, then stop after
  `checkpoint_grace`), `cancel` (stop at once).
* `default_max_attempts`: attempts per window before a goal's window counts as failed.
* `stall_timeout`: a run that shows no progress (no agent action) this long is stopped and
  retried - a deterministic watchdog, no LLM health check involved.

The model endpoint's own parallel limit is `max_running_agents` in the model config.
