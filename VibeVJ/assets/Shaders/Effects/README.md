# Effects Shaders

The `Effects/` directory contains visual effect shaders that process existing visual content.

## Overview

Effects shaders transform input textures/video into new visuals. They typically require an input texture and produce output through GLSL shader processing.

## Categories

| Category | Description |
|----------|-------------|
| **Backgrounds** | Background generation and processing shaders |
| **Color** | Color manipulation and adjustment effects |
| **Examples** | Reference and example effect shaders |
| **Exciters** | Exciter-based effect shaders |
| **Feedback** | Feedback loop and recursive effects |
| **Glow&Light** | Glow, bloom, and lighting effects |
| **Kaleidoscope** | Kaleidoscope and symmetry effects |
| **Morph** | Morphing and transformation effects |
| **Patterns** | Pattern generation and modulation effects |
| **Retro** | Retro, vintage, and analog emulation effects |
| **Utility** | Effect utility and helper shaders |

## Shader Format

All effects follow the GLSL shader format:
- Entry point: `src/__init__.glsl`
- Input: `uniform sampler2D in` (required)
- Annotations for UI controls (`//@slider`, `//@float`, etc.)
- Shadertoy format supported (`mainImage` function)

## Notes

- Effects are typically chained in the processor pipeline
- Each effect can have multiple uniforms controlled via annotations
- Time uniform `u_time` is available for animation

## Navigation

- [Shaders Overview](../README.md)
- [Shader Format Guide](../SHADER_GUIDE.MD)
