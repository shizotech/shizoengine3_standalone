# SHADER_CHECK.MD - Shader Conversion Checklist

Complete checklist of all shaders to convert from `old/` to `Sources/` or `Effects/` with logical grouping.

## Legend
- `[ ]` = Not started
- `[~]` = In progress  
- `[x]` = Completed
- `[!]` = Blocked/Issues

---

## Audio Shaders (Sources/Audio/)

### 3drgb
- [x] 3drgb (`old/Audio/3drgb.ogl`) → `Sources/Audio/3drgb.glsl/`

### 8bit
- [x] 8bit (`old/Audio/8bit.ogl`, `8bit_B.ogl`, `8bit_C.ogl`, `8bit_D.ogl`) → `Sources/Audio/8bit/`

### Particle
- [x] Particle (`old/Audio/Particle.ogl`, `Particle_B.ogl`, `Particle_C.ogl`, `Particle_D.ogl`) → `Sources/Audio/Particle/`

### ParticlesDance
- [x] ParticlesDance (`old/Audio/ParticlesDance.ogl`) → `Sources/Audio/ParticlesDance.glsl/`

### Points
- [x] Points (`old/Audio/Points.ogl`) → `Sources/Audio/Points.glsl/`

### abstract
- [x] abstract (`old/Audio/abstract.ogl`, `abstract_B.ogl`) → `Sources/Audio/abstract/`

### abstract2
- [x] abstract2 (`old/Audio/abstract2.ogl`) → `Sources/Audio/abstract2.glsl/`

### abstract3
- [x] abstract3 (`old/Audio/abstract3.ogl`) → `Sources/Audio/abstract3.glsl/`

### altair
- [x] altair (`old/Audio/altair.ogl`, `altair_B.ogl`) → `Sources/Audio/altair.glsl/`

### altair2
- [x] altair2 (`old/Audio/altair2.ogl`, `altair2_B.ogl`) → `Sources/Audio/altair2.glsl/`

### balls
- [x] balls (`old/Audio/balls.ogl`) → `Sources/Audio/balls.glsl/`

### beat
- [x] beat (`old/Audio/beat.ogl`) → `Sources/Audio/beat.glsl/`

### circle
- [x] circle (`old/Audio/circle.ogl`) → `Sources/Audio/circle.glsl/`

### circleaura
- [x] circleaura (`old/Audio/circleaura.ogl`) → `Sources/Audio/circleaura.glsl/`

### circles
- [x] circles (`old/Audio/circles.ogl`) → `Sources/Audio/circles.glsl/`

### cockpit
- [x] cockpit (`old/Audio/cockpit.ogl`) → `Sources/Audio/cockpit.glsl/`

### colors
- [x] colors (`old/Audio/colors.ogl`) → `Sources/Audio/colors.glsl/`

### cube
- [x] cube (`old/Audio/cube_A.ogl`, `cube_B.ogl`) → `Sources/Audio/cube/`

### disco
- [x] disco (`old/Audio/disco.ogl`) → `Sources/Audio/disco.glsl/`

### discoball
- [x] discoball (`old/Audio/discoball.ogl`) → `Sources/Audio/discoball.glsl/`

### discotunnel
- [x] discotunnel (`old/Audio/discotunnel.ogl`, `discotunnel_B.ogl`) → `Sources/Audio/discotunnel.glsl/`

### frac
- [x] frac (`old/Audio/frac.ogl`, `frac_B.ogl`, `frac_C.ogl`, `frac_D.ogl`) → `Sources/Audio/frac/`

### guy
- [x] guy (`old/Audio/guy_A.ogl`, `guy_B.ogl`) → `Sources/Audio/guy/`

### heart
- [x] heart (`old/Audio/heart.ogl`, `heart_B.ogl`) → `Sources/Audio/heart/`

### heart2
- [ ] heart2 (`old/Audio/heart2.ogl`, `heart2_B.ogl`) → `Sources/Audio/heart2/`

### hex
- [ ] hex (`old/Audio/hex.ogl`) → `Sources/Audio/hex.glsl/`

### hex2
- [ ] hex2 (`old/Audio/hex2.ogl`) → `Sources/Audio/hex2.glsl/`

### kaleidoscope
- [ ] kaleidoscope (`old/Audio/kaleidoscope.ogl`) → `Sources/Audio/kaleidoscope.glsl/`

