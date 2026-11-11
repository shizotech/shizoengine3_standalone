
# Asset Format Documentation

This documentation covers the generator asset format used in the engine, based on shizoscript.
Working with shizoscript files `.shio` requires the shizoscript and shizoscript nanogui skill.
Generators are specific shizoscript classes defined in the engine core code ( "engine/generators" ) tied to this program.
There are generator entry loaders for different file extensions within "engine/generators/extensions" you can find relevant source code there only when necessary.

## Where the shizoscript documentation lives (no source repo needed)

shizoscript is a **custom language** (ShizoScript 3) — the app you are writing an asset for *is* its
interpreter, and it prints its own reference. Run it in the app folder (`_shizoengine3/` in a checkout,
the folder of `VibeVJ.exe` in a released build; `shz` on an installed system):

```
shz docs                    every namespace, object type, function, its parameters, its description,
                            examples - and every module in shizotech/packages (nanogui, json, bitmap, …)
shz docs nanogui            the same searched by keyword (a plain word, "nanogui.widget" finds nothing)
shz mcpdocs                 the reference as an MCP server on http://localhost:13338:
                            shizoscript_help, shizoscript_docs, shizoscript_search_keywords,
                            shizoscript_syntax_checker, shizoscript_debugger
shz --check assets/.../src/__init__.shio   check an asset script without running it
shz -p "std.print(math.abs(-2));"       run one line of shizoscript to try something
```

The language guide written for AI agents is a file, not a website:
`shizotech/system/miniagent/skills/shizoscript/SKILL.md`, with the deep dives
(`nanogui.md`, `kernels.md`, `shizonet.md`, `video.md`) next to it in `docs/`.
A command name is looked up in the current folder first, so `shz docs` reaches
`shizotech/system/docs/__init__.shio` unless a folder of that name shadows it — then run
`shz shizotech/system/docs`. Full resolution rules and the measurements:
[`../AGENTS.MD`](../AGENTS.MD), section *ShizoScript 3*.

## Design Your Own UI (View Composition)

- A core concept of this program: users **design their own UI** by dragging a view (e.g. a `clipview` or `generatorview`) and dropping it inside another view to build individual, reusable UI setups.
- Views are the composable UI building blocks: `generatorview`, `clipview`, `clipstackview`, `singleview` (defined in `engine/generators/*.shio`).
- The engine wires up `on_dragdrop` / `on_dragdrop_hover` handlers on each of these view containers, so views can be nested and composed freely.
- See also `engine/generators/README.md` and `assets/Views/README.md` for the view containers and their drag/drop handlers.

---

## 1. Directory Structure

Assets are organized as directories with the `.asset` extension.

Organize new assets in logical subdirectories to keep it clean.

### Basic Structure

```
MyAsset.asset/
├── asset.json             # The id of the asset, made by the engine (do not copy it by hand, see below)
└── src/
    ├── __init__.shio      # Entry point (MANDATORY)
    ├── A.shio             # Optional: additional script file
    ├── B.shio             # Optional: additional script file
    └── subdirectory/      # Optional: subdirectories to keep things clean
        └── helper.shio
```

The entry file picks the loader (`engine/generators/extensions/`): `src/__init__.shio` a script asset (this guide),
`src/__init__.glsl` a shader (`Shaders/SHADER_GUIDE.MD`), `src/__init__.native` a native asset (below).

### Native assets: an algorithm in C (#201)

A native asset is a generator whose code is a C ABI plugin (plain C, or C++ / Rust / Zig through the C interface)
instead of a script: an algorithm on the CPU that the engine shows like a shader. Example and walkthrough:
`assets/Generators/Native/Life.asset` and the section *A native VibeVJ asset* of
`core/shizoscript3_core_cabi/README.md` (in the source repository); one that processes a picture (an input and a text
control, C ABI 1.3): `assets/Generators/Native/Dither.asset`.

