# Output and devices

How the picture leaves VibeVJ (a display or projector, NDI, Spout, other generators) and how VibeVJ talks to lights
(Art-Net, fixtures, LED mapping) and to the DJ booth (Prolink).

> Screenshot to add: a shader window on its *Control* tab with *Outputs* open: *Monitor* (*Display mode*, *Display*),
> *Video router*, *Spout* and *NDI stream*, next to the sidebar tab *Devices* with *Network* and *Fixtures* open.

## Show the picture on a display or projector

Every shader generator can send its picture out. A simple way is the shader *output* in `Shaders` › `Utilities`.

1. Drag *output* from the sidebar tab *Assets* (`Shaders` › `Utilities`) into a view.
2. Link the *Out* port of your [Clipview](Clipview.md#the-parts) (or of any generator) into the input of *output*.
   See [Ports](Linking.md#ports).
3. On the tab *Control*, open *Outputs* › *Monitor*.
4. Choose the *Display mode* first: *Fullscreen* or *Window* (a window without a frame).
5. Choose the *Display*: *Display 1*, *Display 2* … The output opens there. *Width* and *Height* are set to the size
   of that display.
6. To stop, set *Display* to *Off*. Closing the output window does the same.

*Display mode* can be changed while the output shows: the output opens again in the new mode.

## The tabs of a shader

A shader generator has three tabs: *Control*, *Settings* and *Transform*.

### Outputs (tab Control)

| Section | Controls | What it does |
|---|---|---|
| *Monitor* | *Display mode*, *Display* | Picture on a display, see above. |
| *Video router* | *Enable router*, *Video router name* | Offers the picture to other shaders by name. In another shader, open *Inputs*, then the input, and pick the name from the list. *No Input* clears it. |
| *Spout* | *Enable Spout*, *Spout name* | Sends the picture to other programs on the same computer. Windows only. |
| *NDI stream* | *Enable NDI*, *NDI name* | Sends the picture over the network as NDI. |

The names start as the shader name plus a short random code, so two outputs never clash. Type your own name to make it
easy to find in the receiving program.

### Render settings (tab Settings)

The tab has the groups *Render*, *Size*, *Format* and *Mask*.

| Setting | What it does |
|---|---|
| *Size* | *Project* (the standard) uses *Target width* and *Target height* from [*Settings* › *Project*](Settings.md#project). *Custom* uses *Width* and *Height* below. |
| *Render scale* | Multiplies the size. 0.5 renders at half size (faster), 1 at full size. |
| *Component format*, *Pixel format* | The format of the picture. NDI always sends 8-bit RGBA; a float picture is converted (values above 1 are cut off). |
| *Render mask* | Turns the mask input on or off. |

How the time of a shader runs (*Free*, *Manual*, *Sync*) is on [Settings](Settings.md#default-sync).

### Transform and projection mapping (tab Transform)

| Control | What it does |
|---|---|
| *X*, *Y* | Moves the picture. |
| *Rotate*, *Zoom* | Turns and scales it. |
| *Flip X*, *Flip Y* | Mirrors it. |
| *Clip UV* | Cuts the picture off where a move, a turn or the zoom pushes it out of its frame. |
| *Projection mapping* › *Edit Grid* | Shows a grid over the picture. Drag its points to fit the picture onto a surface. |
| *Subdivide*, *Reset* | A finer grid; back to the plain grid. |
| *Grid* › *X*, *Y* | How many fields the grid has across and down, 1 at the start. |
| *Fine* › *X*, *Y* | How finely each field is divided, 4 at the start. |

For several slices and outputs with masks and soft edges, use *MapLab*: see [Mapping](#mapping).

## The whole window as NDI

[*Settings* › *Output*](Settings.md#output) › *NDI* sends the whole VibeVJ window as NDI (*Enable NDI*, *NDI name*,
"ProgramOut" at the start).

## Receiving video

*NDIReceiver* and *SpoutReceiver* (in `Generators` › `Network`) bring video from other programs in.

1. Open the list *Select* at the top and pick a sender.
2. Link *OUT* of the generator onward.

- *Flip Y* (NDI) turns the picture upside down.
- *VideoRouter* offers the picture to shaders by name, as a shader does.
- NDI needs the NDI runtime on this computer, Spout works on Windows only: see
  [Troubleshooting](Troubleshooting.md#ndi-not-visible).

## Art-Net

The sidebar tab *Devices*, section *Network* › *Artnet*:

- *ArtNetSync* (on at the start) sends an Art-Net sync after every frame, so all nodes update at the same moment.
- Every Art-Net node that VibeVJ finds on the network gets a section "name [MAC]" with its IP and MAC address.

Two generators in `Generators` › `Network` work with single channels.

| Generator | How to use it |
|---|---|
| *ArtnetSender* | Pick a node in the list *Select device* at the top; its name, IP and MAC show below. Click *Add channel* or *Add 16-bit channel*: each row has *Universe* (0–15), *Channel* (1–512) and a slider *Value* that sends 0–255 (16-bit: 0–65535). × removes a row. *Start universe* and *Start channel* shift all rows. The node is remembered by its MAC address. |
| *ArtnetReceiver* | It listens to all Art-Net on the network, there is no node to pick. Click *ADD CHANNEL* or *ADD 16-BIT CHANNEL*. The slider of a row follows that channel. Click *L* on a row, then move the fader on your console: *U* (universe) and *C* (channel) are filled in. *START UNIVERSE* and *START CHANNEL* shift all rows. |

With the power button off, the sender stops sending and the receiver stops following. *L* still works.

For whole lamps instead of single channels, use fixtures.

## Fixtures

Fixtures are lamps described by a file in `Fixtures` of the *Assets* tab (`Bars`, `MovingHeads`, `Pars` and some
examples). Set them up once per project.

### Set up your lamps

1. In the tab *Assets*, open `Fixtures` and double-click *Setup.menu*. The fixture setup opens in a new tab.
2. Drag a fixture file from `Fixtures` onto "Drop fixtures here" on the left, or onto the grid.
3. Click the fixture name. Its settings open on the right.
4. Set *Total count*, or click *Add New Instance* for each lamp of this type.
5. For each lamp: type a name, pick the Art-Net node in *Select Target*, set *Uni* (universe 0–15), *Adr* (start
   address 1–512) and *Count* (several identical lamps at following addresses).
6. Move the lamps on the grid in the middle to where they hang. They snap to a grid.

The setup is saved with the project.

### Play them

The lamps then appear in the tab *Devices*, section *Fixtures*:

| Part | What it does |
|---|---|
| *Dimmers* | One *Dim* slider per channel. Scales that channel on every lamp of this type. |
| *Flashers* | A slider and a *Flash* button per channel. While *Flash* is held, every lamp takes the slider value on that channel. |
| One section per lamp | A slider per channel. A colour channel has a colour picker; an RGBW colour has sliders for red, green, blue and white. |

Every slider has notches: [link](Linking.md) it to an LFO or the [audio analysis](Audio.md), or map it to
[MIDI](MIDI.md).

### Make a fixture file

*Editor.menu* in `Fixtures` opens the fixture editor.

1. Click *Create new fixture*. Double-click its name to rename it.
2. Click the fixture, then *Add Channel* for each channel, in the order of the DMX chart of the lamp.
3. Give each channel its type: *8-bit*, *16-bit*, *RGB* or *RGBW*.

### Effects over fixtures

*Phaser* in `FixturesEffects` runs one value over many lamps: *Add Target* picks a fixture and a channel, and the
list *INDEX* / *CENTER UV* / *LEFT UV* / *RIGHT UV* sets how the value is spread over the lamps.

## Mapping

Three generators in `Mapping` bring pictures onto surfaces and LEDs. They are tools of their own; this is what each is
for.

| Generator | What it is for |
|---|---|
| *MapLab* | Projection mapping with several inputs, slices and outputs: cut slices out of the inputs, place and warp them with a grid, mask them, blend their edges. Each output has an *OUT* port and a video router. |
| *LEDMapper* | Draws LED segments over a video input, groups them into scenes and sends the colours to Art-Net nodes or fixtures. |
| *MaskTransform* | One mask or warp surface between an *IN* and an *OUT*. |

Their inputs list every picture that is offered by a *Video router*: a shader, a [video](Video.md#controls) or a
receiver with its router on.

## Prolink (CDJs)

Two generators in `Generators` › `Network` read the CDJs through a prolink-bridge ESP32. Both use the same
connection.

- **Prolink Bridge** (*ProlinkBridge*) gives the values of the tempo master deck: BPM, beat and bar, beat and downbeat
  pulses, beats to the next cue, cue ramp, drop pulse, progress, playing, on air, master deck, and *Low* / *Mid* /
  *High* from the waveform.
  - *Sync timeline* (on at the start) makes the [timeline](Timeline.md#sync-the-timeline-from-audio) follow the master
    deck while it plays.
  - *Bar lock* (on at the start) also puts the bar on its downbeat.
  - *Phase offset* moves the beat earlier or later; *Pulse length* sets how long the pulses last (10 to 1000 ms).
- **Prolink Decks** (*ProlinkDecks*) draws the decks with their waveforms, cues and phrases as a video output (*Out*).
  - Each section *Deck 1* … *Deck 4* has *BPM*, *Beat*, *Low*, *Mid*, *High*, *Progress*, *Cue ramp*, *Playing*,
    *On air*, *Phrase ramp*, *Buildup* and *Drop*. These are [pure outputs](Linking.md#pure-outputs): link from them,
    not into them.
  - The section *History* lists the tracks that were played, with *Save CSV*, *Save TXT* and *Clear*.
  - Keys on its picture: H shows the history, + and - zoom, 0 resets the zoom.

*Source* (in the section *Settings*) is *USB* (finds the ESP32 by itself, or set *Port*), *Demo* (plays a recorded
set, no hardware) or *Network* (a relay ESP32 over ShizoNet). The line at the top shows the connection or what is
wrong: the messages are on [Troubleshooting](Troubleshooting.md#esp32-not-found).

## Shizonet

*Devices* › *Network* › *Shizonet* switches ShizoNet on or off (on at the start). Off stops VibeVJ from looking for
ShizoNet devices and from talking to them; Art-Net keeps running. ShizoNet is used by the ESP32 sources of
[Audio](Audio.md#source) and Prolink when they come over the network.

## See also

- [Assets](Assets.md)
- [Audio](Audio.md)
- [Video](Video.md)
- [Linking](Linking.md)
- [Clipview](Clipview.md)
- [Settings](Settings.md)
- [Troubleshooting](Troubleshooting.md)
