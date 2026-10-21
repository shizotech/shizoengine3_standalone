# Troubleshooting

Common problems and what to do. Most of them come down to three things: a power button that is off, show mode that is
still on, or a device that VibeVJ cannot see. When something goes wrong, VibeVJ says so at the bottom right and keeps
the message in [the log](#the-log).

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

Prolink Bridge and Prolink Decks show the state of DJ Watch (the ESP32 box in the DJ network) in a status line. Audio
Input Analysis has its own, shorter messages (the last two rows).

| Message | What to do |
|---|---|
| "No DJ Watch found (USB cable, CH343 driver?)" | Check the USB cable and install the CH343 driver. Or type the port into *Port*. |
| "Port busy (is bridge.py or a serial monitor running?)" | Close the other program that uses the port. |
| "Permission denied (add the user to the dialout group)" | Linux: add your user to the group *dialout*, then log in again. |
| "Lost the DJ Watch (cable unplugged or restart)" | Plug it in again. VibeVJ reconnects by itself. |
| "Waiting for the relay (ShizoNet)" or "No data from the relay (ShizoNet)" | Source *Network*: the relay ESP32 is not on the same network as VibeVJ, or it is off. Check that [*ShizoNet*](Output-and-Devices.md#shizonet) is on in *Devices* › *Network*. |
| "Connecting to DJ Watch…" | VibeVJ is still looking for the box. If it stays, see the rows above. |
| "DJ Watch connected, no tempo master" | Prolink Bridge is connected, but no CDJ is tempo master. Make a deck master on the CDJs. |
| "DJ Watch not connected" | Audio with *DJ Watch (USB)*: the board is not connected. See the first row. |
| "No audio from DJ Watch (firmware: audio mic\|line)" | Audio: the board sends no audio. Turn audio on in the firmware (command "audio mic" or "audio line"). |

## CDJs not found on the network card

With the source *Network card* ([without DJ Watch](Output-and-Devices.md#without-dj-watch-network-card)) the status
line of Prolink Bridge and Prolink Decks shows what the computer sees in the DJ network.

| Message | What to do |
|---|---|
| "Looking for CDJs on all network cards…" | No CDJ has shown up yet. Is the card plugged into the switch of the players, and are the players on? Windows: allow VibeVJ through the firewall (also for *Public* networks). |
| "CDJ-3000 (169.254.12.7) is in no subnet of this computer's network cards…" | The card has an address that does not match the players. Set the card to *automatic* (DHCP, then 169.254.x.y by itself) or to an address in the subnet of the players. |
| "Network card Ethernet 2 not found, not connected or without IPv4 address" | The name in *Network card* does not match, the cable is out, or the card has no address yet. Leave the field empty to find the card by itself. |
| "UDP ports 50000-50002 are in use (…)" | Another Pro DJ Link program runs on this computer (rekordbox, Beat Link, ShowKontrol). Close it. |
| "Network card Ethernet 2: no CDJs yet" | The card is open, but no player is on it. Check the cable and the switch. |
| "Network card Ethernet 2: joining the DJ network…" | VibeVJ announces itself as one more player (about 6 seconds). If it stays: another program on the network may use the same player number. |
| "Network card Ethernet 2 (listen only)" | *Listen only* is on: tempo and beats only, no titles, waveforms or cues. |
| "Network card Ethernet 2: the computer's broadcasts go into the DJ network…" | ShizoNet and Art-Net broadcasts of this computer would go out through the DJ card. Give the light/VJ card priority: see [Without DJ Watch](Output-and-Devices.md#without-dj-watch-network-card). |
| "Network card Ethernet 2 lost its address (cable?)" | The cable was pulled or the card was switched off. VibeVJ opens it again by itself. |

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

1. In *Devices* › *Network* › *Art-Net*, check that the node is listed. If not, VibeVJ cannot see it on the network.
2. In the [fixture setup](Output-and-Devices.md#set-up-your-lamps), every lamp needs a node, the right *Universe* and
   *Address*. Red lamps have a problem: point at them in the list to see which. *Highlight* lights the selected lamps
   to check the address.
3. In *Devices* › *Fixtures*, check that the *Dim* sliders are not at 0.
4. LEDMapper: the group needs a node; *Test* lights the selected segment white. A strip that shows wrong colours needs
   another *Colours* order (many are *GRB*). A red segment shares its channels with something else (another segment,
   another LEDMapper or a lamp of the fixture setup): its settings say with what. Two senders on one channel flicker
   between their values.
5. In *ArtnetSender*, pick the node in the list at the top. Values are sent once the node is found; move the slider
   again.

## The output stutters

Press **Ctrl + Shift + P** (or *Performance overlay* in the [command palette](Shortcuts-and-Tips.md#the-command-palette))
for a small panel at the top right. It counts each second:

| Line | Tells |
|---|---|
| *FPS* | Frames per second, and the target of [*Settings* › *Project*](Settings.md#project). Yellow when it is more than 10 % below the target. |
| *Frame* | How long a frame takes on average, and the slowest frame of the second. |
| *Script … GPU … VRAM …* | All generators together: their script time per frame, the time the graphics card needs for all shaders, and the video memory the shaders take. If the frame is long but script and GPU are small, the outputs or the resolution are what is slow. |
| The next lines | The generators that cost the most per frame: script time, GPU time and video memory. Yellow above 4 ms. A generator in a view counts for itself, not for the view too. Click one to bring its area to the front. |
| *Last autosave* | How long the last [autosave](Getting-Started.md#autosave) took; the output stands still for that time. |

Press Ctrl + Shift + P again to close it. While it is closed nothing is measured.

The video memory is the one of the shaders' pictures: a shader at 1920 × 1080 takes about 16 MB (8 bit) up to 63 MB (32 bit float), depending on its
[format](Output-and-Devices.md#render-settings-tab-settings). Too many large shaders and the graphics card runs out of
memory; a smaller *Render scale* in their *Settings* helps.

## The log

Errors and warnings show up as short messages at the bottom right of the screen, above the timeline: red for an error,
yellow for a warning, with the file and line where it happened. A warning goes after 6 seconds, an error after 12. The
same message again counts up on its message (×3) instead of a new one. Click one to open the log.

The log is a window with the last 400 messages. Open it with the bell in the [top bar](The-Screen.md#top-bar); its badge
counts the errors since you looked last.

- **All / Errors / Warnings:** which messages the list shows.
- **Clear:** empties the list.
- Each line starts with the time. A runtime error also names where it happened (*at*) and the calls that led there
  (*from*), the last call first.
- You can select text in the list and copy it (Ctrl + C) for a bug report.

What ends up there: errors and warnings of VibeVJ and its generators, scripts that fail, and shaders that do not
compile. A shader that does not compile also shows its error in its window.

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
