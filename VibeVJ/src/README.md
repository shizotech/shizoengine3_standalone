# Source Code

The `src/` directory contains the main application source code.

## Overview

The source code implements the menu-specific application logic, the entire layout UI of VibeVJ, and the core functionality of the VJ application.

## Directory Structure

```
src/
├── defs.shio                 # Core definitions file
├── README.md                 # This file
└── menu/                     # Menu system code
    ├── menu.shio             # Main menu implementation (class main_menu)
    ├── assetbrowser/         # Asset browser component
    ├── generators/           # Generator UI components (tabbed singleview)
    ├── timeline/             # Timeline UI component (bottom panel)
    ├── mainview/             # Main view component (currently empty)
    ├── midi/                 # MIDI input handling (currently empty)
    └── outputs/              # Output configuration UI (currently empty)
```

## Components

### Core
- **defs.shio** - Central definitions and configurations

### Menu System
- **menu.shio** - Main menu implementation (class `main_menu`)
- **assetbrowser/** - Asset browsing and selection UI (fixtures / artnet / shizonet / chat)
- **generators/** - Generator management UI (tabbed `singleview`)
- **timeline/** - Timeline editor UI (bottom panel, BPM/phase nudge logic)
- **mainview/** - Main view component (empty placeholder directory)
- **midi/** - MIDI input handling (empty placeholder directory)
- **outputs/** - Output configuration UI (empty placeholder directory)

## Main UI Layout

The VibeVJ interface is a vertical split arrangement orchestrated by `menu.shio` (class `main_menu`), which instantiates three top-level menus: `assetbrowser`, `generators`, and `timeline`.

- **Left column (fixed width):** The **AssetBrowser** (`menu/assetbrowser/assetbrowser.shio`) is the leftmost panel, hosting asset browsing / fixtures / artnet / shizonet / chat menus.
- **Top-right:** The **GeneratorView & files** panel (`menu/generators/generators.shio`) is anchored to the right of the asset browser, at the top. It holds a tabbed `singleview` for displaying generator views, with a fixed height of `screen.height() - 350`.
- **Bottom (right of the asset browser column):** The **Timeline** (`menu/timeline/timeline.shio`) is anchored to the bottom with a fixed height of ~350px. Dragging the timeline's top edge resizes both the generators panel above it and the timeline itself, keeping the two stacked without overlap.

In short: a vertical split of `[AssetBrowser | GeneratorView & files]` on top, with the `Timeline` along the bottom.

## File Types

- **.shio** - Application-specific source files
- Code organization follows module-based architecture

## Notes

- Source files are compiled/interpreted by the engine
- The menu system provides the primary user interface
- Components are organized by functional area
- Cross-references between components are managed by the engine

## Navigation

- [Agent Onboarding (ROOT)](../AGENT_README.md)
- [Engine Code](../engine/README.md)
- [Assets Overview](../assets/README.md)
- [Asset Guide](../assets/ASSET_GUIDE.MD)
- [Shader Guide](../assets/Shaders/SHADER_GUIDE.MD)
