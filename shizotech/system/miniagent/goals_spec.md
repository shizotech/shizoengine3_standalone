# Goals: scheduled autonomous work (`goal_engine.shio`)

A **goal** is work a node does on its own at set times: "tonight, explore a new app idea",
"every Sunday clean up the repository", "check the server logs every 2 days at 06:00",
"fix GitHub issues from 05:00 to 10:00". Goals are
Markdown files a person can read, edit, diff and version; the node's scheduler (plain code, no
LLM) decides when they run.

```
LLM (receptionist)  interprets the request  ──► create_goal / update_goal (validated by code)
                                                     │
.agentspace/goals/active/<id>/goal.md  ◄─────────────┘   ◄── or a person edits the file
        │  rescan (every tick, content hash = revision)
GoalScheduler.tick()  ── windows, misfires, retries, stop policy, limits ──►  Megamind.add_task
        │                                                                          │
.agentspace/.runtime/ledger.json  ◄──── task_finished listener / inspect_task ◄────┘
```

| File | What it is |
|---|---|
| `goal_time.shio` | calendar math, IANA zones (zoneinfo footer or built-in table), POSIX TZ rules, DST |
| `goal_frontmatter.shio` | the YAML subset of the front matter: reader and writer |
| `goal_engine.shio` | `GoalSpace` (the tree), validation, `GoalLedger` (runtime state), `GoalScheduler` |
| `goal_tools.shio` | the agent operations: `get_goals`, `create_goal`, `update_goal`, `set_goal_status`, `run_goal_now` |
| `goals.shio` | the CLI: `shz miniagent.goals ...` |
| `agentspace_template/` | what `goals init` creates |
| `goals_selftest.shio` | 161 checks, fake host + fake clock, no LLM |

## The tree

```text
.agentspace/
  preferences/scheduling.md       timezone, named windows ("tonight"), default window / duration
  preferences/resource-policy.md  background limits, interactive reservation, stop defaults
  goals/<status>/<id>/goal.md     the definition: front matter + instructions
  goals/<status>/<id>/plan.md     optional plan / checklist (agents keep it current)
  goals/<status>/<id>/history.md  one entry per run, written by the scheduler
  projects/<project>/project.md   context, paths; policy.md rules; monitors.md signals
  templates/                      starting points
  state/                          generated summaries only
  .runtime/ledger.json            runtime state (revisions, windows, runs, events) - .gitignore'd
  .runtime/requests/*.json        run requests from other processes (CLI, router)
```

`<status>` is the folder: `proposed`, `active`, `paused`, `completed`, `cancelled`,
`archived`. Only `active/` runs. A front matter `status:` that disagrees is a warning; the
folder wins. Moving the folder is the status change (the CLI and the tools do exactly that).

The node finds the tree in its working directory (`.agentspace/goals` exists) or through
`--agentspace <dir>`; `--no-goals` turns the scheduler off.

## `goal.md` — schema 1

```markdown
---
id: github-issue-resolution        # optional, must equal the folder name
title: Resolve eligible GitHub issues
project: shizoscript3              # optional: .agentspace/projects/<project>/
priority: normal                   # low | normal | high | urgent (urgent ignores background limits)
schedule:
  type: windowed                   # once | recurring | windowed | manual
  days: weekdays                   # recurring/windowed: [monday, ...] | daily | weekdays | weekends
  every: 2d                        # recurring/windowed: an interval in whole days, INSTEAD of days
  date: 2026-10-20                 # once only
  window: tonight                  # a named window from preferences/scheduling.md, or:
  start: "05:00"                   #   local wall time (quote it)
  end: "10:00"                     #   end <= start crosses midnight; or duration: 2h
  timezone: Europe/Berlin          # default: preferences timezone
  start_date: 2026-10-01           # optional bounds; with `every` it is also the phase
  end_date: 2026-12-31
  misfire: run_if_open             # run_if_open | skip | catch_up
policy:
  max_parallel_workers: 1          # work runs of this goal at the same time (1..8)
  repeat_in_window: true           # windowed default: run again while the window is open
  max_runs_per_window: 6
  min_remaining: 20m               # no new run with less time left
  stop_policy: checkpoint          # drain | checkpoint | cancel (at window end)
  checkpoint_grace: 15m
  max_attempts: 3                  # consecutive failures per window
  retry_backoff: 10m
  stall_timeout: 30m               # no agent action this long: stop + retry (default: preferences)
  verify: true                     # a verification run checks the acceptance criteria
  dry_run: true                    # write the prompt to history.md, dispatch nothing
  pause_stops: false               # pausing also applies the stop policy to a running run
  plan_updates: allow              # allow | propose | deny (may the worker edit plan.md)
  allow: [read, edit, test, commit, push_branch, open_pull_request]
  require_approval: [merge, release, deploy, delete, force_push]   # the default
---

# Objective ... (the instructions the worker gets, verbatim)
```

