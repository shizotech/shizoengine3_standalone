# Python server (#853 step 1): test on Windows and macOS

[#853](https://github.com/shizotech/shizoscript3_source/issues/853): Python scripts as VibeVJ generators. Step 1 is
the server: a Python process the host calls over framed stdin / stdout pipes, large binary data through shared
memory, and a crash or hang of Python that never takes the host with it (`docs/python-server.md`). Branch
`claude/python-server-853`. Built and checked on Linux in a container with Python 3.13 (system), 3.12.16 and 3.9.25
(both installed by uv). A container cannot show the Windows pipes and named file mappings, `python.exe` and the
Microsoft Store alias, or macOS `shm_open`: this checklist.

**C++ changed** (`modules/shzmodule_ipc`): a new class `ipc.shared_memory` (`shz_shared_memory.cpp`, in the
`.vcxproj` files and in `shzscript_macos/CMakeLists.txt`). The ipc module has to be built. The rest is script
(`_shizoengine3/engine/python/`), Python and Markdown.

Write the results into *Results* at the end of this file (machine, Python version and where it came from, what
passed, what not), or as a comment on the PR.

---

## What changed

| File | What |
|---|---|
| `modules/shzmodule_ipc/shz_shared_memory.{h,cpp}` (new) | `ipc.shared_memory`: `create(name, size)`, `open(name, size)`, `read`, `read_string`, `write`, `unlink`, `close`. POSIX `shm_open("/" + name)` 0600, Windows `CreateFileMappingA(name)` (the session namespace, the same as Python's `mmap.mmap(-1, size, tagname=name)`) |
| `_shizoengine3/engine/python/python_server.shio` (new) | the host: `PythonServer` |
| `_shizoengine3/engine/python/shz_python_server.py` (new) | the Python side (stdlib only): frames on the real stdin / stdout in binary mode (`msvcrt.setmode` on Windows), fd 1 pointed at stderr |
| `_testing/python_server_853.shio` (new) | the test, fixtures in `_testing/python_server_853/` |
| `docs/python-server.md` (new) | API and protocol |

### Checked on Linux

- `_testing/python_server_853.shio` with `python3` 3.13.17, uv's 3.12.16 and 3.9.25: ALL PASSED (calls, 8 MiB through
  shared memory both ways in about 45 ms, exceptions, `os._exit(3)`, `sys.exit(4)`, a segfault (exit code -11), a hang,
  a stopped process (`SIGSTOP`: 400 KiB of calls do not block the host), restart, stop, kill, the end of stdin).
- The command form through uv: `["uv", "run", "--no-project", "--python", "3.12", "python"]`.
- `_testing/run_tests.sh --no-gui`, `shzscript_macos/check_libcxx_linux.sh` (clang + libc++),
  `_testing/windows_app/check_msvc_linux.sh --only exe,subprocess,ipc` (clang-cl against the MSVC STL and the
  Windows SDK: compiles, does not link).

---

## Phase 0: get the branch, a Python

```
git fetch origin claude/python-server-853
git checkout claude/python-server-853
```

- **Windows**: `& .\_testing\windows_app\build.ps1` (the ipc module changed). A Python 3.9+ on the PATH as `python`
  (python.org installer, or `uv python install 3.12` and its `python.exe`). Note what `where python` lists: the
  Microsoft Store alias in `WindowsApps` is no Python.
- **macOS**: `sh shzscript_macos/setup_mac.sh --build`. `python3` of the Command Line Tools (3.9) or Homebrew, or
  `uv python install 3.12`.

## Phase 1: the test

- [ ] Windows: `build.ps1` builds the ipc module without an error (new file `shz_shared_memory.cpp`).
- [ ] `shz _testing/python_server_853.shio` → `ALL PASSED`. The output names the Python and its version, the time of
      300 calls and of 8 MiB there and back; note them.
- [ ] Again with another Python: `shz _testing/python_server_853.shio <path to python.exe / python3>` (e.g. the
      `python.exe` of `uv python install 3.12`) → `ALL PASSED`.
- [ ] Windows: the segfault line prints an exit code (expected 3221225477 or -1073741819, `0xC0000005`), the test
      goes on and passes.
- [ ] Windows: no console window opens for the Python process (the test is started from a terminal; also from the
      VibeVJ exe later in step 2).
- [ ] Without any Python (rename it, or a PATH without it): the test prints `SKIP: no Python 3.9 ...` and exits with 0.
      Windows with only the Store alias: `SKIP` too, or `start` fails with the message of the alias (exit code 9009);
      note which.

## Phase 2: by hand (a terminal with shz)

Save as `t.shio` next to `_testing/` and run it from the checkout root:

```
#include "_shizoengine3/engine/python/python_server"
s = PythonServer("_testing/python_server_853/handlers.py");
std.print(s.start(), s.last_error(), s.info());
b = std.buffer(); b.resize(64 * 1024 * 1024, 1);
t = std.millis(); r = s.call("shift", None, b, [out_size = b.size()]);
std.print(r.ok, r.binary.size(), r.binary[0], std.millis() - t, "ms");
std.print(s.call("hang", [5], None, [timeout = 500]).kind, s.ping());
s.kill(); std.print(s.state(), s.last_error());
```

- [ ] `start` true, the hello shows the Python version. 64 MiB come back with `2` as the first byte; note the ms.
- [ ] The hang gives `timeout`, ping a number of ms; `kill` gives `dead` and "killed".
- [ ] macOS: while the server runs, nothing named `shzpy*` stays behind after the script ended (there is no
      `/dev/shm` to look at: run the script twice, the second `create` of a pool segment would fail with "exists").
- [ ] Windows: Task Manager shows no `python.exe` left after the script ended, also after the `kill`.
- [ ] Kill the host (close the terminal / `taskkill /F` the shz) while a call hangs: the `python.exe` goes too
      (Windows: the job object; macOS: the end of stdin, within about 2 s).

---

## Results

### Windows (<date>)

Machine, Python (version, where from), per phase pass / fail, the times, anything wrong.

### macOS (<date>)

Machine (Apple silicon), Python (version, where from), per phase pass / fail, the times, anything wrong.
