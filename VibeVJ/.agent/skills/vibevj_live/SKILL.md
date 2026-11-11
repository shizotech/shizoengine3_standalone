
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

Over MCP every query is also a tool of its own name (`get_timeline`, `desk_command`, ...; `mcp_bridge.shio`,
`refresh_tools`). A name that two interfaces register with different arguments gets **no** tool (`Unknown tool`), only
`vibevj_query` with the live_path reaches it. So a new query takes a name no other interface uses, unless it is
meant to be the same query (`add_item` of Patchview and Clipview). 2026-10-29: the desk's `get_timeline` (#755) hid
the timeline's (#680); the desk's are `get_cue_timeline` / `set_cue_timeline` now.

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

**Show mode** (#285) locks the layout and undo for performing; `show_mode` of `vibevj_describe_layout` is 1 then, and
the layout tools refuse. No MCP tool switches it and it is not a control (not mappable to MIDI, not saved: every start
is unlocked). The user turns it on with the lock of the timeline bar or Ctrl+L (Cmd+L) and leaves it by holding either
for 400 ms; a short press of the key does not unlock. Ask the user to leave it; do not try to work around it.

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
| `vibevj_maximize_area` | *Maximize* of the head and the menu (Ctrl+Space): the splits above give the area all of their room; another maximized area is restored first. `restore` 1 = *Restore the layout*. No undo step (only shares change, a save stores the layout restored) | `area`, `restore` |
| `vibevj_duplicate_view` | *Duplicate* of the menu: a copy set as the view is, in a new area to its right (`result.duplicate`); a view of its own, not linked | `area` |
| `vibevj_delete_view` | *Delete view…* of the menu after "yes": the only layout action that deletes, so only when the user asked. The area goes (a tab of a Tabview / a whole view tab stays, empty); `vibevj_undo` brings it back | `area` |
| `vibevj_undo` | Undo / Redo of the top bar (Ctrl+Z / Ctrl+Y) | `redo` (1) |

- The undo history is one for the program: links, values, generators and clips the user changes are steps too.
  Before `vibevj_undo` check `undo` (`redo`) of `vibevj_describe_layout`: it names the step that goes.
- Moving keeps the view alive (state, links, MIDI mappings, uid); a copy is a new view with the same settings.
- Generators the user Alt + drags out of a Patchview (#348; no MCP tool does it) move alive into an area, another
  Patchview, a Clipview cell or a CueList (one clip of them: `<clipview>/<clip guid>/<generator guid>`), or a clip of
  the timeline or a loop. Their guid stays, their `live_path` changes to the new place: look them up again
  (`vibevj_list_generators`, the last part of the path is the guid). The undo step is "Move generator(s)" / "Copy
  generator(s)"; undo puts a moved one back into its Patchview.
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
   Building blocks to combine like TouchDesigner operators (#586): effects `Feedback&Blur/FeedbackTransform`,
   `Morph&Mirror/Displace` (second input `displace_map`), `Utility/Composite` (second input `layer`), `Color/GradientMap`,
   `Color/Levels`, `Glow&Light/Relief`; sources `3D/SDFScene`, `Patterns/InstanceGrid`, `Patterns/FoldFractal`; value
   generators `assets/Generators/Math/Lag.asset`, `Trigger.asset`, `Speed.asset`, `Math.asset`, `Count.asset`,
   `Hold.asset`, `Select.asset`, `Filter.asset` (their *Input* takes a link); the sound and text assets: see *Sound,
   text and values* below. Their
   controls are uniforms (`uniforms.uniforms@Controls.<name>`, an enum takes its index, a button 0 / 1, a `vec2` `[x, y]`,
   an `//@rgb` colour `[[r, g, b]]`: a flat `[r, g, b]` is ignored without an error); the wiki page *Assets* lists them.
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
   - The settings of a clip are controls of the clip `<cv>/<guid>` (the guid is the second to last part of
     `grid[r].row[c].stacked[0].live_path` of `get_target_status`): its inputs
     `input_settings.shader_input@Inputs.<input>` (e.g. `iChannel0`; Relative: 1 = the layer below, 0 = off) with
     `..._type` (0 Relative, 1 Absolute), its macros `macros.@Macros.MACRO <n>` (n = 1 ... 8).
   - **In** (`default_io@IN` of `<cv>`, bottom left): a picture linked to it goes to the default input (the only one,
     or the first `input` / `iChannel0` of a shader) of every live clip whose input is 0 (off). New clips have 1 there:
     set it to 0 to use In. Nothing linked to In: an input at 0 stays empty (#374, 2026-10-28).
4. **Start:** query `launch_clip` (`row`, `col`) or `launch_column` (`col`) of `<cv>`. `get_target_status` of `<cv>` has `live`: the
   column of the live clip of each row (-1: none), to check it started (#359).
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

## A show on the timeline (clips on lanes, #680)

The main timeline (bottom of the window, *View* › *Timeline*) holds clips on lanes, like a video editor. Its interface
has the live_path `timeline` (a query only it has goes there without a live_path):

| Query | Arguments | Does |
|---|---|---|
| `get_timeline` | `loop`, `song` | `position` (beats), `bpm`, `playing`, `loop` [start, end, on], `lanes` [lane, blend, mix, `crossfade`, `fading`, `transition`, `envelopes`], `clips` [id, name, path, lane, beat, length, active, `fade_in`, `fade_out`, `curve`]; the main timeline also `loops` (its loop timelines), `cues` and `song` (the song it is) |
| `add_timeline_clip` | `path` (asset root), `lane` (0 = top), `beat`, `length` (beats, 16 default) | a clip; returns it with its `id` |
| `set_timeline_clip` | `id`, `lane`, `beat`, `length`, `fade_in`, `fade_out` (beats), `curve` (`linear`, `equal_power`, `s_curve`) | moves / resizes; its fades and their curve (also of a crossfade into it) |
| `remove_timeline_clip` | `id` | deletes it with its generators |
| `set_timeline_lane` | `lane`, `blend` (name or index: No Blend, Add, Add Mask, Mix, ...), `mix` (0..1) | the blending of a lane |
| `set_timeline_loop` | `start`, `end` (beats), `on` (0 / 1) | the loop range and the button Loop |
| `set_transport` | `play` (0 / 1), `position` (beats), `bpm` | the transport bar |
| `add_timeline_envelope` | `lane`, `target` (full path of a control, empty = the Mix of the lane), `points`, `show` | an envelope of the lane; returns it with its number `envelope` |
| `set_timeline_envelope` | `lane`, `envelope`, `points`, `target`, `show` (1 shows it on the lane, 0 hides the lane's envelopes) | changes it |
| `remove_timeline_envelope` | `lane`, `envelope` | deletes it with its links |
| `edit_timeline_envelope_points` | `lane`, `envelope` (default the shown one), `action` (`select`, `move`, `copy`, `paste`, `delete`), `points` (indices) or `beat` / `to` (select), `beats` / `value` (move), `beat` (paste, default the playhead) | the selected points as with the mouse (`selected` of the envelope in `get_timeline`) |
| `get_timeline_cues` | | the cues: id, beat, name, action, does (text), fired (count), last (result of the last run) |
| `add_timeline_cue` / `set_timeline_cue` | `beat`, `name`, `action` (below); set: `id`, `fire` 1 (run it now) | a cue; returns it with its `id` |
| `remove_timeline_cue` | `id` | deletes it |
| `get_timeline_songs` | | the songs of the show: number (from 1), guid, name, timecode, bpm, active, lanes, clips, cues; `active`, `by_timecode` |
| `add_timeline_song` | `name`, `timecode`, `bpm` | a song (an empty timeline) at the end; it does not play yet |
| `set_timeline_song` | `song`, `name`, `timecode` (hh:mm:ss:ff, empty: none), `bpm` (0: keep), `by_timecode` (0 / 1) | changes it |
| `select_timeline_song` | `song`, `position` | it plays: from its start (or `position`), its BPM |
| `remove_timeline_song` | `song` | deletes it (not the first song) |
| `get_timeline_loops` | | the loop timelines: guid, name, beats, start, rate, running, chase, phase, position, lanes, clips |
| `add_loop_timeline` | `name`, `beats` | a loop timeline in the view *Loops* (stopped) |
| `set_loop_timeline` | `loop`, `name`, `beats`, `running` (1 start, 0 stop), `reset`, `chase` (0 / 1) | as the buttons of its row |
| `remove_loop_timeline` | `loop` | deletes it with its clips; a step of the undo history (undo makes it again in its place) |
| `add_timeline_lane` | `lane` (its position, default the bottom), `name` | a lane; returns its JSON (`id`, `name`) |
| `remove_timeline_lane` | `lane` | deletes it with its clips and envelopes (undo brings them and the links back) |
| `move_timeline_lane` | `lane`, `to` | moves it with its clips, envelopes, links and MIDI mappings |
| `select_timeline_clips` | `ids` (`[]`: none) | selects clips (`selected` in `get_timeline`) |
| `copy_timeline_clips` | `ids` (default the selection), `paste` (a beat), `duplicate` (1) | copies them (Ctrl+C); pastes at `paste` or duplicates right after them; returns the copies |
| `paste_timeline_clips` | `beat` (default the cursor) | pastes the copied clips on the lanes they came from |
| `get_timecode` / `set_timecode` | `on`, `source` (`mtc`, `clock`, `ltc`), `device`, `offset` | the timecode / clock chase of the main timeline (below) |
| `set_timecode_output` | `device` (empty: none), `clock`, `mtc` (0 / 1), `rate` | VibeVJ as the master: MIDI clock / MTC to a MIDI output |
| `send_test_timecode` | `time`, `rate`, `play`, `locate`, `speed` | MTC into the virtual MIDI device *Shizo Virtual MIDI* |
| `send_test_clock` | `bpm`, `play`, `beat`, `off` | MIDI clock into the virtual MIDI device *Shizo Test Clock* |
| `send_test_ltc` | `time`, `rate`, `play`, `reverse`, `off` | the LTC messages of the audio analysis, made here (no sound) |

Every query of a timeline (`get_timeline`, `add_timeline_clip`, `set_timeline_clip`, `remove_timeline_clip`,
`set_timeline_lane`, `set_timeline_loop`, the envelope, lane, cue and copy queries) takes `loop`: the guid, name or
index of a loop timeline, and `song`: the name, number (from 1) or guid of a song of the show; without them the query
is for the main timeline, i.e. the song that plays.

- A clip is active only while the playhead is inside it (`active` in `get_timeline`): put the cursor there with
  `set_transport` `position`, or play. Outside it, its generator is off (the power button stays as it is; the
  timeline dispatches `"active"`).
- Lane 0 is the top lane and the final picture: lane 0 over lane 1 over lane 2, as the layers of a Clipview. The start
  blend mode is *Mix* with Mix 1 (the lane covers the lanes below where its clip plays); an empty lane passes the lanes
  below through. Overlays: *Add*, or *Mix* with a Mix below 1.
- The picture of the timeline: the port *Out* above the lane heads (link it into an output shader), or the LayerBlend
  of lane 0 (live_path `timeline/timeline_lane_shader_0`; its *Outputs* send it to a display). The generators of a
  clip are under `timeline/<clip id>`: `timeline/<clip id>` itself is the stack round them (only the queries every
  generator has), the generator is one level deeper (`timeline/<clip id>/<id>`, the same `file_path`) and has its own
  queries (`mask_*` of a MaskDraw clip; smoke phase `maskdraw`, 2026-11-01).
- Each add / move / delete / loop change over these queries is one step of the undo history (`vibevj_undo`).
- **Lanes (step 3)** have an `id` they keep (`get_timeline` `lanes[].id`, `name`): the head of a lane is the node
  `timeline_lane_<id>` (a loop: `<loop guid>_lane_<id>`), its LayerBlend `timeline_lane_shader_<id>`, so control paths
  (`timeline/timeline_lane_<id>/MIX`), links and MIDI mappings stay with the lane when it moves; `lane` in the
  queries is the position (0 = top). Old projects: id = position. Without a name a lane is called "Lane <id + 1>".
  There is always an empty lane at the bottom (a new one comes when a clip lands on the last lane).
- **Crossfades:** two clips that overlap on a lane are both active; over the overlap the later one fades in (the
  LayerBlend's `TRANSITION`, iChannel2), `crossfade` true on the lane in `get_timeline`.
- **A video clip** (a video file added without `length`) takes the length of the video in beats at the tempo now
  (`waits_for_video_length` in the answer when the video was not open yet; `get_timeline` a moment later).
- **MIDI Time Code:** `set_timecode` `on` 1, `device` (a MIDI device name, empty = any), `offset` (the timecode at beat
  0, hh:mm:ss:ff or seconds): the cursor is (timecode - offset) * BPM / 60. The master starts / stops / locates: the
  timeline plays / stops / jumps; while both run the cursor lands on the timecode every frame (`error_seconds` in
  `get_timecode`, the cursor `position`, `playing` and `target_beat` of one answer: compare these, not the answers
  of two calls, which can be seconds apart). `position` is the cursor of the last frame, `target_beat` is read when the
  call is answered, `frame_age_seconds` later: while it plays the cursor is behind the target by about
  `frame_age_seconds` * BPM / 60 beats (0.3 beats at 7 fps and 128 BPM), and what VibeVJ sends as the master is ahead
  of `position` by as much; `fps` is the frame rate the chase steps with (2026-11-01). Rates 24, 25, 29.97df, 30 come from
  the timecode. Without a master: `send_test_timecode` (`time`, `rate`, `play` 1 / 0, `locate` 1 for a full frame,
  `speed` 1.05 for a master 5 % fast) into *Shizo Virtual MIDI*. The device and offset are saved (`timecode.json`),
  Chase is the control `CHASE` of the bar.
- **MIDI clock (step 4):** `set_timecode` `source` `clock`: the cursor is the song position in beats (no offset), the
  BPM control follows the tempo of the clock (`clock` in `get_timecode`: `bpm` smoothed over the last beat, `running`,
  `position`, `clock` = clocks come, `locates`). Test master: `send_test_clock` (`bpm`, `beat` = a song position, `play`
  1 = Continue / Start at 0, 0 = Stop; what is not given goes on) into *Shizo Test Clock* (a virtual device of its own,
  so the output can use *Shizo Virtual MIDI*). The decoders are C++ (`mididevice.clock()`, `nanogui.midi_clock(name)`);
  clock messages carry the time the driver delivered them (`midi_message::time`).
- **LTC (step 4):** `source` `ltc`: the timecode the *Audio Input Analysis* generator reads in its sound
  (`simpleaudio.ltc()` in `engine/processes/audio_process.shio`, each input channel; "ltc" ipc messages to the asset,
  which calls `timeline.timecode.ltc_message`). Needs that generator in the project. Backwards LTC moves the cursor
  back. `get_timecode` `ltc`: time, running, rate, reverse, channel. Test without sound: `send_test_ltc`.
- **Output (step 4):** `set_timecode_output` `device`, `clock` / `mtc`, `rate`: a C++ thread per device
  (`mididevice.send_sync(state)`) sends 24 clocks a beat (also while stopped), SPP + Continue (Start at 0) on Play,
  Stop, Stop + SPP + Continue on a jump while playing, MTC quarter frames while playing and a full frame on a
  start / jump / move while stopped; the timecode is offset + position * 60 / BPM. Fed every frame after the cursor
  moved (`after_move` in `__init__.shio`). To a virtual device the messages come in as its input: send to
  *Shizo Virtual MIDI* and read it back with `set_timecode` `device` *Shizo Virtual MIDI* (`get_timecode` `clock` /
  `timecode`), the chase off. `get_timecode` `output.sent` counts what went out. Messages of the sender thread reach a device through the queue of `nanogui.mididevicehandler()`: a script outside the app (a test) must make the handler first, or nothing comes in (`_testing/nanogui/midi_clock.shio`). Saved in `timecode.json`
  (`source`, `out_device`, `out_clock`, `out_mtc`, `out_rate`).
- **Fades (step 5):** `fade_in` / `fade_out` in beats; a clip with fades and no crossfade fades over the lanes below
  (`fading` true on the lane, `transition` its gain now by its `curve`: equal power is sin(t * pi / 2)); a crossfade
  weighs the two clips by the curve of the later one (`XFADE_CURVE` of the LayerBlend; linear 1 - t / t, equal power
  cos / sin, S smoothstep). The handles at the top corners of a clip drag them (`Clip fades` in the undo history).
- **The stack of a clip:** adding / removing an entry in the Clip panel is a step of the undo history (`Add to clip`,
  `Remove from clip`); undo makes the clip again from its snapshot (same guid, entries and settings).
- **The generators of a clip:** `get_timeline` `clips[].entries` = `[name, live_path]` of the entries of its stack; reach
  them with `vibevj_query` (e.g. a *LoopTrigger* clip: query `set_loop` `loop` = a loop guid / name).
- With software OpenGL (the Linux test containers) every running clip is a full-screen shader: keep few clips under
  the playhead at once, frames get slow (several seconds) with three 3D shaders running.

**Envelopes (Ableton style, #680).** One full-length envelope per lane and target, no envelope clips. An envelope is
an output control of the lane head (`ENV_<n>`, full path in `control` of its JSON) whose value is the envelope at the
playhead; it reaches its target through a **normalized** link, so 0..1 runs through the range of the target, and any
linkable control can be a target (`target`: the `full_path` that `get_local_control` of a generator returns). The
first envelope of a lane (its button in the head, or `add_timeline_envelope` without `target`) drives the lane's Mix.
- `points`: `[[beat, value 0..1, curve -1..1], ...]`, sorted by beat. Before the first point the envelope holds the
  first value, after the last one the last value; two points on one beat are a jump. `curve` bends the segment that
  starts at the point (0 straight, 1 slow start, -1 fast start).
- In the JSON: `envelope` (its number on the lane), `name` (the control it drives, else "Env <n>"), `targets` (full
  paths), `control`, `points`, `value` (now), `shown`.
- The envelope writes its target only when its own value changes: a target moved by hand stays until the envelope
  moves on. The links are saved in `controls.json`, the points in `timeline_clips.json` (`lane_state`).
- Adding, deleting an envelope and changing its points are steps of the undo history (`Add envelope`,
  `Delete envelope`, `Edit envelope`); showing / hiding is not.
- **Selected points (step 5):** `selected` (indices) in the envelope JSON; `edit_timeline_envelope_points` selects
  (indices, or `beat` .. `to`), moves the selection by `beats` / `value` (as a group: clamped so every point stays in
  0..1 and at beat 0 or later), copies, pastes at a beat (the points in the pasted span are replaced) and deletes. With
  the mouse: click / Shift + click / a rubber band on a lane that shows its envelope (it takes the points there, not the
  clips); Delete, Ctrl+C, Ctrl+V work on the points while some are selected (`Move envelope points`, `Paste envelope
  points`, `Delete envelope points`; a mouse drag is `Edit envelope`).

**Cues (step 5).** A cue is a flag on the ruler of a timeline (a song; loop timelines have none) that runs its `action`
when the playhead passes it while Play runs (from the beat of the last frame up to the beat now; a jump of more than
2 beats, a locate or `set_transport` `position`, runs none; the loop jumping back runs the cues at its start). Actions
(`src/menu/timeline/cues.shio`, `tl_cue_run`): `{type: clip, view: <live_path of a Clipview or "" = the first>, row,
col}` (its `launch_clip`), `{type: column, view, col}`, `{type: desk, command: "goto 3 stack Main"}` (the desk's
command line), `{type: midi, device, message: "90 3C 7F"}` (hex bytes to a MIDI output), `{type: loop, loop: <name>,
run: 1 / 0}`, `{type: song, song: <name or number>}`, `{type: query, live_path, query, args}` (any AI query). `fired`
and `last` (`ok`, `error`) in `get_timeline_cues` say whether it ran. Saved with the timeline (`cues` in
`timeline_clips.json` / the song's `timeline`); the flags are markers of the widget (`marker_add`, ...).

**Shows: songs (step 5, `src/menu/timeline/shows.shio`).** The view *Timeline* holds a list of songs, each a timeline
of its own (lanes, clips, envelopes, loop, cues); one plays at a time and is what the queries without `song` reach.
The first song is the timeline of before (`timeline_clips.json`, heads `timeline_lane_<id>`, Out `timeline_out`); the
others are in `timeline_shows.json` with their timelines, their lane heads are `<song guid>_lane_<id>`. All songs
share Out and the Clip panel. A song picked by hand / MIDI / cue / MCP (`select_timeline_song`) plays from its start
(beat 0) and its `bpm` (> 0) becomes the tempo. **By timecode** (`by_timecode`, default on): while the chase follows
MTC or LTC, the song with the last `timecode` at or before the incoming time plays and its timecode is the offset (the
cursor is (time - song start) * BPM / 60); a locate into another song's range switches. MIDI: the bar of the song
popup has `SONG_PREV`, `SONG_NEXT` (buttons) and `SONG` (int 0..127: map a program change, program n = song n + 1),
each row a `GO` button (node `song_<guid>`). Adding / deleting / renaming songs and changing timecode / BPM are steps
of the undo history; selecting is not.

**Loop timelines (the view *Loops*).** Each loop of the view *Loops* is a timeline of its own with lanes, clips,
blending and envelopes, the same code as the main timeline. Its cursor (`position`) runs from `start` over `beats`
again and again while the loop runs (`set_loop_timeline` `running` 1), along the main timeline (Play, BPM; a loop does
not move while the main timeline stands). A stopped loop plays no clips (its envelopes hold their value). A clip added
without `length` fills the turn. `set_timeline_loop` with `loop` sets its range (start, end = start + beats). Its
picture is its own port *Out* (above its lane heads). Its lane shaders are made with its first clip (an empty loop
renders nothing); the clips of all loops share the *Clip* panel at the right of the view *Loops*. Saved in `loops.json`
(`timeline` of each loop).
- **Chase (step 4):** `set_loop_timeline` `chase` 1 (the button *Chase* in its row head, control `CHASE` of the node
  `<guid>`): while it runs its turns are main position * rate / beats, so it jumps with the main timeline (and with a
  timecode / clock the main timeline chases).
- **Start a loop from the main timeline:** the asset `assets/Generators/Utility/LoopTrigger.asset` as a clip
  (`add_timeline_clip`), its loop set with `vibevj_query` on `clips[].entries[0].live_path`, query `set_loop`. While the
  cursor is inside the clip the loop runs (`clip_start`: reset + run with *From the start*, else start on the bars;
  `clip_stop`: stop with *Stop at the end*). It keeps the loop by guid and name (`save_state`).

## Instancing, a 3D stage, transform and a million particles (#586)
The fourth set (the wiki page *Assets*, section *Shaders › Instancing, 3D, transform and points*): the effects
`assets/Shaders/Effects/Morph&Mirror/Instancer.glsl` (a shape copied over a grid, circle, ball, drum or scatter, each
copy sized, coloured, turned and pushed out by the pixel of the input under it) and
`assets/Shaders/Effects/Utility/Transform.glsl` (crop, fit, move / scale / turn around a pivot, tiles with mirror,
brick offset and gaps, edge modes, scroll and spin by the beat), and the sources
`assets/Shaders/Sources/3D/Stage.glsl` (raymarched objects on a reflecting floor under a spot light that follows the
beat; `quality` 1 to 3) and `assets/Shaders/Sources/Simulations/Particles2.glsl` (up to 1 048 576 particles in 3D,
drawn as real GL points; second input `field`). Stack the effects onto a clip, as above. Controls are uniforms
(`uniforms.uniforms@Controls.<name>`); the number of particles is `particles`, the copies of the Instancer
`columns` × `rows`.

- Instancer and Particles 2 draw with a *point pass* (`//@settings draw=points` / `draw=quads`, SHADER_GUIDE.MD 3.4):
  a pass whose vertex shader places `count` points. Their picture is the pass `I` / `D`, which `__init__` puts over the
  background; the hover preview of the *Assets* tab runs only `__init__`, with its test picture on every sampler
  (also on `I` / `D`), so it shows that picture, not the points.
- Under Xvfb (Mesa llvmpipe) Particles 2 with a million particles renders about a frame a second; its simulation steps
  at most 0.1 s a frame, so it needs a minute or two of waiting before the picture settles. A changed `.glsl` reaches
  the app only in a new instance (the loader reads the source when the asset is added): `add_item` again (2026-10-30).

## Blur, time, motion and particles (#586)
More building blocks to chain like TouchDesigner operators (the wiki page *Assets*, section *Shaders › Blur, time,
motion and particles*): effects `assets/Shaders/Effects/Feedback&Blur/GaussianBlur.glsl` (second input `blur_mask`),
`DirectionalBlur.glsl`, `RadialBlur.glsl`, `LensBlur.glsl` (second input `depth_map`), `TiltShift.glsl`,
`TimeMachine.glsl` (a frame cache with time displacement, second input `time_map`), `FlowSmear.glsl` (datamosh),
`assets/Shaders/Effects/Utility/OpticalFlow.glsl` (the motion as a picture; *Output mode* 0 *Vectors* feeds the
`displace_map` of Displace), and the source `assets/Shaders/Sources/Simulations/Particles.glsl` (second input `field`).
Stacked onto a clip (`add_item` on a filled cell) an effect gets the picture of the clip. Their controls are uniforms
(`set_local_control` with `path` `uniforms.uniforms@Controls.<name>`: an enum takes its index, a button 0 / 1, a
`vec2` `[x, y]`, an `//@rgb` colour `[[r, g, b]]`). To look at one picture full screen (also under Xvfb), set
`ctrls.ctrls.output_ctrls_monitor.output_ctrls_monitor@Outputs.Outputs.Monitor.monitor_select` of that shader to 1
(Display 1) and take a screenshot; 0 closes it again.

## Video into 3D and time (#586)
Effects on any picture, in `assets/Shaders/Effects/Video3D/` (the wiki page *Assets*, section *Shaders › Video into 3D
and time*): `RuttEtra.glsl` (scanlines bent by the brightness, in 3D), `PointCloud.glsl` (the picture as dots in 3D
that burst on the beat), `Voxels.glsl` (the picture as lit blocks), `SlitScan.glsl` (time displacement from a frame
cache, or the slit-scan camera), `Datamosh.glsl` (block motion pushed onto the last picture). Stack one onto a video
clip (`add_item` on its cell), or in a Patchview link the video's `OUT` to the effect's `input_ctrls@input` (no
MCP tool makes a link: write it into `links.local` of the Patchview's node in `controls.json` of a saved project and
load it, as `smoke.py` `clipin` does). A video or picture generator's port is `<guid>/OUT`; `output_ctrls@OUT` is the
port of a shader: a link written with it to a video is dropped at the load without a message (2026-11-04). An effect
with nothing linked shows a test picture of four colour bars. To look at one effect big, set its
`ctrls.ctrls.output_ctrls_monitor.output_ctrls_monitor@Outputs.Outputs.Monitor.monitor_select` to 1 and take a
screenshot of the display (`import -window root`); `vibevj_capture` with `picture: 1` of a shader gave its whole
window (400 x 300) there. Controls are uniforms
(`uniforms.uniforms@Controls.<name>`):

- Shared: `music` (0 Auto, 1 Sound, 2 Beat, 3 Off), `music_gain`, `beat_every`; the 3D ones `camera_tilt`,
  `camera_turn`, `camera_sway`, `camera_orbit`, `camera_distance`, `zoom`, `background_mode` (0 Colour,
  1 Transparent, 2 Picture), `background_color`, `exposure`.
- RuttEtra: `lines`, `detail` (segments a line; the cost is `lines` x `detail`), `line_mode` (0 Horizontal,
  1 Vertical, 2 Grid), `displacement`, `displace_direction` (0 Up, 1 Towards camera, 2 Both), `displace_by`,
  `thickness`, `glow`, `color_mode` (0 Picture, 1 Gradient, 2 Single colour, 3 Picture x colour), `color_a`,
  `color_b`, `bass_displace`, `beat_flash`, `wave`, `scroll`, `cutoff`.
- PointCloud: `columns`, `rows` (the number of points), `point_size`, `point_shape` (0 Soft dot, 1 Disc, 2 Square,
  3 Ring), `depth`, `depth_by`, `jitter`, `threshold`, `explode`, `explode_mode` (0 Random, 1 Outwards, 2 Towards
  camera, 3 Swirl), `explode_spread`, `spring`, `turbulence`.
- Voxels: `columns`, `height`, `height_by`, `height_curve`, `block_mode` (0 Extrude, 1 Cubes), `gap`, `bevel`,
  `edge_glow`, `ripple`, `ripple_speed`, `wave`, `sun_angle`, `sun_height`, `quality` (1 no shadows, 2 shadows,
  3 shadows and 4x antialiasing).
- SlitScan: `time_mode` (0 Rows, 1 Columns, 2 Diagonal, 3 Radial, 4 Brightness, 5 Time map, 6 Slit stack),
  `cache_frames` (0 16 .. 4 144 frames), `record_every`, `freeze` (button), `depth`, `offset`, `reverse`, `steps`,
  `scan_direction` (0 Left .. 4 Out), `scan_speed`, `slit_position`; second input `time_map` (port
  `input_ctrls@time_map`), asked about in pass N of one pixel.
- Datamosh: `mosh_trigger` (0 Beats, 1 Hold only, 2 Always), `mosh_hold` (button: the one for a MIDI pad), `mosh`,
  `mosh_beats`, `mosh_cycle`, `decay`, `residual`, `block_size` (0 8 px .. 3 64 px), `quality` (the search range),
  `strength`, `melt`, `hold_vectors` (button), `glitch_blocks`, `output_mode` (1 Motion vectors).
- SlitScan and Datamosh need a moving picture: a still one shows no change (and Datamosh only its `melt`). They keep
  frames in passes, so their look builds up over a second or two after the start or a change of `cache_frames`.

## Foreground objects (#586)
Photoreal eye catchers for the top layer (the wiki page *Assets*, section *Shaders › Foreground objects*):
`assets/Shaders/Sources/Objects/Monolith.glsl` (black glossy cubes / pyramids / prisms / a slab, neon lines, a city),
`Prism.glsl` (clear glass ray traced per wavelength: rainbow fringes; `shape` 0-17 (0 Prism, 3 Gem, 5 Sphere, 12 Knot, 14 Heart ...), `count_x` / `count_y` 1-6 a grid of copies, `backdrop` 0 Auto (the picture of the optional input `background`, else Lines) ... 8 Bokeh, `dispersion`, `spectral_samples`; `beam_intensity` 8 for the album-cover beam), `Ferrofluid.glsl` (a black spiky blob),
`LavaLamp.glsl` (molten wax drops). Controls are uniforms (`uniforms.uniforms@Controls.<name>`), shared by all four:
`music` (0 Auto, 1 Sound, 2 Beat, 3 Off), `music_gain`, `react`, `glitch`, `glitch_kind` (0 Mix, 1 Slices, 2 RGB split,
3 Tear, 4 Shatter), `glitch_on_beat`, `glitch_every`, `glitch_on_sound`, `glitch_length`, `glitch_hold` (button 0 / 1:
the one to map to a MIDI pad), `background_mode` (0 Scene, 1 Colour, 2 Transparent: black with alpha 0 around the
object), `quality` (1 live, 2 full, 3 with 4x antialiasing), `exposure`, `tone_mapping`, `bloom`. The sound comes in by
the sampler `AUDIO` (port `input_ctrls@AUDIO`) like the sound shaders below: a running AudioInputAnalysis by itself, or
a link from its `output_ctrls@FFT TEXTURE OUT`; without sound they follow the beat. Each is
several passes (`S` the music state, `A` the object, `B` / `C` the glow, `__init__` the post): under Xvfb (software
OpenGL) a frame at 1080p takes seconds, so set `settings.@Render.Renderscale` 0.5 (or less) before a screenshot.

## Backgrounds: carpets and tunnels (#586)
Moving backgrounds for LED walls (wiki *Assets*, section *Backgrounds: carpets and tunnels*). Carpets (2D):
`assets/Shaders/Sources/Patterns/CarpetGirih.glsl` (Islamic star patterns, `tiling` 0-3), `CarpetPersian.glsl`
(`carpet_layout` 0 whole wall / 1 repeat / 2 field only), `CarpetKilim.glsl` (`pattern` 0 kilim, 1 ikat, 2 eye-dazzler,
3 kente), `CarpetOpArt.glsl` (`pattern` 0 Truchet, 1 Deco fans, 2 Vasarely bulge, 3 Riley waves). They share the LED
wall controls: `led_pixel` (output pixels per LED, 0 = off), `softness`, `wall_columns`, `wall_rows`, `screen_column`,
`screen_row` (1-based, row 1 = top), `screen_gap`, `canvas_offset`, `brightness`, `led_gamma`, `black_floor`,
`quality`; one carpet over several outputs = one copy per output with the same values except `screen_column` /
`screen_row`, time *Sync*. Morphs: `morph_every` (beats, 0 = off), `morph_beats`, the second pattern in `*_b`.
Tunnels (3D): `assets/Shaders/Sources/3D/TunnelChrome.glsl`, `TunnelConcrete.glsl`, `TunnelOrganic.glsl`; shared
`fly_speed`, `curves`, `banking`, `fov`, `fog`, `beat_lights`, `light_speed`, `exposure`, `brightness`, `quality` (1
live, 3 heavy), `debug_view`. A new shader starts with the *Default sync* setting, *Free* (seconds) in a fresh
copy: for a still at a given beat set `ctrls.timectrls@Time.Sync` to 1 (*Manual*) and `ctrls.timectrls@Time.Time`
to the beat.

## Sound, text and values (#586, third set)
The wiki page *Assets* (sections *Shaders › Sound*, *Generators › Sources*, *Generators › Math*) lists their controls.
- Shaders that draw or move with the music: `assets/Shaders/Sources/Audio/Spectrum.glsl`, `Oscilloscope.glsl`,
  `Spectrogram.glsl` (*View* 3 *Raw* is a grey map for Displace and co.) and the effect
  `assets/Shaders/Effects/Morph&Mirror/AudioDisplace.glsl`. A sampler named `AUDIO` or `WAVE` gets the FFT texture of
  the running AudioInputAnalysis by itself (`engine.audio_texture`, `shader_loader.shio`), also in a clip, unless
  something is linked into it; without an analysis their `test_signal` (0 Auto) plays a made-up beat, 1 Off, 2 Always.
  A clip that is not live does not render: launch it (`launch_clip`) before putting it on a display to look at it.
- `assets/Generators/Sources/Text.asset`: text as a picture (*Out*). Control paths: `Text`, `.@Number.Value`,
  `.@Number.Decimals`, `.@Font.Font face` (0 Sans, 1 Sans bold, 2 Mono, 3 Font file), `.@Font.Font file`,
  `.@Font.Size`, `.@Place.Align`, `.@Place.X`, `.@Place.Y`, `.@Place.Rotation`, `...@Colors.Colors.Color.R` (`.G`,
  `.B`), `.@Colors.Outline`, `...@Colors.Colors.Outline color.R`, `.@Colors.Shadow blur`,
  `...@Colors.Colors.Background.A` (a sub-vector adds a dot and its name, like the `//@rgb` of a shader),
  `.@Animation.Animation` (0 None, 1 Typewriter, 2 Scroll left, 3 Scroll up, 4 Lines, 5 Words), `.@Animation.Time`
  (0 Free, 1 Sync). `|` in the text starts a new line, `{value}` shows `.@Number.Value`. It has `get_capture_widget`,
  so `vibevj_capture` with `picture: 1` gives the text picture alone.
- Value operators in `assets/Generators/Math/`: `Math.asset` (`A`, `B`, `Combine`, `Function`, `.@Range.From low` ...,
  `Clamp`, `Output`: plain numbers), `Count.asset` (`Count button`, `Input`, `Steps`, `Mode`, `Reset`; outputs `Count`,
  `Output`), `Hold.asset` (`Input`, `Trigger`, `Sample`, `Mode`, `Value`; `Output`), `Select.asset` (`Inputs`, `Index`,
  `Position`, `.@Values.Input 1` ... `Input 8`, `Fade`; `Output`, `Picked`), `Filter.asset` (`Mode` 0 One euro,
  1 Average, 2 Median, 3 Envelope, 4 Slope; `Input`, `Output`). Set the inputs with `set_local_control`, read the
  outputs with `get_local_control`; they update once a frame.

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
- **Macros:** the controls `Macro 1` ... `Macro 8` of the CueList (`set_local_control` with that path) set the macro of
  the same number (`macros.@Macros.MACRO <n>` of the clip `<cuelist>/<guid>`) of the running cue of every list and of
  a cue fading in. A cue that starts gets the value of every fader that was moved once; a fader never moved leaves the
  cues' own macros alone. Which ones were moved is saved with the CueList (`cue_macros_moved` in its state) (#374,
  2026-10-28).



---

# Python generators (.py assets, #853)

A Python script as a generator (wiki page *Python-Generators*): `assets/<folder>/Name.py/src/__init__.py` (plus an
`asset.json` with `home` and a new 16 hex `id`, like the other asset folders) or a single `Name.py` file. Add it with
`add_item` and the asset root (`assets/Generators/Python/LFO.py`), never the `src/__init__.py`. The script runs in a
Python process of its own (engine/python, docs/python-server.md); a crash or hang ends only that process.

Writing one (the //@ grammar of the shaders with `#`, one implementation: `engine/generators/extensions/glsl/annotation_controls.shio`):
- `#@<type> key=value ...` at the start of a line, directly above a module level `name = default` (a type hint
  `name: float = 0.5` is fine). Types: `slider`, `float`, `int`, `bool` / `button`, `trigger` (True for one frame per
  press), `enum` / `choice` `options=(A, B)` (the default as text gives the text, as a number the index), `color` /
  `rgb` / `rgba` (a tuple 0..1), `vec2`-`vec4`, `ivec*`, `slidervec*`, `text`. `value=` wins over the assignment.
- `#@input size=(320,180) format=rgba|rgb|gray`: a port `input_ctrls@<name>`; the variable is a `shz.Image` (width,
  height, channels, data: bytes, rows from the top; `pixel(x, y)`, `to_pil()`, `to_numpy()`) or None while nothing is
  linked, valid only during process(). An input named `input` is the default input (stacking on clips).
- `#@output float|int|bool|vec2..4|rgb|rgba|text|list min= max=`: controls in *Outputs*, linkable. `#@output texture`:
  the picture, port `output_ctrls@OUT` (`shz.Image(w, h, data, channels)`; one per script).
- `#@settings rate=30 timeout=2000`. `def process(...)` gets what it names of `time`, `beat`, `bpm`, `dt`, `frame` and
  the variables; it sets output variables (`global`) or returns `{"name": value}`.
- Check before adding: `_testing/linux_app/check_assets.sh <shz> assets/.../Name.py/src/__init__.py` (annotations and
  Python syntax).

Driving one over MCP:
- Control paths as for shader uniforms: `uniforms.uniforms@Controls.<name>`; a colour
  `uniforms.uniforms.uniforms.@Controls.Controls.<name>.RGB` with `[r, g, b]`; value outputs
  `outputs.outputs@Outputs.<name>` (read with `get_local_control`).
- `get_python_status`: `state` (running, starting, installing, dead, stopped), `error` (the red line of the window),
  `detail` (the traceback / stderr), `python`, `pid`, `frame_ms`, `frames`, `dropped`, `note` (set when the annotations
  of the file changed: *Reload module* of the … menu makes the controls again), `declarations`, `problems` (annotations
  it could not read), `env` (below). `restart_python` = the *Restart* button (*Retry* after a failed install).
- A change of the file restarts Python by itself (checked once a second); the controls keep their values.
- Packages (#853 step 3): the asset's `asset.json` names them, `"python": {"version": "3.12", "dependencies":
  ["numpy>=1.26"]}` (or a `requirements.txt` in the asset folder / `src/`; a single `.py` file cannot). On first use uv
  makes a venv for that Python and set of packages (one per set, shared by assets with the same set) in the cache
  (Windows `%LOCALAPPDATA%\VibeVJ\python`, macOS `~/Library/Caches/VibeVJ/python`, Linux `~/.cache/VibeVJ/python`;
  `cache` of `configs/python.json`). Meanwhile `state` is `installing`; `env` has `state` (ready, building, error,
  fallback, override), `status` (*Installing dependencies: numpy>=1.26*), `progress` (the last line of uv), `venv`,
  `dependencies`, `python_request`, `error`. Poll `get_python_status` (a large package takes minutes); VibeVJ runs on.
  A failed install (`env.state` error: no network, a package that does not exist) shows uv's reason in `error`;
  `restart_python` tries again. `reinstall_python_env` deletes the venv of the generator and makes it again. After
  adding a package to `asset.json`, the generator restarts by itself (checked once a second) with the new set.
  `ModuleNotFoundError` in `error`: the script imports a package its `asset.json` does not name.
- `configs/python.json` `{"python": "/path/to/python3"}` (a string or a command list) wins over uv for every asset (no
  packages are installed then). Without uv and offline an asset that names nothing runs with the system's Python
  (`env.state` fallback, `env.note` says why).

# The web remote (phones and tablets)

live_path `web_remote` (#359, wiki page Web-Remote): a web page VibeVJ serves to phones in the same network (Devices ›
Network › Web remote). Queries:
- `get_web_remote`: on / off, address, phones paired and connected, `pages` (`[id, name, controls]`), `controls` (all
  entries with their `page`), `phone_edit`, `preview` (on, fps, width, quality, `sources`, the pictures made now in
  `active`, and what they cost: `render_thread_us` a frame, `per_picture_us`, `encode_ms`, `kb_per_frame`).
- `add_web_remote_control` (`control`: a full path, as `full_path` of `get_local_control`; `label`, `kind`, `page`: id
  or name, default the first page), `set_web_remote_control` (`id`; `label`, `kind`, `size` 0-3, `y`),
  `remove_web_remote_control` (`id`).
- `add_web_remote_page` (`name`), `rename_web_remote_page` (`page`, `name`), `remove_web_remote_page` (`page`; the last
  page stays).
- `set_web_remote_preview` (`on`, `fps` 1-15, `width` 160/240/320/480/640, `quality` 20-95): the live preview, off by
  default, a setting of this computer. `preview.available` 0 (with `preview.error`): this build has no `nanogui.encode_jpeg`
  (an older nanogui module); then `/api/preview` answers 501 and the phones show no eye, the rest works.

Facts an agent needs:

- The pages are saved with the project (`web_remote.json`, format 2: `pages`; a format 1 file of #786 with one
  `controls` list opens as the page *Controls*); port, network, the paired phones and the preview settings are
  personal (`configs/web_remote.json`). The PIN is never given out over MCP: only the user pairs a phone.
- The kind comes from the type of the control: a slider or a number with a range is a fader, a button a button, a
  list a choice, a vector of two an XY pad, a number with the whole float range (no `#min` / `#max`) gets - / +.
  To make a shader uniform a usable fader, give it a range first (its `#min` / `#max` attribute controls). A fader can
  also be `hfader` (across), `number`, or `xy` together with `y` (the full path of a second fader for Y): one XY pad
  that moves two faders. `size`: 1 one cell, 2 two, 3 the whole row, 0 the default of the kind.
- Phones edit the pages too (`/api/edit`, while *Phones can edit the pages* is on): what they change is in
  `get_web_remote` at once. Edits wait in show mode (409), from the phone as in VibeVJ.
- The preview shows the output shaders (Shaders › Utilities › output) and the views (`generator_view/<id>`, two parts:
  a Clipview, a shader in a view of its own); the source id is the live_path with `.` for `/`. A hidden shader per
  picture is made only while a phone asks (4 s after the last request it goes) and renders only fps times a second.
  Under Xvfb (software GL) VibeVJ runs at about 1-2 frames a second, so the preview does too, and a playing
  CenterBlob clip shows black in most frames there, in VibeVJ's own views as well (2026-10-30: not the preview).
- The phone sets values as MIDI does: no undo steps, links follow; the last change wins.
- Which clip is live in each row of a Clipview: `live` of its `get_target_status` (`module_status.live`, the column or
  -1), the same as the phone shows.

---

## Video clips: jog, sound for the audio analysis, pre-listen and level (#460)
Controls of a video generator (`get_local_control` / `set_local_control`, paths as `get_local_controls` lists them):
- `Jog`: a knob -1..1 without end. Each change moves the clip by `(new - old) * 63.5 * Jog step` frames and holds it;
  0.2 s after the last change it plays on (when *Play* is on), and the knob goes back to 0 (that return moves
  nothing). Over MCP: `value` 0.0315 moves 2 frames forward, -0.0315 two back (from 0, so one call per jump; to place
  the clip use `Position`). For MIDI it needs a *Relative* mapping (an endless encoder or a jog wheel).
- `jog_settings.@Jog settings.Jog touch` (1 held, 0 let go: the clip holds), `jog_settings.@Jog settings.Jog step`
  (frames per step, 1).
- `.@Options.Audio analysis` (0 / 1): the sound of the clip goes to the audio analysis. The AudioInputAnalysis
  generator takes it with `SOURCE` = 3 (*Video clips*; 0 sound card, 1 DJ Watch USB, 2 DJ Watch network).
- `LEVEL` (an output, 0..1, read it with `get_local_control`): how loud the clip is, the peak since the last frame,
  falling back 1.5 per second. It moves only while the sound is decoded (*Audio*, *Pre-listen* or *Audio analysis*
  on) and the clip plays forward at speed 1. Link it like any output (#460 point 5).
- `.@Options.Pre-listen` (0 / 1): the sound goes to the pre-listen output (headphones) instead of the main output and
  the analysis. The devices themselves are chosen in *Settings › Sound* (no MCP tool; personal, in `style.json` as
  `video_audio_output` / `video_audio_prelisten`, device names as `nanogui.video_audio_devices()` lists them).
- Converting a clip: `.@Options.Convert format` (0 HAP, 1 HAP Alpha, 2 HAP Q, 3 ProRes, 4 DNxHR), `.@Options.Convert
  size` (0 original, 1 2160p, 2 1080p, 3 720p, 4 480p), `.@Options.Convert result` (0 a copy `clip_hap.mov` next to
  the file, 1 *Replace*: the checked result takes the place of the file as `clip.mov`, every generator of the project
  that plays it follows, the original goes to `_originals/` next to it). Then `.@Options.Convert to HAP` = 1 starts it
  (the control keeps that name whatever it converts to); a second 1 while it runs cancels. Done when
  `vibevj_list_generators` shows the new `file_path` (#460, `_testing/linux_app/smoke.py replace`).
- A clip in a Clipview cell plays (and sounds) only while its cell is launched (`launch_clip` / `launch_column` of
  the Clipview); before that the generator is inactive and the analysis hears silence.
- Testing the jog with the virtual controller: a knob with `mode = "relative"` sends the steps between its old and its
  new value (`play_controller_element`, value 0..1, 127 steps). Give it `feedback = false`: with feedback the value
  the jog sends back when its knob returns to 0 moves the virtual knob, and the next steps come out wrong (2026-10-28).

## Projection mapping building blocks (#586, fifth set)
Shaders that work around a mask of the mapped objects (white = surface / object), wiki page *Output and devices*,
section *Projection mapping building blocks*: effects `assets/Shaders/Effects/Mapping/EdgeSweep.glsl` (light along
the outlines of the input and the mask), `MaskReveal.glsl` (the input only on the surfaces, wiped in),
`MaskPrep.glsl` (makes a clean mask of its input), `EdgeBlend.glsl` (soft edges for overlapping projectors); sources
`assets/Shaders/Sources/Mapping/MaskFluid.glsl` (smoke around the objects; second input `emit_picture`),
`MaskContours.glsl`, `RegionChase.glsl` (every region of the mask on its own; second input `fill_picture`),
`MaskRain.glsl`, `MappingTest.glsl` (test patterns). Example masks: `assets/Textures/mapping_mask_facade.png`,
`mapping_mask_objects.png`, `mapping_idmap_boxes.png`.
- All but EdgeBlend have the input `mask` (MaskPrep: its `input`) and the same mask controls (`mask_source` 0 Auto /
  1 Mask input / 2 Demo facade / 3 Demo objects / 4 None, `mask_channel`, `mask_threshold`, `mask_softness`,
  `mask_invert`, `mask_blur`, `mask_offset` `[x, y]`, `mask_scale`, `mask_rotation`, `mask_flip`), most also
  `show_mask`; EdgeSweep, MaskFluid, MaskContours, RegionChase, MaskRain and MaskReveal fire pulses from `pulse_every`
  (beats) and the button `trigger`. Auto uses demo shapes while nothing is linked; EdgeSweep then uses no mask.
  An unlinked sampler reads no texture in any pass since #880 (2026-11-03; before, it read another input of its pass, so the assets ask in pass
  M or the one-pixel pass N); to check Auto, compare it with *Demo facade* / *Demo objects* (the same
  picture when nothing is linked).
- Mask in a Clipview without links: the PNG in a lower row of the same column (e.g. row 2 under the shader in row 0),
  then on the clip `<cv>/<guid>` `set_local_control` `input_settings.shader_input@Inputs.mask` = 2 (Relative: two
  rows below; `..._type` 1 Absolute). A stacked effect (`add_item` on a filled cell) gets no input settings of its
  own: put the effect alone in its cell and its `input` = 1 (the row below) for the material.
- Since #852 a new PNG picture has `Flip Y` on and reaches a shader upright: a mask PNG put into a Clipview cell with
  `add_item` needs `mask_flip` 0 (checked 2026-11-01 with MaskPhysarum and `mapping_mask_objects.png`). Only a picture
  with `Flip Y` 0 (an older project) needs `Flip Y` 1 or the shader's `mask_flip` 1 (Vertical). The assets read a mask
  with the brightest channel, so grey PNGs work.
- Looking at them under Xvfb: llvmpipe gives a few frames a second, and MaskFluid, the comets of EdgeSweep (Trace) and
  the labels of RegionChase move per frame: wait 20 to 40 s before a screenshot. `debug_view` of EdgeSweep (1 distance,
  2 comets) and RegionChase (1 regions) show their passes.
- Simulations with a 3D look (#586): `MaskPhysarum.glsl` (slime mould agents; `mask_role` 0 Food around objects /
  1 Food / 2 Walls / 3 Container / 4 Ignore; `population`, `sensor_distance`, `species` 1-2, `brush` + `brush_position`,
  `pulse_action` 0 Food drop .. 4 Restart; `strains` 1-8 with `palette` 0 Slime / 1 Colour A to B / 2 Rainbow / 3 Fire /
  4 Ocean / 5 Toxic / 6 Candy, `color_variation`, `behavior_variation`, `repulsion` (also between the strains);
  `capillaries`, `show_agents` (agents as dots); second input `food_picture`) and `MaskReaction.glsl` (`model` 0 Gray-Scott /
  1 FitzHugh-Nagumo / 2 BZ; `pattern`, `pattern_outside` (9 Nothing), `mask_role` 0 Two patterns / 1 Inside only /
  2 Outside only / 3 Ignore; `seed_mode`, `brush`; second input `seed_picture`). Both share `lib/relief.glsl` (the
  same file in both assets): `look` 0 Photoreal / 1 Classic flat / 2 Glow, `material` 0 Wet slime / 1 Wax / 2 Gold /
  3 Chrome / 4 Glass jelly / 5 Ceramic, `relief_height` (px at 1080p), `camera_tilt`, `light_angle`, `light_height`,
  `ground` 0 Black / 1 Colour / 2 Agar / 3 Transparent, `bloom`, `tonemap`, `detail` + `detail_size` (micro relief and
  glints), `aging`, `tip_glow` (#892). `debug_view` shows the height, normals,
  trail / chemicals, agents and mask. At 1920 x 1080 under Xvfb they render well below one frame a second (an MCP call
  can take minutes while one is live on a loaded machine): give MCP calls long timeouts, or Render scale 0.5.
- Simulations in the mask (wiki *Simulations in the mask*), all `assets/Shaders/Sources/Mapping/`: `MaskSwarm.glsl`
  (boids; `mask_role` 0 Obstacles / 1 Container / 2 Ignore, `edge_attract`, `target` `[x, y]` with `attract`),
  `MaskBeams.glsl` (lasers; `surfaces` 0 Mirrors / 1 Glass / 2 Absorbers, `dispersion`, `emitter_layout`, `motion`),
  `MaskRipples.glsl` (water; second input `picture`: under the water and / or `picture_stir`), `MaskFire.glsl` (second
  input `emit_picture`; `fire_source`, `mask_role`), `MaskSand.glsl` (second input `picture`: grain colours and
  `pulse_action` 1 Picture to sand; button `clear_now`), `MaskLightning.glsl` (`arc_mode`, `timing`, `point_a` /
  `point_b`). Each also has `pulse_action` (or `pulse_look`), `obstacle_view` (or `land_view`) and `show_mask`.
- They step once a frame, the beat pulses count beats: under llvmpipe (a few frames a second) `pulse_every` 1 fires
  every few frames, so a swarm that scatters never forms flocks, a sand spout that bursts pours nearly all the time and
  the fire throws embers without a pause. Set `pulse_every` to 8 or 16 (or 0) before judging how they look, and wait
  60 to 120 s for flocks, piles and waves to form (2026-11-01).
- Before the fix of #586 (mask simulations) MaskSwarm's main pass read another texture through its unlinked `mask` in a
  Patchview: Auto drew walls over the whole picture while the boids (pass B, from pass M) were right. If a mask shader
  shows a wrong mask with nothing linked, compare with `mask_source` 2 / 3 (a demo) to tell the two apart. The same
  for an optional picture (MaskRipples *Picture*, MaskFire *Emit picture*, MaskSand *Picture*, the Grow *Seed
  picture*): with nothing linked they must fall back (tiles, no fuel, no seeds), never show another texture (#880).
- Growing shapes (sixth set, wiki section *Growing shapes*): `assets/Shaders/Sources/Mapping/GrowCoral.glsl`
  (reaction and diffusion), `GrowFrost.glsl` (phase field crystals), `GrowMoss.glsl` (spreading colonies),
  `GrowBranches.glsl` (tips that branch). Same mask input and controls as above, plus `mask_role` (0 on the surfaces,
  1 around the objects, 2 everywhere) and the life cycle: `cycle_mode` (0 Wither, 1 Burn, 2 Invert, 3 Recede,
  4 Reseed), `turn_at` (coverage share), `turn_every` (beats, 0 off), `turn_when_stuck` (beats), `turn_length`
  (beats), the button `turn` (set 1, then 0), `pulse_action` (0 nothing, 1 seed burst, 2 turn); seeds `seed_points`,
  `seed_edges`, `seed_from_picture` (second input `seed_picture`), `burst_seeds`; `palette`, `age_span`,
  `generation_hue`, `glow`, `transparent`, `grow_speed`, `debug_view`.
- Their values (pure outputs, //@readout of pass O, 0..1): `get_local_control` path
  `readouts.readouts@Values.life` (coverage / `turn_at`), `.turning` (0..1 through a turn), `.turn_pulse`,
  `.coverage`. Watching them is the way to see the cycle over MCP; they lag a frame or two and stand still while no
  output or preview shows the shader. Under Xvfb the simulations grow per frame (llvmpipe: a few frames a second),
  the turn counts beats (2 a second while the timeline stands still), so a turn looks fast and growth slow there: for
  a test set `turn_at` lower and `turn_length` longer (2026-10-31).
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
- Mapping by hand in the window (real input, a test): *Learn*, then a click on an element, then a click on the
  control (its learn overlay, which shows from the next frame on); or a right click on the element without *Learn*.
  Esc lets a waiting element go. An agent uses `map_controller_element` instead; both end in the same
  `map_element` (2026-10-28, #343).
- The controller draws with the theme (accent, control, text colours of `shz_theme`): a screenshot after a new accent
  shows the new colour, an element's own `color` stays.

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
  Denon players (Engine DJ) with the source *Network card* come in like CDJs (deck = player number), but their phrases
  are found in the waveform (Intro, Break, Drop, Buildup, Outro; no Verse) and their cues are hot cues, not memory cues.
- `store cue <n> name <name> starts <go|follow|wait|beats|drop|break|phrase>` names a cue and sets how it starts.
- Stores, records, deletes and clear are steps of the undo history: `vibevj_undo` takes them back.
- Effect timelines (#755): `set_cue_timeline` (stack, cue, timeline = {length: beats, loop, lanes: [{target: group or
  lamp by name or "all", attr: dimmer|color|pan|tilt|strobe|zoom|label:<channel>, keys: [{t, v, curve: step|linear|
  smooth}], wave: {shape: none|sine|saw|square|triangle|random, period, amp, center}, spread: 0..1}]}) gives a cue
  keys and waves that play over its values while the stack plays it (`go stack <name>`), with the BPM; a missing cue is
  made empty. v is 0..1, for color [r, g, b]. `get_cue_timeline` (stack, cue) returns it and `playhead` (beats, -1: not
  playing). One undo step per call. The Programmer's *Timeline* button edits the same.
- 'get_desk_state': palettes, stacks with their cues (number, name, fade, delay, trig, values, timeline_lanes) and what each plays,
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
  'add_cue_phaser' (stack, cue, level, blend, speed_master; #755): a phaser that plays a cue of the desk (its tracked
  values and its effect timeline) on the Phaser's clock, whether the stack plays or not; Level scales its dimmers.
  It runs with the timeline of VibeVJ like every phaser: Play has to run.
- LEDMapper: 'get_layout', 'add_segment', 'set_group', 'select', 'set_test', 'add_lamps', 'list_presets',
  'insert_preset', 'remove_selected'.
- MapLab: 'get_outputs' (per output: its effects, the guid of its LEDMapper, whether that maps what goes out) and
  'led_mapping' {index, action: open / close / remove}. The LED mapping of an output is a LEDMapper of its own (#755),
  over the projection area, fed with the end of the output's effects; it is a generator of its own, so its queries go

## Native assets (C ABI plugins, #201)

A native asset is a generator whose code is a C ABI plugin (a folder `Name.asset` with `src/__init__.native`, e.g.
`assets/Generators/Native/Life.asset`). Add it like any asset (`add_item` of a Patchview or a Clipview). Its window is
the one of a shader (*Out*, render size, outputs). Over `get_local_controls` / `set_local_control`:
- its controls: `uniforms.uniforms@Controls.<name>` (the names the plugin declares; an enum takes its index, a button
  0 / 1, a colour `[[r, g, b]]` like the `//@rgb` of a shader);
- its value outputs: `native_values@Values` (all as a list) and `native_values.native_values@Values.<name>` (pure
  outputs: link them, do not set them);
- Life: `rate` (generations a second, 0 stops it), `sync` (one per beat; Play must run), `rule`, `density` with
  `reseed` (each change of that button fills the field anew), `sparks`, `wrap`, `fade`, the colours `alive` / `dead`;
  values `population`, `births`, `step`.
A value set over MCP counts as a move (the plugin acts on a pushbutton); while a project loads, values are restored
without that (2026-10-29). Writing one: `core/shizoscript3_core_cabi/README.md`, *A native VibeVJ asset*.
- a text control (C ABI 1.3) takes a string: `uniforms.uniforms@Controls.palette` of Dither
  (`assets/Generators/Native/Dither.asset`, colours as `#rrggbb`); the plugin cuts it to its `max_length` and the
  field then shows what it kept;
- a picture input (C ABI 1.3) is a port like a shader's input: `input_ctrls@<name>` (Dither: `input_ctrls@input`,
  the *In* of the window). No MCP tool makes a link: a test writes it into `controls.json` of the view and loads the
  project (`{"ctrl1": "<gen>/output_ctrls@OUT", "ctrl2": "<gen>/input_ctrls@input", "type": 1}`, smoke phase
  `native`). The picture reaches the plugin one or two frames after the link;
- the queries `get_native_plugin` (read: the plugin's library, version, `reloads`, `changed` = rebuilt since it was
  loaded, what the asset declares incl. its inputs and whether they are linked, Watch on / off) and
  `reload_native_plugin` (loads the rebuilt library again; the asset keeps its controls, inputs and state; when it
  declares other controls its window is built again in the next frame, so read `get_local_controls` again then; its
  live_path stays). With *Watch the library* on (default) a rebuilt library is loaded by itself within about two
  seconds (2026-10-30).
## MaskDraw: a mask drawn with the mouse (#586)
`assets/Mapping/MaskDraw.asset` (wiki *Output and devices* › *Drawing a mask (MaskDraw)*): shapes over a picture,
output a mask (white = a surface, black = free) at the project size, the form the *Mask* ports of the mapping shaders
take. Ports: `IN` (*Background*, the picture to draw on: the lasso and the snapping follow its edges), `OUT` (*Mask*),
`IDS` (*IDs*: every shape in a flat colour, black elsewhere, nearest filtering: an ID map). Queries (vibevj_query on
its live_path):
| Query | Arguments | What |
|---|---|---|
| `mask_shapes` | | the shapes (the model: with `keys`), `selected`, `selected_point`, `tool`, `view`, `invert`, `output_size`, `edges_ready`, `background`, `drafting`, `draft`, `view_rect`, `phase`, `animated`, `drive`, `poses` (animated: the shapes as shown now), `mask_keys`, `lasso_curves`, `follow` |
| `mask_add_shape` | `shape` | `[type = "rect", min = [x, y], max = [x, y]]`, `[type = "polygon", points = [[x, y], ...]]` or `[type = "ellipse", center, radius, angle]`; `mode` add / subtract / intersect, `feather`, `grow` (pixels of the output), `name`, `color` "#rrggbb" (IDs) |
| `mask_set_shape` | `index`, `shape` | only the keys given change |
| `mask_remove_shape` | `index` (-1: all) | |
| `mask_lasso` | `points` (anchors, >= 3), `width`, `mode`, `add` | a lasso outline through the anchors along the edges of the Background, added as a shape (`add` 0: only returned) |
| `mask_snap` | `point`, `radius`, `corners` | the nearest corner (or edge) of the Background |
| `mask_value` | `points` | the mask 0..1 and the IDs colour (0xRRGGBB as a number) at points, as the outputs give them |
| `mask_tool` | `tool`, `view`, `snap_points`, `lasso_curves`, `curve_tolerance` | select, rect, ellipse, polygon, freehand, lasso / overlay, picture, mask, ids; a lasso / freehand outline fitted with curves |
| `mask_smooth` | `index`, `point`, `smooth` | a point smooth (handles along the line between its neighbours) or a corner |
| `mask_keys` | `index` (-1 / none: the whole mask) | `keys`, `phase`, `drive`, `beats`, `pingpong`, `pose` (the shape as shown now) |
| `mask_add_key` | `index`, `time`, `key` | a key holding what it is at `time` (default the phase now), then the values of `key` set |
| `mask_set_key` | `index`, `key_index`, `key` | `time`, `ease` (linear, in, out, inout, smooth, hold), `offset` [x, y], `scale` [x, y] or a number, `rotation` (degrees clockwise), `opacity`, `feather`, `grow`, geometry (`points`, `handles`, `type`, `center`, ...) |
| `mask_remove_key` | `index`, `key_index` (-1: all) | a shape without keys stays as it was shown |
| `mask_phase` | `phase`, `drive`, `beats`, `pingpong` | `drive`: phase (the *Phase* control), beats (a loop of `beats` beats of the timeline), clip (`clip_position` when it is a timeline clip) |
| `mask_follow` | `index`, `follow`, `locked`, `on`, `rate`, `radius`, `keep_form`, `rotate`, `scale`, `resnap` | the live video lasso: shapes with `follow` re-snap onto the moving Background |
| `mask_svg` | `import_path` or `text`, `fit`, `replace`, `export_path` | SVG in (contain / stretch / bounds / none) and out; without arguments it returns the SVG text |
- Curves: a polygon shape has `handles` [[in x, in y, out x, out y], ...] (offsets from each point, normalized) and
  `smooth` [0 / 1, ...] when a segment is curved; segment i is the cubic from point i (+ its out handle) to point i + 1
  (+ its in handle). No `handles` = straight lines.
- Animation: `shapes` / `mask_shapes` give the model (a shape with `keys` keeps its geometry in them; its own
  `points` are only where it was last stored); `poses` / `pose` are what the mask is made of at the phase now. A
  change of an animated shape (mouse, `mask_set_shape` with geometry, feather, grow or opacity, the panel) is written
  into the key at the phase now, a key is made there when there is none. Key transforms turn and scale round the mean
  of the shape's points, keys of the whole mask round the middle of the output. Different point counts morph
  (resampled outlines). The phase is set in `update()` from the drive every frame: to test a pose at a phase, use
  `mask_phase` with `drive` phase, or `set_transport` `position` with drive beats (phase = position mod beats / beats).
- Coordinates are 0..1 from the top left of the picture as a shader sees it. Every query that changes shapes is one
  step of the undo history (`Mask: ...`), like the mouse; an asset makes such steps with `engine.env.edit_step(name,
  undo_fn, redo_fn, key)` (generators.shio).
- `mask_lasso` and `mask_snap` need the edges of the Background: `edges_ready` 0 means not read yet (they are read in
  the next frame after the lasso tool is picked or a lasso starts; the query asks for it and says to try again).
- Driving it with real input: `view_rect` is where the picture is on the screen (window pixels), so a point (x, y)
  of the picture is at `view_rect[0] + x * view_rect[2]`, `view_rect[1] + y * view_rect[3]`. The keys (L, P, X, S,
  Enter, ...) need the focus: click into the editor first. `_testing/linux_app/smoke.py` phase `maskdraw` does it.
- A PNG as Background needs its *Flip Y* on (`set_local_control` `Flip Y` 1 on the picture): MaskDraw shows what a
  shader sees, and a picture file is upside down there. No MCP tool links two generators: the smoke phase writes the
  link into `controls.json` of a saved project and loads it (`links.local` of the Patchview: `<img>/OUT` -> `<maskdraw>/IN`).
- Controls (`set_local_control`): `maskdraw@Tool`, `maskdraw@View` (indices), `maskdraw@Snap points`,
  `maskdraw@Invert`, `maskdraw@Overlay`, `maskdraw@Snap radius`, `maskdraw@Lasso width`, `maskdraw@Lasso spacing`;
  `maskdraw_shape@Mode` / `Feather` / `Grow` / `Opacity` / `Follows` / `Lock` act on the selected shape (without one:
  on new shapes); `maskdraw@Drive`, `maskdraw@Phase` (linkable: an envelope or an LFO into it moves the mask),
  `maskdraw@Phase now` (an output: the phase whatever drives it), `maskdraw@Beats`, `maskdraw@Ping-pong`, `maskdraw@Lasso curves`, `maskdraw@Curve tolerance`,
  `maskdraw@Follow the picture`, `maskdraw@Follow rate`, `maskdraw@Follow radius`, `maskdraw@Keep form`,
  `maskdraw@SVG file`, `maskdraw@SVG fit`; `maskdraw_key@...` are the fields of the selected key.
- Following (`mask_follow` `on` 1, a shape with `follow` 1): each step reads the Background at most 640 px wide (a
  blit, then `glReadPixels`), finds the edges along the outline's normals and moves the shape as a whole (`keep_form`
  0: its points too). Moves under 0.3 px of that copy are ignored (no drift on a still picture), `locked` shapes and
  shapes with keys never move. In a script test, `edge_picture(buffer, w, h)` then `track_step()` does one step on a
  picture of your own (`_testing/nanogui/mask_editor.shio`).
- SVG: the import reads path (all commands, arcs as curves), polygon, polyline, rect (rx / ry), circle, ellipse, `g`
  and `svg` with `transform`; `defs`, `clipPath`, `mask`, `symbol`, text, `display:none` are left out; `use` is not
  resolved. A compound path: a subpath inside an odd number of others is a hole. The export writes `data-mask-mode`,
  `-feather`, `-grow`, `-opacity`, `-name`, `-visible`, which the import reads back; keys are not exported (the shapes
  as shown now). Paths of `import_path` / `export_path` are relative to the VibeVJ folder (the working directory).
