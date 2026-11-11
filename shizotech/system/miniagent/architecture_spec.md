# Architecture graph (`architecture.shio`, `web/architecture/`)

A high-level map of the codebase a workspace works on, shown as a node graph in the web
interface (`shz miniagent --web`). The owner designs on that map instead of writing long
specs: edits in the graph are collected as **pending changes**, a worker can write a
**plan** for them, and only **Apply** lets a worker change the code.

```
            Analyze / Re-sync                     Review plan (optional, repeatable)
   worker ──────────────────► architecture.json ──────────────────► architecture_plan.md
   reads the code              nodes, edges,       pending edits      (no code changes)
                               pending, plan, job       │
   owner edits the graph ──────────────────────────────►│
                                                        ▼  Apply
                                              worker implements the edits;
                                              on "finished" they become the model
```

Everything runs on the workspace's task system: every job is one `Workspace.add_task`
session task (it shows in the workspace Tasks page, the Telegram router and `/api/tasks`
like any other task), its end arrives through `Workspace.add_task_finished_listener`.

## Files (the node-level graph at `std.user_path()/miniagent/node/.megamind/architecture`, a project workspace's `.megamind/architecture/`, or `--agentspace <dir>`)

| File | Written by | What |
|---|---|---|
| `architecture.json` | the board (code) | the model: nodes, edges, pending edits, plan, the last job, history |
| `architecture.analysis.json` | the analysis worker | the raw analysis; the board validates and merges it |
| `architecture_plan.md` | the plan worker | the plan the owner reads before Apply |
| `architecture_changes.md` | the board (code) | the change list of a Plan / Apply job: every edit in full, the groups, the nodes it touches |
| `architecture_plan.previous.md` | the board (code) | the last plan, read by a revision (Review plan with feedback) |

Workers never write `architecture.json`: the board merges their output, so a re-sync
cannot lose pending edits or the positions the owner arranged. A file that cannot be
read is moved to `architecture.json.corrupt-<ms>` and the board starts empty.

## `architecture.json`

```json
{
  "version": 1, "project": "demo", "summary": "two or three sentences",
  "revision": 3, "analyzed_at": "2026-10-28 18:00:00",
  "nodes": [{"id": "core", "label": "Core", "kind": "module", "group": "back",
             "path": "src/core.cpp", "purpose": "one line", "x": 120.0, "y": 80.0}],
  "edges": [{"id": "app>core:calls", "source": "app", "target": "core",
             "kind": "calls", "label": "run()"}],
  "pending": [{"id": "e1793…-ab12", "op": "add_node", "node": {…}, "note": "…", "created": 1793…}],
  "plan": {"text": "# Plan …", "edit_ids": ["e…"], "outdated": false, "feedback": "", "taskid": "…"},
  "job": {"kind": "apply", "taskid": "…", "state": "implement", "started": 1793…,
          "report": "", "error": "", "edit_ids": ["e…"]},
  "history": [{"kind": "apply", "time": 1793…, "taskid": "…", "report": "…", "edits": 2}]
}
```

* node `kind`: `module file service ui data external test config`; edge `kind`:
  `calls data includes events network` (source uses / sends to target). Unknown kinds fall
  back to `module` / `calls`. An analysis may write `from` / `to` instead of
  `source` / `target` and leave out ids (made from the label).
* `x` / `y`: the position on the page (`POST /api/workspaces/<id>/architecture/layout`); nodes without
  one are placed by the page's layout and then stored.
* An empty list is written as `{}` (ShizoScript json); readers treat it as `[]`.

## Pending edits

| op | fields | check |
|---|---|---|
| `add_node` | `node` = label, kind, group, path, purpose (x, y) | a taken id gets `-2`, `-3`, … |
| `update_node` | `target`, `node` = the changed fields | the node exists, is not pending add / remove |
| `remove_node` | `target` | its edges go with it |
| `add_edge` | `edge` = source, target, kind, label | both nodes exist (pending new nodes count), no self loop, no duplicate |
| `update_edge` | `target`, `edge` = kind / label | |
| `remove_edge` | `target` | |

