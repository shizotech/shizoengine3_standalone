# Troubleshooting

Common problems and what to do. Most of them come down to three things: a power button that is off, show mode that is
still on, or a device that VibeVJ cannot see.

> Screenshot to add: a generator window with its power button off (grey icon, dimmed title) next to the same window with the
> power button on (green icon).

## A generator does nothing

The values of a generator stand still, a shader shows no new frames, or an Art-Net generator sends nothing.

1. Look at the [power button](Generators.md#the-window-header) in the window header. Off = grey icon and a dimmed
   title.
2. Click it. It turns green and the generator runs again.
3. If the power button is linked or mapped to MIDI, check what drives it: a link or a fader can switch it off. Rest
   the mouse on its notch to [see its links](Linking.md#seeing-your-links).

A generator can also stop updating after an error in its code. Open the ⋯ menu in its header and click *Reload
module*. This loads the code again and keeps the settings and all links.

A generator that fills an area has no header: click into it and press E to show it.

## A generator does not open

You drop an asset into a view and no window appears. The asset is not valid. The console says why, for example
"Not a valid asset (no __init__.shio found)", "Not a valid asset (no 'src/' directory found)" or
"No __init__.glsl entry point found!". Use another asset or fix the files of this one.

## A link does not connect

While you drag, only controls that can take the link get a violet outline. If your target gets none:

| Cause | How to see it | What to do |
|---|---|---|
| The target is a [pure output](Linking.md#pure-outputs) | It has only a right notch (for example *Beat* of Audio Input Analysis, the deck values of Prolink Decks). | Link the other way: from the pure output into the control it should drive. |
| The target is **disabled** | It is greyed out, its notches have no grip dot. | A disabled control takes no links. Pick another target. |
| **Show mode** is on | The lock in the timeline bar is green. | Leave show mode (see below). |
| Start and target are the **same control** | — | A control cannot link to itself. |
| The outline is **red and dashed** | The two are linked already. | Dropping there removes the link. Drop again to make it anew. |

A link into a pure output that was saved in an older project is dropped when the project loads.

## A value does not do what I set

- **It jumps back:** something writes it. Rest the mouse on its left notch to see what is linked in, or open the
  [options](Linking.md#the-options-of-a-control), tab *In*.
- **It moves by itself:** the tab *Env* of its options has a sync on, or a MIDI controller sends.
- **It follows slowly:** *smoothing* is set in the tab *Main*.
- **It only uses a part of the range:** check *min* and *max* in the tab *Main*, and the
  [type of the link](Linking.md#link-types).

## I cannot move, close or change anything

[Show mode](Timeline.md#show-mode) is on. It locks notches, links, the layout, moving and closing windows, dropping
assets, the right-click menus, undo, *Paste settings*, *Reload module* and *Exit*. Values, clips and MIDI keep working.

1. Find the green lock in the timeline bar, right of the link button.
2. Press and **hold** it for about half a second, then let go. A short click does not leave show mode, on purpose.

If only one Clipview is locked, its [*Live*](Clipview.md#live) button is on.

## A view is gone

- **You closed its area or its tab:** nothing is deleted by closing. The view is in a tab of its own in the top bar.
  Drag that tab down into an area to put it back: see [Moving a view](The-Screen.md#moving-a-view).
- **You deleted it** (*Delete view…*, or the × of a view tab): Ctrl + Z brings it back, as long as you did not load
  another project since. See [Undo and redo](The-Screen.md#undo-and-redo).
- **An area is too small to see anything:** drag the line beside it, or press Ctrl + Space in it to maximize it.

## I cannot delete a clip

A clip has no delete button. Select it (click its name tag) and remove every entry of its stack with × in the *Layer*
window. When the last entry goes, the clip goes. In a [CueList](CueList.md#a-list), the × beside the cue does it.

## The tempo keeps changing by itself

Something syncs the timeline:

- *Sync timeline* is on in [Audio Input Analysis](Audio.md#sync-timeline). Its *BPM* overwrites the timeline every
  frame.
- *Sync timeline* is on in [Prolink Bridge](Output-and-Devices.md#prolink-cdjs) (it is on at the start) and a deck is
  playing.

Turn the sync off to set the tempo by hand or with *Tap*.

## Autoplay does not move on

[Autoplay](Clipview.md#autoplay-and-duration) counts the beats of the timeline.

1. Press *Play* in the timeline bar.
2. Check the *Duration* of the layer: 64 beats at 120 BPM are 32 seconds.
3. Clips with *Trigger* = *Hold* or with *Exclude* on are skipped.

## No audio input

*Audio Input Analysis* shows no movement in *Beat*, *BPM* or the energy rows.

1. Check that its power button is on.
2. Check *Source*. For *Sound card*, VibeVJ uses the standard recording input of your computer: set the right input
   as standard in the sound settings of your system and make sure music reaches it.
3. Wait a few seconds. The analysis starts again by itself after a stop.
4. Still nothing: close the window and drag *AudioInputAnalysis* in again.

The line under *Source* says what is heard: see [Audio](Audio.md#source).

## ESP32 not found

Prolink Bridge and Prolink Decks show the state of the ESP32 in a status line. Audio Input Analysis has its own,
shorter messages (the last two rows).

| Message | What to do |
|---|---|
| "No ESP32 found (USB cable, CH343 driver?)" | Check the USB cable and install the CH343 driver. Or type the port into *Port*. |
| "Port busy (is bridge.py or a serial monitor running?)" | Close the other program that uses the port. |
| "Permission denied (add the user to the dialout group)" | Linux: add your user to the group *dialout*, then log in again. |
| "Lost the ESP32 (cable unplugged or restart)" | Plug it in again. VibeVJ reconnects by itself. |
| "Waiting for the relay (ShizoNet)" or "No data from the relay (ShizoNet)" | Source *Network*: the relay ESP32 is not on the same network as VibeVJ, or it is off. Check that [*Shizonet*](Output-and-Devices.md#shizonet) is on in *Devices* › *Network*. |
| "Connected, no tempo master" | Prolink Bridge is connected, but no CDJ is tempo master. Make a deck master on the CDJs. |
| "ESP32 not connected" | Audio with *ESP32 (USB)*: the board is not connected. See the first row. |
| "No audio from the ESP32 (firmware: audio mic\|line)" | Audio: the board sends no audio. Turn audio on in the firmware (command "audio mic" or "audio line"). |

## A video does not play

- **The window says why:** the line under the controls shows "No video" or the error.
- **The FFmpeg libraries are missing:** see [What you need](Video.md#what-you-need).
- **It stutters with many clips:** the graphics card decodes only so many at once. Turn the power of clips off that
  are not shown, or use fewer 4K clips. See [Which files play well](Video.md#which-files-play-well).
- **No sound:** videos play without sound.

## NDI not visible

1. Check that *Enable NDI* is on (in *Outputs* › *NDI stream* of the shader, or *Settings* › *Output* for the whole
   window).
2. Install the NDI runtime on this computer. Without it VibeVJ cannot send or find NDI.
3. Check that the power button of the generator is on.
4. Look for the *NDI name* in the receiving program, on the same network.

## Spout not visible

- Spout works on Windows only.
- Check *Enable Spout*.

## The display output is wrong

- Wrong mode: change *Display mode* (*Fullscreen* / *Window*), the output opens again in that mode.
- The output window was closed: *Display* went back to *Off*. Choose the display again.
- Wrong size: the tab *Settings* of the shader, *Size*. See
  [Render settings](Output-and-Devices.md#render-settings-tab-settings).

## A MIDI controller does not react

1. In the tab *Devices* › *MIDI*, check that the device is listed and not marked "· Offline".
2. A mapping only listens to the device it was learned from, by name. Learn it again with this device.
3. Make sure *MIDI learn* and *MIDI mapping* are off. While learning, a message can replace the mapping of the
   selected control.
4. Faders jump or fight: open the options of the control, tab *MIDI*, and turn off *MIDI backpropagate*.

More on [MIDI](MIDI.md).

## Lights do not react (Art-Net, fixtures)

1. In *Devices* › *Network* › *Artnet*, check that the node is listed. If not, VibeVJ cannot see it on the network.
2. In the [fixture setup](Output-and-Devices.md#set-up-your-lamps), every lamp needs a node in *Select Target*, the
   right *Uni* and *Adr*.
3. In *Devices* › *Fixtures*, check that the *Dim* sliders are not at 0.
4. In *ArtnetSender*, pick the node in the list at the top. Values are sent once the node is found; move the slider
   again.

## A tooltip is in the way

A tooltip with links locks after a second, so you can move the mouse into it. Click on its text, press Esc or click
anywhere else to close it. See [Tooltips](Shortcuts-and-Tips.md#tooltips).

## The Help window shows an old text

A page of the wiki is read when it is first opened. After you changed a file in `VibeVJ/wiki`, restart VibeVJ.

## See also

- [Generators](Generators.md)
- [Linking](Linking.md)
- [Timeline](Timeline.md)
- [Audio](Audio.md)
- [MIDI](MIDI.md)
- [Output and devices](Output-and-Devices.md)
- [Shortcuts and tips](Shortcuts-and-Tips.md)
