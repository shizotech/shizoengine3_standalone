# Receptionist and Mind Agent System --- Implementation Plan

**Status:** Design plan\
**Scope:** Receptionist and Mind agents, their runtime contracts,
lifecycle, event handling, and goal orchestration decisions.\
**Out of scope for this phase:** Detailed Worker implementation,
messaging gateway internals, scheduler internals, durable workflow
engine internals, UI, and external-channel adapters. These systems are
referenced only where Receptionist or Mind needs a contract with them.

------------------------------------------------------------------------

## 1. Goals

Build an event-driven multi-agent system in which:

1.  The **Receptionist** is the always-available entry point for user
    requests and relevant system events.
2.  The Receptionist routes requests but does not investigate or execute
    substantive work.
3.  Each **Mind** owns a goal, plans how to achieve it, and remains
    responsible for the goal until it reaches a terminal outcome or is
    explicitly stopped.
4.  Individual LLM invocations are short-lived execution runs. Durable
    state lives in the runtime, not solely in an LLM transcript.
5.  Neither the Receptionist nor a Mind needs to keep an LLM call open
    while waiting for a Worker, timer, message, or other event.
6.  Minds can choose an appropriate execution shape: a one-shot task, a
    recurring timed action, or a persistent iterative workflow.
7.  State transitions and completion events are reliable enough that
    requests, messages, and notifications are not silently lost or
    duplicated.
8.  The architecture stays simple: the Receptionist is a router; a Mind
    is a goal owner; the runtime owns persistence and event delivery.

## 2. Core concepts

### 2.1 Receptionist

A logical actor responsible for: - Receiving user requests and relevant
system events. - Identifying whether a request is new work, a follow-up,
a stop/cancel request, or a reference to a recent action. - Creating a
Mind for new substantive work. - Forwarding follow-up instructions to
the responsible Mind. - Requesting Mind termination when the user asks
to stop work. - Giving the user a brief, truthful acknowledgement of
what the runtime confirmed.

The Receptionist does **not**: - Research a request. - Investigate
whether a task is possible. - Search for or inspect taskroutes. - Plan
or execute the underlying task. - Inspect implementation details or
review technical results. - Manage Workers directly. - Poll or wait for
a Mind to finish. - Decide how a goal should be decomposed into a
workflow.

### 2.2 Mind

A logical, persistent goal owner responsible for: - Interpreting the
user's intended outcome. - Defining success and completion criteria. -
Determining whether the request needs a one-shot task, recurring timed
event, or persistent workflow. - Finding and following an applicable
taskroute. - Determining whether the requested work is feasible and what
capabilities or information are required. - Planning and delegating
concrete work. - Tracking progress and relevant runtime state. -
Reacting to Worker results, user messages, failures, and other events. -
Detecting drift from the goal, repeated failures, or lack of progress. -
Adapting the plan where appropriate. - Reporting completion, failure,
blockers, or a request for user input.

A Mind does not have to be continuously running. Its **goal and state
persist**, while each LLM invocation is a separate execution run
triggered by an event or explicit runtime request.

### 2.3 LLM run

A single invocation of a model to handle one event or advance a goal. An
invocation: - Receives the relevant goal state, event, and bounded
context. - Performs a finite amount of reasoning and tool use. -
Persists any state changes through runtime tools. - Ends promptly
instead of waiting for future events.

An LLM run is not the same thing as a Mind. A Mind is the durable
goal-owning actor; a run is one temporary execution of that actor.

### 2.4 Taskroute

A documented, reusable procedure, initially represented by a `.md` file,
that describes how to perform a class of tasks. A taskroute should
define: - When it applies. - Required inputs and preconditions. - The
steps or decision process. - Permitted tools and capabilities. -
Verification requirements. - Failure and escalation behavior. - Any
user-confirmation requirements.

The Mind selects and executes taskroutes. The Receptionist never
searches for them.

### 2.5 Workflow and timed-event concepts

Minds need to recognize three broad execution shapes:

-   **One-shot task:** Perform an action, verify it, and finish.
-   **Recurring timed action:** Arrange for a task to be triggered on a
    schedule, such as checking a sensor every 15 minutes.
-   **Persistent iterative workflow:** Repeat a process until a defined
    completion condition is met, such as resolving repository issues one
    at a time with verification after each change.

The scheduler and workflow engine are future runtime components. This
plan specifies how Receptionist and Mind interact with those concepts,
not their full implementation.

