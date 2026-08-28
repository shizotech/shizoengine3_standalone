# VJ Program

A VJ (Video Jockey) application for live visual performances and creative video output, written in shizoscript.

## Overview

This project provides a real-time visual generation and processing system with:
- **Shaders** - GLSL-based visual effects and source generators
- **Generators** - Asset generators for audio, network, output, and utility purposes
- **Textures** - Texture assets for shader and visual processing
- **Views** - UI components for clip and patch management
- **Engine** - Core engine code for processing and asset management
- **Source Code** - Application logic and menu system
- **Projects** - Project configuration and state files

The entire program is written in shizoscript, glsl and (on windows platforms) hlsl.

## Directory Structure

```
├── assets/                 # Visual and processing assets
│   ├── Shaders/            # GLSL shader definitions
│   │   ├── Effects/        # Visual effect shaders (Backgrounds, Color, Patterns, etc.)
│   │   ├── Sources/        # Source/generator shaders (3D, Basic, Patterns, etc.)
│   │   └── Utilities/      # Utility shaders
│   ├── Textures/           # Image and texture assets
│   ├── Views/              # UI view assets (Clipview, Patchview)
│   └── Generators/         # Generator definitions
│       ├── Audio/          # Audio analysis generators
│       ├── Network/        # Network/external input generators
│       ├── Output/         # Output configuration generators
│       └── Utility/        # Utility generators
├── src/                    # Application source code
│   ├── menu/               # Menu system code
│   └── defs.shio           # Core definitions
├── engine/                 # Engine implementation
│   ├── assets/             # Engine asset definitions
│   ├── generators/         # Generator implementation
│   └── processes/          # Processing logic
├── projects/               # Project configuration files
│   └── first_time/         # Initial project state
├── README.md               # This file
├── crash.log               # Crash logging
├── deploy.shio             # Deployment script
└── preview.png             # Preview image
```

## Quick Links

### Navigation

- [Engine Code Navigation](engine/README.md)
- [Source Code Navigation](src/README.md)
- [Assets Overview](assets/README.md)

### Implementations

- [Assets Creation Documentation](assets/ASSET_GUIDE.MD)
- [Shader Documentation](assets/Shaders/SHADER_GUIDE.MD)
