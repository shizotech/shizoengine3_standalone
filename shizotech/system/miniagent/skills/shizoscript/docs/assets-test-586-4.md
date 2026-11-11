# Point passes and the fourth set of assets (#586): test on Windows and macOS

Issue [#586](https://github.com/shizotech/shizoscript3_source/issues/586): "Add more complex visual components to
algorithmically create visuals just like in touch designer". Branch `claude/586-procedural-assets-4`.

Built and checked in a Linux container (Mesa llvmpipe under Xvfb). That cannot show: a real GPU (speed, the largest
GL point size, blending into float textures), Apple's OpenGL driver, NVIDIA. **C++ changed** (`nanogui.shader`, a point
draw): a build is needed.

## What changed

| Area | Before | Now |
|---|---|---|
| `modules/shzmodule_nanogui/shader.cpp/.h` | a shader always drew its picture (two triangles) | `points(n)` (-1 = the picture, the default): `n` GL points from `gl_VertexID`, no vertex buffer; `point_quads(true)`: two triangles a point; `point_blend` `add` / `alpha` / `max` / `none`; the custom vertex source gets the renames of reserved names (`input`) |
| `shader_loader.shio`, `shadertoy.shio` | — | a pass with `//@settings draw=points` / `draw=quads count=... blend=...` is compiled as vertex (`mainPoint`) and fragment (`pointPixel`) shader; `count` is read from controls every frame |
| `compile_scripts/check_glsl.py` | fragment shaders | point passes: both stages compiled and linked |
| `iResolution.z` (`shader_loader.shio`, the hover preview) | width / height divided as two ints: 1 for 16:9, 0 for a portrait picture | the float aspect (1.78 for 16:9), as SHADER_GUIDE.MD says; FeedbackTransform, Composite, Relief, Displace and Force2Colors read it: their turns and noise are round now instead of stretched |
| New assets | — | `Sources/Simulations/Particles2.glsl` (up to 1 048 576 points), `Effects/Morph&Mirror/Instancer.glsl` (quads from a picture), `Effects/Utility/Transform.glsl`, `Sources/3D/Stage.glsl` (raymarched) |

No existing asset, uniform name or save key changed.

## Checked on Linux

- `_testing/nanogui/shader_points.shio` (points, quads, the four blends, count 0 and -1): ALL PASSED; the other
  `nanogui/shader_*` tests pass (`shader_source_change.shio` has no PASSED line on main either).
- `python3 compile_scripts/check_glsl.py`: 329/329; `check_assets.sh` 73 passed; `smoke.py static generators` passed.
- `check_msvc_linux.sh --only nanogui`: ok; `check_libcxx_linux.sh`: see the PR.
- In the app: each asset looked at full screen, saved and loaded over MCP (41 of 41 values back).

## Phase 0: get the branch

- Windows: `& .\_testing\windows_app\build.ps1 -Only nanogui`, then `testcopy.ps1 -Name pr586-4 -Binaries <out>`.
- macOS: `sh shzscript_macos/setup_mac.sh --build`.

## Phase 1: automatic

- [ ] `shz _testing/nanogui/shader_points.shio` prints ALL PASSED (Windows: from the test copy; Mac: in the bundle).
- [ ] No `Error 00000502` / GL errors in the log while the assets below run (Apple's driver is strict about the
      blend and point state).

## Phase 2: the assets on a real GPU (Clipview, a clip each, full screen on a display)

| Asset | Settings | Should show |
|---|---|---|
| Particles2 | defaults, then *Particles* 1 048 576 | a cloud of thin swirling threads from a sphere, turning slowly; 60 fps at 1080p on a mid GPU (say the fps) |
| Particles2 | *Point size* 8, *Point shape* *Spark* / *Glow* | big points with the shape (Mac: points bigger than the driver's largest point size are cut to it, say the size where it stops) |
| Particles2 | *View* *Flat*, *Emitter* *Field picture*, a video linked into *Field*, *Color mode* *From field* | the particles born on the bright parts of the video, in its colours |
| Instancer | on a video, defaults | dots on a grid that leans back, big and close where the video is bright, coloured by it |
| Instancer | *Layout mode* *Sphere*, *Shape* *Star*, *Blend* *Over* | the video wrapped around a ball of stars, the back hidden |
| Instancer | *Columns* 200, *Rows* 112 | still smooth (22 400 copies) |
| Transform | on a video: *Tiles x* / *y* 3, *Tile mirror* *Mirror both*, *Rotate* 12, *Scale* 0.85, *Tile gap* 0.06 | 9 mirrored copies with gaps, turned |
| Composite | *Layer rotate* 45 on two pictures | the layer turned as a square turns (not sheared) |
| Stage | defaults, *Quality* 1, then 2 | three bouncing boxes on tiles, soft shadows, a mirror image in the floor, the light jumping at each beat; Quality 1 real time at 1080p (say the fps of 1 and 2) |
| Stage | *Shape* *Sphere*, *Arrangement* *Ring*, *Metallic* 0.8, *Floor pattern* *Checker*, *Floor reflection* 0.8 | six metal balls mirrored in a checker floor, the far checker smooth grey (no flicker) |

## Results

### Windows (date)

Machine, GPU, per phase pass / fail, fps, screenshots of anything wrong.

### macOS (date)

Machine, per phase pass / fail, fps, the largest point size seen, screenshots of anything wrong.
