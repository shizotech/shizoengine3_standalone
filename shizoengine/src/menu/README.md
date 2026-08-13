# Menu Code

The `src/menu/` directory contains the menu system implementation for the VJ application.

## Overview

The menu system provides the primary user interface for controlling the VJ application. It includes asset browsing, generator management, MIDI input, output configuration, and timeline editing.

## Directory Structure

```
src/menu/
├── menu.shio                # Main menu implementation
├── assetbrowser/            # Asset browser component
├── generators/              # Generator UI components
├── mainview/                # Main view component
├── midi/                    # MIDI input handling
├── outputs/                 # Output configuration UI
└── timeline/                # Timeline editor UI
```

## Components

### menu.shio
- Main menu orchestration
- Component initialization and communication
- Global state management

### assetbrowser/
- Asset browsing and selection
- File system integration
- Asset preview functionality

### generators/
- Generator configuration UI
- Parameter editing interfaces
- Generator management controls

### mainview/
- Primary visual output display
- Real-time preview functionality
- View mode controls

### midi/
- MIDI input processing
- MIDI mapping configuration
- Controller integration

### outputs/
- Output device configuration
- Display selection and setup
- Resolution and mode settings

### timeline/
- Timeline editor interface
- Clip sequencing controls
- Time-based parameter automation

## File Types

- **.shio** - Application-specific source files
- Components are organized as subdirectories with main implementation files

## Notes

- The menu system is the primary user interface
- Components communicate through the engine's event system
- UI state is synchronized with the engine state
- Customization is possible through configuration files

## Navigation

- [Source Code Overview](../README.md)
- [Root README](../../README.md)
