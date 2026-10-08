# Output and devices

How the picture leaves VibeVJ (a display or projector, NDI, Spout, other generators) and how VibeVJ talks to lights
(Art-Net, fixtures) and to the DJ booth (Prolink).

> Screenshot to add: a shader window on its *Control* tab with *Outputs* open: *Monitor* (*Display mode*, *Display*),
> *Video router*, *Spout* and *NDI stream*, next to the sidebar tab *Devices* with *Network* and *Fixtures* open.

## Show the picture on a display or projector

Every shader generator can send its picture out. A simple way is the shader *output* in *Shaders › Utilities*.

1. Drag *output* from the sidebar tab **Assets** (*Shaders › Utilities*) into a view.
2. Link the *Out* port of your Clipview (or any generator) into the input of *output*.
3. On the tab **Control**, open **Outputs › Monitor**.
4. Choose the **Display mode** first: *Fullscreen* or *Window* (a window without a frame).
5. Choose the **Display**: *Display 1*, *Display 2* … The output opens there. *Width* and *Height* are set to the size of that
   display.
6. To stop, set *Display* to *Off*. Closing the output window does the same.

*Display mode* is used when the output opens. To change it, set *Display* to *Off*, change the mode, then choose the display
again.

### Outputs (tab Control)

| Section | Controls | What it does |
|---|---|---|
| *Monitor* | *Display mode*, *Display* | Picture on a display, see above. |
| *Video router* | *Enable router*, *Video router name* | Offers the picture to other shaders by name. In another shader, open *Inputs*, then the input, and pick the name from the list. *No Input* clears it. |
| *Spout* | *Enable Spout*, *Spout name* | Sends the picture to other programs on the same computer. Windows only. |
| *NDI stream* | *Enable NDI*, *NDI name* | Sends the picture over the network as NDI. |

The names start as the shader name plus a short random code, so two outputs never clash. Type your own name to make it easy
to find in the receiving program.

### Render settings (tab Settings)

| Setting | What it does |
|---|---|
| *Size* | *Project* (the default) uses *Target width* and *Target height* from *Project › Settings*. *Custom* uses *Width* and *Height* below. |
| *Render scale* | Multiplies the size. 0.5 renders at half size (faster), 1 at full size. |
| *Component format*, *Pixel format* | The format of the picture. Keep *uint8* and *rgba* for NDI: NDI sends only that format. |
| *Render mask* | Turns the mask input on or off. |

### The whole window as NDI

*Project › Settings › NDI stream* sends the whole VibeVJ window as NDI (*Enable NDI*, *NDI name*, "ProgramOut" by default).

### Receiving video

*NDIReceiver* and *SpoutReceiver* (in *Generators › Network*) bring video from other programs in. Open the list at the top,
pick a sender, and link the output of the generator onward. Both can also offer their picture to shaders through their own
video router.

## Art-Net

The sidebar tab **Devices**, section **Network › Artnet**:

- **ArtNetSync** (on by default) sends an Art-Net sync after every frame, so all nodes update at the same moment.
- Every Art-Net node that VibeVJ finds on the network gets a section "name [MAC]" with its IP and MAC address.

Two generators in *Generators › Network* work with single channels. Their labels are still written in capitals.

| Generator | How to use it |
|---|---|
| *ArtnetSender* | Pick a node in the list at the top. Click *Add channel* or *Add 16-bit channel*. Each row has *U* (universe), *C* (channel) and a slider that sends 0–255 (or 0–65535). *Start universe* and *Start channel* shift all rows. |
| *ArtnetReceiver* | Add rows the same way. A row's slider follows that channel from the network. Click *L* on a row, then move the fader on your console: *U* and *C* are filled in. |

With the power button off, both stop sending or following.

## Fixtures

Fixtures are lamps described by a file in *Assets › Fixtures* (*Bars*, *MovingHeads*, *Pars*). Set them up once per project.

1. In the tab **Assets**, open *Fixtures* and double-click *Setup.menu*. The fixture setup opens in a new tab.
2. Drag a fixture file from *Assets › Fixtures* onto "Drop fixtures here" on the left.
3. Click the fixture name. Its settings open on the right.
4. Set *Total count* or click *Add New Instance* for each lamp of this type.
5. For each lamp: type a name, pick the Art-Net node in *Select Target*, set *Uni* (universe 0–15), *Adr* (start address
   1–512) and *Count* (several identical lamps at following addresses).
6. Move the lamps on the grid in the middle to where they hang. The setup is saved with the project.

The lamps then appear in the tab **Devices**, section **Fixtures**:

| Part | What it does |
|---|---|
| *Dimmers* | One *Dim* slider per channel. Scales that channel on every lamp of this type. |
| *Flashers* | A slider and a *Flash* button per channel. While *Flash* is held, every lamp takes the slider value on that channel. |
| One section per lamp | A slider per channel; colour channels have a colour picker. Link or map them like any control. |

*Editor.menu* in *Assets › Fixtures* opens the fixture editor for new fixture files.

## Prolink (CDJs)

Two generators in *Generators › Network* read the CDJs through a prolink-bridge ESP32. Both use the same connection.

- **Prolink Bridge** (*ProlinkBridge*) gives the values of the tempo master deck: BPM, beat and bar, beat and downbeat pulses, beats to the
  next cue, cue ramp, drop pulse, progress, playing, on air, master deck, and *Low* / *Mid* / *High* from the waveform.
  *Timeline BPM sync* (on by default) makes the timeline follow the master deck while it plays; *Bar lock* also puts the bar
  on its downbeat. *Phase offset* moves the beat earlier or later.
- **Prolink Decks** (*ProlinkDecks*) draws the decks with their waveforms, cues and phrases as a video output. Each section *Deck 1* … *Deck 4*
  has *BPM*, *Beat*, *Low*, *Mid*, *High*, *Progress*, *Cue ramp*, *Playing*, *On air*, *Phrase ramp*, *Buildup* and *Drop*.
  These are **pure outputs**: link from them, not into them.

*Source* (in *Settings*) is *USB* (finds the ESP32 by itself, or set *Port*), *Demo* (plays a recorded set, no hardware) or
*Network* (a relay ESP32 over ShizoNet). The line at the top shows the connection or what is wrong.

## Shizonet

*Devices › Network* also has *Shizonet*. The button does not change anything yet. ShizoNet itself is used by the ESP32 sources in [Audio](Audio.md) and Prolink.

## See also

- [Audio](Audio.md): the ESP32 as audio source
- [Linking](Linking.md): links, ports, pure outputs
- [Clipview](Clipview.md): its *Out* port
- [Troubleshooting](Troubleshooting.md): NDI or Spout not visible, ESP32 not found
- [Glossary](../../design/wiki/Glossary.md)