### neural
- [x] neural (`old/Audio/neural.ogl`) → `Sources/Audio/neural.glsl/`

### neural2
- [ ] neural2 (`old/Audio/neural2.ogl`, `neural2_B.ogl`) → `Sources/Audio/neural2/`

### noise
- [ ] noise (`old/Audio/noise.ogl`, `noise_B.ogl`, `noise_C.ogl`, `noise_D.ogl`, `noise_E.ogl`, `noise_shared.ogl`) → `Sources/Audio/noise/`

### psy1
- [ ] psy1 (`old/Audio/psy1.ogl`) → `Sources/Audio/psy1.glsl/`

### psy2
- [ ] psy2 (`old/Audio/psy2.ogl`, `psy2_B.ogl`, `psy2_C.ogl`, `psy2_shared.ogl`) → `Sources/Audio/psy2/`

### psyflash
- [ ] psyflash (`old/Audio/psyflash.ogl`) → `Sources/Audio/psyflash.glsl/`

### psytunnel
- [ ] psytunnel (`old/Audio/psytunnel.ogl`, `psytunnel_B.ogl`, `psytunnel_C.ogl`, `psytunnel_D.ogl`) → `Sources/Audio/psytunnel/`

### psytunnel2
- [ ] psytunnel2 (`old/Audio/psytunnel2.ogl`, `psytunnel2_B.ogl`) → `Sources/Audio/psytunnel2/`

### rainbowspec
- [ ] rainbowspec (`old/Audio/rainbowspec.ogl`) → `Sources/Audio/rainbowspec.glsl/`

### room
- [ ] room (`old/Audio/room.ogl`) → `Sources/Audio/room.glsl/`

### smoke
- [ ] smoke (`old/Audio/smoke.ogl`, `smoke_B.ogl`) → `Sources/Audio/smoke/`

### spectro
- [ ] spectro (`old/Audio/spectro.ogl`, `spectro_B.ogl`) → `Sources/Audio/spectro/`

### spiral
- [ ] spiral (`old/Audio/spiral.ogl`, `spiral_B.ogl`) → `Sources/Audio/spiral/`

### tris
- [ ] tris (`old/Audio/tris.ogl`, `tris_B.ogl`, `tris_C.ogl`) → `Sources/Audio/tris/`

### tunnel
- [ ] tunnel (`old/Audio/tunnel.ogl`) → `Sources/Audio/tunnel.glsl/`

### tunnel2
- [ ] tunnel2 (`old/Audio/tunnel2.ogl`, `tunnel2_B.ogl`, `tunnel2_C.ogl`) → `Sources/Audio/tunnel2/`

### vaporwave
- [ ] vaporwave (`old/Audio/vaporwave.ogl`) → `Sources/Audio/vaporwave.glsl/`

### vinyl
- [ ] vinyl (`old/Audio/vinyl.ogl`) → `Sources/Audio/vinyl.glsl/`

### wave
- [ ] wave (`old/Audio/wave.ogl`, `wave_B.ogl`, `wave_C.ogl`) → `Sources/Audio/wave/`

### izotope (root level)
- [ ] izotope (`old/izotope.ogl`) → `Sources/Audio/izotope/`

---

## Background Shaders (Effects/Backgrounds/)

### glitch_background
- [ ] glitch_background (`old/glitch_background.ogl`) → `Effects/Backgrounds/glitch_background.glsl/`

### Sphere - Myst
- [ ] Sphere - Myst (`old/Backgrounds/Sphere - Myst.ogl`) → `Effects/Backgrounds/sphere_myst.glsl/`

### Wavy Particles
- [ ] Wavy Particles (`old/Backgrounds/Wavy Particles.ogl`, `Wavy Particles_B.ogl`, `Wavy Particles_C.ogl`, `Wavy Particles_D.ogl`, `Wavy Particles_E.ogl`, `Wavy Particles_shared.ogl`) → `Effects/Backgrounds/wavy_particles/`

### slime
- [ ] slime (`old/Backgrounds/slime.ogl`) → `Effects/Backgrounds/slime.glsl/`

---

## Basic Shaders (Sources/Basic/)

### two_lines
- [ ] two_lines (`old/two_lines.ogl`) → `Sources/Basic/two_lines.glsl/`

### Stripes
- [ ] Stripes (`old/Basic/Stripes.ogl/`) → `Sources/Basic/Stripes.glsl/`

