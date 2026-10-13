# Mind System Contracts

**Status:** Phase 1 contracts — implemented and tested
**Applies to:** Receptionist, Mind, the mind runtime, and every future component that
touches goal state (scheduler, workflow engine, messaging gateway, Workers).
**Implementation:** `runtime/mind_contracts.shio` (vocabulary), `runtime/mind_runtime.shio`
(durable state owner), `runtime/mind_dispatcher.shio` (event → LLM run, notification consumer,
direct delivery into a live Mind agent).
**Tests:** `tests/mind_runtime_test.shio`, `tests/receptionist_tools_test.shio`,
`tests/mind_dispatcher_test.shio` — 281 assertions.

This document is the contract half of
[`receptionist_mind_system_plan.md`](receptionist_mind_system_plan.md) Phase 1. Where this
document and the code disagree, the code wins and this document is wrong — fix the document.

---

## 1. The four records

The exit criterion of Phase 1: a logical Mind, one LLM run, a queued message and a lifecycle
event are four different things with four different ids. Nothing merges them.

| Record | Owner of | Lifetime | Id prefix | Store location |
|---|---|---|---|---|
| **Mind** | one goal and its state | durable, survives restarts, terminal states are addressable for history | `mind_` | `state.json → minds` |
| **Run** | one LLM invocation of a Mind | short-lived, one event at a time | `run_` | `state.json → runs` |
| **Message** | an instruction waiting for a Mind | queued → delivered → processed | `msg_` | `state.json → messages` + `mind.mailbox` |
| **Event** | one authoritative lifecycle transition | immutable once emitted, append-only | `evt_` | `state.json → events` + `events.jsonl` |

Consequences that must never be violated:

- A Mind is **not** a transcript. Closing a transcript does not end a goal.
- A Run ending does **not** mean the goal advanced; only events and Mind state say that.
- A Message being **queued is not** proof it was processed, and processing is not proof the
  requested action succeeded.
- Events are emitted from runtime state transitions, **never** inferred from natural-language
  output.

---

## 2. Store layout

```
.agent/mind/
├── state.json      checkpoint: the authoritative full state (atomic tmp + replace)
└── events.jsonl    append-only event journal (one compact JSON object per line)
```

- The store root is `MIND_STORE_DIR` (`.agent/mind/`), overridable with `mind_set_root(path)`.
- The in-process store object lives in `std.global("mind_store")`; every mutation runs inside the
  named critical section `mind_store_lock` (recursive per task).
- `state.json.seq` is a single monotonic counter shared by events and action-log entries.
- `state.json.checkpoint_seq` records the highest journal seq folded into the checkpoint.
- **The journal is append-only and strictly seq-ordered.** It is maintained as a text buffer that
  is appended to when an event is emitted, never rebuilt from the in-memory event map: JSON map
  iteration order is not insertion order, and a journal rebuilt from a map replays the
  `mind.created` snapshot last, which resurrects a creation-time record over the current state.
- Compaction keeps the newest `MIND_EVENT_LOG_MAX` lines (a suffix of a seq-ordered file stays
  seq-ordered).
- Nothing grows without bound: action log 300, mailbox 100, per-Mind run ids 50, state history 40,
  recent references 12, journal 4000 (only **processed** events are dropped from the in-memory map).
- The `mind.created` event carries a **copy** of the record as it was at creation, so the journal is
  self-sufficient for a rebuild from scratch and the snapshot cannot alias the live record.

---

## 3. Mind record

`mind_new_mind(goal, context, opts)` produces exactly these fields
(`mind_required_fields()` validates them):

| Field | Meaning |
|---|---|
| `id`, `contract_version` | stable identity |
| `created_ms`, `created_at`, `updated_ms`, `title` | creation metadata |
| `request` | `{text, context, source, request_id}` — the user request **verbatim**, never rewritten |
| `goal` | the Mind's own interpretation of the goal |
| `success_criteria` | list of conditions that must hold for "done" |
| `execution_shape` | `unknown` \| `one_shot` \| `recurring` \| `iterative` |
| `plan` | `{strategy, next_step}` — the next **bounded** step |
| `taskroutes` | `[{id, path, version, reason, registered_at}]` |
| `workflow` | schedule / workflow references (Phase 6) |
| `outstanding` | open Worker assignments (Phase 5) |
| `decisions`, `assumptions`, `approvals` | reasoning a later run cannot reconstruct |
| `blockers`, `waiting_for` | why progress is not happening right now |
| `state`, `state_reason`, `state_history` | lifecycle, enforced by the transition table |
| `counters` | `{runs, failures, retries, messages, progress}` |
| `recent` | last 12 event/action references, for continuity |
| `notification` | `{wanted, condition, registered_ms, delivered}` — durable completion notification |
| `idempotency_key` | deduplication of the creating request |
| `correlation_id` | the chain this goal belongs to |
| `last_event_seq` | the last seq this Mind consumed |
| `mailbox` | ordered ids of queued messages |
| `runs`, `active_run` | run ids owned by this Mind; at most one active |
| `outcome` | `{status, report, evidence, verified, ms}` — set only on terminal transitions |

