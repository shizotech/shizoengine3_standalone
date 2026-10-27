# Video on macOS: test results (#459)

Video playback (#278) and FFmpeg 9 on macOS arm64, tested by the checklist of
[#459](https://github.com/shizotech/shizoscript3_source/issues/459) (rules: #457). Branch
`claude/video-macos-457`, based on `claude/video-phase2-278` at `010c2c19`. Design and the Windows
numbers: `docs/video.md`.

## Machine

| | |
|---|---|
| Mac | MacBook Pro 14" 2023 (Mac14,9), Apple M2 Pro, 16 GB |
| macOS | 26.1 (25B78) |
| Compiler | Apple clang 17.0.0 (clang-1700.0.13.5), libc++ |
| FFmpeg | Homebrew `ffmpeg` 9.0.2_1 (avformat 63.1.102 / avcodec 63.1.102 / avutil 61.1.102 / swscale 10.1.102) |
| FFmpeg for HAP | Homebrew `ffmpeg-full` 9.0.2 (keg-only, has `--enable-libsnappy`), see Phase 2 |
| Display | built-in Liquid Retina XDR 3024x1964, ProMotion (up to 120 Hz) |
| Sound | MacBook Pro speakers (default output) |

## Phase 0: packages

- `brew install ffmpeg` installs 9.0.2. Before, only `ffmpeg@6` (6.1.6) was there; Homebrew unlinks it on the
  install, so `ffmpeg` on the `PATH` is 9.0.2 afterwards.
- **Homebrew's `ffmpeg` has no HAP encoder**: it is built without libsnappy (`ffmpeg -encoders | grep hap`
  prints nothing). HAP *decoding* works (FFmpeg's own decoder), ProRes / DNxHR encoding too. Converting to HAP
  needs `brew install ffmpeg-full` (keg-only, GPL, 47 dependencies) or a shipped FFmpeg with snappy (Phase 7).

## Phase 1: build

`sh shzscript_macos/setup_mac.sh --build`: builds, bundles and tests without an error.

- Every new file compiles with clang / libc++ without an error or a warning: `video_decoder.cpp`,
  `video_convert.cpp`, `video_hap.cpp`, `video_audio.cpp`, `video_audio_device.cpp`, `ffmpeg_runtime.cpp`,
  `video_widget.cpp`, `filebrowser.cpp`, `context_nano.cpp` (and `video_d3d11*.cpp`, which are empty off
  Windows). No fix was needed.
- `otool -L .../nanogui/native/macos_arm64/libshzmodule_nanogui.dylib | grep -i -E "libav|libsw"` prints
  nothing: FFmpeg is only loaded at run time. CoreAudio and AudioToolbox are linked.
- `_testing/run_tests.sh`: 47 ok, 0 FAIL. `smoke_test.sh`: all modules load. prolink: 200 checks, 0 errors.

## Phase 2: headless decoder test

```
clang++ -std=c++20 -stdlib=libc++ -O1 ... _testing/video/decoder_test.cpp ... -o video_decoder_test
video_decoder_test _testing/video/clips
```

| FFmpeg | Result |
|---|---|
| Homebrew `ffmpeg` (found by itself, no `SHZ_FFMPEG_DIR`) | `FAILED (5 failures)`: all of them `This FFmpeg build has no hap encoder` (3 HAP / HAP Q conversions, and "a missing source starts / fails", which converts to HAP too) |
| `SHZ_FFMPEG_DIR=/opt/homebrew/opt/ffmpeg-full/lib` | `PASSED (0 failures)`, 3 runs in a row |

- First line `FFmpeg: avformat 63.1.102 / avcodec 63.1.102 / avutil 61.1.102 / swscale 10.1.102`.
- VideoToolbox is used for `orange_hevc10.mp4` (`p010le`) and `orange_prores4444.mov` (`rgba`), even at 32x32.
  H.264 / MPEG-2 at 32x32 and 64x64 are refused by VideoToolbox (FFmpeg logs `Failed setup for format
  videotoolbox_vld: hwaccel initialisation returned error`) and fall back to the software decoder, as designed.
- A run while the build was going in parallel failed twice with `1x media time follows wall time` (2 frames
  behind after 2.5 s); on an idle machine it never did. A load effect, not a bug.

## Phase 3: GL test

`cd <empty folder> && dist/macos_arm64/data/shz _testing/nanogui/video_playback.shio` (OpenGL 4.1 core).

| FFmpeg | Result |
|---|---|
| `SHZ_FFMPEG_DIR=/opt/homebrew/opt/ffmpeg-full/lib`, with fix `e04a1d31` | `ALL PASSED` (44 ok), 3 runs in a row |
| Homebrew `ffmpeg` | everything up to "scrubbing H.264" ok, then `video_convert: This FFmpeg build has no hap encoder` is thrown and the script stops (no `ALL PASSED`) |

- Every orange clip is right (RGB within 3 of 255,128,0). `hw='videotoolbox'` for all four 720p clips, the
  854x480 HEVC orientation clip, `orange_hevc10.mp4` and `orange_prores4444.mov`; the small H.264 clips are software
  decoded. `zero_copy=0` everywhere (Phase 8).
- **HAP as DXT works**: Apple's GL has `GL_EXT_texture_compression_s3tc`; `counter_hap / hap_chunks / hapalpha / hapq`
  show `DXT 1` and the same frame as FFmpeg's RGBA path.
- Sound: `sound plays at 1x, level 0.09` through the speakers, silent paused and at 2x.
- The runtime error at `g.speed(-1)` (line 326) is the expected warning of an H.264 clip; the next line is
  `ok speed(-1) on H.264 is refused`.

### Fix: `speed(1) turns around` (shared, `e04a1d31`, `_testing/nanogui/video_playback.shio`)

Failed in every run with `2.600000 -> 0.000000`. A trace of the position every 50 ms shows that the player is
right: backwards from frame 25 for 3 s it wraps to 2.6, `speed(1)` turns around there (2.6, 2.7, 2.8, 2.9,
then the loop to 0.0, 0.1, ...). The test waits 0.5 s after turning, which crosses the loop seam from 2.6.
On Windows `std.sleep(50)` overshoots, so the backwards run ends earlier in the clip and the test passed by
chance. Fix: `h.position(1.5)` before turning around, so the 0.5 s forward stay inside the clip.

## Phase 4: real media and measurements

Media of `_testing/video/clips/README.md` ("Real media") made on the Mac: NVENC replaced by `h264_videotoolbox` /
`hevc_videotoolbox` (`-g 120`, 10 bit `-profile:v main10` from `p010le`), the B-frame clip with
`libx264 -preset veryfast -bf 3 -g 250` (VideoToolbox's H.264 encoder writes no B-frames), HAP with `ffmpeg-full`.
5.7 GB in `~/media`. Render loop: **60 fps** (`ctx.fps()` takes the monitor's refresh rate from GLFW; the
built-in ProMotion display reports 60 Hz, once 120).

| Run | Result (after the fixes of Phase 6) |
|---|---|
| `video_hardware.shio ~/media` | `ALL PASSED`; `slow` only at 4x: H.264 2160p60 2.1x, HEVC 2160p60 2.5x, HEVC 10 bit 2160p60 3.3x, ProRes 4444 1080p30 1.9x |
| `video_hardware.shio ~/media random` | `ALL PASSED` |
| `stress hap_2160p30.mov 8 8` | 26.7 - 29.6 fps, render loop 60, 94 % CPU |
| `stress hap_2160p30.mov 8 8 nodxt` | 3.5 fps, render loop 4.6 fps, 521 % |
| `stress h264_1080p60.mp4 8 8` | min 42 / avg 58 of 60 fps, render loop 60, 102 % |

Before the fixes the same runs had: 4 x `FAIL … pause / play`, 3 x `FAIL … expected decoder ''` (ProRes),
one H.264 1080p60 stream at 40 of 60 pictures per second and 60 fps clips with 132 - 176 of 180 pictures in 3 s.

Every 1080p / 2160p H.264 and HEVC (8 and 10 bit) clip goes through VideoToolbox, colours and orientation are right
(`orange_h264_1080p.mp4` 255,126,1), loop seams have no gap above 37 ms. At 1x after the fixes: 60 fps clips 180 of
180 pictures in 3 s, max gap 18 - 19 ms; 30 fps clips 90 of 90, max gap 34 - 36 ms.

### Decoder budget (M2 Pro, render loop 60 fps, copy through system memory)

CPU load of the whole process in percent of one core (12 cores = 1200 %), sampled from outside after 6 s.

| Clip | Streams at 60 fps | Above |
|---|---|---|
| H.264 1080p60 (20 Mbit/s) | 4 (8: avg 58, min 42 fps) | 12: 47 fps, render loop 47; 16: 32 / 32 |
| HEVC 1080p60 8 bit | 8 | 16: 33 fps, render loop 33 |
| HEVC 1080p60 10 bit | below 8 (8: 53 fps) | 16: 21 fps |
| H.264 2160p60 (60 Mbit/s) | 2 | 4: 36 fps, render loop 36 |
| HEVC 2160p60 8 bit | 2 | 4: 34 fps |
| HEVC 2160p60 10 bit | 1 (2: 53 fps) | 4: 23 fps |

| Streams | VideoToolbox (copy) | Software |
|---|---|---|
| 1 x H.264 1080p60 | 27 % | 58 % |
| 4 x H.264 1080p60 | 55 % | 173 % |
| 8 x H.264 1080p60 | 102 % | - |
| 12 x H.264 1080p60 | 134 % | - |
| 8 x HEVC 1080p60 | 105 % | - |
| 1 x H.264 2160p60 | 59 % | - |
| 2 x H.264 2160p60 | 104 % | - |
| 1 x HEVC 2160p60 | 55 % | 180 % |
| 2 x HEVC 2160p60 | 101 % | - |
| 1 x HEVC 10 bit 2160p60 | 74 % | - |

(An empty window at 60 fps is part of these numbers.)

- Unlike Windows (NVDEC is the limit, the render loop stays at its rate), on the Mac the **render loop** goes down
  with the streams: from 12 x 1080p60 / 4 x 2160p60 on, render loop and streams run at the same 21 - 47 fps.
  The copy path (`av_hwframe_transfer_data` of every frame, upload of the planes on the render thread) is the limit;
  that is what zero-copy (Phase 8) removes.
- Intra-only codecs, one stream (percent of one core): HAP 1080p30 16 %, ProRes 422 HQ 1080p30 32 % (VideoToolbox;
  software 73 %), DNxHR HQ 1080p30 58 %; 2160p30: HAP 29 %, ProRes 422 52 % (software 240 %), DNxHR SQ 164 %.
  8 x 1080p30 play smoothly with each of them: HAP 49 %, ProRes 422 HQ 95 %, DNxHR HQ 482 %.
- **Apple Silicon decodes ProRes in hardware**: FFmpeg uses VideoToolbox for every ProRes clip (also 4444 with
  alpha). Backwards, the frame cache and scrubbing work with it (`random` passes). ProRes 4444 at 4x reaches only 1.9x
  through VideoToolbox (software 2.9x, but at 4x the CPU).

HAP as DXT against FFmpeg's RGBA (`nodxt`):

| Streams (`stress`, 8 s) | FFmpeg RGBA (`nodxt`) | DXT |
|---|---|---|
| 4 x HAP 2160p30 | 29.2 fps, render loop 57, 141 % | 30 fps, 60, 62 % |
| 8 x HAP 2160p30 | 3.8 fps, render loop 4.6, 521 % | 29.6 fps (min 26.7), 60, 94 % |
| 16 x HAP 2160p30 | - | 28.9 fps, 59.6, 151 % |
| 16 x HAP 1080p30 | 27.5 fps (min 23.6), 54, 193 % | 29.8 fps, 59.3, 63 % |
| 48 x HAP 1080p30 | - | 29.5 fps (min 28.4), 58.7, 122 % |
| 8 x HAP Q 1080p30 | 30 fps, 60, 261 % | 30 fps, 60, 65 % |

Position control (`random`):

| Clip | Jump (paused) | Scrub, pictures/s | -1x / -2x / -4x, pictures/s |
|---|---|---|---|
| H.264 1080p60 (videotoolbox) | 237 ms (max 430) | 6 | refused |
| H.264 1080p30 B-frames (videotoolbox) | 359 ms (max 868) | 5.5 | refused |
| HEVC 2160p60 (videotoolbox) | 451 ms (max 802) | 1.5 | refused |
| HAP 1080p30 (DXT) | 16 ms | 60 (render rate) | 30 / 60 / 60 |
| HAP Q 1080p30 (DXT) | 16 ms | 60 | 30 / 60 / 60 |
| ProRes 422 HQ 1080p30 (videotoolbox) | 16 ms | 60 | 30 / 60 / 60 |
| DNxHR HQ 1080p30 | 48 ms | 28 | 30 / 30 / 40 |
| HAP 2160p30 (DXT) | 16 ms | 60 | 30 / 60 / 60 |
| ProRes 422 2160p30 (videotoolbox) | 36 ms (max 56) | 59 | 30 / 60 / 60 |
| DNxHR SQ 2160p30 | 115 ms | 9.5 | 15 / 15 / 17 |

Jumps in H.264 / HEVC take 3 - 4 x longer than with NVDEC on Windows (71 / 126 / 122 ms): VideoToolbox decodes the
frames from the key frame (GOP 120) at about 250 fps. The runtime errors `speed: this video cannot play backwards`
in the `random` log are the expected warnings of the "backwards refused" checks.

## Phase 6: fixes

| Commit | File | Cause | Shared |
|---|---|---|---|
| `e04a1d31` | `_testing/nanogui/video_playback.shio` | "speed(1) turns around" crossed the loop seam (Phase 3) | yes |
| `a0b2838b` | `modules/shzmodule_nanogui/ffmpeg_runtime.cpp` (`__APPLE__` list), `shzscript_macos/README_VibeVJ_macOS.md` | Homebrew's `ffmpeg` has no HAP encoder: `/opt/homebrew/opt/ffmpeg-full/lib` is searched first | no (macOS only) |
| `39750c0a` | `modules/shzmodule_nanogui/video_decoder.cpp` | cherry-pick of Linux' `0f332958` (a pass that ends after `seek()`) | yes (from Linux) |
| `fd01b8ba` | `modules/shzmodule_nanogui/video_decoder.cpp` | pause did not hold the picture after the decoder had fallen behind (4K60 at 4x): the clock was held only on ticks without a new frame and ran up to 2 s ahead; `pause()` then showed the frames that were already due for another 0.4 - 2 s | yes |
| `1661ef37` | `_testing/nanogui/video_hardware.shio` | ProRes goes through VideoToolbox on Apple Silicon, the test expected software | yes |
| `c48311f2` | `modules/shzmodule_nanogui/video_decoder.{h,cpp}`, `_testing/video/decoder_test.cpp` | 60 fps on a 60 Hz render loop: the clock starts on a frame time and moves in ticks, so every frame time fell on a tick and jitter dropped every third picture (40 of 60 fps), 30 fps had gaps of 50 ms. Frames are now picked half a tick early (at most half a frame) | yes |

After all fixes: `decoder_test` `PASSED` (3 / 3 runs), `video_playback.shio` `ALL PASSED` (2 / 2, without
`SHZ_FFMPEG_DIR`: the loader finds `ffmpeg-full`), `video_hardware.shio` and `random` `ALL PASSED`.

## Phase 5: VibeVJ

Run by hand: mouse and keyboard driven with `cliclick`, checked on screenshots, the sound by ear at the Mac. Clips in
`VibeVJ/assets/Videos/`: `counter_h264_audio.mp4`, an H.264 1080p30 clip (20 s) and a 4 s cut of it.

| Step | Result |
|---|---|
| 1 drag `.mp4` into the patchview | ok: the preview plays, the info line reads `h264 1920x1080 30 fps, videotoolbox` (on the zero-copy branch: `, zero-copy`) |
| 2 Position / Frame back / forward | ok: Position jumps (picture changes); Frame forward switches Play off and moves one frame; Frame back brings the previous picture back exactly |
| 3 Options › Convert to HAP | ok: the button reads *Cancel convert*, the info line shows `converting to HAP: 46 %`, then `HAP copy ready`, and `h264_1080p30_hap` appears in *Assets* |
| 4 right click in *Assets* | ok: *Convert to HAP*, the line at the bottom shows `Converting to HAP: h264_short.mov 85 %`, then `h264_short_hap` is listed; on a clip with a copy the entry is greyed out (`HAP copy exists: h264_1080p30_hap.mov`) |
| 5 HAP copy, Speed −4..4 | ok: info `hap 1920x1080 30 fps, DXT on the GPU, backwards`; Speed goes to −4.00 and 4.00; at −2.27 the position runs back by 0.11 / s (20 s clip) and wraps from 0.10 to 0.99; at 4 it runs forward by 0.19 / s |
| 6 sound | ok: info line `sound` with Audio on; tone audible and clean (confirmed by ear at the Mac), silent with Play off and at Speed 2, back at Speed 1, quieter at Volume 0.2 |
| 7 save, quit, start | **failed at first**: Speed, Audio, Volume and Play came back, but Position was 0. Fixed with Linux' `7b4e3184` / `4d11e4d1` (cherry-picked as `2be2adc9` / `9f3d831d`); after that Position 0.43 with the right picture comes back too |

Cause of step 7, found with output in the module before the Linux commits were seen: loading a project calls the
callback of every control with its saved value. *Frame back* (0), *Frame forward* (0) and *Restart* (0) acted on
that (step −1, step +1, `stop()`), and `stop()` rewound to 0. On top of that, `controlslider.value(x, false)`
still calls the callback: `shz_midicontrol_slider::set_value` sets the nanogui slider, whose own
`set_value` always calls `notify_value_changed()`. `update()` showing the position therefore issued a real seek to
where the clip already was, 4 times per second while playing (on long-GOP H.264 every one decodes from the key frame).
The Linux fix works around it in the module. The underlying slider behaviour (`midicontrolslider.cpp`) affects every
`value(x, false)` in VibeVJ and is left for a separate issue.

Not video: resizing a generator window by its corner sometimes grabbed the window instead and moved it; once a
window came back empty until it was maximized. VibeVJ also logs "Layout of nanogui.window … did not settle" for the
mod matrix.

## Phase 7: FFmpeg for macOS users (recommendation)

What the tests showed:

- Homebrew's `ffmpeg` is GPL (`--enable-gpl --enable-version3`) and built **without libsnappy**, so *Convert to HAP*
  does not work with it. `ffmpeg-full` has it, but is GPL too and pulls 47 formulae.
- Everything else works with Homebrew's build: VideoToolbox for H.264 / HEVC / ProRes, HAP / DNxHR decoding,
  ProRes / DNxHR encoding, sound.
- When Homebrew's `ffmpeg` moves to 10, the loader no longer finds major 63 there, video is gone until the user
  installs `ffmpeg@9` (which Homebrew does not have yet).

| | (a) keep `brew install ffmpeg` | (b) ship an LGPL FFmpeg 9 (arm64) | (c) `brew install ffmpeg-full` |
|---|---|---|---|
| Convert to HAP | no | yes (`--enable-libsnappy`, BSD) | yes |
| Licence of what users run | GPL, not ours to ship | LGPL v3 like Windows / Linux | GPL |
| User steps | Homebrew + one formula | none | Homebrew + 47 formulae |
| Breaks when Homebrew moves to FFmpeg 10 | yes | no (pinned) | yes |
| Work | none | build in `macos.yml`, cache it, `install_name` `@loader_path`, codesign in `bundle.sh` | none |

**Recommendation: (b)**, with Homebrew kept as the fallback (the loader already searches the module's `ffmpeg/`
folder first, then Homebrew):

- Configure like BtbN's LGPL builds: `--enable-shared --disable-static --disable-gpl --disable-nonfree
  --enable-version3 --enable-videotoolbox --enable-audiotoolbox --enable-libsnappy` (snappy linked statically),
  `--disable-programs --disable-doc`, `--arch=arm64`, minimum macOS as the rest of the bundle.
- Install names `@loader_path/libavutil.61.dylib`, ... so `libavcodec` finds `libswresample` next to it without an
  RPATH (the same reason the loader opens `swresample` first on Linux).
- Build it in `macos.yml` keyed by the FFmpeg version and cache it (`actions/cache`): about 10 macOS runner minutes
  once (100 billed minutes), then nothing; or build it once on this Mac and attach the archive to a release with a
  SHA-256, like `fetch_ffmpeg.shio` does for BtbN's archives (no CI minutes).
- `bundle.sh` copies it into `packages/nanogui/native/macos_arm64/ffmpeg/` with `LICENSE.txt` / `README.txt` and signs
  the dylibs with the rest; it stays out of `bundle_dylibs.py` (nothing links it).

This is a decision for the maintainer (#457 "Things to decide"); nothing of it is built here.

## Phase 8: zero-copy with VideoToolbox (branch `claude/video-macos-zerocopy`)

VideoToolbox frames stay on the GPU (`set_keep_hardware_frames`, as with D3D11 on Windows). On the render thread
`shz_video::import_hardware_frame` binds the Y and UV planes of the frame's CVPixelBuffer IOSurface as rectangle
textures (`CGLTexImageIOSurface2D`, R8 / RG8, or R16 / RG16 for 10 bit). The existing NV12 / P010 shader path samples
them through a `sampler2DRect` variant (`u_rect`, texture units 4 and 5). The last two CVPixelBuffers stay retained
until GL is surely done with them. Formats that are not two-plane (ProRes 4444) end zero-copy for that file and are
copied as before. `SHZ_VIDEO_ZERO_COPY=0` forces the copy, `=1` keeps zero-copy under load (as on Windows).

Tests with zero-copy: `decoder_test` 3 / 3 `PASSED`, `video_playback.shio` 2 / 2 `ALL PASSED` (all VideoToolbox clips
`zero_copy=1`, colours, 10 bit, full range, orientation and edges right), `video_hardware.shio` check and random
`ALL PASSED`. At 4x: H.264 2160p60 2.4x (copy 2.1x), HEVC 2160p60 2.8x (2.5x), HEVC 10 bit 2160p60 4x (3.3x).

| Streams | Copy: stream fps / render loop, CPU | Zero-copy: stream fps / render loop, CPU |
|---|---|---|
| 1 x H.264 1080p60 | 60 / 60, 27 % | 60 / 60, 17 % |
| 4 x H.264 1080p60 | 60 / 60, 55 % | 60 / 60, 28 % |
| 8 x H.264 1080p60 | avg 58 (min 42) / 60, 102 % | avg 58 (min 40) / 60, 38 % |
| 12 x H.264 1080p60 | 47 / 47, 134 % | avg 59 (min 51) / 60, 40 % |
| 16 x H.264 1080p60 | 32 / 32, 151 % | avg 59 (min 46) / 60, 52 % |
| 8 x HEVC 1080p60 | 60 / 60, 105 % | 60 / 60, 33 % |
| 16 x HEVC 1080p60 | 33 / 33, 158 % | 60 / 60, 53 % |
| 32 x HEVC 1080p60 | - | 40 / 60, 44 % |
| 8 x HEVC 10 bit 1080p60 | 53 / 53, 138 % | 60 / 60, 37 % |
| 16 x HEVC 10 bit 1080p60 | 21 / 21, 191 % | 60 / 60, 57 % |
| 1 / 2 / 4 x H.264 2160p60 | 60, 60, 36 fps; 59 / 104 / 137 % | 60, 60, 60 fps; 22 / 28 / 32 % |
| 1 / 2 / 4 x HEVC 2160p60 | 60, 60, 34 fps; 55 / 101 / 137 % | 60, 60, 60 fps; 23 / 29 / 37 % |
| 8 x HEVC 2160p60 | - | 45 / 60, 32 % |
| 1 / 2 / 4 x HEVC 10 bit 2160p60 | 60, 53, 23 fps; 74 / 129 / 174 % | 60, 60, 60 fps; 24 / 29 / 35 % |
| 8 x HEVC 10 bit 2160p60 | - | 60 / 60, 54 % |
| 1 x ProRes 422 HQ 1080p30 | 30 / 60, 32 % | 30 / 60, 17 % |
| 8 x ProRes 422 HQ 1080p30 | 30 / 60, 95 % | 30 / 60, 39 % |
| 1 x ProRes 422 2160p30 | 30 / 60, 52 % | 30 / 60, 24 % |

- With zero-copy the render loop stays at 60 fps in every run. The limit is now the decoder (Apple's media engine),
  as with NVDEC on Windows. CPU load drops to a third or a quarter.
- The import guard (it suspends zero-copy when importing frames stalls the render loop) is on as on Windows. In
  these runs it did not suspend it: at the end of every run the first stream still reported `zero-copy`.
