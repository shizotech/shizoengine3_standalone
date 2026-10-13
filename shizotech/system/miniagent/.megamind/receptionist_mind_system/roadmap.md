# Roadmap — Receptionist & Mind runtime

## Direction
The plan (`receptionist_mind_system_plan.md`) is implemented as three layers:

1. `runtime/mind_contracts.shio` — vocabulary: lifecycle states, legal transitions, event types,
   envelope builders. No I/O.
2. `runtime/mind_runtime.shio` — the durable state owner. Everything the Receptionist tools need,
   plus the state machine the Mind tools drive. Pure shizoscript, **no LLM required**, so it is
   testable headless.
3. `runtime/mind_dispatcher.shio` — turns pending events into short-lived Mind LLM runs in a
   background thread. This is what makes the Receptionist non-blocking.

## Key decisions made in this run
- **Store location**: `.agent/mind/` (AGENT_DIR is the repo-local agent space). `state.json` is a
  checkpoint, `events.jsonl` is append-only. Recovery = load checkpoint, replay journal tail.
- **One record per concept**: `minds`, `runs`, `messages`, `events` are separate maps. A Mind is
  not a run; a queued message is not an event; a lifecycle event is not a message.
- **Stop semantics**: `stop_requested` is recorded immediately; `stopped` only when the
  dispatcher confirms the run is not active any more. `stop_requested -> completed` is illegal in
  the transition table, so a stop can never be reported as completion by construction.
- **Idempotency**: `spawn_mind` dedupes on `idempotency_key`/`request_id`; `send_message` dedupes
  on `idempotency_key`; event delivery is at-least-once with a claim/processed marker.
- **Serialization**: one active LLM run per Mind (plan §11.4 default). Store mutations are guarded
  by the named critical section `mind_store`.
- **Headless testability**: the receptionist tools are thin wrappers over runtime functions, and the
  tool callbacks are reachable through `agt.llm_api.tools.tool_callbacks[name](args)`, so the whole
  Phase 2 surface can be exercised without an LLM endpoint.

## Discoveries / gotchas
- Full list in `avoid.md`. The two that actually broke behaviour and were caught by the durability
  test: (1) rebuilding `events.jsonl` from the event map produced non-seq order after a reload, so
  replay applied `mind.created` last and resurrected the creation-time record; (2) the
  `mind.created` event aliased the live record, so its "snapshot" was the newest state.
  Fix: append-only journal text buffer + `mind.copy()` in the created event.
- `miniagent(cfg, role)` constructs fine with an empty `ModelConfig` (no network call in the
  constructor) — that is what makes offline tool tests possible.
- Tool callbacks are reachable headless through `agt.llm_api.tools.tool_callbacks[name](args)`;
  the tool list is `agt.llm_api.tools.tools[i].function.name`. This is how the Receptionist
  contract is asserted without an LLM.
- `std.module().load_file(ROLE.shio)` gives each role module its own symbol table; shared state must
  live in `std.global(...)` (the `local_files` pattern in `roles/SHARED.shio`).
- `roles/<role>/ROLE.shio` is found through `find_skill("roles", name)` → repo `roles/` dir.
- shizoscript has no `while`; `for(cond)` is the loop. Blocks create scopes, so declare accumulators
  before the block.

## Verification state
- First run: 114 + 73 + 44 assertions, all green. Current state is in the "gap fix run" section
  below; no artifacts left in `.agent/` (the suites clean their own store roots).

## Gap fix run (notifications + live delivery) — decisions
- **Nothing is silently dropped**: the dispatcher's notification consumer prints every event it
  consumes. `mind_notify_class(type)` splits `notify` (completed/failed/stopped/blocked/
  reactivated/stop_requested/run_failed) from `info`; levels `all` (default) / `notify` / `off`.
  Printing is deduplicated per event id and mirrored into a bounded `g.notify_log`, which is what
  the headless tests assert on (`std.cout` cannot be captured).
