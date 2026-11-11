"""AverageColour: a picture in, values out (#853). Plain Python, no packages.

The input picture comes as a shz.Image (width, height, channels, data: RGBA bytes, rows from the top). The script
looks at every few pixels and sends their average colour and brightness out: link them into a shader, a lamp group
or anything with an input.

The name input makes it the In of the generator: stacked onto a clip it gets the picture of the clip.
"""

#@input size=(64,36) tooltip="The picture to measure"
input = None

#@int min=1 max=16 tooltip="Every how many pixels it looks at (1: all of them)"
step = 2

#@slider min=0 max=1 tooltip="How fast the values follow the picture: 1 at once, lower is smoother"
follow = 1.0

#@output rgb
colour = (0.0, 0.0, 0.0)

#@output float min=0 max=1
brightness = 0.0

#@output float min=0 max=1 tooltip="How much of the picture is brighter than the average"
spread = 0.0


def process():
    global colour, brightness, spread
    if input is None:
        return {"colour": (0.0, 0.0, 0.0), "brightness": 0.0, "spread": 0.0}
    data, w, h, ch = input.data, input.width, input.height, input.channels
    s = max(1, int(step))
    r = g = b = 0
    n = 0
    lums = []
    for y in range(0, h, s):
        row = y * w * ch
        for x in range(0, w, s):
            i = row + x * ch
            pr, pg, pb = data[i], data[i + 1], data[i + 2]
            r += pr
            g += pg
            b += pb
            lums.append(0.299 * pr + 0.587 * pg + 0.114 * pb)
            n += 1
    if n == 0:
        return None
    now = (r / n / 255.0, g / n / 255.0, b / n / 255.0)
    k = min(max(follow, 0.0), 1.0)
    colour = tuple(c + (t - c) * k for c, t in zip(colour, now))
    avg = sum(lums) / n
    brightness = brightness + (avg / 255.0 - brightness) * k
    spread = sum(1 for v in lums if v > avg) / n