The state store is authoritative. The LLM transcript is disposable working context.

---

## 4. Lifecycle states and transitions

States: `starting`, `active`, `waiting`, `blocked`, `completed`, `failed`, `stop_requested`,
`stopped`. Terminal: `completed`, `failed`, `stopped`.

| From | Allowed targets |
|---|---|
| `starting` | `active`, `waiting`, `blocked`, `completed`, `failed`, `stop_requested`, `stopped` |
| `active` | `active`, `waiting`, `blocked`, `completed`, `failed`, `stop_requested`, `stopped` |
| `waiting` | `active`, `blocked`, `completed`, `failed`, `stop_requested`, `stopped` |
| `blocked` | `active`, `waiting`, `completed`, `failed`, `stop_requested`, `stopped` |
| `stop_requested` | `stopped`, `failed` |
| `completed` / `failed` / `stopped` | *(none — terminal)* |

Rules the runtime enforces (a prompt cannot grant these):

1. An unknown state is rejected.
2. A transition not in the table is rejected with `status: "illegal_transition"`.
3. Re-entering the current state is a no-op (`status: "unchanged"`), so transitions are idempotent.
4. **`stop_requested` → `completed` does not exist.** A stop can never become a completion, and
   `mind_report(..., "completed")` is refused while a stop is pending.
5. Every accepted transition emits exactly one event and appends one action-log entry.
6. Entering a terminal state writes the `outcome` record and clears `active_run`.
7. `waiting_for` is owned by the runtime: entering `waiting`/`blocked` with a value records it,
   any other transition clears it.
8. Terminal → active is **not** a transition. It is the explicit runtime operation
   `mind_reactivate(mind_id, reason)`, which emits `mind.reactivated` and resets `outcome`.
   It is not exposed to the Receptionist in this phase.

State → event mapping: `starting→mind.created`, `active→mind.started`, `waiting→mind.waiting`,
`blocked→mind.blocked`, `completed→mind.completed`, `failed→mind.failed`,
`stop_requested→mind.stop_requested`, `stopped→mind.stopped`.

---

## 5. Event envelope

```json
{
  "id": "evt_...",            "seq": 42,
  "ts": 1791843610006,        "timestamp": "2026-10-13 00:20:10",
  "type": "mind.created",
  "mind_id": "mind_...",      "run_id": "",
  "correlation_id": "mind_...", "causation_id": "evt_...",
  "source": "runtime|receptionist|mind|worker|scheduler",
  "data": { "summary": "...", "state": "...", "previous_state": "..." },
  "delivery": { "status": "pending|claimed|processed|failed",
                "attempts": 0, "claimed_ms": 0, "processed_ms": 0, "handler": "" }
}
```

Declared types: `mind.created`, `mind.started`, `mind.waiting`, `mind.progress`, `mind.blocked`,
`mind.completed`, `mind.failed`, `mind.stop_requested`, `mind.stopped`,
`mind.message_received`, `mind.run_started`, `mind.run_finished`, `mind.run_failed`,
`mind.recovered`, `mind.reactivated`. An undeclared type is rejected by the validator.

Delivery semantics: **at-least-once delivery with idempotent handling**, not exactly-once.

- `mind_claim_event(id)` moves `pending → claimed`; claiming a `claimed` or `processed` event
  fails with `already_claimed` / `already_processed`.
- `mind_mark_event(id, "processed")` is idempotent and records `processed_ms`.
- A `claimed` event at startup is returned to `pending` and a `mind.recovered` event is emitted
  (§8).

Dispatcher classification:

