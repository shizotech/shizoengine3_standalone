# Generators

The `Generators/` directory contains generator definitions that produce and process visual/audio content.

## Overview

Generators are the core processing units of the VJ application. They can generate visuals from scratch (sources), process existing content (effects), handle audio analysis, manage network I/O, and configure outputs.

## Categories

| Category | Description | Assets |
|----------|-------------|--------|
| **Math** | Waveforms, LFOs, clocks, step sequencers and value operators | SineGenerator, TriangleWave, SawtoothWave, SquareWave, NoiseGenerator, LFOSynth, LFOClock, StepChaser, PathPad, Lag, Trigger, Speed, Math, Count, Hold, Select, Filter |
| **Sources** | Pictures made by a script (not a shader) | Text |
| **Audio** | Audio analysis that drives everything else | AudioInputAnalysis |
| **Input** | Video devices of this computer (webcams, capture cards; on macOS the screens) | Camera |
| **Network** | Art-Net in and out, video in (NDI, Spout), CDJs over Pro DJ Link | ArtnetReceiver, ArtnetSender, NDIReceiver, SpoutReceiver, ProlinkBridge, ProlinkDecks |
| **Utility** | Pads, button fields, envelopes and small helpers | XYPad, XYPathPad, XYPositions, CurvePad, ColorSelector, Button-Feld, Control-Button-Matrix, EnvelopeOutput, StepChaser, LoopTrigger, control4, quantize, textbox, value_text, Chat, broken |
| **output** | Masks for an output | RGBMask (`legacy/` holds VideoToRGB, no longer in the asset list) |
| **ExampleBasics** | Code examples for asset authors | custom_drawing_ui_controls |
| **Python** | Python scripts (`Name.py/src/__init__.py`, #853): controls from `#@` comments, a picture in, values and a picture out. Wiki page Python-Generators | LFO, AverageColour, Threshold, Edges (numpy: a dependency in asset.json) |
| **Native** | Native assets: a C ABI plugin instead of a script (#201, `src/__init__.native`) | Life, Dither |

`Utility/broken.asset` fails on purpose: it shows what the error report of a broken asset looks like (the Linux smoke
test, `_testing/linux_app/smoke.py`, leaves it out).

## Directory Structure

```
Generators/
├── Math/            SineGenerator, TriangleWave, SawtoothWave, SquareWave, NoiseGenerator,
│                    LFOSynth, LFOClock, StepChaser, PathPad, Lag, Trigger, Speed,
│                    Math, Count, Hold, Select, Filter
├── Sources/         Text
├── Audio/           AudioInputAnalysis
├── Input/           Camera
├── Network/         ArtnetReceiver, ArtnetSender, NDIReceiver, SpoutReceiver, ProlinkBridge, ProlinkDecks
├── Utility/         XYPad, XYPathPad, XYPositions, CurvePad, ColorSelector, Button-Feld,
│                    Control-Button-Matrix, EnvelopeOutput, StepChaser, LoopTrigger, control4,
│                    quantize, textbox, value_text, Chat, broken
├── output/          RGBMask, legacy/VideoToRGB
├── ExampleBasics/   custom_drawing_ui_controls
└── Python/          LFO, AverageColour, Threshold, Edges
└── Native/          Life, Dither
```

Every name above is a folder `<Name>.asset` with its entry point in `src/__init__.shio`, except in `Python/`: there a
folder `<Name>.py` with `src/__init__.py` (the loader `engine/generators/extensions/py`).
Every name above is a folder `<Name>.asset` with its entry point in `src/__init__.shio`, except the native assets:
`src/__init__.native` names the C ABI plugin in their folder `plugin/` (Life: Conway's Game of Life in C, `life.c`;
Dither: dithers the picture of its input to a palette, `dither.c`;
how to write one: the section *A native VibeVJ asset* of `core/shizoscript3_core_cabi/README.md`).

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
- **Lag**: smooths a value linked into *Input* (the Lag / Filter CHOP of TouchDesigner): separate *Rise* and *Fall* times
  in seconds, *Smooth*, *Linear* (slew limiter) or *Spring* (overshoot, *Bounce*). Counts real time, not beats (#586).
- **Trigger**: an attack / decay / sustain / release envelope (the Trigger CHOP): the gate opens when *Input* rises above
  *Threshold*, on every *Every* beats, or while the *Trigger* button is held; outputs *Output* and *Gate* (#586).
- **Speed**: integrates a speed into a position from 0 to 1 that wraps or ping-pongs (the Speed CHOP): a change of the
  speed never makes the output jump; per beat or per second (#586).

- **Math**: combines A and B (+, -, *, /, min, max, average, difference, power, modulo), then a Function and a Range
  with Clamp (the Math CHOP); plain numbers in and out (#586).
- **Count**: counts events (Input rising above Threshold, every Every beats, a press of Count) with Step through Steps
  values: Wrap, Ping-pong, Stop or Random; Reset to Start; outputs Count and Output (0..1) (#586).
- **Hold**: sample and hold on a trigger (or Track while it is open); Value Random gives stepped noise (#586).
- **Select**: picks one of up to 8 values by Index or Position, Fade glides between picks (the Switch CHOP) (#586).
- **Filter**: One euro (jitter removal), Average, Median (spike removal), Envelope (peak follower), Slope (#586).

### Sources Generators
- **Text**: text as a picture as big as the project, drawn with NanoVG into a shader's texture (render_draw): fonts of
  the program or a .ttf / .otf file, outline, shadow / glow, background, typewriter, scroll, lines, words, beat pulse;
  `{value}` shows a linked number (#586).

### Audio Generators
Process audio input and generate reactive visual output based on audio analysis.

### Input Generators
- **Camera**: the picture of a webcam or capture card (nanogui.video `open_camera`, FFmpeg's input devices), with
  resolution, frame rate, the video router and *Out*; *Test pattern* works without a camera

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
