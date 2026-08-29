# VibeVJ (VVJ) — Agent Onboarding

A VJ (Video Jockey) application for live visual performances and creative video output, written in ShizoScript (`.shio`), GLSL (`.glsl`) and (on Windows) HLSL.

This file is the **primary onboarding document for any AI agent** working in this repository. Read it top-to-bottom before touching anything.

---

## Core Principle: "Everything is a Generator"

The entire program is built on one universal building block: the **generator**.

- A generator is a self-contained visual/logic unit that the engine loads, wraps in its own window, and manages end-to-end.
- Every visual effect, audio source, network input, output configuration, and utility is a generator. There is no separate "effect" vs. "generator" distinction — they are all the same primitive.

### The generator class

The base generator class lives in:

- `engine/generators/generatoritem.shio`

This class is a **universal wrapper** for any generator. When instantiated it:
- Creates a nanoGUI `window` + a `matrixnode` for the generator's UI.
- Provides the **ACT** button (`active_btn`) that gates whether the generator runs.
- Provides **Save (S)** and **Reload (R)** buttons, a close (`X`) button, a **big-view (`|_|`)** toggle and a **collapse (`_`)** toggle.
- Handles **state save/load** (`save_state` / `load_state`) including window position, size, big/collapse state, and per-generator data.
- Detects the asset's **file extension**, then loads the matching **extension-specific loader** from `engine/generators/extensions/<ext>/__init__.shio` and calls its `load_extension(generator)` entry point.

### Extension loaders

Generators get their actual behavior from a **loader** selected by file extension. Loaders live in:

```
engine/generators/extensions/
├── asset/__init__.shio    # Loads a .asset directory (src/__init__.shio)
├── glsl/__init__.shio     # Loads a .glsl directory (src/__init__.glsl) + shader_loader.shio
├── png/__init__.shio      # Loads a .png image generator + image_module.shio
└── txt/__init__.shio      # Loads a .txt text generator + text_module.shio
```

Each `__init__.shio` **must** export a `load_extension(generator)` entry point that builds the generator's control widgets into `generator.node`. Optional exports:
- `save_state()` / `load_state(state.data)` — per-generator data persistence.
- `dispatcher` — a callback `dispatcher(generator, cmd, value)` that the ACT button and other dispatches route through.

### How a generator works end-to-end

1. **Asset directory with an extension** — e.g. `sinegenerator.asset` or `shader.glsl`. The directory holds a `src/` entry point:
   - `sinegenerator.asset -> src -> __init__.shio`
   - `shader.glsl -> src -> __init__.glsl`
2. **Extension auto-detection** — `generatoritem.shio` inspects the path:
   - With an explicit file extension (`.png`, `.txt`, `.glsl`, `.preset`, etc.) it uses that.
   - Without a file extension, it checks `path/src/__init__.shio` (=> `asset`) or `path/src/__init__.glsl` (=> `glsl`).
3. **Loader lookup** — the class loads `engine/generators/extensions/<ext>/__init__.shio` into a `std.module()` and calls `load_extension(this)`, which populates the generator's UI and behavior.
4. **Window wrapping** — `generatoritem.shio` wraps the generator in a movable/resizable nanoGUI window with the ACT/save/reload/big-view/collapse controls and full state save/load.

### How to add a new generator

1. **Create the asset directory** with the correct extension, e.g. `assets/Generators/<Category>/<mymod>.asset` (or `.glsl` for shader-based generators).
2. **Add the entry point** inside `src/`:
   - For a ShizoScript generator: `src/__init__.shio` exporting `load_extension(generator)`.
   - For a shader generator: `src/__init__.glsl`.
3. **Ensure a matching loader exists** in `engine/generators/extensions/<ext>/__init__.shio`. The four supported extensions are `asset`, `glsl`, `png`, `txt`. If you introduce a brand-new extension, a corresponding loader must be added (this touches engine code — see DO NOT CHANGE).
4. **Implement `load_extension`** to build the control widgets into `generator.node`, and optionally `save_state`/`load_state`/`dispatcher`.
5. **Test** with `shizoscript_syntax_checker` / `shizoscript_debugger`.

See `assets/ASSET_GUIDE.MD` for the full asset authoring guide and `assets/Shaders/SHADER_GUIDE.MD` for shader authoring.

---

## Core Concept: "Design Your Own UI"

The second core idea of VibeVJ is that **users design their own UI**. Instead of a fixed, hardcoded layout, the interface is built by **dragging a view and dropping it into another view** to nest and compose individual, reusable setups. The four composable view containers make this possible:

