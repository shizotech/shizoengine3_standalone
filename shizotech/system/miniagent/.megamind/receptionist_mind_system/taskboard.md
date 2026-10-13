# Taskboard — Receptionist & Mind system, first requirements

Scope of this run: `receptionist_mind_system_plan.md` **Phase 1 (contracts + data model)** and
**Phase 2 (Receptionist)**, plus the minimum Phase 3 groundwork (Mind role + event dispatcher)
that `spawn_mind` needs to be non-blocking and truthful.

**Verification (latest run): 114 runtime + 82 receptionist tools + 36 run-outcome = 232
assertions passing, exit code 0.** `shz --check` is clean on every new/changed `.shio` file.
`tests/mind_dispatcher_test.shio` (85 assertions) is **red** since the no-model-endpoint guard was
removed from `mind_dispatcher_launch` on purpose — see "Notification bug fix run" below.

## Phase 1 — Contracts and data model
- [x] `mind_contracts.md` — Mind record, lifecycle states + transition table, event envelope,
      message envelope, run record, tool I/O schemas, idempotency, stop/completion semantics,
      durable minimum, recovery, how to run it
- [x] `runtime/mind_contracts.shio` — machine-readable vocabulary: states, transitions, event
      types, envelope builders, validators
- [x] `runtime/mind_runtime.shio` — durable store (atomic checkpoint + append-only seq-ordered
      journal), spawn / overview / message / stop / last-actions / transitions / runs / recovery
- [x] Exit criterion: Mind, LLM run, queued message and lifecycle event are four distinct records
      with four distinct id namespaces (`tests/mind_runtime_test.shio`, 114 assertions)

## Phase 2 — Receptionist
- [x] Five coordination tools implemented in `roles/receptionist/ROLE.shio`
- [x] `roles/receptionist/ROLE.md` extended with the invocation model and the tool contracts
- [x] Routing-only tool surface asserted structurally: 5 tools + core `sleep`, nothing else
- [x] Non-blocking semantics asserted: every tool returns < 2 s, creates no run, consumes no event
- [x] Truthful acknowledgements: `queued` ≠ processed, `stop_requested` ≠ `stopped`,
      unverified completion refused, impossible requests still delegated
- [x] Exit criterion verified by `tests/receptionist_tools_test.shio` (73 assertions)

## Phase 3 groundwork (needed so spawn_mind is real, not a stub)
- [x] `roles/mind/ROLE.md` + `roles/mind/ROLE.shio` — goal owner, durable state tools,
      taskroute discovery/registration, terminal + continuation tools, ends its run promptly
- [x] `runtime/mind_dispatcher.shio` — claims pending events, one serialized LLM run per event,
      informational events consumed, stop signalling, post-run bookkeeping, no-endpoint guard
- [x] `runtime/mind_host.shio` — runnable host (receptionist + dispatcher + user CLI)
- [x] `tests/mind_dispatcher_test.shio` (44 assertions), including the live loop against a host
      with no model endpoint (blocks truthfully, never spins, never fakes a run)
- [x] `taskroutes/README.md` — the route format the Mind role reads

## Gap fix run — notification events + live message delivery
- [x] Notification consumer in `runtime/mind_dispatcher.shio`: every event the dispatcher consumes
      is printed to the console (`[NOTIFY]` for user-relevant, `[event]` for routine) instead of
      being silently marked processed. Idempotent per event id, bounded `notify_log`, levels
      `all|notify|off` (`mind_dispatcher_set_notify_level`, host `/notify`).
- [x] Durable `mind.notification` is discharged once by the terminal event
      (`mind_notify_mark_delivered`) and printed as a user-facing notification.
- [x] `send_message` (receptionist tool) now delivers to the live Mind agent through
      `miniagent.send_prompt` via `mind_dispatcher_deliver` / `mind_dispatcher_inject`:
      async (caller returns promptly), recorded as a Run with `trigger: "message_injected"`,
      message `queued → delivered → processed`, the `mind.message_received` event spent so no
      duplicate run starts. Result carries `delivery: injected_live_agent | queued_for_dispatch`.