| Class | Types | Effect |
|---|---|---|
| run trigger | `mind.created`, `mind.message_received`, `mind.recovered` | one Mind LLM run |
| stop request | `mind.stop_requested` | signal the runner, confirm `stopped` |
| informational | everything else | marked processed, never starts a run |

`mind.progress` and the state-change events are **never** triggers: a Mind run emits them, so
treating them as triggers would make every run invoke itself.

### Notification consumer

An event the dispatcher consumes without starting a run is **never dropped silently**: the
notification consumer prints it to the console before it is marked processed.

| Level | Prints |
|---|---|
| `all` (default) | every consumed event: `notify` class highlighted, the rest as plain event lines |
| `notify` | only the user-relevant events |
| `off` | nothing (explicit opt-out, e.g. for a UI host) |

`notify` class: `mind.completed`, `mind.failed`, `mind.stopped`, `mind.blocked`,
`mind.reactivated`, `mind.stop_requested`, `mind.run_failed`. Level is set with
`mind_dispatcher_set_notify_level(level)` (`/notify <level>` in the host) and reported in
`mind_dispatcher_status()`.

- Printing is **idempotent per event id**: at-least-once delivery never yields duplicate
  notifications (bounded memory of printed ids).
- `mind.run_failed` is `notify` class and means a **genuine** failure (see §7): a run that ended
  because a terminal tool stopped the agent is `mind.run_finished`, `info` class. A completed goal
  prints one user-facing notification, not a failure next to it.
- Every printed line is recorded in a bounded `mind_dispatcher_notify_log()` — the headless proof
  that an event was consumed and seen.
- The durable `mind.notification` condition (§5.8 of the plan) is discharged **once**, by the
  terminal event (`mind.completed` / `mind.failed` / `mind.stopped`): the consumer prints the
  user-facing notification and calls `mind_notify_mark_delivered`. A channel adapter (Telegram,
  e-mail, the web UI) replaces the printing step and consumes the same events.

---

## 6. Message envelope

```json
{
  "id": "msg_...",  "mind_id": "mind_...",
  "from": "receptionist|user|mind:<id>|system",
  "kind": "instruction|info|answer|stop",
  "body": "...",
  "correlation_id": "...", "causation_id": "...", "idempotency_key": "",
  "status": "queued|delivered|processed",
  "queued_ms": 0, "queued_at": "...", "delivered_ms": 0, "processed_ms": 0
}
```

- `send_message` **enqueues only**. It never invokes the target Mind and never runs it
  synchronously.
- Statuses are distinct: `queued` (accepted into the mailbox) → `delivered` (handed to a run) →
  `processed` (the run consumed it). Only the last is evidence the Mind saw it.
- A message to a Mind in a terminal state is rejected with `mind_terminal`; independent follow-up
  work needs a new Mind.
- Every accepted message also emits a `mind.message_received` event, which is what triggers the
  next run.
- **Live delivery:** if a Mind agent of that Mind is running right now, the message is handed to
  it directly with `miniagent.send_prompt()` (`mind_dispatcher_inject`), so the Mind can react
  inside the run it is in. This is asynchronous — the caller returns promptly — and it is recorded
  as a `Run` with `trigger: "message_injected"`, so one Mind still has one active run at a time.
  The message goes `queued → delivered → processed`, and the `mind.message_received` event that
  carried it is marked processed: the same instruction never starts a second run.
  `mind_dispatcher_deliver()` reports which path the message took: `injected_live_agent` or
  `queued_for_dispatch`.

---

## 7. Run record

```json
{
  "id": "run_...", "mind_id": "mind_...", "event_id": "evt_...",
  "trigger": "mind.created",
  "correlation_id": "...", "causation_id": "evt_...",
  "status": "running|finished|failed|stopped",
  "effort": "low|medium|high",
  "started_ms": 0, "started_at": "...", "ended_ms": 0,
  "summary": "...", "actions": []
}
```

- `mind_run_start` sets `mind.active_run`; `mind_run_end` clears it. **One active run per Mind**
  (plan §11.4): the dispatcher will not start a second run for a Mind that is already running.
- A run records the event it was triggered by, so causality is queryable:
  event → run → events emitted by that run.
- A run that is `running` at startup is reconciled to `failed` with the summary
  *"interrupted by runtime restart (outcome unknown, reconciled)"*. It is never assumed successful.
