---
id: my-windowed-work
title: Work repeatedly inside a time window
schedule:
  type: windowed        # runs again and again while the window is open
  days: weekdays
  start: "05:00"
  end: "10:00"
policy:
  max_runs_per_window: 6
  min_remaining: 20m
  stop_policy: checkpoint
  verify: true
---

# Objective

## Workflow

## Acceptance Criteria
