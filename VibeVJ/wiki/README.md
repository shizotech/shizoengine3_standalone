# VibeVJ user wiki

How to use VibeVJ, written for VJs. Each page says what a part of the program is for and how to use it step by step.

The same pages are in the program: the **?** button of the top bar, or F1, opens them in the Help window.

The design wiki (`../../design/wiki/`) explains what the colours, notches and sizes of the interface mean. This wiki
explains what you do with them.

![VibeVJ with the sidebar, a Clipview and a Patchview side by side, and the timeline bar](media/overview.png)

## Pages

| Page | What it covers |
|---|---|
| [Getting started](Getting-Started.md) | Install, start, your first project, save and open |
| [The screen](The-Screen.md) | Top bar, sidebar, areas and views, moving views, undo, the Help window, tooltips |
| [Generators](Generators.md) | What a generator is, adding one, the window header, selecting and moving, presets |
| [Assets](Assets.md) | What comes with VibeVJ: generators, shaders, views, mapping, fixtures |
| [Linking](Linking.md) | Notches, dragging links, link types, the options of a control, envelopes, cable view |
| [Clipview](Clipview.md) | Layers, clips, columns, Master / Mix / Transition, autoplay, live and next, macros |
| [CueList](CueList.md) | Clips as lists of cues with big buttons |
| [Timeline](Timeline.md) | Play, Stop, BPM and Tap, Bar, the view switch, show mode |
| [MIDI](MIDI.md) | Devices, MIDI learn, MIDI mapping |
| [Audio](Audio.md) | Audio Input Analysis: beat, energy, break and drop |
| [Video](Video.md) | Video clips: playback, speed, formats |
| [Output and devices](Output-and-Devices.md) | Shader output, NDI, Spout, Art-Net, fixtures, mapping, Prolink |
| [Settings](Settings.md) | Project, links, appearance, output, view scaling |
| [Shortcuts and tips](Shortcuts-and-Tips.md) | Keys and gestures |
| [Troubleshooting](Troubleshooting.md) | When something does not work |

## Where to start

- New here: [Getting started](Getting-Started.md), then [The screen](The-Screen.md).
- You want things to move: [Linking](Linking.md) and [Audio](Audio.md).
- You play live: [Clipview](Clipview.md), [MIDI](MIDI.md) and [show mode](Timeline.md#show-mode).
- You bring the picture out: [Output and devices](Output-and-Devices.md).

## Words

The wiki uses the same words as the program. They are in `glossary.json`: the Help window shows them as its page
*Glossary*, and the tooltips of the program show them as links.

## Writing a page

Every new feature or UI change adds or updates its page here in the same pull request (see `../AGENTS.MD`,
*Documentation: every feature gets its user wiki page*).

- Plain Markdown, English, sentence case, the words of the program.
- What it is for, then the steps, then a table of the controls if there are many.
- At least one current screenshot or GIF in `media/`. Until it is taken, a line `> Screenshot to add: …` says what to
  capture (the Help window does not show such a line).
- Only what the program does today. Planned things are marked *(Planned.)*.

### Links

- Link to the place that says more, not only to the page: `[Moving a view](The-Screen.md#moving-a-view)`, on the same
  page `[Moving a view](#moving-a-view)`.
- The name of a heading in a link is its text in small letters, signs dropped, a `-` for every blank: "Undo and
  redo" is `#undo-and-redo`. GitHub and the Help window make it the same way.
- Renaming a heading breaks the links to it: search the wiki, `glossary.json` and the tooltips (`[[wiki:`) for its
  old name.
- `python _testing/wiki/check_links.py` (from the root of the repository) checks every link, picture, glossary page
  and tooltip link, and says which ones lead nowhere.
- A page ends with "See also": a list of links, one per line. The Help window shows them as buttons.
- In the Help window a link shows a tooltip: the glossary term with the same name as the link text, or the heading
  and the first lines of the part it leads to. So start every part with a sentence that says what it is about.

### What the Help window shows

Headings (three levels), paragraphs, lists (one level of nesting), tables, pictures and GIFs, notes (`>`), code
blocks, links. Bold and italic show in paragraphs, list items and notes (not in tables and headings, there they lose
their marks). A `|` inside a table cell is written `\|`.

### The glossary and the tooltips

`glossary.json` has one entry per term: `title`, `text` and `page`.

- `text` is one or two sentences. Other terms in it are links: `[[area]]`, or `[[area|areas]]` to show another word.
- `page` is the place in the wiki that says more: `The-Screen#views-and-tabs`.
- A tooltip in the program links a term the same way: `"Split right: an empty [[area]] appears beside this one"`.
- A tooltip leads into the wiki with `[[wiki:The-Screen#moving-a-view]]` on a line of its own. It shows as *More in
  the wiki (F1)*, and F1 on the control follows it. A tooltip that links a term needs none: F1 follows the page of
  the term.
