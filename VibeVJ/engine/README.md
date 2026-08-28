# Engine Code

The `engine/` directory contains the core engine implementation for the VJ application.

Core principle: **everything is a generator.** The base generator wrapper
(`engine/generators/generatoritem.shio`) creates a nanoGUI window/node,
handles the ACT button, save/reload buttons, big-view/collapse and state
save/load. The actual generator behavior comes from a "loader" selected by
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
│   ├── generatoritem.shio         # Universal generator wrapper class (window, ACT, save/reload, big-view/collapse, state save/load)
│   ├── generatorview.shio         # Generator view (holds multiple generators)
│   ├── clipview.shio             # Clip view
│   ├── clipstackview.shio        # Clip stack view
│   ├── singleview.shio           # Single-view container
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
└── processes/                     # Subprocess code (DO NOT CHANGE)
    ├── audio_process.shio         # Audio processing subprocess
    └── monitor_process.shio       # Monitor processing subprocess
```

## Components

- **`generators/generatoritem.shio`** — the universal generator wrapper. It wraps any
  generator asset in a nanoGUI window, wires up the ACT button, save/reload,
  big-view/collapse and state save/load, then auto-detects the asset extension:
  - No file extension → looks for `path/src/__init__.shio` (=> `asset`) or `path/src/__init__.glsl` (=> `glsl`).
  - It then loads the matching extension loader from `engine/generators/extensions/<ext>/__init__.shio`.
- **`generators/` views** — `generatorview.shio`, `clipview.shio`, `clipstackview.shio`
  and `singleview.shio` are different containers/structures for working with generators.
- **`generators/extensions/`** — each subfolder (`asset`, `glsl`, `png`, `txt`) contains an
  `__init__.shio` exporting a `load_extension(generator)` entry point (plus optional
  `save_state` / `load_state` / `dispatcher`).
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