------------------------------------------------------------------------

## 3. Architecture and ownership

### 3.1 Logical flow

``` text
User / system event
        |
        v
Receptionist invocation
        |
        +-- new substantive goal --> spawn Mind
        |
        +-- follow-up -------------> send message to existing Mind
        |
        +-- stop request ----------> request Mind stop
        |
        +-- recent-action reference -> get last actions
        |
        v
Receptionist invocation ends

Mind goal state (durable)
        |
        v
Mind invocation triggered by an event
        |
        +-- inspect goal state and event
        +-- choose next action
        +-- consult/select taskroute
        +-- execute a bounded step or delegate work
        +-- persist state and expected next event
        |
        v
Mind invocation ends

Worker result / user reply / timer / tool result / stop request
        |
        v
New event -> another Mind invocation
```

### 3.2 Responsibility boundaries

  -----------------------------------------------------------------------
  Responsibility                      Owner
  ----------------------------------- -----------------------------------
  Receive user request                Receptionist/runtime

  Decide which existing Mind a        Receptionist, using overview and
  follow-up belongs to                current context

  Decide whether a task is feasible   Mind

  Find and select taskroutes          Mind

  Define goal and success criteria    Mind

  Choose one-shot, recurring, or      Mind
  iterative execution                 

  Persist Mind state and lifecycle    Runtime

  Execute concrete implementation     Worker or an appropriate taskroute
  work                                capability

  Persist and emit                    Runtime
  completion/stop/failure events      

  Decide whether an event warrants    Runtime event dispatcher
  another Mind run                    

  Deliver messages between            Shared messaging interface,
  agents/services                     designed separately

  Notify the user of later completion Durable notification/event
                                      mechanism, designed separately
  -----------------------------------------------------------------------

The same host process may contain multiple logical actors. Separate
contexts, mailboxes, state records, and execution budgets are still
required. Co-location must not make the Receptionist responsible for
Mind execution.

------------------------------------------------------------------------

## 4. Receptionist specification

### 4.1 Required tools

Keep the Receptionist's tool surface intentionally small:

-   `get_overview()`
    -   Returns a concise view of current Minds and their lifecycle
        states.
    -   Used to identify the owner of existing work or disambiguate a
        reference.
    -   Must not wake or invoke Minds as a side effect.
-   `get_last_actions()`
    -   Returns a compressed, recent action history suitable for
        resolving references such as "do that again."
    -   Is not a general-purpose historical search tool.
    -   Must return enough information to identify the action and its
        target without exposing implementation logs.
-   `spawn_mind(goal, context, ...)`
    -   Requests creation of a new Mind for a new substantive goal.
    -   Returns a stable Mind ID and a truthful creation/acceptance
        state.
    -   Should support an idempotency key or equivalent deduplication
        mechanism where possible.
-   `stop_mind(mind_id, ...)`
    -   Requests that a Mind stop.
    -   Must distinguish `stop_requested` from confirmed `stopped`.
    -   Should be idempotent.
-   `send_message(mind_id, message, ...)`
    -   Enqueues a message for an existing Mind.
    -   Must return promptly and must not synchronously run the target
        Mind.
    -   Should return a message/correlation ID and a truthful delivery
        or queue state.

No general web search, repository inspection, taskroute search, Worker
management, or task execution tools should be exposed to the
Receptionist.

### 4.2 Routing policy

1.  **New substantive request:** Spawn a Mind and pass the user's intent
    with relevant conversational context. Do not pre-validate
    feasibility.
2.  **Follow-up to active work:** Identify the target Mind from the
    current context or `get_overview()`, then enqueue the instruction
    with `send_message()`.
3.  **Stop/cancel request:** Identify the target and call `stop_mind()`.
4.  **Reference to a previous action:** If the reference cannot be
    resolved from the current context, call `get_last_actions()`. Do not
    invent the action or its target.
5.  **Ambiguous consequential request:** Ask one concise clarification
    if multiple targets are plausible and acting on the wrong one would
    matter.
6.  **Unsupported or apparently impossible request:** Still delegate it.
    Feasibility and capability discovery belong to the Mind.
7.  **Request to be notified later:** Pass the notification requirement
    to the Mind as part of the goal. The runtime/Mind must arrange
    durable notification registration; the Receptionist must not wait
    for completion.
8.  **System lifecycle event:** Handle only the routing or
    acknowledgement required by that event. Do not inspect or rewrite
    the technical outcome.

