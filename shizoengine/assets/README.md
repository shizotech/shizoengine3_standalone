# Assets

The `assets/` directory contains all visual and processing assets used by the VJ application.

## Overview

Assets are organized into four main categories:
- **Shaders** - GLSL-based visual effects and source generators
- **Textures** - Image and texture assets
- **Views** - UI component assets
- **Generators** - Asset generator definitions

## Directory Structure

```
assets/
├── Shaders/              # GLSL shader definitions
│   ├── Effects/          # Visual effect shaders
│   ├── Sources/          # Source/generator shaders
│   └── Utilities/        # Utility shaders
├── Textures/             # Image and texture assets
├── Views/                # UI view assets
└── Generators/           # Generator definitions
    ├── Audio/            # Audio generators
    ├── Network/          # Network generators
    ├── Output/           # Output generators
    └── Utility/          # Utility generators
```

## Navigation

- [Shaders](Shaders/README.md) - Shader navigation and documentation
- [Textures](Textures/README.md) - Texture assets overview
- [Views](Views/README.md) - View asset documentation
- [Generators](Generators/README.md) - Generator overview

## Notes

- Shaders follow the format documented in [SHADER_GUIDE.MD](Shaders/SHADER_GUIDE.MD)
- All assets are loaded dynamically by the engine
- Asset files use `.asset` extension for configuration metadata