---

## Interactive Shaders (Sources/Interactive/)

### Graffiti
- [ ] Graffiti (`old/Interactive/Graffiti.ogl`, `Graffiti_B.ogl`, `Graffiti_C.ogl`) → `Sources/Interactive/Graffiti/`

---

## Kaleidoscope Shaders (Effects/Kaleidoscopes/)

### trippy_spiral
- [ ] trippy_spiral (`old/trippy_spiral.ogl`) → `Effects/Kaleidoscopes/trippy_spiral.glsl/`

### kaleidoscope1
- [ ] kaleidoscope1 (`old/Kaleidoscopes/kaleidoscope1.ogl`) → `Effects/Kaleidoscopes/kaleidoscope1.glsl/`

### kaleidoscope2
- [ ] kaleidoscope2 (`old/Kaleidoscopes/kaleidoscope2.ogl`) → `Effects/Kaleidoscopes/kaleidoscope2.glsl/`

### kaleidoscope3
- [ ] kaleidoscope3 (`old/Kaleidoscopes/kaleidoscope3.ogl`) → `Effects/Kaleidoscopes/kaleidoscope3.glsl/`

### kaleidoscope4_multi
- [ ] kaleidoscope4_multi (`old/Kaleidoscopes/kaleidoscope4_multi.ogl`) → `Effects/Kaleidoscopes/kaleidoscope4_multi.glsl/`

### kaleidoscope5
- [ ] kaleidoscope5 (`old/Kaleidoscopes/kaleidoscope5.ogl`) → `Effects/Kaleidoscopes/kaleidoscope5.glsl/`

### kaleidoscope6
- [ ] kaleidoscope6 (`old/Kaleidoscopes/kaleidoscope6.ogl`) → `Effects/Kaleidoscopes/kaleidoscope6.glsl/`

### kaleidoscope7
- [ ] kaleidoscope7 (`old/Kaleidoscopes/kaleidoscope7.ogl`) → `Effects/Kaleidoscopes/kaleidoscope7.glsl/`

### kaleidoscope_1
- [ ] kaleidoscope_1 (`old/Kaleidoscopes/kaleidoscope_1.ogl`) → `Effects/Kaleidoscopes/kaleidoscope_1.glsl/`

### kaleidoscope_2
- [ ] kaleidoscope_2 (`old/Kaleidoscopes/kaleidoscope_2.ogl`) → `Effects/Kaleidoscopes/kaleidoscope_2.glsl/`

### kaleidoscope9
- [ ] kaleidoscope9 (`old/Kaleidoscopes/kaleidoscope9_A.ogl`, `kaleidoscope9_B.ogl`) → `Effects/Kaleidoscopes/kaleidoscope9/`

### kaleidoscope10_cyberneon
- [ ] kaleidoscope10_cyberneon (`old/Kaleidoscopes/kaleidoscope10_cyberneon.ogl`) → `Effects/Kaleidoscopes/kaleidoscope10_cyberneon.glsl/`

### kaleidoscope11_cyberneon2
- [ ] kaleidoscope11_cyberneon2 (`old/Kaleidoscopes/kaleidoscope11_cyberneon2.ogl`) → `Effects/Kaleidoscopes/kaleidoscope11_cyberneon2.glsl/`

### kaleidoscope12
- [ ] kaleidoscope12 (`old/Kaleidoscopes/kaleidoscope12.ogl`) → `Effects/Kaleidoscopes/kaleidoscope12.glsl/`

### kaleidoscope13
- [ ] kaleidoscope13 (`old/Kaleidoscopes/kaleidoscope13.ogl`) → `Effects/Kaleidoscopes/kaleidoscope13.glsl/`

### kaleidoscope8_nice
- [ ] kaleidoscope8_nice (`old/Kaleidoscopes/kaleidoscope8_nice.ogl`) → `Effects/Kaleidoscopes/kaleidoscope8_nice.glsl/`

---

## Misc Shaders (Effects/Misc/)

### barber
- [ ] barber (`old/Misc/barber.ogl`) → `Effects/Misc/barber.glsl/`

---

## Noise Shaders (Effects/Noise/)

### color_noise
- [ ] color_noise (`old/color_noise.ogl`) → `Effects/Noise/color_noise.glsl/`

