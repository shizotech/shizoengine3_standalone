---
id: health-check
title: Health check the Mind
project: example-project
priority: normal
schedule:
  type: recurring
  days: [sunday]
  window: tonight
policy:
  max_parallel_workers: 1
  stop_policy: checkpoint
  verify: true
  allow: [read, edit, move, delete, test, commit, push_branch]
  require_approval: [merge, release, deploy, force_push]
---

# Objective

Audit and clean the workspace Mind (`.megamind/topics/`): remove stale topics and nodes,
archive finished topics, and verify that every claim still matches the repository.

## Scope

- Work on `.megamind/topics/`, `.megamind/archive/`, and `.megamind/sessions/` only as an
  input for cross-checking. Do not edit source code, repository docs, `goal.md`, `.agentspace/`,
  or `.runtime/`.
- Do not delete a topic or node unless its claims are obsolete, duplicated, or contradicted by
  the repository. Archive first when the history is still useful; delete empty or duplicate
  artifacts after the archive.
- Keep the Mind graph closed: every live node is linked from its topic's `index.md`, and
  `index.md`, `roadmap.md`, `taskboard.md`, `avoid.md`, and `log.md` are current.
- Scratch work stays in `testbench/health_check/`; never copy source files, logs, chats, or
  generated data into the Mind.

## Workflow

1. List `.megamind/topics/` and read every `index.md`. Record each topic's status, nodes, edges,
   and last update.
2. Open the live nodes that matter and compare their claims against the current repository:
   file paths, symbols, APIs, contracts, behavior, and docs. Mark every claim as current,
   stale, wrong, or unverifiable.
3. Merge duplicate or overlapping nodes into the existing node; update every edge that points
   to the old node instead of creating a third version.
4. Archive or remove stale topics and nodes. When a topic is finished, set `status: done` in
   its `index.md`, promote durable facts into repository docs, then move the topic to
   `.megamind/archive/`.
5. Update `taskboard.md` with finished and deferred work. Add dead ends and pitfalls to
   `avoid.md`; append one dated line to `log.md`.
6. Verify the result: every live topic has an `index.md`, no live node is unreachable, no
   artifact is stored in the Mind, and durable claims agree with the repository.
7. Report what was archived or removed, what was corrected, and what remains for a later run.

## Acceptance Criteria

- No stale topic or duplicate node remains live; every removed or archived item is named.
- Every live topic has an `index.md` and every live node is linked from it.
- The Mind's durable claims match the repository, or mismatches are reported with file
  references.
- The report lists the files inspected, the cleanup performed, the verification evidence, and
  the remaining stale or unverifiable items.

This goal is proposed. Move it to `goals/active/` only when the owner wants the weekly Mind
health check to run.
