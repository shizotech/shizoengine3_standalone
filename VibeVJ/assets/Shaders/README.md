# Shaders

The `Shaders/` directory contains all GLSL shader definitions for the VJ application.

## Overview

Shaders are organized into three main categories:
- **Effects** - Visual processing shaders (color shifts, kaleidoscope, feedback, etc.)
- **Sources** - Generator shaders that produce visual content from scratch
- **Utilities** - Helper and utility shaders

## Shader Format

Shaders follow the format documented in [SHADER_GUIDE.MD](SHADER_GUIDE.MD):
- Directory-based structure with `.glsl` extension
- Entry point: `src/__init__.glsl`
- Supports annotation system for UI controls
- Shadertoy-compatible format supported

## Directory Structure

```
Shaders/
├── Effects/              # Visual effect shaders
│   ├── Color/            # Color manipulation effects
│   ├── Examples/         # Example shaders
│   ├── Exciters/         # Strobe, chromatic, glitch
│   ├── Feedback&Blur/    # Feedback loops, blurs, frame cache
│   ├── Glow&Light/       # Glow and lighting effects
│   ├── Kaleidoscope/     # Kaleidoscope effects
│   ├── Mapping/          # Projection mapping helpers
│   ├── Morph&Mirror/     # Displacement, mirror, morph, instancing
│   ├── Retro/            # Retro/vintage effects
│   ├── Utility/          # Effect utilities
│   ├── Video3D/          # Picture into 3D or time: RuttEtra, PointCloud, Voxels, SlitScan, Datamosh
│   └── basic/, morph/    # Older distortion and cloning effects
├── Sources/              # Source/generator shaders
│   ├── 3D/               # 3D rendering shaders
│   ├── Audio/            # Audio-reactive shaders
│   ├── Basic/            # Basic generator shaders
│   ├── Examples/         # Example source shaders
│   ├── Objects/          # Object-based shaders
│   ├── Patterns/         # Pattern source shaders
│   ├── Sequences/        # Sequence-based shaders
│   ├── Simulations/      # Simulation shaders
│   ├── Stuff/            # Miscellaneous shaders
│   └── Things/           # Additional shaders
└── Utilities/            # Utility shaders
    ├── output.glsl       # Output shader
    └── Shaderstack.asset # Shader stack configuration
```

## Quick Links

- [Effects Overview](Effects/README.md)
- [Sources Overview](Sources/README.md)
- [Shader Format Guide](SHADER_GUIDE.MD)