### 4.3 Non-blocking contract

The Receptionist must: - Make only the tool calls needed to route the
current request. - Never wait for a Mind to finish. - Never poll for
progress. - Never repeatedly inspect the overview to see whether a task
has completed. - Never investigate delegated work. - End its invocation
after routing and acknowledging the request.

Completion, failure, and termination arrive later as events. A separate
Receptionist invocation may then notify the user or route the event as
configured.

### 4.4 Receptionist system prompt

Use the following as the initial prompt. Tool schemas and runtime
contracts remain authoritative if a prompt and tool behavior ever
disagree.

> # Role: Receptionist
>
> You are the event-driven receptionist of a multi-agent system. Each
> invocation is a fresh LLM run. You coordinate Minds but never perform
> their work yourself.
>
> ## Rules
>
> 1.  **Delegate all substantive requests immediately.** For every new
>     task, call `spawn_mind` with the user's goal and relevant context.
>     Do not research, investigate, analyze feasibility, search for
>     solutions, inspect taskroutes, or attempt to solve the task
>     yourself. The Mind is responsible for determining how to execute
>     the request and whether it can be completed.
>
> 2.  **Do not pre-validate requests.** Forward the user's intent as
>     given, even if the task appears impossible, unsupported, unclear,
>     or dependent on unavailable capabilities. Let the Mind investigate
>     and report success or failure. Ask for clarification only when
>     needed to identify the intended existing task or avoid a
>     consequential routing mistake.
>
> 3.  **Route follow-ups to existing Minds.** When the user refers to
>     ongoing work, use `get_overview` if necessary to identify the
>     responsible Mind, then use `send_message` to forward the
>     instruction. Do not spawn a new Mind for a follow-up to an
>     existing task.
>
> 4.  **Resolve references to past actions.** If the user says "do that
>     again," "repeat the previous task," or refers to an earlier action
>     that is not clear from the current context, call
>     `get_last_actions` and resolve the reference from its results.
>     Never invent past actions.
>
> 5.  **Stop Minds on request.** Identify the relevant Mind and call
>     `stop_mind`. Do not claim it has stopped unless the tool confirms
>     that it has. Distinguish a stop request from confirmed
>     termination.
>
> 6.  **Stay responsive and event-driven.** Perform only the
>     coordination calls needed for the current request. Never wait for
>     a Mind to finish, poll for progress, monitor execution, or
>     investigate delegated work. Mind completion and termination are
>     reported through system events.
>
> 7.  **Acknowledge accurately.** Respond briefly after routing a
>     request or instruction. Report only states confirmed by the tools,
>     distinguishing accepted, queued, running, completed, failed,
>     stop-requested, and stopped as applicable. Never claim success
>     without confirmation.
>
> 8.  **Avoid duplicate work.** Before creating a Mind for a request
>     that might concern existing work, consult `get_overview` when
>     necessary. If the intended target is ambiguous and acting could
>     cause a consequential mistake, ask the user to clarify.
>
> 9.  **Remain a receptionist.** Use only your coordination tools. Do
>     not perform substantive work, manage Workers directly, inspect
>     implementation details, review technical results, or rewrite a
>     Mind's completion report.
>
> ## Tools
>
> -   `get_overview()` --- inspect current system state and active
>     Minds.
> -   `get_last_actions()` --- retrieve a compressed list of recent
>     actions.
> -   `spawn_mind()` --- create a Mind for a new goal.
> -   `stop_mind()` --- request that a Mind stop its work.
> -   `send_message()` --- forward a message to an existing Mind.
>
> Use tools only to route requests and manage Mind lifecycles. Your
> responsibility ends when the request has been correctly routed or
> handled. Do not continue working on the user's underlying task.

------------------------------------------------------------------------

## 5. Mind specification

### 5.1 Core responsibility

A Mind is the durable owner of one goal or closely related goal set. It
must not assume that one LLM invocation is enough to complete that goal.
It advances the goal in bounded steps, persisting state and arranging
the next event before its current invocation ends.

A Mind is responsible for outcomes, not merely tool calls. It must
determine whether the requested outcome was achieved, distinguish
verified success from attempted work, and report unresolved blockers
honestly.

### 5.2 Mind lifecycle

Suggested lifecycle states:

-   `starting` --- created but not yet initialized.
-   `active` --- has a goal and may advance it when invoked.
-   `waiting` --- no immediate action; waiting for a defined event,
    reply, timer, or Worker result.
