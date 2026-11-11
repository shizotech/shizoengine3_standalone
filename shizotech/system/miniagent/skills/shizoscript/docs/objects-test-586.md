# Foreground objects (#586): test on Windows and macOS

The owner asked on #879 (2026-11-01) for "foreground objects": black shiny cubes / triangles as a cyberpunk eye
catcher, a glass prism that splits light like the Pink Floyd prism in 3D, a black ferrofluid blob that reacts to music,
lava lamp wax with subsurface scattering, "all of them glitch and tweakable via parameter uniforms".

Branch `claude/586-hero-objects`. Built and checked in a Linux container: Mesa llvmpipe (software OpenGL) under Xvfb,
with the build of `main` (no C++ changed: only shaders and docs, no build is needed). What that could not show: the
frame rate on a real graphics card, the look on a real display, NVIDIA / AMD / Apple GLSL compilers (the check is
glslangValidator, strict 330 core), real sound from a sound card.

## What changed

New folder `_shizoengine3/assets/Shaders/Sources/Objects/` with four shader sources (new asset ids, nothing renamed):

| Asset | What it shows |
|---|---|
| `Monolith.glsl` | a glossy black cube (or pyramid, triangle prism, octahedron, slab; trio, ring, orbit) with neon lines, alone in the dark, glowing: a halo, a glow that fills the picture and light rays (the neon city and the floor are options) |
| `Prism.glsl` | clear glass ray traced per wavelength (rainbow fringes inside and at the edges): 18 shapes (prism, gem, sphere, torus, knot, heart, star, ...), a grid of up to 6 x 6 copies, a backdrop it bends (the optional input *Background* or a pattern); with *Beam intensity* the white beam split into a rainbow fan |
| `Ferrofluid.glsl` | a black spiky ball (or a dish) whose spikes grow with the music |
| `LavaLamp.glsl` | glowing wax drops that rise, merge, split and sink over the whole picture (no lamp, no glass) |

Each has the passes `S` (4 x 1 pixels, the music), `A` (the object), `B` / `C` (the glow at 1/4 and 1/16 size),
`__init__` (glitch, glow, tone mapping); Prism and LavaLamp also `L` (32 x 8 / 32 x 2 pixels: the beam paths / the wax
drops), Monolith also `R` (the light rays, 1/4 size), Prism also `M` (1 pixel: whether a picture is linked into
*Background*). They have a sampler `AUDIO` (port *Audio*). Wiki: *Assets › Shaders › Foreground objects*.

## Checked on Linux

- `compile_scripts/check_glsl.py`: 590/590 (after merging main).
- `_testing/asset_ids.shio`: all passed; `check_assets.sh`: 73 passed; `_testing/wiki/check_links.py`: 0 broken;
  `smoke.py static`: passed.
- Each object in a Clipview, full screen on the monitor at render scale 0.5 (software OpenGL: seconds a frame).
- Save / load over MCP of the four with changed controls of each kind: 26 of 26 the same.
- Real sound: a video with a 120 BPM track, an AudioInputAnalysis on *Video clips*, its *FFT texture* linked into the
  Ferrofluid (*Field* 0): *Music* *Off* a smooth ball, *Music* *Sound* spikes that change from shot to shot.
