
# Asset Format Documentation

This documentation covers the generator asset format used in the engine, based on shizoscript.
Working with shizoscript files `.shio` requires the shizoscript and shizoscript nanogui skill.
Generators are specific shizoscript classes defined in the engine core code ( "engine/generators" ) tied to this program.
There are generator entry loaders for different file extensions within "engine/generators/extensions" you can find relevant source code there only when necessary.

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
└── src/
    ├── __init__.shio      # Entry point (MANDATORY)
    ├── A.shio             # Optional: additional script file
    ├── B.shio             # Optional: additional script file
    └── subdirectory/      # Optional: subdirectories to keep things clean
        └── helper.shio
```

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

# Testing and verification

Always use available shizoscript syntax and error check tools to verify each shizoscript file for correctness!
Do NOT ship non-compiling assets!

## Gotchas & Failures

Technically, each script file that you test with the builtin shizoscript debugging tools needs to import the corresponding modules.
Inside the program itself this is not done for every single file as 'import nanogui;' already happened in the main entry script.
But when you test individual single script files, you might need to add 'import nanogui' etc to it to compile correctly.
Having this extra text in a script file is generally not a problem as modules only get imported once anyways.

If script files include other script files, it is enough to just check the main script file. You do not have to check each included file individually, but still make sure each individual entry file is checked.