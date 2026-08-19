# Output Generators

The `Generators/Output/` directory contains generators for configuring and managing visual output destinations.

## Overview

Output generators define how the application renders to physical displays and external systems.

## Components

| Component | Description |
|-----------|-------------|
| **LEDMapping.asset** | LED wall/panel mapping configuration |

## LED Mapping

The `LEDMapping.asset` generator provides:
- LED panel grid configuration
- Physical to logical coordinate mapping
- Panel orientation and rotation settings
- Gap and bezel compensation
- Multiple output device support

## Output Configuration

Output generators can configure:
- Display monitor selection
- Resolution and refresh rate
- Fullscreen/windowed mode
- Multi-monitor arrangements
- Output scaling and cropping

## Usage

Output generators are connected at the end of the processing pipeline:
```
Visual Generator → Effects → Output Generator → Display
```

## Notes

- Output configuration is saved per-project
- Multi-monitor setups are supported
- Hardware acceleration may be enabled
- Output resolution can be fixed or auto-detected

## Navigation

- [Generator Overview](../README.md)
- [Assets Overview](../../README.md)
