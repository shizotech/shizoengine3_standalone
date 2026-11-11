# Jog and clip sound for the audio analysis (#460): test on Windows and macOS

[#460](https://github.com/shizotech/shizoscript3_source/issues/460) points 10 and 4: "MIDI jog / scratch mode: a
control Jog that moves the position relatively (turntable / jog wheel of a DJ controller), pauses while touched and
continues afterwards" and "the sound of a clip as input of the audio analysis: pick a video generator as audio source
of the analysis (BPM, FFT bands, energy) instead of the sound card". Branch `claude/460-jog-audio-source`.

Built and checked on Linux in a container (g++, Mesa llvmpipe under Xvfb, FFmpeg 9.0.2 of BtbN). A container has no
sound card, no speakers and no MIDI hardware: the jog was played with the virtual MIDI controller (an endless knob,
relative), the sound went through miniaudio's null device. A real output device (WASAPI, CoreAudio), a real jog wheel
and what the analysis makes of real music are this checklist.

**C++ changed** (`modules/shzmodule_nanogui`): nanogui has to be built. Scripts changed too.

Write the results into *Results* at the end of this file (machine, sound device, MIDI controller, what passed, what
not, screenshots), or as a comment on the PR.

---

## What changed

### nanogui (C++)

| File | What |
|---|---|
| `video_audio.h/.cpp` | A source has two routes: `set_to_output` (the speakers, *Audio*) and `set_to_analysis`. `shz_video_audio_mix_sources` mixes one period: every source, the ones to the output into the device buffer, the ones to the analysis into a second buffer. `shz_video_audio_analysis` keeps that second mix as mono int16 (at most 0.5 s) until it is taken |
| `video_audio_device.cpp` | The device callback uses the function above. Without an output device the null device of miniaudio runs instead (`MA_ENABLE_NULL`): it plays nothing, its clock keeps the analysis fed. *Audio* still reports "No audio output device could be opened" then |
| `video_widget.cpp/.h` | `video.audio_analysis(on)`; the sound is decoded while *Audio* or *Audio analysis* is on; switching one of them while the other is on does not reopen the file. Save / load key `audio_analysis` |
| `context_nano.cpp` | `nanogui.video_audio_take()`: `[rate, samples, clips, device, data]`, data = int16 little-endian mono 48 kHz |

### VibeVJ (scripts)

- Video clips (`engine/generators/extensions/video/video_module.shio`): new controls *Jog* (a knob -1..1, below
  *Position*), *Jog settings* › *Jog touch* and *Jog step*, *Options* › *Audio analysis*. New save keys
  `audio_analysis`, `jog_step`. No other ID changed; old projects load with both off.
- AudioInputAnalysis: *Source* has a fourth entry *Video clips* (index 3). The line under it says how many clips it
  hears. The analysis process gets the samples as "pcm" messages, like the ones of DJ Watch.
- Docs: wiki *Video* (*Jog*, *Sound for the audio analysis*), wiki *Audio* (*Source*), skill `vibevj_live`.

### Checked on Linux

- `_testing/video/decoder_test.cpp`: PASSED, with the new part "sound to the audio analysis" (mix of output and
  analysis routes, int16 conversion, 0.5 s limit, paused = silence).
- `_testing/nanogui/video_audio_analysis.shio` (new): ALL PASSED (440 Hz clip, *Audio* off: 48 000 samples per second,
  peak 2895; paused: silence; *Audio* on as well; off; `load()`; close).
- `_testing/nanogui/video_playback.shio`: the sound part passes; "speed(-1) plays backwards" and "backwards loop wraps"
  fail under load on main too (other builds ran on the machine).
- `check_assets.sh`: 70 passed. Wiki links: 0 broken.
- In the app over MCP (Xvfb): a HAP clip with *Audio analysis* on, AudioInputAnalysis *Source* *Video clips*: the line
  says "Video clips: 1 clip in the analysis (no output device, ...)", the energies move. *Jog* mapped to a relative
  knob of the virtual controller: +3 / +2 / -4 / -5 steps moved the clip 3 / 2 / -4 / -5 frames and held it, it played
  on 0.2 s after the last step; *Jog touch* held it 0.8 s; a mouse drag of 40 px up moved it 25 frames. Saved and
  loaded: *Audio analysis*, *Jog step* and *Source* come back.
- macOS compile: the four changed files of nanogui compile with clang + libc++ (the CMake build of `shzscript_macos`,
  only those objects; not linked, the Mac tests not run).
- MSVC compile check (`check_msvc_linux.sh --only nanogui`): nanogui 120 files ok.

---

## Phase 0: get the branch

- Windows: `& .\_testing\windows_app\build.ps1 -Only nanogui`, then `& .\_testing\windows_app\testcopy.ps1 -Name pr460j -Binaries <build out>`.
- macOS: `sh shzscript_macos/setup_mac.sh --build`.

## Phase 1: automatic

- [ ] `_testing/nanogui/video_audio_analysis.shio`: ALL PASSED. With a sound card the "info sound" line does not
      appear (the real device runs).
- [ ] `_testing/nanogui/video_playback.shio`: ALL PASSED (the sound plays at 1x with the real device).
- [ ] `_testing/video/decoder_test.cpp` (build line at its top): PASSED.

## Phase 2: sound for the analysis (needs speakers or headphones)

Put a video with music (a music video, a DJ set recording; H.264 or HAP) into a Clipview and launch it; add
AudioInputAnalysis.

- [ ] Video *Options* › *Audio analysis* on, *Audio* off; analysis *Source* *Video clips*. Nothing is heard; *BPM*
      finds the tempo of the music within ~10 s, *Low energy* follows the kick, the FFT texture moves.
- [ ] *Audio* on as well: the music plays, no click or gap when *Audio* is switched (the file is not opened again),
      the analysis goes on.
- [ ] *Volume* down to 0.2: the analysis still follows (its levels adapt; very low volumes may lose the beat, note it).
- [ ] Pause the clip: the energies fall to 0; play: they come back. Speed 2 or backwards: silent for the analysis too.
- [ ] Two clips with *Audio analysis* on: the line says "2 clips", both are in the analysis.
- [ ] *Source* *Sound card* and back to *Video clips*: switching works, no error in the log.
- [ ] Unplug the headphones / switch the default output while it plays: note what happens (the device is not
      reopened, known; the analysis may stop until the clips are reopened).
- [ ] CPU of the app with one 1080p clip and *Audio analysis* on: about the same as without (the analysis is a process
      of its own).

## Phase 3: jog (needs a MIDI controller with a jog wheel or an endless encoder)

- [ ] MIDI learn *Jog* with the jog wheel, set the mapping to *Relative* (the kind the manual names). Turning moves the
      clip frame by frame, forward and back, and holds it; it plays on when the wheel stops.
- [ ] Map the touch note of the jog wheel to *Jog settings* › *Jog touch*: the clip holds while the hand is on the
      wheel, plays on when it is let go.
- [ ] Fast spinning with a HAP clip: the picture follows without lag (scratching). With an H.264 clip: it follows
      slower (note how it feels).
- [ ] *Jog step* 4: one turn goes four times as far.
- [ ] *Play* off: the jog moves the held clip, it stays held afterwards.
- [ ] *Sync* *Bars*: the jog does nothing.
- [ ] Mouse: drag *Jog* up / down: the clip scrubs, the knob springs back to 0 when let go.
- [ ] Windows: the knob looks right at 100 % and 150 % display scale; macOS: on a Retina screen.

---

## Results

### Windows (date)

Machine, sound device, MIDI controller. Per phase: pass / fail, screenshots for anything wrong, bugs fixed during the
test with their commit.

### macOS (date)

Machine, sound device, MIDI controller. Per phase: pass / fail, screenshots, fixes.