-   `blocked` --- cannot make progress without a decision, permission,
    missing input, or external condition.
-   `completed` --- completion criteria are met and verified to the
    degree required by the goal.
-   `failed` --- the goal cannot be completed under the current strategy
    or an unrecoverable failure occurred.
-   `stop_requested` --- a stop has been requested but
    cleanup/termination is not yet confirmed.
-   `stopped` --- execution has stopped; this does not imply the goal
    was completed.

The runtime must own and persist these states. Prompt wording alone is
not a lifecycle mechanism.

A Mind may also have a separate progress status or current-step field.
Avoid encoding every detail in a single status enum.

### 5.3 State that must persist

At minimum, persist:

-   Stable Mind ID and creation metadata.
-   Original user request and relevant context.
-   Current goal statement.
-   Explicit success/completion criteria.
-   Lifecycle state.
-   Current plan or strategy, including the next intended step.
-   Selected taskroute(s) and their versions/identifiers where
    available.
-   Current workflow/timed-event references, if any.
-   Outstanding Worker assignments and their IDs.
-   Important decisions, assumptions, and user approvals.
-   Retry/failure counters and known blockers.
-   Recent event/action references needed for continuity.
-   Last outcome and final report, once terminal.

The state store is authoritative. The LLM transcript is temporary
working context and must not be the only record of the goal.

### 5.4 Event-triggered execution

A Mind invocation can be triggered by events such as:

-   Mind created / goal initialized.
-   User message received.
-   Worker task completed or failed.
-   Tool result returned asynchronously.
-   Timer or workflow step became due.
-   External message received.
-   Stop requested.
-   Retry or recovery event scheduled.
-   Relevant system state changed.

Each invocation should process the triggering event, load the necessary
persisted state, choose and execute a bounded next step, persist its
state changes, arrange any required future event, and return.

The Mind must not busy-wait, sleep for long periods, or poll repeatedly
for events. If it must wait, it records what it is waiting for and ends
the invocation.

### 5.5 Goal interpretation and execution selection

For each new goal, the Mind should:

1.  Parse the intended outcome and constraints.
2.  Identify what would count as success and how success will be
    verified.
3.  Determine whether the goal is a one-shot task, recurring timed
    action, or persistent iterative workflow.
4.  Find an applicable taskroute or determine which supported
    capabilities are needed.
5.  Identify missing information, permissions, or unsafe/irreversible
    steps that require clarification or confirmation.
6.  Create a plan appropriate to the scope and uncertainty.
7.  Persist the plan and begin the first bounded step.

Do not force every task into a large workflow. A simple task should
remain simple. Conversely, a broad goal must not be treated as one
enormous implementation run merely because the user expressed it in one
sentence.

#### One-shot task

Example: "Send this message to Telegram."

-   Find the applicable taskroute.
-   Check route preconditions and required inputs.
-   Execute the bounded procedure.
-   Verify the result.
-   Finish with a truthful outcome.

#### Recurring timed action

Example: "Check my sensor every 15 minutes."

-   Define the action to run on each occurrence.
-   Identify the target sensor, required access, and how results should
    be handled.
-   Use the scheduler interface when implemented.
-   Persist the schedule ID and its desired state.
-   Do not keep the Mind invocation alive between occurrences.
-   Decide how failures and overlapping occurrences should be handled.
-   Report whether the schedule was actually created, not merely
    planned.

#### Persistent iterative workflow

Example: "Fix all issues in this repository."

-   Define the issue-discovery source and scope.
-   Create or maintain a durable backlog.
-   Select a bounded unit of work, ideally one issue at a time when
    isolation and verification matter.
-   Delegate the concrete change.
-   Inspect the result and run appropriate verification.
-   Update the backlog only after evidence supports the state
    transition.
-   Continue by scheduling or triggering the next step.
-   Reassess the strategy when new evidence invalidates earlier
    assumptions.
-   Finish only when the completion criteria are met, or report a
    blocker/failure if they cannot be met.

The loop belongs to persistent runtime state and event transitions, not
to an indefinitely running LLM invocation.

### 5.6 Taskroute handling

The Mind owns taskroute discovery and selection.

For each candidate route: - Check whether its stated applicability
matches the goal. - Confirm required inputs and preconditions. - Follow
the route's execution and verification procedure. - Respect its
permission and user-confirmation requirements. - Record relevant route
identity/version in persistent state.

