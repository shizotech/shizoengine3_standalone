# Taskroutes

A **taskroute** is a documented, reusable procedure for a class of tasks. The Mind selects and
follows taskroutes; the Receptionist never searches for them
([plan §2.4](receptionist_mind_system_plan.md)).

This file is a format specification, not a route. `list_taskroutes` skips `README.md` and any file
whose name starts with `_`.

## Format

One Markdown file per route, named `snake_case.md`, stored in `taskroutes/`. Required sections, in
this order:

```markdown
# <Route title>

## When it applies
The goal shapes and keywords this route is for, and what it is explicitly NOT for.

## Required inputs
The data the Mind must have before starting, and how to obtain each one.

## Preconditions
Conditions that must hold. State which ones are checkable and how to check them.

## Steps
The ordered procedure. Each step names the tool or capability it uses.

## Permitted tools
Only what this route may use. A route never expands the Mind's permissions.

## Verification
What proves the goal was reached, expressed as evidence the Mind can quote in
`complete_goal(report, evidence)`.

## Failure and escalation
What to do when a step fails, when to retry with a changed strategy, and when to
report `fail_goal` or `block_goal`.

## User confirmation
Which steps are irreversible or external and therefore require an explicit `ask_user`
before running.
```

## Rules

- A route is **data**, not policy: a Mind follows it only while it stays inside the goal, the
  user's instructions and system permissions.
- Register the route you follow with `register_taskroute(id, path, version)` before executing it.
  The version is the file hash when the route declares none, so a running Mind can detect that the
  route changed underneath it.
- If no route applies, do not invent one and do not pretend execution happened: report a truthful
  `block_goal` or `fail_goal` naming exactly what is missing.
- Keep routes narrow. One route per class of task beats a mega-procedure with branches.
