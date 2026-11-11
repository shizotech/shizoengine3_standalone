# Timeline sync, step 4 (#680): test on Windows and macOS

[#680](https://github.com/shizotech/shizoscript3_source/issues/680): "It may be used for timecode synced shows, or just
pre-programmed shows in general in the future." Step 4 adds MIDI clock (follow and send), sending MTC, LTC (timecode as
sound) read by the audio analysis, a chase for loop timelines and the *LoopTrigger* clip that starts a loop timeline
from the main timeline. Branch `claude/680-timeline-sync`. Built and checked on Linux in a container (g++, Mesa llvmpipe
under Xvfb). A container has no MIDI hardware, no DAW and no sound card: MIDI clock and MTC were tested through the
virtual MIDI devices (VibeVJ sends to itself, the same decoders after the device), LTC with samples made by a small
encoder in the tests. What reaches the decoders from a real MIDI input, what a DAW makes of the clock and MTC VibeVJ
sends, and LTC from a real sound input on Windows (WinMM, WASAPI) and macOS (CoreMIDI, CoreAudio) is this checklist.

**C++ changed** (`modules/shzmodule_nanogui`, `modules/shzmodule_audio`): nanogui and simpleaudio have to be built.
Scripts changed too.

Write the results into *Results* at the end of this file (machine, MIDI interface, DAW, sound input, what passed, what
not), or as a comment on the PR.

---

## What changed

### nanogui (C++)

| File | What |
|---|---|
| `mididevice.h/.cpp` | `shz_midi_clock_decoder`: clock (0xF8) → tempo over the last beat (smoothed; a change of more than 20 % at once), Start (0xFA) / Continue (0xFB) / Stop (0xFC), Song Position Pointer (0xF2) → position in beats. `midi_message::time`: when the driver delivered the message (the clock measures the tempo from it). `mididevice.clock()`, `nanogui.midi_clock(name)`, `nanogui.midi_device(name)` |
| | `shz_midi_sync_sender`: a thread per device that sends MIDI clock (+ Start / Continue / Stop / SPP) and MTC (quarter frames, full frames), `mididevice.send_sync(state)`. `send_raw(bytes)` for system messages and sysex. A recursive output mutex around the output handles (open / close / detach / send) |
| Windows only (`#ifdef _WIN32`) | `MIM_DATA` messages get `time`; `send_raw`: `midiOutShortMsg` for clock / SPP / quarter frames, `midiOutPrepareHeader` + `midiOutLongMsg` for the full frame (waits up to 50 ms for `MHDR_DONE`); the sender thread uses `timeBeginPeriod(1)` |
| macOS only (`#ifdef __APPLE__`) | `midiReadProc` passes 0xF8 / 0xFA / 0xFB / 0xFC (realtime, between any bytes) and 0xF2 with two data bytes; `send_raw` with `MIDISend`; the port of a virtual device (`MIDIReceived`) gets the system messages too |
| Linux | ALSA `SND_SEQ_EVENT_CLOCK / START / CONTINUE / STOP / SONGPOS`; output through `snd_midi_event_encode` |

### simpleaudio (C++)

| File | What |
|---|---|
| `shz_ltc.h` (new, header only, in both `.vcxproj` and their filters) | `simpleaudio.ltc(sample_rate)`: biphase mark decoder, sync word 0x3FFD forwards and backwards, 24 / 25 / 29.97df / 30, the speed followed, any polarity. `feed(buffer, channel)` / list / int16 binary, `state()`, `frames()` |
| `shz_audio.cpp` | `simpleaudio.buffer()` can be made by a script |

### VibeVJ (scripts)

- `src/menu/timeline/timecode.shio`: the popup of *TC*: *Chase* (control `CHASE`, the caption was *Chase timecode*),
  *Source* (MIDI Time Code, MIDI clock, LTC), MIDI input, offset, *Send* (a MIDI output, *MIDI clock*, *MTC*, rate).
  `timecode.json` gets `source`, `out_device`, `out_clock`, `out_mtc`, `out_rate` (old projects: MTC, nothing sent).
- `engine/processes/audio_process.shio`: reads LTC on each input channel, sends "ltc" messages;
  `assets/Generators/Audio/AudioInputAnalysis.asset`: passes them to the timeline, a line *LTC* in *Analysis*.
- `loop_clock.shio` / `loops.shio`: *Chase* per loop (control `CHASE` in the node of the loop, `chase` in `loops.json`).
- `assets/Generators/Utility/LoopTrigger.asset` (new): a clip that starts / stops a loop timeline.
- `__init__.shio`: `timecode.after_move()` every frame after the cursor moved (feeds the sender).

## Checked on Linux

