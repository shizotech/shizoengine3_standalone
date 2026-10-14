# Views

The `Views/` directory contains UI view assets for the VJ application interface.

## Overview

Views define the layout and behavior of UI components in the application. They control how clips, patches, and other elements are displayed and interacted with.

## Components

| View | Description |
|------|-------------|
| **Clipview.asset** | Clip grid in layers and columns, for playing live |
| **CueList.asset** | Cues in order, played one after the other |
| **Patchview.asset** | Free area for generator windows and their links |
| **Tabview.asset** | Several views in tabs |
| **Links.asset** | Every link of the project in a list: sender, receiver, type and live value; a click goes to an end |
| **HorizontalSplit.asset** | Two or more views side by side |
| **VerticalSplit.asset** | Two or more views one above the other |

## How views are placed

A view tab of the top bar starts as one empty area. An area holds one view or generator
(`engine/generators/singleview.shio`). The user guide is [The screen](../../wiki/The-Screen.md#views-and-tabs).

- An empty area asks "What goes here?": a tile per view, the presets, and it takes a drop. A small area shows a list.
- An area has a header with *Split right*, *Split down*, *Maximize*, a menu and *Close area*. A right click opens the
  same menu.
- An asset dropped on an edge of a filled area splits it, in the middle it is added as a tab. A view that takes drops
  itself (Patchview, Clipview grid, CueList) gets everything dragged from the *Assets* tab, views and their presets
  too, so views nest (#425). Only a drag by the head of an area or a tab (`payload.layout`) always addresses the area.
- The header of an area, a tab of a Tabview or a view tab of the top bar can be dragged onto another area to move the
  view. A tab under such a drag comes to the front after a moment.
- Alt + drag anywhere in an area moves its view too (`widget.on_grab`, the key is `nanogui.grab_modifier`). Ctrl at
  the drop leaves a copy instead (`drop_copy`).
- A view tab can save its layout as a preset (right click on the tab). A layout is a preset of the split at its top;
  an empty area lists those under "Layouts".
- Only the areas below a view tab of the top bar are split (`can_split()`). A split or Tabview that sits as a window in
  a Patchview keeps its areas as they are.
- Closing never deletes: the view moves into a tab of its own in the top bar. Only *Delete view…* deletes.
- The splits are made by the area, the user does not pick them. A split of an area in a split of the same direction
  adds an area to that split (`insert_view`), so a row of three or more areas is one split. The line between two areas
  is dragged to share their room (`engine/generators/splitpanes.shio`, which both splits include).

## view.json

Every view asset can carry a `view.json` next to its `src/` folder. The area reads it (`view_assets()` in
`engine/generators/singleview.shio`) for the tiles of an empty area, the header and the *Replace view with* list of the
menu. A view without it still shows up, with a plain square icon.

```json
{
	"name": "Side by side",
	"icon": "columns",
	"order": 90,
	"toolbar": false,
	"description": "Views side by side"
}
```

| Key | Default | Meaning |
|---|---|---|
| `name` | folder name without `.asset` | Name on the tile, in the header of an area and in the menu |
| `icon` | `square` | A name for `nanogui.icon()` (see `shzmodule_nanogui/context_nano.cpp`) |
| `order` | 100 | Position among the tiles and in the menu, lowest first |
| `toolbar` | `true` | `false`: not offered in an empty area, not under *Replace view with* and not listed in the *Assets* tab (the two splits) |
| `description` | empty | Purpose on the tile (two short lines) and second line of its tooltip |

Presets in `<View>.asset/presets/*.preset` are offered in an empty area, below the tiles (the first twelve), also those
of a view with `"toolbar": false`.

## Notes

- Views are `.asset` directories like generators; the engine loads `src/__init__.shio`
- Views can be nested: every area of a Tabview or a split takes any view
- A view that holds other views or generators in managed globals needs `on_free()`: it sets those globals to `None`.
  The generator calls it before the module goes. Without it, what the view holds stays alive after the view was
  loaded from a project and then freed (#361)
- A view that holds areas offers `get_view(index)`. The area knows a split by `set_ratio` and a Tabview by
  `add_new_tab`. A split also offers `view_count`, `is_side_by_side`, `insert_view` / `remove_view` (an area more or
  less), `get_sizes` / `set_sizes` / `maximize_view` (*Maximize*, undo) and `ensure_views`

## Navigation

- [Assets Overview](../README.md)
- [Generator Overview](../Generators/README.md)
