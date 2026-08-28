# Engine Generators (`engine/generators/`)

This directory holds the **"views"** — the containers that structure and hold
one or more generators, plus the **universal generator wrapper**.

```
engine/generators/
├── generatoritem.shio        # Universal generator wrapper class (window, ACT, save/reload, big-view/collapse, state save/load)
├── generatorview.shio        # Generator view (holds a group of generators)
├── clipview.shio            # Clip view container
├── clipstackview.shio       # Clip stack view container
├── singleview.shio          # Single-generator view
└── extensions/              # Per-extension loaders (see extensions/README.md)
```

## Key Pieces

- **`generatoritem.shio`** — the base `generator` class. It is a **universal
  wrapper** for any generator asset. On init it:
  - Creates a nanoGUI `window` + a `matrixnode` for the generator's UI.
  - Wires up the **ACT** button, **Save (S)** / **Reload (R)** buttons, the
    **big-view (`|_|`)** and **collapse (`_`)** toggles and the **close (X)**
    button.
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

## Navigation / Quick Links

- [`../../AGENT_README.md`](../../AGENT_README.md) — Primary onboarding; see "DO NOT CHANGE" for `engine/assets/` (engine-internal glue) and `engine/processes/` (subprocess functions)
- [`extensions/README.md`](extensions/README.md) — The four extension loaders
- [`../../assets/ASSET_GUIDE.MD`](../../assets/ASSET_GUIDE.MD) — How to create/author generator assets
- [`../../assets/Shaders/SHADER_GUIDE.MD`](../../assets/Shaders/SHADER_GUIDE.MD) — GLSL shader authoring guide
