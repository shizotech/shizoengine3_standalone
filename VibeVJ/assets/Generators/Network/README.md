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
| **ProlinkBridge.asset** | CDJ tempo, beats, memory cues and track titles from DJ Watch over USB; syncs the timeline |
| **DJMidiOut.asset** | The DJ's beats, phrases, drops, track loads and deck values as MIDI notes / CCs, and the SoundSwitch preset |
| **ProlinkDecks.asset** | Deck view of up to six CDJs like ShowKontrol and the CDJ-3000 (artwork, titles, key, BPM, time, preview and scrolling detail waveforms with beat grid and cues, the live deck framed) as video output, plus per-deck controls for effects |

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

### DJ Watch

DJ Watch is the ESP32-P4 that sits in the Pro DJ Link network of the CDJs and passes tempo, beats, tracks, cues and
waveforms on (hostname `dj-watch.local`; firmware, protocol and wiring in the repository
[prolink-bridge](https://github.com/shizotech/prolink-bridge), its former name). The two generators below read it
through the native module `prolink` (see `modules/shzmodule_prolink/README.md` in the source repo). Their asset names
(`ProlinkBridge`, `ProlinkDecks`) and control IDs stay, so saved projects keep working; the captions follow the Shizo UI
writing rules (`design/wiki/Writing-and-Naming.md`).

### ProlinkBridge (CDJs over USB)
- Reads Pioneer Pro DJ Link data from DJ Watch directly over USB
- *Sync timeline* (ID `TIMELINE BPM SYNC`) locks the timeline to the tempo master deck, like the audio analysis does
- Outputs of the master deck: *BPM*, *Beat* and *Bar* phase, *Beat pulse*, *Downbeat pulse*, *Cue in* (beats to the next memory cue, `—` without one), *Cue ramp* (build-up over 16 beats), *Drop pulse* (memory cue reached), *Progress*, *Playing*, *On air*, *Master deck*
- *Source*: *USB* finds DJ Watch by itself (or set *Port*), *Demo* replays a recorded two-deck set without hardware, *Network* takes the data from a relay ESP32 in the light/VJ network over ShizoNet (the listener stays in the DJ network, see prolink-bridge `docs/relay-und-audio.md`), *Network card* needs no DJ Watch: this computer joins the DJ network itself through one of its network cards (`device.lan()`; *Network card (empty = auto)* = name or address of the card, empty = the card on which CDJs show up; *Listen only* sends nothing, tempo and beats only). Best a card of its own for the DJ network, apart from Art-Net
- *Phase offset* (beats) shifts *Beat* and the timeline lock to compensate output latency
- *Bar lock* also puts timeline positions 0, 4, 8 ... on the downbeat of the master deck
- *Low* / *Mid* / *High*: bass, mids and highs of the master deck's waveform at the playhead, usable like an audio analysis without an audio line
- *Now playing* (ID `NOW PLAYING`, section *Deck*): the deck whose track the audience hears (`device.now_playing()`, the mix status of the prolink module), its title in the line below
- The status line names the device: "DJ Watch not connected", "Connecting to DJ Watch…", "DJ Watch connected, no tempo master", or the track of the master deck

### ProlinkDecks (deck view)
- One lane per deck with the scrolling detail waveform (3-band colors like the CDJ-3000, smooth edges): beat grid (downbeats red, bar lines). The part already played is at half brightness in the lanes and in the whole-track waveforms, with its cues and phrases
- Cues in the detail and the whole-track waveforms: hot cues as a box with their letter (in the cue color) and their comment, memory cues as a triangle, loops as a highlighted range with in and out lines
- Phrases (song structure of rekordbox 6+, named like DJs do: Intro, Verse, Break, Buildup, Drop, Outro) as a colored band at the bottom of the detail and the whole-track waveforms, and the current phrase with the beats to the next one (e.g. `Drop 12`) next to the cue countdown (`Cue 16`, in the Shizo UI `cue` amber in the last 16 beats). A rising stretch at the end of a break before a drop (riser, snare roll) is detected from the waveform and shown as Buildup. Tracks without rekordbox phrases get their structure from the waveform alone (no bass = Break, bass = Drop, plus Intro, Outro and Buildups)
- *Decks*: *Auto* shows one lane per player that is on the network (up to 6, the view adapts when one joins or leaves); *1*-*6* fixes the number of lanes. With five or six decks the panels of *Decks and lanes* sit in two rows of three
- **Live**: the deck that is heard gets a 4 px ring in the Shizo UI `live` green around its panel and its lane and a chamfered *Live* badge (under the player number), the same signs as a playing clip in the Clipview. With a DJM on the network a deck is live while its channel is open (On Air; several decks during a mix). Without a mixer nothing reports that, so the view takes the tempo master while it plays, or the only deck that plays; none while several play without a master
- Chips next to the tempo, each a word so it reads without its colour: *Master* (light), *Sync* (accent) and the key of the track (*Key 8A*, neutral); where a panel is narrow the key goes first, then Sync. The BPM sits in a box like on the CDJ-3000, filled light on the tempo master. A stripe left of each panel and lane: light for the tempo master, green for a live deck, grey otherwise. A green ▶ shape before the time marks a playing deck, a grey pause sign a stopped one. No *MT* (Master Tempo) chip: the players' data in the prolink module has no such field
- *Layout*: *Decks and lanes* puts a row of deck panels on top in three rows like the CDJ-3000 screen: the player number in a box and the artwork of the track (an empty square while it has none; smaller or left out where the title would get too little room), title, artist, the BPM box, the chips and the tempo (±%), and below the number the *Live* badge and the player model (*CDJ-3000*), then the beat in the bar, the beats to the next memory cue, the phrase, the other time in grey (elapsed when *Time display* shows the remaining time and the other way round) and the time with its tenths smaller, above the preview waveform of the whole track; *Lanes only (compact)* drops the panels and shows the same infos smaller in a column left of each lane (number, *Live*, model, chips and BPM in the first row, the artwork next to title and artist)
- Artwork: `device.artwork(n)` (JPEG) is written to the cache folder (`.cache/VibeVJ/prolink_artwork` in the ShizoScript config folder, two files per deck) by a worker thread and loaded into a texture of the shader on the next frame; it comes when the source sends it (DJ Watch / network card with artwork on)
- *Time display*: *Remaining* (default, `-3:07.4`) or *Elapsed* (`1:02.3`); `—` while a loaded track has no position (only the CDJ-3000 sends it)
- *Playhead from left* (%): where the playhead sits in the lane; smaller values show less of the past and more of what comes
- *Overview in lanes*: the whole track as a thin bar at the bottom of each lane; *Auto* = on in the compact layout
- *Text size*, *Zoom*, *Level smoothing*. *Zoom* (ID `ZOOM (seconds)`) is the time across the detail waveforms of an output 1920 px wide (1920x1080 and 3840x2160 look as before). Wider outputs keep its seconds per pixel and show more: at 3840x1080 about 17 s for *Zoom* 8 s, most of it ahead of the playhead, which stays at *Playhead from left*
- Zoom bar under the view (like on rekordbox): fold / unfold the history column, zoom in, the seconds visible in the lanes, *Reset* (back to 8 s), zoom out, and an arrow to fold the bar away. After clicking into the view also the keys **+**, **-**, **0** (reset) and **H** (history)
- The view in the generator window takes the whole width of the window at the aspect ratio of the output and follows when the window is resized; at most as high as the window, then it gets bars left and right
- *Style* sets the colours of the content: *CDJ* (default) has the waveform colours of the CDJ-3000 and rekordbox (red playhead and downbeats); *VibeVJ* draws the waveforms in the accent colour of the VibeVJ theme (follows a changed accent) with a white playhead. The chrome around them is the same in both styles and uses the Shizo UI tokens (`design/tokens.json` 0.3.0): `canvas` background, `surface` panels, `field` behind the waveforms, `text` / `text_2` / `text_3` for the texts, radius 4 px at 1080 lines, BPM and times in Inconsolata
- *History*: *Right column* shows the played tracks (newest on top, with time, deck, title, artist and BPM) as a column right of the decks; *Off* (default) hides it. A track counts when it is *now playing* (the mix status of the prolink module: at once when it is the first one heard or the track before was cued or ended, else after 128 beats), or with *History rule* *Audible 30 s* once it was heard for 30 s. The column folds to a narrow tab (number of tracks, "History") and back: click into it in the view, press **H** after clicking into the view, use the history button in the zoom bar, or *Show history* in the settings (mappable to MIDI, saved with the project). The decks take the room while it is folded
- "History" section: the last tracks played, *Save CSV* / *Save TXT* (writes all of them to `Documents/prolink-history/history-<date>-<time>.csv|txt`) and *Clear*; *History rule* (ID `HISTORY RULE`: *Now playing* / *Audible 30 s*), *Now playing* (ID `NOW PLAYING MODE`: *Smart*, *Waits for silence*, *Follows master*) and *Write playlist* (ID `WRITE PLAYLIST`: the plays of the set while they happen to `Documents/prolink-history/set-<date>-<time>.csv`), set with `device.history_options()` (the DJ Watch program sets its own in its History tab)
- *Output*: size of the rendered view, 1920x1080 (default), wider 2560x1080 (21:9) and 3840x1080 (32:9), 3840x2160, a flat strip (1920x540, 1920x360; best with the compact layout), *Custom* or *Fit window*. *Custom* uses *Width (px)* and *Height (px)* (IDs `OUTPUT WIDTH`, `OUTPUT HEIGHT`; 320-7680 x 120-4320, shown only then). *Fit window* takes the shape of the generator window, *Height (px)* high (default 1080), and follows a resized window once it stays the same for a moment. Wider outputs keep the info columns and texts at the pixel size of 1920x1080 and give the room to the waveforms; higher ones scale them up, narrower or taller ones (*Custom*, *Fit window*) down so they fit. In flat strips the text part of the deck panels keeps three readable rows. In *Lanes only* the phrase (`Drop 12`) gets a row of its own when the lane is high enough
- *Out* is the rendered view, routable like any shader
- Per deck controls in "Deck 1" ... "Deck 6": *BPM*, *Beat*, *Low*, *Mid*, *High*, *Progress*, *Cue ramp*, *Playing*, *On air* (channel open on the DJM; without a mixer on the network: the deck is playing), *Phrase ramp* (0 at the start of the current phrase .. 1 at its end), *Buildup* (0 .. 1 through a buildup, 0 otherwise), *Drop* (1 while a drop plays)
- *Source* / *Port* / *Network card* / *Listen only* have the same meaning as in ProlinkBridge; both share one connection. The status line under the view says "DJ Watch connected: <port>" (or "Demo set (no DJ Watch needed)")

### DJMidiOut (DJ events as MIDI)
- Reads the decks of a ProlinkBridge / ProlinkDecks (their device in `std.global("prolink_sources")`), opens no connection and takes no `events()` of its own: the events come from comparing the state of the deck from frame to frame
- *MIDI output* (ID `OUTPUT DEVICE`, the name), *Send MIDI* (ID `SEND MIDI`), *Deck* (ID `FOLLOW DECK`: Auto = `device.lead()`, or deck 1-6), *Note length*
- Notes (ID `NOTE <NAME> ON / CH / NUM`): beat 36, downbeat 37, phrase change 38, phrase kind 40 + code (Intro 0, Verse 1-6, Bridge 7, Drop 8, Buildup 9, Down 10, Outro 11, autoblink's codes; rekordbox's Bridge and Down are both Break), drop 52, buildup 53, track load 54, cue reached 55, all on channel 1
- CCs (ID `CC <NAME> ON / CH / NUM`, sent only on a change, each at most 60 times a second): BPM coarse 1 (BPM - 50), BPM fine 2, pitch 3 (64 = 0 %, 0.25 % a step), bar phase 4, beat phase 5, playing 6, master deck 7, phrase kind 20 (code x 10, 127 none), phrase progress 21, beats left 22, Low / Mid / High of deck n on 30 / 36 / 42 + n - 1
- *Send* on each line sends it once (MIDI learn of the receiving program)
- SoundSwitch (ID `SOUNDSWITCH`, rows `SS <KIND> BANK / LOOP`): per phrase one bank select (channel 16, notes 60-63) and one AutoLoop pulse (channel 13-16, notes 64-95); the AutoLoop per phrase kind (intro, verse, break, buildup, drop, outro) is set per row, *Send* sends the pair for SoundSwitch's *Map*
- Timing: script side, a beat note within half a frame of the beat (the next one is sent early when it is due before the next frame); the MIDI devices (nanogui) and the beat clock of the tempo sender (prolink) are in two modules that cannot reach each other
- Test: `_testing/nanogui/dj_midi_out.shio` (the demo set, a virtual MIDI device)

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
