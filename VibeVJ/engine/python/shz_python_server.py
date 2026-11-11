"""The Python side of the Python server of VibeVJ (#853, protocol: docs/python-server.md).

The host (engine/python/python_server.shio) starts this file as

    python -u shz_python_server.py <user_script.py>

and talks to it over stdin / stdout in frames. This file loads the user script, calls its
functions for the requests of the host and writes the replies. An exception of the user code
becomes an error reply, the server keeps running. Large binary data goes through shared memory
segments the host creates.

Only the standard library, Python 3.9 or newer.

The user script:

    import shz                      # this server, given to the script as the module "shz"

    def process(scale, binary=None):    # called by the host: server.call("process", [2])
        return {"value": scale * 2}

    @shz.handler("other_name")          # a handler under another name
    def _f(*args):
        return shz.Result({"n": 1}, binary=b"bytes")   # a value and binary data

    shz.emit("ready", {"x": 1})         # an event to the host, from any thread
"""

import io
import json
import math
import mmap
import os
import queue
import sys
import threading
import time
import traceback
import types

PROTOCOL = 1
MAGIC = b"SHZPY1"
MAX_HEADER_LINE = 64

# Exit codes of the server itself (the user code can end it with any other code)
EXIT_OK = 0
EXIT_SCRIPT_FAILED = 2      # the user script raised while it was loaded
EXIT_PROTOCOL = 3           # the host sent something that is no frame

# ---- the pipes ------------------------------------------------------------------------------
# The frames use the real stdin / stdout. Everything else that writes to fd 1 (print, C libraries)
# would break the frames, so fd 1 becomes a copy of stderr and fd 0 reads nothing.


def _take_pipes():
    in_fd = os.dup(0)
    out_fd = os.dup(1)
    if os.name == "nt":
        import msvcrt
        # Binary mode: the C runtime of Windows would turn \n into \r\n
        msvcrt.setmode(in_fd, os.O_BINARY)
        msvcrt.setmode(out_fd, os.O_BINARY)
    try:
        sys.stdout.flush()
    except Exception:
        pass
    os.dup2(2, 1)
    devnull = os.open(os.devnull, os.O_RDONLY)
    os.dup2(devnull, 0)
    os.close(devnull)
    sys.stdout = sys.stderr
    sys.stdin = io.TextIOWrapper(io.BytesIO(b""))
    return in_fd, out_fd


_in_fd = -1
_out_fd = -1
_write_lock = threading.Lock()


def _write_all(data):
    view = memoryview(data)
    while len(view):
        n = os.write(_out_fd, view)
        view = view[n:]


