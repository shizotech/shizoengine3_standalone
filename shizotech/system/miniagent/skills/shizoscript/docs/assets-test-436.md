# Assets (#436): test on Windows and macOS

[#436](https://github.com/shizotech/shizoscript3_source/issues/436): "Fix broken assets (some shaders are not
compiling / buggy). Finish and polish all assets. Unify the looks of the generators." Branch
`claude/github-issue-436-c6p5qu`. Everything was found and checked on Linux in a container, with software OpenGL
(Mesa llvmpipe) under Xvfb. What a container cannot show (a real GPU, Apple's GLSL compiler, sound, Spout, NDI, an
Art-Net node, a Retina screen, a person moving the mouse) is this checklist.

**No C++ changed**: only scripts (`.shio`), shaders (`.glsl`), Python and Markdown. The binaries of `main` run the
branch as they are; no build is needed to test it (on a Mac `setup_mac.sh --build` still bundles the new scripts).

Write the results into a section *Results* at the end of this file (machine, GPU, driver, what passed, what not,
screenshots for anything that looks wrong), or as a comment on #436.

---

## What changed

### Shaders (29 assets, and the shader loader)

Found by loading every shader in the app and looking at the picture (`_testing/linux_app/look_assets.py`); all
272 already compiled before.

| Kind of bug | Shaders | Before → now |
|---|---|---|
| Control does not fit the uniform type (slider on an `int`, button on a `float`, enum on a `float`): the engine sets a uniform with the type of the control, so it did nothing and the uniform stayed 0 | PulseFractal, Bubble, Kaleidoscope (effect), PixelSort, HSVAdjust, BasicTime, Audio/kaleidoscope, FeedbackFlow | controls do nothing, PulseFractal / Bubble black → counts are `//@int`, modes `//@enum` with named options |
| Colour / value without `value=` | ChaseLights, PulseRings, SeqSweep, GridMatrixChase, ParticleStorm, HelloWithControls, Effects/Examples (3), mix, izotope, 3drgb | black at the start → a default |
| A uniform nobody sets | Bubble (`time`, `resolution`), ParticleStorm (7 settings), Aurora (presets), design_thing (camera) | black / one look only → controls |
| `iDate` never set by the engine | DateTime (and colors, beat) | clock 00:00 → the time |
| `//@text` not in the loader | Text | nothing → the text field works |
| `//@enum ... value=2` ignored | every enum with a default other than the first | first option → the default |
| Wrong logic | GrayScott, ReactionDiffusion (passes swapped, never started, wrong maths), FeedbackSDF / FeedbackFlow (ran up to white), 8bit (passes wired wrong), altair (trail read an unbound input), Grid, Matrix, PulseFractal (drew nothing), FireworksBurst (one spark covered the picture), MultiStepSeq (played once), PlasmaWaves (flat without sound), DateTime (wrong 7-segment digits), Text (upside down, cut), fluidstream (white background) | see the commits |

Loader (`engine/generators/extensions/glsl/shader_loader.shio`): shader controls show a caption made from the
uniform name (`bg_colour` → *Background colour*; the uniform stays the ID); the ports are *In* / *In 2* /
*Channel 0* / *Out* (also in the picture and video windows). `compile_scripts/check_glsl.py` fails all the
annotation mistakes above now, and `SHADER_GUIDE.MD` has the rules.

### Generators (24 assets, the Cue List, the sidebar)

The Shizo UI rules (`design/README.md`) for every generator: sentence case captions, units, pure outputs, segmented
switches, theme colours, 28 px rows that fill the window, tooltips. **Control IDs and save keys did not change**
(links, MIDI mappings and projects keep working), except LFOSynth's *Release* slider, which had the ID of the
*Release* button and could never be linked (its value still loads).

Finished or fixed: XY Pad (drew nothing), RGBMask (always black), CurvePad (no point could be set), PathPad (closed
shapes, Ping-pong), EnvelopeOutput (bent points), LFOSynth (Trigger / Release by link, removed waves, links after a
load), ArtnetSender (sent to the first node instead of the picked one), ArtnetReceiver (learn never fired),
NDIReceiver (a status line; an old receiver stayed in the window), SpoutReceiver ("Windows only" elsewhere), Button
field / Control button matrix (flash buttons stuck, the matrix lost its buttons on resize), Step Chaser (table
cleared on every slider move), ColorSelector, quantize (division by 0), value_text (`0.500000`). The Cue List shows
the running cue in green (`live`) instead of amber. Sidebar *Devices › Network*: *Art-Net*, *Art-Net sync*,
*ShizoNet*, one line "IP · MAC" per node.

