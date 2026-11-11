# Timeline step 3 (#680): test on Windows and macOS

[#680](https://github.com/shizotech/shizoscript3_source/issues/680): "It may be used for timecode synced shows, or just
pre-programmed shows in general in the future." Step 3 adds lane management, several selected clips, crossfades and
the chase of MIDI Time Code (MTC). Branch `claude/680-timeline-step3` (stacked on #794 and #778). Built and checked on
Linux in a container (g++, Mesa llvmpipe under Xvfb, FFmpeg 9 of `release/`). A container has no MIDI hardware and no
DAW: MTC was tested with the virtual MIDI device (the test timecode VibeVJ sends to itself, the same decoder after the
device). What reaches the decoder from a real MIDI input on Windows (WinMM) and macOS (CoreMIDI) is this checklist.

**C++ changed** (`modules/shzmodule_nanogui`): nanogui has to be built. Scripts changed too.

Write the results into *Results* at the end of this file (machine, MIDI interface, DAW, what passed, what not), or as
a comment on the PR.

---

## What changed

### nanogui (C++)

| File | What |
|---|---|
| `mididevice.h/.cpp` | `shz_mtc_decoder`: quarter frames (0xF1) and the full frame message (F0 7F id 01 01 hh mm ss ff F7) → time, running, rate (24 / 25 / 29.97df / 30), locates. System messages (0xF0..0xFF) no longer reach MIDI learn, the mapped controls or the MIDI monitor. `midi_message` has a short `sysex` field. `mididevice.timecode()`, `input([bytes])` for a sysex on a virtual device |
| Windows only (`#ifdef _WIN32`) | `add_sysex_buffers()` / `remove_sysex_buffers()`: two 256 byte buffers for WinMM (`midiInPrepareHeader` / `midiInAddBuffer` before `midiInStart`, given back after each `MIM_LONGDATA`; `midiInStop` / `midiInReset` / unprepare before `midiInClose`). Quarter frames came through `MIM_DATA` already |
| macOS only (`#ifdef __APPLE__`) | `midiReadProc` passes 0xF1 with its data byte and short sysex messages (F0 .. F7, at most 16 bytes) |
| Linux | ALSA `SND_SEQ_EVENT_QFRAME` and `SND_SEQ_EVENT_SYSEX` |
| `context_nano.cpp` | `nanogui.midi_timecode(name = "")` |
| `timeline.h/.cpp` | several selected items (Ctrl / Cmd + click, Shift + click, rubber band), a selection moved together (`edits_callback`), crossfade marks, `lane_marker` |

### VibeVJ (scripts)

- `src/menu/timeline/timecode.shio` (new): *TC* in the bar, its popup (*Chase timecode* = control `CHASE`, MIDI
  input, offset, *Send test timecode*). Saved in `timecode.json` (device, offset).
- `timeline_clips.shio`: lanes with ids (heads `timeline_lane_<id>`, old projects: id = position, nothing renamed),
  `lane_info` in `timeline_clips.json`; add / delete / move / rename lanes; copy / paste / duplicate; crossfades; a
  video clip as long as its video. `loops.shio`: deleting a loop is an undo step.

## Checked on Linux

- `_testing/nanogui/midi_timecode.shio` (new), `timeline_clips.shio`, `timeline_follow.shio`, `virtual_midi.shio`,
  `midi_controller.shio`, `loop_clock_test.shio`, `vibevj_contracts.shio`: pass.
- Smoke phase `tlstep3` (new) and `static loops tlclips tlenv midi dragdrop clipundo`: pass.
- `check_libcxx_linux.sh` (clang + libc++, the Mac build) and `check_msvc_linux.sh --only nanogui` (the Windows compile,
  no link).

## Phase 0: get the branch

- Windows: build (`_testing/windows_app/build.ps1 -Only nanogui`), then `testcopy.ps1 -Name pr680 -Binaries <out>`.
- macOS: `sh shzscript_macos/setup_mac.sh --build`.

## Phase 1: what Linux showed, again (a script can do it over MCP)

- [ ] `_testing/nanogui/midi_timecode.shio` prints ALL PASSED.
- [ ] Smoke phase `tlstep3` (Mac: `_testing/mac_app/smoke.py` has no such phase: do Phase 2 by hand).

## Phase 2: by hand, the lanes and clips (a person with a mouse; on the Mac a trackpad too)

- [ ] Timeline open, two clips on lane 1 that overlap: a cross on the overlap; Play: the picture fades from the first to
  the second over the overlap (link *Out* to an output shader or open the LayerBlend of the lane).
- [ ] The dots of a lane head: rename (Enter), add above / below, move up / down, delete; Ctrl / Cmd + Z for each.
- [ ] Drag the grip of a lane head up and down: the head follows, a violet line shows where it lands.
- [ ] Shift + click, Cmd + click (Mac) / Ctrl + click (Windows), a rubber band; drag the selection; Cmd / Ctrl + C, V,
  D, A, Delete.
- [ ] A video from *Assets* › *Videos* dropped onto a lane: as long as the video.

## Phase 3: MIDI Time Code from a real master (needs a MIDI interface or a virtual port, and a DAW)

Windows: loopMIDI makes a port; macOS: the IAC Driver (Audio MIDI Setup). In the DAW (Reaper, Ableton Live, Logic,
Cubase): send MIDI Time Code (Reaper: *Preferences* › *MIDI devices* › the output › *Send clock / SPP* and *Send
timecode*; Ableton: *Sync* of the output on, MTC in the MIDI preferences).

- [ ] *TC* › MIDI input: the port; offset 01:00:00:00, the DAW's project starts at 01:00:00:00. *Chase timecode* on.
- [ ] Play in the DAW: VibeVJ plays, the ruler shows *TC* and the time; the popup says *running* at the frame rate of
  the DAW (try 24, 25, 29.97 drop frame, 30).
- [ ] Stop in the DAW: VibeVJ stops at the same time. Click another place in the DAW while stopped (a full frame):
  the playhead of VibeVJ jumps there. **Windows: this is the new sysex path (`MIM_LONGDATA`)**; without it the
  playhead only follows once the DAW plays.
- [ ] Jump while playing (click in the DAW's ruler): VibeVJ jumps.
- [ ] Several minutes of playing: the clips stay on the bars of the DAW (no drift).
- [ ] With *Chase timecode* on, MIDI learn of a control still takes a knob, never the timecode.
- [ ] Unplug / close the port while running and plug it in again: no crash, the chase goes on (Windows: the close
  path with the sysex buffers).
- [ ] Quit VibeVJ while timecode comes in: no hang, no crash (Windows: `midiInReset` returns the buffers).

## Results

### Windows (<date>)

Machine, MIDI interface / loopMIDI, DAW. Per phase: pass / fail, screenshots of anything wrong.

### macOS (<date>)

Machine, IAC / interface, DAW. Per phase: pass / fail, screenshots of anything wrong.