```
MyAlgo.asset/
├── asset.json
├── src/
│   └── __init__.native     # {"asset": "my_algo.algo", "package": "plugin"}: the type the plugin registers, its folder
└── plugin/                 # the C ABI plugin as a package: package.shz, the sources, CMakeLists.txt
    └── native/<platform>/shzmodule_my_algo.<so|dylib|dll>   # built for each system (linux_x64, macos_arm64, windows_x64)
```

- The plugin includes only `shz_abi.h` and registers its asset with `reg->add_asset()` (C ABI 1.2): controls of the
  kinds a shader annotation has (slider, int, float, button, pushbutton, enum, vec2..4, ivec2..4, slidervec2..4, rgb,
  rgba; 1.3: text), value outputs, a picture (RGBA8 or RGBA32F, made on the CPU), 1.3: picture inputs (the engine reads
  the linked picture back from the GPU at the size the input asks for) and the callbacks create / update / render /
  control_changed / save / load / destroy.
- Rebuilt while VibeVJ runs, the plugin is loaded again (the section *Plugin* of its window: *Reload plugin*, *Watch the
  library*; `std.native_reload` in a script): *Reloading a plugin while it runs* of the README of the C ABI.
- The engine builds the window of a shader around it (`engine/generators/extensions/native/`): the controls in the
  section *Controls* of the *Control* tab (the same builder as for shader uniforms), the value outputs in *Values*, the
  picture as the input of a passthrough shader, so *Out*, render size, Spout, NDI and the displays work.
- Without a library for the system in `plugin/native/`, the package named like the namespace of the type is imported
  (`shizotech/packages/my_algo`): that is how the builds of this repository ship the plugins of its own assets.
- Check it without the app: `_testing/native_asset.shio` shows how (the loader's `native_asset_open()` gives the object
  and what it declares; `set`, `update`, `render`, `serialize` on it).

### asset.json: the id of an asset

