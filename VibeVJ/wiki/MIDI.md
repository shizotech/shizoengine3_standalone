# MIDI

Play VibeVJ with a MIDI controller. Any control with a notch can follow a fader, a knob or a pad, and the controller can
follow VibeVJ back (motor faders, pad lights).

![Devices › MIDI with MIDI learn on (amber while it waits for a message)](media/midi-learn.png)

## Your devices

MIDI devices are in the [sidebar](The-Screen.md#sidebar), tab *Devices*, section *MIDI*.

- Every controller that VibeVJ finds gets its own section, named after the device. Plug in a controller and it shows up
  within a second: VibeVJ looks for new devices all the time.
- A controller that is unplugged keeps its section. Its name then ends in "· Offline". Plug it back in and the name
  goes back to normal.
- A device with an input (it sends MIDI to VibeVJ) shows a *MIDI mapping* button and a row *In · name*. A device with
  an output (it receives MIDI) shows a row *Out · name*.

| Button | Where | What it does |
|---|---|---|
| *MIDI learn* | Top of the MIDI section | Learn mode for all devices: the next MIDI message from any controller is learned. Amber while it is on. |
| *MIDI mapping* | In the section of one device | Learn mode for this device only. Messages from other controllers are ignored while learning. |

Only one device can be the learn device. Turn *MIDI mapping* on for a second device and it takes over from the first; the
button of the first goes off.

## Map a control with MIDI learn

1. Open the tab *Devices* and the section *MIDI*.
2. Click *MIDI learn* (or *MIDI mapping* of one device). Every control now gets an amber overlay.
3. Click the overlay of the control you want to play, for example the *Mix* of a layer or the power button of a
   generator.
4. Move a fader or a knob, or hit a pad, on the controller. The overlay now shows what was learned, for example
   "CC 7 ch1", and the control jumps to the value of the controller.
5. Click the overlay of the next control and move the next fader. Repeat for every control you want.
6. Click *MIDI learn* (or *MIDI mapping*) again to leave learn mode. The overlays go away and the mappings stay.

What the overlay says:

| Overlay | Message |
|---|---|
| "CC 7 ch1" | Control change number 7 on channel 1 |
| "N 36 ch10" | Note 36 on channel 10 |
| "PB ch1" | Pitch bend |
| "PG ch1" | Program change |
| "AT ch1" | Channel pressure (aftertouch) |
| "AP 36 ch1" | Poly pressure of note 36 |

Tips:

- Moving another fader while a control is still selected replaces its mapping. Select the next control first.
- Several controls can learn the same fader. They all follow it.
- Pitch bend, program change and channel pressure have no number: a mapping to one of them listens to the whole
  channel.
- A mapping belongs to one device, found by its name. It is saved with the project and works again as soon as a device
  with the same name is connected.

## What a message does

| From the controller | The control gets |
|---|---|
| Control change (CC) | The value of the knob or fader, 0 to 127 spread over the range of the control |
| Note (pad, key) | The velocity while pressed, 0 when released |
| Pitch bend, program change, aftertouch | The value of the message |

- A fader fills the whole range of the control. To use only a part, set *min* and *max* in the options of the control
  (tab *Main*), or map a helper control and link it on with a *Normalized* or *Inverted* link. Both are on
  [Linking](Linking.md#the-options-of-a-control).
- To smooth a jumpy knob, set *smoothing* there.

## The MIDI tab in the options

Click a notch of a control to open its options. The tab *MIDI* shows the mapping of this control.

| Item | What it does |
|---|---|
| Mapping row, for example "nanoKONTROL2 CC 7 · ch 1" | Shows the learned device, the kind of message (*Note*, *CC*, *Program*, *Pitch bend*, *Channel pressure*, *Poly pressure*), its number and the channel. |
| × next to the mapping | Removes the mapping. |
| *MIDI backpropagate* | On (the standard): when the value changes in VibeVJ (mouse, a link, a clip), the value is sent back to the controller, so motor faders move and pad lights follow. Turn it off if the controller should only send. Saved per mapping. |

- A value that just came from the controller is not sent back to it for a second, so a fader does not fight itself.
- Some controls have no options (for example *Target FPS* in [*Settings* › *Project*](Settings.md#project), *Cable view*
  in *Settings* › *Links*, or the transport buttons of a [Clipview](Clipview.md#transport-buttons)). To remove their
  mapping, turn on *MIDI learn*, click the overlay of the control and press Esc.

## What can be mapped

Every control with a notch: value fields and sliders, control buttons, lists and switches, the power button of a
generator window, the columns, layers and transport of a Clipview, the buttons of a [CueList](CueList.md), the
transport of the [timeline](Timeline.md#the-transport-bar), fixture channels. Plain buttons without a notch (for
example *Save* in the *Projects* tab of the sidebar) cannot be mapped.

[Pure outputs](Linking.md#pure-outputs) (rows with only a right notch, such as *BPM* or *Low energy* of
[Audio Input Analysis](Audio.md)) are written by their generator all the time. A MIDI mapping on them is overwritten
at once, so map the controls they drive instead.

## Show mode

In [show mode](Timeline.md#show-mode) the notches are locked, so options and links cannot be changed. Set up your
mappings before the show.

## See also

- [Linking](Linking.md)
- [Clipview](Clipview.md)
- [Generators](Generators.md)
- [Output and devices](Output-and-Devices.md)
- [Troubleshooting](Troubleshooting.md)