### GaussianNoise
- [ ] GaussianNoise (`old/Noise/GaussianNoise.ogl`) → `Effects/Noise/GaussianNoise.glsl/`

---

## Pattern Shaders (Effects/Patterns/)

### Bubbles
- [ ] Bubbles (`old/Bubbles.ogl`) → `Effects/Patterns/Bubbles.glsl/`

### CenterBlob
- [ ] CenterBlob (`old/CenterBlob.ogl`) → `Effects/Patterns/CenterBlob.glsl/`

### ChainThing
- [ ] ChainThing (`old/ChainThing.ogl`) → `Effects/Patterns/ChainThing.glsl/`

### DotsColored
- [ ] DotsColored (`old/DotsColored.ogl`) → `Effects/Patterns/DotsColored.glsl/`

### design_thing
- [ ] design_thing (`old/design_thing.ogl`, `design_thing_B.ogl`, `design_thing_C.ogl`, `design_thing_D.ogl`, `design_thing_E.ogl`, `design_thing_shared.ogl`) → `Effects/Patterns/design_thing/`

### journey_matrix_temple
- [ ] journey_matrix_temple (`old/journey_matrix_temple.ogl`) → `Effects/Patterns/journey_matrix_temple.glsl/`

### lavalamp
- [ ] lavalamp (`old/lavalamp.ogl`, `lavalamp_A.ogl`, `lavalamp_B.ogl`, `lavalamp_C.ogl`, `lavalamp_shared.ogl`) → `Effects/Patterns/lavalamp/`

### led_pattern
- [ ] led_pattern (`old/led_pattern.ogl`) → `Effects/Patterns/led_pattern.glsl/`

### matrix
- [ ] matrix (`old/matrix.ogl`) → `Effects/Patterns/matrix.glsl/`

### modular
- [ ] modular (`old/modular.ogl`) → `Effects/Patterns/modular.glsl/`

### smoke_rings
- [ ] smoke_rings (`old/smoke_rings.ogl`) → `Effects/Patterns/smoke_rings.glsl/`

### trance
- [ ] trance (`old/trance.ogl`) → `Effects/Patterns/trance.glsl/`

### wave_circles
- [ ] wave_circles (`old/wave_circles.ogl`, `wave_circles_B.ogl`, `wave_circles_C.ogl`, `wave_circles_shared.ogl`) → `Effects/Patterns/wave_circles/`

### HeavyLines
- [ ] HeavyLines (`old/Patterns/HeavyLines.ogl`, `HeavyLines_B.ogl`, `HeavyLines_C.ogl`) → `Effects/Patterns/HeavyLines/`

### ancient_tech_2_ins
- [ ] ancient_tech_2_ins (`old/Patterns/ancient_tech_2_ins.ogl`) → `Effects/Patterns/ancient_tech_2_ins.glsl/`

### antipod
- [ ] antipod (`old/Patterns/antipod.ogl`) → `Effects/Patterns/antipod.glsl/`

### cool_lines
- [ ] cool_lines (`old/Patterns/cool_lines.ogl`) → `Effects/Patterns/cool_lines.glsl/`

### pat1
- [ ] pat1 (`old/Patterns/pat1.ogl`) → `Effects/Patterns/pat1.glsl/`

### pat2
- [ ] pat2 (`old/Patterns/pat2.ogl`) → `Effects/Patterns/pat2.glsl/`

### pat3
- [ ] pat3 (`old/Patterns/pat3.ogl`) → `Effects/Patterns/pat3.glsl/`

### pat4
- [ ] pat4 (`old/Patterns/pat4.ogl`) → `Effects/Patterns/pat4.glsl/`

### pat5
- [ ] pat5 (`old/Patterns/pat5.ogl`) → `Effects/Patterns/pat5.glsl/`

### pat6
- [ ] pat6 (`old/Patterns/pat6.ogl`) → `Effects/Patterns/pat6.glsl/`

### pat7
- [ ] pat7 (`old/Patterns/pat7.ogl`) → `Effects/Patterns/pat7.glsl/`

### pattern1
- [ ] pattern1 (`old/Patterns/pattern1.ogl`) → `Effects/Patterns/pattern1.glsl/`

### procedural
- [ ] procedural (`old/Patterns/procedural.ogl`) → `Effects/Patterns/procedural.glsl/`

### psy_texture
- [ ] psy_texture (`old/Patterns/psy_texture.ogl`) → `Effects/Patterns/psy_texture.glsl/`

