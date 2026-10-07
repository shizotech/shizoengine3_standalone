# Network Generators

The `Generators/Network/` directory contains generators for network-based input and output communication.

## Overview

Network generators enable communication with external devices and systems over network protocols.

## Components

| Component | Description |
|-----------|-------------|
| **ArtnetReceiver.asset** | Artnet protocol receiver |
| **ArtnetSender.asset** | Artnet protocol sender |
| **SpoutReceiver.asset** | Spout2 protocol receiver |
| **NDIReceiver.asset** | NDI video receiver |
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
- **SOURCE** `USB` finds the ESP32 by itself (or set **PORT**), `DEMO` replays a recorded two-deck set without hardware, `NETWORK` takes the data from a relay ESP32 in the light/VJ network over ShizoNet (the listener ESP32 stays in the DJ network, see prolink-bridge `docs/relay-und-audio.md`)
- **Phase offset** shifts BEAT and the timeline lock to compensate output latency
- **BAR LOCK** also puts timeline positions 0, 4, 8 ... on the downbeat of the master deck
- **LOW / MID / HIGH**: bass, mids and highs of the master deck's waveform at the playhead, usable like an audio analysis without an audio line

### ProlinkDecks (deck view)
- One lane per deck with the scrolling detail waveform (3-band colors like the CDJ-3000, smooth edges): beat grid (downbeats red, bar lines), the part already played dimmed
- Cues in the detail and the whole-track waveforms: hot cues as a box with their letter (in the cue color) and their comment, memory cues as a triangle, loops as a highlighted range with in and out lines
- Phrases (song structure of rekordbox 6+, named like DJs do: Intro, Verse, Break, Buildup, Drop, Outro) as a colored band at the bottom of the detail and the whole-track waveforms, and the current phrase with the beats to the next one (e.g. `Drop 12`) next to the cue countdown. A rising stretch at the end of a break before a drop (riser, snare roll) is detected from the waveform and shown as Buildup. Tracks without rekordbox phrases get their structure from the waveform alone (no bass = Break, bass = Drop, plus Intro, Outro and Buildups)
- **DECKS**: `AUTO` shows one lane per CDJ that is on the network (1-4, the view adapts when one joins or leaves); `1`-`4` fixes the number of lanes
- **ON AIR** (red, channel open on the DJM), **MASTER** (orange) and **SYNC** (blue) labels next to the tempo of each deck, in both layouts. ON AIR needs a mixer on the network
- **LAYOUT**: `DECKS + LANES` puts a row of deck panels on top (deck number, title, artist, remaining time, BPM in orange for the tempo master, pitch, beat in the bar, beats to the next memory cue, preview waveform of the whole track); `LANES ONLY (COMPACT)` drops the panels and shows the same infos smaller in a column left of each lane
- **PLAYHEAD (% from left)**: where the playhead sits in the lane; smaller values show less of the past and more of what comes
- **OVERVIEW IN LANES**: the whole track as a thin bar at the bottom of each lane; `AUTO` = on in the compact layout
- **TEXT SIZE**, **ZOOM** (seconds visible in the detail waveforms), Level smoothing
- Zoom bar under the view (like on rekordbox): fold / unfold the history column, zoom in, **RST** (back to 8 s), zoom out, and an arrow to fold the bar away. After clicking into the view also the keys **+**, **-**, **0** (reset) and **H** (history)
- **STYLE**: `CDJ` (default) has the colors of the CDJ-3000 and rekordbox; `VIBEVJ` uses the look of the VibeVJ interface: its dark grey surfaces with rounded corners, the waveforms in the accent color of the VibeVJ theme (follows a changed accent), white playhead, flat pills and the beat as small squares
- **HISTORY**: `RIGHT COLUMN` shows the played tracks (newest on top, with time, deck, title, artist and BPM) as a column right of the decks; `OFF` (default) hides it. A track counts once it was audible for 30 s (channel open on the DJM; without a mixer: playing). The column folds to a narrow tab (number of tracks, "HISTORY") and back: click into it in the view, press **H** after clicking into the view, use the history button in the zoom bar, or **HISTORY OPEN** in the settings (mappable to MIDI, saved with the project). The decks take the room while it is folded
- "History" section: the last tracks played, **Save CSV** / **Save TXT** (writes all of them to `Documents/prolink-history/history-<date>-<time>.csv|txt`) and **Clear**
- **OUTPUT**: size of the rendered view, 1920x1080 (default), wider 2560x1080 (21:9) and 3840x1080 (32:9), 3840x2160, or a flat strip (1920x540, 1920x360; best with the compact layout). Other sizes keep the info columns at the pixel width of 1920x1080 and give the room to the waveforms
- **OUT** is the rendered view, routable like any shader
- Per deck controls in "Deck 1" ... "Deck 4": BPM, BEAT, LOW, MID, HIGH, PROGRESS, CUE RAMP, PLAYING, ON AIR (channel open on the DJM; without a mixer on the network: the deck is playing), PHRASE RAMP (0 at the start of the current phrase .. 1 at its end), BUILDUP (0 .. 1 through a buildup, 0 otherwise), DROP (1 while a drop plays)
- SOURCE / PORT have the same meaning as in ProlinkBridge; both share one connection

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