### Checked on Linux

`check_glsl.py` 272/272, `check_assets.sh` 63/63, `shz --check __init__.shio`, `triage_assets.py` (every generator
loads, saves, loads again with its values), `smoke.py static generators projects` (passed; its 10 warnings are the known ones: #330 / #204, assets that old projects name and that no longer exist), `look_assets.py` over every
shader and generator (pictures looked at), wiki links.

---

## Phase 0: get the branch

```
git fetch origin claude/github-issue-436-c6p5qu
git checkout claude/github-issue-436-c6p5qu
```

- **Windows**: start VibeVJ from the checkout: `cd _shizoengine3` and `shz __init__.shio` (the installed shz of
  `main` is fine).
- **macOS**: `sh shzscript_macos/setup_mac.sh --build` (bundles the branch's scripts and runs every test), then
  `cd dist/VibeVJ_macos_arm64 && ./VibeVJ.out`. Or with an installed shz: `cd _shizoengine3 && shz __init__.shio`.

## Phase 1: automatic checks

- [ ] `python3 compile_scripts/check_glsl.py` → `272/272 shaders compile`. Needs `glslangValidator`
      (macOS: `brew install glslang`; Windows: it comes with the Vulkan SDK, put its `Bin` folder on the `PATH`).
- [ ] macOS: `setup_mac.sh --build` ends without an error.

## Phase 2: shaders on a real GPU

macOS (Apple's OpenGL 4.1 compiler) is the strict one; Windows with NVIDIA accepts more. Watch the log window /
console for `shader: Fragment shader compile failed` while adding them.

- [ ] Drag each of these into a Patchview (Assets › Shaders) and check the picture. Press Play in the timeline:
      several follow the beat.

  | Shader | Should show |
  |---|---|
  | Sources/3D/PulseFractal | a blue Sierpinski tetrahedron, turning and pulsing; *Fractal depth* 2–8 changes the detail |
  | Sources/Basic/Grid | a grid of lines that turns and bends |
  | Sources/Basic/Matrix | green digital rain in columns |
  | Sources/Basic/ParticleStorm | an orange burst of particles; the sliders change count, speed, size |
  | Sources/Basic/Aurora | green aurora; *Layers*, *Colours*, *Stars*, *Shape* are lists |
  | Sources/Basic/DiscoBlocks, SeqBlocks | blocks that blink with the beat (dark half of each beat in *Instant*) |
  | Sources/Patterns/Bubble | coloured arcs moving up |
  | Sources/Sequences/ChaseLights, PulseRings, SeqSweep, GridMatrixChase, MultiStepSeq | chases and rings in colour (MultiStepSeq loops red → green → blue) |
  | Sources/LED/GrayScott, ReactionDiffusion | spots that grow into a coral / maze pattern (GrayScott: many seeds; ReactionDiffusion: one in the middle) |
  | Sources/LED/FeedbackSDF, FeedbackFlow | blue blobs with trails, **not** white |
  | Sources/LED/FireworksBurst | small bursts of sparks every few beats, falling down |
  | Sources/Simulations/fluidstream | two coloured streams on black |
  | Sources/VJ/PlasmaWaves | moving colour waves also without sound |
  | Sources/utility/DateTime | the local time (check all digits 0–9 over a while, and the date formats) |
  | Sources/utility/Text | `HTTP`; type another text into *Text* in Controls, try *Scroll speed* |
  | Sources/Examples/HelloWithControls | a pattern, not black |
  | Sources/Audio/8bit, altair | 8bit: dots through blur, warp and a CRT look; altair: a scene with a soft trail |
  | Effects/Kaleidoscope/Kaleidoscope, Effects/Retro/PixelSort, Effects/Color/HSVAdjust | with a picture linked into *In*: *Mirror*, *Direction* / *Luminance function*, *Clip* are lists and work |

- [ ] The controls of any shader read as plain words (*Background colour*, not `bg_colour`), the ports *In* /
      *Out*. A project saved on `main` still has its shader values and links.
- [ ] Sound: start the audio analysis (*AudioInputAnalysis*), link its FFT texture into *Channel 0* / *Audio* of the
      shaders in `Sources/Audio` (beat, disco, hex, hex2, heart, kaleidoscope, wmp_bars, wmp_waveform, Points,
      ParticlesDance, colors, …). In the container they were black for lack of sound: check that each reacts.

## Phase 3: generators

Assets › Generators, each into a Patchview. Look: same row height, sentence case, units, notches, no overlaps.

- [ ] **XY Pad**: click and drag move the dot, X / Y follow (0,0 top left). Link a Sine into X: the dot moves.
- [ ] **XY Path Pad**: the path is walked; start point green, end point (Open) violet.
- [ ] **Path Pad**, **Curve Pad**: click adds a point, drag moves it, right click removes it; Path Pad makes a closed
      shape; *Curve* rounds it; Ping-pong goes there and back.
- [ ] **Envelope Output**: bend a point with the mouse wheel: the output follows the bent curve; the play line moves.
- [ ] **LFO Synth**: *Add wave*, remove the middle one, save, load again: the other waves keep their links. Link a
      button into *Trigger* / *Release*: the envelope follows. *Release* slider links (new ID `Release time`).
- [ ] **Step Chaser** (Math and Utility): change *Steps* by dragging: the table is not cleared on each move.
- [ ] **Button field**, **Control button matrix**: a Flash button pressed and released outside goes off; change
      Rows / Columns: the buttons that stay keep their names and modes.
- [ ] **ColorSelector**, **quantize** (*Steps* 0 not possible, 1.0 is the top step), **value_text** (`0.5`, not
      `0.500000`), **textbox** (saved), **control4**.
- [ ] **RGBMask**: drag a rectangle and a line on the picture, also ending outside it: the shape is where the mouse
      was; *Red* / *Green* / *Blue* follow the picture under the shape.
- [ ] **Cue List**: the running cue has a green bar, not an amber fill.
- [ ] Interface size 150 % and 200 % (Settings › Appearance): rows still fill the windows, nothing overlaps.
- [ ] macOS Retina: XY Pad, Path Pad, RGBMask: the dot / shape is exactly under the mouse.

## Phase 4: devices

- [ ] **Art-Net sender** (a real node, best two): pick the second node of the list: the DMX goes to it, not to the
      first. Save, load with the node switched off, open the list: the node stays picked ("… (not found)").
- [ ] **Art-Net receiver**: press the learn icon (amber), move a fader of the console: *Universe* / *Channel* are
      filled in.
- [ ] Sidebar *Devices › Network › Art-Net*: *Art-Net sync*, each node "IP … · MAC …".
- [ ] **Windows: Spout receiver**: pick a sender, the picture comes; *Size*. **macOS**: it says "Spout works on
      Windows only".
- [ ] **NDI receiver**: status "No sender" / "Waiting for the sender…" / "Connected"; switch senders a few times: the
      picture follows, nothing doubles.

## Results

### Windows (2026-10-21)

Windows 11 Home 26200, i5-13600K, **NVIDIA RTX 4080, driver 617.14** (OpenGL 4.1 context), 3440 × 1440 at 100 %.
`shz` / modules of `main` 9d5920b4 (built 2026-10-21), the branch's scripts. Driven with SendInput + MCP; the shaders
were added to a Patchview over MCP with the timeline playing. Screenshots in `docs/assets-test-436/`.

**Fixed on this branch** (commits "Windows test of #436", "RGBMask: …", "Art-Net sender: …"):

| What | Cause | Fix |
|---|---|---|
| DateTime: digits drawn on top of each other ("14:42" looked like `H 42`, [before](assets-test-436/datetime-before.png)) | default *Glyph pitch* 0.72 is narrower than a glyph with its strokes (0.66 + 0.12) | default 0.9 |
| DateTime: no colon at all on NVIDIA | `sepSDF + 1e9 * (1 - colon_vis)`: the driver loses the distance in float precision | a branch instead |
| DateTime: HH:MM:SS off centre, seconds cut | centred as 7 cells, it has 8 | 8 |
| DateTime: date formats cut on both sides at the default size | 10 cells × 0.28 do not fit 16:9 | the text height shrinks so the widest line fits ([after](assets-test-436/datetime-after.png)) |
| Every `//@button` shader control (Flip Y, Blink colon, GrayScott Auto seed, … 23 in 15 shaders) could be switched on, never off | the loader built it as a momentary button (no `.push(1)`): its callback only fires on the press | `.push(1)` (a toggle, as SHADER_GUIDE.MD says) |
| HSVAdjust and HueRotate recoloured every picture, also at neutral settings ([before](assets-test-436/hsvadjust-before.png)) | broken `rgb2hsv` (wrong constants, swapped `mix` arms; checked against Python's colorsys) | the usual formula |
| Points and ParticlesDance invisible (preview and mix), also with sound | alpha stayed 0 | alpha 1 ([after](assets-test-436/points-after.png)) |
| Path Pad, Curve Pad, Envelope Output: a right-click on the pad also opened the view's menu ([screenshot](assets-test-436/pad-rightclick-menu.png)) | the screen opens the menu of the nearest widget with `on_context_menu` after any right-click | the pad has an own, empty one |
| LFO Synth: a linked Trigger kept the envelope at the start of the attack | a link calls the button callback on every frame while its source is high: restart each frame | Trigger / Release act on the rising edge (per `update()`) |
| RGBMask: every shape started in the top left corner of the picture ([before](assets-test-436/rgbmask-before.png)) | the press comes as a `Vector2i`: `pos.x / w` was an integer division (0) | `std.float(pos.x) / w` |
| RGBMask: Red / Green / Blue were always the colour of the whole picture, also without a shape | the mask was passed to `avg_shader.input()` as a texture; `input()` takes a picture source and dropped it, so the averaging read the picture as its mask | the mask shader itself ([after](assets-test-436/rgbmask-after.png)) |
| Art-Net sender: a saved node that answered only after the load never got DMX (see Phase 4) | only a moved fader looked for the node | looked for once a second, every row sent when it is found or picked |

All re-checked in the app after the fix; `check_glsl.py` 272/272 and `shz --check` pass after the changes.

**Phase 1**: `check_glsl.py` (glslang 12.2 from MSYS2) **272/272** before and after the fixes.

**Phase 2** (shaders, RTX 4080): no compile error in the log for any of them. Pass: PulseFractal, Grid, Matrix,
ParticleStorm, Aurora, DiscoBlocks, SeqBlocks, Bubble, ChaseLights, PulseRings, SeqSweep, GridMatrixChase, MultiStepSeq
(cycles red / green / blue), GrayScott (full coral pattern at full size; the small preview looks like noise),
ReactionDiffusion (one spot in the middle growing), FeedbackSDF / FeedbackFlow (blue, not white), FireworksBurst (small
bursts every few beats), fluidstream, PlasmaWaves, Text (`HTTP`), HelloWithControls, altair, DateTime (after the fixes:
every format, Flip Y, blinking colon). Effects with a picture in *In*: Kaleidoscope (Off / Mirror / Bloom: Bloom only adds
a small wobble), PixelSort, HSVAdjust (after the fix), HueRotate (after the fix). Captions read as words, ports *In* /
*Out* / *Channel 0*. **A project saved with the scripts of `main`** (Kaleidoscope segments 5 / Bloom, DateTime format /
pitch / Flip Y, HSVAdjust hue / clip, Bubble count, PulseFractal depth, Aurora intensity, two links) loads on the branch
with every value (the old slider values land in the new int / list controls) and both links.
**Sound: only partly checked**: this PC has no music input (webcam mic, NVIDIA Broadcast mic); the analysis
normalises the noise up to energies of 1.0 with a jumping BPM. With that, hex, hex2, wmp_bars, wmp_waveform, kaleidoscope,
colors, Points (after the fix) react; beat and disco are plain white (saturated), heart is very dim, 8bit stays black.
Needs a check with real music.

**Phase 3** (generators): all load without an error. Pass: XY Pad (dot under the click, 0,0 top left, clamps, a linked
Sine moves it), XY Path Pad, Path Pad / Curve Pad (add, drag, right-click remove; Path Pad keeps its first and last point
by design), Envelope Output (click a point, then the wheel bends it; output and play line follow), LFO Synth (*Add wave*,
remove the middle one, save, load: the other waves keep their links; Trigger by link after the fix; *Release time*
links), Step Chaser (values kept while *Steps* is dragged 4 → 16), Button field Flash (released outside goes off),
Control button matrix (3×3 → 2×4: the modes of the remaining buttons stay), value_text (`0.5`).
Look issues, not fixed (layout decisions): LFO Synth wave rows clip the frequency (".25 per beat",
[screenshot](assets-test-436/lfosynth-clipped.png)); the block Step Chaser cuts "Sync" / "Free" / "Hold" to "Sy…" "Fr…"
"H…" and its steps run out of the window ([screenshot](assets-test-436/stepchaser-cramped.png)); the "Change" lists of
the other Step Chaser draw their arrow over the text; the Settings popup of a Button field button is cut at the bottom
of the window; the "…" menu of a maximized window at the right edge of the screen is cut. "Layout of nanogui.window …
did not settle" is logged once per start.
Also pass (second round): quantize (*Steps* 0 becomes 1; Input 1.0 gives the top step, 0.75 with 4 steps, as its code
comment says), value_text with a linked Sine (`0.659`, `0`, `0.609`), textbox (the text comes back after save / load),
control4, ColorSelector (a colour sets RGB / HSV of its target, a column header sets every target, the choice is marked,
targets / colours are saved), RGBMask after the fix (no shape: 0; rectangle and line exactly under the mouse, a line
released outside ends at the edge; the colour follows the picture under the shape), Cue List (the running cue has the
green bar and tint), interface size 150 % and 200 % (rows fill the windows, nothing overlaps, no "did not settle"; at
150 % the XY Pad dot and an RGBMask shape are exactly under the mouse; at 200 % the empty area shows the compact picker).
Look issues: ColorSelector at its default size gives the colour grid about 100 px, one column of huge circles and a
scroll bar; maximized it is fine ([screenshot](assets-test-436/colorselector-default-size.png)). The Cue List column cuts
"Master" / "Transition" to "Mas…" / "Tran…". `vibevj_describe_layout` lists no picker tiles in the compact picker.

**Phase 4** (devices). No real Art-Net hardware here: two Art-Net nodes (127.0.0.2 "NodeA 436", 127.0.0.3 "NodeB 436")
and a console (127.0.0.4) were simulated with [fake_artnet.py](assets-test-436/fake_artnet.py) (ArtPollReply to the
app, ArtDmx logged per node). Two more nodes of the local network showed up as well (SHZ_AI_NODE, SHZ_RT_TEST,
SHIZOV3); nothing was sent to them.
- Sidebar *Devices › Network › Art-Net*: *Art-Net sync*, each node with "IP 127.0.0.3 · MAC 02:36:00:00:00:B2"
  ([screenshot](assets-test-436/sidebar-artnet.png)). Pass.
- **Art-Net sender**: NodeB picked (third entry of the list): all ArtDmx went to 127.0.0.3 (channel 1 = 127 for 0.5),
  none to NodeA ([screenshot](assets-test-436/artnet-sender-nodeb.png)). Saved by its MAC; loaded with the nodes off
  the list says "02:36:00:00:00:B2 (not found)" ([screenshot](assets-test-436/artnet-sender-not-found.png); the MAC,
  the name is not saved). **Fixed**: when the node came back, the sender never found it again (only a moved fader
  looked for it), so it got nothing and the list kept saying "not found". The sender now looks for a missing saved
  node once a second and sends every row once when it is found or picked ([after](assets-test-436/artnet-sender-found-again.png)).
- **Art-Net receiver**: learn (amber), then the console moves channel 10 of universe 3: *Universe* 3 / *Channel* 10 are
  filled in and the value follows ([screenshot](assets-test-436/artnet-learn.png)). Pass. Learn stays on until it is
  clicked again (by design: another fader moved later is learned too).
- **Spout receiver** (Windows): "Pick a sender…"; no Spout sender on this PC, picture not checked.
- **NDI receiver**: status "No sender"; no NDI sender here, switching senders not checked.
- Small look issues: the row captions *Universe* / *Channel* are cut to "Univ…" / "Chan…" in both Art-Net generators.
