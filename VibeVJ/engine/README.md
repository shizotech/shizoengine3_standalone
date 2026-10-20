# Engine Code

The `engine/` directory contains the core engine implementation for the VJ application.

Core principle: **everything is a generator.** The base generator wrapper
(`engine/generators/generatoritem.shio`) creates a nanoGUI window/node,
handles the window header (power button, ⋯ menu with save preset and reload,
maximize / collapse / close) and state save/load. The actual generator behavior comes from a "loader" selected by
the asset file extension. Loaders live in `engine/generators/extensions/`.

```
engine/
├── style.json                     # Styling configuration
├── last_project.dat               # Last project data
├── assets/                        # ENGINE-INTERNAL generator assets (DO NOT CHANGE)
│   ├── composition.glsl/          # Composition shader (src/__init__.glsl)
│   ├── layerblend.glsl/          # Layer blending shader (src/__init__.glsl)
│   └── shaderstack.asset/        # Shader stack configuration (src/__init__.shio)
├── generators/                    # The "views" — containers that hold one or more generators
│   ├── generatoritem.shio         # Universal generator wrapper class (window, header: power, ⋯ menu, maximize/collapse/close, state save/load)
│   ├── generatorview.shio         # Generator view (holds multiple generators)
│   ├── clipview.shio             # Clip view
│   ├── clipstackview.shio        # Clip stack view
│   ├── singleview.shio           # Single-view container
│   ├── asset_resolver.shio       # Asset ids (asset.json): finds the asset of a saved generator after a move (#202)
│   └── extensions/               # Per-extension "loaders" (each exports load_extension(generator))
│       ├── asset/__init__.shio   # Loader for .asset generators (src/__init__.shio entry point)
│       ├── glsl/
│       │   ├── __init__.shio     # Loader for .glsl generators (src/__init__.glsl entry point)
│       │   └── shader_loader.shio
│       ├── png/
│       │   ├── __init__.shio     # Loader for .png image generators
│       │   └── image_module.shio
│       └── txt/
│           ├── __init__.shio      # Loader for .txt text generators
│           └── text_module.shio
├── interfaces/
│   ├── aiinterface.shio           # AIInterface: the queries an AI agent can run on a generator
│   ├── mcp_bridge.shio            # MCP server of the MCP tab, serves the AIInterface queries as tools
│   └── videorouter.shio
├── migrate/
│   └── migrate.shio               # Format of projects and presets on disk, steps from older formats (#386)
├── patch/                         # The fixture setup as data (#439), no UI
│   ├── patch.shio                 # Lamps (node > universe > address), groups, nodes: engine.patch
│   ├── ledmap.shio                # LED positions and DMX addresses of the LEDMapper
│   ├── dmx.shio                   # Who sends to which channels, channels written twice (#440)
│   ├── patch_ai.shio              # The fixture setup's AI queries: engine.patch_ai, live_path fixture_setup (#440)
│   └── palette.shio
└── processes/                     # Subprocess code (DO NOT CHANGE)
    ├── audio_process.shio         # Audio processing subprocess
    └── monitor_process.shio       # Monitor processing subprocess
```

## AI access: AIInterface, Chat and MCP

Every generator owns an `AIInterface` (`generatoritem.ai_interface`). Generators and their
modules register queries with `generator.register(name, args, callback, description, access)`:

```
generator.register("set_split", [size = "&float(0,1): Normalized split position"], [this](args){
	...
	return [ok = 1];                      // [ok = 0, error = "..."] reports a failure
}, "Moves the split.");
```

- `args` use the typed notation of the MCP / openai includes (`&` = required, `string()`, `int(min,max)`,
  `float()`, `enum(a,b)`, `any()`). A plain description is still accepted (becomes `&any(): ...`,
  `any(): ...` when it starts with OPTIONAL).
- `access` is `"read"` or `"write"`; by default names starting with `get_` / `list_` / `has_` are reads.
- `query(name, args, caller)` returns `[ok = true, value = ...]` or `[ok = false, error = "<real message>"]`,
  `list_queries()` / `describe()` / `on_query_changed()` describe the interface.
- Two agents use the interfaces at the same time: the **Chat** tab (in-process miniagent, caller `"chat"`)
  and the **MCP** tab (`engine/interfaces/mcp_bridge.shio`, caller `"mcp:<client>"`). Without locks the last
  write wins; `lock(owner, ttl_ms)` reserves a generator for one caller. The last write of any agent is in
  `engine.ai_activity` and shown in both tabs ("AI control").
