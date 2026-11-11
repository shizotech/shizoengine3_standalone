# The Python server (#853)

A Python script runs in a process of its own. ShizoScript calls its functions through a framed message queue over the
stdin / stdout pipes of that process; large binary data (textures) goes through shared memory. A crash, an exception
or a hang of the Python side ends at most that process: the host gets an error reply and keeps running. It is the
"stability" path next to the in-process CPython bridge `modules/shzmodule_python` (`python.exec/eval/call`).

The three steps of #853:

1. **The server** (this document): the protocol, the host library, the Python side, crash isolation.
2. A VibeVJ asset type for `.py` scripts: parameters parsed from comments (like the `//@` annotations of GLSL
   shader assets) become controls; texture in, values / texture out. See *Step 2* below (done).
3. Dependencies per asset with uv (uv-managed Python, a venv per asset, built on first use). See *Step 3* below (done).

| File | What |
|---|---|
| `_shizoengine3/engine/python/python_server.shio` | the host: `PythonServer` (start, call, call_async, events, stop, restart) |
| `_shizoengine3/engine/python/shz_python_server.py` | the Python side: loads the user script, runs its functions, writes the replies. Standard library only, Python 3.9+ |
| `modules/shzmodule_ipc/shz_shared_memory.{h,cpp}` | `ipc.shared_memory`: named shared memory segments (POSIX `shm_open`, Windows named file mappings) |
| `_testing/python_server_853.shio` | the test (fixtures in `_testing/python_server_853/`) |

## The host API (ShizoScript)

```
#include "engine/python/python_server"         // from _shizoengine3/; imports subprocess and ipc

server = PythonServer("assets/Python/hands.py", [python = "python3", cwd = "", env = ["KEY=VALUE"], timeout = 10000]);
if(!server.start())                            // waits for the hello of the Python side; start(false) does not
    std.warn(server.last_error());

r = server.call("process", [0.5], pixels, [out_size = w * h * 4, timeout = 200]);
if(r.ok)
    texture.upload_data(r.binary);             // r.result: the JSON value the function returned
else
    std.warn(r.kind + ": " + r.error);         // r.traceback for an exception

server.call_async("process", [0.5], [this](r) { ... }, pixels, [out_size = w * h * 4]);
server.on_event([](ev) { std.print(ev.name, ev.data); });     // shz.emit() of the script
server.on_exit([](info) { std.warn(info.error); });           // [code, error, stderr]
server.stop();                                 // graceful (stdin closed), killed after stop_grace ms
```

| Method | |
|---|---|
| `start(wait = true)` | starts the process. With `wait` it returns whether the hello came (`start_timeout`, default 20 s: imports like mediapipe are slow), without it at once; calls wait in the queue until the hello |
| `call(name, args, binary, options)` | blocks until the reply or the timeout and returns the reply |
| `call_async(name, args, callback, binary, options)` | returns the id; `callback(reply)` runs in a later `poll()`. When the server does not run it runs at once |
| `ping(timeout_ms)` | the round trip in ms, -1 without an answer. The reader thread of the Python side answers, also while a call hangs |
| `poll()` | reads the pipes, runs the callbacks, notices timeouts and the end of the process, writes waiting requests. A `std.thread` of the server calls it every `pump_ms` (default 2); an asset can call it in its per frame update too |
| `alive()`, `state()` | `stopped`, `starting`, `running`, `dead` |
| `last_error()` | why it does not run: the start failed, the script raised while it loaded (with the traceback), the process ended (exit code, `signal 11`, the last 2000 bytes of stderr), it was killed, a protocol error |
| `exit_code()`, `pid()`, `info()` (the hello), `stderr_tail()`, `pending()` | |
| `stop(grace_ms)`, `kill()`, `restart()` | |
| `on_event(cb)`, `on_exit(cb)`, `on_stderr(cb)` | callbacks, run inside `poll()` |

- `args`: a list (positional arguments), an object (keyword arguments) or `None`. `binary`: a `std.buffer`, a binary
  value (`shader.pixel_buffer()`, `ipc.shared_memory.read()`) or a string; the function gets it as the keyword
  argument `binary` (a read-only `memoryview`, valid during the call). `options`: `timeout` (ms, default the
  `timeout` of the constructor), `out_size` (bytes of binary data the reply may bring back through shared memory).
