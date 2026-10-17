# notes

- Config specs: plain name, path, `path#profile`.
- Search order for plain names: cwd, `.agent/configs`, default ShizoScript config dir.
- New plain-name configs are saved in cwd; existing plain names are searched cwd, `.agent/configs`, then default config dir.
- `ModelConfig` supports flat JSON, top-level profile objects, and `profiles` maps.
- `connect=false` is used for noninteractive config creation so endpoints need not be online.
- Main endpoint flags use prefix `config-` (`--config-url`), role flags use `receptionist-` and `worker-`.
- ShizoScript pitfall: `std.argv(i) ?? ""` can fail compile; assign argv to a variable first.
- ShizoScript pitfall: bare `{ ... }` blocks in class methods are not accepted; use normal statements.
