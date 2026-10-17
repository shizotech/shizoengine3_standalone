# fixing_stop_propagation

status: done

- [stop contract](nodes/stop_contract.md) — miniagent.stop() is top-down and total; should_stop() is ancestor-aware
- [root cause: child registry](nodes/root_cause_child_registry.md) — subagent() erased every live child, so stop() reached only the newest one
- [other stop holes](nodes/other_stop_holes.md) — finalize nudge after stop, sleep unit/interruptibility, slot queue, Megamind.stop_task
- [avoid](avoid.md) — shizoscript landmines hit while testing this (global `e` vs catch(e), JSON-literal lambda stubs, bare blocks, --verbose)
- [taskboard](taskboard.md) — 12/12 done
- test: tests/stop_propagation_test.shio (45 checks, offline, creates its own batch fixture)
- repro + probes: testbench/fixing_stop_propagation/ — probe_stop.shio (the original
  bug: 1 of 3 children stopped), probe_double.shio (finalize nudge after a stop)
