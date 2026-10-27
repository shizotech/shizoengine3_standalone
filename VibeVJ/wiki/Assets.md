# Assets

Everything you can drag into a view is an asset: a generator, a shader, a view, a picture, a video. This page lists
what comes with VibeVJ and where it is in the *Assets* tab of the [sidebar](The-Screen.md#assets-tab).

![The Assets tab of the sidebar](media/assets.png)

## Find and use an asset

1. Open the *Assets* tab. The icon in front of a name says what it is:

   | Icon | What it is |
   |---|---|
   | Cube | A generator |
   | Wand | A shader |
   | Four squares | A view (*Clipview*, *Patchview*, …) |
   | Diagram | A mapping tool |
   | Light bulb | A fixture or a fixture effect |
   | Stacked layers | A preset |

   An asset is a folder too, but you rarely open it: its arrow is faint. A name too long for the sidebar ends in "…";
   rest the mouse on it to read all of it.
2. Open a folder with its arrow, or type part of a name into *Filter*.
3. Drag the asset into a view. Where it lands decides what it becomes:
   - in a [Patchview](The-Screen.md#views-and-tabs): a window of its own;
   - in an [area](The-Screen.md#dropping-an-asset): the view of that area, a split or a tab;
   - in a cell of a [Clipview](Clipview.md#make-a-clip): a clip;
   - on a [CueList](CueList.md#add-cues): a cue.

How a generator window works is on [Generators](Generators.md). Your own settings of an asset can be kept as a
[preset](Generators.md#presets): it shows up in the folder `presets` inside the asset.

## The folders

| Folder | What is in it |
|---|---|
| `Generators` | Values, audio, network and helpers: see below. |
| `Shaders` | Pictures and effects: `Sources`, `Effects`, `Utilities`. |
| `Views` | The views: *Clipview*, *CueList*, *Patchview*, *Tabview*, with their presets and saved layouts. See [Views and tabs](The-Screen.md#views-and-tabs). |
| `Mapping` | *MapLab*, *LEDMapper*, *MaskTransform*. See [Mapping](Output-and-Devices.md#mapping). |
| `Fixtures`, `FixturesEffects` | Lamps and effects over them: the Phaser, FixtureState, and the [lighting desk](Lighting-Desk.md) (Programmer, Executors, LampValues, CueTrigger). See [Fixtures](Output-and-Devices.md#fixtures). |
| `Textures`, `Videos` | Pictures and [video files](Video.md). Each opens as a generator with an *Out* port. |
| `FFGL` | FFGL plugins you add yourself (`.dll`, `.bundle`, `.so`). See [FFGL plugins](#ffgl-plugins). |

## Generators › Math

Sources of moving values. Link their *Output* into anything ([Linking](Linking.md#make-a-link)). Each can run free or
in step with the [timeline](Timeline.md).

| Generator | What it gives |
|---|---|
| *SineGenerator* | A sine wave: *Frequency*, *Bias*, *Gain*, *Saturation*. *Mode* is *Free* or *Sync*. |
| *TriangleWave*, *SawtoothWave*, *SquareWave* | The same with another shape. |
| *LFOSynth* | Up to 8 waves in one window (*Add wave*), each with its own *Wave* shape, *Frequency*, *Phase*, *Bias*, *Gain* and *Output*. All of them rise and fall with the *Envelope*: *Trigger* starts it, *Release* lets it fall to 0. Until the first *Trigger* the waves pass unchanged. |
| *NoiseGenerator* | Random values: *Type* is *White* or *Pink*, *Rate* sets how often a new value comes. |
| *LFOClock* | A pulse on every beat that falls back to 0. |
| *StepChaser* | A step sequencer in a table: the bar (*Bar length*) is cut into *Steps*, every step has a *Value* or *Hold*, a *Fade in* and a *Fade out*. Every block (*Add block*) has its own *Output*. *Mode* is *Sync* or *Free*. |
| *PathPad* | A point that travels along a path of points you set on a pad (click to add, drag to move, right-click to remove), as *X* and *Y*. *Curve* rounds the path, *Path* is *Loop* or *Ping-pong*, one run takes *Duration* beats. *Output mode* *Relative* adds the path to *Input X* / *Input Y*. |

## Generators › Utility

| Generator | What it is for |
|---|---|
| *ShowControls* | Your own surface of faders, knobs, buttons and toggles for a show. See [Show controls](#show-controls). |
| *XYPad* | A field you click or drag on: the point sets *X* (left 0 to right 1) and *Y* (top 0 to bottom 1). A link into *X* or *Y* moves the point. |
| *XYPathPad* | A point that walks along a path of points you drag on a field: one walk takes *Travel* beats, *Loop* or *Bounce*, the path *Closed* or *Open*. *Output X* / *Output Y* (-1 to 1) mix it with *Input X* / *Input Y*. |
| *CurvePad* | A point that walks along a closed path of points you set on a pad, as *X* and *Y*: *Curve* rounds it, one run takes *Duration* beats, free or on the beat. |
| *XYPositions* | A list of positions that glide into one X / Y output. |
| *EnvelopeOutput* | A curve you draw, played free or on the beat: one run takes *Duration* beats, the line shows where it plays, *Output* gives its value. |
| *StepChaser* | A step sequencer on the beat: the bar (*Bar length*) is cut into *Steps*, every step has a *Value* (or *Hold*), a *Fade in* and a *Fade out*. Every block (*Add output*) has its own *Output*. |
| *Button-Feld*, *Control-Button-Matrix* | A grid of buttons to link from: 3 × 3, or *Rows* × *Columns*. The *Settings* of a button hold its name, the mode (*Flash*, *Relative*, *Absolute*), *Value*, *Input* and the *Output* to link. |
| *ColorSelector* | Colours for several targets: pick one per row, the target sends it as *RGB* and *HSV*, with *Brightness* and *Smoothing*. *Lamps* under the name of a row colours a group of the fixture setup directly ([lighting desk](Lighting-Desk.md#groups-as-link-targets)). |
| *control4* | Four plain values, *Control 1* to *Control 4*, to set by hand or MIDI and link. |
| *quantize* | Rounds *Input* down to a number of *Steps* (4: 0, 0.25, 0.5, 0.75) as its *Output*. |
| *value_text* | Shows the value linked into *Input* as text, numbers with up to three decimals. |
| *textbox* | A note. It is saved with the project. |
| *Chat* | The AI chat of the sidebar as a window. |

### Show controls

*ShowControls* (`Generators` › `Utility`) is a surface you lay out yourself, for the controls you play during a show.

1. Drag *ShowControls* into an area or a Patchview. It starts in edit mode with one fader.
2. *Edit* on: *Fader*, *Knob*, *Button* (on while it is held) and *Toggle* (on and off), each with a plus, add a control. Drag a
   control to move it, drag its lower right corner to resize it, × removes it. Everything snaps to a 10 px grid.
3. *Edit* off: the controls are played. A fader and a knob go up and down with the mouse (Shift: finer), a double
   click types a value.

Each control is a normal control of the program: [link](Linking.md#make-a-link) it, map it to MIDI, rename it in its
options (tab *Main*, the name field), set its range and envelope there. Several surfaces make a show UI: put them into
the areas or tabs of a view tab, or as windows into a Patchview. The surface, its controls and their values are saved
with the project.

## FFGL plugins

FFGL plugins, for example the ones made for Resolume, run in VibeVJ like a shader. Put the plugin into the folder
`VibeVJ/assets/FFGL/` (`.dll` on Windows, `.bundle` on macOS, `.so` on Linux); it shows in the *Assets* tab under
`FFGL`.

1. Drag the plugin into a Patchview or an area, or onto a clip of the [Clipview](Clipview.md) to stack it as an effect.
2. Its window is the one of a shader: preview, *Out*, and in *Settings* and *Outputs* the render size, Spout, NDI and
   the display.
3. The section *FFGL* in the *Control* tab holds its parameters as controls: sliders with the range the plugin gives,
   buttons, lists and text fields. Link them and map them to MIDI like any control.
4. An effect has the port *In 1* (a mixer also *In 2*): link a picture into it. In a clip or in the effects of a MapLab
   output it gets the picture before it by itself.

The time and the beat of the timeline go to the plugin. Only FFGL 2 plugins load (Resolume 7 and later); an older one
says so in its window.

## Generators › Audio and Network

| Generator | What it is for |
|---|---|
| *AudioInputAnalysis* | Beat, tempo, energy and breaks from the music: [Audio](Audio.md). |
| *ArtnetSender*, *ArtnetReceiver* | Single Art-Net channels out and in: [Art-Net](Output-and-Devices.md#art-net). |
| *NDIReceiver*, *SpoutReceiver* | Video from other programs (Spout on Windows, Syphon on macOS): [Receiving video](Output-and-Devices.md#receiving-video). |
| *ProlinkBridge*, *ProlinkDecks* | Tempo, beat and waveforms of CDJs: [Prolink](Output-and-Devices.md#prolink-cdjs). |

## Generators › output

| Generator | What it is for |
|---|---|
| *RGBMask* | Takes a picture (*In*) and gives the average colour inside the rectangles or lines you draw on it, as *Red*, *Green*, *Blue* and *Out*: a lamp follows a part of the picture. *Clear* removes the shapes. |

## Shaders

A shader makes or changes a picture. Every shader has the [tabs *Control*, *Settings* and *Transform*](Output-and-Devices.md#the-tabs-of-a-shader)
and an *Out* port.

| Folder | What is in it |
|---|---|
| `Sources` | Shaders that make a picture: patterns, 3D, noise, LED looks, shaders that draw with the [sound](Audio.md#fft-texture). |
| `Effects` | Shaders that change a picture: colour, blur and feedback, glow, kaleidoscope, mirror, retro looks. Link a picture into their input, or stack them onto a [clip](Clipview.md#make-a-clip). |
| `Utilities` | *output* shows a picture on a display or projector: [Output and devices](Output-and-Devices.md#show-the-picture-on-a-display-or-projector). *Shaderstack* holds several shaders in one generator. |

**See a shader before you drag it:** rest the mouse on a shader in the list for half a second. A small window beside
the sidebar plays it, with the values its controls start with. It goes when the mouse leaves the shader. An effect
needs a picture to work on, so its window only says so: drop it onto a view with a source to see it.

A double click on a file of a shader opens its code in a tab: see the [code editor](Shortcuts-and-Tips.md#code-editor). Only text files open this way (code, shaders, JSON, Markdown, presets); pictures, videos and sound are dragged onto a view instead.

## Your own files

- **Pictures and videos:** copy them into `VibeVJ/assets/Textures` or `VibeVJ/assets/Videos` (or any folder below
  `assets`), then press refresh in the *Assets* tab.
- **Presets** are written into the asset they belong to.
- **Layouts** you save from a view tab are in `Views` and are offered in every
  [empty area](The-Screen.md#an-empty-area).

## See also

- [Generators](Generators.md)
- [The screen](The-Screen.md)
- [Clipview](Clipview.md)
- [Output and devices](Output-and-Devices.md)
- [Linking](Linking.md)
