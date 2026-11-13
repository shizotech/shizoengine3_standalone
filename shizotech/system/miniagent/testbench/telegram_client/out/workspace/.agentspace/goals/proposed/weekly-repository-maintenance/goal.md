---
id: weekly-repository-maintenance
title: Weekly repository maintenance
project: example-project
schedule:
  type: recurring
  days: [sunday]
  window: tonight
policy:
  stop_policy: checkpoint
  allow: [read, edit, test, commit, push_branch, open_pull_request]
---

# Objective

Keep the repository tidy: find redundant or dead code, outdated docs and failing checks.

## Workflow

1. Run the project's tests and linters; note what fails.
2. Look for duplicated helpers, unused files and docs that no longer match the code.
3. Fix the small things on one branch and open ONE pull request; list the bigger findings
   in plan.md instead of fixing them.

## Acceptance Criteria

- One pull request with the small fixes, or a report that nothing was found.
- plan.md lists the larger findings with file references.
