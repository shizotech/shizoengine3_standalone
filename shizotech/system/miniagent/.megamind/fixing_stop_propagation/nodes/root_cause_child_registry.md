# root cause: the child registry

`miniagent.subagent()` had:

```
//Clear old entries first
for(i = 0; i < _child_agents.size(); i++) {
    if(_child_agents[i])      // <-- live entries, not dead ones
        _child_agents.erase(i);
        i--;
}
```

Two bugs in five lines:

1. The condition is inverted: it erases every **live** child and keeps the dead
   ones. Every `subagent()` call wiped the siblings, so `_child_agents` held only
   the newest child and `stop()` reached only that one.
2. `i--` is not part of the `if` body (indentation-scoped body = the single
   `erase` line), so it runs on every iteration.

`simple_agent()` had the same shape with `if(!_child_agents[i])`: the unconditional
`i--` spins forever on the first live entry (infinite loop, hidden because it is
only reached when a parent already has children).

Measured before the fix (`testbench/fixing_stop_propagation/probe_stop.shio`):
3 children + 2 grandchildren, `root.stop()` → only the last child stopped
(`stops: root=1 a=0 b=0 c=1 ga=0`), and a child created after the stop ran
normally (`runs=2`).

After the fix: all 6 stopped, late/continued children refuse to generate.

The adaptive role makes this fatal because it spawns children from **threads**
(`fork`, `file_task_batch` pool, parallel `start_task` tool calls): each thread
creates a subagent and erases the others from the registry.

Fix: prune only falsy entries, `i--` inside the `if`, registration + pruning under
`std.critical_section_named("miniagent_tree")`, and `stop()` iterates a snapshot.

See [stop contract](stop_contract.md).
