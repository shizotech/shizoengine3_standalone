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
5. Choose the *Display*: *Display 1*, *Display 2* …, each with the name of the display. The output opens there.
   *Width* and *Height* are set to the size of that display.
6. *Picture*: what happens when the picture and the display have another shape. *Stretch* (the standard) fills the
   display and distorts the picture, *Fit* shows all of it with black bars, *Fill* fills the display and cuts the
   edges off.
7. To stop, set *Display* to *Off*. Closing the output window does the same.

*Display mode* and *Picture* can be changed while the output shows.

The project keeps the name of the display. At another venue, where the displays are connected in another order, the
output goes to the display with that name. When it is not connected, the output stays off and the [Log](Troubleshooting.md#the-log)
says so: it never lands on the screen VibeVJ itself is on.

## The tabs of a shader

A shader generator has three tabs: *Control*, *Settings* and *Transform*.

The section *Controls* of the tab *Control* holds the shader's own controls. Their names come from the shader's code in
plain words: `bg_colour` shows as *Background colour*, `timeMultiplier` as *Time multiplier*. Its inputs are *In* (or
*In 1*, *In 2*, …, *Channel 0*, …), its picture goes out at *Out*.

### Outputs (tab Control)

| Section | Controls | What it does |
|---|---|---|
| *Monitor* | *Display mode*, *Display*, *Picture* | Picture on a display, see above. |
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

## Blackout

When something goes wrong on the screen or in the lights, press **Ctrl + B** (Cmd + B on a Mac) or the Blackout button
in the bar of the [timeline](Timeline.md#the-transport-bar), next to the show mode lock. Everything that leaves VibeVJ
goes black at once:

- the Display outputs of shaders and of MapLab (the picture on a projector or monitor),
- the NDI of every shader and of the whole window, and the Spout of every shader,
- the brightness and colour channels of your [fixtures](#fixtures) and every [LEDMapper](#ledmapper).

Pan, tilt, gobos and the other channels of a fixture stay where they are, so moving heads do not swing. The views in
VibeVJ keep showing everything, so you see what will come back. The button is marked while the blackout is on.

Press Ctrl + B or the button again: the outputs come back with a fade, one second at the start. Change it in
[*Settings* › *Output* › *Blackout*](Settings.md#output).

- It works in show mode.
- The button has a notch: map it to a MIDI pad ([MIDI](MIDI.md)) to have it under your hand.
- A blackout is not part of the project: opening a project keeps the outputs as they are.
- *ArtnetSender* sends exactly what you give it: the blackout does not change it.

## The whole window as NDI

[*Settings* › *Output*](Settings.md#output) › *NDI* sends the whole VibeVJ window as NDI (*Enable NDI*, *NDI name*,
"ProgramOut" at the start).

## Receiving video

*NDIReceiver* and *SpoutReceiver* (in `Generators` › `Network`) bring video from other programs in.

1. Open the list *Pick a sender…* at the top and pick a sender, or type its name into *Sender*.
2. Link *Out* of the generator onward.

- *Flip Y* (NDI) turns the picture upside down. Under the list NDI shows whether it is connected.
- *Size* shows the width and height of the picture that comes in.
- *Video router* offers the picture to shaders by name, as a shader does.
- NDI needs the NDI runtime on this computer, Spout works on Windows only (on other systems *SpoutReceiver* says so):
  see [Troubleshooting](Troubleshooting.md#ndi-not-visible).

## Art-Net

The sidebar tab *Devices*, section *Network* › *Art-Net*:

- *Art-Net sync* (on at the start) sends an Art-Net sync after every frame, so all nodes update at the same moment.
- Every Art-Net node that VibeVJ finds on the network gets a section "name [MAC]" with its IP and MAC address.

Two generators in `Generators` › `Network` work with single channels.

| Generator | How to use it |
|---|---|
| *ArtnetSender* | Pick a node in the list at the top (*No node* until you do); its IP and MAC show below. Click *Add channel* or *Add 16-bit channel*: each row has *Universe*, *Channel* (1–512) and a slider *Value* that sends 0–255 (16-bit: 0–65535). × removes a row. *Start universe* and *Start channel* shift all rows. The node is remembered by its MAC address; until it answers, the line below says "not found on the network". |
| *ArtnetReceiver* | It listens to all Art-Net on the network, there is no node to pick. Click *Add channel* or *Add 16-bit channel*. The *Value* of a row follows that channel (a [pure output](Linking.md#pure-outputs)). Click the crosshair of a row (learn, amber while it waits), then move the fader on your console: *Universe* and *Channel* are filled in. *Start universe* and *Start channel* shift all rows. |

With the power button off, the sender stops sending and the receiver stops following. Learn still works.

For whole lamps instead of single channels, use fixtures.

### Network cards

*Devices* › *Network* › *Network cards* chooses the network cards Art-Net and ShizoNet use: VibeVJ looks for nodes over
them (ArtPoll, ShizoNet), sends the Art-Net sync over them, and only accepts nodes from their networks.

- *All* (at the start): every card, as before.
- *Network cards*: the wired and Wi-Fi cards, without docker, VPN, WSL or Hyper-V switches.
- *Picked*: only the cards switched on in the list below. It starts with the cards *Network cards* would use.

The list shows every card with its address, "virtual" and "down" where that applies. *Refresh* reads the cards again,
e.g. after plugging in a USB network adapter. The choice belongs to this computer: it is the same for every project.

## Fixtures

Fixtures are lamps: a par, a moving head, a pixel bar. Each kind of lamp is described once by a file in `Fixtures` of
the *Assets* tab (`Bars`, `MovingHeads`, `Pars` and some examples). The lamps of your rig are set up once per project
in the fixture setup, and saved with the project.

A lamp is addressed the way it is set on the lamp: a node, a universe and a DMX start address. There are no internal
universes or patch layers in between.

### Set up your lamps

![The fixture setup: fixture types and lamps on the left, the stage plan in the middle, the lamp settings on the right, the universe map below](media/fixture-setup.png)

1. In the tab *Assets*, open `Fixtures` and double-click *Setup.menu*. The fixture setup opens in a new tab.
2. Your Art-Net nodes are listed on the right under *Nodes* as soon as they answer. A node that does not answer
   ArtPoll (or is not on the network yet): *Add node by IP*, with its IP address and a name.
3. In *Fixture types* on the left, click a type, set *Count* and click *Add lamps*. Or drag the type onto the plan.
   New lamps get the next free channels of the node you picked last, one after the other.
4. Click a lamp on the plan or in the list *Lamps*. On the right: *Name*, *Node*, *Universe* and *Address*.
   *Next free address* moves it to the first channels nobody else uses.
5. Move the lamps on the plan to where they hang: drag them, *Row*, *Grid* or *Circle* for the selected lamps. The plan
   is the stage seen from above, the audience at the bottom, one square a metre.

| On the plan | What it does |
|---|---|
| Click | Selects a lamp |
| Shift+click, or a box dragged on the empty plan | Selects more lamps. The numbers show the order you picked them in |
| Drag a lamp | Moves the selected lamps (in quarter metres while *Snap* is on) |
| Scroll, right mouse button | Zoom, move the plan. *Fit* shows all lamps |
| Delete, Ctrl+D, Ctrl+A, Esc | Remove, duplicate, select all, select none |

With several lamps selected, *Node*, *Universe* and *Start address* go to all of them: *Address in order* gives them
addresses one after the other in the order you picked them.

**Problems are red.** Two lamps on the same channels, a lamp past channel 512 or without a node are red in the list
and on the plan, and the top right says how many lamps need attention. A lamp is also red when a segment of a
[LEDMapper](#ledmapper) writes its channels without being meant for it (a segment or group whose *Lamp* is that lamp
is fine). The *universe map* at the bottom shows the 512 channels of the universe of the selected lamp: each lamp has
its own colour, the selected ones are highlighted, channels a LEDMapper sends to are grey, red channels are used twice.
Point at a channel to see who uses it, lamps and LEDMapper segments; click it to select that lamp.

![A bar of the fixture setup that a LEDMapper segment writes over: red in the list, the problem under its settings, its channels red in the universe map, the other channels of the LEDMapper grey](media/fixture-setup-ledmapper.png)

**Find a lamp in the rig.** Switch on *Highlight*: the selected lamps go to full (white, intensity full). Select other
lamps and they light up instead. Off: back to their values.

**With the AI.** The *Chat* and an AI tool connected over the *MCP* tab can work on the fixture setup too: list, add,
address, move, group and remove lamps, add nodes by IP, show a universe and find channels that are used twice ("put
eight hexapads on the truss node from address 1 and make a group of them"). See [The screen](The-Screen.md#chat-tab).

**Groups.** *New group from selection* makes a group of the selected lamps, in the order you picked them: that order
is the order of a [Phaser](#effects-over-fixtures). ✓ selects the lamps of a group, ⟳ replaces them by the selection.

### Play them

![Devices, Fixtures: one section per fixture type with Dimmers and Flashers, then one per lamp](media/devices-fixtures.png)

The lamps appear in the tab *Devices*, section *Fixtures*, one section per fixture type:

| Part | What it does |
|---|---|
| *Dimmers* | One *Dim* slider per channel. Scales that channel on every lamp of this type. |
| *Flashers* | A slider and a *Flash* button per channel. While *Flash* is held, every lamp takes the slider value on that channel. |
| One section per lamp | Its name and address, then a slider per channel. A colour channel has a colour picker; an RGBW colour has sliders for red, green, blue and white. |

Every slider has notches: [link](Linking.md) it to an LFO or the [audio analysis](Audio.md), or map it to
[MIDI](MIDI.md). Links and MIDI mappings stay when you re-address or move a lamp.

### Make a fixture file

*Editor.menu* in `Fixtures` opens the fixture editor.

1. Click *Create new fixture*. Double-click its name to rename it (lamps of that type follow the new name).
2. Click the fixture, then *Add Channel* for each channel, in the order of the DMX chart of the lamp.
3. Give each channel its type: *8-bit*, *16-bit*, *RGB* or *RGBW*, and a count for channels that repeat (the 8
   pixels of a bar: one *RGB* channel with a count of 8).

Lamps of the type in the fixture setup take the change at once.

### Effects over fixtures

![The Phaser: a plan of the lamps lit by their values on the left, the phasers on the right, one with its settings open](media/phaser.png)

The *Phaser* in `FixturesEffects` runs a wave over the lamps of a group: each lamp a bit later than the one before. It
uses the words of a lighting desk: wave, speed, phase, width, wings.

1. Drag *Phaser* into a view and click *Add phaser*.
2. *Lamps*: a group of the fixture setup, or all lamps of a type. *Attribute*: the channel it moves, such as *DIMMER*,
   *PAN* or a colour.
3. Pick the *Wave* and how fast it runs (*Cycle* in beats: it follows the BPM of the [timeline](Timeline.md)).
4. *Phase* spreads the wave over the lamps: 0° all together, 360° one wave from the first lamp to the last.

| Setting | What it does |
|---|---|
| Level slider (the row) | 0 holds the lamps at *Low*, 1 runs the full wave. Link or map it like any slider. |
| *Wave* | *Sine*, *Triangle*, *Ramp up*, *Ramp down*, *Square*, *Pulse*, *Random*, or *Input* (below). |
| *Cycle* | Length of a cycle in beats. |
| *Phase* | Degrees of the wave spread over the lamps. 720 makes two waves. |
| *Spread* | Which lamp comes first: *In order* (the order of the group), *From the middle*, *Left to right*, *Right to left*, *Back to front*, *Front to back*, *Outside in*. The directions use where the lamps hang on the plan. |
| *Width* | The part of a cycle the wave runs; the rest of it the lamp stays at *Low*. A *Pulse* with a small width is a chase. |
| *Low*, *High* | The values at the bottom and the top of the wave. |
| *Wings* | Mirrors the phase: with 2 wings the second half of the lamps runs the other way. |
| *First lamp*, *Last lamp* | Only the lamps from … to … of the group (counted from 0, *Last lamp* -1: to the last). |
| *Auto mirror X* / *Y* | Lamps left of (behind) the middle of the stage get the mirrored value: pan and tilt move symmetrically. |
| *Priority* (top) | When two phasers move the same channel, the higher priority wins. |

The bars under each row show what it sends to each lamp; the plan on the left shows the lamps of the phaser whose
settings are open, lit by their values.

**Input.** With the wave *Input* the Level slider is the value that runs over the lamps, each lamp *Phase delay* beats
later than the first. Put an LFO or the audio analysis into the area on the left of the Phaser and link it into the
slider. This is what the Phaser did before; phasers of older projects keep doing it.

## Mapping

Three generators in `Mapping` bring pictures onto surfaces and LEDs. They are tools of their own; this is what each is
for.

| Generator | What it is for |
|---|---|
| *MapLab* | Projection mapping with several inputs, slices and outputs: cut slices out of the inputs, place and warp them with a grid, mask them, blend their edges. Each output has an *Out* port and goes to a display, Spout, NDI or a video router: see [the outputs of MapLab](#the-outputs-of-maplab). |
| *LEDMapper* | LED strips, bars and matrices drawn over a picture; their colours go to Art-Net nodes or to lamps of the fixture setup. See [LEDMapper](#ledmapper). |
| *MaskTransform* | One mask or warp surface between an *In* and an *Out*. |

Their inputs list every picture that is offered by a *Video router*: a shader, a [video](Video.md#controls) or a
receiver with its router on.

### The outputs of MapLab

Under its name each output shows a small live picture of what goes out of it (after its effects); a click on it opens
the output like its arrow does. Open an output with its arrow (right column of MapLab). Besides *Width*, *Height* and
*Edge Smooth* it sends its picture on, without a shader generator in between:

| Section | What it does |
|---|---|
| *VideoRouter* › *Enable Router* | Offers the output under its name in every input list (shaders, LEDMapper, MapLab). |
| *Display* | *Display*: the screen it is shown on (*Off*: none). *Display mode*: *Fullscreen* covers that screen, *Window* is a window of its own on it. |
| *Spout* | *Enable Spout* sends it as a Spout source (Windows), named after *Spout name*. |
| *NDI stream* | *Enable NDI* sends it as an NDI source, named after *NDI name*. |

The names start as the name of the output.

**Effects of an output.** *Effects* opens the effects of the output in the upper half of MapLab (where an input mask
shows). Drag shaders from the *Assets* tab onto the list on the left of it: the first one gets the mapped output, each
next one the one before, and the last one is what the output sends (*Out*, the display, Spout, NDI and the video
router). Click an entry to see its controls; × removes it. The effects are saved with the project.

**LED mapping of an output.** *LED mapping* adds a *LEDMapper* to the effects of the output and opens them: it gets
the picture of this output (after the effects before it), maps its LEDs from it and passes the picture on unchanged.
How the LEDMapper works: see [LEDMapper](#ledmapper). A second click adds a second LEDMapper, for example for
another set of nodes.

### LEDMapper

![The LEDMapper: the layout and the library on the left, the picture with a line, a curve and a matrix in the middle, the settings of the selected segment on the right](media/ledmapper.png)

The LEDMapper takes the colours for your LEDs from a picture. Each **segment** is one strip with its own number of
LEDs, drawn where it is in the picture: a line, a curve, or a matrix with several rows. A **group** is what one node
gets (its segments one after the other), a **scene** is a set of groups with a master.

1. Pick the picture in *Input* (every shader, video or receiver whose *Video router* is on).
2. Choose *Line* or *Curve* in the toolbar and drag on the picture. A scene and a group are made for the first
   segment; the group goes to the first node found.
3. Click the segment: on the right set *LEDs*, *Rows* (a matrix), *Colours* (the order of the colour channels; many
   strips are *GRB*) and *White channel* for RGBW LEDs.
4. Click its group in the *Layout* on the left: *Node*, *Universe* and *Address* of the first LED. The segments of a
   group follow one after the other.
5. Switch on *Test*: the selected segment, group or scene is white on the real LEDs and everything else black, to find
   a strip in the rig.

| On the picture | What it does |
|---|---|
| *Select* (V) | Click a segment to pick it. Drag it, its ends, or the square handle of a curve. Delete removes it, Ctrl+D duplicates it, R reverses it. |
| *Line* (L), *Curve* (C) | Drag to draw a segment into the selected group. Its LEDs and colours are those of the segment before. |
| *Transform* (T) | Moves and scales the whole selected group (drag the corners or the middle); *Angle* in its settings turns it. |
| *Snap*, grid | Ends snap to a grid of this many cells across the picture. |
| *Addresses* | Shows the first and the last DMX address of each segment. |

**Where the data starts.** The big dot is the first LED, the arrow the direction of the data. *Reverse* (R) turns it
around; *Zigzag rows* makes every second row of a matrix run back, as most LED panels are wired.

**Addresses.** The first and last address of the selection are under its settings. A segment can have its *Own
address* (the next ones follow it). *Spacing* in the group: 0 = each segment right after the one before, otherwise
the channels from the start of one segment to the start of the next (512: a universe each). *Whole pixels per
universe* fills a universe with whole LEDs only (170 RGB, 128 RGBW), as many nodes expect. A segment is red when
another one writes the same channels of its node: in this LEDMapper, in another LEDMapper, or a lamp of the
[fixture setup](#set-up-your-lamps) it is not meant for. The status under the picture counts them, and the settings
of the segment say what it overlaps with.

![A LEDMapper segment on the channels of a bar of the fixture setup: the segment and the status under the picture are red, the settings say which lamp it overlaps](media/ledmapper-overlap.png)

**Lamps of the fixture setup.** A group's *Output* can be a *Lamp of the setup* instead of a node, and a segment can
have a *Lamp*: the address then comes from the lamp and follows it when you re-address the lamp. *Add these lamps*
in the settings of a scene makes a group of all lamps of a group or type that have colour channels, one segment per
lamp, placed as they hang on the stage plan.

**Masters and switching off.** Under the picture is a *Master* slider per scene (link it or map it to MIDI). The eye
in the *Layout* switches a scene or group off: it is not sent at all. *Brightness* in a group scales its LEDs.

**Presets.** *Preset* in the settings of a scene, group or segment saves it; the *Library* on the left lists the
presets: click one to insert it where the selection is. Presets can also be dragged in from the *Assets* tab
(`Mapping` › `LEDMapper` › `scenes`, `groups`, `segments`).

| Left column | What it does |
|---|---|
| *LED Radius* | 0: each LED takes the pixel under it. More: the average of a circle of this many pixels. |
| *LED Smoothing* | Changes fade over a few frames. |
| *Analog Mode* | Smoothing like a light bulb: up quickly, down slowly. |
| *Width*, *Height* | Size of the picture the segments are drawn on. |

## Prolink (CDJs)

Two generators in `Generators` › `Network` read the CDJs through **DJ Watch**, a small ESP32 box in the DJ network
(`dj-watch.local`; it was called prolink-bridge before). Both use the same connection.

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
  - *Time display* (section *Settings*) shows the *Remaining* time of each track (default) or the *Elapsed* time.
  - Next to the BPM of each deck the words *On air* (green, needs a mixer on the network), *Master* and *Sync*; a green
    ▶ before the time while a deck plays.
  - *Style* changes the colours of the waveforms (*CDJ* or *VibeVJ*); the background, texts and badges look like the
    rest of VibeVJ in both.
  - Keys on its picture: H shows the history, + and - zoom, 0 resets the zoom.
  - *Output* sets the size of the picture: fixed sizes from 1920 x 1080 to 3840 x 1080 and flat strips, *Custom*
    (*Width (px)* and *Height (px)*) or *Fit window* (the shape of the generator window, *Height (px)* high). The picture in the
    window takes the whole width of the window.
  - *Zoom* is the time across the waveforms at a width of 1920 px. A wider output shows more seconds at the same speed,
    most of them ahead of the playhead. The zoom bar under the picture shows the seconds you see.

*Source* (in the section *Settings*) is *USB* (finds DJ Watch by itself, or set *Port*), *Demo* (plays a recorded
set, no hardware), *Network* (a relay ESP32 over ShizoNet) or *Network card* (no DJ Watch, see
[Without DJ Watch](#without-dj-watch-network-card)). The line at the top shows the connection ("DJ Watch
connected") or what is wrong: the messages are on [Troubleshooting](Troubleshooting.md#esp32-not-found).

### Without DJ Watch (network card)

With the source *Network card* VibeVJ needs no DJ Watch: this computer joins the DJ network itself, through one of its
network cards, and does what DJ Watch does. It shows up there as one more player (like ShowKontrol or Beat Link),
gets the status of the players and fetches titles, waveforms, cues and artwork from them. Everything else works the
same: both generators, the history, *Sync timeline*.

Use a network card of its own for the DJ network: a second Ethernet port on the board, a PCIe card or a USB Ethernet
adapter.

- **Why a card of its own?** CDJs and mixers are made for a small, quiet network. Art-Net (often many universes, 40
  times a second, as broadcast) and ShizoNet in the same network can disturb them, and with two networks on one card
  the computer does not know which way a broadcast should go. With two cards the DJ network stays as the DJ set it up.
- VibeVJ sends Pro DJ Link only through the card it uses for the DJ network. Art-Net and ShizoNet keep using the
  other card. When the computer would send its own broadcasts (ShizoNet, Art-Net to broadcast) through the DJ card,
  VibeVJ warns: give the light/VJ card priority (below).
- Do not run rekordbox, Beat Link or ShowKontrol on the same computer: they need the same ports (UDP 50000 to 50002).

**Set it up**

1. Plug the card into the switch of the players. Not into a numbered channel port of a mixer: there the mixer wants to
   give out player numbers itself.
2. Set the card to *automatic* (DHCP). Without a router in the DJ network, Windows and macOS then take an address
   169.254.x.y by themselves, like the CDJs. Linux: set the connection to *Link-local only* (NetworkManager:
   `nmcli connection modify <name> ipv4.method link-local`). A fixed address works too, in the same subnet as the
   players.
3. Windows: allow VibeVJ through the firewall for this network (the first start asks; tick *Private* and *Public*,
   the DJ network has no internet and counts as *Public*).
4. In *Prolink Bridge* or *Prolink Decks*: *Settings* › *Source* › *Network card*. Leave *Network card (empty = auto)*
   empty: VibeVJ listens on all cards, sends nothing, and takes the card on which the first CDJ shows up. Or type the
   name of the card (Windows: "Ethernet 2" as in the network settings; Linux: eth1; macOS: en7) or its address.
5. The line at the top shows "Looking for CDJs on all network cards…", then "Network card Ethernet 2: joining the DJ
   network…" (about 6 seconds), then the decks.

| Control | What it does |
|---|---|
| *Network card (empty = auto)* | The card in the DJ network: name or address. Empty: the card on which CDJs show up. |
| *Listen only* | Send nothing into the DJ network. VibeVJ then gets only tempo and beats (and the mixer's on air), no titles, waveforms, cues or play state. For setups where a DJ does not want anything new in the network. |

Both generators share one connection: a different card in one of them switches it for both.

To keep the light/VJ card first for the computer's own broadcasts:

- Windows: *Control Panel* › *Network Connections* › the light/VJ card › *Properties* › *Internet Protocol Version 4* ›
  *Advanced* › untick *Automatic metric* and give it a lower *Interface metric* (for example 5) than the DJ card
  (for example 50).
- macOS: *System Settings* › *Network* › *…* › *Set Service Order*: the light/VJ card above the DJ card.
- Linux: the default route on the light/VJ card (the DJ card without a gateway).

> Screenshot to add: Prolink Decks with *Source* › *Network card*, the line at the top "Network card Ethernet 2", two
> decks with waveforms.

## ShizoNet

*Devices* › *Network* › *ShizoNet* switches ShizoNet on or off (on at the start). Off stops VibeVJ from looking for
ShizoNet devices and from talking to them; Art-Net keeps running. ShizoNet is used by the DJ Watch sources of
[Audio](Audio.md#source) and Prolink when they come over the network.

## See also

- [Assets](Assets.md)
- [Audio](Audio.md)
- [Video](Video.md)
- [Linking](Linking.md)
- [Clipview](Clipview.md)
- [Settings](Settings.md)
- [Troubleshooting](Troubleshooting.md)
