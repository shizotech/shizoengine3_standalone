# Avoid

- **A short fixed settle timer for the whole handoff.** The node's task runs for
  minutes; settling the record N seconds after the ack announces a fake completion and
  the real `task_finished` push then arrives for a node with nothing open -> adopted as
  a SECOND mirror entry -> two messages again. The settle window may only cover event
  latency after the ack, never the task runtime: bind the task first (`task_started`),
  settle unbound records only.
- **Broadcasting `task_started` straight from the `on_task_started` callback.**
  `Megamind.add_task` is also reached from the `ai_task_add` on_get handler = the
  ShizoNet script thread, and handlers must never touch the transport
  (router_api.md ground rules, same reason `pending_state` exists). Queue it.
- **Telling the router agent to name the task.** The router's name is overwritten by
  the node's task name; a name the user sees twice is the bug. The router names nothing.
- **`while`** — not a shizoscript keyword. `for(cond) {}`.
- **A json field named `key`** — reserved token in shizoscript object literals, the
  entry is silently dropped (see router_api.shio `_node_key` comment).
- **`remove` on a directory** needs the identical call twice (confirmation). Same for a
  non-empty **file** with `write_file`: it refuses to overwrite — `remove` then write,
  or `replace_string`.
- **Escapes in `replace_string`**: a `\t` / `\n` typed into `replacement_text` arrives as
  a literal backslash sequence in the file, not as whitespace. Write real tabs/newlines.
- **Synchronising a selftest on chat text** that an earlier section already produced
  (`bot.has_for(CHAT_A, "picked GPUBox")`) returns instantly and the assertions race the
  real turn. Sync on the agent's turn counter, and give each section a unique needle.
- **`wait_for(count_kind("task_started") > 0)`** in `shizonet_ai_selftest`: an earlier
  `ai_task_add` already announced one, so the wait is a no-op and the payload checks
  race the push. Sync on the named event.
- **Running two selftests at once**: they all want UDP 6454; the loser binds 6457 and
  shizonet discovery fails with "no peer" errors that look like real breakage.