- **The transcript never decides the run status.** Every Mind terminal tool (`complete_goal`,
  `fail_goal`, `block_goal`, `ask_user`, `wait_for`, `end_run`) calls `agent.stop()`; that aborts
  the stream, so `miniagent.task()` returns the streamed text — empty when the model only emitted
  the tool call — as `ok=false` ("Agent returned nothing (maybe crashed)"). Reading that as a crash
  marks every run, successful completions included, as `failed`.
  `mind_dispatcher_run_outcome(agent, mind_id, res, crashed, opts)` classifies from the durable
  record instead:

  | Condition | Run status | `reason` |
  |---|---|---|
  | the agent call raised an exception | `failed` | `crashed` |
  | Mind is in state `stop_requested` | `stopped` (§9.3) | `stop_requested` |
  | the result reports `ok=true` | `finished` | `agent_reported` |
  | the Mind reached a terminal state during the run | `finished` | `terminal_report` |
  | the agent stopped itself (dispatcher-launched run only) | `finished` | `agent_stopped_by_tool` |
  | none of the above | `failed` | `agent_returned_nothing` |

  `opts.stopped_by_tool` is `false` for injected runs: `send_prompt()` stops the agent itself, so
  `agent.stopped` proves nothing there and only a durable outcome can make the run `finished`.
- `mind.run_failed` is emitted **only** for a run that is genuinely `failed`; `mind.run_finished`
  covers `finished` and `stopped`. `mind.counters.failures` counts real failures only.

---

## 8. Receptionist tool contracts

The Receptionist has exactly these five tools plus the core `sleep`. It has **no** file, write,
command, skill, search, taskroute, Worker or task-execution tool — the routing-only boundary is
structural, not a suggestion.

### `get_overview()`
No arguments. Returns `{ok, contract_version, store, seq, generated_at, total_minds,
states{state:count}, pending_events, minds[], note}` where each `minds[]` entry is
`{id, title, state, state_reason, goal, execution_shape, next_step, waiting_for, created_at,
updated_ms, runs, failures, pending_messages, active_run, correlation_id, outcome_status,
outcome_report?}`.
Read-only: it creates no run, consumes no event and does not advance `seq`. It must never be used
to watch progress.

### `get_last_actions(limit?)`
`limit` int 1–100, default 20. Returns `{ok, count, total_in_log, truncated, actions[], note}`,
newest first, each action `{seq, ts, timestamp, kind, mind_id, correlation_id, summary, target}`.
`kind` values: `spawn_mind`, `send_message`, `stop_mind`, `stop_confirmed`, `state:<state>`,
`report:<status>`. It identifies the action and its target Mind; it contains no implementation
logs and is not a historical search.

### `spawn_mind(goal, context, title?, request_id?, idempotency_key?, notification_condition?)`
Returns `{ok, deduplicated, mind_id, status: "created"|"existing", state, event_id, event_seq,
correlation_id, created_at, title, note}`.
- Creation and the `mind.created` event are one durable operation, so a crash cannot leave a goal
  with no scheduled first event.
- Returns promptly; it never executes the goal.
- `notification_condition` is registered durably with the goal at creation time, so a goal that
  finishes immediately cannot race past its notification registration.
- Empty goal → `{ok: false, status: "rejected"}`.

### `stop_mind(mind_id, reason?)`
Returns `{ok, status, confirmed, mind_id, event_id?, active_run?, idempotent?, note}`.
- `status: "stop_requested"`, `confirmed: false` — the request is recorded and the runner
  signalled.
- `status: "stopped"|"completed"|"failed"`, `confirmed: true` — already terminal.
- Idempotent: repeat calls return the same state and emit nothing new.
- `stopped` is confirmed **only** by the runtime (`mind_confirm_stopped`), once no run is active.

### `send_message(mind_id, message, kind?, idempotency_key?)`
Returns `{ok, deduplicated, message_id, mind_id, status: "queued", queue_depth, event_id,
event_seq, correlation_id, delivery, delivery_note, note}`. The note states explicitly that queued
is not proof of processing. `delivery` is `injected_live_agent` (the running Mind agent got it via
`send_prompt`) or `queued_for_dispatch` (no live agent; the dispatcher will invoke the Mind).

### Idempotency summary

