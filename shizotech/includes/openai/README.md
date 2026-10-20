
These are classes & functions which can be used with openai api compatible endpoints (v1)
TESTED WITH VLLM ONLY
## Context compaction (`openai_compact.shio`)

`openai_api` keeps a conversation inside the model's context without cutting it:

* A conversation that is too long is compacted: the model writes a **handoff summary** (task,
  done, facts, in progress, next, avoid) of the old messages, and that summary takes their place.
  * Before a request (`ask()`, `task()`, `get_json()`, a continued conversation): past **half
    the context**, so the model has at least half of it free to answer.
  * Between the rounds of a tool loop inside one `task()`: past **80% of the context**
    (`api.compact_run_threshold = 0.8`), so a long run is not compacted every round.
* Kept verbatim: the system prompt, the current request (the summary goes in front of it, or
  after it when the compacted part is the progress on it) and the tool round in flight (an
  assistant `tool_calls` message and its results are never separated).
* A transcript larger than half the context is summarized in parts (rolling summary).
* Inside a tool loop the size comes from the server's streamed `usage` plus the new tool
  results (no extra request).
* `api.compaction = false` restores the old behaviour (cut the oldest messages to a third);
  cutting is also the fallback when no summary can be produced.
* `api.on_compact = [](info) { ... }` gets `[messages, tokens_before, max_tokens, summary]`;
  `api.compactions` counts them.

Test: `shz openai_compact_selftest.shio` (message surgery + a real `openai_api` against a fake
server with a 2000 token context).