- [x] New runtime helper `mind_message_mark_delivered(message_id)`.
- [x] Fixed the missing no-model-endpoint guard in `mind_dispatcher_launch` (documented in
      `avoid.md` item 11 and asserted by the suite, but absent from the code): checked **before**
      claiming, so the event stays queued, no run is created, the Mind is blocked truthfully.
- [x] Host: `/message` uses the same delivery path, new `/notify [level]` command.
- [x] Docs updated: `mind_contracts.md` (notification consumer, live delivery, tool contract,
      host commands, extension points), `roles/receptionist/ROLE.md`, `roles/mind/ROLE.md`.
- [x] Tests: dispatcher suite 44 → 85 assertions (notification consumer, dedup, levels, durable
      notification, injection with a stand-in agent, deliver paths); receptionist suite 73 → 82
      (tool-level live delivery). The end-to-end loop assertion now polls with a bound instead of
      sleeping a fixed 900 ms (console printing makes a step slower than that).

## Notification bug fix run — spurious "run_failed" next to "Completed"
- [x] Root cause: every Mind terminal tool calls `agent.stop()`; `miniagent.task()` then returns
      the empty transcript as `ok=false` ("Agent returned nothing (maybe crashed)") and
      `mind_dispatcher_execute` read that as a crash → **every** run, completions included, ended
      as `MIND_RUN_FAILED` → `mind.run_failed` (notify class) printed next to `mind.completed`,
      plus a bogus `counters.failures++`.
- [x] New `mind_dispatcher_run_outcome(agent, mind_id, res, crashed, opts)` in
      `runtime/mind_dispatcher.shio`: the durable record decides the status (crash → failed,
      `stop_requested` → stopped, `ok=true` / terminal state / tool-stop → finished, else failed).
      `opts.stopped_by_tool=false` for injected runs (`send_prompt` stops the agent itself).
- [x] `mind_dispatcher_execute` and `mind_dispatcher_inject_run` use it; the empty-transcript
      "crash" path is gone, the run summary comes from the durable outcome, and only a real failure
      logs an error.
- [x] New suite `tests/mind_run_outcome_test.shio` — 36 assertions, exit 0: classification of all
      seven cases, end-to-end through `mind_dispatcher_execute` (completed / dead agent / stop)
      asserting what the notification consumer sees, and both injected-run outcomes.
- [x] Verified: `mind_runtime_test` 114 + `receptionist_tools_test` 82 still green (exit 0);
      `shz --check` clean on the dispatcher, the new suite and the dispatcher suite.
- [x] Docs: `mind_contracts.md` §7 (outcome table), §5 (run_failed = genuine failure only),
      §9.3 (a stop is not a failure), §11 (test list + known-red dispatcher suite).
- [ ] **Known red, NOT fixed here:** `tests/mind_dispatcher_test.shio` crashes at line 92 —
      `mind_dispatcher_step(None)` → `mind_dispatcher_launch` → `root.subagent` because the
      no-model-endpoint guard was **removed on purpose** (parent's decision: do not re-add it).
      Its "Launch guard" section (lines 105-113) asserts the removed behavior and needs rewriting.

## Deferred (later phases of the plan — NOT done here)
- [ ] Phase 3 full: multi-invocation goal progress against a **real** LLM endpoint. No model
      endpoint is configured on this machine, so no Mind run has ever executed a prompt. The
      plumbing (claim → run → persist → next event) is tested; the model call is not.
- [ ] Phase 4: taskroute matching engine (only discovery/reading exists; no routes authored)
- [ ] Phase 5: bounded Worker delegation contracts + `worker.result` events (`delegate` tool)
- [ ] Phase 6: scheduler / workflow service integration (recurring + iterative shapes)
- [ ] Phase 7: reliability test matrix (crash injection, duplicate events, stop races,
      delayed results, restart with in-flight irreversible actions)
- [x] Notification consumer: terminal events are printed to the console and discharge the durable
      notification once (§5.8, §6.6). Remaining: a real channel adapter (Telegram / e-mail / web UI)
      that consumes the same events.
- [ ] Per-goal budget limits (§11.10)
- [ ] Multi-process store access (currently single-process, critical-section guarded)
