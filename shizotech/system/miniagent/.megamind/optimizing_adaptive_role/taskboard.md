# Taskboard — optimizing roles/adaptive/ROLE.MD for parallel agents

STATUS: DONE. Original backup: `.megamind/optimizing_adaptive_role/ROLE.MD.orig` (890 lines / 31.5 KB).
New file: `roles/adaptive/ROLE.MD` — 482 lines / 20.5 KB (~35% smaller, all rules kept).
Also: `batch_spec.md` +8 lines documenting the once-per-turn invocation constraint.

## Blockers found and fixed

- [x] B1 `signal()` advertised `UPDATE` in "Task Exit" — the tool enum is only
      FINISHED/FAILED/QUESTION. Guaranteed invalid call. → single 3-row table, explicit
      "nothing else exists".
- [x] B2 "Do not poll for these events. The task system will signal you." — false for a parent;
      `start_task` is a blocking call that returns the child report. → "Receiving child results"
      now states results arrive as the tool return value, no async message, no UPDATE event.
- [x] B3 No instruction on HOW to get parallelism. → "Running children in parallel":
      parallelism = multiple `start_task` calls in ONE turn; sequential turns = sequential agents.
      Verified in `includes/openai/openai.shio:792-799` (one thread per tool call, joined after).
- [x] B4 `file_task_batch` never named in ROLE.md; its "one at a time, never in parallel" rule
      undocumented. → dedicated section with target semantics, snapshot, per-item QUESTION
      handling, and the once-per-turn rule.
- [x] B5 Child is amnesiac (gets only goal/context/contract/constraints/hierarchy) — never stated.
      → stated explicitly; "as discussed above means nothing to it".
- [x] B6 `continue_task` / `milestone` / `wait_for` existed in the harness, undocumented.
      → documented, incl. "a child on QUESTION stays idle forever unless continued".
- [x] B7 Batch per-item QUESTIONs are not auto-answered. → documented with task_id continuation.
- [x] B8 No file-ownership rules → parallel collisions. → "File ownership": disjoint owned paths,
      shared files owned by parent, coordinated multi-file change = one workload.
- [x] B9 Mandated shared `taskboard.md` writes from parallel agents. → children write
      `.megamind/<topic>/notes/<owner>.md`; only the parent edits roadmap/taskboard.
- [x] B10 Harness friction undocumented. → "Harness friction": write_file refuses non-empty files,
      replace_string byte-exact + multi-occurrence failure, directory `remove` double-call
      confirmation, confirmation-agent DECLINE, append_text start/end only, dynamic skill tools.
- [x] B11 "Don't verify subtasks" vs "parent verifies integration" contradiction → resolved in one
      rule: trust the child's internal work, the parent owns the seams.
- [x] B12 Repetition (decompose-not-actions ~6x, manager mode in 5 sections) → one decision tree +
      one manager section.

## Harness note (not a bug — do not "fix")

Shizoscript binds a brace-less `if` to the **entire following indented block** (see
`__init__.shio` `/dream`). The `continue_task` lookup loop at `ROLE.shio:376-380` therefore
scans all tasks correctly. An intermediate edit adding braces was a no-op and was reverted;
`git diff -- roles/adaptive/ROLE.shio` is empty.

## Verification performed

- Placeholders `{{OS}}` / `{{DATE}}` present exactly once each (lines 477-478) — harness
  substitution in `miniagent.shio:63-66` still works.
- No `UPDATE` signal anywhere (only the sentence forbidding it).
- Every tool name referenced in ROLE.md exists in `ROLE.shio` / `SHARED.shio` / `miniagent.shio`.
- Role loads: `ROLE.MD` non-empty, `ROLE.shio` present with `add_tools` entry point.
- Live agent run NOT possible here: no model config (`%APPDATA%/%LOCALAPPDATA%\miniagent\
  default_model.json` absent) and no API endpoint. Verification is structural + source-verified
  against the harness, not an end-to-end agent run.
