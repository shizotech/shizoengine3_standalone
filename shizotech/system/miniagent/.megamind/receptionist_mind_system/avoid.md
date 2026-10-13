# Avoid — shizoscript pitfalls hit while building the mind runtime

1. **JSON map iteration order is not insertion order after a load.**
   Rebuilding the `events.jsonl` journal from `g.state.events` (a string-keyed map) produced
   seq order in memory and hash order after a reload. Replaying that journal applied
   `mind.created` **last**, resurrecting the creation-time record and wiping every later
   transition. The journal is now an append-only text buffer (`g.journal`), never rebuilt from
   the map. Compaction keeps a suffix, which stays seq-ordered.

2. **A JSON value assigned into two places is one shared object.**
   `mind_emit("mind.created", id, [mind = mind])` aliased the live record, so the "snapshot" in
   the journal always contained the newest state. Use `mind.copy()` for snapshots.

3. **`json.erase()` takes exactly one argument** (key or index). `erase(0, n)` compiles and does
   the wrong thing. Trim lists with a loop (`mind_trim_front`).

4. **JSON literal keys are literal identifiers, not variables.**
   `[field: value]` creates the key `"field"`. For a dynamic key build the object:
   `patch = []; patch[field] = value;`.

5. **Lambda capture lists accept plain variables only.** `[run.run_id]` is a syntax error; copy
   into a local first.

6. **Functions must be declared before use (source position).** Use `def name(args);` for the
   loader/replay cycle.

7. **`shz --silent` suppresses compile errors.** Run `shz --check <file>` first; a script that
   prints nothing and exits 1 did not compile.

8. **A script run from a console waits on "Press enter to exit..."** — pipe `< NUL` in batch.

9. **`std.sleep()` is milliseconds**, despite the agent-facing `sleep` tool describing seconds.

10. **`fileio.remove()` on a directory path with a trailing slash does not delete it.** Strip it.

11. **An unreachable/empty LLM base URL makes `openai_stream.poll()` spin forever**
    ("Response was empty!"). Never start the dispatcher against a host with no endpoint.
    **Superseded:** the guard that blocked the Mind and kept the event queued was removed from
    `mind_dispatcher_launch` deliberately — do not re-add it. Consequence: `mind_dispatcher_step`
    with `root = None` (or a host with no endpoint) goes straight into `root.subagent` / a real
    model call.

12. **The agent tree is not thread safe.** Create subagents in one thread (the dispatcher
    thread); run them in worker threads. Same rule as `roles/adaptive` batch children.

13. **`miniagent.send_prompt()` blocks**: it stops the running task, waits for it and runs the new
    prompt. Calling it from the Receptionist tool callback would violate the non-blocking contract
    (§4.3) — hand it to its own thread (`mind_dispatcher_inject`) and report the delivery path.

14. **`std.cout` is slow on a Windows console.** Printing every consumed event made one dispatcher
    step take ~1 s with ~40 pending events, so a test that slept a fixed 900 ms after spawning a
    Mind became flaky. Poll the expected state with a bound instead of sleeping.

15. **Event delivery is at-least-once, so the notification consumer must dedupe by event id**
    (`g.notified`), and it must be driven from `mind_dispatcher_step` — emitting an event does not
    notify anything. Tests assert on `mind_dispatcher_notify_log()`, because `std.cout` output
    cannot be captured from inside a script.

16. **`mind_set_state` to the current state returns `unchanged` and does not update
    `state_reason`.** Repeated blocking keeps the first truthful reason — do not expect a later
    reason to overwrite it.

17. **The no-endpoint guard must run before `mind_claim_event`.** Claiming first leaves the event
    `claimed` and breaks the contract that an unrunnable event stays queued.
    **Superseded:** the guard was removed from `mind_dispatcher_launch` deliberately (it broke
    things). Do not add it back; rewrite the assertions that expect it.

18. **`miniagent.task()` returns `ok=false` whenever a tool stopped the agent.** `stop()` aborts
    the stream, `openai_api.task()` returns the streamed text — empty when the model only emitted
    the tool call — and `task()` reports `Agent returned nothing (maybe crashed)`. Every Mind
    terminal tool stops the agent, so treating `ok=false` as a crash marks **every** run failed and
    prints `mind.run_failed` next to `mind.completed`. Classify from the durable record
    (`mind_dispatcher_run_outcome`), never from the transcript.

19. **`opts.key ?? default` is truthiness-based, so an explicit `false` reads back as the
    default.** `opts.stopped_by_tool ?? true` with `[stopped_by_tool = false]` gives `true`.
    Test the key: `if(opts.has("k")) v = opts.k ? true : false;`.

20. **`mind_dispatcher_step(None)` / `mind_dispatcher_launch(None, ev)` crash** at
    `root.subagent(...)` ("not a function!") — there is no endpoint guard to stop them first.
    A headless test of the run/notify path must call `mind_dispatcher_execute` /
    `mind_dispatcher_inject_run` / `mind_dispatcher_notify` directly, never `step`/`launch`.