### psy_texture2
- [ ] psy_texture2 (`old/Patterns/psy_texture2.ogl`) → `Effects/Patterns/psy_texture2.glsl/`

### psy_texture3
- [ ] psy_texture3 (`old/Patterns/psy_texture3.ogl`) → `Effects/Patterns/psy_texture3.glsl/`

---

## ReactionDiffusion Shaders (Sources/ReactionDiffusion/)

### Lattice
- [ ] Lattice (`old/ReactionDiffusion/Lattice.ogl`, `Lattice_B.ogl`, `Lattice_C.ogl`, `Lattice_D.ogl`, `Lattice_E.ogl`) → `Sources/ReactionDiffusion/Lattice/`

### React
- [ ] React (`old/ReactionDiffusion/React.ogl`, `React_B.ogl`, `React_C.ogl`, `React_D.ogl`, `React_E.ogl`) → `Sources/ReactionDiffusion/React/`

---

## Simulation Shaders (Sources/Simulations/)

### GameOfLife
- [ ] GameOfLife (`old/Simulations/GameOfLife1/`) → `Sources/Simulations/GameOfLife/`

### fluidstream
- [ ] fluidstream (`old/Simulations/fluidstream.ogl`) → `Sources/Simulations/fluidstream.glsl/`

---

## Subject Shaders (Sources/Subjects/)

### Earth
- [ ] Earth (`old/Earth.ogl`, `Earth_B.ogl`, `Earth_shared.ogl`) → `Sources/Subjects/Earth/`

### digital_brain
- [ ] digital_brain (`old/digital_brain.ogl`) → `Sources/Subjects/digital_brain.glsl/`

### fire
- [ ] fire (`old/fire.ogl`) → `Sources/Subjects/fire.glsl/`

### golden_4dsun
- [ ] golden_4dsun (`old/golden_4dsun.ogl`, `golden_4dsun_base.ogl`) → `Sources/Subjects/golden_4dsun/`

### neon_heart
- [ ] neon_heart (`old/neon_heart.ogl`) → `Sources/Subjects/neon_heart.glsl/`

### orbits
- [ ] orbits (`old/orbits.ogl`) → `Sources/Subjects/orbits.glsl/`

### robot
- [ ] robot (`old/robot.ogl`) → `Sources/Subjects/robot.glsl/`

### rough_sea
- [ ] rough_sea (`old/rough_sea.ogl`) → `Sources/Subjects/rough_sea.glsl/`

### star_nest
- [ ] star_nest (`old/star_nest.ogl`) → `Sources/Subjects/star_nest.glsl/`

### eye
- [ ] eye (`old/Subjects/eye.ogl`) → `Sources/Subjects/eye.glsl/`

### flame
- [ ] flame (`old/Subjects/flame.ogl`) → `Sources/Subjects/flame.glsl/`

### watercolor
- [ ] watercolor (`old/watercolor.ogl`, `watercolor_base.ogl`) → `Sources/Subjects/watercolor/`

---

## Tunnel Shaders (Effects/Tunnels/)

### BlockTunnel
- [ ] BlockTunnel (`old/Tunnels/BlockTunnel.ogl`, `BlockTunnel_B.ogl`, `BlockTunnel_C.ogl`, `BlockTunnel_D.ogl`) → `Effects/Tunnels/BlockTunnel/`

### CrazyTunnel
- [ ] CrazyTunnel (`old/Tunnels/CrazyTunnel.ogl`) → `Effects/Tunnels/CrazyTunnel.glsl/`

### creepy_tunnel
- [ ] creepy_tunnel (`old/Tunnels/creepy_tunnel.ogl`) → `Effects/Tunnels/creepy_tunnel.glsl/`

### tunnel
- [ ] tunnel (`old/Tunnels/tunnel_A.ogl`, `tunnel_B.ogl`) → `Effects/Tunnels/tunnel/`

---

## Fractal Shaders (Effects/Fractals/)

### FracWithLights
- [ ] FracWithLights (`old/FracWithLights.ogl`, `FracWithLights_B.ogl`) → `Effects/Fractals/FracWithLights.glsl/`

### silver_fractal
- [ ] silver_fractal (`old/silver_fractal.ogl`) → `Effects/Fractals/silver_fractal.glsl/`