- The reply: `[ok, kind, result, error, error_type, traceback, binary, ms, id, name]`. `kind`: `ok`, `exception`
  (the function raised: `error` is `"ValueError: text"`, `traceback` the Python traceback), `timeout`, `died` (the
  process ended: `error` has the exit code and stderr), `stopped`, `not_running`. `binary` is a `std.buffer` or None.
- Options of the constructor: `python` (a string or a command with arguments, a list such as
  `["uv", "run", "python"]`; default the first of `python3` / `python` (Windows: `python` / `python3`) that is 3.9
  or newer, `pysrv_find_python()`), `cwd`, `env` (added to the inherited environment), `timeout`, `start_timeout`,
  `stop_grace`, `inline_max`, `pipe_budget`, `pump_ms`.
- **Stop the server** (`stop()`, or `kill()`): its pump thread holds it, a server that is only dropped keeps its
  process until the host ends (then the subprocess module kills it).
- A callback runs on the script thread inside `poll()`; a blocking `call()` in a render callback stalls the frame up
  to its timeout: per frame work uses `call_async`.

## The Python side

```python
import shz                                  # the server, given to the script as the module "shz"

def process(scale, binary=None):            # server.call("process", [2], pixels)
    pixels = bytes(binary)                  # copy it to keep it after the call
    return shz.Result({"hands": 2}, binary=out_bytes)   # a value and binary data back

@shz.handler("other")                       # a function under another name
def _f(x):
    return x * 10

shz.emit("loaded", {"model": "hands"})      # an event (any thread)
shz.log("text")                             # stderr (print() goes there too)
shz.current()                               # the call that runs: .id, .name, .binary, .out_capacity
shz.on_shutdown(fn)                         # runs when the server ends normally
```

The host calls the functions defined in the script (not the ones it imports, not names that start with `_`) and the
ones registered with `shz.handler`. A function returns a JSON value (dicts, lists, numbers, strings, None; numpy
arrays and numbers through their `tolist()` / `item()`; NaN and infinity become None), `bytes` (binary only) or
`shz.Result(value, binary)`. An exception becomes an error reply and the server keeps running. `SystemExit`
(`sys.exit(n)`) and `os._exit(n)` end the process with that code.

The server runs one call at a time, in the order they came (the main thread). A reader thread takes the frames out of
stdin at once and answers pings, so a long call does not stop the host from writing.

## The protocol (version 1)

### Frames

Both directions, the same layout:

```
SHZPY1 <header bytes> <payload bytes>\n<header><payload>
```

A text line (`SHZPY1`, the decimal byte counts of the header and of the payload, at most 64 bytes with the `\n`),
then the header: one JSON object, UTF-8 (the Python side writes ASCII only, `ensure_ascii`), then the payload: raw
bytes, binary data that goes through the pipe ("inline"). The pipes are binary on every platform (`msvcrt.setmode` on
Windows, `-u`): no `\r\n` translation. A line that is no frame header ends the server (protocol error): the host kills
the process and reports it, the Python side exits with code 3.

The Python side keeps the real stdin / stdout for the frames and points fd 1 at stderr and fd 0 at `/dev/null`
before it loads the script: `print()`, C libraries that write to stdout and `input()` do not touch the frames.

### Messages

`kind` of the header:

| kind | from | fields |
|---|---|---|
| `hello` | Python, first frame | `protocol` (1), `ok`, `pid`, `python` ("3.12.16"), `executable`, `script`, `handlers` (names); when the script raised while it loaded: `ok` false, `error`, `traceback`, then exit code 2 |
| `call` | host | `id` (int, unique per process), `name`, `args` (list / object / null), `timeout_ms` (for information), `binary` (a blob, below), `out` (`{shm, capacity}`: a segment for the binary data of the reply), `args_blob` (a blob with `{"args": ...}` as JSON instead of `args`, when the header would be larger than `inline_max`) |
| `reply` | Python | `id`, `ok`, `result` or `error` / `error_type` / `traceback`, `binary` (a blob), `mapped` (names of the segments this call opened for the first time), `ms` (time in the function) |
| `ping` / `pong` | host / Python | `id`; the pong has `busy` (a call runs). Answered by the reader thread |
| `event` | Python | `name`, `data`, `binary` (inline only) |
| `shm_release` | host | `names`: segments the Python side closes (the host frees them) |
| `shutdown` | host | the Python side runs the calls it has, then exits with 0. The end of stdin does the same; a call that does not return within 2 s after it is cut off (`os._exit(0)`) |
| `error` | Python | `error`: a frame of an unknown kind |