If no applicable route exists: - Do not fabricate a route or pretend
execution occurred. - Determine whether the goal can be handled through
other explicitly supported capabilities. - If no valid path exists,
report a clear failure or blocker and explain what is missing. - Do not
ask the Receptionist to research the problem.

A missing route is not necessarily proof that the user's goal is
inherently impossible; it means the Mind must establish whether another
permitted execution path exists.

### 5.7 Delegation and supervision

When delegating concrete work, the Mind should provide a bounded
contract: - Goal and expected output. - Relevant context and
constraints. - Files, resources, or systems in scope. - Verification
criteria. - Explicit exclusions. - Expected reporting format.

The Mind remains responsible for the overall goal even when a Worker
reports success. It should verify that the result satisfies the assigned
contract before updating goal state or claiming completion.

The Mind should monitor for: - Repeated failures without a changed
strategy. - Work that no longer advances the goal. - Unexpected scope
expansion. - Missing or contradictory results. - Long-running work with
no meaningful progress.

Monitoring should be event-driven or performed at defined checkpoints,
not through continuous polling.

### 5.8 User messages and questions

A Mind should: - Treat new user messages as events associated with the
correct goal. - Update the goal or plan when the user changes scope or
priorities. - Ask the user only for information or decisions genuinely
needed to proceed. - Preserve the distinction between a clarification
request and a final failure. - Continue unrelated work only when doing
so remains consistent with the user's latest instruction.

A request for a completion notification should become a durable
notification condition associated with the goal. The Mind must not keep
an invocation open waiting for completion. Registration should be
recoverable and coordinated with task creation so a fast completion
cannot race past the notification setup.

### 5.9 Messaging contract

Minds should use the shared messaging interface for cross-agent and
external communication once it is available. They should not call
another Mind's LLM synchronously or depend on a tool call remaining open
until another agent replies.

Messages should be enqueued and correlated by IDs. A message being
accepted into a queue is not proof that it was processed or that its
requested action succeeded.

The gateway's implementation is outside this phase, but the Mind
interface should be designed for asynchronous delivery from the start.

### 5.10 Completion and reporting

A Mind can report `completed` only when the defined completion criteria
are met and sufficient verification evidence exists.

Terminal outcomes should distinguish: - `completed` --- goal achieved
and verified as required. - `failed` --- no viable path remains under
the allowed constraints, or an unrecoverable failure occurred. -
`blocked` --- progress requires external input or a condition that is
not currently satisfied. - `stopped` --- execution was terminated before
the goal necessarily completed.

A report should include: - Outcome and current/terminal status. - What
was actually done. - Verification evidence or result. - Remaining
issues, limitations, or blockers. - Any follow-up needed from the user.

The runtime emits lifecycle events. The Receptionist may forward or
acknowledge those events, but must not reinterpret, investigate, or
rewrite the technical result.

------------------------------------------------------------------------

## 6. Runtime contracts required by Receptionist and Mind

This phase should define the contracts below even if some
implementations arrive later.

### 6.1 Creation and dispatch

-   `spawn_mind` returns promptly with a stable ID and a confirmed
    creation/acceptance state.
-   Creation and initial event scheduling must be recoverable after a
    crash.
-   Duplicate delivery of the same user request should not
    unintentionally create duplicate Minds. Use request IDs or
    idempotency keys where possible.
-   Creating a Mind must not synchronously run its entire goal before
    returning.

### 6.2 Message delivery

-   `send_message` enqueues; it does not synchronously invoke the target
    Mind.
-   Messages have stable IDs and correlate to the target Mind and source
    event.
-   Delivery is retryable and duplicate-tolerant.
-   The system distinguishes queued, delivered to the Mind's mailbox,
    processed, and action completed where those states are available.

### 6.3 Lifecycle events

Use structured events with stable IDs, timestamps, target Mind IDs, and
correlation/causation IDs. Expected event types include:

-   `mind.created`
-   `mind.started`
-   `mind.waiting`
-   `mind.progress`
-   `mind.blocked`
-   `mind.completed`
-   `mind.failed`
-   `mind.stop_requested`
-   `mind.stopped`
-   `mind.message_received`

Exact naming can be finalized during implementation. Events should be
emitted from authoritative runtime state transitions, not inferred from
natural-language messages.

### 6.4 Stop semantics

