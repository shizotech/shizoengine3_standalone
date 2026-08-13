# Audio Generators

The `Generators/Audio/` directory contains generators for audio analysis and audio-reactive visual processing.

## Overview

Audio generators analyze audio input and convert it into parameters that can drive visual generators and effects.

## Components

| Component | Description |
|-----------|-------------|
| **AudioInputAnalysis.asset** | Audio input analysis configuration |

## Audio Input Analysis

The `AudioInputAnalysis.asset` generator provides:
- Audio input source selection
- Frequency analysis (FFT)
- Amplitude detection
- Feature extraction for reactive visuals

## Usage

Audio generators are typically connected to visual generators to create reactive visuals:
```
Audio Input → Audio Generator → Visual Generator → Output
```

## Notes

- Audio analysis runs in real-time
- FFT resolution and windowing can be configured
- Output values are normalized and can be scaled
- Multiple audio input sources can be selected

## Navigation

- [Generator Overview](../README.md)
- [Assets Overview](../../README.md)
