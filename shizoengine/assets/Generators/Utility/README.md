# Utility Generators

The `Generators/Utility/` directory contains utility and helper generators for debugging, testing, and additional functionality.

## Overview

Utility generators provide auxiliary functionality including debugging tools, value display, and test patterns.

## Components

| Component | Description |
|-----------|-------------|
| **test.asset** | Test generator for debugging |
| **textbox.asset** | Text display generator |
| **value_text.asset** | Value display generator |

## Components Detail

### test.asset
- Basic test pattern generator
- Useful for verifying pipeline connectivity
- Can output solid colors or test patterns

### textbox.asset
- Renders text to screen
- Configurable font, size, and color
- Useful for annotations and overlays

### value_text.asset
- Displays numerical values as text
- Can show generator parameters
- Useful for debugging and monitoring

## Usage

Utility generators are typically used during:
- Development and debugging
- System testing
- Information overlays during performance
- Monitoring generator parameters

## Notes

- Utility generators may have minimal performance impact
- Can be enabled/disabled independently
- Some may render on top of main output
- Useful for quick visual feedback

## Navigation

- [Generator Overview](../README.md)
- [Assets Overview](../../README.md)