def _json_safe(value):
    """NaN and infinity are no JSON: they become None."""
    if isinstance(value, float):
        return value if math.isfinite(value) else None
    if isinstance(value, dict):
        return {str(k): _json_safe(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_safe(v) for v in value]
    return value


def _json_default(value):
    # numpy arrays and numbers, sets, ... without importing numpy
    if hasattr(value, "tolist"):
        return value.tolist()
    if hasattr(value, "item"):
        return value.item()
    if isinstance(value, (set, frozenset)):
        return list(value)
    raise TypeError("an object of type %s is not JSON serializable" % type(value).__name__)


def _dumps(header):
    try:
        text = json.dumps(header, separators=(",", ":"), ensure_ascii=True, allow_nan=False, default=_json_default)
    except ValueError:
        text = json.dumps(_json_safe(json.loads(json.dumps(header, default=_json_default))),
                          separators=(",", ":"), ensure_ascii=True, allow_nan=False)
    return text.encode("ascii")


def send_frame(header, payload=b"", body=None):
    """One frame to the host: 'SHZPY1 <header bytes> <payload bytes>\\n', the header, the payload."""
    if body is None:
        body = _dumps(header)
    payload = memoryview(payload).cast("B") if payload else b""
    line = b"%s %d %d\n" % (MAGIC, len(body), len(payload))
    with _write_lock:
        try:
            _write_all(line + body)
            if len(payload):
                _write_all(payload)
        except (BrokenPipeError, OSError):
            # The host is gone: nobody reads the replies any more
            os._exit(EXIT_OK)


def _read_frame(stream):
    """(header, payload) of the next frame of the host, None at the end of stdin."""
    line = stream.readline(MAX_HEADER_LINE + 1)
    if not line:
        return None
    if not line.endswith(b"\n"):
        if len(line) <= MAX_HEADER_LINE:
            return None  # stdin ended inside the line
        raise ValueError("no frame header: %r" % line[:MAX_HEADER_LINE])
    parts = line[:-1].split(b" ")
    if len(parts) != 3 or parts[0] != MAGIC:
        raise ValueError("no frame header: %r" % line[:MAX_HEADER_LINE])
    hlen, plen = int(parts[1]), int(parts[2])
    body = stream.read(hlen)
    payload = stream.read(plen) if plen else b""
    if len(body) != hlen or len(payload) != plen:
        return None
    return json.loads(body.decode("utf-8")), payload


# ---- shared memory --------------------------------------------------------------------------
# The host creates every segment (ipc.shared_memory); this side only opens them by name. POSIX:
# shm_open("/" + name), Windows: the named file mapping "name" (the same as Python's
# multiprocessing.shared_memory, without its resource tracker, which would delete the segments
# of the host when this process ends).


def _open_segment(name, size):
    if os.name == "nt":
        return mmap.mmap(-1, size, tagname=name)
    try:
        import _posixshmem
        fd = _posixshmem.shm_open("/" + name, os.O_RDWR, mode=0o600)
    except ImportError:
        fd = os.open("/dev/shm/" + name, os.O_RDWR)
    try:
        return mmap.mmap(fd, size)
    finally:
        os.close(fd)


class _Segments:
    def __init__(self):
        self.maps = {}
        self.lock = threading.Lock()

    def get(self, desc, newly_mapped):
        """The mapping of a segment descriptor {shm, capacity, ...}, opened on first use."""
        name = desc["shm"]
        cap = int(desc.get("capacity", 0)) or (int(desc.get("offset", 0)) + int(desc["size"]))
        with self.lock:
            m = self.maps.get(name)
            if m is not None and len(m) >= cap:
                return m
            if m is not None:
                self._close(m)
            m = _open_segment(name, cap)
            self.maps[name] = m
            newly_mapped.append(name)
            return m

    def release(self, names):
        with self.lock:
            for name in names:
                m = self.maps.pop(name, None)
                if m is not None:
                    self._close(m)

    @staticmethod
    def _close(m):
        try:
            m.close()
        except BufferError:
            pass  # the user code still holds a memoryview of it: closed when that goes


_segments = _Segments()


# ---- the API of the user script (module "shz") -----------------------------------------------


class Result:
    """A reply with a value and binary data: return shz.Result({"n": 1}, binary=b"...")."""

    def __init__(self, value=None, binary=None):
        self.value = value
        self.binary = binary


class Call:
    """The request a handler runs for (shz.current())."""

    def __init__(self, cid, name, binary, out_capacity):
        self.id = cid
        self.name = name
        self.binary = binary
        self.out_capacity = out_capacity


_handlers = {}
_shutdown_hooks = []
_local = threading.local()


def handler(name_or_fn=None):
    """Registers a function as a handler: @shz.handler, @shz.handler("name") or shz.handler(fn)."""
    if callable(name_or_fn):
        _handlers[name_or_fn.__name__] = name_or_fn
        return name_or_fn

    def deco(fn):
        _handlers[name_or_fn or fn.__name__] = fn
        return fn
    return deco


def emit(name, data=None, binary=None):
    """Sends an event to the host (server.on_event). Safe from any thread."""
    header = {"kind": "event", "name": str(name), "data": data}
    payload = b""
    if binary is not None:
        payload = _as_bytes(binary)
        header["binary"] = {"inline": True, "size": len(payload)}
    send_frame(header, payload)


def current():
    """The Call the current handler runs for, None outside of a handler."""
    return getattr(_local, "call", None)


def log(*args):
    """Prints to stderr: the host keeps the last lines (server.stderr_tail(), on_stderr)."""
    print(*args, file=sys.stderr, flush=True)


def on_shutdown(fn):
    """fn() runs when the server ends normally (shutdown frame or end of stdin)."""
    _shutdown_hooks.append(fn)
    return fn


def _as_bytes(data):
    if isinstance(data, (bytes, bytearray)):
        return data
    if isinstance(data, memoryview):
        return data.cast("B") if data.contiguous else data.tobytes()
    if hasattr(data, "tobytes"):
        return data.tobytes()  # numpy arrays, array.array
    return memoryview(data).tobytes()


def _make_api_module():
    m = types.ModuleType("shz")
    m.__doc__ = "The API of the VibeVJ Python server for the user script (#853)."
    m.PROTOCOL = PROTOCOL
    m.Result = Result
    m.Call = Call
    m.handler = handler
    m.emit = emit
    m.current = current
    m.log = log
    m.on_shutdown = on_shutdown
    return m


# ---- calls ------------------------------------------------------------------------------------

_script = None


def _find_handler(name):
    fn = _handlers.get(name)
    if fn is not None:
        return fn
    if not name or name.startswith("_") or _script is None:
        return None
    fn = getattr(_script, name, None)
    # Only the functions of the script itself, not what it imported
    if callable(fn) and getattr(fn, "__module__", None) == _script.__name__:
        return fn
    return None


def _handler_names():
    names = set(_handlers)
    if _script is not None:
        for k, v in vars(_script).items():
            if not k.startswith("_") and callable(v) and getattr(v, "__module__", None) == _script.__name__ \
                    and not isinstance(v, type):
                names.add(k)
    return sorted(names)


def _blob(desc, payload, mapped):
    """The bytes of a blob descriptor: the inline payload or a view into a segment."""
    if desc is None:
        return None
    if desc.get("inline"):
        return memoryview(payload)[: int(desc.get("size", len(payload)))]
    m = _segments.get(desc, mapped)
    off = int(desc.get("offset", 0))
    return memoryview(m)[off: off + int(desc["size"])]


def _error_reply(cid, exc, tb_text, mapped, ms):
    return {"kind": "reply", "id": cid, "ok": False, "error": "%s: %s" % (type(exc).__name__, exc),
            "error_type": type(exc).__name__, "traceback": tb_text, "mapped": mapped, "ms": ms}


def _run_call(header, payload):
    cid = header.get("id")
    name = header.get("name", "")
    mapped = []
    start = time.perf_counter()
    binary = None
    try:
        # Every segment of the request is opened first: the reply says which, the host may then
        # remove their names (they stay mapped here)
        out = header.get("out")
        out_map = _segments.get(out, mapped) if out else None
        binary = _blob(header.get("binary"), payload, mapped)
        if "args_blob" in header:
            # Arguments too big for the pipe: {"args": ...} as JSON in a segment
            view = _blob(header["args_blob"], payload, mapped)
            try:
                args = json.loads(bytes(view).decode("utf-8"))["args"]
            finally:
                view.release()
        else:
            args = header.get("args")

        fn = _find_handler(name)
        if fn is None:
            raise LookupError("the script has no function '%s' (it has: %s)" % (name, ", ".join(_handler_names())))

        kwargs = {}
        if binary is not None:
            kwargs["binary"] = binary
        _local.call = Call(cid, name, binary, int(out["capacity"]) if out else 0)
        try:
            if args is None:
                result = fn(**kwargs)
            elif isinstance(args, dict):
                kwargs.update(args)
                result = fn(**kwargs)
            elif isinstance(args, list):
                result = fn(*args, **kwargs)
            else:
                result = fn(args, **kwargs)
        finally:
            _local.call = None

        value, data = result, None
        if isinstance(result, Result):
            value, data = result.value, result.binary
        elif isinstance(result, (bytes, bytearray, memoryview)):
            value, data = None, result

        reply = {"kind": "reply", "id": cid, "ok": True, "result": value, "mapped": mapped}
        out_payload = b""
        if data is not None:
            data = _as_bytes(data)
            n = len(data)
            if out_map is not None and n <= int(out["capacity"]):
                out_map[0:n] = data
                reply["binary"] = {"shm": out["shm"], "offset": 0, "size": n}
            else:
                out_payload = data
                reply["binary"] = {"inline": True, "size": n}
        reply["ms"] = round((time.perf_counter() - start) * 1000.0, 3)
        try:
            body = _dumps(reply)
        except Exception as e:
            reply = _error_reply(cid, TypeError("the result can not be sent: %s" % e), "", mapped, reply["ms"])
            body, out_payload = None, b""
        send_frame(reply, out_payload, body)
    except Exception as e:
        send_frame(_error_reply(cid, e, traceback.format_exc(), mapped,
                                round((time.perf_counter() - start) * 1000.0, 3)))
    finally:
        if isinstance(binary, memoryview):
            binary.release()


# ---- the loops --------------------------------------------------------------------------------

_work = queue.Queue()
_STOP = object()
_stdin_closed = threading.Event()


def _reader():
    """Reads the frames of the host. Runs while a handler works, so ping answers while a call hangs."""
    stream = os.fdopen(_in_fd, "rb", buffering=1 << 16)
    try:
        while True:
            frame = _read_frame(stream)
            if frame is None:
                break
            header, payload = frame
            kind = header.get("kind")
            if kind == "call":
                _work.put((header, payload))
            elif kind == "ping":
                send_frame({"kind": "pong", "id": header.get("id"), "busy": _busy.is_set()})
            elif kind == "shm_release":
                _segments.release(header.get("names", []))
            elif kind == "shutdown":
                _work.put(_STOP)
                return
            else:
                send_frame({"kind": "error", "error": "unknown frame kind '%s'" % kind, "id": header.get("id")})
    except Exception as e:
        sys.stderr.write("shz_python_server: protocol error: %s\n" % e)
        sys.stderr.flush()
        os._exit(EXIT_PROTOCOL)
    # End of stdin: the host is gone or wants the server to end
    _stdin_closed.set()
    _work.put(_STOP)
    # A handler that does not return keeps the process: end it after a grace time
    deadline = time.monotonic() + 2.0
    while time.monotonic() < deadline:
        if not _busy.is_set():
            return
        time.sleep(0.05)
    os._exit(EXIT_OK)


_busy = threading.Event()


def _load_script(path):
    import importlib.util
    path = os.path.abspath(path)
    folder = os.path.dirname(path)
    if folder not in sys.path:
        sys.path.insert(0, folder)
    spec = importlib.util.spec_from_file_location("shz_user_script", path)
    if spec is None or spec.loader is None:
        raise ImportError("can not load '%s' as a Python script" % path)
    module = importlib.util.module_from_spec(spec)
    sys.modules["shz_user_script"] = module
    spec.loader.exec_module(module)
    return module


def main(argv):
    global _in_fd, _out_fd, _script
    _in_fd, _out_fd = _take_pipes()
    if len(argv) < 2:
        send_frame({"kind": "hello", "protocol": PROTOCOL, "ok": False, "pid": os.getpid(),
                    "error": "usage: shz_python_server.py <script.py>"})
        return EXIT_SCRIPT_FAILED

    script_path = argv[1]
    # No __pycache__ folder in the folder of the script (an asset); installed packages have theirs
    sys.dont_write_bytecode = True
    sys.modules["shz"] = _make_api_module()
    sys.argv = [script_path] + list(argv[2:])
    hello = {"kind": "hello", "protocol": PROTOCOL, "pid": os.getpid(), "script": os.path.abspath(script_path),
             "python": "%d.%d.%d" % sys.version_info[:3], "executable": sys.executable}
    try:
        _script = _load_script(script_path)
    except BaseException as e:
        tb = traceback.format_exc()
        sys.stderr.write(tb)
        sys.stderr.flush()
        hello.update(ok=False, error="%s: %s" % (type(e).__name__, e), traceback=tb)
        send_frame(hello)
        return EXIT_SCRIPT_FAILED

    hello.update(ok=True, handlers=_handler_names())
    send_frame(hello)

    threading.Thread(target=_reader, name="shz-reader", daemon=True).start()
    while True:
        item = _work.get()
        if item is _STOP:
            break
        _busy.set()
        try:
            _run_call(*item)
        finally:
            _busy.clear()

    for fn in _shutdown_hooks:
        try:
            fn()
        except Exception:
            traceback.print_exc()
    return EXIT_OK


if __name__ == "__main__":
    code = main(sys.argv)
    try:
        sys.stderr.flush()
    except Exception:
        pass
    # os._exit: threads of the user script (non-daemon) must not keep the process
    os._exit(code)