### myst
- [ ] myst (`old/myst.ogl`) → `Effects/Fractals/myst.glsl/`

---

## Retro Shaders (Effects/Retro/)

### GreenScanVert
- [ ] GreenScanVert (`old/GreenScanVert.ogl`) → `Effects/Retro/GreenScanVert.glsl/`

### WhiteScanner
- [ ] WhiteScanner (`old/WhiteScanner.ogl`) → `Effects/Retro/WhiteScanner.glsl/`

### scanner_round
- [ ] scanner_round (`old/scanner_round.ogl`) → `Effects/Retro/scanner_round.glsl/`

---

## Raymarching Shaders (Effects/Raymarching/)

### raymarch_basic
- [ ] raymarch_basic (`old/raymarch_basic.ogl`) → `Effects/Raymarching/raymarch_basic.glsl/`

---

## Color Shaders (Effects/Color/)

### SimpleColor
- [ ] SimpleColor (`old/SimpleColor.ogl`) → `Effects/Color/SimpleColor.glsl/`

---

## Exciters (Effects/Exciters/)

### Strobe
- [ ] Strobe (`old/Strobe.ogl`) → `Effects/Exciters/Strobe.glsl/`

---

## Utility (Effects/Utility/)

### Testpattern
- [ ] Testpattern (`old/Testpattern.ogl`) → `Effects/Utility/Testpattern.glsl/`

---

## Cars (Effects/Cars/)

### cardrive
- [ ] cardrive (`old/cardrive.ogl`) → `Effects/Cars/cardrive.glsl/`

---

## Banners (Effects/Banners/)

### Banner
- [ ] Banner (`old/Banner.ogl`) → `Effects/Banners/Banner.glsl/`

---

## Notes

### Multi-file Shader Groups
Shaders with multiple `.ogl` files (e.g., `_B`, `_C`, `_shared`, `_base`, `_A`) should be consolidated into single directories.

### Duplicate Entries
Previously SimpleColor was listed under both Basic and Color categories. It has been moved exclusively to Effects/Color/.

### Banner Placement
Previously listed under Basic. Per goal, Banner is moved to Effects/Banners/.

### Subdirectory Exploration
All subdirectories in `old/` have been explored and included:
- `old/Audio/` - 70+ shaders
- `old/Backgrounds/` - 4 shaders
- `old/Basic/` - 1 shader (Stripes)
- `old/Interactive/` - 1 shader (Graffiti)
- `old/Kaleidoscopes/` - 16 shaders
- `old/Misc/` - 1 shader (barber)
- `old/Noise/` - 1 shader (GaussianNoise)
- `old/Patterns/` - 14 shaders
- `old/ReactionDiffusion/` - 2 shader groups
- `old/Simulations/` - 2 shaders
- `old/Subjects/` - 2 shaders (eye, flame)
- `old/Tunnels/` - 4 shader groups

---

## Statistics

| Category | Total | Converted | Remaining |
|----------|-------|-----------|-----------|
| Audio | 72 | 5 | 67 |
| Backgrounds | 4 | 0 | 4 |
| Basic | 2 | 0 | 2 |
| Interactive | 1 | 0 | 1 |
| Kaleidoscopes | 17 | 0 | 17 |
| Misc | 1 | 0 | 1 |
| Noise | 2 | 0 | 2 |
| Patterns | 40 | 0 | 40 |
| ReactionDiffusion | 2 | 0 | 2 |
| Simulations | 2 | 0 | 2 |
| Subjects | 13 | 0 | 13 |
| Tunnels | 4 | 0 | 4 |
| Fractals | 3 | 0 | 3 |
| Retro | 3 | 0 | 3 |
| Raymarching | 1 | 0 | 1 |
| Color | 1 | 0 | 1 |
| Exciters | 1 | 0 | 1 |
| Utility | 1 | 0 | 1 |
| Cars | 1 | 0 | 1 |
| Banners | 1 | 0 | 1 |
| **Total** | **~168** | **2** | **~166** |

---

## Conversion Priority

1. **High Priority**: Multi-file shader groups (design_thing, lavalamp, earth, etc.)
2. **Medium Priority**: Root-level single shaders
3. **Low Priority**: Subdirectory shaders and specialized categories

---

## Next Steps

1. Begin conversion with high-priority multi-file groups
2. Update checkboxes as conversions are completed
3. Verify duplicate entries don't cause conflicts
