
# Asset Format Documentation

This documentation covers the generator asset format used in the engine, based on shizoscript.
Working with shizoscript files `.shio` requires the shizoscript and shizoscript nanogui skill.
Generators are specific shizoscript classes defined in the engine core code ( "engine/generators" ) tied to this program.
There are generator entry loaders for different file extensions within "engine/generators/extensions" you can find relevant source code there only when necessary.

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