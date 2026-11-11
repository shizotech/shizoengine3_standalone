"""Threshold: a picture in, a picture out (#853). Plain Python on the bytes, no packages.

The input is read as gray (format=gray: one byte per pixel, the GPU computes the brightness). bytes.translate()
maps every byte through a table of 256 values, which is fast enough in plain Python for a picture of this size.
The picture output is a shz.Image; a gray or RGB one is made RGBA on the way out.
"""
import shz

#@input size=(320,180) format=gray
input = None

#@slider min=0 max=1 tooltip="Brighter than this is on"
threshold = 0.5

#@slider min=0 max=0.5 tooltip="A soft edge around the threshold"
softness = 0.02

#@button tooltip="Dark parts on instead of bright ones"
invert = False

#@rgb
colour = (1.0, 1.0, 1.0)

#@output texture
result = None

#@output float min=0 max=1 tooltip="The share of the picture that is on"
coverage = 0.0


def _table(lo, hi, flip):
    out = bytearray(256)
    for v in range(256):
        x = v / 255.0
        if hi <= lo:
            t = 1.0 if x >= lo else 0.0
        else:
            t = min(max((x - lo) / (hi - lo), 0.0), 1.0)
            t = t * t * (3.0 - 2.0 * t)
        if flip:
            t = 1.0 - t
        out[v] = int(t * 255.0 + 0.5)
    return bytes(out)


def process():
    global result, coverage
    if input is None:
        return None
    gray = bytes(input.data)
    mask = gray.translate(_table(threshold - softness, threshold + softness, invert))
    n = input.width * input.height
    rgba = bytearray(n * 4)
    for i in range(3):
        level = min(max(colour[i], 0.0), 1.0)
        rgba[i::4] = mask.translate(bytes(int(v * level + 0.5) for v in range(256)))
    rgba[3::4] = b"\xff" * n
    result = shz.Image(input.width, input.height, rgba)
    coverage = sum(mask) / (255.0 * n) if n else 0.0
