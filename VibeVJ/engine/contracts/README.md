# Contracts

What the engine calls on a generator module, written down as classes (#202, `../../REWRITE_PLAN.md`, approach B).
The files are in strict mode (`#strict`).

| File | What it is |
|---|---|
| `generator_module.shio` | `GeneratorModule`, the contract of a generator module, and the mixins `VideoIO`, `Transitionable`, `ItemStack` |
| `legacy_module.shio` | `LegacyModule`: an asset with the old entry points behind the same methods |
| `contract.shio` | `contract_missing()` / `contract_error()`: checks an object by the names of its methods |

## Why the check is by names

Every asset is its own `std.module()` program. An asset that `#include`s `generator_module.shio` gets its **own copy**
of `GeneratorModule`:

- `std.instanceof(obj, GeneratorModule)` with the engine's class object is false for it.
- `std.instanceof(obj, "GeneratorModule")` by name is true.

So the engine checks what it calls, by name, once when the asset is loaded (`contract_error`). A missing method is
then an error in the log at load time, not a failure deep in a frame. `_testing/module_class_contract.shio` pins this
behaviour of the language.

## GeneratorModule

| Method | Required | Default | Called |
|---|---|---|---|
| `build(generator, node)` | **yes** (`abstract`) | — | once, after the engine set `generator` and `node` |
| `save_state()` / `load_state(state)` | no | `None` / nothing | the module's own data, `state.data` of the generator |
| `save_view()` / `load_view(view)` | no | `None` / nothing | view only data (zoom, pan), `state.view` |
| `active(on)` | no | nothing | the power button (ACT); only while it is on |
| `on_free()` | no | nothing | before the module goes |
| `hooks()` | no | `[]` | which of `update` / `update_pre` / `update_post` run every frame |
| `update(tl_pos, delta)`, `update_pre(tl_pos, delta)`, `update_post()` | no | nothing | every frame, if named in `hooks()` |
| `dispatch(cmd, value)` | no | see below | `generator.dispatch()` |

The engine still sends some commands as strings (`generator.dispatch(cmd, value)`); phase 3 of the plan turns them
into calls. Until then, the default `dispatch()` sends `"active"` to `active()`, and every command of
`GENERATOR_COMMANDS` to the method of the same name, when the module has one:

| Mixin | Methods |
|---|---|
| `VideoIO` | `get_default_input()`, `get_default_output()`, `get_inputs()`, `set_input(v)`, `set_uniform(v)`, `set_render_callback(v)` |
| `Transitionable` | `transition(v)`, `clip_preview(v)` |
| `ItemStack` | `get_items()`, `get_item(i)`, `add_item(path)`, `on_items_changed(cb)` |

A class asset:

```
#include "engine/contracts/generator_module"

class Fx : GeneratorModule, VideoIO
{
	output = None;
	build(generator, node) { output = node.controlslider("Out", "fx"); }
	get_default_output() { return output; }
	hooks() { return ["update"]; }
	update(tl_pos, delta) { ... }
}

create(generator, node) { return Fx(); }
```

## LegacyModule

The old way stays: an asset or extension module with any of `save_state`, `load_state`, `save_view`, `load_view`,
`dispatcher(generator, cmd, value)` and `on_free` as functions. `LegacyModule` gives them the methods of
`GeneratorModule`. It is the one place where the engine asks a module which functions it has. `entry()` and
`update` / `update_pre` / `update_post` are still run by the extension loaders (`engine/generators/extensions/`).

Tests: `_testing/vibevj_contracts.shio` (no GUI).
