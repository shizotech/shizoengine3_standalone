# avoid.md — optimizing_adaptive_role

## Do not "fix" this code

`roles/adaptive/ROLE.shio:376-380` (`continue_task` task lookup) looks like a broken loop:

```
for(i = 0; i < tasks.size(); i++) {
    if(tasks[i].id == args.task_id)
        task = tasks[i];
        break;
}
```

It is **correct**. Shizoscript binds a brace-less `if` to the entire following indented block, so
`break` is inside the `if`. Adding braces is a no-op. (Proof of the semantics: the `/dream` branch
in `__init__.shio` only works because of this rule.)

Verified by experiment: an edit adding braces produced an empty `git diff`.

## Harness facts worth reusing

- Multiple tool calls in one assistant turn run **in parallel**
  (`includes/openai/openai.shio:792-799`: one `std.thread` per tool call, joined after the loop).
  This is what makes parallel `start_task` real.
- `signal()` accepts only FINISHED / FAILED / QUESTION (`ROLE.shio:449`). Any other event is an
  invalid call.
- `start_task` blocks and returns the child report; there is no async notification to the parent.
- `file_task_batch` self-manages concurrency (default 4, else `model_config.max_running_agents`)
  and must be called once per turn.
- `write_file` refuses existing non-empty files; directory `remove` needs the identical call twice;
  writes can be DECLINED by the confirmation agent (`roles/SHARED.shio`).
- Role loading: `miniagent.shio:51-66` reads `ROLE.md`, substitutes `{{OS}}` / `{{DATE}}`, then
  calls `add_tools` from `ROLE.shio`. A role file must keep both placeholders and the `add_tools`
  entry point.

## Environment limits in this repo checkout

No model config at `%APPDATA%\miniagent\default_model.json` or `%LOCALAPPDATA%\...`, so no
end-to-end agent run is possible. Verification of prompt changes is structural + source-based.