- `generatorview.shio` — holds a free-floating group of generator windows in a scroll area (drag/drop handlers at `area.content().on_dragdrop_hover` ~lines 23-25 and `on_dragdrop` ~lines 27-33, which calls `add_generator`).
- `clipview.shio` — the clip/timeline view (drag/drop handlers `on_dragdrop_hover` ~lines 101-103, `on_cell_drop` line 105, and `begin_dragdrop` for dragging clips and stacking effects at line 866).
- `clipstackview.shio` — the clip stack view, which can itself be dragged into the clipview to stack effects onto sources (`on_dragdrop_hover` ~lines 25-27, `on_dragdrop` ~lines 29-38; see the TODO at line 4).
- `singleview.shio` — a single-generator view with its own `on_dragdrop_hover` (~lines 20-22) and `on_dragdrop` (~lines 24-30) handlers.

The engine wires `on_dragdrop` / `on_dragdrop_hover` handlers on each of these views so they can be nested and composed by the user. See `engine/generators/README.md` for the view-container overview and `assets/Views/README.md` for the user-facing view assets.

---

## Directory Map

```
.
├── AGENT_README.md            # This onboarding doc (primary agent doc)
├── __init__.shio             # Program entry point
├── deploy.shio               # Deployment script
├── test.shio                 # Test harness
├── prompt.txt                # Prompt/reference notes
├── preview.png               # Preview image
├── SPECIAL_CONTROLS.MD       # Special-key controls reference
├── VibeVJ (VVJ) Brand.md    # Branding notes
├── assets/                   # Actual generator assets (math, audio, network, utility, shaders, fixtures, LED mapping, etc.)
│   ├── Shaders/              # GLSL shader definitions (Effects, Sources, Utilities)
│   ├── Generators/           # Generator asset definitions (Audio, Math, Network, Utility)
│   ├── Fixtures/             # Fixture definitions
│   ├── FixtureEffects/       # Fixture effect assets
│   ├── LEDMapping/           # LED mapping assets
│   ├── Textures/             # Image/texture assets
│   ├── Views/                # UI view assets
│   ├── ASSET_GUIDE.MD        # Asset authoring guide
│   └── README.md             # Assets orientation
├── engine/                   # Core engine code
│   ├── generators/           # "Views" + the universal generator wrapper (generatoritem.shio)
│   │   ├── generatoritem.shio   # Universal generator wrapper class
│   │   ├── generatorview.shio   # Generator view container
│   │   ├── clipview.shio        # Clip view container
│   │   ├── clipstackview.shio   # Clip stack view container
│   │   ├── singleview.shio      # Single generator view
│   │   └── extensions/        # Per-extension loaders (asset, glsl, png, txt)
│   ├── assets/              # ⚠ DO NOT CHANGE — engine-internal glue generators
│   │   ├── composition.glsl
│   │   ├── layerblend.glsl
│   │   └── shaderstack.asset
│   └── processes/           # ⚠ DO NOT CHANGE — subprocess functions
│       ├── audio_process.shio
│       └── monitor_process.shio
├── src/                      # Menu-specific code + the entire layout UI of VibeVJ
│   ├── defs.shio            # Core definitions
│   └── menu/               # Menu system (assetbrowser, generators, timeline, mainview, midi, outputs)
├── projects/                 # Project configuration and state files
└── configs/                  # Application configuration
```

---

## ⚠ DO NOT CHANGE

- **`engine/assets/`** — engine-internal glue generators (`composition.glsl`, `layerblend.glsl`, `shaderstack.asset`) that tie the composition pipeline together. These are internal machinery, not user-facing assets. Do **not** modify or delete them.
- **`engine/processes/`** — code for specific functions that run in a subprocess (`audio_process.shio`, `monitor_process.shio`). Treat as read-only unless absolutely necessary.

Everything under `assets/`, `src/`, and `engine/generators/extensions/` is the area an agent typically works in.

---

## How the UI is laid out

The main layout is a vertical split:
- **Top** — a horizontal split of `[AssetBrowser | GeneratorView & files]`.
- **Bottom** — the **Timeline**.

The menu/UI code lives in `src/menu/`. See `src/README.md` for details.

---

## Quick Links

### Navigation
- [Engine Code](engine/README.md)
- [Source Code](src/README.md)
- [Assets Overview](assets/README.md)

### Reference Guides
- [Asset Authoring Guide](assets/ASSET_GUIDE.MD)
- [Shader Guide](assets/Shaders/SHADER_GUIDE.MD)

Always check directory specific README.md's