Unknown fields are ignored on both sides; a new field does not need a new version. A change that an old side would
misread changes `PROTOCOL` / `SHZPY1` (the host refuses a hello of another protocol).

### Binary data: blobs and shared memory

A blob is `{"inline": true, "size": n}` (the payload of the same frame) or `{"shm": name, "offset": 0, "size": n,
"capacity": c}` (the bytes are in the segment `name` of `c` bytes).

- **The host creates every segment** (`ipc.shared_memory.create`); the Python side only opens them. POSIX:
  `shm_open("/" + name)` (`_posixshmem`, what `multiprocessing.shared_memory` uses, without its resource tracker,
  which would delete the host's segments when the Python process ends), Windows: the named file mapping `name` in the
  session namespace (`mmap.mmap(-1, size, tagname=name)`). Names: `shzpy<8 hex>_<server>_<n>`, at most 30
  characters of `[A-Za-z0-9_]` (macOS allows 31 with the `/`).
- Binary data of a call larger than `inline_max` (4096) goes into a segment of the host's pool (sizes rounded up to
  64 KiB, a free segment that is large enough is reused); smaller data goes inline. A call with `out_size` gets a
  second segment: the Python side writes binary data of the reply that fits there, larger data comes inline.
- A segment belongs to its call until the reply. The Python side opens it on first use and keeps it open (by name);
  the reply lists it in `mapped`, and the host then removes its name (POSIX `shm_unlink`): the memory lives while
  either side maps it, and nothing is left in `/dev/shm` when one of them crashes. A Windows mapping goes with its
  last handle anyway.
- The host keeps at most `pool_free_max` (8) free segments; one it frees is listed in a `shm_release` frame.
- When the process ends, every segment of it is closed: a new process gets new ones.

### Flow control: the host never blocks

The host writes to the stdin pipe without blocking only while the pipe has room, and a Python process that stopped
reading (frozen, `SIGSTOP`, a C extension that holds the GIL) must not stall it. So the host writes requests only
while the bytes of requests without a reply stay within `pipe_budget` (3072, below the 4 KiB of a Windows pipe; one
request alone may be larger). The rest waits in the host's queue, and their timeouts run there. Pings and
`shm_release` may use 512 bytes more, so a ping gets through a full queue. A call that times out keeps its bytes and
segments until its late reply comes (then dropped) or the process ends. Large data never goes through the pipe from
the host (`inline_max`, `args_blob`).

The host reads stdout and stderr without blocking in every `poll()`; stderr is kept (`stderr_keep`, 16 KiB) for
`last_error()` and passed to `on_stderr`.

### Crash isolation

- The end of the process (an exception that is no `Exception`, `os._exit`, a segfault, a kill) is noticed in
  `poll()`: the frames written before it are still read, then every open call gets `kind = "died"` with the exit code
  (negative: the signal on POSIX) and the end of stderr, `state()` is `dead`, `on_exit` runs. `restart()` starts a
  new process.
- An exception in a function is an error reply; the server keeps running.
- A hang: the call times out (`kind = "timeout"`), the server stays (the next calls wait behind the hang). `ping()`
  tells a busy server from a frozen one; `restart()` (`stop()` kills after `stop_grace`) ends a hang.
- The host gone: the Python side reads the end of stdin and exits (after 2 s also when a call hangs). Linux: the
  subprocess module sets `PR_SET_PDEATHSIG`; Windows: the job object of the process kills it with its last handle.

## Step 2: the `.py` asset type

A Python script is a VibeVJ generator (user docs: the wiki page `Python-Generators`; for agents the `vibevj_live`
skill). An asset is a folder `Name.py/` with `src/__init__.py` and `asset.json`, or a single `Name.py` file.

