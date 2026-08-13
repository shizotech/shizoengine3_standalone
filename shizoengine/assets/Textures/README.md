# Textures

The `Textures/` directory contains image and texture assets used by shaders and visual processing.

## Overview

Texture assets are loaded and bound to shader uniforms as `sampler2D` inputs. They provide the visual material for shaders to process.

## Files

| File | Description |
|------|-------------|
| `noisegrey.png` | Greyscale noise texture |
| `sky.png` | Sky image texture |
| `sky2.png` | Alternative sky texture |
| `skyscraper8.jpg` | Skyscraper image (JPEG) |
| `skyscraper8.png` | Skyscraper image (PNG) |
| `strauss.png` | Strauss image texture |
| `summer-4181783.png` | Summer-themed texture |
| `tex00.png` through `tex19.png` | Generic texture assets |
| `wood.png` | Wood texture |
| `wood2.png` | Alternative wood texture |

## Usage

Textures are typically bound to shader inputs:
```glsl
uniform sampler2D input;      // Main input
uniform sampler2D input1;     // Secondary input
uniform sampler2D texture1;   // Named texture
```

## Notes

- All textures are loaded as 2D images
- Formats supported: PNG, JPG
- Textures are dynamically loaded by the engine
- File naming follows standard conventions

## Navigation

- [Assets Overview](../README.md)
- [Shader Format Guide](../Shaders/SHADER_GUIDE.MD)
