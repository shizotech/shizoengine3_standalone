# Source Code

The `src/` directory contains the main application source code.

## Overview

The source code implements the application logic, UI framework integration, and core functionality of the VJ application.

## Directory Structure

```
src/
├── defs.shio                 # Core definitions file
└── menu/                     # Menu system code
    ├── menu.shio             # Main menu implementation
    ├── assetbrowser/         # Asset browser component
    ├── generators/           # Generator UI components
    ├── mainview/             # Main view component
    ├── midi/                 # MIDI input handling
    ├── outputs/              # Output configuration UI
    └── timeline/             # Timeline UI component
```

## Components

### Core
- **defs.shio** - Central definitions and configurations

### Menu System
- **menu.shio** - Main menu implementation
- **assetbrowser/** - Asset browsing and selection UI
- **generators/** - Generator management UI
- **mainview/** - Primary view component
- **midi/** - MIDI input processing and UI
- **outputs/** - Output configuration UI
- **timeline/** - Timeline editor UI

## File Types

- **.shio** - Application-specific source files
- Code organization follows module-based architecture

## Notes

- Source files are compiled/interpreted by the engine
- The menu system provides the primary user interface
- Components are organized by functional area
- Cross-references between components are managed by the engine

## Navigation

- [Root README](../README.md)
- [Engine Code](../engine/README.md)
- [Assets Overview](../assets/README.md)