- `_testing/nanogui/midi_clock.shio` (new: clock in by hand, clock and MTC sent to a virtual device and read back),
  `_testing/ltc_decoder.shio` (new: every rate, backwards, polarity, 0.6x / 1.1x / 1.5x speed, noise, int16, a stereo
  buffer), `_testing/ltc_audio_process.shio` (new: LTC as "pcm" through the real audio process), and
  `midi_timecode`, `virtual_midi`, `midi_controller`, `midi_controller_learn`, `timeline_clips`, `timeline_follow`,
  `midi_transport_range_793`, `loop_clock_test`, `vibevj_contracts`, `simpleaudio_stop`: pass.
- Smoke phase `tlsync` (new) and `tlstep3 loops tlclips tlenv midi`: pass.
- `check_msvc_linux.sh --only nanogui,audio` (the Windows compile, no link) and `check_libcxx_linux.sh` (the Mac build).

## Phase 0: get the branch

- Windows: build (`_testing/windows_app/build.ps1 -Only nanogui,simpleaudio`), then
  `testcopy.ps1 -Name pr680sync -Binaries <out>`.
- macOS: `sh shzscript_macos/setup_mac.sh --build`.

## Phase 1: what Linux showed, again (a script can do it)

- [ ] `_testing/nanogui/midi_clock.shio`, `_testing/nanogui/midi_timecode.shio`, `_testing/ltc_decoder.shio`,
  `_testing/ltc_audio_process.shio` print ALL PASSED (on a quiet machine: `midi_clock` measures timing).
- [ ] Smoke phase `tlsync` (Windows: over MCP with `mcp.py` the same queries; Mac: `_testing/mac_app/smoke.py` has no
  such phase, do the queries of the phase by hand over MCP).

## Phase 2: MIDI clock from a DAW (a person; needs a DAW and a MIDI loopback: loopMIDI on Windows, the IAC bus on macOS)

- [ ] In the DAW send MIDI clock (and song position) to the loopback port. VibeVJ: *TC*, *Source* *MIDI clock*, the
  port as *MIDI input*, *Chase* on. The status line shows the tempo of the DAW (to 0.1 BPM after a beat), the *BPM*
  of the timeline follows.
- [ ] Play in the DAW from bar 1: the timeline plays from beat 0. Stop: it stops. Play from bar 9 (song position):
  the timeline from beat 32. Jump in the DAW while it plays: the timeline jumps.
- [ ] Change the tempo of the DAW while it plays (also an automation ramp): the BPM follows within about a beat, the
  status line says "off by" a few ms at most.
- [ ] Windows: the timing is even (no jumps of the BPM by several BPM): WinMM delivers the clock with its own timer.

## Phase 3: VibeVJ as the master (a person, a DAW, the loopback port)

- [ ] *Send*: the loopback port, *MIDI clock* on. In the DAW: sync to external MIDI clock from that port. Play in
  VibeVJ: the DAW starts at the same bar, at the BPM of VibeVJ; Stop: it stops; a jump of the playhead (click in the
  ruler) while it plays: the DAW jumps there (Stop, song position, Continue).
- [ ] *MTC* on, rate 25 (and 30, 29.97df): the DAW chases MTC from the port: it shows offset + position. A loop of
  the timeline comes out as a jump.
- [ ] Windows: the full frame (sysex, `midiOutLongMsg`) reaches the DAW: a locate while VibeVJ stands moves the DAW.
- [ ] macOS: send to *Shizo Virtual MIDI*: a DAW sees it as a MIDI source (its port of the system) and gets the clock.

## Phase 4: LTC from the sound input (a person; an LTC source: a DAW with an LTC plugin or an LTC file, a cable or a loopback into the input)

- [ ] *Audio Input Analysis* in a view, *Source* *Sound card*. Play LTC (25 fps) into the input: the line *LTC* in
  *Analysis* shows the timecode, "25 fps", the channel. LTC on one channel and music on the other works.
- [ ] *TC*: *Source* *LTC (audio input)*, the offset of the show, *Chase* on: the timeline plays with the LTC, stops
  when it stops, jumps when it jumps. Try 24, 29.97df, 30 fps.
- [ ] Play the LTC backwards (scrub back in the DAW): the playhead goes back.
- [ ] The level: quiet LTC (about -30 dB) still reads; the sound card at 44.1 kHz too (miniaudio converts to 48 kHz).

## Phase 5: loops (a person with a mouse)

- [ ] View *Loops*: *Chase* in the head of a loop, the loop running: it is where the main timeline is in its turn; a
  click in the ruler of the main timeline moves the loop too.
- [ ] *Generators* › *Utility* › *LoopTrigger* dropped onto a lane of the main timeline, the loop picked in its *Loop*
  list (the *Clip* panel): Play over the clip starts the loop, after the clip it stops. Saved and loaded: still so.

## Results

### Windows (<date>)

Machine, MIDI interface / loopback, DAW, sound input. Per phase: pass / fail, screenshots of what is wrong, bugs fixed
during the test with their commit.

### macOS (<date>)

The same.
