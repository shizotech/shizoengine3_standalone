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
│   ├── mcp_layout.shio            # its layout tools: split, close, move, set the view of an area, view tabs, undo (#344)
│   └── videorouter.shio
├── migrate/
│   └── migrate.shio               # Format of projects and presets on disk, steps from older formats (#386)
├── patch/                         # The fixture setup as data (#439), no UI
│   ├── patch.shio                 # Lamps (node > universe > address), groups, nodes: engine.patch
│   ├── ledmap.shio                # LED positions and DMX addresses of the LEDMapper
│   ├── dmx.shio                   # Who sends to which channels, channels written twice (#440)
│   ├── patch_ai.shio              # The fixture setup's AI queries: engine.patch_ai, live_path fixture_setup (#440)
│   ├── fx.shio                    # What the Phaser computes: attributes, shapes, colours, the blend of phasers (#655)
│   ├── desk.shio                  # The lighting desk as logic (#719): programmer, palettes, cue stacks, command line
│   ├── desk_runtime.shio          # engine.desk: sends the desk every frame, desk.json, AI queries (live_path desk)
│   └── palette.shio
└── processes/                     # Subprocess code (DO NOT CHANGE)
    ├── audio_process.shio         # Audio processing subprocess
    └── monitor_process.shio       # Monitor processing subprocess
```

## The engine speaks ShizoScript 3 — the reference ships with the app

Every `.shio` file here is **ShizoScript 3**, the custom language of this engine; `nanogui`, `shizonet`
and the generator classes are its builtins/modules, not libraries from somewhere else. The interpreter
(`shz`, in a released VibeVJ `VibeVJ.exe` / `VibeVJ.out`) ships the reference of everything it knows,
so nothing of this repository is needed to read it:

```
shz docs                 every namespace / object type / function, with parameters and examples
shz docs <keyword>       the same, searched (plain word: nanogui, json, shader)
shz mcpdocs              the reference as an MCP server on http://localhost:13338 (the MCP tab of
                         VibeVJ itself serves its generators on 13340, a different server)
shz --check <file>       compile check without running - the way to verify an engine edit
shz --paths              the search paths a name is resolved through
```

`engine/interfaces/mcp_bridge.shio:33` reaches the stdlib the same way: its
`#include "mcp/mcp_server"` is `shizotech/includes/mcp/mcp_server.shio`, and
`src/menu/assetbrowser/chat_menu.shio:1` includes `miniagent/miniagent`, which is
`shizotech/system/miniagent/` — a folder of the same name in the app directory wins, so an app file
can shadow a stdlib file on purpose. Full rules and the measured evidence:
[`../AGENTS.MD`](../AGENTS.MD), section *ShizoScript 3*.

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
- The lighting desk (#719) has one too: `engine.desk.ai` (`patch/desk_runtime.shio`), live_path `desk`, with
  `get_desk_state`, `get_lamp_values` and `desk_command` (the command line of the Programmer: everything the desk
  does). The Chat reaches it with the tool `vibevj_desk`. Its queries take the critical section "desk", which the
  frame (`engine.desk.tick()`, after the generators) takes too. When a stack uses the phrases of the DJ, the frame
  reads the master deck of a ProlinkBridge / ProlinkDecks (`std.global("prolink_sources")`, only `master()`: `events()`
  empties the queue the generator itself reads). The inputs of the groups (Devices > Fixtures > Masters > Groups) are read by the frame
  (`fixture_menu.group_input_values`); a ColorSelector row with *Lamps* sends through `engine.desk.set_input()`.

The MCP tab runs the server on a configurable port (default 13340, `configs/mcp_server.json`):
`http://localhost:<port>/mcp` (Streamable HTTP) and `/sse` (HTTP+SSE). Each query name becomes a tool
with an extra `live_path` argument, plus `vibevj_list_generators`, `vibevj_get_focus`,
`vibevj_describe_generator`, `vibevj_query`, `vibevj_lock_generator`, `vibevj_unlock_generator`,
`vibevj_activity`, `vibevj_describe_layout` (the areas of every view tab as data, read only; `busy` while a step of
the layout runs; `areas` and `picker`: where the areas and the tiles of the pickers of the view tab in front are on the
screen) and `vibevj_list_links` (every link between controls with both ends, their place from
`nanogui.cable_place`, the type and the values; optional `filter`). `vibevj_load_project` {name} and
`vibevj_save_project` {name?} load and save a project of `projects/` as the Projects tab does (Save as… with a name),
on the render thread, and return when it is done and the layout has settled, with the errors and warnings logged
meanwhile (#634: the smoke tests load and save without restarts and the dialog). A name is one folder of `projects/`
(no `/`, `\`, `:` or leading dot). "Pause" rejects every request, "Allow changes" off rejects every write, these two
tools included.

The query tools follow `engine.ai_interfaces`: the bridge rebuilds them when `engine.ai_interfaces_revision` changed,
from a watcher thread once a second **and** before every `tools/list` and every `tools/call` of a name it does not have
(`VibeVJMCPServer.refresh`). So a query of a generator added a moment ago (`add_item` of a Camera, then `set_camera`)
can be called at once; with the watcher alone that call got "Unknown tool" in 2 of 3 runs of the smoke phase
`fixturecam` (2026-10-26).

The layout actions of the mouse are tools too (#344, `interfaces/mcp_layout.shio`): `vibevj_split_area`,
`vibevj_close_area`, `vibevj_move_view` (move, copy, swap, new_tab), `vibevj_set_area_view` (the picker of an empty
area; as a tab; Replace view), `vibevj_view_tab` (add, select, close, rename), `vibevj_set_split_sizes` (the line
between two areas) and `vibevj_undo`. They run on the render thread like the project tools and call the code of the
head, the menu, the drop and the top bar of the views (`singleview.shio`, `generators.shio`), so each is the same one
undo step as with the mouse, and return `vibevj_describe_layout` with a `result`. An area is addressed by its path in
its view tab (`generators.area_list`: "" the tab, "1/0" the index in the split or the Tabview at each level; `areas`
of `vibevj_describe_layout` has it) or by the uid of its view / the guid of its split or Tabview. All are writes.

For tests only, `"debug_input": 1` in `configs/mcp_server.json` (there is no switch for it in the MCP tab) adds
`vibevj_debug_input` (keys with modifiers, clicks, drags, scrolls and text, sent through the event path of the window,
one per frame on the render thread; the real pointer and keyboard are not used, a letter is sent as the key that has
that name in the keyboard layout in use), `vibevj_debug_widgets` (visible widgets with their text, tooltip and place;
also what widgets draw themselves: the tabs and the "+" of a tabwidget, the rows of a filebrowser, the segments of a
segmented combobox through their `item_rects()`, the cells of a gridview from its headers) and `vibevj_debug_capture`
(a PNG of the window). See `engine/interfaces/mcp_debug_input.shio`; the Mac smoke test
`_testing/mac_app/smoke.py` drives the app with them (#552), `_testing/nanogui/debug_input_test.shio` tests them.

Tests: `_testing/aiinterface_test.shio`, `_testing/vibevj_mcp_bridge.shio`, `_testing/patch_ai.shio`, `_testing/fixture_desk.shio` (repo root, no GUI needed), and the Linux smoke test
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
  Controls made by a script are saved like any other (`controls.json`: value, `#min` / `#max` under `attributes`,
  envelope) and so are the links between them, **with their type**: a load sets the saved type on the link the script
  made again. Changing the range or the link type of a script-made control (as 4 -> 5 did for the Cue List's
  Transition, 2026-10-24) therefore needs a step; the links are saved on every level of the tree, with the path of the
  node in front.
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
