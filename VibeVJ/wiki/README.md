# VibeVJ user wiki

How to use VibeVJ, written for VJs. Each page says what a part of the app is for and how to use it step by step.

The design wiki (`../../design/wiki/`) explains what the colours, notches and sizes of the interface mean. This wiki explains
what you do with them.

![VibeVJ with a Clipview, the sidebar and the transport bar](media/overview.png)

## Pages

| Page | What it covers |
|---|---|
| [Getting started](Getting-Started.md) | Install, start, your first project, save and open |
| [The screen](The-Screen.md) | Sidebar, views and tabs, generator windows, the timeline |
| [Generators](Generators.md) | What a generator is, adding one, the window header, presets |
| [Clipview](Clipview.md) | Layers, clips, columns, Master / Mix / Transition, autoplay, live and next |
| [Linking](Linking.md) | Notches, dragging links, link types, cable view, hold and drag |
| [MIDI](MIDI.md) | Devices, MIDI learn, MIDI mapping |
| [Timeline](Timeline.md) | Play, Stop, Follow, BPM and Tap, Bar, the view switch, show mode |
| [Audio](Audio.md) | Audio Input Analysis: beat, energy, break and drop |
| [Video](Video.md) | Video clips: playback, speed and position |
| [Output and devices](Output-and-Devices.md) | Shader output, NDI, Spout, Art-Net, fixtures, Prolink |
| [Settings](Settings.md) | Appearance, calm notches, cable view, view scaling |
| [Shortcuts and tips](Shortcuts-and-Tips.md) | Keys and gestures |
| [Troubleshooting](Troubleshooting.md) | When something does not work |

## Words

The wiki uses the same words as the app. The short list is in the design glossary:
[Glossary](../../design/wiki/Glossary.md).

## Writing a page

Every new feature or UI change adds or updates its page here in the same pull request (see `../AGENTS.MD`,
*Documentation: every feature gets its user wiki page*).

- Plain Markdown, English, sentence case, the words of the app.
- What it is for, then the steps, then a table of the controls if there are many.
- At least one current screenshot or GIF. Until it is taken, a line `> Screenshot to add: …` says what to capture.
- Only what the app does today. Planned things are marked *(Planned.)*.