| File | What |
|---|---|
| `_shizoengine3/engine/generators/extensions/py/__init__.shio` | the loader (`load_extension`): `generatoritem.shio` picks it by the extension `py` |
| `.../py/py_annotations.shio` | parses the `#@` annotations: `py_parse_annotations(source)` -> declarations, settings, problems (pure, tested by `_testing/py_annotations_853.shio`) |
| `.../py/py_generator.shio` | the generator: controls, ports, the Python server, the frame loop, errors, reload on a file change |
| `.../py/py_asset_runner.py` | the script of the Python server: loads the asset's script (path in `SHZ_PY_ASSET`), sets its variables, calls `process()` |
| `.../glsl/annotation_controls.shio` | the controls of a `//@` / `#@` type, shared with `shader_loader.shio` (one implementation of the grammar) |

**The annotations** are the `//@` grammar of the shaders with `#`: `#@<type> key=value ...` at the start of a line
directly above a module level assignment `name = default`, attributes in the order given (`options=(A, B)`,
`displayname="..."`, any setter of the control: `min`, `max`, `decimals`, `unit`, `tooltip`, ...), continued on the
next `#` lines. The assignment gives the name and the default; `value=` wins. Types: the ones of the shaders (`slider`,
`float`, `int`, `button`, `pushbutton`, `vec*`, `ivec*`, `slidervec*`, `rgb`, `rgba`, `enum`, `text`), the aliases
`bool`, `color` (rgba with four numbers), `choice`, and `trigger` (a press: True for one frame). Python only:
`#@input size=(w,h) format=rgba|rgb|gray`, `#@output <float|int|bool|vecN|rgb|rgba|text|list|texture>`,
`#@settings rate=<calls per second> timeout=<ms>`. Parameters have the control paths of shader uniforms
(`uniforms.uniforms@Controls.<name>`), inputs `input_ctrls@<name>`, the picture `output_ctrls@OUT`, value outputs
`outputs.outputs@Outputs.<name>`.

**A frame** (`update()` of the generator, the frame start of the engine):

1. Once a second the file's time: changed -> Python starts again (the controls stay; other annotations -> a note asks
   for *Reload module*, which makes the controls again with their values and links).
2. `server.poll()` (the generator polls itself, `pump_ms = 0`: no thread per generator). A `dead` server shows its
   `last_error()` in red and in the Log, once; *Restart* (`restart_python`) starts it again.
3. A call in flight: the frame is left out (`dropped`). The render loop never waits for Python.
4. Else `call_async("shz_frame", [params, inputs, time, beat, bpm, dt, frame], cb, <first input>, [out_size, timeout])`.
   Each input has a copy shader (`render_size` = `size=`, `output_pixel_format`, `pixel_readback(true)`); its
   `pixel_buffer()` is the binary of the call for the first input, every other input goes in a `shz_input` call before
   it (copied by the runner). A picture that is not read back yet (size 0) is `None` in Python.
5. The reply: `outputs` set the output controls, `texture` (`width`, `height`, `channels`) and `r.binary` go to the
   texture of *Out* (`upload_data`, made again when the size changes; `out_size` = the last picture, so it comes
   through shared memory). An exception is a red line with the traceback in the tooltip; the next good frame clears it.

`shz_setup(outputs, texture, params)` runs after each start: which variables are outputs and the Python types of the
parameters (bool, int, float, str, tuple), so `True` / `False` and tuples arrive as in the defaults.

