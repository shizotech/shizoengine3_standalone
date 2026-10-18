# Generator Extension Loaders (`engine/generators/extensions/`)

This directory holds the **per-extension "loaders"** that give each generator
its actual behavior. `generatoritem.shio` auto-detects the asset's file
extension, then loads `engine/generators/extensions/<ext>/__init__.shio`
and calls its `load_extension(generator)` entry point.

```
engine/generators/extensions/
├── asset/
│   └── __init__.shio            # Loader for .asset directories (src/__init__.shio entry point)
├── ffgl/
│   ├── __init__.shio            # Loader for FFGL plugins (.dll, .bundle, .so), #428
│   ├── ffgl_loader.shio         # shader_loader + the nanogui ffgl host, parameters as controls
│   └── passthrough.glsl         # the shader generator around the plugin reads it from here
├── glsl/
│   ├── __init__.shio            # Loader for .glsl directories (src/__init__.glsl entry point)
│   └── shader_loader.shio
├── png/
│   ├── __init__.shio            # Loader for .png image generators
│   └── image_module.shio
├── txt/
│   ├── __init__.shio            # Loader for .txt text generators
│   └── text_module.shio
└── video/
    ├── __init__.shio            # Loader for video files (.mp4, .mov, .mkv, ...)
    └── video_module.shio        # nanogui.video player + transport controls
```

## Loader Contract

Every loader subfolder contains an `__init__.shio` that **must** export:

- `load_extension(generator)`. It must:
  - load the module of the asset into `generator.module` (a `std.module()`);
  - build the generator's controls into `generator.node`;
  - register any `update` / `update_pre` / `update_post` callbacks;
  - set `generator._was_loaded = true`.

  On a failure it returns false (or leaves a `call_error()`). The generator then frees its window and
  `generator.is_loaded()` is false (#202).

The loader itself exports nothing else. What the engine calls later is looked up on **`generator.module`** (the asset
or the module the loader made, e.g. `shader_loader.shio`), not on the loader. It goes through `generator.impl`, an
object of the contract `GeneratorModule` (`engine/contracts/`, #202):

- A **class asset** exports `create(generator, node)`. The `asset` loader sets `generator.impl` to what it returns.
  The generator then:
  - checks it against the contract by the names of its methods;
  - calls `build(generator, node)`;
  - runs the hooks `hooks()` names.
- **Every other module** is wrapped in a `LegacyModule`. Its functions, each one optional, keep working as before:
  - `save_state()` / `load_state(state.data)`: the generator's own data;
  - `save_view()` / `load_view(state.view)`: view-only data;
  - `dispatcher(generator, cmd, value)`: what the ACT button and other dispatches route through;
  - `on_free()`: called before the module goes.

See `engine/contracts/README.md`.

## How Extension Detection Works

`generatoritem.shio` inspects the asset path:

1. If the path has an explicit file extension (`.png`, `.txt`, `.glsl`,
   `.preset`, ...) it uses that. Video containers (`.mp4`, `.mov`, `.m4v`,
   `.mkv`, `.webm`, `.avi`, `.mxf`, `.mpg`, `.mpeg`, `.ts`, `.wmv`) all map to
   the `video` loader (see `docs/video.md` in the repository root).
2. Otherwise (a bare directory), it checks for `path/src/__init__.shio`
   (→ `asset`) or `path/src/__init__.glsl` (→ `glsl`).
3. It then loads `engine/generators/extensions/<ext>/__init__.shio` into a
   `std.module()` and calls `load_extension(this)`.

## Adding a New Extension

To support a brand-new asset extension (e.g. `.myext`):

1. Create `engine/generators/extensions/myext/__init__.shio` exporting
   `load_extension(generator)`, which loads the module of the asset into
   `generator.module` (with the optional functions above, or a class asset's
   `create()`).
2. Update the extension-detection logic in `engine/generators/generatoritem.shio`
   so the new extension is recognised. This touches engine code — treat with
   care (see DO NOT CHANGE callouts in `engine/README.md`).

## Navigation / Quick Links

- [`../../../AGENT_README.md`](../../../AGENT_README.md) — Primary AI-agent onboarding (core principle + directory map)
- [`../README.md`](../README.md) — Generator views + universal wrapper
- [`../../../assets/README.md`](../../../assets/README.md) — User-facing generator assets
- [`../../../assets/ASSET_GUIDE.MD`](../../../assets/ASSET_GUIDE.MD) — How to create/author generator assets
- [`../../../assets/Shaders/SHADER_GUIDE.MD`](../../../assets/Shaders/SHADER_GUIDE.MD) — GLSL shader authoring guide
