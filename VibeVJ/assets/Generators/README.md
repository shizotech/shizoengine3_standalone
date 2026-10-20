# Generators

The `Generators/` directory contains generator definitions that produce and process visual/audio content.

## Overview

Generators are the core processing units of the VJ application. They can generate visuals from scratch (sources), process existing content (effects), handle audio analysis, manage network I/O, and configure outputs.

## Categories

| Category | Description | Assets |
|----------|-------------|--------|
| **Math** | Waveforms, LFOs, clocks and step sequencers | SineGenerator, TriangleWave, SawtoothWave, SquareWave, NoiseGenerator, LFOSynth, LFOClock, StepChaser, PathPad |
| **Audio** | Audio analysis that drives everything else | AudioInputAnalysis |
| **Network** | Art-Net in and out, video in (NDI, Spout), CDJs over Pro DJ Link | ArtnetReceiver, ArtnetSender, NDIReceiver, SpoutReceiver, ProlinkBridge, ProlinkDecks |
| **Utility** | Pads, button fields, envelopes and small helpers | XYPad, XYPathPad, XYPositions, CurvePad, ColorSelector, Button-Feld, Control-Button-Matrix, EnvelopeOutput, StepChaser, control4, quantize, textbox, value_text, Chat, broken |
| **output** | Masks for an output | RGBMask (`legacy/` holds VideoToRGB, no longer in the asset list) |
| **ExampleBasics** | Code examples for asset authors | custom_drawing_ui_controls |

`Utility/broken.asset` fails on purpose: it shows what the error report of a broken asset looks like (the Linux smoke
test, `_testing/linux_app/smoke.py`, leaves it out).

## Directory Structure

```
Generators/
├── Math/            SineGenerator, TriangleWave, SawtoothWave, SquareWave, NoiseGenerator,
│                    LFOSynth, LFOClock, StepChaser, PathPad
├── Audio/           AudioInputAnalysis
├── Network/         ArtnetReceiver, ArtnetSender, NDIReceiver, SpoutReceiver, ProlinkBridge, ProlinkDecks
├── Utility/         XYPad, XYPathPad, XYPositions, CurvePad, ColorSelector, Button-Feld,
│                    Control-Button-Matrix, EnvelopeOutput, StepChaser, control4, quantize,
│                    textbox, value_text, Chat, broken
├── output/          RGBMask, legacy/VideoToRGB
└── ExampleBasics/   custom_drawing_ui_controls
```

Every name above is a folder `<Name>.asset` with its entry point in `src/__init__.shio`.

## Generator Types

### Math Generators
Produce waveforms from mathematical functions.
- **SineGenerator**: single sine LFO with free/sync mode and saturation.
- **TriangleWave**: triangle waveform generator.
- **LFOSynth**: multi-channel LFO synth with 4 selectable waveforms (sine/triangle/sawtooth/square), FREE/SYNC mode, optional ADSR envelope, and save/load state.
- **SawtoothWave**: single-channel sawtooth LFO with FREE/SYNC mode, frequency, gain and bias.
- **SquareWave**: single-channel square LFO with FREE/SYNC mode, frequency, gain and bias.
- **NoiseGenerator**: white/pink noise source that emits a new random value at a user-configurable rate.
- **LFOClock**: BPM-driven beat clock that pulses the output to 1.0 on each beat, then decays to 0 over a configurable decay duration.

### Audio Generators
Process audio input and generate reactive visual output based on audio analysis.

### Network Generators
Handle network-based input/output:
- **ArtnetReceiver / ArtnetSender**: DMX512 over Ethernet (Art-Net) in and out
- **NDIReceiver / SpoutReceiver**: video from other programs (NDI on every system, Spout on Windows)
- **ProlinkBridge / ProlinkDecks**: CDJ data (Pioneer Pro DJ Link) from DJ Watch (the ESP32 formerly called prolink-bridge) or, without it, through a network card of this computer, and a deck view of it

### Output Generators
- **RGBMask**: shapes that mask an output. The LED mapping lives in `assets/Mapping/` (LEDMapper, MapLab).

### Utility Generators
Provide helper functionality and debugging tools.

## Notes

- Generators are loaded as `.asset` configuration files
- Each generator can have multiple parameters and controls
- Generators can be chained together in pipelines
- The engine manages generator lifecycle and rendering

## Navigation

- [Assets Overview](../README.md)
- [Audio Generators](Audio/README.md)
- [Network Generators](Network/README.md)
- [Utility Generators](Utility/README.md)
