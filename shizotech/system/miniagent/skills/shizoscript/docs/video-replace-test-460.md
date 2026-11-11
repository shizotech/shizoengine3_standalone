# Replace the original (#460): test on Windows

[#460](https://github.com/shizotech/shizoscript3_source/issues/460) "Convert settings ... optionally replace the
original". Branch `claude/460-replace-original`.

Built and checked on Linux in a container (g++, Mesa llvmpipe under Xvfb, FFmpeg 9.0.2): `decoder_test`,
`_testing/nanogui/video_replace.shio`, `smoke.py replace`, the *Assets* menu by hand. What Linux cannot show: Windows
refuses to rename or remove a file that is open (Linux does not care), Windows paths (drive letters, `\`) in the new
path code, NTFS hard links, and a USB stick with exFAT (no hard links: the original is moved instead).

**C++ changed** (`modules/shzmodule_nanogui`: `video_convert.cpp/.h`, `video_decoder.cpp`, `context_nano.cpp`,
`video_widget.cpp`): nanogui has to be built. Scripts changed too.

Write the results into *Results* at the end of this file, or as a comment on the PR.

---

## What changed

- `nanogui.video_convert(src, dst, format, size, check)`: with `check` the finished file is read again before it is
  renamed (frames, length, first and last frame).
- `nanogui.video_replace(src, converted)`: `_originals/` next to the file, the original kept there by a hard link (or
  moved), the result renamed to `<name>.mov`, the old name removed. `nanogui.video_replace_path(src)`.
- `video_convert.shio` `video_replace_finish`: the generators of the project that play the file close it, the swap,
  they open the new file; `_originals/replaced.json`; `asset_resolver.shio` reads it for old projects.
- *Assets* right click: *Result* › *Replace the original*; video generator *Options* › *Convert result*.
- Jumps in long-GOP H.264 / HEVC skip the non-reference frames before the target (#465 point 5).

## Checklist (Windows)

1. Build (`_testing/windows_app/build.ps1`), `testcopy.ps1 -Name replace`, FFmpeg 9 in the copy.
2. `video_decoder_test.exe _testing/video/clips` (build line in `decoder_test.cpp`): `PASSED`. The part
   "replace the original" runs in `%TEMP%` (NTFS: `linked` hard links).
3. `shz _testing/nanogui/video_replace.shio`: `ALL PASSED`. Its stand-in generators hold the file open in a video
   widget while the swap runs: on Windows this is the real test that they let go of it.
4. In the app: copy a few clips (an `.mp4` H.264, a `.mov` ProRes) into a folder under `assets`. Drag the `.mp4` into a
   Patchview twice and onto the timeline. Let the clips play.
   - Right click the `.mp4` in *Assets* › *Result* › *Replace the original* › *Replace with HAP*. The line at the
     bottom says "clip.mp4 replaced by clip.mov, the original is _originals/clip.mp4 (3 clips updated)".
   - The three clips play on, at about the place where they were; *Speed* goes below 0 now.
   - Explorer: `clip.mov` next to `_originals\clip.mp4` (the same size as before), `_originals\replaced.json`; no
     `.replacing` file left.
   - Save the project, close VibeVJ, start it again: the project plays `clip.mov`.
5. A project saved **before** the replacement (save one with the `.mp4` first, replace, load the old one): it loads
   `clip.mov` ("Asset replaced: ... is now ..." in the console).
6. Folder: right click the folder › *Replace N videos here with HAP*: the ProRes `.mov` keeps its name, its original
   goes to `_originals\other.mov` (or `other (2).mov` when that is taken).
7. Locked file: open the `.mp4` in another program that locks it (e.g. a video editor), replace it in VibeVJ: the
   line says it failed ("Could not move the original away (is it open somewhere?)"), `clip.mp4` is still there and
   unchanged, no `clip.mov`, nothing in `_originals` but what was there before.
8. A USB stick with exFAT (or FAT32): replace a clip there. It works; `_originals\clip.mp4` is the original (moved,
   no hard link).
9. Cancel: a long clip (generate one, `_testing/video/clips/README.md`), *Replace with HAP* in the generator, click
   the button again while it converts: the clip is untouched, no `.replacing` / `.replacing.part` left.
10. A path with a drive letter and spaces (`D:\VJ clips\my clip.mp4` linked into a project from outside `assets`):
    replace it from the video generator: the generator plays `D:\VJ clips\my clip.mov`.

## Results

(machine, Windows version, file systems, what passed, what not)
