"""Runs a Python asset of VibeVJ (#853 step 2) inside the Python server (engine/python/shz_python_server.py).

The loader (py_generator.shio) starts the server with this file as its script and the path of the asset's script in
the environment variable SHZ_PY_ASSET. This file loads that script as the module "vibevj_asset" and offers the host
three functions:

    shz_setup(outputs, texture, params)   which module variables are outputs, which one is the picture output, the
                                      Python types of the parameters (float, int, bool, str, tuple)
    shz_input(name, width, height, channels, binary)   the picture of a second, third ... input (kept until the frame)
    shz_frame(params, inputs, time, beat, bpm, dt, frame, binary)   one frame: sets the parameters and inputs as
                                      module variables, calls process(), returns the outputs (and the picture)

The script sees only its own variables, process() and the module shz (shz.Image, shz.log, shz.emit, ...).
Standard library only; numpy and PIL are used by Image.to_numpy() / to_pil() only when the script calls them.
"""

import importlib.util
import inspect
import math
import os
import sys

import shz


class Image:
    """A picture: width, height, channels (4 RGBA, 3 RGB, 1 gray, one byte each) and data (rows from the top).

    The data of an input is a view into shared memory that is valid while process() runs: bytes(image.data) keeps a
    copy. A picture output is an Image (or bytes of width * height * channels)."""

    __slots__ = ("width", "height", "channels", "data")

    def __init__(self, width, height, data=None, channels=4):
        self.width = int(width)
        self.height = int(height)
        self.channels = int(channels)
        if self.channels not in (1, 3, 4):
            raise ValueError("an Image has 1, 3 or 4 channels, not %d" % self.channels)
        size = self.width * self.height * self.channels
        if data is None:
            data = bytearray(size)
        if len(data) != size:
            raise ValueError("an Image of %d x %d with %d channels has %d bytes, not %d"
                             % (self.width, self.height, self.channels, size, len(data)))
        self.data = data

    def __repr__(self):
        return "shz.Image(%d x %d, %d channels)" % (self.width, self.height, self.channels)

    def pixel(self, x, y):
        """The values of the pixel at x, y (0, 0 is the top left) as a tuple of 0 - 255."""
        i = (int(y) * self.width + int(x)) * self.channels
        return tuple(self.data[i:i + self.channels])

    def copy(self):
        return Image(self.width, self.height, bytearray(self.data), self.channels)

    def to_numpy(self):
        """A numpy array (height, width, channels) of uint8; a view of the data (copy it to keep it)."""
        import numpy
        return numpy.frombuffer(self.data, dtype=numpy.uint8).reshape(self.height, self.width, self.channels)

    def to_pil(self):
        """A PIL image (a copy)."""
        from PIL import Image as PILImage
        mode = {4: "RGBA", 3: "RGB", 1: "L"}[self.channels]
        return PILImage.frombytes(mode, (self.width, self.height), bytes(self.data))

    @staticmethod
    def from_numpy(array):
        """An Image of a uint8 array (height, width) or (height, width, 1 / 3 / 4)."""
        a = array
        if a.ndim == 2:
            a = a.reshape(a.shape[0], a.shape[1], 1)
        h, w, c = a.shape
        return Image(w, h, a.astype("uint8").tobytes(), c)

    @staticmethod
    def from_pil(picture):
        """An Image of a PIL image (L, RGB or RGBA; other modes are converted to RGBA)."""
        if picture.mode not in ("L", "RGB", "RGBA"):
            picture = picture.convert("RGBA")
        channels = {"L": 1, "RGB": 3, "RGBA": 4}[picture.mode]
        return Image(picture.width, picture.height, picture.tobytes(), channels)


shz.Image = Image

_asset = None           # the module of the script
_process = None         # its process(), or None
_process_args = None    # the keyword arguments process() takes (None: every one, it has **kwargs)
_outputs = []           # names of the value outputs
_texture = ""           # name of the picture output, "" when it has none
_kept_inputs = {}       # name -> Image of the inputs that came with shz_input (a copy)
_warned = set()


def _load():
    global _asset, _process, _process_args
    path = os.environ.get("SHZ_PY_ASSET", "")
    if not path:
        raise RuntimeError("SHZ_PY_ASSET is not set: the loader of the asset starts this file")
    path = os.path.abspath(path)
    folder = os.path.dirname(path)
    if folder not in sys.path:
        sys.path.insert(0, folder)
    spec = importlib.util.spec_from_file_location("vibevj_asset", path)
    if spec is None or spec.loader is None:
        raise ImportError("can not load '%s' as a Python script" % path)
    module = importlib.util.module_from_spec(spec)
    sys.modules["vibevj_asset"] = module
    spec.loader.exec_module(module)
    _asset = module
    fn = getattr(module, "process", None)
    _process = fn if callable(fn) else None
    _process_args = None
    if _process is not None:
        try:
            params = inspect.signature(_process).parameters.values()
            if not any(p.kind == p.VAR_KEYWORD for p in params):
                _process_args = set(p.name for p in params if p.kind in (p.POSITIONAL_OR_KEYWORD, p.KEYWORD_ONLY))
        except (TypeError, ValueError):
            _process_args = None