| Operation | Key | Duplicate behaviour |
|---|---|---|
| `spawn_mind` | `idempotency_key` (falls back to `request_id`) | returns the existing Mind, `deduplicated: true`, no new event |
| `send_message` | `idempotency_key` | returns the existing message, mailbox unchanged |
| `stop_mind` | the Mind's state itself | returns the current state, no new event |
| event delivery | event id + `delivery.status` | a processed event is never delivered again |
| `mind_run_end` | run id | second call is a no-op |
| state transition | current state | re-entering the state is `unchanged` |

---

## 9. Stop and completion semantics

Stop is a two-phase operation, never a single claim:

1. `stop_mind` records `stop_requested` and emits `mind.stop_requested`.
2. The dispatcher signals the running Mind agent (`agent.stop()`) and, when no run is active,
   calls `mind_confirm_stopped` → `stopped` + `mind.stopped`.
3. A run that terminates after a stop request ends as `stopped`, and post-run bookkeeping
   confirms the stop — never as `failed`: a stop is not a failure, it increments no failure
   counter and emits no `mind.run_failed` (§7).

Completion:

- `complete_goal` → `mind_report(id, "completed", report, evidence, verified=true)`. The runtime
  **refuses** a completion without `verified` and evidence.
- `fail_goal` → `failed`, with what was attempted and why no viable path remains.
- `block_goal` / `ask_user` → `blocked`, with `needs` recorded. A question is not a failure.
- A `stop_requested` Mind cannot be completed. Refused, with an explanation.
- `stopped` never implies the goal completed: `outcome.goal_completed = false`.

---

## 10. Minimum durable state for recovery

Recovery needs nothing beyond `state.json` + `events.jsonl`. On load:

1. Read the checkpoint; repair missing top-level fields.
2. Replay journal entries with `seq > checkpoint_seq` (idempotent: creates missing Minds, applies
   state transitions, re-adds messages).
3. Reconcile in-flight work: every `running` run → `failed` with an "outcome unknown, reconciled"
   summary, `active_run` cleared, `counters.failures++`.
4. Re-deliver unprocessed events: every `claimed` event → `pending`, plus one durable
   `mind.recovered` event per redelivery.
5. If `state.json` is missing or corrupt, the journal alone rebuilds the state
   (`mind.created` carries the full Mind record).

Recovery never assumes an irreversible action succeeded and never blindly repeats one: the
in-flight run is marked *unknown*, not *done*.

---

## 11. Running it

```
shz runtime/mind_host.shio                  # interactive: receptionist + dispatcher + CLI
shz runtime/mind_host.shio "the request"    # single request, then keep the host running
```

The host loads the model config from `std.config_path("miniagent", "default_model")`, prompts for
it on first use, starts the dispatcher, and gives the user `/overview`, `/actions`, `/status`,
`/mind <id>`, `/message <id> <text>`, `/stop <id>`, `/notify [all|notify|off]`, `/clear`, `/exit`.

Tests (no LLM endpoint required, exit code 0 on success):

```
shz tests/mind_runtime_test.shio        # Phase 1 contracts, durability, recovery
shz tests/receptionist_tools_test.shio  # Phase 2 tool surface and semantics
shz tests/mind_run_outcome_test.shio    # run outcome classification (§7) + notifications
shz tests/mind_dispatcher_test.shio     # event -> run dispatch, stop, bookkeeping
```

`tests/mind_dispatcher_test.shio` is **currently red**: its "Launch guard" section asserts a
no-model-endpoint guard in `mind_dispatcher_launch` that was removed deliberately, so
`mind_dispatcher_step(None)` reaches `root.subagent` and raises. Those assertions must be rewritten
against the intended behaviour — the guard is not to be re-added.

## 12. Extension points (later phases)

The contracts are shaped so these plug in without changing the records above:

- **Worker delegation (Phase 5):** `mind.outstanding` assignments + `worker.result` events added to
  `MIND_RUN_TRIGGER_EVENTS`.
- **Scheduler / workflow (Phase 6):** `mind.workflow` + `timer.due` / `workflow.step_due` events.
- **Messaging gateway (§5.9):** message envelopes already carry `from`, correlation and causation
  ids; delivery states are already `queued → delivered → processed`, and the live-agent path
  (`mind_dispatcher_inject`) is the same call a gateway adapter needs for an online Mind.
- **Notification delivery (§5.8):** `mind.notification` is durable at creation and discharged once
  by the terminal event. The dispatcher's notification consumer prints it; a channel adapter
  (Telegram, e-mail, web UI) replaces the printing step and consumes the same events.
- **Budgets (§11.10):** `mind.counters` is the accounting base.
