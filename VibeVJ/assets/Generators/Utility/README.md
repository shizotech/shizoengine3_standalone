# Utility Generators

The `Generators/Utility/` directory contains utility and helper generators for debugging, testing, and additional functionality.

## Overview

Utility generators are the controls you play with (pads, button fields, envelopes, step sequencers) and small helpers
that show or shape a value.

## Components

| Component | Description |
|-----------|-------------|
| **XYPad.asset** | Two sliders (X, Y) set from one pad |
| **XYPathPad.asset** | Points on a pad form a path; a point travels along it at an even speed |
| **XYPositions.asset** | A list of X/Y positions; click one to send it |
| **CurvePad.asset** | Points on a pad, joined by a line or a smooth curve, travelled as a closed loop |
| **ColorSelector.asset** | A grid of colour buttons; the colours that are on are sent out, with brightness and smoothing |
| **Button-Feld.asset** | A field of buttons, each Flash, Relative or Absolute, each with its own output |
| **Control-Button-Matrix.asset** | A matrix of buttons with the same three modes |
| **EnvelopeOutput.asset** | An editable envelope, run FREE or SYNC, sampled into an output |
| **StepChaser.asset** | A step sequencer synced to the bar: a value or HOLD for every count |
| **control4.asset** | Four plain sliders, to link to |
| **quantize.asset** | Rounds an input to a number of steps |
| **textbox.asset** | A text field; its text is saved with the project |
| **value_text.asset** | Shows the value of its input as text |
| **Chat.asset** | The chat of the sidebar as a generator |
| **broken.asset** | Fails on purpose: an example of the error report of a broken asset |

## Usage

Utility generators are typically used during:
- Development and debugging
- System testing
- Information overlays during performance
- Monitoring generator parameters

## Notes

- Utility generators may have minimal performance impact
- Can be enabled/disabled independently
- Some may render on top of main output
- Useful for quick visual feedback

## Navigation

- [Generator Overview](../README.md)
- [Assets Overview](../../README.md)