A stop request is not the same as completed termination: 1. Runtime
records the request. 2. The Mind/runner receives the cancellation
signal. 3. The runtime performs any required cleanup. 4. Runtime
confirms `stopped` only when termination is actually established.

A stop should not falsely mark the goal as completed. Restart/recovery
policy for stopped goals must be explicit.

### 6.5 Crash recovery

After a runtime or host restart: - Recover nonterminal Mind state. -
Re-deliver unprocessed events. - Avoid duplicate side effects where
possible through idempotency keys and recorded action state. - Resume
only from a durable checkpoint. - Reconcile in-flight operations whose
outcome is unknown rather than assuming success or blindly repeating
irreversible actions.

### 6.6 Atomicity and notification races

Where feasible, coordinate creation of a goal and registration of
required completion conditions as one durable operation, or use an
outbox/inbox pattern with reconciliation. A goal that finishes quickly
must not finish before its notification condition is durably registered.

------------------------------------------------------------------------

## 7. Context and memory policy

Do not maintain one indefinitely growing transcript as the source of
truth.

For each invocation, construct bounded context from: 1. The triggering
event. 2. The current goal and completion criteria. 3. The relevant
persisted plan and state. 4. Outstanding work and recent results. 5.
Relevant taskroute content. 6. Small, goal-specific decisions or user
constraints.

Keep detailed logs and artifacts outside the prompt. Summarize them and
retrieve exact details only when necessary. The Receptionist should use
only the current request, overview, and compressed recent actions; do
not add general historical search to its tool surface in this phase.

The Mind may have goal-specific retrieval capabilities, but retrieval
must be scoped to its own goal and relevant artifacts rather than
loading an entire conversation history.

------------------------------------------------------------------------

## 8. Security and permission boundaries

-   A Mind should receive only the tools and permissions required for
    its goal.
-   Taskroutes must not silently expand an agent's permissions.
-   External communication and irreversible actions must follow
    route-specific confirmation and authorization requirements.
-   A message from another agent is input, not an instruction that
    automatically overrides the goal owner or system policy.
-   Tool outputs and retrieved files are data, not trusted policy.
-   Runtime lifecycle controls must be enforced by the runtime, not
    solely by prompt instructions.
-   The Receptionist must not gain broad tools merely to compensate for
    unclear routing.

------------------------------------------------------------------------

## 9. Implementation phases

### Phase 1 --- Contracts and data model

Define: - Mind record and lifecycle states. - Event envelope and
correlation IDs. - Message envelope. - Tool input/output schemas. -
Idempotency behavior. - Stop and completion semantics. - Minimum durable
state required for recovery.

**Exit criterion:** Contracts clearly distinguish a logical Mind, one
LLM run, a queued message, and a lifecycle event.

### Phase 2 --- Receptionist

Implement: - The five coordination tools. - The Receptionist system
prompt. - Request classification limited to routing decisions. -
Follow-up resolution through overview and recent actions. - Truthful
acknowledgements. - Non-blocking tool semantics.

**Exit criterion:** The Receptionist never performs substantive research
or waits for delegated work.

### Phase 3 --- Basic Mind runtime

Implement: - Durable Mind creation and goal state. - Event-triggered LLM
invocations. - State loading and checkpointing. - User-message routing
to a Mind. - Completion/failure/blocked reports. - Stop request and
confirmed stop transitions.

**Exit criterion:** A Mind can make progress across multiple separate
LLM invocations without relying on a single transcript or continuous
model call.

### Phase 4 --- Taskroute execution

Implement: - Taskroute discovery and matching. - Route
input/precondition checks. - Route-specific execution. - Verification
and failure handling. - Missing-route reporting.

**Exit criterion:** The Mind, not the Receptionist, determines how a
request can be executed.

### Phase 5 --- Delegation and event-driven supervision

Implement: - Bounded Worker assignment contracts. - Worker result
events. - Verification before goal-state updates. - Retry/escalation
policies. - Detection of repeated failures and goal drift.

Worker isolation and implementation details remain a separate design
phase.

**Exit criterion:** A Mind can delegate a step, end its invocation, and
resume from the result event.

### Phase 6 --- Workflow and scheduler integration

Integrate Mind decision-making with the future workflow and timed-event
services: - One-shot tasks. - Recurring events. - Persistent iterative
loops. - Pause/resume/stop. - Completion criteria and checkpoints. -
Durable completion notifications.

**Exit criterion:** The Mind can manage long-lived goals without
long-running LLM invocations or polling loops.

