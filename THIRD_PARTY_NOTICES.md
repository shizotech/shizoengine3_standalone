# Third-party notices

VibeVJ (the scripts in `VibeVJ/`, the ShizoScript interpreter `VibeVJ.exe` / `VibeVJ.out` / `VibeVJ.app` and the
standard library with its modules in `shizotech/`) is licensed under the Non-Commercial Software License v1.1
(`LICENSE.md`). It contains or ships the third-party components listed here. They are **not** covered by that license
(section 11 of `LICENSE.md`): each one is under its own license, which takes precedence for that component.

Paths are relative to the VibeVJ folder. `<platform>` is `windows_x64`, `linux_x64`, `linux_arm64` or `macos_arm64`;
`shizotech/packages/<package>/native/<platform>/` holds the native files of a package.

## FFmpeg

- **What:** the libraries `avcodec`, `avformat`, `avutil`, `swscale`, `swresample`, `avfilter` and `avdevice` of
  FFmpeg 9.0.2 (source commit `669f5ab083`, release/9.0 branch), used by video playback, conversion and cameras.
- **License:** GNU Lesser General Public License version 3 (LGPL-3.0-or-later; built with `--enable-version3`, without
  `--enable-gpl` and `--enable-nonfree`). The license text is `LICENSE.txt` next to the libraries,
  `README.txt` there names the build, its SHA-256 and the source. See also <https://ffmpeg.org/legal.html>.
- **Where:** `shizotech/packages/nanogui/native/<platform>/ffmpeg/` (`*.dll`, `*.so.*` or `*.dylib`).
- **Linking:** dynamic. The nanogui module loads the libraries at run time (`LoadLibrary` / `dlopen`) and contains no
  FFmpeg code.
