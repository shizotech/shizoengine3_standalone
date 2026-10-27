# Engine Generators (`engine/generators/`)

This directory holds the **"views"** — the containers that structure and hold
one or more generators, plus the **universal generator wrapper**.

```
engine/generators/
├── generatoritem.shio        # Universal generator wrapper class (window, header: chevron, power, link, ⋯ menu, minimize/maximize/close, state save/load)
├── generatorview.shio        # Generator view (holds a group of generators)
├── clipview.shio            # Clip view container
├── clipstackview.shio       # Clip stack view container
├── singleview.shio          # Single-generator view
├── copy_links.shio          # The links of copied generators among themselves (Ctrl at a drop, Ctrl+C / Ctrl+V, #348)
└── extensions/              # Per-extension loaders (see extensions/README.md)
```

## Key Pieces

- **`generatoritem.shio`** — the base `generator` class. It is a **universal
  wrapper** for any generator asset. On init it:
  - Creates a nanoGUI `window` + a `matrixnode` for the generator's UI.
  - Wires up the header: the **power** button (the MIDI control `ACT`), the
    **⋯ menu** (*Copy settings*, *Paste settings*, *Save preset…*, *Reload module*,
    *Hide header (E)*), the **link** button (*Always draw links*) and
    **minimize** / **maximize** / **close** (Windows order) plus the collapse chevron at the top left.
  - Handles **state save/load** (`save_state` / `load_state`) for window
    position, size, big/collapse state and per-generator data.
  - Auto-detects the asset's file extension (no extension → checks for
    `path/src/__init__.shio` = `asset`, or `path/src/__init__.glsl` = `glsl`)
    and loads the matching loader from `extensions/<ext>/__init__.shio`,
    calling its `load_extension(generator)` entry point.

- **View containers** — `generatorview.shio`, `clipview.shio`,
  `clipstackview.shio` and `singleview.shio` are the different ways to
  structure and work with one or many generators.

- **`extensions/`** — the per-extension loaders that give each generator its
  actual behavior. See [`extensions/README.md`](extensions/README.md).

## Drop targets (#346)

What a drag carries (`payload`, a JSON the nanogui screen hands to `on_dragdrop_hover` / `on_dragdrop`):

| From | Payload |
|---|---|
| Asset browser (filebrowser.cpp) | `type="files"`, `path`, `paths`; `layout=1` for a view asset |
| Header / tab of an area (`singleview.start_drag`) | `type="area"`, `layout=1`, `name` (the view is in `env.dragged_view`) |
| Alt + drag of generators (`generatorview.start_drag`) | `type="generators"`, `generators=1`, `ghost` (in `env.dragged_generators`) |
| Name tag of a clip (`clipview`) | `cell`, `item` (`type="generic"`) |
| A widget with `dragdrop_enabled(true)` | `type="generic"`, `source_widget` only |

- `layout=1` payloads only reach widgets with drop zones (the areas), not what an area shows.
- Every target answers the hover with what it takes (`takes_drop(payload)` in singleview, generatorview, clipview,
  clipstackview, `tabs_take_drop` in Tabview, `accepts` in LEDMapper): `false` makes the screen draw a red outline
  and skip the drop. The drop callback checks again and returns `false`: a hover answer may come late, and a
  missing key read outside `#strict` is `None`: before #346 a clip or generators dropped on a Patchview / a cell
  went to `add_generator(fileio.relative_path_cwd(None))`, the notice "Asset has no valid extension". Check with
  `payload.has("path")`, not `payload.path`.
- Esc during a dragdrop cancels it in the screen (`m_dragdrop_canceled`, screen.cpp): no drop, and no new dragdrop
  until the next mouse press, also not one a script starts late. `env.dragged_view` / `env.dragged_generators` stay
  set; they are only read by a drop.
- Pitfall: a widget callback (`on_mouse_button`, `on_mouse_drag`, ...) that is still running when the next event
  comes drops that event (`shz_callback_task::call`; `call_or_spawn` would queue it). A slow press handler
  (`describe_all` for undo) lost the release, a slow first click the second press of a double click. Keep press and
  click handlers cheap and finish a step in the handler that makes it (the double click on a divider in
  `splitpanes.shio` records its undo step at the press, the drag describes the layout at its first move).

## Navigation / Quick Links

- [`../../AGENT_README.md`](../../AGENT_README.md) — Primary onboarding; see "DO NOT CHANGE" for `engine/assets/` (engine-internal glue) and `engine/processes/` (subprocess functions)
- [`extensions/README.md`](extensions/README.md) — The four extension loaders
- [`../../assets/ASSET_GUIDE.MD`](../../assets/ASSET_GUIDE.MD) — How to create/author generator assets
- [`../../assets/Shaders/SHADER_GUIDE.MD`](../../assets/Shaders/SHADER_GUIDE.MD) — GLSL shader authoring guide
