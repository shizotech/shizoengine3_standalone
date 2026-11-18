# Stage, STEP and LEDs on the stage (#980): test on Windows and macOS

[#980](https://github.com/shizotech/shizoscript3_source/issues/980), PR
[#979](https://github.com/shizotech/shizoscript3_source/pull/979), branch `claude/gallant-turing-u79ub3`. Built and checked on
Linux in a container (Mesa llvmpipe under Xvfb), driven with xdotool and over MCP; the macOS build checked with
`check_libcxx_linux.sh`, the Windows compile with `check_msvc_linux.sh --only nanogui`. What a container cannot show:
point sprites on a real GPU and driver (Apple's core profile, NVIDIA / AMD / Intel on Windows), Retina, the uv install
of `cadquery-ocp` (OpenCASCADE, with VTK) on Windows and macOS arm64, Windows paths in the Import field.

**C++ changed** (`modules/shzmodule_nanogui`): `nanogui.splats3d` (new `splats3d.cpp/.h`: reads Gaussian splat `.ply`
/ `.splat`) and the `view3d` item option `splats` (a second shader program, instanced quads with `glVertexAttribIPointer`
/ `glVertexAttribDivisor` on attribute 5, the data in an RGBA32F texture of 4096 texels a row, a counting sort back to
front), `mesh3d.quad(w, h)` and `mesh3d.uvs()` (texture coordinates, a 4th
vertex attribute), the `view3d` item option `picture` (a shader or video output on texture unit 4; the view draws every
frame while one is shown; #980 LED walls); before that: `mesh3d.points(vertices)` (a mesh of points), `mesh3d.colors(buffer,
offset, count, stride, first)` (8 bit RGB per vertex, copied from a buffer: the read-back of a LEDMapper's shader), the
`view3d` item mode `"glow"` with the option `point_size` (metres; round points, a core and a halo, added like light,
hidden behind what is in front of them), the item options `material` / `lit_by` (a translucent surface lit by the LEDs
of glow items: an RGBA32F texture of their positions and colours on texture unit 3, a loop over the LEDs near it in the
fragment shader). The shader got a colour attribute (location 2), `gl_PointSize`, and the view
switches `GL_PROGRAM_POINT_SIZE` on while it draws (desktop GL; restored afterwards). Build the nanogui module
(Windows: `build.ps1`; macOS: `setup_mac.sh --build`). The rest is scripts.

## What changed

| Area | What |
|---|---|
| Tools button (#975) | toolbox icon at the right of the top bar: Fixture setup, Stage, Fixture editor; kept menus (closing the tab hides them) |
| Stage menu | model files of `assets/Stage` (STEP, 3MF, STL, OBJ, GLB) placed in 3D, saved as `stage.json`; drag / Shift+drag / R, inspector, Floor, hangs on, hide |
| STEP | converted once with OpenCASCADE in a uv environment (about 170 MB download, 1.2 GB on disk, asked first) into `<file>.step.stagemesh` |
| LEDs on the stage | a LEDMapper group, *On the stage*: its LEDs as glowing points in the colours sent, in the Stage menu and the fixture setup's 3D view; *Simulation* (bigger glow) |
| LEDs along edges | inspector › *Show edges*, click an edge: a strip along the outline in a LEDMapper group, hanging on the object (Shift: one piece) |
| Camera scan | LEDMapper › *Camera scan*: one LED after the other lit, its place where a camera sees it (segment shape *Scanned*) |
| LED walls, screens | Stage › *Screen*: panels / size, the picture of a video router on it (Simulation on), also in the fixture setup's 3D view |
| Scans of the venue | a Gaussian splat `.ply` / `.splat` as an object; *Floor: click 3 points*, *Measure* + *Scale to it*; *Splats* (how many), *Up to m* |
| Measured materials | Stage › Materials › *Measure a material with a camera*: dark picture, the LED without the piece, the spot through it at a few distances → spread and light, a preset in `assets/Stage/Materials` |
| MCP | live_path `stage` (list / add / set / remove objects, convert_step); LEDMapper `set_stage_place` |

## Windows

1. Build the exe and the modules (`& .\_testing\windows_app\build.ps1`), a test copy (`testcopy.ps1 -Name stage`).
2. Tests:
   - [ ] `_testing/nanogui/view3d.shio`: ALL PASSED (the last block: points in their colours, round, hidden behind a wall)
   - [ ] `cd _shizoengine3; shz engine/menus/stage/stage_check.shio`: ALL PASSED (LEDs red / green / blue as sent, the glow
     of the simulation)
   - [ ] `shz _testing/stage_step.shio --install`: installs OpenCASCADE with uv (the first time minutes), ALL PASSED
3. In the app:
   - [ ] Tools › Stage; double-click `Examples/Truss 2m.stl` and `Examples/Hexagon panel.3mf`: both stand on the stage
   - [ ] *Import* with a path from Explorer's "Copy as path" (quotes, backslashes, a drive letter): copied into
     `assets\Stage`, added
   - [ ] a STEP file from Fusion: *Convert* asks about OpenCASCADE, installs, converts; bodies with names and colours
   - [ ] a LEDMapper in a view, a few segments, a group *On the stage*, *Test* on: the LEDs glow in the Stage menu in
     front of the panel; *Simulation* on: a bigger glow; the colours follow the LEDMapper's picture
   - [ ] materials (Simulation on): the hexagon panel's *Diffuser* set to *Acrylic, opal*, a LED ring 2 cm behind it:
     a soft glow through it, the middle dark; *Acrylic, clear*: points; Simulation off: solid
   - [ ] LEDs along edges: the hexagon panel selected, *Show edges*, click the inner edge of the frame: a closed ring of
     LEDs along it (the note says how many), a group *Edges of Hexagon panel* in the LEDMapper; the lines are hit with
     the mouse at the panel's size on the screen (Retina on the Mac)
   - [ ] **Camera scan** (needs real LEDs on an Art-Net node and a webcam): a strip laid in a curve, its segment with the
     right LEDs and address, a Camera generator seeing it, the room dark; LEDMapper › *Camera scan*, pick the camera,
     *Scan the selection*: each LED lights on its own, one after the other; at the end the segment follows the strip
     (*Shape* *Scanned*, "N LEDs: N seen"). LEDs in the place of the one before: the *Wait* it needed (the webcam's
     delay). `shz _testing/nanogui/ledscan_gpu.shio`: ALL PASSED (the measure shader, float read-back)
   - [ ] **LED walls:** a shader with *Enable router* on, Stage › *Screen*, *Picture* = that shader, Simulation on: the
     picture runs on the wall, upright and not mirrored (a picture with text), smooth while the shader plays; a video
     (Video asset with its router on) too; Simulation off: dark, the 3D view no longer redraws every frame (GPU load)
   - [ ] **Scans:** a real Gaussian splat scan of a room (`.ply` from Scaniverse / Polycam / Postshot, 0.5 to 3 million
     splats) into `assets/Stage`, added: it shows (a moment later), smooth while turning the view (the sort), no
     holes or stripes; *Floor: click 3 points* makes its floor level, *Measure* + *Scale to it* its real size; *High*
     on a big scan: how fast (frames a second) on this GPU; the scan hides behind models in front of it and covers
     models behind it
   - [ ] **Measure a material** (a webcam, one LED on a node, a printed test piece): the steps of the wiki
     (Stage › Measure a material) at 3, 5, 10, 20 mm; the spreads grow with the distance, *off by* a few mm at most;
     *Light* between 0 and 1 and plausible (white PETG 2 mm: about 0.3 to 0.6); *Save as a preset*: the file in
     `assets/Stage/Materials`, the preset in every body's list, after a restart too
   - [ ] the fixture setup's 3D view shows the models and the LEDs, its lamps still take the clicks
   - [ ] no "Failed to call on_prepare callback" in the Log

## macOS

1. `sh shzscript_macos/setup_mac.sh --build` (builds, bundles, runs every test).
2. The same tests and steps as Windows (paths with `/`), plus:
   - [ ] Retina: the LEDs are as big (in metres) as on a non-Retina screen, round, not squares (point sprites)
   - [ ] the glow is not cut off at a size limit when zoomed in close (points up to 128 px)
   - [ ] `shz _testing/stage_step.shio --install` on arm64: uv installs `cadquery-ocp` and `vtk` wheels

Report: a comment on PR #979 with what passed and what did not (screenshots of the Stage menu with LEDs welcome).
