---
id: github-issue-resolution
title: Resolve eligible GitHub issues
project: example-project
schedule:
  type: windowed
  days: weekdays
  start: "05:00"
  end: "10:00"
policy:
  max_parallel_workers: 1
  max_runs_per_window: 6
  stop_policy: checkpoint
  verify: true
  dry_run: true
  allow: [read, edit, test, commit, push_branch, open_pull_request]
  require_approval: [merge, release, deploy, delete, force_push]
---

# Objective

Resolve eligible issues in the repository of the project.

## Scope

- Prefer actionable issues with clear reproduction steps and a bounded scope.
- Skip issues that are assigned to someone, labelled `wontfix` / `question`, or already have
  an open pull request.
- Never merge, release or close issues yourself.

## Workflow

1. Read the open issues and this goal's history; skip what was already attempted.
2. Pick ONE issue that fits the remaining time.
3. Work in an isolated branch / worktree: reproduce, fix, test.
4. Push the branch, open a pull request that references the issue, add the test evidence.
5. Signal finished with the issue number, the PR link and what is left.

## Acceptance Criteria

- The attempted issue has a recorded outcome (PR link, or why it was skipped).
- The change has test evidence where feasible.
- Unfinished work is pushed to a branch and described.

Remove `dry_run: true` once a few dry runs (see history.md) look right, then move this folder
to `goals/active/`.