- The music state with an `AUDIO` texture (outside the app), the beat fallback, *Glitch on beat* only on whole beats.
- Prism glass rework (#889 comment, 2026-11-01): `check_glsl.py` 591/591, `check_assets.sh` 92 passed; every shape,
  backdrop, dispersion 0 / 6 / 12, grids 3 x 3 and 6 x 6, shape variation, the beam and a picture in *Background*
  rendered with `render_asset.py` (`pic:background=...`); in the app (Xvfb, render scale 0.25) it loads in a Patchview,
  all new controls and the port `input_ctrls@background` exist, *Count x* / *Count y* / *Shape* / *Backdrop* /
  *Dispersion* set over MCP read back the same and change the picture on the monitor.

## Phase 0: get the branch

- Windows: `& .\_testing\windows_app\testcopy.ps1 -Name pr586obj` (no `-Binaries`: no C++ changed).
- macOS: `sh shzscript_macos/setup_mac.sh --build` on the branch.

## Phase 1: they compile and render (GPU)

- [ ] Drag each of the four from *Shaders › Sources › Objects* into a Clipview cell: it shows a picture within a
      second, no error in the log. Put each on a display (the *Monitor* of its *Outputs*) full screen.
- [ ] *Quality* 1, 2, 3 on each: no error, 3 looks smoother on edges. Note the frame rate (the FPS of the app) at
      1920 x 1080 for each quality, with nothing else running. Goal: Quality 1 >= 60 fps on a mid-range card;
      Quality 2 >= 30 fps.

| Asset | Should show (defaults) |
|---|---|
| Monolith | black cube standing on a corner, cyan lines inset along its edges and veins of light on its faces, nothing else around it: a blue glow fills the whole picture, light rays shoot out of it, all brighter on each beat; not blown out to flat white |
| Prism | a glass prism turning slowly in front of thin orange / blue / white lines on black; the lines seen through it are bent and have rainbow edges, a soft shadow with a bright spot on the lines below right |
| Ferrofluid | a black ball with spikes all over, white and orange / blue highlights on the spikes, spikes pulsing on the beat (timeline playing) |
| LavaLamp | orange-red wax drops over the whole picture in dark purple liquid, a glowing pool of wax at the bottom, darker drops behind; the drops rise, merge and sink slowly |

## Phase 2: the look on a real display

- [ ] Monolith: the faces stay dark next to the bright glow, the glow and the rays fill the picture up to the corners
      and pulse on the beat; *Glow radius* 0 / 1, *Rays* 0, *Color cycle* 0.5, *Flicker* 0.5 do what they say; no stair
      steps flicker on the lines at Quality 1 with *Edge smoothing* 1. *Environment* *City* with *Floor reflection*
      0.6 still gives the neon city and the wet floor.
- [ ] Prism: *Shape* through all 18: each is a clear glass object, no black blocks, no flicker of single pixels
      that does not belong to a sparkle. *Dispersion* 0 / 6 / 12: no rainbow / fringes / wide rainbows. *Spectral
      samples* 1 / 3 / 8 (Quality 2): 1 no colours, 8 the smoothest. *Count x* 3, *Count y* 3: nine copies, none cut
      at its side. *Backdrop* each pattern; a video linked into *Background*: it fills the screen and the glass bends
      it (a sphere shows it upside down). *Beam intensity* 8, *Environment* Studio, *Camera distance* 5.5: the album
      cover (beam, fan, floor); *Rock* moves the fan; no black or white pixels (NaN).
- [ ] Prism frame rate at 1920 x 1080: Quality 1 / 2 / 3 with one object and with *Count* 6 x 6, and with *Shape*
      Knot (the most expensive shape).
- [ ] Ferrofluid: with the timeline playing the spikes rise on each beat, overshoot a little and settle; *Viscosity* 0
      makes them wobble more. *Form* Dish shows a puddle with spikes in a dish.
- [ ] LavaLamp: over a minute drops rise from the bottom, merge, split and come down, spread over the whole picture
      (not all at the top or bottom); each *Palette* looks different, *Rainbow* blends the colours where drops melt
      together; *Blobs* 32 and *Blob size* 2 still run smoothly.
- [ ] *Background mode* Transparent on each, the object in Layer 1 (*Add*) over a video in Layer 2: only the object
      and its glow show over the video.

## Phase 3: glitch and music

- [ ] *Glitch* 0.8 with each *Glitch kind* (Slices, RGB split, Tear, Shatter, Mix): each looks different, Shatter
      breaks the object into blocks.
- [ ] *Glitch on beat* 1, *Glitch every* 4, the timeline playing: a glitch every 4 beats; the timeline stopped: no
      glitch. *Glitch hold*: MIDI learn it to a pad, holding the pad glitches fully.
- [ ] A sound card: an AudioInputAnalysis on the input, its *FFT texture* linked into the port *Audio* of the
      Ferrofluid, *Music* *Sound*: the spikes follow the bass of real music; *Music* *Off*: the spikes rest.

## Results

### Windows (date)

Machine, GPU, per phase pass / fail, the frame rates, screenshots of anything wrong.

### macOS (date)

Machine, per phase pass / fail, the frame rates, screenshots of anything wrong.
