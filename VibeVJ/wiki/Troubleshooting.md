# Troubleshooting

Common problems and what to do. Most of them come down to three things: a power button that is off, show mode that is still
on, or a device that VibeVJ cannot see.

> Screenshot to add: a generator window with its power button off (grey icon, dimmed title) next to the same window with the
> power button on (green icon).

## A generator does nothing

The values of a generator stand still, a shader shows no new frames, or an Art-Net generator sends nothing.

1. Look at the power button at the left of the window header. Off = grey icon and a dimmed title.
2. Click it. It turns green and the generator runs again.
3. If the power button is linked or mapped to MIDI, check what drives it: a link or a fader can switch it off.

A generator can also stop updating after an error in its code. Open the ⋯ menu in its header and click **Reload module**.
This loads the code again and keeps the settings.

## A generator does not open

You drop an asset into a view and no window appears. The asset is not valid: it has no entry file (for example
"Not a valid asset (no __init__.shio found)" or "No __init__.glsl entry point found!" in the console). Use another asset or
fix the files of this one.

## A link does not connect

While you drag, only controls that can take the link get a violet outline. If your target gets none:

| Cause | How to see it | What to do |
|---|---|---|
| The target is a **pure output** | It has only a right notch (for example *Beat* of Audio Input Analysis, the deck values of Prolink Decks). | Link the other way: from the pure output into the control it should drive. |
| The target is **disabled** | It is greyed out, its notches have no grip dot. | A disabled control takes no links. Pick another target. |
| **Show mode** is on | The *Show* badge is in the timeline bar. | Leave show mode (see below). |
| Start and target are the **same control** | — | A control cannot link to itself. |

A link into a pure output that was saved in an older project is dropped when the project loads.

## I cannot move, close or change anything

Show mode is on. It locks notches, links, moving and closing windows, dropping assets, *Paste settings* and *Reload module*.
Values, clips and MIDI keep working.

1. Find the lock in the timeline bar, next to the *Show* badge.
2. Press and **hold** it for about half a second, then let go. A short click does not leave show mode, on purpose.

## The tempo keeps changing by itself

Something syncs the timeline:

- *Sync timeline* is on in [Audio Input Analysis](Audio.md). Its *BPM* overwrites the timeline every frame.
- *Timeline BPM sync* is on in Prolink Bridge (it is on by default) and a deck is playing.

Turn the sync off to set the tempo by hand or with *Tap*.

## No audio input

*Audio Input Analysis* shows no movement in *Beat*, *BPM* or the energy rows.

1. Check that its power button is on.
2. Check *Source*. For *Sound card*, VibeVJ uses the default recording input of your computer: set the right input as default
   in your system's sound settings and make sure music reaches it.
3. Wait a few seconds. The analysis starts again by itself after a stop.
4. Still nothing: close the window and drag *AudioInputAnalysis* in again.

## ESP32 not found

Audio Input Analysis, Prolink Bridge and Prolink Decks show the state of the ESP32 in a status line.

| Message | What to do |
|---|---|
| "No ESP32 found (USB cable, CH343 driver?)" | Check the USB cable and install the CH343 driver. Or type the port into *Port* / *ESP32 port*. |
| "Port busy (is bridge.py or a serial monitor running?)" | Close the other program that uses the port. |
| "Permission denied (add the user to the dialout group)" | Linux: add your user to the group *dialout*, then log in again. |
| "Lost the ESP32 (cable unplugged or restart)" | Plug it in again. VibeVJ reconnects by itself. |
| "ESP32 not connected" | Audio with *ESP32 (USB)*: the board is not connected. See the first row. |
| "No audio from the ESP32 (firmware: audio mic\|line)" | The board sends no audio. Turn audio on in the firmware (command "audio mic" or "audio line"). |
| "Waiting for the relay (ShizoNet)" or "No data from the relay (ShizoNet)" | Source *Network*: the relay ESP32 is not on the same network as VibeVJ, or it is off. |
| "Connected, no tempo master" | Prolink Bridge is connected, but no CDJ is tempo master. Make a deck master on the CDJs. |

## NDI not visible

1. Check that *Enable NDI* is on (in *Outputs › NDI stream* of the shader, or *Project › Settings › NDI stream* for the whole
   window).
2. Install the NDI 6 runtime on this computer. Without it VibeVJ cannot send or find NDI.
3. Check the format on the tab *Settings*: NDI sends only *rgba* with *uint8*. Some shaders set their own format; send those
   through the shader *output* (*Shaders › Utilities*) and use NDI there.
4. Check that the generator's power button is on.
5. Look for the *NDI name* in the receiving program, on the same network.

## Spout not visible

- Spout works on Windows only.
- Check *Enable Spout*.
- You changed the *Spout name* while a *Display* was chosen: turn *Enable Spout* off and on again to use the new name.

## The display output is wrong

- Wrong mode (*Fullscreen* / *Window*): set *Display* to *Off*, change *Display mode*, choose the display again.
- The output window was closed: *Display* went back to *Off*. Choose the display again.

## A MIDI controller does not react

1. In the tab *Devices › MIDI*, check that the device is listed and not marked "· Offline".
2. A mapping only listens to the device it was learned from, by name. Learn it again with this device.
3. Make sure **MIDI learn** and **MIDI mapping** are off. While learning, a message can replace the mapping of the selected
   control.
4. Faders jump or fight: open the control's options, tab *MIDI*, and turn off **MIDI backpropagate**.

## Lights do not react (Art-Net, fixtures)

1. In *Devices › Network › Artnet*, check that the node is listed. If not, VibeVJ cannot see it on the network.
2. In the fixture setup, every lamp needs a node in *Select Target*, the right *Uni* and *Adr*.
3. In *Devices › Fixtures*, check that the *Dim* sliders are not at 0.
4. In *ArtnetSender*, pick the node in the list at the top. Values are sent once the node is found; move the slider again.

## See also

- [Generators](Generators.md): the power button and the ⋯ menu
- [Linking](Linking.md): pure outputs and disabled controls
- [Timeline](Timeline.md#show-mode): show mode
- [Audio](Audio.md), [MIDI](MIDI.md), [Output and devices](Output-and-Devices.md)