Scalars: `yes/no/true/false/on/off`, integers, `null`, everything else is a string. Times
must be quoted (`"05:00"`) to stay YAML-portable; unquoted works here too. Unknown fields are
a warning, not an error — **including keys inside `schedule:` / `policy:`**, so a
`schedule.interval: 2d` (a key the scheduler does not read) is reported as
`unknown field 'schedule.interval' (ignored)` instead of silently running daily.

### Validation

Every change is parsed and validated before it applies. An invalid edit is reported **once**
(console, node notification → routers → Telegram) with the file and line, and the **last valid
revision stays active**. `shz miniagent.goals validate` runs the same checks.

### Revisions and edits

- Revision = a hash of the file content. The ledger stores the text of the applied revision,
  so `goals diff <id>` shows what changed, and every change is an event
  (`definition_added`, `definition_changed`, `definition_invalid`, `status_changed`,
  `definition_removed`, with the actor: `file`, `agent`, `scheduler`).
- A window and each run record the revision they started with. Edits apply from the next run;
  a running task is never rewritten.
- Agents write through `GoalSpace.write_goal(id, data, body, status, expected_revision)`:
  validated first, written atomically (tmp + rename), refused when the file changed since
  `expected_revision` (no silent overwrite of a human edit).

## Windows

A window starts on a local day at `start` and ends at `end` (next day when `end <= start`) or
after `duration`.

Which days: `days` is a weekday set (`[monday, ...]`, `daily`, `weekdays`, `weekends`), and
`every: 2d` is an **interval in whole days** that replaces it. `days` + `every` together is an
error, `every` on `once`/`manual` is an error, a bare `2` (it would mean minutes in a duration)
and a part-day `36h` are errors, `365d` is the maximum. The **phase** of an interval is
`start_date` when given, else the local day the goal became active (`active_since` in the
ledger — a plain edit does not slide the cadence, moving the folder into `active/` re-anchors it
to that day), else epoch day 0 for a preview without a ledger. `every: 2d` + `start: "06:00"` is "every 2 days at 6:00 in the morning": gaps of exactly
2 days, across month boundaries and DST.

Daylight saving time:

- a start inside the spring gap moves forward (02:30 → 03:30 CEST), it is never skipped;
- a start inside the autumn overlap takes the first occurrence, it never runs twice;
- a 22:00-06:00 window is 9 h on the fall-back night and 7 h on the spring-forward night.

Time zones are POSIX rules: the system zoneinfo file's footer (Linux, macOS), else the built-in
table in `goal_time.shio` (Windows), or a POSIX string given directly
(`CET-1CEST,M3.5.0,M10.5.0/3`). Only the current rule of a zone is known, which is what
scheduling a few weeks ahead needs.

## Scheduler

`GoalScheduler(space, host)` runs `tick()` every 15 s on its own thread:

1. **Rescan** the tree (definitions, status folders, preferences).
2. **Settle runs**: task-finished pushes (`Megamind.add_task_finished_listener`) and
   `inspect_task` polls. `finished` → success (and a verification run if `verify`);
   `question` → the window is `blocked` and the owner is asked; `failed` / `lost` → retry after
   `retry_backoff` while `max_attempts` allows; a stop the scheduler asked for is no failure.
   A running task with no agent action for `stall_timeout` (`Megamind` task `last_update_ms`)
   is stopped and counts as a failed attempt — a deterministic watchdog, no LLM check.
3. **Window end**: no new runs; open runs follow the stop policy — `drain` lets them finish,
   `checkpoint` sends an update ("save your progress, report what is left") and stops after
   `checkpoint_grace`, `cancel` stops at once. A stop request is not a stop: the run stays open
   until the host reports it.
4. **Activate** due windows exactly once — the key is `goal id @ window start (UTC)`, stored
   before anything is dispatched, so restarts and repeated ticks never duplicate a window.
   A window that started while the scheduler was down follows `misfire`: `run_if_open` (start
   late while it is still open), `skip` (record it as skipped), `catch_up` (missed windows run
   once, now, for the original length). A window that ended unseen is recorded as `missed` and
   reported. Windows before the goal became active are never "missed".
