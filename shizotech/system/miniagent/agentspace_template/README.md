# .agentspace

The goals, schedules and policies of this node's autonomous agents, as plain Markdown.
Edit these files directly (or with `shz miniagent.goals ...`); the node's scheduler picks up
every change within a few seconds. Keep this folder in Git: history, diffs and rollback for free.

```text
.agentspace/
  preferences/scheduling.md       time zone, what "tonight" means, default window length
  preferences/resource-policy.md  how much background work may run, interactive reservation
  goals/<status>/<id>/goal.md     one goal: front matter (schedule, policy) + instructions
  goals/<status>/<id>/plan.md     the current plan / checklist (optional, agents keep it current)
  goals/<status>/<id>/history.md  one short entry per run (written by the scheduler)
  projects/<project>/             project context (project.md), rules (policy.md), monitors.md
  templates/                      starting points for new goals
  state/                          generated summaries only - not a source of truth
  .runtime/                       runtime state of the scheduler (ignored by Git, never edit)
```

## Status = folder

`<status>` is one of `proposed`, `active`, `paused`, `completed`, `cancelled`, `archived`.
Only goals in `active/` run. Moving a folder IS the status change:

| Move to | Effect on the next windows | Effect on a run that is working right now |
|---|---|---|
| `active/` | windows activate | - |
| `paused/` | no new windows | keeps running (`policy.pause_stops: true` applies the stop policy) |
| `completed/`, `archived/` | no new windows | keeps running |
| `cancelled/` or folder deleted | no new windows | stopped |

## Editing rules

* An edit is validated before it applies. An invalid edit is reported once (console, Telegram)
  and the last valid revision stays active, so a typo never stops or duplicates a schedule.
* A run keeps the revision it started with; edits apply from the next run.
* `shz miniagent.goals validate` checks every file, `shz miniagent.goals diff <id>` shows what
  changed since the last applied revision.
* Agents never write these files directly: they use validated goal tools that refuse to
  overwrite an edit they have not seen.

The full format: `goals_spec.md` next to the miniagent sources.
