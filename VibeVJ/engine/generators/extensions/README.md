# Generator Extension Loaders (`engine/generators/extensions/`)

This directory holds the **per-extension "loaders"** that give each generator
its actual behavior. `generatoritem.shio` auto-detects the asset's file
extension, then loads `engine/generators/extensions/<ext>/__init__.shio`
and calls its `load_extension(generator)` entry point.

```
engine/generators/extensions/
├── asset/
│   └── __init__.shio            # Loader for .asset directories (src/__init__.shio entry point)
├── glsl/
│   ├── __init__.shio            # Loader for .glsl directories (src/__init__.glsl entry point)
│   └── shader_loader.shio
├── png/
│   ├── __init__.shio            # Loader for .png image generators
│   └── image_module.shio
└── txt/
    ├── __init__.shio            # Loader for .txt text generators
    └── text_module.shio
```

## Loader Contract

Every loader subfolder contains an `__init__.shio` that **must** export:

- `load_extension(generator)` — builds the generator's control widgets into
  `generator.node` and registers any `update` / `update_pre` / `update_post`
  callbacks.

Optional exports:

- `save_state()` — returns a JSON blob of per-generator data (called by
  `generator.save_state()`).
- `load_state(state.data)` — restores per-generator data (called by
  `generator.load_state()`).
- `dispatcher` — a `dispatcher(generator, cmd, value)` callback that the ACT
  button and other dispatches route through.

## How Extension Detection Works

`generatoritem.shio` inspects the asset path:

1. If the path has an explicit file extension (`.png`, `.txt`, `.glsl`,
   `.preset`, ...) it uses that.
2. Otherwise (a bare directory), it checks for `path/src/__init__.shio`
   (→ `asset`) or `path/src/__init__.glsl` (→ `glsl`).
3. It then loads `engine/generators/extensions/<ext>/__init__.shio` into a
   `std.module()` and calls `load_extension(this)`.

## Adding a New Extension

To support a brand-new asset extension (e.g. `.myext`):

1. Create `engine/generators/extensions/myext/__init__.shio` exporting
   `load_extension(generator)` (plus optional `save_state` / `load_state` /
   `dispatcher`).
2. Update the extension-detection logic in `engine/generators/generatoritem.shio`
   so the new extension is recognised. This touches engine code — treat with
   care (see DO NOT CHANGE callouts in `engine/README.md`).

## Navigation / Quick Links

- [`../../../AGENT_README.md`](../../../AGENT_README.md) — Primary AI-agent onboarding (core principle + directory map)
- [`../README.md`](../README.md) — Generator views + universal wrapper
- [`../../../assets/README.md`](../../../assets/README.md) — User-facing generator assets
- [`../../../assets/ASSET_GUIDE.MD`](../../../assets/ASSET_GUIDE.MD) — How to create/author generator assets
- [`../../../assets/Shaders/SHADER_GUIDE.MD`](../../../assets/Shaders/SHADER_GUIDE.MD) — GLSL shader authoring guide
