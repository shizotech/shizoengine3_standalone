// --- EdgeSweep: what every pass shares ---
#define MASK_AUTO 4
#include mapping.glsl
#include mask.glsl
#include beat.glsl
#include jfa.glsl

uniform sampler2D input;   // the material: a video, a picture, a shader

//@enum options=(Input picture, Mask, Both) value=2
uniform int edge_source;      // which outlines light up: the edges in the picture, the outline of the mask, or both
//@slider min=0.0 max=1.0 value=0.12
uniform float edge_threshold; // how strong an edge of the picture must be
//@slider min=0.5 max=8.0 value=1.0
uniform float edge_detail;    // pixels: blurs the picture before the edges are found; more ignores fine texture
//@enum options=(Linear, Radial, Around, Trace, Pulse, Sparkle) value=3
uniform int sweep_mode;       // Trace: comets that run along the outlines

float mp_luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
