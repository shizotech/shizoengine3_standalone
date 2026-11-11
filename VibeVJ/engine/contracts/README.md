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
| `Transitionable` | `transition(v)`, `clip_preview(v)`, `has_cell_preview()` / `draw_cell(size)` (a module without a picture draws its clip cell, #677) |
| `ItemStack` | `get_items()`, `get_item(i)`, `add_item(path)`, `on_items_changed(cb)` |
| `TimelineClip` | `clip_start(v)`, `clip_position(v)`, `clip_stop(v)`: the generator is a clip on the timeline (#680) |

### Clips on the timeline (#680)

A generator dropped onto a lane of the timeline is a clip there (`src/menu/timeline/timeline_clips.shio`). It is in a
stack like a clip of the Clipview (`engine/assets/shaderstack.asset`), which passes every command to its entries.

| Command | When | Before / after |
|---|---|---|
| `clip_start` | the cursor enters the clip (playing, a jump, the loop, a clip moved under the cursor) | after `"active"` true |
| `clip_position` | every frame while the cursor is inside the clip, also while the timeline stands | |
| `clip_stop` | the cursor leaves the clip, or the clip is deleted | before `"active"` false |

The value is `[pos, beat, seconds, length, length_seconds, lane, start]`: `pos` 0..1 through the clip, `beat` the
beats since its start, `seconds` the same in seconds at the tempo now, `length` the length in beats. A module that
does nothing with them needs nothing: the clip is switched on and off with `"active"` anyway. An old dispatcher
(`dispatcher(generator, cmd, value)`) gets them like any command. What the engine does with them itself: a shader gets
the uniforms `CLIP_POS` and `CLIP_TIME` when it declares them (`extensions/glsl/shader_loader.shio`), a video starts at
its In point, as far into it as the cursor is in the clip (`extensions/video/video_module.shio`).

The timeline also asks the entries of a new clip `clip_length` (value None, #680 step 3): an entry that answers a
number of seconds sets the length of the clip (in beats at the tempo now). The video module answers the seconds from
its In to its Out point at its Speed, None while the video is not open (the timeline asks again for 10 s). Only for a
video file dropped (or added over MCP without `length`) onto the main timeline.

Two clips that overlap on a lane both get their commands (both are active); the lane crossfades them over the overlap.

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