Every edit may carry a `note` for the worker. Dropping an `add_node` edit drops the edits
that depend on it. The page shows the model **with** the edits applied, marked
(`pending` = add / update / remove). While an Apply runs no edits are accepted; an edit
added or dropped after a plan was written marks the plan `outdated`.

## Jobs (one at a time)

| Button | Task | When it ends `finished` | Otherwise |
|---|---|---|---|
| Analyze / Re-sync | `Architecture-Analysis`: write `architecture.analysis.json` | validated, merged (ids keep positions, pending stays), `revision + 1` | the model stays, `job.error` says why (invalid JSON, unknown node ids, no file) |
| Review plan (+ feedback) | `Architecture-Plan`: write `architecture_plan.md`, change no code | `plan` = the file (or the report) | |
| Apply | `Architecture-Apply`: implement the edits (with the plan) | the edits are committed into nodes / edges, the plan is cleared | the edits stay pending, `job.error` = the report |

Every job is **one** task with the role `adaptive` (the default role of `Workspace.add_task`;
`ArchitectureBoard(Workspace, root, role)` / `--architecture-role` change it). That agent may
delegate subtasks with `start_task` / `fork` / `file_task_batch`; how many generate at the
same time is the existing `max_running_agents` of the model config (`agent_slots.shio`),
there is no second limit.

`question` from a worker is shown as an error with the question.

## Context: big change sets

A job prompt never carries the whole model or the whole change set:

* `architecture.json` is a **file reference**: the worker searches it for the node ids it
  needs (`search_in_file`) and reads around them (`read_file` with `start_line` /
  `end_line`).
* The board writes **`architecture_changes.md`** (every edit in full, numbered, the groups,
  the nodes they touch with their connections). The prompt has one short line per edit, at
  most `ARCH_SUMMARY_LINES` (12); the rest is only in the file.
* The plan is a **file reference** too (`architecture_plan.md`, a revision reads
  `architecture_plan.previous.md`).
* **Split rule:** more than `ARCH_SPLIT_EDITS` (6) edits, or a change list or plan longer
  than `ARCH_SPLIT_CHARS` (12000 characters): the prompt tells the worker that it
  coordinates — one `start_task` per group of edits (the group of the first node an edit
  touches; a group with more than 6 edits: one subtask per edit), each subtask gets only its
  edit numbers, the change file and the files it touches, the independent groups run
  together (up to `max_running_agents`), the coordinator keeps the short results and puts
  the parts together. A plan of a split set is researched the same way and written with
  one section per group. Below the limits the worker does the work itself.
* Inside one agent, a conversation that fills up is compacted by `openai_compact.shio`
  (a handoff summary replaces the old messages), as for every miniagent.
* The job records `split` (true / false) so the page and the logs show which way it ran. A job whose task the
  workspace does not know after a restart is marked `lost`.

## HTTP (workspace API, with the node API token)

| Method | Path | Body |
|---|---|---|
| GET | `/api/workspaces/<id>/architecture` | – (model with the edits applied, pending, plan, live job) |
| POST | `/api/workspaces/<id>/architecture/analyze` | – |
| POST | `/api/workspaces/<id>/architecture/edits` | one edit (table above) |
| DELETE | `/api/workspaces/<id>/architecture/edits/<edit_id>` | – |
| POST | `/api/workspaces/<id>/architecture/discard` | – (all pending edits and the plan) |
| POST | `/api/workspaces/<id>/architecture/layout` | `{"positions": {"<id>": [x, y]}}` |
| POST | `/api/workspaces/<id>/architecture/plan` | `{"feedback": "…"}` (optional) |
| POST | `/api/workspaces/<id>/architecture/apply` | – |

A refused action answers `409` with the reason (`{"ok": false, "error": "…"}`).

## The page

`web/architecture/` — an SVG renderer of its own (no library, no CDN): groups as tinted
areas, node cards coloured by kind, curved edges with arrows (data / events animated),
pending changes in amber (removals in red), pan / zoom / drag, search, hover and
selection dim everything that is not connected. The side panel shows the overview
(pending changes, Review plan, Apply, the plan with a feedback box, history) or the
selected node / connection with its change form, *Connect to…* and *Remove*.

Tests: `shz architecture_selftest.shio` (model, merge, edits, jobs on a fake host, the
`--web` command line).
