# Python generators (#853 step 2): test on Windows and macOS

[#853](https://github.com/shizotech/shizoscript3_source/issues/853), step 2: a `.py` asset is a VibeVJ generator, its
`#@` comments become controls (wiki page `Python-Generators`, `docs/python-server.md`). Branch
`claude/python-asset-853`, stacked on step 1 (`claude/python-server-853`, its checklist:
`docs/python-server-test-853.md`; do that one first). Built and checked on Linux with Python 3.13 (system) and 3.12.16
(uv). What Linux cannot show: `python.exe` and the paths of Windows (drive letters, `\`) in the start of the Python
process, the Python VibeVJ finds on a Mac (Homebrew, Xcode's `python3`), and the picture of a GPU instead of Mesa.

**C++ changed**: `modules/shzmodule_nanogui/texture.cpp` (`upload_data` takes a `std.buffer`). nanogui has to be
built. The rest is script, Python and Markdown.

Write the results into *Results* at the end of this file, or as a comment on the PR.

---

## 1. The tests without the app

- [ ] `shz _testing/py_annotations_853.shio`: ALL PASSED.
- [ ] `shz _testing/py_asset_853.shio`: ALL PASSED (prints the Python it used). On Windows also with the full path of
  a `python.exe` as argument.

## 2. In the app

1. [ ] Drag `Generators` › `Python` › *LFO* into a Patchview. The status line says *Python 3.x · 0.x ms* within a few
   seconds; no console window opens on Windows. Turn *Free* on: *Value* moves.
2. [ ] *Threshold* and *AverageColour*: link the *Out* of a shader (e.g. `Sources/Basic/SimpleColor`) into their *In*.
   AverageColour's *Colour* is the colour of the shader; Threshold shows the picture, not upside down (try
   `Sources/utility/Text`: the text reads normally), *Threshold* at 0.05 lights all of it.
3. [ ] Stack *Threshold* onto a clip of a Clipview: it gets the picture of the clip.
4. [ ] Save the project, load it: the values stay, the generators run again.
5. [ ] End the Python process of one generator (Task Manager / Activity Monitor: the `python` with
   `shz_python_server.py`): the line turns red (*Python ended: …*), VibeVJ runs on; *Restart* brings it back.
6. [ ] Open `assets/Generators/Python/LFO.py/src/__init__.py` in an editor, change `rate = 0.25` to `rate = 0.5`, save:
   within a second or two the status line shows a new start. Add `#@float` + `x = 1.0` at the end: a note asks for
   *Reload module*; *Reload module* of the … menu makes the control.
7. [ ] Close VibeVJ: no `python` process of it is left.
8. [ ] An asset in a folder with a space or non-ASCII letters in its path (copy LFO.py to `assets/Mein Ordner ü/`): it
   runs.

## 3. Another Python

- [ ] `VibeVJ/configs/python.json` with `{"python": "C:\\Path\\To\\python.exe"}` (macOS: a Homebrew or uv Python):
  the status line shows that version.
- [ ] Without any Python on the PATH: the line says *No Python 3.9 or newer found*, VibeVJ runs on.

---

## Results

(machine, Python and where it came from, what passed, what not)