5. **Dispatch** runs within the limits: `max_background_tasks` (node), free workers minus
   `reserve_interactive_workers`, no new run within `yield_after_interactive` of the owner's
   last request (`Megamind.background_capacity()`), per goal `max_parallel_workers`. A run is
   written to the ledger before `add_task` (outbox): after a crash it is found and settled as
   `interrupted`, then retried while its window is open. A dispatch the host **refuses** (no
   taskid) is a failed attempt: `dispatch_failed` in the ledger **and** a notification to the
   owner naming the goal, the run and the time of the next attempt — the owner does not have to
   wait for `max_attempts` to run out to learn that nothing can start on this node.

After every tick that changed something, `state/overview.md` is rewritten: every goal with
its schedule, current or next window, last outcome and file (generated, never read back).

A once-goal whose window succeeded moves to `goals/completed/`. Every activation, missed
window, finished / failed run, verification and invalid edit is a node notification
(`notify_user` → routers → Telegram) and an entry in `history.md`. A refused dispatch is
notified as well — ledger event `dispatch_failed`, no `history.md` entry, because no run
started.

### Status changes and running work

| Change | New windows | A run working right now |
|---|---|---|
| → `paused` | none | continues (`pause_stops: true`: stop policy) |
| → `completed` / `archived` | none | continues |
| → `cancelled`, folder deleted | none | stopped |

### The worker prompt

`build_prompt()`: title, window and minutes left, revision, the instructions, `plan.md`, the
project files, the previous run's report (or the tail of `history.md`), the other runs of the
goal, the rules (allowed actions, actions that need the owner's approval, branch / worktree
only, plan updates, never edit `goal.md` / `.runtime`) and the Mind topic of the goal
(`.megamind/goal_<id>/`, memory across runs). `goals run <id> --dry-run` prints it.

## Natural language (receptionist tools)

The receptionist (`roles/receptionist/ROLE.md`, "Scheduled goals") turns requests into
structured calls; code validates them.

| Tool | Does |
|---|---|
| `get_goals()` | local time, time zone, named windows, defaults, precedence rules, the goals |
| `create_goal(title, instructions, schedule_type, date?, days?, every?, window?, start?, end?, duration?, timezone?, ..., activate?)` | validated create; refuses the same id and near duplicates (`allow_duplicate=yes` overrides); `activate` missing → `proposed`; goals that allow merge/release/deploy/delete stay `proposed` |
| `update_goal(id, revision, ...)` | changes only the given fields; refuses a stale revision |
| `set_goal_status(id, status)` | the folder move |
| `run_goal_now(id)` | queues a run (the tick thread starts it) |

On a node without a goal system (no `.agentspace`) every one of these tools answers
`ok = false` with the reason; the receptionist relays that answer to the owner instead of
quietly starting the work as a normal task.

Precedence: an explicit time in the request > a named window from the preferences >
`default_window`. Preferences are only changed by the owner.

## CLI

```
shz miniagent.goals init | list | show <id> | validate [id] | next <id> [n]
shz miniagent.goals run <id> [--dry-run] | history <id> [n] | diff <id> | status
shz miniagent.goals pause|resume|cancel|complete|archive|propose|activate <id>
                    [--root <dir>]   (default .agentspace)
```

The CLI never writes the ledger: `run` drops a request file the node's scheduler consumes.

## Router / Telegram

`ai_goals` (router_api.md) lists and controls the goals of a node; `Router.goals(node?)`,
`Router.goal_action(action, goal, node?)`, router role tool `get_goals`, Telegram `/goals`
and `/goal <run|pause|resume|cancel|archive> <id> [node]`. Creating goals goes through the
normal routing: the router delegates the request, the node's receptionist owns the goal.

The node info (`AINodeInfo` / `ai_info`) advertises `goals = 1|0` — the node runs a scheduler —
so `Router.nodes_summary()`, the router role's `get_nodes` and Telegram `/nodes` show per node
whether scheduled work is possible there. On a node without an `.agentspace` every goal tool
answers `ok = false` with the reason ("Goals are not enabled on this node: start it in a folder
with an .agentspace (shz miniagent.goals init) or with --agentspace <dir>."); the receptionist
relays that text into its turn report, and the router agent says it in its `finish(report)` —
a scheduling request that cannot become a goal is reported, never quietly turned into plain work.

## Not done yet (issue #477 phases)

- Leases / heartbeats for workers on other nodes, cross-node dispatch and capability-based
  allocation (phase 2 / 5): runs are local to the node that owns the `.agentspace`.
- PostgreSQL / multi-node shared ledger: the ledger is one JSON file per node.
- Recursive planning budgets and project monitors (phase 6): `monitors.md` is documentation.
- Dashboards (phase 7): `goals list/status`, `/goals`, `state/overview.md` and `history.md`
  are the views today.