_load()


def _warn_once(text):
    if text not in _warned:
        _warned.add(text)
        shz.log(text)


_CASTS = {"float": float, "int": int, "bool": bool, "str": str, "tuple": tuple}
_param_types = {}       # name -> the Python type of a parameter (float, int, bool, str, tuple)


def shz_setup(outputs=None, texture="", params=None):
    """The host tells which module variables are outputs and the types of the parameters. Returns what the script has."""
    global _outputs, _texture, _param_types
    _outputs = list(outputs or [])
    _texture = texture or ""
    _param_types = {k: _CASTS[v] for k, v in (params or {}).items() if v in _CASTS}
    return {"process": _process is not None, "python": "%d.%d.%d" % sys.version_info[:3]}


def shz_input(name, width, height, channels, binary=None):
    """A picture of an input that does not come with the frame: kept as a copy until the next one."""
    if binary is None:
        _kept_inputs[name] = None
    else:
        _kept_inputs[name] = Image(width, height, bytearray(binary), channels)
    return None


def _json_value(name, value):
    """An output value as JSON: numbers, bools, strings, lists / tuples of them (numpy through tolist)."""
    if hasattr(value, "tolist"):
        value = value.tolist()
    if isinstance(value, bool) or value is None or isinstance(value, str):
        return value
    if isinstance(value, (int, float)):
        return value if math.isfinite(value) else None
    if isinstance(value, (list, tuple)):
        return [_json_value(name, v) for v in value]
    if isinstance(value, dict):
        return {str(k): _json_value(name, v) for k, v in value.items()}
    _warn_once("output %s: a %s is no value (number, bool, text or a list of them)" % (name, type(value).__name__))
    return None


def _picture(value):
    """The picture output: an Image, (width, height, bytes[, channels]) or None."""
    if value is None:
        return None
    if isinstance(value, Image):
        return value
    if isinstance(value, (tuple, list)) and len(value) in (3, 4):
        return Image(value[0], value[1], value[2], value[3] if len(value) == 4 else 4)
    if hasattr(value, "ndim") and hasattr(value, "shape"):
        return Image.from_numpy(value)
    if hasattr(value, "mode") and hasattr(value, "tobytes"):
        return Image.from_pil(value)
    raise TypeError("the picture output %s must be a shz.Image, not a %s" % (_texture, type(value).__name__))


def _rgba(pic):
    """A gray or RGB picture as RGBA (strided slices: no loop in Python)."""
    if pic is None or pic.channels == 4:
        return pic
    n = pic.width * pic.height
    src = bytes(pic.data)
    out = bytearray(n * 4)
    if pic.channels == 1:
        out[0::4] = src
        out[1::4] = src
        out[2::4] = src
    else:
        out[0::4] = src[0::3]
        out[1::4] = src[1::3]
        out[2::4] = src[2::3]
    out[3::4] = b"\xff" * n
    return Image(pic.width, pic.height, out, 4)


def shz_frame(params=None, inputs=None, time=0.0, beat=0.0, bpm=120.0, dt=0.0, frame=0, binary=None):
    """One frame: parameters and inputs into the module, process(), the outputs back."""
    asset = _asset
    values = {}
    if params:
        for k, v in params.items():
            cast = _param_types.get(k)
            if cast is not None and v is not None:
                try:
                    v = cast(v)
                except (TypeError, ValueError):
                    pass
            setattr(asset, k, v)
            values[k] = v
    if inputs:
        for k, desc in inputs.items():
            if desc is None:
                img = None
            elif desc.get("frame") and binary is not None:
                img = Image(desc["width"], desc["height"], binary, desc.get("channels", 4))
            else:
                img = _kept_inputs.get(k)
            setattr(asset, k, img)
            values[k] = img
    if _process is None:
        _warn_once("the script has no process(): its outputs do not change")
        result = None
    else:
        values.update(time=time, beat=beat, bpm=bpm, dt=dt, frame=frame)
        if _process_args is None:
            kwargs = values
        else:
            kwargs = {k: v for k, v in values.items() if k in _process_args}
        result = _process(**kwargs)

    # The outputs: the module variables, overridden by the dict process() returns
    out = {}
    for name in _outputs:
        out[name] = getattr(asset, name, None)
    picture = getattr(asset, _texture, None) if _texture else None
    if isinstance(result, dict):
        for k, v in result.items():
            if k == _texture and _texture:
                picture = v
            elif k in out:
                out[k] = v
            else:
                _warn_once("process() returned '%s', which is no #@output of the script" % k)
    elif result is not None:
        _warn_once("process() returned a %s: return None or a dict of outputs" % type(result).__name__)

    reply = {"outputs": {k: _json_value(k, v) for k, v in out.items()}}
    pic = _rgba(_picture(picture)) if _texture else None
    if pic is None:
        return reply
    reply["texture"] = {"width": pic.width, "height": pic.height, "channels": pic.channels}
    return shz.Result(reply, binary=pic.data)
