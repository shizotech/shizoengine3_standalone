---
id: my-interval
title: Check the server logs every 2 days
schedule:
  type: recurring
  every: 2d                # an interval in whole days: every 2 days, not a weekday list
  start: "06:00"           # 6:00 in the morning, local time
  duration: 30m
policy:
  stop_policy: checkpoint
---

# Objective

Read the last 200 lines of the server log and report anything suspicious.

## Workflow

- the cadence starts the day this goal becomes active; add `start_date: YYYY-MM-DD` to
  phase it (e.g. start on the 1st of the month, every 2 days from there)
- report, do not fix: a scheduled run leaves decisions to the owner

## Acceptance Criteria

- the run names the log it read and what it found, or says "nothing suspicious"
