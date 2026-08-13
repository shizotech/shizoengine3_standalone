# Engine Code

The `engine/` directory contains the core engine implementation for the VJ application.

## Overview

The engine provides the fundamental processing capabilities, asset management, and integration layer between source code and assets.

## Directory Structure

```
engine/
├── style.json               # Styling configuration
├── last_project.dat         # Last project data
├── assets/                  # Engine asset definitions
│   ├── composition.glsl     # Composition shader
│   ├── layerblend.glsl      # Layer blending shader
│   └── shaderstack.asset    # Shader stack configuration
├── generators/              # Generator implementation
│   ├── extensions/          # Extension modules
│   ├── clipstackview.shio   # Clip stack view
│   ├── clipview.shio        # Clip view
│   ├── generatoritem.shio   # Generator item
│   └── generatorview.shio   # Generator view
└── processes/               # Processing logic
    ├── audio_process.shio   # Audio processing
    ├── crash.log            # Crash logging
    └── monitor_process.shio # Monitor processing
```

## Components

### Core Files
- **style.json** - Application styling and appearance configuration
- **last_project.dat** - Last session project data preservation

### Assets
- **composition.glsl** - Visual composition shader
- **layerblend.glsl** - Layer blending effects
- **shaderstack.asset** - Shader stack configuration

### Generators
- **extensions/** - Additional generator modules
- **clipstackview.shio** - Clip stack management UI
- **clipview.shio** - Individual clip view
- **generatoritem.shio** - Generator item representation
- **generatorview.shio** - Generator overview view

### Processes
- **audio_process.shio** - Audio processing logic
- **monitor_process.shio** - Monitor/output processing
- **crash.log** - Crash dump logging

## Notes

- The engine manages the full processing pipeline
- Assets are loaded and managed dynamically
- Generator implementations handle GLSL shader processing
- Process modules handle real-time computation

## Navigation

- [Source Code](../src/README.md)
- [Assets Overview](../assets/README.md)
- [Root README](../README.md)
