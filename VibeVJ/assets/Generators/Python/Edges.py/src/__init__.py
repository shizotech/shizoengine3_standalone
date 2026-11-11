"""Edges: the outlines of a picture, with numpy (#853).

numpy is a dependency: asset.json names it under "python" -> "dependencies". The first time the generator is used,
VibeVJ makes a Python environment for it with uv (the status line shows the progress); later starts are immediate.
numpy works on the whole picture at once: a Sobel filter on 480 x 270 pixels takes a few milliseconds, where a loop
over the pixels in plain Python would take seconds.
"""
import numpy as np

#@input size=(480,270) format=gray
input = None

#@slider min=0 max=8 tooltip="How bright the edges are"
gain = 2.0

#@slider min=0 max=1 tooltip="Weaker edges than this stay black"
threshold = 0.05

#@rgb
colour = (0.2, 1.0, 0.6)

#@slider min=0 max=1 tooltip="How much of the picture shows under the edges"
underlay = 0.0

#@output texture
result = None

#@output float min=0 max=1 tooltip="The share of the picture that is an edge"
amount = 0.0


def process():
    global result, amount
    if input is None:
        return None
    g = input.to_numpy()[:, :, 0].astype(np.float32) * (1.0 / 255.0)
    p = np.pad(g, 1, mode="edge")
    # Sobel: the brightness changes from left to right and from top to bottom
    gx = (p[:-2, 2:] + 2.0 * p[1:-1, 2:] + p[2:, 2:]) - (p[:-2, :-2] + 2.0 * p[1:-1, :-2] + p[2:, :-2])
    gy = (p[2:, :-2] + 2.0 * p[2:, 1:-1] + p[2:, 2:]) - (p[:-2, :-2] + 2.0 * p[:-2, 1:-1] + p[:-2, 2:])
    edge = np.sqrt(gx * gx + gy * gy) * gain
    edge = np.where(edge >= threshold, np.minimum(edge, 1.0), 0.0)
    rgb = edge[:, :, None] * np.asarray(colour, dtype=np.float32)[None, None, :]
    if underlay > 0.0:
        rgb = np.maximum(rgb, g[:, :, None] * underlay)
    out = np.empty((g.shape[0], g.shape[1], 4), dtype=np.uint8)
    out[:, :, :3] = np.clip(rgb * 255.0 + 0.5, 0.0, 255.0).astype(np.uint8)
    out[:, :, 3] = 255
    result = out
    amount = float(np.count_nonzero(edge)) / edge.size
