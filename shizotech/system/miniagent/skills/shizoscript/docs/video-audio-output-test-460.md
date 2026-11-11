# Output device, pre-listen and the level of video clips (#460): test on Windows and macOS

[#460](https://github.com/shizotech/shizoscript3_source/issues/460) point 5: "pick the output device for clip sound
(settings), optionally a second 'cue' output for headphones; the level of a clip as an output control that can be
linked". Branch `claude/460-audio-output`, stacked on `claude/460-jog-audio-source` (#773).

Built and checked on Linux in a container (g++, Mesa llvmpipe under Xvfb, FFmpeg 9.0.2 of BtbN). A container has no
sound card: the device handling was tested with a fake device list (each "device" is miniaudio's null device under a
name), and the only real device there is ALSA's "Discard all samples" plug-in. Real outputs (WASAPI, CoreAudio), two
devices at once, plugging headphones in and out, and what a person hears are this checklist.

**C++ changed** (`modules/shzmodule_nanogui`): nanogui has to be built. Scripts changed too.

Write the results into *Results* at the end of this file (machine, sound devices, what passed, what not, screenshots),
or as a comment on the PR.

---

## What changed

### nanogui (C++)

| File | What |
|---|---|
| `video_audio_device.cpp` | Two output devices instead of one: the main output and the pre-listen output (`cue` in the C++). Each is chosen by device name; the list comes from one miniaudio context of the system's backends, a device is opened by its id. Main: a missing device -> the default output plays (`fallback`); no device at all -> the null device, as in #773. Pre-listen: a missing device is waited for. While devices are open a thread looks at the list every 2 s and reopens a device that went or came back, also after miniaudio's "stopped" notification (unplugged) |
| `video_audio.h/.cpp` | A source can go to the pre-listen output (`set_to_cue`): the main device then leaves it to the pre-listen device, without one it is mixed and dropped (in step, heard nowhere); never to the audio analysis. `take_peak()`: the highest peak since the last call |
| `video_widget.cpp/.h` | `video.prelisten(on)` (save / load key `prelisten`), `video.audio_peak()`, `audio_error()` says why a clip on pre-listen is not heard |
| `context_nano.cpp` | `nanogui.video_audio_devices()`, `video_audio_output([name])`, `video_audio_prelisten_output([name])`, `video_audio_status()`; icon names `volume_up`, `headphones` |

### VibeVJ (scripts)

- *Settings* › *Sound* (new page, `src/menu/assetbrowser/sound_settings.shio`): *Main output* (*System default* or a
  device), *Pre-listen output* (*Off* or a device), a status line, *Look for devices*. Personal: `style.json` keys
  `video_audio_output`, `video_audio_prelisten` (device names), applied at start (`__init__.shio`). A chosen device
  that is missing shows as "Name (not connected)".
- Video clips (`video_module.shio`): *Level* (an output under *Out*, 0..1, the peak of the sound, falls back 1.5 per
  second) and *Options* › *Pre-listen*. New save key `prelisten`; old projects load with it off. No ID changed.
- Docs: wiki *Video* (*Sound*, *Pre-listen*), wiki *Settings* (*Sound*), `docs/video.md`, skill `vibevj_live`,
  `_testing/linux_app/README.md`.

### Checked on Linux

- `_testing/video/audio_output_test.cpp` (new, no FFmpeg): PASSED. Cue routing of the mixer; with a fake list
  "Speakers", "Headphones": main output and pre-listen output by name, main output missing -> the default plays,
  pre-listen output missing -> none, both back after plugging in again, the watching thread notices an unplugged
  device within 2 s, off / default again, the last clip closes the devices; the system's list.
- `_testing/nanogui/video_audio_output.shio` (new): ALL PASSED (status before a clip, a choice that is not connected,
  `audio_level` / `audio_peak` 0.088 for the 440 Hz test tone, pre-listen without an output: not heard, not in the
  analysis, `audio_error` says why; a pre-listen output that is not there; save / load `prelisten`; pre-listen alone
  decodes the sound).
- `_testing/nanogui/video_audio_analysis.shio` (#773): ALL PASSED. `_testing/video/decoder_test.cpp`: PASSED.
- `_testing/nanogui/video_playback.shio`: the sound part passes; "speed(-1) plays backwards" fails under load, on main
  too (other builds ran on the machine).
- `check_assets.sh`: 70 passed. `shz --check __init__.shio`: ok. Wiki links: 0 broken.
- In the app (Xvfb, MCP): *Settings* › *Sound* shows both lists; choosing ALSA's "Discard all samples" device writes it
  into `style.json`; a clip with sound (*Audio* on): *Level* 0.088 over MCP; with *Pre-listen* on as well, the level
  still moves.
- A real ALSA device chosen by name (the "Discard all samples" plug-in): opened through the device list, the clip is
  mixed (`audio_peak` 0.088). That device has no clock of its own, so the timing means nothing there.
- MSVC compile check (`check_msvc_linux.sh --only nanogui`) and the macOS check (`check_libcxx_linux.sh`): see the PR.

---

## Phase 0: get the branch

- Windows: `& .\_testing\windows_app\build.ps1 -Only nanogui`, then `& .\_testing\windows_app\testcopy.ps1 -Name pr460o -Binaries <build out>`.
- macOS: `sh shzscript_macos/setup_mac.sh --build`.

## Phase 1: automatic

- [ ] `_testing/video/audio_output_test.cpp` (build line at its top; Windows: the `cl` line): PASSED. The last part
      lists the real devices of the machine and plays on the default one ("plays on <name>").
- [ ] `_testing/nanogui/video_audio_output.shio`: ALL PASSED. With a sound card the line "missing main output: <your
      default device> plays instead (fallback)" appears instead of "no output device at all".
- [ ] `_testing/nanogui/video_audio_analysis.shio`, `_testing/nanogui/video_playback.shio`: ALL PASSED.

## Phase 2: choosing the devices (needs two outputs: speakers and headphones, or a USB interface)

Put a video with music into a Patchview, *Options* › *Audio* on.

- [ ] *Settings* › *Sound* lists the outputs of the system with their names as the system shows them. Two of the same
      name: the second is "Name (2)".
- [ ] *Main output* = the headphones: the music moves to the headphones at once (a short gap is fine), the status line
      says "Plays on <headphones>". Back to *System default*: back to the speakers.
- [ ] Restart VibeVJ: the choice comes back (`engine/style.json`, `video_audio_output`), the music plays there.
- [ ] *System default*, then change the default output in the system settings while it plays: the sound follows
      (miniaudio reroutes the default device). Note how long it takes.

## Phase 3: unplugging (needs USB or Bluetooth headphones, or an interface you can unplug)

- [ ] *Main output* = the USB device, music playing. Unplug it: within about 2 s the default output plays; *Settings* ›
      *Sound* shows "<name> (not connected)" and the status "(the chosen one is not connected)". No crash, no hang of
      the picture.
- [ ] Plug it in again: within about 2 s the music is back on it.
- [ ] Unplug and plug while *Settings* is closed: the same.
- [ ] Start VibeVJ with the chosen device unplugged: it plays on the default; plug it in: it moves there.

## Phase 4: pre-listen (needs two outputs)

- [ ] *Pre-listen output* = the headphones. A clip with *Options* › *Pre-listen* on (and *Audio* on or off): heard only
      on the headphones, not on the speakers.
- [ ] A second clip with *Audio* on and *Pre-listen* off: on the speakers only, the first stays on the headphones.
- [ ] *Pre-listen* off on the first clip (*Audio* on): it moves to the speakers, no click, no gap in the picture.
- [ ] With the AudioInputAnalysis on *Source* *Video clips* and *Audio analysis* on in both clips: the analysis follows
      only the clip on the speakers.
- [ ] Unplug the headphones: the clip on pre-listen is silent, the line under its controls says "The pre-listen output
      '...' is not connected"; plug them in: it plays again within about 2 s.
- [ ] Main output and pre-listen output the same device: both clips are heard there, nothing breaks.

## Phase 5: Level (a person watching)

- [ ] *Level* of a clip with music follows the loudness (the kick shows as peaks), falls back to 0 within about a
      second when the clip is paused.
- [ ] Link *Level* into the size or brightness of a shader: it pulses with the music.
- [ ] *Volume* 0.5: *Level* about half.
- [ ] *Audio* off, *Audio analysis* on: *Level* still moves (nothing is heard).
- [ ] Map *Level* to a MIDI output (LED of a controller) if one is at hand: it lights with the music.

---

## Results

### Windows (date)

Machine, sound devices. Per phase: pass / fail, screenshots for anything wrong, bugs fixed during the test with their
commit.

### macOS (date)

Machine, sound devices. Per phase: pass / fail, screenshots, fixes.