**What changed in step 1's code for it**: the pump thread holds the server through a variable (`[this]` held nothing:
a server dropped after `stop()` was freed under the sleeping thread, "class not valid"); `flush()` / `write_request()`
do not write to a process that ended (the subprocess module logs that write as an error, "process stdin pipe is
closed", which no `try` catches; seen when a Python process was killed between two polls). `texture.upload_data()`
takes a `std.buffer` too (a picture that came inline).

## Step 3: dependencies per asset (uv)

Each asset runs in a venv of its own Python version and packages, made by [uv](https://docs.astral.sh/uv/) the first
time it is used. The Python is one uv manages (python-build-standalone), not the system's and not a bundled copy.
User docs: the wiki page `Python-Generators`, section *Dependencies*.

| File | What |
|---|---|
| `_shizoengine3/engine/python/py_env.shio` | what an asset declares, the keys, the cache folder, finding / downloading uv, the build (`pyenv_build`, blocking), the registry of the builds of a run (`pyenv_for_script`, `pyenv_poll`) |
| `_shizoengine3/engine/python/py_env_build.shio` | the build process: `shz py_env_build.shio <request.json>` runs `pyenv_build` and writes its progress to stdout; `--uv-hashes [version]` prints the table of the uv archives |
| `.../py/py_generator.shio` | `py_asset_python(path)`: the hook of step 2, now asks `pyenv_for_script`; `py_start()` waits for a build, `update()` polls it |
| `_testing/py_deps_853.shio` | the test (fixtures in `_testing/py_deps_853/`) |

**Declaring.** `asset.json` of the asset folder (the file that already holds `home` and `id`):

```json
"python": {"version": "3.12", "dependencies": ["numpy>=1.26", "mediapipe==0.10.*"]}
```

`version` is what `uv venv --python` takes (default `PYENV_DEFAULT_PYTHON`, 3.12, or `default_python` of
`configs/python.json`); `dependencies` are PEP 508 requirements as `uv pip install` takes them. A `requirements.txt`
in the asset folder or in `src/` adds its lines (comments and empty lines left out; option lines such as
`--index-url` are left out with a warning: an index belongs in `uv.toml`). `pyproject.toml` and the inline metadata of
PEP 723 are not read. A single-file asset (`Name.py`) has no folder and declares nothing.

**The key** of an environment is a hash (two 32 bit FNV-1a, 16 hex digits, `pyenv_hash`) of `PYENV_FORMAT`, the
Python version and the sorted dependencies. Two assets with the same set share a venv; a change of the set (or of the
version) gives a new key, so a new venv; the old one stays until it is deleted. An asset that declares nothing gets
the key of the default Python without packages (one venv for all of them).

**The cache** (`pyenv_cache_root`): Windows `%LOCALAPPDATA%\VibeVJ\python`, macOS `~/Library/Caches/VibeVJ/python`,
Linux `~/.cache/VibeVJ/python` (`$XDG_CACHE_HOME` is not read), or `cache` of `configs/python.json`. Never the asset
folder (it may be read-only or in the repository).

```
<cache>/venvs/<key>/                the venv; its python: bin/python, Windows Scripts\python.exe
<cache>/venvs/<key>/vibevj_env.json the marker: written last, after the venv's python ran (key, version, dependencies, uv)
<cache>/venvs/<key>.lock            {time}: refreshed every 5 s while a build runs
<cache>/venvs/<key>.request.json    what the last build process was asked
<cache>/python/                     UV_PYTHON_INSTALL_DIR: the Pythons uv installs
<cache>/uv-cache/                   UV_CACHE_DIR: wheels and downloads
<cache>/tools/uv-<version>/uv       uv, when VibeVJ downloaded it
```

uv runs with `UV_PYTHON_PREFERENCE=only-managed` (only Pythons uv installed), `UV_PYTHON_INSTALL_DIR`,
`UV_CACHE_DIR` and `UV_PYTHON_BIN_DIR` under the cache, `NO_COLOR`, `UV_NO_PROGRESS`, an empty `VIRTUAL_ENV`, and
`--no-project`: nothing goes into the user's own uv folders or `~/.local/bin`. uv's own configuration (`uv.toml`, its
`UV_*` variables such as an index or a proxy) is still read. Clearing: close VibeVJ, delete the folder (or one
`venvs/<key>`); the query `reinstall_python_env` of a generator deletes its venv and builds it again.

**uv** (`pyenv_get_uv`): `uv` of `configs/python.json`, else `uv` on the PATH, else `<cache>/tools/uv-<version>/`,
else downloaded: `curl` gets `https://github.com/astral-sh/uv/releases/download/<PYENV_UV_VERSION>/<archive>`, its
SHA-256 (sha256sum, macOS `shasum -a 256`, Windows `certutil`; openssl as a fallback) must be the one of
`PYENV_UV_BUILDS`, else it is deleted and not used; `tar` unpacks it (Windows: `%SystemRoot%\System32\tar.exe`, which
unpacks the `.zip`). The archives: `uv-<x86_64|aarch64>-unknown-linux-musl.tar.gz` (static, any distribution),
`uv-<aarch64|x86_64>-apple-darwin.tar.gz`, `uv-<x86_64|aarch64>-pc-windows-msvc.zip`; `uv.exe` is at the top of the
zip, `uv` in a folder of the tar.gz. **To update uv**: `shz _shizoengine3/engine/python/py_env_build.shio --uv-hashes
<version>` prints `PYENV_UV_VERSION` and `PYENV_UV_BUILDS` with the hashes of the release's `.sha256` files; paste
them into `py_env.shio`, run `_testing/py_deps_853.shio` (it downloads the pinned uv and builds with it).

**The build** (`pyenv_build(root, python, dependencies, opts, out)`, blocking): the marker there -> done. A fresh
lock of another process (another VibeVJ) -> wait until it is gone or stale (30 s without a refresh: a killed build).
Write the lock; get uv; delete a venv without marker (what a killed build left); `uv python find <version>` decides
the status text (*Installing Python 3.12* or *Making the environment*); `uv venv --no-project --python <version>
<venv>` (installs that Python when it is missing); `uv pip install --python <venv python> <dependencies>`; the venv's
python prints its version; the marker; the lock goes. A failing step deletes the venv and the lock and returns
`kind`: `uv` (no uv), `python` (the Python could not be installed), `deps` (a package that does not resolve or
install), `check`; `error` is the line of uv that says why (`error: ...` with its `cause:` / `Caused by:` line, or the
`×` line of its error tree), `detail` the last 25 lines of its stderr.

**Not on the render thread.** `pyenv_for_script(script, over)` (over: fields on top of `configs/python.json`):
- `python` in the configuration -> state `override` (that Python for every asset, no uv).
- The marker of the key -> state `ready`, `python` = the venv's python. One file read, no process: the usual start.
- Else a build process: `std.local_executable()` (the shz of VibeVJ) runs `py_env_build.shio` with a request file
  (`<key>.request.json`), cwd the app folder. It prints `@status <text>`, `@progress <last line of uv>` and
  `@result <json>`; `pyenv_poll(entry)` reads them without blocking. State `building`, then `ready` or `error`.
  Without uv or a uv Python for an asset that declares nothing: `fallback` (the generator runs
  `pysrv_find_python()`, the Python of the system, with a warning in the Log).
- The registry (`std.global("py_env_builds")`, by venv folder) holds the entry of a build for the whole run: every
  generator of the same key gets the same entry and polls the same process (one build). An `error` / `fallback` entry
  stays until `pyenv_forget(entry)` (*Retry*), so a failing install is not tried again every frame or by every new
  generator.

The generator (`py_start()`): a `building` entry sets `env_waiting`; the status line shows `status_text` + "…" in the
cue colour, the label under it the last line of uv (`progress`), the tooltip the Python, the packages and the venv;
`update()` polls each frame and starts the server with the python when the state changes. An `error` is the red line
(the first line, the message of uv and its stderr in the tooltip, once in the Log) and the button reads *Retry*.
`get_python_status` has `state` `installing` meanwhile and `env`: `state`, `building`, `venv`, `python_request`,
`dependencies`, `env_key`, `cache`, `status`, `progress`, `error`, `build_no` (the number of the build process of this
run; 0 when the environment was found built), `problems`, `note`, `command`. A change of `asset.json` or
`requirements.txt` (checked with the script once a second) restarts the generator, which then gets the environment
of the new set.

`python` of `configs/python.json` stays the override: it wins for every asset, uv is not used (e.g. a conda Python
with CUDA packages installed by hand).

**Windows and macOS** differ in: the venv's python (`Scripts\python.exe`), the archive (`.zip`, unpacked by the
System32 `tar.exe`), the hash tool (`certutil`), `%LOCALAPPDATA%` (`std.system_path`), `shasum` and
`~/Library/Caches` on the Mac. The checklist: `docs/python-deps-test-853.md`.
