
# VibeVJ Live

You can interact with the live VibeVJ program by using the 'vibevj_*' tools.

First, determine the target by utilizing 'vibevj_get_focus' to get the currently focused item.

Then use vibevj_query() to interact with the generator (get & set)

If no generator is focused currently, hint the user to click on an item to make it visible to you.

The whole program is build around dynamically placeable UI containers ("Views") which hold different kinds of generator assets.
You can find both views and all asset types under "assets/".

When adding shaders or any generator:

ALWAYS use the ASSET_ROOT as only valid path to add new generators.
NEVER try to instantiate assets or shaders from raw `.glsl` or `.shio` files directly.

The ASSET_ROOT is basically the MyAsset.extension directory.

# vibevj_query()

vibevj_query() takes two arguments:

- name
The name of the action to execute on the generator (you need to choose a valid action as returned by 'vibevj_get_focus'.

- args
The JSON arguments for the query
Arguments are provided for each action returned by 'vibevj_get_focus'.
This should be a ***VALID JSON*** object, ***NOT*** a string!

# live_path

A 'live_path' is NOT a real filesystem path!
Instead, 'live_path' can be used to focus on active generator instances currently within the running instance of the vibevj software.

# each turn

Each new user message resets the current focus path and sets it to the last user focused generator again.

# asset generator controls

The '@' in a controls name is their respective group.

For example

uniforms@x
uniforms@y
uniforms@size

All belong to the same group.

---

Controls which have a '#' in their name are attribute controls.
Attribute controls means that they belong to a parent control (the one with the same prefix but without '#')

For example:

node/control_1 <--- PARENT CONTROL
node/control_1#Min <--- Attribute control
node/control_1#Max <--- Attribute control
node/control_1#Trigger <--- Attribute control

Change attribute controls only when you want to change the attributes of their respective parent control.
Attribute controls do not belong to the generator directly, only their parent control.
You can get and set attribute controls just like any other regular control.
In a saved state (`node.serialize_json()`: presets, `generators.json`, `controls.json`) the attribute controls are
under `attributes`, and since #96 (2026-10-24) only those that differ from the value nanogui made them with
(`#min` / `#max`: 0 / 1 for a slider, the whole float or int32 range for a number field; `#smoothing` 0,
`#SyncMultiplier` 1, `#Trigger` 0, `#default` ""). A state with
`aux_defaults_omitted: 1` means: a missing one is at that default, and loading the state sets it so.

---

# The layout of the views (MCP tools)

The screen is made of view tabs (top bar), each split into areas; an area holds one view (Patchview, Clipview, ...),
a split, a Tabview, or nothing (then it shows the picker "What goes here?"). `vibevj_describe_layout` reads it. These
tools of the MCP server (MCP tab; "Allow changes" on, show mode off) change it as the mouse does, through the same code
(#344, 2026-10-24): each action is one step of the undo history, and each returns the new layout (the answer of
`vibevj_describe_layout`) with `result`: what was done, where things are now (`[tab, tab_name, path]`), `undo` (the
step it made) and `changed`. A wrong argument is a tool error with the reason, and nothing changes.

**Naming an area.** `area` is the path of the area in its view tab: `""` is the whole tab; below it the index of the
area in its split, or of the tab in its Tabview, at each level (`"1"`, `"1/0"`), in the order `vibevj_describe_layout`
lists `views` of a split and `tabs` of a Tabview (left to right, top to bottom). `areas` of `vibevj_describe_layout`
gives the path of every area of the view tab in front. Instead of a path: the uid of the view in the area (`uid` of a
leaf, the keys of `assets`) or the guid of a split / Tabview, which stays the same while paths shift. `tab`: the guid,
the name or the place of a view tab in the top bar (0 = the first); empty = the one in front.

| Tool | What the user does | Arguments |
|---|---|---|
| `vibevj_set_area_view` | a tile of the picker of an empty area; a drop in the middle (`mode` tab); *Replace view with* (`mode` replace: the old view moves into a view tab of its own) | `area`, `view` (a name of the picker: Patchview, Clipview, CueList, a layout or preset; or an asset path), `mode` (empty, tab, replace) |
| `vibevj_split_area` | *Split right* / *Split down* of the head (Ctrl+E / Ctrl+Shift+E); with `view` a drop on the edge | `area`, `direction` (right, down, left, up), `ratio` (share of the new area, default 0.5), `view` |
| `vibevj_close_area` | *Close area* (Ctrl+W); for a tab of a Tabview its close button. Closing never deletes: the view moves into a view tab of its own (`result.view`) | `area` |
| `vibevj_move_view` | the head of an area dragged onto another area: `zone` center = as a tab (into an empty area: fills it), an edge = split; `mode` copy = Ctrl at the drop; swap = *Swap with*; new_tab = *Move to new tab* | `area`, `to`, `to_tab`, `zone`, `mode` |
| `vibevj_set_split_sizes` | the line between two areas dragged (each area keeps at least 72 px) | `area` (the split), `sizes` (a share per area) or `divider` + `position` (0 - 1 of the split) |
| `vibevj_view_tab` | the view tabs: + (`add`), a click (`select`, no undo step), a double click (`rename`), the close button (`close`: deletes the views in it, so only with `delete_views` 1 when the user wants that) | `action`, `tab`, `name`, `delete_views` |
| `vibevj_undo` | Undo / Redo of the top bar (Ctrl+Z / Ctrl+Y) | `redo` (1) |

- The undo history is one for the program: links, values, generators and clips the user changes are steps too.
  Before `vibevj_undo` check `undo` (`redo`) of `vibevj_describe_layout`: it names the step that goes.
- Moving keeps the view alive (state, links, MIDI mappings, uid); a copy is a new view with the same settings.
- With software OpenGL (the Linux test containers) a step takes seconds, with a Clipview up to a minute; the tool
  returns when it is done and the layout has settled. During an autosave or a project load the call waits (up to 2 min).
- The in-app Chat does not have these tools (yet); it is an MCP client feature.

# Building a show (a Clipview from nothing)

Found out by building one with an outside MCP client (2026-10-24). The paths are the ones a new Clipview gets;
`<cv>` is the live_path of the Clipview (`vibevj_list_generators`: the entry with `assets/Views/Clipview.asset`).

1. **The first view.** An empty area is no generator: no generator query puts a view into it. Over MCP,
   `vibevj_set_area_view` {view: "Clipview"} does what a click on its tile in the picker ("What goes here?") does
   (see *The layout of the views* above). After that the Clipview is in the generator list.
2. **Clips:** query `add_item` of `<cv>` with `path` (the asset root, e.g.
   `assets/Shaders/Sources/3D/trance.glsl`), `row`, `col`. Rows and columns count from 0: row 0 is *Layer 1*, the top
   layer that gives the final picture, so backgrounds go in the lowest row and overlays above. `add_item` on a cell
   that has a clip stacks the asset onto it (an effect on a source); `clear: true` replaces it. The grid grows by
   itself. Sources with 3D scenes: `assets/Shaders/Sources/3D/`; effects: `assets/Shaders/Effects/*/`.
3. **Layers** (controls of `<cv>`, `set_local_control`, `<r>` = row):
   - `layer_ctrls_<r>@BLEND`: index into the list `get_local_control` returns (0 No Blend, 1 Add, 2 Add Mask, 3 Mix,
     4 Multiply, ...). A layer with *No Blend* covers everything below it; overlays need *Add* or *Mix*.
   - `layer_ctrls_<r>@MIX` (0..1), `layer_ctrls_<r>@MASTER` (0..1).
   - `layer_ctrls_<r>@TRANSITION`: the fade in seconds (0..60, 0 = hard cut); `value: 2` is 2 s. The slider has a
     curve as envelope, so its handle stands further right than the value (fine steps for short fades). Builds before
     the fix of 2026-10-24 applied the curve to the sent value (2 gave 0.065 s, 11.77 gave 2 s): if `new_value` in the
     answer is not what you sent, the app is older; send again with the value corrected.
     In a **Cue List** the cue's `cue_trans_<r>@Transition` is a mirror of the layer's: seconds (0..60), the same curve,
     linked **absolute** both ways. Set either one; both show the same seconds, also after a save and a load. Builds
     before 2026-10-24 had it 0..1 (normalized links): there a load made 0.065 s of a saved 2 s. Projects of then are
     migrated on load (format 5, `engine/migrate/migrate.shio`). The cue's Master and Mix stay normalized (both 0..1).
   - Any slider: `set_local_control` sets the value (the number shown, in its unit), also on a slider with an
     envelope; MIDI and normalized links set the handle position, and the envelope makes the value of it.
4. **Start:** query `launch_clip` (`row`, `col`) or `launch_column` (`col`) of `<cv>`.
5. **Autoplay:** the beats per clip are on the layer generator `<cv>/layer_shader_<r>`, control
   `autoplay_settings_<r>@Autoplay` (a vector: `[32]`). Switch it on with `layer_autoplay_start_<r>@>>>` = 1 on `<cv>`
   (`@<<<` backwards, `layer_autoplay_random_<r>@RND`). It counts the beats of the timeline: it waits until *Play* in
   the timeline bar runs (no query for it: the user presses Play or Space). Layers with different durations (16, 32,
   64 beats) give new combinations all the time.
6. **Picture on a display:** the final picture of the Clipview is the generator `<cv>/composition_shader`; its controls
   `ctrls.ctrls.output_ctrls_monitor.output_ctrls_monitor@Outputs.Outputs.Monitor.monitor_select` (index into its
   items: 0 Off, then "Display 1 · name · 3440 × 1440 · Control", ...), `...monitor_type` (0 Fullscreen, 1 Window) and
   `...monitor_fit` (0 Stretch, 1 Fit, 2 Fill). Read the items first: the numbers of VibeVJ are not the ones of the
   operating system. No output shader and no link are needed.
7. **Output size:** with *Settings › Project › Size from* = *Output displays* (the standard) the project size is the
   size of the *first* output display. With a portrait monitor among the outputs every shader renders portrait
   (`settings@Size` of a shader shows it) and a landscape display gets a stretched picture. No query sets it: the user
   picks *Common size… › 1920 × 1080* in *Settings › Project* (that sets *Manual*, saved with the project).
8. **Light in the show:** a Phaser (`assets/FixturesEffects/Phaser.asset`) is a clip like a shader. Put one per
   column into a free row and give each other quick effects (see *Phaser* below): the light changes with the columns
   and autoplay. The lamps must exist in the fixture setup first.
9. **Save:** `vibevj_save_project` with `name` the first time (a new project has none), without arguments after that.

## A CueList (the order of its cues)

A CueList (`assets/Views/CueList.asset`) is a Clipview with lists on top: each row of its grid is a list, its clips
are the cues, in the order of the columns (empty cells skipped). Its Clipview is no generator of its own, so
`add_item` / `launch_clip` do not exist here; cues are added by dragging assets onto it (real input).

- `get_target_status` of the CueList: `module_status.lists` = `[{row, name, cues: [{col, name, guid, live}]}]`, and
  `live` (the *Live* button of the CueList).
- `move_cue` {`row`, `index` (0 = the first cue of the list), `direction`: `up` / `down`}: the cue swaps places with
  its neighbour (both clips are made again in the other cell with their guid; the running cue keeps running). One step
  of the undo history, *Move cue up* / *Move cue down* (`vibevj_describe_layout` `undo`). An error at the start / end
  of a list and while *Live* is on. It returns when both clips are made, which takes seconds with software OpenGL:
  undo pressed before that undoes the step before (#374, 2026-10-24).



---

# The virtual MIDI controller

live_path `virtual_controller` (#343): `get_controller_layout` (the layout and its full key list in `help`),
`set_controller_layout`, `map_controller_element` (MIDI learn in one step, a control's `full_path`),
`play_controller_element`, `move_controller_mappings`. Facts an agent needs when it builds a layout:

- `set_controller_layout` never fails on a bad element: it leaves it (or the bad key) out and lists why in
  `problems`. Read `problems` and the returned `layout`, do not assume the input went in unchanged.
- Keep the `id` of an element when you change it: mapped controls follow an element by its id (new numbers, a new
  encoding), not by its place in the list.
- Optional per element (left out = as before): `min` / `max` (the range it sends; a mapped control then only reaches
  that part of its range), `feedback = false`, `color` `"#rrggbb"`, a grid's `colors` (one per pad). An endless knob
  is `mode = "relative"` (`"increment"` is the same) with `encoding` `"twos"` (default) or `"offset"`; it ignores
  `min` / `max`.

---

# fixtures

## The fixture setup (the lamps of the rig)

Use the tool 'vibevj_fixture_setup(action, args)' for the lamps, groups and Art-Net nodes. You do not need a focus for it.

- 'list_queries' lists every action with its arguments.
- Lamps and groups are named by their id or their name, nodes by MAC, IP or name, fixture types by path or name.
- 'list_fixtures' / 'list_fixture_types' / 'list_fixture_groups' / 'list_artnet_nodes' show what is there.
- 'import_gdtf' (path of a .gdtf file: GDTF Share, the manufacturer) makes a fixture type of each DMX mode and returns
  their paths, for 'add_fixtures'.
- 'add_fixtures' adds lamps at the next free DMX addresses (or at 'address'), optionally into a group.
- 'set_fixture' changes one lamp (also 'z', its height above the floor in metres, 'mount': floor or hanging, and 'lean':
  degrees it leans towards its front, for the 3D view); lamps and types report their 'kind' (head, bar, par, dimmer); 'address_fixtures' addresses lamps one after the other; 'arrange_fixtures' places them on the stage plan
  (row, grid, circle); 'remove_fixtures' removes them.
- 'add_fixture_group' / 'set_fixture_group' / 'remove_fixture_group': groups are ordered, the order is the order of a
  Phaser.
- 'get_dmx_universe' shows what uses the 512 channels of a universe of a node; 'get_dmx_conflicts' lists every place where
  two senders (lamps, LEDMapper segments) write the same channels. Check it after you changed addresses and tell the user
  about conflicts.
- 'highlight_fixtures' lights lamps at full so the user finds them in the rig (empty list: off).
- A rig for the 3D view, as built once: 'add_fixtures' with 'count', 'name' and 'group' (a new group of that name);
  then 'set_fixture' per lamp with 'x' / 'y' (metres on the plan, the plan seen from above; a larger 'y' is nearer the
  audience at the bottom), 'z' (height) and 'mount'. Moving heads on a truss: 'z' 5, 'mount' hanging (beam down); pars
  on the floor at the front: 'z' 0, 'mount' floor (beam up). The user sees it with *3D* in the toolbar of the fixture
  setup (Devices › Fixtures › Fixture setup opens it in a tab of its own).
- Lamps without a node are red ("No node") and send nothing; the 3D view and the Phaser work anyway. Do not pick a
  node of a real rig unless the user asks: the lamps then really move.
- Virtual lamps (#679): the type 'assets/Fixtures/Virtual/ProjectionZone.json' (a dimmer and a colour) needs no node and
  is never red for it ('list_fixtures' gives 'virtual' 1 and the node "Virtual (no DMX)"). It starts at full and white.
  'add_fixtures' with that type and 'node' "none" makes them; a Phaser runs over them like over real lamps.

## The lighting desk (programmer, palettes, cue stacks, executors)

Light and video as from a lighting console (#719, wiki page Lighting-Desk). MCP: `vibevj_query` with live_path `desk`
(or the query tools `desk_command`, `get_desk_state`, `get_lamp_values`); Chat: the tool 'vibevj_desk(action, args)'.

- 'desk_command' with 'command': the command line of the Programmer. Select: `group 1`, `group "Front pars"`,
  `fixture 3 thru 6`, `all`, `+` / `-`. Values: `at 50` (dimmer %), `full`, `out`, `at color red` (`#ff8000`,
  `100/50/0`), `pan 25`, `tilt 75`, `<channel> <0-100>`. `palette <n|name>`, `store palette colour <name>`,
  `store cue [n] [stack <name>] [fade <s>]`, `go`, `back`, `goto <n>`, `off` (`stack <name>` after them), `clear`,
  `highlight`, `help`. Several in one line; a selection after values starts a new one. By place (of the selection of
  the line, else of all lamps): `left`, `right`, `front` (towards the audience), `back`, `high`, `low`, `middle`,
  `lit`, `dark`, `odd`, `even`. `record cue [n]`: what the lamps show now (the selection, else all), effects included.
  `blind` (the programmer is not sent) / `take [s]` (sent, fading in).
- Cues start by themselves on `Drop` / `Break` of the audio analysis (trig of the cue; Prolink memory cues are drops),
  and a stack can wait with Go for the next beat, bar, 4 bars or DJ phrase (`quantize` in get_desk_state: 0, 1, 4, 16,
  -1 = phrase; set in the Executors).
- DJ Link phrases (rekordbox: Intro, Verse 1-6, Buildup, Break, Drop, Outro of the master deck, read from a
  ProlinkBridge / ProlinkDecks): `on_phrase` of a stack (`phrases go|match|off [stack <name>]`): `go` plays the next cue
  at each new phrase, `match` the cue named like the phrase or its group ("Verse" for Verse 2; names starting with the
  group count, several take turns). Only while the stack is on. A cue with trig `phrase` starts at the next phrase.
  `dj_phrase` in get_desk_state is the phrase now. To build a set for a DJ: cues named Intro, Buildup, Drop, Break,
  Outro (`store cue 3 name Drop`), `phrases match`, `go`; the rules then run without an agent. To try without CDJs:
  `music phrase Drop` (also `music drop`, `music break`) does what the music would do.
- `store cue <n> name <name> starts <go|follow|wait|beats|drop|break|phrase>` names a cue and sets how it starts.
- Stores, records, deletes and clear are steps of the undo history: `vibevj_undo` takes them back.
- 'get_desk_state': palettes, stacks with their cues (number, name, fade, delay, trig, values) and what each plays,
  the selection. 'get_lamp_values' (fixtures: lamps or empty): what the controls of the lamps have now, 0 to 1.
- The programmer wins over everything until 'clear'; 'clear' and 'off' give the lamps back what they had before.
- Virtual lamps are lamps of the desk: a MapLab slice (`ProjectionZone`: Dimmer, Colour, Pan, Tilt, Zoom, Rotate,
  Strobe; *Lamps for slices* in MapLab makes them) and a shader (`Look`, read by the generator LampValues). One
  palette or cue moves light and video together: `all at color red` colours pars and slices.
- Generators (assets/FixturesEffects): Programmer, Executors (faders of stacks and group masters, its controls
  `Master` / `Go` / `Back` / `Off` / `Flash` with the group `executor_<n>`), LampValues, CueTrigger (a cue when the clip
  it is in starts).
- Groups as link targets: Devices › Fixtures › Masters › Groups › <group> has `GROUP_MASTER` (group `group_master_<group
  id>`) and the inputs `Colour` (vector, group `group_input_<group id>`, components `R`/`G`/`B` with groups
  `group_input_<group id>_r` ...), `Dimmer`, `Pan`, `Tilt` (group `group_input_<group id>`). Link any output into them
  (vibevj_link_controls with full paths, or by hand); an input that moved sends to the group's lamps like a cue stack
  (HTP dimmers, LTP the rest) until Release. Over the desk interface: `set_group_input` (group, function color|dimmer|
  pan|tilt, value: 0..1 or [r, g, b]) and `release_group`; `group_inputs` in get_desk_state. A ColorSelector row has
  *Lamps* (all lamps or a group): its colour goes to them directly, no link needed.
- Devices › Fixtures › Masters: `SPEED_1` .. `SPEED_4`
  (group `speed_masters`); a phaser follows a speed master by its setting *Speed master*.

## Fixture types

Fixture definitions are located in assets/Fixtures using a simple json scheme
To get an overview of the exact format and possible channel definitions, look at assets/Fixtures/example.json which showcases all possibilities
You can create new fixtures there using regular file operation tools
You can also look up specific fixture definitions there

Optional, besides what example.json shows:
- a channel can say what it does: "function" is one of dimmer, pan, tilt, color, colorwheel, strobe, gobo, beam, speed,
  control, other. Without it the function is guessed from the name ("PT Speed" a speed, "COLOR" a colour wheel);
  'list_fixture_types' shows the functions of the controls. The Phaser uses them (Position for pan + tilt, Colour for
  RGB / RGBW), the 3D view of the fixture setup turns beams by pan and tilt.
- the fixture: "pan_range" and "tilt_range" (degrees from 0 to full, default 540 and 270) and "beam_angle" (degrees, for
  the 3D view).
- a channel can have a "default" (0 to 1, a list for the components of a colour, #669): where a new lamp starts. A
  virtual lamp starts its dimmer and colour at full and its other channels at their default, else 0 (#719).

## Testing lamps: test values

- 'set_fixture_test' holds lamps at values until 'clear_fixture_test': `{"dimmer": 1, "color": [1, 0, 0],
  "pan_degrees": 270, "tilt": 0.5}`. Keys: a function (dimmer, pan, tilt, strobe, colorwheel, gobo, beam, speed, ...),
  "color" ([r, g, b] or [r, g, b, w] from 0 to 1, the first RGB / RGBW colour of the lamp), "pan_degrees" /
  "tilt_degrees" (from 0, by the pan / tilt range of the fixture type), or the label of a control ("Shutter"). Values
  0..1 (or "50%"). A function a lamp does not have is skipped for it ('not_on_these_lamps'), so one call lights pars and
  moving heads alike; an unknown label is an error.
- 'dark_others': 1 holds every other lamp dark (dimmer and colour 0): only the lamps of the test light.
- A held value wins over the lamp's own value and over a running Phaser; the blackout still darkens it ('blackout' in the
  answer says so). The test is not saved. Always end with 'clear_fixture_test' (no lamps: all), or the rig stays held.
- 'get_fixture_values' shows each control: 'value' (its own), 'held', 'sent' (what goes out, after dimmers, flash,
  highlight and blackout).
- 'set_fixture_values' (same keys) sets the lamp's own controls for good, as moving the sliders in Devices › Fixtures
  does (saved with the project): to keep what you found. A Phaser on a control still moves it.

## Seeing: captures and the camera

Tools: 'vibevj_capture' (no live_path: the whole screen; a live_path: the window of a generator; 'picture' 1: only its
picture), 'vibevj_list_cameras', 'vibevj_camera_capture'. The in-app Chat gets each picture as the next message (needs a
vision model, e.g. a Qwen VL model); over MCP it comes as an image in the tool result, plus 'path' / 'absolute_path' of
the PNG ('image': 0 sends only the file, for a model that takes no images in tool results: open the file yourself).

**A camera.** 'vibevj_list_cameras' lists the Camera generators (assets/Generators/Input/Camera.asset). None: add one to
a view ('add_item' of a Patchview; 'vibevj_get_testarea' gives one). On its live_path: 'list_cameras' (the devices and
"Test pattern"), 'set_camera' (name or id), 'get_camera_status' ('picture' 1 once frames arrive; the first one can take a
second or two). The camera must see the stage: ask the user where it points if the picture does not show the lamps.

**'vibevj_camera_capture'** with 'fixtures', 'values', 'dark_others' runs 'set_fixture_test' first and takes the picture
'wait_ms' later (default 600). A moving head that turns far needs 1500-3000 ms; a picture taken too early shows it on
the way. Without 'fixtures' it only looks. The text part says what the lamps send.

## Workflows with the camera (found out for #670, 2026-10-24)

Look before you change: say what you see in each picture (where the light is, its colour, left / right / near / far)
before the next step. One picture per step; small, sure steps beat many guesses.

1. **Reference picture.** 'vibevj_camera_capture' with every lamp dark: 'fixtures' [the first lamp], 'values'
   {"dimmer": 0, "color": [0, 0, 0]}, 'dark_others' 1. Later pictures are compared with it (room light, reflections).
2. **Which lamp is where.** Per lamp: 'fixtures' [lamp], {"dimmer": 1, "color": [1, 1, 1]}, 'dark_others' 1. Where
   the light shows in the picture is where the lamp is. Faster: give several lamps different colours with
   'set_fixture_test' (one call per colour: red, green, blue, yellow, ...), then one 'vibevj_camera_capture' without
   fixtures, and tell them apart by colour. Then 'set_fixture' 'x' / 'y' (the plan seen from above: x to the right,
   a larger y nearer the audience), and 'set_fixture_group' 'fixtures' in the order seen (e.g. left to right).
3. **Does the lamp do what the fixture setup says?** One function at a time: only "dimmer" (does it light?), then only
   "color": [1, 0, 0] (is it red, or green / blue: channel order of the fixture type wrong), "strobe", "pan". No light
   at all: 'get_fixture_values' (is 'sent' 1?), the lamp's node / universe / address ('list_fixtures' problems,
   'get_dmx_conflicts'), the blackout; a wrong colour or a wrong channel moving: the address is off by some channels
   or the fixture type is wrong. Fix it in the fixture setup ('set_fixture') or the fixture file, then look again.
4. **Aim a moving head.** Light it ({"dimmer": 1, "color": [1, 1, 1]} or its colour wheel open), 'dark_others' 1. Move
   in big steps first ('pan_degrees' / 'tilt_degrees'), see where the spot lands, then halve the step towards the
   target. Find which way pan and tilt move the spot in the picture once, then steer. Keep the result with
   'set_fixture_values' (or as the position of a Phaser), then 'clear_fixture_test'.
5. **Check an effect.** After 'add_quick_effect' / 'add_phaser' of a Phaser: 'clear_fixture_test', then two or three
   'vibevj_camera_capture' a beat apart: the light should change as the effect says (a chase runs along the order of
   the group). Autoplay and Phasers follow the timeline: it has to run (Play).
6. **Done.** 'clear_fixture_test', tell the user what was changed in the fixture setup and what is still unclear.

Pitfalls: a camera adjusts its exposure: a full white lamp in a dark room blooms, use "dimmer" 0.5 when the spot is a
white blob. The picture of 'vibevj_camera_capture' may have black bars (it keeps the aspect of the camera). Lamps
without a node send nothing (red "No node" in the fixture setup): the camera sees nothing, the test values still show
in 'get_fixture_values'.

## Light and video together (#679)

- MapLab: each slice has a Lamp list (the lamp's colour x dimmer tints the slice in every output). Its button *Lamps for
  slices* makes a virtual lamp per slice and a group "MapLab slices" (left to right); a Phaser quick effect on that group
  plays on the projection. MapLab has no queries for this: it is the user's click.
- 'assets/FixturesEffects/FixtureState.asset' (add_item): its Out is a float texture, one column per lamp; row 0 colour x
  dimmer (a = dimmer), row 1 x, y, z on the plan, row 2 pan, tilt, moving. 'assets/Shaders/Sources/Fixtures/FixtureGlow.glsl'
  reads it on its input "fixtures" (a shader declares 'uniform sampler2D fixtures;' and uses texelFetch).
- Art-Net learn (Devices > Network > Art-Net) maps any control to a DMX channel of a console, like MIDI learn. It is the
  user's click; the mapping is saved with the control ("artnet" in controls.json: universe, channel, bits16).

## Phaser and LEDMapper (generators, through vibevj_query)

- Phaser: 'list_targets' (lamps and the attributes they have: @position, @color:<slot>, or a channel label),
  'add_quick_effect' (Chase, Wave, Sparkle, Rainbow, Fade, Circle, Fan, Figure 8 over a target), 'add_phaser' (with
  blend: Priority, Highest, Add, Multiply, Lowest; shape for a position; color_mode and color_a / color_b for a colour),
  'list_phasers' (with 'sent': what the lamps get with every phaser blended), 'remove_phaser', 'show_patch'.
- LEDMapper: 'get_layout', 'add_segment', 'set_group', 'select', 'set_test', 'add_lamps', 'list_presets',
  'insert_preset', 'remove_selected'.