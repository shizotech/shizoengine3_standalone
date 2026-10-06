# Network Generators

The `Generators/Network/` directory contains generators for network-based input and output communication.

## Overview

Network generators enable communication with external devices and systems over network protocols.

## Components

| Component | Description |
|-----------|-------------|
| **artnet_receiver.asset** | Artnet protocol receiver |
| **artnet_sender.asset** | Artnet protocol sender |
| **spout_receiver.asset** | Spout2 protocol receiver |
| **ProlinkBridge.asset** | CDJ tempo, beats, memory cues and track titles from the prolink-bridge ESP32 over USB; syncs the timeline |
| **ProlinkDecks.asset** | Deck view of the CDJs like ShowKontrol (titles, BPM, time, preview and scrolling detail waveforms with beat grid and cues) as video output, plus per-deck controls for effects |

## Protocol Support

### Artnet
- DMX512 over Ethernet protocol
- Supports both sending and receiving
- Commonly used for lighting control integration
- Universe and address configuration available

### Spout
- SPOUT2 video sharing protocol (Windows/macOS)
- Receive video from other applications
- Send video to other applications
- Low-latency inter-app video sharing

### ProlinkBridge (CDJs over USB)
- Reads Pioneer Pro DJ Link data from the [prolink-bridge](https://github.com/shizotech/prolink-bridge) ESP32-P4 directly over USB (native module `prolink`, see `shzmodule_prolink/README.md` in the source repo)
- **TIMELINE BPM SYNC** locks the timeline to the tempo master deck, like the audio analysis does
- Outputs of the master deck: BPM, BEAT and BAR phase, BEAT PULSE, DOWNBEAT PULSE, BEATS TO CUE, CUE RAMP (build-up over 16 beats), DROP PULSE (memory cue reached), PROGRESS, PLAYING, ON AIR, MASTER DECK
- **SOURCE** `USB` finds the ESP32 by itself (or set **PORT**), `DEMO` replays a recorded two-deck set without hardware
- **Phase offset** shifts BEAT and the timeline lock to compensate output latency
- **BAR LOCK** also puts timeline positions 0, 4, 8 ... on the downbeat of the master deck
- **LOW / MID / HIGH**: bass, mids and highs of the master deck's waveform at the playhead, usable like an audio analysis without an audio line

### ProlinkDecks (deck view)
- Renders up to 4 decks: header with deck number, title, artist, remaining time, BPM (orange = tempo master) and pitch, the preview waveform of the whole track with playhead and cues, and below that the scrolling detail waveforms with beat grid (downbeats red), memory cues and loops
- **OUT** is the rendered view (1920x1080), routable like any shader
- Per deck controls in "Deck 1" ... "Deck 4": BPM, BEAT, LOW, MID, HIGH, PROGRESS, CUE RAMP, PLAYING, ON AIR
- Settings: SOURCE / PORT (same meaning as in ProlinkBridge; both share one connection), DECKS (1-4), ZOOM (seconds visible in the detail waveforms), Level smoothing

## Configuration

Each network generator can be configured with:
- Network interface selection
- Port configuration
- Address/universe settings
- Connection parameters

## Usage

Network generators enable:
- Integration with external lighting consoles
- Video input from other applications
- Video output to external displays/software
- Synchronization with other systems

## Notes

- Network generators run continuously in the background
- Connection status is monitored and reported
- Reconnection logic handles network interruptions
- Some protocols may require specific system libraries

## Navigation

- [Generator Overview](../README.md)
- [Assets Overview](../../README.md)
