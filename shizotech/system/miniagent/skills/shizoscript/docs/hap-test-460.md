# HAP Q Alpha and HAP R on the GPU (#460): test on Windows and macOS

[#460](https://github.com/shizotech/shizoscript3_source/issues/460) point 12: "HAP Q Alpha and HAP R as DXT. These
variants still go through FFmpeg's CPU decode. HAP Q Alpha = two textures (YCoCg DXT5 + alpha RGTC1), HAP R = BPTC
(BC7)." Branch `claude/460-hap-alpha-bptc`. Built and checked on Linux in a container (g++, Mesa llvmpipe under Xvfb,
FFmpeg 9 of the release snapshot). llvmpipe has S3TC, RGTC and BPTC, so every path ran; what it cannot show is how
real drivers (NVIDIA, AMD, Intel, Apple) take RGTC / BPTC uploads, and whether macOS has BPTC at all.

**C++ changed** (`modules/shzmodule_nanogui`): nanogui has to be built. Scripts did not change (tests and docs only).

Write the results into *Results* at the end of this file, or as a comment on the PR.

---

## What changed

| File | What |
|---|---|
| `video_hap.cpp/.h` | Multiple-image frames (section `0x0D`): HAP Q Alpha unpacks into two textures (YCoCg DXT5, then RGTC1 alpha). New formats `ycocg_dxt5_alpha_rgtc1`, `rgba_bptc` (HAP R), `alpha_rgtc1` (HAP Alpha-Only). A BC7 decoder for the CPU (`decode_bc7`, all 8 modes, threads for big pictures) |
| `video_decoder.cpp/.h` | HAP R (`Hap7`, no FFmpeg decoder): opened with FFmpeg's HAP decoder as a stand-in context, every frame unpacked here; BC7 passed through (`set_bptc_passthrough`) or decoded to RGBA on the decoder thread. HAP Q Alpha frames carry the alpha texture in `data[1]`. Seeks round the time stamp down (a MOV with time scale = fps showed the next frame) |
| `video_widget.cpp` | Uploads `GL_COMPRESSED_RED_RGTC1` (HAP Q Alpha plane 1, HAP Alpha-Only with a gray swizzle) and `GL_COMPRESSED_RGBA_BPTC_UNORM` (HAP R); BPTC only with OpenGL 4.2 or `GL_ARB_texture_compression_bptc`, else the decoder decodes HAP R on the CPU. The YCoCg shader mode takes the alpha of plane 1 |
| `video_convert.cpp`, `context_nano.cpp` | `video_probe` names `hap_r` and `hap_alpha_only` |

| Variant | Before | Now |
|---|---|---|
| HAP Q Alpha (`HapM`) | FFmpeg, RGBA on the CPU | DXT5 + RGTC1 on the GPU |
| HAP R (`Hap7`) | did not open ("No decoder for the video stream") | BPTC on the GPU, else BC7 on the CPU |
| HAP Alpha-Only (`HapA`) | FFmpeg, gray on the CPU | RGTC1 on the GPU (gray) |
| HAP, HAP Alpha, HAP Q | DXT on the GPU | unchanged |

## Checked on Linux

- `_testing/video/decoder_test.cpp`: PASSED (new: HAP sections, BC7 blocks of mode 5 / 6 / reserved, a 1022x1021
  picture decoded in stripes, the three new clips frame 7 passed through vs. decoded on the CPU: HAP Q Alpha largest
  difference 2 against FFmpeg, HAP R 0, HAP Alpha-Only 0; `video_probe` of them).
- `_testing/nanogui/video_playback.shio`: the three new lines `ok` (whole 64x64 picture with alpha, GPU vs. CPU:
  HAP Q Alpha 3, HAP R 0 = llvmpipe's BPTC decode equals the CPU BC7 decoder byte for byte over random blocks of every
  mode, HAP Alpha-Only 1). ALL PASSED (under heavy load of the machine `speed(-1) plays backwards` failed in some
  runs, on main too: it measures wall time). `video_loop_points.shio`, `video_convert_formats.shio`: ALL PASSED.
- macOS check: the nanogui module and `decoder_test.cpp` built with clang + libc++ (configure of
  `check_libcxx_linux.sh`, target `shzmodule_nanogui`). MSVC check: `check_msvc_linux.sh --only nanogui`, 120 files ok.

## Phase 0: get the branch

- Windows: `& .\_testing\windows_app\build.ps1 -Only nanogui`, then
  `& .\_testing\windows_app\testcopy.ps1 -Name pr460hap -Binaries <build out>`.
- macOS: `sh shzscript_macos/setup_mac.sh --build`.

## Phase 1: automatic tests (no person needed)

- [ ] `decoder_test` (build line at the top of `_testing/video/decoder_test.cpp`): `PASSED`.
- [ ] `video_playback.shio`: the lines `counter_hapq_alpha.mov`, `counter_hapr.mov`, `counter_hap_alpha_only.mov`
      are `ok`. Write down for `counter_hapr.mov` whether it says `compressed textures 1` (BPTC on this GPU) and the
      largest difference. On macOS a `note ... no BPTC textures here` line is allowed (the test then compares the CPU
      decode with itself); on Windows it must be `compressed textures 1` with difference 0. A difference above 0 there
      means the driver's BC7 decode and `decode_bc7` disagree: report the number.

## Phase 2: real clips and load (GPU)

Make big clips: `python3 _testing/video/clips/make_hap_variants.py <folder> 1920 1080 60` (about 2 min, about 190 MB:
`counter_hapq_alpha_1920x1080.mov`, `counter_hapr_1920x1080.mov`, `counter_hap_alpha_only_1920x1080.mov`). Real HAP R /
HAP Q Alpha files from Adobe's Hap exporter or TouchDesigner are better where there are some.

- [ ] In VibeVJ, a video generator with each clip: it plays, the info line says `DXT on the GPU` (HAP R on a Mac
      without BPTC: a software line), the top half counts up in gray, the transparent parts show what is behind
      (alpha: top left gets more opaque frame by frame, bottom left 25 %).
- [ ] *Speed* -1 and scrubbing work with each (every frame stands on its own).
- [ ] 8 clips of `counter_hapr_1920x1080.mov` at once: frame rate of the render loop (Windows: should stay at the
      monitor rate). On a Mac without BPTC: how many 1080p HAP R clips keep 30 fps on the CPU decoder.
- [ ] Windows on Intel graphics if there is one: HAP R plays (BPTC), no errors in the log.

## Results

### Windows (date)

Machine, GPU, driver. Phase 1 / 2: pass / fail, numbers, screenshots of anything wrong.

### macOS (date)

Machine. Whether `counter_hapr.mov` went through BPTC. Phase 1 / 2: pass / fail, numbers.
