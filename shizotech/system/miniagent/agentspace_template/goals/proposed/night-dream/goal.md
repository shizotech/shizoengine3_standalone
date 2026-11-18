---
id: night-dream
title: Night dream — review sessions and update the Mind
project: example-project
priority: normal
schedule:
  type: recurring
  days: daily
  start: "23:00"
  duration: 2h
policy:
  max_parallel_workers: 1
  stop_policy: checkpoint
  verify: true
  allow: [read, edit, move, delete, test, commit, push_branch]
  require_approval: [merge, release, deploy, force_push]
---

# Objective

Review previous sessions and chats, identify what blocked execution, and update the Mind with
learned task patterns. Remove or correct patterns that are invalid, duplicated, or outdated.

## Scope

- Read `.megamind/sessions/`, goal `history.md` files, recent reports, and the Mind topics
  (`.megamind/topics/`, `archive/`, `avoid.md`, `notes.md`). Treat chats and session logs as
  evidence, not as text to copy into the Mind.
- Update only the Mind and, where a durable fact belongs there, the repository docs. Do not
  edit source code, `goal.md`, `.agentspace/`, or `.runtime/`.
- Do not implement code fixes found during the review; record them as deferred work in the
  taskboard and report them.
- Keep every new conclusion as a linked node: create it and link it from the topic's
  `index.md` in the same edit. Merge new findings into existing nodes before creating another.

## Workflow

1. List recent `.megamind/sessions/` entries and goal histories. Read the turns, tool failures,
   finalize reports, and user corrections in chronological order.
2. Extract execution blockers: failed or missing tools, missing skills, invalid paths,
   permission limits, ambiguous contracts, merge conflicts, model/context limits, stalled
   runs, environment assumptions, and repeated retries.
3. Group blockers by root cause. For each recurring blocker, write one concrete rule: a
   pitfall in `avoid.md`, a workflow in `notes.md` or `roadmap.md`, or a durable doc update.
4. Check existing patterns and assumptions against the current repository and recent sessions.
   Delete patterns that are contradicted or obsolete; merge duplicates; fix broken edges.
5. Update `taskboard.md` with checks for the next run and deferred work. Add one dated line to
   `log.md` and keep `index.md` current.
6. Verify: every new or updated node is linked, `avoid.md` names concrete blockers and fixes,
   and no stale pattern remains live in the topic graph.
7. Report the sessions reviewed, the blockers and evidence, the patterns added, corrected, or
   removed, and what cannot be concluded yet.

## Acceptance Criteria

- The report names the reviewed sessions or histories and the concrete blockers found.
- The Mind contains only distilled conclusions; no session transcript, tool output, log, or
  generated data is copied into it.
- Invalid or outdated patterns are removed or corrected, and every new conclusion is linked
  from an `index.md`.
- The next run can use the recorded pattern without repeating the same blocker.

This goal is proposed. Move it to `goals/active/` only when the owner wants the nightly review
to run.
