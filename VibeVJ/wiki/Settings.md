# Settings

The settings have a window of their own, *Settings*. Its pages *Project* and *Links* belong to the project, the page
*Appearance* is personal and valid for every project, and the page *Output* is for the output of the whole window. This
page also explains how to scale views with Page Up and Page Down.

![The Settings window with the page Appearance open](media/settings.png)

## Open the settings

1. Click the gear button (⚙) in the top bar, between the sidebar button and the help button (?).
2. Click a page in the list at the left side of the window: *Project*, *Links*, *Appearance* or *Output*.

The window floats above the program.

- **Move:** drag its header.
- **Close:** click its ×, or press Esc while the window has the focus. Closing keeps all values.

## Project

The settings on the page *Project* are saved with the project. The page has two sections, "Output size" and "Timing".

| Setting | What it does |
|---|---|
| *Target width*, *Target height* | The output size, 1920 × 1080 at the start. New shader generators and the mapping tools start with this size. |
| *Target FPS* | How many frames per second VibeVJ draws. Starts at the refresh rate of your screen. The lowest value is 30; 0 means no limit. It has no options: to map it to MIDI, see [MIDI](MIDI.md#the-midi-tab-in-the-options). |
| *Default sync* | How the time of a new shader generator runs: *Free*, *Manual* or *Sync* (see below). |
| *Current FPS* | Shows the frames per second VibeVJ reaches right now. |

### Default sync

Every shader generator has a *Time* section with its own *Sync* setting. *Default sync* only sets what a **new** shader
starts with; you can change each shader later.

| Choice | The shader's time |
|---|---|
| *Free* | Runs on its own, in seconds, times the shader's *Multiplier*. |
| *Manual* | Stands still. You set *Time* yourself, or link it to another control. |
| *Sync* | Follows the timeline position, in beats. It stops when the timeline stops. |

## Links

The settings on the page *Links* are saved with the project.

| Setting | What it does |
|---|---|
| *Cable view* | Draws every link whose two controls are on screen as a cable: the cable view. |
| *Off-screen link hints* | Puts a small badge with a number on a control whose link partner is not on screen. |

### Cable view and off-screen link hints

*Cable view* turns the whole screen into the cable view: every link whose two ends are visible is drawn as a cable.
It does not open the notches. Turn it off to keep the screen calm while you play. The link button in the
[timeline bar](Timeline.md#the-transport-bar), next to the show mode lock, is the same switch.

- A generator with *Always draw links* on (the link icon in its header) draws its own cables also when *Cable view* is
  off. See [Generators](Generators.md). The link button in the timeline bar counts these local cable views in a small
  bubble and, when you rest the mouse on it, splits to offer a broken link that ends them all ([Linking](Linking.md#seeing-your-links)).
- *Off-screen link hints* work only while *Cable view* is on. The badge counts the links of that control whose other end
  is not visible right now: in another tab, scrolled away or covered by a window. It is not the number of all links.
- In show mode there is no cable view and no badges.

More about cables and notches: [Seeing your links](Linking.md#seeing-your-links) and
[Calm notches](Linking.md#calm-notches).

## Appearance

The settings on the page *Appearance* are personal. They are not saved in the project but in the file
`VibeVJ/engine/style.json`, so they stay the same for every project. They take effect at once.

| Setting | What it does |
|---|---|
| *Interface size* | How big everything is drawn: 90 % to 200 %, on top of the scale of your system. Takes effect the next time VibeVJ starts. See [Interface size](#interface-size). |
| *Accent colour* | The colour picker sets your highlight colour, used for links and selection. Violet at the start. |
| *Reset accent colour* | Sets the accent colour back to violet. |
| *Calm notches* | Where free notches show their grey edge: *Everywhere* (the standard) or *Clipview only*. |
| *Linked notches* | *Open* (the standard): a linked notch is open. *Edge only*: it stays a thin coloured edge until you hover the row. |
| *Area headers* | *Always* (the standard): every area shows its header. *Auto-hide*: the header takes no room and only comes while the mouse is at the top edge of the area. One area can differ, see [The screen](The-Screen.md#the-header-of-an-area). |

### Interface size

VibeVJ follows the display scale of your system. On a screen where that is too small or too big, *Interface size*
changes it for VibeVJ alone:

1. Open *Settings* › *Appearance*.
2. Pick a size under *Interface size*. *100 %* is the scale of your system.
3. Start VibeVJ again.

Useful on a 4K screen under Linux without display scaling (pick *150 %* or *200 %*), or when you stand far from the
screen. It works the same on Windows, Linux and macOS: on a Mac the window keeps its size and everything in it is
drawn bigger or smaller, still sharp on a Retina screen.

### Calm notches

Free notches are thin grey edges at rest in every view. A notch opens in full while the mouse is over its row, while you
drag a link from it, and while it is linked (unless *Linked notches* is *Edge only*). The cable view does not open them.

| Choice | What you see |
|---|---|
| *Everywhere* | Free notches show a grey edge in every view. |
| *Clipview only* | Free notches show a grey edge only in the Clipview; elsewhere they appear when you hover the row. |

To change it:

1. Open *Settings* › *Appearance*.
2. Pick *Everywhere* or *Clipview only* under *Calm notches*.

The cable view draws the cables, it does not open the notches.

### Linked notches

| Choice | What you see |
|---|---|
| *Open* | A linked notch is open at full width, so you see at once which rows are linked. |
| *Edge only* | A linked notch is a thin coloured edge, quieter with many links. Hover the row to open it. |

Show mode always shows linked notches as thin coloured edges, whatever you pick.

### Move areas with

Holding this key and dragging anywhere in an area moves its view to another area: *Alt + drag* (the standard),
*Ctrl + Alt + drag* or *Off*. Some window managers on Linux move a window with Alt + drag and never pass it on; pick
*Ctrl + Alt + drag* there. Dragging an area by its header always works. See
[The screen](The-Screen.md#moving-a-view).

## Output

The page *Output* is for the output of the whole VibeVJ window.

| Setting | What it does |
|---|---|
| *NDI stream* | In the section "NDI". *Enable NDI* sends the whole VibeVJ window, interface included, as an NDI source named after *NDI name* (*ProgramOut* at the start). |

The NDI output of a single shader is on [Output and devices](Output-and-Devices.md).

## View scaling with Page Up and Page Down

You can make the content of a view bigger or smaller, for example to fit a big Clipview on a small screen.

1. Click into the view, or into the sidebar.
2. Press Page Up to make it bigger, Page Down to make it smaller. Each press changes the size by about 10 %.

| Where | How to scale | Kept after a restart |
|---|---|---|
| An area of a view tab, a tab of a Tabview, half of a split | Page Up / Page Down | Yes, with the project |
| The sidebar | Page Up / Page Down | No |
| A Patchview | Mouse wheel, the zoom chip, Ctrl + 0 / Ctrl + 1; right mouse button drags the area | Yes, with the project |
| The timeline area | Mouse wheel; right mouse button drags the area | No |

Scaling does not work while a generator window is maximized.

## See also

- [Linking](Linking.md)
- [The screen](The-Screen.md)
- [Output and devices](Output-and-Devices.md)
- [Getting started](Getting-Started.md)
- [Shortcuts and tips](Shortcuts-and-Tips.md)
