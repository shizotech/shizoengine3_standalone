FFmpeg 9.0.2 for nanogui.video (windows_x64)

These are the shared libraries of an LGPL build of FFmpeg, unchanged:
  avutil-61.dll, swresample-7.dll, swscale-10.dll, avcodec-63.dll, avformat-63.dll, avfilter-12.dll, avdevice-63.dll
Build:   ffmpeg-n9.0.2-28-g669f5ab083-win64-lgpl-shared-9.0.zip (BtbN/FFmpeg-Builds, release autobuild-2026-10-17-20-51)
SHA-256: 00ab3bc8fe02554bd0fffac9968bba498d1ab7e899a4871b85fbba828a50bfcc
Source:  https://github.com/FFmpeg/FFmpeg/tree/669f5ab083
         build scripts: https://github.com/BtbN/FFmpeg-Builds
Mirror:  https://github.com/shizotech/shizoscript3/releases/download/ffmpeg-9.0.2-lgpl-shared/

FFmpeg is licensed under the GNU Lesser General Public License version 3
(the build uses --enable-version3), see LICENSE.txt and https://ffmpeg.org/legal.html.

You may replace these files with your own build of FFmpeg, as long as it has the
same major versions (the numbers in the file names). nanogui loads them at run
time; the environment variable SHZ_FFMPEG_DIR points it at another folder.
