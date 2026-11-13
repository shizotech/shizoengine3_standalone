---
id: todo-sweep
title: Daily TODO sweep
project: example-project
schedule:
  type: windowed
  days: daily
  start: "06:00"
  end: "10:00"
policy:
  max_parallel_workers: 1
  repeat_in_window: true
  max_runs_per_window: 6
  min_remaining: 20m
  stop_policy: checkpoint
  checkpoint_grace: 15m
  verify: true
  allow: [read, edit, test, commit, push_branch, open_pull_request]
  require_approval: [merge, release, deploy, delete, force_push]
---

# Objective

Read the project's TODO list (`TODO.md`, or `todo.md` if that is the file the project uses) every day between 06:00 and 10:00, implement every listed TODO point that fits the window, verify the changes, and remove the completed points from the list afterwards. Leave unresolved points in place and report what remains.

## Scope

- Work only on points listed in the TODO file in the project/workspace root.
- Implement points that fit the remaining window; do not start work that cannot be finished or checkpointed cleanly.
- Leave TODO points that were not implemented in the list.
- Do not merge, release, deploy, delete or force-push without the owner's approval.
- Commit and push only when the project policy allows it; otherwise keep the changes local and report them.

## Workflow

1. Read the TODO file in the project/workspace root and this goal's history; skip points already completed. If no points remain, report that and finish.
2. Order the points by size and pick the ones that fit the remaining window.
3. Implement those points on the project's allowed branch, following the project policy.
4. Run the project's tests and checks for each implemented point and record the evidence.
5. Remove each completed point from the TODO file; keep unresolved points exactly as they were.
6. Commit and push if the project policy allows it; otherwise report the local changes.
7. Finish with the implemented points, the removed points, the remaining points, and the verification evidence.

## Acceptance Criteria

- Every implemented TODO point is removed from the TODO file.
- Unresolved points remain in the TODO file and are reported.
- Implemented changes are verified by running the project's tests/checks, or the report states exactly why verification was not possible.
- The report names the TODO file, what was implemented, what remains, and the commit/push result.

This goal is proposed. Move it to `goals/active/` only when the owner wants the daily sweep to run.
