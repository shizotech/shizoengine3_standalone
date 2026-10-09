# Shortcuts and tips

All keys and mouse or touch gestures of VibeVJ on one page. A key works on the part of the screen you clicked last.

> Screenshot to add: a generator window before and after pressing E (header shown, then hidden), side by side.

## Keys

| Key | Where | Does |
|---|---|---|
| E | A generator window | Hides or shows the window's header (power, name, buttons). Works even when the header is hidden. Same as ⋯ › *Hide header (E)*. |
| Page Up | A view tab or the sidebar | Makes everything in it bigger. |
| Page Down | A view tab or the sidebar | Makes everything in it smaller. |
| Enter | While typing a value | Sets the value. |
| Esc | While typing a value | Keeps the old value. |

To use E or Page Up / Page Down, first click inside the window, view or sidebar (not into a text field), then press the key. In a graph
or a mapping editor, Page Up / Page Down change that editor's grid instead.

## Value fields and sliders

| Gesture | Does |
|---|---|
| Click on a slider | The value jumps to that point. |
| Drag on a slider | Sets the value as you move. |
| Drag the thumb (the violet bar in the slider) | Picks it up where it is, the value does not jump. It gets wider when the mouse is on it. Works at 0 % and 100 % too, next to the notches. |
| Shift + drag on a slider | Fine control: the value does not jump, and it moves ten times slower than the mouse. You can also press Shift during a drag. |
| Double click on a slider | Opens a box to type the value. Enter sets it, Esc keeps the old one. |
| Click on a number field | Type a new value, then Enter. |
| Double click on a text or number field | Selects the whole text, ready to overwrite. |
| Mouse wheel over a number field you clicked | Changes the value step by step; with Shift ten steps at a time. |

## Linking

| Gesture | Does |
|---|---|
| Drag from the right notch onto another control | Makes a link (preferred). |
| Drag from the left notch onto another control | Also makes a link, from the row you start on. |
| Drag a link onto a control it already goes to | Removes that link. |
| Click a notch | Opens the control's options and link list. |
| Hold still on a row for 400 ms, then drag | Starts a link from anywhere on the row: right half from the output, left half from the input. Made for touch. |

More in [Linking](Linking.md).

## Clipview

| Gesture | Does |
|---|---|
| Click a clip picture | Starts the clip. |
| Hold a clip picture (*Trigger* = *Hold*) | Plays the clip while held, then goes back. |
| Click a clip's name tag | Selects the clip and shows its settings. |
| Drag a clip by its name tag | Moves it to another cell. |
| Ctrl while dropping a clip | Copies it instead of moving it. |
| Drag an asset onto a clip | Stacks it onto that clip as an effect. |

More in [Clipview](Clipview.md).

## Views, tabs and the sidebar

| Gesture | Does |
|---|---|
| Mouse wheel on the Patchview or the timeline's *Loops* / *Patch* area | Zooms in or out. |
| Right mouse button drag there | Moves the view around. |
| Double click a view tab | Renames the tab. |
| Double click a file in *Assets* | Opens it in a new tab. |

## Timeline

| Gesture | Does |
|---|---|
| Mouse wheel on the ruler | Zooms around the mouse. |
| Drag on the ruler | Left or right moves the view, up or down zooms. |
| Right click on the ruler | Moves the playhead to the nearest grid line. |
| Click *Tap* on each beat | Sets the tempo. |
| Click the lock | Turns show mode on. |
| Hold the lock for 400 ms, then let go | Leaves show mode. |

More in [Timeline](Timeline.md).

## Code editor

When a file opens as text (for example a shader):

| Key | Does |
|---|---|
| Ctrl + F | Find. |
| Ctrl + H | Replace (while the find bar is open). |
| F3 / Shift + F3 | Next / previous match. |
| Esc | Closes the find bar. |
| Ctrl + Z | Undo. |
| Ctrl + Y or Ctrl + Shift + Z | Redo. |
| Ctrl + Space | Suggestions. |
| Ctrl + A, Ctrl + C, Ctrl + X, Ctrl + V | Select all, copy, cut, paste. |

## Tips

- **Before the show,** turn on show mode. Nothing can be linked, moved or closed by accident, but every value, clip and MIDI
  control keeps working.
- **Lost a cable?** Turn on *Cable view* in *Project* › *Settings* to see every link on screen. With *Off-screen link
  hints* a badge counts the links that end somewhere you can't see.
- **One generator's wiring only:** click the link icon in its header (*Always draw links*).
- **Too many cables after patching?** The small violet bubble on the link button in the timeline bar says how many generators
  still draw their own cables. Rest the mouse on the button and click the broken link that slides in: all of them stop at once.
- **Touch screen:** use hold and drag to link, and use the Clipview's *Live* toggle so clips can't be dragged away.

## See also

- [The screen](The-Screen.md)
- [Linking](Linking.md)
- [Clipview](Clipview.md)
- [Timeline](Timeline.md)
- [Settings](Settings.md)
- Design: [Links and notches](../../design/wiki/Links-and-Notches.md#hold-and-drag-touch-and-mouse)