- All interfaces are listed in `engine.ai_interfaces`. Asset modules include the engine files into their
  own `std.module()`, so shared state lives on the engine object, not in file globals.
- The fixture setup is no generator but has an interface too: `engine.patch_ai` (`patch/patch_ai.shio`),
  live_path `fixture_setup`. Its queries list, add, change and remove lamps, groups and nodes of the patch and
  report channels written twice (`patch/dmx.shio`: lamps and the segments every LEDMapper publishes). The Chat
  reaches it with the tool `vibevj_fixture_setup`, MCP clients with its query tools (`list_fixtures`, ...);
  a query tool without a live_path goes to the only generator that has that query. Writes change
  `engine.patch` at once and call `engine.patch_changed()` at the end of the frame (`patch_changed_soon()`),
  not from the query's thread.

The MCP tab runs the server on a configurable port (default 13340, `configs/mcp_server.json`):
`http://localhost:<port>/mcp` (Streamable HTTP) and `/sse` (HTTP+SSE). Each query name becomes a tool
with an extra `live_path` argument, plus `vibevj_list_generators`, `vibevj_get_focus`,
`vibevj_describe_generator`, `vibevj_query`, `vibevj_lock_generator`, `vibevj_unlock_generator`,
`vibevj_activity`, `vibevj_describe_layout` (the areas of every view tab as data, read only; `busy` while a step of
the layout runs) and `vibevj_list_links` (every link between controls with both ends, their place from
`nanogui.cable_place`, the type and the values; optional `filter`). "Pause" rejects every request, "Allow changes"
off rejects every write.

Tests: `_testing/aiinterface.shio`, `_testing/vibevj_mcp_bridge.shio`, `_testing/patch_ai.shio` (repo root, no GUI needed), and the Linux smoke test
`_testing/linux_app/smoke.py`, which drives the running app and checks it through this server (#385).

## Components

- **`generators/generatoritem.shio`** — the universal generator wrapper. It wraps any
  generator asset in a nanoGUI window, wires up the header (power,
  ⋯ menu, maximize/collapse/close) and state save/load, then auto-detects the asset extension:
  - No file extension → looks for `path/src/__init__.shio` (=> `asset`) or `path/src/__init__.glsl` (=> `glsl`).
  - It then loads the matching extension loader from `engine/generators/extensions/<ext>/__init__.shio`.
- **`generators/` views** — `generatorview.shio`, `clipview.shio`, `clipstackview.shio`
  and `singleview.shio` are different containers/structures for working with generators.
- **`generators/extensions/`** — each subfolder (`asset`, `glsl`, `png`, `txt`) contains an
  `__init__.shio` exporting a `load_extension(generator)` entry point (plus optional
  `save_state` / `load_state` / `dispatcher`).
- **`migrate/`** — `PROJECT_FORMAT`, the format of projects and presets. A project folder has `project.json`
  (`format`), a preset has `format` at its top level; without it the format is 1. On load, `migrate_project_file()` /
  `migrate_preset()` bring older JSON to the current format before anything reads it, so `load_state` of the views and
  generators only knows the current one. A newer format is not loaded. The first save over an older project keeps its
  old files in `projects/<name>/.backup_v<format>/`. To change the format: raise `PROJECT_FORMAT` and add a step
  (`migrate_<n>_to_<n+1>`), tested in `_testing/project_migration.shio`.
- **`assets/`** — engine-internal generator assets used as glue between engine parts.
- **`processes/`** — code for functions that must run in a subprocess.

## ⚠️ DO NOT CHANGE

- **`engine/assets/`** — these are engine-internal generator assets that glue the engine
  together. Do NOT modify, rename, or remove them.
- **`engine/processes/`** — subprocess functions for specific engine behavior. Do NOT
  modify the code here.

## Navigation / Quick Links

- [`../AGENT_README.md`](../AGENT_README.md) — Primary AI-agent onboarding (core principle + full directory map)
- [`../src/README.md`](../src/README.md) — Menu & layout UI (AssetBrowser | GeneratorView & files, Timeline at bottom)
- [`../assets/README.md`](../assets/README.md) — User-facing generator assets
- [`../assets/ASSET_GUIDE.MD`](../assets/ASSET_GUIDE.MD) — How to create/author generator assets
- [`../assets/Shaders/SHADER_GUIDE.MD`](../assets/Shaders/SHADER_GUIDE.MD) — GLSL shader authoring guide