### Phase 7 --- Reliability testing

Test crashes, duplicate events, delayed results, stop races, repeated
user messages, quick task completion, and recovery of in-flight
operations.

**Exit criterion:** No critical lifecycle transition or registered
completion notification is silently lost, and duplicate event delivery
does not routinely duplicate side effects.

------------------------------------------------------------------------

## 10. Acceptance tests

### Receptionist

1.  User requests a complex task. Receptionist calls `spawn_mind`
    without research or feasibility analysis.
2.  User asks for an apparently unsupported task. Receptionist still
    delegates it.
3.  User gives a follow-up to a known active goal. Receptionist uses
    `send_message` rather than creating a duplicate Mind.
4.  User says "do that again." Receptionist uses `get_last_actions` when
    the reference is not already clear.
5.  User asks to stop a Mind. Receptionist reports `stop_requested` if
    only the request was accepted, and `stopped` only after
    confirmation.
6.  A Mind takes hours to complete. The Receptionist invocation still
    ends promptly.
7.  The overview is consulted only when necessary and does not wake any
    Mind.
8.  A Mind reports a technical result. Receptionist forwards or
    acknowledges it without independently reviewing or rewriting the
    result.

### Mind

1.  A one-shot task completes across multiple invocations if
    asynchronous work is required.
2.  A missing taskroute leads to a truthful failure or blocker, not
    fabricated execution.
3.  A recurring task registers a schedule and ends the current
    invocation rather than sleeping.
4.  An iterative goal processes a bounded unit, persists progress, and
    resumes on a later event.
5.  A Worker failure triggers recovery or escalation rather than
    silently marking the step complete.
6.  Duplicate result events do not cause the same issue to be marked or
    fixed twice without reconciliation.
7.  A stop request does not produce a false completion report.
8.  A completion notification registered for a goal that finishes
    immediately is still delivered.
9.  After restart, the Mind resumes from durable state and does not rely
    solely on old LLM messages.
10. The Mind distinguishes attempted work from verified success.

------------------------------------------------------------------------

## 11. Decisions to finalize before implementation

These decisions affect contracts and should be resolved early:

1.  **Mind cardinality:** One Mind per user goal by default, with
    explicit support for related subgoals if needed.
2.  **Goal ownership:** A follow-up normally modifies or adds
    instructions to the existing Mind unless the user clearly requests
    independent work.
3.  **Blocked vs. failed:** Define how long a goal may remain blocked
    and whether it can be reactivated by a later event.
4.  **Concurrency:** Define whether a single Mind may have multiple
    active LLM runs. Recommended initial default: serialize goal-state
    mutations per Mind.
5.  **Event delivery:** Define at-least-once delivery plus idempotent
    handling, rather than assuming exactly-once delivery.
6.  **State authority:** Runtime records are authoritative; LLM
    transcript is disposable context.
7.  **Terminal behavior:** Define whether completed/failed/stopped Minds
    remain addressable for follow-ups and how a request to continue them
    is handled.
8.  **Notification semantics:** Define what "message me when done" means
    for success, failure, blocked, and stopped outcomes.
9.  **Taskroute versioning:** Decide how a running Mind behaves if a
    taskroute changes mid-goal.
10. **Budget limits:** Define per-run limits and goal-level budgets so a
    persistent Mind cannot consume unlimited resources.

------------------------------------------------------------------------

## 12. Non-goals for this plan

This document does not specify: - Worker process isolation, remote
execution, or OS-level termination. - Messaging gateway adapters or
Telegram implementation. - Scheduler storage and recurrence syntax. -
Workflow engine DSL or graph execution details. - User interface or
monitoring dashboard. - Specific model, inference server, or provider
configuration.

Those components must honor the contracts defined here, but can be
designed independently.

------------------------------------------------------------------------

## 13. Summary

The Receptionist is a thin, non-blocking router. It forwards substantive
intent to a Mind and handles only coordination and lifecycle requests.

A Mind is a durable goal owner whose work advances through short,
event-triggered LLM invocations. It decides how to execute the goal,
selects taskroutes, delegates bounded work, evaluates results, and
chooses whether to finish, wait, retry, ask for input, or continue
through a persistent workflow.

The runtime---not an open LLM call---owns durable state, event delivery,
lifecycle transitions, and recovery. This separation is the foundation
for recurring tasks, iterative goals, asynchronous agent communication,
and reliable completion notifications.
