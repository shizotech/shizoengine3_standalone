# Generators

The `Generators/` directory contains generator definitions that produce and process visual/audio content.

## Overview

Generators are the core processing units of the VJ application. They can generate visuals from scratch (sources), process existing content (effects), handle audio analysis, manage network I/O, and configure outputs.

## Categories

| Category | Description | Files |
|----------|-------------|-------|
| **Math** | Math-based waveform/LFO generators | SineGenerator.asset, TriangleWave.asset, LFOSynth.asset, SawtoothWave.asset, SquareWave.asset, NoiseGenerator.asset, LFOClock.asset |
| **Audio** | Audio analysis and reactive generators | AudioInputAnalysis.asset |
| **Network** | Network input/output generators | artnet_receiver.asset, artnet_sender.asset, spout_receiver.asset |
| **Output** | Output configuration generators | LEDMapping.asset |
| **Utility** | Utility and helper generators | test.asset, textbox.asset, value_text.asset |

## Directory Structure

```
Generators/
├── Math/             # Math-based waveform/LFO generators
│   ├── SineGenerator.asset
│   ├── TriangleWave.asset
│   ├── LFOSynth.asset
│   ├── SawtoothWave.asset
│   ├── SquareWave.asset
│   ├── NoiseGenerator.asset
│   └── LFOClock.asset
├── Audio/            # Audio generators
│   └── AudioInputAnalysis.asset
├── Network/          # Network generators
│   ├── artnet_receiver.asset
│   ├── artnet_sender.asset
│   └── spout_receiver.asset
├── Output/           # Output generators
│   └── LEDMapping.asset
└── Utility/          # Utility generators
    ├── test.asset
    ├── textbox.asset
    └── value_text.asset
```

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
- **Artnet**: DMX512 over Ethernet protocol support
- **Spout**: SPOUT2 video sharing protocol support

### Output Generators
Configure and manage visual output destinations.

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
- [Output Generators](Output/README.md)
- [Utility Generators](Utility/README.md)
