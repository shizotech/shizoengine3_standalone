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
- Audio input source selection (**SOURCE**): `LOCAL` = sound card, `ESP32 USB` = microphone or line-in of a prolink-bridge ESP32 on USB, `ESP32 NETWORK` = the same from a relay ESP32 over ShizoNet. For the ESP32 the analysis subprocess gets the samples instead of opening the sound card (firmware command `audio mic|line`, see prolink-bridge `docs/relay-und-audio.md`)
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