A project saves each generator with the `path` of its asset and, next to it, its `asset_id`. When the folder was moved
or renamed, the project finds it again by that id (`engine/generators/asset_resolver.shio`, #202).

- `asset.json` is `{"id": "...", "home": "assets/..."}`: a random id and the path of the folder when the id was made.
  The engine writes it the first time a project (or preset) with an asset under `assets/` that has none is saved. The
  asset browser does not list it.
- Move or rename an asset folder freely: the engine finds it by its id and sets `home` to the new place.
- A copied folder has the id of its original at first. The engine sees that (two folders, one id) and gives the copy an
  id of its own; the one at `home` stays the original.
- The assets of this repository have their `asset.json` committed, so every install has the same ids. A new asset
  folder in the repository: commit its `asset.json` too. `_testing/asset_ids.shio` checks this;
  `cd _shizoengine3 && shz ../_testing/asset_ids.shio --stamp` makes the missing ones.
- Single files (`.png`, `.txt`, videos, FFGL plugins) have no `asset.json`: they are found again by size and content.

### Source file structure

A generator's `src/__init__.shio` is the entry point. The engine calls a fixed set of **lifecycle functions** defined at the top level of this file. Only `entry` is mandatory; the rest are optional hooks that the engine invokes when present.

#### entry — MANDATORY

```
entry(generator, area) {
    // Builds the generator UI into 'area' (a nanogui parent widget).
    area.layout(nanogui.layout_vertical());
    freq = area.controlslider("Frequency").value(0.25);
}
```

`entry(generator, area)` — MANDATORY. Present in every generator (Math, Network, Audio, Utility). It takes the `generator` handle and `area` (a nanogui parent widget) and builds all UI controls, and sets up any shaders or IPC handles the generator needs.

#### update — OPTIONAL

```
update(generator, tl_pos, pos_delta) {
    // Compute the generator's output from the current timeline position.
    ...
    out.value(v);
}
```

`update(generator, tl_pos, pos_delta)` — OPTIONAL. Computes the generator's output each frame from the timeline position `tl_pos` and frame delta `pos_delta`. Used by the Math generators (SineGenerator, TriangleWave) to drive their output control.

#### dispatcher — OPTIONAL

```
dispatcher(generator, cmd, value) {
    // React to engine commands.
    ...
}
```

`dispatcher(generator, cmd, value)` — OPTIONAL. Called by the engine to react to commands. Used by the Network generators (artnet_receiver, artnet_sender, spout_receiver) and the AudioInputAnalysis generator.

**Clips on the timeline (#680).** Any generator can be dropped onto a lane of the timeline. It is then active only while
the playhead is inside the clip (`"active"` true / false as from its power button) and gets three commands:

| `cmd` | When |
|---|---|
| `"clip_start"` | the playhead enters the clip (playing, a jump, the loop), after `"active"` true |
| `"clip_position"` | every frame while the playhead is inside, also while the timeline stands |
| `"clip_stop"` | the playhead leaves the clip, or the clip is deleted; before `"active"` false |
| `"clip_length"` | a video file became a clip (#680 step 3): answer the seconds it should last, or None (the video module answers In to Out at its Speed) |

`value` is `[pos, beat, seconds, length, length_seconds, lane, start]`: `pos` from 0 to 1 through the clip, `beat` the
beats since its start, `seconds` the same in seconds at the tempo now, `length` its length in beats, `start` where it
starts on the timeline. A generator that ignores them still works as a clip. A class asset gets them as the methods
`clip_start(v)`, `clip_position(v)`, `clip_stop(v)` (mixin `TimelineClip`, `engine/contracts/README.md`). Example: a
generator that runs one sweep over the length of the clip:

```
dispatcher(generator, cmd, value) {
    if(cmd == "clip_position")
        out_ctrl.value(value.pos);
}
```

Shaders get the uniforms `CLIP_POS` and `CLIP_TIME` instead (`Shaders/SHADER_GUIDE.MD`); a video starts at its In point
when its clip starts.

#### save_state / load_state — OPTIONAL

```
save_state() {
    // Return a JSON object of the generator's serializable state.
    return state;
}

load_state(state) {
    // Restore the generator's state from the JSON returned by save_state().
    ...
}
```

`save_state()` returns a JSON object capturing the generator's serializable state (artnet_receiver ~line 144; also spout_receiver, textbox, ColorSelector). `load_state(state)` restores it (artnet_receiver ~line 158). Both are OPTIONAL.

#### Undo steps of your own editor

Values of controls and links are steps of the undo history by themselves. An asset with an editor of its own (shapes,
points, a list) makes its edits steps with `generator.engine.env.edit_step(name, undo_fn, redo_fn, key)`: `undo_fn` and
`redo_fn` put the state before / after back; a step with the same non-empty `key` less than a second after the last
one extends it (a drag). Nothing is recorded while a step is undone or a project loads. The functions can run after
the generator was deleted: catch the errors there. Example: `record()` in `assets/Mapping/MaskDraw.asset` (#586).

#### update_pre / update_post — OPTIONAL

```
generator.pre_callback([captured_vars](generator, tl_pos, pos_delta) {
    // Runs before the engine frame; e.g. pushes settings over IPC.
    ...
});
```

`update_pre` / `update_post` — OPTIONAL. Per-frame hooks that run before/after the engine's main update. They can also be wired directly through the `generator` handle:

- `generator.pre_callback([...captures](generator, tl_pos, pos_delta){ ... })` — runs before the frame (see AudioInputAnalysis `__init__.shio`, line 261).
- `generator.post_callback([...captures](generator, tl_pos, pos_delta){ ... })` — runs after the frame.

## Input/Output Handling

A generator exposes its inputs and outputs through `area.control` widgets (a `nanogui.midicontrolio`) or, for plain numbers, through the primitive controls `controlfloat`, `controlint` and `controlslider`. There are two output strategies:

1. **Rich values** (arbitrary classes, types, primitives, etc.) go through a `nanogui.control` widget, which is a `nanogui.midicontrolio`. Technically ANY kind of generator value can be sent through it — the GLSL `shader_loader` (`engine/generators/extensions/glsl/shader_loader.shio`) just happens to send the shader object, but the same mechanism works for any class/type/primitive.
2. **Primitive values** (a plain number) use the primitive controls `controlfloat`, `controlint` and `controlslider`, which are already used by several existing assets (SineGenerator, TriangleWave, PhaserGroup, AudioInputAnalysis).

### Output — rich values (nanogui.control / midicontrolio)

Modeled on `shader_loader.shio` (lines ~839-847). Create the output control, set its value, wire a callback that resets the value, and register the default output so the engine can query it via `get_default_output` (the shader_loader `dispatcher`, lines ~53-54):

```
out = io_panel.control("OUT", "output_ctrls");
out.anchor_right(0).anchor_top(0).anchor_bottom(0).fixed_width(70);
out.value(shaders[0].shader);
out.callback([out](v){
    //Reset value back to shader...
    out.value(shaders[0].shader);
});

default_output = out;
```

The `dispatcher` then exposes it to the engine:

```
if(cmd == "get_default_output")
    return default_output;
```

### Input — rich values (nanogui.control aka nanogui.midicontrolio)

Modeled on `shader_loader.shio` (lines ~663-690 in `parse_inputs`). Create an input control, wire `callback` to forward the incoming value to the target(s), and `on_unlink` to reset the value to `None` when the link is removed. A `default_input` is auto-detected by lowercased name ("in" / "input" / "ichannel0") (lines ~688-689):

```
in_ctrl = in_panel.control(input_name, "input_ctrls");
in_ctrl.anchor_left((*total_inputs) * 100).anchor_top(0).anchor_bottom(0).fixed_width(100);

in_ctrl.on_unlink([in_ctrl, input_name, input_entry](ctrl1, ctrl2){
    if(ctrl2 == in_ctrl) {
        for(sid = 0; sid < input_entry.size(); sid++)
            input_entry[sid].input(input_name, None);
    }
});
in_ctrl.callback([input_name, input_entry](v){
    for(sid = 0; sid < input_entry.size(); sid++)
        input_entry[sid].input(input_name, v);
});

lc = input_name.lowercase();
if(!default_input && (lc == "input" || lc == "ichannel0"))
    default_input = in_ctrl;
```

The engine can also push an input directly through the `dispatcher` `set_input` command (shader_loader, lines ~77-84): it looks up `inputs[value.name]` and forwards `value.value` to all registered targets.

```
if(cmd == "set_input") {
    if(!inputs.has(value.name))
        return false;
    ins = inputs[value.name];
    for(i = 0; i < ins.size(); i++)
        ins[i].input(value.name, value.value);
    return true;
}
```

### Inspecting incoming values

When handling specific generator inputs (or when overriding a `nanogui.midicontrolio` `on_link` callback), use `std.type` / `std.is_type` to inspect what kind of variable is coming in (class, type, primitive, etc.) so the input can be dispatched to the right handler.

### Output — primitive values (controlfloat / controlint / controlslider)

For a plain-number output, create the primitive control in `entry` and drive it in `update`. Modeled on SineGenerator (`assets/Generators/Math/SineGenerator.asset/src/__init__.shio`, line 20 in `entry` and line 47 in `update`):

```
entry(generator, area) {
    area.layout(nanogui.layout_vertical());
    freq = area.controlslider("Frequency").value(0.25);

    out = area.controlslider("Output");
}

update(generator, tl_pos, pos_delta) {
    v = math.sin(tl_pos * 2.0 * math.PI * freq.value());
    v = 0.5 + v / 2.0;
    out.value(v);
}
```

`controlfloat` and `controlint` are used for floating and integer values respectively — see `PhaserGroup` (controlfloat "Phase Delay", controlint "Start device" / "End device" / "Priority") and `AudioInputAnalysis` (controlfloat "BPM", controlslider "BEAT" / "LOW ENERGY").

# Nanogui UI and widget notes

- UI elements are created directly from parent widgets, you have to keep that in mind when looking up documentation for certain UI widgets.

For example, you might see something like:

parent.button(); --> Look up "nanogui.button" to find this widget instead of "parent.button".

- The entire codebase makes heavy use of chained function calls for widget settings.

For example:

parent.button().fixed_width(200).fixed_height(200); <-- all affect 'button'

- Some widget elements have a dedicated "content" widget, which sometimes needs to be addressed instead of the actual widget.

For example

vscroll().layout(...) <-- wrong, as vscroll has a content widget
vscroll().content().layout(...) <-- Now it actually affects the content area that you most likely meant

Still, to address these widgets parameters which are related to its parent, use the widget directly:

vscroll().fixed_width() <-- setting the content widget doesnt make sense in this case.

## Widget Layouts

This module (`shzmodule_nanogui`) exposes `nanogui.*` script classes. Everything below is actual engine behavior; use it to build UIs that survive resizing of node windows and the screen.

### The two placement systems

There are exactly two ways widgets are placed, and you must understand which one owns a widget:

1. **Anchors** — edge constraints relative to the parent widget. This is the *flexible* system. Anchored widgets are recomputed on every layout pass, so they follow the parent when a node window is resized or maximized. **Prefer anchors for any UI that must resize.**
2. **Layout objects** (`nanogui.layout_vertical` / `nanogui.layout_horizontal`) — simple stacking lists attached to a container. They are rigid: a vertical layout stacks children top-to-bottom and a horizontal layout stacks left-to-right. They are fine for small stacks inside an anchored panel, but they are *not* a general layout solution (see limits below).

A container with **no layout object** keeps children where you manually put them (`position`, `x`, `y`); manual positions survive layout passes. Anchors always win: if a widget has anchors, they are re-applied *after* the parent's layout result, overriding layout-computed position/size for the anchored edges.

### Anchors (the important part)

Every widget has four anchors relative to its parent's rectangle. Script API on `nanogui.widget`:

- `anchor(value, mode)` — sets left, right, top AND bottom anchors to the same value (mode: `"pixels"` default, `"percent"`, `"none"`).
- `anchor_left(v, mode)`, `anchor_right(v, mode)`, `anchor_top(v, mode)`, `anchor_bottom(v, mode)` — get (no args) / set one edge.
- `clear_anchor_left()`, `clear_anchor_right()`, `clear_anchor_top()`, `clear_anchor_bottom()`, `clear_anchors()` — remove anchors.
- Mode `"percent"` means the value is a **fraction of the parent size** (`0.0`..`1.0`), left/right against parent width, top/bottom against parent height. `"pixels"` means an offset in pixels. `"none"` disables that edge.

Anchor values are **offsets from the respective edge**, never coordinates. The engine computes (per axis, parent size P):

| Anchors set | Result |
|---|---|
| left only | `pos = left` (size unchanged) |
| right only | `pos = P - right - size` (fixed distance from right edge) |
| left + right | `pos = left`, `size = P - left - right` → **widget stretches horizontally** |
| top only | `pos_y = top` |
| bottom only | `pos_y = P_h - bottom - size_y` |
| top + bottom | `pos_y = top`, `size_y = P_h - top - bottom` → **widget stretches vertically** |

Recipes:

```
panel = w.widget().anchor(0)                      // fill the whole parent
header = w.widget().anchor_top(0).fixed_height(28) // pinned top strip, auto height follows resize
footer = w.widget().anchor_bottom(0).fixed_height(24)
body  = w.widget().anchor_top(28).anchor_bottom(24) // fills between header and footer
right = w.widget().anchor_left(0.5, "percent").anchor_right(0).anchor_top(0).anchor_bottom(0) // right half
center = w.widget().anchor_left(0.25, "percent").anchor_right(0.25, "percent").anchor_top(0).anchor_bottom(0) // middle 50%
```

Anchors are applied by the **parent** during layout passes; they re-fire whenever the parent is resized. That is exactly why anchored UIs track node-window resizing while manually positioned widgets do not. Setting or clearing an anchor automatically marks the parent layout dirty.

### Layout objects and their limits

```
container.layout("vertical")                      // quick string form
container.layout(nanogui.layout_vertical().spacing(6).padding(vec4f(4,4,4,4)))
container.layout(None)                            // remove layout
```

- `spacing(value)` — gap between children (get/set). `padding(value)` — inner padding `[left, top, right, bottom]`; **requires a vec4f object, not a plain list**.
- Only `"vertical"` and `"horizontal"` exist. There is **no grid, no alignment options, no per-child sizing options.**

Vertical layout rules (per pass):
- Only *visible* children participate; `visible(False)` removes a child from the stack.
- Every child gets the **full content width** of the container. `fixed_width` is *ignored* for width in vertical layout — children always stretch across. (Fixed width only matters for the container's own preferred size.)
- Child height: `fixed_height` if set, otherwise the widget's preferred height; a child whose preferred height exceeds the available content height becomes a *flex* child and shares the remaining space equally with the other flex children (so oversized content shrinks to fit instead of overflowing).
- Horizontal layout mirrors this: children stack left-to-right, widths come from `fixed_width`/preferred width (they can overflow, no shrink), and **every child is stretched to the full content height**; `fixed_height` is ignored there.
- Layouts iterate to a fixpoint with oscillation detection; do not fight the layout from `on_layout` callbacks by setting values that change preferred size back and forth.

Because of these limits: **use layouts only inside an anchored region** (e.g. a vertical stack of controls inside a fixed sidebar panel). For anything that must resize, split, center, pin to edges, or share space proportionally — use anchors.

### Manual placement in a layout-less parent

- `position([x,y])` / `x(v)` / `y(v)` move a child inside its parent (top-left origin, parent-local).
- `width(v)` / `height(v)` / `size([w,h])` set the live size, but it is volatile: on the next layout pass the parent re-sizes the child to its preferred size (or fixed size) — in a layout-owning parent according to the layout rules, and even in a layout-less parent the child's size is reset to `preferred/fixed` (only its `position` survives there). To pin a size against layout passes use `fixed_width` / `fixed_height` / `fixed_size([w,h])`; pass `-1` to clear a fixed dimension (it means "auto").
- `refresh_layout()` on the parent forces a re-layout after programmatic changes (evaluation is lazy and runs at render time; there is no need to redraw or loop).
- `on_layout(fn)` fires on a container after its layout pass — useful for post-layout tweaks. `attr` on any widget stores arbitrary script data.

### Scrollable regions — vscroll / hscroll / scrollarea

For any content area that can exceed its space, wrap it in a scroll widget instead of overflowing:

- `w.vscroll()` → vertical scroll panel, auto scrollbar on the right when content overflows. Script API: `scroll(f)` normalized 0..1, `scroll_step(f)`, `scrollbar_width(f)`, `content()` returns the inner content panel. Widgets added to the vscroll land in its content panel. Give the content panel a vertical layout and add items to it; the vscroll tracks the content height and scrolls automatically.
- `w.hscroll()` → horizontal equivalent, bar at the bottom: `scroll(f)`, `scroll_step(f)`, `scrollbar_height(f)`, `content()`.
- `w.scrollarea()` → pan/zoom viewport (no scrollbars): `scale(f)`, `min_scale`/`max_scale`, `pan([x,y])`, `zoom_on_scroll(bool)`, `zoom_step(f)`, `fit_mode(bool)` keeps the content fitted to the parent window, `fit_content()` zoom+pans to fit, `lock_controls(bool)` disables user pan/zoom. Make content bigger than the viewport by setting `fixed_size` on `scrollarea().content()`.

Typical scrollable list inside a resizable window (fully responsive):

```
list = w.vscroll().anchor(0)
list.content().layout("vertical").spacing(4)
for i in range(100):
    item = list.widget()                 // added into the vscroll content panel
        .layout("horizontal").spacing(4)
        .fixed_height(24)
    item.button("Item " + str(i))
```

### Resizable node windows

`nanogui.window` is the floating panel primitive (`parent.window("Title")`):

- Widgets added to a window are routed into its **content panel** automatically — anchors inside the window are relative to that content panel, which the engine keeps sized below the header with `margin` insets as the window is resized. `content()` gives direct access to the panel, `button_panel()` the header button area.
- Resizing: `resizable(True)` enables all edges, or per edge `resizable_left/right/top/bottom(bool)`; `movable(True)` enables header drag, `movable_x/movable_y`, `clamp_move(bool)` restricts dragging to the parent area.
- Callbacks: `on_resize(fn(new_size, old_size))`, `on_move(fn(new_pos, old_pos))`, `on_move_finished(fn())`.
- `margin(f)` is the inner margin around the content panel (default 8). `header_height()` reports the effective header height (`0` if `header_enabled(False)` or no title/buttons).
- A window's own preferred size follows its content, so an anchored layout inside the content panel drives the window size; `size([w,h])` / `fixed_size([w,h])` pin the initial size (the user resize updates it; min width 60, min height header+10, and the window is clamped inside its parent).

**Rule for node UIs: never place window contents with absolute pixels. Anchor everything inside the window content panel (percent + pixel combinations) and use vscroll/hscroll for areas with unbounded content.** Then dragging edges to resize the node just works.

### Common gotchas

1. Anchors override layouts. A child inside a vertical layout that also has anchors gets the anchor result, not the stack position.
2. Vertical layouts stretch width and horizontal layouts stretch height — that is the only "resize" they provide. They do not resize with the parent unless the *container itself* is anchored.
3. Percent anchor values are fractions (`0.25`), not `25`.
4. `right`/`bottom` anchor values are distances from that edge, not positions.
5. `width()`/`height()` changes are overwritten by layout passes; use `fixed_*` to pin sizes, `-1` clears them.
6. Hidden widgets (`visible(False)`) take no layout space.
7. Layouts run lazily at render time; call `refresh_layout()` on the affected parent after changing anchors/fixed sizes programmatically.
8. `padding()` on layout objects takes a vec4f; lists are not accepted there (most other vec2/vec3/vec4 params accept both).

# Testing and verification

Always use available shizoscript syntax and error check tools to verify each shizoscript file for correctness!
Do NOT ship non-compiling assets!

## Gotchas & Failures

Technically, each script file that you test with the builtin shizoscript debugging tools needs to import the corresponding modules.
Inside the program itself this is not done for every single file as 'import nanogui;' already happened in the main entry script.
But when you test individual single script files, you might need to add 'import nanogui' etc to it to compile correctly.
Having this extra text in a script file is generally not a problem as modules only get imported once anyways.

If script files include other script files, it is enough to just check the main script file. You do not have to check each included file individually, but still make sure each individual entry file is checked.

# Examples

Check out `assets/Generators/ExampleBasics` to get a grip of the general structure for an asset (ground of truth)

A generator can also be written as a class: `assets/Generators/ExampleBasics/class_module.asset` derives from
`GeneratorModule` (`engine/contracts/generator_module.shio`) and exports `create(generator, node)` instead of `entry`.
The engine checks it against the contract when it loads, so a missing method is an error in the log at once, not in a
frame. See `engine/contracts/README.md` (#202).