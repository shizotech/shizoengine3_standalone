"""CrowdMotion: how much the crowd moves, from a camera, with numpy.

Link the Out of a Camera generator into In. The script compares each picture with the one before: the share of the
pixels that changed is the movement. Light of the show (a strobe, a colour change, a fade) changes every pixel at once;
each picture is brought to the same mean brightness first, so that is not taken for movement.

- Motion: the movement now, 0 (still) to 1 (Gain sets what counts as full).
- Activity: the movement of the last Slow seconds, for the mood of the room.
- Burst: 1 for a moment when the movement jumps above Activity (hands up on a drop, a jump).
- Out: the moving pixels in white over the dark picture, to set Area, Noise and Gain.

Link Motion (or Activity) into Crowd of the Director: the model then knows how the crowd reacts.
"""
import numpy as np

#@settings rate=30

#@input size=(160,90) format=gray tooltip="The camera on the crowd: link the Out of a Camera generator into it"
input = None

#@vec4 min=0 max=1 displayname="Area" tooltip="The part of the picture that is the crowd: left, top, right, bottom (0 to 1)"
area = (0.0, 0.0, 1.0, 1.0)

#@slider min=0 max=0.5 tooltip="How much a pixel must change to count as movement: higher ignores camera noise"
noise = 0.08

#@slider min=0.5 max=20 tooltip="How much movement gives Motion 1: raise it for a crowd far away or a small Area"
gain = 4.0

#@slider min=0 max=1 tooltip="How fast Motion follows: 1 at once, lower is smoother"
follow = 0.3

#@slider min=1 max=120 unit="s" tooltip="Activity is the movement of about this many seconds"
slow = 10.0

#@slider min=0.1 max=3 tooltip="How far Motion must jump above Activity for a Burst (0.5: half as much again)"
burst_at = 0.5

#@bool tooltip="Light of the show does not count as movement: each picture is brought to the same brightness first"
light_compensation = True

#@output float min=0 max=1
motion = 0.0

#@output float min=0 max=1
activity = 0.0

#@output float min=0 max=1 tooltip="1 for half a second when the movement jumps above Activity"
burst = 0.0

#@output texture
result = None

_prev = None
_burst_left = 0.0
_raw = 0.0


def _crop(g):
    h, w = g.shape
    x0, y0, x1, y1 = (min(max(float(v), 0.0), 1.0) for v in area)
    if x1 <= x0 or y1 <= y0:
        return g, (0, 0, w, h)
    a, b = int(x0 * w), int(y0 * h)
    c, d = max(a + 1, int(round(x1 * w))), max(b + 1, int(round(y1 * h)))
    return g[b:d, a:c], (a, b, c, d)


def process(dt=0.0):
    global motion, activity, burst, result, _prev, _burst_left, _raw
    if input is None:
        _prev = None
        return {"motion": 0.0, "burst": 0.0}
    full = input.to_numpy()[:, :, 0].astype(np.float32) * (1.0 / 255.0)
    g, (a, b, c, d) = _crop(full)
    if light_compensation:
        mean = float(g.mean())
        g = g * (0.5 / max(mean, 0.02))
    if _prev is None or _prev.shape != g.shape:
        _prev = g
        return None
    moving = np.abs(g - _prev) > noise
    _prev = g
    _raw = min(1.0, float(np.count_nonzero(moving)) / moving.size * gain)

    k = min(max(float(follow), 0.0), 1.0)
    motion = motion + (_raw - motion) * k
    # Activity: an average over about Slow seconds (dt of the frame; 1/30 s when it is not known)
    step = dt if dt and dt > 0.0 else 1.0 / 30.0
    activity = activity + (motion - activity) * min(1.0, step / max(float(slow), 0.1))

    if _burst_left > 0.0:
        _burst_left -= step
    elif motion > 0.15 and motion > activity * (1.0 + burst_at):
        _burst_left = 0.5
    burst = 1.0 if _burst_left > 0.0 else 0.0

    # The picture to set it up: the moving pixels white, the rest of the area dim, outside the area dark
    view = (full * 0.25 * 255.0).astype(np.uint8)
    view[b:d, a:c] = np.where(moving, 255, (full[b:d, a:c] * 0.5 * 255.0).astype(np.uint8))
    out = np.empty((view.shape[0], view.shape[1], 4), dtype=np.uint8)
    out[:, :, 0] = view
    out[:, :, 1] = view
    out[:, :, 2] = view
    out[:, :, 3] = 255
    result = out