- **Source:** Windows and Linux use the unmodified LGPL shared builds of
  [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds) (`ffmpeg-n9.0.2-28-g669f5ab083-<target>-lgpl-shared-9.0`).
  These builds link some external codec libraries into the FFmpeg files; the BtbN build scripts list them with their
  versions. macOS uses an LGPL v3 build of the same, unmodified FFmpeg source with VideoToolbox / AudioToolbox and
  [Snappy](https://github.com/google/snappy) 1.2.2 (BSD-3-Clause, linked statically for the HAP encoder). The FFmpeg
  source of this commit is at <https://github.com/FFmpeg/FFmpeg/tree/669f5ab083>.
- **Replacing:** you may replace these files with your own build of FFmpeg with the same major versions (the numbers
  in the file names). The environment variable `SHZ_FFMPEG_DIR` points the nanogui module at another folder.
- **Patents:** FFmpeg includes decoders for H.264 / HEVC and other formats that may be covered by patents in some
  countries. The license of this software grants no patent rights; users are responsible for any patent licenses their
  use needs.

## Libraries shipped as separate files

| Component | License | Files | Platforms |
|---|---|---|---|
| FFmpeg 9.0.2 | LGPL-3.0-or-later | `nanogui/native/<platform>/ffmpeg/` (see above) | all |
| NDI runtime 6 (Vizrt NDI AB) | NDI SDK License Agreement, <http://ndi.link/ndisdk_license>; third-party licenses of the runtime below | `nanogui/native/linux_x64/libndi.so` | Linux x64. On Windows and macOS VibeVJ uses an NDI runtime installed on the computer (NDI Tools); none is shipped. |
| libcurl | curl license | `curl/native/windows_x64/libcurl.dll`, `tgbot/native/windows_x64/libcurl.dll` | Windows |
| zlib | zlib license | `curl/native/windows_x64/zlib1.dll`, `tgbot/native/windows_x64/zlib1.dll` | Windows |
| OpenSSL 3 | Apache-2.0 | `webserver/` and `tgbot/native/windows_x64/libssl-3-x64.dll`, `libcrypto-3-x64.dll` | Windows |
| OpenSSL 1.1 | OpenSSL License and SSLeay License | `webserver/native/windows_x64/libssl-1_1-x64.dll`, `libcrypto-1_1-x64.dll` (where present: files of an older build, not loaded by the current module) | Windows |
| tgbot-cpp | MIT | `tgbot/native/windows_x64/TgBot.dll` (where present: a file of an older build, not loaded by the current module) | Windows |
| CPython 3.12 | Python Software Foundation License Version 2 | `python/native/windows_x64/python3.dll`, `python312.dll` | Windows |
| Microsoft Visual C++ runtime | Microsoft Visual Studio redistribution terms (distributable code) | `python/native/windows_x64/vcruntime140.dll`, `vcruntime140_1.dll` | Windows |
| Boost.System 1.74 | BSL-1.0 | `webserver/native/linux_x64/libboost_system.so.1.74.0` | Linux x64 |
| Homebrew libraries | their own licenses (named by each Homebrew formula) | any `libs/` folder next to a module in `native/macos_arm64/` | macOS |

Package paths in this table start at `shizotech/packages/`. On Linux the modules use the system's libcurl, OpenSSL,
LevelDB and Python, which are not part of VibeVJ.

## Compiled into the interpreter and the modules

| Component | License | Used in |
|---|---|---|
| [NanoGUI](https://github.com/wjakob/nanogui) (Wenzel Jakob); the widgets of the nanogui module are derived from it | BSD-3-Clause | nanogui |
| [NanoVG](https://github.com/memononen/nanovg) (Mikko Mononen) | zlib | nanogui |
| [GLFW](https://www.glfw.org) 3 | zlib | nanogui |
| [glad](https://github.com/Dav1dde/glad) OpenGL loader (generated) with `khrplatform.h` (The Khronos Group) | generated code: public domain / CC0 / WTFPL or Apache-2.0; `khrplatform.h`: MIT | nanogui |
| [stb_image](https://github.com/nothings/stb) 2.30, stb_image_write 1.16 (Sean Barrett) | public domain or MIT | nanogui |
| [UTF8-CPP](https://github.com/nemtrif/utfcpp) (Nemanja Trifunovic) | BSL-1.0 | nanogui |
| [nativefiledialog-extended](https://github.com/btzy/nativefiledialog-extended) | zlib | nanogui (Windows) |
| [Spout 2](https://spout.zeal.co) (Lynn Jarvis) | BSD-2-Clause | nanogui (Windows) |
| [Syphon Framework](https://github.com/Syphon/Syphon-Framework) (Tom Butterworth, Anton Marini) | BSD-3-Clause | nanogui (macOS) |
| NDI SDK headers 6 (Vizrt NDI AB); the runtime is loaded at run time | MIT (headers only) | nanogui |
| Roboto Regular / Bold (Google) | Apache-2.0 | nanogui (embedded font) |
| Inconsolata (Raph Levien) | SIL Open Font License 1.1 | nanogui (embedded font) |
| Font Awesome Free, Solid (Fonticons, Inc.) | SIL Open Font License 1.1 | nanogui (embedded font) |
| Noto Emoji (Google) | SIL Open Font License 1.1 | nanogui (embedded font) |
| [miniaudio](https://miniaud.io) 0.11.21 (David Reid) | public domain (Unlicense) or MIT-0 | simpleaudio, nanogui |
| [KISS FFT](https://github.com/mborgerding/kissfft) (Mark Borgerding) | BSD-3-Clause | simpleaudio |
| [BTrack](https://github.com/adamstark/BTrack) (Adam Stark, Queen Mary University of London) | GPL-3.0-or-later | simpleaudio |
| [libsamplerate](https://github.com/libsndfile/libsamplerate) (Erik de Castro Lopo) | BSD-2-Clause | simpleaudio |
| [Eclipse Paho MQTT C and C++](https://eclipse.dev/paho/) | EPL-2.0 or EDL-1.0 (used under EDL-1.0, a BSD-3-Clause license) | mqtt |
| [LevelDB](https://github.com/google/leveldb) (The LevelDB Authors); macOS: 1.23 | BSD-3-Clause | leveldb (Windows, macOS) |
| [Snappy](https://github.com/google/snappy) (Google); macOS: 1.3.1 | BSD-3-Clause | leveldb (macOS) |
| OpenSSL 3.5 | Apache-2.0 | webserver (macOS; license file in `webserver/native/macos_arm64/licenses/`) |
| [Boost](https://www.boost.org) (Asio and others) | BSL-1.0 | webserver |
| [libcurl](https://curl.se) with [zlib](https://zlib.net) | curl license, zlib | `VibeVJ.exe` (Windows) |
| [JSON for Modern C++](https://github.com/nlohmann/json) 3.12.0 (Niels Lohmann) | MIT | interpreter, tgbot, prolink |
| [xxHash](https://github.com/Cyan4973/xxHash) 0.8 (Yann Collet) | BSD-2-Clause | interpreter, nanogui |
| [atomic_queue](https://github.com/max0x7ba/atomic_queue) (Maxim Egorushkin) | MIT | interpreter, ipc, webserver |
| [oscpp](https://github.com/kaoskorobase/oscpp) (Stefan Kersten) | BSL-1.0 | interpreter (OSC) |
| [Eigen](https://eigen.tuxfamily.org) 3.4.0, unmodified | MPL-2.0 (a few files BSD-3-Clause) | interpreter, nanogui |
| [Bitmap Image Reader Writer Library](http://partow.net/programming/bitmap/index.html) (Arash Partow) | MIT | interpreter |
| [miniz-cpp](https://github.com/tfussell/miniz-cpp) (Thomas Fussell) with miniz 1.15 (Rich Geldreich) | MIT; miniz: public domain (Unlicense) | zip |

The macOS bundle carries the license files of OpenSSL, LevelDB and Snappy in `native/macos_arm64/licenses/` of the
`webserver` and `leveldb` packages.

**Source code:** the source of Eigen 3.4.0 (MPL-2.0) is at <https://gitlab.com/libeigen/eigen/-/tree/3.4.0>, the
source of BTrack (GPL-3.0-or-later) at <https://github.com/adamstark/BTrack>.

## Shaders and other assets

Some shaders in `VibeVJ/assets/Shaders/` are adapted from works of other authors (for example from Shadertoy). Where
the original names an author or a license (for example Creative Commons Attribution-NonCommercial-ShareAlike 3.0),
it is kept in the header of the shader file, and those terms apply to that file.

## Trademarks

NDI® is a registered trademark of Vizrt NDI AB. VibeVJ is not a product of Vizrt NDI AB; NDI is named only to say that
VibeVJ can send and receive NDI video. See <https://ndi.video>. Spout, Syphon, FFmpeg, H.264 and HEVC are names of
their respective owners.

## License texts

Licenses that are long and standard are referenced by their official text:

- GNU Lesser General Public License v3 (FFmpeg): `LICENSE.txt` in the FFmpeg folder,
  <https://www.gnu.org/licenses/lgpl-3.0.html> (it builds on <https://www.gnu.org/licenses/gpl-3.0.html>)
- GNU General Public License v3 (BTrack): <https://www.gnu.org/licenses/gpl-3.0.html>
- Mozilla Public License 2.0 (Eigen): <https://www.mozilla.org/MPL/2.0/>
- Eclipse Public License 2.0 (Paho, alternative to EDL-1.0): <https://www.eclipse.org/legal/epl-2.0/>
- SIL Open Font License 1.1 (Inconsolata, Font Awesome Free, Noto Emoji): <https://openfontlicense.org>
- Python Software Foundation License Version 2 (CPython): <https://docs.python.org/3/license.html>.
  Copyright (c) 2001 Python Software Foundation; All Rights Reserved.
- OpenSSL License and SSLeay License (OpenSSL 1.1): <https://www.openssl.org/source/license-openssl-ssleay.txt>.
  This product includes software developed by the OpenSSL Project for use in the OpenSSL Toolkit
  (<http://www.openssl.org/>). This product includes cryptographic software written by Eric Young (eay@cryptsoft.com).
- Apache License 2.0 (OpenSSL 3, Roboto): the full text is at the end of this file.

### BSD-3-Clause

- NanoGUI: Copyright (c) 2017 Wenzel Jakob <wenzel.jakob@epfl.ch>, All rights reserved.
- Syphon Framework: Copyright 2010 bangnoise (Tom Butterworth) & vade (Anton Marini). All rights reserved.
- KISS FFT: Copyright (c) 2003-2004, Mark Borgerding. All rights reserved.
- LevelDB: Copyright (c) 2011 The LevelDB Authors. All rights reserved.
- Snappy: Copyright 2011, Google Inc. All rights reserved.
- Eclipse Paho (Eclipse Distribution License v1.0): Copyright (c) 2007, Eclipse Foundation, Inc. and its licensors.
  All rights reserved. Paho MQTT C: Copyright (c) 2009, 2024 IBM Corp., Ian Craggs and others.
- Eigen (the files under BSD-3-Clause): the copyright holders named in those files.

```
Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following
   disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
   disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote
   products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

### BSD-2-Clause

- Spout 2: Copyright (c) 2014-2023, Lynn Jarvis. All rights reserved.
- xxHash: Copyright (C) 2012-2023 Yann Collet
- libsamplerate: Copyright (c) 2002-2016, Erik de Castro Lopo <erikd@mega-nerd.com>

```
Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following
   disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
   disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

### zlib License

- GLFW: Copyright (c) 2002-2006 Marcus Geelnard, Copyright (c) 2006-2019 Camilla Löwy
- NanoVG: Copyright (c) 2013 Mikko Mononen memon@inside.org
- nativefiledialog-extended: Copyright (c) the nativefiledialog-extended authors
- zlib: Copyright (C) 1995-2024 Jean-loup Gailly and Mark Adler

```
This software is provided 'as-is', without any express or implied warranty. In no event will the authors be held
liable for any damages arising from the use of this software.

Permission is granted to anyone to use this software for any purpose, including commercial applications, and to
alter it and redistribute it freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software.
   If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is
   not required.
2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original
   software.
3. This notice may not be removed or altered from any source distribution.
```

### MIT License

- JSON for Modern C++: Copyright (c) 2013-2025 Niels Lohmann <https://nlohmann.me>
- atomic_queue: Copyright (c) 2019 Maxim Egorushkin
- Bitmap Image Reader Writer Library: Copyright (c) Arash Partow
- miniz-cpp: Copyright (c) 2014-2017 Thomas Fussell
- tgbot-cpp: Copyright (c) 2015 Oleg Morozenkov
- NDI SDK headers: Copyright (C) 2023-2026 Vizrt NDI AB. All rights reserved.
- `khrplatform.h`: Copyright (c) 2008-2018 The Khronos Group Inc.
- stb_image, stb_image_write (MIT alternative of their public domain dedication): Copyright (c) 2017 Sean Barrett

```
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit
persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

### Boost Software License 1.0

- Boost: Copyright the Boost authors (each library names its own)
- UTF8-CPP: Copyright 2006 Nemanja Trifunovic
- oscpp: Copyright (c) 2004-2013 Stefan Kersten <sk@k-hornz.de>

```
Permission is hereby granted, free of charge, to any person or organization obtaining a copy of the software and
accompanying documentation covered by this license (the "Software") to use, reproduce, display, distribute, execute,
and transmit the Software, and to prepare derivative works of the Software, and to permit third-parties to whom the
Software is furnished to do so, all subject to the following:

The copyright notices in the Software and this entire statement, including the above license grant, this restriction
and the following disclaimer, must be included in all copies of the Software, in whole or in part, and all derivative
works of the Software, unless such copies or derivative works are solely in the form of machine-executable object
code generated by a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

### curl License

```
COPYRIGHT AND PERMISSION NOTICE

Copyright (c) 1996 - 2025, Daniel Stenberg, <daniel@haxx.se>, and many contributors, see the THANKS file.

All rights reserved.

Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted,
provided that the above copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF THIRD PARTY RIGHTS. IN NO EVENT
SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

Except as contained in this notice, the name of a copyright holder shall not be used in advertising or otherwise to
promote the sale, use or other dealings in this Software without prior written authorization of the copyright holder.
```

### Public domain

miniaudio (David Reid), miniz 1.15 (Rich Geldreich) and stb (Sean Barrett) are dedicated to the public domain
(miniaudio alternatively MIT-0, stb alternatively MIT). No notice is required; they are named here as a courtesy.

### NDI runtime: third-party licenses

The NDI runtime (`libndi.so`) comes with the following notice (`licenses/libndi_licenses.txt` of the NDI SDK), which
Vizrt NDI AB asks to include with every distribution of its binary files:

```
********************************************************************************
NDI
Copyright (C) 2023-2026 Vizrt NDI AB. All rights reserved.
********************************************************************************

The NDI SDK license available at:
    http://ndi.link/ndisdk_license

The NDI Advanced SDK license is available at
    http://ndi.link/ndisdk_embedded_license

For more information about NDI please visit:
    http://ndi.video/

This file should be included with all distribution of the binary files included with the NDI SDK.

We are truly thankful for the NDI community and the amazing support that it has shown us over the years.

********************************************************************************
NDI gratefully uses the following third party libraries.

********************************************************************************
RapidJSON (https://rapidjson.org)

Tencent is pleased to support the open source community by making RapidJSON available.

Copyright (C) 2015 THL A29 Limited, a Tencent company, and Milo Yip. All rights reserved.

Licensed under the MIT License (the "License"); you may not use this file except
in compliance with the License. You may obtain a copy of the License at

http://opensource.org/licenses/MIT

Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.

****************************************************
SpeexDSP (https://www.speex.org), resampling code only.

© 2002-2003, Jean-Marc Valin/Xiph.Org Foundation

Redistribution and use in source and binary forms, with or without modification, are permitted provided
that the following conditions are met:

Redistributions of source code must retain the above copyright notice, this list of conditions and the
following disclaimer.

Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
following disclaimer in the documentation and/or other materials provided with the distribution.
Neither the name of the Xiph.org Foundation nor the names of its contributors may be used to endorse or
promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

********************************************************************************
RapidXML (http://rapidxml.sourceforge.net)

Copyright (c) 2006, 2007 Marcin Kalicinski

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

********************************************************************************
CxxUrl (https://github.com/chmike/CxxUrl)

The MIT License (MIT)

Copyright (c) 2015 Christophe Meessen

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

********************************************************************************
ASIO (https://think-async.com)

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

Copyright (c) Microsoft Corporation.

********************************************************************************
MsQuic (https://github.com/microsoft/msquic)

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

********************************************************************************
Opus Interactive Audio Codec (https://opus-codec.org)

Copyright 2001-2011 Xiph.Org, Skype Limited, Octasic,
                    Jean-Marc Valin, Timothy B. Terriberry,
                    CSIRO, Gregory Maxwell, Mark Borgerding,
                    Erik de Castro Lopo

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

- Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

- Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

- Neither the name of Internet Society, IETF or IETF Trust, nor the
names of specific contributors, may be used to endorse or promote
products derived from this software without specific prior written
permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Opus is subject to the royalty-free patent licenses which are
specified at:

Xiph.Org Foundation:
https://datatracker.ietf.org/ipr/1524/

Microsoft Corporation:
https://datatracker.ietf.org/ipr/1914/

Broadcom Corporation:
https://datatracker.ietf.org/ipr/1526/

********************************************************************************
Updated to C++, zedwood.com 2012
Based on Olivier Gay's version
See Modified BSD License below:

FIPS 180-2 SHA-224/256/384/512 implementation
Issue date:  04/30/2005
http://www.ouah.org/ogay/sha2/

Copyright (C) 2005, 2007 Olivier Gay <olivier.gay@a3.epfl.ch>
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
3. Neither the name of the project nor the names of its contributors
   may be used to endorse or promote products derived from this software
   without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED.  IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
SUCH DAMAGE.
```

### Apache License 2.0

```

                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS

   APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "[]"
      replaced with your own identifying information. (Don't include
      the brackets!)  The text should be enclosed in the appropriate
      comment syntax for the file format. We also recommend that a
      file or class name and description of purpose be included on the
      same "printed page" as the copyright notice for easier
      identification within third-party archives.

   Copyright [yyyy] [name of copyright owner]

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
```
