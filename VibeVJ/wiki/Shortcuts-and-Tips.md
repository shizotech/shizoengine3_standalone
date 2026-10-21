# Shortcuts and tips

All keys and mouse or touch gestures of VibeVJ on one page. A key works on the part of the screen you clicked last.

> Screenshot to add: a generator window before and after pressing E (header shown, then hidden), side by side.

## Keys

| Key | Where | Does |
|---|---|---|
| F1 | Anywhere | Opens [Help](The-Screen.md#the-help-window): this wiki, in the program. With the mouse on something that has a tooltip, it opens the part of the wiki that tooltip is about; otherwise the page for the part of the screen the mouse is in. |
| F11 | Anywhere | The window fills the whole monitor, and back. See [The program window](The-Screen.md#the-program-window). |
| F11 | A [view window](The-Screen.md#view-windows) | That window fills its monitor without a frame (a projector, an output monitor), and back. |
| Ctrl + K | Anywhere | The [command palette](#the-command-palette): find an action, an asset, a project or a page of the wiki by typing. |
| Ctrl + Shift + P | Anywhere | The [performance overlay](Troubleshooting.md#the-output-stutters): FPS, frame time, GPU time, video memory and the generators that need the most. |
| Ctrl + S | Anywhere | *Save* the project, as in the [Projects tab](Getting-Started.md#save). A new project first asks for a name. |
| Ctrl + Shift + S | Anywhere | *Save as…*: asks for a new name. |
| Space | Anywhere | Play or pause the [timeline](Timeline.md#the-transport-bar). |
| Shift + Space | Anywhere | Stop the timeline and go back to the start. |
| T | Anywhere | Tap the tempo, like the *Tap* button: press it on each beat. |
| Ctrl + B | Anywhere | [Blackout](Output-and-Devices.md#blackout): all outputs to black at once; again: back with a fade. |
| Ctrl + Z | The views | [Undo](The-Screen.md#undo-and-redo): takes back the last change of the layout, a link or a value. |
| Ctrl + Y or Ctrl + Shift + Z | The views | Redo. |
| Ctrl + E | An area of a view tab | *Split right*: an empty area appears beside it. |
| Ctrl + Shift + E | An area of a view tab | *Split down*: an empty area appears below it. |
| Ctrl + D | An area of a view tab | *Duplicate*: a copy of the view appears beside it. |
| Ctrl + Space | An area in a split | *Maximize*, and back. |
| Ctrl + W | An area in a split, or a tab of a Tabview | *Close area* (or the tab). The view moves into a tab of its own in the top bar, nothing is deleted. |
| F6 / Shift + F6 | A view tab | Goes to the next / previous area. A violet line at its top edge marks it. |
| Ctrl + Tab / Ctrl + Shift + Tab | The views | Brings the next / previous tab of the top bar to the front. |
| E | A generator window | Hides or shows the [header of the window](Generators.md#hide-and-show-the-header-with-e) (power, name, buttons). Same as ⋯ › *Hide header (E)*. |
| Page Up / Page Down | A view tab or the sidebar | Makes everything in it bigger / smaller. See [View scaling](Settings.md#view-scaling-with-page-up-and-page-down). |
| Enter / Esc | While typing a value | Enter sets the value, Esc keeps the old one. |
| Enter / Esc | A dialog that asks for a name | Enter confirms it, Esc cancels it. You can type at once, the field has the focus. |
| Esc | The *Settings* or *Help* window | Closes the window. All values stay. |
| Esc | A tooltip that is locked | Closes it. |

- To use E or Page Up / Page Down, first click inside the window, view or sidebar (not into a text field), then press
  the key. In a graph or a mapping editor, Page Up / Page Down change the grid of that editor instead.
- The keys for areas work while the views have the focus (click into them once). They act on the area the mouse is in.
  After F6 they act on the marked area, until the mouse enters an area again. The buttons in the header of an area name
  their key in the tooltip. More in [The screen](The-Screen.md#views-and-tabs).
- Undo, redo and the keys for areas are off in [show mode](Timeline.md#show-mode).
- Ctrl + K, Ctrl + S, Ctrl + B, Space, Shift + Space and T work everywhere, also in show mode, but not while you type: a text field, a
  value you type, the code editor (there Ctrl + S saves the code) and the mapping editors keep their keys. After a click
  on a button or a slider they work at once.

### On a Mac

Cmd (⌘) does what this page calls Ctrl: Cmd + K, Cmd + S, Cmd + B, Cmd + Z, Cmd + E, Cmd + W, Cmd + 0, Cmd while dropping a clip, Cmd + C in a text
field, and so on. macOS keeps a few keys for itself, so these differ:

| Windows and Linux | Mac | Why |
|---|---|---|
| F11 | Ctrl + Cmd + F (F11 too, where macOS does not use it for itself), or the green traffic light | The Mac key for the full screen. VibeVJ goes into the full screen of macOS, in a Space of its own. |
| Ctrl + Y (redo) | Cmd + Shift + Z (Cmd + Y too) | The Mac key for redo. |
| Ctrl + Space (maximize an area) | Cmd + Return | Cmd + Space opens Spotlight. |
| Ctrl + Tab / Ctrl + Shift + Tab | Control + Tab / Control + Shift + Tab | Cmd + Tab switches programs. |
| Ctrl + Space in the code editor | Control + Space | Spotlight. |
| Ctrl + H in the code editor | Cmd + Option + F | Cmd + H hides the program. |
| Right click | Control + click also works | As everywhere on a Mac. |

On a Mac the tooltips, the command palette and the menu bar show the Mac keys: ⌘ is Cmd, ⌥ Option, ⇧ Shift and ⌃
Control, so *Undo (⌘Z)*, *Redo (⇧⌘Z)*, *Maximize this area (⌘↩)*. The menu bar has an item for most keys of this page;
choosing it does exactly what the key does. Two fingers on the trackpad move a view, a pinch zooms
([On a Mac](The-Screen.md#on-a-mac)).

## The command palette

Press **Ctrl + K** and type a few letters of what you want. The list shows what matches, at most ten:

| Kind | On the right | Enter |
|---|---|---|
| Actions | Their key (Ctrl+S) or where they are | Runs it: Save, Blackout, Play / pause, Split right, Settings, Help, Log, … |
| Assets | *Add* and the folder | Puts the generator, shader, view, picture, video or preset into the area the mouse is in, like a drop: an empty area takes it, a full one gets it as a tab. Undo takes it back. |
| Projects, templates | *Open project*, *New project from template* | Opens it. |
| Wiki pages | *Wiki* | Opens the [Help window](The-Screen.md#the-help-window) at that page. |

- Several words find what has all of them (`shader spiral`). What starts with your text comes first.
- Up / Down choose another line, Enter runs it, a click on a line too. Esc closes the palette.
- In show mode the palette has no assets and none of the actions that change the layout.

## Tooltips

Rest the mouse on a button or a control and its tooltip shows.

| Gesture | Does |
|---|---|
| Rest on the thing for a second | A tooltip with links locks: its edge turns violet, and the mouse can move into it. A small bar shows the wait. |
| Middle click | Locks the tooltip at once. |
| Rest on a word shown as a link | Opens the tooltip of that word, on top. It can lock too, and so on. |
| Click *More in the wiki (F1)* | Opens the wiki at the part the tooltip is about. |
| F1 | The same, without locking the tooltip first. |
| Click on the text of a locked tooltip | Closes it. |
| Esc | Closes the topmost locked tooltip. |
| Click anywhere else | Closes all tooltips. |

All the words are in the *Glossary* of the Help window.

## Value fields and sliders

| Gesture | Does |
|---|---|
| Click on a slider | The value jumps to that point. |
| Drag on a slider | Sets the value as you move. |
| Drag the thumb (the violet bar in the slider) | Picks it up where it is, the value does not jump. It gets wider when the mouse is on it. Works at 0 % and 100 % too, next to the notches. |
| Shift + drag on a slider | Fine control: the value does not jump, and it moves ten times slower than the mouse. You can also press Shift during a drag; it stays fine until you let go of the mouse. |
| Double click on a slider | Opens a box to type the value. Enter sets it. A value outside the range is set to its nearest end. |
| Click on a number field | Type a new value, then Enter. Leaving the field also sets it; text that is no number keeps the old value. |
| Double click on a text or number field | Selects the whole text, ready to overwrite. |
| Mouse wheel over a number field you clicked | Changes the value step by step; with Shift ten steps at a time. |

- A slider has no mouse wheel and no reset by double click. Type the value to set it exactly.
- The fill of a slider shows the value that is sent, the thumb where you put it. They differ while *smoothing* or an
  envelope is on: see [Envelope and sync](Linking.md#envelope-and-sync).
- In a text or number field: Left / Right / Home / End move the caret, with Shift they select. Shift + click selects
  up to the click. Ctrl + A, C, X, V select all, copy, cut and paste.

## Linking

| Gesture | Does |
|---|---|
| Drag from the right notch onto another control | Makes a link (preferred). |
| Drag from the left notch onto another control | Also makes a link, from the row you start on. |
| Drag a link onto a control it already goes to | Removes that link. |
| Click a notch | Opens the options of the control and its link lists. |
| Hold still on a row for 400 ms, then drag | Starts a link from anywhere on the row: right half from the output, left half from the input. Made for touch. |
| Rest on a linked notch | Shows the cables of that row for a moment. |

More in [Linking](Linking.md).

## Clipview and CueList

| Gesture | Does |
|---|---|
| Click a clip picture | Starts the clip. |
| Hold a clip picture (*Trigger* = *Hold*) | Plays the clip while held, then goes back. |
| Click the name tag of a clip | Selects the clip and shows its settings. Again: deselects it. |
| Drag a clip by its name tag | Moves it to another cell. |
| Ctrl while dropping a clip | Copies it instead of moving it. |
| Drag an asset onto a clip | Stacks it onto that clip as an effect. |
| Mouse wheel on the grid | Scrolls it. With Shift: makes the cells bigger or smaller. |
| Drag an asset onto a CueList | A new list; onto a list: one more cue. |

More in [Clipview](Clipview.md) and [CueList](CueList.md).

## Views, tabs and the sidebar

| Gesture | Does |
|---|---|
| Mouse wheel on a Patchview or the *Loops* / *Patch* area of the timeline | Zooms in or out at the cursor. Away from you zooms in, as everywhere in VibeVJ. |
| Ctrl + 0 / Ctrl + 1 | The Patchview the mouse was over last shows everything / goes to 100 %. See [Zoom and the grid of a Patchview](The-Screen.md#zoom-and-the-grid-of-a-patchview). |
| Right mouse button drag there | Moves the view around. |
| Double click a view tab | Renames the tab. |
| Drag a view tab along the top bar | Moves the tab. |
| Drag a view tab down out of the top bar, the header of an area, or a tab of a Tabview | Moves the view to the area you drop it on: an edge splits, the middle adds a tab. See [Moving a view](The-Screen.md#moving-a-view). |
| Hold such a drag over another tab | That tab comes to the front, so you can drop into it. |
| Alt + drag anywhere in an area | Moves its view, like a drag by the header. The key is a setting: [*Move areas with*](Settings.md#move-areas-with). |
| Ctrl while dropping a view | Drops a copy; the view you dragged stays where it is. |
| Right click in an area | Opens [the menu of the area](The-Screen.md#the-menu-of-an-area). Not on a button, a text field or a control: they keep their own right click. |
| Click the header of a generator in a Patchview | Selects it. Ctrl or Shift + click adds one or takes it away. |
| Drag on the empty canvas of a Patchview | A frame that selects every generator it touches. With Shift or Ctrl it adds to the selection. |
| Alt + drag a generator in a Patchview | Takes it, with the others that are selected, to another Patchview or into an area. Ctrl while dropping leaves copies. See [Select and move generators](Generators.md#select-and-move-generators). |
| Right click on a view tab of the top bar | *Rename…*, *Save layout as preset…*, *Delete tab…*. |
| Double click a file in *Assets* | Opens it in a new tab. |

## Timeline

| Gesture | Does |
|---|---|
| Mouse wheel over the timeline | Zooms around the mouse. |
| Drag on the ruler | Left or right moves the view, up or down zooms. |
| Right click on the ruler | Moves the playhead to the nearest whole beat. |
| Click *Tap* on each beat | Sets the tempo. |
| Click the lock | Turns show mode on. |
| Hold the lock for 400 ms, then let go | Leaves show mode. |

More in [Timeline](Timeline.md).

## Help window

| Gesture | Does |
|---|---|
| Rest on a link | A tooltip shows what is behind it. |
| Click a link | Goes there. |
| The arrow in the header | Goes back to where you followed the last link. |
| Rest on a picture | A magnifier shows the part under the mouse at full size. |
| Click a picture | Shows it big. A click on the big picture closes it. |

## Code editor

When a file opens as text (for example a shader):

| Key | Does |
|---|---|
| Ctrl + F | Find. |
| Ctrl + H | Replace (while the find bar is open). |
| F3 / Shift + F3 | Next / previous match (while the find bar is open). |
| Esc | Closes the find bar, or the suggestions. |
| Ctrl + Z | Undo. |
| Ctrl + Y or Ctrl + Shift + Z | Redo. |
| Ctrl + Space | Suggestions. Up / Down choose, Enter or Tab takes one. |
| Tab / Shift + Tab | Indents the selected lines, or takes the indent back. |
| Ctrl + A, Ctrl + C, Ctrl + X, Ctrl + V | Select all, copy, cut, paste. |
| Double click | Selects a word. Shift + click selects up to the click. |
| Shift + mouse wheel | Makes the text bigger or smaller. |

## Tips

- **Before the show,** turn on [show mode](Timeline.md#show-mode). Nothing can be linked, moved or closed by accident,
  but every value, clip and MIDI control keeps working.
- **Lost a cable?** Turn on *Cable view* with the link button in the timeline bar to see every link on screen. With
  *Off-screen link hints* a badge counts the links that end somewhere you cannot see. See
  [Seeing your links](Linking.md#seeing-your-links).
- **The wiring of one generator only:** click the link icon in its header (*Always draw links*).
- **Too many cables after patching?** The small violet bubble on the link button in the timeline bar says how many
  generators still draw their own cables. Rest the mouse on the button and click the broken link that slides in: all
  of them stop at once.
- **Touch screen:** use hold and drag to link, and use the *Live* toggle of the Clipview so clips cannot be dragged
  away.
- **Closed the wrong thing?** Closing an area never deletes: the view is in a tab of its own in the top bar. And
  Ctrl + Z takes the step back.
- **Something does not work?** [Troubleshooting](Troubleshooting.md) starts with the three usual causes.

## See also

- [The screen](The-Screen.md)
- [Linking](Linking.md)
- [Clipview](Clipview.md)
- [Timeline](Timeline.md)
- [Settings](Settings.md)
- [Troubleshooting](Troubleshooting.md)
