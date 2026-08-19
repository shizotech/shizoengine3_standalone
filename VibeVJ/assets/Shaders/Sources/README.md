# Source Shaders

The `Sources/` directory contains generator shaders that produce visual content from scratch without external input.

## Overview

Source shaders generate visuals independently - they don't require input textures. They are used as the starting point in the processor pipeline.

## Categories

| Category | Description |
|----------|-------------|
| **3D** | Three-dimensional rendering and projection shaders |
| **Audio** | Audio-reactive source shaders |
| **Basic** | Fundamental generator shaders |
| **Examples** | Reference and example source shaders |
| **Objects** | Object-based generator shaders |
| **Patterns** | Pattern generation source shaders |
| **Sequences** | Sequence-based generator shaders |
| **Simulations** | Simulation and procedural generation shaders |
| **Stuff** | Miscellaneous generator shaders |
| **Things** | Additional generator shaders |

## Shader Format

All sources follow the GLSL shader format:
- Entry point: `src/__init__.glsl`
- No input required (self-contained)
- Annotations for UI controls
- Shadertoy format supported

## Notes

- Sources can be chained with effects for full pipeline
- Time uniform `u_time` is available for animation
- Some sources may accept optional inputs for variation

## Navigation

- [Shaders Overview](../README.md)
- [Shader Format Guide](../SHADER_GUIDE.MD)
