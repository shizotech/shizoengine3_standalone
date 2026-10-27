# Camera input (#588) and video sync (#460): test on Windows and macOS

[#588](https://github.com/shizotech/shizoscript3_source/issues/588): "Need a camera input generator for vibevj."
[#460](https://github.com/shizotech/shizoscript3_source/issues/460) points 1 and 2: "Prolink sync: a clip follows a
CDJ deck" and "BPM sync: loop length on whole bars, the timeline drives the position". Branch
`claude/brave-gates-35sjyt`. Built and checked on Linux in a container (g++, Mesa llvmpipe under Xvfb, the pinned
FFmpeg 9.0.2 of BtbN). A container has no camera, no CDJ and no real GPU: the camera path was tested with FFmpeg's
test source (`lavfi`, same code path after the device), the deck sync with the demo recording of ProlinkBridge.
Everything with a real device is this checklist.

**C++ changed** (`modules/shzmodule_nanogui`): nanogui has to be built, and the FFmpeg folder needs the two new
libraries (below). Scripts changed too.

Write the results into *Results* at the end of this file (machine, camera / capture card, CDJ model, what passed,
what not, screenshots), or as a comment on the PR.

---

## What changed

### nanogui (C++)

| File | What |
|---|---|
| `video_camera.cpp/.h` (new) | `nanogui.camera_devices()`: DirectShow (Windows), Video4Linux2 (Linux), AVFoundation (macOS, read from FFmpeg's log, includes the screens). Builds what `avformat_open_input` gets: size, rate, pixel format, and attempts with fewer constraints when the device refuses |
| `video_decoder.cpp/.h` | `open_live()`: live mode (newest frame wins, no seek / loop / cache / sound / GPU decoder), FFmpeg interrupt callback (close does not wait for the next frame, open gives up after 10 s) |
| `video_widget.cpp/.h` | `video.open_camera(id, [width, height, fps, input_format, format])`, `live()`, `camera()`; save / load keep the camera instead of a file name |
| `ffmpeg_runtime.cpp/.h` | loads `avfilter` + `avdevice` the first time a camera is used, from the folder of the other FFmpeg libraries; optional (files still play without them) |
| `context_nano.cpp` | `nanogui.camera_devices()`, `camera_available()`, `camera_error()` |
| `libraries/ffmpeg/include` | headers of libavdevice 63, `libavfilter/version_major.h` |

New FFmpeg files (about 38 MB per platform; `compile_scripts/ffmpeg_fetch.shio` fetches them from the same pinned
archive, the hash did not change): Windows `avfilter-12.dll`, `avdevice-63.dll`; Linux `libavfilter.so.12`,
`libavdevice.so.63`; macOS `libavfilter.12.dylib`, `libavdevice.63.dylib` (`build_ffmpeg.sh` build 2, now with
`--enable-avfoundation`). The app bundle has `NSCameraUsageDescription` (`bundle.sh`).

### VibeVJ (scripts)

- New generator `assets/Generators/Input/Camera.asset`: list *Pick a camera…* (cameras + *Test pattern*), control
  `camera` (the id, saved), *Play*, *Resolution*, *Frame rate*, *Flip Y*, *Size*, *Video router*, *Out*. Reopens a
  lost camera every 3 s.
- Video clips (`engine/generators/extensions/video/video_module.shio`): control *Sync* (Off / Bars / Deck) and
  *Sync settings* (*Bars*, *Deck*, *Offset*). New save keys `sync`, `sync_bars`, `sync_deck`, `sync_offset`; old
  projects load with *Sync* off. No other ID changed.
- ProlinkBridge / ProlinkDecks put their device into `std.global("prolink_sources")` (and take it out in `on_free`),
  so a clip reads the decks without a connection of its own.
- Docs: `docs/video.md` (Cameras, Sync), wiki *Video* (Sync), *Output and devices* (Receiving video).

### Checked on Linux

- `_testing/nanogui/video_camera.shio` (new): ALL PASSED (live colour, 30 frames / s, pause, save / load, missing
  device, close).
- `_testing/nanogui/video_playback.shio`: ALL PASSED. `_testing/video/decoder_test.cpp`: PASSED.
- `check_assets.sh` on the four changed scripts: 4 passed. Wiki links: 0 broken.
- In the app over MCP (Xvfb): Camera with *Test pattern* shows 1280x720 30 fps; a HAP clip with *Sync* *Bars*: 1 / 2 /
  4 bars at 150 BPM measured 1.77 / 0.92 / 0.45x (expected 1.875 / 0.94 / 0.47x, the measurement is coarse: 10 fps
  clip read over MCP); timeline stopped + *Offset* 1.5 s → position 0.5 of the 3 s clip; *Deck* with ProlinkBridge
  *Demo*: the clip runs with the master deck (0.94x).
- `shzscript_macos/check_libcxx_linux.sh` (clang + libc++).

---

## Phase 0: get the branch

```
git fetch origin claude/brave-gates-35sjyt
git checkout claude/brave-gates-35sjyt
```

- **Windows**: `& .\_testing\windows_app\build.ps1` (nanogui changed), then
  `& .\_testing\windows_app\testcopy.ps1 -Name pr -Binaries <build out>`. Run `shz compile_scripts/fetch_ffmpeg.shio
  windows_x64` (or copy `avfilter-12.dll` and `avdevice-63.dll` from the BtbN archive) so the `ffmpeg\` folder next to
  nanogui has the two new DLLs.
- **macOS**: `sh shzscript_macos/setup_mac.sh --build` (builds FFmpeg again: build 2, with AVFoundation; bundles,
  runs every test).

## Phase 1: automatic checks

- [ ] Windows: `build.ps1` builds nanogui without an error (new file `video_camera.cpp` in the `.vcxproj`).
- [ ] macOS: `setup_mac.sh --build` ends without an error; `ffmpeg/` in the bundle has `libavdevice.63.dylib` and
      `libavfilter.12.dylib`.
- [ ] `shz _testing/nanogui/video_camera.shio` → `ALL PASSED` (no camera needed).
- [ ] `shz _testing/nanogui/video_playback.shio` → `ALL PASSED` (file playback unchanged).
- [ ] `shz -p "import nanogui; std.print(nanogui.camera_available(), nanogui.camera_error(), nanogui.camera_devices());"`
      lists the cameras of the machine with id / name / format.

## Phase 2: a real camera (needs a webcam or a capture card)

Drag *Generators* › *Input* › *Camera* into a Patchview.

- [ ] *Pick a camera…* lists the cameras by name (Windows: no microphones; macOS: also *Capture screen 0*). Picking
      one shows its picture within about a second; the line under the list says e.g. `<name>: 1280x720 30 fps mjpeg`.
- [ ] *Resolution* 1280x720 / 1920x1080 and *Frame rate* 30 / 60: the line shows what the camera gave. A size the
      camera does not have falls back to its default instead of an error.
- [ ] The picture is the right way up and moves smoothly (no growing delay after a minute: wave a hand, the
      picture follows at once).
- [ ] *Out* linked into a shader input and as *Video router* in a shader's *Inputs*: the camera picture there.
- [ ] *Play* off holds the picture, on goes on. ACT (power) off holds it too.
- [ ] Unplug the camera: the line says it is not available (trying again); plug it in: the picture comes back by
      itself within a few seconds.
- [ ] Open the camera in another program first (Windows: the Camera app; macOS: Photo Booth): the line says why it
      cannot be opened; close the other program: it comes back.
- [ ] Save the project, restart VibeVJ, load it: the same camera opens with the same resolution / rate.
- [ ] Two Camera generators with two cameras at once (if there are two).
- [ ] macOS: the first time macOS asks for the camera permission (VibeVJ.app); after *Allow* the picture comes.
      Capture screen 0 shows the screen.
- [ ] Capture card (HDMI / SDI, if there is one): its picture at its size.
- [ ] Remove the generator while the camera runs: no hang, no crash, the camera light goes off.

## Phase 3: Bars sync (no hardware)

A video clip (best a HAP copy: *Options* › *Convert to HAP*) in a Patchview, *Sync* = *Bars*.

- [ ] Timeline playing at 120 BPM, *Bars* 1: a 4 s clip plays twice as fast (2.0x in the line) and starts over on
      every bar (watch the bar counter of the timeline).
- [ ] Change the BPM / tap: the clip speed follows, still on the bar.
- [ ] Timeline stopped, drag the cursor: the clip scrubs with it.
- [ ] *Offset*: the clip starts later in the bar by that many seconds.
- [ ] A H.264 clip: it follows too (jumps at most once a second).
- [ ] *Sync* Off: the *Speed* slider works again.

## Phase 4: Deck sync (needs CDJs, or the ProlinkBridge demo)

ProlinkBridge (*Source* USB / Network card with real CDJs; without: *Demo*), a clip with *Sync* = *Deck*.

- [ ] *Deck* 0: the clip follows the tempo master: play / pause on the CDJ plays / holds the clip, a cue jump or a
      jump in the track moves the clip there, pitch ± changes its speed (line: `sync: deck N (title), speed x`).
- [ ] *Deck* 1..4 follows that player.
- [ ] CDJ-3000 and an older player (position from the beat grid): both follow; a track without beat grid says
      "has no position".
- [ ] Remove the ProlinkBridge generator: the clip says "no CDJs" and stops following, no error.

---

## Results

### Windows (<date>)

Machine, GPU, camera(s), FFmpeg folder. Per phase: pass / fail, screenshots of anything wrong, bugs fixed during the
test with their commit.

### macOS (<date>)

Machine, macOS version, camera(s). Per phase as above.
