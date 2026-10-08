# Video playback (nanogui.video)

Hardware-accelerated video playback for VibeVJ, tracked in
[#278](https://github.com/shizotech/shizoscript3_source/issues/278).

## Decision (Phase 0)

**FFmpeg (libavformat / libavcodec), LGPL build, loaded at runtime.**

- One code path for every platform and container, with the platform GPU decoder
  behind it: D3D11VA / CUDA / DXVA2 on Windows, VAAPI / CUDA / VDPAU on Linux,
  VideoToolbox on macOS. When no GPU decoder is available or it refuses a
  stream (unsupported profile, decoder session limit, missing driver), FFmpeg's
  software decoder takes over.
- HAP / HAP Alpha, ProRes and DNxHR decoders come for free, which Phase 2 needs.
- The libraries are opened with `LoadLibrary` / `dlopen` like the NDI run-time
  (`ffmpeg_runtime.cpp`, modelled on `ndi_sdk.cpp`). Nothing is linked at build
  time, the module loads without FFmpeg, and the LGPL libraries ship unmodified
  as separate, replaceable files. Headers: `shzmodule_nanogui/libraries/ffmpeg/`
  (see its README for versions, file names and search paths).

### FFmpeg on Windows

Tested with the BtbN build `ffmpeg-n6.1.3-win64-lgpl-shared-6.1.zip` (release
`autobuild-2025-08-31-13-00`, the last 6.1 build of
[BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds/releases)). It is
configured without `--enable-gpl` / `--enable-nonfree`, but with
`--enable-version3`, so it is **LGPL v3**. Needed are `avformat-60.dll`,
`avcodec-60.dll`, `avutil-58.dll`, `swscale-7.dll` and `swresample-4.dll`
(78 MB together), next to `shzmodule_nanogui.dll`, in its `ffmpeg\` folder, or
in the folder `SHZ_FFMPEG_DIR` points to. `nanogui.video_available()` and
`nanogui.video_version()` tell whether they were found. Shipping them in the
bundles is still open (#263).

## Architecture

```
file ──> worker thread (video_decoder.cpp)                 render thread (video_widget.cpp)
         demux + decode (GPU when possible)                  clock: wall time * speed
         queue of 4 frames  ─────────────────────────────>   pick due frame (drop / hold)

         software frame, or GPU surface copied to            upload planes (R8/RG8/R16/RG16/RGBA8)
         system memory (NV12/P010, av_hwframe_transfer)       YUV -> RGB shader pass into output texture

         Windows zero-copy: D3D11VA surface stays            D3D11 video processor -> BGRA texture
         on the GPU (video_d3d11.cpp)                        shared with GL (WGL_NV_DX_interop), blit into output texture
```

- `video_decoder.*` has no GL or script dependencies (tested headless by
  `_testing/video/decoder_test.cpp`).
- Frames go to the GPU as their native planes; colour conversion (BT.601 /
  709 / 2020, limited / full range, 8-16 bit, alpha plane) runs in a shader, so
  the CPU never converts pixels. Formats the shader does not know are converted
  to RGBA with swscale on the worker thread.
- The output texture keeps its object for the lifetime of the widget and is in
  GL orientation (row 0 = bottom), like every shader output.
- Script callbacks (`frame_event`) run in `draw_offscreen`, never on the decoder
  thread and never inside another shader's render pass.
- GPU decoder devices are shared per type by all players, so many clips do not
  open many decoder sessions.
- A GPU decoder that refuses a stream is tried once per file. The stream is
  then opened again for software decoding on all cores (a context set up for a
  GPU decoder decodes on one thread).

## Zero-copy

"No CPU readback path" from the issue: a frame decoded on the GPU must not pass
through system memory.

| Platform | State | Path |
|---|---|---|
| Windows | done, tested on NVIDIA (full path) and Intel (Direct3D half) | D3D11VA surface -> `ID3D11VideoProcessor` -> BGRA texture -> `WGL_NV_DX_interop` |
| Linux | open | VAAPI surface -> DRM PRIME -> `EGL_EXT_image_dma_buf_import` (needs an EGL context, GLFW currently uses GLX) |
| macOS | open | VideoToolbox `CVPixelBuffer` -> IOSurface -> `CGLTexImageIOSurface2D` (pairs with the Syphon work in #264) |

Where there is no zero-copy path, or it does not work on a machine, the GPU
surface is copied to system memory (`av_hwframe_transfer_data`, NV12 = 1.5
bytes per pixel) and uploaded again. The interface between the two is
`shz_video_decoder::to_uploadable()` (decoder thread: keep the surface or copy
it) and `shz_video::upload_frame()` (render thread: import the surface, or
upload planes). `video.zero_copy()` and the info line of the VibeVJ generator
("d3d11va, zero-copy") tell which one is in use.

### Windows (D3D11VA -> OpenGL)

- `shz_video_d3d11::create_device()` creates the D3D11 device
  (`D3D11_CREATE_DEVICE_VIDEO_SUPPORT`, multithread protected) and hands it to
  FFmpeg (`av_hwdevice_ctx_alloc` / `AVD3D11VADeviceContext` /
  `av_hwdevice_ctx_init`). The decoder, the video processor and the interop
  have to share one device, and it has to sit on the adapter OpenGL renders
  with, so the widget passes the vendor of the GL renderer (laptops with two
  GPUs: the default adapter is not always the GL one).
- FFmpeg decodes into one NV12 / P010 texture array (`frame->data[0]` =
  texture, `data[1]` = slice). `shz_video_d3d11::converter` converts the slice
  with the D3D11 video processor into a BGRA texture: colour matrix and range
  from the frame (`VideoProcessorSetStreamColorSpace1`, legacy call as
  fallback), source rectangle = picture (decoder surfaces are padded), no
  scaling, deinterlacing or driver "enhancements". If a driver does not take
  a slice of the decoder's array as input, the slice is first copied into a
  texture of its own (`CopySubresourceRegion`, still on the GPU).
- The picture is then copied (`CopyResource`) into a second BGRA texture, and
  that one is registered with OpenGL (`wglDXRegisterObjectNV`, entry points
  loaded with Spout's `loadInteropExtensions()`). The render thread locks it,
  blits it into the widget's output texture (flip to GL orientation, alpha 1)
  and unlocks it.
- The decoder gets `extra_hw_frames` for the surfaces that wait in the frame
  queue.

Things that were not obvious:

- **The video processor target must not be the texture shared with GL.**
  Sharing it works for playback, but the NVIDIA driver (617.14, RTX 4080)
  crashes in `nvwgf2umx.dll` when a texture that was a video processor target
  is unregistered from the interop (`wglDXUnregisterObjectNV`), i.e. on every
  close or size change. A texture that only was a `CopyResource` destination
  is fine, hence the second texture.
- **The hand-over waits for the decoder's device.** `wglDXLockObjectsNV`, the
  device lock and the buffer swap wait for work queued on the D3D11 device.
  Below the decoder's capacity that is about 0.3 ms per frame. With more
  streams than the GPU decoder can decode in real time the render loop itself
  stalls (16 x 1080p60 H.264: 144 -> 15 fps), where the copy path only slows
  the clips down, because there the decoder threads do the waiting. So the
  widget watches the render loop: when it stays below half its target rate
  for 1.5 s while frame hand-overs take more than 1 ms, zero-copy is suspended
  for all players (they copy through system memory), and it comes back when a
  clip is closed or paused. If the loop does not recover within 2 s, video was
  not the reason and zero-copy returns.
- For comparing the paths: `SHZ_VIDEO_ZERO_COPY=0` forces the copy path,
  `SHZ_VIDEO_ZERO_COPY=1` keeps zero-copy even when overloaded,
  `SHZ_VIDEO_D3D11_COPY=1` forces the surface copy in front of the video
  processor.

## Script API

The player is a widget (it needs the render loop and draws a preview), created
like `image` / `ndi_receiver`:

```
v = area.video(path);           // check v.is_open() / v.error()
v.play(); v.pause(); v.stop();  // stop = pause + back to the first frame
v.playing(true);
v.speed(1.0);                   // 0..4, negative is an error until Phase 2
v.loop(true);
v.position();                   // seconds of the frame on screen (read-only in Phase 1)
v.duration(); v.fps(); v.width(); v.height();
v.codec(); v.container(); v.has_alpha(); v.intra_only();
v.hw_decoder();                 // "d3d11va", "vaapi", "videotoolbox", "cuda", ... or "" for software
v.zero_copy();                  // true while frames reach the texture without a copy through system memory
v.hardware(false);              // force software decoding (reopens)
v.seekable();                   // false until Phase 2, so UIs can grey out position control
v.texture();                    // same texture object for the lifetime of the widget
v.frame_event([](){ ... });     // after a new frame was uploaded (render loop)
v.flip_y(true);
v.save() / v.load(json);
nanogui.video_available(); nanogui.video_version(); nanogui.video_error();
```

`output.value(v)` / shader inputs work like with `image`, since the widget is a
`shz_shader_input_source`.

## VibeVJ

`engine/generators/extensions/video/` loads `.mp4 .mov .m4v .mkv .webm .avi
.mxf .mpg .mpeg .ts .wmv` (mapped in `generatoritem.shio`): preview, OUT,
Play, Restart, Speed, Loop, a Position output (0..1), size, Flip Y, HW Decode,
an info line (codec, size, fps, decoder) and the VideoRouter. ACT off pauses
decoding. State saves play / speed / loop / flip / hardware / position.

## Tests

- `_testing/video/decoder_test.cpp`: headless decoder core (timing at 1x / 2x,
  pause, restart, loop on / off, pixel layout table). On Windows also the
  Direct3D half of the zero-copy path: GPU decode, video processor, pixels read
  back from the BGRA texture, per adapter (`video_decoder_test.exe <clips>
  nvidia|amd|intel`). Build lines in the file.
- `_testing/nanogui/video_playback.shio`: the full widget through GL, one
  solid-colour clip per pixel path (`_testing/video/clips/README.md`), checks
  the RGB values a shader reads from `texture()`, orientation, `flip_y`,
  transport, `frame_event`, texture identity, save. The 720p / 480p clips go
  through the GPU decoder where there is one. Linux headless:
  `LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a shz _testing/nanogui/video_playback.shio`.
- `_testing/nanogui/video_hardware.shio <media_dir>`: real 1080p / 4K media
  (H.264, HEVC 8 / 10 bit, HAP, ProRes, DNxHR; commands in the clips README):
  decoder in use, colours and padded surfaces through the GPU decoder, speed
  0.25x..4x, pause, loop, and a `stress` mode that plays N instances of a clip
  for the decoder budget.

- VibeVJ by hand (real mouse input, RTX 4080): `.mp4` dragged into a Patchview
  and `.mov` into a Clipview cell; preview; OUT linked to a shader input;
  VideoRouter picked in LEDMapper; Play, Restart, Speed (2.51x measured 2.53x,
  4x measured 4.03x), Loop on / off (stops on the last frame), Flip Y, HW Decode
  (info line switches between "software" and "d3d11va, zero-copy"); ACT off
  pauses; save, exit, start: Speed, Loop, the options, the router and the links
  are back. User page: `_shizoengine3/wiki/Video.md`.

State: Linux passes with software decoding (Mesa llvmpipe, FFmpeg 6.1).
Windows 11, MSVC (VS Build Tools v145), FFmpeg n6.1.3, RTX 4080 (driver
617.14): all three pass, D3D11VA with zero-copy. Intel UHD 770 (driver
32.0.101.7088): `decoder_test` passes (decode + video processor, also with the
forced surface copy); the GL half was not run there, GL uses the NVIDIA card on
that machine. Not tested: AMD, VAAPI, VideoToolbox, CUDA.

## Decoder budget (Windows, RTX 4080 + i5-13600K, render loop 144 fps)

How many instances of one 60 fps clip play without dropped frames (every stream
at 60 fps, render loop at 144 fps), and the CPU load of the whole process in
percent of one core (20 threads = 2000 %).

| Clip | Copy through system memory | Zero-copy |
|---|---|---|
| H.264 1080p60 (20 Mbit/s) | 12 (16: 48 fps) | 14 (16: suspended) |
| HEVC 1080p60 8 bit | 8 (more not measured) | 24 (32: suspended) |
| HEVC 1080p60 10 bit | below 8 (8: 55 fps) | 24 |
| H.264 2160p60 (60 Mbit/s) | 2 (4: 46 fps) | 4 (5: suspended) |
| HEVC 2160p60 8 bit | 2 (4: 52 fps) | 8 (10: suspended) |
| HEVC 2160p60 10 bit | 1 (2: 55 fps) | 8 |

| Streams | Copy | Zero-copy |
|---|---|---|
| 1 x H.264 1080p60 | 33 % | 19 % |
| 4 x H.264 1080p60 | 98 % | 45 % |
| 8 x H.264 1080p60 | 156 % | 49 % |
| 12 x H.264 1080p60 | 170 % | 60 - 84 % |
| 8 x HEVC 1080p60 | 133 % | 41 % |
| 1 x H.264 2160p60 | 81 % | 13 % |
| 2 x H.264 2160p60 | 133 % | 25 % |
| 1 x HEVC 2160p60 | 58 % | 17 % |
| 2 x HEVC 2160p60 | 123 % | 24 % |

(An empty window at 144 fps is part of these numbers. Software decoding for
comparison: 1 x H.264 1080p60 49 %, 4 x 187 %, 1 x HEVC 2160p60 168 %.)

- The limit is the GPU's video decoder (NVDEC: "decoder" utilisation in
  `nvidia-smi` at 85 - 100 %), not the CPU. Beyond it zero-copy is suspended,
  the render loop stays at its rate and the clips slow down (they do not skip:
  H.264 / HEVC cannot drop reference frames). Suspending takes about 3.5 s
  after too many clips were opened at once; in that time the render loop
  stutters.
- Video memory per stream (`nvidia-smi`): 2160p about 480 MB with zero-copy
  and 330 MB with the copy path, 1080p about 125 MB and 80 MB. The difference
  are the six decoder surfaces for the frame queue and the two BGRA textures.
  Eight 4K streams take close to 4 GB.
- Speed: every GPU decoded clip reaches 4x (4K60 H.264 only with zero-copy, the
  copy path reached 2.4x). From 2x on non-reference frames are skipped.
- Intra-only codecs are decoded on the CPU (one 1080p30 stream, percent of
  one core): HAP 18 %, ProRes 422 HQ 70 %, DNxHR HQ 59 %; 2160p30: HAP 71 %,
  ProRes 422 186 %, DNxHR SQ 132 %. 8 x 1080p30 play smoothly with each of
  them (HAP 96 %, DNxHR HQ 382 %, ProRes 422 HQ 513 %). HAP is decoded to RGBA
  by FFmpeg and uploaded uncompressed, which costs memory bandwidth: 4 x HAP
  2160p30 bring the render loop down to 22 fps (2 x: 129 fps). Uploading the
  DXT data as it is belongs to Phase 2.
- NVIDIA consumer cards limit the number of *encoder* sessions; a decoder
  session limit did not show up to 32 streams (the D3D11 device is shared).

## Found on the way (not part of the video code)

- Dropping any file into a view logs `JSON parse error at byte 1 of <file size>`:
  something reads the whole file and tries to parse it as JSON (a PNG five
  times, a video once). With large videos that costs time and memory on every
  drop. The caller was not found in the scripts.
- A double click on a file in the asset browser opens it as text in a code box
  (`assetbrowser.shio`), also a video of several hundred MB.
- VibeVJ crashes on exit in the static destructor of `shz_mididevice_handler`
  (access violation at DLL unload), also with an empty project.

## Open questions (from #278)

- Audio: video stays silent; carrying audio into `audio_process.shio` needs a decision.
- Sidecar index files for Phase 2: next to the media or in a project cache.
- AMD: nothing was tested on AMD hardware. The fallbacks are in place
  (surface copy in front of the video processor, copy through system memory
  when the interop fails), and the first run should be
  `video_decoder_test.exe <clips> amd` followed by `video_playback.shio`.

## Phase 2 (next)

HAP / HAP Alpha first (DNxHR, ProRes as fallbacks): frame index at open,
`position(t)` / `seek` / `step_frames(n)`, negative speed, LRU cache of decoded
frames in both directions, and a "convert to VJ format" job (ffmpeg CLI) in the
asset browser. HAP frames are DXT textures, so uploading them compressed
(skipping FFmpeg's CPU DXT decode) is part of that work.