- **The durable notification is discharged by the terminal event**: `mind.notification.delivered`
  is set via `mind_notify_mark_delivered` exactly once, and the user-facing line is printed. A
  channel adapter replaces only the printing step later.
- **`send_message` reaches a live Mind agent**: `mind_dispatcher_inject` calls
  `agent.send_prompt(prompt)` on the agent registered in `g.active[mind_id]`, in its own thread
  (the Receptionist must return promptly). It registers a real Run (`trigger: "message_injected"`),
  marks the message delivered→processed and marks the `mind.message_received` event processed, so
  the same instruction never starts a second run. `mind_dispatcher_mind_running()` now also honours
  `mind_run_active()`, so an injected run serializes with dispatcher runs.
- **Endpoint guard is checked before claiming** an event in `mind_dispatcher_step`; claiming first
  would leave the event `claimed` and the test contract (`event stays queued`) would break.
  **Superseded:** the guard was later removed from `mind_dispatcher_launch` because it broke
  things — see the notification bug fix run below. It must not be re-added.

## Verification state (gap fix run)
- 114 + 82 + 85 = 281 assertions, all suites exit code 0; `shz --check` clean on all changed files.
- Host smoke-tested offline (`/notify`, `/overview`, `/status`, `/message` on an unknown Mind).
- Still not verified: a real Mind LLM run (no model endpoint on this machine).

## Notification bug fix run — why a completed goal printed "run_failed"
- **The transcript is not the authority for a run's outcome.** Every Mind terminal tool calls
  `agent.stop()`; `miniagent.stop()` aborts the stream, `openai_api.task()` returns the streamed
  text (empty when the model only emitted the tool call), and `miniagent.task()` reports that as
  `ok=false`. The dispatcher turned that into `MIND_RUN_FAILED` for **every** run — so a completed
  goal printed `mind.completed` (notify) and `mind.run_failed` (notify) back to back, and
  `counters.failures` counted successes. No role calls `add_finalize_tool`, so `env.use_finalize`
  is falsy for Mind agents and the empty-transcript path is always taken.
- `mind_dispatcher_run_outcome(agent, mind_id, res, crashed, opts)` decides from the durable
  record: exception → `failed`; Mind `stop_requested` → `stopped` (contract §9.3, previously
  violated); `ok=true` / terminal Mind state / agent stopped by a tool → `finished`; else `failed`.
  For **injected** runs `opts.stopped_by_tool=false`: `send_prompt()` stops the agent itself, so
  `agent.stopped` proves nothing and only a durable outcome may save the run.
- `mind.run_failed` is now emitted only for genuine failures; `mind.run_finished` (info class)
  covers `finished` and `stopped`. The notify-class list itself is unchanged — the classification
  feeding it was wrong, not the consumer.
- New headless suite `tests/mind_run_outcome_test.shio` drives `mind_dispatcher_execute` /
  `mind_dispatcher_inject_run` with stand-in agents (plain JSON with `task`/`send_prompt`/`stopped`),
  so the whole path is testable without a model endpoint. It never calls
  `mind_dispatcher_step`/`launch` — those need a root agent.

## Verification state (notification bug fix run)
- 114 + 82 + 36 = 232 assertions green, exit 0; `shz --check` clean on all changed files.
- `tests/mind_dispatcher_test.shio` is red at line 92: the no-model-endpoint guard was **removed
  from `mind_dispatcher_launch` deliberately** (it broke things), so `mind_dispatcher_step(None)`
  reaches `root.subagent` and raises. Its "Launch guard" section asserts the removed behavior.
  **Do not re-add the guard**; rewrite those assertions instead.
- Still not verified: a real Mind LLM run (no model endpoint on this machine). The
  empty-transcript-after-stop behaviour is reproduced by stand-in agents, not by a live model.

## Dead ends (avoid)
- Do not put the durable state in `agt.env` — subagents get fresh `env` objects; only `env_shared`
  and `std.global` cross the agent tree.
- Do not run a Mind synchronously inside `spawn_mind`: that violates the non-blocking contract
  (§4.3) and the creation contract (§6.1).
