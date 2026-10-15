# FFGL plugins

Put FFGL plugins here: `.dll` on Windows, `.bundle` on macOS, `.so` on Linux. Drag one from the *Assets* tab into a
Patchview, an area or onto a clip like a shader (#428).

- Only FFGL 2 plugins (Resolume 7 and later) load. FreeFrame 1 plugins are refused with a message in the generator.
- A plugin becomes a generator like a GLSL shader: preview, *OUT*, render size, Spout, NDI, display and video router.
  Its parameters are controls in the section *FFGL* of the *Control* tab: sliders (with the range the plugin gives),
  buttons for bool and event parameters, a list for options, a text field for text. They are linked, MIDI mapped and
  saved like any control.
- An effect has the port *In 1* in that section (a mixer *In 1* and *In 2*). *In 1* is the default input, so an FFGL
  effect works in the stack of a clip and in the effects of a MapLab output.
- The time and the beat of the timeline go to the plugin.
- The host: `shzmodule_nanogui/ffgl_host.cpp` (nanogui `ffgl` widget), the loader:
  `engine/generators/extensions/ffgl/`.

Plugins are not part of the repository; this folder only holds this file.
