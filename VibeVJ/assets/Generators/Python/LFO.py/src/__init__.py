"""LFO: a wave in Python, a value generator without pictures (#853).

Every #@ comment above a variable makes a control of the generator, like the //@ comments of a shader. VibeVJ sets
the variables before each call of process(); the #@output variables are read back after it.
"""
import math
import random

#@enum options=(Sine, Triangle, Saw, Square, Noise)
shape = "Sine"

#@slider min=0 max=4 unit="per beat" tooltip="How many waves per beat"
rate = 0.25

#@slider min=0 max=1 tooltip="How far the wave moves: 1 from 0 to 1"
depth = 1.0

#@button tooltip="Free: its own time in seconds. Off: locked to the beat of the timeline"
free = False

#@trigger tooltip="Starts the free wave at 0 again"
reset = False

#@output float min=0 max=1
value = 0.0

#@output vec2 min=(0,0) max=(1,1)
circle = (0.5, 0.5)

_phase = 0.0


def _wave(kind, p):
    p = p % 1.0
    if kind == "Triangle":
        return 1.0 - abs(p * 2.0 - 1.0)
    if kind == "Saw":
        return p
    if kind == "Square":
        return 1.0 if p < 0.5 else 0.0
    return 0.5 + 0.5 * math.sin(p * 2.0 * math.pi)


def process(beat, dt):
    global _phase, value, circle
    if reset:
        _phase = 0.0
    elif free:
        _phase += dt * rate
    else:
        _phase = beat * rate
    if shape == "Noise":
        # A new random value at every whole wave, smoothed in between
        step = int(math.floor(_phase))
        rnd = random.Random(step).random()
        nxt = random.Random(step + 1).random()
        t = _phase % 1.0
        t = t * t * (3.0 - 2.0 * t)
        v = rnd + (nxt - rnd) * t
    else:
        v = _wave(shape, _phase)
    value = 0.5 + (v - 0.5) * depth
    a = _phase * 2.0 * math.pi
    circle = (0.5 + 0.5 * depth * math.cos(a), 0.5 + 0.5 * depth * math.sin(a))
