# Audio

The generator *Audio Input Analysis* listens to the music and turns it into values you can link: the tempo, the beat,
the energy of bass, mids and highs, and whether a break is playing. It can also keep the timeline in time with the
music.

![Audio Input Analysis: Beat, energies and the analysis values are pure outputs (right notch only)](media/audio.png)

## Add it

1. Open the sidebar tab *Assets* and go to `Generators` › `Audio`.
2. Drag *AudioInputAnalysis* into a view. The window opens and the analysis starts.
3. Choose the *Source* (see below). The line under it says what VibeVJ hears right now.
4. Play music. *Beat*, *BPM* and the energy rows start to move.
5. Link the rows you need into other controls: drag from the right notch of *Beat* onto the control it should drive.
   See [Make a link](Linking.md#make-a-link).

The [power button](Generators.md#the-window-header) in the window header must be on (green). With the power off the
analysis stops after a few seconds and every value stays where it was. Turned on again, it needs a few seconds to
start.

## Source

| Source | What it uses | Line under *Source* |
|---|---|---|
| *Sound card* | The standard recording input of your computer (line-in, microphone, audio interface). Choose that input in the sound settings of your system; VibeVJ has no device list of its own. | "Sound card" |
| *DJ Watch (USB)* | The microphone or line-in of DJ Watch (the ESP32 box in the DJ network, formerly prolink-bridge) on USB. It shares the USB connection with the [Prolink generators](Output-and-Devices.md#prolink-cdjs). | "DJ Watch USB: … kHz" while audio comes in |
| *DJ Watch (network)* | The same audio from a relay ESP32 in your network, over ShizoNet. | "DJ Watch relay: … kHz" or "DJ Watch listener via relay: … kHz" |

- For DJ Watch the firmware must send audio (firmware command "audio mic" or "audio line"). If it does not, the line
  says "No audio from DJ Watch (firmware: audio mic|line)".
- With *DJ Watch (USB)* and no board found it says "DJ Watch not connected".
- *DJ Watch port (empty = auto)*, in the section *Settings* of the window, picks a USB port by hand. Leave it empty to
  find the board by itself.
- For *DJ Watch (network)*, *Shizonet* must be on in the sidebar: see [Output and devices](Output-and-Devices.md#shizonet).

## The values

These rows are [pure outputs](Linking.md#pure-outputs): the analysis writes them all the time. They have only a right
notch. Link **from** them into other controls; a link into them is refused.

| Row | What it shows |
|---|---|
| *BPM* | The tempo the analysis hears. It glides to a new tempo instead of jumping. |
| *Beat* | Where you are inside the current beat, 0 to 1. It starts again at 0 on every beat. |
| *Low energy* | Energy of the bass, below *Low energy cutoff*. 0 to 1. |
| *Mid energy* | Energy between the two cutoffs. 0 to 1. |
| *High energy* | Energy above *High energy cutoff*. 0 to 1. |
| *Score* (section *Analysis*) | The running score of the beat tracker, 0 to 10000. |
| *Break* (section *Analysis*) | 1 while a break plays, else 0. |
| *Break inverted* (section *Analysis*) | 0 while a break plays, else 1. |

The energy rows adapt to the level of the music: 1 means as loud as that band was lately, 0 as quiet. You do not need
to set a gain.

Ideas for links:

- *Beat* into the brightness of a shader: it pulses with the music.
- *Low energy* into a zoom or a strobe, with a *Normalized* [link type](Linking.md#link-types) so it fills the range.
- *Break inverted* into the *Master* of a [layer](Clipview.md#layers): the layer goes dark in a break.

## Sync timeline

Turn on *Sync timeline* (off at the start) and the timeline follows the music: its BPM is set to the *BPM* of the
analysis and its position is nudged onto the beat, every frame. While it is on, a BPM you type in the timeline is
overwritten. Turn it off to set the tempo by hand. See [Timeline](Timeline.md#sync-the-timeline-from-audio).

## Settings

The section *Settings* of the window. (The settings of the program are in a window of their own:
[Settings](Settings.md).)

| Setting | At the start | What it does |
|---|---|---|
| *Fix BPM* | *Auto* | *Auto* (-1) lets the analysis find the tempo. Type a tempo (up to 999) to lock the beat tracker to it. |
| *Phase offset* | 0 | Shifts *Beat* (and with it the timeline sync) by up to half a beat, -0.5 to 0.5. Use it when the visuals are early or late against the sound. |
| *Break threshold* | 0.3 | A break starts when the bass falls below this share of its normal level. Higher = breaks are found sooner. |
| *Drop threshold* | 0.6 | The break ends (the drop) when the bass comes back above this share of its normal level. |
| *Low energy cutoff* | 250 Hz | Upper end of *Low energy*, lower end of *Mid energy*. 20 to 20000 Hz. |
| *High energy cutoff* | 4000 Hz | Upper end of *Mid energy*, lower end of *High energy*. 20 to 20000 Hz. |
| *DJ Watch port (empty = auto)* | empty | Only for *DJ Watch (USB)*, see above. |

A break lasts at least 1.5 seconds, and a new one can start 3 seconds after the last one at the earliest. There is no
separate drop row: the drop is the moment *Break* goes back to 0.

## FFT texture

The row *FFT texture* is a texture output with an *Out* port. It holds the spectrum (512 bands, low to high) in its
first row and the waveform in its second row. Link it into the input of an audio shader, for example one from
`Shaders` › `Sources` › `Audio`, to draw with the sound. The preview at the bottom of the window shows the same data.

The section *FFT* shapes the spectrum:

| Setting | At the start | What it does |
|---|---|---|
| *Band smoothing* | 5 | Blends each band with this many neighbours, 0 to 50. Higher = smoother. |
| *Attack* | 0.2 | How fast a band rises. Higher = faster. |
| *Decay* | 0.995 | How long the loudest level is remembered, 0.8 to 0.9999. Lower = more dynamic. |
| *Release* | 0.08 | How fast a band falls. Higher = faster. |
| *Noise floor* | 0.08 | Bands below this share of their peak are set to 0. 0 to 0.9. |

## See also

- [Linking](Linking.md)
- [Timeline](Timeline.md)
- [Output and devices](Output-and-Devices.md)
- [Assets](Assets.md)
- [Troubleshooting](Troubleshooting.md)
