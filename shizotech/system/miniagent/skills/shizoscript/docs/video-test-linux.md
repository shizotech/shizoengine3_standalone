# Video on Linux: test results (#458)

Video playback (#278) and FFmpeg 9 on Linux x64, tested by the checklist of
[#458](https://github.com/shizotech/shizoscript3_source/issues/458) (rules: #457). Branch
`claude/video-linux-457`, based on `claude/video-phase2-278` at `010c2c19`. Design and the Windows
numbers: `docs/video.md`.

## Machine

| | |
|---|---|
| Distribution | CachyOS (Arch based, rolling), KDE Plasma 6.7.5 |
| Kernel | 7.2.9-1-cachyos |
| CPU | Intel Core i5-13600K (20 threads), 32 GB |
| GPUs | NVIDIA GeForce RTX 4080 (renders, `renderD128`, driver 615.71.09) + Intel UHD Graphics 770 (`renderD129`, i915) |
| OpenGL | 4.6.0 NVIDIA 615.71.09 (`glxinfo -B`) |
| Mesa | 26.2.4 |
| VAAPI | libva 2.24.1; drivers `iHD` (Intel) and `nvidia` (libva-nvidia-driver 0.0.18, NVIDIA's wrapper on NVDEC). `vainfo` is not installed (no root on this machine) |
| Sound | PulseAudio 15.0 API on PipeWire 1.6.9 (`pactl info`) |
| Display | Wayland (KWin); the app runs on XWayland (`DISPLAY=:0`) |
| Compiler | GCC 16.2.1, glibc 2.44 |
| FFmpeg (to make test media only) | Arch `ffmpeg` 9.0.2 |

## Phase 0: packages

Everything to build was there. Not installed and no root to install them: `xorg-server-xvfb`, `xdotool`,
`boost`, `libva-utils` (`vainfo`). Consequences: the webserver module does not build (boost, not related to
video); the headless GL run of Phase 3 needs a replacement for `xvfb-run` (see there).

## Phase 1: build

`_testing/linux_app/build.sh`: shz and every module VibeVJ imports build with GCC 16 (only webserver fails:
`boost/asio.hpp` missing, see Phase 0).

- All new files compile without an error: `video_decoder.cpp`, `video_convert.cpp`, `video_hap.cpp`,
  `video_audio.cpp`, `video_audio_device.cpp`, `ffmpeg_runtime.cpp`, `video_widget.cpp`, `filebrowser.cpp`,
  `context_nano.cpp`. `build.sh` compiles with `-w`; compiled once more with `-Wall -Wextra` they give no
  warning either (only the old `filebrowser.cpp:33` misleading indentation, harmless).
- `ldd .../shzmodule_nanogui.so | grep -i -E "libav|libsw"` prints nothing.
- `fetch_ffmpeg.shio linux_x64`: the mirror `shizotech/shizoscript3/releases/download/ffmpeg-9.0.2-lgpl-shared/`
  answers **404** (the mirror release does not exist yet), the second URL (BtbN `autobuild-2026-10-17-20-51`)
  works, the hash matches. `ffmpeg/` then holds `libavcodec.so.63`, `libavformat.so.63`, `libavutil.so.61`,
  `libswresample.so.7`, `libswscale.so.10`, `LICENSE.txt`, `README.txt`. A second run: "is up to date".

## Phase 2: headless decoder test

Built exactly as in #458 (`g++ -std=c++20 -O1 ... -ldl -pthread`).

| Run | Result |
|---|---|
| `010c2c19` as it is | `FAILED`, 2 to 7 failures per run, different ones every run (5 runs) |
| with the two fixes below | `PASSED (0 failures)`, 10 runs in a row |
| same, VAAPI switched off (`LIBVA_DRIVER_NAME=doesnotexist`, i.e. like an NVIDIA-only machine: `cuda`) | `PASSED (0 failures)`, 3 runs |
| without `SHZ_FFMPEG_DIR`, binary next to `ffmpeg/` | `PASSED (0 failures)`, first line `FFmpeg: avformat 63.1.102 / avcodec 63.1.102 / avutil 61.1.102 / swscale 10.1.102` |

- The loader finds the BtbN libraries (no RPATH) in `<own folder>/ffmpeg/`.
- The 32x32 / 64x64 H.264, HEVC and MJPEG clips are below what NVDEC accepts; with `cuda` FFmpeg logs
  `Failed setup for format cuda: hwaccel initialisation returned error` and falls back to software, as designed
  (macOS shows the same with VideoToolbox).

### Fix 1: NVIDIA's VA-API wrapper (Linux only)

Failures: `seek 0.75 s shows frame 7 (got 14)`, `seek 2.25 s shows frame 22 (got 11)` (MPEG-2), random seek and
backwards failures with MJPEG and H.264. Cause: FFmpeg opens `renderD128` for VAAPI when no device is named,
which here is the NVIDIA GPU with NVIDIA's VA-API wrapper (`nvidia_drv_video.so`, libva-nvidia-driver on top of
NVDEC). It refuses to set up H.264 / HEVC / MJPEG (`Failed setup for format vaapi`) and, after a seek, the first
frame carries the picture of a frame decoded before the seek, at the right position. Without hardware, with
`cuda` and with VAAPI on the Intel GPU the same seeks are right every time (diagnosis program, 8 runs per clip).

Fix (`336687b3`, `video_decoder.cpp`, inside `#if defined(__linux__)`): VAAPI is opened on the first render
node whose kernel driver is not `nvidia` (`/sys/class/drm/renderD*/device/driver`). An NVIDIA-only machine has
none and decodes through `cuda` (NVDEC, next in the list); a machine with an Intel / AMD GPU next to the NVIDIA
one uses that one for VAAPI.

### Fix 2: a pass that ends after a seek (shared)

Failure: `plays backwards` after a conversion, about 1 run in 3: after a forward pass to the end (loop off),
`seek(2.95, true)` delivered no frame at all. Cause: the worker was still finishing the old pass when `seek()`
came in; `seek()` cleared `m_reached_end`, then the worker set it again for the pass that had just ended, and
the new pass waited forever. Reproduced 3 times in 40, 0 times in 300 after the fix.

Fix (`0f332958`, `shared:`, `video_decoder.cpp`): `m_reached_end` is only set when no newer seek is pending.

## Phase 3: GL test

`_testing/nanogui/video_playback.shio`, each run in an empty folder. Includes the macOS shared fix `e04a1d31`
(cherry-picked: "speed(1) turns around" starts from the middle of the clip).

| Run | GL | Decoder | Result |
|---|---|---|---|
| desktop (KDE Wayland, XWayland), 4 runs | NVIDIA RTX 4080, 4.6.0 NVIDIA 615.71.09 | `vaapi` (Intel UHD 770) | `ALL PASSED` |
| desktop after fix 3 (Phase 4), 19 runs | NVIDIA RTX 4080 | `cuda` | `ALL PASSED` 18 times; once the first 720p clip had no picture after 500 ms (not seen again, see Open) |
| desktop, VAAPI switched off (`LIBVA_DRIVER_NAME=doesnotexist`) | NVIDIA RTX 4080 | `cuda` | `ALL PASSED` |
| headless: `Xvfb :97`, `LIBGL_ALWAYS_SOFTWARE=1 __GLX_VENDOR_LIBRARY_NAME=mesa` | llvmpipe (LLVM 23.1.1), Mesa 26.2.4 | `vaapi` (Intel UHD 770) | `ALL PASSED` |

- No root here, so `Xvfb` and `vainfo` came from the Arch packages `xorg-server-xvfb` 21.1.25-2 and
  `libva-utils` 2.24.0-1, signatures checked with `pacman-key --verify`, only unpacked into a scratch folder.
  With the NVIDIA libGL in place, llvmpipe needs `__GLX_VENDOR_LIBRARY_NAME=mesa` besides
  `LIBGL_ALWAYS_SOFTWARE=1`.
- HAP as DXT: `DXT 1` for HAP, HAP chunks, HAP Alpha and HAP Q on NVIDIA and on llvmpipe (both have
  `GL_EXT_texture_compression_s3tc`).
- Sound: `sound plays at 1x, level 0.09` on the desktop (PipeWire). The headless run found the PipeWire
  server as well (same user session), so the "no output device" case was not seen.
- The 720p clips name `vaapi` under llvmpipe too: the decoder uses the DRM render node, it does not depend on
  the GL renderer.
- The `Runtime Error` block in the output (`speed: this video cannot play backwards`) is the expected warning
  of "speed(-1) on H.264 is refused".

## Phase 4: real media and measurements

The clips of `_testing/video/clips/README.md` ("Real media", 5.7 GB) were made with the very same commands as on
Windows, NVENC included (Arch's `ffmpeg` 9.0.2 has `h264_nvenc` / `hevc_nvenc` and the `hap` encoder), so the
bitstreams match the Windows ones; libx264 / libx265 were not needed. Same hardware as the Windows numbers in
`docs/video.md` (RTX 4080 + i5-13600K, render loop 144 fps), so the tables compare directly.

### Fix 3: decode on the GPU that renders (Linux only)

With fix 1 alone this machine decoded on the Intel UHD 770 (VAAPI comes first, renderD129 is the first node
that is not NVIDIA's), while GL renders on the RTX 4080. `video_hardware.shio ~/media` passed, but 4K60 at 4x
only reached 3.11x (H.264), 3.63x (HEVC) and 2.25x (HEVC 10 bit), and every frame went from one GPU to the
other through system memory.

Fix (`8369872c`, inside `#if defined(__linux__)` in `video_decoder.{h,cpp}` and `video_widget.cpp`): like
`zero_copy_wanted()` on Windows, `shz_video::open()` hands `GL_VENDOR` to the decoder. NVIDIA renders: `cuda`
before VAAPI. Intel / AMD renders: VAAPI on the render node of that PCI vendor. Headless (decoder_test, llvmpipe:
vendor "Mesa") nothing changes. A laptop that renders on its Intel GPU keeps decoding there and does not wake
the NVIDIA one. Afterwards every clip names `cuda` here and every speed is reached.

### `video_hardware.shio ~/media` (check)

`ALL PASSED`, no `slow` line. H.264 / HEVC 8 and 10 bit, 1080p and 2160p: `cuda`; HAP, HAP Q, HAP Alpha:
`DXT on the GPU`; ProRes, DNxHR: `software`. Colours (orange 252,127,0, BT.601 full range 255,127,0) and
orientation through NVDEC are right, also at the padded edges. 1x follows real time (1.00x), 0.25x to 4x are
reached (4K60 at 4x: 4.00x for H.264, HEVC and HEVC 10 bit; Windows copy path: 2.4x), pause / play and the loop
seam work for every clip (seam gap 14 to 63 ms, the 63 ms is ProRes 4444).

Run once more with VAAPI on the Intel UHD 770 (before fix 3): `ALL PASSED` as well, with the three `slow` 4x
lines above.

### `video_hardware.shio ~/media random`

`ALL PASSED`: every jump lands on its frame, long-GOP backwards is refused.

| Clip | Jump (paused) | Scrub, pictures/s | -1x / -2x / -4x, pictures/s |
|---|---|---|---|
| H.264 1080p60 (cuda) | 71 ms (max 125) | 20.4 | refused |
| H.264 1080p30 B-frames (cuda) | 122 ms (max 236) | 15 | refused |
| HEVC 2160p60 (cuda) | 122 ms (max 215) | 8.5 | refused |
| HAP 1080p30 (DXT) | 6 ms (max 7) | 144 (render rate) | 30 / 60 / 120 |
| HAP Q 1080p30 (DXT) | 6 ms (max 7) | 144 | 30 / 60 / 120 |
| ProRes 422 HQ 1080p30 | 38 ms (max 43) | 31 | 30 / 30 / 41 |
| DNxHR HQ 1080p30 | 30 ms (max 35) | 47 | 30 / 60 / 60 |
| HAP 2160p30 (DXT) | 7 ms (max 9) | 144 | 30 / 60 / 120 |
| ProRes 422 2160p30 | 91 ms (max 110) | 11 | 15 / 15 / 17 |
| DNxHR SQ 2160p30 | 73 ms (max 84) | 14.5 | 15 / 20 / 20 |

Every backwards speed is reached (within 3 %); like on Windows, 4K ProRes / DNxHR skip frames to keep it. The
numbers are the Windows ones within a few percent, the CPU-decoded intra-only clips slightly faster.

### `stress`: decoder budget (cuda, copy through system memory)

How many instances of one 60 fps clip play without dropped frames, as in `docs/video.md` "Decoder budget". Linux
has only the copy path so far (zero-copy is Phase 8); Windows columns from `docs/video.md` for comparison.

| Clip | Linux, cuda (copy) | Windows, copy | Windows, zero-copy |
|---|---|---|---|
| H.264 1080p60 (20 Mbit/s) | 16 (20: 49 fps, 24: 41 fps) | 12 (16: 48 fps) | 14 (16: suspended) |
| HEVC 1080p60 8 bit | 24 (32: 44 fps) | 8 (more not measured) | 24 (32: suspended) |
| HEVC 1080p60 10 bit | 12 (16: 42 fps) | below 8 (8: 55 fps) | 24 |
| H.264 2160p60 (60 Mbit/s) | 4 (5: 49 fps, 6: 41 fps) | 2 (4: 46 fps) | 4 (5: suspended) |
| HEVC 2160p60 8 bit | 8 (min 58.2 fps, i.e. at the limit; 10: 33 fps) | 2 (4: 52 fps) | 8 (10: suspended) |
| HEVC 2160p60 10 bit | 4 (6: 29 fps) | 1 (2: 55 fps) | 8 |

| Streams | CPU, Linux cuda (copy) | NVDEC load | Windows copy | Windows zero-copy |
|---|---|---|---|---|
| 1 x H.264 1080p60 | 6 % | 8 % | 33 % | 19 % |
| 4 x H.264 1080p60 | 15 % | 36 % | 98 % | 45 % |
| 8 x H.264 1080p60 | 35 % | 62 - 76 % | 156 % | 49 % |
| 12 x H.264 1080p60 | 55 % | 74 % | 170 % | 60 - 84 % |
| 16 x H.264 1080p60 | 74 % | 98 % | - | - |
| 8 x HEVC 1080p60 | 33 % | 31 % | 133 % | 41 % |
| 1 x H.264 2160p60 | 12 % | 30 % | 81 % | 13 % |
| 2 x H.264 2160p60 | 30 % | 65 % | 133 % | 25 % |
| 1 x HEVC 2160p60 | 15 % | 14 % | 58 % | 17 % |
| 2 x HEVC 2160p60 | 32 % | 28 % | 123 % | 24 % |

(Software decoding for comparison: 1 x H.264 1080p60 29 %, 4 x 119 %, 1 x HEVC 2160p60 100 %; Windows 49 %,
187 %, 168 %.)

- The render loop stays at 144 fps in every run (lowest 137.9 fps with 6 x HEVC 10 bit 2160p60).
- 8 bit: the limit is NVDEC (98 - 100 % "decoder" in `nvidia-smi` at the first count that drops, as on
  Windows). The CUDA copy (`av_hwframe_transfer_data`, DMA into system memory) is much cheaper than the D3D11
  staging copy on Windows: the Linux copy path reaches the Windows zero-copy counts for 8 bit and costs about as
  much CPU as Windows zero-copy.
- 10 bit (P010, twice the bytes) stops earlier with NVDEC at only 43 - 49 %: there the copy and the upload of
  16 bit planes are the limit. That is where zero-copy (Phase 8) would gain most.
- Video memory (`nvidia-smi`, whole GPU incl. the desktop at about 1.3 GB): + about 75 MB per 1080p stream and
  + about 270 MB per 2160p stream.

### `stress`: HAP as DXT

The three runs of the checklist:

| Run | Result |
|---|---|
| `stress hap_2160p30.mov 8 8` | DXT on the GPU, every stream 30 of 30 fps, render 144 of 144 fps, smooth, CPU 50 % |
| `stress hap_2160p30.mov 8 8 nodxt` | FFmpeg RGBA, streams 17.8 of 30 fps, render 24 of 144 fps, DROPS, CPU 413 % |
| `stress h264_1080p60.mp4 8 8` | cuda, every stream 60 of 60 fps, render 144 of 144 fps, smooth, CPU 35 % |

Same columns as `docs/video.md` (8 s each):

| Streams (`stress`, 8 s) | FFmpeg RGBA (`nodxt`) | DXT |
|---|---|---|
| 4 x HAP 2160p30 | 29.6 fps, render loop 102 fps (CPU 167 %) | 30 fps, render loop 144 fps (CPU 22 %) |
| 8 x HAP 2160p30 | 17.8 fps, render loop 24 fps (413 %) | 30 fps, 144 fps (50 %) |
| 16 x HAP 2160p30 | - | 30 fps, 144 fps (109 %) |
| 16 x HAP 1080p30 | 29.5 fps, render loop 140 fps (202 %) | 30 fps, 144 fps (32 %) |
| 48 x HAP 1080p30 | - | 30 fps, 144 fps (105 %) |
| 8 x HAP Q 1080p30 | 30 fps, render loop 143 fps (338 %) | 30 fps, 144 fps (26 %) |

CPU: the whole process in percent of one core (20 threads = 2000 %), from `/proc/<pid>/stat` over the
measurement window. The DXT path matches Windows (30 fps, render loop 144 everywhere); FFmpeg's RGBA path
holds up somewhat better here than on Windows (4 x HAP 2160p30: render loop 102 instead of 20 fps).

### Intra-only on the CPU

One stream, CPU of the process: HAP 1080p30 (DXT) 3 %, ProRes 422 HQ 1080p30 53 %, DNxHR HQ 1080p30 44 %;
2160p30: HAP (DXT) 5 %, ProRes 422 146 %, DNxHR SQ 115 %. 8 x 1080p30 play smoothly: ProRes 422 HQ 442 %,
DNxHR HQ 348 %. (Windows: ProRes 422 HQ 70 %, DNxHR HQ 59 %, 8 x 513 % / 382 %.)

## Phase 5: VibeVJ by hand

VibeVJ from `out/run` (a copy of `_shizoengine3`, like `app.sh desktop`) on the KDE Wayland desktop (XWayland,
3440x1440, 144 Hz), RTX 4080 with `cuda`. Driven with real input events (XTest through python-xlib: clicks,
drags from *Assets*, right clicks, menu), checked on screenshots; the sound measured on the monitor of the
default output (`parec`, RMS of 2 s). `assets/Videos/` got `counter_h264_audio.mp4` and `h264_1080p60.mp4`.
(Local only: the webserver module of the standalone Linux bundle, this machine has no boost.)

| Step | Result |
|---|---|
| 1. Patchview, drag `h264_1080p60.mp4` in | preview plays, info line `h264 1920x1080 60 fps, cuda` |
| 2. *Position*, *Frame back* / *Frame forward* | Position 0.36 → 0.82: picture jumps to 16.4 s (frame 984) and plays on; *Frame back*: *Play* goes off, frame 1126; 2 x *Frame forward*: 1128 |
| 3. *Options › Convert to HAP* | button reads *Cancel convert*, info line `converting to HAP: 22 %` … `80 %`, then `HAP copy ready: h264_1080p60_hap.mov`; the file appears in *Assets* (826 MB, about 10 s) |
| 4. Right click in *Assets* | menu *Convert to HAP*; line under the list `Converting to HAP: 199596-910653729.mp4 20 %` … `63 %` … `… is ready`; on `h264_1080p60` the entry is greyed out: `HAP copy exists: h264_1080p60_hap.mov` |
| 5. HAP copy, *Speed* | −4.00 … 4.00; at −2.15 the time code runs backwards (6.7 s → 2.8 s) and wraps to the end (18.8 s); info line `hap 1920x1080 60 fps, DXT on the GPU, backwards` |
| 6. Clip with sound | info line `sound off`, silent; *Audio* on: `sound`, RMS 0.061; *Play* off: 0; *Speed* 2: 0; 0.87: 0; 1: 0.057; *Volume* 0.51: RMS 0.029 (0.47 of full) |
| 7. Save, quit (*Exit*), start | Speed, Loop, Audio, Volume are back, **Position was not** (fix 4) |

### Fix 4: loading a project restarted every clip and converted it (shared)

Found in step 7: a clip saved paused at 18.8 s came back at frame 0, and the load had written
`h264_1080p60_hap_hap.mov` next to the HAP clip. With prints in the callbacks: `nanogui.deserialize_controls`
(after the generators' `load_state`) calls the callback of **every** control with its saved value, also of the
momentary buttons (value 0): *Restart* stopped every clip (playing ones started over, paused ones sat at 0 s),
*Frame back* / *Frame forward* stepped it, *Convert to HAP* started a conversion of every clip without a copy.
A click gives 1 (the release is filtered in `midicontrolbutton.cpp`).

Fix (`7b4e3184`, `shared:`, `video_module.shio`): those four callbacks return on `v == 0`. Clicks still work
(*Restart* → 0.00, *Frame back* → *Play* off, *Convert to HAP* → "There is a HAP copy already").

### Fix 5: the position display sought every clip four times a second (shared)

Also seen in those prints: the *Position* callback ran every 250 ms for every clip. `update()` shows the position
with `position_ctrl.value(x, false)`, but `shz_slider::set_value` calls its value callback anyway, so the
`false` (no callback) has no effect on a controlslider, and each clip got a seek to where it was (a long-GOP clip
decodes from its key frame each time).

Fix (`4d11e4d1`, `shared:`, `video_module.shio`): a flag skips the callback while `update()` sets the value.
After a load the only seeks left are the two of `deserialize_controls` per clip (counted: before, 4 per second
and clip for as long as the app ran). `controlslider.value(v, false)` ignoring `notify_callback` itself is a
nanogui issue outside the video code and was left alone (it may matter for other scripts that rely on it).

After both fixes, step 7 again: the paused HAP copy is back at 0.71 with Speed −2.15, the clip with sound plays
with *Audio* on and Volume 0.51 (RMS 0.032), no conversion started, no script error.

### Fix 6: no libva ended the process (Linux only)

BtbN's `libavutil` loads `libva.so.2`, `libva-drm.so.2`, `libva-x11.so.2` and `libdrm.so.2` on first use through
implib-gen stubs (`libavcodec` too for `libva.so.2`); a stub that cannot load its library calls `abort()`. Tested
in a user / mount namespace with the libraries covered by an empty file (`unshare -r -m`, as on a system without
`libva2` / `libva-drm2`): `decoder_test` died with `libva-drm.so.2.init.c:122: load_library: Assertion ... failed`
(core dump) at the first VAAPI device. In VibeVJ that is the first video dragged in.

Fix (`62eecb26`, `video_decoder.cpp`, inside `#if defined(__linux__)`): VAAPI is only tried when `libva.so.2`,
`libva-drm.so.2` and `libdrm.so.2` load with `dlopen`; otherwise `cuda` or software. Same test afterwards:
`PASSED (0 failures)`, with the libraries present still `vaapi`. (libva-x11 is not needed: the device is opened
on a DRM render node.)

## Phase 6: everything again

With all fixes (1 - 6) and the macOS shared fixes `e04a1d31`, `fd01b8ba`, `1661ef37`, `c48311f2` cherry-picked:

| Run | Result |
|---|---|
| `decoder_test` 5x (`SHZ_FFMPEG_DIR`), 1x next to `ffmpeg/`, 1x without libva | `PASSED (0 failures)` every time |
| `video_playback.shio`, desktop (cuda) 4x, headless llvmpipe 1x | `ALL PASSED` |
| `video_hardware.shio ~/media` / `random` | `ALL PASSED` / `ALL PASSED`, no `slow` line |
| `stress hap_2160p30.mov 8 8` | 30 of 30 fps, render 144, smooth, CPU 48 % |
| `stress hap_2160p30.mov 8 8 nodxt` | 18.1 fps, render 24.7, DROPS, CPU 393 % |
| `stress h264_1080p60.mp4 8 8` | 60 of 60 fps, render 144, smooth, CPU 32 % |
| `stress hevc_2160p60.mp4 8 8` | 57.1 - 58.3 of 60 fps, render 142, smooth (at the NVDEC limit), CPU 155 % |
| VibeVJ step 7 (save, quit, start) | Position, Speed, Audio, Volume back; no conversion on load |

## Phase 7 (arm64)

Not done: no Raspberry Pi here (#470).

## Open

- Once in 19 desktop runs of `video_playback.shio` (the first run after a rebuild, cuda) the first 720p clip had
  no picture after the test's 500 ms (`valid=0`, no error). Not seen again in the 22 runs since; the decoder
  itself delivers the first NVDEC frame of such a clip in about 20 ms, also with the GPU idle. (#471)
- The FFmpeg mirror release `shizotech/shizoscript3/releases/tag/ffmpeg-9.0.2-lgpl-shared` does not exist yet
  (404); `fetch_ffmpeg.shio` falls back to BtbN, which deletes old builds after a while. (#468)
- `controlslider.value(v, false)` calls the value callback anyway (see fix 5), for every script that uses it (#466).
- `deserialize_controls` runs the callbacks of momentary buttons on every project load (see fix 4); other scripts
  than the video generator may have the same problem, e.g. CueList *Random* (#467).
- Laptops that render on the Intel / AMD GPU with an NVIDIA GPU next to it: by fix 3 they decode with VAAPI on the
  rendering GPU (no dGPU wake-up); not tested here, this machine renders on NVIDIA.

## Recommendation for #457: system FFmpeg or the shipped one (Linux)

**Keep the shipped one first** (the loader's order today: `SHZ_FFMPEG_DIR`, the module folder, its `ffmpeg/`,
then the system path):

- It is the build that was tested here and on Windows (hash-pinned), LGPL, with the `hap` encoder (libsnappy)
  that *Convert to HAP* needs; distribution builds differ (Arch's is GPL, Debian / Ubuntu's FFmpeg 9 may lack
  NVENC / snappy, and their minor versions move under us).
- The only Linux-specific weak point of BtbN's build was the libva abort (fix 6); `cuda` and VAAPI both work with
  it (Arch, glibc 2.44).
- The system FFmpeg stays the fallback when the folder is missing (a distribution package of VibeVJ that does
  not ship FFmpeg could rely on that).

## Phase 8: zero-copy (branch `claude/video-linux-zerocopy`)

Two paths, both inside `#if defined(__linux__)`, both feeding the plane textures of the copy path, so the
NV12 / P010 / planar conversion shader is the same and nothing else changes for GL:

| GL renders on | Decoder | Zero-copy path | Needs |
|---|---|---|---|
| Intel / AMD | VAAPI (on that GPU, fix 3) | `video_vaapi_gl.cpp`: `av_hwframe_map` to DRM PRIME, one EGL image per plane (`EGL_EXT_image_dma_buf_import`, with modifiers), `glEGLImageTargetTexture2DOES`; the frame is held until the next one | EGL contexts: `SHZ_GL_EGL=1` (opt-in for now, `screen.cpp`) |
| NVIDIA | cuda (NVDEC) | `video_cuda_gl.cpp`: plane textures registered with CUDA (`cuGraphicsGLRegisterImage`), one `cuMemcpy2D` per plane on the GPU; the surface goes back at once | nothing (GLX or EGL) |

- EGL, `av_hwframe_map` and libcuda are looked up at run time (no new link dependency, no EGL / CUDA headers).
- A broken import (EGL refuses the dma-buf, CUDA registration fails) switches every player to the copy path for
  the rest of the process, like on Windows; a surface format a path does not take only that clip. The import
  guard of the Windows path watches both. `SHZ_VIDEO_ZERO_COPY=0` forces the copy path, `=1` keeps zero-copy
  under overload.
- Step 1 of the checklist, EGL contexts on their own (`SHZ_GL_EGL=1`, commit `4d5804aa`): `libEGL_nvidia`
  instead of `libGLX_nvidia`, `video_playback.shio` `ALL PASSED`, VibeVJ loads a project with three clips, no error.
- Pitfall found on the way: `build.sh` rebuilds an object only when its `.cpp` is newer, so a changed class
  layout in a header (a new member of `shz_video`) left `widget.cpp` / `context_nano.cpp` with the old one: heap
  corruption at start. Clean rebuilds of `out/obj/nanogui` after every header change here.

### Testing VAAPI zero-copy on this machine

GL renders on the RTX 4080 here, and Mesa on the Intel GPU cannot present through KWin's XWayland (its DRI3
device is the NVIDIA one: `xcb_dri3_pixmap_from_buffer failed`). A headless `gamescope` on the Intel GPU gives an
Xwayland of its own: `gamescope --backend headless --prefer-vk-device 8086:a780 -- …` with
`SHZ_GL_EGL=1 __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json`; `glxinfo` there:
`Mesa Intel(R) Graphics (RPL-S)`. The tests read pixels back, so no visible window is needed. Render loop there:
60 fps (gamescope's headless output).

### Results, Intel UHD 770 (GL and VAAPI on it)

- `video_playback.shio`: `ALL PASSED` with `zero_copy=1` for H.264, HEVC 8 / 10 bit and MJPEG (a planar 4:2:2
  surface), colours, orientation and padded edges right.
- `video_hardware.shio ~/media` check / `random`: `ALL PASSED` with zero-copy, no `slow` line. The copy path in
  the same setup: `ALL PASSED` but 4K60 at 4x only 3.0x (H.264), 3.05x (HEVC), 2.22x (HEVC 10 bit).

| Streams (`stress`, 8 s, render loop 60 fps) | Zero-copy: fps, CPU | Copy: fps, CPU |
|---|---|---|
| 1 x H.264 1080p60 | 60, 2 % | 60, 12 % |
| 4 x H.264 1080p60 | 60, 5 % | 60, 109 % |
| 8 x H.264 1080p60 | min 41 (DROPS), 11 % | min 54 (DROPS), 247 % |
| 8 x HEVC 1080p60 | 60, 13 % | min 40 (DROPS), 237 % |
| 4 x HEVC 10 bit 1080p60 | 60, 7 % | 60, 227 % |
| 1 x H.264 2160p60 | 60, 2 % | 60, 46 % |
| 2 x H.264 2160p60 | 60, 4 % | 60, 130 % |
| 1 x HEVC 2160p60 | 60, 3 % | 60, 47 % |
| 2 x HEVC 2160p60 | 60, 5 % | 60, 146 % |
| 1 x HEVC 10 bit 2160p60 | 60, 4 % | 60, 89 % |

The copy out of the Intel GPU's tiled surfaces is expensive on the CPU; zero-copy takes it to almost nothing.
8 x H.264 1080p60 is beyond what the UHD 770's decoder does in real time either way.

### Results, RTX 4080 (GL and cuda on it, GLX, the default)

- `video_playback.shio` with GLX and with EGL: `ALL PASSED`, `zero_copy=1` for H.264, HEVC 8 / 10 bit, colours
  and edges right. `decoder_test`: `PASSED`.
- `video_hardware.shio ~/media` check: `ALL PASSED`, every cuda clip `cuda zero-copy`, 4K60 at 4x reached; one
  `slow` line for ProRes 422 HQ at 0.25x (0.22x, software decoded, not touched by this). `random`: `ALL PASSED`.
- VibeVJ: info line `h264 1920x1080 60 fps, cuda, zero-copy`, plays, the saved project loads, no error.

Same columns as the Windows "Decoder budget" in `docs/video.md` (render loop 144 fps, 8 s per run):

| Streams | Zero-copy: fps, CPU | Copy: fps, CPU | Windows zero-copy (`docs/video.md`): CPU, or how many streams play without drops |
|---|---|---|---|
| 1 x H.264 1080p60 | 60, 2 % | 60, 4 % | 19 % |
| 4 x H.264 1080p60 | 60, 5 % | 60, 15 % | 45 % |
| 8 x H.264 1080p60 | 60, 7 % | 60, 37 % | 49 % |
| 16 x H.264 1080p60 | 60, 12 % | 60, 70 % | (16: suspended) |
| 20 x H.264 1080p60 | 48.8 (NVDEC 100 %), 18 % | 48.4, 71 % | - |
| 24 x HEVC 1080p60 | 60, 19 % | 59, 119 % | 24 |
| 12 x HEVC 10 bit 1080p60 | 60, 11 % | 60, 112 % | - |
| 16 x HEVC 10 bit 1080p60 | 60, 14 % | 42 (DROPS), 132 % | - |
| 24 x HEVC 10 bit 1080p60 | 60, 19 % | 31 (DROPS), 128 % | 24 |
| 1 x H.264 2160p60 | 60, 2 % | 60, 12 % | 13 % |
| 4 x H.264 2160p60 | 60 (NVDEC 100 %), 6 % | 60, 64 % | 4 |
| 2 x HEVC 2160p60 | 60, 4 % | 60, 33 % | 24 % |
| 8 x HEVC 2160p60 | 60, 12 % | 50 (DROPS), 153 % | 8 |
| 4 x HEVC 10 bit 2160p60 | 60, 6 % | 53 (DROPS), 157 % | - |
| 8 x HEVC 10 bit 2160p60 | 60, 13 % | 22 (DROPS), 161 % | 8 |

- The render loop stays at 144 fps in every zero-copy run. 8 bit is limited by NVDEC either way (H.264: 16 x
  1080p60, 4 x 2160p60); 10 bit, which the copy path could not move (fix 3 / Phase 4), now plays 24 x 1080p60 and
  8 x 2160p60 like Windows zero-copy, at a tenth of the CPU of the copy path.
- Video memory is higher than with the copy path (the queued surfaces stay on the GPU): 8 x HEVC 10 bit 2160p60
  about 7.0 GB of the 16 GB in use (copy: 5.1 GB).

### Open for zero-copy

- EGL contexts are opt-in (`SHZ_GL_EGL=1`), so VAAPI zero-copy is off by default on Intel / AMD (#469). Making EGL the
  default needs a wider test (other drivers, Wayland sessions, the NDI / Syphon-like texture sharing) than this
  machine gives; the NVIDIA path needs no EGL and is on by default.
- AMD (radeonsi VAAPI) not tested here; same code path as Intel (#469).
- The import guard (overload -> copy path) was not triggered in these runs: past the NVDEC limit the render loop
  stayed at 144 fps with zero-copy too.
