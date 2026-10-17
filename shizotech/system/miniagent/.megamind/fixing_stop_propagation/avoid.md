# avoid — landmines hit in this repo

- **Never name a global variable `e` in a script that includes miniagent/SHARED/adaptive.**
  Every included file uses `catch(e)`; in the merged script the catch variable
  aliases the global slot, and an agent stored in a global named `e` silently
  breaks (`stop()` stops calling `llm_api.stop()`, no error, `--silent` hides it).
  Cost an hour of debugging a *test*, not the code.
- **Do not build test stubs as a JSON literal holding lambdas that capture the
  agent** (`[stop = [agt]() {...}]`). Capture lifetime makes the counters
  unreliable across many instantiations. Use a small class with members
  (`class stub_api { stops = 0; stop() { stops++; } }`) — see
  `tests/stop_propagation_test.shio`.
- **Bare `{ }` blocks are not valid shizoscript** ("Too many expressions inside
  bracket"). Scope a critical section by `cs.release()`, not by a block.
- **`shz --verbose` floods the console with per-instruction compiler info.** Use
  `--silent` plus targeted `std.print`, and `--check` for syntax.
- `std.sleep` is **milliseconds**; `-1` = forever.
- Indentation-scoped `if` bodies: a following line at the *same* indent as the
  body is NOT part of the `if` — this is exactly how the `i--` bug survived.
- `tests/mind_*.shio` and `tests/receptionist_tools_test.shio` are **pre-existing
  broken**: they `#include "../runtime/mind_dispatcher"`, and `runtime/` does not
  exist in this repo. Not related to any change here.
- The repo is edited concurrently: `model_config.shio` grew from 100 to 253 lines
  and `model_config_cli.shio` appeared mid-task. Re-read a file right before
  editing it.
