# Python dependencies per asset (#853 step 3): test on Windows and macOS

[#853](https://github.com/shizotech/shizoscript3_source/issues/853), step 3: a `.py` asset names its packages in
`asset.json` (`"python": {"version": ..., "dependencies": [...]}`) and VibeVJ makes a venv for them with uv on first
use (wiki page `Python-Generators`, section *Dependencies*; `docs/python-server.md`, *Step 3*). Branch
`claude/python-deps-853`, stacked on step 2 (`claude/python-asset-853`, its checklist: `docs/python-asset-test-853.md`)
and step 1 (`docs/python-server-test-853.md`). Built and checked on Linux x64 with uv 0.13.6 (downloaded and checked
by the test) and uv 0.11.32 (on the PATH), Python 3.12.13 from uv.

What Linux cannot show: the venv's `Scripts\python.exe`, the `.zip` of uv unpacked by `System32\tar.exe`, `certutil`
for the SHA-256, `%LOCALAPPDATA%` on Windows; `shasum`, `~/Library/Caches` and the arm64 build of uv on the Mac; long
paths of big packages on Windows.

**No C++ changed**: script, Python and Markdown. The build of step 2 is enough.

Write the results into *Results* at the end of this file, or as a comment on the PR.

---

## 1. The test without the app

- [ ] `shz _testing/py_deps_853.shio`: ALL PASSED (with network). It downloads uv 0.13.6 into its cache folder
  (Windows `Documents\Shizoscript\.cache\shizoscript_tests\py_deps_853`, else
  `~/.config/shizoscript/.cache/shizoscript_tests/py_deps_853`), refuses a file with another SHA-256, and builds
  venvs with six and colorama. Note the time it took. A folder as argument puts the cache elsewhere.
- [ ] The same without network (Wi-Fi off): it prints `SKIP no network` after the checks that need none, no FAIL.
- [ ] Windows: once with no `uv` on the PATH (the test downloads its own anyway; the line `uv: ...` names the one it
  used).

## 2. In the app

1. [ ] Delete the Python cache first (Windows `%LOCALAPPDATA%\VibeVJ\python`, macOS `~/Library/Caches/VibeVJ/python`).
   No `configs/python.json` in VibeVJ (or one without `"python"`).
2. [ ] Drag `Generators` › `Python` › *LFO* into a Patchview: the status line says *Getting uv…* / *Installing Python
   3.12…* (orange), a grey line under it shows what uv does, then *Python 3.12.x · … ms*. VibeVJ stays usable
   meanwhile (move a slider of another generator). No console window opens on Windows.
3. [ ] Drag *Edges* in twice, quickly: both say *Installing dependencies: numpy>=1.26…*; both run when it is done
   (`get_python_status` of both: the same `env.venv`, the same `env.build_no`, or 0 for one that came later). Link a
   shader with shapes (`Sources/Basic/Checkerboard`) into *In*: *Out* shows its outlines, *Amount* is above 0.
4. [ ] The cache folder has `venvs/<two folders>` (LFO without packages, Edges with numpy), `python/`, `uv-cache/`,
   and `tools/uv-0.13.6/` when there was no uv on the PATH. Nothing new in `~/.local/bin` (Mac) and no new Python in
   *Apps & features* (Windows).
5. [ ] Close VibeVJ while *Edges* installs (delete its venv folder first, or change `numpy>=1.26` to `numpy>=2` in
   `assets/Generators/Python/Edges.py/asset.json`): start again, drag Edges in: it waits at most 30 s (*Waiting for
   another VibeVJ…*), then installs again and runs. No `python` / `uv` process of the closed VibeVJ is left.
6. [ ] Write `"vibevj-no-such-package"` into the dependencies of a copy of Edges: the line turns red (*The
   dependencies could not be installed: No solution found …*), the tooltip has uv's message, the button says *Retry*;
   VibeVJ runs on. No `venvs/<key>` folder of it is left.
7. [ ] Network off, cache deleted, no uv on the PATH: *LFO* runs with the Python of the system (the Log has a warning
   that uv could not be had); *Edges* is red (*uv could not be downloaded …*), *Retry* with the network on installs it.
8. [ ] `configs/python.json` `{"python": "C:\\Path\\To\\python.exe"}`: every asset runs with that Python, nothing is
   installed (Edges then needs numpy in that Python).
9. [ ] Windows: a user name with a space or non-ASCII letters (`C:\Users\Jürgen M\AppData\Local\VibeVJ\python`): the
   install and the start work. A big package (`"torch"` in a copy of Edges): it installs (long paths) and imports.

---

## Results

(machine, uv on the PATH or downloaded, what passed, what not, the times of the first install)
